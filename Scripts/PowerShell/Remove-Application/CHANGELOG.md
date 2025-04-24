# Remove-Application release history

> This script is designed to be used in a Configuration Manager (ConfigMgr) or Intune compliance settings environment.

## 2.0.1b - 2025-04-24

* Fixed error in `Get-Application` when parsing a non-existing registry path

## 2.0.0b - 2025-04-24

* [Breaking] Renamed `Get-InstalledApplication` to `Get-Application`
* [Breaking] Renamed `Uninstall-InstalledApplication` to `Remove-Application`
* [Breaking] Moved `Get-Application` and `Remove-Application` to different folders
* Minor bug fixes and improvements

## 1.1.1b - 2025-04-16

* Minor bug fixes and improvements

## 1.1.0b - 2025-04-16

* Added fix for non-fully silent install argument `/SILENT`
* Added support for killing `*post*` install processes
* Code cleanup and refactoring

## 1.0.0b - 2025-04-16

* Uninstalls matching applications on a system from provided application list.
