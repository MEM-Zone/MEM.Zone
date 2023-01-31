
$LastFullbackupSB = {
    SQLCMD.exe -Q "SELECT top 1 LastFullbackup FROM (
        SELECT DatabaseName = db.name,
        	LastFullbackup = (
                SELECT TOP 1 s.backup_start_date FROM msdb.dbo.backupset s WHERE s.database_name=db.name and s.[Type]='D' order by s.backup_start_date DESC
            ),
        	LastLogBackup = (
                SELECT TOP 1 s.backup_start_date FROM msdb.dbo.backupset s WHERE s.database_name=db.name and s.[Type]='L' order by s.backup_start_date DESC
            )
        FROM Sys.databases db
        WHERE db.name NOT IN ('tempdb')
    ) AS Temp
    ORDER BY LastFullbackup"
}

[DateTime]$LastFullbackup = (Invoke-Command -ScriptBlock $LastFullbackupSB)[2]
