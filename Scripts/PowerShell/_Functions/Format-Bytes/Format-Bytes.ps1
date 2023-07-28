#region Format-Bytes
Function Format-Bytes {
<#
.SYNOPSIS
    Formats a number of bytes in the coresponding sizes.
.DESCRIPTION
    Formats a number of bytes bytes in the coresponding sizes depending or the size ('KB','MB','GB','TB','PB').
.PARAMETER Bytes
    Specifies bytes to format.
.EXAMPLE
    Format-Bytes -Bytes 12344567890
.INPUTS
    None.
.OUTPUTS
    None.
.NOTES
    Created by Ioan Popovici.
    v1.0.0 - 2021-09-01

    This is an private function should tipically not be called directly.
    Credit to Anthony Howell.
.LINK
    https://theposhwolf.com/howtos/Format-Bytes/
.LINK
    https://MEM.Zone/
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    Powershell
.FUNCTIONALITY
    Format Bytes
#>
    Param (
        [Parameter(ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [float]$Bytes
    )
    Begin {
        [string]$Output = $null
        [boolean]$Negative = $false
        $Sizes = 'KB','MB','GB','TB','PB'
    }
    Process {
        Try {
            If ($Bytes -le 0) {
                $Bytes = -$Bytes
                [boolean]$Negative = $true
            }
            For ($Counter = 0; $Counter -lt $Sizes.Count; $Counter++) {
                If ($Bytes -lt "1$($Sizes[$Counter])") {
                    If ($Counter -eq 0) {
                    $Number = $Bytes
                    $Sizes = 'B'
                    }
                    Else {
                        $Number = $Bytes / "1$($Sizes[$Counter-1])"
                        $Number = '{0:N2}' -f $Number
                        $Sizes = $Sizes[$Counter-1]
                    }
                }
            }
        }
        Catch {
            $Output = "Format Failed for Bytes ($Bytes! Error: $($_.Exception.Message)"
            Write-Log -Message $Output -EventID 2 -Severity 3
        }
        Finally {
            If ($Negative) { $Number = -$Number }
            $Output = '{0} {1}' -f $Number, $Sizes
            Write-Output -InputObject $Output
        }
    }
    End{
    }
}
#endregion