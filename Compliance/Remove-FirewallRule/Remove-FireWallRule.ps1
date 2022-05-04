<#
.SYNOPSIS
    Removes a firewall rule.
.DESCRIPTION
    Removes a firewall rule if its detected.
.PARAMETER DisplayName
    Specifies the firewall rule displayname.
.PARAMETER Remediate
    Specifies if the remediation should be executed.
.EXAMPLE
    Remove-FireWallRule.ps1 -DisplayName '*Java*' -Remediate
.INPUTS
    System.String.
.OUTPUTS
    System.String. Returns 'Compliant' or 'NonCompliant'
.NOTES
    Created by Ioan Popovici
.LINK
    https://MEM.Zone/
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    CM Compliance
.FUNCTIONALITY
    Removes Firewall Rule.
#>

## Set script requirements
#Requires -Version 3.0

#*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

## Get script parameters
Param (
    [Parameter(Mandatory = $false, Position = 0)]
    [ValidateNotNullorEmpty()]
    [string]$DisplayName,
    [Parameter(Mandatory = $false, Position = 1)]
    [switch]$Remediate
)

## Set script variables.
[string]$DisplayName = 'Java(TM) Platform SE binary'

## Set remediation to $true if used in a remediation script
[bool]$Remediate = $true

#endregion
##*=============================================
##* END VARIABLE DECLARATION
##*=============================================

##*=============================================
##* FUNCTION LISTINGS
##*=============================================
#region FunctionListings

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
    https://MEM.Zone/
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

#endregion
##*=============================================
##* END FUNCTION LISTINGS
##*=============================================

##*=============================================
##* SCRIPT BODY
##*=============================================
#region ScriptBody

Try {
    [scriptblock]$GetFirewallRule = { Get-FirewallRule -DisplayName $DisplayName }
    If ((& $GetFirewallRule) -eq 'NonCompliant' -and $Remediate) {
        $null = Get-FirewallRule -DisplayName $DisplayName -PassThru | Remove-NetFirewallRule
    }
}
Catch {
    Throw "Remediation failed. `n$($_.Exception.Message)"
}
Finally {
    Write-Output -InputObject $(& $GetFirewallRule)
}

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================