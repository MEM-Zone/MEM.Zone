<#
.SYNOPSIS
    Gets matching installed applications on a system.
.DESCRIPTION
    Gets matching installed applications on a system using specified search patterns.
.PARAMETER SearchPatterns
    Specifies application name patterns to use (supports wildcards).
.EXAMPLE
    .\Get-Application.ps1
.EXAMPLE
    .\Get-Application.ps1 -SearchPatterns '7-Zip*', 'Adobe*'
.INPUTS
    None.
.OUTPUTS
    System.String
.NOTES
    Created by Ioan Popovici 2025-04-04
.LINK
    https://MEMZ.one/Get-Application
.LINK
    https://MEMZ.one/Get-Application-CHANGELOG
.LINK
    https://MEMZ.one/Get-Application-GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    Application Management
.FUNCTIONALITY
    Get Matching Installed Applications
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
    [Parameter(Mandatory = $false, Position = 0)]
    [string[]]$SearchPatterns
)

## Define default application search patterns
$Script:ApplicationDetectionRules = [string[]]@(
    'Dell SupportAssist*'
    '*minitool*'
    '*treesize*'
    '*krita*'
    '*ccleaner*'
    '*recuva*'
    '*download manager*' # '_iu14D2N.tmp'
    #'*adobe*'
    #'*Zip*'
    #'*vlc*'
    #'*firefox*'
    #'*chrome*'
    #'*ccleaner*'
    #  Add more applications as needed
)

### Do not modify anything below this line unless you know what you're doing!
## --------------------------------------------------------------------------

## Set script variables
$Script:Version          = '3.0.1'
$Script:Name             = 'Discover-BlacklistedApplications'
$Script:NameAndVersion   = $Script:Name + ' v' + $Script:Version
$Script:Path             = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path)
$Script:FullName         = $MyInvocation.MyCommand.Path
$Script:LogName          = 'Uninstall-BlacklistedApplications'
$Script:LogPath          = [System.IO.Path]::Combine($Env:ProgramData, 'Logs', $Script:LogName)
$Script:LogFullName      = [System.IO.Path]::Combine($Script:LogPath, $Script:LogName + '.log')
$Script:LogDebugMessages = $false
$Script:LogMaxSizeMB     = 5
$Script:LogBuffer        = [System.Collections.ArrayList]::new()
$Script:RunningAs        = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$Script:RunningAsAdmin   = [bool]([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

## Set default matching applications if none provided, working around for the 'Compliant' state passed by the Discovery script
if (-not $PSBoundParameters['SearchPatterns'] -or $PSBoundParameters['SearchPatterns'] -eq 'Compliant') { $SearchPatterns = $Script:ApplicationDetectionRules }

## Set compliance state
[string]$ComplianceState = 'NonCompliant'
[string]$Severity        = 'Warning'

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
                    Write-Warning -Message "Failed to create log folder: $($PSItem.Exception.Message). Using script directory instead."
                }
            }

            ## Create log file if it doesn't exist
            [bool]$LogFileExists = Test-Path -Path $LogFile -PathType Leaf
            if (-not $LogFileExists) {
                try {
                    $null = New-Item -Path $LogFile -ItemType File -Force -ErrorAction Stop
                }
                catch {
                    Write-Warning -Message "Failed to create log file: $($PSItem.Exception.Message)"
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
    Specifies the severity level of the message. Available options: Information, Warning, Debug, Error.
.PARAMETER Message
    The log message to write.
.PARAMETER FormatOptions
    Optional hashtable of parameters to pass to Format-Header for formatting the console and/or log output.
.PARAMETER LogDebugMessages
    Whether to write debug messages to the log file (default: value of $Script:LogDebugMessages).
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
    Get-Application -SearchPatterns '*chrome*', '*vlc*'
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

        ## Log the start of the process
        Write-Log -Message 'Retrieving installed applications...' -FormatOptions @{ AddEmptyRow = 'After' }
    }
    process {
        try {

            ## Get registry application uninstall keys
            $UninstallKeys = Get-ItemProperty -Path $UninstallPaths -ErrorAction SilentlyContinue

            ## Process items registry uninstall keys
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
                #  Get longest display name length
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

#endregion
##*=============================================
##* END FUNCTION LISTINGS
##*=============================================

##*=============================================
##* SCRIPT BODY
##*=============================================
#region ScriptBody

## Check if log path exists or if the log file exceeds size limit
Test-LogFile -LogFile $Script:LogFullName -MaxSizeMB $Script:LogMaxSizeMB

## Write initial log entries
Write-Log -Message "$Script:NameAndVersion Started" -FormatOptions @{ Mode = 'CenteredBlock'; AddEmptyRow = 'After' }
Write-Log -Message 'ENVIRONMENT' -FormatOptions @{ Mode = 'InlineHeader'; AddEmptyRow = 'After' }
Write-Log -Message "Running elevated: [$Script:RunningAsAdmin]" -FormatOptions @{ Mode = 'Default' }
Write-Log -Message "Running as:       [$Script:RunningAs]" -FormatOptions @{ Mode = 'Default' }
Write-Log -Message "Script path:      [$Script:Path]" -FormatOptions @{ Mode = 'Default' }
Write-Log -Message "Log path:         [$Script:LogPath]" -FormatOptions @{ Mode = 'Default' }
Write-Log -Message 'DISCOVERY' -FormatOptions @{ Mode = 'InlineHeader'; AddEmptyRow = 'BeforeAndAfter' }

Try {

    ## Get matching applications
    $InstalledApplications = Get-Application -SearchPatterns $SearchPatterns

    ## Check if any applications were found
    [int]$MatchCount = $InstalledApplications.DisplayName.Count

    ## Set compliance state based on match count
    if ($MatchCount -eq 0) {
        $ComplianceState = 'Compliant'
        $Severity = 'Information'
    }

    ## Log the compliance
    Write-Log -Message 'SUMMARY' -FormatOptions @{ Mode = 'InlineHeader'; AddEmptyRow = 'BeforeAndAfter' }
    Write-Log -Message "Compliance state: [$ComplianceState] - [$MatchCount] matching application(s) found" -FormatOptions @{ AddEmptyRow = 'After' }
}
Catch {

    ## If discovery fails for any reason, return a clear failure message and assume non-compliant to be safe
    [string]$ComplianceState = "Compliance state: [NonCompliant] - Discovery Failed: [$($_.Exception.Message)]"
    Write-Log -Severity Error -Message $ComplianceState
}
Finally {

    ## Make sure to flush any buffered log entries
    Write-LogBuffer

    ## End logging
    Write-Log -Message "$Script:NameAndVersion Completed" -FormatOptions @{ Mode = 'CenteredBlock'; AddEmptyRow = 'Before' }

    ## Ensure final flush of log buffer
    Write-LogBuffer

    ## Output the result
    Write-Output -InputObject $ComplianceState
}

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================
