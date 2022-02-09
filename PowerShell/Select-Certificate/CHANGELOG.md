# Select-Certificate release history

## 3.0.0 - 2022-02-09

* Added TemplateOID support
* Minor code optimisations

## 2.0.0 - 2021-09-29

* Added `Filter` parameter
* Added `Subject` parameter
* Added better error handling
* Added Verbose output
* Added `Summarization` parameter for better output
* Added option o use inline parameters
* Added script `Param()` and `CmdletBinding`. Can be run using parameters now.
* Modified default values quotes `"` instead of `'`. `'` are not supported with the `Run Script` feature.
* Can be used with the `Run Script` feature or as with a `Compliance Baseline` now.

## 1.3.0 - 2017-10-11

* Removed result table headers
* Added automatic space removal for cerSerialNumber

## 1.1.0 - 2017-09-27

* Fixed compliance output

## 1.0.0 - 2017-09-26

### First version

* Gets the details of a Specific certificate using the certificate `Serial Number`, `Subject` or a `Filter`.
