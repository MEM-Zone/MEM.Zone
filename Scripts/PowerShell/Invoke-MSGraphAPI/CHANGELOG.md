# Invoke-MSGraphAPI release history

## 1.1.0 - 2024-07-10

* Renamed `Get-MsGraphAccessToken` to `Get-MsGraphAPIAccessToken` to better reflect the function's purpose.
* Fixed a bug with the `Invoke-MSGraphAPI` pagination handling. The script now correctly handles the `@odata.nextLink` property and fetches all pages of the response.
* Fixed the `Error Message` in the `Invoke-MSGraphAPI` function to correctly display the error message from the response body.

## 1.0.1 - 1.0.3 (Ferry Bodijn)

* Made some changes to make `Invoke-MSGraphAPI` function work properly.
* Fixed `Invoke-MSGraphAPI` paging when there is no `output.value` property in the response.

## 1.0.0 - 2024-06-19

### First version

* Invokes the Microsoft Graph API with paging support.
