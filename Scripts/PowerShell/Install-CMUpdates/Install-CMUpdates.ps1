<#
.SYNOPSIS
    SCCM Agent Actions and Reporting.
.DESCRIPTION
    Invokes a configuration manager agent action.
.EXAMPLE
    Install-CMUpdates
.OUTPUTS
    System.String. Returns CM Evaluation States.
.NOTES
    Created by Ioan Popovici & Paul Vilcu
.LINK
    https://MEM.Zone/
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    Install-CMUpdates | Get-CMUpdates
.FUNCTIONALITY
    Invokes CM Action
#>

## Set script requirements
#Requires -Version 3.0

#*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

$Client = $env:COMPUTERNAME
$EvaluationStates = @{
    '0' = 'None';
    '1' = 'Available';
    '2' = 'Submitted';
    '3' = 'Detecting';
    '4' = 'PreDownload';
    '5' = 'Downloading';
    '6' = 'WaitInstall';
    '7' = 'Installing';
    '8' = 'PendingSoftReboot';
    '9' = 'PendingHardReboot';
    '10'= 'WaitReboot';
    '11' = 'Verifying';
    '12' = 'InstallComplete';
    '13' = 'Error';
    '14' = 'WaitServiceWindow';
    '15' = 'WaitUserLogon';
    '16' = 'WaitUserLogoff';
    '17' = 'WaitJobUserLogon';
    '18' = 'WaitUserReconnect';
    '19' = 'PendingUserLogoff';
    '20' = 'PendingUpdate';
    '21' = 'WaitingRetry';
    '22' = 'WaitPresModeOff';
    '23' = 'WaitForOrchestration';
}

#endregion
##*=============================================
##* END VARIABLE DECLARATION
##*=============================================


##*=============================================
##* FUNCTION LISTINGS
##*=============================================
#region FunctionListings

Function Get-CMUpdates {

    $Updates = Get-WmiObject -ComputerName $Client -Namespace 'root\ccm\clientSDK' -Class 'CCM_SoftwareUpdate' | Where-Object -Property 'ComplianceState' -eq '0'

    ([wmiclass]'ROOT\ccm\ClientSDK:CCM_SoftwareUpdatesManager').InstallUpdates([System.Management.ManagementObject[]] ($Updates))

    Get-CimInstance -ComputerName $Client -Namespace 'root\ccm\clientSDK' -ClassName 'CCM_SoftwareUpdate' |  Select-Object -Property Name,  @{ Name = 'EvaluationState'; Expression = { $EvaluationStates.Get_Item([string]$_.EvaluationState) } }, PercentComplete
}

#endregion
##*=============================================
##* END FUNCTION LISTINGS
##*=============================================