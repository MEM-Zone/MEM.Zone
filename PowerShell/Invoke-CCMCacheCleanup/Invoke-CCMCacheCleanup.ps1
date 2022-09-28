<#
.SYNOPSIS
    Cleans the configuration manager client cache.
.DESCRIPTION
    Cleans the configuration manager client cache of all unneeded with the option to delete persisted content.
.PARAMETER CleanupActions
    Specifies cleanup action to perform. ('All', 'Applications', 'Packages', 'Updates', 'Orphaned'). Default is: 'All'.
    If it's set to 'All' all cleaning actions will be performed.
.PARAMETER LowDiskSpaceThreshold
    Specifies the low disk space threshold percentage after which the cache is cleaned. Default is: '100'.
    If it's set to '100' Free Space Threshold Percentage is ignored.
.PARAMETER ReferencedThreshold
    Specifies to remove cache element only if it has not been referenced in specified number of days. Default is: 0.
    If it's set to '0' Last Referenced Time is ignored.
.PARAMETER SkipSuperPeer
    This switch specifies to skip cleaning if the client is a super peer (Peer Cache). Default is: $false.
.PARAMETER RemovePersisted
    This switch specifies to remove content even if it's persisted. Default is: $false.
.PARAMETER LoggingOptions
    Specifies logging options: ('Host', 'File', 'EventLog', 'None'). Default is: ('Host', 'File', 'EventLog').
.PARAMETER LogName
    Specifies log folder name and event log name. Default is: 'Configuration Manager'.
.PARAMETER LogSource
    Specifies log file name and event source name. Default is: 'Clean-CMClientCache'.
.PARAMETER LogDebugMessages
    This switch specifies to log debug messages. Default is: $false.
.EXAMPLE
    Clean-CMClientCache.ps1 -CleanupActions "Applications, Packages, Updates, Orphaned" -LoggingOptions 'Host' -LowDiskSpaceThreshold '100' -ReferencedThreshold '30' -SkipSuperPeer -RemovePersisted -Verbose -Debug
.INPUTS
    System.String.
.OUTPUTS
    System.Management.Automation.PSObject
.NOTES
    Created by Ioan Popovici
.LINK
    https://MEM.Zone/Invoke-CCMCacheCleanup
.LINK
    https://MEM.Zone/Invoke-CCMCacheCleanup-CHANGELOG
.LINK
    https://MEM.Zone/Invoke-CCMCacheCleanup-GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    CM Client
.FUNCTIONALITY
    Clean CM Client Cache
#>

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

## Set script requirements
#Requires -Version 3.0

## Get script parameters
Param (
    [Parameter(Mandatory = $false, Position = 0)]
    [ValidateSet('All', 'Applications', 'Packages', 'Updates', 'Orphaned')]
    [Alias('Action')]
    [string[]]$CleanupActions = 'All',
    [Parameter(Mandatory = $false, Position = 1)]
    [ValidateNotNullorEmpty()]
    [Alias('FreeSpace')]
    [int16]$LowDiskSpaceThreshold = 100,
    [Parameter(Mandatory = $false, Position = 2)]
    [ValidateNotNullorEmpty()]
    [Alias('OlderThan')]
    [int16]$ReferencedThreshold = 0,
    [Parameter(Mandatory = $false, Position = 3)]
    [switch]$SkipSuperPeer = $false,
    [Parameter(Mandatory = $false, Position = 4)]
    [switch]$RemovePersisted = $false,
    [Parameter(Mandatory = $false, Position = 5)]
    [ValidateSet('Host', 'File', 'EventLog', 'None')]
    [Alias('Logging')]
    [string[]]$LoggingOptions = @('Host', 'File', 'EventLog'),
    [Parameter(Mandatory = $false, Position = 6)]
    [string]$LogName = 'Configuration Manager',
    [Parameter(Mandatory = $false, Position = 7)]
    [string]$LogSource = 'Clean-CMClientCache',
    [Parameter(Mandatory = $false, Position = 8)]
    [switch]$LogDebugMessages = $false
)

## Initialize result variable
[psobject]$CleanupResult = @()

## Set script variables
$script:LoggingOptions = $LoggingOptions
$script:LogName = $LogName
$script:LogSource = $LogSource
$script:LogDebugMessages = $LogDebugMessages
$script:ReferencedThreshold = $ReferencedThreshold

#  Initialize ShouldRun with true. It will be checked in the script body
[boolean]$ShouldRun = $true

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

#region Function Get-CCMCachedApplications
Function Get-CCMCachedApplications {
<#
.SYNOPSIS
    Lists all ccm cached applications.
.DESCRIPTION
    Lists all configuration manager client cached applications with custom properties.
.EXAMPLE
    Get-CCMCachedApplications
.INPUTS
    None
.OUTPUTS
    System.Object.
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.COMPONENT
    CM Client Cache
.FUNCTIONALITY
    Get cached applications
#>
    [CmdletBinding()]
    Param ()
    Begin {
        Try {

            ## Get the name of this function and write verbose header
            [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
            #  Write verbose header
            Write-Log -Message 'Start' -VerboseMessage -ScriptSection ${CmdletName}

            ## Initialize the CCM resource manager com object
            [__comobject]$CCMComObject = New-Object -ComObject 'UIResource.UIResourceMgr'

            ## Get ccm cache info
            $CacheInfo = $($CCMComObject.GetCacheInfo().GetCacheElements())

            ## Get ccm application list
            $Applications = Get-CimInstance -Namespace 'Root\ccm\ClientSDK' -ClassName 'CCM_Application' -Verbose:$false

            ## Count the applications
            $ApplicationCount = $($Applications | Measure-Object).Count

            ## Initialize counter
            $ProgressCounter = 0

            ## Initialize result object
            [psobject]$CachedApps = @()
        }
        Catch {
            Write-Log -Message "Initialization failed. `n$(Resolve-Error)" -Severity '3' -ScriptSection ${CmdletName}
            Throw "Initialization failed. `n$($_.Exception.Message)"
        }
    }
    Process {
        Try {

            ## Get cached application info
            ForEach ($Application in $Applications) {

                ## Show the progress
                $ProgressCounter++
                Write-Progress -Activity 'Processing Applications' -CurrentOperation $Application.FullName -PercentComplete (($ProgressCounter / $ApplicationCount) * 100)

                ## Get application deployment types
                $ApplicationDTs = ($Application | Get-CimInstance -Verbose:$false).AppDTs

                ## Get application content ID
                ForEach ($DeploymentType in $ApplicationDTs) {

                    ## Get allowed actions (each action can have a different content id)
                    ForEach ($ActionType in $DeploymentType.AllowedActions) {

                        #  Assemble Invoke-Method arguments
                        $Arguments = [hashtable]@{
                            'AppDeliveryTypeID' = [string]$($DeploymentType.ID)
                            'Revision'          = [uint32]$($DeploymentType.Revision)
                            'ActionType'        = [string]$($ActionType)
                        }
                        #  Get app content ID via GetContentInfo wmi method
                        $AppContentID = (Invoke-CimMethod -Namespace 'Root\ccm\cimodels' -ClassName 'CCM_AppDeliveryType' -MethodName 'GetContentInfo' -Arguments $Arguments -Verbose:$false).ContentID

                        ## Get the cache info for the application using the ContentID
                        $AppCacheInfo = $CacheInfo | Where-Object { $($_.ContentID) -eq $AppContentID }

                        ## Debug info
                        Write-Log -Message "CachedInfo: `n $($AppCacheInfo | Out-String)" -DebugMessage -ScriptSection ${CmdletName}

                        ## Accounting for cache items with multiple CacheElementIDs
                        ForEach ($CacheItem in $AppCacheInfo) {

                            ## If the application is in the cache, assemble properties and add it to the result object
                            If ($CacheItem) {
                                #  Set content size to 0 if null to avoid division by 0
                                If ($($CacheItem.ContentSize) -eq 0) { [int]$AppContentSize = 0 } Else { [int]$AppContentSize = $($CacheItem.ContentSize) }
                                #  Assemble result object props
                                $CachedAppProps = [ordered]@{
                                    Name              = $($Application.Name)
                                    DeploymentType    = $($DeploymentType.Name)
                                    InstallState      = $($Application.InstallState)
                                    ContentID         = $($CacheItem.ContentID)
                                    ContentVersion    = $($CacheItem.ContentVersion)
                                    ReferenceCount    = $($CacheItem.ReferenceCount)
                                    LastReferenceTime = $($CacheItem.LastReferenceTime)
                                    Location          = $($CacheItem.Location)
                                    'Size(MB)'        = '{0:N2}' -f $($AppContentSize / 1KB)
                                    CacheElementID    = $($CacheItem.CacheElementID)
                                }
                                #  Add items to result object
                                $CachedApps += New-Object 'PSObject' -Property $CachedAppProps
                            }
                        }
                    }
                }
            }
        }
        Catch {
            Write-Log -Message "Could not get cached application [$($Application.Name)].  `n$(Resolve-Error)" -Severity '3' -ScriptSection ${CmdletName}
            Throw "Could not get cached application [$($Application.Name)]. `n$($_.Exception.Message)"
        }
        Finally {
            Write-Output -InputObject $CachedApps
        }
    }
    End {

        ## Write verbose footer
        Write-Log -Message 'Stop' -VerboseMessage
    }
}
#endregion

#region Function Get-CCMCachedPackages
Function Get-CCMCachedPackages {
<#
.SYNOPSIS
    Lists all ccm cached packages.
.DESCRIPTION
    Lists all configuration manager client cached packages with custom properties.
.EXAMPLE
    Get-CCMCachedPackages
.INPUTS
    None
.OUTPUTS
    System.Object.
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.COMPONENT
    CM Client Cache
.FUNCTIONALITY
    Get cached packages
#>
    [CmdletBinding()]
    Param ()
    Begin {
        Try {

            ## Get the name of this function and write verbose header
            [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

            #  Write verbose header
            Write-Log -Message 'Start' -VerboseMessage -ScriptSection ${CmdletName}

            ## Initialize the CCM resource manager com object
            [__comobject]$CCMComObject = New-Object -ComObject 'UIResource.UIResourceMgr'

            ## Get ccm cache info
            $CacheInfo = $($CCMComObject.GetCacheInfo().GetCacheElements())

            ## Get ccm package list
            $Packages = Get-CimInstance -Namespace 'Root\ccm\ClientSDK' -ClassName 'CCM_Program' -Verbose:$false

            ## Count the packages
            [int]$PackageCount = $($Packages | Measure-Object).Count

            ## Initialize counter
            [int]$ProgressCounter = 0

            ## Initialize result object
            [psobject]$CachedPkgs = @()
        }
        Catch {
            Write-Log -Message "Initialization failed. `n$(Resolve-Error)" -Severity 3 -ScriptSection ${CmdletName}
            Throw "Initialization failed. `n$($_.Exception.Message)"
        }
    }
    Process {
        Try {

            ## Get cached package info
            ForEach ($Package in $Packages) {

                ## Show the progress
                $ProgressCounter++
                Write-Progress -Activity 'Processing Packages' -CurrentOperation $($Package.FullName) -PercentComplete $(($ProgressCounter / $PackageCount) * 100)

                ## Get the cache info for the package using the ContentID
                $PkgCacheInfo = $CacheInfo | Where-Object { $_.ContentID -eq $Package.PackageID }

                ## Debug info
                Write-Log -Message "CurentPackage: `n $($PkgCacheInfo | Out-String)" -DebugMessage -ScriptSection ${CmdletName}

                ## Accounting for cache items with multiple CacheElementIDs
                ForEach ($CacheItem in $PkgCacheInfo) {

                    ## If the package is in the cache, assemble properties and add it to the result object
                    If ($CacheItem) {
                        #  Set content size to 0 if null to avoid division by 0
                        If ($CacheItem.ContentSize -eq 0) { [int]$PkgContentSize = 0 } Else { [int]$PkgContentSize = $($CacheItem.ContentSize) }
                        #  Assemble result object props
                        $CachedPkgProps = [ordered]@{
                            Name              = $($Package.FullName)
                            Program           = $($Package.Name)
                            LastRunStatus     = $($Package.LastRunStatus)
                            RepeatRunBehavior = $($Package.RepeatRunBehavior)
                            ContentID         = $($CacheItem.ContentID)
                            ContentVersion    = $($CacheItem.ContentVersion)
                            ReferenceCount    = $($CacheItem.ReferenceCount)
                            LastReferenceTime = $($CacheItem.LastReferenceTime)
                            Location          = $($CacheItem.Location)
                            'Size(MB)'        = '{0:N2}' -f $($PkgContentSize / 1KB)
                            CacheElementID    = $($CacheItem.CacheElementID)
                        }
                        #  Add items to result object
                        $CachedPkgs += New-Object 'PSObject' -Property $CachedPkgProps
                    }
                }
            }
        }
        Catch {
            Write-Log -Message "Could not get cached package [$($Package.Name)]. `n$(Resolve-Error)" -Severity '3' -ScriptSection ${CmdletName}
            Throw "Could not get cached package [$($Package.Name)]. `n$($_.Exception.Message)"
        }
        Finally {
            Write-Output -InputObject $CachedPkgs
        }
    }
    End {

        ## Write verbose footer
        Write-Log -Message 'Stop' -VerboseMessage -ScriptSection ${CmdletName}
    }
}
#endregion

#region Function Get-CCMCachedUpdates
Function Get-CCMCachedUpdates {
<#
.SYNOPSIS
    Lists all ccm cached updates.
.DESCRIPTION
    Lists all configuration manager client cached updates with custom properties.
.EXAMPLE
    Get-CCMCachedUpdates
.INPUTS
    None
.OUTPUTS
    System.Object.
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.COMPONENT
    CM Client Cache
.FUNCTIONALITY
    Get cached updates
#>

    [CmdletBinding()]
    Param ()
    Begin {
        Try {

            ## Get the name of this function and write verbose header
            [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

            #  Write verbose header
            Write-Log -Message 'Start' -VerboseMessage -ScriptSection ${CmdletName}

            ## Initialize the CCM resource manager com object
            [__comobject]$CCMComObject = New-Object -ComObject 'UIResource.UIResourceMgr'

            ## Get ccm cache info
            $CacheInfo = $($CCMComObject.GetCacheInfo().GetCacheElements())

            ## Get ccm update list
            $Updates = Get-CimInstance -Namespace 'Root\ccm\SoftwareUpdates\UpdatesStore' -ClassName 'CCM_UpdateStatus' -Verbose:$false

            ## Count the updates
            [int]$UpdateCount = $($Updates | Measure-Object).Count

            ## Initialize counter
            [int]$ProgressCounter = 0

            ## Initialize result object
            [psobject]$CachedUpdates = @()
        }
        Catch {
            Write-Log -Message "Initialization failed. `n$(Resolve-Error)" -Severity 3 -ScriptSection ${CmdletName}
            Throw "Initialization failed. `n$($_.Exception.Message)"
        }
    }
    Process {
        Try {

            ## Get cached update info
            ForEach ($Update in $Updates) {

                ## Show the progress
                $ProgressCounter++
                Write-Progress -Activity 'Processing Updates' -CurrentOperation $Update.FullName -PercentComplete (($ProgressCounter / $UpdateCount) * 100)

                ## Get the cache info for the update using the ContentID
                $UpdateCacheInfo = $CacheInfo | Where-Object { $_.ContentID -eq $Update.UniqueID }

                ## Debug info
                Write-Log -Message "CachedInfo: `n $($UpdateCacheInfo | Out-String)" -DebugMessage -ScriptSection ${CmdletName}

                ## Accounting for cache items with multiple CacheElementIDs
                ForEach ($CacheItem in $UpdateCacheInfo) {

                    ## If the update is in the cache, assemble properties and add it to the result object
                    If ($CacheItem) {
                        #  Set content size to 0 if null to avoid division by 0
                        If ($($CacheItem.ContentSize) -eq 0) { [int]$UpdateContentSize = 0 } Else { [int]$UpdateContentSize = $($CacheItem.ContentSize) }
                        #  Assemble result object props
                        $CachedUpdateProps = [ordered]@{
                            Name              = $($Update.Title)
                            Article           = $($Update.Article)
                            Status            = $($Update.Status)
                            ContentID         = $($CacheItem.ContentID)
                            ContentVersion    = $($CacheItem.ContentVersion)
                            ReferenceCount    = $($CacheItem.ReferenceCount)
                            LastReferenceTime = $($CacheItem.LastReferenceTime)
                            Location          = $($CacheItem.Location)
                            'Size(MB)'        = '{0:N2}' -f $($UpdateContentSize / 1KB)
                            CacheElementID    = $($CacheItem.CacheElementID)
                        }
                        #  Add items to result object
                        $CachedUpdates += New-Object 'PSObject' -Property $CachedUpdateProps
                    }
                }
            }
        }
        Catch {
            Write-Log -Message "Could not get cached update [$($Update.Title)]. `n$(Resolve-Error)" -Severity '3' -ScriptSection ${CmdletName}
            Throw "Could not get cached update [$($Update.Title)]. `n$($_.Exception.Message)"
        }
        Finally {
            Write-Output -InputObject $CachedUpdates
        }
    }
    End {

        ## Write verbose footer
        Write-Log -Message 'Stop' -VerboseMessage -ScriptSection ${CmdletName}
    }
}
#endregion

#region Function Remove-CCMCacheElement
Function Remove-CCMCacheElement {
<#
.SYNOPSIS
    Removes a ccm cache element.
.DESCRIPTION
    Removes a configuration manager client cache element and optionally removes persisted content.
.PARAMETER CacheElementID
    Specifies the Cache Element ID to be deleted.
.PARAMETER RemovePersisted
    Specifies to remove cache element even if it's persisted. Default is: $false.
.PARAMETER ReferencedThreshold
    Specifies to remove cache element only if it has not been referenced in the last specified number of days.
    Default is: $script:ReferencedThreshold.
.EXAMPLE
    Remove-CCMCacheElement -ContentID '234234234' -RemovePersisted
.INPUTS
    System.String.
.OUTPUTS
    System.Object.
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.COMPONENT
    CM Client Cache
.FUNCTIONALITY
    Remove cached element
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullorEmpty()]
        [Alias('ID')]
        [string]$CacheElementID,
        [Parameter(Mandatory = $false, Position = 1)]
        [ValidateNotNullorEmpty()]
        [Alias('Persisted')]
        [boolean]$RemovePersisted = $false,
        [Parameter(Mandatory = $false, Position = 2)]
        [ValidateNotNullorEmpty()]
        [Alias('Threshold')]
        [int16]$ReferencedThreshold = $script:ReferencedThreshold
    )

    Begin {

        ## Get the name of this function and write verbose header
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

        #  Write verbose header
        Write-Log -Message 'Start' -VerboseMessage -ScriptSection ${CmdletName}

        ## Initialize the CCM resource manager com object
        [__comobject]$CCMComObject = New-Object -ComObject 'UIResource.UIResourceMgr'

        ## Initialize result object
        [psobject]$RemovedCache = @()

        ## Set the date threshold
        [datetime]$OlderThan = (Get-Date).ToUniversalTime().AddDays( - $ReferencedThreshold)
    }
    Process {
        Try {

            ## Get the CacheElementID to delete
            $CacheInfo = $CCMComObject.GetCacheInfo().GetCacheElements() | Where-Object { ($_.CacheElementID -eq $CacheElementID) }

            ## Write verbose message
            Write-Log -Message "Processing CacheItem [$($CacheInfo.ContentID) | $($CacheInfo.CacheElementID)]" -VerboseMessage -ScriptSection ${CmdletName}

            ## Delete only if no action is in progress
            If ($($CacheInfo.ReferenceCount) -lt 1) {
                #  Delete only if the $ReferencedThreshold is respected
                If ([datetime]($CacheInfo.LastReferenceTime) -le $OlderThan) {
                    #  Call the remove cache item method
                    $null = $CCMComObject.GetCacheInfo().DeleteCacheElementEx([string]$($CacheInfo.CacheElementID), [bool]$RemovePersisted)
                }
                Else {
                    $AboveReferencedThreshold = $true
                }

                ## Check if the CacheElement has been deleted
                $CacheInfo = $CCMComObject.GetCacheInfo().GetCacheElements() | Where-Object { $_.CacheElementID -eq $CacheElementID }
                #  If cache item still exists perform additional checks (this is a hack it would be nice to get the deployment flags from somewhere)
                If ($CacheInfo) {
                    #  If cache is above referenced threshold set status to 'AboveReferencedThreshold'
                    If ($AboveReferencedThreshold) { $RemovalStatus = 'AboveReferencedThreshold' }
                    #  If the RemovePersisted switch is set throw error
                    ElseIf ($RemovePersisted) { Throw "Failed to remove cache element [$($CacheInfo.ContentID) | $($CacheInfo.CacheElementID)]" }
                    #  If cache item still exists and RemovePersisted is not specified set the RemovalStatus to 'Persisted'
                    Else { $RemovalStatus = 'Persisted' }
                }
                #  If the cache is no longer present set the status to 'Removed'
                Else { $RemovalStatus = 'Removed' }
            }
            Else {
                ## If the cache item is still referenced set the removal status to 'Referenced'
                $RemovalStatus = 'Referenced'
            }

            ## Build result object
            $RemovedCacheProps = [ordered]@{
                ContentID         = $($CacheInfo.ContentID)
                ContentVersion    = $($CacheInfo.ContentVersion)
                ReferenceCount    = $($CacheInfo.ReferenceCount)
                LastReferenceTime = $($CacheInfo.LastReferenceTime)
                Location          = $($CacheInfo.Location)
                'Size(MB)'        = '{0:N2}' -f $($CacheInfo.ContentSize / 1KB)
                CacheElementID    = $($CacheInfo.CacheElementID)
                RemovalStatus     = $RemovalStatus
            }

            ##  Add items to result object
            $RemovedCache += New-Object 'PSObject' -Property $RemovedCacheProps
        }
        Catch {
            Write-Log -Message "Could not delete cache element [$($CacheInfo.ContentID) | $($CacheInfo.CacheElementID)]. `n$(Resolve-Error)" -Severity '3' -ScriptSection ${CmdletName}
            Throw "Could not delete cache element [$($CacheInfo.ContentID) | $($CacheInfo.CacheElementID)]. `n$($_.Exception.Message)"
        }
        Finally {
            Write-Output -InputObject $RemovedCache
        }
    }
    End {

        ## Write verbose footer
        Write-Log -Message 'Stop' -VerboseMessage -ScriptSection ${CmdletName}
    }
}
#endregion

#region Function Remove-CCMCachedApplications
Function Remove-CCMCachedApplications {
    <#
.SYNOPSIS
    Removes all ccm cached applications.
.DESCRIPTION
    Removes all ccm cached applications with the option to skip persisted content.
.PARAMETER RemovePersisted
    Specifies to remove cached application even if it's persisted. Default is: $false.
.EXAMPLE
    Remove-CCMCachedApplications -RemovePersisted $true
.INPUTS
    System.Boolean.
.OUTPUTS
    System.Object.
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.COMPONENT
    CM Client Cache
.FUNCTIONALITY
    Remove cached applications
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateNotNullorEmpty()]
        [Alias('RPer')]
        [boolean]$RemovePersisted = $false
    )

    Begin {
        Try {

            ## Get the name of this function and write verbose header
            [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

            #  Write verbose header
            Write-Log -Message 'Start' -VerboseMessage -ScriptSection ${CmdletName}

            ## Get ccm cached applications
            $CachedApplications = Get-CCMCachedApplications

            ## Initialize result object
            [psobject]$RemovedApplications = @()
        }
        Catch {
            Write-Log -Message "Initialization failed. `n$(Resolve-Error)" -Severity '3' -ScriptSection ${CmdletName}
            Throw "Initialization failed. `n$($_.Exception.Message)"
        }
    }
    Process {
        Try {

            ## Process remove cached applications
            ForEach ($Application in $CachedApplications) {
                #  Call Remove-CCMCacheElement
                $RemoveCacheElement = Remove-CCMCacheElement -CacheElementID $($Application.CacheElementID) -RemovePersisted $RemovePersisted
                #  Assemble result object props
                $RemovedApplicationProps = [ordered]@{
                    FullName          = $($Application.Name)
                    Name              = $($Application.DeploymentType)
                    ContentID         = $($Application.ContentID)
                    ContentVersion    = $($Application.ContentVersion)
                    ReferenceCount    = $($Application.ReferenceCount)
                    LastReferenceTime = $($Application.LastReferenceTime)
                    Location          = $($Application.Location)
                    'Size(MB)'        = $($Application.ContentSize)
                    CacheElementID    = $($Application.CacheElementID)
                    Status            = $($RemoveCacheElement.RemovalStatus)
                }
                #  Add items to result object
                $RemovedApplications += New-Object 'PSObject' -Property $RemovedApplicationProps
            }
        }
        Catch {
            Write-Log -Message "Could not remove cached application [$($Application.Name)]. `n$(Resolve-Error)" -Severity '3' -ScriptSection ${CmdletName}
            Throw "Could not remove cached application [$($Application.Name)]. `n$($_.Exception.Message)"
        }
        Finally {
            Write-Output -InputObject $RemovedApplications
        }
    }
    End {

        ## Write verbose footer
        Write-Log -Message 'Stop' -VerboseMessage -ScriptSection ${CmdletName}
    }
}
#endregion

#region Function Remove-CCMCachedPackages
Function Remove-CCMCachedPackages {
<#
.SYNOPSIS
    Removes all ccm cached packages.
.DESCRIPTION
    Removes all ccm cached packages with the option to skip persisted content.
.PARAMETER RemovePersisted
    Specifies to remove cached package even if it's persisted. Default is: $false.
.EXAMPLE
    Remove-CCMCachedPackages -RemovePersisted $true
.INPUTS
    System.Boolean.
.OUTPUTS
    System.Object.
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.COMPONENT
    CM Client Cache
.FUNCTIONALITY
    Remove cached packages
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateNotNullorEmpty()]
        [Alias('RPer')]
        [boolean]$RemovePersisted = $false
    )

    Begin {
        Try {

            ## Get the name of this function and write verbose header
            [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

            #  Write verbose header
            Write-Log -Message 'Start' -VerboseMessage -ScriptSection ${CmdletName}

            ## Get ccm cached packages
            $CachedPackages = Get-CCMCachedPackages

            ## Initialize result object
            [psobject]$RemovePackages = @()
        }
        Catch {
            Write-Log -Message "Initialization failed. `n$(Resolve-Error)" -Severity '3' -ScriptSection ${CmdletName}
            Throw "Initialization failed. `n$($_.Exception.Message)"
        }
    }
    Process {
        Try {

            ## Process remove cached packages
            ForEach ($Package in $CachedPackages) {
                #  Check if program in the package needs the cached package, it looked weird to call it Program instead of Package
                If ($Package.LastRunStatus -eq 'Succeeded' -and $Package.RepeatRunBehavior -ne 'RerunAlways' -and $Package.RepeatRunBehavior -ne 'RerunIfSuccess') {
                    #  Call Remove-CCMCacheElement
                    $RemoveCacheElement = Remove-CCMCacheElement -CacheElementID $($Package.CacheElementID) -RemovePersisted $RemovePersisted
                }
                Else {
                    $Status = 'Needed'
                }
                #  Set removal status
                If ($Status -ne 'Needed') { $Status = $($RemoveCacheElement.RemovalStatus) }
                #  Assemble result object props
                $RemovePackageProps = [ordered]@{
                    FullName          = $($Package.Name)
                    Name              = $($Package.Program)
                    ContentID         = $($Package.ContentID)
                    ContentVersion    = $($Package.ContentVersion)
                    ReferenceCount    = $($Package.ReferenceCount)
                    LastReferenceTime = $($Package.LastReferenceTime)
                    Location          = $($Package.Location)
                    'Size(MB)'        = $($Package.ContentSize)
                    CacheElementID    = $($Package.CacheElementID)
                    Status            = $Status
                }
                #  Add items to result object
                $RemovePackages += New-Object 'PSObject' -Property $RemovePackageProps
            }
        }
        Catch {
            Write-Log -Message "Could not remove cached package [$($Package.Name)]. `n$(Resolve-Error)" -Severity '3'
            Throw "Could not remove cached package [$($Package.Name)]. `n$($_.Exception.Message)"
        }
        Finally {
            Write-Output -InputObject $RemovePackages
        }
    }
    End {

        ## Write verbose footer
        Write-Log -Message 'Stop' -VerboseMessage -ScriptSection ${CmdletName}
    }
}
#endregion

#region Function Remove-CCMCachedUpdates
Function Remove-CCMCachedUpdates {
<#
.SYNOPSIS
    Removes all ccm cached updates.
.DESCRIPTION
    Removes all ccm cached updates.
.EXAMPLE
    Remove-CCMCachedUpdates
.INPUTS
    None
.OUTPUTS
    System.Object.
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.COMPONENT
    CM Client Cache
.FUNCTIONALITY
    Remove cached updates
#>

    [CmdletBinding()]
    Param ()
    Begin {
        Try {

            ## Get the name of this function and write verbose header
            [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

            #  Write verbose header
            Write-Log -Message 'Start' -VerboseMessage

            ## Get ccm cached updates
            $CachedUpdates = Get-CCMCachedUpdates

            ## Initialize result object
            [psobject]$RemoveUpdates = @()
        }
        Catch {
            Write-Log -Message "Initialization failed. `n$(Resolve-Error)" -Severity 3 -ScriptSection ${CmdletName}
            Throw "Initialization failed. `n$($_.Exception.Message)"
        }
    }
    Process {
        Try {

            ## Process remove cached updates
            ForEach ($Update in $CachedUpdates) {
                #  Check if update is installed
                If ($Update.Status -eq 'Installed') {
                    #  Call Remove-CCMCacheElement
                    $RemoveCacheElement = Remove-CCMCacheElement -CacheElementID $($Update.CacheElementID) -RemovePersisted $RemovePersisted
                }
                Else {
                    $Status = 'Needed'
                }
                #  Set removal status
                If ($Status -ne 'Needed') { $Status = $($RemoveCacheElement.RemovalStatus) }
                #  Assemble result object props
                $RemoveUpdateProps = [ordered]@{
                    FullName          = $($Update.Title)
                    Name              = $($Update.Article)
                    ContentID         = $($Update.ContentID)
                    ContentVersion    = $($Update.ContentVersion)
                    ReferenceCount    = $($Update.ReferenceCount)
                    LastReferenceTime = $($Update.LastReferenceTime)
                    Location          = $($Update.Location)
                    'Size(MB)'        = $($Update.ContentSize)
                    CacheElementID    = $($Update.CacheElementID)
                    Status            = $Status
                }
                #  Add items to result object
                $RemoveUpdates += New-Object 'PSObject' -Property $RemoveUpdateProps
            }
        }
        Catch {
            Write-Log -Message "Could not remove cached update [$($Update.Title)]. `n$(Resolve-Error)" -Severity '3'
            Throw "Could not remove cached update [$($Update.Title)]. `n$($_.Exception.Message)"
        }
        Finally {
            Write-Output -InputObject $RemoveUpdates
        }
    }
    End {

        ## Write verbose footer
        Write-Log -Message 'Stop' -VerboseMessage -ScriptSection ${CmdletName}
    }
}
#endregion

#region Function Remove-CCMOrphanedCache
Function Remove-CCMOrphanedCache {
<#
.SYNOPSIS
    Removes all orphaned ccm cache items.
.DESCRIPTION
    Removes all ccm cache items not present it wmi.
.EXAMPLE
    Remove-CCMOrphanedCache
.INPUTS
    None.
.OUTPUTS
    System.Object.
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.COMPONENT
    CM Client Cache
.FUNCTIONALITY
    Remove orphaned cached items
#>

    [CmdletBinding()]
    Param ()
    Begin {
        Try {

            ## Get the name of this function and write verbose header
            [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

            #  Write verbose header
            Write-Log -Message 'Start' -VerboseMessage -ScriptSection ${CmdletName}

            ## Initialize the CCM resource manager com object
            [__comobject]$CCMComObject = New-Object -ComObject 'UIResource.UIResourceMgr'

            ## Get ccm disk cache info
                [string]$DiskCachePath = $($CCMComObject.GetCacheInfo()).Location
                $DiskCacheInfo = Get-ChildItem -LiteralPath $DiskCachePath | Select-Object -Property 'FullName', 'Name'

            ## Get ccm wmi cache info
            $WmiCacheInfo = $($CCMComObject.GetCacheInfo().GetCacheElements())

            ## Get ccm wmi cache paths
            $WmiCachePaths = $WmiCacheInfo | Select-Object -ExpandProperty 'Location'

            ## Initialize result object
            [psobject]$RemoveOrphaned = @()
        }
        Catch {
            Write-Log -Message "Initialization failed. `n$(Resolve-Error)" -Severity '3' -ScriptSection ${CmdletName}
            Throw "Initialization failed. `n$($_.Exception.Message)"
        }
    }
    Process {
        Try {

            ## Process disk cache items
            ForEach ($CacheElement in $DiskCacheInfo) {
                ## Set variables
                #  Set cache Path
                $CacheElementPath = $($CacheElement.FullName)
                #  Set cache Size
                $CacheElementSize = $(Get-ChildItem -LiteralPath $CacheElementPath -Recurse | Measure-Object -Property 'Length' -Sum).Sum

                ## If disk cache path is not present in wmi, delete it
                If ($CacheElementPath -notin $WmiCachePaths) {
                    #  Remove cache item
                    $RemoveCacheElement = Remove-Item -LiteralPath $CacheElementPath -Recurse -Force

                    #  Assemble result object props
                    $RemoveOrphanedProps = [ordered]@{
                        FullName   = 'Orphaned Disk Cache'
                        Location   = $CacheElementPath
                        'Size(MB)' = '{0:N2}' -f $($CacheElementSize / 1MB)
                        Status     = 'Removed'
                    }
                    #  Add items to result object
                    $RemoveOrphaned += New-Object 'PSObject' -Property $RemoveOrphanedProps
                }
            }

            ## Process wmi cache items
            ForEach ($CacheElement in $WmiCacheInfo) {
                #  If disk cache path is not present in wmi, delete it
                If ($($CacheElement.Location) -notin $($DiskCacheInfo.FullName)) {
                    #  Remove cache item
                    $RemoveCacheElement = Remove-CCMCacheElement -CacheElementID ($CacheElement.CacheElementID) -RemovePersisted $RemovePersisted
                    #  Assemble result object props
                    $RemoveOrphanedProps = [ordered]@{
                        FullName   = 'Orphaned WMI Cache'
                        ContentID  = $($CacheElement.ContentID)
                        'Size(MB)' = '0'
                        Status     = $($RemoveCacheElement.RemovalStatus)
                    }
                    #  Add items to result object
                    $RemoveOrphaned += New-Object 'PSObject' -Property $RemoveOrphanedProps
                }
            }
        }
        Catch {
            Write-Log -Message "Could not remove cached item [$($CacheElementPath)]. `n$(Resolve-Error)" -Severity '3' -ScriptSection ${CmdletName}
            Throw "Could not remove cached item [$($CacheElementPath)]. `n$($_.Exception.Message)"
        }
        Finally {
            Write-Output -InputObject $RemoveOrphaned
        }
    }
    End {

        ## Write verbose footer
        Write-Log -Message 'Stop' -VerboseMessage -ScriptSection ${CmdletName}
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

    ## Set the script section
    [string]${ScriptSection} = 'Main:Initialization'

    ## Write Start verbose message
    Write-Log -Message 'Start' -VerboseMessage -ScriptSection ${ScriptSection}

    ## Initialize the CCM resource manager com object
    [__comobject]$CCMComObject = New-Object -ComObject 'UIResource.UIResourceMgr'

    ## Get cache drive free space percentage
    #  Get ccm cache drive location
    [string]$CacheDrive = $($CCMComObject.GetCacheInfo()).Location | Split-Path -Qualifier
    #  Get cache drive info
    $CacheDriveInfo = Get-CimInstance -ClassName 'Win32_LogicalDisk' -Filter "DeviceID='$CacheDrive'" -Verbose:$false
    #  Get cache drive size in GB
    [int16]$DriveSize = $($CacheDriveInfo.Size) / 1GB
    #  Get cache drive free space in GB
    [int16]$DriveFreeSpace = $($CacheDriveInfo.FreeSpace) / 1GB
    #  Calculate percentage
    [int16]$DriveFreeSpacePercentage = ($DriveFreeSpace * 100 / $DriveSize)

    ## Get super peer status
    [boolean]$CanBeSuperPeer = Get-CimInstance -Namespace 'root\ccm\Policy\Machine\ActualConfig' -ClassName 'CCM_SuperPeerClientConfig' -Verbose:$false | Select-Object -ExpandProperty 'CanBeSuperPeer'

    ## Set run condition. If disk free space is above the specified threshold or CanBeSuperPeer is true and SkipSuperPeer is not specified, the script will not run.
    If (($DriveFreeSpacePercentage -gt $LowDiskSpaceThreshold) -or ($CanBeSuperPeer -eq $true -and $SkipSuperPeer)) { $ShouldRun = $false }

    ## Check run condition and stop execution if $ShouldRun is not $true
    If ($ShouldRun) {
        Write-Log -Message 'Should Run test passed' -VerboseMessage -ScriptSection ${ScriptSection}
    }
    Else {
        Write-Log -Message 'Should Run test failed.' -Severity '3' -ScriptSection ${ScriptSection}
        Write-Log -Message "FreeSpace/Threshold [$DriveFreeSpacePercentage`/$LowDiskSpaceThreshold] | IsSuperPeer/SkipSuperPeer [$CanBeSuperPeer`/$SkipSuperPeer]" -DebugMessage -ScriptSection ${CmdletName}
        Write-Log -Message 'Stop' -VerboseMessage -ScriptSection ${ScriptSection}

        ## Stop execution
        Exit
    }
    Write-Log -Message 'Stop' -VerboseMessage -ScriptSection ${ScriptSection}
}
Catch {
    Write-Log -Message "Script initialization failed. `n$(Resolve-Error)" -Severity '3' -ScriptSection ${ScriptSection}
    Throw "Script initialization failed. $($_.Exception.Message)"
}
Try {

    ## Set the script section
    [string]${ScriptSection} = 'Main:CleanupActions'

    ## Write debug action
    Write-Log -Message "Cleanup Actions [$CleanupActions]" -DebugMessage -ScriptSection ${ScriptSection}

    ## Process selected actions
    Switch ($CleanupActions) {
        All {
            $CleanupResult += Remove-CCMCachedApplications -RemovePersisted $RemovePersisted
            $CleanupResult += Remove-CCMCachedPackages -RemovePersisted $RemovePersisted
            $CleanupResult += Remove-CCMCachedUpdates
            $CleanupResult += Remove-CCMOrphanedCache
        }
        Applications {
            $CleanupResult += Remove-CCMCachedApplications -RemovePersisted $RemovePersisted
        }
        Packages {
            $CleanupResult += Remove-CCMCachedPackages -RemovePersisted $RemovePersisted
        }
        Updates {
            $CleanupResult += Remove-CCMCachedUpdates
        }
        Orphaned {
            $CleanupResult += Remove-CCMOrphanedCache
        }
        Default {
            Write-Log -Message "Invalid cleanup action [$_] selected." -Severity '3' -ScriptSection ${ScriptSection}
            Throw "Invalid cleanup action selected."
        }
    }
}
Catch {
    Write-Log -Message "Could not perform cleanup action. `n$(Resolve-Error)" -Severity '3' -ScriptSection ${ScriptSection}
    Throw "Could not perform cleanup action. `n$($_.Exception.Message)"
}
Finally {

    ## Set the script section
    [string]${ScriptSection} = 'Main:CleanupResult'

    ## Calculate total deleted size
    $TotalDeletedSize = $CleanupResult | Where-Object { $_.Status -eq 'Removed' } | Measure-Object -Property 'Size(MB)' -Sum | Select-Object -ExpandProperty Sum
    If (-not $TotalDeletedSize) { $TotalDeletedSize = 0 }

    ## Assemble output result
    $OutputResult = $($CleanupResult | Format-List -Property FullName, Name, Location, LastReferenceTime, 'Size(MB)', Status | Out-String) + "TotalDeletedSize: " + $TotalDeletedSize

    ## Write output to log, event log and console and status
    Write-Log -Message $OutputResult -ScriptSection ${ScriptSection}

    ## Write verbose stop
    Write-Log -Message 'Stop' -VerboseMessage -ScriptSection ${ScriptSection}
}

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================
