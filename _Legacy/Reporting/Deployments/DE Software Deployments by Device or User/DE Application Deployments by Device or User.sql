/*
.SYNOPSIS
    Lists the Application Deployments for a Collection.
.DESCRIPTION
    Lists the Application Deployments for a Device or User Collection.
.NOTES
    Created by Ioan Popovici
    Part of a report should not be run separately.
.LINK
    https://SCCM.Zone/DE-Deployments-by-Device-or-User
.LINK
    https://SCCM.Zone/DE-Deployments-by-Device-or-User-CHANGELOG
.LINK
    https://SCCM.Zone/DE-Deployments-by-Device-or-User-GIT
.LINK
    https://SCCM.Zone/Issues
*/

/*##=============================================*/
/*## QUERY BODY                                  */
/*##=============================================*/

/* Testing variables !! Need to be commented for Production !! */

/*
DECLARE @UserSIDs VARCHAR(16)= 'Disabled';
DECLARE @CollectionID VARCHAR(16)= 'HUB005A6';
--DECLARE @CollectionID VARCHAR(16)= 'HUB00744';
DECLARE @SelectBy VARCHAR(16);
DECLARE @CollectionType VARCHAR(16);
SELECT @SelectBy = ResourceID
FROM fn_rbac_FullCollectionMembership(@UserSIDs) AS CollectionMembers
WHERE CollectionMembers.CollectionID = @CollectionID
    AND CollectionMembers.ResourceType = 5; --Device collection
IF @SelectBy > 0
    SET @CollectionType = 2;
ELSE
    SET @CollectionType = 1;
*/

/* Initialize CollectionMembers table */
DECLARE @CollectionMembers TABLE (
    ResourceID     INT
    , ResourceType INT
    , SMSID        NVARCHAR(100)
)

/* Populate CollectionMembers table */
INSERT INTO @CollectionMembers (ResourceID, ResourceType, SMSID)
SELECT ResourceID, ResourceType, SMSID
FROM fn_rbac_FullCollectionMembership(@UserSIDs) AS CollectionMembers
WHERE CollectionMembers.CollectionID = @CollectionID
    AND CollectionMembers.ResourceType IN (4, 5); --Only Users or Devices

/* User collection query */
IF @CollectionType = 1
    BEGIN
        SELECT DISTINCT
            UserName           = Users.Unique_User_Name0
            , PrimaryUser      = Devices.PrimaryUser
            , TopConsoleUser   = Console.TopConsoleUser0
            , SoftwareName     = Deployments.SoftwareName
            , CollectionName   = Deployments.CollectionName
            , Device           = AssetData.MachineName
            , Manufacturer     = Enclosure.Manufacturer0
            , DeviceType       = (
                CASE
                    WHEN Enclosure.ChassisTypes0 IN (8, 9, 10, 11, 12, 14, 18, 21, 31, 32) THEN 'Laptop'
                    WHEN Enclosure.ChassisTypes0 IN (3, 4, 5, 6, 7, 15, 16) THEN 'Desktop'
                    WHEN Enclosure.ChassisTypes0 IN (17, 23, 28, 29) THEN 'Servers'
                    WHEN Enclosure.ChassisTypes0 = '30' THEN 'Tablet'
                    ELSE 'Unknown'
                END
            )
            , ChassisType      = (
                CASE Enclosure.ChassisTypes0
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
                END
            )
            , SerialNumber     = Enclosure.SerialNumber0
            , Purpose          = (
                CASE
                    WHEN Assignments.DesiredConfigType = 1
                    THEN 'Install'
                    ELSE 'Remove'
                END
            )
            , InstalledBy      = Users.Unique_User_Name0
            , EnforcementState = (
                dbo.fn_GetAppState(AssetData.ComplianceState, AssetData.EnforcementState, Assignments.OfferTypeID, 1, AssetData.DesiredState, AssetData.IsApplicable)
            )
        FROM fn_rbac_CollectionExpandedUserMembers(@UserSIDs) AS CollectionMembers
            INNER JOIN v_R_User AS Users ON Users.ResourceID = CollectionMembers.UserItemKey
            INNER JOIN v_DeploymentSummary AS Deployments ON Deployments.CollectionID = CollectionMembers.SiteID
            LEFT JOIN v_AppIntentAssetData AS AssetData ON AssetData.UserName = Users.Unique_User_Name0
                AND AssetData.AssignmentID = Deployments.AssignmentID
            INNER JOIN v_CIAssignment AS Assignments ON Assignments.AssignmentID = Deployments.AssignmentID
			LEFT JOIN v_GS_SYSTEM_ENCLOSURE AS Enclosure ON Enclosure.ResourceID = AssetData.MachineID
            LEFT JOIN v_GS_SYSTEM_CONSOLE_USAGE AS Console ON Console.ResourceID = AssetData.MachineID
			LEFT JOIN  v_CombinedDeviceResources AS Devices ON Devices.MachineID = AssetData.MachineID
        WHERE Deployments.FeatureType = 1
            AND Users.Unique_User_Name0 IN (
                SELECT SMSID
                FROM @CollectionMembers
                WHERE ResourceType = 4 --Ony Users
            )
    END;

/* Device collection query */
IF @CollectionType = 2
    BEGIN
        SELECT DISTINCT
            Device             = Devices.Name
			, PrimaryUser      = Devices.PrimaryUser
            , TopConsoleUser   = Console.TopConsoleUser0
            , Manufacturer     = Enclosure.Manufacturer0
            , DeviceType       = (
                CASE
                    WHEN Enclosure.ChassisTypes0 IN (8 , 9, 10, 11, 12, 14, 18, 21, 31, 32) THEN 'Laptop'
                    WHEN Enclosure.ChassisTypes0 IN (3, 4, 5, 6, 7, 15, 16) THEN 'Desktop'
                    WHEN Enclosure.ChassisTypes0 IN (17, 23, 28, 29) THEN 'Servers'
                    WHEN Enclosure.ChassisTypes0 = '30' THEN 'Tablet'
                    ELSE 'Unknown'
                END
            )
            , ChassisType      = (
                CASE Enclosure.ChassisTypes0
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
                END
            )
			, SerialNumber     = Enclosure.SerialNumber0
            , SoftwareName     = Deployments.SoftwareName
            , CollectionName   = Deployments.CollectionName
            , Purpose          = (
                CASE
                    WHEN Assignments.DesiredConfigType = 1
                    THEN 'Install'
                    ELSE 'Remove'
                END
            )
            , InstalledBy      = AssetData.UserName
            , EnforcementState = Dbo.fn_GetAppState(AssetData.ComplianceState, AssetData.EnforcementState, Assignments.OfferTypeID, 1, AssetData.DesiredState, AssetData.IsApplicable)
        FROM v_CombinedDeviceResources AS Devices
            INNER JOIN fn_rbac_FullCollectionMembership(@UserSIDs) AS CollectionMembers ON CollectionMembers.ResourceID = Devices.MachineID
                AND CollectionMembers.ResourceType = 5 --Only Devices
            INNER JOIN v_DeploymentSummary AS Deployments ON Deployments.CollectionID = CollectionMembers.CollectionID
                AND Deployments.FeatureType = 1
            LEFT JOIN v_AppIntentAssetData AS AssetData ON AssetData.MachineID = CollectionMembers.ResourceID
                AND AssetData.AssignmentID = Deployments.AssignmentID
            INNER JOIN v_CIAssignment AS Assignments ON Assignments.AssignmentID = Deployments.AssignmentID
			LEFT JOIN v_GS_SYSTEM_ENCLOSURE AS Enclosure ON Enclosure.ResourceID = Devices.MachineID
            LEFT JOIN v_GS_SYSTEM_CONSOLE_USAGE AS Console ON Console.ResourceID = Devices.MachineID
        WHERE Devices.isClient = 1
            AND Devices.MachineID IN (
                SELECT ResourceID
                FROM @CollectionMembers
                WHERE ResourceType = 5 --Only Devices
            )
    END;

/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/