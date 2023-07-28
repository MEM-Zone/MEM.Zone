# Invoke-CCMCacheCleanup release history

## 6.0.1 - 2023-07-28

* Fixed `Error getting cached element` for `Package` type
* Added `ListOnly` CleanupType option

## 6.0.0 - 2023-07-28

* [Breaking] Completely rewritten, functionality has changed
* [Breaking] Renamed `CleanupActions` to `CacheType`
* [Breaking] Added `CleanupType` parameter with `Automatic` mode for cache cleanup
* Fixed [Get-CimInstance : Invalid class](https://github.com/MEM-Zone/MEM.Zone/issues/14) @idrositis
* Fixed [Error On Line 831](https://github.com/MEM-Zone/MEM.Zone/issues/8) @SCCMWalker
* Fixed [Not detecting or removing most content](https://github.com/MEM-Zone/MEM.Zone/issues/7) @PhilAitman
* Added a lot of optimizations under the hood

## 5.0.0 - 2022-09-28

* Renamed script to `Invoke-CCMCacheCleanup` to as per PowerShell verb requirements
* Moved the the `MEM.Zone` repo. Old location will no longer be maintained
* Changed links to `MEM.Zone`. Links redirects will follow.

## 4.1.0 - 2019-07-30

## Changes (Fixed by Wolfereign - Big Thanks!)

* Fixed skip cache bug with LastReferenceTime by changing $OlderThan date to UTC.
* Fixed skip cache bug where script handles only 'Install' action type.

## 4.0.0 - 2019-03-15

* Fixed error on ContentID with multiple CacheElementIDs
* [Breaking] Changed the logic of the Get-* functions
* [Breaking] Changed the logic of the Remove* functions
* [Breaking] Changed the parameter name of the Remove-CacheElementFunction function
* Added Orphaned WMI cache cleanup (Previously it was disk only)
* Some code cleanup

## 3.5.0 - 2018-09-13

* Fixed Get-Help functionality.
* Moved written requirements to #Required statement
* Added full Get-Help support
* Code cleanup

## 3.4.0 - 2018-08-30

* Fixed `Write-log` inconsistencies
* Fixed Incorrect size for orphaned items cleanup
* Fixed `00:00:00` time in support center log viewer
* Changed task category to 'None'

### Changes

* Simplified log naming and source by merging to $script:LogName and $script:LogSource variables only
* Simplified Write-Log parameter requirements by removing the requirement for $Source and using $ScriptSection
* Changed Write-Log to use $script:Section by default instead of $Source. (It can still be specified if needed)
* Added option to log debug messages
* Added event source deletion if the event log source already exists
* Moved release log to separate markdown file

## 3.3.0 - 2018-08-07

* Fixed division by 0
* Added basic debug info

## 3.2.0 - 2018-07-10

* Fixed should run bug

## 3.1.0 - 2018-07-09

* Added ReferencedThreshold
* Fixed lots of bugs

## 3.0.0 - 2018-07-05

* Added better logging and logging options by adapting the PADT logging cmdlet. (Slightly modified version)
* Added support for verbose and debug to the PADT logging cmdlet
* Added more cleaning options
* Added `LowDiskSpaceThreshold` option to only clean cache when there is not enough space on the disk.
* Added `SkipSuperPeer`, for Peer Cache 'Hosts'
* Added `ReferencedThreshold`, for skipping cache younger than specified number of days
* Added `ConfigurationItem` support
* Fixed persisted cache cleaning, it's not removed without the RemovePersisted switch
* Fixed orphaned cache cleaning and it's not a hack anymore
* Fixed error reporting
* Moved file log in `$Env:WinDir\Logs\Configuration Manager\Clean-CCMClientCache.log`
* Optimized for speed
* Optimized the functionality by splitting correctly into functions
* Optimized Cmdlets to be module friendly
* Optimized by complete re-write

## 1.1.0 - 2.9.0 (2015 - 2018)

* Fixed first time run logging bug @Walker
* Fixed remove package bug, better logging @ChristopherWinney
* Fixed `TotalSize` decimals
* Fixed `NULL` ContentID
* Added eventLog logging support
* Added check for not downloaded Cache Items
* Added Orphaned cache cleanup
* Added Improved logging
* Added Basic error Management

## 1.0.0 - 2015-11-13

### First version

* Cleans the configuration manager client cache of all unneeded with the option to delete persisted content