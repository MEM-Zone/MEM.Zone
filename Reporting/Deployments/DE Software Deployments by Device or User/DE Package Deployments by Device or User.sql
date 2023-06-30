/*
.SYNOPSIS
    Lists the Package Deployments for a Collection.
.DESCRIPTION
    Lists the Package Deployments for a Device or User Collection.
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
DECLARE @CollectionID VARCHAR(16)= 'PC100026';
--DECLARE @CollectionID VARCHAR(16)= 'PC100025';
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
            UserName         = CollectionMembership.SMSID
            , PackageName    = Package.Name
            , ProgramName    = Advertisment.ProgramName
            , CollectionName = Deployment.CollectionName
            , Purpose        = (
                CASE
                    WHEN Advertisment.AssignedScheduleEnabled = 0
                    THEN 'Available'
                    ELSE 'Required'
                END
            )
            , LastStateName  = AdvertismentStatus.LastStateName
            , Device         = 'Device'         -- Needed in order to be able to save the report.
            , Manufacturer   = 'Manufacturer'   -- Needed in order to be able to save the report.
            , DeviceType     = 'DeviceType'     -- Needed in order to be able to save the report.
            , ChassisType    = 'ChassisType'    -- Needed in order to be able to save the report.
            , SerialNumber   = 'SerialNumber'   -- Needed in order to be able to save the report.
            , PrimaryUser    = 'PrimaryUser'    -- Needed in order to be able to save the report.
            , TopConsoleUser = 'TopConsoleUser' -- Needed in order to be able to save the report.
        FROM v_Advertisement AS Advertisment
            INNER JOIN v_Package AS Package ON Package.PackageID = Advertisment.PackageID
            LEFT JOIN v_ClientAdvertisementStatus AS AdvertismentStatus ON AdvertismentStatus.AdvertisementID = Advertisment.AdvertisementID
            INNER JOIN vClassicDeployments AS Deployment ON Deployment.DeploymentID = Advertisment.AdvertisementID
            INNER JOIN fn_rbac_FullCollectionMembership(@UserSIDs) AS CollectionMembership ON CollectionMembership.CollectionID = Advertisment.CollectionID
                AND ResourceType = 4 -- Ony Users
        WHERE CollectionMembership.SMSID IN (
            SELECT SMSID
            FROM @CollectionMembers
            WHERE ResourceType = 4 -- Ony Users
        )
    END;

/* Device collection query */
IF @CollectionType = 2
    BEGIN
        SELECT DISTINCT
            Device           = Devices.Name
            , PrimaryUser    = Devices.PrimaryUser
            , TopConsoleUser = Console.TopConsoleUser0
            , Manufacturer   = Enclosure.Manufacturer0
            , DeviceType     = (
                CASE
                    WHEN Enclosure.ChassisTypes0 IN (8, 9, 10, 11, 12, 14, 18, 21, 31, 32) THEN 'Laptop'
                    WHEN Enclosure.ChassisTypes0 IN (3, 4, 5, 6, 7, 15, 16) THEN 'Desktop'
                    WHEN Enclosure.ChassisTypes0 IN (17, 23, 28, 29) THEN 'Servers'
                    WHEN Enclosure.ChassisTypes0 = '30' THEN 'Tablet'
                    ELSE 'Unknown'
                END
            )
            , ChassisTypes   = (
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
            , SerialNumber   = Enclosure.SerialNumber0
            , PackageName    = Package.Name
            , ProgramName    = Advertisment.ProgramName
            , CollectionName = Deployment.CollectionName
            , Purpose        = (
                CASE
                    WHEN Deployment.Purpose = 0
                    THEN 'Available'
                    ELSE 'Required'
                END
            )
            , LastStateName  = AdvertismentStatus.LastStateName
        FROM v_Advertisement AS Advertisment
            JOIN v_Package AS Package ON Package.PackageID = Advertisment.PackageID
            JOIN v_ClientAdvertisementStatus AS AdvertismentStatus ON AdvertismentStatus.AdvertisementID = Advertisment.AdvertisementID
            JOIN v_CombinedDeviceResources AS Devices ON Devices.MachineID = AdvertismentStatus.ResourceID
            LEFT JOIN v_GS_SYSTEM_ENCLOSURE AS Enclosure ON Enclosure.ResourceID = Devices.MachineID
            LEFT JOIN v_GS_SYSTEM_CONSOLE_USAGE AS Console ON Console.ResourceID = Devices.MachineID
            JOIN vClassicDeployments AS Deployment ON Deployment.CollectionID = Advertisment.CollectionID
                AND Advertisment.ProgramName != '*' -- Only Programs
        WHERE Devices.isClient = 1
            AND Devices.MachineID IN (
                SELECT ResourceID
                FROM @CollectionMembers
                WHERE ResourceType = 5 -- Only Devices
            )
    END;

/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/