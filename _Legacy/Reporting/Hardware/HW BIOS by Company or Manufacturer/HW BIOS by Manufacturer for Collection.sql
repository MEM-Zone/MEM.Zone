/*
.SYNOPSIS
    Gets the Hardware info of a Computer Collection.
.DESCRIPTION
    Gets the Hardware info of a Computer Collection including BIOS version and Computer model.
.NOTES
    Created by
        Ioan Popovici   2018-01-18
    Release notes
        https://github.com/Ioan-Popovici/SCCMZone/blob/master/Reporting/Hardware/HW%20BIOS%20by%20Company%20or%20Manufacturer/CHANGELOG.md
    This query is part of a report should not be run separately.
.LINK
    https://SCCM-Zone.com
.LINK
    https://github.com/Ioan-Popovici/SCCMZone
*/

/*##=============================================*/
/*## QUERY BODY                                  */
/*##=============================================*/

/* Testing variables !! Need to be commented for Production !! */
--DECLARE @UserSIDs               AS VARCHAR(16) = 'Disabled';
--DECLARE @CollectionID           AS VARCHAR(16) = 'A01000B3';
--DECLARE @ExcludeVirtualMachines AS VARCHAR(3)  = 'YES';

SELECT DISTINCT
    Manufacturer = System.Manufacturer0
    , Model =
        CASE
            WHEN System.Model0 LIKE '10AA%' THEN 'ThinkCentre M93p'
            WHEN System.Model0 LIKE '10AB%' THEN 'ThinkCentre M93p'
            WHEN System.Model0 LIKE '10AE%' THEN 'ThinkCentre M93z'
            WHEN System.Model0 LIKE '10FLS1TJ%' THEN 'ThinkCentre M900'
            WHEN Product.Version0 = 'Lenovo Product' THEN ('Unknown ' + System.Model0)
            WHEN System.Manufacturer0 = 'LENOVO' THEN Product.Version0
            ELSE System.Model0
        END,
    DeviceName          = System.Name0
    , UserName          = CONCAT(Computers.User_Domain0 + '\', Computers.User_Name0) -- Add user domain to UserName
    , BIOSName          = BIOS.Name0
    , BIOSVersion       = BIOS.Version0
    , SMBIOSVersion     = BIOS.SMBIOSBIOSVersion0
    , BIOSSerialNumber  = BIOS.SerialNumber0
    , OperatingSystem   =
        CONCAT(
            REPLACE(OperatingSystem.Caption0, 'Microsoft ', ''),         -- Remove 'Microsoft ' from OperatingSystem
            REPLACE(OperatingSystem.CSDVersion0, 'Service Pack ', ' SP') -- Replace 'Service Pack ' with ' SP' in OperatingSystem
        )
	, OSVersion         = OSLocalizedNames.Value
    , OSBuildNumber     = OperatingSystem.Version0
    , OSInstallDate     = OperatingSystem.InstallDate0
FROM fn_rbac_R_System(@UserSIDs) AS Computers
    JOIN fn_rbac_GS_OPERATING_SYSTEM(@UserSIDs) AS OperatingSystem ON OperatingSystem.ResourceID = Computers.ResourceID
    JOIN fn_rbac_GS_COMPUTER_SYSTEM(@UserSIDs) AS System ON System.ResourceID = Computers.ResourceID
    LEFT JOIN fn_GetWindowsServicingStates() AS OSServicingStates ON OSServicingStates.Build = OperatingSystem.Version0
        AND Computers.OSBranch01 = OSServicingStates.Branch -- Select only the branch of the installed OS
    LEFT JOIN fn_GetWindowsServicingLocalizedNames() AS OSLocalizedNames ON OSLocalizedNames.Name = OSServicingStates.Name
    JOIN fn_rbac_ClientCollectionMembers(@UserSIDs) AS Collections ON Collections.ResourceID = Computers.ResourceID
    JOIN fn_rbac_GS_PC_BIOS(@UserSIDs) AS BIOS ON BIOS.ResourceID = Computers.ResourceID
    JOIN fn_rbac_GS_COMPUTER_SYSTEM_PRODUCT(@UserSIDs) AS Product ON Product.ResourceID = Computers.ResourceID
WHERE Collections.CollectionID = @CollectionID
    AND System.Model0 NOT LIKE (
            CASE @ExcludeVirtualMachines
                WHEN 'YES' THEN '%Virtual%'
                ELSE ''
            END
        )
ORDER BY
    Model,
    BIOSName,
    BIOSVersion

/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/
