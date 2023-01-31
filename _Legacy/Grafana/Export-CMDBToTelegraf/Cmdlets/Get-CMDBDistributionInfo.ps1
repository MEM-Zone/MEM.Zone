#region Function Get-CMDBDistributionInfo
Function Get-CMDBDistributionInfo {
<#
.SYNOPSIS
    Gets package distribution information.
.DESCRIPTION
    Gets package distribution information from the SCCM database.
.PARAMETER Server
    Specifies the server name.
.PARAMETER Database
    Specifies the database name.
.EXAMPLE
    Get-CMDBDistributionInfo -Server 'SomeServer' -Database 'CM_SomeSiteCode'
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
        [string]$Database
    )
    Begin {

        ## Query definition
        [string]$Query =
        "
            USE $Database;
            WITH CTE AS (
                SELECT
                    DP_Name         = (
                        UPPER(SUBSTRING(PkgDistribution.ServerNALPath, 13, CHARINDEX('.', PkgDistribution.ServerNALPath) - 13))
                    )
                    , Not_Installed = (
                        COUNT(
                            CASE
                                WHEN PkgDistribution.State NOT IN ('0', '3', '6') THEN '*'
                                ELSE 'Unknown'
                            END
                        )
                    )
                    , Error         = (
                        COUNT(
                            CASE
                                WHEN PkgDistribution.State IN('3', '6') THEN '*'
                            END
                        )
                    )
                    , Status        = (
                        CASE
                            WHEN PkgDistribution.State = '0'                  THEN '1' --'OK'
                            WHEN PkgDistribution.State NOT IN ('0', '3', '6') THEN '2' --'In_Progress'
                            WHEN PkgDistribution.State IN ('3', '6')          THEN '3' --'Error'
                        END
                    )
                FROM dbo.v_PackageStatusDistPointsSumm AS PkgDistribution
                    , dbo.SMSPackages AS Packages
                WHERE Packages.PackageType != 4
                    AND (Packages.PkgID = PkgDistribution.PackageID)
                GROUP BY
                    PkgDistribution.ServerNALPath,
                    PkgDistribution.State
            )
            SELECT
                PKG_Not_Installed = SUM(Not_Installed)
                , PKG_Error       = SUM(Error)
                , DP_OK           = (
                    SELECT COUNT(DP_Name)
                    FROM CTE
                    WHERE Status  = '1'
                )
                , DP_In_Progress  = (
                    SELECT COUNT(DP_Name)
                    FROM CTE
                    WHERE Status  = '2'
                )
                , DP_Error        = (
                    SELECT COUNT(DP_Name)
                    FROM CTE
                    WHERE Status = '3'
                )
            FROM CTE;
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