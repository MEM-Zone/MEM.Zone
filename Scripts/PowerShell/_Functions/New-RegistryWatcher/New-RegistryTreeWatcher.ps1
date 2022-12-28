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