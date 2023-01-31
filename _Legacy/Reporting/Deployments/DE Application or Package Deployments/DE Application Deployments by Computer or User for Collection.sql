/*
*********************************************************************************************************
* Requires          | SQL, Cofiguration Manager DB                                                      *
* ===================================================================================================== *
* Modified by       |    Date    | Revision | Comments                                                  *
* _____________________________________________________________________________________________________ *
* Ioan Popovici     | 2018-05-23 | v1.0     | First version                                             *
* Ioan Popovici     | 2018-08-02 | v1.1     | Added computer service tag, chasis and type information   *
* Ioan Popovici     | 2018-08-03 | v1.2     | Updated report template                                   *
* ===================================================================================================== *
*                                                                                                       *
*********************************************************************************************************

.SYNOPSIS
    This SQL Query is used to get the Application Deployments for a Collection.
.DESCRIPTION
    This SQL Query is used to get the Application Deployments for a Device or User Collection.
.NOTES
    Part of a report should not be run separately.
.LINK
    https://SCCM-Zone.com
    https://github.com/Ioan-Popovici/SCCMZone
*/

/*##=============================================*/
/*## QUERY BODY                                  */
/*##=============================================*/

/* For testing only */
/*
DECLARE @UserSIDs VARCHAR(16)= 'Disabled';
--DECLARE @CollectionID VARCHAR(16)= 'A010016B';
DECLARE @CollectionID VARCHAR(16)= 'A01000B3';
DECLARE @Locale INT= 2;
DECLARE @SelectBy VARCHAR(16);
DECLARE @CollectionType VARCHAR(16);
SELECT @SelectBy = ResourceID
FROM fn_rbac_FullCollectionMembership(@UserSIDs) AS CM
WHERE CM.CollectionID = @CollectionID
    AND CM.ResourceType = 5; --Device collection
IF @SelectBy > 0
    SET @CollectionType = 2;
    ELSE
SET @CollectionType = 1;
*/

/* Remove previous temporary table if exists */
IF OBJECT_ID(N'TempDB.DBO.#CollectionMembers') IS NOT NULL
    BEGIN
        DROP TABLE #CollectionMembers;
    END;

/* Get collection members */
SELECT *
INTO #CollectionMembers
FROM fn_rbac_FullCollectionMembership(@UserSIDs) AS CM
WHERE CM.CollectionID = @CollectionID
    AND CM.ResourceType IN (4, 5); --Only Users or Devices

/* User collection query */
IF @CollectionType = 1
    BEGIN
        SELECT DISTINCT
            UD.Unique_User_Name0 AS UserName,
            DS.SoftwareName,
            DS.CollectionName,
            AD.MachineName,
            SE.Manufacturer0 AS Manufacturer,
            CASE
                WHEN SE.ChassisTypes0 IN (8, 9, 10, 11, 12, 14, 18, 21, 31, 32) THEN 'Laptop'
                WHEN SE.ChassisTypes0 IN (3, 4, 5, 6, 7, 15, 16) THEN 'Desktop'
                WHEN SE.ChassisTypes0 IN (17, 23, 28, 29) THEN 'Servers'
                WHEN SE.ChassisTypes0 = '30' THEN 'Tablet'
                ELSE 'Unknown'
            END AS ComputerType,
			CASE SE.ChassisTypes0
				WHEN '1' THEN 'Other'
				WHEN '2' THEN 'Unknown'
				WHEN '3' THEN 'Desktop'
				WHEN '4' THEN 'Low Profile Desktop'
				WHEN '5' THEN 'Pizza Box'
				WHEN '6' THEN 'Mini Tower'
				WHEN '7' THEN 'Tower'
				WHEN '8' THEN 'Portable'
				WHEN '9' THEN 'Laptop'
				WHEN '10' THEN 'Notebook'
				WHEN '11' THEN 'Hand Held'
				WHEN '12' THEN 'Docking Station'
				WHEN '13' THEN 'All in One'
				WHEN '14' THEN 'Sub Notebook'
				WHEN '15' THEN 'Space-Saving'
				WHEN '16' THEN 'Lunch Box'
				WHEN '17' THEN 'Main System Chassis'
				WHEN '18' THEN 'Expansion Chassis'
				WHEN '19' THEN 'SubChassis'
				WHEN '20' THEN 'Bus Expansion Chassis'
				WHEN '21' THEN 'Peripheral Chassis'
				WHEN '22' THEN 'Storage Chassis'
				WHEN '23' THEN 'Rack Mount Chassis'
				WHEN '24' THEN 'Sealed-Case PC'
                WHEN '25' THEN 'Multi-system chassis'
                WHEN '26' THEN 'Compact PCI'
                WHEN '27' THEN 'Advanced TCA'
                WHEN '28' THEN 'Blade'
                WHEN '29' THEN 'Blade Enclosure'
                WHEN '30' THEN 'Tablet'
                WHEN '31' THEN 'Convertible'
                WHEN '32' THEN 'Detachable'
				ELSE 'Undefinded'
			END AS ChassisType,
            SE.SerialNumber0 AS SerialNumber,
            CASE
                WHEN CIA.DesiredConfigType = 1
                THEN 'Install'
                ELSE 'Remove'
            END AS Purpose,
            AD.UserName AS InstalledBy,
            Dbo.fn_GetAppState(AD.ComplianceState, AD.EnforcementState, CIA.OfferTypeID, 1, AD.DesiredState, AD.IsApplicable) AS EnforcementState
        FROM fn_rbac_CollectionExpandedUserMembers(@UserSIDs) AS CM
            INNER JOIN fn_rbac_R_User(@UserSIDs) AS UD ON UD.ResourceID = CM.UserItemKey
            INNER JOIN fn_rbac_DeploymentSummary(Dbo.FnlShortNameToLCID(@Locale), @UserSIDs) AS DS ON DS.CollectionID = CM.SiteID
            LEFT JOIN fn_rbac_AppIntentAssetData(@UserSIDs) AS AD ON AD.UserName = UD.Unique_User_Name0
                AND AD.AssignmentID = DS.AssignmentID
            INNER JOIN fn_rbac_CIAssignment(@UserSIDs) AS CIA ON CIA.AssignmentID = DS.AssignmentID
			LEFT JOIN v_GS_SYSTEM_ENCLOSURE SE ON SE.ResourceID = AD.MachineID
        WHERE DS.FeatureType = 1
            AND UD.Unique_User_Name0 IN (
                SELECT SMSID
                FROM #CollectionMembers
                WHERE ResourceType = 4 --Ony Users
            )
        ORDER BY
            UserName,
            SoftwareName,
            CollectionName,
            MachineName,
            EnforcementState,
            InstalledBy;
    END;

/* Device collection query */
IF @CollectionType = 2
    BEGIN
        SELECT DISTINCT
            SD.Netbios_Name0 AS MachineName,
            SE.Manufacturer0 AS Manufacturer,
            CASE
                WHEN SE.ChassisTypes0 IN (8 , 9, 10, 11, 12, 14, 18, 21, 31, 32) THEN 'Laptop'
                WHEN SE.ChassisTypes0 IN (3, 4, 5, 6, 7, 15, 16) THEN 'Desktop'
                WHEN SE.ChassisTypes0 IN (17, 23, 28, 29) THEN 'Servers'
                WHEN SE.ChassisTypes0 = '30' THEN 'Tablet'
                ELSE 'Unknown'
            END AS ComputerType,
			CASE SE.ChassisTypes0
				WHEN '1' THEN 'Other'
				WHEN '2' THEN 'Unknown'
				WHEN '3' THEN 'Desktop'
				WHEN '4' THEN 'Low Profile Desktop'
				WHEN '5' THEN 'Pizza Box'
				WHEN '6' THEN 'Mini Tower'
				WHEN '7' THEN 'Tower'
				WHEN '8' THEN 'Portable'
				WHEN '9' THEN 'Laptop'
				WHEN '10' THEN 'Notebook'
				WHEN '11' THEN 'Hand Held'
				WHEN '12' THEN 'Docking Station'
				WHEN '13' THEN 'All in One'
				WHEN '14' THEN 'Sub Notebook'
				WHEN '15' THEN 'Space-Saving'
				WHEN '16' THEN 'Lunch Box'
				WHEN '17' THEN 'Main System Chassis'
				WHEN '18' THEN 'Expansion Chassis'
				WHEN '19' THEN 'SubChassis'
				WHEN '20' THEN 'Bus Expansion Chassis'
				WHEN '21' THEN 'Peripheral Chassis'
				WHEN '22' THEN 'Storage Chassis'
				WHEN '23' THEN 'Rack Mount Chassis'
				WHEN '24' THEN 'Sealed-Case PC'
                WHEN '25' THEN 'Multi-system chassis'
                WHEN '26' THEN 'Compact PCI'
                WHEN '27' THEN 'Advanced TCA'
                WHEN '28' THEN 'Blade'
                WHEN '29' THEN 'Blade Enclosure'
                WHEN '30' THEN 'Tablet'
                WHEN '31' THEN 'Convertible'
                WHEN '32' THEN 'Detachable'
				ELSE 'Undefinded'
			END AS ChassisType,
			SE.SerialNumber0 AS SerialNumber,
            DS.SoftwareName,
            DS.CollectionName,
            CASE
                WHEN CIA.DesiredConfigType = 1
                THEN 'Install'
                ELSE 'Remove'
            END AS Purpose,
            AD.UserName AS InstalledBy,
            Dbo.fn_GetAppState(AD.ComplianceState, AD.EnforcementState, CIA.OfferTypeID, 1, AD.DesiredState, AD.IsApplicable) AS EnforcementState
        FROM fn_rbac_R_System(@UserSIDs) AS SD
            INNER JOIN fn_rbac_FullCollectionMembership(@UserSIDs) AS CM ON CM.ResourceID = SD.ResourceID
                AND CM.ResourceType = 5 --Only Devices
            INNER JOIN fn_rbac_DeploymentSummary(Dbo.FnlShortNameToLCID(@Locale), @UserSIDs) AS DS ON DS.CollectionID = CM.CollectionID
                AND DS.FeatureType = 1
            LEFT JOIN fn_rbac_AppIntentAssetData(@UserSIDs) AS AD ON AD.MachineID = CM.ResourceID
                AND AD.AssignmentID = DS.AssignmentID
            INNER JOIN fn_rbac_CIAssignment(@UserSIDs) AS CIA ON CIA.AssignmentID = DS.AssignmentID
			LEFT JOIN v_GS_SYSTEM_ENCLOSURE SE ON SE.ResourceID = SD.ResourceID
        WHERE Client0 = 1
            AND SD.Netbios_Name0 IN (
                SELECT Name
                FROM #CollectionMembers
                WHERE ResourceType = 5 --Only Devices
            )
        ORDER BY
            MachineName,
            SoftwareName,
            CollectionName,
            InstalledBy,
            EnforcementState;
    END;

/* Remove  temporary table */
DROP TABLE #CollectionMembers;

/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/