/*
*********************************************************************************************************
* Requires          | SQL, Cofiguration Manager DB                                                      *
* ===================================================================================================== *
* Modified by       |    Date    | Revision | Comments                                                  *
* _____________________________________________________________________________________________________ *
* Ioan Popovici     | 2018-07-16 | v1.0     | First version                                             *
* Ioan Popovici     | 2018-08-06 | v1.1     | Fixed empty software name                                 *
* Ioan Popovici     | 2018-08-06 | v1.2     | Added computer service tag and type information           *
* Ioan Popovici     | 2018-08-06 | v1.3     | Fixed empty or NULL publisher, updated report template    *
* ===================================================================================================== *
*                                                                                                       *
*********************************************************************************************************

.SYNOPSIS
    This SQL Query is used to get installed software by collection and software name.
.DESCRIPTION
    This SQL Query is used to get installed software by collection and software name.
.NOTES
    Part of a report should not be run separately.
.LINK
    https://SCCM-Zone.com
    https://github.com/Ioan-Popovici/SCCMZone
*/

/*##=============================================*/
/*## QUERY BODY                                  */
/*##=============================================*/
/* #region QueryBody */

/* Remove previous temporary table if exists */
IF OBJECT_ID (N'TempDB.DBO.#InstalledSoftware') IS NOT NULL
    BEGIN
        DROP TABLE #InstalledSoftware;
    END;

/* Get installed software */
SELECT DISTINCT
    SYS.Netbios_Name0 AS Computer,
    SE.Manufacturer0 AS Manufacturer,
    CASE
        WHEN SE.ChassisTypes0 IN (8 , 9, 10, 11, 12, 14, 18, 21, 31, 32) THEN 'Laptop'
        WHEN SE.ChassisTypes0 IN (3, 4, 5, 6, 7, 15, 16) THEN 'Desktop'
        WHEN SE.ChassisTypes0 IN (17, 23, 28, 29) THEN 'Servers'
        WHEN SE.ChassisTypes0 = '30' THEN 'Tablet'
        ELSE 'Unknown'
    END AS ComputerType,
    SE.SerialNumber0 AS SerialNumber,
    CASE
        WHEN SW.Publisher0 IS NULL THEN '<No Publisher>'
        WHEN SW.Publisher0 = '' THEN '<No Publisher>'
        WHEN SW.Publisher0 = '<no manufacturer>' THEN '<No Publisher>'
        ELSE SW.Publisher0
    END AS Publisher,
    SW.DisplayName0 AS Software,
    SW.Version0 AS Version,
    SYS.Resource_Domain_OR_Workgr0 AS DomainOrWorkgroup,
    SYS.User_Name0 AS UserName,
    OS.Caption0 AS OperatingSystem
INTO #InstalledSoftware
FROM fn_rbac_Add_Remove_Programs(@UserSIDs) SW
    JOIN fn_rbac_R_System(@UserSIDs) SYS ON SW.ResourceID = SYS.ResourceID
    JOIN v_ClientCollectionMembers COL ON COL.ResourceID = SYS.ResourceID
    JOIN v_GS_OPERATING_SYSTEM OS ON OS.ResourceID = SYS.ResourceID
    LEFT JOIN v_GS_SYSTEM_ENCLOSURE SE ON SE.ResourceID = SYS.ResourceID
WHERE COL.CollectionID = @CollectionID
    AND SW.DisplayName0 LIKE '%'+@SoftwareName+'%'
    AND SW.DisplayName0 != ''
ORDER BY SYS.Netbios_Name0,
    Publisher,
    SW.DisplayName0,
    SW.Version0;

/* Use NOT LIKE if needed */
IF @SoftwareNameNotLike != ''
BEGIN
    SELECT
        Computer,
        Manufacturer,
        ComputerType,
        SerialNumber,
        Publisher,
        Software,
        Version,
        DomainOrWorkgroup,
        UserName,
        OperatingSystem
    FROM #InstalledSoftware
        WHERE Software NOT LIKE '%'+@SoftwareNameNotLike+'%'
END;

/* Otherwise perform a normal select */
IF @SoftwareNameNotLike = ''
BEGIN
    SELECT
        Computer,
        Manufacturer,
        ComputerType,
        SerialNumber,
        Publisher,
        Software,
        Version,
        DomainOrWorkgroup,
        UserName,
        OperatingSystem
    FROM #InstalledSoftware
END;

/* Remove  temporary table */
DROP TABLE #InstalledSoftware;

/* #endregion */
/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/