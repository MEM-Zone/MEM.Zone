/*
*********************************************************************************************************
* Requires          | SQL, company AD attribute gathering, Configuration Baseline                       *
* ===================================================================================================== *
* Modified by       |    Date    | Revision | Comments                                                  *
* _____________________________________________________________________________________________________ *
* Ioan Popovici     | 2017-09-22 | v1.0     | First version                                             *
* ===================================================================================================== *
* Release info moved separate markdown file, see notes.                                                 *
*********************************************************************************************************

.SYNOPSIS
    This SQL Query is used to get the Compliance of a Configuration Baseline by Company.
.DESCRIPTION
    This SQL Query is used to get the Compliance by Company and Actual Values of a Configuration Baseline Result.
.NOTES
    Release notes
        https://github.com/Ioan-Popovici/SCCMZone/blob/master/Reporting/Compliance/CB%20Configuration%20Baseline%20Compliance/CHANGELOG.md
    Part of a report should not be run separately.
.LINK
    https://SCCM-Zone.com
    https://github.com/Ioan-Popovici/SCCMZone
*/

/*##=============================================*/
/*## QUERY BODY                                  */
/*##=============================================*/
/* #region QueryBody */

/* Remove previous temporary table if exists */
IF OBJECT_ID (N'TempDB.DBO.#CIComplianceStatusDetails') IS NOT NULL
    BEGIN
    DROP TABLE #CIComplianceStatusDetails;
END;

/* Get configuration item current value for collection members and insert the result in a temporary table */
WITH
    CTE
    AS
    (
        SELECT DISTINCT
            CIComplianceStatusDetails.ResourceID,
            CIComplianceStatusDetails.CIVersion AS CBRevision,
            CIComplianceStatusDetails.CurrentValue,
            CIComplianceStatusDetails.LastComplianceMessageTime,
            CIComplianceStatusDetails.Netbios_Name0
        FROM dbo.fn_rbac_CICurrentSettingsComplianceStatusDetail(@UserSIDs) AS CIComplianceStatusDetails
        WHERE CIComplianceStatusDetails.CI_ID
            IN (
                SELECT ReferencedCI_ID
        FROM dbo.fn_rbac_CIRelation_All(@UserSIDs)
        WHERE CI_ID = @BaselineID
            AND RelationType NOT IN ('7', '0') --Exlude itself and no relation
            )
    )
SELECT
    ResourceID,
    CBRevision,
    CurrentValue,
    LastComplianceMessageTime
INTO #CIComplianceStatusDetails
FROM CTE
ORDER BY ResourceID;

/* Get the other details and join with them with the temporary table based on ResourceID */
SELECT

    /* IMPORTANT! YOU NEED TO ENABLE THE COMPANY FIELD GATHERING FOR SYSTEM DISCOVERY OTHERWISE THIS COLUMN IS NOT AVAILABLE */
    ComputerSystem.Company0 AS 'Company',

    /* CUSTOM FUNCTION LEAVE DISABLED */
    --( SELECT [CM_Tools].[dbo].[ufn_GetCompany_by_ResourceID]([ComputerSystem].[ResourceID]) ) AS [Company],

    CollectionMembers.ResourceID,
    CIComplianceState.DisplayName,
    ( SELECT ISNULL(CIComplianceState.ComplianceStateName, 'Unknown' )) AS ComplianceState,
    OperatingSystem.Caption0 AS OperatingSystem,
    ( SELECT ISNULL(ComputerSystem.UserName0, 'Unknown' )) AS UserName,
    ComputerSystem.Name0 AS DeviceName,
    ComputerSystem.Model0 AS Model,
    ComputerStatus.LastHWScan,
    CIComplianceState.CIVersion AS CIRevision,
    CIComplianceStatusDetails.CBRevision,
    CIComplianceStatusDetails.CurrentValue,
    CIComplianceStatusDetails.LastComplianceMessageTime,
    CIComplianceStatusDetails.LastComplianceMessageTime AS LastEvaluation
FROM
    v_ClientCollectionMembers AS CollectionMembers
    LEFT JOIN v_GS_OPERATING_SYSTEM AS OperatingSystem ON OperatingSystem.ResourceID = CollectionMembers.ResourceID
    LEFT JOIN v_GS_COMPUTER_SYSTEM AS ComputerSystem ON ComputerSystem.ResourceID = CollectionMembers.ResourceID
    LEFT JOIN v_GS_WORKSTATION_STATUS AS ComputerStatus ON ComputerStatus.ResourceID = CollectionMembers.ResourceID
    FULL JOIN dbo.fn_rbac_ListCI_ComplianceState(@LocaleID, @UserSIDs) AS CIComplianceState ON CIComplianceState.ResourceID = CollectionMembers.ResourceID
        AND CIComplianceState.CI_ID = @BaselineID
    FULL JOIN #CIComplianceStatusDetails AS CIComplianceStatusDetails ON CIComplianceStatusDetails.ResourceID = CollectionMembers.ResourceID
WHERE
	CollectionMembers.CollectionID = @CollectionID
ORDER BY
    Company,
	DisplayName,
	ComplianceStateName

/* Remove  temporary table */
DROP TABLE #CIComplianceStatusDetails;

/* #endregion */
/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/