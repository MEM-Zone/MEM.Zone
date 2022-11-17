# Import-Win32IDesktopAPI release history

## 1.2.1 - 2022-11-17

* Fixed display resolution detection for non scalled displays. Scalled displays will return scalled resolution.

## 1.2.0 - 2021-12-09

* Fixed all methods, everything works correctly now
* Added workaround for the `AdvanceSlideshow` method so at least it works for the first index monitor
* Changed the `SlideshowAdvanceInterval` to seconds from milliseconds
* Changed the Example variables to be less confusing

## 1.1.0 - 2021-03-31

* Added case insensitive support for Wallpaper `Position` parameter
* Improved error handling
* Commented unnecessary output
* Improved code formating for visibility

## 1.0.0 - 2021-02-26

### First version

Imports the Win32 IDesktop API so it can be used in PowerShell.
