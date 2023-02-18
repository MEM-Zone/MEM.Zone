<#
.SYNOPSIS
    Creates a shortcut in a specified path or special folder.
.DESCRIPTION
    Creates a shortcut in a specified path or special folder using the specialfolder method.
.PARAMETER Target
    The target path for the shortcut.
.PARAMETER Name
    Specifies the name of the shortcut. Must contain lnk or url extension.
.PARAMETER Path
    The destination path of the shortcut. If this parameter is specified the SpecialFolder parameter is ignored.
.PARAMETER SpecialFolder
    The special folder to create the shortcut in. If this parameter is specified the Destination parameter is ignored.
    Valid values are
        'AllUsersDesktop'
        'AllUsersStartMenu'
        'AllUsersPrograms'
        'AllUsersStartup'
        'Desktop'
        'Favorites'
        'Fonts'
        'MyDocuments'
        'NetHood'
        'PrintHood'
        'Programs'
        'Recent'
        'SendTo'
        'StartMenu'
        'Startup'
        'Templates'
.EXAMPLE
    New-Shortcut.ps1 -Target 'C:\Windows\System32\cmd.exe' -Path 'C:\Users\Public\Desktop' -Name 'cmd.lnk'
.EXAMPLE
    New-Shortcut.ps1 -Target 'C:\Windows\System32\cmd.exe' -SpecialFolder 'Desktop' -Name 'cmd.lnk'
.INPUTS
    None.
.OUTPUTS
    None.
.NOTES
    Created by Ioan Popovici
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    File System
.FUNCTIONALITY
    Create Shortcut
#>

## Set script requirements
#Requires -Version 3.0

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

## Get script parameters
[CmdletBinding(DefaultParameterSetName = 'Path')]
Param (
    [Parameter(Mandatory = $true, ParameterSetName = 'Path', HelpMessage = 'Source Path: ', Position = 0)]
    [Parameter(Mandatory = $true, ParameterSetName = 'SpecialFolder', HelpMessage = 'Source Path: ', Position = 0)]
    [ValidateNotNullorEmpty()]
    [ValidateScript({
        Resolve-Path -Path $PSItem -ErrorAction 'Stop'
        If (Test-Path -Path $PSItem -PathType 'Container') { Throw "'$PSItem' source is a directory!" }
    })]
    [Alias('Source')]
    [string]$Target,
    [Parameter(Mandatory = $true, ParameterSetName = 'Path', HelpMessage = 'Name: ', Position = 1)]
    [Parameter(Mandatory = $true, ParameterSetName = 'SpecialFolder', HelpMessage = 'Name: ', Position = 1)]
    [ValidateNotNullorEmpty()]
    [Alias('ShortcutName')]
    [string]$Name,
    [Parameter(Mandatory = $true, ParameterSetName = 'Path', HelpMessage = 'Destination Path: ', Position = 2)]
    [ValidateNotNullorEmpty()]
    [ValidateScript({
        Resolve-Path -Path $PSItem -ErrorAction 'Stop'
        If (Test-Path -Path $PSItem -PathType 'Leaf') { Throw "'$PSItem' destination is a file!" }
    })]
    [Alias('Destination')]
    [string]$Path,
    [Parameter(Mandatory = $true, ParameterSetName = 'SpecialFolder', HelpMessage = 'Special Folder: ', Position = 2)]
    [ValidateSet('AllUsersDesktop', 'AllUsersStartMenu', 'AllUsersPrograms', 'AllUsersStartup', 'Desktop', 'Favorites', 'Fonts', 'MyDocuments', 'NetHood', 'PrintHood', 'Programs',
        'Recent','SendTo','StartMenu','Startup','Templates'
    )]
    [Alias('Special')]
    [string]$SpecialFolder
)

#endregion
##*=============================================
##* END VARIABLE DECLARATION
##*=============================================

##*=============================================
##* FUNCTION LISTINGS
##*=============================================
#region FunctionListings

#region Function New-Shortcut
Function New-Shortcut {
<#
.SYNOPSIS
    Creates a shortcut in a specified path or special folder.
.DESCRIPTION
    Creates a shortcut in a specified path or special folder using the specialfolder method.
.PARAMETER Target
    The source path for the shortcut.
.PARAMETER Name
    Specifies the name of the shortcut. Must contain lnk or url extension.
.PARAMETER Path
    The destination path of the shortcut. If this parameter is specified the SpecialFolder parameter is ignored.
.PARAMETER SpecialFolder
    The special folder to create the shortcut in. If this parameter is specified the Destination parameter is ignored.
    Valid values are
        'AllUsersDesktop'
        'AllUsersStartMenu'
        'AllUsersPrograms'
        'AllUsersStartup'
        'Desktop'
        'Favorites'
        'Fonts'
        'MyDocuments'
        'NetHood'
        'PrintHood'
        'Programs'
        'Recent'
        'SendTo'
        'StartMenu'
        'Startup'
        'Templates'
.EXAMPLE
    New-Shortcut -Target 'C:\Windows\System32\cmd.exe' -Path 'C:\Users\Public\Desktop' -Name 'cmd.lnk'
.EXAMPLE
    New-Shortcut -Target 'C:\Windows\System32\cmd.exe' -SpecialFolder 'Desktop' -Name 'cmd.lnk'
.INPUTS
    None.
.OUTPUTS
    None.
.NOTES
    Created by Ioan Popovici
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    File System
.FUNCTIONALITY
    Create Shortcut
#>
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    Param (
        [Parameter(Mandatory = $true, ParameterSetName = 'Path', HelpMessage = 'Source Path: ', Position = 0)]
        [Parameter(Mandatory = $true, ParameterSetName = 'SpecialFolder', HelpMessage = 'Source Path: ', Position = 0)]
        [ValidateNotNullorEmpty()]
        [ValidateScript({
            Resolve-Path -Path $PSItem -ErrorAction 'Stop'
            If (Test-Path -Path $PSItem -PathType 'Container') { Throw "'$PSItem' source is a directory!" }
        })]
        [Alias('Source')]
        [string]$Target,
        [Parameter(Mandatory = $true, ParameterSetName = 'Path', HelpMessage = 'Name: ', Position = 1)]
        [Parameter(Mandatory = $true, ParameterSetName = 'SpecialFolder', HelpMessage = 'Name: ', Position = 1)]
        [ValidateNotNullorEmpty()]
        [Alias('ShortcutName')]
        [string]$Name,
        [Parameter(Mandatory = $true, ParameterSetName = 'Path', HelpMessage = 'Destination Path: ', Position = 2)]
        [ValidateNotNullorEmpty()]
        [ValidateScript({
            Resolve-Path -Path $PSItem -ErrorAction 'Stop'
            If (Test-Path -Path $PSItem -PathType 'Leaf') { Throw "'$PSItem' destination is a file!" }
        })]
        [Alias('Destination')]
        [string]$Path,
        [Parameter(Mandatory = $true, ParameterSetName = 'SpecialFolder', HelpMessage = 'Special Folder: ', Position = 2)]
        [ValidateSet('AllUsersDesktop', 'AllUsersStartMenu', 'AllUsersPrograms', 'AllUsersStartup', 'Desktop', 'Favorites', 'Fonts', 'MyDocuments', 'NetHood', 'PrintHood', 'Programs',
            'Recent','SendTo','StartMenu','Startup','Templates'
        )]
        [Alias('Special')]
        [string]$SpecialFolder
    )

    Begin {

        ## Start Logging
        [string]$LogPath = Join-Path -Path $Env:TEMP -ChildPath 'New-Shortcut.log'
        Start-Transcript -Path $LogPath -Force

        ## Create COM Object
        $ComObject = New-Object -ComObject 'WScript.Shell'
    }
    Process {
        Try {
            If ($PSCmdlet.ParameterSetName -eq 'SpecialFolder') {
                [string]$SpecialFolderPath = $ComObject.SpecialFolders.Item($SpecialFolder)
                $Destination = Join-Path -Path $SpecialFolderPath -ChildPath $Name
            }
            Else {
                $Destination = Join-Path -Path $Path -ChildPath $Name
            }

            ## Create Shortcut
            $Shortcut = $ComObject.CreateShortcut($Destination)
            $Shortcut.TargetPath = $Target
            $Shortcut.Save()
            $Output = If ($?) { "Successfully created shortcut in '$Destination' with target '$Target'." } Else { Throw $Result }
        }
        Catch {
            $Output = "Failed to create shortcut in '$Destination' with target '$Target'!"
            $PSCmdlet.ThrowTerminatingError($PSItem)
        }
        Finally {
            Write-Verbose -Message $Output -Verbose
        }
    }
    End {

        ## Release COM Object
        $null = [System.Runtime.Interopservices.Marshal]::ReleaseComObject($ComObject)

        ## Stop Logging
        Stop-Transcript
    }
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

## Call New-Shortcut function
New-Shortcut @PSBoundParameters

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================
