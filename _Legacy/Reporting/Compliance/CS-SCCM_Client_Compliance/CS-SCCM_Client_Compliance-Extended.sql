--DECLARE @UserSIDs VARCHAR(16);
--SELECT @UserSIDs = 'disabled';

SELECT
    CASE
        WHEN (srn.Resource_Names0 != '') THEN srn.Resource_Names0
        ELSE vrs.Name0
    END AS 'Machine Name',
    sites.SMS_Assigned_Sites0 AS 'Assigned Sites',
    vrs.Client_Version0 AS 'Client Version',
    chcs.ClientStateDescription AS 'Client State Description',
    CASE
       WHEN (chcs.ClientActiveStatus = 0) THEN 'Inactive'
       WHEN (chcs.ClientActiveStatus = 1) THEN 'Active'
    END AS 'Client Active Status',
    chcs.LastActiveTime AS 'Last Active Time',
    CASE
       WHEN (chcs.IsActiveDDR) = 0 THEN 'Inactive'
       WHEN (chcs.IsActiveDDR) = 1 THEN 'Active'
    END AS 'DDR Status',
    CASE
       WHEN (chcs.IsActiveHW = 0) THEN 'Inactive'
       WHEN (chcs.IsActiveHW = 1) THEN 'Active'
    END AS 'Hardware Inventory Status',
    CASE
       WHEN (chcs.IsActiveSW = 0) THEN 'Inactive'
       WHEN (chcs.IsActiveSW = 1) THEN 'Active'
    END AS 'Software Inventory Status',
    CASE
       WHEN (chcs.ISActivePolicyRequest = 0) THEN 'Inactive'
       WHEN (chcs.ISActivePolicyRequest = 1) THEN 'Active'
    END AS 'Policy Request Status',
    CASE
       WHEN (chcs.IsActiveStatusMessages = 0) THEN 'Inactive'
       WHEN (chcs.IsActiveStatusMessages = 1) THEN 'Active'
    END AS 'Status Messages Status',
    chcs.LastOnline AS 'Last Online Time',
    chcs.LastDDR AS 'Last DDR Time',
    chcs.LastHW AS 'Last Hardware Inventory',
    chcs.LastSW AS 'Last Software Inventory',
    chcs.LastPolicyRequest AS 'Last Policy Request',
    chcs.LastStatusMessage AS 'Last Status Message',
    chcs.LastHealthEvaluation AS 'Last Health Evaluation',
    CASE
       WHEN (chcs.LastHealthEvaluationResult = 1) THEN 'Not Yet Evaluated'
       WHEN (chcs.LastHealthEvaluationResult = 2) THEN 'Not Applicable'
       WHEN (chcs.LastHealthEvaluationResult = 3) THEN 'Evaluation Failed'
       WHEN (chcs.LastHealthEvaluationResult = 4) THEN 'Evaluated Remediated Failed'
       WHEN (chcs.LastHealthEvaluationResult = 5) THEN 'Not Evaluated Dependency Failed'
       WHEN (chcs.LastHealthEvaluationResult = 6) THEN 'Evaluated Remediated Succeeded'
       WHEN (chcs.LastHealthEvaluationResult = 7) THEN 'Evaluation Succeeded'
    END AS 'Last Health Evaluation Result',
    CASE
       WHEN (chcs.LastEvaluationHealthy = 1) THEN 'Pass'
       WHEN (chcs.LastEvaluationHealthy = 2) THEN 'Fail'
       WHEN (chcs.LastEvaluationHealthy = 3) THEN 'Unknown'
    END AS 'Last Evaluation Healthy',
    CASE
       WHEN (chcs.ClientRemediationSuccess = 1) THEN 'Pass'
       WHEN (chcs.ClientRemediationSuccess = 2) THEN 'Fail'
    END AS 'Client Remediation Success',
    chcs.ExpectedNextPolicyRequest AS 'Next Expected Policy Request',
    ccm.DeploymentEndTime AS 'SCCM Client Deployment End Time',
    cs.Domain0 AS 'Domain or Worgroup',
    vrs.Full_Domain_Name0 AS 'Full Domain Name',
    MAX(ou.System_OU_Name0) 'System OU Name',
    cs.Manufacturer0 AS 'Manufacturer',
    cs.Model0 AS 'Model',
    vrs.Virtual_Machine_Host_Name0 AS 'Virtual Machine HostName',
    cs.UserName0 AS 'User Name',
    cons.TopConsoleUser0 AS 'Top Console User',
    vrs.Last_Logon_Timestamp0 AS 'Last Logon Time',
    os.Caption0 AS 'Operating System',
    os.CSDVersion0 AS 'Service Pack',
    os.LastBootUpTime0 AS 'Last Boot Time',
    os.InstallDate0 AS 'Build Date',
    uss.LastWUAVersion AS 'Last WUA Version',
    uss.LastScanTime AS 'Last WUA Scan',
    (SELECT CM_Tools.dbo.fnGetIP_by_ResourceID (chcs.ResourceID)) AS 'IP',
    (SELECT CM_Tools.dbo.fnGetDefaultIPGateway_by_ResourceID (chcs.ResourceID)) AS 'Default Gateway',
    CASE
        WHEN (se.ChassisTypes0 = '1') THEN 'Other'
        WHEN (se.ChassisTypes0 = '2') THEN 'Unknown'
        WHEN (se.ChassisTypes0 = '3') THEN 'Desktop'
        WHEN (se.ChassisTypes0 = '4') THEN 'Low Profile Desktop'
        WHEN (se.ChassisTypes0 = '5') THEN 'Pizza Box'
        WHEN (se.ChassisTypes0 = '6') THEN 'Mini Tower'
        WHEN (se.ChassisTypes0 = '7') THEN 'Tower'
        WHEN (se.ChassisTypes0 = '8') THEN 'Portable'
        WHEN (se.ChassisTypes0 = '9') THEN 'Laptop'
        WHEN (se.ChassisTypes0 = '14') THEN 'Sub Notebook'
        WHEN (se.ChassisTypes0 = '15') THEN 'Space-Saving'
        WHEN (se.ChassisTypes0 = '16') THEN 'Lunch Box'
        WHEN (se.ChassisTypes0 = '17') THEN 'Main System Chassis'
        WHEN (se.ChassisTypes0 = '18') THEN 'Expansion Chassis'
        WHEN (se.ChassisTypes0 = '10') THEN 'Notebook'
        WHEN (se.ChassisTypes0 = '11') THEN 'Hand Held'
        WHEN (se.ChassisTypes0 = '12') THEN 'Docking Station'
        WHEN (se.ChassisTypes0 = '13') THEN 'All in One'
        WHEN (se.ChassisTypes0 = '19') THEN 'SubChassis'
        WHEN (se.ChassisTypes0 = '20') THEN 'Bus Expansion Chassis'
        WHEN (se.ChassisTypes0 = '21') THEN 'Peripheral Chassis'
        WHEN (se.ChassisTypes0 = '22') THEN 'Storage Chassis'
        WHEN (se.ChassisTypes0 = '23') THEN 'Rack Mount Chassis'
        WHEN (se.ChassisTypes0 = '24') THEN 'Sealed-Case PC'
    END AS 'Chassis Type',
    bios.ReleaseDate0 AS 'BIOS Release Date',
    CASE
        WHEN (scep.EpInstalled = '1') THEN 'Yes'
        WHEN (scep.EpInstalled = '0') THEN 'No'
    END AS 'Endpoint Protection Installed',
    CASE
        WHEN (scep.EpManaged = '1') THEN 'Yes'
        WHEN (scep.EpManaged = '0') THEN 'No'
    END AS 'Endpoint Protection Managed',
    CASE
        WHEN (scep.EpEnabled = '1') THEN 'Yes'
        WHEN (scep.EpEnabled = '0') THEN 'No'
    END AS 'Endpoint Protection Enabled',
    CASE
        WHEN ((SELECT COUNT(svc.DisplayName00)
        FROM Services_DATA svc WHERE svc.MachineID = vrs.ResourceID
            AND svc.Name00 LIKE '%HealthService%') = '0') THEN 'No'
        ELSE 'Yes'
    END AS 'SCOM Installed',
    CASE
        WHEN ((SELECT COUNT(DISTINCT svc.PathName00)
        FROM Services_DATA svc WHERE svc.MachineID = vrs.ResourceID
            AND svc.PathName00 LIKE '%TSM\baclient\dsmcsv%') = '0') THEN 'No'
        ELSE 'Yes'
    END AS 'TSM Installed'
FROM dbo.v_R_System AS vrs
LEFT OUTER JOIN dbo.v_CH_ClientSummary AS chcs ON chcs.ResourceID = vrs.ResourceID
LEFT OUTER JOIN dbo.v_ClientCollectionMembers AS col ON col.ResourceID = vrs.ResourceID
LEFT OUTER JOIN dbo.v_RA_System_SystemOUName AS ou ON ou.ResourceID = vrs.ResourceID
LEFT OUTER JOIN dbo.v_RA_System_ResourceNames AS srn ON srn.ResourceID = vrs.ResourceID
LEFT OUTER JOIN dbo.v_GS_PC_BIOS AS bios ON bios.ResourceID = vrs.ResourceID
LEFT OUTER JOIN dbo.v_GS_SYSTEM_CONSOLE_USAGE_MAXGROUP AS cons ON cons.ResourceID = vrs.ResourceID
LEFT OUTER JOIN dbo.v_GS_COMPUTER_SYSTEM AS cs ON cs.ResourceID = vrs.ResourceID
LEFT OUTER JOIN dbo.v_GS_OPERATING_SYSTEM AS os ON os.ResourceID = vrs.ResourceID
LEFT OUTER JOIN dbo.v_GS_SYSTEM_ENCLOSURE AS se ON se.ResourceID = vrs.ResourceID
LEFT OUTER JOIN dbo.v_RA_System_SMSAssignedSites AS sites ON sites.ResourceID = vrs.ResourceID
LEFT OUTER JOIN dbo.v_UpdateScanStatus AS uss ON uss.ResourceID = vrs.ResourceID
LEFT OUTER JOIN dbo.v_EndpointProtectionStatus AS scep ON scep.ResourceID = vrs.ResourceID
LEFT OUTER JOIN dbo.v_ClientDeploymentState AS ccm ON ccm.SMSID = vrs.SMS_Unique_Identifier0
--WHERE chcs.ResourceID = @CompID AND DefaultIPGateway0 != '' AND netw.IPEnabled0 = 1
GROUP BY
    srn.Resource_Names0,
    sites.SMS_Assigned_Sites0,
    vrs.ResourceID,
    vrs.Name0,
    vrs.Full_Domain_Name0,
    vrs.Client_Version0,
    vrs.Virtual_Machine_Host_Name0,
    chcs.ResourceID,
    chcs.ClientStateDescription,
    chcs.ClientActiveStatus,
    chcs.LastActiveTime,
    chcs.IsActiveDDR,
    chcs.IsActiveHW,
    chcs.IsActiveSW,
    chcs.IsActivePolicyRequest,
    chcs.IsActiveStatusMessages,
    chcs.LastOnline,
    chcs.LastDDR,
    chcs.LastHW,
    chcs.LastSW,
    chcs.LastPolicyRequest,
    chcs.LastStatusMessage,
    chcs.LastHealthEvaluation,
    chcs.LastHealthEvaluationResult,
    chcs.LastEvaluationHealthy,
    chcs.ClientRemediationSuccess,
    chcs.ExpectedNextPolicyRequest,
    cs.Domain0,
    cs.Manufacturer0,
    cs.Model0,
    cs.UserName0,
    cons.TopConsoleUser0,
    vrs.Last_Logon_Timestamp0,
    os.Caption0,
    os.CSDVersion0,
    os.LastBootUpTime0,
    os.InstallDate0,
    uss.LastWUAVersion,
    uss.LastScanTime,
    chcs.LastHW,
    chcs.LastSW,
    bios.ReleaseDate0,
    se.ChassisTypes0,
    scep.EpInstalled,
    scep.EpManaged,
    scep.EpEnabled,
    ccm.DeploymentEndTime
ORDER BY
    srn.Resource_Names0
