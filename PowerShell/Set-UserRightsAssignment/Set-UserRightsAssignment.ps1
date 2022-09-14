<#
.SYNOPSIS
    Add or Remove user rights assignment.
.DESCRIPTION
    Add or Remove user rights assignment to a local computer.
.PARAMETER Action
    Specify the action to perform.
    Valid values:
        - Add
        - Remove
.PARAMETER Identity
    Defines the Identity under which the service should run.
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
    Set-UserRightsAssignment.ps1 -Add -Identity 'CONTOSO\User' -Privileges 'SeServiceLogonRight'
.EXAMPLE
    Set-UserRightsAssignment.ps1 -Remove -Identity 'CONTOSO\Group' -Privileges 'SeServiceLogonRight'
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
    Adds or Remove User Rights Assigment.
#>
<#
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = 'Add/Remove user right.', Position = 0)]
        [ValidateSet('Add', 'Remove', IgnoreCase = $true)]
        [Alias('Task')]
        [string]$Action,
        [Parameter(Mandatory = $false, Position = 1)]
        [Alias('User')]
        [string]$Identity = -join ($env:USERDOMAIN, '\', $env:USERNAME),
        [Parameter(Mandatory = $true, Position = 2)]
        [ValidateSet('SeNetworkLogonRight', 'SeBackupPrivilege', 'SeChangeNotifyPrivilege', 'SeSystemtimePrivilege', 'SeCreatePagefilePrivilege', 'SeDebugPrivilege', 'SeRemoteShutdownPrivilege', 'SeAuditPrivilege', 'SeIncreaseQuotaPrivilege', 'SeIncreaseBasePriorityPrivilege', 'SeLoadDriverPrivilege', 'SeBatchLogonRight', 'SeServiceLogonRight', 'SeInteractiveLogonRight', 'SeSecurityPrivilege', 'SeSystemEnvironmentPrivilege', 'SeProfileSingleProcessPrivilege', 'SeSystemProfilePrivilege', 'SeAssignPrimaryTokenPrivilege', 'SeRestorePrivilege', 'SeShutdownPrivilege', 'SeTakeOwnershipPrivilege', 'SeDenyNetworkLogonRight', 'SeDenyInteractiveLogonRight', 'SeUndockPrivilege', 'SeManageVolumePrivilege', 'SeRemoteInteractiveLogonRight', 'SeImpersonatePrivilege', 'SeCreateGlobalPrivilege', 'SeIncreaseWorkingSetPrivilege', 'SeTimeZonePrivilege', 'SeCreateSymbolicLinkPrivilege', 'SeDelegateSessionUserImpersonatePrivilege', 'SeMachineAccountPrivilege', 'SeTrustedCredManAccessPrivilege', 'SeTcbPrivilege', 'SeCreateTokenPrivilege', 'SeCreatePermanentPrivilege', 'SeDenyBatchLogonRight', 'SeDenyServiceLogonRight', 'SeDenyRemoteInteractiveLogonRight', 'SeEnableDelegationPrivilege', 'SeLockMemoryPrivilege', 'SeRelabelPrivilege', 'SeSyncAgentPrivilege', IgnoreCase = $true)]
        [Alias('Rights')]
        [array]$Privilege
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

#region Function Set-UserRightsAssignment
Function Set-UserRightsAssignment {
<#
.SYNOPSIS
    Add or Remove user rights assignment.
.DESCRIPTION
    Add or Remove user rights assignment to a local computer.
.PARAMETER Action
    Specify the action to perform.
    Valid values:
        - Add
        - Remove
.PARAMETER Identity
    Defines the Identity under which the service should run.
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
    Set-UserRightsAssignment -Add -Identity 'CONTOSO\User' -Privileges 'SeServiceLogonRight'
.EXAMPLE
    Set-UserRightsAssignment -Remove -Identity 'CONTOSO\Group' -Privileges 'SeServiceLogonRight'
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
    User Rights Assignment
.FUNCTIONALITY
    Adds or Remove User Rights Assignment.
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = 'Add/Remove user right.', Position = 0)]
        [ValidateSet('Add', 'Remove', IgnoreCase = $true)]
        [Alias('Task')]
        [string]$Action,
        [Parameter(Mandatory = $false, Position = 1)]
        [Alias('User')]
        [string]$Identity = -join ($env:USERDOMAIN, '\', $env:USERNAME),
        [Parameter(Mandatory = $true, Position = 2)]
        [ValidateSet('SeNetworkLogonRight', 'SeBackupPrivilege', 'SeChangeNotifyPrivilege', 'SeSystemtimePrivilege', 'SeCreatePagefilePrivilege', 'SeDebugPrivilege', 'SeRemoteShutdownPrivilege', 'SeAuditPrivilege', 'SeIncreaseQuotaPrivilege', 'SeIncreaseBasePriorityPrivilege', 'SeLoadDriverPrivilege', 'SeBatchLogonRight', 'SeServiceLogonRight', 'SeInteractiveLogonRight', 'SeSecurityPrivilege', 'SeSystemEnvironmentPrivilege', 'SeProfileSingleProcessPrivilege', 'SeSystemProfilePrivilege', 'SeAssignPrimaryTokenPrivilege', 'SeRestorePrivilege', 'SeShutdownPrivilege', 'SeTakeOwnershipPrivilege', 'SeDenyNetworkLogonRight', 'SeDenyInteractiveLogonRight', 'SeUndockPrivilege', 'SeManageVolumePrivilege', 'SeRemoteInteractiveLogonRight', 'SeImpersonatePrivilege', 'SeCreateGlobalPrivilege', 'SeIncreaseWorkingSetPrivilege', 'SeTimeZonePrivilege', 'SeCreateSymbolicLinkPrivilege', 'SeDelegateSessionUserImpersonatePrivilege', 'SeMachineAccountPrivilege', 'SeTrustedCredManAccessPrivilege', 'SeTcbPrivilege', 'SeCreateTokenPrivilege', 'SeCreatePermanentPrivilege', 'SeDenyBatchLogonRight', 'SeDenyServiceLogonRight', 'SeDenyRemoteInteractiveLogonRight', 'SeEnableDelegationPrivilege', 'SeLockMemoryPrivilege', 'SeRelabelPrivilege', 'SeSyncAgentPrivilege', IgnoreCase = $true)]
        [Alias('Rights')]
        [array]$Privileges
    )

    Begin {

        ## Cleanup
        [string]$TempFolderPath = [System.IO.Path]::GetTempPath()
        [string]$ImportFile = Join-Path -Path $TempFolderPath -ChildPath 'import.inf'
        If (Test-Path -Path $ImportFile) { Remove-Item -Path $ImportFile -Force }
        [string]$ExportFile = Join-Path -Path $TempFolderPath -ChildPath 'export.inf'
        If (Test-Path $ExportFile) { Remove-Item -Path $ExportFile -Force }
        [string]$SecedtFile = Join-Path -Path $TempFolderPath -ChildPath 'secedt.sdb'
        If (Test-Path -Path $SecedtFile) { Remove-Item -Path $SecedtFile -Force }

        ## Set output Object
        $Result = [ordered]@{
            SID          = 'N/A'
            Identity     = $Identity
            Privilege    = 'N/A'
            Action       = $Action
            Operation    = 'N/A'
        }
    }
    Process {
        Try {

            ## Check for Admin Rights
            $IsAdministrator = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
            If (-not $IsAdministrator) { Throw 'You must have administrative privileges to run this script!' }

                ## Set user rights
                $Output = ForEach ($Privilege in $Privileges) {
                $Result.Privilege = $Privilege

                ## Get user SID
                $SID = ((New-Object System.Security.Principal.NTAccount($Identity)).Translate([System.Security.Principal.SecurityIdentifier])).Value
                $Result.SID = $SID

                ## Export current user rights
                $null = secedit /export /cfg $ExportFile

                ## Select the user right to modify
                $SIDs = (Select-String $ExportFile -Pattern $Privilege).Line

                ## Add or remove user right to the SIDList
                Switch ($Action) {
                    'Add'    { $SIDList = "$SIDs,*$SID"; Break }
                    'Remove' { $SIDList = $($SIDs.Replace("*$SID", '').Replace($Identity, '').Replace(',,', ',').Replace('= ,', '= ')); Break }
                }

                ## Assemble the import file to use with secedit
                $Lines = @('[Unicode]', 'Unicode=yes', '[System Access]', '[Event Audit]', '[Registry Values]', '[Version]', "Signature=`"`$CHICAGO$`"", 'Revision=1', '[Profile Description]', "Description=$Action $Priviledge for $Identity", "[Privilege Rights]", "$SIDList")
                ForEach ($Line in $Lines) { Add-Content -Path $ImportFile -Value $Line }

                ## Use secedit to set user rights by importing the previously created import file
                $null = secedit /import /db $SecedtFile /cfg $ImportFile
                $null = secedit /configure /db $SecedtFile

                ## Cleanup
                Remove-Item -Path $ImportFile -Force -ErrorAction 'SilentlyContinue'
                Remove-Item -Path $ExportFile -Force -ErrorAction 'SilentlyContinue'
                Remove-Item -Path $SecedtFile -Force -ErrorAction 'SilentlyContinue'

                ## Return results
                $Result.Operation = 'Successful'
                [pscustomobject]$Result
            }
        }
        Catch {
            $Result.Operation = 'Failed'
            $Output += $Result
            $ErrorMessage = "Error granting '{0}' to '{1}' on '{2}'!" -f $Privilege, $Identity, $env:COMPUTERNAME, $($PsItem.Exception.Message)
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
    #  Set user rights
    Set-UserRightsAssignment -Action 'Add' -Identity 'BUILTIN\Administrators'       -Privileges 'SeRemoteInteractiveLogonRight', 'SeShutdownPrivilege', 'SeSystemProfilePrivilege', 'SeUndockPrivilege' -ErrorAction 'SilentlyContinue'
    Set-UserRightsAssignment -Action 'Add' -Identity 'BUILTIN\Users'                -Privileges 'SeRemoteInteractiveLogonRight', 'SeUndockPrivilege'                                                    -ErrorAction 'SilentlyContinue'
    Set-UserRightsAssignment -Action 'Add' -Identity 'BUILTIN\Remote Desktop Users' -Privileges 'SeRemoteInteractiveLogonRight'                                                                         -ErrorAction 'SilentlyContinue'
    Set-UserRightsAssignment -Action 'Add' -Identity 'BUILTIN\Guests'               -Privileges 'SeDenyBatchLogonRight', 'SeDenyServiceLogonRight'                                                      -ErrorAction 'SilentlyContinue'
    Set-UserRightsAssignment -Action 'Add' -Identity 'NT AUTHORITY\LOCAL SERVICE'   -Privileges 'SeAssignPrimaryTokenPrivilege'                                                                         -ErrorAction 'SilentlyContinue'
    Set-UserRightsAssignment -Action 'Add' -Identity 'NT AUTHORITY\NETWORK SERVICE' -Privileges 'SeAssignPrimaryTokenPrivilege'                                                                         -ErrorAction 'SilentlyContinue'
    Set-UserRightsAssignment -Action 'Add' -Identity 'NT SERVICE\WdiServiceHost'    -Privileges 'SeSystemProfilePrivilege'                                                                              -ErrorAction 'SilentlyContinue'
    #  Update Group Policy
    $null = gpupdate /force
    Write-Verbose -Message $("Script '{0}\{1}' completed." -f $ScriptPath, $ScriptName) -Verbose
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