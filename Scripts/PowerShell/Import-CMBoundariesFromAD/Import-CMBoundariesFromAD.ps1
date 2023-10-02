<#
.SYNOPSIS
    Imports AD Sites subnets into MEMCM.
.DESCRIPTION
    Imports AD Sites subnets into MEMCM as IP Ranges.
.PARAMETER SiteFQDN
    Specifies the SMS provider fully qualified domain name.
    Default is: '$env:COMPUTERNAME'
.PARAMETER DomainName
    Specifies the Domain name to query.
    Default is: '*'.
.EXAMPLE
    Import-CMBoundariesFromAD.ps1 -SiteFQDNFQDN 'sms.contoso.com' -DomainName 'contoso.com'
.INPUTS
    None.
.OUTPUTS
    None.
.NOTES
    Created by Ioan Popovici
.LINK
    https://MEMZ.one/Import-CMBoundariesFromAD
.LINK
    https://MEMZ.one/Import-CMBoundariesFromAD-CHANGELOG
.LINK
    https://MEMZ.one/Import-CMBoundariesFromAD-GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    Mirosoft Configuration Manager
.FUNCTIONALITY
    Imports AD Sites subnets into MEMCM.
#>

## Set script requirements
#Requires -Version 5.0

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

## Get script parameters
Param (
    [Parameter(Mandatory=$false,HelpMessage="SMS Provider FQDN:",Position=0)]
    [ValidateNotNullorEmpty()]
    [Alias('CMSite')]
    [string]$SiteFQDN = $env:COMPUTERNAME,
    [Parameter(Mandatory=$false,HelpMessage="Domain Name:",Position=1)]
    [ValidateNotNullorEmpty()]
    [Alias('Domain')]
    [string]$DomainName = '*'
)

## Get script path and name
[string]$ScriptPath = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Definition)
[string]$ScriptName = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Definition)

#endregion
##*=============================================
##* END VARIABLE DECLARATION
##*=============================================

##*=============================================
##* FUNCTION LISTINGS
##*=============================================
#region FunctionListings

#region Function Get-ADSiteSubnet
Function Get-ADSiteSubnet {
<#
.SYNOPSIS
    Gets the AD site subnets.
.DESCRIPTION
    Gets the AD site subnets for all forrests domains.
.PARAMETER DomainName
    Specifies the Domain name to query.
    Default is: '*'.
.PARAMETER ExportFile
    Specifies the path to export the results to.
.EXAMPLE
    Get-ADSiteSubnet -DomainName 'contoso.com' -ExportPath 'c:\temp\sites.csv'
.INPUTS
    None.
.OUTPUTS
    System.IO
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.COMPONENT
    AD
.FUNCTIONALITY
    Gets the AD site subnets.
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$false,Position=0)]
        [ValidateNotNullorEmpty()]
        [Alias('Domain')]
        [string]$DomainName = '*',
        [Parameter(Mandatory=$false,Position=1)]
        [ValidateNotNullorEmpty()]
        [Alias('Path')]
        [string]$ExportPath
    )

    Begin {
        Write-Verbose -Message "Starting [$($MyInvocation.Mycommand)]"
    }
    Process {
        Try {
            ## Get a list of all domains in all forests
            $Domains = (Get-ADForest).Domains | Where-Object { $PSItem -like $DomainName }

            ## Get a list of all domains controllers per forest
            $DomainControllers = ForEach ($Domain in $Domains) {
                [string]$Server = (Get-ADDomainController -Discover -DomainName $Domain).Name
                Get-ADDomainController -Server $Server -Filter * | Select-Object -Property 'Site', 'Name', 'Domain'
            }

            ## Get all replication subnets from Sites and Services
            $Subnets =  ForEach ($Domain in $Domains) {
                [string]$Server = (Get-ADDomainController -Discover -DomainName $Domain).Name
                Get-ADReplicationSubnet -Server $Server -Filter * -Properties * | Select-Object 'Name', 'Site', 'Location', 'Description'
            }

            ## Loop through all subnets and build the subnet list
            $Output = ForEach ($Subnet in $Subnets) {
                [string]$SiteName = ($Subnet.Site | Select-String -Pattern '(?<=^CN=)[^,]*').Matches.Value
                $IsDCInSite = [boolean]($DomainControllers.Site -Contains $SiteName)
                #  Create output properties
                [pscustomobject]@{
                    SiteName    = $SiteName
                    IsDcInSite  = $IsDCInSite
                    Subnet      = $Subnet.Name
                    Location    = $Subnet.Location
                    Description = $Subnet.Description
                }
            }
        }
        Catch {
            $PSCmdlet.WriteError($PSItem)
        }
        Finally {
            If ($PSBoundParameters.ContainsKey('ExportPath')) { $Output | Export-Csv -Path $ExportPath -NoTypeInformation }
            Write-Output -InputObject $Output
        }
    }
    End {
        Write-Verbose -Message "Ending [$($MyInvocation.Mycommand)]"
    }
}
#endregion

#region Function Invoke-CMSiteCommand
Function Invoke-CMSiteCommand {
<#
.SYNOPSIS
    Runs a command on a remote CMSite.
.DESCRIPTION
    Runs a command on a remote site and retunrs the resuly to the pipeline.
.PARAMETER SiteFQDN
    Specifies SMS provider FQDN.
.Parameter Command
    Specifies the command to run.
.EXAMPLE
    Invoke-CMSiteCommand -SiteFQDN 'site.sms.com' -Command 'Get-CMSite'
.INPUTS
    None.
.OUTPUTS
    System.Object
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.COMPONENT
    Configuration Manager
.FUNCTIONALITY
    Run a remote command on a CMSite.
#>
[CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true,HelpMessage='Site FQDN:',Position=0)]
        [ValidateNotNullorEmpty()]
        [Alias('Name')]
        [string]$SiteFQDN,
        [Parameter(Mandatory=$true,HelpMessage='Command to run:',Position=1)]
        [ValidateNotNullorEmpty()]
        [Alias('cmd')]
        [string]$Command
    )

    Begin {

        ## Set command scriptblock
        [string]$CMSiteCommand =
@"
            ## Import the configuration manager module
            Import-Module `$env:SMS_ADMIN_UI_PATH.Replace('\bin\i386','\bin\configurationmanager.psd1') -ErrorAction 'Stop'

            ## Get the site code
            `$SiteLocation = (Get-PSDrive -PSProvider 'CMSITE').Name + ':\'

            ## Change context to the site
            Push-Location `$SiteLocation

            ## Get the site collections
            $Command

            ## Change context back
            Pop-Location

            ## Remove SCCM PSH Module
            Remove-Module 'ConfigurationManager' -ErrorAction 'SilentlyContinue'
"@
        $ScriptBlock = [ScriptBlock]::Create($CMSiteCommand)
    }
    Process {
        Try {
            $Output = Invoke-Command -ComputerName $SiteFQDN -ScriptBlock $ScriptBlock -ErrorAction 'Stop'
        }
        Catch {
            $PSCmdlet.WriteError($PsItem)
        }
        Finally {
            Write-Output -InputObject $Output
        }
    }
    End {
    }
}
#endregion

#region Function Get-CMBoundaryMembership
Function Get-CMBoundaryMembership {
<#
.SYNOPSIS
    Gets the MEMCM boundary groups for a specified boundary.
.DESCRIPTION
    Gets the MEMCM boundary groups for a specified boundary, using WMI.
.PARAMETER SiteFQDN
    Specifies the SMS provider fully qualified domain name.
    Default is: '$env:COMPUTERNAME'
.PARAMETER BoundaryList
    Specifies the boundary name to query.
    Default is: '*'.
.EXAMPLE
    Get-CMBoundaryMembership -BoundaryList '10.55.55.0-10.55.55.254'
.INPUTS
    None.
.OUTPUTS
    None.
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.COMPONENT
    MEMCM
.FUNCTIONALITY
    Gets CM boundary groups for a specified boundary.
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$false,HelpMessage="SMS Provider FQDN:",Position=0)]
        [ValidateNotNullorEmpty()]
        [Alias('CMSite')]
        [string]$SiteFQDN = $env:COMPUTERNAME,
        [Parameter(Mandatory=$true,HelpMessage="Boundary Name:",Position=1)]
        [ValidateNotNullorEmpty()]
        [Alias('Boundary')]
        [string[]]$BoundaryList
    )

    Begin {
        Write-Verbose -Message "Starting [$($MyInvocation.Mycommand)]"

    }
    Process {
        Try {

            ## Get the site code
            [string]$SiteCode = (Invoke-CMSiteCommand -Command 'Get-CMSite' -SiteFQDN $SiteFQDN).SiteCode
            [string]$NameSpace = -join ('Root\SMS\site_', $SiteCode)

            $BoundaryRanges = Get-CimInstance -Namespace $NameSpace -ClassName 'SMS_Boundary' #-Filter "BoundaryType = 3"
            $BoundaryGroupMembers = Get-CimInstance -Namespace $NameSpace -ClassName 'SMS_BoundaryGroupMembers'
            $BoundaryGroups = Get-CimInstance -Namespace $NameSpace -ClassName 'SMS_BoundaryGroup'

            $Output = ForEach ($Boundary in $BoundaryList) {
                ForEach ($BoundaryRange in $BoundaryRanges) {
                    $IsPresent = [boolean]($Boundary -eq $BoundaryRange.Value)
                    Write-Warning "Boundary '$($Boundary)' already added '$($BoundaryRange.BoundaryID)'!"
                    ForEach ($BoundaryGroupMember in $BoundaryGroupMembers) {
                        If ($BoundaryGroupMember.BoundaryID -eq $BoundaryRange.BoundaryID) {
                            [pscustomObject]@{
                                BoundaryName = $BoundaryRange.DisplayName
                                IsPresent    = $IsPresent
                                BoundaryId   = $BoundaryGroupMember.BoundaryID
                                GroupName    = ($BoundaryGroups.Where({ $PsItem.GroupID -eq $BoundaryGroupMember.GroupID})).Name
                                GroupID      = $BoundaryGroupMember.GroupID
                            }
                        }
                    }

                }
            }
        }
        Catch {
            $PSCmdlet.WriteError($PSItem)
        }
        Finally {
            Write-Output -InputObject $Output
        }
    }
    End {
        Write-Verbose -Message "Ending [$($MyInvocation.Mycommand)]"
    }
}
#endregion

#region Function Get-IpRangeFromSubnet
Function Get-IPRangeFromSubnet {
<#
.SYNOPSIS
    Gets all valid IP addresses from a specified subnet.
.DESCRIPTION
    Gets all valid IP addresses from a specified subnet in a CIDR format.
.PARAMETER Subnets
    The subnet written in CIDR format 'a.b.c.d/#' and an example would be '192.168.1.24/27'. Can be a single value, an
    array of values, or values can be taken from the pipeline.
.EXAMPLE
    Get-IPRangeFromSubnet -Subnet '192.168.1.24/30'
.EXAMPLE
    '192.168.1.128/30' | Get-IPRangeFromSubnet
.NOTES
    Credit to John Dougherty for the original script.
.LINK
    https://itpro.outsidesys.com/2018/01/16/powershell-list-all-subnets-in-sites-services/
#>

    [CmdletBinding(ConfirmImpact = 'None')]
    Param(
        [Parameter(Mandatory,HelpMessage="Please enter a subnet in the form a.b.c.d/#", ValueFromPipeline, Position = 0)]
        [string[]]$Subnets
    )

    Begin {
        Write-Verbose -Message "Starting [$($MyInvocation.Mycommand)]"
    }
    Process {
        Foreach ($Subnet in $subnets) {
            If ($Subnet -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/\d{1,2}$') {

                ## Split IP and subnet
                $IP = ($Subnet -split '\/')[0]
                [int] $SubnetBits = ($Subnet -split '\/')[1]
                If ($SubnetBits -lt 7 -or $SubnetBits -gt 30) {
                    Write-Error -Message 'The number following the / must be between 7 and 30'
                    break
                }

                ## Convert IP into binary
                #  Split IP into different octects and for each one, figure out the binary with leading zeros and add to the total
                $Octets = $IP -split '\.'
                $IPInBinary = @()
                Foreach ($Octet in $Octets) {
                    #  Convert to binary
                    $OctetInBinary = [convert]::ToString($Octet, 2)
                    #  Get length of binary string add leading zeros to make octet
                    $OctetInBinary = ('0' * (8 - ($OctetInBinary).Length) + $OctetInBinary)
                    $IPInBinary = $IPInBinary + $OctetInBinary
                }
                $IPInBinary = $IPInBinary -join ''
                #  Get network ID by subtracting subnet mask
                $HostBits = 32 - $SubnetBits
                $NetworkIDInBinary = $IPInBinary.Substring(0, $SubnetBits)
                #  Get host ID and get the first host ID by converting all 1s into 0s
                $HostIDInBinary = $IPInBinary.Substring($SubnetBits, $HostBits)
                $HostIDInBinary = $HostIDInBinary -replace '1', '0'
                #  Work out all the host IDs in that subnet by cycling through $i from 1 up to max $HostIDInBinary (i.e. 1s stringed up to $HostBits)
                #  Work out max $HostIDInBinary
                $imax = [convert]::ToInt32(('1' * $HostBits), 2) - 1
                $IPs = @()
                #  Next ID is first network ID converted to decimal plus $i then converted to binary
                For ($i = 1 ; $i -le $imax ; $i++) {
                    #  Convert to decimal and add $i
                    $NextHostIDInDecimal = ([convert]::ToInt32($HostIDInBinary, 2) + $i)
                    #  Convert back to binary
                    $NextHostIDInBinary = [convert]::ToString($NextHostIDInDecimal, 2)
                    #  Add leading zeros
                    #  Number of zeros to add
                    $NoOfZerosToAdd = $HostIDInBinary.Length - $NextHostIDInBinary.Length
                    $NextHostIDInBinary = ('0' * $NoOfZerosToAdd) + $NextHostIDInBinary
                    #  Work out next IP
                    #  Add networkID to hostID
                    $NextIPInBinary = $NetworkIDInBinary + $NextHostIDInBinary
                    #  Split into octets and separate by . then join
                    $IP = @()
                    For ($x = 1 ; $x -le 4 ; $x++) {
                        #  Work out start character position
                        $StartCharNumber = ($x - 1) * 8
                        #  Get octet in binary
                        $IPOctetInBinary = $NextIPInBinary.Substring($StartCharNumber, 8)
                        #  Convert octet into decimal
                        $IPOctetInDecimal = [convert]::ToInt32($IPOctetInBinary, 2)
                        #  Add octet to IP
                        $IP += $IPOctetInDecimal
                    }
                    #  Separate by .
                    $IP = $IP -join '.'
                    $IPs += $IP
                }
                Write-Output -InputObject $IPs
            }
            Else { Write-Error -Message "Subnet [$subnet] is not in a valid format" }
        }
    }
    End {
        Write-Verbose -Message "Ending [$($MyInvocation.Mycommand)]"
    }
}
#endregion

##*=============================================
##* END FUNCTION LISTINGS
##*=============================================

##*=============================================
##* SCRIPT BODY
##*=============================================
#region ScriptBody

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================



    $Subnets = Import-Csv -Path E:\Temp\AD-Subnets.csv

    $Subnets | Add-Member -MemberType 'NoteProperty' -Name 'IPRange' -Value 'N/A' -Force

    ForEach ($Subnet in $Subnets) {
        $IPAddresses = Get-IpRange -Subnets $Subnet.Subnet
        $FirstAddress = $IPAddresses[$IPAddresses.GetLowerBound(0)]
        $LastAddress = $IPAddresses[$IPAddresses.GetUpperBound(0)]
        $Subnet.IPRange = "{0}-{1}" -f ($FirstAddress, $LastAddress)
    }


    $subnets | Out-GridView

    $Subnets | ForEach-Object { New-CMBoundary -Name $PSitem.SiteName -Value $PSitem.IPRange -Type IPRange }