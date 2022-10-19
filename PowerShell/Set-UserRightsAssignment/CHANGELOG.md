# Set-UserRightsAssignment release history

## 2.2.1 - 2022-10-19

* Added logging support

## 2.2.0 - 2022-10-14

* Added `Locale` warning when using `Principal Name` instead of a `SID`
* Added force stop if the `SID` cannot be resolved
* Added custom error handling
* Fixed empty `Privilege` on error

## 2.1.0 - 2022-09-19

* Added `RemoveAll` support for the `Action` parameter
* Added some code optimizations
* `Privilege` parameter is now dynamic

## 2.0.0 - 2022-09-16

* Added `SID` Support for `Principal`
* Added Resolve-Principal support for both `PrincipalSID` and `PrincipalName`
* Added random file names for all used files
* Added some code optimizations
* Replaced `Identity` with `Principal`
* Fixed some variable declarations
* Fixed `Replace` Support


## 1.0.1 - 2022-09-15

* Added `Replace` option.
* Set `ErrorActionPreference` on a single line.

## 1.0.0 - 2022-09-14

### First version

* Add or Remove user rights assignment to a local computer.
