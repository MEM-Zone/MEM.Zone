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
.EXAMPLE
    Clean-ADInactiveDevice.ps1 -Server 'somedomain.com' -SearchBase 'CN=Computers,DC=somedomain,DC=com' -DaysInactive 365 -Destination 'CN=DisabledObjects,DC=somedomain,DC=com'
.EXAMPLE
    Clean-ADInactiveDevice.ps1 -Server 'somedomain.com' -SearchBase 'CN=Computers,DC=somedomain,DC=com' -DaysInactive 365 -ListOnly
.INPUTS
    None.
.OUTPUTS
    System.IO
    System.String
.NOTES
    Created by Ioan Popovici
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/Issues
.COMPONENT
    AD
.FUNCTIONALITY
    Clean AD Inactive Devices
#>

## Set script requirements
#Requires -Version 3.0

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

## Get script parameters
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
    [Alias('InactiveThreshold')]
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
    [string]$LogPath
)

## Get script path and name
[string]$ScriptPath = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Definition)
[string]$ScriptName = [System.IO.Path]::GetFileName($MyInvocation.MyCommand.Definition)
[string]$ScriptFullName = Join-Path -Path $ScriptPath -ChildPath $ScriptName

## Set script global variables
$script:LoggingOptions = @('Host', 'File', 'EventLog')
$script:LogName = 'Active Directory Scripts'
$script:LogSource = $ScriptName
$script:LogDebugMessages = $false

## Get Show-Progress steps
$ProgressSteps = $(([System.Management.Automation.PsParser]::Tokenize($(Get-Content -Path $ScriptFullName), [ref]$null) | Where-Object { $_.Type -eq 'Command' -and $_.Content -eq 'Show-Progress' }).Count)
$ForEachSteps = $(([System.Management.Automation.PsParser]::Tokenize($(Get-Content -Path $ScriptFullName), [ref]$null) | Where-Object { $_.Type -eq 'Keyword' -and $_.Content -eq 'ForEach' }).Count)
## Set Show-Progress steps
$Script:Steps = $ProgressSteps - $ForEachSteps
$Script:Step = 0

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
        [string]$LogFileDirectory = $(Join-Path -Path $Env:WinDir -ChildPath $('\Logs\' + $script:LogName)),
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
                    Write-EventLog -LogName $LogName -Source $Source -EventId $EventID -EntryType $EventType -Category '0' -Message $ConsoleLogLine -ErrorAction 'Stop'
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
            [string]$LegacyTextLogLine = ''
            If ($Msg) {
                #  Create the CMTrace log message
                If ($ScriptSectionDefined) { [string]$CMTraceMsg = "[$ScriptSection] :: $Msg" }

                #  Create a Console and Legacy "text" log entry
                [string]$LegacyMsg = "[$LogDate $LogTime]"
                If ($ScriptSectionDefined) { [string]$LegacyMsg += " [$ScriptSection]" }
                If ($Source) {
                    [string]$ConsoleLogLine = "$LegacyMsg [$Source] :: $Msg"
                    Switch ($Severity) {
                        3 { [string]$LegacyTextLogLine = "$LegacyMsg [$Source] [Error] :: $Msg" }
                        2 { [string]$LegacyTextLogLine = "$LegacyMsg [$Source] [Warning] :: $Msg" }
                        1 { [string]$LegacyTextLogLine = "$LegacyMsg [$Source] [Info] :: $Msg" }
                    }
                }
                Else {
                    [string]$ConsoleLogLine = "$LegacyMsg :: $Msg"
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
    Specifies the progress delay in milliseconds. Default: 400.
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
    v1.0.0 - 2021.01.01

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
        [string]$Delay = 400,
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
        [string]$Filter = "Enabled eq 'true'",
        [Parameter(Mandatory=$false,HelpMessage='Specify the inactivity threshold in days.',Position=3)]
        [ValidateNotNullorEmpty()]
        [Alias('InactiveThreshold')]
        [int16]$DaysInactive = 365
    )

    Begin {
        [datetime]$CurrentDateTime = [System.DateTime]::Now
        [datetime]$InactiveThreshold = $CurrentDateTime.AddDays(- $DaysInactive)
        $Filter = -Join ('lastLogonDate -lt $InactiveThreshold -and ', $Filter)
    }
    Process {
        Try {

            $InactiveComputers = Get-ADComputer -Server $Server -Property 'Name', 'LastLogonDate' -Filter $Filter -SearchBase $SearchBase | Sort-Object -Property 'LastLogonDate' | Select-Object -Property 'Name', @{ Name='DaysSinceLastLogon';Expression={[int16](New-TimeSpan -Start $_.lastLogonDate -End $CurrentDateTime).Days} }, 'LastLogonDate', 'DistinguishedName', 'Enabled'
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

#endregion
##*=============================================
##* END FUNCTION LISTINGS
##*=============================================

#endregion
##*=============================================
##* END FUNCTION LISTINGS
##*=============================================

##*=============================================
##* SCRIPT BODY
##*=============================================
#region ScriptBody

Try {

    ## Show Progress
    Show-Progress -Status "Cleaning up inactive devices --> [$SearchBase]"

    ## Get inactive devices
    $InactiveDevices = Get-ADInactiveDevice -Server $Server -SearchBase $SearchBase -Filter $Filter -DaysInactive $DaysInactive

    ## Process inactive devices
    ForEach ($InactiveDevice in $InactiveDevices) {
        $Identity = $InactiveDevice.DistinguishedNam

        ## Check if the 'ListOnly' switch was specified
        If ($ListOnly) { Add-Member -InputObject $InactiveDevice -NotePropertyName 'Operation' -NotePropertyValue 'ListOnly' }
        Else {

            ## Show progress
            Show-Progress -Status "Disable [$($InactiveDevice.Name)]" -Loop

            ## Disable inactive device
            Disable-ADAccount -Server $Server -Identity $Identity
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
                Move-ADObject -Server $Server -Identity $Identity -TargetPath $TargetPath
                #  If operation was succesfull change the property 'Operation' to 'Successful' else change it to 'Failed'
                If ($?) { $InactiveDevice.Operation = 'Successful' } Else { $InactiveDevice.Operation = 'Failed' }
            }
        }
    }

    ## Convert result to CSV
    If ($InactiveDevices) { $InactiveDevicesCSV = ConvertTo-Csv -InputObject $InactiveDevices -Delimiter ';' -NoTypeInformation | Out-String }
    Else { $InactiveDevices = "No devices with an inactivity threshold larger than $DaysInactive days found!" }
}
Catch {
    Write-Error -Message $_.Exception
}
Finally {
    Write-Log -Message $InactiveDevicesCSV -LogType 'Legacy'

    ## Show progress
    Show-Progress -Status 'Cleanup Completed!' -Delay 1000 -Step $Steps
}

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================
