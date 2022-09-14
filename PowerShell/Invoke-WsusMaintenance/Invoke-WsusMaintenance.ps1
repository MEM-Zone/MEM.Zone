<#
.SYNOPSIS
    Runs WSUS maintenance tasks.
.DESCRIPTION
    Runs WSUS maintenance tasks by running specified optimization and cleanup tasks.
.PARAMETER Task
    Specifies maintenance task to run.
    Valid values are:
        - 'DisableDriverSync'             - Disables driver synchronization, major performance improvement
        - 'OptimizeConfiguration'         - Optimizes WSUS configuration, by setting recommended values
        - 'OptimizeDatabase'              - Optimizes WSUS database, by adding and rebuilding indexes, and applying a performance fix for delete updates
        - 'DeclineExpiredUpdates'         - Declines expired updates
        - 'DeclineSupersededUpdates'      - Declines superseded updates
        - 'CleanupObsoleteUpdates'        - Cleans up obsolete updates
        - 'CompressUpdates'               - Deletes unneded update revisions
        - 'CleanupObsoleteComputers'      - Cleans up obsolete computers that are no longer active
        - 'CleanupUnneededContentFiles'   - Cleans up unneeded content files that are no longer referenced
.PARAMETER ServerInstance
    Specifies a character string or SQL Server Management Objects (SMO) object that specifies the name of an instance of the Database Engine.
    For default instances, only specify the computer name: MyComputer. For named instances, use the format ComputerName\InstanceName.
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
    [Parameter(Mandatory = $true, HelpMessage = 'SQL server and instance name', Position = 0)]
    [ValidateNotNullorEmpty()]
    [Alias('Server')]
    [string]$ServerInstance,
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

#region Function Invoke-SQLQuery
Function Invoke-SQLQuery {
<#
.SYNOPSIS
    Runs an SQL query.
.DESCRIPTION
    Runs an SQL query without any dependencies except .net.
.PARAMETER ServerInstance
    Specifies a character string or SQL Server Management Objects (SMO) object that specifies the name of an instance of the Database Engine.
    For default instances, only specify the computer name: MyComputer. For named instances, use the format ComputerName\InstanceName.
.PARAMETER Database
    Specifies the name of a database. This cmdlet connects to this database in the instance that is specified in the ServerInstance parameter.
.PARAMETER Username
    Specifies the login ID for making a SQL Server Authentication connection to an instance of the Database Engine.
    If Username and Password are not specified, this cmdlet attempts a Windows Authentication connection using the Windows account running the
    Windows PowerShell session. When possible, use Windows Authentication.
.PARAMETER Password
    Specifies the password for the SQL Server Authentication login ID that was specified in the Username parameter.
    If Username and Password are not specified, this cmdlet attempts a Windows Authentication connection using the Windows account running the
    Windows PowerShell session. When possible, use Windows Authentication.
.PARAMETER Query
    Specifies one or more queries that this cmdlet runs.
.PARAMETER ConnectionTimeout
    Specifies the number of seconds when this cmdlet times out if it cannot successfully connect to an instance of the Database Engine.
    The timeout value must be an integer value between 0 and 65534. If 0 is specified, connection attempts does not time out.
    Default is: '0'.
.PARAMETER UseSQLAuthentication
    Specifies to use SQL Server Authentication instead of Windows Authentication. You will be asked for credentials if this switch is used.
.EXAMPLE
    Invoke-SQLQuery -ServerInstance 'CM-SQL-RS-01A' -Database 'CM_XXX' -Query 'SELECT * TOP 5 FROM v_UpdateInfo' -ConnectionTimeout 20
.EXAMPLE
    Invoke-SQLQuery -ServerInstance 'CM-SQL-RS-01A' -Database 'CM_XXX' -Query 'SELECT * TOP 5 FROM v_UpdateInfo' -ConnectionTimeout 20 -UseSQLAuthentication
.INPUTS
    None.
.OUTPUTS
    System.Data.DataRow
    System.String
    System.Exception
.NOTES
    This is an private function and should tipically not be called directly.
.LINK
    https://stackoverflow.com/questions/8423541/how-do-you-run-a-sql-server-query-from-powershell
.LINK
    https://MEM.Zone/
.LINK
    https://MEM.Zone/Invoke-SQLQuery-GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    SQL
.FUNCTIONALITY
    Runs an SQL query.
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = 'SQL server and instance name', Position = 0)]
        [ValidateNotNullorEmpty()]
        [Alias('Server')]
        [string]$ServerInstance,
        [Parameter(Mandatory = $true, HelpMessage = 'Database name', Position = 1)]
        [ValidateNotNullorEmpty()]
        [Alias('Dbs')]
        [string]$Database,
        [Parameter(Mandatory = $true, Position = 4)]
        [ValidateNotNullorEmpty()]
        [Alias('Qry')]
        [string]$Query,
        [Parameter(Mandatory = $false, Position = 5)]
        [ValidateNotNullorEmpty()]
        [Alias('Tmo')]
        [int]$ConnectionTimeout = 0,
        [Parameter(Mandatory = $false, Position = 6)]
        [ValidateNotNullorEmpty()]
        [Alias('SQLAuth')]
        [switch]$UseSQLAuthentication
    )
    Begin {

        ## Assemble connection string
        [string]$ConnectionString = "Server=$ServerInstance; Database=$Database; "
        #  Set connection string for integrated or non-integrated authentication
        If ($UseSQLAuthentication) {
            # Get credentials if SQL Server Authentication is used
            $Credentials = Get-Credential -Message 'SQL Credentials'
            [string]$Username = $($Credentials.UserName)
            [securestring]$Password = $($Credentials.Password)
            # Set connection string
            $ConnectionString += "User ID=$Username; Password=$Password;"
        }
        Else { $ConnectionString += 'Trusted_Connection=Yes; Integrated Security=SSPI;' }
    }
    Process {
        Try {

            ## Connect to the database
            Write-Verbose -Message "Connecting to [$Database]..."
            $DBConnection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
            $DBConnection.Open()

            ## Assemble query object
            $Command = $DBConnection.CreateCommand()
            $Command.CommandText = $Query
            $Command.CommandTimeout = $ConnectionTimeout

            ## Run query
            Write-Verbose -Message 'Running SQL query...'
            $DataAdapter = New-Object System.Data.SqlClient.SqlDataAdapter -ArgumentList $Command
            $DataSet = New-Object System.Data.DataSet
            $DataAdapter.Fill($DataSet) | Out-Null

            ## Return the first collection of results or an empty array
            If ($null -ne $($DataSet.Tables[0])) { $Table = $($DataSet.Tables[0]) }
            ElseIf ($($Table.Rows.Count) -eq 0) { $Table = New-Object System.Collections.ArrayList }

            ## Close database connection
            $DBConnection.Close()
        }
        Catch {
            Throw (New-Object System.Exception("Error running query! $($PsItem.Exception.Message)", $PsItem.Exception))
        }
        Finally {
            Write-Output $Table
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
    System.Object
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
            $Output = Join-Path -Path 'IIS:\Sites\' -ChildPath $IISLocalizedString | Join-Path -ChildPath 'ClientWebService'
            If ([string]::IsNullOrEmpty($Output)) { Throw 'Unable to get IIS localized path!' }
        }
        Catch {
            Throw (New-Object System.Exception("Error getting IIS Localized Path! $($PsItem.Exception.Message)", $PsItem.Exception))
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
            Throw (New-Object System.Exception("Error testing WSUS configuration values! $($PsItem.Exception.Message)", $PsItem.Exception))
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
        $Output = @{}
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
.PARAMETER ServerInstance
    Specifies a character string or SQL Server Management Objects (SMO) object that specifies the name of an instance of the Database Engine. For default instances, only specify the computer name: MyComputer.
    For named instances, use the format ComputerName\InstanceName.
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
        [Parameter(Mandatory = $true, HelpMessage = 'SQL server and instance name', Position = 0)]
        [ValidateNotNullorEmpty()]
        [Alias('Server')]
        [string]$ServerInstance,
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

        ## Define Result object
        $Result = [orderd]@{
            'OptimizationTask' = 'N/A'
            'Operation' = 'N/A'
        }

        ## Define SQL queries
        [string]$CreateIndexes =
@'
            IF EXISTS (SELECT name FROM sys.indexes WHERE name = N'IX_tbRevisionSupersedesUpdate')
                BEGIN
                    DROP INDEX [IX_tbRevisionSupersedesUpdate] ON [dbo].[tbRevisionSupersedesUpdate];
                END
            IF EXISTS (SELECT name FROM sys.indexes WHERE name = N'IX_tbLocalizedPropertyForRevision')
                BEGIN
                    DROP INDEX [IX_tbLocalizedPropertyForRevision] ON [dbo].tbLocalizedPropertyForRevision;
                END
            CREATE NONCLUSTERED INDEX [IX_tbRevisionSupersedesUpdate] ON [dbo].[tbRevisionSupersedesUpdate]([SupersededUpdateID]);
            CREATE NONCLUSTERED INDEX [IX_tbLocalizedPropertyForRevision] ON [dbo].tbLocalizedPropertyForRevision([LocalizedPropertyID]);
'@
        [string]$RebuildIndexes =
@'
            SET NOCOUNT ON;

            -- Rebuild or reorganize indexes based on their fragmentation levels
            DECLARE @work_to_do TABLE (
                objectid int
                , indexid int
                , pagedensity float
                , fragmentation float
                , numrows int
            )

            DECLARE @objectid int;
            DECLARE @indexid int;
            DECLARE @schemaname nvarchar(130);
            DECLARE @objectname nvarchar(130);
            DECLARE @indexname nvarchar(130);
            DECLARE @numrows int
            DECLARE @density float;
            DECLARE @fragmentation float;
            DECLARE @command nvarchar(4000);
            DECLARE @fillfactorset bit
            DECLARE @numpages int

            -- Select indexes that need to be defragmented based on the following
            -- * Page density is low
            -- * External fragmentation is high in relation to index size
            PRINT 'Estimating fragmentation: Begin. ' + convert(nvarchar, getdate(), 121)
            INSERT @work_to_do
            SELECT
                f.object_id
                , index_id
                , avg_page_space_used_in_percent
                , avg_fragmentation_in_percent
                , record_count
            FROM
                sys.dm_db_index_physical_stats (DB_ID(), NULL, NULL , NULL, 'SAMPLED') AS f
            WHERE
                (f.avg_page_space_used_in_percent < 85.0 and f.avg_page_space_used_in_percent/100.0 * page_count < page_count - 1)
                or (f.page_count > 50 and f.avg_fragmentation_in_percent > 15.0)
                or (f.page_count > 10 and f.avg_fragmentation_in_percent > 80.0)

            PRINT 'Number of indexes to rebuild: ' + cast(@@ROWCOUNT as nvarchar(20))

            PRINT 'Estimating fragmentation: End. ' + convert(nvarchar, getdate(), 121)

            SELECT @numpages = sum(ps.used_page_count)
            FROM
                @work_to_do AS fi
                INNER JOIN sys.indexes AS i ON fi.objectid = i.object_id and fi.indexid = i.index_id
                INNER JOIN sys.dm_db_partition_stats AS ps on i.object_id = ps.object_id and i.index_id = ps.index_id

            -- Declare the cursor for the list of indexes to be processed.
            DECLARE curIndexes CURSOR FOR SELECT * FROM @work_to_do

            -- Open the cursor.
            OPEN curIndexes

            -- Loop through the indexes
            WHILE (1=1)
            BEGIN
                FETCH NEXT FROM curIndexes
                INTO @objectid, @indexid, @density, @fragmentation, @numrows;
                IF @@FETCH_STATUS < 0 BREAK;

                SELECT
                    @objectname = QUOTENAME(o.name)
                    , @schemaname = QUOTENAME(s.name)
                FROM
                    sys.objects AS o
                    INNER JOIN sys.schemas as s ON s.schema_id = o.schema_id
                WHERE
                    o.object_id = @objectid;

                SELECT
                    @indexname = QUOTENAME(name)
                    , @fillfactorset = CASE fill_factor WHEN 0 THEN 0 ELSE 1 END
                FROM
                    sys.indexes
                WHERE
                    object_id = @objectid AND index_id = @indexid;

                IF ((@density BETWEEN 75.0 AND 85.0) AND @fillfactorset = 1) OR (@fragmentation < 30.0)
                    SET @command = N'ALTER INDEX ' + @indexname + N' ON ' + @schemaname + N'.' + @objectname + N' REORGANIZE';
                ELSE IF @numrows >= 5000 AND @fillfactorset = 0
                    SET @command = N'ALTER INDEX ' + @indexname + N' ON ' + @schemaname + N'.' + @objectname + N' REBUILD WITH (FILLFACTOR = 90)';
                ELSE
                    SET @command = N'ALTER INDEX ' + @indexname + N' ON ' + @schemaname + N'.' + @objectname + N' REBUILD';
                PRINT convert(nvarchar, getdate(), 121) + N' Executing: ' + @command;
                EXEC (@command);
                PRINT convert(nvarchar, getdate(), 121) + N' Done.';
            END

            -- Close and deallocate the cursor.
            CLOSE curIndexes;
            DEALLOCATE curIndexes;


            IF EXISTS (SELECT * FROM @work_to_do)
            BEGIN
                PRINT 'Estimated number of pages in fragmented indexes: ' + cast(@numpages as nvarchar(20))
                SELECT @numpages = @numpages - sum(ps.used_page_count)
                FROM
                    @work_to_do AS fi
                    INNER JOIN sys.indexes AS i ON fi.objectid = i.object_id and fi.indexid = i.index_id
                    INNER JOIN sys.dm_db_partition_stats AS ps on i.object_id = ps.object_id and i.index_id = ps.index_id

                PRINT 'Estimated number of pages freed: ' + cast(@numpages as nvarchar(20))
            END


            --Update all statistics
            PRINT 'Updating all statistics.' + convert(nvarchar, getdate(), 121)
            EXEC sp_updatestats
            PRINT 'Done updating statistics.' + convert(nvarchar, getdate(), 121)
'@
        [string]$SlowDeleteUpdateFix =
@'
            ALTER PROCEDURE [dbo].[spDeleteUpdate]
                @localUpdateID int
            AS
            SET NOCOUNT ON
            BEGIN TRANSACTION
            SAVE TRANSACTION DeleteUpdate
            DECLARE @retcode INT
            DECLARE @revisionID INT
            DECLARE @revisionList TABLE(RevisionID INT PRIMARY KEY)
            INSERT INTO @revisionList (RevisionID)
                SELECT r.RevisionID FROM dbo.tbRevision r
                    WHERE r.LocalUpdateID = @localUpdateID
            IF EXISTS (SELECT b.RevisionID FROM dbo.tbBundleDependency b WHERE b.BundledRevisionID IN (SELECT RevisionID FROM @revisionList))
            OR EXISTS (SELECT p.RevisionID FROM dbo.tbPrerequisiteDependency p WHERE p.PrerequisiteRevisionID IN (SELECT RevisionID FROM @revisionList))
            BEGIN
                RAISERROR('spDeleteUpdate got error: cannot delete update as it is still referenced by other update(s)', 16, -1)
                ROLLBACK TRANSACTION DeleteUpdate
                COMMIT TRANSACTION
                RETURN(1)
            END
            INSERT INTO @revisionList (RevisionID)
                SELECT DISTINCT b.BundledRevisionID FROM dbo.tbBundleDependency b
                    INNER JOIN dbo.tbRevision r ON r.RevisionID = b.RevisionID
                    INNER JOIN dbo.tbProperty p ON p.RevisionID = b.BundledRevisionID
                    WHERE r.LocalUpdateID = @localUpdateID
                        AND p.ExplicitlyDeployable = 0
            IF EXISTS (SELECT IsLocallyPublished FROM dbo.tbUpdate WHERE LocalUpdateID = @localUpdateID AND IsLocallyPublished = 1)
            BEGIN
                INSERT INTO @revisionList (RevisionID)
                    SELECT DISTINCT pd.PrerequisiteRevisionID FROM dbo.tbPrerequisiteDependency pd
                        INNER JOIN dbo.tbUpdate u ON pd.PrerequisiteLocalUpdateID = u.LocalUpdateID
                        INNER JOIN dbo.tbProperty p ON pd.PrerequisiteRevisionID = p.RevisionID
                        WHERE u.IsLocallyPublished = 1 AND p.UpdateType = 'Category'
            END
            DECLARE #cur CURSOR LOCAL FAST_FORWARD FOR
                SELECT t.RevisionID FROM @revisionList t ORDER BY t.RevisionID DESC
            OPEN #cur
            FETCH #cur INTO @revisionID
            WHILE (@@ERROR=0 AND @@FETCH_STATUS=0)
            BEGIN
                IF EXISTS (SELECT b.RevisionID FROM dbo.tbBundleDependency b WHERE b.BundledRevisionID = @revisionID
                            AND b.RevisionID NOT IN (SELECT RevisionID FROM @revisionList))
                OR EXISTS (SELECT p.RevisionID FROM dbo.tbPrerequisiteDependency p WHERE p.PrerequisiteRevisionID = @revisionID
                                AND p.RevisionID NOT IN (SELECT RevisionID FROM @revisionList))
                BEGIN
                    DELETE FROM @revisionList WHERE RevisionID = @revisionID
                    IF (@@ERROR <> 0)
                    BEGIN
                        RAISERROR('Deleting disqualified revision from temp table failed', 16, -1)
                        GOTO Error
                    END
                END
                FETCH NEXT FROM #cur INTO @revisionID
            END
            IF (@@ERROR <> 0)
            BEGIN
                RAISERROR('Fetching a cursor to value a revision', 16, -1)
                GOTO Error
            END
            CLOSE #cur
            DEALLOCATE #cur
            DECLARE #cur CURSOR LOCAL FAST_FORWARD FOR
                SELECT t.RevisionID FROM @revisionList t ORDER BY t.RevisionID DESC
            OPEN #cur
            FETCH #cur INTO @revisionID
            WHILE (@@ERROR=0 AND @@FETCH_STATUS=0)
            BEGIN
                EXEC @retcode = dbo.spDeleteRevision @revisionID
                IF @@ERROR <> 0 OR @retcode <> 0
                BEGIN
                    RAISERROR('spDeleteUpdate got error from spDeleteRevision', 16, -1)
                    GOTO Error
                END
                FETCH NEXT FROM #cur INTO @revisionID
            END
            IF (@@ERROR <> 0)
            BEGIN
                RAISERROR('Fetching a cursor to delete a revision', 16, -1)
                GOTO Error
            END
            CLOSE #cur
            DEALLOCATE #cur
            COMMIT TRANSACTION
            RETURN(0)
            Error:
                CLOSE #cur
                DEALLOCATE #cur
                IF (@@TRANCOUNT > 0)
                BEGIN
                    ROLLBACK TRANSACTION DeleteUpdate
                    COMMIT TRANSACTION
                END
                RETURN(1)
'@
    }
    Process {
        Try {
            $Output = Switch ($PSBoundParameters['Task']) {
                'CreateIndexes' {
                    $Result.OptimizationTask = 'CreateIndexes'
                    Write-Verbose -Message "Creating 'IX_tbRevisionSupersedesUpdate' and 'IX_tbLocalizedPropertyForRevision' indexes..." -Verbose
                    Invoke-SQLQuery -ServerInstance $ServerInstance -Database $Database -Query $CreateIndexes
                    $Result.Operation = 'Successful'
                    [pscustomobject]$Result
                }
                'RebuildIndexes' {
                    $Result.OptimizationTask = 'RebuildIndexes'
                    Write-Verbose -Message 'Rebuilding indexes, please wait...' -Verbose
                    Invoke-SQLQuery -ServerInstance $ServerInstance -Database $Database -Query $RebuildIndexes
                    $Result.Operation = 'Successful'
                    [pscustomobject]$Result
                }
                'SlowDeleteUpdateFix' {
                    $Result.OptimizationTask = 'SlowDeleteUpdateFix'
                    Write-Verbose -Message 'Applying spDeleteUpdate performance fix...' -Verbose
                    Invoke-SQLQuery -ServerInstance $ServerInstance -Database $Database -Query $SlowDeleteUpdateFix
                    $Result.Operation = 'Successful'
                    [pscustomobject]$Result
                }
            }
        }
        Catch {
            $Result.Operation = 'Failed wirh error: ' + $PsItem.Exception.Message
            $Output += $Result
            Throw (New-Object System.Exception("Error running optimization task! $($PsItem.Exception.Message)", $PsItem.Exception))
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
    Runs WSUS maintenance tasks by running specified optimization and cleanup tasks.
.PARAMETER Task
    Specifies maintenance task to run.
    Valid values are:
        - 'DisableDriverSync'             - Disables driver synchronization, major performance improvement
        - 'OptimizeConfiguration'         - Optimizes WSUS configuration, by setting recommended values
        - 'OptimizeDatabase'              - Optimizes WSUS database, by adding and rebuilding indexes, and applying a performance fix for delete updates
        - 'DeclineExpiredUpdates'         - Declines expired updates
        - 'DeclineSupersededUpdates'      - Declines superseded updates
        - 'CleanupObsoleteUpdates'        - Cleans up obsolete updates
        - 'CompressUpdates'               - Deletes unneded update revisions
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
    System.Object
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
        [Parameter(Mandatory=$true, HelpMessage = 'SQL server and instance name', Position = 0)]
        [ValidateNotNullorEmpty()]
        [Alias('Server')]
        [string]$ServerInstance,
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

        ## Define Result object
        $Result = [orderd]@{
            'Task' = 'N/A'
            'Output' = 'N/A'
            'Operation' = 'N/A'
        }

        ## Define SQL queries
        [string]$spDeclineExpiredUpdates       = 'EXEC spDeclineExpiredUpdates'
        [string]$spDeclineSupersededUpdates    = 'EXEC spDeclineSupersededUpdates'
        [string]$spCleanupObsoleteComputers    = 'EXEC spCleanupObsoleteComputers'
        [string]$spGetObsoleteUpdatesToCleanup = 'EXEC spGetObsoleteUpdatesToCleanup'
        [string]$spGetUpdatesToCompress        = 'EXEC spGetUpdatesToCompress'
        [string]$spUpdateToCompress            = 'EXEC spUpdateToCompress @LocalUpdateID='
        [string]$spDeleteUpdate                = 'EXEC spDeleteUpdate @LocalUpdateID='
        [string]$spCleanupUnneededContentFiles = 'EXEC spCleanupUnneededContentFiles'
    }
    Process {
        Try {
            $Output = Switch ($PSBoundParameters['Task']) {
                'DisableDriverSync' {
                    $Result.Task = 'DisableDriverSync'
                    Write-Verbose -Message 'Disable WSUS driver sync...' -Verbose
                    $WsusClassification = (Get-WsusClassification).Where({ $PSItem.Classification.Title -in ('Drivers', 'Driver Sets') })
                    $WsusClassification | Set-WsusClassification -Disable
                    $Result.Operation = 'Successful'
                    [pscustomobject]$Result
                }
                'OptimizeConfiguration' {
                    $Result.Task = 'OptimizeConfiguration'
                    Write-Verbose -Message 'Optimize WSUS configuration...' -Verbose
                    Optimize-WsusConfiguration
                    $Result.Operation = 'Successful'
                    [pscustomobject]$Result
                }
                'OptimizeDatabase' {
                    $Result.Task = 'OptimizeDatabase'
                    Write-Verbose -Message 'Optimize WSUS database...' -Verbose
                    Optimize-WsusDatabase
                    $Result.Operation = 'Successful'
                    [pscustomobject]$Result
                }
                'DeclineExpiredUpdates' {
                    $Result.Task = 'DeclineExpiredUpdates'
                    Write-Verbose -Message 'Declining expired updates. This may take a while...' -Verbose
                    Invoke-SQLQuery -ServerInstance $ServerInstance -Database $Database -Query $spDeclineExpiredUpdates
                    $Result.Operation = 'Successful'
                    [pscustomobject]$Result
                }
                'DeclineSupersededUpdates' {
                    $Result.Task = 'DeclineSupersededUpdates'
                    Write-Verbose -Message 'Declining superseded updates. This may take a while...' -Verbose
                    Invoke-SQLQuery -ServerInstance $ServerInstance -Database $Database -Query $spDeclineSupersededUpdates
                    $Result.Operation = 'Successful'
                    [pscustomobject]$Result
                }
                'CleanupObsoleteUpdates' {
                    $Result.Task = 'CleanupObsoleteUpdates'
                    Write-Verbose -Message 'Deleting obsolete updates. This may take a while...' -Verbose
                    $ObsoleteUpdates = Invoke-SQLQuery -ServerInstance $ServerInstance -Database $Database -Query $spGetObsoleteUpdatesToCleanup
                    ForEach ($ObsoleteUpdate in $ObsoleteUpdates) {
                        $Query = -join $spDeleteUpdate, $ObsoleteUpdate.LocalUpdateID
                        Invoke-SQLQuery -ServerInstance $ServerInstance -Database $Database -Query $Query
                    }
                    $Result.Operation = 'Successful'
                    [pscustomobject]$Result
                }
                'CompressUpdates' {
                    $Result.Task = 'CompressUpdates'
                    Write-Verbose -Message 'Deleting update revisions. This may take a while...' -Verbose
                    $UpdatesToCompress = Invoke-SQLQuery -ServerInstance $ServerInstance -Database $Database -Query $spGetUpdatesToCompress
                    ForEach ($UpdateToCompress in $UpdatesToCompress) {
                        $Query = -join $spUpdateToCompress, $UpdateToCompress.LocalUpdateID
                        Invoke-SQLQuery -ServerInstance $ServerInstance -Database $Database -Query $Query
                    }
                    $Result.Operation = 'Successful'
                    [pscustomobject]$Result
                }
                'CleanupObsoleteComputers' {
                    $Result.Task = 'CleanupObsoleteComputers'
                    Write-Verbose -Message 'Cleaning up obsolete computers...' -Verbose
                    Invoke-SQLQuery -ServerInstance $ServerInstance -Database $Database -Query $spCleanupObsoleteComputers
                    $Result.Operation = 'Successful'
                    [pscustomobject]$Result
                }
                'CleanupUnneededContentFiles' {
                    $Result.Task = 'CleanupUnneededContentFiles'
                    Write-Verbose -Message 'Cleaning up uneeded content files...' -Verbose
                    Invoke-SQLQuery -ServerInstance $ServerInstance -Database $Database -Query $spCleanupUnneededContentFiles
                    $Result.Operation = 'Successful'
                    [pscustomobject]$Result
                }
            }
        }
        Catch {
            $Result.Operation = 'Failed'
            $Output += $Result
            Throw (New-Object System.Exception("Error running cleanup task! $($PsItem.Exception.Message)", $PsItem.Exception))
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