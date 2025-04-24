<#
.SYNOPSIS
    Removes matching installed applications.
.DESCRIPTION
    Removes matching installed applications using a specified search pattern in bulk.
    Supports both MSI and EXE uninstallation methods.
    AppX support is not yet implemented.
.PARAMETER SearchPattern
    Specifies application name patterns to remove (supports wildcards).
.EXAMPLE
    .\Remove-Application.ps1
    Uninstalls all applications matching the default search pattern.
.EXAMPLE
    .\Remove-Application.ps1 -SearchPatterns "7-Zip*", "Adobe*"
    Uninstalls all applications matching the specified patterns.
.INPUTS
    None.
.OUTPUTS
    None.
.NOTES
    Created by Ioan Popovici 2025-04-04
.LINK
    https://MEMZ.one/Remove-Application
.LINK
    https://MEMZ.one/Remove-Application-CHANGELOG
.LINK
    https://MEMZ.one/Remove-Application-GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    Application Management
.FUNCTIONALITY
    Removes Matching Applications
#>

## Set script requirements
#Requires -Version 5.0

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

## Get script parameters
[CmdletBinding()]
param (
    [Parameter(Position = 0)]
    [Alias('Applications')]
    [ValidateNotNullOrEmpty()]
    [string[]]$SearchPatterns
)

## Define default application search patterns
[string[]]$ApplicationDetectionRules = @(
    'Dell SupportAssist*'
    '*minitool*'
    '*treesize*'
    '*krita*'
    '*ccleaner*'
    '*recuva*'
    '*download manager*' # '_iu14D2N.tmp'
    #  Add more applications as needed
)

## Define EXE uninstaller detection rules
#  These rules are used to identify the type of uninstaller based on the uninstaller executable metadata
[array]$Script:UninstallerMetadataDetectionRules = @(
    @{ Pattern = '*NSIs*'                    ; SilentArgs = '/S'                                       ; Type = 'NSIs'              },
    @{ Pattern = '*Inno*'                    ; SilentArgs = '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART' ; Type = 'Inno Setup'        },
    @{ Pattern = '*InstallShield*'           ; SilentArgs = '/s'                                       ; Type = 'InstallShield'     },
    @{ Pattern = '*Squirrel*'                ; SilentArgs = '--uninstall'                              ; Type = 'Squirrel'          },
    @{ Pattern = '*Google Chrome Installer*' ; SilentArgs = '--force-uninstall'                        ; Type = 'Google Chrome'     },
    @{ Pattern = '*Adobe*'                   ; SilentArgs = '/sAll /rs /rps'                           ; Type = 'Adobe Installer'   }
)
#  These rules are used to identify the type of uninstaller based on the executable name
[array]$Script:UninstallerFileNameDetectionRules = @(
    @{ Pattern = 'uninst.exe$'               ; SilentArgs = '/S'                                       ; Type = 'NSIs'              },
    @{ Pattern = 'unins\d{3}\.exe$'          ; SilentArgs = '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART' ; Type = 'Inno Setup'        },
    @{ Pattern = 'setup\.exe$'               ; SilentArgs = '/s'                                       ; Type = 'InstallShield'     },
    @{ Pattern = 'install\.exe$'             ; SilentArgs = '/quiet'                                   ; Type = 'Generic Installer' },
    @{ Pattern = 'update\.exe$'              ; SilentArgs = '--uninstall'                              ; Type = 'Squirrel'          }
)

## Do not modify anything below this line unless you know what you're doing

## Get script information
[PSCustomObject]$Script = @{
    Name             = 'Remediate-BlacklistedApplications'
    Version          = '1.1.1b'
    Path             = $MyInvocation.MyCommand.Path
    Directory        = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
    LogPrefix        = 'Uninstall-BlacklistedApplications'
    LogDebugMessages = $false
    MaxLogSizeMB     = 5
}

## Set default matching applications if none provided, working around for the 'Compliant' state passed by the Discovery script
if (-not $PSBoundParameters['SearchPatterns'] -or $PSBoundParameters['SearchPatterns'] -eq 'Compliant') { $SearchPatterns = $ApplicationDetectionRules }

## Set up logging in ProgramData with a single log file
[string]$LogDirectory = Join-Path -Path $env:ProgramData -ChildPath "Logs\$($Script.LogPrefix)"
[string]$LogFile = Join-Path -Path $LogDirectory -ChildPath "$($Script.LogPrefix).log"
#  Initializing Log buffer
$LogBuffer = [System.Collections.ArrayList]::new()
#  Ensure log directory exists
[bool]$isLogDirectoryCreated = Test-Path -Path $LogDirectory -PathType Container
if (-not $isLogDirectoryCreated) {
    try {
        $null = New-Item -Path $LogDirectory -ItemType Directory -Force -ErrorAction Stop
    }
    catch {
        ## Fallback to script directory if ProgramData is inaccessible
        [string]$LogDirectory = $Script.Directory
        [string]$LogFile = Join-Path -Path $LogDirectory -ChildPath "$($Script.LogPrefix).log"
    }
}
#  Create log file if it doesn't exist
[bool]$isLogFileCreated = Test-Path -Path $LogFile -PathType Leaf
if (-not $isLogFileCreated) {
    try {
        $null = New-Item -Path $LogFile -ItemType File -Force -ErrorAction Stop
    }
    catch {
        Write-Warning -Message "Failed to create log file: $($PSItem.Exception.Message)"
    }
}

## Set environment variables
[string]$ScriptRunningAs = $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)
[string]$ScriptNameAndVersion = "$($Script.Name) v$($Script.Version)"

#endregion
##*=============================================
##* END VARIABLE DECLARATION
##*=============================================

##*=============================================
##* FUNCTION LISTINGS
##*=============================================
#region FunctionListings

#region function Test-LogFileSize
function Test-LogFileSize {
<#
.SYNOPSIS
    Checks if the log file exceeds the maximum size.
.DESCRIPTION
    Checks if the log file exists and exceeds the maximum size, and clears it if needed.
.PARAMETER LogFile
    Specifies the path to the log file.
.PARAMETER MaxSizeMB
    Specifies the maximum size in MB before the log file is cleared.
.EXAMPLE
    Test-LogFileSize -LogFile 'C:\Logs\Application.log' -MaxSizeMB 5
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
#>
    [CmdletBinding()]
    param()

    process {
        if ($script:LogBuffer.Count -gt 0) {
            try {

                ## Convert ArrayList to string array for Add-Content
                [string[]]$LogEntries = $script:LogBuffer.ToArray()

                ## Append to log file
                Add-Content -Path $script:LogFile -Value $LogEntries -ErrorAction Stop

                ## Clear buffer
                $script:LogBuffer.Clear()
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
    Specifies the severity level of the message. Available options: Information, Warning, Debug, Error.
.PARAMETER Message
    The log message to write.
.PARAMETER FormatOptions
    Optional hashtable of parameters to pass to Format-Header for formatting the console and/or log output.
.PARAMETER LogDebugMessages
    Whether to write debug messages to the log file (default: value of $Script.LogDebugMessages).
.PARAMETER SkipLogFormatting
    Whether to skip formatting for the log message.
#>
    [CmdletBinding()]
    param (
        [Parameter(Position = 0)]
        [Alias('Level')]
        [ValidateSet('Information', 'Warning', 'Debug', 'Error')]
        [string]$Severity = 'Information',

        [Parameter(Mandatory = $true, Position = 1)]
        [Alias('LogMessage')]
        [ValidateNotNullOrEmpty()]
        [string]$Message,

        [Parameter()]
        [hashtable]$FormatOptions,

        [Parameter()]
        [switch]$LogDebugMessages = $Script:LogDebugMessages,

        [Parameter()]
        [switch]$SkipLogFormatting
    )

    begin {
        [string]$Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    }
    process {
        try {

            ## Apply formatting options if provided
            [string[]]$MessageLines = if ($PSBoundParameters.ContainsKey('$SkipLogFormatting')) {
                @($Message)
            }
            elseif ($PSBoundParameters.ContainsKey('FormatOptions')) {
                Format-Header -Message $Message @FormatOptions
            }
            else {
                Format-Header -Message $Message -Mode 'Timeline' -AddEmptyRow 'No'
            }

            ## Write to console and log file
            foreach ($MessageLine in $MessageLines) {
                switch ($Severity) {
                    'Information' { Write-Verbose -Message $MessageLine }
                    'Warning'     { Write-Warning -Message $MessageLine }
                    'Debug'       { Write-Debug -Message $MessageLine}
                    'Error'       { Write-Error -Message $MessageLine -ErrorAction Continue }
                }

                #  Skip debug logging if disabled
                if ($Severity -eq 'Debug' -and -not $LogDebugMessages) {
                    continue
                }

                #  Add timestamp and severity to the message and add to the log buffer
                [string]$LogEntry = "$Timestamp [$Severity] $MessageLine"
                $null = $Script:LogBuffer.Add($LogEntry)
            }

            #  Write the log buffer to the log file if it exceeds the threshold or if the severity is Error
            if ($Script:LogBuffer.Count -ge 10 -or $Severity -eq 'Error') {
                Write-LogBuffer
            }
        }
        catch {
            Write-Warning -Message "Write-Log failed: [$($PSItem.Exception.Message)]"
        }
    }
}
#endregion

#region Function Format-Header
Function Format-Header {
<#
.SYNOPSIS
    Formats a text header.
.DESCRIPTION
    Formats a header block, centered block, section header, sub-header, inline log, or adds separator rows.
.PARAMETER Message
    The main message to display (used for Block and CenteredBlock).
.PARAMETER AddEmptyRow
    Optionally adds blank lines before/after.
    Default is: 'No'.
.PARAMETER Mode
    Defines output style: Block, CenteredBlock, Line, InlineHeader, InlineSubHeader, Timeline, or AddRow.
    Default is: 'Block'.
.EXAMPLE
    Format-Header -Message 'UNINSTALL' -Mode InlineHeader
.EXAMPLE
    Format-Header -Message 'Mozilla Firefox (v137.0.1)' -Mode InlineSubHeader
.EXAMPLE
    Format-Header -Mode Line
.EXAMPLE
    Format-Header -Message 'Uninstalling Google Chrome v100.0.0.0' -Mode Timeline
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
    Console
.FUNCTIONALITY
    Format Output
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,

        [Parameter(Position = 1)]
        [ValidateSet('No', 'Before', 'After', 'BeforeAndAfter')]
        [string]$AddEmptyRow = 'No',

        [Parameter(Position = 2)]
        [ValidateSet('Block', 'CenteredBlock', 'Line', 'InlineHeader', 'InlineSubHeader', 'Timeline', 'Default')]
        [string]$Mode = 'Default'
    )

    begin {

        ## Fixed output width
        [int]$LineWidth = 60
        [string]$Separator = '=' * $LineWidth
    }
    process {
        try {
            [string[]]$OutputLines = @()

            ## Format the message based on the specified mode
            switch ($Mode) {
                'Line' {
                    $OutputLines = @($Separator)
                }
                'Block' {

                    #  Add prefix and format message
                    [string]$Prefix = '▶ '
                    [int]$MaxMessageLength = $LineWidth - $Prefix.Length
                    [string]$FormattedMessage = $Prefix + $Message.Trim()

                    #  Truncate message if it exceeds the maximum length
                    if ($FormattedMessage.Length -gt $LineWidth) { $FormattedMessage = $Prefix + $Message.Trim().Substring(0, $MaxMessageLength - 3) + '...' }

                    #  Add separation lines
                    $OutputLines = @($Separator, $FormattedMessage, $Separator)
                }
                'CenteredBlock' {

                    #  Trim message
                    [string]$CleanMessage = $Message.Trim()

                    #  Truncate message if it exceeds the maximum length
                    if ($CleanMessage.Length -gt ($LineWidth - 4)) { $CleanMessage = $CleanMessage.Substring(0, $LineWidth - 7) + '...' }

                    #  Center the message
                    [int]$ContentWidth = $CleanMessage.Length
                    [int]$SidePadding = [math]::Floor(($LineWidth - $ContentWidth) / 2)
                    [string]$CenteredLine = $CleanMessage.PadLeft($ContentWidth + $SidePadding).PadRight($LineWidth)

                    #  Add separator lines
                    $OutputLines = @($Separator, $CenteredLine, $Separator)
                }
                'InlineHeader' {

                    #  Trim and truncate message
                    [string]$Trimmed = $Message.Trim()
                    if ($Trimmed.Length -gt 54) { $Trimmed = $Trimmed.Substring(0, 51) + '...' }

                    #  Add padding to the message
                    [string]$HeaderLine = "===[ $Trimmed ]==="
                    $OutputLines = @($HeaderLine)
                }
                'InlineSubHeader' {

                    #  Trim and truncate message
                    [string]$Trimmed = $Message.Trim()
                    if ($Trimmed.Length -gt 54) { $Trimmed = $Trimmed.Substring(0, 51) + '...' }

                    #  Add padding to the message
                    [string]$HeaderLine = "---[ $Trimmed ]---"
                    $OutputLines = @($HeaderLine)
                }
                'Timeline' {

                    #  Add prefix to the message
                    $HeaderLine = "    - $Message"
                    $OutputLines = @($HeaderLine)
                }
                Default {

                    #  Trim the message
                    $OutputLines = @($Message.Trim())
                }
            }

            ## Add spacing if requested
            switch ($AddEmptyRow) {
                'Before' {
                    $OutputLines = @('') + $OutputLines
                }
                'After' {
                    $OutputLines += ''
                }
                'BeforeAndAfter' {
                    $OutputLines = @('') + $OutputLines + @('')
                }
            }

            ## Output
            foreach ($OutputLine in $OutputLines) {
                Write-Output -InputObject $OutputLine
            }
        }
        catch {
            Continue
        }
    }
}
#endregion

#region function Get-Application
function Get-Application {
<#
.SYNOPSIS
    Gets installed applications from the registry.
.DESCRIPTION
    Gets installed applications from the registry by querying the uninstall keys.
    If search patterns are provided, returns only matching applications.
.PARAMETER SearchPatterns
    Optional search patterns to match against application display names.
.EXAMPLE
    Get-Application
    Returns all installed applications.
.EXAMPLE
    Get-Application -SearchPatterns "*chrome*", "*vlc*"
    Returns only applications with display names matching the patterns.
.INPUTS
    None.
.OUTPUTS
    System.Collections.ArrayList
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
#>
    [CmdletBinding()]
    [OutputType([System.Collections.ArrayList])]
    param (
        [Parameter()]
        [string[]]$SearchPatterns
    )

    begin {

        ## Set Registry paths for installed applications
        [string[]]$UninstallPaths = @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
            'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
            'HKCU:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
        )

        ## Initialize application lists
        $InstalledApplications = [System.Collections.ArrayList]::new()
        $FilteredApplications = [System.Collections.ArrayList]::new()
        #  Log the start of the process
        Write-Log -Message 'Retrieving installed applications...' -FormatOptions @{ AddEmptyRow = 'After' }
    }
    process {
        try {

            ## Get registry application uninstall keys
            $UninstallKeys = Get-ItemProperty -Path $UninstallPaths -ErrorAction SilentlyContinue

            ## Process items without pipeline
            foreach ($UninstallKey in $UninstallKeys) {
                if (-not [string]::IsNullOrWhiteSpace($UninstallKey.DisplayName)) {
                    $Application = [PSCustomObject]@{
                        DisplayName          = $UninstallKey.DisplayName
                        DisplayVersion       = $UninstallKey.DisplayVersion
                        Publisher            = $UninstallKey.Publisher
                        UninstallString      = $UninstallKey.UninstallString
                        QuietUninstallString = $UninstallKey.QuietUninstallString
                        PSPath               = $UninstallKey.PSPath
                    }
                    $null = $InstalledApplications.Add($Application)
                }
            }
            #  Log installed applications
            Write-Log -Severity Debug -Message $($InstalledApplications | Out-String) -FormatOptions @{ AddEmptyRow = 'After' }

            ## If search patterns are supplied, filter the list
            if ($SearchPatterns) {
                Write-Log -Severity Debug -Message "Filtering applications using search patterns: [$($SearchPatterns -join ', ')]" -FormatOptions @{ AddEmptyRow = 'After' }
                foreach ($InstalledApp in $InstalledApplications) {
                    foreach ($SearchPattern in $SearchPatterns) {
                        if ($InstalledApp.DisplayName -like $SearchPattern) {
                            $null = $FilteredApplications.Add($InstalledApp)
                            break
                        }
                    }
                }

                ## Log the number of matching applications
                [int]$MatchCount = $FilteredApplications.Count
                Write-Log -Message "Found [$MatchCount/$($InstalledApplications.Count)] matching application(s)" -FormatOptions @{ Mode = 'Default' }

                ## Output the filtered list
                # Get longest display name length
                [int]$MaxNameLength = ($FilteredApplications.DisplayName | ForEach-Object { $PsItem.Length } | Measure-Object -Maximum).Maximum
                #  Format and output the filtered list
                foreach ($Application in $FilteredApplications) {
                    [string]$PaddedApplicationName = $Application.DisplayName.PadRight($MaxNameLength)
                    Write-Log -Message "$PaddedApplicationName | Version: $($Application.DisplayVersion)"
                }
            }
        }
        catch {
            Write-Log -Severity Error -Message "Error retrieving installed applications: [$($PSItem.Exception.Message)]" -FormatOptions @{ AddEmptyRow = 'After' }
        }
        finally {

            ## Output matching or full list based on presence of search patterns
            $OutputList = if ($SearchPatterns) { $FilteredApplications } else { $InstalledApplications }
            if ($OutputList) {
                Write-Log -Severity Debug -Message ($OutputList -join "`n") -FormatOptions @{ AddEmptyRow = 'After' }
            }
            Write-Output -InputObject $OutputList -NoEnumerate
        }
    }
}
#endregion

#region function Get-InstallerCommand
function Get-InstallerCommand {
<#
.SYNOPSIS
    Splits an install or uninstall string into executable, arguments, and metadata.
.DESCRIPTION
    Uses regex to separate the executable path and arguments from a given uninstall string.
    Also detects whether known silent uninstall arguments are already present.
.PARAMETER CommandString
    The installer command string.
.EXAMPLE
    Get-InstallerCommand -CommandString 'C:\Program Files\App\uninstall.exe /S'
.INPUTS
    System.String
.OUTPUTS
    System.PSCustomObject
.NOTES
    This is an internal script function and should typically not be called directly.
#>

    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$CommandString
    )

    begin {
        Write-Log -Severity Debug -Message "Processing command string: [$CommandString]..."

        # Regex patterns
        [regex]$PathPattern = '^(?:["'']?(?<Path>[a-zA-Z]:\\(?:[^""''\s\\]+\\)*)(?<Exe>[^\\\/]+\.exe)["'']?|(?<Path>.+?\\)(?<Exe>[^\\]+\.exe))(?<Args>.*)?$'
        [regex]$SilentArgsPattern = '(?i)(?<=^|\s)(\/s|\/verysilent|\/quiet|\/silent|--force-uninstall|--force-install)(?=\s|$)'
    }
    process {
        try {
            if (-not ($CommandString -match $PathPattern)) {
                return [PSCustomObject]@{
                    Path          = ''
                    Name          = ''
                    Arguments     = ''
                    FullName      = ''
                    SilentArgs    = @()
                    hasSilentArgs = $false
                }
            }

            ## Normalize and parse components
            [string]$Path = $Matches['Path'].Trim('"')
            [string]$Name = $Matches['Exe'].Trim('"')
            [string]$Arguments = $Matches['Args'].Trim('"')
            [string]$FullName = Join-Path -Path $Path -ChildPath $Name

            ## Extract silent switches
            [string[]]$SilentArgs = [regex]::Matches($Arguments, $SilentArgsPattern) | ForEach-Object { $PSItem.Value.Trim() }

            ## Set hasSilentArgs flag
            [bool]$hasSilentArgs = $SilentArgs.Count -gt 0

            #  If only /SILENT or is present, set hasSilentArgs to false because it's not a fully silent argument
            if ($SilentArgs.Count -eq 1 -and $SilentArgs[0] -ceq '/SILENT') { $hasSilentArgs = $false }

            # Output
            return [PSCustomObject]@{
                Path          = $Path
                Name          = $Name
                Arguments     = $Arguments
                FullName      = $FullName
                SilentArgs    = $SilentArgs
                hasSilentArgs = $hasSilentArgs
            }
        }
        catch {
            Write-Log -Severity Error -Message "Failed to process command string: $($PSItem.Exception.Message)"
        }
    }
}
#endregion

#region function Get-SilentUninstallCommand
function Get-SilentUninstallCommand {
<#
.SYNOPSIS
    Builds a silent uninstall command based on known installer types.
.DESCRIPTION
    Identifies installer type from EXE name and metadata, and appends proper silent flags.
.PARAMETER UninstallString
    Raw uninstall string from the registry.
.PARAMETER FilenameRules
    Optional array of filename-based uninstall detection rules.
.PARAMETER MetadataRules
    Optional array of metadata-based uninstall detection rules.
.EXAMPLE
    Get-SilentUninstallCommand -UninstallString 'C:\Program Files\Example\uninstall.exe'
    Returns a command with silent arguments based on the installer type.
.INPUTS
    None.
.OUTPUTS
    System.String
        - Fully assembled, shell-ready uninstall command string.
        - The silent uninstall command string.
        - If no silent arguments are found, returns the original uninstall string.
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
#>
    [CmdletBinding()]
    [OutputType([System.String])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$UninstallString,

        [Parameter()]
        [array]$MetadataRules = $Script:UninstallerMetadataDetectionRules,

        [Parameter()]
        [array]$FilenameRules = $Script:UninstallerFileNameDetectionRules
    )
    begin {

        ## Log the uninstall string
        Write-Log -Severity Debug -Message "Inferring silent uninstall string from: [$UninstallString]..."

        ## Initialize variables
        [string]$DetectedType = ''
        [string]$SilentArgs = ''
    }

    process {
        try {
            ## Parse the uninstall string
            [PSCustomObject]$UninstallParameters = Get-InstallerCommand -CommandString $UninstallString
            [string]$ExecutableName = $UninstallParameters.Name
            [string]$ExecutableFullName = $UninstallParameters.FullName
            [string]$Arguments = $UninstallParameters.Arguments
            [bool]$hasSilentArgs = $UninstallParameters.hasSilentArgs

            ## If we already have silent args, return early
            If ($hasSilentArgs) {
                Write-Log -Message 'Silent arguments already present'
                return
            }

            ## Attempt metadata-based detection first if have a valid executable
            if (Test-Path -Path $ExecutableFullName) {
                try {
                    #  Get executable metadata
                    $VersionInfo = (Get-Item -Path $ExecutableFullName).VersionInfo
                    $MetaString = "$($VersionInfo.ProductName) | $($VersionInfo.CompanyName) | $($VersionInfo.FileDescription)"
                    Write-Log -Severity Debug -Message "EXE Metadata: $MetaString"
                    #  Loop through metadata rules to find a match and exit immediately if found
                    foreach ($MetadataRule in $MetadataRules) {
                        if ($MetaString -like $MetadataRule.Pattern) {
                            $SilentArgs = $MetadataRule.SilentArgs
                            $DetectedType = $MetadataRule.Type
                            break
                        }
                    }

                    if (-not [string]::IsNullOrWhiteSpace($SilentArgs)) {
                        Write-Log -Message "Detected via metadata [$DetectedType]: [$SilentArgs]"
                    }
                }
                catch {
                    Write-Log -Severity Warning -Message "Failed to read EXE metadata: $($PSItem.Exception.Message)"
                }
            }

            ## Fallback to filename-based detection if metadata detection failed (silent args are still empty)
            if ([string]::IsNullOrWhiteSpace($SilentArgs)) {

                #  Loop through filename rules to find a match and exit immediately if found
                foreach ($FilenameRule in $FilenameRules) {
                    if ($ExecutableName -match $FilenameRule.Pattern) {
                        $SilentArgs = $FilenameRule.SilentArgs
                        $DetectedType = $FilenameRule.Type
                        break
                    }
                }

                ## Default fallback if nothing matched
                if ([string]::IsNullOrWhiteSpace($SilentArgs)) {
                    $SilentArgs = '/S'
                    $DetectedType = 'Unknown'
                }
                Write-Log -Message "Detected via fallback [$DetectedType]: [$SilentArgs]"
            }

            ## Construct final argument list, make sure to remove any leading/trailing/internal extra spaces
            [string]$MergedArguments = if ([string]::IsNullOrWhiteSpace($SilentArgs)) {
                $Arguments
            }
            else {
                [string]::Join(' ', @(($SilentArgs, ($Arguments -split '\s+' -join ' ')) | Where-Object { $PSItem }))
            }

            ## Construct final uninstall command
            [string]$UninstallString = [string]::Join(' ', @($ExecutableFullName, $MergedArguments))
            Write-Log -Severity Debug -Message "Detected silent uninstall string: [$UninstallString]"
        }
        catch {
            Write-Log -Severity Error -Message "Failed to process uninstall string: $($PSItem.Exception.Message)"
        }
        finally {
            Write-Output -InputObject $UninstallString
        }
    }
}
#endregion

#region function Test-MsiExecuteMutex
function Test-MsiExecuteMutex {
<#
.SYNOPSIS
    Tests if the Windows Installer is currently in use.
.DESCRIPTION
    Tests if the Windows Installer is currently in use by checking for the MSI Mutex.
.EXAMPLE
    Test-MsiInUse
.INPUTS
    None.
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
#>
    [CmdletBinding()]
    [OutputType([bool])]
    param ()

    process {
        try {

            ## Check for the _MSIExecute mutex - this indicates if Windows Installer is in use
            $Mutex = [System.Threading.Mutex]::OpenExisting('Global\_MSIExecute')
            $Mutex.Dispose()

            ## If we can open the mutex, it means Windows Installer is in use
            Write-Log -Severity Debug -Message 'MSI mutex present: [_MSIExecute]'
            return $true
        }
        catch {

            ## If we can't open the mutex, it means Windows Installer is not in use
            Write-Log -Severity Debug 'MSI mutex not present: [_MSIExecute]'
            return $false
        }
    }
}
#endregion

#region function Wait-ForMsiExecuteMutex
function  Wait-ForMsiExecuteMutex {
<#
.SYNOPSIS
    Tests if the Windows Installer is currently in use.
.DESCRIPTION
    Tests if the Windows Installer is currently in use by checking for the MSI Mutex.
.PARAMETER TimeoutSeconds
    Specifies the maximum time to wait for the Windows Installer to become available.
.PARAMETER IntervalSeconds
    Specifies the interval time to wait between checks.
.EXAMPLE
    Wait-ForMsiExecuteMutex -TimeoutSeconds 300 -IntervalSeconds 5
.INPUTS
    None.
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
#>
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Position = 0)]
        [int]$TimeoutSeconds = 120,

        [Parameter(Position = 1)]
        [int]$IntervalSeconds = 5
    )

    process {
        try {

            $Elapsed = 0
            While (Test-MsiExecuteMutex) {
                if ($Elapsed -ge $TimeoutSeconds) {
                    Write-Log -Severity Error -Message "Timeout: Windows Installer is still unavailable after [$TimeoutSeconds`s]"
                    return $false
                }
                Write-Log -Message "Waiting: Windows Installer is unavailable, [$Elapsed`s] elapsed..."
                Start-Sleep -Seconds $IntervalSeconds
                $Elapsed += $IntervalSeconds
            }

            Write-Log -Message 'Windows Installer is now available...'
            return $true
        }
        catch {
            Write-Log -Severity Debug -Message "Windows Installer status check failed: $($PSItem.Exception.Message)"
            return $false
        }
    }
}
#endregion

#region function Lock-Mutex
function Lock-Mutex {
<#
.SYNOPSIS
    Locks a global mutex to prevent concurrent operations.
.DESCRIPTION
    Attempts to acquire a named global mutex with a timeout. Returns a result object
    indicating whether the lock was successfully acquired.
.PARAMETER Name
    The name of the mutex to lock.
.PARAMETER TimeoutSeconds
    Maximum number of seconds to wait for the mutex. Default is 600 seconds.
.PARAMETER ExitOnFailure
    If true (default), exits the script if the mutex cannot be acquired.
.PARAMETER Global
    If true, the mutex is created as a global mutex. Default is false.
.EXAMPLE
    Lock-Mutex -Name 'MyMutex' -TimeoutSeconds 300 -Global -ExitOnFailure
.INPUTS
    None.
.OUTPUTS
    PSCustomObject with:
        - Success:      [System.Boolean]
        - Mutex:        [System.Threading.Mutex]
        - Name:         [System.String]
        - ErrorMessage: [System.String]
.NOTES
    This is an internal script function and should typically not be called directly.
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Name,

        [Parameter(Position = 1)]
        [int]$TimeoutSeconds = 600,

        [Parameter()]
        [switch]$ExitOnFailure,

        [Parameter()]
        [switch]$Global
    )

    begin {

        ## Set mutex name to global if specified
        if ($PSBoundParameters['Global']) {
            $Name = "Global\$Name"
        }

        ## Initialize result object early
        $Result = [PSCustomObject]@{
            Success      = $false
            Mutex        = $null
            Name         = $Name
            ErrorMessage = ''
        }

        ## Check if the mutex name is valid
        if ($Name -notmatch '^[\w\\-]+$') {
            $Result.ErrorMessage = "Invalid mutex name [$Name]: Only letters, numbers, underscores, and hyphens allowed"
            Write-Log -Severity Error -Message $Result.ErrorMessage
            return $Result
        }

        ## Check if the mutex name is too long
        if ($Name.Length -gt 260) {
            $Result.ErrorMessage = "Mutex name [$Name] exceeds maximum length of 260 characters"
            Write-Log -Severity Error -Message $Result.ErrorMessage
            return $Result
        }
    }

    process {
        try {
            Write-Log -Severity Debug -Message "Acquiring mutex: [$Name]..."
            $Mutex = [System.Threading.Mutex]::new($false, $Name)
            if ($Mutex.WaitOne([TimeSpan]::FromSeconds($TimeoutSeconds), $false)) {
                #  Set the result object
                $Result.Success = $true
                $Result.Mutex = $Mutex
                #  Log the successful acquisition of the mutex
                $Message = "Mutex acquired: [$Name]"
                Write-Log -Severity Debug -Message $Message
            }
            else {

                ## If the mutex acquisition timed out, set and log the error message
                $Message = "Timeout: Waited [$TimeoutSeconds`s] for mutex [$Name]"
                $Result.ErrorMessage = $Message
                Write-Log -Severity Warning -Message $Message
            }
        }
        catch {
            $Result.ErrorMessage = $PSItem.Exception.Message
            Write-Log -Severity Error -Message "Mutex acquisition failed for [$Name]: $($PSItem.Exception.Message)"
        }
        finally {

            ## Output the result object
            Write-Output -InputObject $Result

            ## If the lock failed and ExitOnFailure is set, exit here
            if (-not $Result.Success -and $ExitOnFailure) {
                Write-Log -Message -Severity Error "Exit triggered by mutex conflict [$Name]: Already held by another process"

                ## Exit the script with a non-zero (failure) exit code
                exit 1
            }
        }
    }
}
#endregion

#region function Unlock-Mutex
function Unlock-Mutex {
<#
.SYNOPSIS
    Releases and disposes a mutex.
.DESCRIPTION
    Releases and disposes a mutex, allowing other processes to acquire it.
.PARAMETER Mutex
    The System.Threading.Mutex object to release.
.PARAMETER Name
    The name of the mutex to release.
.EXAMPLE
    Unlock-Mutex -Mutex $MyMutex
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
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Threading.Mutex]$Mutex,

        [Parameter()]
        [string]$Name = '<Undefined>'
    )

    try {

        Write-Log -Severity Debug -Message "Releasing mutex: [$Name]"
        $Mutex.ReleaseMutex()
        Write-Log -Severity Debug -Message "Successfully released mutex: [$Name]"
    }
    catch {
        Write-Log -Severity Error -Message "Failed to release mutex [$Name]: $($PSItem.Exception.Message)"
    }
    finally {
        $Mutex.Dispose()
    }
}
#endregion

#region function Start-ProcessWithTimeout
function Start-ProcessWithTimeout {
<#
.SYNOPSIS
    Starts a process with timeout handling.
.DESCRIPTION
    Starts a process with the specified executable and arguments, and waits for it to complete with a timeout.
.PARAMETER FilePath
    Specifies the path to the executable file.
.PARAMETER Arguments
    Specifies the arguments to pass to the executable.
.PARAMETER TimeoutSeconds
    Specifies the timeout in seconds.
.EXAMPLE
    Start-ProcessWithTimeout -FilePath 'msiexec.exe' -Arguments '/x {ProductCode} /qn' -TimeoutSeconds 600
.INPUTS
    None.
.OUTPUTS
    System.Int32
        -1 = Timed out, process killed
        -2 = Failed to kill process
        -3 = Failed to start process
        0+ = Normal process exit code
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
#>
    [CmdletBinding()]
    [OutputType([int])]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [Alias ('Path')]
        [ValidateNotNullOrEmpty()]
        [string]$FilePath,

        [Parameter(Position = 1)]
        [string]$Arguments = '',

        [Parameter(Position = 2)]
        [ValidateRange(1, 3600)]
        [int]$TimeoutSeconds = 600
    )

    process {
        try {

            ## log the start of the process
            Write-Log -Severity Debug -Message "Starting [$FilePath $Arguments] (Timeout: [$TimeoutSeconds`s])"

            ## Create process start info
            $ProcessStartInfo = [System.Diagnostics.ProcessStartInfo]::new()
            $ProcessStartInfo.FileName = $FilePath
            $ProcessStartInfo.Arguments = $Arguments
            $ProcessStartInfo.UseShellExecute = $false
            $ProcessStartInfo.CreateNoWindow = $true

            ## Start the process
            $Process = [System.Diagnostics.Process]::Start($ProcessStartInfo)

            if (-not $Process) {
                Write-Log -Severity Error -Message "Failed to start process: [$FilePath]"
                return -3
            }

            Start-Sleep -Seconds 1  # wait briefly for UI to initialize

            if ($Process.MainWindowHandle -ne 0) {
                Write-Log -Severity Warning -Message 'Running interactively'
            }
            else {
                Write-Log -Message 'Running silently'
            }

            ## Wait for the process to exit with timeout
            $ExitedNormally = $Process.WaitForExit($TimeoutSeconds * 1000)

            ## Kill any child processes matching post*
            $null = Get-Process | Where-Object { $PSItem.Parent -eq $Process.Id -and $PSItem.ProcessName -like 'post*' } | Stop-Process -Force

            if (-not $ExitedNormally) {
                try {
                    $Process.Kill()
                    Write-Log -Severity Warning -Message "Terminated [$FilePath]: timeout after [$TimeoutSeconds`s]"
                    return -1
                }
                catch {
                    if ($Process.HasExited) {
                        Write-Log -Severity Warning -Message "Process [$FilePath] exited just before kill attempt (Exit Code: $($Process.ExitCode))"
                        return $Process.ExitCode
                    }
                    else {
                        Write-Log -Severity Error -Message "Failed to terminate [$FilePath]: $($PSItem.Exception.Message)"
                        return -2
                    }
                }
            }
            else {
                Write-Log -Severity Debug -Message "Process [$FilePath] exited normally (Exit Code: $($Process.ExitCode))"
                return $Process.ExitCode
            }
        }
        catch {
            Write-Log -Severity Error -Message "Error starting [$FilePath]: $($PSItem.Exception.Message)"
            return -3
        }
    }
}
#endregion

#region function Remove-Application
function Remove-Application {
<#
.SYNOPSIS
    Uninstalls an application.
.DESCRIPTION
    Uninstalls an application using the appropriate method (MSI or EXE).
    Uses a mutex to prevent concurrent uninstallation operations.
.PARAMETER Application
    Specifies the application to uninstall.
.EXAMPLE
    Remove-Application -Application $Application
.INPUTS
    None.
.OUTPUTS
   System.PSCustomObject
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
#>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullorEmpty()]
        [Alias('App')]
        [PSCustomObject]$Application
    )

    begin {
        [string]$ApplicationName = $Application.DisplayName
        [string]$ApplicationVersion = $Application.DisplayVersion
        [string]$UninstallString = $Application.UninstallString
        [string]$QuietUninstallString = $Application.QuietUninstallString
        [bool]$hasRegistrySilentArgs = -not [string]::IsNullOrEmpty($QuietUninstallString)
        [int]$TimeoutSeconds = 600

        ## Create result object
        [PSCustomObject]$Result = [PSCustomObject]@{
            Success            = $false
            ApplicationName    = $ApplicationName
            ApplicationVersion = $ApplicationVersion
            ExitCode           = $null
            ErrorMessage       = ''
        }

        ##  Log the start of the uninstallation
        Write-Log -Message "==> $ApplicationName v$ApplicationVersion" -FormatOptions @{ AddEmptyRow = 'Before' }

        ## Set the mutex name
        [string]$MutexName = $Script.Name + '_UninstallTask'
    }
    process {
        try {

            ## Wait 10 minutes for windows installer to be free before uninstalling
            if (-not (Wait-ForMsiExecuteMutex -TimeoutSeconds 120 -IntervalSeconds 5)) {
                return
            }

            ## Try to acquire the mutex to ensure only one uninstall process runs at a time
            $UninstallMutex = Lock-Mutex -Name $MutexName -TimeoutSeconds 600 -Global

            ## If mutex acquisition failed, skip the uninstallation
            if (-not $UninstallMutex.Success) {
                Write-Log -Message -Severity Warning 'Mutex acquisition failed, skipping uninstallation...'
                $Result.ExitCode = $UninstallMutex.ErrorMessage
                return
            }

            ## Check if it's an MSI uninstall
            if ($UninstallString -match 'msiexec') {

                ## Extract product code from uninstall string
                if ($UninstallString -match '{[0-9A-Fa-f\-]{36}}') {
                    [string]$ProductCode = $Matches[0]
                    Write-Log -Severity Debug -Message "Detected MSI product code: [$ProductCode]"

                    ## Start the uninstall process
                    Write-Log -Message 'Starting MSI uninstall...'

                    #  Set up the executable and arguments
                    [string]$FilePath = 'msiexec.exe'
                    [string]$Arguments = "/x $ProductCode /qn /norestart"
                    [int]$ExitCode = Start-ProcessWithTimeout -FilePath $FilePath -Arguments $Arguments -TimeoutSeconds $TimeoutSeconds
                    $Result.ExitCode = $ExitCode

                    ## Check the exit code and handle accordingly
                    switch ($ExitCode) {

                        { $PSItem -in @(0, 3010, 19) } {

                            #  Exit code 19: Possibly non-fatal condition (e.g., partial uninstall or app still running)
                            Write-Log -Message "SUCCESSFUL (Exit Code: $ExitCode)"
                            $Result.Success = $true
                            break
                        }

                        1618 {
                            $Result.ErrorMessage = 'FAILED - Another install in progress (Exit Code: $ExitCode)'
                            Write-Log -Severity Warning -Message $Result.ErrorMessage
                            break
                        }

                        -1 {
                            $Result.ErrorMessage = "FAILED - Uninstall timed out (Exit Code: $ExitCode)"
                            Write-Log -Severity Warning -Message $Result.ErrorMessage
                            break
                        }

                        default {
                            $Result.ErrorMessage = "FAILED - Failed to uninstall MSI application (Exit Code: $ExitCode)"
                            Write-Log -Severity Warning -Message $Result.ErrorMessage
                        }
                    }
                }
                else {
                    $Result.ErrorMessage = "FAILED - Could not extract MSI product code (Uninstall string: $UninstallString)"
                    Write-Log -Severity Warning -Message $Result.ErrorMessage
                }
            }

            ## Check if it's an EXE uninstall
            if ($UninstallString -notmatch 'msiexec') {

                ## Use quiet uninstall string if available
                [string]$EffectiveUninstallString = if ($hasRegistrySilentArgs) {
                    Write-Log -Message 'Detected silent uninstall string (Registry)'
                    $QuietUninstallString
                }
                else {
                    Write-Log -Message 'Missing silent uninstall string (Registry)'
                    $UninstallString
                }

                ## Always disassemble the uninstall string to get the executable and arguments, will return 'hasSilentArgs = $false' if only '/SILENT' is present
                $UninstallParameters = Get-InstallerCommand -CommandString $EffectiveUninstallString

                ## If it lacks silent args, try to get a silent command
                if (-not $UninstallParameters.hasSilentArgs) {

                    ## If the uninstall string is not fully silent log a warning
                    If ($UninstallParameters.SilentArgs.Count -gt 0) {
                        Write-Log -Severity Warning -Message "Uninstall string is not fully silent: [$($UninstallParameters.SilentArgs)]"
                    }

                    ## Get the silent uninstall command
                    $SilentParams = Get-SilentUninstallCommand -UninstallString $EffectiveUninstallString
                    $UninstallParameters.Arguments = $SilentParams
                }

                ## Start the uninstall process
                Write-Log -Message 'Starting EXE uninstall...'

                #  Set up the executable and arguments
                [string]$FilePath = $UninstallParameters.FullName
                [string]$Arguments = $UninstallParameters.Arguments

                #  Execute the uninstall command
                [int]$ExitCode = Start-ProcessWithTimeout -FilePath $FilePath -Arguments $Arguments -TimeoutSeconds $TimeoutSeconds
                $Result.ExitCode = $ExitCode

                ## Check the exit code and handle accordingly
                switch ($ExitCode) {
                    { $PSItem -in 0, 3010, 19 } {

                        #  Exit code 19: Possibly non-fatal condition (e.g., partial uninstall or app still running)
                        Write-Log -Message "SUCCESSFUL (Exit Code: $ExitCode)"
                        $Result.Success = $true
                        break
                    }

                    -1 {
                        $Result.ErrorMessage = "FAILED - Uninstall timed out (Exit Code: $ExitCode)"
                        Write-Log -Severity Warning -Message $Result.ErrorMessage
                        break
                    }

                    default {
                        $Result.ErrorMessage = "FAILED - Failed to uninstall EXE application (Exit Code: $ExitCode))"
                        Write-Log -Severity Warning -Message $Result.ErrorMessage
                    }
                }
            }
        }
        catch {
            $Result.ErrorMessage = "FAILED - Failed to uninstall EXE application: $($PSItem.Exception.Message)"
            Write-Log -Severity Warning -Message $Result.ErrorMessage
        }
        finally {

            ## Release the mutex if we acquired it and the uninstallation was successful
            Unlock-Mutex -Mutex $UninstallMutex.Mutex -Name $UninstallMutex.Name

            ## Return result
            Write-Output -InputObject $Result
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

## Check if log file exceeds size limit and clear it if needed
Test-LogFileSize -LogFile $LogFile -MaxSizeMB $Script.MaxLogSizeMB

## Check if another instance of the script is already running and exit gracefully if so
[string]$MutexName = $Script.Name + '_Script'
$ScriptMutex = Lock-Mutex -Name $MutexName -TimeoutSeconds 0 -Global
if (-not $ScriptMutex.Success) {
    Write-Log -Severity Debug -Message 'Another instance of the script is already running. Exiting...' -FormatOptions { Mode = 'Default' }
    exit 0
}

## Write initial log entries
Write-Log -Message "$ScriptNameAndVersion Started" -FormatOptions @{ Mode = 'CenteredBlock'; AddEmptyRow = 'After' }
Write-Log -Message 'ENVIRONMENT' -FormatOptions @{ Mode = 'InlineHeader'; AddEmptyRow = 'After' }
Write-Log -Message "Running as:  [$ScriptRunningAs]" -FormatOptions @{ Mode = 'Default' }
Write-Log -Message "Script path: [$($Script.Path)]" -FormatOptions @{ Mode = 'Default' }
Write-Log -Message "Log file:    [$LogFile]" -FormatOptions @{ Mode = 'Default' }
Write-Log -Message 'DISCOVERY' -FormatOptions @{ Mode = 'InlineHeader'; AddEmptyRow = 'BeforeAndAfter' }

## Check for administrative privileges
[bool]$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Log -Severity Warning-Message 'Script is not running with administrative privileges. Uninstallation may fail!' -FormatOptions @{ Mode = 'AddSpace'; AddEmptyRow = 'After' }
}

try {

    ## Initialize variables
    [int]$SuccessCount = 0
    [int]$FailureCount = 0
    $UninstallResults = [System.Collections.ArrayList]::new()

    ## Get matching applications
    $InstalledApplications = Get-Application -SearchPatterns $SearchPatterns

    ## Loop through each installed application and uninstall it
    Write-Log -Message 'UNINSTALL' -FormatOptions @{ Mode = 'InlineHeader'; AddEmptyRow = 'Before' }

    #  If no applications were found, log a message
    if ($InstalledApplications.Count -eq 0) {
        Write-Log -Message 'No applications to uninstall.' -FormatOptions @{ AddEmptyRow = 'Before' }
    }
    foreach ($Application in $InstalledApplications) {
        $UninstallResult = Remove-Application -Application $Application
        $null = $UninstallResults.Add($UninstallResult)

        #  Increment success or failure count based on the result
        if ($UninstallResult.Success) { $SuccessCount++ } else { $FailureCount++ }

        ## Add a small delay between uninstalls to prevent resource contention
        Start-Sleep -Seconds 2
    }

    ## Detailed results
    Write-Log -Message 'RESULTS' -FormatOptions @{ Mode = 'InlineHeader'; AddEmptyRow = 'BeforeAndAfter' }

    #  If no applications were uninstalled, log a message
    if ($UninstallResults.ApplicationName.Count -eq 0) {
        Write-Log -Message 'No applications were uninstalled.'
    }

    #  Calculate maximum widths for padding
    [int]$MaxNameLength = ($UninstallResults | ForEach-Object { $PSItem.ApplicationName.Length } | Measure-Object -Maximum).Maximum
    [int]$MaxVersionLength = ($UninstallResults | ForEach-Object { $PSItem.ApplicationVersion.Length } | Measure-Object -Maximum).Maximum

    #  Pad the application names and versions for better readability
    foreach ($UninstallResult in $UninstallResults) {
        $AppName = [string]$UninstallResult.ApplicationName
        $AppVersion = [string]$UninstallResult.ApplicationVersion

        #  Set the status based on the success of the uninstallation
        $Status = if ($UninstallResult.Success) { '[SUCCESSFUL]' } else { '[FAILED]' }

        $PaddedAppName = $AppName.PadRight($MaxNameLength)
        $PaddedAppVersion = $AppVersion.PadRight($MaxVersionLength)
        #  Log the results
        Write-Log -Message "$PaddedAppName | Version: $PaddedAppVersion | Status: $Status"
    }

    ## Output summary
    Write-Log -Message 'SUMMARY' -FormatOptions @{ Mode = 'InlineHeader'; AddEmptyRow = 'BeforeAndAfter' }
    Write-Log -Message "Successfully uninstalled:     [$SuccessCount]" -FormatOptions @{ Mode = 'Default' }
    Write-Log -Message "Failed to uninstall:          [$FailureCount]" -FormatOptions @{ Mode = 'Default' }
    Write-Log -Message "Total applications processed: [$($InstalledApplications.DisplayName.Count)]" -FormatOptions @{ Mode = 'Default'; AddEmptyRow = 'After' }
}
catch {

    ## If the script fails for any reason, return a clear failure message and assume non-compliance
    [string]$ComplianceState = "Compliance state: [NonCompliant] - Script Failed: [$($PSItem.Exception.Message)]"
    Write-Log -Severity Error -Message $ComplianceState -FormatOptions @{ AddEmptyRow = 'BeforeAndAfter' }

    ## Exit with non-zero code to indicate failure
    exit 1
}
finally {

    ## Release the mutex if it was created
    Unlock-Mutex -Mutex $ScriptMutex.Mutex -Name $ScriptMutex.Name

    ## Make sure to flush any buffered log entries
    Write-LogBuffer

    ## End logging
    Write-Log -Message "$($Script.Name) v$($Script.Version) Completed" -FormatOptions @{ Mode = 'CenteredBlock'; AddEmptyRow = 'Before' }

    ## Ensure final flush of log buffer
    Write-LogBuffer

    ## Exit with appropriate code based on uninstallation results
    if ($FailureCount -gt 0) {

        #  Some uninstallation tasks failed
        exit 2
    }
    else {

        #  All uninstallation tasks succeeded, or no applications to uninstall
        exit 0
    }
}

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================
