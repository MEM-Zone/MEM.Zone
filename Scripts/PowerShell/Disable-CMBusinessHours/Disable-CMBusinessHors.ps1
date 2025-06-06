<#
.SYNOPSIS
    Disables ConfigMgr business hours restriction.
.DESCRIPTION
    Disables the 'Automatically install software only outside business hours' setting and unchecks all business hours days in ConfigMgr Software Center.
.PARAMETER ComputerName
    Computer name to configure.
    Defaults is: 'env:COMPUTERNAME'.
.EXAMPLE
    Disable-ConfigMgrBusinessHours.ps1
.EXAMPLE
    Disable-ConfigMgrBusinessHours.ps1 -ComputerName 'PC001'
.INPUTS
    None.
.OUTPUTS
    System.String
.NOTES
    Created by Ioan Popovici
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    ConfigMgr
.FUNCTIONALITY
    Disable Business Hours
#>

## Set script requirements
#Requires -Version 3.0
#Requires -RunAsAdministrator

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

## Get script parameters
[CmdletBinding()]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$ComputerName = $env:COMPUTERNAME
)

## Display script path and name
Write-Verbose -Message 'Running script: Disable-ConfigMgrBusinessHours' -Verbose

## Set ConfigMgr client WMI settings
[string]$WmiNamespace               = 'root\ccm\ClientSDK'
[string]$WmiClassName               = 'CCM_ClientUXSettings'
[string]$GetAutoInstallMethodName   = 'GetAutoInstallRequiredSoftwaretoNonBusinessHours'
[string]$SetAutoInstallMethodName   = 'SetAutoInstallRequiredSoftwaretoNonBusinessHours'
[string]$GetBusinessHoursMethodName = 'GetBusinessHours'
[string]$SetBusinessHoursMethodName = 'SetBusinessHours'

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

#region function Test-ConfigMgrClient
function Test-ConfigMgrClient {
<#
.SYNOPSIS
    Tests ConfigMgr client connectivity.
.DESCRIPTION
    Tests if the ConfigMgr client is accessible via WMI on the specified computer.
.PARAMETER ComputerName
    The computer name to test.
.EXAMPLE
    Test-ConfigMgrClient -ComputerName 'PC001'
.INPUTS
    None.
.OUTPUTS
    System.Boolean
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.COMPONENT
    ConfigMgr
.FUNCTIONALITY
    Test ConfigMgr Client
#>
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ComputerName
    )

    begin {
        [bool]$IsAccessible = $false
    }
    process {
        try {
            $null = Get-WmiObject -ComputerName $ComputerName -Namespace $WmiNamespace -Class $WmiClassName -ErrorAction Stop
            $IsAccessible = $true
            Write-Verbose -Message "ConfigMgr client is accessible on '$ComputerName'" -Verbose
        }
        catch {
            Write-Verbose -Message "ConfigMgr client not accessible on '$ComputerName': $($_.Exception.Message)" -Verbose
        }
        finally {
            Write-Output -InputObject $IsAccessible
        }
    }
}
#endregion

#region function Get-BusinessHoursConfiguration
function Get-BusinessHoursConfiguration {
<#
.SYNOPSIS
    Gets current business hours configuration.
.DESCRIPTION
    Retrieves the current auto-install and business hours settings from ConfigMgr client.
.PARAMETER ComputerName
    The computer name to query.
.EXAMPLE
    Get-BusinessHoursConfiguration -ComputerName 'PC001'
.INPUTS
    None.
.OUTPUTS
    System.Collections.Hashtable
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.COMPONENT
    ConfigMgr
.FUNCTIONALITY
    Get Business Hours Configuration
#>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ComputerName
    )

    begin {
        [hashtable]$Configuration = @{}
    }
    process {
        try {

            ## Get auto-install setting
            [object]$AutoInstallResult = Invoke-WmiMethod -ComputerName $ComputerName -Namespace $WmiNamespace -Class $WmiClassName -Name $GetAutoInstallMethodName -ErrorAction Stop
            $Configuration.AutoInstallEnabled = [bool]$AutoInstallResult.AutomaticallyInstallSoftware

            ## Get business hours settings
            [object]$BusinessHoursResult = Invoke-WmiMethod -ComputerName $ComputerName -Namespace $WmiNamespace -Class $WmiClassName -Name $GetBusinessHoursMethodName -ErrorAction Stop
            $Configuration.WorkingDays = [int]$BusinessHoursResult.WorkingDays
            $Configuration.StartTime = [int]$BusinessHoursResult.StartTime
            $Configuration.EndTime = [int]$BusinessHoursResult.EndTime
            $Configuration.Success = $true

            Write-Verbose -Message "Retrieved business hours configuration from '$ComputerName'" -Verbose
        }
        catch {
            $Configuration.Success = $false
            $Configuration.Error = $_.Exception.Message
            Write-Verbose -Message "Failed to retrieve business hours configuration from '$ComputerName': $($_.Exception.Message)" -Verbose
        }
        finally {
            Write-Output -InputObject $Configuration
        }
    }
}
#endregion

#region function Set-BusinessHoursConfiguration
function Set-BusinessHoursConfiguration {
<#
.SYNOPSIS
    Sets business hours configuration.
.DESCRIPTION
    Disables auto-install restriction and clears all business hours days.
.PARAMETER ComputerName
    The computer name to configure.
.PARAMETER StartTime
    The start time to preserve.
.PARAMETER EndTime
    The end time to preserve.
.EXAMPLE
    Set-BusinessHoursConfiguration -ComputerName 'PC001' -StartTime 8 -EndTime 17
.INPUTS
    None.
.OUTPUTS
    System.Collections.Hashtable
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.COMPONENT
    ConfigMgr
.FUNCTIONALITY
    Set Business Hours Configuration
#>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ComputerName,

        [Parameter(Mandatory = $true)]
        [ValidateRange(0, 23)]
        [int]$StartTime,

        [Parameter(Mandatory = $true)]
        [ValidateRange(0, 23)]
        [int]$EndTime
    )

    begin {
        [hashtable]$Result = @{
            AutoInstallSuccess = $false
            BusinessHoursSuccess = $false
            OverallSuccess = $false
        }
    }
    process {
        try {

            ## Disable auto-install restriction
            Write-Verbose -Message "Disabling auto-install business hours restriction on '$ComputerName'" -Verbose
            [object]$AutoInstallResult = Invoke-WmiMethod -ComputerName $ComputerName -Namespace $WmiNamespace -Class $WmiClassName -Name $SetAutoInstallMethodName -ArgumentList @($false) -ErrorAction Stop
            $Result.AutoInstallSuccess = ($AutoInstallResult.ReturnValue -eq 0)

            ## Clear all business hours days (set WorkingDays to 0)
            Write-Verbose -Message "Clearing all business hours days on '$ComputerName'" -Verbose
            [object]$BusinessHoursResult = Invoke-WmiMethod -ComputerName $ComputerName -Namespace $WmiNamespace -Class $WmiClassName -Name $SetBusinessHoursMethodName -ArgumentList @($EndTime, $StartTime, 0) -ErrorAction Stop
            $Result.BusinessHoursSuccess = ($BusinessHoursResult.ReturnValue -eq 0)

            ## Set overall success
            $Result.OverallSuccess = $Result.AutoInstallSuccess -and $Result.BusinessHoursSuccess

            if ($Result.OverallSuccess) {
                Write-Verbose -Message "Successfully disabled business hours on '$ComputerName'" -Verbose
            }
        }
        catch {
            $Result.Error = $_.Exception.Message
            Write-Verbose -Message "Failed to set business hours configuration on '$ComputerName': $($_.Exception.Message)" -Verbose
        }
        finally {
            Write-Output -InputObject $Result
        }
    }
}
#endregion

#endregion
##*=============================================
##* END FUNCTION LISTINGS
##*=============================================

##*=============================================
##* SCRIPT BODY
##*=============================================
#region ScriptBody

try {
    Write-Verbose -Message "Checking current business hours settings on '$ComputerName'" -Verbose

    ## Test connectivity and ConfigMgr client
    if (-not (Test-Connection -ComputerName $ComputerName -Count 1 -Quiet)) {
        throw $(New-Object -TypeName 'System.Exception' -ArgumentList "Computer '$ComputerName' is not reachable")
    }

    if (-not (Test-ConfigMgrClient -ComputerName $ComputerName)) {
        throw $(New-Object -TypeName 'System.Exception' -ArgumentList "ConfigMgr client not accessible on '$ComputerName'")
    }

    ## Get current configuration
    [hashtable]$CurrentConfig = Get-BusinessHoursConfiguration -ComputerName $ComputerName
    if (-not $CurrentConfig.Success) {
        throw $(New-Object -TypeName 'System.Exception' -ArgumentList "Failed to retrieve current configuration: $($CurrentConfig.Error)")
    }

    ## Display current settings
    [string]$AutoInstallStatus = if ($CurrentConfig.AutoInstallEnabled) { 'ENABLED' } else { 'DISABLED' }
    Write-Verbose -Message "Current auto-install restriction: $AutoInstallStatus" -Verbose
    Write-Verbose -Message "Current business hours: $($CurrentConfig.StartTime):00 - $($CurrentConfig.EndTime):00, Working days: $($CurrentConfig.WorkingDays)" -Verbose

    ## Check if changes are needed
    [bool]$NeedsAutoInstallChange = $CurrentConfig.AutoInstallEnabled
    [bool]$NeedsBusinessHoursChange = $CurrentConfig.WorkingDays -ne 0

    if ($NeedsAutoInstallChange -or $NeedsBusinessHoursChange) {
        Write-Verbose -Message 'Changes needed - applying configuration' -Verbose

        ## Apply changes
        [hashtable]$SetResult = Set-BusinessHoursConfiguration -ComputerName $ComputerName -StartTime $CurrentConfig.StartTime -EndTime $CurrentConfig.EndTime

        if ($SetResult.OverallSuccess) {
            Write-Verbose -Message 'Business hours completely disabled. Software can install anytime.' -Verbose
            $Output = 'Compliant'
        }
        else {
            [string]$ErrorDetails = ''
            if (-not $SetResult.AutoInstallSuccess) { $ErrorDetails += 'Failed to disable auto-install restriction. ' }
            if (-not $SetResult.BusinessHoursSuccess) { $ErrorDetails += 'Failed to clear business hours days. ' }
            if ($SetResult.Error) { $ErrorDetails += $SetResult.Error }

            throw $(New-Object -TypeName 'System.Exception' -ArgumentList "Configuration failed: $ErrorDetails")
        }
    }
    else {
        Write-Verbose -Message 'Business hours are already completely disabled. No changes needed.' -Verbose
        $Output = 'Compliant'
    }
}
catch {
    $Output = $_.Exception.Message
    Write-Verbose -Message "ERROR: $Output" -Verbose
}
finally {
    Write-Output -InputObject $Output
}

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================