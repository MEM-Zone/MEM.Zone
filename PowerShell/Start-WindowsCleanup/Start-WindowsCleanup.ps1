<#
.SYNOPSIS
    Performs a windows cleanup.
.DESCRIPTION
    Performs a windows cleanup by removing volume caches, update backups, update and CCM caches.
.PARAMETER CleanupOptions
    Supported options:
        "comCacheRepair"   # Component Cache Repair
        "comCacheCleanup"  # Component Cache Cleanup
        "volCacheCleanup"  # Volume Cache Cleanup
        "volShadowCleanup" # Volume Shadow Copy Cleanup
        "updCacheCleanup"  # Update Cache Cleanup
        "ccmCacheCleanup"  # CCM Cache Cleanup
        "Recommended"      # Performs some or all of the above mentioned cleanup operations in a specific order depending on the operating system.
        "All"              # Performs all the above mentioned cleanup operations.
    If set to "Recommended", the cleanup will be done with in the recommended order.
    Default is: "Recommended".
.EXAMPLE
    Start-WindowsCleanup.ps1 -CleanupOptions "comCacheRepair", "comCacheCleanup", "updCacheCleanup", "volCacheCleanup", "ccmCacheCleanup"
.EXAMPLE
    Start-WindowsCleanup.ps1 -CleanupOptions "Recommended"
.EXAMPLE
    Start-WindowsCleanup.ps1 -CleanupOptions "All"
.INPUTS
    None.
.OUTPUTS
    None.
.NOTES
    Created by Ioan Popovici
.LINK
    https://MEM.Zone/Start-WindowsCleanup-CREDIT (@mikael_nystrom [Deplyment Bunny] - Original VB Script)
.LINK
    https://MEM.Zone/Start-WindowsCleanup
.LINK
    https://MEM.Zone/Start-WindowsCleanup-CHANGELOG
.LINK
    https://MEM.Zone/Start-WindowsCleanup-GIT
.LINK
    https://MEM.Zone/Issues
.COMPONENT
    Windows Cleanup
.FUNCTIONALITY
    Clean Windows data and caches.
#>

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

## Set script requirements
#Requires -Version 3.0

## Get script parameters
Param (
    [Parameter(Mandatory = $false)]
    [ValidateNotNullorEmpty()]
    [string[]]$CleanupOptions = "Recommended"
)

## Get script path and name
[string]$ScriptName     = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Definition)
[string]$ScriptFullName = [System.IO.Path]::GetFullPath($MyInvocation.MyCommand.Definition)

## Get Show-Progress steps
$ProgressSteps = $(([System.Management.Automation.PsParser]::Tokenize($(Get-Content -Path $ScriptFullName), [ref]$null) | Where-Object { $_.Type -eq 'Command' -and $_.Content -eq 'Show-Progress' }).Count)
$ForEachSteps  = $(([System.Management.Automation.PsParser]::Tokenize($(Get-Content -Path $ScriptFullName), [ref]$null) | Where-Object { $_.Type -eq 'Keyword' -and $_.Content -eq 'ForEach' }).Count)

## Set Show-Progress steps
$Script:Steps = $ProgressSteps - $ForEachSteps
$Script:Step  = 1

## Set script global variables
$script:LoggingOptions   = 'EventLog'
$script:LogName          = 'Endpoint Management'
$script:LogSource        = $ScriptName
$script:LogDebugMessages = $false
$script:LogFileDirectory = If ($LogPath) { Join-Path -Path $LogPath -ChildPath $script:LogName } Else { $(Join-Path -Path $Env:WinDir -ChildPath $('\Logs\' + $script:LogName)) }


## Initialize variables
[string]$StartWindowsCleanup = $null

#endregion
##*=============================================
##* END VARIABLE DECLARATION
##*=============================================

##*=============================================
##* FUNCTION LISTINGS
##*=============================================
#region FunctionListings

#region Function Resolve-Error
Function Resolve-Error {
<#
.SYNOPSIS
    Enumerate error record details.
.DESCRIPTION
    Enumerate an error record, or a collection of error record, properties. By default, the details for the last error will be enumerated.
.PARAMETER ErrorRecord
    The error record to resolve. The default error record is the latest one: $global:Error[0]. This parameter will also accept an array of error records.
.PARAMETER Property
    The list of properties to display from the error record. Use "*" to display all properties.
    Default list of error properties is: Message, FullyQualifiedErrorId, ScriptStackTrace, PositionMessage, InnerException
.PARAMETER GetErrorRecord
    Get error record details as represented by $_.
.PARAMETER GetErrorInvocation
    Get error record invocation information as represented by $_.InvocationInfo.
.PARAMETER GetErrorException
    Get error record exception details as represented by $_.Exception.
.PARAMETER GetErrorInnerException
    Get error record inner exception details as represented by $_.Exception.InnerException. Will retrieve all inner exceptions if there is more than one.
.EXAMPLE
    Resolve-Error
.EXAMPLE
    Resolve-Error -Property *
.EXAMPLE
    Resolve-Error -Property InnerException
.EXAMPLE
    Resolve-Error -GetErrorInvocation:$false
.NOTES
    Unmodified version of the PADT error resolving cmdlet. I did not write the original cmdlet, please do not credit me for it!
.LINK
    https://psappdeploytoolkit.com
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $false, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [AllowEmptyCollection()]
        [array]$ErrorRecord,
        [Parameter(Mandatory = $false, Position = 1)]
        [ValidateNotNullorEmpty()]
        [string[]]$Property = ('Message', 'InnerException', 'FullyQualifiedErrorId', 'ScriptStackTrace', 'PositionMessage'),
        [Parameter(Mandatory = $false, Position = 2)]
        [switch]$GetErrorRecord = $true,
        [Parameter(Mandatory = $false, Position = 3)]
        [switch]$GetErrorInvocation = $true,
        [Parameter(Mandatory = $false, Position = 4)]
        [switch]$GetErrorException = $true,
        [Parameter(Mandatory = $false, Position = 5)]
        [switch]$GetErrorInnerException = $true
    )

    Begin {
        ## If function was called without specifying an error record, then choose the latest error that occurred
        If (-not $ErrorRecord) {
            If ($global:Error.Count -eq 0) {
                #Write-Warning -Message "The `$Error collection is empty"
                Return
            }
            Else {
                [array]$ErrorRecord = $global:Error[0]
            }
        }

        ## Allows selecting and filtering the properties on the error object if they exist
        [scriptblock]$SelectProperty = {
            Param (
                [Parameter(Mandatory = $true)]
                [ValidateNotNullorEmpty()]
                $InputObject,
                [Parameter(Mandatory = $true)]
                [ValidateNotNullorEmpty()]
                [string[]]$Property
            )

            [string[]]$ObjectProperty = $InputObject | Get-Member -MemberType '*Property' | Select-Object -ExpandProperty 'Name'
            ForEach ($Prop in $Property) {
                If ($Prop -eq '*') {
                    [string[]]$PropertySelection = $ObjectProperty
                    Break
                }
                ElseIf ($ObjectProperty -contains $Prop) {
                    [string[]]$PropertySelection += $Prop
                }
            }
            Write-Output -InputObject $PropertySelection
        }

        #  Initialize variables to avoid error if 'Set-StrictMode' is set
        $LogErrorRecordMsg = $null
        $LogErrorInvocationMsg = $null
        $LogErrorExceptionMsg = $null
        $LogErrorMessageTmp = $null
        $LogInnerMessage = $null
    }
    Process {
        If (-not $ErrorRecord) { Return }
        ForEach ($ErrRecord in $ErrorRecord) {
            ## Capture Error Record
            If ($GetErrorRecord) {
                [string[]]$SelectedProperties = & $SelectProperty -InputObject $ErrRecord -Property $Property
                $LogErrorRecordMsg = $ErrRecord | Select-Object -Property $SelectedProperties
            }

            ## Error Invocation Information
            If ($GetErrorInvocation) {
                If ($ErrRecord.InvocationInfo) {
                    [string[]]$SelectedProperties = & $SelectProperty -InputObject $ErrRecord.InvocationInfo -Property $Property
                    $LogErrorInvocationMsg = $ErrRecord.InvocationInfo | Select-Object -Property $SelectedProperties
                }
            }

            ## Capture Error Exception
            If ($GetErrorException) {
                If ($ErrRecord.Exception) {
                    [string[]]$SelectedProperties = & $SelectProperty -InputObject $ErrRecord.Exception -Property $Property
                    $LogErrorExceptionMsg = $ErrRecord.Exception | Select-Object -Property $SelectedProperties
                }
            }

            ## Display properties in the correct order
            If ($Property -eq '*') {
                #  If all properties were chosen for display, then arrange them in the order the error object displays them by default.
                If ($LogErrorRecordMsg) { [array]$LogErrorMessageTmp += $LogErrorRecordMsg }
                If ($LogErrorInvocationMsg) { [array]$LogErrorMessageTmp += $LogErrorInvocationMsg }
                If ($LogErrorExceptionMsg) { [array]$LogErrorMessageTmp += $LogErrorExceptionMsg }
            }
            Else {
                #  Display selected properties in our custom order
                If ($LogErrorExceptionMsg) { [array]$LogErrorMessageTmp += $LogErrorExceptionMsg }
                If ($LogErrorRecordMsg) { [array]$LogErrorMessageTmp += $LogErrorRecordMsg }
                If ($LogErrorInvocationMsg) { [array]$LogErrorMessageTmp += $LogErrorInvocationMsg }
            }

            If ($LogErrorMessageTmp) {
                $LogErrorMessage = 'Error Record:'
                $LogErrorMessage += "`n-------------"
                $LogErrorMsg = $LogErrorMessageTmp | Format-List | Out-String
                $LogErrorMessage += $LogErrorMsg
            }

            ## Capture Error Inner Exception(s)
            If ($GetErrorInnerException) {
                If ($ErrRecord.Exception -and $ErrRecord.Exception.InnerException) {
                    $LogInnerMessage = 'Error Inner Exception(s):'
                    $LogInnerMessage += "`n-------------------------"

                    $ErrorInnerException = $ErrRecord.Exception.InnerException
                    $Count = 0

                    While ($ErrorInnerException) {
                        [string]$InnerExceptionSeperator = '~' * 40

                        [string[]]$SelectedProperties = & $SelectProperty -InputObject $ErrorInnerException -Property $Property
                        $LogErrorInnerExceptionMsg = $ErrorInnerException | Select-Object -Property $SelectedProperties | Format-List | Out-String

                        If ($Count -gt 0) { $LogInnerMessage += $InnerExceptionSeperator }
                        $LogInnerMessage += $LogErrorInnerExceptionMsg

                        $Count++
                        $ErrorInnerException = $ErrorInnerException.InnerException
                    }
                }
            }

            If ($LogErrorMessage) { $Output = $LogErrorMessage }
            If ($LogInnerMessage) { $Output += $LogInnerMessage }

            Write-Output -InputObject $Output

            If (Test-Path -LiteralPath 'variable:Output') { Clear-Variable -Name 'Output' }
            If (Test-Path -LiteralPath 'variable:LogErrorMessage') { Clear-Variable -Name 'LogErrorMessage' }
            If (Test-Path -LiteralPath 'variable:LogInnerMessage') { Clear-Variable -Name 'LogInnerMessage' }
            If (Test-Path -LiteralPath 'variable:LogErrorMessageTmp') { Clear-Variable -Name 'LogErrorMessageTmp' }
        }
    }
    End {
    }
}
#endregion

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
        #  Check for overlapping log names
        [string[]]$OverLappingLogName = Get-EventLog -List | Where-Object -Property 'Log' -Like $($LogName.Substring(0,8) + '*') | Select-Object -ExpandProperty 'Log'
        If (-not [string]::IsNullOrEmpty($ScriptSection)) {
            Write-Warning -Message "Overlapping log names:`n$($OverLappingLogName | Out-String)"
            Write-Warning -Message 'Change the name of your log or use Remove-EventLog to remove the log(s) above!'
        }

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
            If (-not $DisableLogging) {
                If ($WriteFile) {
                    ## Write to file log
                    Try {
                        $LogLine | Out-File -FilePath $LogFilePath -Append -NoClobber -Force -Encoding 'UTF8' -ErrorAction 'Stop'
                    }
                    Catch {
                        If (-not $ContinueOnError) {
                            Write-Host -Object "[$LogDate $LogTime] [$ScriptSection] [${CmdletName}] :: Failed to write message [$Msg] to the log file [$LogFilePath]. `n$(Resolve-Error)" -ForegroundColor 'Red'
                        }
                    }
                }
                If ($WriteEvent) {
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

#region Format-Bytes
<#
.SYNOPSIS
    Formats a number of bytes in the coresponding sizes.
.DESCRIPTION
    Formats a number of bytes bytes in the coresponding sizes depending or the size ('KB','MB','GB','TB','PB').
.PARAMETER Bytes
    Specifies bytes to format.
.EXAMPLE
    Format-Bytes -Bytes 12344567890
.INPUTS
    None.
.OUTPUTS
    None.
.NOTES
    Created by Ioan Popovici.
    v1.0.0 - 2021-09-01

    This is an private function should tipically not be called directly.
    Credit to Anthony Howell.
.LINK
    https://theposhwolf.com/howtos/Format-Bytes/
.LINK
    https://MEM.Zone/
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    Powershell
.FUNCTIONALITY
    Format Bytes
#>
Function Format-Bytes {
    Param (
        [Parameter(ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [float]$Bytes
    )
    Begin{
        $Sizes = 'KB','MB','GB','TB','PB'
    }
    Process {
        # New for loop
        For($Counter = 0; $Counter -lt $Sizes.Count; $Counter++) {
            If ($Bytes -lt "1$($Sizes[$Counter])") {
                If ($Counter -eq 0) { Return "$Bytes B" }
                Else {
                    $Number = $Bytes / "1$($Sizes[$Counter-1])"
                    $Number = '{0:N2}' -f $Number
                    Return "$Number $($Sizes[$Counter-1])"
                }
            }
        }
    }
    End{
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

#region Function Start-WindowsCleanup
Function Start-WindowsCleanup {
<#
.SYNOPSIS
    Performs a windows cleanup.
.DESCRIPTION
    Performs a windows cleanup by removing volume caches, update backups, update and CCM caches.
.PARAMETER CleanupOptions
    Supported options:
        "comCacheRepair"   # Component Cache Repair
        "comCacheCleanup"  # Component Cache Cleanup
        "volCacheCleanup"  # Volume Cache Cleanup
        "volShadowCleanup" # Volume Shadow Copy Cleanup
        "updCacheCleanup"  # Update Cache Cleanup
        "ccmCacheCleanup"  # CCM Cache Cleanup
        "Recommended"      # Performs some or all of the above mentioned cleanup operations in a specific order depending on the operating system.
        "All"              # Performs all the above mentioned cleanup operations.
    If set to "Recommended", the cleanup will be done with in the recommended order.
    Default is: "Recommended".
.EXAMPLE
    Start-WindowsCleanup.ps1 -CleanupOptions "comCacheRepair", "comCacheCleanup", "updCacheCleanup", "volCacheCleanup", "ccmCacheCleanup"
.EXAMPLE
    Start-WindowsCleanup.ps1 -CleanupOptions "Recommended"
.EXAMPLE
    Start-WindowsCleanup.ps1 -CleanupOptions "All"
.INPUTS
    None.
.OUTPUTS
    None.
.NOTES
    Created by Ioan Popovici
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $false)]
        [ValidateSet('comCacheRepair','comCacheCleanup','volCacheCleanup','volShadowCleanup','updCacheCleanup','ccmCacheCleanup','Recommended','All')]
        [Alias('Options')]
        [string[]]$CleanupOptions = 'Recommended',
        [switch]$OutputJson
    )

    Begin {
        Try {

            ## Variable  declaration
            [boolean]$SkipCleanup = $false
            [string]$StartWindowsCleanup = $null

            ## Get Machine Operating System
            [string]$RegistryExPattern = '(Windows\ (?:7|8\.1|8|10|Server\ (?:2008\ R2|2012\ R2|2012|2016|2019)))'
            [string]$MachineOS = (Get-WmiObject -Class 'Win32_OperatingSystem' | Select-Object -ExpandProperty 'Caption' | Select-String -AllMatches -Pattern $RegistryExPattern | Select-Object -ExpandProperty 'Matches').Value

            ## Get volume info before cleanup
            $VolumeInfo = Get-Volume | Where-Object { $null -ne $PSItem.DriveLetter -and $PSItem.DriveType -eq 'Fixed' } | Select-Object -Property 'DriveLetter','SizeRemaining','Size'
        }
        Catch {}

        ## Perform different cleanup actions depending on the detected Operating System, the action order is intentional
        Switch ($CleanupOptions) {
            'Recommended' {
                If ($MachineOS) {
                    Switch ($MachineOS) {
                        'Windows 7' {
                            $CleanupOptions = @('volCacheCleanup', 'updCacheCleanup', 'ccmCacheCleanup')
                            Break;
                        }
                        'Windows 8' {
                            $CleanupOptions = @('comCacheRepair', 'comCacheCleanup', 'volCacheCleanup', 'updCacheCleanup', 'ccmCacheCleanup')
                            Break;
                        }
                        'Windows 8.1' {
                            $CleanupOptions = @('comCacheRepair', 'comCacheCleanup', 'volCacheCleanup', 'updCacheCleanup', 'ccmCacheCleanup')
                            Break;
                        }
                        'Windows 10' {
                            $CleanupOptions = @('comCacheRepair', 'volCacheCleanup', 'updCacheCleanup', 'comCacheCleanup', 'volShadowCleanup', 'ccmCacheCleanup')
                            Break;
                        }
                        'Windows 11' {
                            $CleanupOptions = @('comCacheRepair', 'volCacheCleanup', 'updCacheCleanup', 'comCacheCleanup', 'volShadowCleanup', 'ccmCacheCleanup')
                            Break;
                        }
                        'Windows Server 2008 R2' {
                            $CleanupOptions = @('volCacheCleanup', 'updCacheCleanup', 'ccmCacheCleanup')
                            Break;
                        }
                        'Windows Server 2012' {
                            $CleanupOptions = @('comCacheRepair', 'comCacheCleanup', 'updCacheCleanup', 'ccmCacheCleanup')
                            Break;
                        }
                        'Windows Server 2012 R2' {
                            $CleanupOptions = @('comCacheRepair', 'comCacheCleanup', 'updCacheCleanup', 'ccmCacheCleanup')
                            Break;
                        }
                        'Windows Server 2016' {
                            $CleanupOptions = @('updCacheCleanup', 'comCacheCleanup', 'ccmCacheCleanup')
                            Break;
                        }
                        'Windows Server 2019' {
                            $CleanupOptions = @('updCacheCleanup', 'comCacheCleanup', 'ccmCacheCleanup')
                            Break;
                        }
                        Default {
                            $StartWindowsCleanup = 'Unknown Operating System, Skipping Cleanup!'
                            $SkipCleanup = $true
                        }
                    }
                Write-Verbose -Message 'Recommended Cleanup Selected!'
                }
                Else {
                    $StartWindowsCleanup = 'Unknown Operating System, Skipping Cleanup!'
                    $SkipCleanup = $true
                }
            }
            'All' { $CleanupOptions = @('comCacheRepair', 'volCacheCleanup', 'updCacheCleanup', 'comCacheCleanup', 'volShadowCleanup', 'ccmCacheCleanup') }
        }
    }
    Process {
        Try {

            ## Write variables for verbose output
            Write-Verbose -Message "$MachineOS Detected. Starting Cleanup..."
            Write-Verbose -Message "Cleanup Options: $CleanupOptions"

            ## Perform Cleanup Actions if $SkipCleanup is not true
            If (-not $SkipCleanup) {
                ForEach ($CleanupOption in $CleanupOptions) {
                    Switch ($CleanupOption) {
                        'comCacheRepair' {

                            ## Start Component Cache Repair
                            Show-Progress -Status 'Running Component Cache Repair. This Can Take a While...' -Loop
                            Start-Process -FilePath 'DISM.exe' -ArgumentList '/Online /Cleanup-Image /RestoreHealth' -WindowStyle 'Hidden' -Wait
                        }
                        'comCacheCleanup' {

                            ## Start Component Cache Cleanup
                            Show-Progress -Status 'Running Component Cache Cleanup. This Can Take a While...' -Loop
                            Start-Process -FilePath 'DISM.exe' -ArgumentList '/Online /Cleanup-Image /StartComponentCleanup /ResetBase' -WindowStyle 'Hidden' -Wait
                        }
                        'volCacheCleanup' {

                            ## Start Volume Cache Cleanup
                            Show-Progress -Status 'Running Volume Cache Cleanup...'

                            ## Get Volume Caches registry paths
                            [string]$RegistryVolumeCachesRootPath = 'HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches'
                            [string[]]$RegistryVolumeCachesPaths = Get-ChildItem -Path $RegistryVolumeCachesRootPath | Select-Object -ExpandProperty 'Name'

                            ## CleanMgr cleanup settings
                            [string]$RegistrySageSet = '5432'
                            [string]$RegistryName = 'StateFlags' + $RegistrySageSet
                            [string]$RegistryValue = '00000002'
                            [string]$RegistryType = 'DWORD'

                            ## Add registry entries required by CleanMgr
                            ForEach ($RegistryVolumeCachesPath in $RegistryVolumeCachesPaths) {
                                Show-Progress -Activity 'Running Volume Cache Cleanup...' -Status "Adding $RegistryName to $RegistryVolumeCachesPath" -Loop
                                $null = New-ItemProperty -Path Registry::$RegistryVolumeCachesPath -Name $RegistryName -Value $RegistryValue -PropertyType $RegistryType -Force
                            }

                            ## If machine is Windows Server 2008 R2, copy files required by CleanMgr and wait for action to complete
                            If ($MachineOS -eq 'Windows Server 2008 R2') {

                                ## Copy CleanMgr.exe and CleanMgr.exe.mui
                                Show-Progress -Activity 'Running Volume Cache Cleanup...' -Status "Copying CleanMgr.exe from $env:SystemRoot\winsxs\..." -Loop
                                $null = Copy-Item -Path "$env:SystemRoot\winsxs\amd64_microsoft-windows-cleanmgr_31bf3856ad364e35_6.1.7600.16385_none_c9392808773cd7da\cleanmgr.exe" -Destination "$env:SystemRoot\System32\" -Force
                                $null = Copy-Item -Path "$env:SystemRoot\winsxs\amd64_microsoft-windows-cleanmgr.resources_31bf3856ad364e35_6.1.7600.16385_en-us_b9cb6194b257cc63\cleanmgr.exe.mui" -Destination "$env:SystemRoot\System32\en-US\" -Force
                            }

                            ## Start Volume Cache Cleanup
                            Show-Progress -Status 'Running Volume Cache Cleanup. This May Take a While...' -Loop
                            Start-Process -FilePath 'CleanMgr.exe' -ArgumentList "/sagerun:$RegistrySageSet" -WindowStyle 'Hidden' -Wait
                        }
                        'volShadowCleanup' {

                            ## Start Volume Cache Cleanup
                            Show-Progress -Status 'Running Volume Shadow Cleanup...' -Loop
                            Start-Process -FilePath 'vssadmin.exe' -ArgumentList 'Delete Shadows /All /Force' -WindowStyle 'Hidden' -Wait
                        }
                        'updCacheCleanup' {

                            ## Start Update Cache Cleanup
                            Show-Progress -Status 'Running Windows Update Cache Cleanup...' -Loop
                            $null = Stop-Service -Name 'wuauserv' -Force -ErrorAction 'SilentlyContinue'
                            $null = Remove-Item -Path "$env:SystemRoot\SoftwareDistribution\" -Recurse -Force
                            $null = Start-Service -Name 'wuauserv' -ErrorAction 'SilentlyContinue'
                        }
                        'ccmCacheCleanup' {

                            ## Start CCM Cache Cleanup
                            Show-Progress -Status 'Running CCM Cache Cleanup...' -Loop

                            ## Initialize the CCM resource manager com object. New-Object does not respect $ErrorActionPreference = 'SilenlyContinue' hence the Try/Catch.
                            [__comobject]$CCMComObject = Try { New-Object -ComObject 'UIResource.UIResourceMgr' } Catch { $null }

                            ## If the CCM client is installed, run the CCM cache cleanup
                            If ($null -ne $CCMComObject) {

                                ## Get ccm cache path
                                [string]$DiskCachePath = $($CCMComObject.GetCacheInfo()).Location

                                ## Get the CacheElementIDs to delete
                                $CacheItems = $CCMComObject.GetCacheInfo().GetCacheElements()

                                ## Remove CCM cache items
                                ForEach ($CacheItem in $CacheItems) {
                                    Show-Progress -Activity 'Running CCM Cache Cleanup...' -Status "Removing $CacheItem.Location" -Loop
                                    $null = $CCMComObject.GetCacheInfo().DeleteCacheElement([string]$($CacheItem.CacheElementID))
                                }

                                ## Remove orphaned cache items
                                Show-Progress -Activity 'Running CCM Cache Cleanup...' -Status "Removing 'orphaned' CCM cache items" -Loop
                                $null = Remove-Item -Path $(Join-Path -Path $DiskCachePath -ChildPathth '\*') -Recurse -Force
                            }
                            Else { Write-Warning -Message 'CCM Client is not installed! Skipping CCM Cache Cleanup...' }
                        }
                        Default { $WindowsCleanup = "$CleanupOption is Not a Valid Cleanup Option!"; Break }
                    }
                }

                ## Calculate the total freed up space and add it to the $VolumeInfo object
                ForEach ($Volume in $VolumeInfo) {
                    $CleanedSpace = $Volume.SizeRemaining - (Get-Volume -DriveLetter $Volume.DriveLetter).SizeRemaining | Format-Bytes
                    $Volume | Add-Member -MemberType 'NoteProperty' -Name 'Reclaimed' -Value $CleanedSpace -ErrorAction 'SilentlyContinue'
                }

                ## Format output
                $WindowsCleanup = $VolumeInfo | Select-Object -Property 'DriveLetter',
                    @{ Name = 'Size'     ; Expression = {Format-Bytes -Bytes $PSItem.Size} },
                    @{ Name = 'Remaining'; Expression = {Format-Bytes -Bytes $PSItem.SizeRemaining} },
                    Reclaimed

                ## Write to event log
                [string]$EventLogEntry = "Cleanup Completed for $env:COMPUTERNAME ($MachineOS)!`n$($WindowsCleanup | Out-String)"
                Write-Log -Message $EventLogEntry
            }
        }
        Catch {
            $WindowsCleanup = "Cleanup for $env:COMPUTERNAME ($MachineOS)! Error: $($_.Exception.Message)"
            Write-Log -Message $WindowsCleanup -EventID 2 -Severity 3
        }
        Finally {
            Write-Output -InputObject $WindowsCleanup
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

Try {
   $WindowsCleanup = Start-WindowsCleanup -CleanupOptions $CleanupOptions
}
Catch {
   $WindowsCleanup = "Cleanup for $env:COMPUTERNAME ($MachineOS)! Error: $($_.Exception.Message)"
}
Finally {
   Write-Output -InputObject $WindowsCleanup
}

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================