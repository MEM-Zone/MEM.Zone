/*
.SYNOPSIS
    Gets SQL product info.
.DESCRIPTION
    Gets SQL product info, id and product key.
.NOTES
    Created by Ioan Popovici.
    Requires the usp_PivotWithDynamicColumns stored procedure (SQL Support Functions).
    Requires SQL Property and ProductID HWI extensions.
    Part of a report should not be run separately.
.LINK
    https://SCCM.Zone/SW-SQL-Server-Products
.LINK
    https://SCCM.Zone/SQL-SupportFunctions
.LINK
    https://SCCM.Zone/SW-SQL-Server-Products-CHANGELOG
.LINK
    https://SCCM.Zone/SW-SQL-Server-Products-GIT
.LINK
    https://SCCM.Zone/Issues
*/

/*##=============================================*/
/*## QUERY BODY                                  */
/*##=============================================*/
/* #region QueryBody */

/* Test variable declaration !! Need to be commented for Production !! */
-- DECLARE @UserSIDs          AS NVARCHAR(10) = 'Disabled';
-- DECLARE @CollectionID      AS NVARCHAR(10) = 'SMS00001';
-- DECLARE @Filter            AS NVARCHAR(20) = 'WID';

/* Variable declaration */
DECLARE @TableName         AS NVARCHAR(MAX);
DECLARE @NonPivotedColumn  AS NVARCHAR(MAX);
DECLARE @DynamicColumn     AS NVARCHAR(MAX);
DECLARE @AggregationColumn AS NVARCHAR(MAX);
DECLARE @StaticColumnList  AS NVARCHAR(MAX);

/* Perform cleanup */
IF OBJECT_ID('tempdb..#SQLProducts', 'U') IS NOT NULL
    DROP TABLE #SQLProducts;

/* Create SQLProducts table */
CREATE TABLE #SQLProducts (
    ResourceID          NVARCHAR(25)
    , SKUName           NVARCHAR(100)
    , [Version]         NVARCHAR(25)
    , FileVersion       NVARCHAR(50)
    , SPLevel           NVARCHAR(2)
    , IsClustered       NVARCHAR(3)
    , SQMReporting      NVARCHAR(3)
)

/* Create SQLRelease table */
DECLARE @SQLRelease Table (FileVersion NVARCHAR(4), Release NVARCHAR(10))

/* Populate StaticColumnList */
SET @StaticColumnList = N'[SKUNAME],[VERSION],[FILEVERSION],[SPLEVEL],[CLUSTERED],[SQMREPORTING]'

/* Populate SQLRelease table */
INSERT INTO @SQLRelease (FileVersion, Release)
VALUES
    ('2019', '2019')
    , ('2017', '2017')
    , ('2016', '2017')
    , ('2015', '2016')
    , ('2014', '2014')
    , ('2013', '2014')
    , ('2012', '2012')
    , ('2011', '2012')
    , ('2010', '2012')
    , ('2009', '2008 R2')
    , ('2007', '2008')
    , ('2005', '2005')
    , ('2000', '2000')
    , ('',     'Unknown')

/* Get SQL 2019 data */
INSERT INTO #SQLProducts
EXECUTE dbo.usp_PivotWithDynamicColumns
    @TableName           = N'dbo.v_GS_EXT_SQL_2019_Property0'
    , @NonPivotedColumn  = N'ResourceID'
    , @DynamicColumn     = N'PropertyName0'
    , @AggregationColumn = N'ISNULL(PropertyStrValue0, PropertyNumValue0)'
	, @StaticColumnList  = @StaticColumnList;

/* Get SQL 2017 data */
INSERT INTO #SQLProducts
EXECUTE dbo.usp_PivotWithDynamicColumns
    @TableName           = N'dbo.v_GS_EXT_SQL_2017_Property0'
    , @NonPivotedColumn  = N'ResourceID'
    , @DynamicColumn     = N'PropertyName0'
    , @AggregationColumn = N'ISNULL(PropertyStrValue0, PropertyNumValue0)'
	, @StaticColumnList  = @StaticColumnList;

/* Get SQL 2016 data */
INSERT INTO #SQLProducts
EXECUTE dbo.usp_PivotWithDynamicColumns
    @TableName           = N'dbo.v_GS_EXT_SQL_2016_Property0'
    , @NonPivotedColumn  = N'ResourceID'
    , @DynamicColumn     = N'PropertyName0'
    , @AggregationColumn = N'ISNULL(PropertyStrValue0, PropertyNumValue0)'
    , @StaticColumnList  = @StaticColumnList;

/* Get SQL 2014 data data */
INSERT INTO #SQLProducts
EXECUTE dbo.usp_PivotWithDynamicColumns
    @TableName           = N'dbo.v_GS_EXT_SQL_2014_Property0'
    , @NonPivotedColumn  = N'ResourceID'
    , @DynamicColumn     = N'PropertyName0'
    , @AggregationColumn = N'ISNULL(PropertyStrValue0, PropertyNumValue0)'
    , @StaticColumnList  = @StaticColumnList;

/* Get SQL 2012 data */
INSERT INTO #SQLProducts
EXECUTE dbo.usp_PivotWithDynamicColumns
    @TableName           = N'dbo.v_GS_EXT_SQL_2012_Property0'
    , @NonPivotedColumn  = N'ResourceID'
    , @DynamicColumn     = N'PropertyName0'
    , @AggregationColumn = N'ISNULL(PropertyStrValue0, PropertyNumValue0)'
    , @StaticColumnList  = @StaticColumnList;

/* Get SQL 2008 data */
INSERT INTO #SQLProducts
EXECUTE dbo.usp_PivotWithDynamicColumns
    @TableName           = N'dbo.v_GS_EXT_SQL_2008_Property0'
    , @NonPivotedColumn  = N'ResourceID'
    , @DynamicColumn     = N'PropertyName0'
    , @AggregationColumn = N'ISNULL(PropertyStrValue0, PropertyNumValue0)'
    , @StaticColumnList  = @StaticColumnList;

/* Get SQL Legacy data */
INSERT INTO #SQLProducts
EXECUTE dbo.usp_PivotWithDynamicColumns
    @TableName           = N'dbo.v_GS_EXT_SQL_Legacy_Property0'
    , @NonPivotedColumn  = N'ResourceID'
    , @DynamicColumn     = N'PropertyName0'
    , @AggregationColumn = N'ISNULL(PropertyStrValue0, PropertyNumValue0)'
    , @StaticColumnList  = @StaticColumnList;

/* Aggregate result data */
WITH SQLProducts_CTE (Release, EditionGroup, [Edition], [Version], ServicePack, CUVersion, IsClustered, Bitness, CEIPReporting, ProductKey, Device, DomainOrWorkgroup, OperatingSystem, IsVirtualMachine, CPUs, PhysicalCores, LogicalCores)
AS (
    SELECT
        Release             = (
            'SQL ' + (SELECT Release FROM @SQLRelease WHERE FileVersion = LEFT(SQLProducts.FileVersion, 4))
        )
        , EditionGroup      = (
            CASE
                WHEN SQLProducts.SKUName LIKE '%enter%' THEN 'Enterprise'
                WHEN SQLProducts.SKUName LIKE '%stand%' THEN 'Standard'
                WHEN SQLProducts.SKUName LIKE '%expre%' THEN 'Express'
                WHEN SQLProducts.SKUName LIKE '%devel%' THEN 'Developer'
                WHEN SQLProducts.SKUName LIKE '%windo%' THEN 'WID'
                WHEN SQLProducts.SKUName IS NULL        THEN 'N/A'
                ELSE 'Legacy'
            END
        )
        , [Edition]         = ISNULL(NULLIF(SQLProducts.SKUName, ''), 'N/A')
        , [Version]         = SQLProducts.[Version]
        , ServicePack       = SQLProducts.SPLevel
        , CUVersion         = SQLProducts.FileVersion
        , IsClustered       = (
            CASE SQLProducts.IsClustered
                WHEN 0 THEN 'No'
                WHEN 1 THEN 'Yes'
                ELSE NULL
            END
        )
        , Bitness           = (
            CASE
                WHEN SQLProducts.SKUName LIKE '%64%' THEN 'x64'
                WHEN SQLProducts.SKUName IS NOT NULL THEN 'x86'
                ELSE 'N/A'
            END
        )
        , CEIPReporting     = (
            CASE SQLProducts.SQMReporting
                WHEN 0 THEN 'No'
                WHEN 1 THEN 'Yes'
                ELSE NULL
            END
        )
        , ProductKey        = ISNULL(SQLProductID.DigitalProductID0, 'N/A')
        , Device            = Devices.[Name]
        , DomainOrWorkgroup = ISNULL(Systems.Full_Domain_Name0, Systems.Resource_Domain_Or_Workgr0)
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
        , IsVirtualMachine  = (
            CASE Devices.IsVirtualMachine
                WHEN 0 THEN 'No'
                WHEN 1 THEN 'Yes'
                ELSE NULL
            END
        )
        , CPUs              = COUNT(Processor.ResourceID)
        , PhysicalCores     = SUM(Processor.NumberOfCores0)
        , LogicalCores      = SUM(Processor.NumberOfLogicalProcessors0)
    FROM fn_rbac_FullCollectionMembership(@UserSIDs) AS CollectionMembers
        JOIN v_R_System AS Systems ON Systems.ResourceID = CollectionMembers.ResourceID
        JOIN v_CombinedDeviceResources AS Devices ON Devices.MachineID = CollectionMembers.ResourceID
        JOIN v_GS_PROCESSOR AS Processor ON Processor.ResourceID = CollectionMembers.ResourceID
        JOIN #SQLProducts AS SQLProducts ON SQLProducts.ResourceID = CollectionMembers.ResourceID
        LEFT JOIN dbo.v_GS_EXT_SQL_PRODUCTID0 AS SQLProductID ON SQLProductID.ResourceID = SQLProducts.ResourceID
            AND SQLProductID.Release0 = (
                SELECT Release FROM @SQLRelease WHERE FileVersion = LEFT(SQLProducts.FileVersion, 4)
            )
            AND SQLProductID.ProductID0 IS NOT NULL
    WHERE CollectionMembers.CollectionID = @CollectionID
    GROUP BY
        SQLProducts.FileVersion
        , SQLProducts.SKUName
        , SQLProducts.[Version]
        , SQLProducts.SPLevel
        , SQLProducts.IsClustered
        , SQLProducts.SQMReporting
        , SQLProductID.DigitalProductID0
        , Devices.[Name]
        , Systems.Full_Domain_Name0
        , Systems.Resource_Domain_Or_Workgr0
        , Systems.Operating_System_Name_and0
        , Systems.Build01
        , Devices.IsVirtualMachine
        , Processor.NumberOfCores0
        , Processor.NumberOfLogicalProcessors0
)

/* Filter results */
SELECT
    Release
    , EditionGroup
    , [Edition]
    , [Version]
    , ServicePack
    , CUVersion
    , IsClustered
    , Bitness
    , CEIPReporting
    , ProductKey
    , Device
    , DomainOrWorkgroup
    , OperatingSystem
    , IsVirtualMachine
    , CPUs
    , PhysicalCores
    , LogicalCores
FROM SQLProducts_CTE
WHERE EditionGroup NOT IN (@Filter)

/* Perform cleanup */
IF OBJECT_ID('tempdb..#SQLProducts', 'U') IS NOT NULL
    DROP TABLE #SQLProducts;

/* #endregion */
/*##=============================================*/
/*## END QUERY BODY                              */
/*##=============================================*/