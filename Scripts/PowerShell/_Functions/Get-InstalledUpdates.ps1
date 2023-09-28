<#
.SYNOPSIS
    Gets the first matching installed update.
.DESCRIPTION
    Gets the first matching installed KB from a CSV list.
.PARAMETER KBs
    Specifies the KBs to query.
.EXAMPLE
    Get-InstalledUpdates -KB '4577069,4576946'
.INPUTS
    System.String.
.OUTPUTS
    System.String.
.NOTES
    Created by Ioan Popovici
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    CM
.FUNCTIONALITY
    Get Update Compliance
#>

## Set script requirements
#Requires -Version 3.0

##*=============================================
##* SCRIPT BODY
##*=============================================
#region ScriptBody

Param (
    [Parameter(Mandatory=$true,Position=0)]
    [ValidateNotNullorEmpty()]
    [Alias('KBlist')]
    [string]$KB
)
Begin {
    [string[]]$KBsToQuery = @($KB -split ',')
}

Process {
    Try {
        [psobject]$KBs = Get-HotFix | Where-Object { $_.HotFixID.Replace('KB', '') -in $KBsToQuery }
        If ($KBs) {
            [string]$FirstMatchingKB = $($KBs.HotFixID | Select-Object -First 1)
            $Result = "Compliant [$FirstMatchingKB]"
        }
        Else {  $Result = 'NonCompliant' }
    }
    Catch {
        $Result = "Error [$($_.Exception.Message)]"
    }
    Finally {
        If (-not $Result) { $Result = 'Unknown' }
        Write-Output -InputObject $Result
    }
}

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================