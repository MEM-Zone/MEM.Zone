/*
.SYNOPSIS
    Gets the software update compliance in SCCM.
.DESCRIPTION
    Gets the software update compliance in SCCM by computer, classification and severity.
.NOTES
    Created by
        Ioan Popovici   2018-10-11
    Release notes
        https://github.com/Ioan-Popovici/SCCMZone/blob/master/Reporting/Updates/SU%20Compliance%20by%20Computer%20Classification%20and%20Severity/CHANGELOG.md
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
--DECLARE @UserSIDs       AS NVARCHAR(10) = 'Disabled';
--DECLARE @CollectionID   AS NVARCHAR(10) = 'A010000A';
--DECLARE @Locale         AS INT  = '2';
--DECLARE @ShowInstalled  AS INT  = '0';
--DECLARE @ExcludeUpdates AS NVARCHAR(250) = '915597,2267602,2461484' --AV Definitions

/* Variable declaration */
DECLARE @LCID AS INT = dbo.fn_LShortNameToLCID (@Locale)

/* Initialize ClientState descriptor table */
DECLARE @ClientState TABLE
(
    BitMask int
    , StateName NVARCHAR(250)
)

/* Populate ClientState table */
INSERT INTO @ClientState
    (BitMask, StateName)
VALUES
    ('0', 'No Reboot'),
    ('1', 'Configuration Manager'),
    ('2', 'File Rename'),
    ('4', 'Windows Update'),
    ('8', 'Add or Remove Feature')

/* Initialize SystemsInfo table */
DECLARE @SystemsInfo TABLE
(
    ResourceID          INT
    , ComputerName      NVARCHAR(250)
    , UserName          NVARCHAR(250)
    , OperatingSystem   NVARCHAR(250)
    , OSBuild           NVARCHAR(250)
    , OSVersion         NVARCHAR(250)
    , Domain            NVARCHAR(250)
    , IPAddresses       NVARCHAR(250)
    , LastBootTime      NVARCHAR(250)
    , PendingRestart    NVARCHAR(250)
    , Managed           NVARCHAR(5)
    , ClientState       NVARCHAR(20)
    , ClientVersion     NVARCHAR(250)
    , LastUpdateScan    NVARCHAR(250)
)

/* Initialize UpdateInfo table */
DECLARE @UpdateInfo TABLE
(
    ResourceID          INT
    , ComplianceStatus  NVARCHAR(250)
    , Classification    NVARCHAR(250)
    , Severity          NVARCHAR(250)
    , ArticleID         NVARCHAR(250)
    , BulletinID        NVARCHAR(250)
    , DisplayName       NVARCHAR(250)
    , DateRevised       NVARCHAR(250)
    , IsDeployed        NVARCHAR(5)
    , IsEnabled         NVARCHAR(5)
)

/* Get systems data */
INSERT INTO @SystemsInfo (ResourceID, ComputerName, UserName, OperatingSystem, OSBuild, OSVersion, Domain, IPAddresses, LastBootTime, PendingRestart, Managed, ClientState, ClientVersion, LastUpdateScan)
SELECT
    ResourceID          = Computers.ResourceID
    , ComputerName      = Computers.Netbios_Name0
    , UserName          = CONCAT(Computers.User_Domain0 + '\', Computers.User_Name0)   --Add user domain to UserName
    , OperatingSystem   =
        CASE
            WHEN OperatingSystem.Caption0 <> '' THEN
                CONCAT(
                    REPLACE(OperatingSystem.Caption0, 'Microsoft ', ''),               --Remove 'Microsoft ' from OperatingSystem
                    REPLACE(OperatingSystem.CSDVersion0, 'Service Pack ', ' SP')       --Replace 'Service Pack ' with ' SP' in OperatingSystem
                )
            ELSE
            /* Workaround for systems not in GS_OPERATING_SYSTEM table */
            (
                CASE
                    WHEN CombinedResources.DeviceOS LIKE '%Workstation 6.1%'    THEN 'Windows 7'
                    WHEN CombinedResources.DeviceOS LIKE '%Workstation 6.2%'    THEN 'Windows 8'
                    WHEN CombinedResources.DeviceOS LIKE '%Workstation 6.3%'    THEN 'Windows 8.1'
                    WHEN CombinedResources.DeviceOS LIKE '%Workstation 10.0%'   THEN 'Windows 10'
                    WHEN CombinedResources.DeviceOS LIKE '%Server 6.0'          THEN 'Windows Server 2008'
                    WHEN CombinedResources.DeviceOS LIKE '%Server 6.1'          THEN 'Windows Server 2008R2'
                    WHEN CombinedResources.DeviceOS LIKE '%Server 6.2'          THEN 'Windows Server 2012'
                    WHEN CombinedResources.DeviceOS LIKE '%Server 6.3'          THEN 'Windows Server 2012 R2'
                    WHEN CombinedResources.DeviceOS LIKE '%Server 10.0'         THEN 'Windows Server 2016'
                    ELSE 'Unknown'
                END
            )
        END
    , OSBuild           = Computers.Build01
    , OSVersion         =
        (
            SELECT OSLocalizedNames.Value
            FROM fn_GetWindowsServicingLocalizedNames() AS OSLocalizedNames
                JOIN fn_GetWindowsServicingStates() AS OSServicingStates ON OSServicingStates.Build = Computers.Build01
            WHERE OSLocalizedNames.Name = OSServicingStates.Name
                AND Computers.OSBranch01 = OSServicingStates.Branch --Select only the branch of the installed OS
        )
    , Domain            = Computers.Full_Domain_Name0
    , IPAddresses       =
        REPLACE(
            (
                SELECT LTRIM(RTRIM(IP.IP_Addresses0)) AS [data()]
                FROM fn_rbac_RA_System_IPAddresses(@UserSIDs) AS IP
                WHERE IP.ResourceID = Computers.ResourceID
                    AND IP.IP_Addresses0 NOT LIKE 'fe%'
                -- Exclude IPv6
                FOR XML PATH('')
            ),
            ' ',', ' -- Replace space with ', '
        )
    , LastBootTime      = OperatingSystem.LastBootUpTime0
    , PendingRestart    =
        CASE
            WHEN CombinedResources.ClientState = 0 THEN 'No'
            ELSE(
                STUFF(
                    REPLACE(
                        (
                            SELECT '#!' + LTRIM(RTRIM(StateName)) AS [data()]
                            FROM @ClientState
                            WHERE BitMask & CombinedResources.ClientState <> 0
                            FOR XML PATH('')
                        ),
                        ' #!',', '
                    ),
                    1, 2, ''
                )
            )
        END
    , Managed           =
        CASE Computers.Client0
            WHEN 1 THEN 'Yes'
            ELSE 'No'
        END
    , ClientState       = ClientSummary.ClientStateDescription
    , ClientVersion     = Computers.Client_Version0
    , LastUpdateScan    = UpdateScan.LastScanTime
FROM fn_rbac_FullCollectionMembership(@UserSIDs) AS CollectionMembers
    LEFT JOIN fn_rbac_R_System(@UserSIDs) AS Computers ON Computers.ResourceID = CollectionMembers.ResourceID
    LEFT JOIN fn_rbac_GS_OPERATING_SYSTEM(@UserSIDs) OperatingSystem ON OperatingSystem.ResourceID = CollectionMembers.ResourceID
    LEFT JOIN fn_rbac_CombinedDeviceResources(@UserSIDs) AS CombinedResources ON CombinedResources.MachineID = CollectionMembers.ResourceID
    LEFT JOIN fn_rbac_CH_ClientSummary(@UserSIDs) AS ClientSummary ON ClientSummary.ResourceID = CollectionMembers.ResourceID
    LEFT JOIN fn_rbac_UpdateScanStatus(@UserSIDs) AS UpdateScan ON UpdateScan.ResourceID = CollectionMembers.ResourceID
WHERE CollectionMembers.CollectionID = @CollectionID

/* Get update data */
INSERT INTO @UpdateInfo (ResourceID, ComplianceStatus, Classification, Severity, ArticleID, BulletinID, DisplayName, DateRevised, IsDeployed, IsEnabled)
SELECT
    CollectionMembers.ResourceID
    , ComplianceStatus   =
        CASE ComplianceStatus.Status
            WHEN 0 THEN 'Unknown'
            WHEN 1 THEN 'Not Required'
            WHEN 2 THEN 'Required'
            WHEN 3 THEN 'Installed'
        END
    , Classification    = Category.CategoryInstanceName
    , Severity          = ISNULL(NULLIF(UpdateCIs.SeverityName, ''), 'Unknown')
    , ArticleID         = UpdateCIs.ArticleID
    , BulletinID        = NULLIF(UpdateCIs.BulletinID, '')
    , DisplayName       = UpdateCIs.DisplayName
    , DateRevised       = UpdateCIs.DateRevised
    , IsDeployed        =
        CASE UpdateCIs.IsDeployed
            WHEN 0 THEN 'No'
            WHEN 1 THEN 'Yes'
        END
    , IsEnabled         =
        CASE UpdateCIs.IsEnabled
            WHEN 0 THEN 'No'
            WHEN 1 THEN 'Yes'
        END
FROM fn_rbac_ClientCollectionMembers(@UserSIDs) AS CollectionMembers
    INNER JOIN fn_rbac_Update_ComplianceStatus(@UserSIDs) AS ComplianceStatus ON CollectionMembers.ResourceID = ComplianceStatus.ResourceID
        AND ComplianceStatus.Status IN (0, 2, @ShowInstalled)   --0 Unknown, 2 Required, 3 Installed
    INNER JOIN fn_ListUpdateCIs(@LCID) AS UpdateCIs ON ComplianceStatus.CI_ID = UpdateCIs.CI_ID
        AND UpdateCIs.CIType_ID IN (1, 8)                       --1 Software Updates, 8 Software Update Bundle (v_CITypes)
        AND UpdateCIs.IsExpired = 0                             --Update is not Expired
        AND UpdateCIs.IsSuperseded = 0                          --Update is not Superseeded
        AND UpdateCIs.ArticleID NOT IN                          --Exclude updates based on ArticleID
			(
				SELECT * FROM dbo.ufn_csv_String_Parser(@ExcludeUpdates, ',')
			)
    LEFT JOIN fn_rbac_CICategories_All(@UserSIDs) AS CICategories ON UpdateCIs.CI_ID = CICategories.CI_ID
    RIGHT JOIN fn_rbac_ListUpdateCategoryInstances(@LCID, @UserSIDs) AS Category ON CICategories.CategoryInstanceID = Category.CategoryInstanceID
        AND Category.CategoryTypeName = 'UpdateClassification' --Get only the 'UpdateClasification' category
WHERE CollectionMembers.CollectionID = @CollectionID

/* Join SystemsInfo and UpdateInfo data */
SELECT
    Managed
    , ComputerName
    , UserName
    , OperatingSystem
    , OSBuild
    , OSVersion
    , Domain
    , IPAddresses
    , LastBootTime
    , PendingRestart
    , ClientState
    , ClientVersion
    , LastUpdateScan
    , ComplianceStatus =
    /* Set Compliance based on Compliance Status Activity and LastUpdateScan */
        (
            CASE
                WHEN ComplianceStatus IS NOT NULL THEN ComplianceStatus
                WHEN ComplianceStatus IS NULL
                    AND LastUpdateScan > = (SELECT DATEADD(dd, -7, CURRENT_TIMESTAMP)) --Scanned for updates in the last 7 days
                    AND ClientState LIKE 'Active%' THEN 'Compliant'
                ELSE 'Unknown'
            END
        )
    , Classification
    , Severity
    , ArticleID
    , BulletinID
    , DisplayName
    , DateRevised
    , IsDeployed
    , IsEnabled
FROM @SystemsInfo AS SystemsInfo
    LEFT JOIN @UpdateInfo AS UpdateInfo ON UpdateInfo.ResourceID = SystemsInfo.ResourceID
ORDER BY
    Managed
    , ComputerName
    , OperatingSystem
    , OSBuild
    , OSVersion
    , Domain
    , IPAddresses
    , LastBootTime
    , PendingRestart
    , ClientState
    , ClientVersion
    , LastUpdateScan
    , ComplianceStatus
    , Classification
    , Severity
    , ArticleID
    , BulletinID
    , DisplayName
    , DateRevised
    , IsDeployed
    , IsEnabled

/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/