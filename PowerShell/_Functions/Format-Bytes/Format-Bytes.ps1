#region Format-Bytes
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
Function Format-Bytes {
    Param (
        [Parameter(ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [float]$Bytes
    )
    Begin{
        $Sizes = 'KB','MB','GB','TB','PB'
    }
    Process {
        # New for loop
        For($Counter = 0; $Counter -lt $Sizes.Count; $Counter++) {
            If ($Bytes -lt "1$($Sizes[$Counter])") {
                If ($Counter -eq 0) { Return "$Bytes B" }
                Else {
                    $Number = $Bytes / "1$($Sizes[$Counter-1])"
                    $Number = '{0:N2}' -f $Number
                    Return "$Number $($Sizes[$Counter-1])"
                }
            }
        }
    }
    End{
    }
}
#endregion