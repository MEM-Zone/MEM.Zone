SELECT
	Device    = Systems.Name0
	, DN      = Systems.Distinguished_Name0
	, Country =  (SELECT SUBSTRING((SELECT CAST('<t>' + REPLACE(Systems.Distinguished_Name0, ',','</t><t>') + '</t>' AS XML).value('/t[3]','varchar(500)')), 4, 4))
FROM v_r_system AS Systems
