# Set-WindowsAzureWallpaper release history

## 4.0.0 - 2022-10-13

* Updated Azure Storage Rest Functions
* Updated Descriptions
* Some code refactoring

## 3.0.0 - 2022-04-22

* Removed authentication requirement for Azure Blob and File storage.
* Renamed Azure Functions for consistency (breaking change)
* Fixed regex pattern for default file name detection (allows more than 3 characters now)
* Fixed Default wallpaper not applying if no matching wallpaper is found.
* Better error handling.
* Updated descriptions
* Code optimisations

## 2.1.0 - 2022-02-09

* Added blob storage support. It automatically detects if it's blob or file storage and acts accordingly.
* Fixed regex pattern for default file name detection
* Fixed default wallpaper url bug

## 2.0.0 - 2021-12-22

* Added support for Setting a Wallpaper SlideShow.
* Improved verbose output
* Changed the `DefaultWallpaper` parameter to `DefaultResolution` so it can be used with the `SlideShow` implementation.
* Simplified some of the code

## 1.0.2 - 2021-12-09

* Fixed issues with the [Import-Win32IDesktopAPI](https://MEM.Zone/Import-Win32IDesktopAPI) function, non critical to the functionality of this script

## 1.0.1 - 2021-04-01

* Added implementation recommendations
* Changed example to use `$env:ProgramData`
* Moved default variables at the end of the script so users can define in-script parameters
* Better error handling

## 1.0.0 - 2021-03-31

### First version

Sets the wallpaper for windows 10, by downloading the necessary wallpaper files from Azure File Storage and activating the default wallpaper.
