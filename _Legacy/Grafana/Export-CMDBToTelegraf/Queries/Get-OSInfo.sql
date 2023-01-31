WITH CTE AS (
    SELECT
        OS          = (
            CASE
                WHEN Systems.Operating_System_Name_And0 LIKE '%Workstation 5.%'             THEN 'WindowsXP'
                WHEN Systems.Operating_System_Name_And0 LIKE '%Workstation 6.0%'            THEN 'WindowsVista'
                WHEN Systems.Operating_System_Name_And0 LIKE '%Workstation 6.1%'            THEN 'Windows7'
                WHEN Systems.Operating_System_Name_And0 LIKE 'Windows_7 Entreprise 6.1'     THEN 'Windows7'
                WHEN Systems.Operating_System_Name_And0 = 'Windows Embedded Standard 6.1'   THEN 'Windows7'
                WHEN Systems.Operating_System_Name_And0 LIKE '%Workstation 6.2%'            THEN 'Windows8'
                WHEN Systems.Operating_System_Name_And0 LIKE '%Workstation 6.3%'            THEN 'Windows8_1'
                WHEN Systems.Operating_System_Name_And0 LIKE '%Workstation 10%'             THEN 'Windows10'
                WHEN Systems.Operating_System_Name_And0 LIKE '%Workstation 10%'             THEN 'Windows10'
                WHEN Systems.Operating_System_Name_And0 LIKE '%Server 5.%'                  THEN 'WindowsServer2003'
                WHEN Systems.Operating_System_Name_And0 LIKE '%Server 6.0%'                 THEN 'WindowsServer2008'
                WHEN Systems.Operating_System_Name_And0 LIKE '%Server 6.1%'                 THEN 'WindowsServer2008R2'
                WHEN Systems.Operating_System_Name_And0 LIKE '%Server 6.2%'                 THEN 'WindowsServer2012'
                WHEN Systems.Operating_System_Name_And0 LIKE '%Server 6.3%'                 THEN 'WindowsServer2012R2'
                WHEN Systems.Operating_System_Name_And0 LIKE '%Server 10%'                  THEN (
                    CASE
                        WHEN CAST(REPLACE(Build01, '.', '') AS INT) > 10017763 THEN 'WindowsServer2019'
                        ELSE 'WindowsServer2016'
                    END
                )
                ELSE Systems.Operating_System_Name_And0
            END
        )
        , OSVersion = (
            CASE
                WHEN Systems.Operating_System_Name_And0 LIKE '%Workstation 10%' THEN (
                    CASE REPLACE(Systems.Build01, '.', '')
                        WHEN '10010240' THEN '1507'
                        WHEN '10010586' THEN '1511'
                        WHEN '10014393' THEN '1607'
                        WHEN '10015063' THEN '1703'
                        WHEN '10016299' THEN '1709'
                        WHEN '10017134' THEN '1803'
                        WHEN '10017763' THEN '1809'
                        ELSE 'N/A'
                    END
                )
                WHEN Systems.Operating_System_Name_And0 LIKE '%Server 10%'      THEN (
                    CASE REPLACE(Systems.Build01, '.', '')
                        WHEN '10014393' THEN '1607'
                        WHEN '10016299' THEN '1709'
                        WHEN '10017134' THEN '1803'
                        WHEN '10017763' THEN '1809'
                        ELSE 'N/A'
                    END
                )
                ELSE 'N/A'
            END
        )
        , OSCount   = COUNT(DISTINCT Systems.Name0)
        , Build01   = ISNULL(Systems.Build01, 0)
    FROM V_R_System AS Systems
    WHERE Systems.Operating_System_Name_And0 != 'Unknown Unknown'
    GROUP BY
        Operating_System_Name_And0
        , Build01
)
SELECT DISTINCT
    OS
    , OSVersion
    , OSType = (
        CASE
            WHEN OS LIKE 'WindowsServer%' THEN 'Server'
            WHEN OS LIKE 'Windows%' THEN 'Workstation'
            ELSE 'Unknown'
        END
    )
	, Count  = (
        SELECT SUM(OSCount) FROM CTE AS Summary WHERE Summary.OS = CTE.OS and Summary.OSVersion = CTE.OSVersion
    )
FROM CTE
GROUP BY
    OS
    , OSVersion
    , Build01
ORDER BY
    OS
    , OSVersion