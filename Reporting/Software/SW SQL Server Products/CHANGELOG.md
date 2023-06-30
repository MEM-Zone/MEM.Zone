# SW SQL Server Products release history

## 2.6.6 - 2020-03-29

* Fixed extension for `SQL 2019`. For real this time, I promise!

## 2.6.5 - 2020-03-29

* Removed `Cannot decode key` for SQL Express
* Fixed definitions and extensions for `SQL 2019`

## 2.6.4 - 2020-03-24

* Updated to support `SQL 2019`

## 2.6.3 - 2019-07-17

* Updated SQL releases definition list to also match `2012 CTP1` and `2012 CTP3`.

## 2.6.2 - 2019-07-17

* Updated SQL releases definition list. Should fix the empty release bug.

## 2.6.1 - 2019-07-17

* Fixed radio buttons not showing up in report viewer

## 2.6.0 - 2019-07-17

* Added `GetSQLProductKey.vb` to the project folder
* Added the ability to hide the product key
* Fixed a typo

## 2.5.1 - 2019-07-15

* Merged definition and extension files for `Property` and `ProductID`
* Added support functions link

## 2.5 - 2019-07-15

* Added edition group filter with multiple selections
* Added `CEIP` Reporting (Customer Experience Improvement)
* Removed unused fields
* Fixed `SKUName`
* Updated formating

## 2.4~prerelease - 2019-07-1z

* Added static column pivot to have predictable column order output
* Fixed x64 detection
* Added new `EditionGroup` definitions
* Default `N/A` if `NULL Edition`
* Default `NULL` for all `CASE` statements
* Added Old SQL extension cleanup
* Removed unused columns

## 2.1-2.3~prerelease - 2019-06-24

### Changes

* Removed `usp_PivotWithDynamicColumns`, it cannot be added dynamically, needs to be created manually.
* Removed `GO` statements, they are not valid `T-SQL` statements.
* Added variable declaration needed for report builder.
* Replaced `Domain` with `DomainOrWorkgroup`.
* Added `EditionGroup` for report grouping.
* Changed `ProductKey` to be shown now as `N/A` if null.
* Fixed different column name storing the same value.
* Standardized formatting and descriptions.

## 2.0~prerelease - 2019-06-18

* Completely re-written, new extension gathers and stores 40-50% less junk data.
* Added: `Product Key`, `Clustered`, `Operating System`, `VM`, `CPUs`, `Physical Cored`, `Logical Cores` information.
* Release is not a hack anymore.
* Code repetition, property name guessing and duplicates have been almost eliminated by pivoting the result table and using a stored procedure.
* Report and report template have been updated to the new standard template.

## 1.0 - 2016-02-08

* First version.
