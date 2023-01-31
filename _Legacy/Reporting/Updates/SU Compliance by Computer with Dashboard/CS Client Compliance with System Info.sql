/*
.SYNOPSIS
    Gets combined system data.
.DESCRIPTION
    Gets combined system data for the PowerBI Dashboard.
.NOTES
    Created by Ioan Popovici
*/

/*##=============================================*/
/*## QUERY BODY                                  */
/*##=============================================*/

/* Testing variables !! Need to be commented for Production !! */
DECLARE @UserSIDs       NVARCHAR (16)  = 'Disabled';
DECLARE @CollectionName NVARCHAR (250) = 'SCCM Managed Systems -';

/* Get report data */
SELECT
    DeviceName        = Systems.Netbios_Name0
    , Manufacturer    = ComputerSystem.Manufacturer0
    , Model           = (

        /* Workaround for lenovo models */
        CASE
            WHEN ComputerSystem.Model0 LIKE '10AA%'          THEN 'ThinkCentre M93p'
            WHEN ComputerSystem.Model0 LIKE '10AB%'          THEN 'ThinkCentre M93p'
            WHEN ComputerSystem.Model0 LIKE '10AE%'          THEN 'ThinkCentre M93z'
            WHEN ComputerSystem.Model0 LIKE '10FLS1TJ%'      THEN 'ThinkCentre M900'
            WHEN ComputerProduct.Version0 = 'Lenovo Product' THEN ('Unknown ' + ComputerSystem.Model0)
            WHEN ComputerSystem.Manufacturer0 = 'LENOVO'     THEN ComputerProduct.Version0
            ELSE ComputerSystem.Model0
        END
    )
    , CollectionName  = CollectionList.Name
    , OperatingSystem = (

        /* Clean OS name and fix inconsistencies*/
        CASE
            WHEN OperatingSystem.Caption0 != '' THEN (
                CASE
                    WHEN CombinedResources.DeviceOS LIKE 'Microsoft Windows NT Workstation 10.0%'             THEN 'Windows 10 Enterprise'
                    WHEN OperatingSystem.Caption0 LIKE '%Windows_7 _dition_Int_grale'                         THEN 'Windows 7 Standard'
                    WHEN OperatingSystem.Caption0 LIKE '%Windows_7 Entreprise'                                THEN 'Windows 7 Enterprise'
                    WHEN OperatingSystem.Caption0 = 'Windows 7 Professionnel'                                 THEN 'Windows 7 Professional'
                    WHEN OperatingSystem.Caption0 = 'Windows 10 Professionnel'                                THEN 'Windows 10 Pro'
                    WHEN OperatingSystem.Caption0 = 'Microsoft(R) Windows(R) Server 2003, Enterprise Edition' THEN 'Windows Server 2003 Enterprise Edition'
                    WHEN OperatingSystem.Caption0 LIKE 'Microsoft_ Windows Server_ 2008 Datacenter'           THEN 'Windows Server 2008 Datacenter'
                    WHEN OperatingSystem.Caption0 LIKE 'Microsoft_ Windows_ Storage Server 2008 Standard'     THEN 'Windows Storage Server 2008 Standard'
                    WHEN OperatingSystem.Caption0 LIKE 'Microsoft_ Windows_ Storage Server 2008 Enterprise'   THEN 'Windows Storage Server 2008 Enterprise'
                    WHEN OperatingSystem.Caption0 LIKE 'Microsoft_ Windows Server_ 2008 Standard'             THEN 'Windows Server 2008 Standard'
                    WHEN OperatingSystem.Caption0 LIKE 'Microsoft_ Windows Server_ 2008 Enterprise'           THEN 'Windows Server 2008 Enterprise'
                    ELSE REPLACE(OperatingSystem.Caption0, 'Microsoft ', '') --Remove 'Microsoft ' from OperatingSystem
                END
            )
            ELSE (

                /* Workaround for systems not in GS_OPERATING_SYSTEM table */
                CASE
                    WHEN CombinedResources.DeviceOS LIKE 'Data Domain OS%'                        THEN 'DELL EMC'
                    WHEN CombinedResources.DeviceOS LIKE 'unknown%'                               THEN 'Unknown'
                    WHEN CombinedResources.DeviceOS LIKE 'Microsoft Windows NT Workstation 5.1%'  THEN 'Windows XP Pro'
                    WHEN CombinedResources.DeviceOS LIKE 'Microsoft Windows NT Workstation 6.1%'  THEN 'Windows 7 Enterprise'
                    WHEN CombinedResources.DeviceOS LIKE 'Windows Workstation 6.1%'               THEN 'Windows 7 Enterprise'
                    WHEN CombinedResources.DeviceOS LIKE 'Windows_7 Entreprise 6.1'               THEN 'Windows 7 Enterprise'
                    WHEN CombinedResources.DeviceOS LIKE 'Microsoft Windows NT Workstation 6.2%'  THEN 'Windows 8 Enterprise'
                    WHEN CombinedResources.DeviceOS LIKE 'Microsoft Windows NT Workstation 6.3%'  THEN 'Windows 8.1 Enterprise'
                    WHEN CombinedResources.DeviceOS LIKE 'Microsoft Windows NT Workstation 10.0%' THEN 'Windows 10 Enterprise'
                    WHEN CombinedResources.DeviceOS = 'Microsoft Windows NT Server 5.2'			  THEN 'Windows Server 2003 R2 Standard Edition'
                    WHEN CombinedResources.DeviceOS = 'Microsoft Windows NT Advanced Server 5.2'  THEN 'Windows Server 2003 R2 Enterprise Edition'
                    WHEN CombinedResources.DeviceOS = 'Microsoft Windows NT Advanced Server 6.0'  THEN 'Windows Server 2008 Enterprise'
                    WHEN CombinedResources.DeviceOS = 'Microsoft Windows NT Server 6.0'			  THEN 'Windows Server 2008 Standard'
                    WHEN CombinedResources.DeviceOS = 'Microsoft Windows NT Advanced Server 6.0'  THEN 'Windows Server 2008 Enterprise'
                    WHEN CombinedResources.DeviceOS = 'Microsoft Windows NT Server 6.1'			  THEN 'Windows Server 2008 R2 Standard'
                    WHEN CombinedResources.DeviceOS = 'Microsoft Windows NT Advanced Server 6.1'  THEN 'Windows Server 2008 R2 Enterprise'
                    WHEN CombinedResources.DeviceOS = 'Microsoft Windows NT Server 6.2'			  THEN 'Windows Server 2012 Standard'
                    WHEN CombinedResources.DeviceOS = 'Microsoft Windows NT Advanced Server 6.2'  THEN 'Windows Server 2012 Datacenter'
                    WHEN CombinedResources.DeviceOS = 'Microsoft Windows NT Server 6.3'			  THEN 'Windows Server 2012 R2 Standard'
                    WHEN CombinedResources.DeviceOS = 'Microsoft Windows NT Advanced Server 6.3'  THEN 'Windows Server 2012 R2 Datacenter'
                    WHEN CombinedResources.DeviceOS = 'Microsoft Windows NT Server 10.0'          THEN 'Windows Server 2016 Standard'
                    WHEN CombinedResources.DeviceOS = 'Microsoft Windows NT Advanced Server 10.0' THEN 'Windows Server 2016 Datacenter'
                    ELSE 'Unknown'
                END
            )
        END
    )
    , ServicePack     = REPLACE(OperatingSystem.CSDVersion0, 'Service Pack ', ' SP') --Replace 'Service Pack ' with ' SP' in OperatingSystem
    , OSVersion       = (
        SELECT OSLocalizedNames.Value
        FROM fn_GetWindowsServicingLocalizedNames() AS OSLocalizedNames
        INNER JOIN fn_GetWindowsServicingStates() AS OSServicingStates ON OSServicingStates.Build = Systems.Build01
        WHERE OSLocalizedNames.Name = OSServicingStates.Name
            AND Systems.OSBranch01 = OSServicingStates.branch --Select only the branch of the installed OS
    )
    , BuildNumber     = Systems.Build01
    , SymantecClient  = (
        CASE
            WHEN Software.DisplayName0 = 'Symantec Endpoint Protection' THEN 'Yes'
            ELSE (
                CASE CombinedResources.IsClient
                    WHEN 1 THEN 'No'
                    ELSE 'Unknown'
                End
            )
        END
    )
    , SCCMClient = (
        CASE CombinedResources.IsClient
            WHEN 1 THEN 'Yes'
            ELSE 'No'
        END
    )
    , SystemOUName    = MAX(SystemOU.System_OU_Name0)
FROM fn_rbac_FullCollectionMembership(@UserSIDs) AS CollectionMembers
    LEFT JOIN fn_rbac_Collection(@UserSIDs) AS CollectionList ON CollectionList.CollectionID = CollectionMembers.CollectionID
    LEFT JOIN fn_rbac_R_System(@UserSIDs) AS Systems ON Systems.ResourceID = CollectionMembers.ResourceID
    LEFT JOIN fn_rbac_GS_COMPUTER_SYSTEM(@UserSIDs) AS ComputerSystem ON ComputerSystem.ResourceID = CollectionMembers.ResourceID
    LEFT JOIN fn_rbac_GS_OPERATING_SYSTEM(@UserSIDs) OperatingSystem ON OperatingSystem.ResourceID = CollectionMembers.ResourceID
    LEFT JOIN fn_rbac_CombinedDeviceResources(@UserSIDs) AS CombinedResources ON CombinedResources.MachineID = CollectionMembers.ResourceID
    LEFT JOIN fn_rbac_GS_COMPUTER_SYSTEM_PRODUCT(@UserSIDs) AS ComputerProduct ON ComputerProduct.ResourceID = CollectionMembers.ResourceID
    LEFT JOIN fn_rbac_Add_Remove_Programs(@UserSIDs) AS Software ON Software.ResourceID = CollectionMembers.ResourceID
        AND Software.DisplayName0 = 'Symantec Endpoint Protection'
    LEFT JOIN fn_rbac_RA_System_SystemOUName(@UserSIDs) AS SystemOU ON SystemOU.ResourceID = CollectionMembers.ResourceID
WHERE CollectionList.Name LIKE @CollectionName + '%'
    AND Systems.Netbios_Name0 != '' --Remove sccm 'Unknown Computer' objects (not real devices)
GROUP BY
    CollectionList.Name
    , Systems.Netbios_Name0
    , ComputerSystem.Manufacturer0
    , ComputerSystem.Model0
    , Systems.Build01
    , Systems.OSBranch01
    , CombinedResources.DeviceOS
    , ComputerProduct.Version0
    , OperatingSystem.Caption0
    , OperatingSystem.Version0
    , OperatingSystem.CSDVersion0
    , Software.DisplayName0
    , CombinedResources.IsClient

/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/