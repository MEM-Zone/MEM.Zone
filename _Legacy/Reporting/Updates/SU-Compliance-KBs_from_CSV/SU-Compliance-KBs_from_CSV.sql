/*
*********************************************************************************************************
* Created by Ioan Popovici, 2015-08-18       | Requirements: HWI - Win32_QuickfixEngineering WMI Class. *
* ======================================================================================================*
* Modified by                   |    Date    | Revision | Comments                                      *
*_______________________________________________________________________________________________________*
* Ioan Popovici/Octavian Cordos | 2015-08-18 | v1.0     | First version                                 *
*-------------------------------------------------------------------------------------------------------*
*                                                                                                       *
*********************************************************************************************************

    .SYNOPSIS
        This SQL query is used to get the Compliance for Multiple KBs.
    .DESCRIPTION
        This SQL query is used to get the Compliance for Multiple KBs for a Machine Collection.
*/

/*##=============================================*/
/*## VARIABLE DECLARATION                        */
/*##=============================================*/
/* #region VariableDeclaration */

/*
## Used for Testing Only
DECLARE @UserSIDs VARCHAR(16);
SELECT @UserSIDs = 'disabled';
DECLARE @CollID VARCHAR(8);
SET @CollID = 'SMS00001';
DECLARE @UpdateList Varchar(MAX);
SET @UpdateList = 'KB4015553,KB4019215,KB4015549,KB4015552,KB4012598,KB4019264,KB4012215,KB4012213,KB4012212,KB4012217,KB4015551,KB4019216,KB4012216,KB4015550,KB4013429,KB4019472,KB4015217,KB4015438,KB4016635,KB4019473,KB4015219,KB4013198,KB4012606,KB4015221,KB4019474,KB4012214,KB4019265,KB4019263,KB4015546,KB4022727,KB4022714,KB4022715,KB4022168,KB4022719,KB4022720,KB4022726,KB4025335,KB4025336,KB4025341,KB4034664,KB4034681,KB4022727,KB4022714,KB4022715,KB4022725,KB4025338,KB4025344,KB4025339,KB4025342,KB4032188,KB4034668,KB4034660,KB4034658,KB4034674'

=Join(Parameters!UpdateList.Value,",")
*/

/* #endregion */
/*##=============================================*/
/*## END VARIABLE DECLARATION                    */
/*##=============================================*/

/*##=============================================*/
/*## QUERY BODY
/*##=============================================*/
/* #region QueryBody */

/* Parsing CSV String using a user defined function */
SELECT *
INTO [#TMP_KB]
    FROM [CM_Tools].[dbo].[ufn_csv_String_Parser](@UpdateList, ',');

/* Getting Raw Compliance list Tagging Installed as 'FALSE' or 'TRUE' */
SELECT [SYS].[Name0],
    CASE
        WHEN [HE].[HotfixID0] IN ( SELECT * FROM [#TMP_KB] ) THEN 'TRUE'
        ELSE 'FALSE'
    END AS 'Installed',
    [HE].[HotfixID0],
    [HE].[ResourceID]
INTO [#TMP_RawCompliance]
FROM [fn_rbac_GS_SYSTEM](@UserSIDs) [SYS]
    JOIN [dbo].[v_GS_QUICK_FIX_ENGINEERING] AS [HE] ON [HE].[ResourceID] = [SYS].[ResourceID]
    JOIN [dbo].[v_FullCollectionMembership] AS [fcm] ON [sys].[ResourceID] = [fcm].[ResourceID]
WHERE [fcm].[CollectionID] = @CollID
    AND [HE].[HotFixID0] IN ( SELECT * FROM [#TMP_KB] )
ORDER BY [sys].[Name0];

/* Getting Machine Collection data and doing Crosscheck with Raw Compliance */
SELECT DISTINCT
    [s].[ResourceID] AS [MachineID],
    ( SELECT [CM_Tools].[dbo].[ufn_GetCompany_by_ResourceID]([s].[ResourceID]) ) AS [Company],
    [r].[Resource_Names0] AS [Machine],
    CASE
        WHEN [cm].[HotFixID0] IS NOT NULL THEN [cm].[HotFixID0]
        WHEN ([s].[Client0] = 0) OR ([s].[Client0] IS NULL) THEN 'Unknown'
        ELSE 'None'
    END AS KB,
    CASE
        WHEN ([s].[Client0] = 1) THEN 'Yes'
        ELSE 'No'
    END AS [Client],
    CASE
        WHEN ([s].[Active0] = 1) THEN 'Active'
        WHEN ([s].[Active0] = 0) THEN 'Inactive'
        ELSE 'Unknown'
    END AS [Active],
    CASE
        WHEN ([chcs].[LastEvaluationHealthy] = 1) THEN 'Pass'
        WHEN ([chcs].[LastEvaluationHealthy] = 2) THEN 'Fail'
        ELSE 'Unknown'
    END AS 'Last Evaluation Healthy',
    [chcs].[LastDDR],
    CASE
        WHEN (DATEDIFF(day, [chcs].[LastDDR], GETDATE()) <= 14) THEN 'Yes'
        WHEN (DATEDIFF(day, [chcs].[LastDDR], GETDATE()) >= 14) THEN 'No'
        ELSE 'Unknown'
    END AS 'DDR in the last 14 Days',
    CASE
        WHEN (DATEDIFF(day, [os].[LastBootUpTime0], GETDATE()) <= 14) THEN 'Yes'
        WHEN (DATEDIFF(day, [os].[LastBootUpTime0], GETDATE()) >= 14) THEN 'No'
        ELSE 'Unknown'
    END AS 'Rebooted in the last 14 Days',
    CASE
        WHEN ([s].[Client_Version0] IS NULL) THEN 'Unknown'
        ELSE [s].[Client_Version0]
    END AS 'Client Version',
    CASE
        WHEN (MAX([ou].[System_OU_Name0]) IS NULL) THEN 'Unknown'
        ELSE MAX([ou].[System_OU_Name0])
    END AS [OUName],
    CASE
        WHEN ([os].[Caption0]  IS NULL) THEN 'Unknown'
        ELSE [os].[Caption0]
    END AS 'OS'
    FROM [dbo].[fn_rbac_R_System](@UserSIDs) [s]
        LEFT JOIN [#TMP_RawCompliance] AS [CM] ON [CM].[ResourceID] = [s].[ResourceID]
        LEFT JOIN [v_RA_System_SystemOUName] AS [ou] ON [s].[ResourceID] = [ou].[ResourceID]
        LEFT JOIN [fn_rbac_GS_SYSTEM](@UserSIDs) AS [SYS] ON [s].[ResourceID] = [SYS].[ResourceID]
        LEFT JOIN [v_RA_System_ResourceNames] [r] ON [s].[ResourceID] = [r].[ResourceID]
        LEFT OUTER JOIN [dbo].[v_GS_OPERATING_SYSTEM] AS [os] ON [os].[ResourceID] = [s].[ResourceID]
        LEFT OUTER JOIN [dbo].[v_CH_ClientSummary] AS [chcs] ON [chcs].[ResourceID] = [s].[ResourceID]
        JOIN [dbo].[v_FullCollectionMembership] AS [fcm] ON [s].[ResourceID] = [fcm].[ResourceID]
    WHERE [fcm].[CollectionID] = @CollID
    GROUP BY [CM].[Installed],
        [cm].[HotFixID0],
        [r].[Resource_Names0],
        [SYS].[SystemRole0],
        [s].[Client0],
        [s].[Active0],
        [s].[Client_Version0],
        [s].[Netbios_Name0],
        [s].[Full_Domain_Name0],
        [s].[ResourceID],
        [chcs].[LastEvaluationHealthy],
        [chcs].[LastDDR],
        [os].[LastBootUpTime0],
        [os].[Caption0] ORDER BY [r].[Resource_Names0];

    DROP TABLE [#TMP_RawCompliance];
    DROP TABLE [#TMP_KB];

/* #endregion */
/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/
