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