<#
.SYNOPSIS
    Discover Microsoft Defender ATP onboarding state
.DESCRIPTION
    Discovers the current Microsoft Defender ATP onboarding state.
.PARAMETER OnboardingJson
    Onboarding information in JSON format.
.EXAMPLE
    .\Discover-DefenderATPOnboarding.ps1 -Verbose
    Discovers the current Microsoft Defender ATP onboarding state.
.INPUTS
    System.String.
.OUTPUTS
    System.String (compliance state).
.NOTES
    Created by Ioan Popovici
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    Microsoft Defender ATP
.FUNCTIONALITY
    Discover Microsoft Defender ATP onboarding state
#>

## Set script requirements
#Requires -Version 5.1

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
$Script:LogName          = 'Discover-WindowsDefenderATPOnboarding'
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

    ## Write initial log entries
    Write-Log -Message "$Script:NameAndVersion Started"             -FormatOptions @{ Mode = 'CenteredBlock'; AddEmptyRow = 'After' }
    Write-Log -Message 'ENVIRONMENT'                                -FormatOptions @{ Mode = 'InlineHeader'; AddEmptyRow = 'After' }
    Write-Log -Message "Running elevated: [$Script:RunningAsAdmin]" -FormatOptions @{ Mode = 'Default' }
    Write-Log -Message "Running as:       [$Script:RunningAs]"      -FormatOptions @{ Mode = 'Default' }
    Write-Log -Message "Script path:      [$Script:Path]"           -FormatOptions @{ Mode = 'Default' }
    Write-Log -Message "Log path:         [$Script:LogPath]"        -FormatOptions @{ Mode = 'Default' }
    Write-Log -Message 'DISCOVERY'                                  -FormatOptions @{ Mode = 'InlineHeader'; AddEmptyRow = 'BeforeAndAfter' }
    Write-Log -Message '>> Starting  Discovery'                     -FormatOptions @{ Mode = 'TimelineHeader' }

    ## Check if system is already onboarded with correct OrganizationID and valid state
    if ((Test-DefenderATPOrganizationID -OrganizationID $OrganizationID) -and (Test-DefenderATPOnboardingState -ExpectedValue 1)) {
        $ComplianceState = 'Compliant'
    }
    else {
        $ComplianceState = 'NonCompliant'
    }
}
catch {

   ## If discovery fails for any reason, return a clear failure message and assume non-compliant to be safe
   [string]$ComplianceState = "Compliance state: [NonCompliant] - Discovery Failed: [$($PSItem.Exception.Message)]"
   Write-Log -Severity Error -Message $ComplianceState
}
finally {

    ## Log the compliance
    Write-Log -Message 'SUMMARY' -FormatOptions @{ Mode = 'InlineHeader'; AddEmptyRow = 'BeforeAndAfter' }
    Write-Log -Message "Compliance state: [$ComplianceState]" -FormatOptions @{ Mode = 'TimelineHeader' }

    ## End logging
    Write-Log -Message "$Script:NameAndVersion Completed" -FormatOptions @{ Mode = 'CenteredBlock'; AddEmptyRow = 'Before' }

    ## Flush any remaining log buffer
    Write-LogBuffer

    ## Output the compliance state
    Write-Output -InputObject $ComplianceState
}

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================
