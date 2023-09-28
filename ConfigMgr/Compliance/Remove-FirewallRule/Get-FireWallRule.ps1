#region Get-FirewallRule
Function Get-FirewallRule {
    <#
.SYNOPSIS
    Gets a firewall rule.
.DESCRIPTION
    Gets a firewall rule.
.PARAMETER DisplayName
    Specifies firewall rule displayname. Supports Wildcards.
.PARAMETER PassThru
    Specifies if the detected firewall rule should be passed to the pipeline.
.EXAMPLE
    Detect-FireWallRule -DisplayName 'Java(TM) Platform SE binary'
.INPUTS
    System.String.
.OUTPUTS
    System.String. Returns 'Compliant' or 'NonCompliant'
    System.Object. Returns the detected firewall rule.
.NOTES
    Created by Ioan Popovici
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    CM Compliance
.FUNCTIONALITY
    Firewall Rule detection
#>
    [cmdletbinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [string]$DisplayName,
        [Parameter(Mandatory = $false)]
        [switch]$PassThru
    )
    Begin {
        $Output = $null
    }
    Process {
        Try {
            $Rules = Get-NetFirewallRule -DisplayName $DisplayName -ErrorAction 'SilentlyContinue'
            $Output = If ($Rules.Count -eq 0) { 'Compliant' } Else { 'NonCompliant' }
            If ($PassThru) { $Output = $Rules }
        }
        Catch {
            $Output = 'You should not see this'
        }
        Finally {
            Write-Output $Output
        }
    }
    End {
    }
}
#endregion