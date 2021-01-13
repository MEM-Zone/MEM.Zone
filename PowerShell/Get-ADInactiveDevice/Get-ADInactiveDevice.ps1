<#
.SYNOPSIS
    Gets Active Directory inactive devices.
.DESCRIPTION
    Gets Active Directory devices that have passed the specified inactive threshhold. Default is '365'.
.PARAMETER Server
    Specifies the domain or server to query.
.PARAMETER SearchBase
    Specifies the search start location. Default is '$null'.
.PARAMETER Filter
    Specifies the filtering options. Default is 'Enable -eq $true'.
.PARAMETER DaysInactive
    Specifies the inactivity threshold.
.EXAMPLE
    Get-ADInactiveDevice.ps1 -Server 'somedomain.com' -SearchBase 'CN=Computers,DC=somedomain,DC=com' -DaysInactive 365
.INPUTS
    None.
.OUTPUTS
    None.
.NOTES
    Created by Ioan Popovici
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/Issues
.COMPONENT
    AD
.FUNCTIONALITY
    Gets Inactive Devices
#>

## Set script requirements
#Requires -Version 3.0

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

## Get script parameters
Param (
    [Parameter(Mandatory=$true,HelpMessage="Enter a valid Domain or Domain Controller.",Position=0)]
    [ValidateNotNullorEmpty()]
    [Alias('ServerName')]
    [string]$Server,
    [Parameter(Mandatory=$false,HelpMessage="Specify a OU Common Name (CN).",Position=1)]
    [ValidateNotNullorEmpty()]
    [Alias('OU')]
    [string]$SearchBase = $null,
    [Parameter(Mandatory=$false,HelpMessage="Specify filtering options.",Position=2)]
    [ValidateNotNullorEmpty()]
    [Alias('FilterOption')]
    [string]$Filter = "Enabled -eq $true",
    [Parameter(Mandatory=$false,HelpMessage="Specify the inactivity threshold in days.",Position=3)]
    [ValidateNotNullorEmpty()]
    [Alias('InactiveThreshold')]
    [int16]$DaysInactive = 365
)

#endregion
##*=============================================
##* END VARIABLE DECLARATION
##*=============================================

##*=============================================
##* FUNCTION LISTINGS
##*=============================================
#region FunctionListings


#region Function Get-ADInactiveDevice
Function Get-ADInactiveDevice {
<#
.SYNOPSIS
    Gets Active Directory inactive devices.
.DESCRIPTION
    Gets Active Directory devices that have passed the specified inactive threshhold. Default is '365'.
.PARAMETER Server
    Specifies the domain or server to query.
.PARAMETER SearchBase
    Specifies the search start location. Default is '$null'.
.PARAMETER Filter
    Specifies the filtering options. Default is 'Enable -eq $true'.
.PARAMETER DaysInactive
    Specifies the inactivity threshold.
.EXAMPLE
    Get-ADInactiveDevice.ps1 -Server 'somedomain.com' -SearchBase 'CN=Computers,DC=somedomain,DC=com' -DaysInactive 365
.INPUTS
    None.
.OUTPUTS
    None.
.NOTES
    Created by Ioan Popovici
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/Issues
.COMPONENT
    AD
.FUNCTIONALITY
    Gets Inactive Devices
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true,HelpMessage="Enter a valid Domain or Domain Controller.",Position=0)]
        [ValidateNotNullorEmpty()]
        [Alias('ServerName')]
        [string]$Server,
        [Parameter(Mandatory=$false,HelpMessage="Specify a OU Common Name (CN).",Position=1)]
        [ValidateNotNullorEmpty()]
        [Alias('OU')]
        [string]$SearchBase = $null,
        [Parameter(Mandatory=$false,HelpMessage="Specify filtering options.",Position=2)]
        [ValidateNotNullorEmpty()]
        [Alias('FilterOption')]
        [string]$Filter = "Enabled eq 'true'",
        [Parameter(Mandatory=$false,HelpMessage="Specify the inactivity threshold in days.",Position=3)]
        [ValidateNotNullorEmpty()]
        [Alias('InactiveThreshold')]
        [int16]$DaysInactive = 365
    )

    Begin {
        [datetime]$CurrentDateTime = [System.DateTime]::Now
        [datetime]$InactiveThreshold = $CurrentDateTime.AddDays(- $DaysInactive)
        $Filter = -Join ('lastLogonDate -lt $InactiveThreshold -and ', $Filter)
    }
    Process {
        Try {

            $InactiveComputers = Get-ADComputer -Server $Server -Property 'Name', 'LastLogonDate' -Filter $Filter -SearchBase $SearchBase | Sort-Object -Property 'LastLogonDate' | Select-Object -Property 'Name', @{Name='DaysSinceLastLogon';Expression={ [int16](New-TimeSpan -Start $_.lastLogonDate -End $CurrentDateTime).Days}}, 'LastLogonDate', 'DistinguishedName'
        }
        Catch {
            Write-Error -Message $_.Exception
        }
        Finally {
            Write-Output -InputObject $InactiveComputers
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

#endregion
##*=============================================
##* END FUNCTION LISTINGS
##*=============================================

##*=============================================
##* SCRIPT BODY
##*=============================================
#region ScriptBody

#Get-ADInactiveDevice -Server $Server -SearchBase $SearchBase -Filter $Filter | ConvertTo-Csv | Out-File D:\Temp\InactiveComputers.csv

#Get-ADInactiveDevice -Server $Server -SearchBase $SearchBase -Filter $Filter | Select DistinguishedName  | Disable-ADAccount -Server $Server

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================
