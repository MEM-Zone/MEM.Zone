SELECT
	Device        = RSystem.Netbios_Name0
	, Version     = RSystem.operatingSystemVersion0
	, KB          = HotFixInfo.HotFixID0
	, InstallDate = LEFT(IIF(HotFixInfo.InstalledOn0 IS NULL, NULL, CONVERT(DATETIME, HotFixInfo.InstalledOn0, 0)), 11)
	, TimeStamp   = HotFixInfo.TimeStamp
FROM v_R_System AS RSystem
	JOIN v_GS_QUICK_FIX_ENGINEERING AS HotFixInfo ON HotFixInfo.ResourceID = RSystem.ResourceID
		AND HotFixInfo.HotFixID0 IN ('KB3012973', 'KB4562830')
	JOIN v_FullCollectionMembership_Valid AS CollectionMembership ON CollectionMembership.ResourceID = HotFixInfo.ResourceID
WHERE CollectionMembership.CollectionID = N'AP201314'
ORDER BY CONVERT(DATETIME, HotFixInfo.InstalledOn0, 0)
