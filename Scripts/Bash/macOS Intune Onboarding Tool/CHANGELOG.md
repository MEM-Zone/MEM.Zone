# macOS Intune Onboarding Tool release history

## 5.0.2 - 2024-06-24

* Spellcheck.

## 5.0.1 - 2023-03-24

* Updated `Error Code` legend.

## 5.0.0 - 2023-03-24

* Added better notifications and alerts.
* Added `displayAlert` function.
* Changed `displayDialog` icon parameter to allow icon resource names or IDs.
* Changed `displayDialog` parameters position to make more sense [`Breaking`].
* Changed last supported OS version to macOS 12 Monterey.
* Changed macOS supported OS check by moving it to the `checkSupportedOS` function.
* Changed `LAST_SUPPORTED_OS_VERSION` to `SUPPORTED_OS_MAJOR_VERSION` [`Breaking`].
* Changed all exit code values [`Breaking`].
* Updated descriptions.

## 4.1.0 - 2023-03-16

* Added `macOS` version check with forced update prompt.

## 4.0.0 - 2023-03-15

* Added proper `JAMF API` support.
* Added proper `JAMF API` management removal.

## 3.0.1 - 2023-03-13

* Fixed local account with `UID` lower than `1000` detection.

## 3.0.0 - 2023-03-13

* Added `JAMF API` management removal for cases where the profile is marked as non-removable. (!! NOT TESTED !!).
* Added detection for `JAMF MDM Profile`.
* Added terminating error if the `JAMF MDM Profile` can't be removed.
* Added removal for `JAMF Binaries` only when present.

## 2.4.0 - 2023-03-09

* Added better error handling.
* Added and documented error/return codes.
* Added minor code optimisations.
* Fixed `Cancel` button press doing nothing.

## 2.3.1 - 2023-03-07

* Fixed `disable` FileVault throwing `Invalid action`.

## 2.3.0 - 2023-03-06

* Added functionality to `enable` `reissue key` for FileVault.
* Renamed `disableFileVault` to `invokeFileVaultAction`.

## 2.2.0 - 2023-03-06

* Added `disable` FileVault step.

## 2.1.0 - 2023-02-23

* Added `suppressNotification` parameter to the `displayNotification` function. This breaks the previous version because the parameter positions have shifted.

## 2.0.0 - 2023-02-17

* Re-wrote the whole script, it was not usable.

## 1.0.0 - 2023-02-09

### First version

* Starts Intune onboarding, converting mobile accounts, removing AD binding and JAMF management. Company portal needs to be preinstalled as a prerequisite.
