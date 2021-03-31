# Get-AzureStorageFileContent release history

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
