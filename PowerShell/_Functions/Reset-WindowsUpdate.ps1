#region Function Reset-WindowsUpdate
Function Reset-WindowsUpdate {
<#
.SYNOPSIS
    Resets the windows update component.
.DESCRIPTION
    Resets the windows update component to its initial state.
.EXAMPLE
    Reset-WindowsUpdate
.INPUTS
    None.
.OUTPUTS
    System.String. This script returns Compliant, Non-Compliant, Reset or Error Message
.NOTES
    This function can typically be called directly.
.LINK
    https://SCCM.Zone
.LINK
    https://SCCM.Zone/Git
.COMPONENT
    WindowsUpdate
.FUNCTIONALITY
    Repair
#>

    Try {

        ## Variable declaration
        #  Setting Paths
        [string]$PathRegsvr    = (Join-Path -Path $env:SystemRoot -ChildPath '\System32\Regsvr32.exe')
        [string]$PathDataStore = (Join-Path -Path $env:SystemRoot -ChildPath '\SoftwareDistribution\DataStore')
        [string]$PathCatroot2  = (Join-Path -Path $env:SystemRoot -ChildPath '\System32\Catroot2')
        [string]$PathQMGRFiles = (Join-Path -Path $env:AllUsersProfile -ChildPath '\Application Data\Microsoft\Network\Downloader\qmgr*.dat')
        #  Setting dll names
        [string[]]$Dlls = @(
            'atl', 'urlmon', 'mshtml', 'shdocvw', 'browseui', 'jscript', 'vbscript','scrrun', 'msxml3', 'msxml6', 'actxprxy', 'softpub'
            , 'wintrust', 'dssenh', 'rsaenh', 'cryptdlg', 'oleaut32', 'ole32', 'shell32', 'wuapi', 'wuaueng', 'wups', 'wups2', 'qmgr'
        )
        #  Setting security descriptors
        [string]$SecurityDescriptors = 'D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;AU)(A;;CCLCSWRPWPDTLOCRRC;;;PU)'
        #  Setting registry keys
        [string]$UpdateRegistryKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate'
        [string[]]$UpdateRegistryProperties = @('AccountDomainSid', 'PingID', 'SusClientId')

        ## Stop the windows update service
        Stop-Service -Name 'wuauserv', 'BITS', 'cryptsvc' -ErrorAction 'SilentlyContinue'

        ## Wait for the windows update service to stop
        #  Setting Loop index to 12 (one minute)
        [int]$Loop = 1
        While ($StatusWuaService -ne 'Stopped') {

            #  Waiting 10 seconds
            Start-Sleep -Seconds 10

            #  Get windows update service status
            [string]$StatusWuaService =  (Get-Service -Name 'wuauserv').Status

            #  Try to kill process if service has not stopped within 4 minutes
            If ($Loop -eq 24) {

                #  Use powershell legacy
                If ($PowerShellVersion -eq 2) {
                    #  Get update service PID
                    [string]$PID = Get-WmiObject -Class 'Win32_Service' -Filter "Name = 'wuauserv'" | Select-Object -ExpandProperty 'ProcessId' -ErrorAction 'SilentlyContinue'
                    #  Kill process if PID is found
                    If ($PID -and $PID -ne '0') {
                        Start-Process -FilePath 'taskkill.exe' -ArgumentList "/f /pid $PID" -Wait -ErrorAction 'SilentlyContinue'
                    }
                }

                #  Use current powershell
                ElseIf ($PowerShellVersion -ge 3) {
                    #  Get update service PID
                    [string]$PID = Get-CimInstance -ClassName 'Win32_Service' -Filter "Name = 'wuauserv'" | Select-Object -ExpandProperty 'ProcessId' -ErrorAction 'SilentlyContinue'
                    #  Kill process if PID is found
                    If ($PID -and $PID -ne '0') {
                        Stop-Process -ID $PID -Force -ErrorAction 'SilentlyContinue'
                    }
                }
            }

            #  Throw error if service has not stopped within 5 minutes
            If ($Loop -ge 30) {
                Throw 'Failed to stop WuaService within 5 minutes.'
            }

            #  Incrementing loop index
            $Loop++
        }

        ## Remove QMGR Data file
        Remove-Item -Path $PathQMGRFiles -Force -ErrorAction 'Stop' | Out-Null

        ## Remove catalog root folder
        Remove-Item -Path $PathCatroot2 -Recurse -Force -ErrorAction 'Stop' | Out-Null

        ## Remove the Windows update DataStore
        Remove-Item -Path $PathDataStore -Recurse -Force -ErrorAction 'Stop' | Out-Null

        ## Remove WSUS client registry entries
        ForEach ($PropertyName in $UpdateRegistryProperties) {
            Remove-ItemProperty -Path $UpdateRegistryKey -Name $PropertyName -ErrorAction 'SilentlyContinue'
        }

        ## Reset BITS and wuaserv services security descriptors to default
        Start-Process -FilePath 'sc.exe' -ArgumentList "sdset BITS $SecurityDescriptors"
        Start-Process -FilePath 'sc.exe' -ArgumentList "sdset wuauserv $SecurityDescriptors"

        ## Re-registr dlls
        Set-Location -Path $(Join-Path -Path $env:systemroot -ChildPath 'System32')
        ForEach ($Dll in $Dlls) {
            $DllName = $Dll + '.dll'
            Start-Process -FilePath $PathRegsvr -ArgumentList "/s $DllName" -Wait -ErrorAction 'SilentlyContinue'
        }

        ## Clear the BITS queue
        Get-BitsTransfer -AllUsers | Remove-BitsTransfer

        ## Start services
        Start-Service -Name 'wuauserv', 'BITS', 'cryptsvc' -ErrorAction 'SilentlyContinue'

        ## Start MEMCM Client software update scan
        $null = Invoke-CimMethod -Namespace 'Root\ccm' -ClassName 'SMS_CLIENT' -MethodName 'TriggerSchedule' -Arguments @{SScheduleID = '{00000000-0000-0000-0000-000000000108}'} -ErrorAction 'SilentlyContinue'

        ## Set result to 'Reset'
        [string]$RepairWuDatastore = 'Reset'
    }
    Catch {
        [string]$RepairWuDatastore = "Windows Update reset failed [$($_.Exception.Message)]."
    }
    Finally {

        ## Return result
        Write-Output -InputObject $RepairWuDatastore
    }
}
#endregion