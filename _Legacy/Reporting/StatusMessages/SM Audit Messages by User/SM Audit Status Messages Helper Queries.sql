/* UserInfo Dataset */
SELECT
    AttributeValue AS UserName,
    (AttributeValue + ' (' + CONVERT(VARCHAR(12),Count(*)) + ')') AS UserNameDisplayName
FROM fn_rbac_StatMsgAttributes(@UserSIDs)
WHERE AttributeID = 403 --Users
GROUP BY AttributeValue
UNION ALL
SELECT
	'%' AS UserName,
	'All' AS UserNameDisplayName
ORDER BY UserName;

/* UserDisplayName Dataset */
SELECT DISTINCT
    AttributeValue AS UserDisplayName
FROM fn_rbac_StatMsgAttributes(@UserSIDs)
WHERE
    AttributeID = 403 -- Users only
    AND AttributeValue = @UserName

/* ReportDescription Dataset */
SELECT DISTINCT Description
FROM ReportServer.dbo.Catalog
WHERE Name = @ReportName