/*
.SYNOPSIS
    Gets the migration status.
.DESCRIPTION
    Gets the migration status by quering the old site.
.NOTES
    Created by Ioan Popovici.
    Requires SQL 2019
    Part of a report should not be run separately.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/ISSUES
*/

/*##=============================================*/
/*## QUERY BODY                                  */
/*##=============================================*/
/* #region QueryBody */

/* Testing variables !! Need to be commented for Production !! */
DECLARE @UserSIDs     AS NVARCHAR(10) = 'Disabled';

/* Initialize ClientState table */
DECLARE @ClientState              TABLE (BitMask INT, StateName NVARCHAR(100));

/* Populate ClientState table */
INSERT INTO @ClientState (BitMask, StateName)
VALUES
    (0, N'No Reboot')
    , (1, N'Configuration Manager')
    , (2, N'File Rename')
    , (4, N'Windows Update')
    , (8, N'Add or Remove Feature')

SELECT DISTINCT
    Migrated         = IIF(NewSiteSystems.Netbios_Name0 IS NOT NULL, 'Yes', 'No')
    , Device         = (
            IIF(
                SystemNames.Resource_Names0 IS NOT NULL, UPPER(SystemNames.Resource_Names0)
                , IIF(Systems.Full_Domain_Name0 IS NOT NULL, Systems.Name0 + N'.' + Systems.Full_Domain_Name0, Systems.Name0)
            )
    )
    , OperatingSystem = (
        CASE
            WHEN OperatingSystem.Caption0 != N'' THEN
                CONCAT(
                    REPLACE(OperatingSystem.Caption0, N'Microsoft ', N''),         -- Remove 'Microsoft ' from OperatingSystem
                    REPLACE(OperatingSystem.CSDVersion0, N'Service Pack ', N' SP') -- Replace 'Service Pack ' with ' SP' in OperatingSystem
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
                            WHEN CAST(REPLACE(Systems.Build01, N'.', N'') AS INTEGER) > 10017763 THEN N'Windows Server 2019'
                            ELSE N'Windows Server 2016'
                        END
                    )
                    ELSE Systems.Operating_System_Name_And0
                END
            )
        END
    )
    , IPAddresses     = REPLACE(IPAddresses.Value, N' ', N',')
    , Uptime          = DATEDIFF(dd, OperatingSystem.LastBootUpTime0, CURRENT_TIMESTAMP)
    , LastBootTime    = CONVERT(NVARCHAR(16), OperatingSystem.LastBootUpTime0, 120)
    , PendingRestart  = (
        CASE
            WHEN CombinedResources.IsClient      = 0
                OR CombinedResources.ClientState = 0
            THEN NULL
            ELSE (
                STUFF(
                    REPLACE(
                        (
                            SELECT N'#!' + LTRIM(RTRIM(StateName)) AS [data()]
                            FROM @ClientState
                            WHERE BitMask & CombinedResources.ClientState <> 0
                            FOR XML PATH(N'')
                        ),
                        N' #!', N', '
                    ),
                    1, 2, N''
                )
            )
        END
    )
    , ClientState     = IIF(CombinedResources.IsClient = 1, ClientSummary.ClientStateDescription, 'Unmanaged')
    , ClientVersion   = CombinedResources.ClientVersion
FROM CM_VIT.dbo.v_R_System AS Systems
    JOIN CM_VIT.dbo.v_CombinedDeviceResources AS CombinedResources ON CombinedResources.MachineID = Systems.ResourceID
    JOIN CM_VIT.dbo.v_FullCollectionMembership AS CollectionMembers ON CollectionMembers.ResourceID = Systems.ResourceID
    LEFT JOIN CM_VIT.dbo.v_RA_System_ResourceNames AS SystemNames ON SystemNames.ResourceID = CollectionMembers.ResourceID
    LEFT JOIN CM_VIT.dbo.v_GS_OPERATING_SYSTEM AS OperatingSystem ON OperatingSystem.ResourceID = CollectionMembers.ResourceID
    LEFT JOIN CM_VIT.dbo.v_CH_ClientSummary AS ClientSummary ON ClientSummary.ResourceID = CollectionMembers.ResourceID
    LEFT JOIN OPENQUERY([VIT-MEM-SQL-001], 'SELECT Netbios_Name0 FROM CM_VID.dbo.v_r_System') AS NewSiteSystems ON NewSiteSystems.Netbios_Name0 = Systems.Netbios_Name0
    OUTER APPLY (
        SELECT Value =  (
            SELECT LTRIM(RTRIM(IP.IP_Addresses0)) AS [data()]
            FROM  CM_VIT.dbo.v_RA_System_IPAddresses AS IP
            WHERE IP.ResourceID = Systems.ResourceID
            -- Exclude IPv6 and 169.254.0.0 Class
                AND IIF(CHARINDEX(N':', IP.IP_Addresses0) > 0 OR CHARINDEX(N'169.254', IP.IP_Addresses0) = 1, 1, 0) = 0
            -- Aggregate results to one row
            FOR XML PATH('')
        )
    ) AS IPAddresses
WHERE Systems.Client0 = 1
    AND CollectionMembers.CollectionID = @CollectionID

/* #endregion */
/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/