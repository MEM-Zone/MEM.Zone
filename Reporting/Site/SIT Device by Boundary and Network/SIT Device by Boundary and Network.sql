/*
.SYNOPSIS
    List devices by boundary and network information.
.DESCRIPTION
    List devices by boundary group, boundary and network information.
.NOTES
    Created by Ioan Popovici
    Part of a report should not be run separately.
    Requires
        CM_Tools.dbo.ufn_IsIPInSubnet
        CM_Tools.dbo.ufn_IsIPInRange
        CM_Tools.dbo.ufn_CIDRFromIPMask
.LINK
    https://SCCM.Zone/SIT-Devices-by-Boundary-and-Network
.LINK
    https://SCCM.Zone/SIT-Devices-by-Boundary-and-Network-CHANGELOG
.LINK
    https://SCCM.Zone/SIT-Devices-by-Boundary-and-Network-GIT
.LINK
    https://SCCM.Zone/Issues
*/

/*##=============================================*/
/*## QUERY BODY                                  */
/*##=============================================*/

/* Testing variables !! Need to be commented for Production !! */
--DECLARE @UserSIDs       AS NVARCHAR(10) = 'Disabled';
--DECLARE @CollectionID   AS NVARCHAR(10) = 'HUB0074A';
--DECLARE @Locale         AS INTEGER      = '2';

/* Variable declaration */
DECLARE @LCID AS INTEGER = dbo.fn_LShortNameToLCID (@Locale);

WITH BoundaryData_CTE (Occurrences, Device, Managed, OperatingSystem, DomainOrWorkgroup, ADSite, SCCMSite, SCCMSiteCode, BoundaryGroup, Boundary, IPAddress, IPSubnet, IPSubnetMask)
AS (

    /* Get boundary data */
    SELECT
        Occurrences         = Count(*) OVER (PARTITION BY Systems.ResourceID)   -- Count ResourceID occurrences
        , Device            = ISNULL(NULLIF(Systems.NetBios_Name0, '-'), 'N/A')
        , Managed           = (
            CASE Systems.Client0
                WHEN 1 THEN 'Yes'
                ELSE 'No'
            END
        )
        , OperatingSystem   = (

            /* Get OS caption by version */
            CASE
                WHEN Systems.Operating_System_Name_And0 LIKE '%Workstation 5.%'              THEN 'Windows XP'
                WHEN Systems.Operating_System_Name_And0 LIKE '%Workstation 6.0%'             THEN 'Windows Vista'
                WHEN Systems.Operating_System_Name_And0 LIKE '%Workstation 6.1%'             THEN 'Windows 7'
                WHEN Systems.Operating_System_Name_And0 LIKE 'Windows_7 Entreprise 6.1'      THEN 'Windows 7'
                WHEN Systems.Operating_System_Name_And0 =    'Windows Embedded Standard 6.1' THEN 'Windows 7'
                WHEN Systems.Operating_System_Name_And0 LIKE '%Workstation 6.2%'             THEN 'Windows 8'
                WHEN Systems.Operating_System_Name_And0 LIKE '%Workstation 6.3%'             THEN 'Windows 8.1'
                WHEN Systems.Operating_System_Name_And0 LIKE '%Workstation 10%'              THEN 'Windows 10'
                WHEN Systems.Operating_System_Name_And0 LIKE '%Workstation 10%'              THEN 'Windows 10'
                WHEN Systems.Operating_System_Name_And0 LIKE '%Server 5.%'                   THEN 'Windows Server 2003'
                WHEN Systems.Operating_System_Name_And0 LIKE '%Server 6.0%'                  THEN 'Windows Server 2008'
                WHEN Systems.Operating_System_Name_And0 LIKE '%Server 6.1%'                  THEN 'Windows Server 2008 R2'
                WHEN Systems.Operating_System_Name_And0 LIKE '%Server 6.2%'                  THEN 'Windows Server 2012'
                WHEN Systems.Operating_System_Name_And0 LIKE '%Server 6.3%'                  THEN 'Windows Server 2012 R2'
                WHEN Systems.Operating_System_Name_And0 LIKE '%Server 10%'                   THEN (
                    CASE
                        WHEN CAST(REPLACE(Build01, '.', '') AS INTEGER) > 10017763 THEN 'Windows Server 2019'
                        ELSE 'Windows Server 2016'
                    END
                )
                ELSE Systems.Operating_System_Name_And0
            END
        )
        , DomainOrWorkgroup = ISNULL(Systems.Full_Domain_Name0, Systems.Resource_Domain_Or_Workgr0)
        , ADSite            = CombinedResources.ADSiteName
        , SCCMSite          = Sites.SiteName
        , SCCMSiteCode      = CombinedResources.SiteCode
        , BoundaryGroup     = ISNULL(BoundaryGroup.Name, 'N/A')
        , Boundary          = ISNULL(Boundary.DisplayName, 'N/A')
        , IPAddress         = Network.IPAddress0
        , IPSubnet          = (
            CASE
                /* Support function */
                WHEN CM_Tools.dbo.ufn_IsIPInSubnet(Network.IPAddress0, Subnets.IP_Subnets0, Network.IPSubnet0) = 1
                THEN Subnets.IP_Subnets0
                ELSE NULL
            END
        )
        , IPSubnetMask      = (
            CASE
                /* Support function */
                WHEN CM_Tools.dbo.ufn_IsIPInSubnet(Network.IPAddress0, Subnets.IP_Subnets0, Network.IPSubnet0) = 1
                /* Support function */
                THEN Network.IPSubnet0 + CM_Tools.dbo.ufn_CIDRFromIPMask(Network.IPSubnet0) -- Add CIDR to the IP subnet
                ELSE NULL
            END
        )
    FROM fn_rbac_FullCollectionMembership(@UserSIDs) AS CollectionMembers
        LEFT JOIN v_R_System AS Systems ON Systems.ResourceID = CollectionMembers.ResourceID
        LEFT JOIN v_CombinedDeviceResources AS CombinedResources ON CombinedResources.MachineID = CollectionMembers.ResourceID
        LEFT JOIN v_Site AS Sites ON Sites.SiteCode = CombinedResources.SiteCode
        LEFT JOIN v_Network_DATA_Serialized AS Network ON Network.ResourceID = CollectionMembers.ResourceID
            AND IPEnabled0 = 1                               -- Exclude non-enabled adapters
            AND Network.IPAddress0 NOT LIKE '%:%'            -- Exclude IPv6
        LEFT JOIN v_RA_System_IPSubnets AS Subnets ON Subnets.ResourceID = CollectionMembers.ResourceID
        INNER JOIN vSMS_Boundary AS Boundary ON
            (
                CASE
                    WHEN Boundary.BoundaryType = 0
                    /* Support function */
                    THEN CM_Tools.dbo.ufn_IsIPInSubnet(Network.IPAddress0, Boundary.Value, Network.IPSubnet0)
                    WHEN Boundary.BoundaryType = 1 AND Boundary.Value = CombinedResources.ADSiteName
                    THEN 1
                    WHEN Boundary.BoundaryType = 3
                    /* Support function */
                    THEN CM_Tools.dbo.ufn_IsIPInRange(Network.IPAddress0, Boundary.Value)
                END
            ) = 1 -- Join only if the Boundary value matches ADSiteName or is in the computer subnet or subnet range.
        INNER JOIN vSMS_BoundaryGroupMembers AS BoundaryRelation ON BoundaryRelation.BoundaryID = Boundary.BoundaryID
        INNER JOIN vSMS_BoundaryGroup AS BoundaryGroup ON BoundaryGroup.GroupID = BoundaryRelation.GroupID
    WHERE CollectionMembers.CollectionID = @CollectionID
)

/* Remove rows that have no subnet only when a ResourceID is present more than once in the result */
SELECT
    Device
    , Managed
    , OperatingSystem
    , DomainOrWorkgroup
    , ADSite
    , SCCMSite
    , SCCMSiteCode
    , BoundaryGroup
    , Boundary
    , IPAddress
    , IPSubnet
    , IPSubnetMask
FROM BoundaryData_CTE AS BoundaryData
WHERE (
    (BoundaryData.Occurrences > 1 AND BoundaryData.IPSubnet IS NOT NULL) -- Remove all rows that have no subnet
    OR
    (BoundaryData.Occurrences = 1)                                       -- Keep at least one occurrence, even if the subnet is NULL
)

/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/
