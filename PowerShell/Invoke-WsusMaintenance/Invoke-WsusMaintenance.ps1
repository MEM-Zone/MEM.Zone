## TODO:
<#

Add 'SqlServer' module as a payload or use the code below to install it:

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Install-PackageProvider -Name 'NuGet'
Install-Module -Name 'SqlServer'

#>



<#
.SYNOPSIS
    Runs WSUS maintenance tasks.
.DESCRIPTION
    Runs WSUS maintenance tasks by performing various optimization and cleanup tasks.
.PARAMETER Task
    Specifies maintenance task to run.
    Valid values are:
        - 'DisableDriverSync'             - Disables driver synchronization, major performance improvement
        - 'OptimizeConfiguration'         - Optimizes WSUS configuration, by setting recommended values
        - 'OptimizeDatabase'              - Optimizes WSUS database, by adding and rebuilding indexes, and applying a performance fix for delete updates
        - 'DeclineExpiredUpdates'         - Declines expired updates
        - 'DeclineSupersededUpdates'      - Declines superseded updates
        - 'CleanupObsoleteUpdates'        - Cleans up obsolete updates
        - 'CompressUpdates'               - Deletes unneeded update revisions
        - 'CleanupObsoleteComputers'      - Cleans up obsolete computers that are no longer active
        - 'CleanupUnneededContentFiles'   - Cleans up unneeded content files that are no longer referenced
.PARAMETER ServerInstance
    Specifies a character string or SQL Server Management Objects (SMO) object that specifies the name of an instance of the Database Engine.
    For default instances, only specify the computer name: MyComputer. For named instances, use the format ComputerName\InstanceName.
    By Default the SQL Server instance is autodetected.
.PARAMETER Database
    Specifies the name of a database. This cmdlet connects to this database in the instance that is specified in the ServerInstance parameter.
    Default is: 'SUSDB'
.EXAMPLE
    Invoke-WSUSMaintenance.ps1 -ServerInstance 'SQLSERVER.contoso.com' -Database 'SUSDB' -Task 'DisableDriverSync', 'OptimizeConfiguration', 'OptimizeDatabase', 'DeclineExpiredUpdates', 'DeclineSupersededUpdates', 'CleanupObsoleteUpdates', 'CompressUpdates', 'CleanupObsoleteComputers', 'CleanupUnneededContentFiles'
.INPUTS
    None.
.OUTPUTS
    System.Object
    System.Exception
.NOTES
    Created by Ioan Popovici
.LINK
    https://MEM.Zone/Invoke-WSUSMaintenance
.LINK
    https://MEM.Zone/Invoke-WSUSMaintenance-CHANGELOG
.LINK
    https://MEM.Zone/Invoke-WSUSMaintenance-GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    WSUS
.FUNCTIONALITY
    Performs WSUS Maintenance Tasks
#>

## Set script requirements
#Requires -Version 3.0

## Get Script Parameters
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $false, HelpMessage = 'SQL server and instance name', Position = 0)]
    [ValidateNotNullorEmpty()]
    [Alias('Server')]
    [string]$ServerInstance = (Get-ItemProperty -Path 'HKLM:\Software\Microsoft\Update Services\Server\Setup' -Name 'SqlServerName').SqlServerName,
    [Parameter(Mandatory = $false, HelpMessage = 'Database name', Position = 1)]
    [ValidateNotNullorEmpty()]
    [Alias('Dbs')]
    [string]$Database = 'SUSDB',
    [Parameter(Mandatory = $true, Position = 2)]
    [ValidateNotNullorEmpty()]
    [ValidateSet(
        'DisableDriverSync', 'OptimizeConfiguration', 'OptimizeDatabase', 'DeclineExpiredUpdates', 'DeclineSupersededUpdates',
        'CleanupObsoleteUpdates', 'CompressUpdates', 'CleanupObsoleteComputers', 'CleanupUnneededContentFiles'
        )
    ]
    [Alias('Action')]
    [string[]]$Task
)

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

## Get script path and name
[string]$ScriptPath = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Definition)
[string]$ScriptName = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Definition)

#endregion
##*=============================================
##* END VARIABLE DECLARATION
##*=============================================

##*=============================================
##* FUNCTION LISTINGS
##*=============================================
#region FunctionListings


#region Function Import-Resource
Function Import-Resource {
<#
.SYNOPSIS
    Imports a script resource.
.DESCRIPTION
    Imports a script resource from a specified path.
.PARAMETER Path
    Specifies the path to the script resource.
    Default is: [System.IO.Path]::Combine($PSScriptRoot, 'Resources')
.PARAMETER Name
    Specifies the name of the script resource.
.EXAMPLE
    Import-Resource -Name 'CleanupObsoleteComputers'
.INPUTS
    None.
.OUTPUTS
    System.String
    System.Exception
.NOTES
    This is an private function and should tipically not be called directly.
.LINK
    https://MEM.Zone/
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    Invoke-WSUSMaintenance
.FUNCTIONALITY
    Imports a script resource.
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $false, HelpMessage = 'Path to the script resource')]
        [ValidateNotNullorEmpty()]
        [string]$Path = [System.IO.Path]::Combine($PSScriptRoot, 'Resources'),
        [Parameter(Mandatory = $true, HelpMessage = 'Name of the script resource')]
        [ValidateNotNullorEmpty()]
        [string]$Name
    )
    Begin {
        $Output = $null
    }
    Process {
        Try {

            ## Asseble and test file path
            [string]$FilePath = Join-Path -Path $Path -ChildPath $Name -Resolve -ErrorAction 'Stop'

            ## Set output
            Write-Verbose -Message "Importing resource '$FilePath'" -Verbose
            $Output = Get-Content -Path $FilePath -Raw
            If ([string]::IsNullOrWhiteSpace($Output)) {

                ## Return custom error. The error handling is done here in order not to break the ForEach loop and allow it to continue.
                $Exception     = [System.Exception]::new('Resource File is Empty!')
                $ExceptionType = [System.Management.Automation.ErrorCategory]::InvalidResult
                $ErrorRecord   = [System.Management.Automation.ErrorRecord]::new($Exception, $PsItem.FullyQualifiedErrorId, $ExceptionType, $FilePath)
                $PSCmdlet.WriteError($ErrorRecord)
             }
        }
        Catch {
            $PSCmdlet.WriteError($PsItem)
        }
        Finally {
            Write-Output $Output
        }
    }
}
#endregion

#region Function Get-WsusIISLocalizedPath
Function Get-WsusIISLocalizedPath {
<#
.SYNOPSIS
    Gets the WSUS IIS localized path.
.DESCRIPTION
    Gets the WSUS IIS localized path.
.EXAMPLE
    Get-WsusIISLocalizedPath
.INPUTS
    None.
.OUTPUTS
    System.String
    System.Exception
.NOTES
    This is an private function and should tipically not be called directly.
.LINK
    https://MEM.Zone/
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    IIS
.FUNCTIONALITY
    Gets the WSUS IIS localized path.
#>
    [CmdletBinding()]
    Param ()
    Begin {
        $Output = $null
    }
    Process {
        Try {
            $IISSitePhysicalPath = Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\Microsoft\Update Services\Server\Setup\' -Name 'TargetDir'
            $IISLocalizedString = (Get-Website).Where({ $PsItem.PhysicalPath.StartsWith($IISSitePhysicalPath) }).Name
            $Output = [System.IO.Path]::Combine('IIS:\Sites\', $IISLocalizedString, 'ClientWebService')
            If ([string]::IsNullOrWhiteSpace($Output)) {

                ## Return custom error. The error handling is done here in order not to break the ForEach loop and allow it to continue.
                $Exception     = [System.Exception]::new('Unable to get IIS Localized Path!')
                $ExceptionType = [System.Management.Automation.ErrorCategory]::ObjectNotFound
                $ErrorRecord   = [System.Management.Automation.ErrorRecord]::new($Exception, $PsItem.FullyQualifiedErrorId, $ExceptionType, $Output)
                $PSCmdlet.WriteError($ErrorRecord)
            }
        }
        Catch {
            $PSCmdlet.WriteError($PSItem)
        }
        Finally {
            Write-Output $Output
        }
    }
}
#endregion

#region Function Get-WsusIISConfig
Function Get-WsusIISConfig {
<#
.SYNOPSIS
    Gets the WSUS IIS configuration values.
.DESCRIPTION
    Get the WSUS IIS configuration values and optionally checks against the recommended values.
.PARAMETER CheckRecommendedValues
    Specifies if the WSUS IIS configuration values should be checked against the recommended values.
.EXAMPLE
    Get-WsusIISConfig -CheckRecommendedValues
.INPUTS
    None.
.OUTPUTS
    System.Object
    System.Exception
.NOTES
    This is an private function and should tipically not be called directly.
.LINK
    https://MEM.Zone/
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    WSUS
.FUNCTIONALITY
    Gets IIS Configuration Values.
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $false)]
        [switch]$CheckRecommendedValues
    )
    Begin {

        ## Intialize output
        $Output = @{}

        ## Define IIS recommended configuration values
        $RecommendedIISSettings = [ordered]@{
            QueueLength              = 25000
            LoadBalancerCapabilities = 'TcpLevel'
            CpuResetInterval         = 15
            RecyclingMemory          = 0
            RecyclingPrivateMemory   = 0
            ClientMaxRequestLength   = 204800
            ClientExecutionTimeout   = 7200
        }
        Write-Verbose -Message $RecommendedIISSettings
    }
    Process {
        Try {

            ## Get IIS localized path
            [string]$IISLocalizedPath = Get-WsusIISLocalizedPath

            ## Get WSUS IIS Index from registry
            [int]$IISSiteIndex = Get-ItemPropertyValue -Path 'HKLM:\Software\Microsoft\Update Services\Server\Setup' -Name 'IISTargetWebSiteIndex'

            ## IIS Site
            [string]$IISSiteName = $(Get-IISSite).Where({$PSItem.Id -eq $IISSiteIndex}).Name

            ## Site Application Pool
            [string]$IISAppPool = $(Get-WebApplication -Site $IISSiteName -Name 'ClientWebService').ApplicationPool

            ## Application Pool Config
            [Microsoft.Web.Administration.ConfigurationElement]$IISConfigElement = Get-IISConfigSection -SectionPath 'system.applicationHost/applicationPools'
            [Microsoft.Web.Administration.ConfigurationElement]$IISApplicationPoolConfig = Get-IISConfigCollection -ConfigElement $IISConfigElement

            ## WSUS Pool Config Root
            [Microsoft.Web.Administration.ConfigurationElement]$WsusPoolConfig = Get-IISConfigCollectionElement -ConfigCollection $IISApplicationPoolConfig -ConfigAttribute @{'Name' = $IISAppPool}

            ## Queue Length
            [int]$QueueLength = Get-IISConfigAttributeValue -ConfigElement $WsusPoolConfig -AttributeName 'queueLength'

            ## Load Balancer Capabilities
            [Microsoft.Web.Administration.ConfigurationElement]$WsusPoolFailureConfig = Get-IISConfigElement -ConfigElement $WsusPoolConfig -ChildElementName 'failure'
            [string]$LoadBalancerCapabilities = Get-IISConfigAttributeValue -ConfigElement $WsusPoolFailureConfig -AttributeName 'loadBalancerCapabilities'

            ## CPU Reset Interval
            [Microsoft.Web.Administration.ConfigurationElement]$WsusPoolCpuConfig = Get-IISConfigElement -ConfigElement $WsusPoolConfig -ChildElementName 'cpu'
            [int]$CpuResetInterval = $(Get-IISConfigAttributeValue -ConfigElement $WsusPoolCpuConfig -AttributeName 'resetInterval').TotalMinutes

            ## Recycling Config Root
            [Microsoft.Web.Administration.ConfigurationElement]$WsusPoolRecyclingConfig = Get-IISConfigElement -ConfigElement $WsusPoolConfig -ChildElementName 'recycling' |
                Get-IISConfigElement -ChildElementName 'periodicRestart'
            #  Recycling Memory
            [int]$RecyclingMemory = Get-IISConfigAttributeValue -ConfigElement $WsusPoolRecyclingConfig -AttributeName 'memory'
            #  Recycling Private Memory
            [int]$RecyclingPrivateMemory = Get-IISConfigAttributeValue -ConfigElement $WsusPoolRecyclingConfig -AttributeName 'privateMemory'

            ## Web service config
            [Microsoft.IIs.PowerShell.Framework.ConfigurationElement]$ClientWebServiceConfig = Get-WebConfiguration -PSPath $IISLocalizedPath -Filter 'system.web/httpRuntime'
            #  MaxRequestLength
            [int]$ClientMaxRequestLength = $ClientWebServiceConfig.maxRequestLength
            #  ExecutionTimeout
            [int]$ClientExecutionTimeout = $($ClientWebServiceConfig.executionTimeout).TotalSeconds

            ## Assemble output object
            $Settings = [ordered]@{
                QueueLength              = $QueueLength
                LoadBalancerCapabilities = $LoadBalancerCapabilities
                CpuResetInterval         = $CpuResetInterval
                RecyclingMemory          = $RecyclingMemory
                RecyclingPrivateMemory   = $RecyclingPrivateMemory
                ClientMaxRequestLength   = $ClientMaxRequestLength
                ClientExecutionTimeout   = $ClientExecutionTimeout
            }

            ## Initialize output object
            $Output = ForEach ($Setting in $Settings.GetEnumerator()) {
                [pscustomobject]@{
                    Name               = $Setting.Name
                    Value              = $Setting.Value
                    RecommendedValue   = $RecommendedIISSettings[$Setting.Name]
                    IsRecommendedValue = If ($RecommendedIISSettings[$Setting.Name] -eq $Setting.Value) { $true } Else { $false }
                }
            }
            If (-not $CheckRecommendedValues) { $Output = $Output | Select-Object -Property 'Name', 'Value' }
        }
        Catch {

            ## Return custom error. The error handling is done here in order not to break the ForEach loop and allow it to continue.
            $Exception     = [System.Exception]::new('Error testing WSUS configuration value!')
            $ExceptionType = [System.Management.Automation.ErrorCategory]::InvalidResult
            $ErrorRecord   = [System.Management.Automation.ErrorRecord]::new($Exception, $PsItem.FullyQualifiedErrorId, $ExceptionType, $Settings)
            $PSCmdlet.WriteError($ErrorRecord)
        }
        Finally {
            Write-Output $Output
        }
    }
}
#endregion

#region Function Set-FilePermission
Function Set-FilePermission {
<#
.SYNOPSIS
    Sets file system permissions.
.DESCRIPTION
    Sets file system permissions, by modifiying the file ACLs.
.PARAMETER File
    Secifies the file to modify.
.PARAMETER Identity
    Specifies the identity to grant permissions to.
.PARAMETER FileSystemRights
    Specifies the file system rights to grant.
    Allowed values:
        - AppendData
        - ChangePermissions
        - CreateDirectories
        - CreateFiles
        - Delete
        - DeleteSubdirectoriesAndFiles
        - ExecuteFile
        - FullControl
        - ListDirectory
        - Modify
        - Read
        - ReadAndExecute
        - ReadAttributes
        - ReadData
        - ReadExtendedAttributes
        - ReadPermissions
        - Synchronize
        - TakeOwnership
        - Traverse
        - Write
        - WriteAttributes
        - WriteData
        - WriteExtendedAttributes
.PARAMETER InheritanceFlags
    Specifies the inheritance flags to use.
    Allowed values:
        - ContainerInherit
        - None
        - ObjectInherit
.PARAMETER PropagationFlags
    Specifies the propagation flags to use.
    Allowed values:
        - None
        - InheritOnly
        - NoPropagateInherit
.PARAMETER AccessControlType
    Specifies the access control type to use.
    Allowed values:
        - Allow
        - Deny
.PARAMETER SetOwner
    Specifies whether to set the owner of the file.
.PARAMETER SetReadWrite
    Specifies whether to set the file as Read/Write.
.EXAMPLE
    Set-FilePermission -File 'C:\Windows\Temp\test.txt' -Identity 'Everyone' -FileSystemRights 'Read' -InheritanceFlags 'None' -PropagationFlags 'None' -AccessControlType 'Allow' -SetOwner $true -SetReadonly $false
.INPUTS
    None.
.OUTPUTS
    System.String
    System.Exception
.NOTES
    This is an private function and should tipically not be called directly.
.LINK
    https://MEM.Zone/
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    File System
.FUNCTIONALITY
    Sets File System Permissions
#>
    [CmdletBinding(DefaultParameterSetName='Default')]
    Param (
        [Parameter(Mandatory = $true, ParameterSetName = 'Default', Position = 0)]
        [Parameter(Mandatory = $true, ParameterSetName = 'Owner', Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$File,
        [Parameter(Mandatory = $true, ParameterSetName = 'Default', Position = 1)]
        [Parameter(Mandatory = $true, ParameterSetName = 'Owner', Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$Identity,
        [Parameter(Mandatory = $true, ParameterSetName = 'Default', Position = 2)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('AppendData', 'ChangePermissions', 'CreateDirectories', 'CreateFiles', 'Delete', 'DeleteSubdirectoriesAndFiles', 'ExecuteFile', 'FullControl', 'ListDirectory', 'Modify', 'Read', 'ReadAndExecute', 'ReadAttributes', 'ReadData', 'ReadExtendedAttributes', 'ReadPermissions', 'Synchronize', 'TakeOwnership', 'Traverse', 'Write', 'WriteAttributes', 'WriteData', 'WriteExtendedAttributes')]
        [string[]]$FileSystemRights,
        [Parameter(Mandatory = $true, ParameterSetName = 'Default', Position = 3)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('ContainerInherit', 'None', 'ObjectInherit')]
        [string]$InheritanceFlags,
        [Parameter(Mandatory = $true, ParameterSetName = 'Default', Position = 4)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('None', 'InheritOnly', 'NoPropagateInherit')]
        [string]$PropagationFlags,
        [Parameter(Mandatory = $true, ParameterSetName = 'Default', Position = 4)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Allow', 'Deny')]
        [string]$AccessControlType,
        [Parameter(Mandatory = $true, ParameterSetName = 'Owner', Position = 3)]
        [switch]$SetOwner,
        [Parameter(Mandatory = $false, ParameterSetName = 'Default', Position = 6)]
        [Parameter(Mandatory = $false, ParameterSetName = 'Owner', Position = 4)]
        [switch]$SetReadWrite
    )
    Begin {

        ## Initialize variables
        $Output = $null
    }
    Process {
        Try {

            ## Get file Acl
            $AclObject = Get-Acl($File)

            ## Set file owner
            If ($PSCmdlet.ParameterSetName -eq 'Owner') {
                $NTAccount = New-Object -TypeName 'System.Security.Principal.NTAccount' -ArgumentList $Identity
                $AclObject.SetOwner($NTAccount)
                Set-Acl -Path $File -AclObject $AclObject
            }

            ## Set file permissions
            If ($PSCmdlet.ParameterSetName -eq 'Default') {
                $FileSystemAccessRule = New-Object -TypeName 'System.Security.AccessControl.FileSystemAccessRule' -ArgumentList $($Identity, $FileSystemRights, $InheritanceFlags, $PropagationFlags, $AccessControlType)
                $AclObject.SetAccessRule($FileSystemAccessRule)
                Set-Acl -Path $File -AclObject $AclObject
            }

            ## Set file as Read/Write
            If ($SetReadWrite) { Set-ItemProperty -Path $File -Name 'IsReadOnly' -Value $false }

            ## Set output
            $Output = "Successfully set permissions on '{0}'" -f $File
        }
        Catch {
            Throw (New-Object System.Exception("Setting permissions on '{0}' failed! {1} -f $File, $($PsItem.Exception.Message)", $PsItem.Exception))
        }
        Finally {
            Write-Output -InputObject $Output
        }
    }
}
#endregion

#region Function Set-WsusIISConfig
Function Set-WsusIISConfig {
<#
.SYNOPSIS
    Sets the WSUS IIS configuration values.
.DESCRIPTION
    Sets the WSUS IIS configuration values to the ones specified.
.PARAMETER Name
    Specifies the name of the IIS configuration value to set.
    Allowed values:
        - QueueLength
        - LoadBalancerCapabilities
        - CpuResetInterval
        - RecyclingMemory
        - RecyclingPrivateMemory
        - ClientMaxRequestLength
        - ClientExecutionTimeout
.PARAMETER Value
    Specifies the value of the IIS configuration value to set.
.EXAMPLE
    Set-WsusIISConfig -Name 'QueueLength' -Value 100000
.INPUTS
    None.
.OUTPUTS
    System.Object
    System.Exception
.NOTES
    Supports ShouldProcess.
    This is an private function and should tipically not be called directly.
.LINK
    https://MEM.Zone/
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    WSUS
.FUNCTIONALITY
    Sets IIS Configuration Values.
#>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Low')]
    Param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateSet('QueueLength', 'LoadBalancerCapabilities', 'CpuResetInterval', 'RecyclingMemory', 'RecyclingPrivateMemory',
            'ClientMaxRequestLength', 'ClientExecutionTimeout'
            )
        ]
        [Alias('SettingKey')]
        [string]$Name,
        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [Alias('SettingValue')]
        $Value
    )
    Begin {

        ## Intialize output
        [pscustomobject]$Output = [ordered]@{
            'Name' = $Name
            'Value' = $Value
            'Operation' = 'N/A'
        }
    }
    Process {
        Try {

            ## Get IIS localized path
            [string]$IISLocalizedPath = Get-WsusIISLocalizedPath

            ## Get the WSUS IIS WebConfigFile path
            [string]$WsusWebConfigFilePath = (Get-WebConfigFile -PSPath $IISLocalizedPath).FullName

            ## Get localized BUILTIN\Administrators group
            [string]$BuiltinAdminGroup = ([System.Security.Principal.SecurityIdentifier]'S-1-5-32-544').Translate([System.Security.Principal.NTAccount]).Value

            ## Set the WSUS IIS WebConfigFile permissions script block
            [scriptblock]$SetWebConfigFilePermissions = {
                Set-FilePermission -File $WsusWebConfigFilePath -Identity $BuiltinAdminGroup -SetOwner
                Set-FilePermission -File $WsusWebConfigFilePath -Identity $BuiltinAdminGroup -FileSystemRights 'FullControl' -InheritanceFlags 'None' -PropagationFlags 'None' -AccessControlType 'Allow' -SetReadWrite
            }

            ## Get WSUS IIS Index from registry
            [int]$IISSiteIndex = Get-ItemPropertyValue -Path 'HKLM:\Software\Microsoft\Update Services\Server\Setup' -Name 'IISTargetWebSiteIndex'

            ## IIS Site
            [string]$IISSiteName = $(Get-IISSite).Where({$PSItem.Id -eq $IISSiteIndex}).Name

            ## Site Application Pool
            [string]$IISAppPool = $(Get-WebApplication -Site $IISSiteName -Name 'ClientWebService').ApplicationPool

            ## Application Pool Config
            [Microsoft.Web.Administration.ConfigurationElement]$IISConfigElement = Get-IISConfigSection -SectionPath 'system.applicationHost/applicationPools'
            [Microsoft.Web.Administration.ConfigurationElement]$IISApplicationPoolConfig = Get-IISConfigCollection -ConfigElement $IISConfigElement

            ## WSUS Pool Config Root
            [Microsoft.Web.Administration.ConfigurationElement]$WsusPoolConfig = Get-IISConfigCollectionElement -ConfigCollection $IISApplicationPoolConfig -ConfigAttribute @{'Name' = $IISAppPool }

            ## WSUS Pool CPU Config
            [Microsoft.Web.Administration.ConfigurationElement]$WsusPoolCpuConfig = Get-IISConfigElement -ConfigElement $WsusPoolConfig -ChildElementName 'cpu'

            ## Load Balancer Capabilities
            [Microsoft.Web.Administration.ConfigurationElement]$WsusPoolFailureConfig = Get-IISConfigElement -ConfigElement $WsusPoolConfig -ChildElementName 'failure'

            ## Recycling Config Root
            [Microsoft.Web.Administration.ConfigurationElement]$WsusPoolRecyclingConfig = Get-IISConfigElement -ConfigElement $WsusPoolConfig -ChildElementName 'recycling' |
                Get-IISConfigElement -ChildElementName 'periodicRestart'

            ## Set value if allowed by should process
            [boolean]$ShouldProcess = $PSCmdlet.ShouldProcess("$Name", "Set Value to $Value")
            If ($ShouldProcess) {
                #  Force terminating errors
                $SavedErrorActionPreference = $ErrorActionPreference
                $ErrorActionPreference = 'Stop'
                #  Handle WSUS IIS Config setting based on input name
                Switch ($Name) {
                    'QueueLength' {
                        # Queue Length
                        Set-IISConfigAttributeValue -ConfigElement $WsusPoolConfig -AttributeName 'queueLength' -AttributeValue $Value
                        Break
                    }
                    'LoadBalancerCapabilities' {
                        # Load Balancer Capabilities
                        Set-IISConfigAttributeValue -ConfigElement $WsusPoolFailureConfig -AttributeName 'loadBalancerCapabilities' -AttributeValue $Value
                        Break
                    }
                    'CpuResetInterval' {
                        # CPU Reset Interval
                        Set-IISConfigAttributeValue -ConfigElement $WsusPoolCpuConfig -AttributeName 'resetInterval' -AttributeValue ([timespan]::FromMinutes($Value))
                        Break
                    }
                    'RecyclingMemory' {
                        Set-IISConfigAttributeValue -ConfigElement $WsusPoolRecyclingConfig -AttributeName 'memory' -AttributeValue $Value
                        Break
                    }
                    'RecyclingPrivateMemory' {
                        Set-IISConfigAttributeValue -ConfigElement $WsusPoolRecyclingConfig -AttributeName 'privateMemory' -AttributeValue $Value
                        Break
                    }
                    'ClientMaxRequestLength' {
                        #  Set the IIS WSUS Client Web Service web.config writable
                        $null = & $SetWebConfigFilePermissions
                        #  Set the ClientMaxRequestLength value in the web.config
                        Set-WebConfigurationProperty -PSPath $IISLocalizedPath -Filter 'system.web/httpRuntime' -Name 'maxRequestLength' -Value $Value
                        Break
                    }
                    'ClientExecutionTimeout' {
                        #  Set the IIS WSUS Client Web Service web.config writable
                        $null = & $SetWebConfigFilePermissions
                        #  Set the ClientExecutionTimeout value in the web.config
                        Set-WebConfigurationProperty -PSPath $IISLocalizedPath -Filter 'system.web/httpRuntime' -Name 'executionTimeout' -Value ([timespan]::FromSeconds($Value))
                        Break
                    }
                }

                ## Restore ErrorActionPreference to previous value
                $ErrorActionPreference = $SavedErrorActionPreference

                ## Set operation success
                $Output.Operation = 'Updated'
                Write-Verbose -Message "Updated IIS Setting '$Name' with '$Value'."
            }
        }
        Catch {
            $Output.Operation = 'Failed'
            Throw (New-Object System.Exception("Error updating '$Name' with '$Value'! $($PsItem.Exception.Message)", $PsItem.Exception))
        }
        Finally {
            Write-Output $Output
        }
    }
}
#endregion

#region Function Optimize-WsusConfiguration
Function Optimize-WsusConfiguration {
<#
.SYNOPSIS
    Sets the WSUS IIS recommended configuration values.
.DESCRIPTION
    Sets the WSUS IIS recommended configuration values or just lists them.
.PARAMETER ListOnly
    Lists the WSUS IIS configuration values without changing them.
.EXAMPLE
    Optimize-WsusConfiguration -ListOnly
.EXAMPLE
    Optimize-WsusConfiguration -Confirm:$false
.INPUTS
    None.
.OUTPUTS
    System.Object
    System.Exception
.NOTES
    Supports ShouldProcess.
    This is an private function and should tipically not be called directly.
.LINK
    https://MEM.Zone/
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    WSUS
.FUNCTIONALITY
    Sets the IIS Recomended Configuration Values.
#>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    Param (
        [switch]$ListOnly
    )

    Begin {

        ## Intialize output
        $Output = $null
    }
    Process {
        Try {

            ## Get the WSUS IIS configuration values and check if they are set to the recommended values
            $WsusIISSettings = Get-WsusIISConfig -CheckRecommendedValues

            ## If the -ListOnly switch is not used and there are non-recommended values, then set the WSUS IIS configuration values to the recommended values
            If (-not $ListOnly) {
                #  Add the 'Operation' property to the output
                $WsusIISSettings | Add-Member -MemberType 'NoteProperty' -Name 'Operation' -Value 'Skipped'
                #  Process each WSUS IIS configuration value
                ForEach ($WsusIISSetting in $WsusIISSettings) {
                    #  Set the WSUS IIS configuration value to the recommended value if it is not already set to the recommended value
                    If ($WsusIISSetting.IsRecommendedValue -eq $false) {
                        [boolean]$ShouldProcess = $PSCmdlet.ShouldProcess("$($WsusIISSetting.Name)", "Change Value from '$($WsusIISSetting.Value)' to '$($WsusIISSetting.RecommendedValue)'")
                        #  Confirm the change if the -Confirm switch is used
                        If ($ShouldProcess) {
                            $null = Set-WsusIISConfig -Name $WsusIISSetting.Name -Value $WsusIISSetting.RecommendedValue -Confirm:$false
                            If ($?) { $WsusIISSetting.Operation = 'Updated' } Else { $WsusIISSetting.Operation = 'Failed' }
                        }
                    }
                }
            }

            ## Set output
            $Output = $WsusIISSettings | Format-Table
        }
        Catch {
            Throw (New-Object System.Exception("Error optimizing WSUS configuration values! $($PsItem.Exception.Message)", $PsItem.Exception))
        }
        Finally {
            Write-Output $Output
        }
    }
}
#endregion

#region Function Optimize-WsusDatabase
Function Optimize-WsusDatabase {
<#
.SYNOPSIS
    Optimizes a WSUS database.
.DESCRIPTION
    Optimizes a WSUS database by performing specified maintenance tasks.
.PARAMETER Task
    Specifies maintenance task to run.
    Available values:
        'CreateIndexes'        - Created NonClustered Indexes on the WSUS 'tbRevisionSupersedesUpdate' and 'tbLocalizedPropertyForRevision' tables.
        'RebuildIndexes'       - Identifies indexes that are fragmented, and defragments them. For certain tables, a fill factor is set to improve
                                 insert performance. Updates potentially out-of-date table statistics.
        'SlowDeleteUpdateFix'  - Sets a primary key on the @revisionList temporary table in order to speed up the delete update operation.
        Default value is: @('CreateIndexes', 'RebuildIndexes', 'SlowDeleteUpdateFix').
.PARAMETER ServerInstance
    Specifies a character string or SQL Server Management Objects (SMO) object that specifies the name of an instance of the Database Engine. For default instances, only specify the computer name: MyComputer.
    For named instances, use the format ComputerName\InstanceName.
    Default value is automatically detected.
.PARAMETER Database
    Specifies the name of a database. This cmdlet connects to this database in the instance that is specified in the ServerInstance parameter.
    Default is: 'SUSDB'
.EXAMPLE
    Optimize-WsusDatabase -Task 'CreateIndexes', 'RebuildIndexes', 'SlowDeleteUpdateFix' -ServerInstance 'SQLServerFQDN' -Database 'SUSDB'
.INPUTS
    None.
.OUTPUTS
    System.Object
    System.Exception
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.COMPONENT
    WSUS
.FUNCTIONALITY
    WSUS Database Optimization
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $false, HelpMessage = 'SQL server and instance name', Position = 0)]
        [ValidateNotNullorEmpty()]
        [Alias('Server')]
        [string]$ServerInstance = (Get-ItemProperty -Path 'HKLM:\Software\Microsoft\Update Services\Server\Setup' -Name 'SqlServerName').SqlServerName,
        [Parameter(Mandatory = $false, HelpMessage = 'Database name', Position = 1)]
        [ValidateNotNullorEmpty()]
        [Alias('Dbs')]
        [string]$Database = 'SUSDB',
        [Parameter(Mandatory = $true, Position = 2)]
        [ValidateNotNullorEmpty()]
        [ValidateSet('CreateIndexes','RebuildIndexes','SlowDeleteUpdateFix')]
        [Alias('Action')]
        [string[]]$Task
    )

    Begin {

        ## Intitialize Output
        $Output = [System.Collections.Generic.List[object]]::new()

        ## Define Result Template
        [hashtable]$OutputProps = [ordered]@{
            'Task' = 'N/A'
            'Output' = 'N/A'
            'Operation' = 'N/A'
        }
    }
    Process {
        Try {
            Switch ($PSBoundParameters['Task']) {
                'CreateIndexes' {
                    #  Update Result
                    $Result = $OutputProps.Clone()
                    $Result.Task = 'CreateIndexes'
                    #  Import SQL query
                    $CreateIndexes  = Import-Resource -Name 'CreateIndexes.sql'-ErrorAction 'Stop'
                    Write-Verbose -Message "Creating 'IX_tbRevisionSupersedesUpdate' and 'IX_tbLocalizedPropertyForRevision' indexes..." -Verbose
                    #  Execute query
                    Invoke-SQLCmd -ServerInstance $ServerInstance -Database $Database -Query $CreateIndexes -QueryTimeout 0
                    #  Update Result
                    $Result.Operation = 'Successful'
                    $Output.Add([pscustomobject]$Result)
                }
                'RebuildIndexes' {
                    #  Update Result
                    $Result = $OutputProps.Clone()
                    $Result.Task = 'RebuildIndexes'
                    #  Import SQL query
                    $RebuildIndexes = Import-Resource -Name 'RebuildIndexes.sql' -ErrorAction 'Stop'
                    Write-Verbose -Message 'Rebuilding indexes, please wait...' -Verbose
                    #  Execute query
                    Invoke-SQLCmd -ServerInstance $ServerInstance -Database $Database -Query $RebuildIndexes -QueryTimeout 0
                    #  Update Result
                    $Result.Operation = 'Successful'
                    $Output.Add([pscustomobject]$Result)
                }
                'SlowDeleteUpdateFix' {
                    #  Update Result
                    $Result = $OutputProps.Clone()
                    $Result.Task = 'SlowDeleteUpdateFix'
                    #  Import SQL query
                    $SlowDeleteUpdateFix = Import-Resource -Name 'SlowDeleteUpdateFix.sql' -ErrorAction 'Stop'
                    Write-Verbose -Message 'Applying spDeleteUpdate performance fix...' -Verbose
                    #  Execute query
                    Invoke-SQLCmd -ServerInstance $ServerInstance -Database $Database -Query $SlowDeleteUpdateFix -QueryTimeout 0
                    #  Update Result
                    $Result.Operation = 'Successful'
                    $Output.Add([pscustomobject]$Result)
                }
            }
        }
        Catch {

            ## Set Output
            $Result.Operation = 'Failed'
            $Output.Add([pscustomobject]$Result)

            ## Return custom error. The error handling is done here in order not to break the ForEach loop and allow it to continue.
            $Exception     = [System.Exception]::new("Error running optimization task! $($PsItem.Exception.Message)")
            $ExceptionType = [System.Management.Automation.ErrorCategory]::OperationStopped
            $ErrorRecord   = [System.Management.Automation.ErrorRecord]::new($Exception, $PsItem.FullyQualifiedErrorId, $ExceptionType, $Result.OptimizationTask)
            $PSCmdlet.ThrowTerminatingError($ErrorRecord)
        }
        Finally {
            Write-Output -InputObject $Output
        }
    }
}
#endregion

#region Function Invoke-WSUSMaintenance
Function Invoke-WSUSMaintenance {
<#
.SYNOPSIS
    Runs WSUS maintenance tasks.
.DESCRIPTION
    Runs WSUS maintenance tasks by performing various optimization and cleanup tasks.
.PARAMETER Task
    Specifies maintenance task to run.
    Valid values are:
        - 'DisableDriverSync'             - Disables driver synchronization, major performance improvement
        - 'OptimizeConfiguration'         - Optimizes WSUS configuration, by setting recommended values
        - 'OptimizeDatabase'              - Optimizes WSUS database, by adding and rebuilding indexes, and applying a performance fix for delete updates
        - 'DeclineExpiredUpdates'         - Declines expired updates
        - 'DeclineSupersededUpdates'      - Declines superseded updates
        - 'CleanupObsoleteUpdates'        - Cleans up obsolete updates
        - 'CompressUpdates'               - Deletes unneeded update revisions
        - 'CleanupObsoleteComputers'      - Cleans up obsolete computers that are no longer active
        - 'CleanupUnneededContentFiles'   - Cleans up unneeded content files that are no longer referenced
.PARAMETER ServerInstance
    Specifies a character string or SQL Server Management Objects (SMO) object that specifies the name of an instance of the Database Engine.
    For default instances, only specify the computer name: MyComputer. For named instances, use the format ComputerName\InstanceName.
.PARAMETER Database
    Specifies the name of a database. This cmdlet connects to this database in the instance that is specified in the ServerInstance parameter.
    Default is: 'SUSDB'
.EXAMPLE
    Invoke-WSUSMaintenance -ServerInstance 'SQLSERVER.contoso.com' -Database 'SUSDB' -Task 'DisableDriverSync', 'OptimizeConfiguration', 'OptimizeDatabase', 'DeclineExpiredUpdates', 'DeclineSupersededUpdates', 'CleanupObsoleteUpdates', 'CompressUpdates', 'CleanupObsoleteComputers', 'CleanupUnneededContentFiles'
.INPUTS
    None.
.OUTPUTS
    System.System.Collections.Generic.List
    System.Exception
.NOTES
    This is an private function and should tipically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.COMPONENT
    WSUS
.FUNCTIONALITY
    Performs WSUS Maintenance Tasks
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $false, HelpMessage = 'SQL server and instance name', Position = 0)]
        [ValidateNotNullorEmpty()]
        [Alias('Server')]
        [string]$ServerInstance = (Get-ItemProperty -Path 'HKLM:\Software\Microsoft\Update Services\Server\Setup' -Name 'SqlServerName').SqlServerName,
        [Parameter(Mandatory = $false, HelpMessage = 'Database name', Position = 1)]
        [ValidateNotNullorEmpty()]
        [Alias('Dbs')]
        [string]$Database = 'SUSDB',
        [Parameter(Mandatory = $true, Position = 2)]
        [ValidateNotNullorEmpty()]
        [ValidateSet(
            'DisableDriverSync', 'OptimizeConfiguration', 'OptimizeDatabase', 'DeclineExpiredUpdates', 'DeclineSupersededUpdates',
            'CleanupObsoleteUpdates', 'CompressUpdates', 'CleanupObsoleteComputers', 'CleanupUnneededContentFiles'
            )
        ]
        [Alias('Action')]
        [string[]]$Task
    )
    Begin {

        ## Intitialize Output
        $Output = [System.Collections.Generic.List[object]]::new()

        ## Define Result Template
        [hashtable]$OutputProps = [ordered]@{
            'Task' = 'N/A'
            'Output' = 'N/A'
            'Operation' = 'N/A'
        }
    }
    Process {
        Try {
            Switch ($PSBoundParameters['Task']) {
                'DisableDriverSync' {
                    $Result = $OutputProps.Clone()
                    $Result.Task = 'DisableDriverSync'
                    Write-Verbose -Message 'Disable WSUS driver sync...' -Verbose
                    $WsusClassification = (Get-WsusClassification).Where({ $PSItem.Classification.Title -in ('Drivers', 'Driver Sets') })
                    $null = $WsusClassification | Set-WsusClassification -Disable
                    $Result.Output = $WsusClassification.Count
                    $Result.Operation = 'Successful'
                    $Output.Add([pscustomobject]$Result)
                }
                'OptimizeConfiguration' {
                    $Result = $OutputProps.Clone()
                    $Result.Task = 'OptimizeConfiguration'
                    Write-Verbose -Message 'Optimize WSUS configuration...' -Verbose
                    Optimize-WsusConfiguration
                    $Result.Output = 'Optimized'
                    $Result.Operation = 'Successful'
                    $Output.Add([pscustomobject]$Result)
                }
                'OptimizeDatabase' {
                    $Result = $OutputProps.Clone()
                    $Result.Task = 'OptimizeDatabase'
                    Write-Verbose -Message 'Optimize WSUS database...' -Verbose
                    $null = Optimize-WsusDatabase -ServerInstance $ServerInstance -Database $Database -Task CreateIndexes, RebuildIndexes, SlowDeleteUpdateFix
                    $Result.Output = 'Optimized'
                    $Result.Operation = 'Successful'
                    $Output.Add([pscustomobject]$Result)
                }
                'DeclineExpiredUpdates' {
                    $Result = $OutputProps.Clone()
                    $Result.Task = 'DeclineExpiredUpdates'
                    Write-Verbose -Message 'Declining expired updates. This may take a while...' -Verbose
                    $Result.Output = (Invoke-SQLCmd -ServerInstance $ServerInstance -Database $Database -Query 'EXEC spDeclineExpiredUpdates' -QueryTimeout 0).Column1
                    $Result.Operation = 'Successful'
                    $Output.Add([pscustomobject]$Result)
                }
                'DeclineSupersededUpdates' {
                    $Result = $OutputProps.Clone()
                    $Result.Task = 'DeclineSupersededUpdates'
                    Write-Verbose -Message 'Declining superseded updates. This may take a while...' -Verbose
                    $Result.Output = (Invoke-SQLCmd -ServerInstance $ServerInstance -Database $Database -Query 'EXEC spDeclineSupersededUpdates' -QueryTimeout 0).Column1
                    $Result.Operation = 'Successful'
                    $Output.Add([pscustomobject]$Result)
                }
                'CleanupObsoleteUpdates' {
                    $Result = $OutputProps.Clone()
                    $Result.Task = 'CleanupObsoleteUpdates'
                    [string]$CleanupObsoleteUpdates = Import-Resource -Name 'CleanupObsoleteUpdates.sql'
                    Write-Verbose -Message 'Deleting obsolete updates. This may take a while...' -Verbose
                    $Result.Output = (Invoke-SQLCmd -ServerInstance $ServerInstance -Database $Database -Query $CleanupObsoleteUpdates -QueryTimeout 0).Column1
                    $Result.Operation = 'Successful'
                    $Output.Add([pscustomobject]$Result)
                }
                'CompressUpdates' {
                    $Result = $OutputProps.Clone()
                    $Result.Task = 'CompressUpdates'
                    [string]$CompressUpdates = Import-Resource -Name 'CompressUpdates.sql'
                    Write-Verbose -Message 'Deleting update revisions. This may take a while...' -Verbose
                    $Result.Output = (Invoke-SQLCmd -ServerInstance $ServerInstance -Database $Database -Query $CompressUpdates -QueryTimeout 0).Column1
                    $Result.Operation = 'Successful'
                    $Output.Add([pscustomobject]$Result)
                }
                'CleanupObsoleteComputers' {
                    $Result = $OutputProps.Clone()
                    $Result.Task = 'CleanupObsoleteComputers'
                    Write-Verbose -Message 'Cleaning up obsolete computers. This make take a while...' -Verbose
                    $Result.Output = (Invoke-SQLCmd -ServerInstance $ServerInstance -Database $Database -Query 'EXEC spCleanupObsoleteComputers' -QueryTimeout 0).Column1
                    $Result.Operation = 'Successful'
                    $Output.Add([pscustomobject]$Result)
                }
                'CleanupUnneededContentFiles' {
                    $Result = $OutputProps.Clone()
                    $Result.Task = 'CleanupUnneededContentFiles'
                    Write-Verbose -Message 'Cleaning up uneeded content files. This make take a while...' -Verbose
                    $null = Invoke-SQLCmd -ServerInstance $ServerInstance -Database $Database -Query 'EXEC spCleanupUnneededContentFiles' -QueryTimeout 0
                    $Result.Output = 'Cleaned'
                    $Result.Operation = 'Successful'
                    $Output.Add([pscustomobject]$Result)
                }
            }
        }
        Catch {

            ## Set Output
            $Result.Operation = 'Failed'
            $Output.Add([pscustomobject]$Result)

            ## Return custom error. The error handling is done here in order not to break the ForEach loop and allow it to continue.
            $Exception     = [System.Exception]::new("Error running cleanup task! $($PsItem.Exception.Message)")
            $ExceptionType = [System.Management.Automation.ErrorCategory]::OperationStopped
            $ErrorRecord   = [System.Management.Automation.ErrorRecord]::new($Exception, $PsItem.FullyQualifiedErrorId, $ExceptionType, $Result.Task)
            $PSCmdlet.ThrowTerminatingError($ErrorRecord)
        }
        Finally {
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

## Write verbose info
Write-Verbose -Message $("Script '{0}\{1}' started." -f $ScriptPath, $ScriptName) -Verbose

Invoke-WSUSMaintenance -ServerInstance $ServerInstance -Database $Database -Task $Task

## Write verbose info
Write-Verbose -Message $("Script '{0}\{1}' completed." -f $ScriptPath, $ScriptName) -Verbose

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================