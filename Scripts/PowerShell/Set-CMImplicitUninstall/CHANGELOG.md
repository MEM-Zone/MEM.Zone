# Set-CMImplicitUninstall release history

## 1.1.4 - 2024-06-14

* Fixed a ton of spelling mistakes in the script.

## 1.1.3 - 2022-04-22

* Fixed the progress indicator.

## 1.1.2 - 2022-03-18

* Removed error message when the `ConfigurationManager` module cannot be unloaded at the end of the script.

## 1.1.1 - 2022-03-18

* Fixed (this time for real) the `ImplicitUninstallEnabled` flag value not being set to true if it already is set to `false`

## 1.1.0 - 2022-03-18

* Fixed the `ImplicitUninstallEnabled` flag value not being set to true if it already is set to `false`
* Added more detailed comments in the script

## 1.0.0 - 2022-03-16

### First version

* Sets the Configuration Manager `ImplicitUninstallEnabled` flag on a required application deployment.
