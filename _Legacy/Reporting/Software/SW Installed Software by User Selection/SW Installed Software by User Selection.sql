/*
.SYNOPSIS
    Lists the installed software.
.DESCRIPTION
    Lists the installed software by user selection (Device, Publisher or Name).
    Supports filtering and exclusions by multiple software names using comma separated values and sql wildcards.
.NOTES
    Created by Ioan Popovici.
    Requires ufn_csv_String_Parser custom function.
    Part of a report should not be run separately.
.LINK
    https://SCCM.Zone/SW-Installed-Software-by-User-Selection
.LINK
    https://SCCM.Zone/SW-Installed-Software-by-User-Selection-CHANGELOG
.LINK
    https://SCCM.Zone/SW-Installed-Software-by-User-Selection-GIT
.LINK
    https://SCCM.Zone/Issues
*/

/*##=============================================*/
/*## QUERY BODY                                  */
/*##=============================================*/
/* #region QueryBody */

/* Testing variables !! Need to be commented for Production !! */
--DECLARE @UserSIDs            AS NVARCHAR(10)  = 'Disabled';
--DECLARE @CollectionID        AS NVARCHAR(250) = 'HUB00095';
--DECLARE @SoftwareNameLike    AS NVARCHAR(250) = 'Adobe%,WinZip%';
--DECLARE @SoftwareNameNotLike AS NVARCHAR(250) = 'Adobe Acrobat [1-8]%,7-zip%,%Fran_aise%';

/* Initialize SoftwareLike table */
DECLARE @SoftwareLike TABLE (
    SoftwareName NVARCHAR(250)
)

/* Initialize SoftwareNotLike table */
DECLARE @SoftwareNotLike TABLE (
    SoftwareName NVARCHAR(250)
)

/* Initialize InstalledSoftware table */
DECLARE @InstalledSoftware TABLE (
    Device              NVARCHAR(250)
    , Manufacturer      NVARCHAR(250)
    , DeviceType        NVARCHAR(50)
    , SerialNumber      NVARCHAR(50)
    , Publisher         NVARCHAR(250)
    , SoftwareName      NVARCHAR(250)
    , Version           NVARCHAR(50)
    , DomainOrWorkgroup NVARCHAR(100)
    , UserName          NVARCHAR(100)
    , OperatingSystem   NVARCHAR(100)
)

/* Populate SoftwareLike table */
INSERT INTO @SoftwareLike (SoftwareName)
SELECT StringValue
FROM CM_Tools.dbo.ufn_csv_String_Parser(@SoftwareNameLike, ',');    --!! Change the 'CM_Tools' database to your custom function database !!

/* Populate SoftwareNotLike table */
INSERT INTO @SoftwareNotLike (SoftwareName)
SELECT StringValue
FROM CM_Tools.dbo.ufn_csv_String_Parser(@SoftwareNameNotLike, ','); --!! Change the 'CM_Tools' database to your custom function database !!

/* Populate InstalledSoftware table */
INSERT INTO @InstalledSoftware (Device, Manufacturer, DeviceType, SerialNumber, Publisher, SoftwareName, Version, DomainOrWorkgroup, UserName, OperatingSystem)
SELECT DISTINCT
    Device              = Systems.Netbios_Name0
    , Manufacturer      = Enclosure.Manufacturer0
    , DeviceType        = (
        CASE
            WHEN Enclosure.ChassisTypes0 IN (8 , 9, 10, 11, 12, 14, 18, 21, 31, 32) THEN 'Laptop'
            WHEN Enclosure.ChassisTypes0 IN (3, 4, 5, 6, 7, 15, 16) THEN 'Desktop'
            WHEN Enclosure.ChassisTypes0 IN (17, 23, 28, 29) THEN 'Servers'
            WHEN Enclosure.ChassisTypes0 = '30' THEN 'Tablet'
            ELSE 'Unknown'
        END
    )
    , SerialNumber      = Enclosure.SerialNumber0
    , Publisher         = (
        CASE
            WHEN Software.Publisher0 IS NULL THEN '<No Publisher>'
            WHEN Software.Publisher0 = '' THEN '<No Publisher>'
            WHEN Software.Publisher0 = '<no manufacturer>' THEN '<No Publisher>'
            ELSE Software.Publisher0
        END
    )
    , SoftwareName      = COALESCE(NULLIF(Software.DisplayName0, ''), 'Unknown')
    , Version           = COALESCE(NULLIF(Software.Version0, ''), 'Unknown')
    , DomainOrWorkgroup = Systems.Resource_Domain_OR_Workgr0
    , UserName          = Systems.User_Name0
    , OperatingSystem   = OS.Caption0
FROM fn_rbac_Add_Remove_Programs(@UserSIDs) AS Software
    JOIN v_R_System AS Systems ON Systems.ResourceID = Software.ResourceID
    JOIN v_ClientCollectionMembers AS CollectionMembers ON CollectionMembers.ResourceID = Systems.ResourceID
    JOIN v_GS_OPERATING_SYSTEM AS OS ON OS.ResourceID = Systems.ResourceID
    LEFT JOIN v_GS_SYSTEM_ENCLOSURE AS Enclosure ON Enclosure.ResourceID = Systems.ResourceID
WHERE CollectionMembers.CollectionID = @CollectionID
    AND EXISTS (
        SELECT SoftwareName
        FROM @SoftwareLike AS SoftwareLike
        WHERE Software.DisplayName0 LIKE SoftwareLike.SoftwareName
    );

/* Use NOT LIKE if needed */
IF EXISTS (SELECT SoftwareName FROM @SoftwareNotLike)
BEGIN
    SELECT
        Device
        , Manufacturer
        , DeviceType
        , SerialNumber
        , Publisher
        , SoftwareName
        , Version
        , DomainOrWorkgroup
        , UserName
        , OperatingSystem
    FROM @InstalledSoftware AS InstalledSoftware
        WHERE NOT EXISTS (
            SELECT SoftwareName
            FROM @SoftwareNotLike AS SoftwareNotLike
            WHERE InstalledSoftware.SoftwareName LIKE SoftwareNotLike.SoftwareName
        )
END;

/* Otherwise perform a normal select */
ELSE
BEGIN
    SELECT
        Device
        , Manufacturer
        , DeviceType
        , SerialNumber
        , Publisher
        , SoftwareName
        , Version
        , DomainOrWorkgroup
        , UserName
        , OperatingSystem
    FROM @InstalledSoftware
END;

/* #endregion */
/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/