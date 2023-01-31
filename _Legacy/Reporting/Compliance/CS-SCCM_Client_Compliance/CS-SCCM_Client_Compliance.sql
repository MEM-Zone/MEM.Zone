/*DECLARE @UserSIDs VARCHAR(16);
SELECT @UserSIDs = 'disabled';
DECLARE @CollID VARCHAR(8);
SET @CollID = 'SMS00001';
*/
SELECT DISTINCT
    [s].[ResourceID] AS [MachineID],
    [r].Resource_Names0 AS [Machine],
    CASE
        WHEN ([s].[Client0] = 1) THEN 'Yes'
        ELSE 'No'
    END AS [Client],
    CASE
        WHEN ([s].[Active0] = 1) THEN 'Active'
        WHEN ([s].[Active0] = 0) THEN 'Inactive'
        ELSE 'Unknown'
    END AS [Active],
    CASE
       WHEN (chcs.LastEvaluationHealthy = 1) THEN 'Pass'
       WHEN (chcs.LastEvaluationHealthy = 2) THEN 'Fail'
       ELSE 'Unknown'
    END AS 'Last Evaluation Healthy',
    chcs.LastDDR,
    CASE
        WHEN (DATEDIFF(day, chcs.LastDDR, GETDATE()) <= 14) THEN 'Yes'
        WHEN (DATEDIFF(day, chcs.LastDDR, GETDATE()) >= 14) THEN 'NO'
        ELSE 'Unknown'
    END AS 'DDR in the last 14 Days',
    CASE
        WHEN (DATEDIFF(day, os.LastBootUpTime0, GETDATE()) <= 14) THEN 'Yes'
        WHEN (DATEDIFF(day, os.LastBootUpTime0, GETDATE()) >= 14) THEN 'No'
        ELSE 'Unknown'
    END AS 'Rebooted in the last 14 Days',
    CASE
        WHEN ([s].[Client_Version0] IS NULL) THEN 'Unknown'
        ELSE [s].[Client_Version0]
    END AS 'Client Version',
    CASE
        WHEN (MAX([ou].[System_OU_Name0]) IS NULL) THEN 'Unknown'
        ELSE MAX([ou].[System_OU_Name0])
    END AS OUName
INTO #TEMP
FROM [dbo].[fn_rbac_R_System](@UserSIDs) [s]
    LEFT JOIN [v_RA_System_SystemOUName] AS [ou] ON [s].[ResourceID] = [ou].[ResourceID]
    LEFT JOIN fn_rbac_GS_SYSTEM (@UserSIDs) AS [sys] ON [s].[ResourceID] = [sys].[ResourceID]
    LEFT JOIN [v_RA_System_ResourceNames] [r] ON [s].[ResourceID] = [r].[ResourceID]
    LEFT OUTER JOIN dbo.v_GS_OPERATING_SYSTEM AS os ON os.ResourceID = [s].[ResourceID]
    LEFT OUTER JOIN dbo.v_CH_ClientSummary AS chcs ON chcs.ResourceID = [s].[ResourceID]
    JOIN dbo.v_FullCollectionMembership AS fcm ON s.ResourceID = fcm.ResourceID
WHERE fcm.CollectionID = @CollID

GROUP BY
    [r].Resource_Names0,
    [sys].[SystemRole0],
    [s].[Client0],
    [s].[Active0],
    [s].[Client_Version0],
    [s].[Netbios_Name0],
    [s].[Full_Domain_Name0],
    [s].[ResourceID],
    chcs.LastEvaluationHealthy,
    chcs.LastDDR,
    os.LastBootUpTime0
ORDER BY
    chcs.LastDDR DESC

SELECT * ,
    CASE
        WHEN ([ou].[OUName] LIKE '%ICC%' OR ou.Machine LIKE '%ICC%') THEN 'ICC'
        WHEN ([ou].[OUName] LIKE '%WTO%' OR ou.Machine LIKE '%WTO%') THEN 'WTO'
        WHEN ([ou].[OUName] LIKE '%WMO%' OR ou.Machine LIKE '%WMO%') THEN 'WMO'
        WHEN ([ou].[OUName] LIKE '%WIPO%' OR ou.Machine LIKE '%WIPO%') THEN 'WIPO'
        WHEN ([ou].[OUName] LIKE '%UNJSPF%' OR ou.Machine LIKE '%UNJSPF%') THEN 'UNJSPF'
        WHEN ([ou].[OUName] LIKE '%OHCHR%' OR ou.Machine LIKE '%OHCHR%') THEN 'OHCHR'
        WHEN ([ou].[OUName] LIKE '%SVC%' OR ou.Machine LIKE '%SVC%') THEN 'SVC'
        ELSE '0-UNKNOWN'
    END AS [Company]
    FROM #TEMP OU
DROP TABLE #TEMP
