<#
.SYNOPSIS
    Creates new Local User.
.DESCRIPTION
    Creates a new Local User and adds it to BUILTIN\Administrators group.
.PARAMETER Name
    Specifies the local user name.
.PARAMETER Password
    Specifies the local user account password.
.PARAMETER Description
    Specifies the local user name account description.
.EXAMPLE
    Add-LocalUser.ps1 -User 'SomeUsername' -Password 'SomePassword' -Description 'SomeDescription'
.INPUTS
    None.
.OUTPUTS
    System.String.
.NOTES
    Created by Ioan Popovici
    2021-03-31 v1.0.0
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/Issues
.COMPONENT
    Account Management
.FUNCTIONALITY
    Add User
#>

## Set script requirements
#Requires -Version 5.0

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

## Get script parameters
Param (
    [Parameter(Mandatory=$true,HelpMessage="Specify Username",Position=0)]
    [ValidateNotNullorEmpty()]
    [Alias('UserName')]
    [string]$User,
    [Parameter(Mandatory=$true,HelpMessage="Specify account password",Position=1)]
    [ValidateNotNullorEmpty()]
    [Alias('Pass')]
    [string]$Password,
    [Parameter(Mandatory=$false,HelpMessage="Specify account description",Position=2)]
    [ValidateNotNullorEmpty()]
    [Alias('Desc')]
    [string]$Description = 'SD Temporary Administrative Account'
)

## Convert password to secure string
[securestring]$SecureString = ConvertTo-SecureString -String $Password -AsPlainText -Force

#endregion
##*=============================================
##* END VARIABLE DECLARATION
##*=============================================

##*=============================================
##* SCRIPT BODY
##*=============================================
#region ScriptBody

Try {

    ## Create the user if it does not already exist
    $UserExists = Get-LocalUser -Name $User -ErrorAction 'SilentlyContinue'
    If (-not $UserExists) {
        New-LocalUser -Name $User -Password $SecureString -Description $Description
        Write-Verbose -Message "Successfully created $User."
    }

    ## Add user to local admin if it's not already added
    $IsLocalAdmin = Get-LocalGroupMember -Name 'Administrators' -ErrorAction 'SilentlyContinue' | Where-Object -Property 'Name' -eq $User
    If (-not $IsLocalAdmin) {
        Add-LocalGroupMember -Group Administrators -Member $User
        Write-Verbose -Message "Successfully added $User to BUILTIN\Administrators group."
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
