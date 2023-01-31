/*
.SYNOPSIS
    Gets the Compliance of a Configuration Baseline.
.DESCRIPTION
    Gets the Compliance and Actual Values of a Configuration Baseline setting result.
.NOTES
    Created by Ioan Popovici
    Requires SSRS/SQL, SCCM Configuration Baseline
.LINK
    BlogPost: https://sccm-zone.com/baseline-reporting-with-actual-values-output-in-sccm-73fec334ba8f
.LINK
    Changes : https://SCCM.Zone/cb-configuration-baseline-compliance-changelog
.LINK
    Github  : https://SCCM.Zone/cb-configuration-baseline-compliance
.LINK
    Issues  : https://SCCM.Zone/issues
*/

/*##=============================================*/
/*## QUERY BODY                                  */
/*##=============================================*/

/* Testing variables !! Need to be commented for Production !! */
--DECLARE @UserSIDs     AS NVARCHAR(250) = 1;
--DECLARE @CollectionID AS NVARCHAR(10)  = 'A01000EC';
--DECLARE @LocaleID     AS INT           = 2;
--DECLARE @BaselineID   AS INT           = 503286;

/* Initialize CIID table */
DECLARE @CIID TABLE
(
    CIID INT
)

/* Initialize SystemsInfo table */
DECLARE @SystemsInfo TABLE
(
    ResourceID         INT
    , DeviceName       NVARCHAR(250)
    , OperatingSystem  NVARCHAR(250)
    , OSVersion        NVARCHAR(250)
    , Managed          NVARCHAR(5)
    , ClientState      NVARCHAR(20)
)

/* Initialize ComplianceInfo table */
DECLARE @ComplianceInfo TABLE
(
    ComplianceState  NVARCHAR(20)
    , ResourceID     INT
    , UserName       NVARCHAR(250)
    , CIVersion      INT
    , SettingVersion INT
    , SettingName    NVARCHAR(250)
    , RuleName       NVARCHAR(250)
    , Criteria       NVARCHAR(250)
    , ActualValue    NVARCHAR(450)
    , InstanceData   NVARCHAR(250)
    , LastEvaluation NVARCHAR(250)
    , Severity       NVARCHAR(20)
)

/* Get CIs to process */
INSERT INTO @CIID (CIID)
SELECT ToCIID
FROM dbo.fn_rbac_CIRelation(@UserSIDs)
WHERE FromCIID = @BaselineID
    AND RelationType NOT IN (7, 0) --Exlude itself and no relation

/* Get systems data */
INSERT INTO @SystemsInfo (ResourceID, Managed, ClientState, DeviceName, OperatingSystem, OSVersion)
SELECT
    ResourceID        = Computers.ResourceID
    , Managed         =
    CASE Computers.Client0
        WHEN 1 THEN 'Yes'
        ELSE 'No'
    END
    , ClientState     = ClientSummary.ClientStateDescription
    , DeviceName      = Computers.Netbios_Name0
    , OperatingSystem =
        CASE
            WHEN OperatingSystem.Caption0 != '' THEN
                CONCAT(
                    REPLACE(OperatingSystem.Caption0, 'Microsoft ', ''),         --Remove 'Microsoft ' from OperatingSystem
                    REPLACE(OperatingSystem.CSDVersion0, 'Service Pack ', ' SP') --Replace 'Service Pack ' with ' SP' in OperatingSystem
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
    , OSVersion       =
        (
            SELECT OSLocalizedNames.Value
            FROM fn_GetWindowsServicingLocalizedNames() AS OSLocalizedNames
                INNER JOIN fn_GetWindowsServicingStates() AS OSServicingStates ON OSServicingStates.Build = Computers.Build01
            WHERE OSLocalizedNames.Name = OSServicingStates.Name
                AND Computers.OSBranch01 = OSServicingStates.branch --Select only the branch of the installed OS
        )
FROM fn_rbac_FullCollectionMembership(@UserSIDs) AS CollectionMembers
    LEFT JOIN fn_rbac_R_System(@UserSIDs) AS Computers ON Computers.ResourceID = CollectionMembers.ResourceID
    LEFT JOIN fn_rbac_GS_OPERATING_SYSTEM(@UserSIDs) OperatingSystem ON OperatingSystem.ResourceID = CollectionMembers.ResourceID
    LEFT JOIN fn_rbac_CombinedDeviceResources(@UserSIDs) AS CombinedResources ON CombinedResources.MachineID = CollectionMembers.ResourceID
    LEFT JOIN fn_rbac_CH_ClientSummary(@UserSIDs) AS ClientSummary ON ClientSummary.ResourceID = CollectionMembers.ResourceID
WHERE CollectionMembers.CollectionID = @CollectionID

/* Get compliance data */
INSERT INTO @ComplianceInfo (ResourceID, ComplianceState, UserName, CIVersion, SettingVersion, SettingName, RuleName, Criteria, ActualValue, InstanceData, LastEvaluation, Severity)
SELECT DISTINCT
    ResourceID        = CISettingsStatus.ResourceID
    , ComplianceState = CIComplianceState.ComplianceStateName
    , UserName        = CISettingsStatus.UserName
    , CIVersion       = CIComplianceState.CIVersion
    , SettingVersion  = CISettingsStatus.CIVersion
    , SettigName      = CISettings.SettingName
    , RuleName        = CIRules.RuleName
    , Criteria        = CISettingsStatus.Criteria
    , ActualValue     = CISettingsStatus.CurrentValue
    , InstanceData    = CISettingsStatus.InstanceData
    , LastEvaluation  = CISettingsStatus.LastComplianceMessageTime
    , Severity        =
        CASE CISettingsStatus.RuleSeverity
            WHEN 0 THEN 'None'
            WHEN 1 THEN 'Information'
            WHEN 2 THEN 'Warning'
            WHEN 3 THEN 'Critical'
            WHEN 4 THEN 'Critical with event'
        END
FROM fn_rbac_FullCollectionMembership(@UserSIDs) AS CollectionMembers
    INNER JOIN fn_rbac_CIComplianceStatusDetail(@UserSIDs) AS CISettingsStatus ON CISettingsStatus.ResourceID = CollectionMembers.ResourceID
    INNER JOIN fn_ListCIRules(@UserSIDs) AS CIRules ON CIRules.Rule_UniqueID = CISettingsStatus.Rule_UniqueID
        AND CIRules.CIVersion = CISettingsStatus.CIVersion --Select only curent baseline version
    INNER JOIN fn_ListCISettings(@LocaleID) AS CISettings ON CISettings.Setting_UniqueID = CISettingsStatus.Setting_UniqueID
        AND CISettings.CIVersion = CISettingsStatus.CIVersion
    INNER JOIN fn_rbac_ListCI_ComplianceState(@LocaleID, @UserSIDs) AS CIComplianceState ON CIComplianceState.ResourceID = CollectionMembers.ResourceID
        AND CIComplianceState.CI_ID = @BaselineID
WHERE CollectionMembers.CollectionID = @CollectionID
    AND CISettingsStatus.CI_ID IN (SELECT CIID FROM @CIID)
	AND CIComplianceState.ComplianceStateName != 'Error' --We are adding errors below, removing artefacts if any

/* Get error data and add it to ComplianceInfo table */
INSERT INTO @ComplianceInfo (ResourceID, ComplianceState, UserName, CIVersion, SettingVersion, SettingName, RuleName, Criteria, ActualValue, InstanceData)
SELECT
    ResourceID        = ErrorDetails.AssetID
    , ComplianceState = 'Error'
    , UserName        = ErrorDetails.ADUserName
    , CIVersion       = ErrorDetails.BLRevision
    , SettingVersion  = ErrorDetails.Revision
    , SettigName      = ErrorDetails.CIName
    , RuleName        = ErrorDetails.ObjectName
    , Criteria        = ErrorDetails.ObjectTypeName
    , ActualValue     = ErrorDetails.ErrorTypeDisplay
    , InstanceData    = ErrorDetails.ErrorCode
FROM fn_rbac_FullCollectionMembership(@UserSIDs) AS CollectionMembers
INNER JOIN fn_DCMDeploymentErrorDetailsPerAsset(@LocaleID) AS ErrorDetails ON ErrorDetails.AssetID = CollectionMembers.ResourceID
    AND ErrorDetails.BL_ID = @BaselineID
WHERE CollectionMembers.CollectionID = @CollectionID

/* Join SystemsInfo and ComplianceInfo data */
SELECT
    ComplianceState   = ( SELECT ISNULL(ComplianceInfo.ComplianceState, 'Unknown' ))
    , Managed         = SystemsInfo.Managed
    , ClientState     = SystemsInfo.ClientState
    , DeviceName      = SystemsInfo.DeviceName
    , OperatingSystem = CONCAT(SystemsInfo.OperatingSystem, (' ' + SystemsInfo.OSVersion))
    , UserName        = ComplianceInfo.UserName
    , CIVersion       = ComplianceInfo.CIVersion
    , SettingVersion  = ComplianceInfo.SettingVersion
    , SettingName     = ComplianceInfo.SettingName
    , RuleName        = ComplianceInfo.RuleName
    , Criteria        = ComplianceInfo.Criteria
    , ActualValue     = ComplianceInfo.ActualValue
    , InstanceData    = ComplianceInfo.InstanceData
    , LastEvaluation  = ComplianceInfo.LastEvaluation
    , Severity        = ComplianceInfo.Severity
FROM @SystemsInfo AS SystemsInfo
    LEFT JOIN @ComplianceInfo AS ComplianceInfo ON ComplianceInfo.ResourceID = SystemsInfo.ResourceID
WHERE DeviceName != '' --Eliminate artefacts with no device name
ORDER BY
    ComplianceState
    , Managed
    , ClientState
    , DeviceName
    , OperatingSystem
    , UserName
    , CIVersion
    , SettingVersion
    , SettingName
    , RuleName
    , Criteria
    , ActualValue
    , InstanceData
    , LastEvaluation
    , Severity

/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/