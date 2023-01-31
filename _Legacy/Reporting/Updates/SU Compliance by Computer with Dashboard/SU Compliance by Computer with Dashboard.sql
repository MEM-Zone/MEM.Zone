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
DECLARE @UserSIDs        AS NVARCHAR(10)  = 'Disabled';
DECLARE @CollectionID    AS NVARCHAR(10)  = 'A01000B3';
DECLARE @Locale          AS INT           = 2;
DECLARE @ReleasedBefore  AS DATE          = GETDATE();
DECLARE @ReleasedAfter   AS DATE          = DATEADD(YEAR, -10,GETDATE());
DECLARE @ExcludeUpdates  AS NVARCHAR(250) = '915597,2267602,2461484'; --AV Definitions
DECLARE @HideInstalled   AS NVARCHAR(10)  = 'Yes';
DECLARE @HideNotDeployed AS NVARCHAR(10)  = 'No';


/* Remove previous global temporary table if exists */
IF OBJECT_ID(N'TempDB.DBO.##CombinedInfo') IS NOT NULL
    BEGIN
        DROP TABLE ##CombinedInfo;
    END;

/* Variable declaration */
DECLARE @LCID AS INT = dbo.fn_LShortNameToLCID (@Locale);

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
    , DeviceName        NVARCHAR(50)
    , UserName          NVARCHAR(100)
    , OperatingSystem   NVARCHAR(100)
    , OSBuild           NVARCHAR(20)
    , OSVersion         NVARCHAR(20)
    , Domain            NVARCHAR(100)
    , IPAddresses       NVARCHAR(250)
    , LastBootTime      NVARCHAR(50)
    , PendingRestart    NVARCHAR(250)
    , Managed           NVARCHAR(5)
    , ClientState       NVARCHAR(20)
    , ClientVersion     NVARCHAR(20)
    , LastUpdateScan    NVARCHAR(50)
)

/* Initialize UpdateInfo table */
DECLARE @UpdateInfo TABLE
(
    ResourceID          INT
    , ComplianceStatus  NVARCHAR(50)
    , Classification    NVARCHAR(50)
    , Severity          NVARCHAR(50)
    , ArticleID         NVARCHAR(50)
    , BulletinID        NVARCHAR(50)
    , DisplayName       NVARCHAR(250)
    , DateRevised       NVARCHAR(50)
    , IsDeployed        NVARCHAR(5)
    , IsEnabled         NVARCHAR(5)
)

/* Get systems data */
INSERT INTO @SystemsInfo (ResourceID, DeviceName, UserName, OperatingSystem, OSBuild, OSVersion, Domain, IPAddresses, LastBootTime, PendingRestart, Managed, ClientState, ClientVersion, LastUpdateScan)
SELECT
    ResourceID          = Computers.ResourceID
    , DeviceName        = Computers.Netbios_Name0
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
                    WHEN CombinedResources.DeviceOS LIKE '%Workstation 6.1%'  THEN 'Windows 7'
                    WHEN CombinedResources.DeviceOS LIKE '%Workstation 6.2%'  THEN 'Windows 8'
                    WHEN CombinedResources.DeviceOS LIKE '%Workstation 6.3%'  THEN 'Windows 8.1'
                    WHEN CombinedResources.DeviceOS LIKE '%Workstation 10.0%' THEN 'Windows 10'
                    WHEN CombinedResources.DeviceOS LIKE '%Server 6.0'        THEN 'Windows Server 2008'
                    WHEN CombinedResources.DeviceOS LIKE '%Server 6.1'        THEN 'Windows Server 2008R2'
                    WHEN CombinedResources.DeviceOS LIKE '%Server 6.2'        THEN 'Windows Server 2012'
                    WHEN CombinedResources.DeviceOS LIKE '%Server 6.3'        THEN 'Windows Server 2012 R2'
                    WHEN CombinedResources.DeviceOS LIKE '%Server 10.0'       THEN 'Windows Server 2016'
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
        AND ComplianceStatus.Status IN (0, 2, 3) --0 Unknown, 2 Required, 3 Installed
    INNER JOIN fn_ListUpdateCIs(@LCID) AS UpdateCIs ON ComplianceStatus.CI_ID = UpdateCIs.CI_ID
        AND UpdateCIs.CIType_ID IN (1, 8)        --1 Software Updates, 8 Software Update Bundle (v_CITypes)
        AND UpdateCIs.IsExpired = 0              --Update is not Expired
        AND UpdateCIs.IsSuperseded = 0           --Update is not Superseeded
        AND UpdateCIs.ArticleID NOT IN           --Exclude updates based on ArticleID
            (
                SELECT * FROM dbo.ufn_csv_String_Parser(@ExcludeUpdates, ',')
            )
    LEFT JOIN fn_rbac_CICategories_All(@UserSIDs) AS CICategories ON UpdateCIs.CI_ID = CICategories.CI_ID
    RIGHT JOIN fn_rbac_ListUpdateCategoryInstances(@LCID, @UserSIDs) AS Category ON CICategories.CategoryInstanceID = Category.CategoryInstanceID
        AND Category.CategoryTypeName = 'UpdateClassification' --Get only the 'UpdateClasification' category
WHERE CollectionMembers.CollectionID = @CollectionID
    AND IsDeployed   = IIF(@HideNotDeployed = 'Yes', 1, 0)
    AND DateRevised >= @ReleasedAfter
    AND DateRevised <= @ReleasedBefore

/* Join SystemsInfo and UpdateInfo data */
SELECT
	ResourceID = SystemsInfo.ResourceID
    , Managed
    , DeviceName
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
    , ComplianceStatus
    , ComplianceState  =

        /* Set Compliance by checking if there are any Required updates, or if the ComplianceStatus is NULL */
        CASE
            WHEN ComplianceStatus IS NULL THEN 'Unknown'
            WHEN SUM(CASE WHEN ComplianceStatus = 'Required' THEN 1 ELSE 0 END) OVER (Partition By DeviceName) = 0  THEN 'Compliant'
            ELSE 'Non-Compliant'
        END
    , Classification
    , Severity
    , ArticleID
    , BulletinID
    , DisplayName
    , DateRevised
    , IsDeployed
    , IsEnabled
INTO ##CombinedInfo
FROM @SystemsInfo AS SystemsInfo
    LEFT JOIN @UpdateInfo AS UpdateInfo ON UpdateInfo.ResourceID = SystemsInfo.ResourceID

/* Remove installed updates if selected */
IF @HideInstalled = 'Yes'
BEGIN
	ALTER TABLE ##CombinedInfo ADD RowID INT Identity(1,1)
	DELETE FROM ##CombinedInfo
	WHERE RowID NOT IN
	(
		SELECT MIN(RowID)
	    FROM ##CombinedInfo
		GROUP BY DeviceName
	) AND ComplianceStatus = 'Installed'
/*    UPDATE ##CombinedInfo
    SET
    ComplianceStatus = NULL
    , Classification = NULL
    , Severity       = NULL
    , ArticleID      = NULL
    , BulletinID     = NULL
    , DisplayName    = NULL
    , DateRevised    = NULL
    , IsDeployed     = NULL
    , IsEnabled      = NULL
    WHERE ComplianceStatus = 'Installed'
*/
END

/* Output result */
SELECT
    Managed
    , DeviceName
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
    , ComplianceStatus
    , ComplianceState
    , Classification
    , Severity
    , ArticleID
    , BulletinID
    , DisplayName
    , DateRevised
    , IsDeployed
    , IsEnabled
FROM ##CombinedInfo
GROUP BY
    Managed
    , DeviceName
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
    , ComplianceStatus
    , ComplianceState
    , Classification
    , Severity
    , ArticleID
    , BulletinID
    , DisplayName
    , DateRevised
    , IsDeployed
    , IsEnabled
ORDER BY
    Managed
    , DeviceName
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
    , ComplianceState
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
