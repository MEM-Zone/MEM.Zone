<#
.SYNOPSIS
    Sets Primary and Secondary DNS server.
.DESCRIPTION
    Sets Primary and Secondary DNS server, and optionally matches and replaces existing DNS server values.
.EXAMPLE
    Set-DnsClientServerAddress
.INPUTS
    None.
.OUTPUTS
    System.String
.NOTES
    Created by Ioan Popovici
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/Issues
.COMPONENT
    Network Interface
.FUNCTIONALITY
    Sets Primary and Secondary DNS server.
#>

## Set script requirements
#Requires -Version 5.0

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

## Detection  script: Set $Remediate to $false | Remediatin script: Set $Remediate to $true
[boolean]$Remediate = $true

## Get script path and name
[string]$ScriptName = 'Set-DnsClientServerAddress'
[string]$ScriptFullName = [System.IO.Path]::GetFileName($MyInvocation.MyCommand.Definition)

## Display script path and name
Write-Verbose -Message "Running script: $ScriptFullName" -Verbose

$PrimaryDNS = @{
    'OldDnsServer' = '10.188.209.31'
    'NewDnsServer' = '10.188.209.31'
}
$SecondaryDNS = @{
    'OldDnsServer' = '10.188.209.18'
    'NewDnsServer' = '10.174.18.21'
}

## Create DNS server addresses match list
[string[]]$DnsServerMatchList = @($PrimaryDNS.OldDnsServer, $SecondaryDNS.OldDnsServer)

## Set output to NonCompliant
[string]$Output = 'NonCompliant'

#endregion
##*=============================================
##* END VARIABLE DECLARATION
##*=============================================

##*=============================================
##* SCRIPT BODY
##*=============================================
#region ScriptBody

Try {

    ## Write verbose message
    Write-Verbose "Remediate: $Remediate" -Verbose

    ## Check for compliance
    $Interfaces = Get-DnsClientServerAddress | Where-Object { $PSItem.InterfaceAlias -match 'Ethernet' -and $PSItem.AddressFamily -eq 2 -and $PSItem.ServerAddresses -ne $null }

    ## Check for compliance
    $IsCompliant = -not [boolean](Compare-Object -ReferenceObject $Interfaces.ServerAddresses -DifferenceObject $DnsServerMatchList -IncludeEqual -ExcludeDifferent)

    ## Remediate if specified
    If ($IsCompliant) { $Output = 'Compliant' }
    ElseIf ($Remediate) {
        ForEach ($Interface in $Interfaces) {
            [string[]]$ServerAddresses = $Interface.ServerAddresses
            If ($ServerAddresses.Count -ge 1) {
                Write-Verbose -Message "DnsServers `n$ServerAddresses" -Verbose
                For ($Index = 0; $Index -le $ServerAddresses.Count; $Index++) {
                    Switch ($ServerAddresses[$Index]) {
                        $PrimaryDNS.OldDnsServer {
                            Write-Verbose -Message "Setting [($ServerAddresses[$Index]] --> $($PrimaryDNS.NewDnsServer)" -Verbose
                            $ServerAddresses[$Index] = $PrimaryDNS.NewDnsServer
                        }
                        $SecondaryDNS.OldDnsServer {
                            Write-Verbose -Message "Setting [$ServerAddresses[$Index]] --> $($SecondaryDNS.NewDnsServer)" -Verbose
                            $ServerAddresses[$Index] = $SecondaryDNS.NewDnsServer
                        }
                    }
                }
                Set-DnsClientServerAddress -InterfaceIndex $Interface.InterfaceIndex -ServerAddresses $ServerAddresses -ErrorAction 'Stop'
            }
        }
        $Output = 'Compliant'
    }

    ## Display success message
    Write-Verbose -Message "$ScriptName ran successfully!" -Verbose
}
Catch {
    $Output = $($PsItem.Exception.Message)
    Throw $Output
}
Finally {
    Write-Output -InputObject $Output
}

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================