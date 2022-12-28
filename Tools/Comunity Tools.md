# Must Have Community Tools

## Tools for Intune

### Intune Device Details GUI

> GitHubRepo
> <https://github.com/petripaavola/IntuneDeviceDetailsGUI>

**Details:**
This Powershell based GUI/report helps Intune admins to see Intune device data in one view.
Especially it shows what Azure AD Groups and Intune filters are used in Application and Configuration Assignments.
Assignment group information helps admins to understand why apps and configurations are targeted to devices and find possible bad assignments.

### Intune Management Tool

> GitHubRepo
> [<https://github.com/petripaavola/IntuneDeviceDetailsGUI>](https://github.com/Micke-K/IntuneManagement)

**Details:**
These PowerShell scripts are using Microsoft Authentication Library (MSAL), Microsoft Graph APIs and Azure Management APIs to manage objects in Intune and Azure. The scripts has a simple WPF UI and it supports operations like Export, Import, Copy, Download, Compare etc.

### Application Icons for Microsoft Intune

> GitHubRepo
> [[<https://github.com/petripaavola/IntuneDeviceDetailsGUI>](https://github.com/Micke-K/IntuneManagement)](https://github.com/aaronparker/icons)

**Details:**
A set of application icons for Windows, macOS, Android and iOS platforms for use when adding applications to Microsoft Intune or Microsoft Endpoint Configuration Manager (or other device management / MDM and application deployment solutions).

Icons have been added in their largest size and best possible quality. All icons have been optimized for size using PNGOUT. Icons are optimized and converted to PNG format by scripts run by AppVeyor builds. All non-PNG files are then removed from the icons folder in the repository and pushed back to GitHub.

### Intune Debug Toolkit

> GitHubRepo
> <https://github.com/MSEndpointMgr/IntuneDebugToolkit>

**Details:**
<https://msendpointmgr.com/intune-debug-toolkit/>

### Intune Sync Debug

> GitHubRepo
> [<https://github.com/petripaavola/IntuneDeviceDetailsGUI>](https://www.powershellgallery.com/packages/intunesyncdebugtool/1.0.0.7)

**Details:**
Install-Module -Name intunesyncdebugtool -RequiredVersion 1.0.0.7

### Intune Device Details GUI

> GitHubRepo
> [<https://github.com/MSEndpointMgr/IntuneDebugToolkit>](https://github.com/petripaavola/IntuneDeviceDetailsGUI)

**Details:**
Version 2.95 is a huge update to the script's functionalities. Built-in search helps using this tool a lot.
This Powershell based GUI/report helps Intune admins to see Intune device data in one view
Especially it shows what Azure AD Groups and Intune filters are used in Application and Configuration Assignments.
Assignment group information helps admins to understand why apps and configurations are targeted to devices and find possible bad assignments.

### KQL Queries Pack Intune

> GitHubRepo
> <https://github.com/ugurkocde/KQL_Intune>

**Details:**
This collection of KQL Querries include some of which I have created because there was a neccessitiy or use case for it.
Other queries are from the Community that I found particulary interisting and worth to share.
The ones from the community will also contain the weblink to the source and author.

### Kusto Query Language (KQL) - cheat sheet

> GitHubRepo
> [<https://github.com/ugurkocde/KQL_Intune>](https://github.com/marcusbakker/KQL)

### Intune Backup & Restore

> GitHubRepo
> <https://github.com/jseerden/IntuneBackupAndRestore>

**Details:**
This PowerShell Module queries Microsoft Graph, and allows for cross-tenant Backup & Restore actions of your Intune Configuration.
Intune Configuration is backed up as (json) files in a given directory.

### Get-WindowsAutoPilotInfo

> PowerShell Gallery
> <https://www.powershellgallery.com/packages/Get-WindowsAutoPilotInfo/3.5>

**Details:**
This script uses WMI to retrieve properties needed for a customer to register a device with Windows Autopilot.

>It is normal for the resulting CSV file to not collect a Windows Product ID (PKID) value since this is not required to register a devicse.
Only the serial number and hardware hash will be populated.

## System Administration

### Total Registry

> GitHubRepo
> <https://github.com/zodiacon/TotalRegistry>

**Details:**
* Replacement for the Windows built-in Regedit.exe tool.
* Show real Registry (not just the standard one)
* Sort list view by any column
* Key icons for hives, inaccessible keys, and links
* Key details: last write time and number of keys/values
* Displays MUI and REG_EXPAND_SZ expanded values
* Full search (Find All / Ctrl+Shift+F)
* Enhanced hex editor for binary values
* Undo/redo
* Copy/paste of keys/values
* Optionally replace RegEdit
* Connect to remote Registry
* View open key handles

### Sysinternals

> Download Locations
> <https://github.com/Sysinternals>
> Also on Microsoft Store // winget install Sysinternals

**Details:**
The Sysinternals web site was created in 1996 by Mark Russinovich to host his advanced system utilities and technical information.
Whether you’re an IT Pro or a developer, you’ll find Sysinternals utilities to help you manage, troubleshoot and diagnose your Windows systems and applications.

### Event Tracing for Windows (ETW)

> Download Locations
> <https://go.microsoft.com/fwlink/p/?LinkId=526740>

**Details:**
Event Tracing for Windows (ETW) is enabling kernel or application event logging.
Before using the WPA tool, we need to have the ETL file loaded.
The wprp file is a Windows Performance Recorder Profile.
How to use the ETW app: <https://call4cloud.nl/2021/11/theres-someone-inside-your-etl/>
In this XML profile, we can define what we want to record `https://call4cloud.nl/wp-content/uploads/2021/11/autopilot.zip`
Example: `wpr -start c:\temp\autopilot.wprp`

### Fiddler

> Download Locations
> <https://www.telerik.com/download/fiddler>

**Details:**
Amplified networking debugging features
An attractive and intuitive UI
Choreographed releases with new features and enhancements

### SQL Visualize Flows

> Link
> <https://sqlflow.gudusoft.com/?utm_content=buffer137ea&utm_medium=social&utm_source=twitter.com&utm_campaign=buffer#/>

**Details:**
Visualize SQL Flows for better understanding

### Graph XRAY

> Link
> <https://www.youtube.com/watch?v=RGjw2OKL4Ks>

**Details:**
Convert Graph Https Calls to Powershell commands

### CM Trace for macOS

> Link
> [<https://www.youtube.com/watch?v=RGjw2OKL4Ks>](https://github.com/MarkusBux/CmTrace)

**Details:**
This is a macOS clone of the Configuration Manager log viewer for Windows. It parses the log file tokens and displays the result in a easily readable table structure. The app provides sorting, filtering as well as highlighting error or warning messages that have specified tokens within the log message.

The main purpose of this project is to learn Swift and macOS programming with a real life project. I'm a macOS user who administers Configuration Manager within client environments. Therefore this tool helps me to view the logs on my mac without the need to fire up a Windows machine.