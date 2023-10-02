<#
.SYNOPSIS
    Cleans the configuration manager client cache.
.DESCRIPTION
    Cleans the configuration manager client cache of all unneeded with the option to delete pinned content.
.PARAMETER CacheType
    Specifies Cache Type to clean. ('All', 'Application', 'Package', 'Update', 'Orphaned'). Default is: 'All'.
    If it's set to 'All' all cache will be processed.
.PARAMETER CleanupType
    Specifies Cleanup Type to clean. ('All', 'Automatic', 'ListOnly', 'Tombstoned', 'Referenced'). Default is: 'Automatic'.
    If 'All', 'Automatic' or 'ListOnly' is selected the other options will be ignored.
    An 'Referenced' item is eligible for deletion if the time specified in its 'LastReferenceTime' property is longer than the time specified 'MaxCacheDuration'.
    An 'Unreferenced' item is eligible for deletion if the time specified in its 'LastReferenceTime' property is longer than the time specified in 'TombStoneDuration'.

    Available Cleanup Options:
        - 'All'
            Tombstoned and Referenced cache will be deleted, 'SkipSuperPeer' and 'DeletePinned' switches will still be respected.
            The 'EligibleForDeletion' convention is NOT respected.
            Not recommended but still safe to use, cache will be redownloaded when needed
        - 'Automatic'
            'Tombstoned' and 'Referenced' will be selected depending on 'FreeDiskSpaceThreshold' parameter.
            If under threshold only 'Tombstoned' cache items will be deleted.
            If over threshold, both 'Tombstoned' and 'Referenced' cache items will be deleted.
            The 'EligibleForDeletion' convention is still respected.
        - 'Tombstoned'
            Only 'Tombstoned' cache items will be deleted.
            The 'EligibleForDeletion' convention is still respected.
        - 'Referenced'
            Only 'Referenced' cache items will be deleted.
            The 'EligibleForDeletion' convention is still respected.
            Not recommended but still safe to use, cache will be redownloaded when needed
.PARAMETER FreeDiskSpaceThreshold
    Specifies the free disk space threshold percentage after which the cache is cleaned. Default is: '100'.
    If it's set to '100' Free Space Threshold Percentage is ignored.
.PARAMETER SkipSuperPeer
    This switch specifies to skip cleaning if the client is a super peer (Peer Cache). Default is: $false.
.PARAMETER DeletePinned
    This switch specifies to remove cache even if it's pinned (Applications and Packages). Default is: $false.
.PARAMETER LoggingOptions
    Specifies logging options: ('Host', 'File', 'EventLog', 'None'). Default is: ('Host', 'File', 'EventLog').
.PARAMETER LogName
    Specifies log folder name and event log name. Default is: 'Configuration Manager'.
.PARAMETER LogSource
    Specifies log file name and event source name. Default is: 'Invoke-CCMCacheCleanup'.
.PARAMETER LogDebugMessages
    This switch specifies to log debug messages. Default is: $false.
.EXAMPLE
    Invoke-CCMCacheCleanup -CacheType "Application, Package, Update, Orphaned" -CleanupType "Tombstoned, Referenced" -FreeDiskSpaceThreshold '100' -SkipSuperPeer -DeletePinned
.INPUTS
    None.
.OUTPUTS
    System.Management.Automation.PSObject
.NOTES
    Created by Ioan Popovici
.LINK
    https://MEMZ.one/Invoke-CCMCacheCleanup
.LINK
    https://MEMZ.one/Invoke-CCMCacheCleanup-CHANGELOG
.LINK
    https://MEMZ.one/Invoke-CCMCacheCleanup-GIT
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
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $false, Position = 0)]
    [ValidateSet('All', 'Application', 'Package', 'Update', 'Orphaned')]
    [Alias('Type')]
    [string[]]$CacheType = 'All',
    [Parameter(Mandatory = $false, Position = 1)]
    [ValidateSet('All', 'Automatic', 'ListOnly', 'Tombstoned', 'Referenced')]
    [Alias('Action')]
    [string[]]$CleanupType = 'Automatic',
    [Parameter(Mandatory = $false, Position = 2)]
    [ValidateNotNullorEmpty()]
    [Alias('FreeSpace')]
    [int16]$FreeDiskSpaceThreshold = 100,
    [Parameter(Mandatory = $false, Position = 3)]
    [switch]$SkipSuperPeer,
    [Parameter(Mandatory = $false, Position = 4)]
    [switch]$DeletePinned,
    [Parameter(Mandatory = $false, Position = 5)]
    [ValidateSet('Host', 'File', 'EventLog', 'None')]
    [Alias('Logging')]
    [string[]]$LoggingOptions = @('File', 'EventLog'),
    [Parameter(Mandatory = $false, Position = 6)]
    [string]$LogName = 'Configuration Manager',
    [Parameter(Mandatory = $false, Position = 7)]
    [string]$LogSource = 'Invoke-CCMCacheCleanup',
    [Parameter(Mandatory = $false, Position = 8)]
    [switch]$LogDebugMessages = $false
)


## Get script path, name and configuration file path
[string]$ScriptName       = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Definition)
[string]$ScriptFullName   = [System.IO.Path]::GetFullPath($MyInvocation.MyCommand.Definition)

## Get Show-Progress steps
$ProgressSteps = $(([System.Management.Automation.PsParser]::Tokenize($(Get-Content -Path $ScriptFullName), [ref]$null) | Where-Object { $_.Type -eq 'Command' -and $_.Content -eq 'Show-Progress' }).Count)
#  Set progress steps
$Script:Steps = $ProgressSteps
$Script:Step = 0
$Script:DefaultSteps = $Script:Steps
$Script:CurrentStep = 0

## Set script global variables
$script:LoggingOptions   = $LoggingOptions
$script:LogName          = $LogName
$script:LogSource        = $ScriptName
$script:LogDebugMessages = $false
$script:LogFileDirectory = If ($LogPath) { Join-Path -Path $LogPath -ChildPath $script:LogName } Else { $(Join-Path -Path $Env:WinDir -ChildPath $('\Logs\' + $script:LogName)) }

## Initialize result variable
[pscustomobject]$Output = @()

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

#region Function Show-Progress
Function Show-Progress {
<#
.SYNOPSIS
    Displays progress info.
.DESCRIPTION
    Displays progress info and maximizes code reuse by automatically calculating the progress steps.
.PARAMETER Actity
    Specifies the progress activity. Default: 'Cleaning Up Configuration Manager Client Cache, Please Wait...'.
.PARAMETER Status
    Specifies the progress status.
.PARAMETER CurrentOperation
    Specifies the current operation.
.PARAMETER Step
    Specifies the progress step. Default: $Script:Step ++.
.PARAMETER Steps
    Specifies the progress steps. Default: $Script:Steps ++.
.PARAMETER ID
    Specifies the progress bar id.
.PARAMETER Delay
    Specifies the progress delay in milliseconds. Default: 0.
.PARAMETER Loop
    Specifies if the call comes from a loop.
.EXAMPLE
    Show-Progress -Activity 'Cleaning Up Configuration Manager Client Cache, Please Wait...' -Status 'Cleaning WMI' -Step ($Step++) -Delay 200
.INPUTS
    None.
.OUTPUTS
    None.
.NOTES
    Created by Ioan Popovici.
    v2.0.0 - 2021-01-01

    This is an private function should tipically not be called directly.
    Credit to Adam Bertram.

    ## !! IMPORTANT !! ##
    #  You need to tokenize the scripts steps at the begining of the script in order for Show-Progress to work:

    ## Get script path and name
    [string]$ScriptPath = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Definition)
    [string]$ScriptName = [System.IO.Path]::GetFileName($MyInvocation.MyCommand.Definition)
    [string]$ScriptFullName = Join-Path -Path $ScriptPath -ChildPath $ScriptName
    #  Get progress steps
    $ProgressSteps = $(([System.Management.Automation.PsParser]::Tokenize($(Get-Content -Path $ScriptFullName), [ref]$null) | Where-Object { $PSItem.Type -eq 'Command' -and $PSItem.Content -eq 'Show-Progress' }).Count)
    $ForEachSteps = $(([System.Management.Automation.PsParser]::Tokenize($(Get-Content -Path $ScriptFullName), [ref]$null) | Where-Object { $PSItem.Type -eq 'Keyword' -and $PSItem.Content -eq 'ForEach' }).Count)
    #  Set progress steps
    $Script:Steps = $ProgressSteps - $ForEachSteps
    $Script:Step = 0
.LINK
    https://adamtheautomator.com/building-progress-bar-powershell-scripts/
.LINK
    https://MEM.Zone
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
        [string]$Activity = 'Cleaning Up Configuration Manager Client Cache, Please Wait...',
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
        [Alias('sts')]
        [int]$Steps = $Script:Steps,
        [Parameter(Mandatory=$false,Position=6)]
        [ValidateNotNullorEmpty()]
        [Alias('del')]
        [string]$Delay = 0,
        [Parameter(Mandatory=$false,Position=7)]
        [ValidateNotNullorEmpty()]
        [Alias('lp')]
        [switch]$Loop
    )
    Begin {


    }
    Process {
        Try {
            If ($Step -eq 0) {
                $Step ++
                $Script:Step ++
                $Steps ++
                $Script:Steps ++
            }
            If ($Steps -eq 0) {
                $Steps ++
                $Script:Steps ++
            }

            [boolean]$Completed = $false
            [int]$PercentComplete = $($($Step / $Steps) * 100)

            If ($PercentComplete -ge 100)  {
                $PercentComplete = 100
                $Completed = $true
                $Script:CurrentStep ++
                $Script:Step = $Script:CurrentStep
                $Script:Steps = $Script:DefaultSteps
            }

            ## Debug information
            Write-Verbose -Message "Percent Step: $Step"
            Write-Verbose -Message "Percent Steps: $Steps"
            Write-Verbose -Message "Percent Complete: $PercentComplete"
            Write-Verbose -Message "Completed: $Completed"

            ##  Show progress
            Write-Progress -Activity $Activity -Status $Status -CurrentOperation $CurrentOperation -ID $ID -PercentComplete $PercentComplete -Completed:$Completed
            If ($Delay -ne 0) { Start-Sleep -Milliseconds $Delay }
        }
        Catch {
            Throw (New-Object System.Exception("Could not Show progress status [$Status]! $($PSItem.Exception.Message)", $PSItem.Exception))
        }
    }
}
#endregion

#region Format-Bytes
Function Format-Bytes {
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
    System.Single.
.OUTPUTS
    System.String.
.NOTES
    Created by Ioan Popovici.
    v1.0.0 - 2021-09-01

    This is an private function should tipically not be called directly.
    Credit to Anthony Howell.
.LINK
    https://theposhwolf.com/howtos/Format-Bytes/
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    Powershell
.FUNCTIONALITY
    Format Bytes
#>
    Param (
        [Parameter(ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [float]$Bytes
    )
    Begin {
        [string]$Output = $null
        [boolean]$Negative = $false
        $Sizes = 'KB','MB','GB','TB','PB'
    }
    Process {
        Try {
            If ($Bytes -le 0) {
                $Bytes = -$Bytes
                [boolean]$Negative = $true
            }
            For ($Counter = 0; $Counter -lt $Sizes.Count; $Counter++) {
                If ($Bytes -lt "1$($Sizes[$Counter])") {
                    If ($Counter -eq 0) {
                    $Number = $Bytes
                    $Sizes = 'B'
                    }
                    Else {
                        $Number = $Bytes / "1$($Sizes[$Counter-1])"
                        $Number = '{0:N2}' -f $Number
                        $Sizes = $Sizes[$Counter-1]
                    }
                }
            }
        }
        Catch {
            $Output = "Format Failed for Bytes ($Bytes! Error: $($_.Exception.Message)"
            Write-Log -Message $Output -EventID 2 -Severity 3
        }
        Finally {
            If ($Negative) { $Number = -$Number }
            $Output = '{0} {1}' -f $Number, $Sizes
            Write-Output -InputObject $Output
        }
    }
    End{
    }
}
#endregion

#region Function Get-CCMApplicationInfo
Function Get-CCMApplicationInfo {
<#
.SYNOPSIS
    Lists ccm cached application information.
.DESCRIPTION
    Lists ccm cached application information.
.PARAMETER ContentID
    Specify cache ContentID, optional.
.EXAMPLE
    Get-CCMApplicationInfo
.INPUTS
    None.
.OUTPUTS
    None.
    System.Management.Automation.PSObject.
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    CM Client Cache
.FUNCTIONALITY
    Get cached application name
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateNotNullorEmpty()]
        [string]$ContentID = $null
    )
    Begin {
        Try {

            ## Get the name of this function and write verbose header
            [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
            #  Write verbose header
            Write-Log -Message 'Start' -VerboseMessage -ScriptSection ${CmdletName}

            ## Get ccm application list
            $Applications = Get-CimInstance -Namespace 'Root\ccm\ClientSDK' -ClassName 'CCM_Application' -Verbose:$false -ErrorAction 'SilentlyContinue'

            ## Initialize output object
            [psobject]$Output = @()
        }
        Catch {

            ## Return custom error
            $Message       = [string]"Error getting cached applications.`n{0}. `n!! TEST !!`n{1}" -f $($PSItem.Exception.Message), $(Resolve-Error)
            $Exception     = [Exception]::new($Message)
            $ExceptionType = [Management.Automation.ErrorCategory]::ObjectNotFound
            $ErrorRecord   = [System.Management.Automation.ErrorRecord]::new($Exception, $PSItem.FullyQualifiedErrorId, $ExceptionType, $Applications)
            #  Write to log
            Write-Log -Message $Message -Severity '3' -ScriptSection ${CmdletName}
            #  Throw terminating error
            $PSCmdlet.ThrowTerminatingError($ErrorRecord)
        }
    }
    Process {
        Try {

            ## Get cached application info
            $Output = ForEach ($Application in $Applications) {

                ## Show progress bar
                Show-Progress -Status "Getting info for [Application] --> [$($Application.FullName)]" -Steps $Applications.Count

                ## Get application deployment types
                $ApplicationDTs = ($Application | Get-CimInstance -Verbose:$false -ErrorAction 'SilentlyContinue').AppDTs

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
                        [psobject]@{
                            'Name'              = $Application.FullName
                            'ContentID'         = $AppContentID
                            'AppDeliveryTypeID' = $DeploymentType.ID
                            'InstallState'      = $Application.InstallState
                        }
                    }
                }
            }
            $Output = $Output | Sort-Object | Select-Object -Unique
        }
        Catch {

            ## Return custom error
            $Message       = [string]"Error getting cached application {0}.`n{1}. `n!! TEST !!`n{2}" -f $($Application.Name), $($PSItem.Exception.Message), $(Resolve-Error)
            $Exception     = [Exception]::new($Message)
            $ExceptionType = [Management.Automation.ErrorCategory]::ObjectNotFound
            $ErrorRecord   = [System.Management.Automation.ErrorRecord]::new($Exception, $PSItem.FullyQualifiedErrorId, $ExceptionType, $Application)
            #  Write to log
            Write-Log -Message $Message -Severity '3' -ScriptSection ${CmdletName}
            #  Throw terminating error
            $PSCmdlet.ThrowTerminatingError($ErrorRecord)
        }
        Finally {
            If (-not [string]::IsNullOrWhiteSpace($ContentID)) { $Output = $Output | Where-Object -Property 'ContentID' -eq $ContentID }
            Write-Output -InputObject $Output
        }
    }
    End {

        ## Write verbose footer
        Write-Log -Message 'Stop' -VerboseMessage -ScriptSection ${CmdletName}
    }
}
#endregion

#region Function Get-CCMOrphanedCache
Function Get-CCMOrphanedCache {
<#
.SYNOPSIS
    Lists ccm orphaned cache items.
.DESCRIPTION
    Lists configuration manager client disk cache items that are not found in WMI and viceversa.
.EXAMPLE
    Get-CCMOrphanedCache
.INPUTS
    None.
.OUTPUTS
    None.
    System.Management.Automation.PSCustomObject.
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    CM Client Cache
.FUNCTIONALITY
    Get orphaned cached items
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
            $CacheInfo = $CCMComObject.GetCacheInfo()

            ## Get ccm disk cache info
            [string]$DiskCachePath = $CacheInfo.Location
            [psobject]$DiskCacheInfo = Get-ChildItem -LiteralPath $DiskCachePath | Select-Object -Property 'FullName'

            ## Get ccm wmi cache info
            $WmiCacheInfo = $CacheInfo.GetCacheElements()

            ## Get ccm wmi cache paths
            [string[]]$WmiCachePaths = $WmiCacheInfo | Select-Object -ExpandProperty 'Location'

            ## Create a file system object
            $FileSystemObject = New-Object -ComObject 'Scripting.FileSystemObject'

            ## Initialize output object
            [pscustomobject]$Output = $null
        }
        Catch {

            ## Return custom error
            $Message       = [string]"Error getting orphaned cache items `n{0}" -f $(Resolve-Error)
            $Exception     = [Exception]::new($Message)
            $ExceptionType = [Management.Automation.ErrorCategory]::ObjectNotFound
            $ErrorRecord   = [System.Management.Automation.ErrorRecord]::new($Exception, $PSItem.FullyQualifiedErrorId, $ExceptionType, $WmiCacheInfo)
            #  Write to log
            Write-Log -Message $Message -Severity '3' -ScriptSection ${CmdletName}
            #  Throw terminating error
            $PSCmdlet.ThrowTerminatingError($ErrorRecord)
        }
    }
    Process {
        Try {

            [scriptblock]$GetCCMOrphanedCache = {
                ## Process disk cache items
                ForEach ($CacheElement in $DiskCacheInfo) {
                    $CacheElementPath = $($CacheElement.FullName)
                    $CacheElementSize = $FileSystemObject.GetFolder($CacheElementPath).Size

                    ## Show progress bar
                    Show-Progress -Status "Searching Disk for Orphaned CCMCache --> [$CacheElementPath]" -Steps $DiskCacheInfo.Count

                    ## Include if disk cache path is not present in wmi
                    If ($CacheElementPath -notin $WmiCachePaths) {
                        #  Assemble output object
                        [pscustomobject]@{
                            'CacheType'           = 'Orphaned'
                            'Name'                = 'Orphaned Disk Cache'
                            'Tombstoned'          = $true
                            'EligibleForDeletion' = $true
                            'ContentID'           = 'N/A'
                            'Location'            = $CacheElementPath
                            'ContentVersion'      = '0'
                            'LastReferenceTime'   = $CacheInfo.MaxCacheDuration + 1
                            'ReferenceCount'      = '0'
                            'ContentSize'         = $CacheElementSize
                            'CacheElementID'      = 'N/A'
                            'Status'              = 'Cached'
                        }
                    }
                }

                ## Process wmi cache items
                ForEach ($CacheElement in $WmiCacheInfo) {

                    ## Show progress bar
                    Show-Progress -Status "Searching WMI for Orphaned CCMCache --> [$($CacheElement.CacheElementID)]" -Steps $WmiCacheInfo.Count

                    ## Include if wmi cache path is not present on disk
                    If ($CacheElement.Location -notin $DiskCacheInfo.FullName) {
                        #  Assemble output object props
                        [pscustomobject]@{
                            'CacheType'           = 'Orphaned'
                            'Name'                = 'Orphaned WMI Cache'
                            'Tombstoned'          = $true
                            'EligibleForDeletion' = $true
                            'ContentID'           = $CacheElement.ContentID
                            'Location'            = $CacheElement.Location
                            'ContentVersion'      = $CacheElement.ContentVersion
                            'LastReferenceTime'   = $CacheInfo.MaxCacheDuration + 1
                            'ReferenceCount'      = '0'
                            'ContentSize'         = $CacheElement.ContentSize
                            'CacheElementID'      = $CacheElement.CacheElementID
                            'Status'              = 'Cached'
                        }
                    }
                }
            }
            $Output = $GetCCMOrphanedCache.Invoke()
        }
        Catch {

            ## Return custom error
            If ( [string]::IsNullOrWhiteSpace($CacheElementPath) ) { $CacheElementPath = $CacheElement.Location }
            $Message       = [string]"Error getting orphaned cache item '{0}'`n{1}" -f $CacheElementPath, $(Resolve-Error)
            $Exception     = [Exception]::new($Message)
            $ExceptionType = [Management.Automation.ErrorCategory]::ObjectNotFound
            $ErrorRecord   = [System.Management.Automation.ErrorRecord]::new($Exception, $PSItem.FullyQualifiedErrorId, $ExceptionType, $CacheElement)
            #  Write to log
            Write-Log -Message $Message -Severity '3' -ScriptSection ${CmdletName}
            #  Throw terminating error
            $PSCmdlet.ThrowTerminatingError($ErrorRecord)
        }
        Finally {
            Write-Output -InputObject $Output
        }
    }
    End {

        ## Write verbose footer
        Write-Log -Message 'Stop' -VerboseMessage -ScriptSection ${CmdletName}
    }
}
#endregion

#region Function Get-CCMCacheInfo
Function Get-CCMCacheInfo {
<#
.SYNOPSIS
    Gets the ccm cache information.
.DESCRIPTION
    Gets the ccm cache information like cache type, status and delete flag.
.PARAMETER CacheType
    Specifies Cache Type to process. ('All', 'Application', 'Package', 'Update', 'Orphaned'). Default is: 'All'.
    If it's set to 'All' all cache will be processed.
.EXAMPLE
    Get-CCMCacheInfo -CacheType 'Application'
.INPUTS
    None.
.OUTPUTS
    None.
    System.Management.Automation.PSObject.
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    CM Client Cache
.FUNCTIONALITY
    Get ccm cache info
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateSet('All', 'Application', 'Package', 'Update', 'Orphaned')]
        [Alias('Type')]
        [string[]]$CacheType = 'All'
    )
    Begin {
        Try {

            ## Get the name of this function and write verbose header
            [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
            #  Write verbose header
            Write-Log -Message 'Start' -VerboseMessage -ScriptSection ${CmdletName}

            ## Initialize the CCM resource manager com object
            [__comobject]$CCMComObject = New-Object -ComObject 'UIResource.UIResourceMgr'

            ## Get ccm cache info
            $CacheInfo = $CCMComObject.GetCacheInfo()

            ## Get ccm cache info
            $CachedElements = $CacheInfo.GetCacheElements()

            ## Get ccm cached application info
            $ApplicationInfo = Get-CCMApplicationInfo

            ## Get ccm cached package info
            $PackageInfo = Get-CimInstance -Namespace 'Root\ccm\ClientSDK' -ClassName 'CCM_Program' -ErrorAction 'SilentlyContinue' -Verbose:$false

            ## Get ccm update list
            $UpdateInfo = Get-CimInstance -Namespace 'Root\ccm\SoftwareUpdates\UpdatesStore' -ClassName 'CCM_UpdateStatus' -ErrorAction 'SilentlyContinue' -Verbose:$false

            ## CurrentTime
            $Now = [datetime]::Now

            ## Initialize output object
            [psobject]$Output = @()
        }
        Catch {

            ## Return custom error
            $Message       = [string]"Error getting cached elements`n{0}" -f $(Resolve-Error)
            $Exception     = [Exception]::new($Message)
            $ExceptionType = [Management.Automation.ErrorCategory]::ObjectNotFound
            $ErrorRecord   = [System.Management.Automation.ErrorRecord]::new($Exception, $PSItem.FullyQualifiedErrorId, $ExceptionType, $CacheInfo)
            #  Write to log
            Write-Log -Message $Message -Severity '3' -ScriptSection ${CmdletName}
            #  Throw terminating error
            $PSCmdlet.ThrowTerminatingError($ErrorRecord)
        }
    }
    Process {
        Try {

            ## Filter cache elements by Cache Type
            $CachedElements = Switch ($CacheType) {
                'All' {
                    $CachedElements
                    Get-CCMOrphanedCache
                    Break
                }
                'Application' {
                    $CachedElements | Where-Object -Property 'ContentID' -match '^Content'
                }
                'Package' {
                    $CachedElements | Where-Object -Property 'ContentID' -match '^\w{8}$'
                }
                'Update' {
                    $CachedElements | Where-Object -Property 'ContentID' -match '^[\dA-F]{8}-(?:[\dA-F]{4}-){3}[\dA-F]{12}$'
                }
                'Orphaned' {
                    Get-CCMOrphanedCache
                }
            }

            ## Sort by CacheType
            $CachedElements = $CachedElements | Sort-Object -Property 'CacheType'

            ## Get cached element info
            ForEach ($CachedElement in $CachedElements) {

                ## Debug info
                Write-Log -Message "CurrentCachedElement: `n $($CachedElement | Out-String)" -DebugMessage -ScriptSection ${CmdletName}

                ## Get the cache info for the element using the ContentID
                Switch -Regex ($CachedElement.ContentID) {
                    '^Content' {
                        $ResolvedCacheType = 'Application'
                        $Name      = $($ApplicationInfo | Where-Object -Property 'ContentID' -eq $CachedElement.ContentID).FullName
                        Break
                    }
                    '^\w{8}$' {
                        $ResolvedCacheType = 'Package'
                        $Name      = $($PackageInfo | Where-Object -Property 'PackageID' -eq $CachedElement.ContentID).FullName
                        Break
                    }
                    '^[\dA-F]{8}-(?:[\dA-F]{4}-){3}[\dA-F]{12}$'   {
                        $ResolvedCacheType = 'Update'
                        $Name      = $($UpdateInfo | Where-Object -Property 'UniqueID' -eq $CachedElement.ContentID).Title
                        Break
                    }
                    Default {

                        ## Return custom error
                        $Message       = [string]"Invalid cache type '{0}'`n{1}" -f $($CacheType), $(Resolve-Error)
                        $Exception     = [Exception]::new($Message)
                        $ExceptionType = [Management.Automation.ErrorCategory]::NotImplemented
                        $ErrorRecord   = [System.Management.Automation.ErrorRecord]::new($Exception, $PSItem.FullyQualifiedErrorId, $ExceptionType, $CacheType)
                        #  Write to log
                        Write-Log -Message $Message -Severity '3' -ScriptSection ${CmdletName}
                        #  Throw terminating error
                        $PSCmdlet.ThrowTerminatingError($ErrorRecord)
                    }
                }

                ## Only write the info to the result object for non-orphaned cache. Orphaned cache already has this info populated.
                If ($CachedElement.CacheType -ne 'Orphaned') {
                    ## An unreferenced item is eligible for deletion if the time specified in its LastReferenceTime property is longer than the time specified in TombStoneDuration
                    If ($CachedElement.ReferenceCount -eq 0) {
                        $TombStoned          = If ($Now - $CachedElement.LastReferenceTime -ge $CacheInfo.TombStoneDuration) { $true } Else { $false }
                        $EligibleForDeletion = $TombStoned
                        $Status              = 'Cached'
                    }

                    ## A referenced item is eligible for deletion if the time specified in its LastReferenceTime property is longer than the time specified MaxCacheDuration
                    Else {
                        $TombStoned          = $false
                        $EligibleForDeletion = If ($Now - $CachedElement.LastReferenceTime -ge $CacheInfo.MaxCacheDuration) { $true } Else { $false }
                        $Status              = 'Cached'
                    }

                    ## Add new object properties
                    If ([string]::IsNullOrWhiteSpace($Name)) { $Name = 'N/A' }
                    $CachedElement | Add-Member -MemberType 'NoteProperty' -Name 'CacheType' -Value $ResolvedCacheType -ErrorAction 'SilentlyContinue'
                    $CachedElement | Add-Member -MemberType 'NoteProperty' -Name 'Name' -Value $Name -ErrorAction 'SilentlyContinue'
                    $CachedElement | Add-Member -MemberType 'NoteProperty' -Name 'TombStoned' -Value $TombStoned -ErrorAction 'SilentlyContinue'
                    $CachedElement | Add-Member -MemberType 'NoteProperty' -Name 'EligibleForDeletion' -Value $EligibleForDeletion -ErrorAction 'SilentlyContinue'
                    $CachedElement | Add-Member -MemberType 'NoteProperty' -Name 'Status' -Value $Status -ErrorAction 'SilentlyContinue'
                }

                ## Show progress bar
                Show-Progress -Status "Getting info for [$($CachedElement.CacheType)] --> [$($CachedElement.CacheElementId)]" -Steps $($CachedElements.ContentID).Count

                ## Set Output
                $Output = $CachedElements
            }
        }
        Catch {

            ## Return custom error
            $Message       = [string]"Error getting cached element '{0}'`n{1}" -f $($CachedElement.ContentID), $(Resolve-Error)
            $Exception     = [Exception]::new($Message)
            $ExceptionType = [Management.Automation.ErrorCategory]::ObjectNotFound
            $ErrorRecord   = [System.Management.Automation.ErrorRecord]::new($Exception, $PSItem.FullyQualifiedErrorId, $ExceptionType, $CachedElement)
            #  Write to log
            Write-Log -Message $Message -Severity '3' -ScriptSection ${CmdletName}
            #  Throw terminating error
            $PSCmdlet.ThrowTerminatingError($ErrorRecord)
        }
        Finally {
            Write-Output -InputObject $Output
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
    Deletes a ccm cache element.
.DESCRIPTION
    Deletes a ccm cache element by CacheElement.
.PARAMETER CacheElement
    Specifies the cache element CacheElement to process.
.PARAMETER DeletePinned
    Specifies to remove cache even if it's pinned.
.EXAMPLE
    Remove-CCMCacheElement -CacheElement $CacheElement -DeletePinned
.INPUTS
    System.Management.Automation.PSObject.
    System.Management.Automation.PSCustomObject.
.OUTPUTS
    System.Management.Automation.PSObject.
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    CM Client Cache
.FUNCTIONALITY
    Removes a ccm cache element.
#>
    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline = $true, Mandatory = $true, Position = 0)]
        [Alias('CacheItem')]
        [psobject]$CacheElement,
        [Parameter(Mandatory = $false, Position = 1)]
        [switch]$DeletePinned
    )

    Begin {
        Try {

            ## Get the name of this function and write verbose header
            [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

            #  Write verbose header
            Write-Log -Message 'Start' -VerboseMessage -ScriptSection ${CmdletName}

            ## Initialize the CCM resource manager com object
            [__comobject]$CCMComObject = New-Object -ComObject 'UIResource.UIResourceMgr'

            ## Initialize output object
            [psobject]$Output = $null
        }
        Catch {

            ## Return custom error
            $Message       = [string]"Error getting ccm cache`n{0}" -f $(Resolve-Error)
            $Exception     = [Exception]::new($Message)
            $ExceptionType = [Management.Automation.ErrorCategory]::ObjectNotFound
            $ErrorRecord   = [System.Management.Automation.ErrorRecord]::new($Exception, $PSItem.FullyQualifiedErrorId, $ExceptionType, $CacheInfo)
            #  Write to log
            Write-Log -Message $Message -Severity '3' -ScriptSection ${CmdletName}
            #  Throw terminating error
            $PSCmdlet.ThrowTerminatingError($ErrorRecord)
        }
    }
    Process {
        Try {
            If ($CacheElement.CacheElementID -eq 'N/A') {
                Try {
                    $null = Remove-Item -LiteralPath $CacheElement.Location -Recurse -Force -ErrorAction 'Stop'
                    $CacheElement.Status = 'Deleted'
                }
                Catch { $CacheElement.Status = "Delete Error" }
            }
            Else {

                ## Delete cache Element
                $null = $CCMComObject.GetCacheInfo().DeleteCacheElementEx([string]$($CacheElement.CacheElementID), [bool]$DeletePinned)
                $CacheElement.Status = 'Deleted'

                ## This is a hack making the script slower to check if the cache elment is pinned.
                #  'PersistInCache' value is no longer in use and there is no documentation about the 'DeploymentFlags'
                If ($CacheElement.CacheType -in @('Application', 'Package')) {

                    ## Check if the CacheElement has been deleted
                    $CacheInfo = ($CCMComObject.GetCacheInfo().GetCacheElements()) | Where-Object { $PSItem.CacheElementID -eq $CacheElement.CacheElementID }
                    #  If cache item still exists perform additional checks.
                    If ($CacheInfo.CacheElementID.Count -eq 1) {
                        If ($DeletePinned) { $CacheElement.Status = 'Delete Error' }
                        #  If cache item still exists and DeletePinned is not specified set the Status to 'Pinned'
                        Else { $CacheElement.Status = 'Pinned' }
                    }
                }
            }
            $Output = $CacheElement
        }
        Catch {

            ## Return custom error
            $Message       = [string]"Error deleting cache item '{0}'`n{1}" -f $($CacheElement.CacheElementID), $(Resolve-Error)
            $Exception     = [Exception]::new($Message)
            $ExceptionType = [Management.Automation.ErrorCategory]::OperationStopped
            $ErrorRecord   = [System.Management.Automation.ErrorRecord]::new($Exception, $PSItem.FullyQualifiedErrorId, $ExceptionType, $CacheElement)
            #  Write to log
            Write-Log -Message $Message -Severity '3' -ScriptSection ${CmdletName}
            #  Throw terminating error
            $PSCmdlet.ThrowTerminatingError($ErrorRecord)
        }
        Finally {
            Write-Output -InputObject $Output
        }
    }
    End {

        ## Write verbose footer
        Write-Log -Message 'Stop' -VerboseMessage -ScriptSection ${CmdletName}
    }
}
#endregion

#region Function Invoke-CCMCacheCleanup
Function Invoke-CCMCacheCleanup {
<#
.SYNOPSIS
    Cleans the configuration manager client cache.
.DESCRIPTION
    Cleans the configuration manager client cache according to the specified parameters.
.PARAMETER CacheType
    Specifies Cache Type to clean. ('All', 'Application', 'Package', 'Update', 'Orphaned'). Default is: 'All'.
    If it's set to 'All' all cache will be processed.
.PARAMETER CleanupType
    Specifies Cleanup Type to clean. ('All', 'Automatic', 'ListOnly', 'Tombstoned', 'Referenced'). Default is: 'Automatic'.
    If 'All', 'Automatic' or 'ListOnly' is selected the other options will be ignored.
    An 'Referenced' item is eligible for deletion if the time specified in its 'LastReferenceTime' property is longer than the time specified 'MaxCacheDuration'.
    An 'Unreferenced' item is eligible for deletion if the time specified in its 'LastReferenceTime' property is longer than the time specified in 'TombStoneDuration'.

    Available Cleanup Options:
        - 'All'
            Tombstoned and Referenced cache will be deleted, 'SkipSuperPeer' and 'DeletePinned' switches will still be respected.
            The 'EligibleForDeletion' convention is NOT respected.
            Not recommended but still safe to use, cache will be redownloaded when needed
        - 'Automatic'
            'Tombstoned' and 'Referenced' will be selected depending on 'FreeDiskSpaceThreshold' parameter.
            If under threshold only 'Tombstoned' cache items will be deleted.
            If over threshold, both 'Tombstoned' and 'Referenced' cache items will be deleted.
            The 'EligibleForDeletion' convention is still respected.
        - 'Tombstoned'
            Only 'Tombstoned' cache items will be deleted.
            The 'EligibleForDeletion' convention is still respected.
        - 'Referenced'
            Only 'Referenced' cache items will be deleted.
            The 'EligibleForDeletion' convention is still respected.
            Not recommended but still safe to use, cache will be redownloaded when needed
.PARAMETER DeletePinned
    This switch specifies to remove cache even if it's pinned (Applications and Packages). Default is: $false.
.EXAMPLE
    Invoke-CCMCacheCleanup -CacheType "Application, Package, Update, Orphaned" -CleanupType "Tombstoned, Referenced" -DeletePinned
.INPUTS
    None.
.OUTPUTS
    System.Management.Automation.PSObject.
.NOTES
    Created by Ioan Popovici
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    CM Client
.FUNCTIONALITY
    Clean CM Client Cache
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateSet('All', 'Application', 'Package', 'Update', 'Orphaned')]
        [Alias('Type')]
        [string[]]$CacheType = 'All',
        [Parameter(Mandatory = $false, Position = 1)]
        [ValidateSet('All', 'Automatic', 'ListOnly', 'Tombstoned', 'Referenced')]
        [Alias('Action')]
        [string[]]$CleanupType = 'Automatic',
        [Parameter(Mandatory = $false, Position = 2)]
        [ValidateNotNullorEmpty()]
        [Alias('FreeSpace')]
        [int16]$FreeDiskSpaceThreshold = 100,
        [Parameter(Mandatory = $false, Position = 3)]
        [switch]$SkipSuperPeer,
        [Parameter(Mandatory = $false, Position = 4)]
        [switch]$DeletePinned
    )

    Begin {

        ## Get the name of this function and write verbose header
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

        #  Write verbose header
        Write-Log -Message 'Start' -VerboseMessage -ScriptSection ${CmdletName}

        ## Initialize output object
        [psobject]$Output = $null
    }
    Process {
        Try {

            ## Get cache elements info according to selected options
            [psobject]$CacheElements = Switch ($CacheType) {
                'All' {
                    Get-CCMCacheInfo -CacheType 'All' -ErrorAction 'Stop'
                    Break
                }
                'Application' {
                    Get-CCMCacheInfo -CacheType 'Application' -ErrorAction 'Stop'
                }
                'Package' {
                    Get-CCMCacheInfo -CacheType 'Package' -ErrorAction 'Stop'
                }
                'Update' {
                    Get-CCMCacheInfo -CacheType 'Update' -ErrorAction 'Stop'
                }
                'Orphaned' {
                    Get-CCMCacheInfo -CacheType 'Orphaned' -ErrorAction 'Stop'
                }
            }

            ## Remove null objects from array (should not be needed)
            $CacheElements = $CacheElements | Where-Object { $null -ne $PSItem }

            ## Set Script Block
            [scriptblock]$CleanupCacheSB = {
                Show-Progress -Status "[$PSitem] Cache Deletion for [$($CacheElement.CacheType)] --> [$($CacheElement.CacheElementID)]" -Steps ($CacheElements.ContentID).Count
                Remove-CCMCacheElement -CacheElement $CacheElement -DeletePinned:$DeletePinned
            }

            ## Process cache elements
            $Output = ForEach ($CacheElement in $CacheElements) {
                If ($CacheElement.EligibleForDeletion -or $CleanupType -contains 'All' -or $CleanupType -contains 'ListOnly') {
                    Switch ($CleanupType) {
                        'All' {
                            $CleanupCacheSB.Invoke()
                            Break
                        }
                        'Automatic' {
                            If ($DriveFreeSpacePercentage -gt $FreeDiskSpaceThreshold) {
                                If ($CacheElement.TombStoned) {
                                    $CleanupCacheSB.Invoke()
                                }
                            }
                            Else {
                                $CleanupCacheSB.Invoke()
                            }
                            Break
                        }
                        'ListOnly' {
                            $CacheElement
                            Break
                        }
                        'TombStoned' {
                            If ($CacheElement.TombStoned) {
                                $CleanupCacheSB.Invoke()
                            }
                        }
                        'Referenced' {
                            If ($CacheElement.ReferenceCount -gt 0) {
                                $CleanupCacheSB.Invoke()
                            }
                        }
                        Default {

                            ## Return custom error
                            $Message       = [string]"Invalid cache type '{0}'`n{1}" -f $($CacheElement.CacheType), $(Resolve-Error)
                            $Exception     = [Exception]::new($Message)
                            $ExceptionType = [Management.Automation.ErrorCategory]::OperationStopped
                            $ErrorRecord   = [System.Management.Automation.ErrorRecord]::new($Exception, $PSItem.FullyQualifiedErrorId, $ExceptionType, $CacheElement)
                            #  Write to log
                            Write-Log -Message $Message -Severity '3' -ScriptSection ${CmdletName}
                            #  Throw terminating error
                            $PSCmdlet.ThrowTerminatingError($ErrorRecord)
                        }
                    }
                }
            }
        }
        Catch {

            ## Return custom error
            $Message       = [string]"Error proccessing cache for removal '{0}'`n{1}" -f $($CacheElement.CacheElementID), $(Resolve-Error)
            $Exception     = [Exception]::new($Message)
            $ExceptionType = [Management.Automation.ErrorCategory]::OperationStopped
            $ErrorRecord   = [System.Management.Automation.ErrorRecord]::new($Exception, $PSItem.FullyQualifiedErrorId, $ExceptionType, $CacheElement)
            #  Write to log
            Write-Log -Message $Message -Severity '3' -ScriptSection ${CmdletName}
            #  Throw terminating error
            $PSCmdlet.ThrowTerminatingError($ErrorRecord)
        }
        Finally {
            Write-Output -InputObject $Output
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
    $CanBeSuperPeer = [boolean]$(Get-CimInstance -Namespace 'root\ccm\Policy\Machine\ActualConfig' -ClassName 'CCM_SuperPeerClientConfig' -Verbose:$false -ErrorAction 'SilentlyContinue').CanBeSuperPeer

    ## Set run condition. If disk free space is above the specified threshold or CanBeSuperPeer is true and SkipSuperPeer is not specified, the script will not run.
    If (($DriveFreeSpacePercentage -gt $FreeDiskSpaceThreshold -or $CleanupType -notcontains 'Automatic') -or ($CanBeSuperPeer -eq $true -and $SkipSuperPeer)) { $ShouldRun = $false }

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
    Throw "Script initialization failed. $($PSItem.Exception.Message)"
}
Try {

    ## Set the script section
    [string]${ScriptSection} = 'Main:CacheCleanup'

    ## Write debug action
    Write-Log -Message "Cleanup Actions [$CleanupType] on [$CacheType]" -DebugMessage -ScriptSection ${ScriptSection}

    $Output = Invoke-CCMCacheCleanup -CacheType $CacheType -CleanupType $CleanupType -DeletePinned:$DeletePinned
}
Catch {
    Write-Log -Message "Could not perform cleanup action. `n$(Resolve-Error)" -Severity '3' -ScriptSection ${ScriptSection}
    Throw "Could not perform cleanup action. `n$($PSItem.Exception.Message)"
}
Finally {

    ## Set the script section
    [string]${ScriptSection} = 'Main:Output'

    ## Calculate total deleted size
    $TotalDeletedSize = ($Output | Where-Object { $PSItem.Status -eq 'Deleted' } | Measure-Object -Property 'ContentSize' -Sum | Select-Object -ExpandProperty 'Sum') * 1000 | Format-Bytes
    If (-not $TotalDeletedSize) { $TotalDeletedSize = 0 }

    ## Assemble output output
    $Output = $($Output | Format-List -Property 'CacheType', 'Name', 'Location', 'ContentSize', 'CacheElementID', 'Status' | Out-String) + "Total Deleted: " + $TotalDeletedSize

    ## Write output to log, event log and console and status
    Write-Log -Message $Output -ScriptSection ${ScriptSection} -PassThru

    ## Write verbose stop
    Write-Log -Message 'Stop' -VerboseMessage -ScriptSection ${ScriptSection}
}