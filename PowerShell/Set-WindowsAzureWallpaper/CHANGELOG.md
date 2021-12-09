# Set-WindowsAzureWallpaper release history


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
