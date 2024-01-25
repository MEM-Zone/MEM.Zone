<#
.SYNOPSIS
    Renames an Intune device.
.DESCRIPTION
    Renames an Intune device according to a specified naming convention.
.PARAMETER TenantID
    Specifies the tenant ID.
.PARAMETER ApplicationID
    Specifies the application ID.
.PARAMETER ApplicationSecret
    Specifies the application secret.
.PARAMETER DeviceName
    Specifies the device name to be processed.
    Default is: 'All'.
.PARAMETER DeviceOS
    Specifies the device OS to be processed
    Valid values are: Windows, macOS or Linux.
    Default is: 'All'.
.PARAMETER Prefix
    Specifies the prefix to be used. Please note that it will be truncated to 6 characters and converted to UPPERCASE.
    If this parameter is used, the PrefixFromUserAttribute parameter will be ignored.
    Default is: 'INTUNE'.
.PARAMETER PrefixFromUserAttribute
    Specifies the user attribute to be used queried and used as prefix. The result will be truncated to 6 characters.
    If this parameter is used, the Prefix parameter will be ignored.
.EXAMPLE
    Rename-IntuneDevice.ps1 -TenantID $TenantID -ApplicationID $ApplicationID -ApplicationSecret $ApplicationSecret -DeviceName 'IntuneDevice001' -WhatIf -Verbose
.EXAMPLE
    Rename-IntuneDevice.ps1 -TenantID $TenantID -ApplicationID $ApplicationID -ApplicationSecret $ApplicationSecret -DeviceOS $DeviceOS -Prefix 'TAG'
.EXAMPLE
    Rename-IntuneDevice.ps1 -TenantID $TenantID -ApplicationID $ApplicationID -ApplicationSecret $ApplicationSecret -DeviceOS $DeviceOS -PrefixFromUserAttribute 'extension_11db5763783a4e822bd6dsd1826184312_msDS_cloudExtensionAttribute66'
.EXAMPLE
    Rename-IntuneDevice.ps1 -TenantID $TenantID -ApplicationID $ApplicationID -ApplicationSecret $ApplicationSecret -DeviceOS $DeviceOS -Confirm
.INPUTS
    None.
.OUTPUTS
    None.
.NOTES
    Created by Ferry Bodijn
    Rewritten by Ioan Popovici to add parameters, improve logging and simplify the script. All other functionality remains the same.
    v1.0.0 - 2021-09-01

    Supports WhatIf and Confirm, see links below for more information.
.LINK
    https://MEMZ.one/Rename-IntuneDevice
.LINK
    https://MEMZ.one/Rename-IntuneDevice-CHANGELOG
.LINK
    https://MEMZ.one/Rename-IntuneDevice-GIT
.LINK
    https://MEM.Zone/ISSUES
.LINK
    https://learn.microsoft.com/en-us/powershell/scripting/learn/deep-dives/everything-about-shouldprocess?view=powershell-7.3#using--whatif
.COMPONENT
    MSGraph
.FUNCTIONALITY
    Renames device in Intune.
#>

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

## Set script requirements
#Requires -Version 5.0

## Get script parameters
[CmdletBinding(SupportsShouldProcess=$true, DefaultParameterSetName = 'Custom')]
Param (
    [Parameter(Mandatory = $true, ParameterSetName = 'Custom', HelpMessage = 'Specify the tenant ID', Position = 0)]
    [Parameter(Mandatory = $true, ParameterSetName = 'UserAttribute', HelpMessage = 'Enter the tenant ID', Position = 0)]
    [ValidateNotNullorEmpty()]
    [Alias('Tenant')]
    [string]$TenantID,
    [Parameter(Mandatory = $true, ParameterSetName = 'Custom', HelpMessage = 'Specify the Application (Client) ID to use.', Position = 1)]
    [Parameter(Mandatory = $true, ParameterSetName = 'UserAttribute', HelpMessage = 'Specify the Application (Client) ID to use.', Position = 1)]
    [ValidateNotNullorEmpty()]
    [Alias('ApplicationClientID')]
    [string]$ClientID,
    [Parameter(Mandatory = $true, ParameterSetName = 'Custom', HelpMessage = 'Specify the Application (Client) Secret to use.', Position = 2)]
    [Parameter(Mandatory = $true, ParameterSetName = 'UserAttribute', HelpMessage = 'Specify the Application (Client) Secret to use.', Position = 2)]
    [ValidateNotNullorEmpty()]
    [Alias('ApplicationClientSecret')]
    [string]$ClientSecret,
    [Parameter(Mandatory = $false, ParameterSetName = 'Custom', HelpMessage = 'Specify the device name to be processed. Supports wildcard characters. Default is: All', Position = 3)]
    [Parameter(Mandatory = $false, ParameterSetName = 'UserAttribute', HelpMessage = 'Specify the device name to be processed. Supports wildcard characters. Default is: All', Position = 3)]
    [ValidateNotNullorEmpty()]
    [Alias('Device')]
    [string]$DeviceName = 'All',
    [Parameter(Mandatory = $false, ParameterSetName = 'Custom', HelpMessage = 'Specify the device OS to be processed. Valid values are: Windows, macOS, Linux, All', Position = 4)]
    [Parameter(Mandatory = $false, ParameterSetName = 'UserAttribute', HelpMessage = 'Specify the device OS to be processed. Valid values are: Windows, macOS, Linux, All', Position = 4)]
    [ValidateSet('Windows', 'macOS', 'Linux')]
    [string]$DeviceOS = 'All',
    [Parameter(Mandatory = $false, ParameterSetName = 'Custom', HelpMessage = 'Specify the prefix to be used. Default isL INTUNE', Position = 5)]
    [ValidateNotNullorEmpty()]
    [string]$Prefix = 'INTUNE',
    [Parameter(Mandatory = $true, ParameterSetName = 'UserAttribute', HelpMessage = 'Specify the user attribute to be used queried and used as prefix. The result will be truncated to 6 characters.', Position = 5)]
    [ValidateNotNullorEmpty()]
    [Alias('UserAttribute')]
    [string]$PrefixFromUserAttribute
)

## Get script path and name
[string]$ScriptName     = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Definition)
[string]$ScriptFullName = [System.IO.Path]::GetFullPath($MyInvocation.MyCommand.Definition)

## Get Show-Progress steps
$ProgressSteps = $(([System.Management.Automation.PsParser]::Tokenize($(Get-Content -Path $ScriptFullName), [ref]$null) | Where-Object { $_.Type -eq 'Command' -and $_.Content -eq 'Show-Progress' }).Count)
$ForEachSteps  = $(([System.Management.Automation.PsParser]::Tokenize($(Get-Content -Path $ScriptFullName), [ref]$null) | Where-Object { $_.Type -eq 'Keyword' -and $_.Content -eq 'ForEach' }).Count)

## Set Show-Progress steps
$script:Steps = $ProgressSteps - $ForEachSteps
$script:Step  = 1

## Set script global variables
$script:LoggingOptions   = @('EventLog', 'File', 'Host')
$script:LogName          = 'Endpoint Management'
$script:LogSource        = $ScriptName
$script:LogDebugMessages = $false
$script:LogFileDirectory = If ($LogPath) { Join-Path -Path $LogPath -ChildPath $script:LogName } Else { $(Join-Path -Path $Env:WinDir -ChildPath $('\Logs\' + $script:LogName)) }

## Initialize script variables
If (-not $PSBoundParameters['DeviceName']) { $DeviceName = 'All' }

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
    Specifies the progress activity. Default: 'Cleaning Up Configuration Manager Client Cache, Please Wait...'.
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

#region Function Get-MSGraphAccessToken
Function Get-MSGraphAccessToken {
<#
.SYNOPSIS
    Gets a Microsoft Graph API access token.
.DESCRIPTION
    Gets a Microsoft Graph API access token,by using an application registered in EntraID.
.PARAMETER TenantID
    Specifies the tenant ID.
.PARAMETER ClientID
    Specify the Application Client ID to use.
.PARAMETER Secret
    Specify the Application Client Secret to use.
.PARAMETER Scope
    Specify the scope to use.
    Default is: 'https://graph.microsoft.com/.default'.
.PARAMETER GrantType
    Specify the grant type to use.
    Default is: 'client_credentials'.
.EXAMPLE
    Get-MSGraphAccessToken -TenantID $TenantID -ClientID $ClientID -Secret $Secret
.INPUTS
    None.
.OUTPUTS
    System.String
.NOTES
    Created by Ioan Popovici
    v1.0.0 - 2024-01-11

    This is an private function should tipically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    MSGraph
.FUNCTIONALITY
    Invokes the Microsoft Graph API.
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = 'Specify the tenant ID.', Position = 0)]
        [ValidateNotNullorEmpty()]
        [Alias('Tenant')]
        [string]$TenantID,
        [Parameter(Mandatory = $true, HelpMessage = 'Specify the Application (Client) ID to use.', Position = 1)]
        [ValidateNotNullorEmpty()]
        [Alias('ApplicationClientID')]
        [string]$ClientID,
        [Parameter(Mandatory = $true, HelpMessage = 'Specify the Application (Client) Secret to use.', Position = 2)]
        [ValidateNotNullorEmpty()]
        [Alias('ApplicationClientSecret')]
        [string]$ClientSecret,
        [Parameter(Mandatory = $false, HelpMessage = 'Specify the scope to use.', Position = 3)]
        [ValidateNotNullorEmpty()]
        [Alias('GrantScope')]
        [string]$Scope = 'https://graph.microsoft.com/.default',
        [Parameter(Mandatory = $false, HelpMessage = 'Specify the grant type to use.', Position = 4)]
        [ValidateNotNullorEmpty()]
        [Alias('AccessType')]
        [string]$GrantType = 'client_credentials'
    )

    Begin {

        ## Get the name of this function and write verbose header
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

        ## Assemble the token body for the API call. You can store the secrets in Azure Key Vault and retrieve them from there.
        [hashtable]$Body = @{
            client_id     = $ClientID
            scope         = $Scope
            client_secret = $ClientSecret
            grant_type    = $GrantType
        }

        ## Assembly the URI for the API call
        [string]$Uri = "https://login.microsoftonline.com/$TenantID/oauth2/v2.0/token"

        ## Write Debug information
        Write-Debug -Message "Uri: $Uri"
        Write-Debug -Message "Body: $($Body | Out-String)"
    }
    Process {
        Try {

            ## Get the access token
            $Response = Invoke-RestMethod -Method 'POST' -Uri $Uri -ContentType 'application/x-www-form-urlencoded' -Body $Body -UseBasicParsing
            $Output = $Response.access_token
        }
        Catch {
            [string]$Message = "Error getting MSGraph API Acces Token for TenantID '{0}' with ClientID '{1}'.`n{2}" -f $TenantID, $ClientID, $(Resolve-Error)
            Write-Log -Message $Message -Severity 3 -ScriptSection ${CmdletName} -EventID 666
            Write-Error -Message $Message
        }
        Finally {
            Write-Output -InputObject $Output
        }
    }
    End {
    }
}
#endregion

#region Function Invoke-MSGraphAPI
Function Invoke-MSGraphAPI {
<#
.SYNOPSIS
    Invokes the Microsoft Graph API.
.DESCRIPTION
    Invokes the Microsoft Graph API with paging support.
.PARAMETER Method
    Specify the method to use.
    Available options are 'GET', 'POST', 'PATCH', 'PUT' and 'DELETE'.
    Default is: 'GET'.
.PARAMETER Token
    Specify the access token to use.
.PARAMETER Version
    Specify the version of the Microsoft Graph API to use.
    Available options are 'Beta' and 'v1.0'.
    Default is: 'Beta'.
.PARAMETER Resource
    Specify the resource to query.
    Default is: 'deviceManagement/managedDevices'.
.PARAMETER Parameter
    Specify the parameter to use. Make sure to use the correct syntax and escape special characters with a backtick.
    Default is: $null.
.PARAMETER Body
    Specify the request body to use.
    Default is: $null.
.PARAMETER ContentType
    Specify the content type to use.
    Default is: 'application/json'.
.EXAMPLE
    Invoke-MSGraphAPI -Method 'GET' -Token $Token -Version 'Beta' -Resource 'deviceManagement/managedDevices' -Parameter "filter=operatingSystem like 'Windows' and deviceName like 'MEM-Zone-PC'"
.EXAMPLE
    Invoke-MSGraphAPI -Token $Token -Resource 'users'
.INPUTS
    None.
.OUTPUTS
    System.Object
.NOTES
    Created by Ioan Popovici
    v1.0.0 - 2024-01-11

    This is an private function should tipically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    MSGraph
.FUNCTIONALITY
    Invokes the Microsoft Graph API.
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $false, HelpMessage = 'Specify the method to use.', Position = 0)]
        [ValidateSet('GET', 'POST', 'PATCH', 'PUT', 'DELETE')]
        [Alias('HTTPMethod')]
        [string]$Method = 'GET',
        [Parameter(Mandatory = $true, HelpMessage = 'Specify the access token to use.', Position = 1)]
        [ValidateNotNullorEmpty()]
        [Alias('AccessToken')]
        [string]$Token,
        [Parameter(Mandatory = $false, HelpMessage = 'Specify the version of the Microsoft Graph API to use.', Position = 2)]
        [ValidateSet('Beta', 'v1.0')]
        [Alias('GraphVersion')]
        [string]$Version = 'Beta',
        [Parameter(Mandatory = $true, HelpMessage = 'Specify the resource to query.', Position = 3)]
        [ValidateNotNullorEmpty()]
        [Alias('APIResource')]
        [string]$Resource,
        [Parameter(Mandatory = $false, HelpMessage = 'Specify the parameters to use.', Position = 4)]
        [ValidateNotNullorEmpty()]
        [Alias('QueryParameter')]
        [string]$Parameter,
        [Parameter(Mandatory = $false, HelpMessage = 'Specify the request body to use.', Position = 5)]
        [ValidateNotNullorEmpty()]
        [Alias('RequestBody')]
        [string]$Body,
        [Parameter(Mandatory = $false, HelpMessage = 'Specify the content type to use.', Position = 6)]
        [ValidateNotNullorEmpty()]
        [Alias('Type')]
        [string]$ContentType = 'application/json'
    )

    Begin {

        ## Get the name of this function and write verbose header
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

        ## Assemble the URI for the API call
        [string]$Uri = "https://graph.microsoft.com/$Version/$Resource"
        If (-not [string]::IsNullOrWhiteSpace($Parameter)) { $Uri += "`?`$$Parameter" }

        ## Assembly parameters for the API call
        [hashtable]$Parameters = @{
            'Uri'         = $Uri
            'Method'      = $Method
            'Headers'     = @{
                'Content-Type'  = 'application\json'
                'Authorization' = "Bearer $Token"
            }
            'ContentType' = $ContentType
        }
        If (-not [string]::IsNullOrWhiteSpace($Body)) { $Parameters.Add('Body', $Body) }

        ## Write Debug information
        Write-Debug -Message "Uri: $Uri"
    }
    Process {
        Try {

            ## Invoke the MSGraph API
            $Output = Invoke-RestMethod @Parameters

            ## If there are more than 1000 rows, use paging. Only for GET method.
            If ($Output.'@odata.nextLink') {
                $Output += Do {
                    $Parameters.Uri = $OutputPage.'@odata.nextLink'
                    $OutputPage = Invoke-RestMethod @Parameters
                    $OutputPage
                }
                Until ([string]::IsNullOrEmpty($OutputPage.'@odata.nextLink'))
            }
            Write-Verbose -Message "Got '$($Output.Count)' Output pages."
        }
        Catch {
            [string]$Message = "Error invoking MSGraph API version '{0}' for resource '{1}' using '{2}' method.`n{3}" -f $Version, $Resource, $Method, $(Resolve-Error)
            Write-Log -Message $Message -Severity 3 -ScriptSection ${CmdletName} -EventID 666
            Write-Error -Message $Message
        }
        Finally {
            $Output = $Output.value
            Write-Output -InputObject $Output
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

    ## Set the script section
    $script:ScriptSection = 'Main'

    ## Write Start verbose message
    Write-Log -Message 'Start' -VerboseMessage

    ## Get API Token
    $Token = Get-MSGraphAccessToken -TenantID $TenantID -ClientID $ClientID -ClientSecret $ClientSecret -ErrorAction 'Stop'

    ## Get the device information
    Write-Verbose -Message "Getting device information, this might take a while..." -Verbose

    #  Assemble the Parameter filter value
    $Parameter = If ($DeviceOS -ne 'All') { "filter=operatingSystem eq '$DeviceOS'" }
    $Parameter += If ($DeviceName -ne 'All') {
        If ($DeviceOS -eq 'All') { "filter=deviceName eq '$DeviceName'" } Else { " and deviceName eq '$DeviceName'" }
    }

    #  Set the parameters for the API call and add the Parameter parameter as a filter if it is not empty
    $Parameters = @{
        Token = $Token
        Resource = 'deviceManagement/managedDevices'
    }
    If (-not [string]::IsNullOrWhiteSpace($Parameter)) { $Parameters.Add('Parameter', $Parameter) }

    #  Get the device information from the MSGraph API
    $Devices = Invoke-MSGraphAPI @Parameters -ErrorAction 'Stop'
    Write-Verbose -Message "Retrieved $($Devices.Count) devices."

    ## Process devices
    ForEach ($Device in $Devices) {

        ## Set variables
        [int]$RenamedCounter = 0
        [string]$Output = ''
        [string]$SerialNumber = $Device.serialNumber
        [string]$UserPrincipalName = $Device.userPrincipalName
        [string]$DeviceName = $Device.deviceName
        [string]$DeviceID = $Device.id
        [string]$OperatingSystem = $Device.operatingSystem
        #  Initialize the prefix variable with the script parameter value
        [string]$Prefix = $PSBoundParameters['Prefix']
        #  Convert to CAPS, shorten to 6 characters, convert to upper case and clean Prefix by removing any non-alphanumeric characters
        If (-not [string]::IsNullOrWhiteSpace($Prefix)) { $Prefix = $($Prefix.Substring(0, [System.Math]::Min(6, $Prefix.Length))).ToUpper() -replace ('[\W | /_]', '') }

        ## Show progress bar
        Show-Progress -Status "Processing Devices for Rename --> [$DeviceName]" -Steps $Devices.Count

        ## Get device assigned user attribute information and set the Prefix if specified
        If ($PSCmdlet.ParameterSetName -eq 'UserAttribute') {
            Try {
                $UserInfo = Invoke-MSGraphAPI -Token $Token -Resource 'users' -Parameter "filter=userPrincipalName eq '$UserPrincipalName'" -ErrorAction 'Stop'
                    #  Get the user attribute
                    [string]$UserAttribute = $UserInfo.$PrefixFromUserAttribute
                    #  Convert to CAPS, shorten to 6 characters, convert to upper case and clean UserAttribute by removing any non-alphanumeric characters
                    $UserAttribute = $($UserAttribute.Substring(0, [System.Math]::Min(6, $UserAttribute.Length))).ToUpper() -replace ('[\W | /_]', '')
                    #  Set the prefix if the user attribute is not empty
                    If (-not [string]::IsNullOrEmpty($UserAttribute)) { $Prefix = $UserAttribute } Else { Throw 'User attribute is empty!' }
            }
            Catch {
                [string]$Message = "Error getting user information for device '{0}' with owner '{1}', check if the device has a user assigned. Skipping...`n{2}" -f $DeviceName, $UserPrincipalName, $(Resolve-Error)
                Write-Log -Message $Message -Severity 3 -EventID 666
                #  Skip to next device in the loop
                Continue
            }
        }

        ## Check if the device has a serialnumber and that it's valid
        [boolean]$IsValidSerialNumber = If (-not [string]::IsNullOrEmpty($SerialNumber) -and ($SerialNumber -ne 'SystemSerialNumber')) { $true } Else { $false }

        ## Clean serialnumber by removing any non-alphanumeric characters
        If ($IsValidSerialNumber) {
            $SerialNumber = ($SerialNumber -replace ('[\W | /_]', '')).ToUpper()

            ## Trim serial number to 15 characters for windows devices
            If ($OperatingSystem -eq 'windows') {
                $NewDeviceName = -join ($Prefix,'-',$SerialNumber)
                $MaxSerialNumberLength = 15 - $Prefix.Length -1
                $SerialNumber = $SerialNumber.subString(0, [System.Math]::Min($MaxSerialNumberLength , $NewDeviceName.Length))
            }

            ## Assemble the new device name
            $NewDeviceName = -join ($Prefix,'-',$SerialNumber)

            ## Rename device if needed
            Try {
                If ($DeviceName -ne $NewDeviceName) {
                    $Parameters = @{
                        Method = 'POST'
                        Token = $Token
                        Resource = "deviceManagement/managedDevices('$DeviceID')/setDeviceName"
                        Body = @{ deviceName = $NewDeviceName } | ConvertTo-Json
                        ContentType = 'application/json'
                        ErrorAction = 'Stop'
                    }
                    ##  Rename device with ShouldProcess support
                    [boolean]$ShouldProcess = $PSCmdlet.ShouldProcess("$DeviceName", "Rename to $NewDeviceName")
                    If ($ShouldProcess) { Invoke-MSGraphAPI @Parameters }
                    #  If operation is successful, output the result
                    $Output = "Device '{0}' renamed to '{1}'." -f $DeviceName, $NewDeviceName
                    $RenamedCounter++
                }
                Else {
                    $Output = "Device '{0}' is already named '{1}'." -f $DeviceName, $NewDeviceName
                }
            }
            Catch {
                Write-Log -Message "Error renaming device '$DeviceName' to '$NewDeviceName'.`n$(Resolve-Error)" -Severity 3 -EventID 666
                Continue
            }
            Finally {
                Write-Log -Message $Output
            }
        }
        Else {
            Write-Log -Message "Device '$DeviceName' does not have a valid serialnumber. Skipping..." -Severity 3 -EventID 666
        }
    }
}
Catch {
    Write-Log -Message "Error renaming device.`n$(Resolve-Error)" -Severity 3 -EventID 666
}
Finally {
    Write-Log -Message "Succesully renamed '$RenamedCounter' devices." -EventID 2
    Write-Log -Message 'Stop' -VerboseMessage
}

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================