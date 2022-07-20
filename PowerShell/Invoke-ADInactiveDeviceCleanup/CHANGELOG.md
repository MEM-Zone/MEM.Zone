# Invoke-ADInactiveDeviceCleanup release history

## 3.0.0 - 2022-07-20

* Moved parameters to `JSON` configuration file

## 2.0.0b - 2021-06-28 - (Beta Version)

* Renamed script to better reflect the purpose
* Added HTML report support
* Added custom HTML table headers support
* Added secure send mail support. Requires: Mailkit and Mailmime (NuGet)

## 1.0.1 - 2021-04-20

* Removed console data from event log
* Fix script name inconsistencies in logging

## 1.0.0 - 2021-04-20

### First version

* Cleans Active Directory devices that have passed the specified inactive threshold by disabling them and optionally moving them to a specified OU.
