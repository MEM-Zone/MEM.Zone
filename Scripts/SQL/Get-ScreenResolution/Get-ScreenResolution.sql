/*
.SYNOPSIS
    Gets the screen resolution.
.DESCRIPTION
    Gets the screen resolutions accross inventoried devices in MEMCM.
.NOTES
    Created by Ioan Popovici
    v1.0.0 - 2021-02-02
.LINK
    https://MEM.Zone/Get-ScreenResolution-SQL
.LINK
    https://MEM.Zone/ISSUES
*/

/*##=============================================*/
/*## QUERY BODY                                  */
/*##=============================================*/
/* #region QueryBody */

/* Testing variables !! Need to be replaced for Production !! */
DECLARE @UserSIDs     AS NVARCHAR(10)  = 'Disabled';
DECLARE @CollectionID AS NVARCHAR(10)  = 'SMS00001';

SELECT
    Resolution = Concat(VideoController.CurrentHorizontalResolution0, 'x', VideoController.CurrentVerticalResolution0)
    , Number = count(*)
FROM v_GS_VIDEO_CONTROLLER AS VideoController
    JOIN v_R_System AS System ON System.ResourceID = VideoController.ResourceID
    JOIN fn_rbac_FullCollectionMembership_Valid(@UserSIDs) AS CollectionMembership ON CollectionMembership.ResourceID = System.ResourceID
WHERE VideoController.CurrentHorizontalResolution0 IS NOT NULL
    AND System.Operating_System_Name_and0 LIKE 'Microsoft_Windows_NT_%Workstation%'
    AND CollectionMembership.CollectionID = @CollectionID
GROUP BY
    VideoController.CurrentHorizontalResolution0
    , VideoController.CurrentVerticalResolution0
ORDER BY
    Number
    , VideoController.CurrentHorizontalResolution0
    , VideoController.CurrentVerticalResolution0

/* #endregion */
/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/
