<#
.SYNOPSIS
    Adds the currently logged-in user to the local administrators group.
.DESCRIPTION
    This script attempts to add the currently logged-in user to the local administrators group.
.EXAMPLE
    .\Add_LoggedOn_User_into_Administrators_Group.ps1
.INPUTS
    None.
.OUTPUTS
    System.Object.
.NOTES
    Created by Ferry Bodijn.
.LINK
    https://github.com/Visma-IT-Communications-AS/VIT-MEM
.COMPONENT
    Windows Registry
.FUNCTIONALITY
    Adds the currently logged-in user to the local administrators group.
#>

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

#endregion VariableDeclaration
##*=============================================
##* END VARIABLE DECLARATION
##*=============================================

##*=============================================
##* FUNCTION LISTINGS
##*=============================================
#region Function Get-CurrentUser
Function Get-CurrentUser {
<#
.SYNOPSIS
    Retrieves the currently logged-in user.
.DESCRIPTION
    This function retrieves the currently logged-in user by querying the session manager.
.EXAMPLE
    Get-CurrentUser
.INPUTSA
    None.
.OUTPUTS
    System.Object.
.NOTES
    This is an internal script function and should not be called directly.
.LINK
    https://www.reddit.com/r/PowerShell/comments/7coamf/query_no_user_exists_for/
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    Session Manager
.FUNCTIONALITY
    Retrieves the currently logged-in user.
#>
    [CmdletBinding()]
    Param ()

    Begin {}
    Process {
        Try {
            # Get all sessions
            $Sessions = (& query session)
            # Select active sessions, convert the result to a CSV object and select only 'Active' connections
            $ActiveSessions = $Sessions -replace ('\s{2,}', ',') | ConvertFrom-Csv | Where-Object -Property 'State' -eq 'Active'
            # Get current user
            $CurrentUser = $ActiveSessions[0]
            # Get user SID
            $CurrentUserSID = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI\SessionData\$($CurrentUser.ID)" -Name 'LoggedOnUserSID' -ErrorAction 'SilentlyContinue').LoggedOnUserSID
            # Get machine domain
            $Domain = [System.Net.Dns]::GetHostByName($Env:ComputerName).HostName.Replace($Env:ComputerName + '.', '')
            # Build output object
            $Output = [pscustomobject]@{
                UserSID       = $CurrentUserSID
                UserName      = $CurrentUser.USERNAME
                MachineDomain = $Domain.ToUpper()
            }
        }
        Catch {
            Write-Error -Message $PsItem.Exception
        }
        Finally {
            Write-Output -InputObject $Output
        }
    }
    End {}
}
#endregion Function Get-CurrentUser
##*=============================================
##* END FUNCTION LISTINGS
##*=============================================

##*=============================================
##* SCRIPT BODY
##*=============================================
#region ScriptBody

# Retrieve the currently logged-on user on this device
$activeUser = Get-CurrentUser

[string]$Domain = $activeUser.MachineDomain
[string]$Username = $activeUser.UserName
[int]$Result = 1

try {
    # Add the user to the local administrators group
    Net localgroup Administrators /add "$Domain\$Username"
}
catch {
    Write-Output "Failed to add the logged-on user to the local administrators group."
}

# Retrieve all members in the local administrators group
$group = [ADSI]"WinNT://$env:COMPUTERNAME/Administrators"
$admins = $group.Invoke('Members') | % {
    $path = ([adsi]$_).path
    [pscustomobject]@{
        Computer = $env:COMPUTERNAME
        Domain = $(Split-Path (Split-Path $path) -Leaf)
        User = $(Split-Path $path -Leaf)
    }
}

# Check if the user is in the local administrators group
foreach ($admin in $admins) {
    if ($($admin.user) -eq $Username) {
        Write-Output "$($admin.user) is a local admin"
        [int]$Result = 0
    }
}

Write-Output "The detection script ended with Exit $Result"
Exit $Result

#endregion ScriptBody
##*=============================================
##* SCRIPT BODY
##*=============================================