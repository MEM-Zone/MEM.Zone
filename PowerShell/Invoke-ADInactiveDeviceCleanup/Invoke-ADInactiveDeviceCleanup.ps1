<#
.SYNOPSIS
    Cleans Active Directory inactive devices.
.DESCRIPTION
    Cleans Active Directory devices that have passed the specified inactive threshold by disabling them and optionally moving them to a specified OU.
.PARAMETER Server
    Specifies the domain or server to query.
.PARAMETER SearchBase
    Specifies the search start location. Default is '$null'.
.PARAMETER Filter
    Specifies the filtering options. Default is 'Enable -eq $true'.
.PARAMETER DaysInactive
    Specifies the inactivity threshold. Default is '365'.
.PARAMETER ListOnly
    Specifies to only list the inactive devices in Active Directory.
.PARAMETER TargetPath
    Specifies to move the disabled devices to a specific Organizational Unit.
.PARAMETER LogPath
    Specifies to save the inactive device list to specified log folder. Default is 'ScriptFolder'.
.PARAMETER HTMLReportConfig
    Specifies the report configuration has a hashtable.
    Default is:
    [hashtable]@{
        ReportName   = 'Report from AD Inactive Device Maintenance'
        ReportHeader = "Devices with an inactivity threshold greater than <b>$DaysInactive</b> days"
        ReportFooter = "Created by: <i><a href = 'https:\\MEM.Zone'>MEM.Zone</a></i> - 2021"
    }
.PARAMETER SendMailConfig
    Specifies the mail configuration as a hashtable.
    Requires: Mailkit and Mailmime (NuGet).
.EXAMPLE
    Invoke-ADInactiveDeviceCleanup.ps1 -Server 'somedomain.com' -SearchBase 'CN=Computers,DC=somedomain,DC=com' -DaysInactive 365 -Destination 'CN=DisabledObjects,DC=somedomain,DC=com'
.EXAMPLE
    [string]$UserName = 'hello@mem.zone'
    [securestring]$Password = 'AppSpecificPassword' | ConvertTo-SecureString -AsPlainText -Force
    [PSCredential]$Credential = New-Object System.Management.Automation.PSCredential ($UserName, $Password)

    [hashtable]$HTMLReportConfig = @{
        ReportName   = 'Report from AD Inactive Device Maintenance'
        ReportHeader = "Devices with an inactivity threshold greater than <b>$DaysInactive</b> days"
        ReportFooter = "For more information write to: <i><a href = 'mailto:servicedesk@company.com'>it-servicedesk@company.com</a></i>"
    }

    [hashtable]$SendMailConfig = @{
        To         = 'ioan@mem.zone'
        From       = 'hello@mem.zone'
        SmtpServer = 'smtp.gmail.com'
        Port       = 587
        Credential = $Credential
    }
    Invoke-ADInactiveDeviceCleanup.ps1 -Server 'somedomain.com' -SearchBase 'CN=Computers,DC=somedomain,DC=com' -DaysInactive 365 -ListOnly -HTMLReportConfig $HTMLReportConfig -SendMailConfig $SendMailConfig
.INPUTS
    None.
.OUTPUTS
    System.IO
    System.String
.NOTES
    Created by Ioan Popovici
.LINK
    https://MEM.Zone/Invoke-ADInactiveDeviceCleanup
.LINK
    https://MEM.Zone/Invoke-ADInactiveDeviceCleanup/CHANGELOG
.LINK
    https://MEM.Zone/Invoke-ADInactiveDeviceCleanup/GIT
.LINK
    https://MEM.Zone/Issues
.COMPONENT
    AD
.FUNCTIONALITY
    Cleans AD Inactive Devices
#>

## Set script requirements
#Requires -Version 7.0

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

## Get script parameters
Param (
    [Parameter(Mandatory=$false,HelpMessage='Specify a valid Domain or Domain Controller.',Position=0)]
    [ValidateNotNullorEmpty()]
    [Alias('ServerName')]
    [string]$Server,
    [Parameter(Mandatory=$false,HelpMessage='Specify a OU Common Name (CN).',Position=1)]
    [ValidateNotNullorEmpty()]
    [Alias('OU')]
    [string]$SearchBase = $null,
    [Parameter(Mandatory=$false,HelpMessage='Specify filtering options.',Position=2)]
    [ValidateNotNullorEmpty()]
    [Alias('FilterOption')]
    [string]$Filter = "Enabled -eq 'true'",
    [Parameter(Mandatory=$false,HelpMessage='Specify the inactivity threshold in days.',Position=3)]
    [ValidateNotNullorEmpty()]
    [Alias('LastActive')]
    [int16]$DaysInactive = 365,
    [Parameter(Mandatory=$false,Position=4)]
    [ValidateNotNullorEmpty()]
    [Alias('List')]
    [switch]$ListOnly,
    [Parameter(Mandatory=$false,HelpMessage='Specify the destination OU (CN) for disabled devices.',Position=5)]
    [ValidateNotNullorEmpty()]
    [Alias('Destination')]
    [string]$TargetPath,
    [Parameter(Mandatory=$false,HelpMessage='Specify the log folder path.',Position=6)]
    [ValidateNotNullorEmpty()]
    [Alias('Log')]
    [string]$LogPath,
    [Parameter(Mandatory=$false,HelpMessage='Specify send html report configuration as a hashtable.',Position=7)]
    [ValidateNotNullorEmpty()]
    [Alias('Report')]
    [hashtable]$HTMLReportConfig = @{
        ReportName   = 'Report from AD Inactive Device Maintenance'
        ReportHeader = "Devices with an inactivity threshold greater than <b>$DaysInactive</b> days"
        ReportFooter = "Created by: <i><a href = 'https:\\MEM.Zone'>MEM.Zone</a></i> - 2021"
    },
    [Parameter(Mandatory=$false,HelpMessage='Specify send mail configuration as a hashtable.',Position=8)]
    [ValidateNotNullorEmpty()]
    [Alias('Mail')]
    [hashtable]$SendMailConfig = $null
)

## Get script path and name
[string]$ScriptName     = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Definition)
[string]$ScriptFullName = [System.IO.Path]::GetFullPath($MyInvocation.MyCommand.Definition)

## Set script global variables
$script:LoggingOptions   = @('Host', 'File', 'EventLog')
$script:LogName          = 'Active Directory Scripts'
$script:LogSource        = $ScriptName
$script:LogDebugMessages = $false
$script:LogFileDirectory = If ($LogPath) { Join-Path -Path $LogPath -ChildPath $script:LogName } Else { $(Join-Path -Path $Env:WinDir -ChildPath $('\Logs\' + $script:LogName)) }

## Get Show-Progress steps
$ProgressSteps = $(([System.Management.Automation.PsParser]::Tokenize($(Get-Content -Path $ScriptFullName), [ref]$null) | Where-Object { $_.Type -eq 'Command' -and $_.Content -eq 'Show-Progress' }).Count)
$ForEachSteps  = $(([System.Management.Automation.PsParser]::Tokenize($(Get-Content -Path $ScriptFullName), [ref]$null) | Where-Object { $_.Type -eq 'Keyword' -and $_.Content -eq 'ForEach' }).Count)
## Set Show-Progress steps
$Script:Steps = $ProgressSteps - $ForEachSteps
$Script:Step  = 0

## Specify new table headers
$NewTableHeaders = [ordered]@{
    'Device Name'       = 'Name'
    'Last Logon (Days)' = 'DaysSinceLastLogon'
    'Last Logon (Date)' = 'LastLogonDate'
    'Path (DN)'         = 'DistinguishedName'
    'Destination (DN)'  = 'TargetPath'
    'Object Enabled'    = 'Enabled'
}

#endregion
##*=============================================
##* END VARIABLE DECLARATION
##*=============================================

##*=============================================
##* FUNCTION LISTINGS
##*=============================================
#region FunctionListings

#region Function Write-Log
Function Write-Log {
<#
.SYNOPSIS
    Write messages to a log file in CMTrace.exe compatible format or Legacy text file format.
.DESCRIPTION
    Write messages to a log file in CMTrace.exe compatible format or Legacy text file format and optionally display in the console.
.PARAMETER Message
    The message to write to the log file or output to the console.
.PARAMETER Severity
    Defines message type. When writing to console or CMTrace.exe log format, it allows highlighting of message type.
    Options: 1 = Information (default), 2 = Warning (highlighted in yellow), 3 = Error (highlighted in red)
.PARAMETER Source
    The source of the message being logged. Also used as the event log source.
.PARAMETER ScriptSection
    The heading for the portion of the script that is being executed. Default is: $script:installPhase.
.PARAMETER LogType
    Choose whether to write a CMTrace.exe compatible log file or a Legacy text log file.
.PARAMETER LoggingOptions
    Choose where to log 'Console', 'File', 'EventLog' or 'None'. You can choose multiple options.
.PARAMETER LogFileDirectory
    Set the directory where the log file will be saved.
.PARAMETER LogFileName
    Set the name of the log file.
.PARAMETER MaxLogFileSizeMB
    Maximum file size limit for log file in megabytes (MB). Default is 10 MB.
.PARAMETER LogName
    Set the name of the event log.
.PARAMETER EventID
    Set the event id for the event log entry.
.PARAMETER WriteHost
    Write the log message to the console.
.PARAMETER ContinueOnError
    Suppress writing log message to console on failure to write message to log file. Default is: $true.
.PARAMETER PassThru
    Return the message that was passed to the function
.PARAMETER VerboseMessage
    Specifies that the message is a debug message. Verbose messages only get logged if -LogDebugMessage is set to $true.
.PARAMETER DebugMessage
    Specifies that the message is a debug message. Debug messages only get logged if -LogDebugMessage is set to $true.
.PARAMETER LogDebugMessage
    Debug messages only get logged if this parameter is set to $true in the config XML file.
.EXAMPLE
    Write-Log -Message "Installing patch MS15-031" -Source 'Add-Patch' -LogType 'CMTrace'
.EXAMPLE
    Write-Log -Message "Script is running on Windows 8" -Source 'Test-ValidOS' -LogType 'Legacy'
.NOTES
    Slightly modified version of the PSADT logging cmdlet. I did not write the original cmdlet, please do not credit me for it.
.LINK
    https://psappdeploytoolkit.com
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [AllowEmptyCollection()]
        [Alias('Text')]
        [string[]]$Message,
        [Parameter(Mandatory = $false, Position = 1)]
        [ValidateRange(1, 3)]
        [int16]$Severity = 1,
        [Parameter(Mandatory = $false, Position = 2)]
        [ValidateNotNullorEmpty()]
        [string]$Source = $script:LogSource,
        [Parameter(Mandatory = $false, Position = 3)]
        [ValidateNotNullorEmpty()]
        [string]$ScriptSection = $script:RunPhase,
        [Parameter(Mandatory = $false, Position = 4)]
        [ValidateSet('CMTrace', 'Legacy')]
        [string]$LogType = 'CMTrace',
        [Parameter(Mandatory = $false, Position = 5)]
        [ValidateSet('Host', 'File', 'EventLog', 'None')]
        [string[]]$LoggingOptions = $script:LoggingOptions,
        [Parameter(Mandatory = $false, Position = 6)]
        [ValidateNotNullorEmpty()]
        [string]$LogFileDirectory = $script:LogFileDirectory,
        [Parameter(Mandatory = $false, Position = 7)]
        [ValidateNotNullorEmpty()]
        [string]$LogFileName = $($script:LogSource + '.log'),
        [Parameter(Mandatory = $false, Position = 8)]
        [ValidateNotNullorEmpty()]
        [int]$MaxLogFileSizeMB = '4',
        [Parameter(Mandatory = $false, Position = 9)]
        [ValidateNotNullorEmpty()]
        [string]$LogName = $script:LogName,
        [Parameter(Mandatory = $false, Position = 10)]
        [ValidateNotNullorEmpty()]
        [int32]$EventID = 1,
        [Parameter(Mandatory = $false, Position = 11)]
        [ValidateNotNullorEmpty()]
        [boolean]$ContinueOnError = $false,
        [Parameter(Mandatory = $false, Position = 12)]
        [switch]$PassThru = $false,
        [Parameter(Mandatory = $false, Position = 13)]
        [switch]$VerboseMessage = $false,
        [Parameter(Mandatory = $false, Position = 14)]
        [switch]$DebugMessage = $false,
        [Parameter(Mandatory = $false, Position = 15)]
        [boolean]$LogDebugMessage = $script:LogDebugMessages
    )

    Begin {
        ## Get the name of this function
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

        ## Logging Variables
        #  Log file date/time
        [string]$LogTime = (Get-Date -Format 'HH:mm:ss.fff').ToString()
        [string]$LogDate = (Get-Date -Format 'MM-dd-yyyy').ToString()
        If (-not (Test-Path -LiteralPath 'variable:LogTimeZoneBias')) { [int32]$script:LogTimeZoneBias = [timezone]::CurrentTimeZone.GetUtcOffset([datetime]::Now).TotalMinutes }
        [string]$LogTimePlusBias = $LogTime + '-' + $script:LogTimeZoneBias
        #  Initialize variables
        [boolean]$WriteHost = $false
        [boolean]$WriteFile = $false
        [boolean]$WriteEvent = $false
        [boolean]$DisableLogging = $false
        [boolean]$ExitLoggingFunction = $false
        If (('Host' -in $LoggingOptions) -and (-not ($VerboseMessage -or $DebugMessage))) { $WriteHost = $true }
        If ('File' -in $LoggingOptions) { $WriteFile = $true }
        If ('EventLog' -in $LoggingOptions) { $WriteEvent = $true }
        If ('None' -in $LoggingOptions) { $DisableLogging = $true }
        #  Check if the script section is defined
        [boolean]$ScriptSectionDefined = [boolean](-not [string]::IsNullOrEmpty($ScriptSection))
        #  Check if the source is defined
        [boolean]$SourceDefined = [boolean](-not [string]::IsNullOrEmpty($Source))
        #  Check if the event log and event source exit
        [boolean]$LogNameNotExists = (-not [System.Diagnostics.EventLog]::Exists($LogName))
        [boolean]$LogSourceNotExists = (-not [System.Diagnostics.EventLog]::SourceExists($Source))

        ## Create script block for generating CMTrace.exe compatible log entry
        [scriptblock]$CMTraceLogString = {
            Param (
                [string]$lMessage,
                [string]$lSource,
                [int16]$lSeverity
            )
            "<![LOG[$lMessage]LOG]!>" + "<time=`"$LogTimePlusBias`" " + "date=`"$LogDate`" " + "component=`"$lSource`" " + "context=`"$([Security.Principal.WindowsIdentity]::GetCurrent().Name)`" " + "type=`"$lSeverity`" " + "thread=`"$PID`" " + "file=`"$Source`">"
        }

        ## Create script block for writing log entry to the console
        [scriptblock]$WriteLogLineToHost = {
            Param (
                [string]$lTextLogLine,
                [int16]$lSeverity
            )
            If ($WriteHost) {
                #  Only output using color options if running in a host which supports colors.
                If ($Host.UI.RawUI.ForegroundColor) {
                    Switch ($lSeverity) {
                        3 { Write-Host -Object $lTextLogLine -ForegroundColor 'Red' -BackgroundColor 'Black' }
                        2 { Write-Host -Object $lTextLogLine -ForegroundColor 'Yellow' -BackgroundColor 'Black' }
                        1 { Write-Host -Object $lTextLogLine }
                    }
                }
                #  If executing "powershell.exe -File <filename>.ps1 > log.txt", then all the Write-Host calls are converted to Write-Output calls so that they are included in the text log.
                Else {
                    Write-Output -InputObject $lTextLogLine
                }
            }
        }

        ## Create script block for writing log entry to the console as verbose or debug message
        [scriptblock]$WriteLogLineToHostAdvanced = {
            Param (
                [string]$lTextLogLine
            )
            #  Only output using color options if running in a host which supports colors.
            If ($Host.UI.RawUI.ForegroundColor) {
                If ($VerboseMessage) {
                    Write-Verbose -Message $lTextLogLine
                }
                Else {
                    Write-Debug -Message $lTextLogLine
                }
            }
            #  If executing "powershell.exe -File <filename>.ps1 > log.txt", then all the Write-Host calls are converted to Write-Output calls so that they are included in the text log.
            Else {
                Write-Output -InputObject $lTextLogLine
            }
        }

        ## Create script block for event writing log entry
        [scriptblock]$WriteToEventLog = {
            If ($WriteEvent) {
                $EventType = Switch ($Severity) {
                    3 { 'Error' }
                    2 { 'Warning' }
                    1 { 'Information' }
                }

                If ($LogNameNotExists -and (-not $LogSourceNotExists)) {
                    Try {
                        #  Delete event source if the log does not exist
                        $null = [System.Diagnostics.EventLog]::DeleteEventSource($Source)
                        $LogSourceNotExists = $true
                    }
                    Catch {
                        [boolean]$ExitLoggingFunction = $true
                        #  If error deleting event source, write message to console
                        If (-not $ContinueOnError) {
                            Write-Host -Object "[$LogDate $LogTime] [${CmdletName}] $ScriptSection :: Failed to create the event log source [$Source]. `n$(Resolve-Error)" -ForegroundColor 'Red'
                        }
                    }
                }
                If ($LogNameNotExists -or $LogSourceNotExists) {
                    Try {
                        #  Create event log
                        $null = New-EventLog -LogName $LogName -Source $Source -ErrorAction 'Stop'
                    }
                    Catch {
                        [boolean]$ExitLoggingFunction = $true
                        #  If error creating event log, write message to console
                        If (-not $ContinueOnError) {
                            Write-Host -Object "[$LogDate $LogTime] [${CmdletName}] $ScriptSection :: Failed to create the event log [$LogName`:$Source]. `n$(Resolve-Error)" -ForegroundColor 'Red'
                        }
                    }
                }
                Try {
                    #  Write to event log
                    Write-EventLog -LogName $LogName -Source $Source -EventId $EventID -EntryType $EventType -Category '0' -Message $EventLogLine -ErrorAction 'Stop'
                }
                Catch {
                    [boolean]$ExitLoggingFunction = $true
                    #  If error creating directory, write message to console
                    If (-not $ContinueOnError) {
                        Write-Host -Object "[$LogDate $LogTime] [${CmdletName}] $ScriptSection :: Failed to write to event log [$LogName`:$Source]. `n$(Resolve-Error)" -ForegroundColor 'Red'
                    }
                }
            }
        }

        ## Exit function if it is a debug message and logging debug messages is not enabled in the config XML file
        If (($DebugMessage -or $VerboseMessage) -and (-not $LogDebugMessage)) { [boolean]$ExitLoggingFunction = $true; Return }
        ## Exit function if logging to file is disabled and logging to console host is disabled
        If (($DisableLogging) -and (-not $WriteHost)) { [boolean]$ExitLoggingFunction = $true; Return }
        ## Exit Begin block if logging is disabled
        If ($DisableLogging) { Return }

        ## Create the directory where the log file will be saved
        If (-not (Test-Path -LiteralPath $LogFileDirectory -PathType 'Container')) {
            Try {
                $null = New-Item -Path $LogFileDirectory -Type 'Directory' -Force -ErrorAction 'Stop'
            }
            Catch {
                [boolean]$ExitLoggingFunction = $true
                #  If error creating directory, write message to console
                If (-not $ContinueOnError) {
                    Write-Host -Object "[$LogDate $LogTime] [${CmdletName}] $ScriptSection :: Failed to create the log directory [$LogFileDirectory]. `n$(Resolve-Error)" -ForegroundColor 'Red'
                }
                Return
            }
        }

        ## Assemble the fully qualified path to the log file
        [string]$LogFilePath = Join-Path -Path $LogFileDirectory -ChildPath $LogFileName
    }
    Process {

        ForEach ($Msg in $Message) {
            ## If the message is not $null or empty, create the log entry for the different logging methods
            [string]$CMTraceMsg = ''
            [string]$ConsoleLogLine = ''
            [string]$EventLogLine = ''
            [string]$LegacyTextLogLine = ''
            If ($Msg) {
                #  Create the CMTrace log message
                If ($ScriptSectionDefined) { [string]$CMTraceMsg = "[$ScriptSection] :: $Msg" }

                #  Create a Console and Legacy "text" log entry
                [string]$LegacyMsg = "[$LogDate $LogTime]"
                If ($ScriptSectionDefined) { [string]$LegacyMsg += " [$ScriptSection]" }
                If ($Source) {
                    [string]$EventLogLine = $Msg
                    [string]$ConsoleLogLine = "$LegacyMsg [$Source] :: $Msg"
                    Switch ($Severity) {
                        3 { [string]$LegacyTextLogLine = "$LegacyMsg [$Source] [Error] :: $Msg" }
                        2 { [string]$LegacyTextLogLine = "$LegacyMsg [$Source] [Warning] :: $Msg" }
                        1 { [string]$LegacyTextLogLine = "$LegacyMsg [$Source] [Info] :: $Msg" }
                    }
                }
                Else {
                    [string]$ConsoleLogLine = "$LegacyMsg :: $Msg"
                    [string]$EventLogLine = $Msg
                    Switch ($Severity) {
                        3 { [string]$LegacyTextLogLine = "$LegacyMsg [Error] :: $Msg" }
                        2 { [string]$LegacyTextLogLine = "$LegacyMsg [Warning] :: $Msg" }
                        1 { [string]$LegacyTextLogLine = "$LegacyMsg [Info] :: $Msg" }
                    }
                }
            }

            ## Execute script block to write the log entry to the console as verbose or debug message
            & $WriteLogLineToHostAdvanced -lTextLogLine $ConsoleLogLine -lSeverity $Severity

            ## Exit function if logging is disabled
            If ($ExitLoggingFunction) { Return }

            ## Execute script block to create the CMTrace.exe compatible log entry
            [string]$CMTraceLogLine = & $CMTraceLogString -lMessage $CMTraceMsg -lSource $Source -lSeverity $lSeverity

            ## Choose which log type to write to file
            If ($LogType -ieq 'CMTrace') {
                [string]$LogLine = $CMTraceLogLine
            }
            Else {
                [string]$LogLine = $LegacyTextLogLine
            }

            ## Write the log entry to the log file and event log if logging is not currently disabled
            If (-not $DisableLogging -and $WriteFile) {
                ## Write to file log
                Try {
                    $LogLine | Out-File -FilePath $LogFilePath -Append -NoClobber -Force -Encoding 'UTF8' -ErrorAction 'Stop'
                }
                Catch {
                    If (-not $ContinueOnError) {
                        Write-Host -Object "[$LogDate $LogTime] [$ScriptSection] [${CmdletName}] :: Failed to write message [$Msg] to the log file [$LogFilePath]. `n$(Resolve-Error)" -ForegroundColor 'Red'
                    }
                }
                ## Write to event log
                Try {
                    & $WriteToEventLog -lMessage $ConsoleLogLine -lName $LogName -lSource $Source -lSeverity $Severity
                }
                Catch {
                    If (-not $ContinueOnError) {
                        Write-Host -Object "[$LogDate $LogTime] [$ScriptSection] [${CmdletName}] :: Failed to write message [$Msg] to the log file [$LogFilePath]. `n$(Resolve-Error)" -ForegroundColor 'Red'
                    }
                }
            }

            ## Execute script block to write the log entry to the console if $WriteHost is $true and $LogLogDebugMessage is not $true
            & $WriteLogLineToHost -lTextLogLine $ConsoleLogLine -lSeverity $Severity
        }
    }
    End {
        ## Archive log file if size is greater than $MaxLogFileSizeMB and $MaxLogFileSizeMB > 0
        Try {
            If ((-not $ExitLoggingFunction) -and (-not $DisableLogging)) {
                [IO.FileInfo]$LogFile = Get-ChildItem -LiteralPath $LogFilePath -ErrorAction 'Stop'
                [decimal]$LogFileSizeMB = $LogFile.Length / 1MB
                If (($LogFileSizeMB -gt $MaxLogFileSizeMB) -and ($MaxLogFileSizeMB -gt 0)) {
                    ## Change the file extension to "lo_"
                    [string]$ArchivedOutLogFile = [IO.Path]::ChangeExtension($LogFilePath, 'lo_')
                    [hashtable]$ArchiveLogParams = @{ ScriptSection = $ScriptSection; Source = ${CmdletName}; Severity = 2; LogFileDirectory = $LogFileDirectory; LogFileName = $LogFileName; LogType = $LogType; MaxLogFileSizeMB = 0; WriteHost = $WriteHost; ContinueOnError = $ContinueOnError; PassThru = $false }

                    ## Log message about archiving the log file
                    $ArchiveLogMessage = "Maximum log file size [$MaxLogFileSizeMB MB] reached. Rename log file to [$ArchivedOutLogFile]."
                    Write-Log -Message $ArchiveLogMessage @ArchiveLogParams -ScriptSection ${CmdletName}

                    ## Archive existing log file from <filename>.log to <filename>.lo_. Overwrites any existing <filename>.lo_ file. This is the same method SCCM uses for log files.
                    Move-Item -LiteralPath $LogFilePath -Destination $ArchivedOutLogFile -Force -ErrorAction 'Stop'

                    ## Start new log file and Log message about archiving the old log file
                    $NewLogMessage = "Previous log file was renamed to [$ArchivedOutLogFile] because maximum log file size of [$MaxLogFileSizeMB MB] was reached."
                    Write-Log -Message $NewLogMessage @ArchiveLogParams -ScriptSection ${CmdletName}
                }
            }
        }
        Catch {
            ## If renaming of file fails, script will continue writing to log file even if size goes over the max file size
        }
        Finally {
            If ($PassThru) { Write-Output -InputObject $Message }
        }
    }
}
#endregion

#region Function Show-Progress
Function Show-Progress {
<#
.SYNOPSIS
    Displays progress info.
.DESCRIPTION
    Displays progress info and maximizes code reuse by automatically calculating the progress steps.
.PARAMETER Actity
    Specifies the progress activity. Default: 'Running Cleanup Please Wait...'.
.PARAMETER Status
    Specifies the progress status.
.PARAMETER CurrentOperation
    Specifies the current operation.
.PARAMETER Step
    Specifies the progress step. Default: $Script:Step ++.
.PARAMETER ID
    Specifies the progress bar id.
.PARAMETER Delay
    Specifies the progress delay in milliseconds. Default: 100.
.PARAMETER Loop
    Specifies if the call comes from a loop.
.EXAMPLE
    Show-Progress -Activity 'Running Install Please Wait' -Status 'Uploading Report' -Step ($Step++) -Delay 200
.EXAMPLE
    Show-Progress -Status "Downloading [$File.Name] --> [$($RSDataSource.Name)]" -Loop
.INPUTS
    None.
.OUTPUTS
    None.
.NOTES
    Created by Ioan Popovici.
    v1.0.0 - 2021-01-01

    This is an private function should tipically not be called directly.
    Credit to Adam Bertram.

    ## !! IMPORTANT !! ##
    #  You need to tokenize the scripts steps at the begining of the script in order for Show-Progress to work:

    ## Get script path and name
    [string]$ScriptPath = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Definition)
    [string]$ScriptName = [System.IO.Path]::GetFileName($MyInvocation.MyCommand.Definition)
    [string]$ScriptFullName = Join-Path -Path $ScriptPath -ChildPath $ScriptName
    #  Get progress steps
    $ProgressSteps = $(([System.Management.Automation.PsParser]::Tokenize($(Get-Content -Path $ScriptFullName), [ref]$null) | Where-Object { $_.Type -eq 'Command' -and $_.Content -eq 'Show-Progress' }).Count)
    $ForEachSteps = $(([System.Management.Automation.PsParser]::Tokenize($(Get-Content -Path $ScriptFullName), [ref]$null) | Where-Object { $_.Type -eq 'Keyword' -and $_.Content -eq 'ForEach' }).Count)
    #  Set progress steps
    $Script:Steps = $ProgressSteps - $ForEachSteps
    $Script:Step = 0
.LINK
    https://adamtheautomator.com/building-progress-bar-powershell-scripts/
.LINK
    https://MEM.Zone/
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    Powershell
.FUNCTIONALITY
    Show Progress
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$false,Position=0)]
        [ValidateNotNullorEmpty()]
        [Alias('act')]
        [string]$Activity = 'Running Cleanup Please Wait...',
        [Parameter(Mandatory=$true,Position=1)]
        [ValidateNotNullorEmpty()]
        [Alias('sta')]
        [string]$Status,
        [Parameter(Mandatory=$false,Position=2)]
        [ValidateNotNullorEmpty()]
        [Alias('cro')]
        [string]$CurrentOperation,
        [Parameter(Mandatory=$false,Position=3)]
        [ValidateNotNullorEmpty()]
        [Alias('pid')]
        [int]$ID = 0,
        [Parameter(Mandatory=$false,Position=4)]
        [ValidateNotNullorEmpty()]
        [Alias('ste')]
        [int]$Step = $Script:Step ++,
        [Parameter(Mandatory=$false,Position=5)]
        [ValidateNotNullorEmpty()]
        [Alias('del')]
        [string]$Delay = 100,
        [Parameter(Mandatory=$false,Position=5)]
        [ValidateNotNullorEmpty()]
        [Alias('lp')]
        [switch]$Loop
    )
    Begin {
        If ($Loop) { $Script:Steps ++ }
        $PercentComplete = $($($Step / $Steps) * 100)
    }
    Process {
        Try {
            ##  Show progress
            Write-Progress -Activity $Activity -Status $Status -CurrentOperation $CurrentOperation -ID $ID -PercentComplete $PercentComplete
            Start-Sleep -Milliseconds $Delay
        }
        Catch {
            Throw (New-Object System.Exception("Could not Show progress status [$Status]! $($_.Exception.Message)", $_.Exception))
        }
    }
}
#endregion

#region  Function Send-MailkitMessage
Function Send-MailkitMessage {
<#
.SYNOPSIS
    Sends an E-Mail to a specified address.
.DESCRIPTION
    Sends an E-Mail to a specified address using Mailkit and Mailmime.
.PARAMETER From
    Specifies the source E-Mail address.
.PARAMETER To
    Specifies the destination E-Mail address.
.PARAMETER CC
    Specifies to include a carbon copy.
.PARAMETER BCC
    Specifies to include a black carbon copy.
.PARAMETER Subject
    Specifies the E-Mail subject.
.PARAMETER Body
    Speicfies the E-Mail body.
.PARAMETER Attachments
    Specifies E-Mail attachments.
.PARAMETER SMTPServer
    Specifies the E-Mail SMTP Server address.
.PARAMETER Port
    Specifies the E-Mail SMTP Port.
.PARAMETER Credential
    Specifies E-Mail account credentials.
.PARAMETER BodyAsHtml
    Specifies to pass the body as HTML.
.EXAMPLE
    [string]$UserName = 'hello@mem.zone'
    [securestring]$Password = 'AppSpecificPassword' | ConvertTo-SecureString -AsPlainText -Force
    [PSCredential]$Credential = New-Object System.Management.Automation.PSCredential ($UserName, $Password)

    [hashtable]$SendMailConfig = @{
        To          = 'ioan@mem.zone'
        From        = 'hello@mem.zone'
        Body        = 'See attached report'
        SmtpServer  = 'smtp.gmail.com'
        Port        = 587
        Credential  = $Credential
        Attachments = "$env:SystemRoot\Runtime.log"
    }
    Send-MailkitMessage @$SendMailConfig
.INPUTS
    None.
.OUTPUTS
    None.
.NOTES
    Created by Adam Listek
    Adapted by Ioan Popovici
.LINK
    https://adamtheautomator.com/powershell-email/#Sending_an_PowerShell_Email_via_MailKit
.LINK
    https://MEM.Zone/
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    Mailkit
.FUNCTIONALITY
    Sends a mail message using Mailkit
#>
    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='Low')]
    Param (
        [Parameter(Mandatory=$true,Position=0)]
        [string]$From,
        [Parameter(Mandatory=$true,Position=1)]
        [string]$To,
        [Parameter(Mandatory=$false,Position=2)]
        [string]$CC,
        [Parameter(Mandatory=$false,Position=3)]
        [string]$BCC,
        [Parameter(Mandatory=$true,Position=4)]
        [string]$Subject,
        [Parameter(Mandatory=$true,Position=5)]
        [string]$Body,
        [Parameter(Mandatory=$false,Position=6)]
        $Attachments = $LogFilePath,
        [Parameter(Mandatory=$true,Position=7)]
        [string]$SmtpServer,
        [Parameter(Mandatory=$false,Position=8)]
        [int32]$Port,
        [Parameter(Mandatory=$false,Position=9)]
        [pscredential]$Credential = $null,
        [Parameter(Mandatory=$false,Position=10)]
        [switch]$BodyAsHtml
    )
    Begin {
        $SMTP    = New-Object 'MailKit.Net.Smtp.SmtpClient'
        $Message = New-Object 'MimeKit.MimeMessage'
    }
    Process {
        Try {

            If ($BodyAsHtml) { $TextPart = [MimeKit.TextPart]::new("html") }
            Else { $TextPart = [MimeKit.TextPart]::new("plain") }

            $TextPart.Text = $Body

            $Message.From.Add($From)
            $Message.To.Add($To)

            If ($CC) { $Message.CC.Add($CC) }
            If ($BCC) { $Message.BCC.Add($BCC) }

            $Message.Subject = $Subject
            $Message.Body    = $TextPart

            If ($Attachment) { $Message.Attachments.Add($Attachments) }

            $SMTP.Connect($SmtpServer, $Port, $False)

            If ($Credential) { $SMTP.Authenticate($Credential.UserName, $Credential.GetNetworkCredential().Password) }

            If ($PSCmdlet.ShouldProcess('Send the mail message via MailKit.')) { $SMTP.Send($Message) }
        }
        Catch {
            Write-Log -Message "Send Mail - Failed!`n$PSItem" -Severity 3
        }
        Finally {
            $SMTP.Disconnect($true)
        }
    }
    End {
        $SMTP.Dispose()
    }
}
#endregion

#region  Set-HtmlTableAlternatingRow
Function Set-HtmlTableAlternatingRow {
<#
.SYNOPSIS
    Sets an alternating css class for a each row in a specified html array object.
.DESCRIPTION
    Sets an alternating css class for a each row in a specified html array object by alternatively replacing two css classes for each new row.
    The object must be piped (IEnumerable) or a for-each must be used.
.PARAMETER Line
    Specifies the Line to parse. Supports pipeline input.
.PARAMETER CSSEvenClass
    Specifies the css class name to be used for 'even' replacement.
.PARAMETER CSSOddClass
    Specifies the css class name to be used for 'odd' replacements.
.EXAMPLE
    HTMLArrayObject | Set-HtmlTableAlternatingRow -CSSEvenClass 'Even' -CSSOddClass 'Odd'
.INPUTS
    System.Object
.OUTPUTS
    System.Object
.NOTES
    Created by Rob Sheppard
    Addapted by Ioan Popovici
.LINK
    https://github.com/MEM-Zone/MEM.Zone/issues/3
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/Issues
.COMPONENT
    HTML
.FUNCTIONALITY
    Sets alternating html table row class
#>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [ValidateNotNullorEmpty()]
        [string]$Line,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [string]$CSSEvenClass,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullorEmpty()]
        [string]$CSSOddClass
    )
    Begin {
        [string]$ClassName = $CSSEvenClass
    }
    Process {
        If ($Line.Contains('<tr><td>')) {
            $Line = $Line.Replace('<tr>',"<tr class=""$ClassName"">")
            If ($ClassName -eq $CSSEvenClass) { $ClassName = $CSSOddClass }
            Else { $ClassName = $CSSEvenClass }
        }
        Write-Output -InputObject $Line
    }
}
#endregion

#region Function Format-HTMLReport
Function Format-HTMLReport {
<#
.SYNOPSIS
    Formats a provided object to an HTML report.
.DESCRIPTION
    Formats a provided object to an HTML report, by formating table headers, html head and body.
.PARAMETER ReportContent
    Specifies the report content object to format. Supports pipeline input.
.PARAMETER HTMLHeader
    Specifies the HTML Head. Optional, should not be used if you don't know what you are doing.
.PARAMETER HTMLBody
    Specifies the HTML Body. Optional, should not be used if you don't know what you are doing.
.PARAMETER ReportName
    Specifies the HTML page name header.
.PARAMETER ReportHeader
    Specifies the HTML page header paragraph.
.PARAMETER ReportFooter
    Specifies the HTML pager footer paragraph.
.PARAMETER NewTableHeaders
    Specifies new table headers if desired. Default is: Original object property names are used as table headers.
.EXAMPLE
    [string]$ReportName = 'Report from AD Inactive Device Maintenance'
    [string]$ReportHeader = "Devices with an inactivity threshold greater than <b>$DaysInactive</b> days"
    [string]$ReportFooter = "For more information write to: <i><a href = 'mailto:servicedesk@company.com'>it-servicedesk@company.com</a></i>"
    [hashtable]$NewTableHeaders = [ordered]@{
        'Last Logon (Days)' = DaysSinceLastLogon
        'Last Logon (Date)' = LastLogonDate
        'Path (DN)'         = DistinguishedName
    }
    Format-HTMLReport -ReportName $ReportName -ReportHeader $ReportHeader -ReportFooter $ReportFooter -NewTableHeaders $NewTableHeaders
.INPUTS
    System.Object
.OUTPUTS
    System.String
.NOTES
    Created by Ioan Popovici
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/Issues
.COMPONENT
    HTML
.FUNCTIONALITY
    Formats object to HTML
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true,ParameterSetName='CustomTemplate',Position=1)]
        [ValidateNotNullorEmpty()]
        [Alias('Head')]
        [string]$HTMLHeader,
        [Parameter(Mandatory=$true,ParameterSetName='CustomTemplate',Position=2)]
        [ValidateNotNullorEmpty()]
        [Alias('Body')]
        [string]$HTMLBody,
        [Parameter(Mandatory=$true,ParameterSetName='CustomTemplate',ValueFromPipeline = $true,Position=0)]
        [Parameter(Mandatory=$true,ParameterSetName='DefaultTemplate',ValueFromPipeline = $true,Position=0)]
        [ValidateNotNullorEmpty()]
        [Alias('Input')]
        [object]$ReportContent,
        [Parameter(Mandatory=$true,ParameterSetName='DefaultTemplate',HelpMessage='Specify the report name',Position=1)]
        [ValidateNotNullorEmpty()]
        [Alias('Name')]
        [string]$ReportName,
        [Parameter(Mandatory=$true,ParameterSetName='DefaultTemplate',HelpMessage='Specify the report header',Position=2)]
        [ValidateNotNullorEmpty()]
        [Alias('Header')]
        [string]$ReportHeader,
        [Parameter(Mandatory=$false,ParameterSetName='DefaultTemplate',HelpMessage='Specify the report footer',Position=3)]
        [ValidateNotNullorEmpty()]
        [Alias('Footer')]
        [string]$ReportFooter = $null,
        [Parameter(Mandatory=$false,ParameterSetName='DefaultTemplate',HelpMessage='Specify the new table headers as a hashtable',Position=3)]
        [Alias('NewTH')]
        [System.Collections.Specialized.OrderedDictionary]$NewTableHeaders = $null
    )
    Begin {

        ## Check if we need to use a custom template, else use the default
        If ($($PSCmdlet.ParameterSetName) -eq 'CustomTemplate') {
            [string]$Head = $HTMLHeader
            [string]$Body = $HTMLBody
        }
        Else {

            ## Get current date and time using ISO 8601
            [string]$CurrentDateTime = Get-Date -Format 'yyyy-MM-dd'

            ## Set default head
            [string]$Head = $('
            <style>
                body {
                    background-color: #ffffff;
                    color: #000000;
                    font-family: Arial;
                }

                h1 {
                    color: #0C71C3
                }

                p {
                    font-size: 120%;
                    font-family: Calibri;
                    border-left: 4px solid #1a75ff;
                    padding-left: 5px;
                }

                a {
                    color: blue;
                }

                table {
                    cellpadding: 5px;
                    font-family: "Verdana";
                    font-size: 100%;
                    margin-left: 10px;
                    border: 1px solid DimGray;
                    border-collapse: collapse;
                }

                th {
                    padding: 5px;
                    font-weight: normal;
                    border: 1px solid DimGray;
                    border-collapse: collapse;
                    background-color: #2ECC71;
                    color: #ffffff;
                }

                td {
                    text-align: center;
                    padding-left: 10px;
                    padding-right: 10px;
                    border: 1px solid DimGray;
                    border-collapse: collapse;
                }

                .even {
                    font-family: "Lucida Console", Courier, monospace;
                    font-size: 80%;
                    background-color: white;
                    color: black;
                }

                .odd {
                    font-family: "Lucida Console", Courier, monospace;
                    font-size: 80%;
                    background-color: lightgrey;
                    color: black;
                }


                #success {
                    background-color: #2ECC71;
                    color: #ffffff;
                }

                #failed {
                    background-color: #FF0000;
                    color: #ffffff;
                }
            </style>
            ')

            ## Set default body
            [string]$Body = ("
                <h1>$ReportName</h1>
                <p>Report as of $CurrentDateTime from <b>$Env:ComputerName</b> - $ReportHeader </p>
            ")

            ## Set report footer
            [string]$Footer = ("<p>$ReportFooter</p>")
        }
    }
    Process {
        Try {

            ## Set new table headers if specified
            If (-not [string]::IsNullOrWhiteSpace($NewTableHeaders)) {
                ForEach ($TableHeader in $NewTableHeaders.GetEnumerator()) {
                    $ReportContent | Add-Member -MemberType 'AliasProperty' -Name $TableHeader.Name -Value $TableHeader.Value -ErrorAction 'SilentlyContinue'
                }

                ## Select result properties
                $ReportContent =  $ReportContent | Select-Object -Property $NewTableHeaders.GetEnumerator().Name
            }

            ## Convert result to html and set alternating row background colors
            [object]$HTMLReport = $ReportContent | ConvertTo-Html -Head $Head -Body $Body -PostContent $Footer |
                Set-HtmlTableAlternatingRow -CSSEvenClass 'even' -CSSOddClass 'odd' |
                    Out-String
        }
        Catch {
            $PSCmdlet.ThrowTerminatingError($PSItem)
        }
        Finally {
            Write-Output -InputObject $HTMLReport
        }
    }
    End {
    }
}
#endregion

#region Function Get-ADInactiveDevice
Function Get-ADInactiveDevice {
<#
.SYNOPSIS
    Gets Active Directory inactive devices.
.DESCRIPTION
    Gets Active Directory devices that have passed the specified inactive threshhold. Default is '365'.
.PARAMETER Server
    Specifies the domain or server to query.
.PARAMETER SearchBase
    Specifies the search start location. Default is '$null'.
.PARAMETER Filter
    Specifies the filtering options. Default is 'Enable -eq $true'.
.PARAMETER DaysInactive
    Specifies the inactivity threshold.
.EXAMPLE
    Get-ADInactiveDevice.ps1 -Server 'somedomain.com' -SearchBase 'CN=Computers,DC=somedomain,DC=com' -DaysInactive '365'
.INPUTS
    None.
.OUTPUTS
    System.Object
.NOTES
    Created by Ioan Popovici
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/Issues
.COMPONENT
    AD
.FUNCTIONALITY
    Gets Inactive Devices
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true,HelpMessage='Enter a valid Domain or Domain Controller.',Position=0)]
        [ValidateNotNullorEmpty()]
        [Alias('ServerName')]
        [string]$Server,
        [Parameter(Mandatory=$false,HelpMessage='Specify a OU Common Name (CN).',Position=1)]
        [ValidateNotNullorEmpty()]
        [Alias('OU')]
        [string]$SearchBase = $null,
        [Parameter(Mandatory=$false,HelpMessage='Specify filtering options.',Position=2)]
        [ValidateNotNullorEmpty()]
        [Alias('FilterOption')]
        [string]$Filter = "Enabled -eq 'true'",
        [Parameter(Mandatory=$false,HelpMessage='Specify the inactivity threshold in days.',Position=3)]
        [ValidateNotNullorEmpty()]
        [Alias('Inactive')]
        [int16]$DaysInactive = 365
    )
    Begin {

        ## Print parameters if verbose is enabled
        Write-Verbose -Message $PSBoundParameters.GetEnumerator()

        ## Set variables
        [datetime]$CurrentDateTime = [System.DateTime]::Now
        [datetime]$InactivityThreshold = $CurrentDateTime.AddDays(- $DaysInactive)
        #  Assemble LDAP filter. Single quotes are intentionally escaped
        $Filter = -Join ("lastLogonDate -lt `'$InactivityThreshold`' -and ", $Filter)

        Write-Debug -Message "LDAP Filter: $Filter"
    }
    Process {
        Try {

            ## Get inactive computers
            $InactiveComputers = Get-ADComputer -Server $Server -Property 'Name', 'LastLogonDate' -Filter $Filter -SearchBase $SearchBase | Sort-Object -Property 'LastLogonDate' | Select-Object -Property 'Name', @{Name='DaysSinceLastLogon';Expression={ [int16](New-TimeSpan -Start $_.lastLogonDate -End $CurrentDateTime).Days }}, 'LastLogonDate', 'DistinguishedName', 'Enabled'
        }
        Catch {
            $PSCmdlet.ThrowTerminatingError($PSItem)
        }
        Finally {
            Write-Output -InputObject $InactiveComputers
        }
    }
    End {
    }
}
#endregion

#region Function Invoke-ADInactiveDeviceCleanup
Function Invoke-ADInactiveDeviceCleanup {
<#
.SYNOPSIS
    Cleans Active Directory inactive devices.
.DESCRIPTION
    Cleans Active Directory devices that have passed the specified inactive threshold by disabling them and optionally moving them to a specified OU.
.PARAMETER Server
    Specifies the domain or server to query.
.PARAMETER SearchBase
    Specifies the search start location. Default is '$null'.
.PARAMETER Filter
    Specifies the filtering options. Default is 'Enable -eq $true'.
.PARAMETER DaysInactive
    Specifies the inactivity threshold. Default is '365'.
.PARAMETER ListOnly
    Specifies to only list the inactive devices in Active Directory.
.PARAMETER TargetPath
    Specifies to move the disabled devices to a specific Organizational Unit.
.PARAMETER LogPath
    Specifies to save the inactive device list to specified log folder. Default is 'ScriptFolder'.
.PARAMETER HTMLReportConfig
    Specifies the report configuration has a hashtable.
    Default is:
    [hashtable]@{
        ReportName   = 'Report from AD Inactive Device Maintenance'
        ReportHeader = "Devices with an inactivity threshold greater than <b>$DaysInactive</b> days"
        ReportFooter = "Created by: <i><a href = 'https:\\MEM.Zone'>MEM.Zone</a></i> - 2021"
    }
.PARAMETER SendMailConfig
    Specifies the mail configuration as a hashtable.
    Requires: Mailkit and Mailmime (NuGet).
.EXAMPLE
    Invoke-ADInactiveDeviceCleanup -Server 'somedomain.com' -SearchBase 'CN=Computers,DC=somedomain,DC=com' -DaysInactive 365 -Destination 'CN=DisabledObjects,DC=somedomain,DC=com'
.EXAMPLE
    [string]$UserName = 'hello@mem.zone'
    [securestring]$Password = 'AppSpecificPassword' | ConvertTo-SecureString -AsPlainText -Force
    [PSCredential]$Credential = New-Object System.Management.Automation.PSCredential ($UserName, $Password)

    [hashtable]$HTMLReportConfig = @{
        ReportName   = 'Report from AD Inactive Device Maintenance'
        ReportHeader = "Devices with an inactivity threshold greater than <b>$DaysInactive</b> days"
        ReportFooter = "For more information write to: <i><a href = 'mailto:servicedesk@company.com'>it-servicedesk@company.com</a></i>"
    }

    [hashtable]$SendMailConfig = @{
        To         = 'ioan@mem.zone'
        From       = 'hello@mem.zone'
        SmtpServer = 'smtp.gmail.com'
        Port       = 587
        Credential = $Credential
    }
    Invoke-ADInactiveDeviceCleanup -Server 'somedomain.com' -SearchBase 'CN=Computers,DC=somedomain,DC=com' -DaysInactive 365 -ListOnly -HTMLReportConfig $HTMLReportConfig -SendMailConfig $SendMailConfig
.INPUTS
    None.
.OUTPUTS
    System.IO
    System.String
.NOTES
    Created by Ioan Popovici
.LINK
    https://MEM.Zone/
.LINK
    https://MEM.Zone/Issues
.COMPONENT
    AD
.FUNCTIONALITY
    Cleans AD Inactive Devices
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true,HelpMessage='Specify a valid Domain or Domain Controller.',Position=0)]
        [ValidateNotNullorEmpty()]
        [Alias('ServerName')]
        [string]$Server,
        [Parameter(Mandatory=$false,HelpMessage='Specify a OU Common Name (CN).',Position=1)]
        [ValidateNotNullorEmpty()]
        [Alias('OU')]
        [string]$SearchBase = $null,
        [Parameter(Mandatory=$false,HelpMessage='Specify filtering options.',Position=2)]
        [ValidateNotNullorEmpty()]
        [Alias('FilterOption')]
        [string]$Filter = "Enabled -eq 'true'",
        [Parameter(Mandatory=$false,HelpMessage='Specify the inactivity threshold in days.',Position=3)]
        [ValidateNotNullorEmpty()]
        [Alias('LastActive')]
        [int16]$DaysInactive = 365,
        [Parameter(Mandatory=$false,Position=4)]
        [ValidateNotNullorEmpty()]
        [Alias('List')]
        [switch]$ListOnly,
        [Parameter(Mandatory=$false,HelpMessage='Specify the destination OU (CN) for disabled devices.',Position=5)]
        [ValidateNotNullorEmpty()]
        [Alias('Destination')]
        [string]$TargetPath,
        [Parameter(Mandatory=$false,HelpMessage='Specify the log folder path.',Position=6)]
        [ValidateNotNullorEmpty()]
        [Alias('Log')]
        [string]$LogPath,
        [Parameter(Mandatory=$false,HelpMessage='Specify send html report configuration as a hashtable.',Position=7)]
        [ValidateNotNullorEmpty()]
        [Alias('Report')]
        [hashtable]$HTMLReportConfig = @{
            ReportName   = 'Report from AD Inactive Device Maintenance'
            ReportHeader = "Devices with an inactivity threshold greater than <b>$DaysInactive</b> days"
            ReportFooter = "Created by: <i><a href = 'https:\\MEM.Zone'>MEM.Zone</a></i> - 2021"
        },
        [Parameter(Mandatory=$false,HelpMessage='Specify send mail configuration as a hashtable.',Position=8)]
        [ValidateNotNullorEmpty()]
        [Alias('Mail')]
        [hashtable]$SendMailConfig = $null
    )
    Begin {

        ## Set script variables
        [hashtable]$SendMailConfig = $ScriptConfig.SendMailConfig
        [hashtable]$HTMLReportConfig = $ScriptConfig.HTMLReportConfig

        ## Show Progress
        Show-Progress -Status "Cleaning up inactive AD devices --> [$SearchBase]"
    }
    Process {
        Try {

            ## Get inactive devices
            $InactiveDevices = Get-ADInactiveDevice -Server $Server -SearchBase $SearchBase -Filter $Filter -DaysInactive $DaysInactive

            ## Process inactive devices
            ForEach ($InactiveDevice in $InactiveDevices) {
                $Identity = $InactiveDevice.DistinguishedName

                ## Check if the 'ListOnly' switch was specified
                If ($ListOnly) {

                    ## Add 'TargetPath' and 'Operation' object properties to result
                    Add-Member -InputObject $InactiveDevice -NotePropertyName 'TargetPath' -NotePropertyValue 'N/A'
                    Add-Member -InputObject $InactiveDevice -NotePropertyName 'Operation' -NotePropertyValue 'ListOnly'
                }
                Else {

                    ## Show progress
                    Show-Progress -Status "Disable [$($InactiveDevice.Name)]" -Loop

                    ## Disable inactive device
                    Disable-ADAccount -Server $Server -Identity $Identity -ErrorAction 'SilentlyContinue'
                    #  If operation was succesfull change the property 'Enabled' to false
                    If ($?) { $InactiveDevice.Enabled = $false }

                    ## If a target was specified move device to target OU
                    If (-not [string]::IsNullOrEmpty($TargetPath)) {

                        ## Show progress
                        Show-Progress -Status "Moving [$($InactiveDevice.Name)] --> [$($TargetPath)]" -Loop

                        ## Add 'TargetPath' and 'Operation' object properties to result
                        Add-Member -InputObject $InactiveDevice -NotePropertyName 'TargetPath' -NotePropertyValue $TargetPath
                        Add-Member -InputObject $InactiveDevice -NotePropertyName 'Operation' -NotePropertyValue 'N/A'

                        ## Move object to target OU
                        Move-ADObject -Server $Server -Identity $Identity -TargetPath $TargetPath -ErrorAction 'SilentlyContinue'
                        #  If operation was succesfull change the property 'Operation' to 'Successful' else change it to 'Failed'
                        If ($?) { $InactiveDevice.Operation = 'Successful' } Else { $InactiveDevice.Operation = 'Failed' }
                    }
                }
            }

            ## If we found devices, convert result to CSV, else add custom message to the result
            If ($InactiveDevices) { $InactiveDevicesCSV = "`n$($InactiveDevices | ConvertTo-Csv -NoTypeInformation | Out-String)" }
            Else { $InactiveDevices = "No devices with an inactivity threshold larger than $DaysInactive days found!" }
        }
        Catch {
            $PSCmdlet.ThrowTerminatingError($PSItem)
        }
        Finally {

            ## Write to log
            Write-Log -Message $InactiveDevicesCSV -LogType 'Legacy'

            ## Splatting Format-HTMLReport table headers
            If (-not $InactiveDevices) { $HTMLReportConfig.Add('ReportContent', $InactiveDevices) }
            If ($NewTableHeaders)      { $HTMLReportConfig.Add('NewTableHeaders', $NewTableHeaders) }
            If ($InactiveDevices)      { $HTMLReportConfig.Add('ReportContent', $InactiveDevices) }

            ## Formating html report
            [object]$InactiveDevicesHTML = Format-HTMLReport @HTMLReportConfig

            ## Send mail report if specified
            If ($SendMailConfig) {
                #  Show progress
                Show-Progress -Status 'Sending mail report...' -Delay 1000 -Step $Steps
                #  Set Mail subject
                $SendMailConfig.Add('Subject', $HTMLReportConfig.ReportName)
                #  Set Mail body
                $SendMailConfig.Add('Body', $InactiveDevicesHTML)
                #  Set Mail body as html
                $SendMailConfig.Add('BodyAsHtml', $true)
                #  Send mail using Mailkit and Mailmime
                Send-MailkitMessage @SendMailConfig
            }

            ## Write html report to disk
            [string]$HTMLFileName = -join ($ScriptName, '.html')
            [string]$HTMLFilePath = Join-Path -Path $script:LogFileDirectory -ChildPath $HTMLFileName
            Out-File -InputObject $InactiveDevicesHTML -FilePath $HTMLFilePath -Force

            ## Show progress
            Show-Progress -Status 'Inactive AD cleanup completed!' -Delay 1000 -Step $Steps
        }
    }
    End {
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

## Set custom script parameters
#  Set credentials
[string]$MailUserName = 'endpoint.management@company.com'
[string]$MailPassword = 'zemajaeasdcyasdgiksdfdctmg' ## !!! DO NOT USE PASSWORDS IN SCRIPTS !!! USED FOR TESTING ONLY !!!
[pscredential]$Credential = New-Object 'System.Management.Automation.PSCredential' ($MailUserName, $($MailPassword | ConvertTo-SecureString -AsPlainText -Force))
#  Set configuration
[hashtable]$ScriptConfig = @{
    Server            = 'dommain.company.com'
    SearchBase        = 'OU=Computers,DC=domain,DC=company,DC=com'
    TargetPath        = 'OU=Disabled Computers,DC=domain,DC=company,DC=com'
    DaysInactive      = 365
    Filter            = "Enabled -eq 'true'"
    ListOnly          = $false
    HTMLReportConfig = @{
        ReportName   = 'Report from AD Inactive Device Maintenance'
        ReportHeader = "Devices with an inactivity threshold greater than <b>$DaysInactive</b> days"
        ReportFooter = "For more information write to: <i><a href = 'mailto:servicedesk@company.com'>it-servicedesk@company.com</a></i>"
    }
    SendMailConfig = @{
        To         = 'ioan@mem.zone'
        From       = 'endpoint.management@company.com'
        SmtpServer = 'smtp.gmail.com'
        Port       = 587
        Credential = $Credential
    }
}

## Invoke script with specified parameters
Invoke-ADInactiveDeviceCleanup @ScriptConfig

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================