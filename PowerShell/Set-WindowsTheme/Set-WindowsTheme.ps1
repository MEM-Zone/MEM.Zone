<#
.SYNOPSIS
    Sets and activates the theme for windows.
.DESCRIPTION
    Sets and activates the theme for windows, using a theme file.
.PARAMETER Action
    Specifies the action to perform.
    Accepted values are:
        * 'Install'   - Installs the theme.
        * 'Uninstall' - Uninstalls the theme.
        * 'Report'    - Reports compliance.
.PARAMETER Path
    Specifies the destination path for the theme.
.PARAMETER Force
    Overwrite the existing local theme file.
.PARAMETER DetectionMethod
    Specify the theme detection method.
    Available values:
        * IsInstalled
        * IsActive
.EXAMPLE
    Set-WindowsTheme.ps1 -Action 'Install' -Path 'C:\Windows\Themes\MyTheme.deskthemepack' -DetectionMethod 'IsInstalled' -Force
.EXAMPLE
    Set-WindowsTheme.ps1 -Action 'Report' -Path 'C:\Windows\Themes\MyTheme.deskthemepack'
.INPUTS
    None.
.OUTPUTS
    System.String
    System.Object
.NOTES
    Created by Ioan Popovici
.LINK
    https://MEM.Zone/Set-WindowsTheme
.LINK
    https://MEM.Zone/Set-WindowsTheme-CHANGELOG
.LINK
    https://MEM.Zone/Set-WindowsTheme-GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    Desktop
.FUNCTIONALITY
    Change Windows Theme
#>

## Set script requirements
#Requires -Version 5.0

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

## !! Comment the reqion below if using in-script parameter values. You can set the parameters in the SCRIPT BODY region at the end of the script !!
#region ScriptParameters
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $true, HelpMessage = 'Perform Action:', Position = 0)]
    [ValidateNotNullorEmpty()]
    [ValidateSet('Install', 'Uninstall', 'Report')]
    [Alias('Run')]
    [string]$Action,
    [Parameter(Mandatory = $true, HelpMessage = 'Theme Path:', Position = 1)]
    [ValidateNotNullorEmpty()]
    [Alias('Location')]
    [string]$Path,
    [Parameter(Mandatory = $true, HelpMessage = 'Theme Detection Method:', Position = 2)]
    [ValidateNotNullorEmpty()]
    [ValidateSet('IsInstalled', 'IsActive')]
    [Alias('Detection')]
    [string]$DetectionMethod,
    [Alias('Overwrite')]
    [Parameter(ParameterSetName = 'SetTheme')]
    [switch]$Force
)
#endregion

#endregion
##*=============================================
##* END VARIABLE DECLARATION
##*=============================================

##*=============================================
##* FUNCTION LISTINGS
##*=============================================
#region FunctionListings

#region Function Get-CurrentUser
Function Get-CurrentUser {
<#
.SYNOPSIS
    Gets the current user.
.DESCRIPTION
    Gets current user regardless of context by quering the session manager.
.EXAMPLE
    Get-CurrentUser
.INPUTS
    None.
.OUTPUTS
    Sytem.Object
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://www.reddit.com/r/PowerShell/comments/7coamf/query_no_user_exists_for/
.LINK
    https://MEM.Zone/
.LINK
    https://MEM.Zone/Issues
.COMPONENT
    Session Manager
.FUNCTIONALITY
    Gets the Current User
#>
    [CmdletBinding()]
    Param ()

    Begin {

        ## Load HKU hive
        $IsHKULoaded = Test-Path -Path 'HKU:'
        If (-not $IsHKULoaded) { New-PSDrive -PSProvider 'Registry' -Name 'HKU' -Root 'HKEY_USERS' | Out-Null }
    }
    Process {
        Try {

            ## Get current user
            #  Get all sessions
            $Sessions = (& query session)
            #  Select active sessions by replacing spaces with ',', convert the result to a CSV object and the select only 'Active' connections
            $ActiveSessions = $Sessions -replace ('\s{2,}', ',') | ConvertFrom-Csv | Where-Object -Property 'State' -eq 'Active'
            #  Get current user
            $CurrentUser = $ActiveSessions[0]
            #  Get user SID
            $CurrentUserSID = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI\SessionData\$($CurrentUser.ID)" -Name 'LoggedOnUserSID' -ErrorAction 'SilentlyContinue').LoggedOnUserSID
            #  Get user domain
            $CurrentUserDomain = (Get-ItemProperty "HKU:\$CurrentUserSID\Volatile Environment" -Name 'USERDNSDOMAIN' -ErrorAction 'SilentlyContinue').USERDNSDOMAIN
            #  Get machine domain
            $Domain = [System.Net.Dns]::GetHostByName($Env:ComputerName).HostName.Replace($Env:ComputerName + '.', '')
            #  Build output object
            $Output = [pscustomobject]@{
                UserSID       = $CurrentUserSID
                UserName      = $CurrentUser.USERNAME
                UserDomain    = $CurrentUserDomain
                MachineDomain = $Domain.ToUpper()
            }
        }
        Catch {
            Write-Error -Message $PsItem.Exception
        }
        Finally {
            Write-Output -InputObject $Output
        }
    }
    End {
        Remove-PSDrive -PSProvider 'Registry' -Name 'HKU' -ErrorAction 'SilentlyContinue' | Out-Null
    }
}
#endregion

#region Function Get-WindowsTheme
Function Get-WindowsTheme {
<#
.SYNOPSIS
    Gets the current windows theme.
.DESCRIPTION
    Gets the current windows theme status and retuns it to the pipeline.
.PARAMTER Path
    Specifies the theme path to get.
.EXAMPLE
    Get-WindowsTheme -Path 'C:\Windows\Themes\MyTheme.deskthemepack'
.INPUTS
    None.
.OUTPUTS
    Sytem.Object
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://www.reddit.com/r/PowerShell/comments/7coamf/query_no_user_exists_for/
.LINK
    https://MEM.Zone/
.LINK
    https://MEM.Zone/Issues
.COMPONENT
    Desktop
.FUNCTIONALITY
    Gets the Current Theme
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = 'Theme Path:', Position = 0)]
        [ValidateNotNullorEmpty()]
        [Alias('Location')]
        [string]$Path
    )
    Begin {

        ## Load HKU hive
        $IsHKULoaded = Test-Path -Path 'HKU:'
        If (-not $IsHKULoaded) { New-PSDrive -PSProvider 'Registry' -Name 'HKU' -Root 'HKEY_USERS' | Out-Null }
    }
    Process {
        Try {

            ## Set variables
            $CurrentUser = Get-CurrentUser
            [string]$ThemeName = $(Split-Path -Path $Path -Leaf)
            [string]$ThemeNameWithoutExtension = $ThemeName.Split('.')[0]
            [string]$UserThemeFolderRoot = Join-Path -Path $env:SystemDrive -ChildPath "Users\$($CurrentUser.UserName)\AppData\Local\Microsoft\Windows\Themes"
            [string]$UserThemeFolder = (Get-ItemProperty -Path "HKU:\$($CurrentUser.UserSID)\Software\Microsoft\Windows\CurrentVersion\Themes" -Name 'CurrentTheme').CurrentTheme


            ## Check if theme is installed or active
            $IsInstalled = [boolean](Get-ChildItem -Path $UserThemeFolderRoot -Filter $ThemeNameWithoutExtension -ErrorAction 'SilentlyContinue')
            $IsActive = [boolean]$UserThemeFolder.Contains($ThemeNameWithoutExtension)

            ## Build output object
            $Output = [pscustomobject]@{
                Action      = 'Report'
                Name        = $ThemeName
                Path        = $UserThemeFolder
                IsInstalled = $IsInstalled
                IsActive    = $IsActive
            }
        }
        Catch {
            $PSCmdlet.WriteError($PsItem.Exception)
        }
        Finally {
            Write-Output -InputObject $Output
        }
    }
    End {
        Remove-PSDrive -PSProvider 'Registry' -Name 'HKU' -ErrorAction 'SilentlyContinue' | Out-Null
    }
}
#endregion

#region Function Set-WindowsTheme
Function Set-WindowsTheme {
<#
.SYNOPSIS
    Sets and activates the theme for windows.
.DESCRIPTION
    Sets and activates the theme for windows, using a theme file.
.PARAMETER Action
    Specifies the action to perform.
    Accepted values are:
        * 'Install'   - Installs the theme.
        * 'Uninstall' - Uninstalls the theme.
        * 'Report'    - Reports compliance.
.PARAMETER Path
    Specifies the destination path for the theme.
.PARAMETER Force
    Overwrite the existing local theme file.
.PARAMETER DetectionMethod
    Specify the theme detection method.
    Available values:
        * IsInstalled
        * IsActive
.EXAMPLE
    Set-WindowsTheme.ps1 -Action 'Install' -Path 'C:\Windows\Themes\MyTheme.deskthemepack' -DetectionMethod 'IsInstalled' -Force
.EXAMPLE
    Set-WindowsTheme.ps1 -Action 'Report' -Path 'C:\Windows\Themes\MyTheme.deskthemepack'
.INPUTS
    None.
.OUTPUTS
    System.Object
.NOTES
    Created by Ioan Popovici
    You can use this script in a baseline as a MEMCM 'Detection' script.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    Desktop
.FUNCTIONALITY
    Set Windows Theme
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = 'Perform Action:', Position = 0)]
        [ValidateNotNullorEmpty()]
        [ValidateSet('Install', 'Uninstall', 'Report')]
        [Alias('Run')]
        [string]$Action,
        [Parameter(Mandatory = $true, HelpMessage = 'Theme Path:', Position = 1)]
        [ValidateNotNullorEmpty()]
        [Alias('Location')]
        [string]$Path,
        [Parameter(Mandatory = $true, HelpMessage = 'Theme Detection Method:', Position = 2)]
        [ValidateNotNullorEmpty()]
        [ValidateSet('IsInstalled', 'IsActive')]
        [Alias('Detection')]
        [string]$DetectionMethod,
        [Alias('Overwrite')]
        [Parameter(ParameterSetName = 'SetTheme')]
        [switch]$Force
    )
    Begin {

        ## Set default output hashtable
        $OutputProps = [ordered]@{
            Action      = 'N/A'
            Name        = 'N/A'
            Status      = 'N/A'
            IsInstalled = 'N/A'
            IsActive    = 'N/A'
        }

        ## Set variables
        [string]$DefaultThemePath = Join-Path -Path $env:SystemDrive -ChildPath 'Windows\resources\Themes\aero.theme'
        [string]$SystemThemeFolder = Split-Path -Path $DefaultThemePath -Parent
        [string]$UserThemeFolder = Join-Path -Path $env:SystemDrive -ChildPath "Users\$((Get-CurrentUser).UserSID)\AppData\Local\Microsoft\Windows\Themes"
        [string]$ThemeName = Split-Path -Path $Path -Leaf
        [scriptblock]$IsSystemSettingsStarted = { [boolean](Get-Process -Name 'SystemSettings' -ErrorAction 'SilentlyContinue') }
        [scriptblock]$IsInstalled = { (Get-WindowsTheme -Path $Path).IsInstalled }
        [scriptblock]$IsActive = { (Get-WindowsTheme -Path $Path).IsActive }
        $OutputProps.Name = $ThemeName
    }
    Process {
        Try {
            Switch ($Action) {
                'Install' {

                    ## Set variables
                    $OutputProps.Action = 'Install'

                    ## Set if theme is not alread active or Force is set
                    If (-not (& $IsActive) -or $Force) {

                        ##  Stop the 'SystemSettings' process if started
                        Stop-Process -Name 'SystemSettings' -ErrorAction 'SilentlyContinue' -Force

                        ##  Install the theme
                        Invoke-Expression -Command $Path

                        ##  Kill the SystemSettings process only after the theme is detected as installed in order to apply the theme.
                        For ([int16]$Counter = 0; $Counter -le 30; $Counter++) {
                            If ($(& $IsActive) -and $(& $IsSystemSettingsStarted)) { Break }
                            Start-Sleep -Seconds 1
                        }

                        ##  Stop the SystemSettings process to apply the theme.
                        Stop-Process -Name 'SystemSettings' -ErrorAction 'SilentlyContinue' -Force

                        $OutputProps.Status = 'Installed'

                        If (-not (& $IsActive)) {
                            $OutputProps.Status  = "Failed to set theme!"
                            Throw $OutputProps.Status
                        }
                    }
                    Else { $OutputProps.Status = "Already active!" }
                    Break
                }
                'Uninstall' {

                    ## Set variables
                    [string]$UserThemePath = (Get-WindowsTheme -Path $DefaultThemePath).Path
                    [scriptblock]$IsInstalled = { (Get-WindowsTheme -Path $DefaultThemePath).IsInstalled }
                    [scriptblock]$IsActive = { (Get-WindowsTheme -Path $DefaultThemePath).IsActive }
                    $OutputProps.Action = 'UnInstall'

                    ## Set default theme if the default theme is not active
                    If (-not (& $IsActive)) {

                        ##  Stop the 'SystemSettings' process if started
                        Stop-Process -Name 'SystemSettings' -ErrorAction 'SilentlyContinue' -Force

                        ##  Install the theme
                        Invoke-Expression -Command $DefaultThemePath

                        ##  Kill the SystemSettings process only after the theme is detected as installed in order to apply the theme.
                        For ([int16]$Counter = 0; $Counter -le 30; $Counter++) {
                            If ($(& $IsActive) -and $(& $IsSystemSettingsStarted)) { Break }
                            Start-Sleep -Seconds 1
                        }

                        ##  Stop the SystemSettings process to apply the theme.
                        Stop-Process -Name 'SystemSettings' -ErrorAction 'SilentlyContinue' -Force

                        If (-not $(& $IsActive)) {
                            $OutputProps.Status = "Failed to set '$DefaultThemePath'!"
                            Throw $OutputProps.Status
                        }
                    }
                    Else { $OutputProps.Status = "'$DefaultThemePath' is already active!" }

                    ## Remove the theme if it's not in the system folder
                    If (& $IsInstalled) {
                        If ($UserThemePath -match $SystemThemeFolder) {
                            $OutputProps.Status = "Theme installed in the system folder, skipping removal!"
                            Write-Warning -Message $OutputProps.Status
                        }
                        Else {
                            Remove-Item -Path $UserThemeFolder
                            $OutputProps.Status = 'UnInstalled'
                            $OutputProps.Remove('Status')
                        }
                    }
                    Break
                }
                'Report' {
                    $OutputProps.Action = 'Report'
                    Break
                }
            }
        }
        Catch {
            Throw $PSItem
        }
        Finally {

            ## Build output object
            $OutputProps.IsInstalled = & $IsInstalled
            $OutputProps.IsActive = & $IsActive
            $Output = [pscustomobject]$OutputProps

            ## Return output object
            Write-Output -InputObject $Output
        }
    }
    End {
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

Try {

    ## Set parameters according to script parameters.
    ## !! Add parameters values here if using in-script parameters. Don't forget to comment the script parameter section !!
    [hashtable]$Parameters = @{
        Action               = $Action
        Path                 = $Path
        Force                = $Force
        DetectionMethod      = $DetectionMethod
        Verbose              = $VerbosePreference
    }

    ## Call Set-WindowsAzureTheme with declared parameters
    $SetWindowsTheme = Set-WindowsTheme @Parameters

    ## Return output if the theme is installed, otherwise return $null
    $IsDetected = $SetWindowsTheme.$DetectionMethod
    $Output = If ($IsDetected) { $SetWindowsTheme } Else { $null }

    ## Set exit code to success
    $ExitCode = 0
}
Catch {

    ## Set exit code to failed
    $ExitCode = 1
    Throw $PSItem
}
Finally {
    Write-Output -InputObject $Output
    Exit $ExitCode
}

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================