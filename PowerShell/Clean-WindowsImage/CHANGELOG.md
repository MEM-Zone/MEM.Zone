# Clean-WindowsImage release history

## 2.9 - 2018-11-19

### Changes

    * Fixed regex pattern for windows server 2019 detection

## 2.8 - 2018-11-17

### Changes

    * Added support for windows server 2019

## 2.7 - 2018-10-18

### Changes

    * Added CCMCache cleanup option

## 2.6 - 2018-10-03

### Changes

    * Fixed parameter bug
    * Minor formating changes

## 2.5 - 2018-10-01

### Changes

    * Regression, switched back to Get-WmiObject, Cim seems to fail in some cases
    * Fixed cleanup is not performed on some systems
    * Moved release history to separate markdown file

## 2.4 - 2018-08-31

### Changes

    * Switched to Cim Commandlets

## 2.3 - 2018-07-27 (Matthew Hilton)

### Changes

    * Added Progress bars
    * Fixed ErrorAction to stop MDT Errors

## 2.2 - 2018-05-24

### Fixes

    * Fixed Windows 10 1803 bigger image after cleanup

## 2.1 - 2017-09-07

### Fixes

    * Fixed Copy-Item Bug
    * Fixed Windows 10 detection

## 2.0 - 017-07-10

### Changes

    * Completely re-written, fixed some broken logic

## 1.0 - 2017-07-10

### First version

    * Cleans the image before SysPrep by removing volume caches, update backups and update caches.