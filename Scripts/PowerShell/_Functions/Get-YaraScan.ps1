$MalwareCampaign = 'Ramnit_and_IranianAPTs_campaigns'
$LogPath = Join-Path -Path $env:ProgramFiles -ChildPath "Yara\Logs\$MalwareCampaign"
$DiskDrives = Get-CimInstance -ClassName 'MSFT_PhysicalDisk' -Namespace 'root\Microsoft\Windows\Storage' -ErrorAction 'SilentlyContinue'
$DiskDrivesType = $DiskDrives | Select-Object -Property 'SerialNumber', 'FriendlyName', @{
    Name = 'MediaType'
    Expression = {
        Switch ($_.MediaType) {
            0 { 'Unspecified' }
            3 { 'HDD' }
            4 { 'SSD' }
            5 { 'SCM' }
        }
    }
}

$PhysicalMemory = $(Get-CimInstance -ClassName 'Win32_PhysicalMemory' | Measure-Object -Property 'Capacity' -Sum ).Sum / 1GB
$Win32_LogicalDisk = Get-CimInstance -ClassName 'Win32_LogicalDisk' | Where-Object -Property 'Volume' -eq $env:SystemDrive
$SystemDriveUsedSpace = [Math]::Round(($Win32_LogicalDisk.Size - $Win32_LogicalDisk.Freespace) / 1GB, 2)

#? If ($DiskDrives) { $diskdrivetype = "$($diskdrive.mediatype)"}

$ErrorActionPreference = 'SilentlyContinue'

If (Test-Path $LogPath) {
    $StartScanLog     = Get-Content -Path "$LogPath\yara_start_$MalwareCampaign.log"
    $MemoryLog        = Get-Content -Path "$LogPath\yara_mem_$MalwareCampaign.log"
    $DiskLog          = Get-Content -Path "$LogPath\yara_disk_$MalwareCampaign.log"
    $FinishScanLog    = Get-Content -Path "$LogPath\yara_finish_$MalwareCampaign.log"
    $DiskLogSentLog   = Get-Content -Path "$LogPath\disk_log_sent.log"
    $MemoryLogSentLog = Get-Content -Path "$LogPath\mem_log_sent.log"
    $SendErrorsLog = Get-Content -Path "$LogPath\logs_sending_errors.log"

    If (-not [string]::IsNullOrEmpty($SendErrorsLog)) {
        $SendErrors = ForEach ($Line in $SendErrorsLog) {
            If ($Line -like '*Failed to send*') { [PSCustomObject]@{ Error = $Line.Split(' ', 2)[1] } }
        }
    }
    If (-not [string]::IsNullOrEmpty($StartScanLog)) {
        ForEach ($Line in $StartScanLog) {
            If ($Line -like "*Starting Yara disk scan on C:\*") {
                [datetime]$DiskScanStart = $_.Split()[0]
            }
            If ($Line -like "*Yara disk scan on C:\ disk is finished*") {
                [datetime]$diskscansfinish = $_.split()[0]
            }
            If ($Line -like "*Starting Yara memory scan!*") {
                [datetime]$memscanstart = $_.split()[0]
            }
            If ($Line -like "*Finished scanning*") {
                [datetime]$memscansfinish = $_.split()[0]
            }
        }
    }
    If ($diskscansfinish) {
        $diskscantime = $diskscansfinish - $diskscanstart
        $diskscantimestr = "Disk scan took $($diskscantime)"
    }
    If ($memscansfinish) {
        $memscantime = $memscansfinish - $memscanstart
        $memscantimestr = "Mem scan took $($memscantime)"
    }
    If ($disk) {
                If ($disk.Length -eq 0) {$DiskStatus="Disk OK" }
                Else {$DiskStatus="Disk Not OK" }
                If ($disklogsent) {$disklogsentStatus ="Disk log sent"}
                Else {$disklogsentStatus ="Disk log NOT sent"}
    } Else {$DiskStatus = "Disk Log not found"}
    If ($memory) {
                If ($memory.Length -eq 0) {$MemoryStatus="Memory OK" }
                Else {$MemoryStatus ="Memory Not OK"}
                If ($memlogsent) {$memlogsenttStatus ="Memory log sent"}
                Else {$memlogsenttStatus ="Memory log NOT sent"}
    } Else {$MemoryStatus = "Memory Log not found"}
    If ($start) {
        If ($finish) {
        #$finish | select *
            $scantime = $finish.CreationTimeutc - $start.CreationTimeutc
            $scanstarttimeutc = "Scan start time (UTC) $($start.CreationTimeutc)"
            $scantimestr = "Scan took $($scantime)"
            $Scanstatus = "Scan Completed"
        } Else {$Scanstatus = "Scan NOT Completed"}
    } Else {$Scanstatus = "Scan NOT Started yet"}
} Else { $Scanstatus = "Scan NOT Started yet"}
If (($DiskStatus -eq "Disk Not OK" -or $MemoryStatus -eq "Memory Not OK") -and (!$disklogsent -or !$memlogsent)) {
    Write-Host "Memory $($PhysicalRAM)GB; Used Space on C: $($Cusedspace)GB; $diskdrivetype; $Scanstatus; $scanstarttimeutc; $scantimestr; $diskscantimestr; $memscantimestr; $DiskStatus; $disklogsentStatus; $MemoryStatus; $memlogsenttStatus; $logssendingerror; $disklogcontent; $memlogcontent"

} Else {
    Write-Host "Memory $($PhysicalRAM)GB; Used Space on C: $($Cusedspace)GB; $diskdrivetype; $Scanstatus; $scanstarttimeutc; $scantimestr; $diskscantimestr; $memscantimestr; $DiskStatus; $disklogsentStatus; $MemoryStatus; $memlogsenttStatus"
}