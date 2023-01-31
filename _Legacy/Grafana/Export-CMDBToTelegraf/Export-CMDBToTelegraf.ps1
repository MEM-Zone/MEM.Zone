<#
.SYNOPSIS
    Exports data from the SCCM database.
.DESCRIPTION
    Exports data from the SCCM database and formats it for telegraf.
.EXAMPLE
    Export-CMDBToTelegraf.ps1 -Server 'SomeSCCMDBServer' -Database 'CM_SomeSiteCode' -ServerCollectionID 'SomeServerCollectionID' -WorkstationCollectionID 'SomeWorkstationCollectionID'
.INPUTS
    None.
.OUTPUTS
    System.String.
.NOTES
    Created by Octavian Cordos & Ioan Popovici
.LINK
    https://SCCM.Zone/Grafana-Dashboards
.LINK
    https://SCCM.Zone/Export-CMDBToTelegraf-CHANGELOG
.LINK
    https://SCCM.Zone/Export-CMDBToTelegraf-GIT
.LINK
    https://SCCM.Zone/Issues
.COMPONENT
    CMDB
.FUNCTIONALITY
    Exports data from CMDB
#>

## Set script requirements
#Requires -Version 3.0

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

## Define script parameters
Param (
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateNotNullorEmpty()]
    [Alias('Srv')]
    [string]$Server,
    [Parameter(Mandatory = $true, Position = 1)]
    [ValidateNotNullorEmpty()]
    [Alias('Dbs')]
    [string]$Database,
    [Parameter(Mandatory = $true, Position = 2)]
    [ValidateNotNullorEmpty()]
    [Alias('SrvCollID')]
    [string]$ServerCollectionID,
    [Parameter(Mandatory = $true, Position = 3)]
    [ValidateNotNullorEmpty()]
    [Alias('WrkCollID')]
    [string]$WorkstationCollectionID
)

## Set connection properties
[hashtable]$ConnectionProps = @{
    'Server' = $Server
    'Database' = $Database
    'ErrorAction' = 'SilentlyContinue'
}

#endregion
##*=============================================
##* END VARIABLE DECLARATION
##*=============================================

##*=============================================
##* FUNCTION LISTINGS
##*=============================================
#region FunctionListings

#region Function Format-Telegraf
Function Format-Telegraf {
<#
.SYNOPSIS
    Formats input object for telegraf.
.DESCRIPTION
    Formats input object for telegraf format.
.PARAMETER InputObject
    Specifies the InputObject.
.PARAMETER Tags
    Specifies the tags to attach.
.PARAMETER AddTimeStamp
    Specifies if a unix time stamp will be added to each row. Defaut is: $false.
.EXAMPLE
    Format-Telegraf -InputObject 'SomeInputObject'
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://SCCM.Zone
.LINK
    https://SCCM.Zone/Git
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $false, ValueFromPipeline = $true, Position = 0)]
        [ValidateNotNullorEmpty()]
        [Alias('Obj')]
        [psobject]$InputObject,
        [Parameter(Mandatory = $false, Position = 1)]
        [Alias('Tags')]
        [string]$TelegrafTags,
        [Parameter(Mandatory = $false, Position = 2)]
        [Alias('TStamp')]
        [switch]$AddTimeStamp
    )
    Begin {

        ## Initialize result variable
        [psobject]$Result = @()
    }
    Process {
        Try {

            ## Get input members
            If ($InputObject) {
                [string[]]$Headers = ($InputObject | Get-Member | Where-Object -Property 'MemberType' -eq 'Property').Name
            }
            Else { $Headers = $null }

            ## Format object
            ForEach ($Row in $InputObject) {
                #  Initialize format variables for every new iteration
                [string]$FormatRowProps = $null
                [string]$FormatRow = $null
                #  Get row data using object headers and format for telegraf
                ForEach ($Header in $Headers) {
                    $FormatRowProps = -join ($Header, '=', $($Row.$Header), ',')
                    $FormatRow = -join ($FormatRow, $FormatRowProps)
                }
                #  Add telegraf tags and remove last ',' from the string
                If ($FormatRow) {
                    #  Add tags if needed
                    If ($TelegrafTags) { $FormatRow = -join ($TelegrafTags, ' ', $FormatRow) }
                    #  Remove last ',' from the string
                    $FormatRow = $FormatRow -replace (".$")
                    #  Add Unix time stamp (UTC)
                    If ($AddTimeStamp) {
                        [string]$UnixTimeStamp = $(([DateTimeOffset](Get-Date)).ToUnixTimeSeconds())
                        $FormatRow = -join ($FormatRow, ' ', $UnixTimeStamp)
                    }
                }
                # Add row to result object
                $Result += $FormatRow
            }
        }
        Catch {
            Write-Error -Message "Formating Error: `n $_.ErrorMessage"
        }
        Finally {

            ## Output result
            Write-Output -InputObject $($Result | Format-Table -HideTableHeaders)
        }
    }
    End {
    }
}
#endregion

#region Function Get-CMDBClientInfo
Function Get-CMDBClientInfo {
<#
.SYNOPSIS
    Gets client information.
.DESCRIPTION
    Gets client information from the SCCM database.
.PARAMETER Server
    Specifies the server name.
.PARAMETER Database
    Specifies the database name.
.PARAMETER LastnDays
    Specifies the how many days in the past to query. Default is: '12'.
.EXAMPLE
    Get-CMDBClientInfo -Server 'SomeServer' -Database 'CM_SomeSiteCode' -LastnDays '12'
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://SCCM.Zone
.LINK
    https://SCCM.Zone/Git
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullorEmpty()]
        [Alias('Srv')]
        [string]$Server,
        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateNotNullorEmpty()]
        [Alias('Dbs')]
        [string]$Database,
        [Parameter(Mandatory = $false, Position = 2)]
        [ValidateNotNullorEmpty()]
        [Alias('Days')]
        [string]$LastnDays = '12'
    )
    Begin {

        ## Add '-' to LastnDays
        [string]$LastnDays = -join ('-', $LastnDays)

        ## Query definition
        [string]$Query =
        "
            DECLARE @Date DATETIME = DATEADD(hh, $LastnDays, GETDATE());
            SELECT
                CMG_Update_Scan = (
                    SELECT COUNT(DISTINCT ResourceID)
                    FROM v_UpdateScanStatus
                    WHERE LastScanTime > @Date
                        AND LastScanPackageLocation LIKE '%cmg%'
                    GROUP BY LastScanPackageLocation
                )
                , CMG_Clients     = (
                    SELECT COUNT(DISTINCT Name)
                    FROM v_CombinedDeviceResources
                    WHERE CNIsOnInternet = 1
                        AND CNIsOnline = 1
                        AND CNAccessMP LIKE '%cmg%'
                )
                , MP_Clients      = (
                    SELECT COUNT(DISTINCT Name)
                    FROM v_CombinedDeviceResources
                    WHERE CNIsOnInternet = 0
                        AND CNIsOnline = 1
                );
        "
    }
    Process {
        Try {

            ## Run SQL query
            [psobject]$Result = Invoke-Sqlcmd -Query $Query -Server $Server -Database $Database -ErrorAction 'Stop'
        }
        Catch {
            Write-Error -Message "Query Error: `n $_.ErrorMessage"
        }
        Finally {

            ## Output result
            Write-Output -InputObject $Result
        }
    }
    End {
    }
}
#endregion

#region Function Get-CMDBDeviceInfo
Function Get-CMDBDeviceInfo {
<#
.SYNOPSIS
    Gets device information.
.DESCRIPTION
    Gets device information from the SCCM database.
.PARAMETER Server
    Specifies the server name.
.PARAMETER Database
    Specifies the database name.
.PARAMETER CollectionID
    Specifies the CollectionID to query.
.EXAMPLE
    Get-CMDBDeviceInfo -Server 'SomeServer' -Database 'CM_SomeSiteCode' -CollectionID 'SomeCollectionID'
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://SCCM.Zone
.LINK
    https://SCCM.Zone/Git
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullorEmpty()]
        [Alias('Srv')]
        [string]$Server,
        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateNotNullorEmpty()]
        [Alias('Dbs')]
        [string]$Database,
        [Parameter(Mandatory = $true, Position = 2)]
        [ValidateNotNullorEmpty()]
        [Alias('CID')]
        [string]$CollectionID
    )
    Begin {

        ## Query definition
        [string]$Query =
        "
            DECLARE @CollectionID NVARCHAR(16)= '$CollectionID';
            DECLARE @UserSIDs NVARCHAR(16)= 'Disabled';
            SELECT
                Client_Version = Systems.Client_Version0
                , Count = COUNT(*)
            FROM fn_rbac_R_System(@UserSIDs) AS SYS
                LEFT JOIN fn_rbac_FullCollectionMembership(@UserSIDs) AS CollectionMembership ON CollectionMembership.ResourceID = Systems.ResourceID
            WHERE Systems.Client0 = 1
                AND CollectionMembership.CollectionID = @CollectionID
            GROUP BY
                Systems.Client_Version0
                , Systems.Client_Type0
            ORDER BY
                Systems.Client_Version0
                , Systems.Client_Type0
        "
    }
    Process {
        Try {

            ## Run SQL query
            [psobject]$Result = Invoke-Sqlcmd -Query $Query -Server $Server -Database $Database -ErrorAction 'Stop'
        }
        Catch {
            Write-Error -Message "Query Error: `n $_.ErrorMessage"
        }
        Finally {

            ## Output result
            Write-Output -InputObject $Result
        }
    }
    End {
    }
}
#endregion

#region Function Get-CMDBDistributionInfo
Function Get-CMDBDistributionInfo {
<#
.SYNOPSIS
    Gets package distribution information.
.DESCRIPTION
    Gets package distribution information from the SCCM database.
.PARAMETER Server
    Specifies the server name.
.PARAMETER Database
    Specifies the database name.
.EXAMPLE
    Get-CMDBDistributionInfo -Server 'SomeServer' -Database 'CM_SomeSiteCode'
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://SCCM.Zone
.LINK
    https://SCCM.Zone/Git
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullorEmpty()]
        [Alias('Srv')]
        [string]$Server,
        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateNotNullorEmpty()]
        [Alias('Dbs')]
        [string]$Database
    )
    Begin {

        ## Query definition
        [string]$Query =
        "
            USE $Database;
            WITH CTE AS (
                SELECT
                    DP_Name         = (
                        UPPER(SUBSTRING(PkgDistribution.ServerNALPath, 13, CHARINDEX('.', PkgDistribution.ServerNALPath) - 13))
                    )
                    , Not_Installed = (
                        COUNT(
                            CASE
                                WHEN PkgDistribution.State NOT IN ('0', '3', '6') THEN '*'
                                ELSE 'Unknown'
                            END
                        )
                    )
                    , Error         = (
                        COUNT(
                            CASE
                                WHEN PkgDistribution.State IN('3', '6') THEN '*'
                            END
                        )
                    )
                    , Status        = (
                        CASE
                            WHEN PkgDistribution.State = '0'                  THEN '1' --'OK'
                            WHEN PkgDistribution.State NOT IN ('0', '3', '6') THEN '2' --'In_Progress'
                            WHEN PkgDistribution.State IN ('3', '6')          THEN '3' --'Error'
                        END
                    )
                FROM dbo.v_PackageStatusDistPointsSumm AS PkgDistribution
                    , dbo.SMSPackages AS Packages
                WHERE Packages.PackageType != 4
                    AND (Packages.PkgID = PkgDistribution.PackageID)
                GROUP BY
                    PkgDistribution.ServerNALPath,
                    PkgDistribution.State
            )
            SELECT
                PKG_Not_Installed = SUM(Not_Installed)
                , PKG_Error       = SUM(Error)
                , DP_OK           = (
                    SELECT COUNT(DP_Name)
                    FROM CTE
                    WHERE Status  = '1'
                )
                , DP_In_Progress  = (
                    SELECT COUNT(DP_Name)
                    FROM CTE
                    WHERE Status  = '2'
                )
                , DP_Error        = (
                    SELECT COUNT(DP_Name)
                    FROM CTE
                    WHERE Status = '3'
                )
            FROM CTE;
        "
    }
    Process {
        Try {

            ## Run SQL query
            [psobject]$Result = Invoke-Sqlcmd -Query $Query -Server $Server -Database $Database -ErrorAction 'Stop'
        }
        Catch {
            Write-Error -Message "Query Error: `n $_.ErrorMessage"
        }
        Finally {

            ## Output result
            Write-Output -InputObject $Result
        }
    }
    End {
    }
}
#endregion

#region Function Get-CMDBDistributionTraffic
Function Get-CMDBDistributionTraffic {
<#
.SYNOPSIS
    Gets package distribution traffic information.
.DESCRIPTION
    Gets package distribution traffic information from the SCCM database.
.PARAMETER Server
    Specifies the server name.
.PARAMETER Database
    Specifies the database name.
.PARAMETER ExcludeBoundaryGroup
    Specifies the boundary group name to exclude. SQL wildcards are supported ('%','_','[]').
.PARAMETER LastnDays
    Specifies the how many days in the past to query. Default is: '7'.
.EXAMPLE
    Get-CMDBDistributionTraffic -Server 'SomeServer' -Database 'CM_SomeSiteCode' -DeviceType 'Server' -LastnDays '7'
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://SCCM.Zone
.LINK
    https://SCCM.Zone/Git
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullorEmpty()]
        [Alias('Srv')]
        [string]$Server,
        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateNotNullorEmpty()]
        [Alias('Dbs')]
        [string]$Database,
        [Parameter(Mandatory = $true, Position = 2)]
        [ValidateNotNullorEmpty()]
        [Alias('ExcludeBG')]
        [string]$ExcludeBoundaryGroup,
        [Parameter(Mandatory = $false, Position = 3)]
        [ValidateNotNullorEmpty()]
        [Alias('Days')]
        [string]$LastnDays = '7'
    )
    Begin {

        ## Add '-' to LastnDays
        $LastnDays = -join ('-', $LastnDays)

        ## Query definition
        [string]$Query =
        "
            DECLARE @StartDate DATE = DATEADD(d, $LastnDays, GETDATE());
            DECLARE @EndDate DATE = GETDATE();
            WITH
                ClientDownloadHistory AS (
                    SELECT
                        DownloadHistory.ID
                        , DownloadHistory.ClientID
                        , DownloadHistory.StartTime
                        , DownloadHistory.BytesDownloaded
                        , DownloadHistory.ContentID
                        , DownloadHistory.DistributionPointType
                        , DownloadHistory.DownloadType
                        , DownloadHistory.HostName
                        , DownloadHistory.BoundaryGroup
                    FROM v_ClientDownloadHistoryDP_BG AS DownloadHistory
                    WHERE DownloadHistory.DownloadType = 0
                        AND DownloadHistory.StartTime >= @StartDate
                        AND (DownloadHistory.StartTime >= @StartDate AND DownloadHistory.StartTime <= @EndDate)
                )
                , ClientDownloadBytes AS (
                    SELECT
                        BoundaryGroup
                        , PeerCacheBytes              = ISNULL(SUM(DownloadBytes.SpBytes), 0)
                        , DistributionPointBytes      = ISNULL(SUM(DownloadBytes.DpBytes), 0)
                        , CloudDistributionPointBytes = ISNULL(SUM(DownloadBytes.CloudDpBytes), 0)
                        , BranchCacheBytes            = ISNULL(SUM(DownloadBytes.BranchCacheBytes), 0)
                        , TotalBytes                  = ISNULL(SUM(DownloadBytes.TotalBytes), 0)
                    FROM (
                        SELECT
                            BoundaryGroup
                            , DistributionPointType
                            , SpBytes           = ISNULL(SUM(IIF(DistributionPointType = 3, BytesDownloaded, 0)), 0)
                            , DpBytes           = ISNULL(SUM(IIF(DistributionPointType = 4, BytesDownloaded, 0)), 0)
                            , BranchCacheBytes  = ISNULL(SUM(IIF(DistributionPointType = 5, BytesDownloaded, 0)), 0)
                            , CloudDpBytes      = ISNULL(SUM(IIF(DistributionPointType = 1, BytesDownloaded, 0)), 0)
                            , TotalBytes        = SUM(BytesDownloaded)
                        FROM ClientDownloadHistory
                        GROUP BY
                            BoundaryGroup
                            , DistributionPointType
                    ) AS DownloadBytes
                    GROUP BY BoundaryGroup
                )
                , Peers(BoundaryGroup, PeerClientCount) AS (
                    SELECT
                        DownloadHistory.BoundaryGroup
                        , COUNT(DISTINCT(ResourceID))
                    FROM v_SuperPeers AS Peers
                        JOIN ClientDownloadHistory AS DownloadHistory ON DownloadHistory.ClientId = Peers.ResourceID
                    GROUP BY DownloadHistory.BoundaryGroup
                )
                , DistributionPoints(BoundaryGroup, CloudDPCount, DPCount) AS (
                    SELECT
                        SiteSystems.GroupId,
                        SUM(IIF(ResourceUse.NALResType = 'Windows Azure', 1, 0)),
                        SUM(IIF(ResourceUse.NALResType <> 'Windows Azure', 1, 0))
                    FROM vSMS_SC_SysResUse AS ResourceUse
                        JOIN vSMS_BoundaryGroupSiteSystems AS SiteSystems ON SiteSystems.ServerNALPath = ResourceUse.NALPath
                    WHERE RoleTypeID = 3
                    GROUP BY SiteSystems.GroupId
                )
            SELECT
                BranchCache_GB   = SUM(ISNULL(ClientDownloadBytes.BranchCacheBytes, 0))            / 1073741824
                , CloudDP_GB     = SUM(ISNULL(ClientDownloadBytes.CloudDistributionPointBytes, 0)) / 1073741824
                , DP_GB          = SUM(ISNULL(ClientDownloadBytes.DistributionPointBytes, 0))      / 1073741824
                , PeerCache_GB   = SUM(ISNULL(ClientDownloadBytes.PeerCacheBytes, 0))              / 1073741824
            FROM BoundaryGroup
                LEFT JOIN Peers ON Peers.BoundaryGroup = BoundaryGroup.GroupID
                LEFT JOIN DistributionPoints ON DistributionPoints.BoundaryGroup = BoundaryGroup.GroupID
                LEFT JOIN ClientDownloadBytes ON ClientDownloadBytes.BoundaryGroup = BoundaryGroup.GroupID
            WHERE ClientDownloadBytes.TotalBytes > 0
                AND BoundaryGroup.Name NOT LIKE `'$ExcludeBoundaryGroup`'
        "
    }
    Process {
        Try {

            ## Run SQL query
            $Result = Invoke-Sqlcmd -Query $Query -Server $Server -Database $Database -ErrorAction 'Stop'
        }
        Catch {
            Write-Error -Message "Query Error: `n $_.ErrorMessage"
        }
        Finally {

            ## Output result
            Write-Output -InputObject $Result
        }
    }
    End {
    }
}
#endregion

#region Function Get-CMDBOSInfo
Function Get-CMDBOSInfo {
<#
.SYNOPSIS
    Gets operating system information.
.DESCRIPTION
    Gets operating system information from the SCCM database.
.PARAMETER Server
    Specifies the server name.
.PARAMETER Database
    Specifies the database name.
.EXAMPLE
    Get-CMDBOSInfo -Server 'SomeServer' -Database 'CM_SomeSiteCode'
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://SCCM.Zone
.LINK
    https://SCCM.Zone/Git
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullorEmpty()]
        [Alias('Srv')]
        [string]$Server,
        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateNotNullorEmpty()]
        [Alias('Dbs')]
        [string]$Database
    )
    Begin {

        ## Query definition
        [string]$Query =
        "
            WITH CTE AS (
                SELECT
                    OS          = (
                        CASE
                            WHEN Systems.Operating_System_Name_And0 LIKE '%Workstation 5.%'             THEN 'WindowsXP'
                            WHEN Systems.Operating_System_Name_And0 LIKE '%Workstation 6.0%'            THEN 'WindowsVista'
                            WHEN Systems.Operating_System_Name_And0 LIKE '%Workstation 6.1%'            THEN 'Windows7'
                            WHEN Systems.Operating_System_Name_And0 LIKE 'Windows_7 Entreprise 6.1'     THEN 'Windows7'
                            WHEN Systems.Operating_System_Name_And0 = 'Windows Embedded Standard 6.1'   THEN 'Windows7'
                            WHEN Systems.Operating_System_Name_And0 LIKE '%Workstation 6.2%'            THEN 'Windows8'
                            WHEN Systems.Operating_System_Name_And0 LIKE '%Workstation 6.3%'            THEN 'Windows8_1'
                            WHEN Systems.Operating_System_Name_And0 LIKE '%Workstation 10%'             THEN 'Windows10'
                            WHEN Systems.Operating_System_Name_And0 LIKE '%Workstation 10%'             THEN 'Windows10'
                            WHEN Systems.Operating_System_Name_And0 LIKE '%Server 5.%'                  THEN 'WindowsServer2003'
                            WHEN Systems.Operating_System_Name_And0 LIKE '%Server 6.0%'                 THEN 'WindowsServer2008'
                            WHEN Systems.Operating_System_Name_And0 LIKE '%Server 6.1%'                 THEN 'WindowsServer2008R2'
                            WHEN Systems.Operating_System_Name_And0 LIKE '%Server 6.2%'                 THEN 'WindowsServer2012'
                            WHEN Systems.Operating_System_Name_And0 LIKE '%Server 6.3%'                 THEN 'WindowsServer2012R2'
                            WHEN Systems.Operating_System_Name_And0 LIKE '%Server 10%'                  THEN (
                                CASE
                                    WHEN CAST(REPLACE(Build01, '.', '') AS INT) > 10017763 THEN 'WindowsServer2019'
                                    ELSE 'WindowsServer2016'
                                END
                            )
                            ELSE Systems.Operating_System_Name_And0
                        END
                    )
                    , OSVersion = (
                        CASE
                            WHEN Systems.Operating_System_Name_And0 LIKE '%Workstation 10%' THEN (
                                CASE REPLACE(Systems.Build01, '.', '')
                                    WHEN '10010240' THEN '1507'
                                    WHEN '10010586' THEN '1511'
                                    WHEN '10014393' THEN '1607'
                                    WHEN '10015063' THEN '1703'
                                    WHEN '10016299' THEN '1709'
                                    WHEN '10017134' THEN '1803'
                                    WHEN '10017763' THEN '1809'
                                    ELSE 'N/A'
                                END
                            )
                            WHEN Systems.Operating_System_Name_And0 LIKE '%Server 10%'      THEN (
                                CASE REPLACE(Systems.Build01, '.', '')
                                    WHEN '10014393' THEN '1607'
                                    WHEN '10016299' THEN '1709'
                                    WHEN '10017134' THEN '1803'
                                    WHEN '10017763' THEN '1809'
                                    ELSE 'N/A'
                                END
                            )
                            ELSE 'N/A'
                        END
                    )
                    , OSCount   = COUNT(DISTINCT Systems.Name0)
                    , Build01   = ISNULL(Systems.Build01, 0)
                FROM V_R_System AS Systems
                WHERE Systems.Operating_System_Name_And0 != 'Unknown Unknown'
                GROUP BY
                    Operating_System_Name_And0
                    , Build01
            )
            SELECT DISTINCT
                OS
                , OSVersion
                , OSType = (
                    CASE
                        WHEN OS LIKE 'WindowsServer%' THEN 'Server'
                        WHEN OS LIKE 'Windows%' THEN 'Workstation'
                        ELSE 'Unknown'
                    END
                )
                , Count  = (
                    SELECT SUM(OSCount) FROM CTE AS Summary WHERE Summary.OS = CTE.OS and Summary.OSVersion = CTE.OSVersion
                )
            FROM CTE
            GROUP BY
                OS
                , OSVersion
                , Build01
            ORDER BY
                OS
                , OSVersion
        "
    }
    Process {
        Try {

            ## Run SQL query
            [psobject]$Result = Invoke-Sqlcmd -Query $Query -Server $Server -Database $Database -ErrorAction 'Stop'
        }
        Catch {
            Write-Error -Message "Query Error: `n $_.ErrorMessage"
        }
        Finally {

            ## Output result
            Write-Output -InputObject $Result
        }
    }
    End {
    }
}
#endregion

#endregion
##*=============================================
##* END FUNCTION LISTINGS
##*=============================================

##*=============================================
##* SCRIPT BODY
##*=============================================
#region ScriptBody

## Get CMDB Data
$CMDBClientInfo             = Get-CMDBClientInfo            @ConnectionProps
$CMDBDeviceInfoServers      = Get-CMDBDeviceInfo            @ConnectionProps -CollectionID $ServerCollectionID
$CMDBDeviceInfoWorkstations = Get-CMDBDeviceInfo            @ConnectionProps -CollectionID $WorkstationCollectionID
$CMDBDistributionInfo       = Get-CMDBDistributionInfo      @ConnectionProps
$CMDBDistributionTraffic    = Get-CMDBDistributionTraffic   @ConnectionProps -ExcludeBoundaryGroup 'Workstation' -LastnDays '7'
$CMDBOSInfo                 = Get-CMDBOSInfo                @ConnectionProps

## Format data for telegraf
$CMDBClientInfo             | Format-Telegraf -ErrorAction 'SilentlyContinue'
$CMDBDeviceInfoServers      | Format-Telegraf -ErrorAction 'SilentlyContinue' -TelegrafTags 'Servers,'
$CMDBDeviceInfoWorkstations | Format-Telegraf -ErrorAction 'SilentlyContinue' -TelegrafTags 'Workstations,'
$CMDBDistributionInfo       | Format-Telegraf -ErrorAction 'SilentlyContinue' -TelegrafTags 'DistributionPoints' -AddTimeStamp
$CMDBDistributionTraffic    | Format-Telegraf -ErrorAction 'SilentlyContinue' -TelegrafTags 'Content_WKS'
$CMDBOSInfo                 | Format-Telegraf -ErrorAction 'SilentlyContinue'

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================