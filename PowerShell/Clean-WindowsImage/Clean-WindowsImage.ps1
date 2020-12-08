<#
.SYNOPSIS
    Cleans the image before SysPrep.
.DESCRIPTION
    Cleans the image before SysPrep by removing volume caches, update backups and update caches.
.EXAMPLE
    Clean-Image.ps1 -CleanCCMCache
.INPUTS
    None.
.OUTPUTS
    None.
.NOTES
    Created by Ioan Popovici
.LINK
    https://deploymentbunny.com (@mikael_nystrom [Deplyment Bunny] - Original VB Script)
.LINK
    https://MEM.Zone/Clean-WindowsImage
.LINK
    https://MEM.Zone/Clean-WindowsImage-CHANGELOG
.LINK
    https://MEM.Zone/Clean-WindowsImage-GIT
.LINK
    https://MEM.Zone/Issues
.COMPONENT
    Cleanup
.FUNCTIONALITY
    Clean Windows Image
#>

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

## Set script requirements
#Requires -Version 3.0

## Get script parameters
Param (
    [Parameter(Mandatory = $false, Position = 0)]
    [switch]$CleanCCMCache = $false
)
## Variables: Get Machine Operating System
[String]$RegExPattern = '(Windows\ (?:7|8\.1|8|10|Server\ (?:2008\ R2|2012\ R2|2012|2016|2019)))'
[String]$MachineOS = (Get-WmiObject -Class 'Win32_OperatingSystem' | Select-Object -ExpandProperty 'Caption' | `
    Select-String -AllMatches -Pattern $RegExPattern | Select-Object -ExpandProperty 'Matches').Value
## Variables: Get Volume Caches registry paths
[String]$regVolumeCachesRootPath = 'HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches'
[Array]$regVolumeCachesPaths = Get-ChildItem -Path $regVolumeCachesRootPath | Select-Object -ExpandProperty 'Name'
## Variables: CleanMgr cleanup settings
[String]$regSageSet = '5432'
[String]$regName = 'StateFlags' + $regSageSet
[String]$regValue = '00000002'
[String]$regType = 'DWORD'

#endregion
##*=============================================
##* END VARIABLE DECLARATION
##*=============================================

##*=============================================
##* FUNCTION LISTINGS
##*=============================================
#region FunctionListings

#region Function Start-Cleanup
Function Start-Cleanup {
<#
.SYNOPSIS
    Cleans volume caches, update backups and update caches.
.DESCRIPTION
    Cleans volume caches, update backups and update caches depending on the selected options.
.PARAMETER CleanupOptions
    The CleanupOptions depending of what type of cleanup to perform.
.EXAMPLE
    Start-Cleanup -CleanupOptions ('comCacheRepair','comCacheCleanup','updCacheCleanup','volCacheCleanup', 'ccmCacheCleanup')
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, Position = 0)]
        [Alias('cOptions')]
        [Array]$CleanupOptions
    )

    Write-Host "$MachineOS Detected. Starting Cleanup... `n" -ForegroundColor 'Yellow' -BackgroundColor 'Black'
    $i = 0
    ## Perform Cleanup Actions
    Switch ($CleanupOptions) {
        'comCacheRepair' {

            #  Write progress
            $i++
            $Taskname = 'Component Cache Repair'
            Write-Progress -Activity 'Performing Cleanup before Sysprep' -Status ('Processing Task {0}' -f $Taskname) -PercentComplete ($i / $CleanupOptions.count * 100)

            #  Start Component Cache Repair
            Write-Host 'Performing Component Cache Repair...' -ForegroundColor 'Yellow' -BackgroundColor 'Black'
            Start-Process -FilePath 'DISM.exe' -ArgumentList '/Online /Cleanup-Image /RestoreHealth' -Wait
        }
        'comCacheCleanup' {

            #  Write progress
            $i++
            $Taskname = 'Component Cache Cleanup'
            Write-Progress -Activity 'Performing Cleanup before Sysprep' -Status ('Processing Task {0}' -f $Taskname) -PercentComplete ($i / $CleanupOptions.count * 100)

            #  Start Component Cache Cleanup
            Write-Host 'Performing Component Cache Cleanup...' -ForegroundColor 'Yellow' -BackgroundColor 'Black'
            Start-Process -FilePath 'DISM.exe' -ArgumentList '/Online /Cleanup-Image /StartComponentCleanup /ResetBase' -Wait
        }
        'volCacheCleanup' {

            #  Write progress
            $i++
            $Taskname = 'Volume Cache Cleanup'
            Write-Progress -Activity 'Performing Cleanup before Sysprep' -Status ('Processing Task {0}' -f $Taskname) -PercentComplete ($i / $CleanupOptions.count * 100)

            #  If Volume Cache Paths exist add registry entries required by CleanMgr
            If ($regVolumeCachesPaths) {
                Write-Host "Adding $regName to the following Registry Paths:" -ForegroundColor 'Yellow' -BackgroundColor 'Black'
                $regVolumeCachesPaths | ForEach-Object {
                    Write-Host "$_"
                    New-ItemProperty -Path Registry::$_ -Name $regName -Value $regValue -PropertyType $regType -Force | Out-Null
                }

                #  If machine is Windows Server 2008 R2, copy files required by CleanMgr and wait for action to complete
                If ($MachineOS -eq 'Windows Server 2008 R2') {
                    Copy-Item -Path 'C:\Windows\winsxs\amd64_microsoft-windows-cleanmgr_31bf3856ad364e35_6.1.7600.16385_none_c9392808773cd7da\cleanmgr.exe' -Destination 'C:\Windows\System32\' -Force | Out-Null
                    Copy-Item -Path 'C:\Windows\winsxs\amd64_microsoft-windows-cleanmgr.resources_31bf3856ad364e35_6.1.7600.16385_en-us_b9cb6194b257cc63\cleanmgr.exe.mui' -Destination 'C:\Windows\System32\en-US\' -Force | Out-Null
                }

                #  Start Volume Cache Cleanup
                Write-Host 'Performing Volume Cache Cleanup...' -ForegroundColor 'Yellow' -BackgroundColor 'Black'
                Start-Process -FilePath 'CleanMgr.exe' -ArgumentList "/sagerun:$regSageSet" -Wait
            }
            Else {
                Write-Host 'Path Not Found! Skipping...' -ForegroundColor 'Red' -BackgroundColor 'Black'
            }
        }
        'volShadowCleanup' {

            #  Write progress
            $i++
            $Taskname = 'Volume Shadow Cleanup'
            Write-Progress -Activity 'Performing Cleanup before Sysprep' -Status ('Processing Task {0}' -f $Taskname) -PercentComplete ($i / $CleanupOptions.count * 100)

            #  Start Volume Cache Cleanup
            Write-Host 'Performing Volume Shadow Cleanup...' -ForegroundColor 'Yellow' -BackgroundColor 'Black'
            Start-Process -FilePath 'vssadmin.exe' -ArgumentList 'Delete Shadows /All /force' -Wait
        }
        'updCacheCleanup' {

            #  Write progress
            $i++
            $Taskname = 'Update Cache Cleanup'
            Write-Progress -Activity 'Performing Cleanup before Sysprep' -Status ('Processing Task {0}' -f $Taskname) -PercentComplete ($i / $CleanupOptions.count * 100)

            #  Start Update Cache Cleanup
            Write-Host 'Performing Update Cache Cleanup...' -ForegroundColor 'Yellow' -BackgroundColor 'Black'
            Stop-Service -Name 'wuauserv' -ErrorAction 'SilentlyContinue' | Out-Null
            Remove-Item -Path 'C:\Windows\SoftwareDistribution\' -Recurse -Force | Out-Null
            Start-Service -Name 'wuauserv' -ErrorAction 'SilentlyContinue' | Out-Null
        }
        'ccmCacheCleanup' {

            ## Initialize the CCM resource manager com object
            [__comobject]$CCMComObject = New-Object -ComObject 'UIResource.UIResourceMgr'

            ## Get the CacheElementIDs to delete
            $CacheInfo = $CCMComObject.GetCacheInfo().GetCacheElements()

            ## Remove cache items
            ForEach ($CacheItem in $CacheInfo) {
                $null = $CCMComObject.GetCacheInfo().DeleteCacheElement([string]$($CacheItem.CacheElementID))
            }
        }
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

## Perform different cleanup actions depending on the detected Operating System, the action order is intentional
If ($MachineOS) {
    Switch ($MachineOS) {
        'Windows 7' {
            Start-Cleanup ('volCacheCleanup', 'updCacheCleanup')
        }
        'Windows 8' {
            Start-Cleanup ('comCacheRepair', 'comCacheCleanup', 'volCacheCleanup', 'updCacheCleanup')
        }
        'Windows 8.1' {
            Start-Cleanup ('comCacheRepair', 'comCacheCleanup', 'volCacheCleanup', 'updCacheCleanup')
        }
        'Windows 10' {
            Start-Cleanup ('comCacheRepair', 'volCacheCleanup', 'updCacheCleanup', 'comCacheCleanup', 'volShadowCleanup')
        }
        'Windows Server 2008 R2' {
            Start-Cleanup ('volCacheCleanup', 'updCacheCleanup')
        }
        'Windows Server 2012' {
            Start-Cleanup ('comCacheRepair', 'comCacheCleanup', 'updCacheCleanup')
        }
        'Windows Server 2012 R2' {
            Start-Cleanup ('comCacheRepair', 'comCacheCleanup', 'updCacheCleanup')
        }
        'Windows Server 2016' {
            Start-Cleanup ('updCacheCleanup', 'comCacheCleanup', 'ccmCacheCleanup')
        }
        'Windows Server 2019' {
            Start-Cleanup ('updCacheCleanup', 'comCacheCleanup', 'ccmCacheCleanup')
        }
        Default {
            Write-Host "Unknown Operating System, Skipping Cleanup! `n" -ForegroundColor 'Red' -BackgroundColor 'Black'
        }
    }
    If ($CleanCCMCache) {
        Start-Cleanup ('ccmCacheCleanup')
    }
}
Else {
    Write-Host "Unknown Operating System, Skipping Cleanup! `n" -ForegroundColor 'Red' -BackgroundColor 'Black'
}

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================