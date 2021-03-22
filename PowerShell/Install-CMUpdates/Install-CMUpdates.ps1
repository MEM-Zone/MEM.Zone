$EvaluationStates = @{
    '0' = 'Available';
    '23' = 'WaitForOrchestration';
    '22'       = 'WaitPresModeOff';
    '21'       = 'WaitingRetry';
    '20'       = 'PendingUpdate';
    '19'       = 'PendingUserLogoff';
    '18'       = 'WaitUserReconnect';
    '17'       = 'WaitJobUserLogon';
    '16'       = 'WaitUserLogoff';
    '15'       = 'WaitUserLogon';
    '14'       = 'WaitServiceWindow';
    '13'       = 'Error';
    '12'       = 'InstallComplete';
    '11'       = 'Verifying';
    '10'       = 'WaitReboot';
    '9'        = 'PendingHardReboot';
    '8'        = 'PendingSoftReboot';
    '7'        = 'Installing';
    '6'        = 'WaitInstall';
    '5'        = 'Downloading';
    '4'        = 'PreDownload';
    '3'        = 'Detecting';
    '2'        = 'Submitted';
    '1'        = 'Available';

}


$Client = $env:COMPUTERNAME
$Updates = Get-WmiObject -ComputerName $Client -Namespace 'root\ccm\clientSDK' -Class 'CCM_SoftwareUpdate' | Where-Object -Property 'ComplianceState' -eq '0'

([wmiclass]'ROOT\ccm\ClientSDK:CCM_SoftwareUpdatesManager').InstallUpdates([System.Management.ManagementObject[]] ($Updates))


Get-CimInstance -ComputerName $Client -Namespace 'root\ccm\clientSDK' -ClassName 'CCM_SoftwareUpdate' |  Select-Object -Property Name,  @{ Name = 'EvaluationState'; Expression = { $EvaluationStates.Get_Item([string]$_.EvaluationState) } }, PercentComplete
