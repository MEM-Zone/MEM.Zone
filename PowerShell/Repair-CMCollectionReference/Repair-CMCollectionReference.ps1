<#
.SYNOPSIS
    Repairs the MEMCM Collection references.
.DESCRIPTION
    Repairs the MEMCM Collection Collection references, by querying the membership rules and limiting collections by name and then updating the membership rules and limiting collection.
.PARAMETER Name
    Specifies the name of the collection to repair. Supports wildcards. Default is: '*'.
.PARAMETER RepairOptions
    Specifies repair options.
    Availabe options are:
    - 'DirectMembershipRules': Repairs the MEMCM Collection Direct Membership references.
    - 'IncludeMembershipRules': Repairs the MEMCM Collection Include Membership references.
    - 'ExcludeMembershipRules': Repairs the MEMCM Collection Exclude Membership references.
    - 'LimitingCollection': Repairs the MEMCM Collection Limiting Collection references.
    If you specify this parameter 'OldSiteFQDN' also needs to be specified!
    Default is: 'DirectMembershipRules'.
.PARAMETER OldSiteFQDN
    Specifies the old site SMS provider FQDN.
.PARAMETER NewSiteFQDN
    Specifies the new site SMS provider FQDN. Default is: $env:ComputerName.
.PARAMETER LogPath
    Specifies the LogPath. Default is: '.\'
.EXAMPLE
    Repair-CMCollectionReference.ps1 -Name '*' -RepairOptions 'DirectMembershipRules', 'IncludeMembershipRules', 'ExcludeMembershipRules', 'LimitingCollection' -OldSiteFQDN 'old.sms.com' -NewSiteFQDN 'new.sms.com' -LogPath 'c:\temp\log.csv'
.INPUTS
    None.
.OUTPUTS
    None.
.NOTES
    Created by Ioan Popovici
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/Repair-CMCollectionReference-CHANGELOG
.LINK
    https://MEM.Zone/Repair-CMCollectionReference-GIT
.LINK
    https://MEM.Zone/Issues
.COMPONENT
    Configuration Manager
.FUNCTIONALITY
    Collection Reference Repair.
#>

## Set script requirements
#Requires -Version 5.0

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

## Get script parameters
[CmdletBinding()]
Param (
    [Parameter(Mandatory=$false,HelpMessage='Collection name to repair:',Position=0)]
    [SupportsWildcards()]
    [ValidateNotNullorEmpty()]
    [Alias('Collection')]
    [string]$Name = '*',
    [Parameter(Mandatory=$false,HelpMessage="Repair Options ('MembershipRules','LimitingCollection'):",Position=1)]
    [ValidateNotNullorEmpty()]
    [ValidateSet('DirectMembershipRules','IncludeMembershipRules','ExcludeMembershipRules','LimitingCollection')]
    [Alias('Options')]
    [string[]]$RepairOptions = 'DirectMembershipRules',
    [Parameter(Mandatory=$false,HelpMessage='Old site FQDN:',Position=2)]
    [ValidateScript({
        If ($PSBoundParameters['RepairOptions'] -contains 'LimitingCollection' -and [string]::IsNullOrWhiteSpace($PSBoundParameters['OldSiteFQDN'])) {
            Throw 'OldSiteFQDN parameter is required when repairing LimitingCollection references!'
        }
        Else { $true }
    })]
    [Alias('OldSite')]
    [string]$OldSiteFQDN,
    [Parameter(Mandatory=$false,HelpMessage='Old site FQDN:',Position=2)]
    [ValidateNotNullorEmpty()]
    [Alias('NewSite')]
    [string]$NewSiteFQDN = $env:ComputerName,
    [Parameter(Mandatory=$false,HelpMessage='Log File Path:',Position=2)]
    [ValidateNotNullorEmpty()]
    [Alias('Log')]
    [string]$LogPath
)

## Set variables
[string]$ScriptName     = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Definition)
[string]$LogName = $ScriptName + '.log'
[string]$LogFilePath = If ($LogPath) { Join-Path -Path $LogPath -ChildPath $LogName } Else { $(Join-Path -Path $Env:WinDir -ChildPath $('\Logs\' + $LogName)) }


#endregion
##*=============================================
##* END VARIABLE DECLARATION
##*=============================================


##*=============================================
##* FUNCTION LISTINGS
##*=============================================
#region FunctionListings

#region Function Invoke-CMSiteCommand
Function Invoke-CMSiteCommand {
<#
.SYNOPSIS
    Runs a command on a remote CMSite.
.DESCRIPTION
    Runs a command on a remote site and retunrs the resuly to the pipeline.
.PARAMETER SiteFQDN
    Specifies SMS provider FQDN.
.PARAMETER Command
    Specifies the command to run.
.EXAMPLE
    Invoke-CMSiteCommand -SiteFQDN 'site.sms.com' -Command 'Get-CMSite'
.INPUTS
    None.
.OUTPUTS
    System.Object
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.COMPONENT
    Configuration Manager
.FUNCTIONALITY
    Run a remote command on a CMSite.
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true,HelpMessage='Site FQDN:',Position=0)]
        [ValidateNotNullorEmpty()]
        [Alias('Name')]
        [string]$SiteFQDN,
        [Parameter(Mandatory=$true,HelpMessage='Command to run:',Position=1)]
        [ValidateNotNullorEmpty()]
        [Alias('cmd')]
        [string]$Command
    )

    Begin {

        ## Set command scriptblock
        [string]$CMSiteCommand =
@"
            ## Import the configuration manager module
            Import-Module `$env:SMS_ADMIN_UI_PATH.Replace('\bin\i386','\bin\configurationmanager.psd1') -ErrorAction 'Stop'

            ## Get the site code
            `$SiteLocation = (Get-PSDrive -PSProvider 'CMSITE').Name + ':\'

            ## Change context to the site
            Push-Location `$SiteLocation

            ## Get the site collections
            $Command

            ## Change context back
            Pop-Location

            ## Remove SCCM PSH Module
            Remove-Module 'ConfigurationManager' -ErrorAction 'SilentlyContinue'
"@
        $ScriptBlock = [ScriptBlock]::Create($CMSiteCommand)
    }
    Process {
        Try {
            $Output = Invoke-Command -ComputerName $SiteFQDN -ScriptBlock $ScriptBlock -ErrorAction 'Stop'
        }
        Catch {
            $PSCmdlet.WriteError($PsItem)
        }
        Finally {
            Write-Output -InputObject $Output
        }
    }
    End {
    }
}
#endregion

#region Function Invoke-SQLCommand
Function Invoke-SQLCommand {
<#
.SYNOPSIS
    Runs an SQL query.
.DESCRIPTION
    Runs an SQL query without any dependencies except .net.
.PARAMETER ServerInstance
    Specifies a character string or SQL Server Management Objects (SMO) object that specifies the name of an instance of the Database Engine. For default instances, only specify the computer name: MyComputer. For named instances, use the format ComputerName\InstanceName.
.PARAMETER Database
    Specifies the name of a database. This cmdlet connects to this database in the instance that is specified in the ServerInstance parameter.
.PARAMETER Username
    Specifies the login ID for making a SQL Server Authentication connection to an instance of the Database Engine.
    If Username and Password are not specified, this cmdlet attempts a Windows Authentication connection using the Windows account running the Windows PowerShell session. When possible, use Windows Authentication.
.PARAMETER Password
    Specifies the password for the SQL Server Authentication login ID that was specified in the Username parameter.
    If Username and Password are not specified, this cmdlet attempts a Windows Authentication connection using the Windows account running the Windows PowerShell session. When possible, use Windows Authentication.
.PARAMETER Query
    Specifies one or more queries that this cmdlet runs.
.PARAMETER ConnectionTimeout
    Specifies the number of seconds when this cmdlet times out if it cannot successfully connect to an instance of the Database Engine. The timeout value must be an integer value between 0 and 65534. If 0 is specified, connection attempts does not time out.
    Default is: '0'.
.PARAMETER UseSQLAuthentication
    Specifies to use SQL Server Authentication instead of Windows Authentication. You will be asked for credentials if this switch is used.
.EXAMPLE
    Invoke-SQLCommand -ServerInstance 'CM-SQL-RS-01A' -Database 'CM_XXX' -Query 'SELECT * TOP 5 FROM v_UpdateInfo' -ConnectionTimeout 20
.EXAMPLE
    Invoke-SQLCommand -ServerInstance 'CM-SQL-RS-01A' -Database 'CM_XXX' -Query 'SELECT * TOP 5 FROM v_UpdateInfo' -ConnectionTimeout 20 -UseSQLAuthentication
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
    https://MEM.Zone/Install-SRSReport-GIT
.LINK
    https://MEM.Zone/Install-SRSReport-ISSUES
.COMPONENT
    RS
.FUNCTIONALITY
    RS Catalog Item Installer
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true,HelpMessage='SQL server and instance name',Position=0)]
        [ValidateNotNullorEmpty()]
        [Alias('Server')]
        [string]$ServerInstance,
        [Parameter(Mandatory=$true,HelpMessage='Database name',Position=1)]
        [ValidateNotNullorEmpty()]
        [Alias('Dbs')]
        [string]$Database,
        [Parameter(Mandatory=$true,Position=4)]
        [ValidateNotNullorEmpty()]
        [Alias('Qry')]
        [string]$Query,
        [Parameter(Mandatory=$false,Position=5)]
        [ValidateNotNullorEmpty()]
        [Alias('Tmo')]
        [int]$ConnectionTimeout = 0,
        [Parameter(Mandatory=$false,Position=6)]
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
            Throw (New-Object System.Exception("Error running query! $($_.Exception.Message)", $_.Exception))
        }
        Finally {
            Write-Output -InputObject $Table
        }
    }
}
#endregion

#region Function Repair-CMCollectionReference
Function Repair-CMCollectionReference {
<#
.SYNOPSIS
    Repairs the MEMCM Collection references.
.DESCRIPTION
    Repairs the MEMCM Collection Collection references, by querying the membership rules and limiting collections by name and then updating the membership rules and limiting collection.
.PARAMETER Name
    Specifies the name of the collection to repair. Supports wildcards. Default is: '*'.
.PARAMETER RepairOptions
    Specifies repair options.
    Availabe options are:
    - 'DirectMembershipRules': Repairs the MEMCM Collection Direct Membership references.
    - 'IncludeMembershipRules': Repairs the MEMCM Collection Include Membership references.
    - 'ExcludeMembershipRules': Repairs the MEMCM Collection Exclude Membership references.
    - 'LimitingCollection': Repairs the MEMCM Collection Limiting Collection references.
    If you specify 'LimitingCollection', 'OldSiteFQDN' also needs to be specified!
    Default is: 'DirectMembershipRules'.
.PARAMETER OldSiteFQDN
    Specifies the old site SMS provider FQDN.
.PARAMETER NewSiteFQDN
    Specifies the new site SMS provider FQDN. Default is: $env:ComputerName.
.EXAMPLE
    Repair-CMCollectionReference -Name '*' -RepairOptions 'DirectMembershipRules', 'IncludeMembershipRules', 'ExcludeMembershipRules', 'LimitingCollection' -OldSiteFQDN 'old.sms.com' -NewSiteFQDN 'new.sms.com'
.INPUTS
    None.
.OUTPUTS
    None.
.NOTES
    Created by Ioan Popovici
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/Repair-CMCollectionReference-CHANGELOG
.LINK
    https://MEM.Zone/Repair-CMCollectionReference-GIT
.LINK
    https://MEM.Zone/Issues
.COMPONENT
    Configuration Manager
.FUNCTIONALITY
    Collection Reference Repair.
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory=$false,HelpMessage='Collection name to repair:',Position=0)]
    [SupportsWildcards()]
    [ValidateNotNullorEmpty()]
    [Alias('Collection')]
    [string]$Name = '*',
    [Parameter(Mandatory=$false,HelpMessage="Repair Options 'DirectMembershipRules','IncludeMembershipRules','ExcludeMembershipRules','LimitingCollection'):",Position=1)]
    [ValidateNotNullorEmpty()]
    [ValidateSet('DirectMembershipRules','IncludeMembershipRules','ExcludeMembershipRules','LimitingCollection')]
    [Alias('Options')]
    [string[]]$RepairOptions = 'DirectMembershipRules',
    [Parameter(Mandatory=$false,HelpMessage='Old site FQDN:',Position=2)]
    [ValidateScript({
        If ($PSBoundParameters['RepairOptions'] -contains 'LimitingCollection' -and [string]::IsNullOrWhiteSpace($PSBoundParameters['OldSiteFQDN'])) {
            Throw 'OldSiteFQDN parameter is required when repairing LimitingCollection references!'
        }
        Else { $true }
    })]
    [Alias('OldSite')]
    [string]$OldSiteFQDN,
    [Parameter(Mandatory=$false,HelpMessage='Old site FQDN:',Position=3)]
    [ValidateNotNullorEmpty()]
    [Alias('NewSite')]
    [string]$NewSiteFQDN = $env:ComputerName
)
    Process {

        ## Get new site collections
        Try {
            Write-Verbose -Message  "Getting collection '$Name' from '$NewSiteFQDN'. This might take a while..." -Verbose
            $NewSiteCollections = Invoke-CMSiteCommand -Command "Get-CMCollection -Name '$Name' -CollectionType 'Device'" -SiteFQDN $NewSiteFQDN -ErrorAction 'Stop'
        }
        Catch {
            Throw "Failed to get site [$NewSiteFQDN] collections!`n$PsItem"
        }

        ## Set progress variables
        [int]$CollectionProgressStep = 0
        [int]$CollectionProgressTotal = ($NewSiteCollections | Measure-Object).Count

        ## Process collections
        Try {
            ForEach ($Collection in $NewSiteCollections) {

                ## Set collection variables
                $CollectionID = $Collection.CollectionID
                $CollectionName = $Collection.Name
                $CollectionRules = $Collection.CollectionRules

                ## Initialize output properties
                $OutputProps = [PSCustomObject]@{
                    CollectionName = $CollectionName
                    RepairType     = 'N/A'
                    RuleName       = 'N/A'
                    Operation      = 'N/A'
                    Result         = 'Healthy'
                }

                ## Show progress status
                $CollectionProgressStep ++
                [int16]$PercentComplete = ($CollectionProgressStep / $CollectionProgressTotal) * 100
                Write-Progress -Activity 'Processing Collections... ' -CurrentOperation "'$CollectionName' ($CollectionID)" -PercentComplete $PercentComplete -Id 0

                ## Process repair options
                Switch ($PSBoundParameters['RepairOptions']) {

                    ## Direct Membership Rules
                    'DirectMembershipRules' {
                        #  Check if the collection contains direct membership rules
                        [boolean]$IsDirectRule = $($CollectionRules | Out-String).Contains('SMS_CollectionRuleDirect')
                        #  Check if we need to start processing
                        If ($IsDirectRule) {
                            #  Get collection direct membership rules
                            $DirectMembershipRules = Invoke-CMSiteCommand -Command "Get-CMDeviceCollectionDirectMembershipRule -CollectionId $CollectionID" -SiteFQDN $NewSiteFQDN -ErrorAction 'Stop'
                            #  Set progress variables
                            [int]$RuleProgressStep = 0
                            [int]$RuleProgressTotal = ($DirectMembershipRules | Measure-Object).Count
                            #  Process rules
                            ForEach ($DirectMembershipRule in $DirectMembershipRules) {
                                Try {
                                    #  Show progress status
                                    $RuleProgressStep ++
                                    [int16]$PercentComplete = ($RuleProgressStep / $RuleProgressTotal) * 100
                                    Write-Progress -Activity 'Processing Direct Membership Rules... ' -CurrentOperation "'$CollectionName' --> '$($DirectMembershipRule.RuleName)'" -PercentComplete $PercentComplete -Id 1
                                    #  Set variables
                                    $RuleName = $DirectMembershipRule.RuleName
                                    #  Initialize output properties
                                    $OutputProps = [PSCustomObject]@{
                                        CollectionName = $CollectionName
                                        RepairType     = 'DirectMembershipRules'
                                        RuleName       = $RuleName
                                        Operation      = 'Skipped'
                                        Result         = 'Healthy'
                                    }
                                    $OldResourceID = $DirectMembershipRule.ResourceID
                                    $NewResourceID = (Invoke-CMSiteCommand -Command "Get-CMDevice -Name $RuleName | Where-Object -Property IsClient -eq $true" -SiteFQDN $NewSiteFQDN -ErrorAction 'SilentlyContinue').ResourceID
                                    [boolean]$IsDuplicate = ($NewResourceID | Measure-Object).Count -gt 1
                                    If (-not $IsDuplicate) {
                                        #  Update membership rule
                                        If (-not [string]::IsNullOrWhiteSpace($NewResourceID)) {
                                            #  If the collection rule is not already set to the new ResourceID, remove the old ResourceID and add the new one. !! This is potentially destructive but you can't have two rules with the same name !!
                                            If ($OldResourceID -ne $NewResourceID -and $NewResourceID -notin $DirectMembershipRules.ResourceID) {
                                                #  Set output props
                                                $OutputProps.Operation  = "Update '$RuleName' | '$OldResourceID' --> '$NewResourceID'"
                                                #  Remove old rule
                                                Write-Verbose -Message "Removing [DM RULE]      | '$CollectionName' ($CollectionID) | '$RuleName' ($OldResourceID)..."
                                                Invoke-CMSiteCommand -Command "Remove-CMDeviceCollectionDirectMembershipRule -CollectionId $CollectionID -ResourceID $OldResourceID -Force" -SiteFQDN $NewSiteFQDN -ErrorAction 'Stop'
                                                #  Add new rule
                                                Write-Verbose -Message "Adding   [DM RULE]      | '$CollectionName' ($CollectionID) | '$RuleName' ['$OldResourceID' --> '$NewResourceID']..."
                                                Invoke-CMSiteCommand -Command "Add-CMDeviceCollectionDirectMembershipRule -CollectionId $CollectionID -ResourceID $NewResourceID" -SiteFQDN $NewSiteFQDN -ErrorAction 'Stop'
                                                $OutputProps.Result = 'Updated'
                                            }
                                        }
                                        Else {
                                            Write-Warning -Message "Failed   [DM RULE]      | '$CollectionName' ($CollectionID) | Device '$RuleName' not found!"
                                            $OutputProps.Result = "Device '$RuleName' not found!"
                                        }
                                    }
                                    Else {
                                        Write-Warning -Message "Failed   [DM RULE]      | '$CollectionName' ($CollectionID) | Device '$RuleName' found more than once!"
                                        $OutputProps.Result = "Device '$RuleName' is not unique!"
                                    }
                                }
                                Catch {
                                    $ErrorMessage = $($_.Exception.Message)
                                    Write-Warning -Message "Failed   [DM RULE]      | '$CollectionName' ($CollectionID) | '$RuleName' | $ErrorMessage"
                                    $OutputProps.Result = $ErrorMessage
                                    $PSCmdlet.WriteError($ErrorMessage)
                                }
                                Finally {
                                    $OutputProps | Export-Csv -Path $LogFilePath -NoClobber -Append -Delimiter ';' -NoTypeInformation
                                }
                            }
                        }
                    }

                    ## Include Collection Membership Rules
                    'IncludeMembershipRules' {
                        #  Check if the collection contains include membership rules
                        [boolean]$IsIncludeRule = $($CollectionRules | Out-String).Contains('SMS_CollectionRuleIncludeCollection')
                        #  Check if we need to start processing
                        If ($IsIncludeRule) {
                            #  Get collection direct membership rules
                            $IncludeMembershipRules = Invoke-CMSiteCommand -Command "Get-CMDeviceCollectionIncludeMembershipRule -CollectionId $CollectionID" -SiteFQDN $NewSiteFQDN -ErrorAction 'Stop'
                            #  Set progress variables
                            [int]$RuleProgressStep = 0
                            [int]$RuleProgressTotal = ($IncludeMembershipRules | Measure-Object).Count
                            #  Process rules
                            ForEach ($IncludeMembershipRule in $IncludeMembershipRules) {
                                Try {
                                    #  Show progress status
                                    $RuleProgressStep ++
                                    [int16]$PercentComplete = ($RuleProgressStep / $RuleProgressTotal) * 100
                                    Write-Progress -Activity 'Processing Include Membership Rules... ' -CurrentOperation "'$CollectionName' --> '$($IncludeMembershipRule.RuleName)'" -PercentComplete $PercentComplete -Id 1
                                    #  Set variables
                                    $RuleName = $IncludeMembershipRule.RuleName
                                    $OutputProps = [PSCustomObject]@{
                                        CollectionName = $CollectionName
                                        RepairType     = 'IncludeMembershipRules'
                                        RuleName       = $RuleName
                                        Operation      = 'Skipped'
                                        Result         = 'Healthy'
                                    }
                                    $OldCollectionID = $IncludeMembershipRule.IncludeCollectionID
                                    $NewCollectionID = (Invoke-CMSiteCommand -Command "Get-CMCollection -Name $RuleName" -SiteFQDN $NewSiteFQDN -CollectionType 'Device' -ErrorAction 'SilentlyContinue').CollectionID
                                    #  Update membership rule
                                    If (-not [string]::IsNullOrWhiteSpace($NewCollectionID)) {
                                        #  If the collection rule is not already set to the new CollectionID, remove the old CollectionID and add the new one. !! This is potentially destructive but you can't have two rules with the same name !!
                                        If ($NewCollectionID -ne $CollectionID -and $NewCollectionID -notin $IncludeMembershipRules.IncludeCollectionID) {
                                            #  Set output props
                                            $OutputProps.Operation  = "Update '$RuleName' | '$OldCollectionID' --> '$NewCollectionID'"
                                            #  Remove old rule
                                            Write-Verbose -Message "Removing [INCLUDE RULE] | '$CollectionName' ($CollectionID) | '$RuleName' ($OldCollectionID)..."
                                            Invoke-CMSiteCommand -Command "Remove-CMDeviceCollectionIncludeMembershipRule -CollectionId $CollectionID -IncludeCollectionId $OldCollectionID -Force" -SiteFQDN $NewSiteFQDN -ErrorAction 'Stop'
                                            #  Add new rule
                                            Write-Verbose -Message "Adding   [INCLUDE RULE] | '$CollectionName' ($CollectionID) | '$RuleName' ['$OldCollectionID' --> '$NewCollectionID']..."
                                            Invoke-CMSiteCommand -Command "Add-CMDeviceCollectionIncludeMembershipRule -CollectionId $CollectionID -IncludeCollectionId $NewCollectionID" -SiteFQDN $NewSiteFQDN -ErrorAction 'Stop'
                                            $OutputProps.Result     = 'Updated'
                                        }
                                    }
                                    Else {
                                        Write-Warning -Message "Failed   [INCLUDE RULE] | '$CollectionName' ($CollectionID) | Collection '$RuleName' not found!"
                                        $OutputProps.Result = "Collection '$RuleName' not found!"
                                    }
                                }
                                Catch {
                                    $ErrorMessage = $($_.Exception.Message)
                                    Write-Warning -Message "Failed   [INCLUDE RULE] | '$CollectionName' ($CollectionID) | '$RuleName' | $ErrorMessage "
                                    $OutputProps.Result = $ErrorMessage
                                    $PSCmdlet.WriteError($ErrorMessage)
                                }
                                Finally {
                                    $OutputProps | Export-Csv -Path $LogFilePath -NoClobber -Append -Delimiter ';' -NoTypeInformation
                                }
                            }
                        }
                    }

                    ## Exclude Collection Membership Rules
                    'ExcludeMembershipRules' {
                        #  Check if the collection contains exclude membership rules
                        [boolean]$IsExcludeRule = $($CollectionRules | Out-String).Contains('SMS_CollectionRuleExcludeCollection')
                        #  Check if we need to start processing
                        If ($IsExcludeRule) {
                            #  Get collection exclude membership rules
                            $ExcludeMembershipRules = Invoke-CMSiteCommand -Command "Get-CMDeviceCollectionExcludeMembershipRule -CollectionId $CollectionID" -SiteFQDN $NewSiteFQDN -ErrorAction 'Stop'
                            #  Set progress variables
                            [int]$RuleProgressStep = 0
                            [int]$RuleProgressTotal = ($ExcludeMembershipRules | Measure-Object).Count
                            #  Process rules
                            ForEach ($ExcludeMembershipRule in $ExcludeMembershipRules) {
                                Try {
                                    #  Show progress status
                                    $RuleProgressStep ++
                                    [int16]$PercentComplete = ($RuleProgressStep / $RuleProgressTotal) * 100
                                    Write-Progress -Activity 'Processing Exclude Membership Rules... ' -CurrentOperation "'$CollectionName' --> '$($ExcludeMembershipRule.RuleName)'" -PercentComplete $PercentComplete -Id 1
                                    #  Set variables
                                    $RuleName = $ExcludeMembershipRule.RuleName
                                    $OutputProps = [PSCustomObject]@{
                                        CollectionName = $CollectionName
                                        RepairType     = 'ExcludeMembershipRules'
                                        RuleName       = $RuleName
                                        Operation      = 'Skipped'
                                        Result         = 'Healthy'
                                    }
                                    $OldCollectionID = $ExcludeMembershipRule.ExcludeCollectionID
                                    $NewCollectionID = (Invoke-CMSiteCommand -Command "Get-CMCollection -Name $RuleName" -SiteFQDN $NewSiteFQDN -CollectionType 'Device' -ErrorAction 'SilentlyContinue').CollectionID
                                    #  Update membership rule
                                    If (-not [string]::IsNullOrWhiteSpace($NewCollectionID)) {
                                        #  If the collection rule is not already set to the new CollectionID, remove the old CollectionID and add the new one. !! This is potentially destructive but you can't have two rules with the same name !!
                                        If ($NewCollectionID -ne $OldCollectionID -and $NewCollectionID -notin $ExcludeMembershipRules.IncludeCollectionID) {
                                            #  Set output props
                                            $OutputProps.Operation = "Update '$RuleName' | '$OldCollectionID' --> '$NewCollectionID'"
                                            #  Remove old rule
                                            Write-Verbose -Message "Removing [EXCLUDE RULE] | $CollectionName ($CollectionID) | '$RuleName' ($OldCollectionID)..."
                                            Invoke-CMSiteCommand -Command "Remove-CMDeviceCollectionExcludeMembershipRule -CollectionId $CollectionID -ExcludeCollectionId $OldCollectionID -Force" -SiteFQDN $NewSiteFQDN -ErrorAction 'Stop'
                                            #  Add new rule
                                            Write-Verbose -Message "Adding   [EXCLUDE RULE] | $CollectionName ($CollectionID) | '$RuleName' ['$OldCollectionID' --> '$NewCollectionID']..."
                                            Invoke-CMSiteCommand -Command "Add-CMDeviceCollectionExcludeMembershipRule -CollectionId $CollectionID -ExcludeCollectionId $NewCollectionID" -SiteFQDN $NewSiteFQDN -ErrorAction 'Stop'
                                            $OutputProps.Result = 'Updated'
                                        }
                                    }
                                    Else {
                                        Write-Warning -Message "Failed   [EXCLUDE RULE] | '$CollectionName' ($CollectionID) | Collection '$RuleName' not found!"
                                        $OutputProps.Result = "Collection '$RuleName' not found!"
                                    }
                                }
                                Catch {
                                    $ErrorMessage = $($_.Exception.Message)
                                    Write-Warning -Message "Failed   [EXCLUDE RULE] | '$CollectionName' ($CollectionID) | '$RuleName' | $ErrorMessage"
                                    $OutputProps.Result = $ErrorMessage
                                    $PSCmdlet.WriteError($ErrorMessage)
                                }
                                Finally {
                                    $OutputProps | Export-Csv -Path $LogFilePath -NoClobber -Append -Delimiter ';' -NoTypeInformation
                                }
                            }
                        }
                    }

                    ## Limiting Collection References
                    'LimitingCollection' {
                        #  Show progress status
                        [int16]$PercentComplete = ($CollectionProgressStep / $CollectionProgressTotal) * 100
                        Write-Progress -Activity 'Processing Limiting Collections... ' -CurrentOperation "$CollectionName --> $($Collection.LimitingCollectionName)" -PercentComplete $PercentComplete -Id 0
                        #  Set variables
                        $LimitingCollectionName  = $Collection.LimitToCollectionName
                        $OutputProps = [PSCustomObject]@{
                            CollectionName = $CollectionName
                            RepairType     = 'LimitingCollection'
                            RuleName       = $LimitingCollectionName
                            Operation      = 'Skipped'
                            Result         = 'Healthy'
                        }
                        #  Check if the Limiting Collection is corrupt
                        If ([string]::IsNullOrWhiteSpace($LimitingCollectionName)) {
                            Try {
                                $OldLimitingCollectionID = $Collection.LimitToCollectionID
                                Write-Verbose -Message "Getting [LIMITING COLL] | Getting Collection Name for '$OldLimitingCollectionID' from '$OldSiteFQDN'"
                                $LimitingCollectionName  = $(Invoke-CMSiteCommand -Command "Get-CMCollection -CollectionID $OldLimitingCollectionID -CollectionType 'Device'" -SiteFQDN $OldSiteFQDN -ErrorAction 'SilentlyContinue').Name
                                $NewLimitingCollectionID = $(Invoke-CMSiteCommand -Command "Get-CMCollection -Name '$LimitingCollectionName' -CollectionType 'Device'" -SiteFQDN $NewSiteFQDN -ErrorAction 'SilentlyContinue').CollectionID
                                $SQLServerInfo  = Invoke-CMSiteCommand -Command "Get-CMSiteRole -RoleName 'SMS SQL Server'" -SiteFQDN $NewSiteFQDN -ErrorAction 'SilentlyContinue'
                                $ServerInstance = $SQLServerInfo.NetworkOSPath.Remove(0,2)
                                $Database       = -join ('CM_', $SQLServerInfo.SiteCode)
                                [string]$Query  =
@"
                                /* Set new Limiting CollectionID */
                                UPDATE Collections_G
                                SET LimitToCollectionID = N'$NewLimitingCollectionID'
                                WHERE SiteID = N'$CollectionID' AND SiteID NOT LIKE N'SMS%';
"@
                                #  Set output props
                                $OutputProps.Operation = "Update '$LimitingCollectionName' | '$OldLimitingCollectionID' --> '$NewLimitingCollectionID'"
                                If (-not [string]::IsNullOrWhiteSpace($NewLimitingCollectionID)) {
                                    #  If the Limiting CollectionID does not match the new  Limiting CollectionID, set the new Limiting CollectionID.
                                    If ($NewLimitigCollectionID -ne $OldLimitigCollectionID) {
                                        Write-Verbose -Message "Setting [LIMITING COLL] | '$CollectionName' ($CollectionID) | '$LimitingCollectionName' ['$OldLimitingCollectionID' --> '$NewLimitingCollectionID']..."
                                        #  Set the new Limiting CollectionID
                                        Invoke-SQLCommand -ServerInstance $ServerInstance -Database $Database -Query $Query -ErrorAction 'Stop'
                                        $OutputProps.Result = 'Updated'
                                    }
                                }
                                Else {
                                    Write-Warning -Message  "Failed [LIMITING COLL]  | '$CollectionName' ($CollectionID) | Limiting Collection '$LimitigCollectionName' not found!"
                                    $OutputProps.Result = "Limiting Collection '$LimitingCollectionName' not found!"
                                }
                            }
                            Catch {
                                $ErrorMessage = $($_.Exception.Message)
                                Write-Warning -Message "Failed [LIMITING COLL]  | '$CollectionName' ($CollectionID) | '$LimitingCollectionName' | $ErrorMessage"
                                $OutputProps.Result = $ErrorMessage
                                $PSCmdlet.WriteError($ErrorMessage)
                            }
                            Finally {
                                $OutputProps | Export-Csv -Path $LogFilePath -NoClobber -Append -Delimiter ';' -NoTypeInformation
                            }
                        }
                    }
                }
            }
        }
        Catch {
            $PSCmdlet.WriteError($PsItem)
        }
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
    $Output = Repair-CMCollectionReference -Name $Name -RepairOptions $RepairOptions -OldSiteFQDN $OldSiteFQDN -NewSiteFQDN $NewSiteFQDN
}
Catch {
    Throw "Failure during processing!`n$PsItem"
}
Finally {
    Write-Output -InputObject $Output
}

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================