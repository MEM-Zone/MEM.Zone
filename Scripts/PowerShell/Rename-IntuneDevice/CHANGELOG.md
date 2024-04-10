# Rename-IntuneComputer release history

## 2.1.1 - 2024-02-09

* Fixed `managedDeviceOwnerType` check, which would cause the script to skip all devices.

## 2.1.0b - 2024-02-02

* Added support for `Android` and `iOS/macOS` devices (Issue #19).
* Added supported devices check.
* Added `iOS/macOS` supervision check.
* Added `Warning` when a device is skipped.
* Simplified the `ForEach` loop.

## 2.0.3 - 2024-01-25

* Fixed `OutputPage` variable name in `Invoke-MSGraphAPI` function. Paging should work now.

## 2.0.2 - 2024-01-23

* Fixed `RenameCounter` value.
* Changed required powershell version to 5.1 due to `Write-EventLog` deprecation. Will fix this in the future.
* Corrected some descriptions in the help section.

## 2.0.1 - 2024-01-22

* Fixed `Write-Log` Overlapping Logs warning and functionality
* Fixed `Write-Log` incorrect `ScriptSection` variable for archive log file.
* Fixed `Write-Log` EventLog message.
* Fixed `Write-Log` respecting `WhatIf` and not logging anything.
* Fixed main script `Parameter` filter value.
* Fixed `Invoke-MSGraphAPI` function paging.
* Fixed `SerialNumber` parameter case change error.
* Fixed `Prefix` parameter shortening logic.
* Fixed `UserAttribute` parameter shortening logic.
* Removed Wildcard parameters.

## 2.0.0 - 2024-01-18

* Fixed `DeviceName` parameter alias.
* Fixed `DeviceOS` and `DeficeName` default values.
* Fixed `Write-Log` Overlapping Logs warning and functionality and added additional warnings for missing parameters.
* Fixed `ResolveError` function call.
* Fixed incorrect `Uri` generation in `Invoke-MSGraphAPI` function.
* Fixed incorrect `Body` splatting in `Invoke-MSGraphAPI` function.
* Fixed incorrect `${cmdletName}` variable troughout the script.
* Fixed incorrect `Prefix` variable initialization in main script `ForEach` loop.
* Fixed prefix logic in main script `ForEach` loop.
* Fixed `MaxSerialNumberLength` value.
* Fixed and improved comments.
* Removed `UserAttribute` parameter set from the 'Prefix` parameter.
* Added minor code refactoring.

## 1.2.0 - 2024-01-17

* Fixed string formatting bug in `Invoke-MSGraphAPI` function.
* Fixed some descriptions in the help section.
* Added `ShouldProcess` support.

## 1.1.0 - 2024-01-15

* Fixed missing `DeviceName` parameter.
* Fixed default values for script parameters.
* Removed obsolete `UserPrincipalName` parameter.
* Replaced `${ScriptSection}` with `$script:ScriptSection` for `Write-Log` in main script.

## 1.0.0 - 2024-01-12

### First version

* Renames an Intune device according to a specified naming convention.
