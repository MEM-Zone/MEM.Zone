<#
*********************************************************************************************************
* Requires          | Requires PowerShell 2.0                                                           *
* ===================================================================================================== *
* Modified by       |    Date    | Revision | Comments                                                  *
* _____________________________________________________________________________________________________ *
* Ioan Popovici     | 2018-04-09 | v1.0     | First version                                             *
* ===================================================================================================== *
*                                                                                                       *
*********************************************************************************************************
#>

#region Function Get-LocalGroupMemberLegacy
Function Get-LocalGroupMemberLegacy {
<#
.SYNOPSIS
    Gets members from a local group.
.DESCRIPTION
    Gets members from a local group in legacy mode, where the Get-LocalGroupMember is not available.
.PARAMETER Name
    Specifies the security group name from which this cmdlet gets members.
.PARAMETER SID
    Specifies the security ID of the security group from which this cmdlet gets members.
.PARAMETER Member
    Specifies a user or group that this cmdlet gets from a security group. You can use Wildcards.
    If you do not specify this parameter, the cmdlet gets all members of the group.
.INPUTS
    System.Management.Automation.SecurityAccountsManager.LocalGroup, System.String, System.Security.Principal.SecurityIdentifier
    You can pipe a local group, a string, or a SID to this cmdlet.
.OUTPUTS
    System.Management.Automation.PSCustomObject
    This cmdlet returns a custom object
.NOTES
    This is a regular function and can typically be called directly.
.LINK
    https://SCCM-Zone.com
.LINK
    https://github.com/Ioan-Popovici/SCCMZone
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$false,ValueFromPipeline=$true,Position=0)]
        [ValidateNotNullorEmpty()]
        [string]$GroupName,
        [Parameter(Mandatory=$false,ValueFromPipeline=$true,Position=1)]
        [ValidateNotNullorEmpty()]
        [System.Security.Principal.SecurityIdentifier]$GroupSID,
        [Parameter(Mandatory=$false,ValueFromPipeline=$true,Position=2)]
        [ValidateNotNullorEmpty()]
        [SupportsWildcards()]
        [string]$GroupMember
    )
    Begin {

        ## Initialize variables
        [ADSI]$Domain = 'WinNT://' + $Env:ComputerName
        [regex]$Pattern = '[^\/]+.[^\/]+.$'

        ## Set default object decoration properties
        [string[]]$DefaultProperties = 'ObjectClass', 'Name', 'PrincipalSource'
        #  Create a new DefaultDisplayPropertySet, and add the properties to display by default
        $DefaultDisplayPropertySet = New-Object System.Management.Automation.PSPropertySet 'DefaultDisplayPropertySet', $DefaultProperties
        #  Create a new PSMemberInfo object and add the DefaultDisplayPropertySet to it
        $PSStandardMembers = [System.Management.Automation.PSMemberInfo[]]$DefaultDisplayPropertySet
    }
    Process {
        Try {

            ## Get local group depending on input parameters
            If ($GroupName) {
                $LocalGroup = $Domain.Children | Where-Object { $_.Class -eq 'Group' } | Where-Object { $_.Name -eq $GroupName }
            }
            ElseIf ($GroupSID) {
                $LocalGroup = $Domain.Children | Where-Object { $_.Class -eq 'Group' } | Where-Object {
                    $(New-Object Security.Principal.SecurityIdentifier ($_.objectSid, 0)).Value -eq $GroupSID
                }
                $GroupName = $GroupSID
            }
            Else {
                Write-Error -Message 'Parameter validation error. You need to specify a value for -GroupName or -GroupSID parameters' -Category 'NotSpecified'
            }

            ## Get local group members
            $LocalGroupMembers = ([ADSI]"$($LocalGroup.Path), Group").Invoke('Members')

            ## Get local group properties
            $GetLocalGroupMember = ForEach ($Member in $LocalGroupMembers) {
                #  Get member properties
                $Class = $Member.GetType.Invoke().InvokeMember('Class', 'GetProperty', $null, $Member , $null)
                $AdsPath = $Member.GetType.Invoke().InvokeMember('AdsPath', 'GetProperty', $null, $Member , $null)
                $Name = $($AdsPath | Select-String -Pattern $Pattern).Matches.Value -Replace ('/','\')
                $PrincipalSource = If ($Name -match $Env:ComputerName) { 'Local' } Else { 'ActiveDirectory' }
                #  Get SID
                $SIDBinary = $Member.GetType().InvokeMember('objectSid', 'GetProperty', $null, $Member, $null)
                $SIDString = New-Object Security.Principal.SecurityIdentifier ($SIDBinary, 0) | Select-Object -ExpandProperty 'Value'

                #  Assemble output
                $LocalGroupMemberProps = [PSCustomObject][Ordered]@{
                    'ObjectClass' = $Class
                    'Name' = $Name
                    'PrincipalSource' = $PrincipalSource
                    'SID' = $SIDString
                }

                #  Add the custom DefaultPropertySet, in order to show only ObjectClass, Name and PrincipalSource by default
                Add-Member -InputObject $LocalGroupMemberProps -MemberType 'MemberSet' -Name 'PSStandardMembers' -Value $PSStandardMembers -PassThru
            }

            ## Get only specified group member
            If ($GroupMember) {
                $GetLocalGroupMember = $GetLocalGroupMember | Where-Object { $_.Name -like $GroupMember }
            }
        }
        Catch {
            Write-Error -Message "Group $GroupName was not found. `n$_" -Category 'ObjectNotFound'
            Break
        }
        Finally {

            ## Return $GetLocalGroupMember
            Write-Output -InputObject $($GetLocalGroupMember | Sort-Object -Property 'Name')
        }
    }
    End {
    }
}
#endregion