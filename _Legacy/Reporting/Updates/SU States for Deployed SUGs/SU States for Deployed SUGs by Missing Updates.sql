/*
DECLARE @CollID varchar(8) = 'Collection ID for Testing'
DECLARE @UserSIDs VARCHAR(16);
SELECT @UserSIDs = 'disabled';
*/

-- Getting Deployments IDs
DECLARE @lcid AS int SET @lcid = dbo.fn_LShortNameToLCID('English')

SELECT cia.AssignmentID AS id INTO #ASSIGNID
FROM fn_rbac_CIAssignmentToGroup(@UserSIDs) atg
JOIN fn_rbac_AuthListInfo(@lcid, @UserSIDs) ugi ON ugi.CI_ID = atg.AssignedUpdateGroup
JOIN v_CIAssignment cia ON atg.AssignmentID = cia.AssignmentID

-- Software update Goup Config Item ID for testing
--WHERE CI_ID IN (17143786,
--                17152698,
--                17159821)

-- Report Usage
   CI_ID in (@SUGS)

-- Getting Updates States for updates in selected Update Groups
    SELECT uc.ResourceID,
           uc.StateType,
           uc.StateID INTO #updatestates_combined
    FROM v_UpdateState_Combined uc WITH (nolock) WHERE uc.ResourceID IN
        (SELECT ast0.ResourceID
         FROM v_CIAssignmentTargetedMachines ast0
         WHERE ast0.AssignmentID IN
                 (SELECT id
                  FROM #ASSIGNID))
    AND uc.CI_ID IN
        (SELECT aci0.CI_ID
         FROM v_CIAssignmentToCI aci0
         WHERE aci0.AssignmentID IN
                 (SELECT id
                  FROM #ASSIGNID))
    SELECT uc.ResourceID,
           s.name0,
           s.Name0+'.'+s.Full_Domain_Name0 AS ComputerName0,
           sn.StateName AS Status ,
           count(sn.StateName) AS countstatus INTO #updates_status
    FROM #updatestates_combined uc
    JOIN v_StateNames sn WITH (nolock) ON sn.TopicType = uc.StateType
    AND sn.StateID = uc.StateID
    JOIN v_R_System s WITH (nolock) ON s.ResourceID = uc.ResourceID
    AND isnull(s.Obsolete0,0) = 0
    JOIN
        (SELECT fcm1.ResourceID
         FROM v_FullCollectionMembership fcm1 WITH (nolock)
         WHERE fcm1.CollectionID = @CollID) fcm ON fcm.ResourceID = s.ResourceID WHERE sn.StateName NOT LIKE 'Update is not required'
GROUP BY uc.ResourceID,
         s.Name0,
         s.Full_Domain_Name0,
         sn.StateName

-- Pivoting Data and setting overall Compliance State
SELECT *,
       CASE
           WHEN [Update is installed] IS NOT NULL
                AND [Detection state unknown] IS NULL
                AND [Downloaded update] IS NULL
                AND [Installing update] IS NULL
                AND [Pending system restart] IS NULL
                AND [Successfully installed update] IS NULL
                AND [Update is required] IS NULL
                AND [Waiting for another installation to complete] IS NULL
                AND [Successfully installed update] IS NULL
                AND [Failed to download update] IS NULL
                AND [Failed to install update] IS NULL
                AND [General failure] IS NULL
                AND [Waiting for maintenance window before installing] IS NULL THEN 'Compliant'
           WHEN [Failed to download update] IS NOT NULL
                OR [Failed to install update] IS NOT NULL
                OR [General failure] IS NOT NULL THEN 'Failed'
           WHEN [Detection state unknown] IS NOT NULL THEN 'State Unknown'
           ELSE 'In Progress'
       END AS [Compliancy]
FROM #updates_status pivot(sum(countstatus)
                           FOR [status] IN ([Detection state unknown],[Downloaded update],[Failed to download update],[Failed to install update],[General failure],[Installing update],[Pending system restart],[Successfully installed update],[Update is installed],[Update is not required],[Update is required],[Waiting for another installation to complete],[Waiting for maintenance window before installing]) ) AS results;

 -- Cleanup
DROP TABLE #updates_status
DROP TABLE #ASSIGNID
DROP TABLE #updatestates_combined
