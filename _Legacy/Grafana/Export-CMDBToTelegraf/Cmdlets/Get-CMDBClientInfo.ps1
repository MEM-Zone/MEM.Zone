#region Function Get-CMDBClientInfo
Function Get-CMDBClientInfo {
<#
.SYNOPSIS
    Gets client information.
.DESCRIPTION
    Gets client information from the SCCM database.
.PARAMETER Server
    Specifies the server name.
.PARAMETER Database
    Specifies the database name.
.PARAMETER LastnDays
    Specifies the how many days in the past to query. Default is: '12'.
.EXAMPLE
    Get-CMDBClientInfo -Server 'SomeServer' -Database 'CM_SomeSiteCode' -LastnDays '12'
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://SCCM.Zone
.LINK
    https://SCCM.Zone/Git
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullorEmpty()]
        [Alias('Srv')]
        [string]$Server,
        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateNotNullorEmpty()]
        [Alias('Dbs')]
        [string]$Database,
        [Parameter(Mandatory = $false, Position = 2)]
        [ValidateNotNullorEmpty()]
        [Alias('Days')]
        [string]$LastnDays = '12'
    )
    Begin {

        ## Add '-' to LastnDays
        [string]$LastnDays = -join ('-', $LastnDays)

        ## Query definition
        [string]$Query =
        "
            DECLARE @Date DATETIME = DATEADD(hh, $LastnDays, GETDATE());
            SELECT
                CMG_Update_Scan = (
                    SELECT COUNT(DISTINCT ResourceID)
                    FROM v_UpdateScanStatus
                    WHERE LastScanTime > @Date
                        AND LastScanPackageLocation LIKE '%cmg%'
                    GROUP BY LastScanPackageLocation
                )
                , CMG_Clients     = (
                    SELECT COUNT(DISTINCT Name)
                    FROM v_CombinedDeviceResources
                    WHERE CNIsOnInternet = 1
                        AND CNIsOnline = 1
                        AND CNAccessMP LIKE '%cmg%'
                )
                , MP_Clients      = (
                    SELECT COUNT(DISTINCT Name)
                    FROM v_CombinedDeviceResources
                    WHERE CNIsOnInternet = 0
                        AND CNIsOnline = 1
                );
        "
    }
    Process {
        Try {

            ## Run SQL query
            [psobject]$Result = Invoke-Sqlcmd -Query $Query -Server $Server -Database $Database -ErrorAction 'Stop'
        }
        Catch {
            Write-Error -Message "Query Error: `n $_.ErrorMessage"
        }
        Finally {

            ## Output result
            Write-Output -InputObject $Result
        }
    }
    End {
    }
}
#endregion