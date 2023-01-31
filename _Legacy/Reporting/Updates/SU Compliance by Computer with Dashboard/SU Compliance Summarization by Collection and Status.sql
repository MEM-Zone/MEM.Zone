/*
.SYNOPSIS
    Summarizes the software update compliance by collection.
.DESCRIPTION
    Summarizes the software update compliance by collection and compliance status in SCCM.
.NOTES
    Created by Ioan Popovici   2018-11-19
*/

/*##=============================================*/
/*## QUERY BODY                                  */
/*##=============================================*/

/* Testing variables !! Need to be commented for Production !! */
DECLARE @UserSIDs       AS NVARCHAR(10)  = 'Disabled';
DECLARE @CollectionName AS NVARCHAR(250) = 'SCCM Managed Systems -';
DECLARE @Locale         AS INT           = 2;

/* Variable declaration */
DECLARE @LCID AS INT = dbo.fn_LShortNameToLCID (@Locale)

/* Initialize SummarizationInfo table */
DECLARE @SummarizationInfo TABLE (
    CollectionID            NVARCHAR(50)
    , CollectionName        NVARCHAR(250)
    , ComplianceStatus      NVARCHAR(50)
    , MissingUniqueUpdates  INT
    , CompliantDevices      INT
    , NonCompliantDevices   INT
    , ClientDevices         INT
    , NonClientDevices      INT
    , TotalDevices          INT
)

/* Get compliance data data */
INSERT INTO @SummarizationInfo(CollectionID, CollectionName, ComplianceStatus, MissingUniqueUpdates, NonCompliantDevices, ClientDevices, TotalDevices)
SELECT DISTINCT
    CollectionID            = Collections.CollectionID
    , CollectionName        = Collections.Name
    , ComplianceStatus      = (
        CASE ComplianceStatus.Status
            WHEN 0 THEN 'Unknown'
            WHEN 2 THEN 'Required'
        END
    )
    , MissingUniqueUpdates = (
        DENSE_RANK() OVER(PARTITION BY Collections.Name ORDER BY ComplianceStatus.Status, UpdateCIs.ArticleID)
        + DENSE_RANK() OVER(PARTITION BY Collections.Name ORDER BY ComplianceStatus.Status, UpdateCIs.ArticleID DESC)
        - 1
    )
    , NonCompliantDevices  = (
        DENSE_RANK() OVER(PARTITION BY Collections.Name ORDER BY ComplianceStatus.Status, ComplianceStatus.ResourceID)
        + DENSE_RANK() OVER(PARTITION BY Collections.Name ORDER BY ComplianceStatus.Status, ComplianceStatus.ResourceID DESC)
        - 1
    )
    , ClientDevices        =  (
        SELECT COUNT(ResourceID) FROM fn_rbac_ClientCollectionMembers(@UserSIDs) AS ClientCollectionMembers WHERE ClientCollectionMembers.CollectionID = Collections.CollectionID

    )
    , TotalDevices         = (
        SELECT COUNT(ResourceID) FROM fn_rbac_FullCollectionMembership(@UserSIDs) AS CollectionMembers WHERE CollectionMembers.CollectionID = Collections.CollectionID
    )
FROM fn_rbac_ClientCollectionMembers(@UserSIDs) AS ClientCollectionMembers
    INNER JOIN fn_rbac_Collection(@UserSIDs) AS Collections ON Collections.CollectionID = ClientCollectionMembers.CollectionID
    INNER JOIN v_Update_ComplianceStatus AS ComplianceStatus ON ComplianceStatus.ResourceID = ClientCollectionMembers.ResourceID
        AND ComplianceStatus.Status IN (0, 2) --0 Unknown, 2 Required, 3 Installed
    INNER JOIN fn_ListUpdateCIs(@LCID) AS UpdateCIs ON UpdateCIs.CI_ID = ComplianceStatus.CI_ID
        AND UpdateCIs.CIType_ID IN (1, 8)     --1 Software Updates, 8 Software Update Bundle (v_CITypes)
        AND UpdateCIs.IsSuperseded = 0        --Update is not Superseeded
        AND UpdateCIs.IsDeployed = 1          --Update is deployed
        AND UpdateCIs.IsExpired = 0           --Update is not Expired
    AND UpdateCIs.IsEnabled = 1               --Update is enabled
WHERE Collections.Name LIKE @CollectionName + '%'

/* Summarize result */
SELECT
    CollectionName
    , ComplianceStatus
    , MissingUniqueUpdates
    , CompliantDevices     = ClientDevices - NonCompliantDevices
    , NonCompliantDevices
    , ClientDevices
    , NonClientDevices     = TotalDevices - ClientDevices
    , TotalDevices
FROM @SummarizationInfo

/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/