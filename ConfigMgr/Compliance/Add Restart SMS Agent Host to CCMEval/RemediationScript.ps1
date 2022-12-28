<#
.SYNOPSIS
Update ccmeval.xml for System Center Configuration Manager Client to include Restart ccmexec (SMS Agent Host) functionality.

.DESCRIPTION
Restart the ccmexec.exe (SMS Agent Host) service as part of the ccmeval cycle.
The modified ccmeval.xml must be in the same folder as this script.

#>

Param(
    $ErrorActionPreference = 'SilentlyContinue'
    )


$CMClientDir = (Get-ItemProperty 'HKLM:\Software\Microsoft\SMS\Client\Configuration\Client Properties').'Local SMS Path'
$XMLFile = $CMClientDir + 'CcmEval.xml'
$NeedtoSave = $false

[xml]$XMLDocument = Get-Content -Path $XMLFile

If (test-path $XMLFile -ErrorAction SilentlyContinue){
    Foreach ($HealthCheck in $XMLDocument.ClientHealth.HealthCheck) {
        Write-Verbose $HealthCheck.Description
        If ($HealthCheck.Description -eq 'Stop Restart SMSAgentHost'){
            $StopExists=$True
        }
        If ($HealthCheck.Description -eq 'Start Restart SMSAgentHost'){
            $StartExists=$True
        }
    }
    
    If (!($StopExists)){
        #Add the Stop Restart SMS Agent Host Functionality
        Write-Verbose "Adding 'Stop Restart SMSAgentHost' Section"
        $NewHealthCheck = $XMLDocument.ClientHealth.AppendChild($XMLDocument.CreateElement("HealthCheck"))
        $NewHealthCheck.SetAttribute("Description","Stop Restart SMSAgentHost")
        $NewHealthCheck.SetAttribute("ID","698ce2b6-e33c-4326-a173-efc99ff1784c")
        $NewHealthCheck.SetAttribute("Type","Services")
        $NewHealthCheck.SetAttribute("DependsOn","8883C683-04C8-4228-BB76-2EDD666BA781")

        $NewApplicability=$NewHealthCheck.AppendChild($XMLDocument.CreateElement("Applicability"))
        $NewApplicability.SetAttribute("Platform","ALL")
        $NewApplicability.SetAttribute("OS","ALL")
        $NewApplicability.SetAttribute("ClientVersion","ALL")

        $NewParameter1=$NewHealthCheck.AppendChild($XMLDocument.CreateElement("PARAM"))
        $NewParameter1.SetAttribute("Order","1")
        $NewParameter1.SetAttribute("Description","Service Check")
        $NewParameter1Value = $NewParameter1.AppendChild($XMLDocument.CreateTextNode("ServiceStatus"))

        $NewParameter2=$NewHealthCheck.AppendChild($XMLDocument.CreateElement("PARAM"))
        $NewParameter2.SetAttribute("Order","2")
        $NewParameter2.SetAttribute("Description","Service Name")
        $NewParameter2Value = $NewParameter2.AppendChild($XMLDocument.CreateTextNode("CcmExec"))

        $NewParameter3=$NewHealthCheck.AppendChild($XMLDocument.CreateElement("PARAM"))
        $NewParameter3.SetAttribute("Order","3")
        $NewParameter3.SetAttribute("Description","Expected Service Status")
        $NewParameter3Value = $NewParameter3.AppendChild($XMLDocument.CreateTextNode("Stopped"))

        $Remediate1=$NewHealthCheck.AppendChild($XmlDocument.CreateElement("Remediate"))

        $NewRemediate1=$Remediate1.AppendChild($XMLDocument.CreateElement("PARAM"))
        $NewRemediate1.SetAttribute("Order","1")
        $NewRemediate1.SetAttribute("Description","Services Remediation")
        $NewRemediate1Value = $NewRemediate1.AppendChild($XMLDocument.CreateTextNode("ServiceStatus"))

        $NewRemediate2=$Remediate1.AppendChild($XMLDocument.CreateElement("PARAM"))
        $NewRemediate2.SetAttribute("Order","2")
        $NewRemediate2.SetAttribute("Description","Service Name")
        $NewRemediate2Value = $NewRemediate2.AppendChild($XMLDocument.CreateTextNode("CcmExec"))

        $NewRemediate3=$Remediate1.AppendChild($XMLDocument.CreateElement("PARAM"))
        $NewRemediate3.SetAttribute("Order","3")
        $NewRemediate3.SetAttribute("Description","Desired Service Status")
        $NewRemediate3Value = $NewRemediate3.AppendChild($XMLDocument.CreateTextNode("Stopped"))

        $NeedtoSave=$true
    }
  
    If (!($StartExists)){
   
        #Add the Stat Restart SMS Agent Host Functionality
        Write-Verbose "Adding 'Start Restart SMSAgentHost' Section"

        $NewHealthCheck = $XMLDocument.ClientHealth.AppendChild($XMLDocument.CreateElement("HealthCheck"))
        $NewHealthCheck.SetAttribute("Description","Start Restart SMSAgentHost")
        $NewHealthCheck.SetAttribute("ID","4fc6a7d2-10c7-4788-b88a-93f739d1baef")
        $NewHealthCheck.SetAttribute("Type","Services")
        $NewHealthCheck.SetAttribute("DependsOn","8883C683-04C8-4228-BB76-2EDD666BA781")

        $NewApplicability=$NewHealthCheck.AppendChild($XMLDocument.CreateElement("Applicability"))
        $NewApplicability.SetAttribute("Platform","ALL")
        $NewApplicability.SetAttribute("OS","ALL")
        $NewApplicability.SetAttribute("ClientVersion","ALL")

        $NewParameter1=$NewHealthCheck.AppendChild($XMLDocument.CreateElement("PARAM"))
        $NewParameter1.SetAttribute("Order","1")
        $NewParameter1.SetAttribute("Description","Service Check")
        $NewParameter1Value = $NewParameter1.AppendChild($XMLDocument.CreateTextNode("ServiceStatus"))

        $NewParameter2=$NewHealthCheck.AppendChild($XMLDocument.CreateElement("PARAM"))
        $NewParameter2.SetAttribute("Order","2")
        $NewParameter2.SetAttribute("Description","Service Name")
        $NewParameter2Value = $NewParameter2.AppendChild($XMLDocument.CreateTextNode("CcmExec"))

        $NewParameter3=$NewHealthCheck.AppendChild($XMLDocument.CreateElement("PARAM"))
        $NewParameter3.SetAttribute("Order","3")
        $NewParameter3.SetAttribute("Description","Expected Service Status")
        $NewParameter3Value = $NewParameter3.AppendChild($XMLDocument.CreateTextNode("ActiveNoPending"))

        $Remediate1=$NewHealthCheck.AppendChild($XmlDocument.CreateElement("Remediate"))

        $NewRemediate1=$Remediate1.AppendChild($XMLDocument.CreateElement("PARAM"))
        $NewRemediate1.SetAttribute("Order","1")
        $NewRemediate1.SetAttribute("Description","Services Remediation")
        $NewRemediate1Value = $NewRemediate1.AppendChild($XMLDocument.CreateTextNode("ServiceStatus"))

        $NewRemediate2=$Remediate1.AppendChild($XMLDocument.CreateElement("PARAM"))
        $NewRemediate2.SetAttribute("Order","2")
        $NewRemediate2.SetAttribute("Description","Service Name")
        $NewRemediate2Value = $NewRemediate2.AppendChild($XMLDocument.CreateTextNode("CcmExec"))

        $NewRemediate3=$Remediate1.AppendChild($XMLDocument.CreateElement("PARAM"))
        $NewRemediate3.SetAttribute("Order","3")
        $NewRemediate3.SetAttribute("Description","Desired Service Status")
        $NewRemediate3Value = $NewRemediate3.AppendChild($XMLDocument.CreateTextNode("Running"))

        $NeedtoSave=$true
    }
}

If ($NeedtoSave){
    Write-Verbose "Saving"
    $XMLDocument.Save($XMLFile)
    Write-Host "Modified"
}
Else{
    Write-Verbose "Nothing To Do"
    write-Host "Compliant"
}