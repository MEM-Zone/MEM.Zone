# macOS Intune Onboarding Tool release history

## 2.4.0 - 2023-03-09

* Added better error handling
* Added and documented error/return codes
* Added minor code optimisations
* Fixed `Cancel` button press doing nothing

## 2.3.1 - 2023-03-07

* Fixed `disable` FileVault throwing `Invalid action`

## 2.3.0 - 2023-03-06

* Added functionality to `enable` `reissue key` for FileVault
* Renamed `disableFileVault` to `invokeFileVaultAction`

## 2.2.0 - 2023-03-06

* Added `disable` FileVault step.

## 2.1.0 - 2023-02-23

* Added `suppressNotification` parameter to the `displayNotification` function. This breaks the previous version because the parameter positions have shifted.

## 2.0.0 - 2023-02-17

* Re-wrote the whole script, it was not usable.

## 1.0.0 - 2023-02-09

### First version

* Starts Intune onboarding, converting mobile accounts, removing AD binding and JAMF management. Company portal needs to be preinstalled as a prerequisite.
