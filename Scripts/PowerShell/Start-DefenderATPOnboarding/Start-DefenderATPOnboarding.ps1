<#
.SYNOPSIS
    Start Microsoft Defender ATP onboarding
.DESCRIPTION
    Performs Microsoft Defender ATP onboarding operations including:
    - Registry configuration for ATP policies
    - WMI security settings
    - ELAM certificate installation
    - Service management and validation
    - Onboarding information registration
.PARAMETER OnboardingJson
    Onboarding information in JSON format.
.PARAMETER DeviceGroupTag
    Optional device group tag to assign to the device.
.EXAMPLE
    .\Start-DefenderATPOnboarding.ps1 -Verbose
    Performs standard onboarding with default device group.
.EXAMPLE
    .\Start-DefenderATPOnboarding.ps1 -DeviceGroupTag "Production" -Verbose
    Performs onboarding and assigns device to Production group.
.INPUTS
    System.String.
.OUTPUTS
    System.Int32 (exit code).
.NOTES
    Created by Ioan Popovici
    Requires administrator privileges
    For more information, visit: https://go.microsoft.com/fwlink/p/?linkid=822807'
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
.LINK
    https://go.microsoft.com/fwlink/p/?linkid=822807
.COMPONENT
    Microsoft Defender ATP
.FUNCTIONALITY
    Device Onboarding
#>

## Set script requirements
#Requires -Version 5.1
#Requires -RunAsAdministrator

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

## Get script parameters
Param (
    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$DeviceGroupTag,
    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$PreviousOrganizationID
)

## Set script parameters (Comment to use script parameters, uncomment to use default values)
$DeviceGroupTag = 'MEMZone'
#  Set Onboarding information (this would typically come from Microsoft's onboarding package)
$Script:OnboardingJson = [ordered]@{
    'body'      = '{"previousOrgIds":[],"orgId":"","geoLocationUrl":"https://winatp-gw-neu.microsoft.com/","datacenter":"SouthEurope","vortexGeoLocation":"EU","version":"1.4"}'
    'sig'       = ''
    'sha256sig' = '='
    'cert'      = ''
    'chain'     = @(
        '',
        ''
    )
} | ConvertTo-Json -Compress

## Set script variables
$Script:Version          = '2.0.0'
$Script:Name             = 'Windows Defender ATP Onboarding'
$Script:NameAndVersion   = $Script:Name + ' v' + $Script:Version
$Script:Path             = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path)
$Script:FullName         = $MyInvocation.MyCommand.Path
$Script:LogName          = 'Start-WindowsDefenderATPOnboarding'
$Script:LogPath          = [System.IO.Path]::Combine($Env:ProgramData, 'Logs', $Script:LogName)
$Script:LogFullName      = [System.IO.Path]::Combine($Script:LogPath, $Script:LogName + '.log')
$Script:LogDebugMessages = $true
$Script:LogMaxSizeMB     = 5
$Script:LogBuffer        = [System.Collections.ArrayList]::new()
$Script:RunningAs        = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$Script:RunningAsAdmin   = [bool]([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

#endregion
##*=============================================
##* END VARIABLE DECLARATION
##*=============================================

##*=============================================
##* FUNCTION LISTINGS
##*=============================================
#region FunctionListings

#region function Test-LogFile
function Test-LogFile {
<#
.SYNOPSIS
    Checks if the log path exists and if the log file exceeds the maximum specified size.
.DESCRIPTION
    Checks if the log path exists and creates the folder and file if needed
    Checks if the log file exceeds the maximum specified size and clears it if needed.
.PARAMETER LogFile
    Specifies the path to the log file.
.PARAMETER MaxSizeMB
    Specifies the maximum size in MB before the log file is cleared.
.EXAMPLE
    Test-LogFile -LogFile 'C:\Logs\Application.log' -MaxSizeMB 5
.INPUTS
    None.
.OUTPUTS
    None.
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    File Log
.FUNCTIONALITY
    Test log file
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullorEmpty()]
        [string]$LogFile,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateRange(1, 100)]
        [int]$MaxSizeMB
    )

    process {
        try {

            ## Create log folder if it doesn't exists
            $LogPath = [System.IO.Path]::GetDirectoryName($LogFile)
            [bool]$LogFolderExists = Test-Path -Path $LogPath -PathType Container
            if (-not $LogFolderExists) {
                try {
                    $null = New-Item -Path $LogPath -ItemType Directory -Force -ErrorAction Stop
                }
                catch {

                    ## Fallback to script directory if ProgramData is inaccessible
                    [string]$Script:LogPath = $Script:Path
                    [string]$Script:LogFullName = Join-Path -Path $Script:LogPath -ChildPath $Script:LogName
                    Write-Warning -Message "Failed to create log folder: [$($PSItem.Exception.Message)]. Using script directory instead."
                }
            }

            ## Create log file if it doesn't exist
            [bool]$LogFileExists = Test-Path -Path $LogFile -PathType Leaf
            if (-not $LogFileExists) {
                try {
                    $null = New-Item -Path $LogFile -ItemType File -Force -ErrorAction Stop
                }
                catch {
                    Write-Warning -Message "Failed to create log file: [$($PSItem.Exception.Message)]"
                }
            }

            ## Get log file information
            [System.IO.FileInfo]$LogFileInfo = Get-Item -Path $LogFile -ErrorAction Stop

            #  Convert bytes to MB
            [double]$LogFileSizeMB = $LogFileInfo.Length / 1MB

            ## If log file exceeds maximum size, clear it
            if ($LogFileSizeMB -ge $MaxSizeMB) {
                Write-Verbose -Message "Log file size [$($LogFileSizeMB.ToString('0.00')) MB] exceeds maximum size [$MaxSizeMB MB]. Clearing log file..."

                ## Clear the log file by creating a new empty file
                [string]$CurrentTimestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
                [string]$RotationMessage = "$CurrentTimestamp [Information] Log file exceeded [$MaxSizeMB MB] limit and was cleared"
                Set-Content -Path $LogFile -Value $RotationMessage -Force -ErrorAction Stop
            }
        }
        catch {
            Write-Warning -Message "Error checking log file size: [$($PSItem.Exception.Message)]"
        }
    }
}
#endregion

#region function Write-LogBuffer
function Write-LogBuffer {
<#
.SYNOPSIS
    Writes the log buffer to the log file.
.DESCRIPTION
    Writes the log buffer to the log file and clears the buffer.
.EXAMPLE
    Write-LogBuffer
.INPUTS
    None.
.OUTPUTS
    None.
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    File Log
.FUNCTIONALITY
    Write log buffer to log file
#>
    [CmdletBinding()]
    param()

    process {
        if ($Script:LogBuffer.Count -gt 0) {
            try {

                ## Convert ArrayList to string array for Add-Content
                [string[]]$LogEntries = $Script:LogBuffer.ToArray()

                ## Append to log file
                Add-Content -Path $Script:LogFullName -Value $LogEntries -ErrorAction Stop

                ## Wait for file system to close the file handle
                Start-Sleep -Milliseconds 10

                ## Clear buffer
                $Script:LogBuffer.Clear()
            }
            catch {
                Write-Warning -Message "Failed to write to log file: [$($PSItem.Exception.Message)]"
            }
        }
    }
}
#endregion

#region function Write-Log
function Write-Log {
<#
.SYNOPSIS
    Writes a message to the log file and/or console.
.DESCRIPTION
    Writes a timestamped log entry to the internal buffer and displays it with optional formatting.
.PARAMETER Severity
    Specifies the severity level of the message. Available options: Information, Warning, Error.
.PARAMETER Message
    The log message to write. Can be a string, array of strings, or object data for table formatting.
.PARAMETER Source
    The source of the message. This is used to identify the source of the message in the log file.
.PARAMETER FormatOptions
    Optional hashtable of formatting parameters:
    - Mode: Output style (Block, CenteredBlock, Line, InlineHeader, InlineSubHeader, Timeline, Table, Default)
    - AddEmptyRow: Add blank lines (No, Before, After, BeforeAndAfter)
    - Title: For table mode, specifies the table title
    - NewHeaders: Maps display headers to property names
    - ColumnWidths: Optional custom column widths
.PARAMETER DebugMessage
    Specifies that the message is a debug message. Debug messages only get logged if -LogDebugMessage is set to $true.
.PARAMETER LogDebugMessages
    Whether to write debug messages to the log file (default: value of $Script:LogDebugMessages).
.PARAMETER SkipLogFormatting
    Whether to skip formatting for the log message.
.EXAMPLE
    Write-Log -Message 'Application uninstalled successfully'
.EXAMPLE
    Write-Log -Message $FilteredApplications -FormatOptions @{
        Mode        = 'Table'
        Title       = 'Applications'
        NewHeaders  = [ordered]@{
            'Application' = 'DisplayName'
            'Version'     = 'DisplayVersion'
            'Type'        = 'InstallerType'
            'Context'     = 'Context'
        }
        AddEmptyRow = 'BeforeAndAfter'
    }
.INPUTS
    System.Object
.OUTPUTS
    None.
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    File Log
.FUNCTIONALITY
    Write log message to log file and/or console
#>
    [CmdletBinding()]
    param (
        [Parameter(Position = 0)]
        [Alias('Level')]
        [ValidateSet('Information', 'Warning', 'Debug', 'Error')]
        [string]$Severity = 'Information',

        [Parameter(Mandatory = $true, Position = 1)]
        [Alias('LogMessage')]
        [AllowNull()]
        [AllowEmptyString()]
        [object]$Message,

        [Parameter(Position = 2)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Source,

        [Parameter(Position = 3)]
        [hashtable]$FormatOptions,

        [Parameter()]
        [switch]$DebugMessage,

        [Parameter()]
        [switch]$LogDebugMessages = $Script:LogDebugMessages,

        [Parameter()]
        [switch]$SkipLogFormatting
    )

    begin {

        ## Initialize variables
        [string]$Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        [string[]]$MessageLines = @()
    }
    process {
        try {

            ## Format the message or use raw message if formatting is skipped
            if ($SkipLogFormatting -or $DebugMessage) {
                #  Skip formatting completely - just convert to string array safely
                if ($null -eq $Message) {
                    $MessageLines = @('(No message)')
                }
                elseif ($Message -is [array] -and $Message[0] -is [string]) {
                    $MessageLines = @($Message | ForEach-Object { if ($null -eq $PSItem) { '(null)' } else { $PSItem.ToString() } })
                }
                else {
                    try {
                        $MessageLines = @($Message.ToString())
                    }
                    catch {
                        $MessageLines = @('(Message cannot be displayed)')
                    }
                }
            }
            else {

                ## Initialize FormatOptions if not provided
                if ($null -eq $FormatOptions) {
                    $FormatOptions = @{ Mode = 'Timeline' }
                }

                #  Ensure Mode is set
                if (-not $FormatOptions.ContainsKey('Mode')) {
                    $FormatOptions['Mode'] = 'Timeline'
                }

                ## Use Format-Message for all formatting
                $MessageLines = Format-Message -Message $Message -FormatData $FormatOptions
            }

            ## Ensure we have at least one line
            if ($MessageLines.Count -eq 0) { $MessageLines = @('(Empty message)') }

            ## Write to console and log file
            foreach ($MessageLine in $MessageLines) {
                if (-not $DebugMessage) {
                    switch ($Severity) {
                        'Information' { Write-Verbose -Message $MessageLine }
                        'Warning'     { Write-Warning -Message $MessageLine }
                        'Error'       { Write-Error   -Message "  $MessageLine" -ErrorAction Continue }
                    }
                }
                else {
                    if ($Source) {
                        Write-Debug -Message "[$Source] $MessageLine"
                    }
                    else {
                        Write-Debug -Message "  $MessageLine"
                    }
                }

                #  Skip debug logging if disabled
                if ($DebugMessage -and -not $LogDebugMessages) { continue }

                #  Add timestamp and severity to the message and add to the log buffer
                if ($DebugMessage -and $Source) {
                    [string]$LogEntry = "$Timestamp [$Source] [$Severity] $MessageLine"
                }
                else {
                    [string]$LogEntry = "$Timestamp [$Severity] $MessageLine"
                }
                $null = $Script:LogBuffer.Add($LogEntry)
            }

            ## Write the log buffer to the log file if it exceeds the threshold or if the severity is Error
            if ($Script:LogBuffer.Count -ge 20 -or $Severity -eq 'Error') { Write-LogBuffer }
        }
        catch {
            Write-Warning -Message "Write-Log failed: [$($PSItem.Exception.Message)]"
        }
    }
}
#endregion

#region function Format-Message
function Format-Message {
<#
.SYNOPSIS
    Formats a text header or table.
.DESCRIPTION
    Formats a header block, centered block, section header, sub-header, inline log, table, or adds separator rows.
.PARAMETER Message
    Specifies the message or data to display. For tables, this contains the data to format.
.PARAMETER FormatData
    Specifies the formatting options as a hashtable:
    - Mode:
        - 'Block'
        - 'CenteredBlock'
        - 'Line'
        - 'InlineHeader'
        - 'InlineSubHeader'
        - 'Timeline'
        - 'TimelineHeader'
        - 'Table'
            - Title:           Table title. Default is: 'Data Table'.
            - NewHeaders:      Mapping of display headers to property names. Default is: (Auto-Detected).
            - ColumnWidths:    Custom column widths. Default is: 0.
            - CellPadding:     Amount of horizontal padding to add within cells. Default is: 0.
            - VerticalPadding: Amount of padding to add above and below the table. Default is: 0.
    Default is: 'Timeline'.
    - AddEmptyRow:
        - 'No'
        - 'Before'
        - 'After'
        - 'BeforeAndAfter'
        Default is: 'No'.
.EXAMPLE
    Format-Message -Message 'UNINSTALL' -FormatData @{ Mode = 'InlineHeader' }
.EXAMPLE
    Format-Message -Message $FilteredApplications -FormatData @{
        Mode            = 'Table'
        Title           = 'Applications'
        NewHeaders = [ordered]@{
            Application = 'DisplayName'
            Version     = 'DisplayVersion'
            Type        = 'InstallerType'
            Context     = 'Context'
        }
        CellPadding     = 1
        VerticalPadding = 1
        AddEmptyRow     = 'BeforeAndAfter'
    }
.INPUTS
    None.
.OUTPUTS
    System.String[]
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    File Log
.FUNCTIONALITY
    Format message for log file and/or console
#>
    [CmdletBinding()]
    [OutputType([System.String[]])]
    param (
        [Parameter(Mandatory, Position = 0)]
        [AllowNull()]
        [object]$Message,

        [Parameter(Position = 1)]
        [hashtable]$FormatData = @{}
    )

    begin {

        ## Initialize variables
        If ($null -eq $Message) { $Message = @() }
        [int]$LineWidth = 80
        [string]$Separator = '=' * $LineWidth
        [string[]]$OutputLines = @()

        #  Extract format options from FormatData with defaults
        $Mode            = if ($null -ne $FormatData.Mode)                   { $FormatData.Mode } else { 'Default' }
        $AddEmptyRow     = if ($null -ne $FormatData.AddEmptyRow)            { $FormatData.AddEmptyRow } else { 'No' }
        $Title           = if ($null -ne $FormatData.Title)                  { $FormatData.Title } else { 'Data Table' }
        $NewHeaders      = if ($null -ne $FormatData.NewHeaders)             { $FormatData.NewHeaders } else { $null }
        $ColumnWidths    = if ($FormatData.Keys -contains 'ColumnWidths')    { $FormatData['ColumnWidths']    } else { @() }
        $CellPadding     = if ($FormatData.Keys -contains 'CellPadding')     { $FormatData['CellPadding']     } else { 0 }
        $VerticalPadding = if ($FormatData.Keys -contains 'VerticalPadding') { $FormatData['VerticalPadding'] } else { 0 }
    }
    process {
        try {

            ## Format the message based on the specified mode
            switch ($Mode) {

                ## LINE MODE
                'Line' {
                    $OutputLines = @($Separator)
                }

                ## BLOCK MODE
                'Block' {
                    #  Add prefix and format and trim the message
                    [string]$Prefix = '▶ '
                    [int]$MaxMessageLength = $LineWidth - $Prefix.Length
                    [string]$FormattedMessage = $Prefix + $Message.ToString().Trim()
                    #  Truncate message if it exceeds the maximum length
                    if ($FormattedMessage.Length -gt $LineWidth) {
                        $FormattedMessage = $Prefix + $Message.ToString().Trim().Substring(0, $MaxMessageLength - 3) + '...'
                    }

                    #  Add separation lines
                    $OutputLines = @($Separator, $FormattedMessage, $Separator)
                }

                ## CENTERED BLOCK MODE
                'CenteredBlock' {
                    #  Trim message
                    [string]$CleanMessage = $Message.ToString().Trim()
                    #  Truncate message if it exceeds the maximum length
                    if ($CleanMessage.Length -gt ($LineWidth - 4)) {
                        $CleanMessage = $CleanMessage.Substring(0, $LineWidth - 7) + '...'
                    }
                    #  Center the message
                    [int]$ContentWidth = $CleanMessage.Length
                    [int]$SidePadding = [math]::Floor(($LineWidth - $ContentWidth) / 2)
                    [string]$CenteredLine = $CleanMessage.PadLeft($ContentWidth + $SidePadding).PadRight($LineWidth)
                    #  Add separator lines
                    $OutputLines = @($Separator, $CenteredLine, $Separator)
                }

                ## INLINE HEADER MODE
                'InlineHeader' {
                    #  Trim and truncate message
                    [string]$Trimmed = $Message.ToString().Trim()
                    if ($Trimmed.Length -gt 54) { $Trimmed = $Trimmed.Substring(0, 51) + '...' }
                    #  Add padding to the message
                    [string]$HeaderLine = "===[ $Trimmed ]==="
                    $OutputLines = @($HeaderLine)
                }

                ## INLINE SUBHEADER MODE
                'InlineSubHeader' {
                    #  Trim and truncate message
                    [string]$Trimmed = $Message.ToString().Trim()
                    if ($Trimmed.Length -gt 54) { $Trimmed = $Trimmed.Substring(0, 51) + '...' }
                    #  Add padding to the message
                    [string]$HeaderLine = "---[ $Trimmed ]---"
                    $OutputLines = @($HeaderLine)
                }

                ## TABLE MODE
                'Table' {
                    #  Set empty message to a single space if no data is provided
                    If ($Message.Count -eq 0) { $Message = @(' ') }
                    #  Add table title
                    $OutputLines = @("---[ $Title ]---", '')
                    #  Add vertical padding above the table
                    if ($VerticalPadding -gt 0) {
                        for ($i = 0; $i -lt $VerticalPadding; $i++) {
                            $OutputLines += ''
                        }
                    }
                    #  Determine headers
                    if ($null -eq $NewHeaders -or $NewHeaders.Count -eq 0) {
                        $FirstObject = $Message[0]
                        $Headers = @($FirstObject.PSObject.Properties.Name)
                        $UseNewHeaders = $false
                    }
                    else {
                        #  Use the keys from NewHeaders as our display headers
                        $Headers = @($NewHeaders.Keys)
                        $UseNewHeaders = $true
                    }
                    #  Calculate column widths if not provided
                    if ($ColumnWidths.Count -eq 0) {
                        $ColumnWidths = @()
                        for ($Counter = 0; $Counter -lt $Headers.Count; $Counter++) {
                            #  Get the header width
                            $MaxWidth = $Headers[$Counter].Length
                            #  Check each row's value width
                            foreach ($Row in $Message) {
                                $Value = if ($UseNewHeaders) {
                                    $Row.($NewHeaders[$Headers[$Counter]])
                                }
                                else {
                                    $Row.($Headers[$Counter])
                                }
                                if ($null -ne $Value) {
                                    $ValueWidth = $Value.ToString().Length
                                    $MaxWidth = [Math]::Max($MaxWidth, $ValueWidth)
                                }
                            }
                            $ColumnWidths += $MaxWidth
                        }
                    }
                    #  Create the format string for consistent column alignment
                    $FormatString = '| '
                    for ($Counter = 0; $Counter -lt $Headers.Count; $Counter++) {
                        #  Apply padding to column width
                        $PaddedWidth = $ColumnWidths[$Counter] + ($CellPadding * 2)
                        $FormatString += "{$Counter,-$PaddedWidth} | "
                    }
                    #  Add the header row
                    $HeaderData = @()
                    for ($Counter = 0; $Counter -lt $Headers.Count; $Counter++) {
                        #  Add padding to header text if requested
                        if ($CellPadding -gt 0) {
                            $HeaderData += (' ' * $CellPadding) + $Headers[$Counter] + (' ' * $CellPadding)
                        }
                        else {
                            $HeaderData += $Headers[$Counter]
                        }
                    }
                    $HeaderLine = $FormatString -f $HeaderData
                    $OutputLines += $HeaderLine
                    #  Add a separator line
                    $SeparatorParts = @()
                    for ($Counter = 0; $Counter -lt $Headers.Count; $Counter++) {
                        # Create padded separator for each column
                        $SepText = '-' * $ColumnWidths[$Counter]
                        if ($CellPadding -gt 0) {
                            $SeparatorParts += (' ' * $CellPadding) + $SepText + (' ' * $CellPadding)
                        }
                        else {
                            $SeparatorParts += $SepText
                        }
                    }
                    $SeparatorLine = $FormatString -f $SeparatorParts
                    $OutputLines += $SeparatorLine
                    #  Add data rows
                    foreach ($Row in $Message) {
                        $RowData = @()
                        for ($Counter = 0; $Counter -lt $Headers.Count; $Counter++) {
                            #  Get the value using the appropriate property name
                            $Value = if ($UseNewHeaders) {
                                $Row.($NewHeaders[$Headers[$Counter]])
                            }
                            else {
                                $Row.($Headers[$Counter])
                            }
                            #  Format the value
                            $FormattedValue = if ($null -eq $Value) { '' } else { $Value.ToString() }
                            #  Add padding if requested
                            if ($CellPadding -gt 0) {
                                $RowData += (' ' * $CellPadding) + $FormattedValue + (' ' * $CellPadding)
                            }
                            else {
                                $RowData += $FormattedValue
                            }
                        }
                        $DataLine = $FormatString -f $RowData
                        $OutputLines += $DataLine
                    }
                    #  Add vertical padding below the table
                    if ($VerticalPadding -gt 0) {
                        for ($i = 0; $i -lt $VerticalPadding; $i++) {
                            $OutputLines += ''
                        }
                    }
                }

                ## TIMELINE MODE
                'Timeline' {
                    #  Add prefix to the message
                    $OutputLines = @("     - $($Message.ToString())")
                }

                ## TIMELINE HEADER MODE
                'TimelineHeader' {
                    #  Add prefix to the message
                    $OutputLines = @("    $($Message.ToString())")
                }

                ## DEFAULT MODE
                Default {
                    #  Just return the trimmed message
                    $OutputLines = @($Message.ToString().Trim())
                }
            }

            ## Add spacing if requested
            switch ($AddEmptyRow) {
                'Before'         { $OutputLines = @('') + $OutputLines }
                'After'          { $OutputLines += '' }
                'BeforeAndAfter' { $OutputLines = @('') + $OutputLines + @('') }
            }

            ## Return the formatted output
            return $OutputLines
        }
        catch {
            Write-Log -Message "Error in Format-Message: [$($PSItem.Exception.Message)]" -Severity Warning
            return @($Message.ToString().Trim())
        }
    }
}
#endregion

#region function Write-EventLogEntry
function Write-EventLogEntry {
<#
.SYNOPSIS
    Writes an entry to the Application event log.
.DESCRIPTION
    Creates an event log entry with specified parameters for Microsoft Defender ATP onboarding.
.PARAMETER Message
    The message to write to the event log.
.PARAMETER EventId
    The event ID for the log entry.
.PARAMETER EntryType
    The type of event (Information, Warning, Error).
.EXAMPLE
    Write-EventLogEntry -Message "Onboarding successful" -EventId 20 -EntryType Information
.INPUTS
    System.String, System.Int32, System.String.
.OUTPUTS
    None.
.NOTES
    Created by Ioan Popovici
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    Windows Event Log
.FUNCTIONALITY
    Write Windows Event Log entry
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Message,

        [Parameter(Mandatory=$true)]
        [int]$EventId,

        [Parameter(Mandatory=$false)]
        [ValidateSet('Information', 'Warning', 'Error')]
        [string]$EntryType = 'Information'
    )

    process {
        try {
            Write-EventLog -LogName 'Application' -Source 'WDATPOnboarding' -EventId $EventId -EntryType $EntryType -Message $Message -ErrorAction SilentlyContinue
        }
        catch {
            Write-Warning -Message "Failed to write event log entry: $($PSItem.Exception.Message)"
        }
    }
}
#endregion

#region function Write-TelemetryMessage
Function Write-TelemetryMessage {
<#
.SYNOPSIS
    Writes telemetry message for Microsoft Defender ATP.
.DESCRIPTION
    Uses ETW to write telemetry messages for onboarding operations.
.PARAMETER Message
    The telemetry message to write.
.PARAMETER Level
    The event level (Error, Informational).
.EXAMPLE
    Write-TelemetryMessage -Message "Onboarding completed" -Level Informational
.INPUTS
    System.String, System.String.
.OUTPUTS
    None.
.NOTES
    Created by Ioan Popovici
.COMPONENT
    Microsoft Defender ATP
.FUNCTIONALITY
    Telemetry Logging
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)]
        [string]$Message,

        [Parameter(Mandatory=$false)]
        [ValidateSet('Error', 'Informational')]
        [string]$Level = 'Informational'
    )

    try {
        $TelemetryCode =
@"
using System;
using System.Diagnostics;
using System.Diagnostics.Tracing;

namespace Sense
{
    [EventData(Name = "Onboarding")]
    public struct Onboarding
    {
        public string Message { get; set; }
    }

    public class Trace
    {
        public static EventSourceOptions TelemetryCriticalOption = new EventSourceOptions()
        {
            Level = EventLevel.$Level,
            Keywords = (EventKeywords)0x0000200000000000,
            Tags = (EventTags)0x0200000
        };

        public void WriteOnboardingMessage(string message)
        {
            es.Write("OnboardingScript", TelemetryCriticalOption, new Onboarding {Message = message});
        }

        private static readonly string[] telemetryTraits = { "ETW_GROUP", "{5ECB0BAC-B930-47F5-A8A4-E8253529EDB7}" };
        private EventSource es = new EventSource("Microsoft.Windows.Sense.Client.Management", EventSourceSettings.EtwSelfDescribingEventFormat, telemetryTraits);
    }
}
"@

        Add-Type -TypeDefinition $TelemetryCode -ErrorAction SilentlyContinue
        $Logger = New-Object -TypeName Sense.Trace
        $Logger.WriteOnboardingMessage($Message)
    }
    catch {
        Write-Log -Message "Failed to write telemetry message: $($PSItem.Exception.Message)" -Severity Error
    }
}
#endregion

#region function Install-ElamCertificate
Function Install-ElamCertificate {
<#
.SYNOPSIS
    Installs ELAM certificate for Windows Defender Boot driver.
.DESCRIPTION
    Uses P/Invoke to call InstallELAMCertificateInfo for WdBoot.sys driver.
.EXAMPLE
    Install-ElamCertificate
.INPUTS
    None.
.OUTPUTS
    System.Boolean.
.NOTES
    Created by Ioan Popovici
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    Windows Driver
.FUNCTIONALITY
    Install ELAM certificate for WdBoot.sys driver
#>
    [CmdletBinding()]
    Param ()

    try {
        $ElamCode = @'
using System;
using System.IO;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
using System.ComponentModel;

public static class ElamInstaller
{
    [DllImport("Kernel32", CharSet=CharSet.Auto, SetLastError=true)]
    public static extern bool InstallELAMCertificateInfo(SafeFileHandle handle);

    public static void InstallWdBoot(string path)
    {
        var stream = File.Open(path, FileMode.Open, FileAccess.Read, FileShare.Read);
        var handle = stream.SafeFileHandle;

        if (!InstallELAMCertificateInfo(handle))
        {
            throw new Win32Exception(Marshal.GetLastWin32Error());
        }
    }
}
'@

        ## Install ELAM certificate for WdBoot.sys driver
        Write-Log -Message 'Installing ELAM certificate for WdBoot.sys driver' -DebugMessage
        if (-not ([System.Management.Automation.PSTypeName]'ElamInstaller').Type) {
            $null = Add-Type -TypeDefinition $ElamCode
        }
        $DriverPath = Join-Path -Path $env:SystemRoot -ChildPath 'System32\Drivers\WdBoot.sys'
        $null = [ElamInstaller]::InstallWdBoot($DriverPath)
        Write-Log -Message 'ELAM certificate successfully installed [WdBoot.sys] driver!' -DebugMessage
    }
    catch {
        Write-Log -Message "Failed to install ELAM certificate [WdBoot.sys] driver: $($PSItem.Exception.Message)" -Severity Error
    }
}
#endregion

#region function Get-OrganizationInfo
function Get-OrganizationInfo {
<#
.SYNOPSIS
    Extracts organization information from Microsoft Defender ATP onboarding JSON.
.DESCRIPTION
    Parses the onboarding JSON string to extract current and previous organization IDs,
    along with other relevant onboarding information.
.PARAMETER OnboardingJson
    The onboarding JSON string containing body, sig, sha256sig, and cert properties.
.EXAMPLE
    Get-OrganizationInfo -OnboardingJson $JsonString
.INPUTS
    System.String
.OUTPUTS
    PSCustomObject with organization information
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    Microsoft Defender ATP
.FUNCTIONALITY
    Get organization information from onboarding JSON
#>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$OnboardingJson
    )

    process {
        try {
            Write-Log -Message "Processing onboarding JSON string" -DebugMessage

            ## Parse the main JSON object
            $OnboardingData = $OnboardingJson | ConvertFrom-Json

            ## Validate that the JSON contains the required 'body' property
            if (-not $OnboardingData.PSObject.Properties['body']) {
                throw "OnboardingJson must contain a 'body' property"
            }

            ## Parse the JSON body
            $BodyData = $OnboardingData.body | ConvertFrom-Json

            ## Create organization info object
            $OrgInfo = [PSCustomObject]@{
                CurrentOrgId     = $BodyData.orgId
                PreviousOrgIds   = $BodyData.previousOrgIds
                GeoLocationUrl   = $BodyData.geoLocationUrl
                Datacenter       = $BodyData.datacenter
                VortexGeoLocation = $BodyData.vortexGeoLocation
                Version          = $BodyData.version
                AllOrgIds        = @($BodyData.orgId) + $BodyData.previousOrgIds
            }

            Write-Log -Message "Current Organization ID: $($OrgInfo.CurrentOrgId)" -DebugMessage
            if ($OrgInfo.PreviousOrgIds.Count -gt 0) {
                Write-Log -Message "Previous Organization IDs: $($OrgInfo.PreviousOrgIds -join ', ')" -DebugMessage
            }
            Write-Log -Message "Datacenter: $($OrgInfo.Datacenter)" -DebugMessage

            return $OrgInfo
        }
        catch {
            Write-Log -Message "Failed to parse onboarding JSON: $($PSItem.Exception.Message)" -Severity Error
            throw
        }
    }
}
#endregion

#region function Set-RegistryValue
Function Set-RegistryValue {
<#
.SYNOPSIS
    Sets a registry value with error handling.
.DESCRIPTION
    Creates or updates a registry value with proper error handling and logging.
.PARAMETER Path
    The registry path.
.PARAMETER Name
    The value name.
.PARAMETER Value
    The value data.
.PARAMETER Type
    The registry value type.
.EXAMPLE
    Set-RegistryValue -Path "HKLM:\SOFTWARE\Test" -Name "TestValue" -Value "TestData" -Type String
.INPUTS
    System.String.
.OUTPUTS
    System.Boolean.
.NOTES
    Created by Ioan Popovici
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    Registry
.FUNCTIONALITY
    Set registry value
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)]
        [string]$Path,

        [Parameter(Mandatory=$true)]
        [string]$Name,

        [Parameter(Mandatory=$true)]
        $Value,

        [Parameter(Mandatory=$true)]
        [ValidateSet('String', 'DWord', 'Binary', 'QWord', 'MultiString', 'ExpandString')]
        [string]$Type
    )

    begin {

        ## Convert binary string to byte array
        if ($Type -eq 'Binary') {
            [byte[]]$Value = for ($Counter = 0; $Counter -lt $Value.Length; $Counter += 2) { [Convert]::ToByte($Value.Substring($Counter, 2), 16) }
        }
    }

    process {
        try {

            ## Ensure the registry path exists
            if (-not (Test-Path -Path $Path)) { New-Item -Path $Path -Force | Out-Null }

            ## Set the registry value
            Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force
            Write-Log -Message "Successfully set registry value: [$Path\$Name]" -DebugMessage
        }
        catch {
            Write-Log -Message "Failed to set registry value [$Path\$Name]: $($PSItem.Exception.Message)" -Severity Error
        }
    }
}
#endregion

#region function Remove-RegistryValue
Function Remove-RegistryValue {
<#
.SYNOPSIS
    Removes a registry value.
.DESCRIPTION
    Safely removes a registry value with error handling.
.PARAMETER Path
    The registry path.
.PARAMETER Name
    The value name.
.EXAMPLE
    Remove-RegistryValue -Path 'HKLM:\SOFTWARE\Test' -Name 'TestValue'
.INPUTS
    System.String.
.OUTPUTS
    System.Boolean.
.NOTES
    Created by Ioan Popovici
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    Registry
.FUNCTIONALITY
    Remove registry value
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    try {
        $null = Remove-ItemProperty -Path $Path -Name $Name -Force -ErrorAction Stop
        Write-Log -Message "Successfully removed registry value: [$Path\$Name]" -DebugMessage
        return $true
    }
    catch {
        Write-Log -Message "Failed to remove registry value [$Path\$Name]: $($PSItem.Exception.Message)" -DebugMessage
        return $false
    }
}
#endregion

#region function Remove-DefenderATPOnboarding
function Remove-DefenderATPOnboarding {
<#
.SYNOPSIS
    Removes Microsoft Defender ATP onboarding information from the registry.
.DESCRIPTION
    Checks for and removes Microsoft Defender ATP onboarding information based on the provided organization IDs.
.PARAMETER OrganizationIDs
    The Microsoft Defender ATP organization IDs to remove from the registry.
.EXAMPLE
    Remove-ATPOnboardingInformation -OrganizationIDs '896C1FF1-4030-4AA4-8713-FAF9B2AA7C0A', '3291C144-EA3D-44B6-7B62-5DAFD29B9B6C'
.INPUTS
    System.String.
.OUTPUTS
    None.
.NOTES
    Created by Ioan Popovici
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    Registry
.FUNCTIONALITY
    Remove Microsoft Defender ATP onboarding information from the registry
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$OrganizationIDs
    )

    begin {
        [string]$Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Advanced Threat Protection'
    }

    process {
        try {
            Write-Log -Message 'Checking for Microsoft Defender ATP onboarding information' -DebugMessage
            foreach ($OrganizationID in $OrganizationIDs) {
                $IsOrganizationIDPresent = Test-RegistryValue -Path $Path -Name $OrganizationID
                if ($IsOrganizationIDPresent) {
                    Remove-ItemProperty -Path $Path -Name $OrganizationID -Force -ErrorAction Stop
                    Write-Log -Message 'Removing onboarding information... [OK]'
                }
                else {
                    Write-Log -Message "Onboarding information [$OrganizationID] not found, skipping removal"
                }
            }
        }
        catch {
            Write-Log -Message "Failed to remove onboarding information [$OrganizationID]: $($PSItem.Exception.Message)" -Severity Error
        }
    }
}
#endregion

#region function Test-RegistryValue
Function Test-RegistryValue {
<#
.SYNOPSIS
    Tests if a registry value exists.
.DESCRIPTION
    Checks for the existence of a registry value.
.PARAMETER Path
    The registry path.
.PARAMETER Name
    The value name.
.EXAMPLE
    Test-RegistryValue -Path 'HKLM:\SOFTWARE\Test' -Name 'TestValue'
.INPUTS
    System.String.
.OUTPUTS
    System.Boolean.
.NOTES
    Created by Ioan Popovici
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    Registry
.FUNCTIONALITY
    Test if registry value exists
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    try {
        $null = Get-ItemProperty -Path $Path -Name $Name -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}
#endregion

#region function Test-DefenderATPOrganizationID
function Test-DefenderATPOrganizationID {
<#
.SYNOPSIS
    Tests if the system is onboarded with the correct Organization ID.
.DESCRIPTION
    Checks if the system is onboarded with the specified Organization ID by reading
    the onboarding JSON from the registry and comparing organization IDs.
.PARAMETER OrganizationID
    The expected Organization ID to check for.
.EXAMPLE
    Test-DefenderATPOrganizationID -OrganizationID '221a114-ef3d-44b6-8162-7dafd2fb926c'
.INPUTS
    System.String
.OUTPUTS
    System.Boolean
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    Microsoft Defender ATP
.FUNCTIONALITY
    Test if system is onboarded with the correct Organization ID
#>
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$OrganizationID
    )

    begin {
        [bool]$IsOnboarded = $false
    }

    process {
        try {

            ## Read the onboarding JSON from registry and compare organization IDs
            $RegistryOnboardingJson = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Advanced Threat Protection' -Name 'OnboardingInfo' -ErrorAction SilentlyContinue).OnboardingInfo

            if ($RegistryOnboardingJson) {
                $RegistryOrgInfo = Get-OrganizationInfo -OnboardingJson $RegistryOnboardingJson
                $RegistryOrgId = $RegistryOrgInfo.CurrentOrgId
                Write-Log -Message "Registry Organization ID: $RegistryOrgId" -DebugMessage

                if ($OrganizationID -eq $RegistryOrgId) {
                    Write-Log -Message "System is onboarded with correct Organization ID: [$RegistryOrgId]"
                    $IsOnboarded = $true
                }
                else {
                    Write-Log -Message "System is onboarded with different Organization ID. Expected: [$OrganizationID], Registry: [$RegistryOrgId]" -Severity Error
                }
            }
            else {
                Write-Log -Message "System is not onboarded with Organization ID: [$OrganizationID]"
            }
        }
        catch {
            Write-Log -Message "Failed to validate organization ID: $($PSItem.Exception.Message)" -Severity Warning
        }
        finally {
            Write-Output -InputObject $IsOnboarded
        }
    }
}
#endregion

#region function Test-DefenderATPOnboardingState
function Test-DefenderATPOnboardingState {
<#
.SYNOPSIS
    Tests the current Microsoft Defender ATP onboarding state.
.DESCRIPTION
    Validates the onboarding state from the registry and optionally waits for it to reach
    a specific value within a timeout period.
.PARAMETER ExpectedValue
    The expected onboarding state value. Default is 1.
.PARAMETER Wait
    If specified, waits for the onboarding state to become valid within the timeout period.
.PARAMETER TimeoutSeconds
    Maximum time to wait for onboarding state validation when -Wait is specified. Default is 20 seconds.
.EXAMPLE
    Test-DefenderATPOnboardingState
.EXAMPLE
    Test-DefenderATPOnboardingState -Wait -TimeoutSeconds 30 -ExpectedValue 1
.INPUTS
    None
.OUTPUTS
    System.Boolean
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    Microsoft Defender ATP
.FUNCTIONALITY
    Test if onboarding state is valid
#>
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter()]
        [int]$ExpectedValue = 1,

        [Parameter()]
        [switch]$Wait,

        [Parameter()]
        [ValidateRange(1, 300)]
        [int]$TimeoutSeconds = 20
    )

    begin {
        [bool]$IsStateValid = $false
        [string]$OnboardingPath = 'HKLM:\SOFTWARE\Microsoft\Windows Advanced Threat Protection\Status'
        [datetime]$EndTime = (Get-Date).AddSeconds($TimeoutSeconds)

        [scriptblock]$TestOnboardingState = {
            if (Test-RegistryValue -Path $OnboardingPath -Name 'OnboardingState') {
                $State = (Get-ItemProperty -Path $OnboardingPath -Name 'OnboardingState' -ErrorAction SilentlyContinue).OnboardingState
                if ($State -eq $ExpectedValue) {
                    Write-Log -Message 'Onboarding state... [OK]'
                    return $true
                }
                else {
                    Write-Log -Message "Device onboarding state is incorrect (Expected: $ExpectedValue, Actual: $State)" -Severity Error
                    return $false
                }
            }
            else {
                Write-Log -Message 'Onboarding state registry key not found' -Severity Warning
                return $false
            }
        }
    }

    process {
        try {
            if ($Wait) {
                Write-Log -Message "Waiting for onboarding state to be valid (Timeout: ${TimeoutSeconds}s)" -DebugMessage
                while ((Get-Date) -lt $EndTime) {
                    if (& $TestOnboardingState) {
                        $IsStateValid = $true
                        break
                    }
                    Start-Sleep -Seconds 2
                }
                if (-not $IsStateValid) {
                    Write-Log -Message "Onboarding state did not become valid within ${TimeoutSeconds}s timeout" -DebugMessage
                }
            }
            else {
                $IsStateValid = & $TestOnboardingState
            }
        }
        catch {
            Write-Log -Message "Failed to test onboarding state: $($PSItem.Exception.Message)" -Severity Warning
        }
        finally {
            Write-Output -InputObject $IsStateValid
        }
    }
}
#endregion


#region function Wait-ForServiceState
Function Wait-ForServiceState {
<#
.SYNOPSIS
    Waits for a service to reach a specific state, optionally starting it first.
.DESCRIPTION
    Monitors a service and waits for it to reach the specified state with timeout.
.PARAMETER ServiceName
    The name of the service to monitor.
.PARAMETER DesiredState
    The desired service state.
.PARAMETER TimeoutSeconds
    Maximum time to wait in seconds. Default is 30.
.PARAMETER StartIfNeeded
    If true and DesiredState is 'Running', will attempt to start the service if it's not already running.
.EXAMPLE
    Wait-ForServiceState -ServiceName 'SENSE' -DesiredState 'Running' -TimeoutSeconds 30
.EXAMPLE
    Wait-ForServiceState -ServiceName 'SENSE' -DesiredState 'Running' -StartIfNeeded -TimeoutSeconds 30
.INPUTS
    System.String, System.String, System.Int32, System.Boolean.
.OUTPUTS
    None. Throws terminating error on failure.
.NOTES
    Created by Ioan Popovici
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    Service
.FUNCTIONALITY
    Wait for service to reach desired state
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [string]$ServiceName,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Running', 'Stopped', 'StartPending', 'StopPending')]
        [string]$DesiredState,

        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 30,

        [Parameter(Mandatory = $false)]
        [switch]$StartIfNeeded
    )

    begin {
        $EndTime = (Get-Date).AddSeconds($TimeoutSeconds)
        Write-Log -Message "Waiting for service [$ServiceName] to reach state [$DesiredState] (Timeout: ${TimeoutSeconds}s)" -DebugMessage
    }

    process {
        try {
            while ((Get-Date) -lt $EndTime) {
                $Service = Get-Service -Name $ServiceName -ErrorAction Stop

                ## If service reached desired state, return success
                if ($Service.Status -eq $DesiredState) {
                    Write-Log -Message "Service [$ServiceName] reached desired state: $DesiredState" -DebugMessage
                    return
                }

                ## Start service if needed (only attempt once)
                if ($StartIfNeeded -and $DesiredState -eq 'Running' -and $Service.Status -notin @('Running', 'StartPending')) {
                    Write-Log -Message "Service [$ServiceName] is $($Service.Status). Attempting to start"
                    $null = Start-Service -Name $ServiceName -ErrorAction Stop -Verbose:$false -WarningAction SilentlyContinue
                }
                Start-Sleep -Seconds 2
            }

            ## Timeout reached
            $FinalStatus = try { (Get-Service -Name $ServiceName -ErrorAction Stop).Status } catch { 'Unknown' }
            $Message = "Service [$ServiceName] did not reach desired state [$DesiredState] within ${TimeoutSeconds}s timeout (Current: $FinalStatus)"
            Write-Log -Message $Message -Severity Error
        }
        catch {
            Write-Log -Message "Failed to manage service [$ServiceName]: $($PSItem.Exception.Message)" -Severity Error
        }
    }
}
#endregion

#region function Set-DefenderATPOnboarding
function Set-DefenderATPOnboarding {
<#
.SYNOPSIS
    Configures Microsoft Defender ATP onboarding.
.DESCRIPTION
    Sets up all required registry values, WMI security settings, ELAM certificate, and onboarding information.
.PARAMETER OnboardingJson
    The onboarding JSON to configure the ATP onboarding.
.EXAMPLE
    Set-DefenderATPOnboarding
.EXAMPLE
    Set-DefenderATPOnboarding -OnboardingJson $OnboardingJson
.INPUTS
    None.
.OUTPUTS
    None.
.NOTES
    Created by Ioan Popovici
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    Windows Defener ATP
.FUNCTIONALITY
    Configure Microsoft Defender ATP onboarding
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$OnboardingJson
    )

    begin {

        ## Variable definitions
        [string]$ATPPath               = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Advanced Threat Protection'
        [string]$DataCollectionPath    = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'
        [string]$WMISecurityPath       = 'HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Security'
        [string[]]$WMIBinaryValueNames = @(
            '14f8138e-3b61-580b-544b-2609378ae460',
            'cb2ff72d-d4e4-585d-33f9-f3a395c40be7'
        )
        [string]$WMIBinaryValue        = '0100048044000000540000000000000014000000020030000200000000001400FF0F120001010000000000051200000000001400E104120001010000000000050B0000000102000000000005200000002002000001020000000000052000000020020000'
    }

    process {
        try {

            ## Set initial registry values
            Write-Log -Message 'Configuring ATP and Data Collection'
            Set-RegistryValue -Path $ATPPath -Name 'latency' -Value 'Demo' -Type String
            Set-RegistryValue -Path $DataCollectionPath -Name 'DisableEnterpriseAuthProxy' -Value 1 -Type DWord

            ## Set WMI security settings
            Write-Log -Message 'Setting WMI security settings'
            Set-RegistryValue -Path $WMISecurityPath -Name $WMIBinaryValueNames[0] -Value $WMIBinaryValue -Type Binary
            Set-RegistryValue -Path $WMISecurityPath -Name $WMIBinaryValueNames[1] -Value $WMIBinaryValue -Type Binary

            ## Install ELAM certificate
            Write-Log -Message 'Installing ELAM certificate for WdBoot.sys driver'
            $null = Install-ElamCertificate

            ## Add onboarding information
            Write-Log -Message 'Adding onboarding information to registry'
            Set-RegistryValue -Path $ATPPath -Name 'OnboardingInfo' -Value $OnboardingJson -Type String

            ## Write to log
            Write-Log -Message 'Defender ATP onboarding configuration completed successfully!' -DebugMessage
        }
        catch {
            Write-Log -Message "Failed to configure Defender ATP onboarding: $($PSItem.Exception.Message)" -Severity Error
        }
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

try {

    ## Check if log path exists or if the log file exceeds size limit
    Test-LogFile -LogFile $Script:LogFullName -MaxSizeMB $Script:LogMaxSizeMB

    ## Extract organization information from onboarding JSON
    $OrganizationInfo = Get-OrganizationInfo -OnboardingJson $OnboardingJson
    $OrganizationID = $OrganizationInfo.CurrentOrgId
    $PreviousOrganizationIDs = $OrganizationInfo.PreviousOrgIds

    ## Write initial log entries
    Write-Log -Message "$Script:NameAndVersion Started"             -FormatOptions @{ Mode = 'CenteredBlock'; AddEmptyRow = 'After' }
    Write-Log -Message 'ENVIRONMENT'                                -FormatOptions @{ Mode = 'InlineHeader'; AddEmptyRow = 'After' }
    Write-Log -Message "Running elevated: [$Script:RunningAsAdmin]" -FormatOptions @{ Mode = 'Default' }
    Write-Log -Message "Running as:       [$Script:RunningAs]"      -FormatOptions @{ Mode = 'Default' }
    Write-Log -Message "Script path:      [$Script:Path]"           -FormatOptions @{ Mode = 'Default' }
    Write-Log -Message "Log path:         [$Script:LogPath]"        -FormatOptions @{ Mode = 'Default' }
    Write-Log -Message 'PREQUISITES'                                -FormatOptions @{ Mode = 'InlineHeader'; AddEmptyRow = 'BeforeAndAfter' }
    Write-Log -Message '>> Starting Pre-Onboarding Actions'         -FormatOptions @{ Mode = 'TimelineHeader' }

    ## Check for administrative privileges
    if (-not $Script:RunningAsAdmin) {
        Write-Log -Message 'Script is not running with administrative privileges. Please run with administrator privileges' -Severity Error
    }

    ## Check if system is already onboarded with correct OrganizationID and valid state
    if ((Test-DefenderATPOrganizationID -OrganizationID $OrganizationID) -and (Test-DefenderATPOnboardingState -ExpectedValue 1)) {
        $ResultMessage = 'Already onboarded, exiting...'
        $Script:ErrorCode = 0
        return
    }

    ## Remove previous onboarding information if specified
    if ($PreviousOrganizationIDs -and $PreviousOrganizationIDs.Count -gt 0) {
        Remove-DefenderATPOnboarding -OrganizationIDs $PreviousOrganizationIDs -ErrorAction Stop
    }

    ## Start onboarding
    Write-Log -Message 'ONBOARDING' -FormatOptions @{ Mode = 'InlineHeader'; AddEmptyRow = 'BeforeAndAfter' }
    Write-Log -Message '>> Starting Onboarding Actions' -FormatOptions @{ Mode = 'TimelineHeader' }

    ## Configure ATP onboarding
    Set-DefenderATPOnboarding -OnboardingJson $OnboardingJson -ErrorAction Stop

    ## Start the SENSE service and wait for it to be running
    Wait-ForServiceState -ServiceName 'SENSE' -DesiredState 'Running' -StartIfNeeded -TimeoutSeconds 25 -ErrorAction Stop

    ## Wait for onboarding status to be available and properly configured
    if (Test-DefenderATPOrganizationID -OrganizationID $OrganizationID) {
        $null = Test-DefenderATPOnboardingState -ExpectedValue 1 -Wait -TimeoutSeconds 20
    }
    else {
        Write-Log -Message 'Organization ID validation failed after onboarding' -Severity Error
    }

    Write-Log -Message 'POST-ONBOARDING' -FormatOptions @{ Mode = 'InlineHeader'; AddEmptyRow = 'BeforeAndAfter' }
    Write-Log -Message '>> Starting Post-Onboarding Actions' -FormatOptions @{ Mode = 'TimelineHeader' }

    ## Reload Windows Defender engine
    Write-Log -Message 'Reloading Windows Defender engine'
    $MpCmdPath = Join-Path -Path $env:ProgramFiles -ChildPath 'Windows Defender\MpCmdRun.exe'
    if (Test-Path -Path $MpCmdPath) {
        try {
            Start-Process -FilePath $MpCmdPath -ArgumentList '-ReloadEngine' -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue
            Write-Log -Message 'Windows Defender engine reloaded successfully' -DebugMessage
        }
        catch {
            Write-Log -Message "Failed to reload Windows Defender engine: $($PSItem.Exception.Message)" -Severity Error
        }
    }
    else {
        Write-Log -Message 'Windows Defender MpCmdRun.exe not found, skipping engine reload' -Severity Warning
    }

    ## Set device group tag
    if (-not [string]::IsNullOrEmpty($DeviceGroupTag)) {
        Write-Log -Message "Setting device group tag: [$DeviceGroupTag]"
        $null = Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Advanced Threat Protection\DeviceTagging' -Name 'Group' -Value $DeviceGroupTag -Type String -ErrorAction Stop
    }

    ## Set result message
    $ResultMessage = "Successfully onboarded [$($env:ComputerName)] to Microsoft Defender ATP!"

    ## Write telemetry message
    Write-Log              -Message 'Sending telemetry message to Windows Defender ATP'
    Write-EventLogEntry    -Message $ResultMessage -EventId 20 -EntryType Information
    Write-TelemetryMessage -Message $ResultMessage -Level Informational

    $Script:ErrorCode = 0
}
catch {

    ## Set result message
    $ResultMessage = "Failed to onboard [$($env:ComputerName)] to Microsoft Defender ATP: $($PSItem.Exception.Message)"

    ## Write event log entry and telemetry message
    Write-Log -Message 'Sending telemetry message to Windows Defender ATP'
    Write-EventLogEntry    -Message $ResultMessage -EventId 20 -EntryType Error
    Write-TelemetryMessage -Message $ResultMessage -Level Error

    $Script:ErrorCode = 1
}
finally {

    ## Write summary
    Write-Log -Message 'SUMMARY' -FormatOptions @{ Mode = 'InlineHeader'; AddEmptyRow = 'BeforeAndAfter' }
    Write-Log -Message $ResultMessage -Severity Information

    ## End logging
    Write-Log -Message "$Script:NameAndVersion Completed" -FormatOptions @{ Mode = 'CenteredBlock'; AddEmptyRow = 'Before' }

    ## Flush any remaining log buffer
    Write-LogBuffer

    ## Exit with appropriate code
    exit $Script:ErrorCode
}

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================
