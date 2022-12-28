<#
.SYNOPSIS
    Sets Primary and Secondary DNS server.
.DESCRIPTION
    Sets Primary and Secondary DNS server by matching and replacing existing DNS address values.
.PARAMETER PrimaryDNS
    Specify Primary DNS server to match.
.PARAMETER SecondaryDNS
    Specify Secondary DNS server to match.
.PARAMETER NewPrimaryDNS
    Specify new Primary DNS server.
.PARAMETER NewSecondaryDNS
    Specify new Secondary DNS server.
.PARAMETER Remediate
    Set remediation to $true or $false. Default is $false.
.EXAMPLE
    Set-DnsClientServerAddress -PrimaryDNS '1.1.1.1' -SecondaryDNS '1.0.0.1' -NewPrimaryDNS '8.8.8.8' -NewSecondaryDNS '8.0.0.8' -Remediate $true
.INPUTS
    None.
.OUTPUTS
    System.String
.NOTES
    Created by Ioan Popovici
.LINK
    https://MEM.Zone/Set-DnsClientServerAddress
.LINK
    https://MEM.Zone/Set-DnsClientServerAddress-CHANGELOG
.LINK
    https://MEM.Zone/Set-DnsClientServerAddress-GIT
.LINK
    https://MEM.Zone/ISSUES
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

#region ScriptParameters (Comment this region with <# #> for hardcoded parameters)
Param (
    [Parameter(Mandatory = $true, HelpMessage = 'Specify primary DNS to match', Position = 0)]
    [ValidateNotNullorEmpty()]
    [Alias('Primary')]
    [string]$PrimaryDNS,
    [Parameter(Mandatory = $true, HelpMessage = 'Specify secondary DNS to match', Position = 1)]
    [ValidateNotNullorEmpty()]
    [Alias('Secondary')]
    [string]$SecondaryDNS,
    [Parameter(Mandatory = $true, HelpMessage = 'Specify new primary DNS', Position = 2)]
    [ValidateNotNullorEmpty()]
    [Alias('NewPrimary')]
    [string]$NewPrimaryDNS,
    [Parameter(Mandatory = $true, HelpMessage = 'Specify new secondary DNS', Position = 3)]
    [ValidateNotNullorEmpty()]
    [Alias('NewSecondary')]
    [string]$NewSecondaryDNS,
    [Parameter(Mandatory = $false, HelpMessage = 'Set remediation', Position = 4)]
    [boolean]$Remediate = $false
)
#endregion

#region HardcodedParameters (Uncomment this region by removing <# and #>, for hardcoded parameters)
<#
[hashtable]$PrimaryDNSConfig = @{
    'CurrentAddress' = '1.1.1.1'
    'NewAddress'     = '1.0.0.1'
}
[hashtable]$SecondaryDNSConfig = @{
    'CurrentAddress' = '1.1.1.1'
    'NewAddress'     = '8.8.8.8'
}
#endregion
#>

## !! Do not modify anything beyond this point !!

## Set script paramters
If ($PrimaryDNSConfig.count -eq 0) {
    $PrimaryDNSConfig = @{
        'CurrentAddress' = $PrimaryDNS
        'NewAddress'     = $NewPrimaryDNS
    }
    $SecondaryDNSConfig = @{
        'CurrentAddress' = $SecondaryDNS
        'NewAddress'     = $NewSecondaryDNS
    }
}

## Create DNS server addresses match list
[string[]]$DnsServerMatchList = @($PrimaryDNSConfig.CurrentAddress, $SecondaryDNSConfig.CurrentAddress)

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
            #  Create ServerAddresses writable variable
            [string[]]$ServerAddresses = $Interface.ServerAddresses
            If ($ServerAddresses.Count -ge 1) {
                Write-Verbose -Message "Current DnsServers: $ServerAddresses" -Verbose
                #  Loop through all DNS server addresses
                For ($Index = 0; $Index -le $ServerAddresses.Count; $Index++) {
                    Switch ($ServerAddresses[$Index]) {
                        $PrimaryDNSConfig.CurrentAddress {
                            Write-Verbose -Message "Setting [$($ServerAddresses[$Index])] --> $($PrimaryDNSConfig.NewAddress)" -Verbose
                            $ServerAddresses[$Index] = $PrimaryDNSConfig.NewAddress
                        }
                        $SecondaryDNSConfig.CurrentAddress {
                            #  Move to the next DNS address if the secondary DNS is the same as the primary DNS address
                            If ($SecondaryDNSConfig.CurrentAddress -eq $PrimaryDNSConfig.CurrentAddress) { $Index++ }
                            Write-Verbose -Message "Setting [$($ServerAddresses[$Index])] --> $($SecondaryDNSConfig.NewAddress)" -Verbose
                            $ServerAddresses[$Index] = $SecondaryDNSConfig.NewAddress
                        }
                    }
                }
                Set-DnsClientServerAddress -InterfaceIndex $Interface.InterfaceIndex -ServerAddresses $ServerAddresses -ErrorAction 'Stop'
            }
        }
        $Output = 'Compliant'
    }
}
Catch {
    $Output = $($PsItem.Exception.Message)
    Throw $Output
}
Finally {
    Write-Verbose -Message "Current DnsServers: $ServerAddresses" -Verbose
    Write-Output -InputObject $Output
}

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================