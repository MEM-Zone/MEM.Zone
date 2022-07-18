# Start-RestAzureStorageTransfer release history

## 2.0.0 - 2021-07-18

    * Renamed script to `Start-RestAzureStorageTransfer`
    * Renamed functions for better powershell verb compliance
    * Added support for both azure blob and file storage
    * Added support for listing the content of a blob or file
    * Re-wrote and optimized some of the code

## 1.0.4 - 2021-07-01

    * Added get file content support

## 1.0.3 - 2021-03-31

    * Fix `Url` duplicate bug
    * Error handling improvements
    * Code cleanup and spell check

## 1.0.2 - 2021-03-15

    * Replaced `Get-Error` cmdlet in order to have backwards compatibility with PowerShell 5

## 1.0.1 - 2021-02-26

    * Fixed error when folder already exists
    * Added `Force` parameter to overwrite the existing file even if it has the same name and size. I can't think why this would be needed but I added it anyway.
    * Added destination path to output

## 1.0.1 - 2021-02-26

    * Fix files being always skipped.

## 1.0.0 - 2021-02-23

### First version

Gets items from azure file storage using REST API and BITS.
