<#
.SYNOPSIS
    Updates a Configuration Manager Software Update Group.
.DESCRIPTION
    Updates a Configuration Manager Software Update Group according to the provided parameters.
.PARAMETER SoftwareUpdateGroupName
    Specifies the name of the Software Update Group.
.PARAMETER SoftwareUpdateCategoryName
    Specifies the name of the Software Update Category.
    Default is: 'Security Updates'.
.PARAMETER SoftwareUpdateCategoryNameMatch
    Specifies the name or names of the Software Update Category to match. This is a regular expression.
    Default is: 'Windows 10|Windows 11|Office 2016|Office 2019|Office 2021|Visual Studio|ASP.NET'.
.PARAMETER SoftwareUpdateNameNotMatch
    Specifies the name of the Software Update Title to exclude. This is a regular expression.
    Default is: 'Server'.
.PARAMETER SoftwareUpdatesRequiredMinimum
    Specifies the minimum number of devices that require the software update.
    Default is: 1.
.PARAMETER SoftwareUpdateReleasedOrRevisedBefore
    Specifies the date before which the software update was released or revised.
    Default is: Get-Date.
.PARAMETER SoftwareUpdateReleasedOrRevisedAfter
    Specifies the date after which the software update was released or revised.
    Default is: Get-PatchTuesday.
.EXAMPLE
    Invoke-UpdateCMSoftwareUpdateGroup -SoftwareUpdateGroupName 'Software Update Group' -SoftwareUpdateCategoryName 'Security Updates' -SoftwareUpdateCategoryNameMatch 'Windows 10|Windows 11|Office 2016|Office 2019|Office 2021|Visual Studio|ASP.NET' -SoftwareUpdateNameNotMatch 'Server' -SoftwareUpdatesRequiredMinimum 1
.EXAMPLE
    Invoke-UpdateCMSoftwareUpdateGroup -SoftwareUpdateGroupName 'Software Update Group' -SoftwareUpdateCategoryName 'Security Updates' -SoftwareUpdateCategoryNameMatch 'Windows 10|Windows 11|Office 2016|Office 2019|Office 2021|Visual Studio|ASP.NET' -SoftwareUpdateNameNotMatch 'Server' -SoftwareUpdatesRequiredMinimum 1 -SoftwareUpdateReleasedOrRevisedAfter '2024-01-01'
.INPUTS
    None.
.OUTPUTS
    None.
.NOTES
    Created by Ioan Popovici.
    v1.0.0 - 2024-03-15
.LINK
    https://MEMZ.one/Invoke-UpdateCMSoftwareUpdateGroup
.LINK
    https://MEMZ.one/Invoke-UpdateCMSoftwareUpdateGroup-CHANGELOG
.LINK
    https://MEMZ.one/Invoke-UpdateCMSoftwareUpdateGroup-GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    Configuration Manager
.FUNCTIONALITY
    Updates a Software Update Group.
#>

## Set script requirements
#Requires -Version 5.0

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

## Get script parameters
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNullorEmpty()]
    [string]$SoftwareUpdateGroupName,
    [Parameter(Mandatory = $false, Position = 1)]
    [ValidateNotNullorEmpty()]
    [string]$SoftwareUpdateCategoryName = 'Security Updates',
    [Parameter(Mandatory = $false, Position = 2)]
    [ValidateNotNullorEmpty()]
    [string]$SoftwareUpdateCategoryNameMatch = 'Windows 10|Windows 11|Office 2016|Office 2019|Office 2021|Visual Studio|ASP.NET',
    [Parameter(Mandatory = $false, Position = 3)]
    [ValidateNotNullorEmpty()]
    [string]$SoftwareUpdateNameNotMatch = 'Server',
    [Parameter(Mandatory = $false, Position = 4)]
    [ValidateNotNullorEmpty()]
    [int]$SoftwareUpdatesRequiredMinimum = 1,
    [Parameter(Mandatory = $false, Position = 5)]
    [ValidateNotNullorEmpty()]
    [datetime]$SoftwareUpdateReleasedOrRevisedBefore = (Get-Date),
    [Parameter(Mandatory = $false, Position = 6)]
    [ValidateNotNullorEmpty()]
    [datetime]$SoftwareUpdateReleasedOrRevisedAfter = '01-01-1980 00:00:00'
)

## Get script path and name
[string]$ScriptName     = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Definition)
[string]$ScriptFullName = [System.IO.Path]::GetFullPath($MyInvocation.MyCommand.Definition)
[string]$ScriptPath     = [System.IO.Path]::GetDirectoryName($ScriptFullName)

## Get Show-Progress steps
$ProgressSteps = $(([System.Management.Automation.PsParser]::Tokenize($(Get-Content -Path $ScriptFullName), [ref]$null) | Where-Object { $_.Type -eq 'Command' -and $_.Content -eq 'Show-Progress' }).Count)
$ForEachSteps  = $(([System.Management.Automation.PsParser]::Tokenize($(Get-Content -Path $ScriptFullName), [ref]$null) | Where-Object { $_.Type -eq 'Keyword' -and $_.Content -eq 'ForEach' }).Count)

## Set Show-Progress steps
$script:Steps = $ProgressSteps - $ForEachSteps
$script:Step  = 1

## Set script global variables
$script:LoggingOptions   = @('EventLog', 'File')
$script:LogName          = 'Endpoint Management'
$script:LogSource        = $ScriptName
$script:LogDebugMessages = $false
$script:LogFileDirectory = $ScriptPath

## Initialize output object
$Output = [pscustomobject]@{
    SoftwareUpdateID        = 'N/A'
    SoftwareUpdateName      = 'N/A'
    SoftwareUpdateGroupName = $SoftwareUpdateGroupName
    Status = 'N/A'
}

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
    The heading for the portion of the script that is being executed. Default is: $script:scriptSection.
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
        [string]$ScriptSection = $script:ScriptSection,
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
        [int]$MaxLogFileSizeMB = 5,
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
        If ('Host' -in $LoggingOptions -and -not ($VerboseMessage -or $DebugMessage)) { $WriteHost = $true }
        If ('File' -in $LoggingOptions) { $WriteFile = $true }
        If ('EventLog' -in $LoggingOptions) { $WriteEvent = $true }
        If ('None' -in $LoggingOptions) { $DisableLogging = $true }
        #  Check if the script section is defined
        [boolean]$ScriptSectionDefined = $(-not [string]::IsNullOrEmpty($ScriptSection))
        #  Check if the source is defined
        [boolean]$SourceDefined = $(-not [string]::IsNullOrEmpty($Source))
        #  Check if the log name is defined
        [boolean]$LogNameDefined = $(-not [string]::IsNullOrEmpty($LogName))
        #  Check for overlapping log names if the log name does not exist
        If ($SourceDefined -and $LogNameDefined) {
        #  Check if the event log and event source exist
        [boolean]$LogNameNotExists = (-not [System.Diagnostics.EventLog]::Exists($LogName))
        [boolean]$LogSourceNotExists = (-not [System.Diagnostics.EventLog]::SourceExists($Source))
        #  Check for overlapping log names. The first 8 characters of the log name must be unique.
            If ($LogNameNotExists) {
                [string[]]$OverLappingLogName = Get-EventLog -List | Where-Object -Property 'Log' -Like  $($LogName.Substring(0,8) + '*') | Select-Object -ExpandProperty 'Log'
                If (-not [string]::IsNullOrEmpty($OverLappingLogName)) {
                    Write-Warning -Message "Overlapping log names:`n$($OverLappingLogName | Out-String)"
                    Write-Warning -Message 'Change the name of your log or use Remove-EventLog to remove the log(s) above!'
                }
            }
        }
        Else { Write-Warning -Message 'No Source '$Source' or Log Name '$LogName' defined. Skipping event log logging...' }

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
            If ($WriteEvent -and $SourceDefined -and $LogNameDefined) {
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
                $null = New-Item -Path $LogFileDirectory -Type 'Directory' -Force -ErrorAction 'Stop' -WhatIf:$false
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
                #  Create Event log message and shorten it to the maximum 32766 characters supported by the event log
                [string]$EventLogLine = [System.Math]::Max(32763, $Msg.Length) + '...'

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
            If ((-not $ExitLoggingFunction) -and (-not $DisableLogging)) {
                If ($WriteFile) {
                    ## Write to file log
                    Try {
                        $LogLine | Out-File -FilePath $LogFilePath -Append -NoClobber -Force -Encoding 'UTF8' -ErrorAction 'Stop' -WhatIf:$false
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
                    [hashtable]$ArchiveLogParams = @{ ScriptSection = ${CmdletName}; Source = $Source; Severity = 2; LogFileDirectory = $LogFileDirectory; LogFileName = $LogFileName; LogType = $LogType; MaxLogFileSizeMB = 0; ContinueOnError = $ContinueOnError; PassThru = $false }

                    ## Log message about archiving the log file
                    $ArchiveLogMessage = "Maximum log file size [$MaxLogFileSizeMB MB] reached. Rename log file to [$ArchivedOutLogFile]."
                    Write-Log -Message $ArchiveLogMessage @ArchiveLogParams

                    ## Archive existing log file from <filename>.log to <filename>.lo_. Overwrites any existing <filename>.lo_ file. This is the same method SCCM uses for log files.
                    Move-Item -LiteralPath $LogFilePath -Destination $ArchivedOutLogFile -Force -ErrorAction 'Stop' -WhatIf:$false

                    ## Start new log file and Log message about archiving the old log file
                    $NewLogMessage = "Previous log file was renamed to [$ArchivedOutLogFile] because maximum log file size of [$MaxLogFileSizeMB MB] was reached."
                    Write-Log -Message $NewLogMessage @ArchiveLogParams
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
    Specifies the progress activity. Default: $script:Activity.
.PARAMETER Status
    Specifies the progress status.
.PARAMETER CurrentOperation
    Specifies the current operation.
.PARAMETER Step
    Specifies the progress step. Default: $script:Step ++.
.PARAMETER Steps
    Specifies the progress steps. Default: $script:Steps ++.
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
    $script:Steps = $ProgressSteps - $ForEachSteps
    $script:Step = 0
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
        [string]$Activity = $script:Activity,
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
        [int]$Step = $script:Step ++,
        [Parameter(Mandatory=$false,Position=5)]
        [ValidateNotNullorEmpty()]
        [Alias('sts')]
        [int]$Steps = $script:Steps,
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
                $script:Step ++
                $Steps ++
                $script:Steps ++
            }
            If ($Steps -eq 0) {
                $Steps ++
                $script:Steps ++
            }

            [boolean]$Completed = $false
            [int]$PercentComplete = $($($Step / $Steps) * 100)

            If ($PercentComplete -ge 100)  {
                $PercentComplete = 100
                $Completed = $true
                $script:CurrentStep ++
                $script:Step = $script:CurrentStep
                $script:Steps = $script:DefaultSteps
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

#region Function Get-PatchTuesday
Function Get-PatchTuesday {
<#
.SYNOPSIS
    Get Microsoft patch Tuesday.
.DESCRIPTION
    Get Microsoft patch Tuesday for a specific month and return it to the pipeline.
.PARAMETER Year
    Set the year for which to calculate Patch Tuesday.
.PARAMETER Month
    Set the month for which to calculate Patch Tuesday.
.EXAMPLE
    Get-PatchTuesday
.EXAMPLE
    Get-PatchTuesday -Year 2015 -Month 3
.INPUTS
    System.String
.OUTPUTS
    System.DateTime.
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.COMPONENT
    Configuration Manager
.FUNCTIONALITY
    Get patch tuesday
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $false, Position = 0)]
        [Alias('Yr')]
        [string]$Year = (Get-Date).Year,
        [Parameter(Mandatory = $false, Position = 1)]
        [Alias('Mo')]
        [string]$Month = (Get-Date).Month
    )
    Begin {

        ## Build Target Month
        [DateTime]$StartingMonth = $Month + '/1/' + $Year
    }
    Process {

        ## Search for First Tuesday
        While ($StartingMonth.DayofWeek -ine 'Tuesday') {
            $StartingMonth = $StartingMonth.AddDays(1)
        }

        ## Set Second Tuesday of the month by adding 7 days
        $PatchTuesday = $StartingMonth.AddDays(7)

        ## Return Patch Tuesday
        Return $PatchTuesday
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

    ## Set the script section
    [string]${ScriptSection} = 'Main:Initialization'

    ## Write Start verbose message
    Write-Log -Message 'Start' -VerboseMessage -ScriptSection ${ScriptSection}

    ## Set script parameter values
    [datetime]$DatePostedMin =  If ($SoftwareUpdateReleasedOrRevisedAfter -eq [datetime]'01-01-1980 00:00:00') { Get-PatchTuesday } Else { $SoftwareUpdateReleasedOrRevisedAfter }
    [datetime]$DateRevisedMin = $DatePostedMin
    [datetime]$DatePostedMax = $SoftwareUpdateReleasedOrRevisedBefore
    [datetime]$DateRevisedMax = $DatePostedMax

    ## Import the configuration manager module
    Import-Module $env:SMS_ADMIN_UI_PATH.Replace('\bin\i386','\bin\configurationmanager.psd1') -ErrorAction 'Stop' -Verbose:$false

    ## Get the site code
    $SiteLocation = (Get-PSDrive -PSProvider 'CMSITE').Name + ':\'

    ## Change context to the site
    Push-Location $SiteLocation -Verbose:$false

    ## Get all updates
    Write-Verbose -Message "Getting all matching updates from the Configuration Manager site server. This might take a while..." -Verbose
    $AllSoftwareUpdates = Get-CMSoftwareUpdate -IsContentProvisioned $True -IsExpired $False -IsSuperseded $False -DatePostedMin $DatePostedMin -DateRevisedMin $DateRevisedMin -DatePostedMax $DatePostedMax -DateRevisedMax $DateRevisedMax -Fast -ErrorAction 'Stop' -Verbose:$false
    Write-Log -Message $("Found '{0}' Updates matching specified parameters.`n{1}" -f $AllSoftwareUpdates.Count, $($AllSoftwareUpdates.LocalizedDisplayName | Out-String)) -VerboseMessage -ScriptSection ${ScriptSection}
}
Catch {
    ## Return to previous location
    Pop-Location

    ## Write error to log
    Write-Log -Message "Script initialization failed. `n$(Resolve-Error)" -Severity '3' -ScriptSection ${ScriptSection}
    Throw "Script initialization failed. $($PSItem.Exception.Message)"
}
Try {

    ## Set the script section
    [string]${ScriptSection} = 'Main:UpdateGroup'

    ## Filter updates in scope
    $SoftwareUpdatesInScope = $AllSoftwareUpdates.Where({
        $PSItem.LocalizedCategoryInstanceNames -contains $SoftwareUpdateCategoryName -and
        $PSItem.LocalizedCategoryInstanceNames -match $SoftwareUpdateCategoryNameMatch -and
        $PSItem.LocalizedDisplayName -notmatch $SoftwareUpdateNameNotMatch -and
        $PSItem.NumMissing -ge $SoftwareUpdatesRequiredMinimum
    })
    Write-Log -Message $("Found '{0}' Updates in Scope.`n{1}" -f $SoftwareUpdatesInScope.Count, $($SoftwareUpdatesInScope.LocalizedDisplayName | Out-String)) -VerboseMessage -LoggingOptions 'File' -ScriptSection ${ScriptSection}

    ## Return to the pipeline if no updates in scope are found
    If ($SoftwareUpdatesInScope.Count -eq 0) { Return }

    ## Get Software Update Group Updates
    $SoftwareUpdatesInGroup = Get-CMSoftwareUpdate -UpdateGroupName $SoftwareUpdateGroupName -Fast -Verbose:$false
    #  Add a placeholder CI_ID if the Update group is empty so we can still do the comparison
    If ($SoftwareUpdatesInGroup.Count -eq 0) { $SoftwareUpdatesInGroup = [psobject]@{CI_ID = ''} }

    ## Compare All Software Updates with the updates in Group and remove the null CI_ID added if the software update group is empty
    $SoftwareUpdates = Compare-Object -ReferenceObject $SoftwareUpdatesInScope -DifferenceObject $SoftwareUpdatesInGroup -Property 'CI_ID' -IncludeEqual -Verbose:$false | Where-Object -Property 'CI_ID' -ne $null

    ## Process Software Updates
    [int]$Steps = $SoftwareUpdates.Count
    [int]$Step = 1

    $Output = ForEach ($SoftwareUpdate in $SoftwareUpdates) {
        $Status = 'N/A'
        $SoftwareUpdateID = $SoftwareUpdate.CI_ID
        #  Get Software Update Name
        $SoftwareUpdateName = $SoftwareUpdatesInGroup.Where({ $PSItem.CI_ID -eq $SoftwareUpdateID }).LocalizedDisplayName
        If ([string]::IsNullOrWhiteSpace($SoftwareUpdateName)) {
            $SoftwareUpdateName = $SoftwareUpdatesInScope.Where({ $PSItem.CI_ID -eq $SoftwareUpdateID }).LocalizedDisplayName
        }
        #  Process Software Updates according to the comparison result
        Show-Progress -Activity "Updating Software Update Group [$SoftwareUpdateGroupName]..." -Status "Processing Update [$Step/$Steps] --> [$SoftwareUpdateName]" -Steps $Steps -Step $Step
        Switch ($SoftwareUpdate.SideIndicator) {
            '<=' {
                Show-Progress -Activity "Updating Software Update Group [$SoftwareUpdateGroupName]..." -Status "Processing Update [$Step/$Steps] --> Adding [$SoftwareUpdateName]" -Steps $Steps -Step $Step
                Add-CMSoftwareUpdateToGroup -SoftwareUpdateID $SoftwareUpdateID -SoftwareUpdateGroupName $SoftwareUpdateGroupName -DisableWildcardHandling -ErrorAction 'Stop' -Verbose:$false
                $Status = 'Added'
            }
            '=>' {
                Show-Progress -Activity "Updating Software Update Group [$SoftwareUpdateGroupName]..." -Status "Processing Update [$Step/$Steps] --> Removing [$SoftwareUpdateName]" -Steps $Steps -Step $Step
                Remove-CMSoftwareUpdateFromGroup -SoftwareUpdateID $SoftwareUpdateID -SoftwareUpdateGroupName $SoftwareUpdateGroupName -DisableWildcardHandling -Force -ErrorAction 'Stop' -Verbose:$false
                $Status = 'Removed'
            }
            '==' {
                Show-Progress -Activity "Updating Software Update Group [$SoftwareUpdateGroupName]..." -Status "Processing Update [$Step/$Steps] --> Skipping [$SoftwareUpdateName]" -Steps $Steps -Step $Step
                $Status = 'Skipped'
            }
        }
        $Step++
        [PSCustomObject]@{
            SoftwareUpdateID        = $SoftwareUpdateID
            SoftwareUpdateName      = $SoftwareUpdateName
            SoftwareUpdateGroupName = $SoftwareUpdateGroupName
            Status = $Status
        }
    }
}
Catch {
    Write-Log -Message "Failed to process Software Updates in Group [$SoftwareUpdateGroupName]. `n$(Resolve-Error)" -Severity 3 -ScriptSection ${ScriptSection}
    Write-Error -Message "Failed to Update Software Update Group `n$($PSItem.Exception.Message)"
}
Finally {

    ## Assemble output
    [int]$Added   = $($Output | Where-Object -Property 'Status' -eq 'Added'  ).Count
    [int]$Removed = $($Output | Where-Object -Property 'Status' -eq 'Removed').Count
    [int]$Skipped = $($Output | Where-Object -Property 'Status' -eq 'Skipped').Count
    [int]$Total   = $Added + $Removed + $Skipped
    $Output = $($Output | Format-List -Property 'SoftwareUpdateID', 'SoftwareUpdateName', 'SoftwareUpdateGroupName', 'Status' | Out-String) + "`nAdded: " + $Added + "`nRemoved: " + $Removed + "`nSkipped: " + $Skipped + "`nTotal : " + $Total

    ## Write output to log, event log and console and status
    Write-Log -Message $Output -PassThru -ScriptSection ${ScriptSection}

    ## Write Stop verbose message
    Write-Log -Message 'Stop' -VerboseMessage -ScriptSection ${ScriptSection}

    ## Return to the previous location
    Pop-Location
}

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================
