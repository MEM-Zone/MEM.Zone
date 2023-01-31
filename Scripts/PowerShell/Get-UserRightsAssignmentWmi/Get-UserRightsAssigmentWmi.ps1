<#
.SYNOPSIS
    Gets user rights assignment for a local computer.
.DESCRIPTION
    Gets user rights assignment for a local computer, and adds the result to the `Win32_UserRightsAssignment` WMI class.
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
    https://MEM.Zone/Get-UserRightsAssignmentWmi
.LINK
    https://MEM.Zone/Get-UserRightsAssignmentWmi-CHANGELOG
.LINK
    https://MEM.Zone/Get-UserRightsAssignmentWmi-GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    User Rights Assignment
.FUNCTIONALITY
    Gets User Rights Assigment.
#>

<#
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
#>

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

## Add the UserRightsFlags enum type .NET definition to the current PowerShell session
Add-Type @'
using System;

[Flags]
public enum UserRightsFlags : ulong  {
    None                                      = 0,
    SeAssignPrimaryTokenPrivilege             = 1L << 0,
    SeAuditPrivilege                          = 1L << 1,
    SeBackupPrivilege                         = 1L << 2,
    SeBatchLogonRight                         = 1L << 3,
    SeChangeNotifyPrivilege                   = 1L << 4,
    SeCreateGlobalPrivilege                   = 1L << 5,
    SeCreatePagefilePrivilege                 = 1L << 6,
    SeCreatePermanentPrivilege                = 1L << 7,
    SeCreateSymbolicLinkPrivilege             = 1L << 8,
    SeCreateTokenPrivilege                    = 1L << 9,
    SeDebugPrivilege                          = 1L << 10,
    SeDelegateSessionUserImpersonatePrivilege = 1L << 11,
    SeDenyBatchLogonRight                     = 1L << 12,
    SeDenyInteractiveLogonRight               = 1L << 13,
    SeDenyNetworkLogonRight                   = 1L << 14,
    SeDenyRemoteInteractiveLogonRight         = 1L << 15,
    SeDenyServiceLogonRight                   = 1L << 16,
    SeEnableDelegationPrivilege               = 1L << 17,
    SeImpersonatePrivilege                    = 1L << 18,
    SeIncreaseBasePriorityPrivilege           = 1L << 19,
    SeIncreaseQuotaPrivilege                  = 1L << 20,
    SeIncreaseWorkingSetPrivilege             = 1L << 21,
    SeInteractiveLogonRight                   = 1L << 22,
    SeLoadDriverPrivilege                     = 1L << 23,
    SeLockMemoryPrivilege                     = 1L << 24,
    SeMachineAccountPrivilege                 = 1L << 25,
    SeManageVolumePrivilege                   = 1L << 26,
    SeNetworkLogonRight                       = 1L << 27,
    SeProfileSingleProcessPrivilege           = 1L << 28,
    SeRelabelPrivilege                        = 1L << 29,
    SeRemoteInteractiveLogonRight             = 1L << 30,
    SeRemoteShutdownPrivilege                 = 1L << 31,
    SeRestorePrivilege                        = 1L << 32,
    SeSecurityPrivilege                       = 1L << 33,
    SeServiceLogonRight                       = 1L << 34,
    SeShutdownPrivilege                       = 1L << 35,
    SeSyncAgentPrivilege                      = 1L << 36,
    SeSystemEnvironmentPrivilege              = 1L << 37,
    SeSystemProfilePrivilege                  = 1L << 38,
    SeSystemtimePrivilege                     = 1L << 39,
    SeTakeOwnershipPrivilege                  = 1L << 40,
    SeTcbPrivilege                            = 1L << 41,
    SeTimeZonePrivilege                       = 1L << 42,
    SeTrustedCredManAccessPrivilege           = 1L << 43,
    SeUndockPrivilege                         = 1L << 44
}
'@

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
                            $SIDObject = New-Object System.Security.Principal.SecurityIdentifier($PrincipalItem.Replace('*', ''))
                            $SIDObject.Translate([Security.Principal.NTAccount]).Value
                            Break
                        }
                    }
                }
                Catch {

                    ## Return custom error. The error handling is done here in order not to break the ForEach loop and allow it to continue.
                    $Exception = [Exception]::new($PsItem.Exception.Message)
                    $ExceptionType = [Management.Automation.ErrorCategory]::ObjectNotFound
                    $ErrorRecord = [System.Management.Automation.ErrorRecord]::new($Exception, $PsItem.FullyQualifiedErrorId, $ExceptionType, $PrincipalItem)
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
        [string]$System32Path = [Environment]::GetFolderPath([Environment+SpecialFolder]::System)

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

#region ConvertTo-HashtableFromPsCustomObject
Function ConvertTo-HashtableFromPsCustomObject {
    <#
.SYNOPSIS
    Converts a custom object to a hashtable.
.DESCRIPTION
    Converts a custom powershell object to a hashtable.
.PARAMETER PsCustomObject
    Specifies the custom object to be converted.
.EXAMPLE
    ConvertTo-HashtableFromPsCustomObject -PsCustomObject $PsCustomObject
.EXAMPLE
    $PsCustomObject | ConvertTo-HashtableFromPsCustomObject
.INPUTS
    System.Object
.OUTPUTS
    System.Object
.NOTES
    Created Ioan Popovici
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/Issues
.COMPONENT
    Conversion
.FUNCTIONALITY
    Convert custom object to hashtable
#>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$PsCustomObject
    )
    Begin {

        ## Preservers hashtable parameter order
        [System.Collections.Specialized.OrderedDictionary]$Output = @{}
    }
    Process {

        ## The '.PsObject.Members' method preservers the order of the members, Get-Member does not.
        [object]$ObjectProperties = $PsCustomObject.PsObject.Members | Where-Object -Property 'MemberType' -EQ 'NoteProperty'
        ForEach ($Property in $ObjectProperties) { $Output.Add($Property.Name, $PsCustomObject.$($Property.Name)) }
        Write-Output -InputObject $Output
    }
}
#endregion

#region PsWmiToolkit
##*=============================================
##* MODULE DEFINITION
##*=============================================

#region Function Resolve-Error
Function Resolve-Error {
<#
.SYNOPSIS
    Enumerate error record details.
.DESCRIPTION
    Enumerate an error record, or a collection of error record, properties. By default, the details for the last error will be enumerated.
.PARAMETER ErrorRecord
    The error record to resolve. The default error record is the latest one: $global:Error[0]. This parameter will also accept an array of error records.
.PARAMETER Property
    The list of properties to display from the error record. Use "*" to display all properties.
    Default list of error properties is: Message, FullyQualifiedErrorId, ScriptStackTrace, PositionMessage, InnerException
.PARAMETER GetErrorRecord
    Get error record details as represented by $_.
.PARAMETER GetErrorInvocation
    Get error record invocation information as represented by $_.InvocationInfo.
.PARAMETER GetErrorException
    Get error record exception details as represented by $_.Exception.
.PARAMETER GetErrorInnerException
    Get error record inner exception details as represented by $_.Exception.InnerException. Will retrieve all inner exceptions if there is more than one.
.EXAMPLE
    Resolve-Error
.EXAMPLE
    Resolve-Error -Property *
.EXAMPLE
    Resolve-Error -Property InnerException
.EXAMPLE
    Resolve-Error -GetErrorInvocation:$false
.NOTES
.LINK
    https://psappdeploytoolkit.com
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $false, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [AllowEmptyCollection()]
        [array]$ErrorRecord,
        [Parameter(Mandatory = $false, Position = 1)]
        [ValidateNotNullorEmpty()]
        [string[]]$Property = ('Message', 'InnerException', 'FullyQualifiedErrorId', 'ScriptStackTrace', 'PositionMessage'),
        [Parameter(Mandatory = $false, Position = 2)]
        [switch]$GetErrorRecord = $true,
        [Parameter(Mandatory = $false, Position = 3)]
        [switch]$GetErrorInvocation = $true,
        [Parameter(Mandatory = $false, Position = 4)]
        [switch]$GetErrorException = $true,
        [Parameter(Mandatory = $false, Position = 5)]
        [switch]$GetErrorInnerException = $true
    )

    Begin {
        ## If function was called without specifying an error record, then choose the latest error that occurred
        If (-not $ErrorRecord) {
            If ($global:Error.Count -eq 0) {
                #Write-Warning -Message "The `$Error collection is empty"
                Return
            }
            Else {
                [array]$ErrorRecord = $global:Error[0]
            }
        }

        ## Allows selecting and filtering the properties on the error object if they exist
        [scriptblock]$SelectProperty = {
            Param (
                [Parameter(Mandatory = $true)]
                [ValidateNotNullorEmpty()]
                $InputObject,
                [Parameter(Mandatory = $true)]
                [ValidateNotNullorEmpty()]
                [string[]]$Property
            )

            [string[]]$ObjectProperty = $InputObject | Get-Member -MemberType '*Property' | Select-Object -ExpandProperty 'Name'
            ForEach ($Prop in $Property) {
                If ($Prop -eq '*') {
                    [string[]]$PropertySelection = $ObjectProperty
                    Break
                }
                ElseIf ($ObjectProperty -contains $Prop) {
                    [string[]]$PropertySelection += $Prop
                }
            }
            Write-Output -InputObject $PropertySelection
        }

        #  Initialize variables to avoid error if 'Set-StrictMode' is set
        $LogErrorRecordMsg = $null
        $LogErrorInvocationMsg = $null
        $LogErrorExceptionMsg = $null
        $LogErrorMessageTmp = $null
        $LogInnerMessage = $null
    }
    Process {
        If (-not $ErrorRecord) { Return }
        ForEach ($ErrRecord in $ErrorRecord) {
            ## Capture Error Record
            If ($GetErrorRecord) {
                [string[]]$SelectedProperties = & $SelectProperty -InputObject $ErrRecord -Property $Property
                $LogErrorRecordMsg = $ErrRecord | Select-Object -Property $SelectedProperties
            }

            ## Error Invocation Information
            If ($GetErrorInvocation) {
                If ($ErrRecord.InvocationInfo) {
                    [string[]]$SelectedProperties = & $SelectProperty -InputObject $ErrRecord.InvocationInfo -Property $Property
                    $LogErrorInvocationMsg = $ErrRecord.InvocationInfo | Select-Object -Property $SelectedProperties
                }
            }

            ## Capture Error Exception
            If ($GetErrorException) {
                If ($ErrRecord.Exception) {
                    [string[]]$SelectedProperties = & $SelectProperty -InputObject $ErrRecord.Exception -Property $Property
                    $LogErrorExceptionMsg = $ErrRecord.Exception | Select-Object -Property $SelectedProperties
                }
            }

            ## Display properties in the correct order
            If ($Property -eq '*') {
                #  If all properties were chosen for display, then arrange them in the order the error object displays them by default.
                If ($LogErrorRecordMsg) { [array]$LogErrorMessageTmp += $LogErrorRecordMsg }
                If ($LogErrorInvocationMsg) { [array]$LogErrorMessageTmp += $LogErrorInvocationMsg }
                If ($LogErrorExceptionMsg) { [array]$LogErrorMessageTmp += $LogErrorExceptionMsg }
            }
            Else {
                #  Display selected properties in our custom order
                If ($LogErrorExceptionMsg) { [array]$LogErrorMessageTmp += $LogErrorExceptionMsg }
                If ($LogErrorRecordMsg) { [array]$LogErrorMessageTmp += $LogErrorRecordMsg }
                If ($LogErrorInvocationMsg) { [array]$LogErrorMessageTmp += $LogErrorInvocationMsg }
            }

            If ($LogErrorMessageTmp) {
                $LogErrorMessage = 'Error Record:'
                $LogErrorMessage += "`n-------------"
                $LogErrorMsg = $LogErrorMessageTmp | Format-List | Out-String
                $LogErrorMessage += $LogErrorMsg
            }

            ## Capture Error Inner Exception(s)
            If ($GetErrorInnerException) {
                If ($ErrRecord.Exception -and $ErrRecord.Exception.InnerException) {
                    $LogInnerMessage = 'Error Inner Exception(s):'
                    $LogInnerMessage += "`n-------------------------"

                    $ErrorInnerException = $ErrRecord.Exception.InnerException
                    $Count = 0

                    While ($ErrorInnerException) {
                        [string]$InnerExceptionSeperator = '~' * 40

                        [string[]]$SelectedProperties = & $SelectProperty -InputObject $ErrorInnerException -Property $Property
                        $LogErrorInnerExceptionMsg = $ErrorInnerException | Select-Object -Property $SelectedProperties | Format-List | Out-String

                        If ($Count -gt 0) { $LogInnerMessage += $InnerExceptionSeperator }
                        $LogInnerMessage += $LogErrorInnerExceptionMsg

                        $Count++
                        $ErrorInnerException = $ErrorInnerException.InnerException
                    }
                }
            }

            If ($LogErrorMessage) { $Output = $LogErrorMessage }
            If ($LogInnerMessage) { $Output += $LogInnerMessage }

            Write-Output -InputObject $Output

            If (Test-Path -LiteralPath 'variable:Output') { Clear-Variable -Name 'Output' }
            If (Test-Path -LiteralPath 'variable:LogErrorMessage') { Clear-Variable -Name 'LogErrorMessage' }
            If (Test-Path -LiteralPath 'variable:LogInnerMessage') { Clear-Variable -Name 'LogInnerMessage' }
            If (Test-Path -LiteralPath 'variable:LogErrorMessageTmp') { Clear-Variable -Name 'LogErrorMessageTmp' }
        }
    }
    End {
    }
}
#endregion

#region Function Write-FunctionHeaderOrFooter
Function Write-FunctionHeaderOrFooter {
<#
.SYNOPSIS
    Write the function header or footer to the log upon first entering or exiting a function.
.DESCRIPTION
    Write the "Function Start" message, the bound parameters the function was invoked with, or the "Function End" message when entering or exiting a function.
    Messages are debug messages so will only be logged if LogDebugMessage option is enabled in XML config file.
.PARAMETER CmdletName
    The name of the function this function is invoked from.
.PARAMETER CmdletBoundParameters
    The bound parameters of the function this function is invoked from.
.PARAMETER Header
    Write the function header.
.PARAMETER Footer
    Write the function footer.
.EXAMPLE
    Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
.EXAMPLE
    Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://psappdeploytoolkit.com
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullorEmpty()]
        [string]$CmdletName,
        [Parameter(Mandatory = $true, ParameterSetName = 'Header')]
        [AllowEmptyCollection()]
        [hashtable]$CmdletBoundParameters,
        [Parameter(Mandatory = $true, ParameterSetName = 'Header')]
        [switch]$Header,
        [Parameter(Mandatory = $true, ParameterSetName = 'Footer')]
        [switch]$Footer
    )

    If ($Header) {
        Write-Log -Message 'Function Start' -Source ${CmdletName} -DebugMessage

        ## Get the parameters that the calling function was invoked with
        [string]$CmdletBoundParameters = $CmdletBoundParameters | Format-Table -Property @{ Label = 'Parameter'; Expression = { "[-$($_.Key)]" } }, @{ Label = 'Value'; Expression = { $_.Value }; Alignment = 'Left' } -AutoSize -Wrap | Out-String
        If ($CmdletBoundParameters) {
            Write-Log -Message "Function invoked with bound parameter(s): `n$CmdletBoundParameters" -Source ${CmdletName} -DebugMessage
        }
        Else {
            Write-Log -Message 'Function invoked without any bound parameters.' -Source ${CmdletName} -DebugMessage
        }
    }
    ElseIf ($Footer) {
        Write-Log -Message 'Function End' -Source ${CmdletName} -DebugMessage
    }
}
#endregion

#region Function Write-Log
Function Write-Log {
<#
.SYNOPSIS
    Write messages to a log file in CMTrace.exe compatible format or Legacy text file format.
.DESCRIPTION
    Write messages to a log file in CMTrace.exe compatible format or Legacy text file format and optionally display in the console.
.PARAMETER Message
    The message to write to the log file or output to the console.
.PARAMETER Severity
    Defines message type. When writing to console or CMTrace.exe log format, it allows highlighting of message type.
    Options: 1 = Information (default), 2 = Warning (highlighted in yellow), 3 = Error (highlighted in red)
.PARAMETER Source
    The source of the message being logged.
.PARAMETER ScriptSection
    The heading for the portion of the script that is being executed. Default is: $script:installPhase.
.PARAMETER LogType
    Choose whether to write a CMTrace.exe compatible log file or a Legacy text log file.
.PARAMETER LogFileDirectory
    Set the directory where the log file will be saved.
    Default is %WINDIR%\Logs\WmiToolkit.
.PARAMETER LogFileName
    Set the name of the log file.
.PARAMETER MaxLogFileSizeMB
    Maximum file size limit for log file in megabytes (MB). Default is 10 MB.
.PARAMETER WriteHost
    Write the log message to the console.
.PARAMETER ContinueOnError
    Suppress writing log message to console on failure to write message to log file. Default is: $true.
.PARAMETER PassThru
    Return the message that was passed to the function
.PARAMETER DebugMessage
    Specifies that the message is a debug message. Debug messages only get logged if -LogDebugMessage is set to $true.
.PARAMETER LogDebugMessage
    Debug messages only get logged if this parameter is set to $true in the config XML file.
.EXAMPLE
    Write-Log -Message "Installing patch MS15-031" -Source 'Add-Patch' -LogType 'CMTrace'
.EXAMPLE
    Write-Log -Message "Script is running on Windows 8" -Source 'Test-ValidOS' -LogType 'Legacy'
.NOTES
.LINK
    https://psappdeploytoolkit.com
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [AllowEmptyCollection()]
        [Alias('Text')]
        [string[]]$Message,
        [Parameter(Mandatory = $false, Position = 1)]
        [ValidateRange(1, 3)]
        [int16]$Severity = 1,
        [Parameter(Mandatory = $false, Position = 2)]
        [ValidateNotNull()]
        [string]$Source = '',
        [Parameter(Mandatory = $false, Position = 3)]
        [ValidateNotNullorEmpty()]
        [string]$ScriptSection = 'Module',
        [Parameter(Mandatory = $false, Position = 4)]
        [ValidateSet('CMTrace', 'Legacy')]
        [string]$LogType = 'Legacy',
        [Parameter(Mandatory = $false, Position = 5)]
        [ValidateNotNullorEmpty()]
        [string]$LogFileDirectory = $(Join-Path -Path $Env:windir -ChildPath '\Logs\PSWmiToolKit'),
        [Parameter(Mandatory = $false, Position = 6)]
        [ValidateNotNullorEmpty()]
        [string]$LogFileName = 'PSWmiToolKit.log',
        [Parameter(Mandatory = $false, Position = 7)]
        [ValidateNotNullorEmpty()]
        [decimal]$MaxLogFileSizeMB = '5',
        [Parameter(Mandatory = $false, Position = 8)]
        [ValidateNotNullorEmpty()]
        [boolean]$WriteHost = $true,
        [Parameter(Mandatory = $false, Position = 9)]
        [ValidateNotNullorEmpty()]
        [boolean]$ContinueOnError = $true,
        [Parameter(Mandatory = $false, Position = 10)]
        [switch]$PassThru = $false,
        [Parameter(Mandatory = $false, Position = 11)]
        [switch]$DebugMessage = $false,
        [Parameter(Mandatory = $false, Position = 12)]
        [boolean]$LogDebugMessage = $false
    )

    Begin {
        ## Get the name of this function
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

        ## Logging Variables
        #  Log file date/time
        [string]$LogTime = (Get-Date -Format 'HH:mm:ss.fff').ToString()
        [string]$LogDate = (Get-Date -Format 'MM-dd-yyyy').ToString()
        If (-not (Test-Path -LiteralPath 'variable:LogTimeZoneBias')) { [int32]$script:LogTimeZoneBias = [timezone]::CurrentTimeZone.GetUtcOffset([datetime]::Now).TotalMinutes }
        [string]$LogTimePlusBias = $LogTime + $script:LogTimeZoneBias
        #  Initialize variables
        [boolean]$ExitLoggingFunction = $false
        If (-not (Test-Path -LiteralPath 'variable:DisableLogging')) { $DisableLogging = $false }
        #  Check if the script section is defined
        [boolean]$ScriptSectionDefined = [boolean](-not [string]::IsNullOrEmpty($ScriptSection))
        #  Get the file name of the source script
        Try {
            If ($script:MyInvocation.Value.ScriptName) {
                [string]$ScriptSource = Split-Path -Path $script:MyInvocation.Value.ScriptName -Leaf -ErrorAction 'Stop'
            }
            Else {
                [string]$ScriptSource = Split-Path -Path $script:MyInvocation.MyCommand.Definition -Leaf -ErrorAction 'Stop'
            }
        }
        Catch {
            $ScriptSource = ''
        }

        ## Create script block for generating CMTrace.exe compatible log entry
        [scriptblock]$CMTraceLogString = {
            Param (
                [string]$lMessage,
                [string]$lSource,
                [int16]$lSeverity
            )
            "<![LOG[$lMessage]LOG]!>" + "<time=`"$LogTimePlusBias`" " + "date=`"$LogDate`" " + "component=`"$lSource`" " + "context=`"$([Security.Principal.WindowsIdentity]::GetCurrent().Name)`" " + "type=`"$lSeverity`" " + "thread=`"$PID`" " + "file=`"$ScriptSource`">"
        }

        ## Create script block for writing log entry to the console
        [scriptblock]$WriteLogLineToHost = {
            Param (
                [string]$lTextLogLine,
                [int16]$lSeverity
            )
            If ($WriteHost) {
                #  Only output using color options if running in a host which supports colors.
                If ($Host.UI.RawUI.ForegroundColor) {
                    Switch ($lSeverity) {
                        3 { Write-Host -Object $lTextLogLine -ForegroundColor 'Red' -BackgroundColor 'Black' }
                        2 { Write-Host -Object $lTextLogLine -ForegroundColor 'Yellow' -BackgroundColor 'Black' }
                        1 { Write-Host -Object $lTextLogLine }
                    }
                }
                #  If executing "powershell.exe -File <filename>.ps1 > log.txt", then all the Write-Host calls are converted to Write-Output calls so that they are included in the text log.
                Else {
                    Write-Output -InputObject $lTextLogLine
                }
            }
        }

        ## Exit function if it is a debug message and logging debug messages is not enabled in the config XML file
        If (($DebugMessage) -and (-not $LogDebugMessage)) { [boolean]$ExitLoggingFunction = $true; Return }
        ## Exit function if logging to file is disabled and logging to console host is disabled
        If (($DisableLogging) -and (-not $WriteHost)) { [boolean]$ExitLoggingFunction = $true; Return }
        ## Exit Begin block if logging is disabled
        If ($DisableLogging) { Return }
        ## Exit function function if it is an [Initialization] message and the toolkit has been relaunched
        If ($ScriptSection -eq 'Initialization') { [boolean]$ExitLoggingFunction = $true; Return }

        ## Create the directory where the log file will be saved
        If (-not (Test-Path -LiteralPath $LogFileDirectory -PathType 'Container')) {
            Try {
                $null = New-Item -Path $LogFileDirectory -Type 'Directory' -Force -ErrorAction 'Stop'
            }
            Catch {
                [boolean]$ExitLoggingFunction = $true
                #  If error creating directory, write message to console
                If (-not $ContinueOnError) {
                    Write-Host -Object "[$LogDate $LogTime] [${CmdletName}] $ScriptSection :: Failed to create the log directory [$LogFileDirectory]. `n$(Resolve-Error)" -ForegroundColor 'Red'
                }
                Return
            }
        }

        ## Assemble the fully qualified path to the log file
        [string]$LogFilePath = Join-Path -Path $LogFileDirectory -ChildPath $LogFileName
    }
    Process {
        ## Exit function if logging is disabled
        If ($ExitLoggingFunction) { Return }

        ForEach ($Msg in $Message) {
            ## If the message is not $null or empty, create the log entry for the different logging methods
            [string]$CMTraceMsg = ''
            [string]$ConsoleLogLine = ''
            [string]$LegacyTextLogLine = ''
            If ($Msg) {
                #  Create the CMTrace log message
                If ($ScriptSectionDefined) { [string]$CMTraceMsg = "[$ScriptSection] :: $Msg" }

                #  Create a Console and Legacy "text" log entry
                [string]$LegacyMsg = "[$LogDate $LogTime]"
                If ($ScriptSectionDefined) { [string]$LegacyMsg += " [$ScriptSection]" }
                If ($Source) {
                    [string]$ConsoleLogLine = "$LegacyMsg [$Source] :: $Msg"
                    Switch ($Severity) {
                        3 { [string]$LegacyTextLogLine = "$LegacyMsg [$Source] [Error] :: $Msg" }
                        2 { [string]$LegacyTextLogLine = "$LegacyMsg [$Source] [Warning] :: $Msg" }
                        1 { [string]$LegacyTextLogLine = "$LegacyMsg [$Source] [Info] :: $Msg" }
                    }
                }
                Else {
                    [string]$ConsoleLogLine = "$LegacyMsg :: $Msg"
                    Switch ($Severity) {
                        3 { [string]$LegacyTextLogLine = "$LegacyMsg [Error] :: $Msg" }
                        2 { [string]$LegacyTextLogLine = "$LegacyMsg [Warning] :: $Msg" }
                        1 { [string]$LegacyTextLogLine = "$LegacyMsg [Info] :: $Msg" }
                    }
                }
            }

            ## Execute script block to create the CMTrace.exe compatible log entry
            [string]$CMTraceLogLine = & $CMTraceLogString -lMessage $CMTraceMsg -lSource $Source -lSeverity $Severity

            ## Choose which log type to write to file
            If ($LogType -ieq 'CMTrace') {
                [string]$LogLine = $CMTraceLogLine
            }
            Else {
                [string]$LogLine = $LegacyTextLogLine
            }

            ## Write the log entry to the log file if logging is not currently disabled
            If (-not $DisableLogging) {
                Try {
                    $LogLine | Out-File -FilePath $LogFilePath -Append -NoClobber -Force -Encoding 'UTF8' -ErrorAction 'Stop'
                }
                Catch {
                    If (-not $ContinueOnError) {
                        Write-Host -Object "[$LogDate $LogTime] [$ScriptSection] [${CmdletName}] :: Failed to write message [$Msg] to the log file [$LogFilePath]. `n$(Resolve-Error)" -ForegroundColor 'Red'
                    }
                }
            }

            ## Execute script block to write the log entry to the console if $WriteHost is $true
            & $WriteLogLineToHost -lTextLogLine $ConsoleLogLine -lSeverity $Severity
        }
    }
    End {
        ## Archive log file if size is greater than $MaxLogFileSizeMB and $MaxLogFileSizeMB > 0
        Try {
            If ((-not $ExitLoggingFunction) -and (-not $DisableLogging)) {
                [IO.FileInfo]$LogFile = Get-ChildItem -LiteralPath $LogFilePath -ErrorAction 'Stop'
                [decimal]$LogFileSizeMB = $LogFile.Length / 1MB
                If (($LogFileSizeMB -gt $MaxLogFileSizeMB) -and ($MaxLogFileSizeMB -gt 0)) {
                    ## Change the file extension to "lo_"
                    [string]$ArchivedOutLogFile = [IO.Path]::ChangeExtension($LogFilePath, 'lo_')
                    [hashtable]$ArchiveLogParams = @{ ScriptSection = $ScriptSection; Source = ${CmdletName}; Severity = 2; LogFileDirectory = $LogFileDirectory; LogFileName = $LogFileName; LogType = $LogType; MaxLogFileSizeMB = 0; WriteHost = $WriteHost; ContinueOnError = $ContinueOnError; PassThru = $false }

                    ## Log message about archiving the log file
                    $ArchiveLogMessage = "Maximum log file size [$MaxLogFileSizeMB MB] reached. Rename log file to [$ArchivedOutLogFile]."
                    Write-Log -Message $ArchiveLogMessage @ArchiveLogParams

                    ## Archive existing log file from <filename>.log to <filename>.lo_. Overwrites any existing <filename>.lo_ file. This is the same method SCCM uses for log files.
                    Move-Item -LiteralPath $LogFilePath -Destination $ArchivedOutLogFile -Force -ErrorAction 'Stop'

                    ## Start new log file and Log message about archiving the old log file
                    $NewLogMessage = "Previous log file was renamed to [$ArchivedOutLogFile] because maximum log file size of [$MaxLogFileSizeMB MB] was reached."
                    Write-Log -Message $NewLogMessage @ArchiveLogParams
                }
            }
        }
        Catch {
            ## If renaming of file fails, script will continue writing to log file even if size goes over the max file size
        }
        Finally {
            If ($PassThru) { Write-Output -InputObject $Message }
        }
    }
}
#endregion

#region Function Get-WmiClass
Function Get-WmiClass {
<#
.SYNOPSIS
    This function is used to get WMI class details.
.DESCRIPTION
    This function is used to get the details of one or more WMI classes.
.PARAMETER Namespace
    Specifies the namespace where to search for the WMI class. Default is: 'ROOT\cimv2'.
.PARAMETER ClassName
    Specifies the class name to search for. Supports wildcards. Default is: '*'.
.PARAMETER QualifierName
    Specifies the qualifier name to search for.(Optional)
.PARAMETER IncludeSpecialClasses
    Specifies to include System, MSFT and CIM classes. Use this or Get operations only.
.EXAMPLE
    Get-WmiClass -Namespace 'ROOT\SCCM' -ClassName 'SCCMZone'
.EXAMPLE
    Get-WmiClass -Namespace 'ROOT\SCCM' -QualifierName 'Description'
.EXAMPLE
    Get-WmiClass -Namespace 'ROOT\SCCM'
.INPUTS
    None.
.OUTPUTS
    None.
.NOTES
    This is a module function and can typically be called directly.
.LINK
    https://MEM.Zone/PsWmiToolkit
.LINK
    https://MEM.Zone/PsWmiToolkit-GIT
.LINK
    https://MEM.Zone/PsWmiToolkit-ISSUES
.COMPONENT
    WMI
.FUNCTIONALITY
    WMI Management
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateNotNullorEmpty()]
        [string]$Namespace = 'ROOT\cimv2',
        [Parameter(Mandatory = $false, Position = 1)]
        [ValidateNotNullorEmpty()]
        [string]$ClassName = '*',
        [Parameter(Mandatory = $false, Position = 2)]
        [ValidateNotNullorEmpty()]
        [string]$QualifierName,
        [Parameter(Mandatory = $false, Position = 3)]
        [ValidateNotNullorEmpty()]
        [switch]$IncludeSpecialClasses
    )

    Begin {
        ## Get the name of this function and write header
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
    }
    Process {
        Try {

            ## Check if the namespace exists
            $NamespaceTest = Get-WmiNamespace -Namespace $Namespace -ErrorAction 'SilentlyContinue'
            If (-not $NamespaceTest) {
                $NamespaceNotFoundErr = "Namespace [$Namespace] not found."
                Write-Log -Message $NamespaceNotFoundErr -Severity 2 -Source ${CmdletName} -DebugMessage
                Write-Error -Message $NamespaceNotFoundErr -Category 'ObjectNotFound'
            }

            ## Get all class details
            If ($QualifierName) {
                $WmiClass = Get-CimClass -Namespace $Namespace -Class $ClassName -QualifierName $QualifierName -ErrorAction 'SilentlyContinue'
            }
            Else {
                $WmiClass = Get-CimClass -Namespace $Namespace -Class $ClassName -ErrorAction 'SilentlyContinue'
            }

            ## Filter class or classes details based on specified parameters
            If ($IncludeSpecialClasses) {
                $GetClass = $WmiClass
            }
            Else {
                $GetClass = $WmiClass | Where-Object { ($_.CimClassName -notmatch '__') -and ($_.CimClassName -notmatch 'CIM_') -and ($_.CimClassName -notmatch 'MSFT_') }
            }

            ## If no class is found, write debug message and optionally throw error if -ErrorAction 'Stop' is specified
            If (-not $GetClass) {
                $ClassNotFoundErr = "No class [$ClassName] found in namespace [$Namespace]."
                Write-Log -Message $ClassNotFoundErr -Severity 2 -Source ${CmdletName} -DebugMessage
                Write-Error -Message $ClassNotFoundErr -Category 'ObjectNotFound'
            }
        }
        Catch {
            Write-Log -Message "Failed to retrieve wmi class [$Namespace`:$ClassName]. `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
            Break
        }
        Finally {

            ## If we have anyting to return, add typename for formatting purposes, otherwise set the result to $null
            If ($GetClass) {
                $GetClass.PSObject.TypeNames.Insert(0, 'Get.WmiClass.Typename')
            }
            Else {
                $GetClass = $null
            }

            ## Return result
            Write-Output -InputObject $GetClass
        }
    }
    End {
        Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
    }
}
#endregion

#region Function Get-WmiProperty
Function Get-WmiProperty {
<#
.SYNOPSIS
    This function is used to get the properties of a WMI class.
.DESCRIPTION
    This function is used to get one or more properties of a WMI class.
.PARAMETER Namespace
    Specifies the namespace where to search for the WMI class. Default is: 'ROOT\cimv2'.
.PARAMETER ClassName
    Specifies the class name for which to get the properties.
.PARAMETER PropertyName
    Specifies the propery name to search for. Supports wildcards. Default is: '*'.
.PARAMETER PropertyValue
    Specifies the propery value or values to search for. Supports wildcards.(Optional)
.PARAMETER QualifierName
    Specifies the property qualifier name to match. Supports wildcards.(Optional)
.PARAMETER Property
    Matches property Name, Value and CimType. Can be piped. If this parameter is specified all other search parameters will be ignored.(Optional)
    Supported format:
        [PSCustomobject]@{
            'Name' = 'Website'
            'Value' = $null
            'CimType' = 'String'
        }
.EXAMPLE
    Get-WmiProperty -Namespace 'ROOT' -ClassName 'SCCMZone'
.EXAMPLE
    Get-WmiProperty -Namespace 'ROOT' -ClassName 'SCCMZone' -PropertyName 'WebsiteSite' -QualifierName 'key'
.EXAMPLE
    Get-WmiProperty -Namespace 'ROOT' -ClassName 'SCCMZone' -PropertyName '*Site'
.EXAMPLE
    $Property = [PSCustomobject]@{
        'Name' = 'Website'
        'Value' = $null
        'CimType' = 'String'
    }
    Get-WmiProperty -Namespace 'ROOT' -ClassName 'SCCMZone' -Property $Property
    $Property | Get-WmiProperty -Namespace 'ROOT' -ClassName 'SCCMZone'
.NOTES
    This is a module function and can typically be called directly.
.LINK
    https://MEM.Zone/PsWmiToolkit
.LINK
    https://MEM.Zone/PsWmiToolkit-GIT
.LINK
    https://MEM.Zone/PsWmiToolkit-ISSUES
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateNotNullorEmpty()]
        [string]$Namespace = 'ROOT\cimv2',
        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateNotNullorEmpty()]
        [string]$ClassName,
        [Parameter(Mandatory = $false, Position = 2)]
        [ValidateNotNullorEmpty()]
        [string]$PropertyName = '*',
        [Parameter(Mandatory = $false, Position = 3)]
        [ValidateNotNullorEmpty()]
        [string]$PropertyValue,
        [Parameter(Mandatory = $false, Position = 4)]
        [ValidateNotNullorEmpty()]
        [string]$QualifierName,
        [Parameter(Mandatory = $false, ValueFromPipeline, Position = 5)]
        [ValidateNotNullorEmpty()]
        [PSCustomObject]$Property = @()
    )

    Begin {
        ## Get the name of this function and write header
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
    }
    Process {
        Try {

            ## Check if class exists
            $ClassTest = Get-WmiClass -Namespace $Namespace -ClassName $ClassName -ErrorAction 'SilentlyContinue'

            ## If no class is found, write debug message and optionally throw error if -ErrorAction 'Stop' is specified
            If (-not $ClassTest) {
                $ClassNotFoundErr = "No class [$ClassName] found in namespace [$Namespace]."
                Write-Log -Message $ClassNotFoundErr -Severity 2 -Source ${CmdletName} -DebugMessage
                Write-Error -Message $ClassNotFoundErr -Category 'ObjectNotFound'
            }

            ## Get class properties
            $WmiProperty = (Get-WmiClass -Namespace $Namespace -ClassName $ClassName -ErrorAction 'SilentlyContinue' | Select-Object *).CimClassProperties | Where-Object -Property Name -Like $PropertyName

            ## Get class property based on specified parameters
            If ($Property) {

                #  Compare all specified properties and return only properties that match Name, Value and CimType.
                $GetProperty = Compare-Object -ReferenceObject $Property -DifferenceObject $WmiProperty -Property Name, Value, CimType -IncludeEqual -ExcludeDifferent -PassThru

            }
            ElseIf ($PropertyValue -and $QualifierName) {
                $GetProperty = $WmiProperty | Where-Object { ($_.Value -like $PropertyValue) -and ($_.Qualifiers.Name -like $QualifierName) }
            }
            ElseIf ($PropertyValue) {
                $GetProperty = $WmiProperty | Where-Object -Property Value -Like $PropertyValue
            }
            ElseIf ($QualifierName) {
                $GetProperty = $WmiProperty | Where-Object { $_.Qualifiers.Name -like $QualifierName }
            }
            Else {
                $GetProperty = $WmiProperty
            }

            ## If no matching properties are found, write debug message and optionally throw error if -ErrorAction 'Stop' is specified
            If (-not $GetProperty) {
                $PropertyNotFoundErr = "No property [$PropertyName] found for class [$Namespace`:$ClassName]."
                Write-Log -Message $PropertyNotFoundErr -Severity 2 -Source ${CmdletName} -DebugMessage
                Write-Error -Message $PropertyNotFoundErr -Category 'ObjectNotFound'
            }
        }
        Catch {
            Write-Log -Message "Failed to retrieve wmi class [$Namespace`:$ClassName] properties. `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
            Break
        }
        Finally {
            Write-Output -InputObject $GetProperty
        }
    }
    End {
        Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
    }
}
#endregion

#region Function Get-WmiNamespace
Function Get-WmiNamespace {
<#
.SYNOPSIS
    This function is used to get WMI namespace information.
.DESCRIPTION
    This function is used to get the details of one or more WMI namespaces.
.PARAMETER Namespace
    Specifies the namespace(s) path(s). Supports wildcards only when not using the -Recurse or -List switch. Can be piped.
.PARAMETER List
    This switch is used to list all namespaces in the specified path. Cannot be used in conjunction with the -Recurse switch.
.PARAMETER Recurse
    This switch is used to get the whole WMI namespace tree recursively. Cannot be used in conjunction with the -List switch.
.EXAMPLE
    C:\PS> Get-WmiNamespace -NameSpace 'ROOT\SCCM'
.EXAMPLE
    C:\PS> Get-WmiNamespace -NameSpace 'ROOT\*CM'
.EXAMPLE
    C:\PS> Get-WmiNamespace -NameSpace 'ROOT' -List
.EXAMPLE
    C:\PS> Get-WmiNamespace -NameSpace 'ROOT' -Recurse
.EXAMPLE
    C:\PS> 'Root\SCCM', 'Root\SC*' | Get-WmiNamespace
.INPUTS
    System.String[].
.OUTPUTS
    System.Management.Automation.PSCustomObject.
        'Name'
        'Path'
        'FullName'
.NOTES
    This is a public module function and can typically be called directly.
.LINK
    https://MEM.Zone/PsWmiToolkit
.LINK
    https://MEM.Zone/PsWmiToolkit-GIT
.LINK
    https://MEM.Zone/PsWmiToolkit-ISSUES
.COMPONENT
    WMI
.FUNCTIONALITY
    WMI Management
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [ValidateNotNullorEmpty()]
        [SupportsWildcards()]
        [string[]]$Namespace,
        [Parameter(Mandatory = $false, Position = 1)]
        [ValidateNotNullorEmpty()]
        [ValidateScript({
                If ($Namespace -match '\*') { Throw 'Wildcards are not supported with this switch.' }
                Return $true
            })]
        [switch]$List = $false,
        [Parameter(Mandatory = $false, Position = 2)]
        [ValidateNotNullorEmpty()]
        [ValidateScript({
                If ($Namespace -match '\*') { Throw 'Wildcards are not supported with this switch.' }
                Return $true
            })]
        [switch]$Recurse = $false
    )

    Begin {
        ## Get the name of this function and write header
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header

        ## Initialize result variable
        [PSCustomObject]$GetNamespace = $null
    }
    Process {
        Try {

            ## Get namespace tree recursively if specified, otherwise just get the current namespace
            If ($Recurse) {

                #  Call Get-WmiNamespaceRecursive internal function
                $GetNamespace = Get-WmiNamespaceRecursive -Namespace $Namespace -ErrorAction 'SilentlyContinue' | Sort-Object -Property Path
            }
            Else {

                ## If namespace is 'ROOT' or -List is specified get namespace else get Parent\Leaf namespace
                If ($List -or ($Namespace -eq 'ROOT')) {
                    $WmiNamespace = Get-CimInstance -Namespace $([string]$Namespace) -ClassName '__Namespace' -ErrorAction 'SilentlyContinue' -ErrorVariable Err
                }
                Else {
                    #  Set namespace path and name
                    [string]$NamespaceParent = $(Split-Path -Path $Namespace -Parent)
                    [string]$NamespaceLeaf = $(Split-Path -Path $Namespace -Leaf)
                    #  Get namespace
                    $WmiNamespace = Get-CimInstance -Namespace $NamespaceParent -ClassName '__Namespace' -ErrorAction 'SilentlyContinue' -ErrorVariable Err | Where-Object { $_.Name -like $NamespaceLeaf }
                }

                ## If no namespace is found, write debug message and optionally throw error is -ErrorAction 'Stop' is specified
                If (-not $WmiNamespace -and $List -and (-not $Err)) {
                    $NamespaceChildrenNotFoundErr = "Namespace [$Namespace] has no children."
                    Write-Log -Message $NamespaceChildrenNotFoundErr -Severity 2 -Source ${CmdletName} -DebugMessage
                    Write-Error -Message $NamespaceChildrenNotFoundErr -Category 'ObjectNotFound'
                }
                ElseIf (-not $WmiNamespace) {
                    $NamespaceNotFoundErr = "Namespace [$Namespace] not found."
                    Write-Log -Message $NamespaceNotFoundErr -Severity 2 -Source ${CmdletName} -DebugMessage
                    Write-Error -Message $NamespaceNotFoundErr -Category 'ObjectNotFound'
                }
                ElseIf (-not $Err) {
                    $GetNamespace = $WmiNamespace | ForEach-Object {
                        [PSCustomObject]@{
                            Name     = $Name = $_.Name
                            #  Standardize namespace path separator by changing it from '/' to '\'.
                            Path     = $Path = $_.CimSystemProperties.Namespace -replace ('/', '\')
                            FullName = "$Path`\$Name"
                        }
                    }
                }
            }
        }
        Catch {
            Write-Log -Message "Failed to retrieve wmi namespace [$Namespace]. `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
            Break
        }
        Finally {

            ## If we have anyting to return, add typename for formatting purposes, otherwise set the result to $null
            If ($GetNamespace) {
                $GetNamespace.PSObject.TypeNames.Insert(0, 'Get.WmiNamespace.Typename')
            }
            Else {
                $GetNamespace = $null
            }

            ## Return result
            Write-Output -InputObject $GetNamespace
        }
    }
    End {
        Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
    }
}
#endregion

#region Function Get-WmiNamespaceRecursive
Function Get-WmiNamespaceRecursive {
<#
.SYNOPSIS
    This function is used to get wmi namespaces recursively.
.DESCRIPTION
    This function is used to get wmi namespaces recursively and returns a custom object.
.PARAMETER Namespace
    Specifies the root namespace(s) path(s) to search. Cand be piped.
.EXAMPLE
    C:\PS> $Result = Get-WmiNamespaceRecursive -NameSpace 'ROOT\SCCM'
.EXAMPLE
    C:\PS> $Result = 'ROOT\SCCM', 'ROOT\Appv' | Get-WmiNamespaceRecursive
.INPUTS
    System.String[].
.OUTPUTS
    System.Management.Automation.PSCustomObject.
        'Name'
        'Path'
        'FullName'
.NOTES
    As this is a recursive function it will run multiple times so you might want to assign it to a variable for sorting.
    You also might want to disable logging when running this function.

    This is an internal module function and should not typically be called directly.
.LINK
    https://MEM.Zone/PsWmiToolkit
.LINK
    https://MEM.Zone/PsWmiToolkit-GIT
.LINK
    https://MEM.Zone/PsWmiToolkit-ISSUES
.COMPONENT
    WMI
.FUNCTIONALITY
    WMI Management
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, ValueFromPipeline, Position = 0)]
        [ValidateNotNullorEmpty()]
        [string[]]$Namespace
    )

    Begin {
        ## Initialize/Reset result object
        [PSCustomObject]$GetNamespaceRecursive = @()
    }
    Process {
        Try {

            ## Get all namespaces in the current root namespace
            $Namespaces = Get-WmiNamespace -Namespace $Namespace -List

            ## Search in the current namespace for other namespaces
            If ($Namespaces) {
                $Namespaces | ForEach-Object {
                    #  Assemble the result object
                    $GetNamespaceRecursive += [PsCustomObject]@{
                        Name     = $_.Name
                        Path     = $_.Path
                        FullName = $_.FullName
                    }

                    #  Call the function again for the next namespace
                    Get-WmiNamespaceRecursive -Namespace $_.FullName
                }
            }
        }
        Catch {
            Write-Log -Message "Failed to retrieve wmi namespace [$Namespace] recursively. `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
            Break
        }
    }
    End {
        Write-Output -InputObject $GetNamespaceRecursive
    }
}
#endregion

#region Function New-WmiClass
Function New-WmiClass {
<#
.SYNOPSIS
    This function is used to create a WMI class.
.DESCRIPTION
    This function is used to create a WMI class with custom properties.
.PARAMETER Namespace
    Specifies the namespace where to search for the WMI namespace. Default is: 'ROOT\cimv2'.
.PARAMETER ClassName
    Specifies the name for the new class.
.PARAMETER Qualifiers
    Specifies one ore more property qualifiers using qualifier name and value only. You can omit this parameter or enter one or more items in the hashtable.
    You can also specify a string but you must separate the name and value with a new line character (`n). This parameter can also be piped.
    The qualifiers will be added with these default values and flavors:
        Static = $true
        IsAmended = $false
        PropagatesToInstance = $true
        PropagatesToSubClass = $false
        IsOverridable = $true
.PARAMETER CreateDestination
    This switch is used to create destination namespace.
.EXAMPLE
    [hashtable]$Qualifiers = @{
        Key = $true
        Static = $true
        Description = 'SCCMZone Blog'
    }
    New-WmiClass -Namespace 'ROOT' -ClassName 'SCCMZone' -Qualifiers $Qualifiers
.EXAMPLE
    "Key = $true `n Static = $true `n Description = SCCMZone Blog" | New-WmiClass -Namespace 'ROOT' -ClassName 'SCCMZone'
.EXAMPLE
    New-WmiClass -Namespace 'ROOT\SCCM' -ClassName 'SCCMZone' -CreateDestination
.NOTES
    This is a module function and can typically be called directly.
.LINK
    https://MEM.Zone/PsWmiToolkit
.LINK
    https://MEM.Zone/PsWmiToolkit-GIT
.LINK
    https://MEM.Zone/PsWmiToolkit-ISSUES
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateNotNullorEmpty()]
        [string]$Namespace = 'ROOT\cimv2',
        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateNotNullorEmpty()]
        [string]$ClassName,
        [Parameter(Mandatory = $false, ValueFromPipeline, Position = 2)]
        [ValidateNotNullorEmpty()]
        [PSCustomObject]$Qualifiers = @("Static = $true"),
        [Parameter(Mandatory = $false, Position = 3)]
        [ValidateNotNullorEmpty()]
        [switch]$CreateDestination = $false
    )

    Begin {
        ## Get the name of this function and write header
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
    }
    Process {
        Try {

            ## Check if the class exists
            [boolean]$ClassTest = Get-WmiClass -Namespace $Namespace -ClassName $ClassName -ErrorAction 'SilentlyContinue'

            ## Check if the namespace exists
            [boolean]$NamespaceTest = Get-WmiNamespace -Namespace $Namespace -ErrorAction 'SilentlyContinue'

            ## Create destination namespace if specified, otherwise throw error if -ErrorAction 'Stop' is specified
            If ((-not $NamespaceTest) -and $CreateDestination) {
                $null = New-WmiNamespace $Namespace -CreateSubTree -ErrorAction 'Stop'
            }
            ElseIf (-not $NamespaceTest) {
                $NamespaceNotFoundErr = "Namespace [$Namespace] does not exist. Use the -CreateDestination switch to create namespace."
                Write-Log -Message $NamespaceNotFoundErr -Severity 3 -Source ${CmdletName}
                Write-Error -Message $NamespaceNotFoundErr -Category 'ObjectNotFound'
            }

            ## Create class if it does not exist
            If (-not $ClassTest) {

                #  Create class object
                [wmiclass]$ClassObject = New-Object -TypeName 'System.Management.ManagementClass' -ArgumentList @("\\.\$Namespace`:__CLASS", [String]::Empty, $null)
                $ClassObject.Name = $ClassName

                #  Write the class and dispose of the class object
                $NewClass = $ClassObject.Put()
                $ClassObject.Dispose()

                #  On class creation failure, write debug message and optionally throw error if -ErrorAction 'Stop' is specified
                If (-not $NewClass) {

                    #  Error handling and logging
                    $NewClassErr = "Failed to create class [$ClassName] in namespace [$Namespace]."
                    Write-Log -Message $NewClassErr -Severity 3 -Source ${CmdletName} -DebugMessage
                    Write-Error -Message $NewClassErr -Category 'InvalidResult'
                }

                ## If input qualifier is not a hashtable convert string input to hashtable
                If ($Qualifiers -isnot [hashtable]) {
                    $Qualifiers = $Qualifiers | ConvertFrom-StringData
                }

                ## Set property qualifiers one by one if specified, otherwise set default qualifier name, value and flavors
                If ($Qualifiers) {
                    #  Convert to a hashtable format accepted by Set-WmiClassQualifier. Name = QualifierName and Value = QualifierValue are expected.
                    $Qualifiers.Keys | ForEach-Object {
                        [hashtable]$PropertyQualifier = @{ Name = $_; Value = $Qualifiers.Item($_) }
                        #  Set qualifier
                        $null = Set-WmiClassQualifier -Namespace $Namespace -ClassName $ClassName -Qualifier $PropertyQualifier -ErrorAction 'Stop'
                    }
                }
                Else {
                    $null = Set-WmiClassQualifier -Namespace $Namespace -ClassName $ClassName -ErrorAction 'Stop'
                }
            }
            Else {
                $ClassAlreadyExistsErr = "Failed to create class [$Namespace`:$ClassName]. Class already exists."
                Write-Log -Message $ClassAlreadyExistsErr -Severity 2 -Source ${CmdletName} -DebugMessage
                Write-Error -Message $ClassAlreadyExistsErr -Category 'ResourceExists'
            }
        }
        Catch {
            Write-Log -Message "Failed to create class [$ClassName] in namespace [$Namespace]. `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
            Break
        }
        Finally {
            Write-Output -InputObject $NewClass
        }
    }
    End {
        Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
    }
}
#endregion

#region Function New-WmiInstance
Function New-WmiInstance {
<#
.SYNOPSIS
    This function is used to create a WMI Instance.
.DESCRIPTION
    This function is used to create a WMI Instance using CIM.
.PARAMETER Namespace
    Specifies the namespace where to search for the WMI class. Default is: 'ROOT\cimv2'.
.PARAMETER ClassName
    Specifies the class where to create the new WMI instance.
.PARAMETER Key
    Specifies properties that are used as keys (Optional).
.PARAMETER Property
    Specifies the class instance Properties or Values. You can also specify a string but you must separate the name and value with a new line character (`n).
    This parameter can also be piped.
.EXAMPLE
    [hashtable]$Property = @{
        'ServerPort' = '89'
        'ServerIP' = '11.11.11.11'
        'Source' = 'File1'
        'Date' = $(Get-Date)
    }
    New-WmiInstance -Namespace 'ROOT' -ClassName 'SCCMZone' -Key 'File1' -Property $Property
.EXAMPLE
    "Server Port = 89 `n ServerIp = 11.11.11.11 `n Source = File `n Date = $(GetDate)" | New-WmiInstance -Namespace 'ROOT' -ClassName 'SCCMZone' -Property $Property
.NOTES
    This is a module function and can typically be called directly.
.LINK
    https://MEM.Zone/PsWmiToolkit
.LINK
    https://MEM.Zone/PsWmiToolkit-GIT
.LINK
    https://MEM.Zone/PsWmiToolkit-ISSUES
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateNotNullorEmpty()]
        [string]$Namespace = 'ROOT\cimv2',
        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateNotNullorEmpty()]
        [string]$ClassName,
        [Parameter(Mandatory = $false, Position = 2)]
        [ValidateNotNullorEmpty()]
        [string[]]$Key,
        [Parameter(Mandatory = $true, ValueFromPipeline, Position = 3)]
        [ValidateNotNullorEmpty()]
        [PSCustomObject]$Property
    )

    Begin {
        ## Get the name of this function and write header
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
    }
    Process {
        Try {

            ## Check if class exists
            $null = Get-WmiClass -Namespace $Namespace -ClassName $ClassName -ErrorAction 'Stop'

            ## If input qualifier is not a hashtable convert string input to hashtable
            If ($Property -isnot [hashtable]) {
                $Property = $Property | ConvertFrom-StringData
            }

            ## Create instance
            If ($Key) {
                $NewInstance = New-CimInstance -Namespace $Namespace -ClassName $ClassName -Key $Key -Property $Property
            }
            Else {
                $NewInstance = New-CimInstance -Namespace $Namespace -ClassName $ClassName -Property $Property
            }

            ## On instance creation failure, write debug message and optionally throw error if -ErrorAction 'Stop' is specified
            If (-not $NewInstance) {
                Write-Log -Message "Failed to create instance in class [$Namespace`:$ClassName]. `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName} -DebugMessage
            }
        }
        Catch {
            Write-Log -Message "Failed to create instance in class [$Namespace`:$ClassName]. `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
            Break
        }
        Finally {
            Write-Output -InputObject $NewInstance
        }
    }
    End {
        Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
    }
}
#endregion

#region Function New-WmiNamespace
Function New-WmiNamespace {
<#
.SYNOPSIS
    This function is used to create a new WMI namespace.
.DESCRIPTION
    This function is used to create a new WMI namespace.
.PARAMETER Namespace
    Specifies the namespace to create.
.PARAMETER CreateSubTree
    This swith is used to create the whole namespace sub tree if it does not exist.
.EXAMPLE
    New-WmiNamespace -Namespace 'ROOT\SCCM'
.EXAMPLE
    New-WmiNamespace -Namespace 'ROOT\SCCM\SCCMZone\Blog' -CreateSubTree
.NOTES
    This is a module function and can typically be called directly.
.LINK
    https://MEM.Zone/PsWmiToolkit
.LINK
    https://MEM.Zone/PsWmiToolkit-GIT
.LINK
    https://MEM.Zone/PsWmiToolkit-ISSUES
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullorEmpty()]
        [string]$Namespace,
        [Parameter(Mandatory = $false, Position = 1)]
        [ValidateNotNullorEmpty()]
        [switch]$CreateSubTree = $false
    )

    Begin {
        ## Get the name of this function and write header
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
    }
    Process {
        Try {

            ## Check if the namespace exists
            $WmiNamespace = Get-WmiNamespace -Namespace $Namespace -ErrorAction 'SilentlyContinue'

            ## Create Namespace if it does not exist
            If (-not $WmiNamespace) {

                #  Split path into it's components
                $NamespacePaths = $Namespace.Split('\')

                #  Assigning root namespace, just for show, should always be 'ROOT'
                [string]$Path = $NamespacePaths[0]

                #  Initialize NamespacePathsObject
                [PSCustomObject]$NamespacePathsObject = @()

                #  Parsing path components and assemle individual paths
                For ($i = 1; $i -le $($NamespacePaths.Length - 1); $i++ ) {
                    $Path += '\' + $NamespacePaths[$i]

                    #  Assembing path props and add them to the NamspacePathsObject
                    $PathProps = [ordered]@{ Name = $(Split-Path -Path $Path) ; Value = $(Split-Path -Path $Path -Leaf) }
                    $NamespacePathsObject += $PathProps
                }

                #  Split path into it's components
                $NamespacePaths = $Namespace.Split('\')

                #  Assigning root namespace, just for show, should always be 'ROOT'
                [string]$Path = $NamespacePaths[0]

                #  Initialize NamespacePathsObject
                [PSCustomObject]$NamespacePathsObject = @()

                #  Parsing path components and assemle individual paths
                For ($i = 1; $i -le $($NamespacePaths.Length - 1); $i++ ) {
                    $Path += '\' + $NamespacePaths[$i]

                    #  Assembing path props and add them to the NamspacePathsObject
                    $PathProps = [ordered]@{
                        'NamespacePath' = $(Split-Path -Path $Path)
                        'NamespaceName' = $(Split-Path -Path $Path -Leaf)
                        'NamespaceTest' = [boolean]$(Get-WmiNamespace -Namespace $Path -ErrorAction 'SilentlyContinue')
                    }
                    $NamespacePathsObject += [PSCustomObject]$PathProps
                }

                #  If the path does not contain missing subnamespaces or the -CreateSubTree switch is specified create namespace or namespaces
                If ((($NamespacePathsObject -match $false).Count -eq 1 ) -or $CreateSubTree) {

                    #  Create each namespace in path one by one
                    $NamespacePathsObject | ForEach-Object {

                        #  Check if we need to create the namespace
                        If (-not $_.NamespaceTest) {
                            #  Create namespace object and assign namespace name
                            $NameSpaceObject = (New-Object -TypeName 'System.Management.ManagementClass' -ArgumentList "\\.\$($_.NameSpacePath)`:__NAMESPACE").CreateInstance()
                            $NameSpaceObject.Name = $_.NamespaceName

                            #  Write the namespace object
                            $NewNamespace = $NameSpaceObject.Put()
                            $NameSpaceObject.Dispose()
                        }
                        Else {
                            Write-Log -Message "Namespace [$($_.NamespacePath)`\$($_.NamespaceName)] already exists." -Severity 2 -Source ${CmdletName} -DebugMessage
                        }
                    }

                    #  On namespace creation failure, write debug message and optionally throw error if -ErrorAction 'Stop' is specified
                    If (-not $NewNamespace) {
                        $CreateNamespaceErr = "Failed to create namespace [$($_.NameSpacePath)`\$($_.NamespaceName)]."
                        Write-Log -Message $CreateNamespaceErr -Severity 3 -Source ${CmdletName} -DebugMessage
                        Write-Error -Message $CreateNamespaceErr -Category 'InvalidResult'
                    }
                }
                ElseIf (($($NamespacePathsObject -match $false).Count -gt 1)) {
                    $SubNamespaceFoundErr = "Child namespace detected in namespace path [$Namespace]. Use the -CreateSubtree switch to create the whole path."
                    Write-Log -Message $SubNamespaceFoundErr -Severity 2 -Source ${CmdletName} -DebugMessage
                    Write-Error -Message $SubNamespaceFoundErr -Category 'InvalidOperation'
                }
            }
            Else {
                $NamespaceAlreadyExistsErr = "Failed to create namespace. [$Namespace] already exists."
                Write-Log -Message $NamespaceAlreadyExistsErr -Severity 2 -Source ${CmdletName} -DebugMessage
                Write-Error -Message $NamespaceAlreadyExistsErr -Category 'ResourceExists'
            }
        }
        Catch {
            Write-Log -Message "Failed to create namespace [$Namespace]. `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
            Break
        }
        Finally {
            Write-Output -InputObject $NewNamespace
        }
    }
    End {
        Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
    }
}
#endregion

#region Function New-WmiProperty
Function New-WmiProperty {
<#
.SYNOPSIS
    This function is used to add properties to a WMI class.
.DESCRIPTION
    This function is used to add custom properties to a WMI class.
.PARAMETER Namespace
    Specifies the namespace where to search for the WMI namespace. Default is: 'ROOT\cimv2'.
.PARAMETER ClassName
    Specifies the class name for which to add the properties.
.PARAMETER PropertyName
    Specifies the property name.
.PARAMETER PropertyType
    Specifies the property type.
.PARAMETER Qualifiers
    Specifies one ore more property qualifiers using qualifier name and value only. You can omit this parameter or enter one or more items in the hashtable.
    You can also specify a string but you must separate the name and value with a new line character (`n). This parameter can also be piped.
    The qualifiers will be added with these default flavors:
        IsAmended = $false
        PropagatesToInstance = $true
        PropagatesToSubClass = $false
        IsOverridable = $true
.PARAMETER Key
    Specifies if the property is key. Default is: false.(Optional)
.EXAMPLE
    [hashtable]$Qualifiers = @{
        Key = $true
        Static = $true
        Description = 'SCCMZone Blog'
    }
    New-WmiProperty -Namespace 'ROOT\SCCM' -ClassName 'SCCMZone' -PropertyName 'Website' -PropertyType 'String' -Qualifiers $Qualifiers
.EXAMPLE
    "Key = $true `n Description = SCCMZone Blog" | New-WmiProperty -Namespace 'ROOT\SCCM' -ClassName 'SCCMZone' -PropertyName 'Website' -PropertyType 'String'
.NOTES
    This is a module function and can typically be called directly.
.LINK
    https://MEM.Zone/PsWmiToolkit
.LINK
    https://MEM.Zone/PsWmiToolkit-GIT
.LINK
    https://MEM.Zone/PsWmiToolkit-ISSUES
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateNotNullorEmpty()]
        [string]$Namespace = 'ROOT\cimv2',
        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateNotNullorEmpty()]
        [string]$ClassName,
        [Parameter(Mandatory = $true, Position = 2)]
        [ValidateNotNullorEmpty()]
        [string]$PropertyName,
        [Parameter(Mandatory = $true, Position = 3)]
        [ValidateNotNullorEmpty()]
        [string]$PropertyType,
        [Parameter(Mandatory = $false, ValueFromPipeline, Position = 4)]
        [ValidateNotNullorEmpty()]
        [PSCustomObject]$Qualifiers = @()
    )

    Begin {
        ## Get the name of this function and write header
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
    }
    Process {
        Try {

            ## Check if the class exists
            $null = Get-WmiClass -Namespace $Namespace -ClassName $ClassName -ErrorAction 'Stop'

            ## Check if the property exist
            $WmiPropertyTest = Get-WmiProperty -Namespace $Namespace -ClassName $ClassName -PropertyName $PropertyName -ErrorAction 'SilentlyContinue'

            ## Create the property if it does not exist
            If (-not $WmiPropertyTest) {

                #  Set property to array if specified
                If ($PropertyType -match 'Array') {
                    $PropertyType = $PropertyType.Replace('Array', '')
                    $PropertyIsArray = $true
                }
                Else {
                    $PropertyIsArray = $false
                }

                #  Create the ManagementClass object
                [wmiclass]$ClassObject = New-Object -TypeName 'System.Management.ManagementClass' -ArgumentList @("\\.\$Namespace`:$ClassName")

                #  Add class property
                $ClassObject.Properties.Add($PropertyName, [System.Management.CimType]$PropertyType, $PropertyIsArray)

                #  Write class object
                $NewProperty = $ClassObject.Put()
                $ClassObject.Dispose()

                ## On property creation failure, write debug message and optionally throw error if -ErrorAction 'Stop' is specified
                If (-not $NewProperty) {

                    #  Error handling and logging
                    $NewPropertyErr = "Failed create property [$PropertyName] for Class [$Namespace`:$ClassName]."
                    Write-Log -Message $NewPropertyErr -Severity 3 -Source ${CmdletName} -DebugMessage
                    Write-Error -Message $NewPropertyErr -Category 'InvalidResult'
                }

                ## Set property qualifiers one by one if specified
                If ($Qualifiers) {
                    #  Convert to a hashtable format accepted by Set-WmiPropertyQualifier. Name = QualifierName and Value = QualifierValue are expected.
                    $Qualifiers.Keys | ForEach-Object {
                        [hashtable]$PropertyQualifier = @{ Name = $_; Value = $Qualifiers.Item($_) }
                        #  Set qualifier
                        $null = Set-WmiPropertyQualifier -Namespace $Namespace -ClassName $ClassName -PropertyName $PropertyName -Qualifier $PropertyQualifier -ErrorAction 'Stop'
                    }
                }
            }
            Else {
                $PropertyAlreadyExistsErr = "Property [$PropertyName] already present for class [$Namespace`:$ClassName]."
                Write-Log -Message $PropertyAlreadyExistsErr  -Severity 2 -Source ${CmdletName} -DebugMessage
                Write-Error -Message $PropertyAlreadyExistsErr -Category 'ResourceExists'
            }
        }
        Catch {
            Write-Log -Message "Failed to create property for class [$Namespace`:$ClassName]. `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
            Break
        }
        Finally {
            Write-Output -InputObject $NewProperty
        }
    }
    End {
        Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
    }
}
#endregion

#region Function Remove-WmiClass
Function Remove-WmiClass {
<#
.SYNOPSIS
    This function is used to remove a WMI class.
.DESCRIPTION
    This function is used to remove a WMI class by name.
.PARAMETER Namespace
    Specifies the namespace where to search for the WMI class. Default is: 'ROOT\cimv2'.
.PARAMETER ClassName
    Specifies the class name to remove. Can be piped.
.PARAMETER RemoveAll
    This switch is used to remove all namespace classes.
.EXAMPLE
    Remove-WmiClass -Namespace 'ROOT' -ClassName 'SCCMZone','SCCMZoneBlog'
.EXAMPLE
    'SCCMZone','SCCMZoneBlog' | Remove-WmiClass -Namespace 'ROOT'
.EXAMPLE
    Remove-WmiClass -Namespace 'ROOT' -RemoveAll
.NOTES
    This is a module function and can typically be called directly.
.LINK
    https://MEM.Zone/PsWmiToolkit
.LINK
    https://MEM.Zone/PsWmiToolkit-GIT
.LINK
    https://MEM.Zone/PsWmiToolkit-ISSUES
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateNotNullorEmpty()]
        [string]$Namespace = 'ROOT\cimv2',
        [Parameter(Mandatory = $false, ValueFromPipeline, Position = 1)]
        [ValidateNotNullorEmpty()]
        [string[]]$ClassName,
        [Parameter(Mandatory = $false, Position = 2)]
        [ValidateNotNullorEmpty()]
        [switch]$RemoveAll = $false
    )

    Begin {
        ## Get the name of this function and write header
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
    }
    Process {
        Try {

            ## Get classes names
            [string[]]$WmiClassNames = (Get-WmiClass -Namespace $Namespace -ErrorAction 'Stop').CimClassName

            ## Add classes to deletion string array depending on selected options
            If ($RemoveAll) {
                $ClassNamesToDelete = $WmiClassNames
            }
            ElseIf ($ClassName) {
                $ClassNamesToDelete = $WmiClassNames | Where-Object { $_ -in $ClassName }
            }
            Else {
                $ClassNameIsNullErr = "ClassName cannot be `$null if -RemoveAll is not specified."
                Write-Log -Message $ClassNameIsNullErr -Severity 3 -Source ${CmdletName}
                Write-Error -Message $ClassNameIsNullErr -Category 'InvalidArgument'
            }

            ## Remove classes
            If ($ClassNamesToDelete) {
                $ClassNamesToDelete | ForEach-Object {

                    #  Create the class object
                    [wmiclass]$ClassObject = New-Object -TypeName 'System.Management.ManagementClass' -ArgumentList @("\\.\$Namespace`:$_")

                    #  Remove class
                    $null = $ClassObject.Delete()
                    $ClassObject.Dispose()
                }
            }
            Else {
                $ClassNotFoundErr = "No matching class [$ClassName] found for namespace [$Namespace]."
                Write-Log -Message $ClassNotFoundErr -Severity 2 -Source ${CmdletName}
                Write-Error -Message $ClassNotFoundErr -Category 'ObjectNotFound'
            }
        }
        Catch {
            Write-Log -Message "Failed to remove class [$Namespace`:$ClassName]. `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
            Break
        }
        Finally {}
    }
    End {
        Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
    }
}
#endregion

#region Function Set-WmiClassQualifier
Function Set-WmiClassQualifier {
<#
.SYNOPSIS
    This function is used to set qualifiers to a WMI class.
.DESCRIPTION
    This function is used to set qualifiers to a WMI class. Existing qualifiers with the same name will be overwriten
.PARAMETER Namespace
    Specifies the namespace where to search for the WMI namespace. Default is: 'ROOT\cimv2'.
.PARAMETER ClassName
    Specifies the class name for which to add the qualifiers.
.PARAMETER Qualifier
    Specifies the qualifier name, value and flavours as hashtable. You can omit this parameter or enter one or more items in the hashtable.
    You can also specify a string but you must separate the name and value with a new line character (`n). This parameter can also be piped.
    If you omit a hashtable item the default item value will be used. Only item values can be specified (right of the '=' sign).
    Default is:
        [hashtable][ordered]@{
            Name = 'Static'
            Value = $true
            IsAmended = $false
            PropagatesToInstance = $true
            PropagatesToSubClass = $false
            IsOverridable = $true
        }
.EXAMPLE
    Set-WmiClassQualifier -Namespace 'ROOT' -ClassName 'SCCMZone' -Qualifier @{ Name = 'Description'; Value = 'SCCMZone Blog' }
.EXAMPLE
    Set-WmiClassQualifier -Namespace 'ROOT' -ClassName 'SCCMZone' -Qualifier "Name = Description `n Value = SCCMZone Blog"
.EXAMPLE
    "Name = Description `n Value = SCCMZone Blog" | Set-WmiClassQualifier -Namespace 'ROOT' -ClassName 'SCCMZone'
.NOTES
    This is a module function and can typically be called directly.
.LINK
    https://MEM.Zone/PsWmiToolkit
.LINK
    https://MEM.Zone/PsWmiToolkit-GIT
.LINK
    https://MEM.Zone/PsWmiToolkit-ISSUES
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateNotNullorEmpty()]
        [string]$Namespace = 'ROOT\cimv2',
        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateNotNullorEmpty()]
        [string]$ClassName,
        [Parameter(Mandatory = $false, ValueFromPipeline, Position = 2)]
        [ValidateNotNullorEmpty()]
        [PSCustomObject]$Qualifier = @()
    )

    Begin {
        ## Get the name of this function and write header
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
    }
    Process {
        Try {

            ## Check if the class exist
            $null = Get-WmiClass -Namespace $Namespace -ClassName $ClassName -ErrorAction 'Stop'

            ## If input qualifier is not a hashtable convert string input to hashtable
            If ($Qualifier -isnot [hashtable]) {
                $Qualifier = $Qualifier | ConvertFrom-StringData
            }

            ## Add the missing qualifier value, name and flavor to the hashtable using splatting
            If (-not $Qualifier.Item('Name')) { $Qualifier.Add('Name', 'Static') }
            If (-not $Qualifier.Item('Value')) { $Qualifier.Add('Value', $true) }
            If (-not $Qualifier.Item('IsAmended')) { $Qualifier.Add('IsAmended', $false) }
            If (-not $Qualifier.Item('PropagatesToInstance')) { $Qualifier.Add('PropagatesToInstance', $true) }
            If (-not $Qualifier.Item('PropagatesToSubClass')) { $Qualifier.Add('PropagatesToSubClass', $false) }
            If (-not $Qualifier.Item('IsOverridable')) { $Qualifier.Add('IsOverridable', $true) }

            ## Create the ManagementClass object
            [wmiclass]$ClassObject = New-Object -TypeName 'System.Management.ManagementClass' -ArgumentList @("\\.\$Namespace`:$ClassName")

            ## Set key qualifier if specified, otherwise set qualifier
            $ClassObject.Qualifiers.Add($Qualifier.Item('Name'), $Qualifier.Item('Value'), $Qualifier.Item('IsAmended'), $Qualifier.Item('PropagatesToInstance'), $Qualifier.Item('PropagatesToSubClass'), $Qualifier.Item('IsOverridable'))
            $SetClassQualifiers = $ClassObject.Put()
            $ClassObject.Dispose()

            ## On class qualifiers creation failure, write debug message and optionally throw error if -ErrorAction 'Stop' is specified
            If (-not $SetClassQualifiers) {

                #  Error handling and logging
                $SetClassQualifiersErr = "Failed to set qualifier [$Qualifier.Item('Name')] for class [$Namespace`:$ClassName]."
                Write-Log -Message $SetClassQualifiersErr -Severity 3 -Source ${CmdletName} -DebugMessage
                Write-Error -Message $SetClassQualifiersErr -Category 'InvalidResult'
            }
        }
        Catch {
            Write-Log -Message "Failed to set qualifier for class [$Namespace`:$ClassName]. `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
            Break
        }
        Finally {
            Write-Output -InputObject $SetClassQualifiers
        }
    }
    End {
        Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
    }
}
#endregion

#region Function Set-WmiPropertyQualifier
Function Set-WmiPropertyQualifier {
<#
.SYNOPSIS
    This function is used to set WMI property qualifier value.
.DESCRIPTION
    This function is used to set WMI property qualifier value to an existing WMI property.
.PARAMETER Namespace
    Specifies the namespace where to search for the WMI namespace. Default is: 'ROOT\cimv2'.
.PARAMETER ClassName
    Specifies the class name for which to add the properties.
.PARAMETER PropertyName
    Specifies the property name.
.PARAMETER Qualifier
    Specifies the qualifier name, value and flavours as hashtable. You can omit this parameter or enter one or more items in the hashtable.
    You can also specify a string but you must separate the name and value with a new line character (`n). This parameter can also be piped.
    If you omit a hashtable item the default item value will be used. Only item values can be specified (right of the '=' sign).
    Default is:
        [hashtable][ordered]@{
            Name = 'Static'
            Value = $true
            IsAmended = $false
            PropagatesToInstance = $true
            PropagatesToSubClass = $false
            IsOverridable = $true
        }
    Specifies if the property is key. Default is: $false.
.EXAMPLE
    Set-WmiPropertyQualifier -Namespace 'ROOT\SCCM' -ClassName 'SCCMZone' -Property 'WebSite' -Qualifier @{ Name = 'Description' ; Value = 'SCCMZone Blog' }
.EXAMPLE
    Set-WmiPropertyQualifier -Namespace 'ROOT\SCCM' -ClassName 'SCCMZone' -Property 'WebSite' -Qualifier "Name = Description `n Value = SCCMZone Blog"
.EXAMPLE
    "Name = Description `n Value = SCCMZone Blog" | Set-WmiPropertyQualifier -Namespace 'ROOT\SCCM' -ClassName 'SCCMZone' -Property 'WebSite'
.NOTES
    This is a module function and can typically be called directly.
.LINK
    https://MEM.Zone/PsWmiToolkit
.LINK
    https://MEM.Zone/PsWmiToolkit-GIT
.LINK
    https://MEM.Zone/PsWmiToolkit-ISSUES
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateNotNullorEmpty()]
        [string]$Namespace = 'ROOT\cimv2',
        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateNotNullorEmpty()]
        [string]$ClassName,
        [Parameter(Mandatory = $true, Position = 2)]
        [ValidateNotNullorEmpty()]
        [string]$PropertyName,
        [Parameter(Mandatory = $false, ValueFromPipeline, Position = 3)]
        [ValidateNotNullorEmpty()]
        [PSCustomObject]$Qualifier = @()
    )

    Begin {
        ## Get the name of this function and write header
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
    }
    Process {
        Try {

            ## Check if the property exists
            $null = Get-WmiProperty -Namespace $Namespace -ClassName $ClassName -PropertyName $PropertyName -ErrorAction 'Stop'

            ## If input qualifier is not a hashtable convert string input to hashtable
            If ($Qualifier -isnot [hashtable]) {
                $Qualifier = $Qualifier | ConvertFrom-StringData
            }

            ## Add the missing qualifier value, name and flavor to the hashtable using splatting
            If (-not $Qualifier.Item('Name')) { $Qualifier.Add('Name', 'Static') }
            If (-not $Qualifier.Item('Value')) { $Qualifier.Add('Value', $true) }
            If (-not $Qualifier.Item('IsAmended')) { $Qualifier.Add('IsAmended', $false) }
            If (-not $Qualifier.Item('PropagatesToInstance')) { $Qualifier.Add('PropagatesToInstance', $true) }
            If (-not $Qualifier.Item('PropagatesToSubClass')) { $Qualifier.Add('PropagatesToSubClass', $false) }
            If (-not $Qualifier.Item('IsOverridable')) { $Qualifier.Add('IsOverridable', $true) }

            ## Create the ManagementClass object
            [wmiclass]$ClassObject = New-Object -TypeName 'System.Management.ManagementClass' -ArgumentList @("\\.\$Namespace`:$ClassName")

            ## Set key qualifier if specified, otherwise set qualifier
            If ('key' -eq $Qualifier.Item('Name')) {
                $ClassObject.Properties[$PropertyName].Qualifiers.Add('Key', $true)
                $SetClassQualifiers = $ClassObject.Put()
                $ClassObject.Dispose()
            }
            Else {
                $ClassObject.Properties[$PropertyName].Qualifiers.Add($Qualifier.Item('Name'), $Qualifier.Item('Value'), $Qualifier.Item('IsAmended'), $Qualifier.Item('PropagatesToInstance'), $Qualifier.Item('PropagatesToSubClass'), $Qualifier.Item('IsOverridable'))
                $SetClassQualifiers = $ClassObject.Put()
                $ClassObject.Dispose()
            }

            ## On property qualifiers creation failure, write debug message and optionally throw error if -ErrorAction 'Stop' is specified
            If (-not $SetClassQualifiers) {

                #  Error handling and logging
                $SetClassQualifiersErr = "Failed to set qualifier [$Qualifier.Item('Name')] for property [$Namespace`:$ClassName($PropertyName)]."
                Write-Log -Message $SetClassQualifiersErr -Severity 3 -Source ${CmdletName} -DebugMessage
                Write-Error -Message $SetClassQualifiersErr -Category 'InvalidResult'
            }
        }
        Catch {
            Write-Log -Message "Failed to set property qualifier for class [$Namespace`:$ClassName]. `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
        }
        Finally {
            Write-Output -InputObject $SetClassQualifiers
        }
    }
    End {
        Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
    }
}
#endregion

#endregion
##*=============================================
##* END MODULE DEFINITION
##*=============================================

#endregion
##*=============================================
##* END FUNCTION LISTINGS
##*=============================================

##*=============================================
##* SCRIPT BODY
##*=============================================
#region ScriptBody

## Get User Rights Assignment
$UserRightsAssignments  = Get-UserRightsAssignment

## Remove existing class
Remove-WmiClass -Namespace 'ROOT\CIMV2' -ClassName 'Win32_UserRightsAssignment' -ErrorAction 'SilentlyContinue'

## Create new class
[hashtable]$Qualifiers = @{
    Static      = $true
    Description = 'Custom Configuration Manager Hardware Inventory Class for User Rights Assignment Data. Endpoint Management Team.'
}
New-WmiClass -Namespace 'ROOT\CIMV2' -ClassName 'Win32_UserRightsAssignment' -Qualifiers $Qualifiers

## Add class properties
New-WmiProperty -Namespace 'ROOT\CIMV2' -ClassName 'Win32_UserRightsAssignment' -PropertyName 'PrincipalSID'     -PropertyType 'String' -Qualifiers @{ Key = $true }
New-WmiProperty -Namespace 'ROOT\CIMV2' -ClassName 'Win32_UserRightsAssignment' -PropertyName 'PrincipalName'    -PropertyType 'String'
New-WmiProperty -Namespace 'ROOT\CIMV2' -ClassName 'Win32_UserRightsAssignment' -PropertyName 'Privilege'        -PropertyType 'StringArray'
New-WmiProperty -Namespace 'ROOT\CIMV2' -ClassName 'Win32_UserRightsAssignment' -PropertyName 'PrivilegeBitMask' -PropertyType 'UInt64' -Qualifiers @{ Key = $true }

## Add class instances
ForEach ($UserRightsAssignment in $UserRightsAssignments) {
    #  Initialize loop variables
    [uint64]$Bitmask = 0
    [string[]]$Privileges = $UserRightsAssignment.Privilege
    ForEach ($Privilege in $Privileges) {
        #  Create bitmask
        [UInt64]$Bitmask += [UInt64][UserRightsFlags]::$Privilege
    }
    #  Convert PSCustomObject to Hashtable
    [hashtable]$Property = $UserRightsAssignment | ConvertTo-HashtableFromPsCustomObject
    #  Add bitmask to hashtable
    $Property.Add('PrivilegeBitMask',  [UInt64]$Bitmask)
    #  Write class instance
    New-WmiInstance -Namespace 'ROOT\CIMV2' -ClassName 'Win32_UserRightsAssignment' -Property $Property
}

## Write output
Write-Output -InputObject $Output

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================