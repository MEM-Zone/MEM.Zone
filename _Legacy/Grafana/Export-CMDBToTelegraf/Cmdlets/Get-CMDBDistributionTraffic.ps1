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
            DECLARE @CollectionID NVARCHAR(16)= '$CollectionID';
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
                AND BoundaryGroup.Name NOT LIKE @CollectionID
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