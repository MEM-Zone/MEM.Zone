# CB Configuration Baseline Compliance release history

## 4.0 - 2019-03-14

### Changes

    * Speed optimisations
    * Workaround for issue [Conversion failed when converting value to data type](https://github.com/SCCM-Zone/sccm-zone.github.io/issues/4)
    * Added 'Compliant' Data
    * Changed OS Caption to static
    * Removed system info temporary table
    * Replaced report template with the new streamlined template
    * Changed report description to static

## 3.2.1 - 2018-11-26

### Changes

    * Fixed missing 'fn_rbac_ListCIRules' function (replaced with 'fn_ListCIRules')

## 3.2 - 2018-10-29

### Changes

    * Fixed Error compliance
    * Fixed null device name
    * Added error info and headers
    * Optimized speed
    * Minor formating fixes

## 3.1 - 2018-10-25

### Changes

    * Fixed totals count

## 3.0 - 2018-10-22

### Changes

    * Fixed duplicates (settings, rules, values)
    * Re-written to optimize speed
    * Added compliance rules, instance data and severity
    * Removed some data and fields that were not critical
    * Deprecated the 'CB Configuration Baseline Compliance by Company with Values' report.
    Will not be updated in the future because it's too hard to maintain two versions of the report.

## 2.1 - 2018-09-03

### Fixed

    * Query result showing just one value per machine
    * Dropping temporary table after completion

### Added

    * CB Revision
    * Encryption progress (in PowerShell script)

### Changed

    * Re-wrote query to be more efficient
    * Re-formated report and report groups

## 2.0 - 2018-06-21

### Changed

    * Completely re-written to optimize speed

## 1.1 - 2018-01-17

### Fixed

    * Actual Value is NULL compliance is not displayed

## 1.0 - 2017-09-22

### First version

    * Get the Compliance by Company and Actual Values of a Configuration Baseline Result