<#
.SYNOPSIS
 Detection Logic for the existance of 'Restart CCMExec.exe' in ccmeval.xml for System Center Configuration Manager Client.

.DESCRIPTION
 Fetch the location of the CM Client, where ccmeval.xml resides.
 Check if 'Restart CCMExec.exe' values exist

.NOTES
TypeofTest = Testing to see if the 'Restart CCMExec.exe' values should or should NOT exist depending upon the CI purpose. Use "ShouldExist" if they should exist, but do not exist.

#>

Param(
    $ErrorActionPreference = 'SilentlyContinue',
    $TypeOfTest = 'ShouldExist'
    )

$CMClientDir = (Get-ItemProperty 'HKLM:\Software\Microsoft\SMS\Client\Configuration\Client Properties').'Local SMS Path'
$XMLFile = $CMClientDir + 'CcmEval.xml'
$StartExists = $false
$StopExists = $false

[xml]$XMLDocument = Get-Content -Path $XMLFile

If (Test-Path $XMLFile -ErrorAction SilentlyContinue){
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
    Write-Verbose "Both Additional checks for Restarting CCMExec exist in XML file"
    Write-Host "Compliant"
}
Else{
    Write-Verbose "Additional Checks for restarting CCMexec do not exist in the XML file"
    If ($TypeofTest -eq 'ShouldExist'){
        Write-Host 'Not compliant'
    }
}