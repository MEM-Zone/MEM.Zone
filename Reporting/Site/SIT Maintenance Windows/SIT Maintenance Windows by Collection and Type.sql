/*
.SYNOPSIS
    Lists all maintenance windows.
.DESCRIPTION
    Lists all SCCM maintenance windows with Start Time and Duration.
.NOTES
    Created by Ioan Popovici
    Part of a report should not be run separately.
.LINK
    https://SCCM.Zone/SIT-Maintenance-Windows
.LINK
    https://SCCM.Zone/SIT-Maintenance-Windows-CHANGELOG
.LINK
    https://SCCM.Zone/SIT-Maintenance-Windows-GIT
.LINK
    https://SCCM.Zone/Issues
*/

/*##=============================================*/
/*## QUERY BODY                                  */
/*##=============================================*/

/* Testing variables !! Need to be commented for Production !! */
DECLARE @UserSIDs       AS NVARCHAR(10) = 'Disabled';

SELECT
    Collection.Name AS Collection
    , ServiceWindow.Name
    , ServiceWindow.Description
    , Type = (
        CASE ServiceWindow.ServiceWindowType
            WHEN 1 THEN 'All Deployments'
            WHEN 2 THEN 'Programs'
            WHEN 3 THEN 'Reboot Required'
            WHEN 4 THEN 'Software Updates'
            WHEN 5 THEN 'Task Sequences'
            WHEN 6 THEN 'User Defined'
        END
    )
    , ServiceWindow.StartTime
    , ServiceWindow.Duration
    , Enabled = (
        CASE ServiceWindow.IsEnabled
            WHEN 1 THEN 'Yes'
            ELSE 'No'
        END
    )
FROM dbo.fn_rbac_ServiceWindow(@UserSIDs) AS ServiceWindow
    JOIN v_Collection AS [Collection] ON [Collection].CollectionID = ServiceWindow.CollectionID
ORDER BY Name

/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/
