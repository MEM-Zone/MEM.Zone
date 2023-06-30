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