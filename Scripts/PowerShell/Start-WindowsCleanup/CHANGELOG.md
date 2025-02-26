# Start-WindowsCleanup release history

## 4.0.2 - 2025-02-06

* Fixed spelling mistakes in descriptions

## 4.0.1 - 2023-08-11

* Fixed spelling mistakes in descriptions

## 4.0.0 - 2023-07-13

* Renamed `Remaining` to `FreeSpace`
* Renamed `Reclaimed` to `ReclaimedSpace`
* Fixed `FreeSpace` computation
* Fixed `FreeSpace` formatting for negative numbers
* Fixed `Format-Bytes` function
* Added Some code improvements
* Added reboot warning for SxS processing for addressing [Less free space each time the cleanup script has been run](https://github.com/MEM-Zone/MEM.Zone/issues/12) @Glitchi85

>Note
>Renaming output headers is a breaking change, bumping major version.

## 3.1.1 - 2023-07-13

* Added wait for `TiWorker` process to start

## 3.1.0 - 2023-07-13

* Added `TiWorker` process priority as `High`, requested per [Increase TiWorker.exe CPU priority](https://github.com/MEM-Zone/MEM.Zone/issues/11)

## 3.0.1 - 2021-11-19

* Fixed a typo in the `childpath` parameter form the `Remove orphaned CCM cache items` @asg2ki (Pull Request)
* Fixed `Windows 11` omission in the regex match @asg2ki (Pull Request)
* Added `Windows Server 2022` support @asg2ki (Pull Request)

## 3.0.0 - 2021-09-02

* Added `CM RunScript` support
* Added the ability to run all, or each cleanup task individually
* Added Progress Bars
* Added Cleanup Result with dynamic size output
* Added EventLog support
* Added orphaned CCM Cache cleanup
* Added Windows 11 support for `Recommended Cleanup`
* Added Error Handling
* Refactoring and optimizations for most of the code
* Changed links to MEM.Zone

## 2.9.0 - 2018-11-19

* Fixed regex pattern for windows server 2019 detection

## 2.8.0 - 2018-11-17

* Added support for windows server 2019

## 2.7.0 - 2018-10-18

* Added CCMCache cleanup option

## 2.6.0 - 2018-10-03

* Fixed parameter bug
* Minor formatting changes

## 2.5.0 - 2018-10-01

* Regression switched back to Get-WmiObject, Cim seems to fail in some cases
* Fixed cleanup is not performed on some systems
* Moved release history to separate markdown file

## 2.4.0 - 2018-08-31

* Switched to Cim Commandlets

## 2.3.0 - 2018-07-27 (Matthew Hilton)

* Added Progress bars
* Fixed ErrorAction to stop MDT Errors

## 2.2.0 - 2018-05-24

* Fixed Windows 10 1803 bigger image after cleanup

## 2.1.0 - 2017-09-07

* Fixed Copy-Item Bug
* Fixed Windows 10 detection

## 2.0.0 - 017-07-10

* Completely re-written, fixed some broken logic

## 1.0.0 - 2017-07-10

Performs a Windows cleanup by removing volume caches, update backups, updates and CCM caches.
