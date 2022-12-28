<#
.SYNOPSIS
 Verify if ccmeval.xml for System Center Configuration Manager Client includes additional Restart ccmexec (SMS Agent Host) functionality.

.DESCRIPTION
 Check if the New Functionality to Restart the ccmexec (SMS Agent Host) service is configured as part of the ccmeval cycle.

#>
Param(
    $ErrorActionPreference = 'SilentlyContinue'
    )

$CMClientDir = (Get-ItemProperty 'HKLM:\Software\Microsoft\SMS\Client\Configuration\Client Properties').'Local SMS Path'
$XMLFile = $CMClientDir + 'CcmEval.xml'
$StartExists = $false
$StopExists = $false

[xml]$XMLDocument = Get-Content -Path $XMLFile

If (test-path $XMLFile -ErrorAction SilentlyContinue){
    Foreach ($HealthCheck in $XMLDocument.ClientHealth.HealthCheck){
        Write-Verbose $HealthCheck.Description
        If ($HealthCheck.Description -eq 'Stop Restart SMSAgentHost'){
            $StopExists=$True
        }
        If ($HealthCheck.Description -eq 'Start Restart SMSAgentHost'){
            $StartExists=$True
        }
    }
}

If ($StartExists -and $StopExists){
    Write-Host "Compliant"
}
Else{
    Write-Host "Non-Compliant"
}