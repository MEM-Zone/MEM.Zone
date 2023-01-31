

$UpdatesToRemove =  @(
    890830,
    2589382,
    2952664,
    3101522,
    3118310,
    3118388,
    3118389,
    3128031,
    3191839,
    3191840,
    3191841,
    3191843,
    3191844,
    3191847,
    3191848,
    3191899,
    3191902,
    3191904,
    3191906,
    3191907,
    3191908,
    3203458,
    3203459,
    3203460,
    3203461,
    3203463,
    3203464,
    3203466,
    3203467,
    3203468,
    3203469,
    3213624,
    4014985,
    4015546,
    4018271,
    4019108,
    4019112,
    4019263,
    4019264,
    4019265,
    4019288,
    4020322,
    4021558,
    4022168,
    4022719,
    4022722,
    4025252,
    4025337,
    4025341
)

$InstalledUpdates = (Get-Hotfix | Select-Object -ExpandProperty HotFixID).Replace('KB','')

$InstalledUpdates | ForEach-Object {
    If ($_ -in $UpdatesToRemove) {

        Write-Host "KB$_ Found - Uninstall Starting..." -ForegroundColor 'Yellow' -BackgroundColor 'Black'
        Start-Process -FilePath 'wusa.exe' -ArgumentList "/uninstall /quiet /KB:$_ /norestart" -Wait
        If (Get-Hotfix -ID $('KB'+$_) -ErrorAction SilentlyContinue) {
            Write-Host "KB$_ Uninstall - Failed" -ForegroundColor 'Red' -BackgroundColor 'Black'
        }
        Else {
            Write-Host "KB$_ Uninstall - Success" -ForegroundColor 'Yellow' -BackgroundColor 'Black'
        }
    }
    Else {
        ## Update Not Found! Do Nothing
        #  For testing only
        #  Write-Host "KB$_ - Found" -ForegroundColor 'Yellow' -BackgroundColor 'Black'
    }
}
