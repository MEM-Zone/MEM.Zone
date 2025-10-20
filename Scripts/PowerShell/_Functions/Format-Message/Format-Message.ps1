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

        #  Extract format options from FormatData
        $Mode            = if ($FormatData.Keys -contains 'Mode')            { $FormatData['Mode']            } else { 'Default' }
        $AddEmptyRow     = if ($FormatData.Keys -contains 'AddEmptyRow')     { $FormatData['AddEmptyRow']     } else { 'No' }
        $Title           = if ($FormatData.Keys -contains 'Title')           { $FormatData['Title']           } else { 'Data Table' }
        $NewHeaders      = if ($FormatData.Keys -contains 'NewHeaders')      { $FormatData['NewHeaders']      } else { $null }
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

                    #  Add prefix and format adn trim the message
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

                            #  Set header width to the length of the header
                            $MaxWidth = $Headers[$Counter].Length

                            #  Check data widths
                            foreach ($Row in $Message) {
                                $Header = $Headers[$Counter]

                                #  Get property name based on whether we're using NewHeaders
                                $PropName = if ($UseNewHeaders -and $Header -in $NewHeaders.Keys) { $NewHeaders[$Header] } else { $Header }

                                #  Get property value
                                $PropValue = if ($Row.PSObject.Properties[$PropName]) {
                                    $Row.$PropName
                                }
                                else {

                                    #  Try case-insensitive match if exact property not found
                                    $FoundProp = $Row.PSObject.Properties | Where-Object -Property Name -eq $PropName
                                    if ($FoundProp) { $FoundProp.Value } else { $null }
                                }

                                #  Set default values
                                if ($null -ne $PropValue) { $ValueLength =
                                    $PropValue.ToString().Length
                                    $MaxWidth = [Math]::Max($MaxWidth, $ValueLength)
                                }
                            }

                            #  Limit column width to prevent excessive wrapping
                            $MaxAllowedWidth = 50
                            $MaxWidth = [Math]::Min($MaxWidth, $MaxAllowedWidth)

                            #  Add the column width
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
                        if ($CellPadding -gt 0) { $SeparatorParts += (' ' * $CellPadding) + $SepText + (' ' * $CellPadding) } else { $SeparatorParts += $SepText }
                    }
                    $SeparatorLine = $FormatString -f $SeparatorParts
                    $OutputLines += $SeparatorLine

                    #  Add data rows
                    foreach ($Row in $Message) {
                        $RowData = @()
                        for ($Counter = 0; $Counter -lt $Headers.Count; $Counter++) {
                            $Header = $Headers[$Counter]

                            #  Get property name based on whether we're using NewHeaders
                            $PropName = if ($UseNewHeaders -and $Header -in $NewHeaders.Keys) { $NewHeaders[$Header] } else { $Header }

                            #  Get property value
                            $PropValue = if ($Row.PSObject.Properties[$PropName]) {
                                $Row.$PropName
                            }
                            else {

                                #  Try case-insensitive match if exact property not found
                                $FoundProp = $Row.PSObject.Properties | Where-Object -Property Name -eq $PropName
                                if ($FoundProp) { $PropValue = $FoundProp.Value } else { $PropValue = '' }
                            }

                            #  Add the property value to the row data
                            $StringValue = if ($null -ne $PropValue) {
                                $Value = $PropValue.ToString()

                                #  Add padding to cell content
                                if ($CellPadding -gt 0) { (' ' * $CellPadding) + $Value + (' ' * $CellPadding) } else { $Value }
                            }
                            else {

                                #  Empty value with padding
                                if ($CellPadding -gt 0) { ' ' * ($CellPadding * 2) } else { '' }
                            }

                            #  Truncate value if it's longer than the column width
                            $MaxDisplayWidth = $ColumnWidths[$Counter] + ($CellPadding * 2)
                            if ($StringValue.Length -gt $MaxDisplayWidth) {

                                #  Ensure at least 3 characters are displayed
                                $TruncateLength = [Math]::Max($MaxDisplayWidth - 3, 3)
                                $StringValue = $StringValue.Substring(0, $TruncateLength) + '...'
                            }

                            #  Add the string value to the row data
                            $RowData += $StringValue
                        }

                        #  Format and add the data line
                        $DataLine = $FormatString -f $RowData
                        $OutputLines += $DataLine
                    }

                    #  Add vertical padding below the table
                    if ($VerticalPadding -gt 0) { for ($i = 0; $i -lt $VerticalPadding; $i++) { $OutputLines += '' } }
                }

                ## TIMELINE MODE
                'Timeline' {

                    #  Add prefix to the message
                    $OutputLines = @("    - $($Message.ToString())")
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
            Write-Warning "Error in Format-Message: [$($PSItem.Exception.Message)]"
            return @($Message.ToString().Trim())
        }
    }
}
#endregion