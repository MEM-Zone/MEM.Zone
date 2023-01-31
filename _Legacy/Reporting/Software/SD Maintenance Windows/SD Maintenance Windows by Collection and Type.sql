/*
*********************************************************************************************************
* Requires          | SQL, SCCM DB                                                                      *
* ===================================================================================================== *
* Modified by       |    Date    | Revision | Comments                                                  *
* _____________________________________________________________________________________________________ *
* Ioan Popovici     | 2016-05-16 | First version                                                        *
* Ioan Popovici     | 2018-08-21 | Added localizations, interactive sorting, updated template           *
* Ioan Popovici     | 2018-08-24 | Added filters for collection name and maintenance window name        *
* ===================================================================================================== *
*                                                                                                       *
*********************************************************************************************************

.SYNOPSIS
    This SQL Query is used to get the Maintenance Windows.
.DESCRIPTION
    This SQL Query is used to get the Maintenance Windows for the whole SCCM environment with Start Time and Duration.
.NOTES
    Part of a report should not be run separately.
.LINK
    https://SCCM-Zone.com
    https://github.com/Ioan-Popovici/SCCMZone
*/

/*##=============================================*/
/*## QUERY BODY                                  */
/*##=============================================*/

SELECT
    Collection.Name AS Collection,
    ServiceWindow.Name,
    ServiceWindow.Description,
    CASE ServiceWindow.ServiceWindowType
        WHEN 1 THEN 'All Deployments'
        WHEN 2 THEN 'Programs'
        WHEN 3 THEN 'Reboot Required'
        WHEN 4 THEN 'Software Updates'
        WHEN 5 THEN 'Task Sequences'
        WHEN 6 THEN 'User Defined'
    END AS Type,
    ServiceWindow.StartTime,
    ServiceWindow.Duration,
    CASE ServiceWindow.IsEnabled
        WHEN 1 THEN 'Yes'
        ELSE 'No'
    END AS Enabled
FROM dbo.fn_rbac_ServiceWindow(@UserSIDs) AS ServiceWindow
    JOIN v_Collection AS Collection ON Collection.CollectionID = ServiceWindow.CollectionID
ORDER BY Name

/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/
