DECLARE @AuthListLocalID AS int
SELECT @AuthListLocalID=CI_ID
FROM v_AuthListInfo
WHERE CI_UniqueID=@AuthListID
    SELECT DISTINCT ui.BulletinID,
                    ui.ArticleID,
                    ui.Title,
                    a ui.Description,
                    ui.DateRevised,
                    CASE ui.Severity
                        WHEN 10 THEN 'Critical'
                        WHEN 8 THEN 'Important'
                        WHEN 6 THEN 'Moderate'
                        WHEN 2 THEN 'Low'
                        ELSE '(Unknown)'
                    END AS [Severity],
                    CASE
                        WHEN DATEDIFF("day",ui.DateRevised,GETDATE()) <  30 THEN '0'
                        WHEN DATEDIFF("day",ui.DateRevised,GETDATE()) >= 30 THEN '1'
                    END AS Age INTO #temp
    FROM v_UpdateComplianceStatus ucsa
    INNER JOIN v_CIRelation cir ON ucsa.CI_ID = cir.ToCIID
    INNER JOIN v_UpdateInfo ui ON ucsa.CI_ID = ui.CI_ID WHERE cir.FromCIID=@AuthListLocalID
    AND cir.RelationType=1
    AND ucsa.Status = '2' --Required

    SELECT DISTINCT bulletinid,
                    articleid,
                    title,
                    description,
                    daterevised,
                    severity,
                    age,
                    ROW_NUMBER() over (ORDER BY bulletinid) AS [row]
    FROM #temp
ORDER BY ROW
DROP TABLE #temp
