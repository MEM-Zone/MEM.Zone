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