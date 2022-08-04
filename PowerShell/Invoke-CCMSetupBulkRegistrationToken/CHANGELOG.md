# Invoke-CCMSetupBulkRegistrationToken release history

## 1.2.0 - 2022-08-04

* Fixed Parameter sets in `New-CMClientBulkRegistrationToken`
* Renamed `New-CMBulkRegistrationToken` to `New-CMClientBulkRegistrationToken`
* Added Documentation for task sequence and scheduled task
* Clarified the run conditions for the `New-CMClientBulkRegistrationToken` scheduled task
* Cleaned up some descriptions

## 1.0.0 - 2022-08-01

### First version

* Invokes CCMSetup.exe with an MEMCM bulk client registration Token. `New-CMClientBulkRegistrationToken` needs to run on the server side to generate the token and upload it to Azure Blob Storage.
