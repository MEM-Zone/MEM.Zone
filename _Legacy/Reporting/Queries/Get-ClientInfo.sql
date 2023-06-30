
DECLARE @Date DATETIME = DATEADD(hh, $LastnDays, GETDATE());
SELECT
    Date              = @Date
    , CMG_Update_Scan = (
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