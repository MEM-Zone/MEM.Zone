<#
.SYNOPSIS
    Creates a registry watcher.
.DESCRIPTION
    Creates a registry watcher and monitors the specified registry tree or key value for changes.
.EXAMPLE
    New-RegistryWatcher.ps1
.INPUTS
    None.
.OUTPUTS
    None.
.NOTES
    Created by Ioan Popovici
.LINK
    https://MEMZ.one/RegistryWatcher
.LINK
    https://MEMZ.one/RegistryWatcher-GIT
.LINK
    https://MEMZ.one/RegistryWatcher-CHANGELOG
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    Registry
.FUNCTIONALITY
    Registry Watcher
#>

## Set script requirements
#Requires -Version 3.0

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

## Get script path and name
[string]$ScriptPath = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Definition)
[string]$ScriptName = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Definition)
[string]$ScriptFullName = [System.IO.Path]::GetFileName($MyInvocation.MyCommand.Definition)

## Display script path and name
Write-Verbose -Message "Running script: $ScriptFullName" -Verbose

#endregion
##*=============================================
##* END VARIABLE DECLARATION
##*=============================================

##*=============================================
##* FUNCTION LISTINGS
##*=============================================
#region FunctionListings

#region Function New-RegistryKeyValueWatcher
Function New-RegistryKeyValueWatcher {
<#
.SYNOPSIS
    Creates a wacher for a registry key value.
.DESCRIPTION
    Creates a wacher for a registry key value using the 'RegistryValueChangeEvent' wmi class.
.PARAMETER Hive
    Specifies the registry hive.
    Accepted values are:
        HKEY_LOCAL_MACHINE
        HKEY_USERS
        HKEY_CURRENT_CONFIG
    Defaut value is: 'HKEY_LOCAL_MACHINE'
.PARAMETER KeyPath
    Specifies the registry key path.
.PARAMETER ValueName
    Specifies the registry value name.
.PARAMETER SourceIdentifier
    Specifies the event source identifier.
.EXAMPLE
    New-RegistryKeyValueWatcher -Hive 'HKEY_LOCAL_MACHINE' -KeyPath 'SOFTWARE\Microsoft\Windows\CurrentVersion\Run' -ValueName 'MEM' -SourceIdentifier 'KeyValueWatcher'
.INPUTS
    None.
.OUTPUTS
    System.String
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.COMPONENT
    Registry
.FUNCTIONALITY
    Registers a WMI registry key value watcher
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$false,Position=0)]
        [ValidateNotNullorEmpty()]
        [ValidateSet('HKEY_LOCAL_MACHINE','HKEY_USERS','HKEY_CURRENT_CONFIG')]
        [Alias('RegistryHive')]
        [string]$Hive = 'HKEY_LOCAL_MACHINE',
        [Parameter(Mandatory=$true,Position=1)]
        [ValidateNotNullorEmpty()]
        [Alias('Key')]
        [string]$KeyPath,
        [Parameter(Mandatory=$true,Position=2)]
        [ValidateNotNullorEmpty()]
        [Alias('Value')]
        [string]$ValueName,
        [Parameter(Mandatory=$true,Position=3)]
        [ValidateNotNullorEmpty()]
        [Alias('Source')]
        [string]$SourceIdentifier
    )
    Begin {
        [string]$Output = $null

        ## Normalizing the path by escaping '\' characters
        $KeyPath = $KeyPath.Replace('\','\\')

        ## Creating the path string
        [string]$Path = Switch ($Hive) {
            'HKEY_LOCAL_MACHINE'  { 'HKLM:'; Break }
            'HKEY_USERS'          { 'HKU:' ; Break }
            'HKEY_CURRENT_CONFIG' { 'HKCC:'; Break }
            Default { 'Unsupported' }
        }

        ## Creating the full name value string
        [string]$ValueFullName  = Join-Path -Path $Path -ChildPath $KeyPath

        ## Build the WMI query string
        [string]$Query = "SELECT * FROM RegistryValueChangeEvent WHERE Hive='$Hive' AND KeyPath='$KeyPath' AND ValueName='$ValueName'"

        ## Performing cleanup by unregistering the event source and removing the generated event
        Unregister-Event -SourceIdentifier $SourceIdentifier -ErrorAction 'SilentlyContinue'
        Remove-Event -SourceIdentifier $SourceIdentifier -ErrorAction 'SilentlyContinue'
    }
    Process {
        Try {

            ## Registering the event source
            Register-WmiEvent -Query $Query -SourceIdentifier $SourceIdentifier
            If ($?) { Write-Verbose -Message "Successfully registered registry key watcher for '$ValueFullName' with source identifier '$SourceIdentifier'" -Verbose }
            Write-Verbose -Message 'Waiting for changes...' -Verbose
            Wait-Event -SourceIdentifier $SourceIdentifier | Out-Null
            [string]$Output = "$PathFullName has been modified!"
        }
        Catch {
            Throw $PsItem
        }
        Finally {
            Write-Output -InputObject $Output
        }
    }
    End {

        ## Performing cleanup by unregistering the event source and removing the generated event
        Unregister-Event -SourceIdentifier $SourceIdentifier -ErrorAction 'SilentlyContinue'
        Remove-Event -SourceIdentifier $SourceIdentifier -ErrorAction 'SilentlyContinue'
    }
}
#endregion

#region Function New-RegistryTreeWatcher
Function New-RegistryTreeWatcher {
<#
.SYNOPSIS
    Creates a watcher for a registry tree.
.DESCRIPTION
    Creates a watcher for a tree watcher using the 'RegistryTreeChangeEvent' wmi class.
.PARAMETER Hive
    Specifies the registry hive.
    Accepted values are:
        HKEY_LOCAL_MACHINE
        HKEY_USERS
        HKEY_CURRENT_CONFIG
    Defaut value is: 'HKEY_LOCAL_MACHINE'
.PARAMETER RootPath
    Specifies the registry root path to watch.
.PARAMETER SourceIdentifier
    Specifies the event source identifier.
.EXAMPLE
    New-RegistryTreeWatcher -Hive 'HKEY_LOCAL_MACHINE' -RootPath 'SOFTWARE\Microsoft\Windows\CurrentVersion\Run' -SourceIdentifier 'RegistryTreeWatcher'
.INPUTS
    None.
.OUTPUTS
    System.String
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.COMPONENT
    Registry
.FUNCTIONALITY
    Registers a WMI registry tree watcher
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$false,Position=0)]
        [ValidateNotNullorEmpty()]
        [ValidateSet('HKEY_LOCAL_MACHINE','HKEY_USERS','HKEY_CURRENT_CONFIG')]
        [Alias('RegistryHive')]
        [string]$Hive = 'HKEY_LOCAL_MACHINE',
        [Parameter(Mandatory=$true,Position=1)]
        [ValidateNotNullorEmpty()]
        [Alias('Path')]
        [string]$RootPath,
        [Parameter(Mandatory=$true,Position=3)]
        [ValidateNotNullorEmpty()]
        [Alias('Source')]
        [string]$SourceIdentifier
    )
    Begin {
        [string]$Output = $null

        ## Normalizing the path by escaping '\' characters
        $RootPath = $RootPath.Replace('\','\\')

        ## Creating the path string
        [string]$Path = Switch ($Hive) {
            'HKEY_LOCAL_MACHINE'  { 'HKLM:'; Break }
            'HKEY_USERS'          { 'HKU:' ; Break }
            'HKEY_CURRENT_CONFIG' { 'HKCC:'; Break }
            Default { 'Unsupported' }
        }

        ## Creating the full name path string
        [string]$PathFullName  = Join-Path -Path $Path -ChildPath $RootPath

        ## Build the WMI query string
        [string]$Query = "SELECT * FROM RegistryTreeChangeEvent WHERE Hive='$Hive' AND RootPath='$RootPath'"

        ## Performing cleanup by unregistering the event source and removing the generated event
        Unregister-Event -SourceIdentifier $SourceIdentifier -ErrorAction 'SilentlyContinue'
        Remove-Event -SourceIdentifier $SourceIdentifier -ErrorAction 'SilentlyContinue'
    }
    Process {
        Try {

            ## Registering the event source
            Register-WmiEvent -Query $Query -SourceIdentifier $SourceIdentifier
            If ($?) { Write-Verbose -Message "Successfully registered registry key watcher for '$PathFullName' with source identifier '$SourceIdentifier'" -Verbose }
            Write-Verbose -Message 'Waiting for changes...' -Verbose
            Wait-Event -SourceIdentifier $SourceIdentifier | Out-Null
            [string]$Output = "$PathFullName has been modified!"
        }
        Catch {
            Throw $PsItem
        }
        Finally {
            Write-Output -InputObject $Output
        }
    }
    End {

        ## Performing cleanup by unregistering the event source and removing the generated event
        Unregister-Event -SourceIdentifier $SourceIdentifier -ErrorAction 'SilentlyContinue'
        Remove-Event -SourceIdentifier $SourceIdentifier -ErrorAction 'SilentlyContinue'
    }
}
#endregion

#endregion
##*=============================================
##* END FUNCTION LISTINGS
##*=============================================

##*=============================================
##* SCRIPT BODY
##*=============================================z
#region ScriptBody

## Endless loop
While ($true) {

    ## Setting up the registry watcher
    New-RegistryTreeWatcher -Hive 'HKEY_LOCAL_MACHINE' -RootPath 'Software\Policies\Microsoft\Edge' -SourceIdentifier 'RegistryTreeWatcher'

    ## Set Registry Values if when a change is detected
    Write-Verbose -Message 'Setting Registry Values...' -Verbose
    Set-ItemProperty -Path 'HKLM:\Software\Policies\Microsoft\Edge' -Name 'HomepageLocation' -Value 'https://MEMZ.one/' -Force -PassThru
}

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================
