/*
.SYNOPSIS
    Gets the Compliance of a Configuration Baseline.
.DESCRIPTION
    Gets the Compliance and Actual Values of a Configuration Baseline setting result.
.NOTES
    Created by Ioan Popovici
    Requires SSRS/SQL, SCCM Configuration Baseline
.LINK
    https://SCCM.Zone/CB-Configuration-Baseline-Compliance
.LINK
    https://SCCM.Zone/CB-Configuration-Baseline-Compliance-CHANGELOG
.LINK
    https://SCCM.Zone/CB-Configuration-Baseline-Compliance-GIT
.LINK
    https://SCCM.Zone/Issues
*/

/*##=============================================*/
/*## QUERY BODY                                  */
/*##=============================================*/

/* Testing variables !! Need to be commented for Production !! */
--DECLARE @CollectionID AS NVARCHAR(10)  = 'HUB000B7';
--DECLARE @LocaleID     AS INTEGER       = 2;
--DECLARE @BaselineID   AS INTEGER       = 39225;

/* Workaround for malformed UserSID */
DECLARE @UserSIDs     AS NVARCHAR(250) = 1;

/* Initialize CIID table */
DECLARE @CIID TABLE
(
    CIID INTEGER
)

/* Initialize ComplianceInfo table */
DECLARE @ComplianceInfo TABLE
(
    ComplianceState  NVARCHAR(20)
    , ResourceID     INTEGER
    , UserName       NVARCHAR(250)
    , CIVersion      INTEGER
    , SettingVersion INTEGER
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
FROM dbo.v_CIRelation
WHERE FromCIID = @BaselineID
    AND RelationType NOT IN (7, 0) -- Exlude itself and no relation

/* Get general compliance data  and add it to ComplianceInfo table */
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
    , Severity        = (
        CASE CISettingsStatus.RuleSeverity
            WHEN 0 THEN 'None'
            WHEN 1 THEN 'Information'
            WHEN 2 THEN 'Warning'
            WHEN 3 THEN 'Critical'
            WHEN 4 THEN 'Critical with event'
        END
    )
FROM v_FullCollectionMembership AS CollectionMembers
    INNER JOIN v_CIComplianceStatusDetail AS CISettingsStatus ON CISettingsStatus.ResourceID = CollectionMembers.ResourceID
    INNER JOIN fn_ListCIRules(@UserSIDs) AS CIRules ON CIRules.Rule_UniqueID = CISettingsStatus.Rule_UniqueID
        AND CIRules.CIVersion = CISettingsStatus.CIVersion -- Select only curent baseline version
    INNER JOIN fn_ListCISettings(@LocaleID) AS CISettings ON CISettings.Setting_UniqueID = CISettingsStatus.Setting_UniqueID
        AND CISettings.CIVersion = CISettingsStatus.CIVersion
    INNER JOIN fn_rbac_ListCI_ComplianceState(@LocaleID, @UserSIDs) AS CIComplianceState ON CIComplianceState.ResourceID = CollectionMembers.ResourceID
        AND CIComplianceState.CI_ID = @BaselineID
WHERE CollectionMembers.CollectionID = @CollectionID
    AND CISettingsStatus.CI_ID IN (SELECT CIID FROM @CIID)
    AND CIComplianceState.ComplianceStateName != 'Error'   -- We are adding errors below, removing artefacts if any

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
FROM v_FullCollectionMembership AS CollectionMembers
INNER JOIN fn_DCMDeploymentErrorDetailsPerAsset(@LocaleID) AS ErrorDetails ON ErrorDetails.AssetID = CollectionMembers.ResourceID
    AND ErrorDetails.BL_ID = @BaselineID
WHERE CollectionMembers.CollectionID = @CollectionID

/* Get compliant data and add it to ComplianceInfo table */
INSERT INTO @ComplianceInfo (ResourceID, ComplianceState, UserName, CIVersion, SettingVersion, SettingName, RuleName, Criteria, ActualValue, InstanceData)
SELECT
    ResourceID        = CompliantDetails.AssetID
    , ComplianceState = 'Compliant'
    , UserName        = CompliantDetails.ADUserName
    , CIVersion       = CompliantDetails.BLRevision
    , SettingVersion  = CompliantDetails.Revision
    , SettigName      = CompliantDetails.CIName
    , RuleName        = CompliantDetails.RuleName
    , Criteria        = CompliantDetails.ValidationRule
    , ActualValue     = CompliantDetails.DiscoveredValue
    , InstanceData    = CompliantDetails.InstanceData
FROM v_FullCollectionMembership AS CollectionMembers
INNER JOIN fn_DCMDeploymentCompliantDetailsPerAsset(@LocaleID) AS CompliantDetails ON CompliantDetails.AssetID = CollectionMembers.ResourceID
    AND CompliantDetails.BL_ID = @BaselineID
WHERE CollectionMembers.CollectionID = @CollectionID;

/* Get systems data and join ComplianceInfo table */
    SELECT
        ComplianceState   = ISNULL(ComplianceInfo.ComplianceState, 'Unknown')
        , Managed         = (
            CASE Systems.Client0
                WHEN 1 THEN 'Yes'
                ELSE 'No'
            END
        )
        , ClientState     = ClientSummary.ClientStateDescription
        , DeviceName      = Systems.Netbios_Name0
        , OperatingSystem = (
            CASE
                WHEN Systems.Operating_System_Name_and0 LIKE 'Microsoft Windows NT %Workstation 10.0%' THEN 'Windows 10'
                WHEN Systems.Operating_System_Name_and0 LIKE 'Microsoft Windows NT %Server 10%'        THEN (
                    CASE
                        WHEN CAST(REPLACE(Systems.Build01, '.', '') AS INTEGER) > 10017763             THEN 'Windows Server 2019'
                        ELSE 'Windows Server 2016'
                    END
                )
                WHEN Systems.Operating_System_Name_and0 LIKE 'Microsoft Windows NT %Server 6.3'        THEN 'Windows Server 2012 R2'
                WHEN Systems.Operating_System_Name_and0 LIKE 'Microsoft Windows NT %Server 6.2'        THEN 'Windows Server 2012'
                WHEN Systems.Operating_System_Name_and0 LIKE 'Microsoft Windows NT %Server 6.1'        THEN 'Windows Server 2008R2'
                WHEN Systems.Operating_System_Name_and0 LIKE 'Microsoft Windows NT %Server 6.0'        THEN 'Windows Server 2008'
                WHEN Systems.Operating_System_Name_and0 LIKE 'Microsoft Windows NT %Workstation 6.3%'  THEN 'Windows 8.1'
                WHEN Systems.Operating_System_Name_and0 LIKE 'Microsoft Windows NT %Workstation 6.2%'  THEN 'Windows 8'
                WHEN Systems.Operating_System_Name_and0 LIKE 'Microsoft Windows NT %Workstation 6.1%'  THEN 'Windows 7'
                ELSE 'Unknown'
            END
        )
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
    FROM v_FullCollectionMembership AS CollectionMembers
        LEFT JOIN v_R_System AS Systems ON Systems.ResourceID = CollectionMembers.ResourceID
        LEFT JOIN v_CH_ClientSummary AS ClientSummary ON ClientSummary.ResourceID = CollectionMembers.ResourceID
        LEFT JOIN @ComplianceInfo AS ComplianceInfo ON ComplianceInfo.ResourceID = CollectionMembers.ResourceID
    WHERE CollectionMembers.CollectionID = @CollectionID
        AND Systems.Netbios_Name0 !=  '' -- Eliminate artefacts with no device name

/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/