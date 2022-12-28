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
    Backup-EventLog -LogName 'Application' -BackupPath 'C:\SCCMZone' -BackupName '1980-09-09_10-10-00_SCCMZoneBlog_Application'
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

                If ($BackUp.ReturnValue -ne 0) { Throw "Backup retuned error [$($BackUp.ReturnValue)]." }
            }
            ElseIf ($PowerShellVersion -ge 3) {

                ## Get event log
                $EventLog = Get-CimInstance -ClassName 'Win32_NtEventLogFile' -Filter "LogFileName = '$LogName'" -ErrorAction 'SilentlyContinue'

                If (-not $EventLog) { Throw 'EventLog not found.' }

                ## Backup event log
                $BackUp = $EventLog | Invoke-CimMethod -Name 'BackupEventLog' -Arguments $BackupArguments -ErrorAction 'SilentlyContinue'

                If ($BackUp.ReturnValue -ne 0) { Throw "Backup retuned error [$($BackUp.ReturnValue)]." }
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