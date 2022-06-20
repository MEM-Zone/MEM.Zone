/*
.SYNOPSIS
    Gets the feature update compliance for a Collection in MEMCM.
.DESCRIPTION
    Gets the feature update compliance in MEMCM by Collection and specified operating system version.
.NOTES
    Requires SQL 2016.
    Part of a report should not be run separately.
.LINK
    https://MEM.Zone/Dashboards
.LINK
    https://MEM.Zone/Dashboards-HELP
.LINK
    https://MEM.Zone/Dashboards-ISSUES
*/

/*##=============================================*/
/*## QUERY BODY                                  */
/*##=============================================*/
/* #region QueryBody */

/* Testing variables !! Need to be commented for Production !! */
DECLARE @UserSIDs            AS NVARCHAR(10) = 'Disabled';
DECLARE @CollectionID        AS NVARCHAR(10) = 'AP200017';
DECLARE @Locale              AS INT          = 2;

/* Variable declaration */
DECLARE @LCID                       AS INT = dbo.fn_LShortNameToLCID(@Locale);
DECLARE @LastSupportedLegacyOSBuild AS INT = 9600;

/* Get device info */
;
WITH DeviceInfo_CTE
AS (
    SELECT Systems.ResourceID
        , Device                = (
                IIF(
                    SystemNames.Resource_Names0 IS NOT NULL, UPPER(SystemNames.Resource_Names0)
                    , IIF(Systems.Full_Domain_Name0 IS NOT NULL, Systems.Name0 + N'.' + Systems.Full_Domain_Name0, Systems.Name0)
                )
        )
        , OperatingSystem       = (
            CASE
                WHEN OperatingSystem.Caption0 != N'' THEN
                    CONCAT(
                        REPLACE(OperatingSystem.Caption0, N'Microsoft ', N''),         --Remove 'Microsoft ' from OperatingSystem
                        REPLACE(OperatingSystem.CSDVersion0, N'Service Pack ', N' SP') --Replace 'Service Pack ' with ' SP' in OperatingSystem
                    )
                ELSE (

                /* Workaround for systems not in GS_OPERATING_SYSTEM table */
                    CASE
                        WHEN CombinedResources.DeviceOS LIKE N'%Workstation 6.1%'   THEN N'Windows 7'
                        WHEN CombinedResources.DeviceOS LIKE N'%Workstation 6.2%'   THEN N'Windows 8'
                        WHEN CombinedResources.DeviceOS LIKE N'%Workstation 6.3%'   THEN N'Windows 8.1'
                        WHEN CombinedResources.DeviceOS LIKE N'%Workstation 10.0%'  THEN N'Windows 10'
                        WHEN CombinedResources.DeviceOS LIKE N'%Server 6.0'         THEN N'Windows Server 2008'
                        WHEN CombinedResources.DeviceOS LIKE N'%Server 6.1'         THEN N'Windows Server 2008R2'
                        WHEN CombinedResources.DeviceOS LIKE N'%Server 6.2'         THEN N'Windows Server 2012'
                        WHEN CombinedResources.DeviceOS LIKE N'%Server 6.3'         THEN N'Windows Server 2012 R2'
                        WHEN Systems.Operating_System_Name_And0 LIKE N'%Server 10%' THEN (
                            CASE
                                WHEN CAST(REPLACE(Build01, N'.', N'') AS INTEGER) > 10017763 THEN N'Windows Server 2019'
                                ELSE N'Windows Server 2016'
                            END
                        )
                        ELSE Systems.Operating_System_Name_And0
                    END
                )
            END
        )
        , OSVersion             = OSInfo.Version
        , OSBuildNumber         = Systems.Build01
        , OSServicingState      = (
            IIF(OSInfo.ServicingState IS NULL,
                CASE
                    WHEN Systems.Build01       = '6.3.9600'
                        AND CURRENT_TIMESTAMP <= CONVERT(DATETIME, '2023-01-10') THEN 'Expiring Soon'
                    WHEN Systems.Build01       = '6.3.9600'
                        AND CURRENT_TIMESTAMP >  CONVERT(DATETIME, '2023-01-10') THEN 'Expired'
                    ELSE
                        IIF(
                            CONVERT(
                                INT
                                , (SELECT SUBSTRING(
                                        (SELECT CAST('<t>' + REPLACE(Systems.Build01, '.','</t><t>') + '</t>' AS XML).value('/t[3]','NVARCHAR(500)'))
                                        , 0, 6 --Last 6 characters
                                    )
                                )
                            ) < @LastSupportedLegacyOSBuild
                            , 'Expired', 'Unknown'
                        )
                END
            , CASE
                WHEN OSInfo.ServicingState = 0 THEN 'Internal'
                WHEN OSInfo.ServicingState = 1 THEN 'Insider'
                WHEN OSInfo.ServicingState = 2 THEN 'Current'
                WHEN OSInfo.ServicingState = 3 THEN 'Expiring Soon'
                WHEN OSInfo.ServicingState = 4 THEN 'Expired'
                WHEN OSInfo.ServicingState = 5 THEN 'Unknown'
              END
          )
        ) --0 = 'Internal', 1 = 'Insider', 2 = 'Current', 3 = 'Expiring Soon', 4 = 'Expired', 5 = 'Unknown'
        , Domain                = Systems.Resource_Domain_OR_Workgr0
        , IPAddresses           = REPLACE(IPAddresses.Value, N' ', N';')
        , Country               = Users.co
        , Location              = Users.l
        , UserName              = Users.Unique_User_Name0
        , UserFullName          = Users.Full_User_Name0
        , UserEmail             = Users.Mail0
        , Region                = Systems.Resource_Domain_OR_Workgr0
        , DeviceModel           = ComputerSystem.Model0
        , ClientState           = IIF(CombinedResources.IsClient = 1, ClientSummary.ClientStateDescription, 'Unmanaged')
        , ClientVersion         = CombinedResources.ClientVersion
    FROM fn_rbac_R_System(@UserSIDs) AS Systems
        JOIN fn_rbac_CombinedDeviceResources(@UserSIDs) AS CombinedResources ON CombinedResources.MachineID = Systems.ResourceID
        JOIN fn_rbac_FullCollectionMembership(@UserSIDs) AS CollectionMembers ON CollectionMembers.ResourceID = CombinedResources.MachineID
        LEFT JOIN fn_rbac_RA_System_ResourceNames(@UserSIDs) AS SystemNames ON SystemNames.ResourceID = CollectionMembers.ResourceID
        LEFT JOIN fn_rbac_GS_OPERATING_SYSTEM(@UserSIDs) AS OperatingSystem ON OperatingSystem.ResourceID = CollectionMembers.ResourceID
        LEFT JOIN fn_rbac_CH_ClientSummary(@UserSIDs) AS ClientSummary ON ClientSummary.ResourceID = CollectionMembers.ResourceID
        LEFT JOIN fn_rbac_R_User(@UserSIDs) AS Users ON Users.User_Name0 = Systems.User_Name0
        LEFT JOIN fn_rbac_GS_COMPUTER_SYSTEM(@UserSIDs) AS ComputerSystem ON ComputerSystem.ResourceID = CollectionMembers.ResourceID
        OUTER APPLY (
            SELECT
                Version = OSLocalizedNames.Value
                , ServicingState = OSServicingStates.State
            FROM fn_GetWindowsServicingLocalizedNames() AS OSLocalizedNames
                JOIN fn_GetWindowsServicingStates() AS OSServicingStates ON OSServicingStates.Build = Systems.Build01
            WHERE OSLocalizedNames.Name = OSServicingStates.Name
                AND Systems.OSBranch01 = OSServicingStates.Branch --Select only the branch of the installed OS
        ) AS OSInfo
         OUTER APPLY (
        SELECT Value =  (
            SELECT LTRIM(RTRIM(IP.IP_Addresses0)) AS [data()]
            FROM fn_rbac_RA_System_IPAddresses(@UserSIDs) AS IP
            WHERE IP.ResourceID = Systems.ResourceID
            -- Exclude IPv6 and 169.254.0.0 Class
                AND IIF(CHARINDEX(N':', IP.IP_Addresses0) > 0 OR CHARINDEX(N'169.254', IP.IP_Addresses0) = 1, 1, 0) = 0
            -- Aggregate results to one row
            FOR XML PATH('')
        )
    ) AS IPAddresses
    WHERE CollectionMembers.CollectionID = @CollectionID
)

SELECT
    DeviceInfo.Device
    , DeviceInfo.ClientState
    , DeviceInfo.ClientVersion
    , DeviceInfo.OperatingSystem
    , DeviceInfo.OSVersion
    , DeviceInfo.OSBuildNumber
    , DeviceInfo.OSServicingState
    , DeviceInfo.IPAddresses
    , DeviceInfo.UserName
    , DeviceInfo.UserFullName
    , DeviceInfo.UserEmail
    , DeviceInfo.DeviceModel
    , DeviceInfo.Country
    , DeviceInfo.Location
    , DeviceInfo.Region
FROM DeviceInfo_CTE AS DeviceInfo
ORDER BY
    Region
    , ClientState
    , ClientVersion
    , OperatingSystem
    , OSVersion
    , OSServicingState

/* #endregion */
/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/