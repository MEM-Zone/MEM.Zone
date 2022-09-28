# Invoke-CCMCacheCleanup release history

## 5.0.0 - 2022-09-28

* Renamed script to `Invoke-CCMCacheCleanup` to as per PowerShell verb requirements
* Moved the the `MEM.Zone` repo. Old location will no longer be maintained
* Changed links to `MEM.Zone`. Links redirects will follow.

## 4.1.0 - 2019-07-30

## Changes (Fixed by Wolfereign - Big Thanks!)

* Fixed skip cache bug with LastReferenceTime by changing $OlderThan date to UTC.
* Fixed skip cache bug where script handles only 'Install' action type.

## 4.0.0 - 2019-03-15

## Changes

* Fixed error on ContentID with multiple CacheElementIDs
* [Breaking] Changed the logic of the Get-* functions
* [Breaking] Changed the logic of the Remove* functions
* [Breaking] Changed the parameter name of the Remove-CacheElementFunction function
* Added Orphaned WMI cache cleanup (Previously it was disk only)
* Some code cleanup

## 3.5.0 - 2018-09-13

## Changes

* Fixed Get-Help functionality.
* Moved written requirements to #Required statement
* Added full Get-Help support
* Code cleanup

## 3.4.0 - 2018-08-30

### Fixed

* Write-log inconsistencies
* Incorrect size for orphaned items cleanup
* 00:00:00 time in support center log viewer
* Changed task category to 'None'

### Changes

* Simplified log naming and source by merging to $script:LogName and $script:LogSource variables only
* Simplified Write-Log parameter requirements by removing the requirement for $Source and using $ScriptSection
* Changed Write-Log to use $script:Section by default instead of $Source. (It can still be specified if needed)
* Added option to log debug messages
* Added event source deletion if the event log source already exists
* Moved release log to separate markdown file

## 3.3.0 - 2018-08-07

### Changes

* Fixed division by 0
* Added basic debug info

## 3.2.0 - 2018-07-10

### Fixes

* Fixed should run bug

## 3.1.0 - 2018-07-09

### Changes

* Added ReferencedThreshold
* Squashed lots of bugs

## 3.0.0 - 2018-07-05

### Added

* Better logging and logging options by adapting the PADT logging cmdlet. (Slightly modified version)
* Support for verbose and debug to the PADT logging cmdlet
* More cleaning options
* LowDiskSpaceThreshold option to only clean cache when there is not enough space on the disk.
* SkipSuperPeer, for Peer Cache 'Hosts'
* ReferencedThreshold, for skipping cache younger than specified number of days

### Fixes

* Persisted cache cleaning, it's not removed without the RemovePersisted switch
* Orphaned cache cleaning and it's not a hack anymore
* Error reporting

### Optimizations

* Speed.
* The functionality is now split correctly in functions
* Script is now ConfigurationItem friendly
* Cmdlets are now module friendly
* Moved file log in $Env:WinDir\Logs\Configuration Manager\Clean-CCMClientCache.log

### Changes

* Completely re-written

## 1.1.0 - 2.9.0 (2015 - 2018)

### Fixed

* First time run logging bug  (Walker)
* Remove package bug, better logging (Christopher Winney)
* TotalSize decimals
* NULL ContentID

### Added

* EventLog logging support
* Check for not downloaded Cache Items
* Orphaned cache cleanup
* Improved logging
* Basic error Management

## 1.0.0 - 2015-11-13

### First version

* Cleans the configuration manager client cache of all unneeded with the option to delete persisted content