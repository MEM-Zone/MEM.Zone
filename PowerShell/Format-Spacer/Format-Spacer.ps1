#region Function Format-Spacer
Function Format-Spacer {
<#
.SYNOPSIS
    Adds padding before and after the specified variable.
.DESCRIPTION
    Adds padding before and after the specified variable in order to make it more visible.
.PARAMETER Message
    Specifies input message for this function.
.PARAMETER Type
    Specifies message output type.
.PARAMETER AddEmptyRow
    Specifies to add empty row before, after or both before and after the output.
.EXAMPLE
    Format-Spacer -Message $SomeVariable -AddEmptyRow 'Before'
.INPUTS
    System.String
.OUTPUTS
    System.String
.NOTES
    Created by Ioan Popovici
    2021-03-31 v1.0.0
    This is an internal script function and should typically not be called directly.
    Thanks @chrisdent from windadmins for fixing my regex :)
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
    Param (
        [Parameter(Mandatory=$true,ValueFromPipeline,HelpMessage='Specify input:',Position=0)]
        [ValidateNotNullorEmpty()]
        [Alias('Variable')]
        [string]$Message,
        [Parameter(Mandatory=$false,Position=1)]
        [ValidateSet('Console','Verbose')]
        [string]$Type = 'Console',
        [Parameter(Mandatory=$false,Position=2)]
        [ValidateSet('No','Before','After','BeforeAndAfter')]
        [string]$AddEmptyRow = 'No'
    )
    Begin {

        ## Set variables
        [string]$Padding = '#========================================#'
    }
    Process {
        Try {

            ## Trim start/end spaces
            [string]$MessageTrimmed = $Message.TrimStart().TrimEnd()

            ## Calculate the numbers of padding characters to remove
            [int]$RemoveRight = [math]::Floor($MessageTrimmed.Length / 2)
            [int]$RemoveLeft  = [math]::Ceiling($MessageTrimmed.Length / 2)

            ## Remove padding characters
            [string]$PaddingRight = $Padding -replace "(?<=#)={$RemoveRight}"
            [string]$PaddingLeft  = $Padding -replace "(?<=#)={$RemoveLeft}"

            ## Add empty rows to the output
            Switch ($AddEmptyRow) {
                'Before' { If ($Type -ne 'Verbose') { $PaddingRight = -join ("`n", $PaddingRight) } }
                'After'  { If ($Type -ne 'Verbose') { $PaddingLeft  = -join ($PaddingLeft, "`n" ) } }
                'After'  { If ($Type -ne 'Verbose') {
                    $PaddingRight = -join ("`n", $PaddingRight)
                    $PaddingLeft  = -join ($PaddingLeft, "`n" ) }
                }
                Default  {}
            }

            ## Assemble result
            [string]$Result = -join ($PaddingRight, ' ', $MessageTrimmed, ' ', $PaddingLeft)
        }
        Catch {
            $PSCmdlet.ThrowTerminatingError($PSItem)
        }
        Finally {

            ## Write to console
            If ($Type -eq 'Console') { Write-Output -InputObject $Result }

            ## Write verbose and add empty rows if specified
            Else {
                If ($AddEmptyRow -eq 'Before' -or $AddEmptyRow -eq 'BeforeAndAfter') { Write-Verbose -Message '' }
                Write-Verbose -Message $Result
                If ($AddEmptyRow -eq 'After' -or $AddEmptyRow -eq 'BeforeAndAfter') { Write-Verbose -Message '' }
            }
        }
    }
    End {
    }
}
#endregion