<#
.SYNOPSIS
    Sets the MEMCM Implicit Uninstall flag on a application deployment.
.DESCRIPTION
    Sets the MEMCM Implicit Uninstall flag on a required application deployment.
.PARAMETER ApplicationName
    Specifies the application name. Supports wildcards. Default is all applications.
.PARAMETER FlagValue
    Specifies the Implicit Uninstall flag value. Default is true.
    Avaliable values are:
        True
        False
.EXAMPLE
    Set-CMImplicitUninstall.ps1 -ApplicationName "*" -FlagValue 'False'
.INPUTS
    None.
.OUTPUTS
    None.
.NOTES
    Created by Ioan Popovici
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/Set-CMImplicitUninstall-CHANGELOG
.LINK
    https://MEM.Zone/Set-CMImplicitUninstall-GIT
.LINK
    https://MEM.Zone/ISSUES
.LINK
    https://docs.microsoft.com/en-us/mem/configmgr/develop/reference/apps/sms_applicationassignment-server-wmi-class
.COMPONENT
    Configuration Manager
.FUNCTIONALITY
    Application deployment Implicit Uninstall flag.
#>

## Set script requirements
#Requires -Version 5.0

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

## Get script parameters
Param (
    [Parameter(Mandatory=$false,HelpMessage='Enter application name',Position=0)]
    [ValidateNotNullorEmpty()]
    [Alias('Name')]
    [string]$ApplicationName = '*',
    [Parameter(Mandatory=$false,HelpMessage="Valid options are: 'true' or 'false'",Position=1)]
    [ValidateNotNullorEmpty()]
    [ValidateSet('true','false')]
    [Alias('Flag')]
    [string]$FlagValue = 'true'
)

## Set variables
[boolean]$ShouldProcess = $false
[int16]$ProgressStep = 0

## Set the bitmask table for the OfferFlags bitmask
[Flags()]Enum OfferFlagsBitmask {
    PreDeploy                = 1
    OnDemand                 = 2
    EnableProcessTermination = 4
    AllowUsersToRepairApp    = 8
    RelativeSchedule         = 16
    HighImpactDeployment     = 32
    ImplicitUninstallEnabled = 64
}

## Set the default xml for the ImplicitUninstallEnabled flag
[xml]$AdditonalPopertiesDefaultXML =
@'
<?xml version="1.0" encoding="utf-16"?>
<Properties>
    <ImplicitUninstallEnabled>true</ImplicitUninstallEnabled>
</Properties>
'@


#endregion
##*=============================================
##* END VARIABLE DECLARATION
##*=============================================


##*=============================================
##* SCRIPT BODY
##*=============================================
#region ScriptBody

## Import MEMCM Powershell module and changing context
Try {
    Import-Module $env:SMS_ADMIN_UI_PATH.Replace('\bin\i386','\bin\configurationmanager.psd1') -ErrorAction 'Stop'
}
Catch {
    Throw "Importing MEMCM Powershell module - Failed!`n$PsItem"
}

## Get the CMSITE SiteCode and change the connection context
Try {
    $SiteCode = Get-PSDrive -PSProvider 'CMSITE'
    Push-Location "$($SiteCode.Name):\"
}
Catch {
    Throw "Changing connection context - Failed!`n$PsItem"
}

## Process applications
Try {

    ## Get all required application assigments
    $ApplicationAssigments = Get-CMApplicationDeployment -Name $ApplicationName | Where-Object -Property 'OfferTypeID' -eq 0

    ## Set progress variables
    [int]$ProgressTotal = $ApplicationAssigments.Count

    ## Process each application deployment
    ForEach ($ApplicationAssigment in $ApplicationAssigments) {

        ## Show progress status
        $ProgressStep ++
        [int]$AssignmentID = $ApplicationAssigment.AssignmentID
        [int16]$PercentComplete = ($ProgressStep / $ProgressTotal) * 100
        [string]$ApplicationName = $ApplicationAssigment.ApplicationName
        Write-Progress -Activity 'Processing Applications... ' -CurrentOperation "$ApplicationName --> $AssignmentID" -PercentComplete $PercentComplete
        Write-Verbose -Message "ApplicationName: $ApplicationName --> AssignmentID: $AssignmentID" -Verbose

        ## Get the application assigment info
        $AssignmentInfo = Get-CimInstance -Namespace "ROOT\SMS\site_$SiteCode" -ClassName 'SMS_ApplicationAssignment' -Filter "AssignmentID = $AssignmentID"
        #  Get assigment OfferFlag bitmask
        [OfferFlagsBitmask]$OfferFlags = $AssignmentInfo.OfferFlags
        Write-Verbose -Message "OfferFlags: $OfferFlags" -Verbose
        #  Get the additional properties xml
        [xml]$AdditonalPoperties = $AssignmentInfo.AdditionalProperties
        Write-Verbose -Message "AdditonalPoperties: $($AdditonalPoperties.Properties)" -Verbose


        ## Set the ImplicitUninstallEnabled flag properties
        #  If there are no additional properties, set the default properties xml
        If (-not $AdditonalPoperties) { $AdditonalPoperties = $AdditonalPopertiesDefaultXML; [boolean]$ShouldProcess = $true }
        #  If the ImplicitUninstallEnabled property is not present add it to the xml
        If (-not $AdditonalPoperties.Properties.ImplicitUninstallEnabled) { $AdditonalPoperties.Properties.SetAttribute('ImplicitUninstallEnabled', 'true'); [boolean]$ShouldProcess = $true }
        #  If the ImplicitUninstallEnabled property value is not 'true' set it to 'true'
        If (-not $AdditonalPoperties.Properties.ImplicitUninstallEnabled -ne 'true') { $AdditonalPoperties.Properties.ImplicitUninstallEnabled = 'true'; [boolean]$ShouldProcess = $true }
        #  If the OfferFlags bitmask does not contain the ImplicitUninstallEnabled flag, add it. (64 is the bitmask value for the ImplicitUninstallEnabled flag, you won't find this value in the documentation)
        If (-not $OfferFlags.HasFlag([OfferFlagsBitmask]::ImplicitUninstallEnabled)) { [int]$OfferFlagsValue = $OfferFlags.GetHashCode() + 64; ; [boolean]$ShouldProcess = $true }

        ## Update the application assigment if needed
        If ($ShouldProcess) {
            $AssignmentInfo | Set-CimInstance -Property @{ AdditionalProperties = ($AdditonalPoperties.OuterXml); OfferFlags = $OfferFlagsValue } -ErrorAction 'Stop'
            Write-Verbose -Message  "Succesfully updated $ApplicationName --> $AssignmentID!" -Verbose
        }
        Else { Write-Verbose -Message  "Nothing to update for $ApplicationName --> $AssignmentID!" -Verbose }
    }

    ## Ouput success
    [string]$Output = 'Successfully processed the ImplicitUninstallEnabled flag on all required application deployments!'
    }
    Catch {
        Throw "Set ImplicitUninstall flag Failed!`n$PsItem"
    }
    Finally {
        Write-Output -InputObject $Output
    }

    ## Return to Script Path
    Pop-Location

    ## Remove SCCM PSH Module
    Remove-Module 'ConfigurationManager' -Force -ErrorAction 'SilentlyContinue'

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================
