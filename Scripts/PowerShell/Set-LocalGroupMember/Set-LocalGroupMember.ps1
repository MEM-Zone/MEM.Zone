<#
.SYNOPSIS
    Adds or removes a user to a local group.
.DESCRIPTION
    Adds or removes a user to a local group on the machine it runs on.
.PARAMETER Name
    Specifies the user name.
.PARAMETER Group
    Specifies the local group name.
.PARAMETER Action
    Specifies the action to take. Valid Actions: 'Add', 'Remove'.
.EXAMPLE
    Add-LocalGroupMember.ps1 -User 'Contoso\greg.bear' -Group 'Administrators'
.EXAMPLE
    Add-LocalGroupMember.ps1 -User 'AzureAD\greg.bear@contoso.com' -Group 'Administrators'
.EXAMPLE
    Add-LocalGroupMember.ps1 -User 'MicrosoftAccount\greg.bear' -Group 'Administrators'
.INPUTS
    None.
.OUTPUTS
    System.String.
.NOTES
    Created by Ioan Popovici
    2021-06-08 v1.0.0
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    Account Management
.FUNCTIONALITY
    Set Local Group Member
#>

## Set script requirements
#Requires -Version 5.0

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

#region ScriptParameters (Comment this region with <# #> for hardcoded parameters)
## Get script parameters
Param (
    [Parameter(Mandatory=$true,HelpMessage="Specify Username",Position=0)]
    [ValidateNotNullorEmpty()]
    [Alias('Usr')]
    [string]$User,
    [Parameter(Mandatory=$true,HelpMessage="Specify local Group",Position=1)]
    [ValidateNotNullorEmpty()]
    [Alias('Grp')]
    [string]$Group,
    [Parameter(Mandatory=$true,HelpMessage="Specify Action ('Add','Remove')",Position=2)]
    [ValidateNotNullorEmpty()]
    [Alias('Act')]
    [string]$Action
)
#endregion

#region HardcodedParameters (Uncomment this region by removiing <# and #>, for hardcoded parameters)
<#
    [string]$User = ''
    [string]$Group = ''
    [string]$Action = ''
#>
#endregion

#endregion
##*=============================================
##* END VARIABLE DECLARATION
##*=============================================

##*=============================================
##* SCRIPT BODY
##*=============================================
#region ScriptBody

Try {

    ## Add user to local admin if it's not already added
    $IsLocalAdmin = Get-LocalGroupMember -Name 'Administrators' -ErrorAction 'SilentlyContinue' | Where-Object -Property 'Name' -Contains $User
    Switch ($Action) {
        'Add' {
            If (-not $IsLocalAdmin) {
                Add-LocalGroupMember -Group $Group -Member $User -ErrorAction 'Stop'
                Write-Verbose -Message "Successfully added $User to $Group group."
            }
        }
        'Remove' {
            If ($IsLocalAdmin) {
                Remove-LocalGroupMember -Group $Group -Member $User -ErrorAction 'Stop'
                Write-Verbose -Message "Successfully removed $User to $Group group."
            }
        }
    }

    ## Set result to success
    [string]$Result = "`nOperation completed succesfully!"
}
Catch {

    ## Set result to error message
    [string]$Result = $_.Exception.Message
}
Finally {

    ## Return result
    Write-Output -InputObject $Result
}

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================
