<#
.SYNOPSIS
    Repairs error 0x800f082f~ encountered during offline servicing.
.DESCRIPTION
    Repairs error 0x800f082f~ encountered during offline servicing by setting the
    HKLM:\Microsoft\Windows\CurrentVersion\Component Based Servicing\SessionsPending\Exclusive value to 0.
.INPUTS
    None.
.OUTPUTS
    None.
.EXAMPLE
    Repair-ServicingError_800f082f.ps1
.NOTES
    Created by Ioan Popovici
    Requirements
        ADK Windows 10, Windows 8 or higher.
.LINK
    https://MEM.Zone.Zone/Repair-ServicingError
.LINK
    https://MEM.Zone.Zone/Repair-ServicingError_800f082f-CHANGELOG
.LINK
    https://MEM.Zone.Zone/Repair-ServicingError_800f082f-GIT
.LINK
    https://MEM.Zone.Zone/Issues
.COMPONENT
    Windows Servicing
.FUNCTIONALITY
    Repairs servicing error 0x800f082f~
#>

## Set script requirements
#Requires -Version 3.0

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

## Get script path and name
[String]$ScriptPath = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Definition)
[String]$ScriptName = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Definition)
## Set Paths and Image Index
[String]$MountPath = (Join-Path -Path $ScriptPath -ChildPath '\Mount')
[String]$MountHivePath =  (Join-Path -Path $MountPath -ChildPath '\Windows\System32\Config\Software')
[String]$MountHiveKey = 'HKLM:\EXTERNAL\Microsoft\Windows\CurrentVersion\Component Based Servicing\SessionsPending'
[String]$ScratchPath = (Join-Path -Path $ScriptPath -ChildPath '\Scratch')
[String]$LogPath = (Join-Path -Path $ScriptPath -ChildPath 'DISM.log')
## Set Environment Path in order to use the latest DISM and System32. This is set for current session only, no need to remove it afterwards.
$Env:Path = 'C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\DISM;C:\Windows\System32'

#endregion
##*=============================================
##* END VARIABLE DECLARATION
##*=============================================
#endregion

##*=============================================
##* FUNCTION LISTINGS
##*=============================================
#region FunctionListings

#region Function Enable-Privilege
Function Enable-Privilege {
<#
.SYNOPSIS
    Enables privileges in a specified access token.
.DESCRIPTION
    Enables privileges in a specified access token.
.PARAMETER Privilege
    The Privilege to inject, valid options are:
        "SeAssignPrimaryTokenPrivilege", "SeAuditPrivilege", "SeBackupPrivilege", "SeChangeNotifyPrivilege", "SeCreateGlobalPrivilege",
        "SeCreatePagefilePrivilege", "SeCreatePermanentPrivilege", "SeCreateSymbolicLinkPrivilege", "SeCreateTokenPrivilege",
        "SeDebugPrivilege", "SeEnableDelegationPrivilege", "SeImpersonatePrivilege", "SeIncreaseBasePriorityPrivilege",
        "SeIncreaseQuotaPrivilege", "SeIncreaseWorkingSetPrivilege", "SeLoadDriverPrivilege","SeLockMemoryPrivilege",
        "SeMachineAccountPrivilege", "SeManageVolumePrivilege", "SeProfileSingleProcessPrivilege", "SeRelabelPrivilege",
        "SeRemoteShutdownPrivilege", "SeRestorePrivilege", "SeSecurityPrivilege", "SeShutdownPrivilege", "SeSyncAgentPrivilege",
        "SeSystemEnvironmentPrivilege", "SeSystemProfilePrivilege", "SeSystemtimePrivilege", "SeTakeOwnershipPrivilege",
        "SeTcbPrivilege", "SeTimeZonePrivilege", "SeTrustedCredManAccessPrivilege", "SeUndockPrivilege", "SeUnsolicitedInputPrivilege"
.EXAMPLE
    Enable-Privilege -Privilege SeTakeOwnershipPrivilege
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    Credit to Pasquale Lantella:
    https://gallery.technet.microsoft.com/Adjusting-Token-Privileges-9b6724fc
#>
Param (
    [Parameter(Mandatory=$true,Position=0)]
    [Alias('Pr')]
    [Array]$Privilege
)
    $Definition = @'
        using System;
        using System.Runtime.InteropServices;
        public class AdjPriv {
            [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
            internal static extern bool AdjustTokenPrivileges(IntPtr htok, bool disall,
            ref TokPriv1Luid newst, int len, IntPtr prev, IntPtr rele);
            [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
            internal static extern bool OpenProcessToken(IntPtr h, int acc, ref IntPtr phtok);
            [DllImport("advapi32.dll", SetLastError = true)]
            internal static extern bool LookupPrivilegeValue(string host, string name,
            ref long pluid);
            [StructLayout(LayoutKind.Sequential, Pack = 1)]
            internal struct TokPriv1Luid {
                public int Count;
                public long Luid;
                public int Attr;
            }
            internal const int SE_PRIVILEGE_ENABLED = 0x00000002;
            internal const int TOKEN_QUERY = 0x00000008;
            internal const int TOKEN_ADJUST_PRIVILEGES = 0x00000020;
            public static bool EnablePrivilege(long processHandle, string privilege) {
                bool retVal;
                TokPriv1Luid tp;
                IntPtr hproc = new IntPtr(processHandle);
                IntPtr htok = IntPtr.Zero;
                retVal = OpenProcessToken(hproc, TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, ref htok);
                tp.Count = 1;
                tp.Luid = 0;
                tp.Attr = SE_PRIVILEGE_ENABLED;
                retVal = LookupPrivilegeValue(null, privilege, ref tp.Luid);
                retVal = AdjustTokenPrivileges(htok, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
                return retVal;
            }
        }
'@

    ## Get process pandle
    $ProcessHandle = (Get-Process -id $pid).Handle
    $type = Add-Type $Definition -PassThru

    ## Inject token
    $type[0]::EnablePrivilege($processHandle, $Privilege)
}

#endregion

#endregion
##*=============================================
##* END FUNCTION LISTINGS
##*=============================================

##*=============================================
##* SCRIPT BODY
##*=============================================
#region ScriptBody

## Create Mount directory if it does not exist
If ((Test-Path $MountPath) -eq $False) {
    New-Item -Path $MountPath -Type Directory | Out-Null
}

## Create Scratch directory if it does not exist
If ((Test-Path $ScratchPath) -eq $False) {
    New-Item -Path $ScratchPath -Type Directory | Out-Null
}

## Check for images
$CheckForImages = Get-ChildItem -Path $ScriptPath -Filter '*.wim'
If (-not $CheckForImages) { Write-Error -Message 'Image not found! Script must be in the same folder as the image.' -ErrorAction 'Stop' }

## Prompt for WIM to service, don't allow null input
Do {
    [Array]$ImageFileInfo = Get-ChildItem -Path $ScriptPath -Filter '*.wim' | Select-Object -Property `
        @{Label='Name';Expression={($PSItem.Name)}},
        @{Label='Size (GB)';Expression={'{0:N2}' -f ($PSItem.Length / 1GB)}},
        @{Label='Path';Expression={($PSItem.FullName)}} | Out-GridView -PassThru -Title 'Choose image to service. Do not use multiple selection!'
}
While ($ImageFileInfo.Length -eq 0)

#  Set image file name and path, process only the first selection
[String]$ImageFile = ($ImageFileInfo | Select-Object -First 1).Name
[String]$ImagePath = ($ImageFileInfo | Select-Object -First 1).Path

## Prompt for windows version, don't allow null input
Do {
    [Array]$ImageIndexInfo = Get-WindowsImage -ImagePath $ImagePath | Select-Object -First 1 -Property `
        @{Label='Index';Expression={($PSItem.ImageIndex)}},
        @{Label='Name';Expression={($PSItem.ImageName)}},
        @{Label='Description';Expression={($PSItem.ImageDescription)}},
        @{Label='Size (GB)';Expression={'{0:N2}' -f ($PSItem.ImageSize / 1GB)}} | Out-GridView -PassThru -Title 'Choose Windows version. Do not use multiple selection!'
}
While ($ImageIndexInfo.Length -eq 0)

#  Set image name and index, process only the first selection
[String]$ImageName = ($ImageIndexInfo | Select-Object -First 1).Name
[Int]$ImageIndex = ($ImageIndexInfo | Select-Object -First 1).Index

## Set Backup path and Backup WIM file
[String]$BackupImagePath = ($ImagePath -replace '.{3}$')+'bkp'

Write-Host "`n`n`n`n`n`nBacking up $ImagePath to $BackupImagePath ..." -ForegroundColor 'Yellow' -BackgroundColor 'Black'
$Operation = Copy-Item -Path $ImagePath -Destination $BackupImagePath -Force

## Mount WIM
Write-Host "`nMounting Image..." -ForegroundColor 'Yellow' -BackgroundColor 'Black'
$Operation = Mount-WindowsImage -ImagePath $ImagePath -Index $ImageIndex -Path $MountPath -ScratchDirectory $ScratchPath -LogPath $LogPaths

#  Display mounted image status
$Operation = Get-WindowsImage -Mounted -ScratchDirectory $ScratchPath -LogPath $LogPath | Out-String
Write-Host "`nMounted Image Info:`n $Operation" -ForegroundColor 'Yellow' -BackgroundColor 'Black'

## Load registry hive
Write-Host "Loading Registry Hive...`n" -ForegroundColor 'Yellow' -BackgroundColor 'Black'
$Operation = Start-Process -FilePath "CMD.EXE" -ArgumentList "/C REG LOAD HKLM\EXTERNAL $MountHivePath" -Wait -WindowStyle Hidden

## Get privileges in order to be able to take ownership of the registry key
Write-Host "Getting Privileges..." -ForegroundColor 'Yellow' -BackgroundColor 'Black'
$Operation = Enable-Privilege -Privilege 'SeTakeOwnershipPrivilege'
If ($Operation) {
    Write-Host "Successful!`n" -ForegroundColor 'Yellow' -BackgroundColor 'Black'
}
Else {
    Write-Host "Failed!`n" -ForegroundColor 'Red' -BackgroundColor 'Black'
}

#  Create new ACL control access rule object
[PsObject]$RegACL = New-Object System.Security.AccessControl.RegistryAccessRule ("Administrators","FullControl","ObjectInherit,ContainerInherit","None","Allow")

#  Set the registry key owner variable
[PsObject]$RegOwner = [System.Security.Principal.NTAccount]"Administrators"

#  Open key with Read/Write and Take Ownership privileges
[PsObject]$RegKeyCR = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey(
    "EXTERNAL\Microsoft\Windows\CurrentVersion\Component Based Servicing\SessionsPending",[Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,[System.Security.AccessControl.RegistryRights]::TakeOwnership
)

#  Get a blank ACL since we don't have access
$ACLCR = $RegKeyCR.GetAccessControl([System.Security.AccessControl.AccessControlSections]::None)

#  Create owner control access rule
$ACLCR.SetOwner($RegOwner)

#  Set Owner using owner control access rule
$RegKeyCR.SetAccessControl($ACLCR)

#  Get the ACL for the registry key now that we have access
$ACLCR = $RegKeyCR.GetAccessControl()

#  Create the control access rule for the registry key
$ACLCR.SetAccessRule($RegACL)

#  Set the permissions on the registry key using the control access rule
$RegKeyCR.SetAccessControl($ACLCR)

#  Closing the handle
$RegKeyCR.Close()

##  Set the new registry key value
Write-Host "Setting Exclusive Registry Key Value to 0...`n" -ForegroundColor 'Yellow' -BackgroundColor 'Black'
Set-ItemProperty -Path $MountHiveKey -Name 'Exclusive' -Value '0' | Out-Null

## Run garbage collector so we can safely unload the registry hive
[gc]::collect()

## Unload registry hive
Write-Host "Unloading Registry Hive...`n" -ForegroundColor 'Yellow' -BackgroundColor 'Black'
Start-Process -FilePath "CMD.EXE" -ArgumentList "/C REG UNLOAD HKLM\EXTERNAL" -Wait -WindowStyle Hidden

## Unmount and save servicing changes to the image
Write-Host "`nCommitting Changes and Dismounting Image..." -ForegroundColor 'Yellow' -BackgroundColor 'Black'
$Operation = Dismount-WindowsImage -Path $MountPath -ScratchDirectory $ScratchPath -LogPath $LogPath -Save -CheckIntegrity

## Wait for keypress
Write-Host "Press any key to continue ..."
$WaitforKeyPress = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================
