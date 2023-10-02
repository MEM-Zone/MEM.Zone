<#
.SYNOPSIS
    Gets user rights assignment.
.DESCRIPTION
    Gets user rights assignment for a local computer, and performs a compliance check.
.PARAMETER Principal
    Defines the Principal to get the rights for.
    If you use the Principal Name instead of a SID you need to localize your Principal Names with the locale of the OS this script will be running on.
    Default is: '*'. Supports wildcards.
.PARAMETER Privilege
    Defines the User Right(s) to get the principals for.
    Valid values are:
        SeAssignPrimaryTokenPrivilege
        SeAuditPrivilege
        SeBackupPrivilege
        SeBatchLogonRight
        SeChangeNotifyPrivilege
        SeCreateGlobalPrivilege
        SeCreatePagefilePrivilege
        SeCreatePermanentPrivilege
        SeCreateSymbolicLinkPrivilege
        SeCreateTokenPrivilege
        SeDebugPrivilege
        SeDelegateSessionUserImpersonatePrivilege
        SeDenyBatchLogonRight
        SeDenyInteractiveLogonRight
        SeDenyNetworkLogonRight
        SeDenyRemoteInteractiveLogonRight
        SeDenyServiceLogonRight
        SeEnableDelegationPrivilege
        SeImpersonatePrivilege
        SeIncreaseBasePriorityPrivilege
        SeIncreaseQuotaPrivilege
        SeIncreaseWorkingSetPrivilege
        SeInteractiveLogonRight
        SeLoadDriverPrivilege
        SeLockMemoryPrivilege
        SeMachineAccountPrivilege
        SeManageVolumePrivilege
        SeNetworkLogonRight
        SeProfileSingleProcessPrivilege
        SeRelabelPrivilege
        SeRemoteInteractiveLogonRight
        SeRemoteShutdownPrivilege
        SeRestorePrivilege
        SeSecurityPrivilege
        SeServiceLogonRight
        SeShutdownPrivilege
        SeSyncAgentPrivilege
        SeSystemEnvironmentPrivilege
        SeSystemProfilePrivilege
        SeSystemtimePrivilege
        SeTakeOwnershipPrivilege
        SeTcbPrivilege
        SeTimeZonePrivilege
        SeTrustedCredManAccessPrivilege
        SeUndockPrivilege
.EXAMPLE
    Get-UserRightsAssignment.ps1
.EXAMPLE
    Get-UserRightsAssignment.ps1 -Principal 'CONTOSO\Group'
.EXAMPLE
    Get-UserRightsAssignment.ps1 -Principal '*S-1-5-19'
.EXAMPLE
    Get-UserRightsAssignment.ps1 -Privilege 'SeServiceLogonRight', 'SeRemoteInteractiveLogonRight'
.INPUTS
    None.
.OUTPUTS
    System.Object
    System.Exception
.NOTES
    Created by Ioan Popovici
.LINK
    https://MEMZ.one/Get-UserRightsAssignment
.LINK
    https://MEMZ.one/Get-UserRightsAssignment-CHANGELOG
.LINK
    https://MEMZ.one/Get-UserRightsAssignment-GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    User Rights Assignment
.FUNCTIONALITY
    Gets User Rights Assigment.
#>

[CmdletBinding(DefaultParameterSetName = 'Principal')]
Param (
    [Parameter(Mandatory = $false, ParameterSetName = 'Principal', Position = 0)]
    [SupportsWildcards()]
    [ValidateNotNullorEmpty()]
    [Alias('PrincipalName')]
    [string]$Principal = '*',
    [Parameter(Mandatory = $true, ParameterSetName = 'Privileges', Position = 1)]
    [ValidateSet('SeAssignPrimaryTokenPrivilege', 'SeAuditPrivilege', 'SeBackupPrivilege', 'SeBatchLogonRight', 'SeChangeNotifyPrivilege',
        'SeCreateGlobalPrivilege', 'SeCreatePagefilePrivilege', 'SeCreatePermanentPrivilege', 'SeCreateSymbolicLinkPrivilege', 'SeCreateTokenPrivilege',
        'SeDebugPrivilege', 'SeDelegateSessionUserImpersonatePrivilege', 'SeDenyBatchLogonRight', 'SeDenyInteractiveLogonRight', 'SeDenyNetworkLogonRight',
        'SeDenyRemoteInteractiveLogonRight', 'SeDenyServiceLogonRight', 'SeEnableDelegationPrivilege', 'SeImpersonatePrivilege', 'SeIncreaseBasePriorityPrivilege',
        'SeIncreaseQuotaPrivilege', 'SeIncreaseWorkingSetPrivilege', 'SeInteractiveLogonRight', 'SeLoadDriverPrivilege', 'SeLockMemoryPrivilege', 'SeMachineAccountPrivilege',
        'SeManageVolumePrivilege', 'SeNetworkLogonRight', 'SeProfileSingleProcessPrivilege', 'SeRelabelPrivilege', 'SeRemoteInteractiveLogonRight', 'SeRemoteShutdownPrivilege',
        'SeRestorePrivilege', 'SeSecurityPrivilege', 'SeServiceLogonRight', 'SeShutdownPrivilege', 'SeSyncAgentPrivilege', 'SeSystemEnvironmentPrivilege', 'SeSystemProfilePrivilege',
        'SeSystemtimePrivilege', 'SeTakeOwnershipPrivilege', 'SeTcbPrivilege', 'SeTimeZonePrivilege', 'SeTrustedCredManAccessPrivilege', 'SeUndockPrivilege', IgnoreCase = $true
    )]
    [Alias('Rights')]
    [string[]]$Privilege
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

#region Function Resolve-Principal
Function Resolve-Principal {
<#
.SYNOPSIS
    Resolves a Principal or Principals.
.DESCRIPTION
    Resolves a Principal or Principals to SID or Principal Name.
.PARAMETER Principal
    Specifies the Principal to resolve.
.EXAMPLE
    Resolve-Principal -Principal 'CONTOSO\User'
.EXAMPLE
    Resolve-Principal -Principal 'CONTOSO\User', 'CONTOSO\Group', 'BUILTIN\Administrators'
.EXAMPLE
    Resolve-Principal -Principal 'S-1-5-21-1234567890-1234567890-1234567890-500'
.EXAMPLE
    Resolve-Principal -Principal 'S-1-5-21-1234567890-1234567890-1234567890-500', 'S-1-5-21-1234567890-1234567890-1234567890-501'
.INPUTS
    System.Array
.OUTPUTS
    System.Object
    System.Exception
.NOTES
    Created by Ioan Popovici
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    Security Principal
.FUNCTIONALITY
    Resolves a Principal or Principals to SID or Principal Name.
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullorEmpty()]
        [Alias('SecurityPrincipal')]
        [string[]]$Principal
    )
    Begin {

        ## Set SID regex match Pattern
        [regex]$Pattern = 'S-\d-(?:\d+-){1,14}\d+'

        ## Initialize output object
        $Output = $null
    }
    Process {
        Try {

            ## Resolve Principal
            $Output = ForEach ($PrincipalItem in $Principal) {
                Try {
                    #  Set Principal type
                    [string]$SIDMatch = (Select-String -Pattern $Pattern -InputObject $PrincipalItem).Matches.Value
                    [string]$PrincipalType = If ([string]::IsNullOrEmpty($SIDMatch)) { 'PrincipalName' } Else { 'PrincipalSID' }
                    #  Resolve Principal
                    Switch ($PrincipalType) {
                        'PrincipalName' {
                            $NTAccountObject = New-Object System.Security.Principal.NTAccount($PrincipalItem)
                            $NTAccountObject.Translate([System.Security.Principal.SecurityIdentifier]).Value
                            Break
                        }
                        'PrincipalSID' {
                            $SIDObject = New-Object System.Security.Principal.SecurityIdentifier($PrincipalItem.Replace('*',''))
                            $SIDObject.Translate([Security.Principal.NTAccount]).Value
                            Break
                        }
                    }
                }
                Catch {

                    ## Return custom error. The error handling is done here in order not to break the ForEach loop and allow it to continue.
                    $Exception     = [Exception]::new($PsItem.Exception.Message)
                    $ExceptionType = [Management.Automation.ErrorCategory]::ObjectNotFound
                    $ErrorRecord   = [System.Management.Automation.ErrorRecord]::new($Exception, $PsItem.FullyQualifiedErrorId, $ExceptionType, $PrincipalItem)
                    $PSCmdlet.WriteError($ErrorRecord)
                }
            }
        }
        Catch {
            $PSCmdlet.WriteError($PSItem)
        }
        Finally {
            Write-Output -InputObject $Output
        }
    }
}
#endregion

#region Function Get-UserRightsAssignment
Function Get-UserRightsAssignment {
<#
.SYNOPSIS
    Gets user rights assignment.
.DESCRIPTION
    Gets user rights assignment for a local computer.
.PARAMETER Principal
    Defines the Principal to get the rights for.
    Default is: 'All'.
.PARAMETER Privilege
    Defines the User Right(s) to get the principals for.
    Valid values are:
        SeAssignPrimaryTokenPrivilege
        SeAuditPrivilege
        SeBackupPrivilege
        SeBatchLogonRight
        SeChangeNotifyPrivilege
        SeCreateGlobalPrivilege
        SeCreatePagefilePrivilege
        SeCreatePermanentPrivilege
        SeCreateSymbolicLinkPrivilege
        SeCreateTokenPrivilege
        SeDebugPrivilege
        SeDelegateSessionUserImpersonatePrivilege
        SeDenyBatchLogonRight
        SeDenyInteractiveLogonRight
        SeDenyNetworkLogonRight
        SeDenyRemoteInteractiveLogonRight
        SeDenyServiceLogonRight
        SeEnableDelegationPrivilege
        SeImpersonatePrivilege
        SeIncreaseBasePriorityPrivilege
        SeIncreaseQuotaPrivilege
        SeIncreaseWorkingSetPrivilege
        SeInteractiveLogonRight
        SeLoadDriverPrivilege
        SeLockMemoryPrivilege
        SeMachineAccountPrivilege
        SeManageVolumePrivilege
        SeNetworkLogonRight
        SeProfileSingleProcessPrivilege
        SeRelabelPrivilege
        SeRemoteInteractiveLogonRight
        SeRemoteShutdownPrivilege
        SeRestorePrivilege
        SeSecurityPrivilege
        SeServiceLogonRight
        SeShutdownPrivilege
        SeSyncAgentPrivilege
        SeSystemEnvironmentPrivilege
        SeSystemProfilePrivilege
        SeSystemtimePrivilege
        SeTakeOwnershipPrivilege
        SeTcbPrivilege
        SeTimeZonePrivilege
        SeTrustedCredManAccessPrivilege
        SeUndockPrivilege
.EXAMPLE
    Get-UserRightsAssignment
.EXAMPLE
    Get-UserRightsAssignment -Principal 'CONTOSO\Group'
.EXAMPLE
    Get-UserRightsAssignment -Principal '*S-1-5-19'
.EXAMPLE
    Get-UserRightsAssignment -Privilege 'SeServiceLogonRight', 'SeRemoteInteractiveLogonRight'
.INPUTS
    None.
.OUTPUTS
    System.Object
    System.Exception
.NOTES
    Created by Ioan Popovici
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    User Rights Assignment
.FUNCTIONALITY
    Gets User Rights Assignment.
#>
    [CmdletBinding(DefaultParameterSetName = 'Principal')]
    Param (
        [Parameter(Mandatory = $false, ParameterSetName = 'Principal', Position = 0)]
        [SupportsWildcards()]
        [ValidateNotNullorEmpty()]
        [Alias('PrincipalName')]
        [string]$Principal = '*',
        [Parameter(Mandatory = $true, ParameterSetName = 'Privileges', Position = 1)]
        [ValidateSet('SeAssignPrimaryTokenPrivilege', 'SeAuditPrivilege', 'SeBackupPrivilege', 'SeBatchLogonRight', 'SeChangeNotifyPrivilege',
            'SeCreateGlobalPrivilege', 'SeCreatePagefilePrivilege', 'SeCreatePermanentPrivilege', 'SeCreateSymbolicLinkPrivilege', 'SeCreateTokenPrivilege',
            'SeDebugPrivilege', 'SeDelegateSessionUserImpersonatePrivilege', 'SeDenyBatchLogonRight', 'SeDenyInteractiveLogonRight', 'SeDenyNetworkLogonRight',
            'SeDenyRemoteInteractiveLogonRight', 'SeDenyServiceLogonRight', 'SeEnableDelegationPrivilege', 'SeImpersonatePrivilege', 'SeIncreaseBasePriorityPrivilege',
            'SeIncreaseQuotaPrivilege', 'SeIncreaseWorkingSetPrivilege', 'SeInteractiveLogonRight', 'SeLoadDriverPrivilege', 'SeLockMemoryPrivilege', 'SeMachineAccountPrivilege',
            'SeManageVolumePrivilege', 'SeNetworkLogonRight', 'SeProfileSingleProcessPrivilege', 'SeRelabelPrivilege', 'SeRemoteInteractiveLogonRight', 'SeRemoteShutdownPrivilege',
            'SeRestorePrivilege', 'SeSecurityPrivilege', 'SeServiceLogonRight', 'SeShutdownPrivilege', 'SeSyncAgentPrivilege', 'SeSystemEnvironmentPrivilege', 'SeSystemProfilePrivilege',
            'SeSystemtimePrivilege', 'SeTakeOwnershipPrivilege', 'SeTcbPrivilege', 'SeTimeZonePrivilege', 'SeTrustedCredManAccessPrivilege', 'SeUndockPrivilege', IgnoreCase = $true
        )]
        [Alias('Rights')]
        [string[]]$Privilege
    )
    Begin {

        ## Set export file path
        [string]$TempFolderPath = [System.IO.Path]::GetTempPath()
        [string]$RandomFileName = [System.IO.Path]::GetRandomFileName()
        [string]$ExportFilePath = Join-Path -Path $TempFolderPath -ChildPath $RandomFileName
        [string]$System32Path   = [Environment]::GetFolderPath([Environment+SpecialFolder]::System)

        ## Set SID regex match Pattern
        [regex]$Pattern = 'S-\d-(?:\d+-){1,14}\d+'

        ## Set output object
        $Output = $null
    }
    Process {
        Try {

            ## Check for Admin Rights
            [boolean]$IsAdministrator = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
            If (-not $IsAdministrator) { Throw 'You must have administrative privileges to run this script!' }

            ## Check if Principal is SID
            [string]$SIDMatch = (Select-String -Pattern $Pattern -InputObject $Principal).Matches.Value
            If (-not [string]::IsNullOrEmpty($SIDMatch)) { $Principal = Resolve-Principal -Principal $Principal -ErrorAction 'Stop' }
            Else { Write-Warning -Message 'You specified a Principal Name. This is not recommended if the names are not localized for the OS this script will be running on. Please use SID instead.' }

            ## Set ScEdit.exe path
            [string]$SecEdit = Join-Path -Path $System32Path -ChildPath 'SecEdit.exe' -Resolve

            ## Export User Rights Assignment to file using SecEdit.exe
            $null = & $SecEdit /export /cfg $ExportFilePath /areas USER_RIGHTS

            ## Select User Rights Assignment from file
            [regex]$Pattern = '^(Se\S+) = (\S+)'
            $UserRightsMatches = (Select-String -Path $ExportFilePath -Pattern $Pattern)

            ## Assemble Result object
            $Result = ForEach ($UserRightsMatch in $UserRightsMatches) {
                $SID = $UserRightsMatch.Matches[0].Groups[2].Value -split ','
                [pscustomobject]@{
                    Privilege     = $UserRightsMatch.Matches[0].Groups[1].Value
                    PrincipalSID  = $SID
                    PrincipalName = Resolve-Principal -Principal $SID
                }
            }

            ## Filter Output object according to parameters
            If ($PSCmdlet.ParameterSetName -eq 'Principal') {
                If ($Principal -ne '*') {
                    $FilterResult = $Result.Where({ $PsItem.PrincipalName -like $Principal })
                    $Output = [pscustomobject]@{
                        #  Stop on unresolved SID, account should exist
                        PrincipalSID  = Resolve-Principal -Principal $Principal -ErrorAction 'Stop'
                        PrincipalName = $Principal
                        Privilege     = @($FilterResult.Privilege)
                    }
                }
                Else {
                    $UniquePrincipals = $Result.PrincipalName | Sort-Object -Unique
                    $Output = ForEach ($UniquePrincipal in $UniquePrincipals) {
                        $FilterResult = ($Result.Where({ $PsItem.PrincipalName -eq $UniquePrincipal }))
                        [pscustomobject]@{
                            #  Continue on unresolved SID, account might be deleted
                            PrincipalSID  = Resolve-Principal -Principal $UniquePrincipal -ErrorAction 'SilentlyContinue'
                            PrincipalName = $UniquePrincipal
                            Privilege     = @($FilterResult.Privilege)
                        }
                    }
                }
            }
            Else { $Output = $Result.Where({ $Privilege -contains $PsItem.Privilege }) }
        }
        Catch {
            $PSCmdlet.WriteError($PSItem)
        }
        Finally {
            Write-Output -InputObject $Output
        }
    }
    End {
        Remove-Item -Path $ExportFilePath -Force -ErrorAction 'SilentlyContinue'
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

$Output = Get-UserRightsAssignment @PSBoundParameters

## Write output
Write-Output -InputObject $Output

## Write verbose info
Write-Verbose -Message $("Script '{0}\{1}' completed." -f $ScriptPath, $ScriptName) -Verbose

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================