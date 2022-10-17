# Get-UserRightsAssignment release history

## 1.1.1 - 2022-10-17

* Fixed `Principal Name` spam

## 1.1.0 - 2022-10-14

* Added `Locale` warning when using `Principal Name` instead of a `SID`
* Added force stop if the `SID` cannot be resolved
* Added better error handling
* Added `Error` to `IsCompliant` if an error occurs
* Added `N/A` to `NonCompliantPrivileges` if an error occurs
* Fixed empty `Privilege` on error
* Fixed wrong `Privilege Compliance` on error

## 1.0.1 - 2022-10-13

* Fixed `Compare-Object` bug when there are more rights assigned then specified in the compliance set

## 1.0.0 - 2022-09-19

### First version

* Gets user rights assignment for a local computer, and performs a compliance check.
