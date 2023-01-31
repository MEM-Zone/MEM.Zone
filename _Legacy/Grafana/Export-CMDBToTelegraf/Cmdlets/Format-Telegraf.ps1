
#region Function Format-Telegraf
Function Format-Telegraf {
<#
.SYNOPSIS
    Formats input object for telegraf.
.DESCRIPTION
    Formats input object for telegraf format.
.PARAMETER InputObject
    Specifies the InputObject.
.PARAMETER Tags
    Specifies the tags to attach.
.PARAMETER AddTimeStamp
    Specifies if a unix time stamp will be added to each row. Defaut is: $false.
.EXAMPLE
    Format-Telegraf -InputObject 'SomeInputObject'
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://SCCM.Zone
.LINK
    https://SCCM.Zone/Git
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $false, ValueFromPipeline = $true, Position = 0)]
        [ValidateNotNullorEmpty()]
        [Alias('Obj')]
        [psobject]$InputObject,
        [Parameter(Mandatory = $false, Position = 1)]
        [Alias('Tags')]
        [string]$TelegrafTags,
        [Parameter(Mandatory = $false, Position = 2)]
        [Alias('TStamp')]
        [switch]$AddTimeStamp
    )
    Begin {

        ## Initialize result variable
        [psobject]$Result = @()
    }
    Process {
        Try {

            ## Get input members
            If ($InputObject) {
                [string[]]$Headers = ($InputObject | Get-Member | Where-Object -Property 'MemberType' -eq 'Property').Name
            }
            Else { $Headers = $null }

            ## Format object
            ForEach ($Row in $InputObject) {
                #  Initialize format variables for every new iteration
                [string]$FormatRowProps = $null
                [string]$FormatRow = $null
                #  Get row data using object headers and format for telegraf
                ForEach ($Header in $Headers) {
                    $FormatRowProps = -join ($Header, '=', $($Row.$Header), ',')
                    $FormatRow = -join ($FormatRow, $FormatRowProps)
                }
                #  Add telegraf tags and remove last ',' from the string
                If ($FormatRow) {
                    #  Add tags if needed
                    If ($TelegrafTags) { $FormatRow = -join ($TelegrafTags, ' ', $FormatRow) }
                    #  Remove last ',' from the string
                    $FormatRow = $FormatRow -replace (".$")
                    #  Add Unix time stamp (UTC)
                    If ($AddTimeStamp) {
                        [string]$UnixTimeStamp = $(([DateTimeOffset](Get-Date)).ToUnixTimeSeconds())
                        $FormatRow = -join ($FormatRow, ' ', $UnixTimeStamp)
                    }
                }
                # Add row to result object
                $Result += $FormatRow
            }
        }
        Catch {
            Write-Error -Message "Formating Error: `n $_.ErrorMessage"
        }
        Finally {

            ## Output result
            Write-Output -InputObject $($Result | Format-Table -HideTableHeaders)
        }
    }
    End {
    }
}
#endregion