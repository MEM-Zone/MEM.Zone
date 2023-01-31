DECLARE @AuthListLocalID AS int
SELECT @AuthListLocalID=CI_ID
FROM v_AuthListInfo
WHERE v_AuthListInfo.Ci_UniqueID=@AuthListID;


SELECT
    [rn].Resource_Names0 AS [Machine],
    [CM_Tools].[dbo].[ufn_GetCompany_by_ResourceID](rn.ResourceID) AS [Company],
    [CM_Tools].[dbo].[ufn_GetOSShortName_by_ResourceID](rn.ResourceID) AS [OS],
    [CM_Tools].[dbo].[ufn_GetOSSPShortName_by_ResourceID](rn.ResourceID) AS [SP],
    ucsa.ResourceID,
    ui.BulletinID,
    ui.ArticleID,
    ui.Title,
    ui.Description,
    ui.DateRevised,
    CASE ui.Severity
        WHEN 10 THEN 'Critical'
        WHEN 8 THEN 'Important'
        WHEN 6 THEN 'Moderate'
        WHEN 2 THEN 'Low'
        ELSE '0-UNKNOWN'
    END AS [Severity]
FROM v_UpdateComplianceStatus ucsa
INNER JOIN [dbo].[v_CIRelation] AS [cir] ON ucsa.CI_ID = cir.ToCIID
INNER JOIN [dbo].[v_UpdateInfo] AS [ui] ON ucsa.CI_ID = ui.CI_ID
JOIN [dbo].[v_RA_System_ResourceNames]  AS [rn] ON ucsa.ResourceID = rn.ResourceID
WHERE cir.RelationType=1
    AND ucsa.ResourceID IN
        (SELECT vc.ResourceID
         FROM v_FullCollectionMembership vc
         WHERE vc.CollectionID = @CollID)
    AND ucsa.Status = '2'
