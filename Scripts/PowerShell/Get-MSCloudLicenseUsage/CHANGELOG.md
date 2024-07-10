# Get-MSCloudLicenseUsage release history

## 1.0.1 - 2024-07-10

* Fixed a bug with the `Invoke-MSGraphAPI` pagination handling. The script now correctly handles the `@odata.nextLink` property and fetches all pages of the response.
* Fixed the `Error Message` in the `Invoke-MSGraphAPI` function to correctly display the error message from the response body.
* Updated  script name in the `Get-Help` output to reflect the correct script name.

## 1.0.0 - 2024-06-19

### First version

* Checks the license usage of the specified license. If the available amount is under the specified MinimumLicenseThreshold it will send a message to a slack webhook.
