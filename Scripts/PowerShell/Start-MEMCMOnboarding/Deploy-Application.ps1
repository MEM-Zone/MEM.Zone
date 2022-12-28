<#
.SYNOPSIS
    This script performs the installation or uninstallation of an application(s).
    # LICENSE #
    PowerShell App Deployment Toolkit - Provides a set of functions to perform common application deployment tasks on Windows.
    Copyright (C) 2017 - Sean Lillis, Dan Cunningham, Muhammad Mashwani, Aman Motazedian.
    This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation, either version 3 of the License, or any later version. This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
    You should have received a copy of the GNU Lesser General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.
.DESCRIPTION
    The script is provided as a template to perform an install or uninstall of an application(s).
    The script either performs an "Install" deployment type or an "Uninstall" deployment type.
    The install deployment type is broken down into 3 main sections/phases: Pre-Install, Install, and Post-Install.
    The script dot-sources the AppDeployToolkitMain.ps1 script which contains the logic and functions required to install or uninstall an application.
.PARAMETER DeploymentType
    The type of deployment to perform. Default is: Install.
.PARAMETER DeployMode
    Specifies whether the installation should be run in Interactive, Silent, or NonInteractive mode. Default is: Interactive. Options: Interactive = Shows dialogs, Silent = No dialogs, NonInteractive = Very silent, i.e. no blocking apps. NonInteractive mode is automatically set if it is detected that the process is not user interactive.
.PARAMETER AllowRebootPassThru
    Allows the 3010 return code (requires restart) to be passed back to the parent process (e.g. SCCM) if detected from an installation. If 3010 is passed back to SCCM, a reboot prompt will be triggered.
.PARAMETER TerminalServerMode
    Changes to "user install mode" and back to "user execute mode" for installing/uninstalling applications for Remote Destkop Session Hosts/Citrix servers.
.PARAMETER DisableLogging
    Disables logging to file for the script. Default is: $false.
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeployMode 'Silent'; Exit $LastExitCode }"
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -AllowRebootPassThru; Exit $LastExitCode }"
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeploymentType 'Uninstall'; Exit $LastExitCode }"
.EXAMPLE
    Deploy-Application.exe -DeploymentType "Install" -DeployMode "Silent"
.NOTES
    Toolkit Exit Code Ranges:
    60000 - 68999: Reserved for built-in exit codes in Deploy-Application.ps1, Deploy-Application.exe, and AppDeployToolkitMain.ps1
    69000 - 69999: Recommended for user customized exit codes in Deploy-Application.ps1
    70000 - 79999: Recommended for user customized exit codes in AppDeployToolkitExtensions.ps1
.LINK
    http://psappdeploytoolkit.com
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $false)]
    [ValidateSet('Install', 'Uninstall', 'Repair')]
    [string]$DeploymentType = 'Install',
    [Parameter(Mandatory = $false)]
    [ValidateSet('Interactive', 'Silent', 'NonInteractive')]
    [string]$DeployMode = 'Interactive',
    [Parameter(Mandatory = $false)]
    [switch]$AllowRebootPassThru = $false,
    [Parameter(Mandatory = $false)]
    [switch]$TerminalServerMode = $false,
    [Parameter(Mandatory = $false)]
    [switch]$DisableLogging = $false
)

Try {
    ## Set the script execution policy for this process
    Try { Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop' } Catch { }

    ##*===============================================
    ##* VARIABLE DECLARATION
    ##*===============================================
    ## Variables: Application
    [string]$appVendor        = ''
    [string]$appName          = ''
    [string]$appVersion       = '1.0.0'
    [string]$appArch          = 'ALL'
    [string]$appLang          = 'EN'
    [string]$appRevision      = '01'
    [string]$appScriptVersion = '1.0.0'
    [string]$appScriptDate    = '08/10/2020'
    [string]$appScriptAuthor  = ''
    ##*===============================================
    ## Variables: Install Titles (Only set here to override defaults set by the toolkit)
    [string]$installName  = ''
    [string]$installTitle = ''

    ##* Do not modify section below
    #region DoNotModify

    ## Variables: Exit Code
    [int32]$mainExitCode = 0

    ## Variables: Script
    [string]$deployAppScriptFriendlyName  = 'Deploy Application'
    [version]$deployAppScriptVersion      = [version]'3.8.2'
    [string]$deployAppScriptDate          = '08/05/2020'
    [hashtable]$deployAppScriptParameters = $psBoundParameters

    ## Variables: Environment
    If (Test-Path -LiteralPath 'variable:HostInvocation') { $InvocationInfo = $HostInvocation } Else { $InvocationInfo = $MyInvocation }
    [string]$scriptDirectory = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent

    ## Dot source the required App Deploy Toolkit Functions
    Try {
        [string]$moduleAppDeployToolkitMain = "$scriptDirectory\AppDeployToolkit\AppDeployToolkitMain.ps1"
        If (-not (Test-Path -LiteralPath $moduleAppDeployToolkitMain -PathType 'Leaf')) { Throw "Module does not exist at the specified location [$moduleAppDeployToolkitMain]." }
        If ($DisableLogging) { . $moduleAppDeployToolkitMain -DisableLogging } Else { . $moduleAppDeployToolkitMain }
    }
    Catch {
        If ($mainExitCode -eq 0) { [int32]$mainExitCode = 60008 }
        Write-Error -Message "Module [$moduleAppDeployToolkitMain] failed to load: `n$($_.Exception.Message)`n `n$($_.InvocationInfo.PositionMessage)" -ErrorAction 'Continue'
        ## Exit the script, returning the exit code to SCCM
        If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = $mainExitCode; Exit } Else { Exit $mainExitCode }
    }

    #endregion
    ##* Do not modify section above
    ##*===============================================
    ##* END VARIABLE DECLARATION
    ##*===============================================


    If ($deploymentType -ine 'Uninstall' -and $deploymentType -ine 'Repair') {
        ##*===============================================
        ##* PRE-INSTALLATION
        ##*===============================================
        [string]$installPhase = 'Pre-Installation'

        ## Show Welcome Message, close Internet Explorer if required, allow up to 3 deferrals, verify there is enough disk space to complete the install, and persist the prompt
        Show-InstallationWelcome -CloseApps 'ccmsetup=SCCM Client Setup' -CheckDiskSpace -PersistPrompt

        ## Show Progress Message (with the default message)
        Show-InstallationProgress -StatusMessage 'Onboarding in Progress...'

        ## <Perform Pre-Installation tasks here>

        ## Set variables
        # Set script variables
        [string]$CMManagementPoint = ''
        [string]$CMSiteCode        = ''
        [string]$NamingConvention  = ''
        [string]$Server            = '' ## !! MUST BE PRIMARY DC !!
        [string]$Domain            = ''
        [string]$OUPath            = '' ## CN
        [string]$ExecutePath       =  $(Join-Path -Path $(Split-Path -Path $scriptRoot -Parent) -ChildPath 'Deploy-Application.exe')
        [string]$CertStoreLocation = 'LocalMachine'
        [string]$CertStoreName     = 'My'
        [string]$CMInstallParams   = "/Source:$DirFiles /NoService /UsePKICert /NoCRLCheck CCMHOSTNAME=$CMManagementPoint SMSSITECODE=$CMSiteCode CCMFIRSTCERT=1"
        [string]$KMSClientSetupKey = 'NPPR9-FWDCX-D2C8J-H872K-2YT43'
        [string]$KMSOSCheck        = 'Microsoft Windows 10 Enterprise'

        ##  Write variables to log
        Write-Log -Message "Naming Convention [$NamingConvention] `nServer [$Server], `nDomain [$Domain], `nOuPath [$OuPath], `nExecutePath [$ExecutePath], `nCertStoreLocation [$CertStoreLocation], `nCertStoreName [$CertstoreName], `nCMInstallParams [$CMInstallParams]" -Severity 1 -Source ${CmdletName}

        ##  Check if domain onboarded
        [bool]$DomainOnboarded = If ($envMachineADDomain -eq $Domain) { $true } Else { $false }

        ##  Check if MEMCM onboarded
        [bool]$MEMCMOnboarded = If ($(Get-CimInstance -Namespace 'ROOT\ccm' -ClassName 'SMS_Client' -ErrorAction 'SilentlyContinue').ClientVersion) { $true } Else { $false }

        ##*===============================================
        ##* INSTALLATION
        ##*===============================================
        [string]$installPhase = 'Installation'

        ## Handle Zero-Config MSI Installations
        If ($useDefaultMsi) {
            [hashtable]$ExecuteDefaultMSISplat = @{ Action = 'Install'; Path = $defaultMsiFile }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
            Execute-MSI @ExecuteDefaultMSISplat; If ($defaultMspFiles) { $defaultMspFiles | ForEach-Object { Execute-MSI -Action 'Patch' -Path $_ } }
        }

        ## <Perform Installation tasks here>
        Try {
            If (-not $DomainOnboarded) {

                ## Domain Onboarding
                Write-Log -Message 'Starting Domain Onboarding...' -Severity 1 -Source ${CmdletName}
                Show-InstallationProgress -StatusMessage 'Domain Onboarding in Progress...'

                If ($MEMCMOnboarded) {
                    ## Uninstall SCCM Client if present
                    Show-BalloonTip -BalloonTipIcon 'Info' -BalloonTipTitle 'Domain Onboarding' -BalloonTipText 'Uninstalling MEMCM Client'
                    Execute-Process -Path 'CCMSETUP.EXE' -Parameters '/uninstall' -WindowStyle 'Hidden'
                }

                ## Get domain join credentials
                [pscredential]$Credential = $host.ui.PromptForCredential("Need $Domain join credentials", 'Please enter your ADM user name and password.', 'ADM\', 'NetBiosUserName')

                ## Domain onboarding
                Show-BalloonTip -BalloonTipIcon 'Info' -BalloonTipTitle 'Domain Onboarding' -BalloonTipText 'Renaming and Joining Domain...'
                Start-DomainOnboarding -Server $Server -Domain $Domain -OUPath $OUPath -NamingConvention $NamingConvention -Credential $Credential -ErrorAction 'Stop'

                ## Set to resume onboarding after reboot
                Show-BalloonTip -BalloonTipIcon 'Info' -BalloonTipTitle 'Domain Onboarding' -BalloonTipText 'Configuring resume after reboot...'
                Set-ResumeAfterReboot -Unregister
                Set-ResumeAfterReboot -Execute $ExecutePath

                ## Restart computer
                Show-InstallationProgress -StatusMessage 'Restart and Resume...'
                Show-InstallationRestartPrompt -CountdownNoHideSeconds 30
                Exit-Script 0
            }
            ElseIf (-not $MEMCMOnboarded) {

                ## MEMCM Onboarding
                Write-Log -Message 'Starting MEMCM Onboarding...' -Severity 1 -Source ${CmdletName}
                Show-InstallationProgress -StatusMessage 'MEMCM Onboarding in Progress...'

                ## Update group policy to get client certificates and wait for it to complete
                Show-BalloonTip -BalloonTipIcon 'Info' -BalloonTipTitle 'MEMCM Onboarding' -BalloonTipText 'Updating Group Policies...'
                Start-Process gpupdate.exe /force -NoNewWindow

                ## Check for PKI certificate
                [string]$DeviceFQDN = $([System.Net.Dns]::GetHostByName(($env:COMPUTERNAME)).HostName)
                [int]$Counter = 0
                Do {
                    $Certificate = Get-Certificate -Name $DeviceFQDN -StoreLocation $CertStoreLocation -StoreName $CertStoreName -ErrorAction 'SilentlyContinue'
                    $Counter ++
                    Start-Sleep -Seconds 30
                    If ($Counter -gt 10) { Throw 'Could not get the MEMCM Certificate withtin 5 miuntes' }
                }
                While ($Certificate.Count -gt 0)

                ## Instal MEMCM Client
                Show-BalloonTip -BalloonTipIcon 'Info' -BalloonTipTitle 'MEMCM Onboarding' -BalloonTipText 'Installing MEMCM Client...'
                Execute-Process -FilePath 'CCMSETUP.EXE' -Parameters $CMInstallParams -WaitForMsiExec -PassThru -ErrorAction 'Stop'

                ## Add regkey to stop Auto-Update
                Write-Log -Message 'Disable Auto Update' -Source 'Disable-AutoUpdate'
                New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' -Name 'NoAutoUpdate' -Value '1' -PropertyType DWORD –Force

                ## Trigger policy and HWI Update
                Write-Log -Message 'Trigger Machine Policy Update' -Source 'Trigger Policy Update'
                Invoke-CimMethod -Namespace 'root\ccm' -ClassName 'SMS_CLIENT' -MethodName 'TriggerSchedule' -Arguments @{SScheduleID = '{00000000-0000-0000-0000-000000000022}'} # Machine Policy
                Start-Sleep -Seconds 15
                Write-Log -Message 'Trigger Hardware Inventory' -Source 'Trigger Hardware Inventory'
                Invoke-CimMethod -Namespace 'root\ccm' -ClassName 'SMS_CLIENT' -MethodName 'TriggerSchedule' -Arguments @{SScheduleID = '{00000000-0000-0000-0000-000000000001}'} # HWI
            }
        }
        Catch {
            Show-InstallationPrompt -Message "Onboarding failed, please contact service desk! `n`nError Record: `n`n$($_.Exception.Message)" -ButtonMiddleText 'Exit' -Icon 'Error' -MinimizeWindows $true
            Exit-Script 1
        }

        ##*===============================================
        ##* POST-INSTALLATION
        ##*===============================================
        [string]$installPhase = 'Post-Installation'

        ## <Perform Post-Installation tasks here>

        ## Remove existing task if present
        Set-ResumeAfterReboot -Unregister

        ## Set KMS Client Setup Key
        Write-Log -Message 'Starting KMS Client Setup Key Configuration...' -Severity 1 -Source ${CmdletName}
        Show-InstallationProgress -StatusMessage 'KMS Client Setup Key Configuration...'
        Set-KMSClientSetupKey -Key $KMSClientSetupKey -OSName $KMSOSCheck -Activate -ErrorAction 'Stop'

        ## Display a message at the end of the install
        If (-not $useDefaultMsi) { Show-InstallationPrompt -Message 'Onboarding Successful!' -ButtonRightText 'OK' -Icon Information -NoWait }
    }
    ElseIf ($deploymentType -ieq 'Uninstall') {
        ##*===============================================
        ##* PRE-UNINSTALLATION
        ##*===============================================
        [string]$installPhase = 'Pre-Uninstallation'

        ## Show Welcome Message, close Internet Explorer with a 60 second countdown before automatically closing
        Show-InstallationWelcome -CloseApps 'ccmsetup=SCCM Client Setup' -CloseAppsCountdown 60

        ## Show Progress Message (with the default message)
        Show-InstallationProgress

        ## <Perform Pre-Uninstallation tasks here>

        ##*===============================================
        ##* UNINSTALLATION
        ##*===============================================
        [string]$installPhase = 'Uninstallation'

        ## Handle Zero-Config MSI Uninstallations
        If ($useDefaultMsi) {
            [hashtable]$ExecuteDefaultMSISplat = @{ Action = 'Uninstall'; Path = $defaultMsiFile }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
            Execute-MSI @ExecuteDefaultMSISplat
        }

        ## <Perform Uninstallation tasks here>

        ## Uninstall SCCM Client
        Show-BalloonTip -BalloonTipText 'Uninstalling MEMCM Client' -BalloonTipTitle 'Uninstall'
        Execute-Process -Path 'CCMSETUP.EXE' -Parameters '/uninstall' -WindowStyle 'Hidden'

        ##*===============================================
        ##* POST-UNINSTALLATION
        ##*===============================================
        [string]$installPhase = 'Post-Uninstallation'

        ## <Perform Post-Uninstallation tasks here>

        ## Display a message at the end of the uninstall
        If (-not $useDefaultMsi) { Show-InstallationPrompt -Message 'Uninstallation Completed!' -ButtonRightText 'OK' -Icon Information -NoWait }
    }
    ElseIf ($deploymentType -ieq 'Repair') {
        ##*===============================================
        ##* PRE-REPAIR
        ##*===============================================
        [string]$installPhase = 'Pre-Repair'

        ## Show Progress Message (with the default message)
        Show-InstallationProgress

        ## <Perform Pre-Repair tasks here>

        ##*===============================================
        ##* REPAIR
        ##*===============================================
        [string]$installPhase = 'Repair'

        ## Handle Zero-Config MSI Repairs
        If ($useDefaultMsi) {
            [hashtable]$ExecuteDefaultMSISplat = @{ Action = 'Repair'; Path = $defaultMsiFile; }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
            Execute-MSI @ExecuteDefaultMSISplat
        }
        # <Perform Repair tasks here>

        ##*===============================================
        ##* POST-REPAIR
        ##*===============================================
        [string]$installPhase = 'Post-Repair'

        ## <Perform Post-Repair tasks here>

    }
    ##*===============================================
    ##* END SCRIPT BODY
    ##*===============================================

    ## Call the Exit-Script function to perform final cleanup operations
    Exit-Script -ExitCode $mainExitCode
}
Catch {
    [int32]$mainExitCode = 60001
    [string]$mainErrorMessage = "$(Resolve-Error)"
    Write-Log -Message $mainErrorMessage -Severity 3 -Source $deployAppScriptFriendlyName
    Show-DialogBox -Text $mainErrorMessage -Icon 'Stop'
    Exit-Script -ExitCode $mainExitCode
}
