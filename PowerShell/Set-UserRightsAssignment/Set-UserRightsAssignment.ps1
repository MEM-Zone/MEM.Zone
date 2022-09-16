<#
.SYNOPSIS
    Add, Remove or replace user rights assignment.
.DESCRIPTION
    Add, Remove or replace user rights assignment to a local computer.
.PARAMETER Action
    Specify the action to perform.
    Valid values:
        - Add
        - Remove
        - Replace
.PARAMETER Principal
    Defines the Principal under which the service should run.
    Default is the current user.
.PARAMETER Privilege
    Defines the User Right(s) you want to set.
    Valid values are:
        SeAssignPrimaryTokenPrivilege
        SeAuditPrivilege
        SeBackupPrivilege
        SeChangeNotifyPrivilege
        SeCreateGlobalPrivilege
        SeCreatePagefilePrivilege
        SeCreatePermanentPrivilege
        SeCreateSymbolicLinkPrivilege
        SeCreateTokenPrivilege
        SeDebugPrivilege
        SeEnableDelegationPrivilege
        SeImpersonatePrivilege
        SeIncreaseBasePriorityPrivilege
        SeIncreaseQuotaPrivilege
        SeIncreaseWorkingSetPrivilege
        SeLoadDriverPrivilege
        SeLockMemoryPrivilege
        SeMachineAccountPrivilege
        SeManageVolumePrivilege
        SeProfileSingleProcessPrivilege
        SeRelabelPrivilege
        SeRemoteShutdownPrivilege
        SeRestorePrivilege
        SeSecurityPrivilege
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
        SeUnsolicitedInputPrivilege
.EXAMPLE
    Set-UserRightsAssignment.ps1 -Add -Principal 'CONTOSO\User' -Privileges 'SeServiceLogonRight'
.EXAMPLE
    Set-UserRightsAssignment.ps1 -Add -Principal 'S-1-5-21-1234567890-1234567890-1234567890-500' -Privileges 'SeServiceLogonRight'
.EXAMPLE
    Set-UserRightsAssignment.ps1 -Remove -Principal 'CONTOSO\Group' -Privileges 'SeServiceLogonRight'
.EXAMPLE
    Set-UserRightsAssignment.ps1 -Replace -Principal 'CONTOSO\Group' -Privileges 'SeServiceLogonRight'
.INPUTS
    None.
.OUTPUTS
    None.
.NOTES
    Created by Ioan Popovici
    Original script by Bill Loytty (weloytty)
.LINK
    https://MEM.Zone/UserRightsAssignment
.LINK
    https://MEM.Zone/UserRightsAssignment-GIT
.LINK
    https://MEM.Zone/ISSUES
.LINK
    https://github.com/weloytty/QuirkyPSFunctions/blob/ab4b02f9cc05505eee97d2f744f4c9c798143af1/Source/Users/Grant-LogOnAsService.ps1
.COMPONENT
    User Rights Assignment
.FUNCTIONALITY
    Sets User Rights Assigment.
#>
<#
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = 'Add/Remove user right.', Position = 0)]
        [ValidateSet('Add', 'Remove', 'Replace', IgnoreCase = $true)]
        [Alias('Task')]
        [string]$Action,
        [Parameter(Mandatory = $false, Position = 1)]
        [Alias('User')]
        [string]$Principal = -join ($env:USERDOMAIN, '\', $env:USERNAME),
        [Parameter(Mandatory = $true, Position = 2)]
        [ValidateSet('SeNetworkLogonRight','SeBackupPrivilege','SeChangeNotifyPrivilege','SeSystemtimePrivilege','SeCreatePagefilePrivilege',
            'SeDebugPrivilege','SeRemoteShutdownPrivilege','SeAuditPrivilege','SeIncreaseQuotaPrivilege','SeIncreaseBasePriorityPrivilege',
            'SeLoadDriverPrivilege','SeBatchLogonRight','SeServiceLogonRight','SeInteractiveLogonRight','SeSecurityPrivilege',
            'SeSystemEnvironmentPrivilege','SeProfileSingleProcessPrivilege','SeSystemProfilePrivilege','SeAssignPrimaryTokenPrivilege',
            'SeRestorePrivilege','SeShutdownPrivilege','SeTakeOwnershipPrivilege','SeDenyNetworkLogonRight','SeDenyInteractiveLogonRight',
            'SeUndockPrivilege','SeManageVolumePrivilege','SeRemoteInteractiveLogonRight','SeImpersonatePrivilege','SeCreateGlobalPrivilege',
            'SeIncreaseWorkingSetPrivilege','SeTimeZonePrivilege','SeCreateSymbolicLinkPrivilege','SeDelegateSessionUserImpersonatePrivilege',
            'SeMachineAccountPrivilege','SeTrustedCredManAccessPrivilege','SeTcbPrivilege','SeCreateTokenPrivilege','SeCreatePermanentPrivilege',
            'SeDenyBatchLogonRight','SeDenyServiceLogonRight','SeDenyRemoteInteractiveLogonRight','SeEnableDelegationPrivilege',
            'SeLockMemoryPrivilege','SeRelabelPrivilege','SeSyncAgentPrivilege', IgnoreCase = $true
        )]
        [Alias('Rights')]
        [string[]]$Privilege
    )
#>

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
            $PSCmdlet.WriteError()
        }
        Finally {
            Write-Output -InputObject $Output
        }
    }
}
#endregion

#region Function Set-UserRightsAssignment
Function Set-UserRightsAssignment {
<#
.SYNOPSIS
    Add, Remove or replace user rights assignment.
.DESCRIPTION
    Add, Remove or replace user rights assignment to a local computer.
.PARAMETER Action
    Specify the action to perform.
    Valid values:
        - Add
        - Remove
        - Replace
.PARAMETER Principal
    Defines the Principal under which the service should run.
    Default is the current user.
.PARAMETER Privileges
    Defines the User Right(s) you want to set.
    Valid values are:
        SeAssignPrimaryTokenPrivilege
        SeAuditPrivilege
        SeBackupPrivilege
        SeChangeNotifyPrivilege
        SeCreateGlobalPrivilege
        SeCreatePagefilePrivilege
        SeCreatePermanentPrivilege
        SeCreateSymbolicLinkPrivilege
        SeCreateTokenPrivilege
        SeDebugPrivilege
        SeEnableDelegationPrivilege
        SeImpersonatePrivilege
        SeIncreaseBasePriorityPrivilege
        SeIncreaseQuotaPrivilege
        SeIncreaseWorkingSetPrivilege
        SeLoadDriverPrivilege
        SeLockMemoryPrivilege
        SeMachineAccountPrivilege
        SeManageVolumePrivilege
        SeProfileSingleProcessPrivilege
        SeRelabelPrivilege
        SeRemoteShutdownPrivilege
        SeRestorePrivilege
        SeSecurityPrivilege
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
        SeUnsolicitedInputPrivilege
.EXAMPLE
    Set-UserRightsAssignment -Add -Principal 'CONTOSO\User' -Privileges 'SeServiceLogonRight'
.EXAMPLE
    Set-UserRightsAssignment -Add -Principal 'S-1-5-21-1234567890-1234567890-1234567890-500' -Privileges 'SeServiceLogonRight'
.EXAMPLE
    Set-UserRightsAssignment -Remove -Principal 'CONTOSO\Group' -Privileges 'SeServiceLogonRight'
.EXAMPLE
    Set-UserRightsAssignment -Replace -Principal 'CONTOSO\Group' -Privileges 'SeServiceLogonRight'
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
    Sets User Rights Assignment.
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = 'Add/Remove user right.', Position = 0)]
        [ValidateSet('Add', 'Remove', 'Replace', IgnoreCase = $true)]
        [Alias('Task')]
        [string]$Action,
        [Parameter(Mandatory = $false, Position = 1)]
        [Alias('User')]
        [string]$Principal = -join ($env:USERDOMAIN, '\', $env:USERNAME),
        [Parameter(Mandatory = $true, Position = 2)]
        [ValidateSet('SeNetworkLogonRight','SeBackupPrivilege','SeChangeNotifyPrivilege','SeSystemtimePrivilege','SeCreatePagefilePrivilege',
            'SeDebugPrivilege','SeRemoteShutdownPrivilege','SeAuditPrivilege','SeIncreaseQuotaPrivilege','SeIncreaseBasePriorityPrivilege',
            'SeLoadDriverPrivilege','SeBatchLogonRight','SeServiceLogonRight','SeInteractiveLogonRight','SeSecurityPrivilege',
            'SeSystemEnvironmentPrivilege','SeProfileSingleProcessPrivilege','SeSystemProfilePrivilege','SeAssignPrimaryTokenPrivilege',
            'SeRestorePrivilege','SeShutdownPrivilege','SeTakeOwnershipPrivilege','SeDenyNetworkLogonRight','SeDenyInteractiveLogonRight',
            'SeUndockPrivilege','SeManageVolumePrivilege','SeRemoteInteractiveLogonRight','SeImpersonatePrivilege','SeCreateGlobalPrivilege',
            'SeIncreaseWorkingSetPrivilege','SeTimeZonePrivilege','SeCreateSymbolicLinkPrivilege','SeDelegateSessionUserImpersonatePrivilege',
            'SeMachineAccountPrivilege','SeTrustedCredManAccessPrivilege','SeTcbPrivilege','SeCreateTokenPrivilege','SeCreatePermanentPrivilege',
            'SeDenyBatchLogonRight','SeDenyServiceLogonRight','SeDenyRemoteInteractiveLogonRight','SeEnableDelegationPrivilege',
            'SeLockMemoryPrivilege','SeRelabelPrivilege','SeSyncAgentPrivilege', IgnoreCase = $true
        )]
        [Alias('Rights')]
        [string[]]$Privilege
    )
    Begin {

        ## Set paths
        $Path = [System.IO.Path]
        [string]$TempFolderPath = $Path::GetTempPath()
        [scriptblock]$RandomFileName = { $Path::GetRandomFileName() }
        [string]$ExportFilePath = Join-Path -Path $TempFolderPath -ChildPath $Path::ChangeExtension($RandomFileName.Invoke(),'.ini')
        [string]$ImportFilePath = Join-Path -Path $TempFolderPath -ChildPath $Path::ChangeExtension($RandomFileName.Invoke(),'.ini')
        [string]$SecedtFilePath = Join-Path -Path $TempFolderPath -ChildPath $Path::ChangeExtension($RandomFileName.Invoke(),'.sdb')
        [string]$System32Path   = [Environment]::GetFolderPath([Environment+SpecialFolder]::System)

        ## Set output Object
        $Result = [ordered]@{
            PrincipalSID  = 'N/A'
            PrincipalName = $Principal
            Privilege     = 'N/A'
            Action        = $Action
            Operation     = 'N/A'
        }

        ## Set SID regex match Pattern
        [regex]$Pattern = 'S-\d-(?:\d+-){1,14}\d+'

    }
    Process {
        Try {

            ## Check for Admin Rights
            [boolean]$IsAdministrator = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
            If (-not $IsAdministrator) { Throw 'You must have administrative privileges to run this script!' }

            ## Set ScEdit.exe path
            [string]$SecEdit = Join-Path -Path $System32Path -ChildPath 'SecEdit.exe' -Resolve

            ## Check if Principal is SID
            [string]$SIDMatch = (Select-String -Pattern $Pattern -InputObject $Principal).Matches.Value
            If ([string]::IsNullOrEmpty($SIDMatch)) {
                $SID = Resolve-Principal -Principal $Principal
                $Result.PrincipalSID = $SID
            }
            Else {
                $SID = $Principal
                $Principal = Resolve-Principal -Principal $SID
                $Result.PrincipalName = $Principal
                $Result.PrincipalSID = $SID
            }

            ## Set user rights
            $Output = ForEach ($PrivilegeItem in $Privilege) {
                $Result.Privilege = $PrivilegeItem

                ## Export current user rights
                $null = & $SecEdit /export /cfg $ExportFilePath

                ## Select the user right to modify
                $SIDs = (Select-String $ExportFilePath -Pattern $PrivilegeItem).Line

                ## Add or remove user right to the SIDList
                Switch ($Action) {
                    'Add'     { $SIDList = "$SIDs,*$SID"; Break }
                    'Remove'  { $SIDList = $($SIDs.Replace("*$SID", '').Replace($Principal, '').Replace(',,', ',').Replace('= ,', '= ')); Break }
                    'Replace' { $SIDList = "*$SID"; Break }
                }

                ## Assemble the import file to use with secedit
                $Lines = @('[Unicode]', 'Unicode=yes', '[System Access]', '[Event Audit]', '[Registry Values]', '[Version]', "Signature=`"`$CHICAGO$`"", 'Revision=1', '[Profile Description]', "Description=$Action $PrivilegeItem for $Principal", "[Privilege Rights]", "$SIDList")
                ForEach ($Line in $Lines) { Add-Content -Path $ImportFilePath -Value $Line }

                ## Use secedit to set user rights by importing the previously created import file
                $null = & $SecEdit /import /db $SecedtFilePath /cfg $ImportFilePath
                $null = & $SecEdit /configure /db $SecedtFilePath

                ## Cleanup
                Remove-Item -Path $ImportFilePath -Force -ErrorAction 'SilentlyContinue'
                Remove-Item -Path $ExportFilePath -Force -ErrorAction 'SilentlyContinue'
                Remove-Item -Path $SecedtFilePath -Force -ErrorAction 'SilentlyContinue'

                ## Return results
                $Result.Operation = 'Successful'
                [pscustomobject]$Result
            }
        }
        Catch {
            $Result.Operation = 'Failed'
            $Output += $Result
            $ErrorMessage = "Error granting '{0}' to '{1}' on '{2}'!" -f $PrivilegeItem, $Principal, $env:COMPUTERNAME, $($PsItem.Exception.Message)
            Throw (New-Object System.Exception($ErrorMessage, $PsItem.Exception))
        }
        Finally {
            Write-Output -InputObject $Output
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

## Write verbose info
Write-Verbose -Message $("Script '{0}\{1}' started." -f $ScriptPath, $ScriptName) -Verbose

## Assemble scriptblock
[scriptblock]$SetUserRightsAssignments = {
    #  Set ErrorActionPreference to SilentlyContinue
    $SavedErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    #  Set user rights
    Set-UserRightsAssignment -Action 'Replace' -Principal 'BUILTIN\Administrators'       -Privilege 'SeRemoteInteractiveLogonRight', 'SeShutdownPrivilege', 'SeSystemProfilePrivilege', 'SeUndockPrivilege'
    Set-UserRightsAssignment -Action 'Replace' -Principal 'BUILTIN\Users'                -Privilege 'SeShutdownPrivilege', 'SeUndockPrivilege'
    Set-UserRightsAssignment -Action 'Replace' -Principal 'BUILTIN\Remote Desktop Users' -Privilege 'SeRemoteInteractiveLogonRight'
    Set-UserRightsAssignment -Action 'Replace' -Principal 'BUILTIN\Guests'               -Privilege 'SeDenyBatchLogonRight', 'SeDenyServiceLogonRight'
    Set-UserRightsAssignment -Action 'Replace' -Principal 'NT AUTHORITY\LOCAL SERVICE'   -Privilege 'SeAssignPrimaryTokenPrivilege'
    Set-UserRightsAssignment -Action 'Replace' -Principal 'NT AUTHORITY\NETWORK SERVICE' -Privilege 'SeAssignPrimaryTokenPrivilege'
    Set-UserRightsAssignment -Action 'Replace' -Principal 'NT SERVICE\WdiServiceHost'    -Privilege 'SeSystemProfilePrivilege'
    #  Update Group Policy
    $null = gpupdate /force
    #  Restore ErrorActionPreference to original value
    $ErrorActionPreference = $SavedErrorActionPreference
}

## Execute scriptblock
$Output = $SetUserRightsAssignments.Invoke()

## Write output
Write-Output -InputObject $Output

## Write verbose info
Write-Verbose -Message $("Script '{0}\{1}' completed." -f $ScriptPath, $ScriptName) -Verbose

## Handle exit codes for proactive remediations
If ($Output -contains 'Failed') { Exit 1}
Else { Exit 0 }

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================