# Rename-IntuneComputer release history

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
* Fixed some descritpions in the help section.
* Added `ShouldProcess` support.

## 1.1.0 - 2024-01-15

* Fixed missing `DeviceName` parameter.
* Fixed default values for script parameters.
* Removed obsolete `UserPrincipalName` parameter.
* Replaced `${ScriptSection}` with `$script:ScriptSection` for `Write-Log` in main script.

## 1.0.0 - 2024-01-12

### First version

* Renames an Intune device according to a specified naming convention.
