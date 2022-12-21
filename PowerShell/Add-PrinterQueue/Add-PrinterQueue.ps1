<#
.SYNOPSIS
    Adds a printer queue.
.DESCRIPTION
    Adds a printer queue based on the computer OU.
.EXAMPLE
    Add-Printer.ps1
.INPUTS
    None.
.OUTPUTS
    System.String
.NOTES
    Created by Ioan Popovici
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/Issues
.COMPONENT
    Printer
.FUNCTIONALITY
    Add Printer
#>

## Set script requirements
#Requires -Version 3.0

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

## Display script path and name
Write-Verbose -Message "Running script: Add-PointAndPrintQueue" -Verbose

## Set scheudled task name
[string]$ScheduledTaskName = 'Add-PointAndPrintQueue'

## Detection  script: Set $Remediate to $false | Remediatin script: Set $Remediate to $true
[boolean]$Remediate = $true

## Set North America OU regex pattern
[regex]$NAMRegexPattern = 'OU=CA,|OU=US,|OU=MX,'

## Do not modify anything beyond this point
[string]$Output = 'Non-Compliant'

#endregion
##*=============================================
##* END VARIABLE DECLARATION
##*=============================================

##*=============================================
##* FUNCTION LISTINGS
##*=============================================
#region FunctionListings

#region Function Get-ADObject
Function Get-ADObject {
<#
.SYNOPSIS
    Gets an active directory object.
.DESCRIPTION
    Gets an active directory object unit using ASDI.
.PARAMETER Name
    Specifies the object name.
.PARAMETER ObjectClass
    Specifies the object class.
    Allowed values are:
        'computer'
        'user'
        'group'
.EXAMPLE
    Get-ADObject -Name $env:ComputerName -ObjectClass 'computer'
.INPUTS
    None.
.OUTPUTS
    System.DirectoryServices.ResultPropertyCollection
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.COMPONENT
    AD
.FUNCTIONALITY
    Get Active Direcotry Object Information
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true,Position=0)]
        [ValidateNotNullorEmpty()]
        [Alias('ObjectName')]
        [string]$Name,
        [Parameter(Mandatory=$true,Position=1)]
        [ValidateNotNullorEmpty()]
        [ValidateSet('computer','user','group')]
        [Alias('Type')]
        [string]$ObjectClass
    )
    Begin {

        ## Initialize variables
        [System.DirectoryServices.ResultPropertyCollection]$Output = $null

        ## Build ADSearcher object
        $ADSISearcher = New-Object -TypeName 'System.DirectoryServices.DirectorySearcher'
        $ADSISearcher.Filter = "(&(name=$Name)(objectClass=$ObjectClass))"
        $ADSISearcher.SearchScope = 'Subtree'
    }
    Process {
        Try {

            ## Get object information
            $Output = $ADSISearcher.FindAll().Properties

            ## If we dont get a result throw an error
            If (-not [string]::IsNullOrWhiteSpace($Output)) { Write-Verbose -Message "Successfully retrieved object '$Name' information" -Verbose }
            Else { Throw $(New-Object -TypeName 'System.Exception' -ArgumentList "Failed to retrieve object '$Name' information") }
        }
        Catch {
            Throw $PsItem
        }
        Finally {
            Write-Output -InputObject $Output
        }
    }
    End {
        Remove-Variable -Name 'ADSISearcher' -ErrorAction 'SilentlyContinue'
    }
}
#endregion

#endregion
##*=============================================
##* END FUNCTION LISTINGS
##*=============================================

##*=============================================
##* SCRIPT BODY
##*=============================================z
#region ScriptBody

Try {

    ## Set computer and domain shortname
    [string]$ComputerName = [System.Net.Dns]::GetHostName()
    [string]$DomainName = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().Name
    [string]$DomainShortName = $DomainName.Split('.')[0].ToUpper()

    ## Get Region
    $Region = If ($DomainShortName -ne 'AM') { $DomainShortName } Else {

        ## Get the OU name
        $ADObject = Get-ADObject -Name $ComputerName -ObjectClass 'computer'
        [string]$ObjectDN = $ADObject.Item('distinguishedname')
        [string]$OU = $ObjectDN.Substring($ObjectDN.IndexOf('OU='))
        Write-Verbose -Message "OU: $OU" -Verbose

        ## If the ou name does not match CA (Canada), US (United States) or MX (Mexico) then we are in North America
        If ($OU -notmatch $NAMRegexPattern) { 'NAM' } Else { 'LAM' }
    }
    Write-Verbose -Message "Region: $Region" -Verbose

    ## Set printer queue per region
    $ConnectionName = Switch ($Region) {
        'AM'  { '\\PrinterShare\AM';  Break }
        'NAM' { '\\PrinterShare\NAM'; Break }
        'LAM' { '\\PrinterShare\LAM'; Break }
        'EM'  { '\\PrinterShare\EM';  Break }
    }
    Write-Verbose -Message "Connection Name: $ConnectionName" -Verbose

    ## Get Printer Queue
    [string]$PrinterName = $ConnectionName.Split('\')[3]
    Write-Verbose -Message "Printer Name: $PrinterName" -Verbose

    ## Check if printer is installed
    $IsInstalled = [boolean](Get-Printer | Where-Object { $PsItem.Name -eq $ConnectionName })
    Write-Verbose -Message "$PrinterName is installed: $IsInstalled" -Verbose

    ## If printer is installed, output 'Compliant'
    If ($IsInstalled) { $Output = 'Compliant' }

    ## If Remediate is specified, attempt to add the printer, and change the output to compliant if successful
    ElseIf ($Remediate) {

        ## Adding scheduled task to automatically add the printer queue on logon (Workaround for the printer not actually being added)
        #  Check if the scheduled task exists
        $ScheduleTaskExists = [boolean](Get-ScheduledTask -TaskName $ScheduledTaskName -ErrorAction 'SilentlyContinue')
        If (-not $ScheduleTaskExists) {
            Write-Verbose -Message "Attempting to add Scheduled Task '$ScheduledTaskName'" -Verbose

            ## Build add printer script block
            $AddPrinterQueue = "Add-Printer -ConnectionName '$ConnectionName' -ErrorAction Stop"
            $ScriptBlock = [ScriptBlock]::Create($AddPrinterQueue)

            ## Build the scheduled task
            $PowershellPath = 'C:\WINDOWS\System32\WindowsPowerShell\v1.0\powershell.exe'
            $Argument  = "-WindowStyle Hidden -NonInteractive -Command `"Invoke-Command -ScriptBlock { $ScriptBlock }`""
            $Action    = New-ScheduledTaskAction -Execute $PowershellPath -Argument $Argument
            $Trigger   = New-ScheduledTaskTrigger -AtLogon
            $Principal = New-ScheduledTaskPrincipal -GroupID 'BUILTIN\Users'
            $Settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

            ## Create the scheduled task
            Register-ScheduledTask -TaskName $ScheduledTaskName -Trigger $Trigger -Action $Action -Principal $Principal -Settings $Settings | Out-Null

            ## Display success message
            Write-Verbose -Message "Scheduled task [$ScheduledTaskName] added successfully!" -Verbose
        }
        Else { Write-Warning -Message "Scheduled task [$ScheduledTaskName] does not exist!" -Verbose }

        ## Attempt to add the printer queue
        Write-Verbose -Message "Attempting to add printer '$PrinterName'" -Verbose
        $PointAndPrintRegistryPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers\PointAndPrint'
        If (-not (Test-Path -Path $PointAndPrintRegistryPath)) { New-Item -Path $PointAndPrintRegistryPath -Force | Out-Null }

        ## Dangerous registry settings. These basically negate all Printer Nighmare protections
        [scriptblock]$Restrictions = {
            Param(
                [Parameter(Mandatory=$true)]
                [ValidateNotNullorEmpty()]
                [ValidateSet('Remove','Add')]
                [string]$Action
            )
            #  Set parameters
            If ($Action -eq 'Remove') { $Value = 0 } Else { $Value = 1 }
            $Parameters = @{
                'RestrictDriverInstallationToAdministrators' = $Value
                'UpdatePromptSettings'                       = $Value
                'NoWarningNoElevationOnInstall'              = $Value
            }
            #  Set registry values
            ForEach ($Parameter in $Parameters){
                New-ItemProperty -Path $PointAndPrintRegistryPath -Name $Parameter.Key -Value $Parameter.Value -PropertyType 'DWord' -Force | Out-Null
            }
        }

        ## Remove restrictions
        $Restrictions.Invoke('Remove')

        ## Add printer
        $WmiPrinterObject = [WMIClass]'\\.\root\cimv2:Win32_Printer'
        $ReturnValue = ($WmiPrinterObject.AddPrinterConnection($ConnectionName)).ReturnValue
        If ($ReturnValue -eq 0) {
            Write-Verbose -Message "Printer '$PrinterName' was successfully installed!" -Verbose
            $Output = 'Compliant'
        }
        Else { Throw $(New-Object -TypeName 'System.Exception' -ArgumentList "Failed to install printer '$PrinterName' with error '$ReturnValue'!") }
    }
}
Catch {
    $Output = $PsItem
}
Finally {

    ## Restore restrictions
    $Restrictions.Invoke('Add')

    ## Output result
    Write-Output -InputObject $Output
}

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================