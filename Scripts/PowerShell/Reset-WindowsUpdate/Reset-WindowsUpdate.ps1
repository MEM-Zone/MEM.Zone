<#
.SYNOPSIS
    Resets the windows update component.
.DESCRIPTION
    Detects and resets a corrupted windows update component.
    Detection is done by testing the eventlog with the specified parameters.
    Reset is performed by resetting the windows update component to its initial state.
    The specified eventlog is backed up and cleared in order not to trigger the detection again before the reset step.
    The backup of the specified eventlog is stored in 'SystemRoot\Temp' folder.
    Defaults are configured for the ESENT '623' error.
.PARAMETER Action
    Specifies the action to be performed. Available actions are: ('DetectAndReset', 'Detect', 'Reset','ResetStandalone').
    'DetectAndReset'  - Performs detection and then performs a reset if necessary.
    'Detect'          - Performs detection and returns the result.
    'Reset'           - Performs a reset and flushes the specified EventLog.
    'ResetStandalone' - Performs a reset only.
.PARAMETER LogName
    Specifies the LogName to search. Default is: 'Application'
.PARAMETER Source
    Specifies the Source to search. Default is: 'ESENT'
.PARAMETER EventID
    Specifies the EventID to search. Default is: '623'
.PARAMETER EntryType
    Specifies the Entry Type to search. Available options are: ('Information','Warning','Error'). Default is: 'Error'.
.PARAMETER LimitDays
    Specifies the number of days from the current date to limit the search to. Default is: 3.
.PARAMETER Threshold
    Specified the numbers of events after which this functions returns $true. Default is: 3.
.EXAMPLE
    Reset-WindowsUpdate.ps1 -Action 'Detect' -LogName 'Application' -Source 'ESENT' -EventID '623' -EntryType 'Error' -LimitDays 3 -Threshold 3
.INPUTS
    None.
.OUTPUTS
    System.String. This script returns Compliant, Non-Compliant, Reset or Error Message
.NOTES
    Created by Ioan Popovici
    This script can be called directly.
.LINK
    https://MEMZ.one/Reset-WindowsUpdate
.LINK
    https://MEMZ.one/Reset-WindowsUpdate-CHANGELOG
.LINK
    https://MEMZ.one/Reset-WindowsUpdate-GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    Windows Update
.FUNCTIONALITY
    Reset Windows Update component
#>

## Set script requirements
#Requires -Version 2.0

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

## Get script parameters
Param (
    [Parameter(Mandatory=$true,Position=0)]
    [ValidateNotNullorEmpty()]
    [ValidateSet("DetectAndReset","Detect","Reset","ResetStandalone")]
    [string]$Action,
    [Parameter(Mandatory=$false,Position=1)]
    [ValidateNotNullorEmpty()]
    [string]$LogName = "Application",
    [Parameter(Mandatory=$false,Position=2)]
    [ValidateNotNullorEmpty()]
    [string]$Source = "ESENT",
    [Parameter(Mandatory=$false,Position=3)]
    [ValidateNotNullorEmpty()]
    [string]$EventID = "623",
    [Parameter(Mandatory=$false,Position=4)]
    [ValidateNotNullorEmpty()]
    [string]$EntryType = "Error",
    [Parameter(Mandatory=$false,Position=5)]
    [ValidateNotNullorEmpty()]
    [int]$LimitDays = 3,
    [Parameter(Mandatory=$false,Position=6)]
    [ValidateNotNullorEmpty()]
    [int]$Threshold = 3
)

#endregion
##*=============================================
##* END VARIABLE DECLARATION
##*=============================================

##*=============================================
##* FUNCTION LISTINGS
##*=============================================
#region FunctionListings

#region Function Test-EventLogCompliance
Function Test-EventLogCompliance {
<#
.SYNOPSIS
    Tests the EventLog compliance for specific events.
.DESCRIPTION
    Tests the EventLog compliance by getting events and returning a Non-Compliant statement after a specified threshold is reached.
.PARAMETER LogName
    Specifies the LogName to search.
.PARAMETER Source
    Specifies the Source to search.
.PARAMETER EventID
    Specifies the EventID to search.
.PARAMETER EntryType
    Specifies the Entry Type to search. Available options are: ('Information','Warning','Error'). Default is: 'Error'.
.PARAMETER LimitDays
    Specifies the number of days from the current date to limit the search to.
    Default is: 1.
.PARAMETER Threshold
    Specifed the numbers of events after which this functions returns $true.
.EXAMPLE
    Test-EventLogCompliance -LogName 'Application' -Source 'ESENT' -EventID '623' -EntryType 'Error' -LimitDays 3 -Threshold 3
.INPUTS
    None.
.OUTPUTS
    System.Boolean.
.NOTES
    This function can typically be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.COMPONENT
    WindowsUpdate
.FUNCTIONALITY
    Test
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true,Position=0)]
        [ValidateNotNullorEmpty()]
        [string]$LogName,
        [Parameter(Mandatory=$true,Position=1)]
        [ValidateNotNullorEmpty()]
        [string]$Source,
        [Parameter(Mandatory=$true,Position=2)]
        [ValidateNotNullorEmpty()]
        [string]$EventID,
        [Parameter(Mandatory=$false,Position=3)]
        [ValidateSet('Information','Warning','Error')]
        [string]$EntryType = 'Error',
        [Parameter(Mandatory=$false,Position=4)]
        [ValidateNotNullorEmpty()]
        [int]$LimitDays = 1,
        [Parameter(Mandatory=$true,Position=5)]
        [ValidateNotNullorEmpty()]
        [int]$Threshold
    )

    Try {

        ## Set day limit by subtracting number of days from the current date
        $After = $((Get-Date).AddDays( - $LimitDays ))

        ## Get events and test threshold
        $Events = Get-EventLog -ComputerName $env:COMPUTERNAME -LogName $LogName -Source $Source -EntryType $EntryType -After $After -ErrorAction 'Stop' | Where-Object { $_.EventID -eq $EventID }

        If ($Events.Count -ge $Threshold) {
            $Compliance = 'Non-Compliant'
        }
        Else {
            $Compliance = 'Compliant'
        }
    }
    Catch {

        ## Set result as 'Compliant' if no matches are found
        If ($($_.Exception.Message) -match 'No matches found') {
            $Compliance =  'Compliant'
        }
        Else {
            $Compliance = "Eventlog [$EventLog] compliance test error. $($_.Exception.Message)"
        }
    }
    Finally {

        ## Return Compliance result
        Write-Output -InputObject $Compliance
    }
}
#endregion

#region Function Backup-EventLog
Function Backup-EventLog {
<#
.SYNOPSIS
    Backs-up an Event Log.
.DESCRIPTION
    Backs-up an Event Log using the BackUpEventLog Cim method.
.PARAMETER LogName
    Specifies the event log to backup.
.PARAMETER BackupPath
    Specifies the Backup Path. Default is: '$env:SystemRoot\Temp'.
.PARAMETER BackupName
    Specifies the Backup name. Default is: 'yyyy-MM-dd_HH-mm-ss_$env:ComputerName_$LogName'.
.EXAMPLE
    Backup-EventLog -LogName 'Application' -BackupPath 'C:\MEMZone' -BackupName '1980-09-09_10-10-00_MEMZoneBlog_Application'
.INPUTS
    System.String.
.OUTPUTS
    None. This function has no outputs.
.NOTES
    This function can typically be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.COMPONENT
    EventLog
.FUNCTIONALITY
    Backup
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true,Position=0)]
        [ValidateNotNullorEmpty()]
        [string]$LogName,
        [Parameter(Mandatory=$false,Position=1)]
        [ValidateNotNullorEmpty()]
        [string]$BackupPath,
        [Parameter(Mandatory=$false,Position=2)]
        [ValidateNotNullorEmpty()]
        [string]$BackupName
    )

    Begin {

        ## Setting variables
        [int]$PowerShellVersion = $PSVersionTable.PSVersion.Major
        [datetime]$Date = $(Get-Date -f 'yyyy-MM-dd_HH-mm-ss')
        #  Setting optional parameters
        If (-not $BackupPath) {
            $BackupPath = $(Join-Path -Path $env:SystemRoot -ChildPath '\Temp')
        }
        If (-not $BackupFileName) {
            [string]$BackUpFileName = "{0}_{1}_{2}.evtx" -f $Date, $env:COMPUTERNAME, $LogName
        }
        #  Setting backup arguments
        [hashtable]$BackupArguments = @{ ArchiveFileName = (Join-Path -Path $BackupPath -ChildPath $BackUpFileName) }
    }
    Process {
        Try {

            If ($PowerShellVersion -eq 2) {

                ## Get event log
                $EventLog = Get-WmiObject -Class 'Win32_NtEventLogFile' -Filter "LogFileName = '$LogName'" -ErrorAction 'SilentlyContinue'

                If (-not $EventLog) { Throw "EventLog [$LogName] not found." }

                ## Backup event log
                $BackUp = $EventLog | Invoke-WmiMethod -Name 'BackupEventLog' -ArgumentList $BackupArguments -ErrorAction 'SilentlyContinue'

                If ($BackUp.ReturnValue -ne 0) { Throw "Backup returned error [$($BackUp.ReturnValue)]." }
            }
            ElseIf ($PowerShellVersion -ge 3) {

                ## Get event log
                $EventLog = Get-CimInstance -ClassName 'Win32_NtEventLogFile' -Filter "LogFileName = '$LogName'" -ErrorAction 'SilentlyContinue'

                If (-not $EventLog) { Throw 'EventLog not found.' }

                ## Backup event log
                $BackUp = $EventLog | Invoke-CimMethod -Name 'BackupEventLog' -Arguments $BackupArguments -ErrorAction 'SilentlyContinue'

                If ($BackUp.ReturnValue -ne 0) { Throw "Backup returned error [$($BackUp.ReturnValue)]." }
            }
            Else {
                Throw "PowerShell version [$PowerShellVersion] not supported."
            }
        }
        Catch {
            Write-Output -InputObject "Backup EventLog [$LogName] error. $_"
        }
    }
    End {
    }
}
#endregion

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
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
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

        ## Start ConfigMgr Client software update scan
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

#endregion
##*=============================================
##* END FUNCTION LISTINGS
##*=============================================

##*=============================================
##* SCRIPT BODY
##*=============================================
#region ScriptBody

Switch ($Action) {
    'DetectAndReset' {

        ## Get machine compliance
        [string]$ESENTError623 = Test-EventLogCompliance -LogName $LogName -Source $Source -EventID $EventID -EntryType $EntryType -LimitDays $LimitDays -Threshold $Threshold

        ## Start processing if compliance test returns 'Non-Compliant'
        If ($ESENTError623 -eq 'Non-Compliant') {

            #  Backup EventLog
            $null = Backup-EventLog -LogName $LogName -ErrorAction 'SilentlyContinue'

            Try {

                #  Clear EventLog
                $null = Clear-EventLog -LogName $LogName -ErrorAction 'Stop'

                #  Reset Windows update component if clear eventlog is successful
                Reset-WindowsUpdate
            }
            Catch {
                Write-Output -InputObject "No reset possible. Clear EventLog [$LogName] error. $($_.Exception.Message)"
            }
        }
        Else {
            Write-Output -InputObject $ESENTError623
        }
    }
    'Detect' {

        ## Get machine compliance and return it
        [string]$ESENTError623 = Test-EventLogCompliance -LogName $LogName -Source $Source -EventID $EventID -EntryType $EntryType -LimitDays $LimitDays -Threshold $Threshold
        Write-Output -InputObject $ESENTError623
    }
    'Reset' {

        ## Backup EventLog
        $null = Backup-EventLog -LogName $LogName -ErrorAction 'SilentlyContinue'

        Try {

            ## Clear EventLog
            $null = Clear-EventLog -LogName $LogName -ErrorAction 'Stop'

            ##  Reset windows update component if clear eventlog is successful
            Reset-WindowsUpdate
        }
        Catch {
            Write-Output -InputObject "No reset possible. Clear EventLog [$LogName] error. $($_.Exception.Message)"
        }
    }
    'ResetStandalone' {

        ##  Reset windows update component
        Reset-WindowsUpdate -ErrorAction 'SilentlyContinue'
    }
}

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================
