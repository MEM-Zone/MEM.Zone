#region Function Get-CurrentUser
Function Get-CurrentUser {
<#
.SYNOPSIS
    Gets the current user.
.DESCRIPTION
    Gets current logged-on user regardless of context by querying the session manager.
.EXAMPLE
    Get-CurrentUser
.INPUTS
    None.
.OUTPUTS
    Sytem.Object
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://www.reddit.com/r/PowerShell/comments/7coamf/query_no_user_exists_for/
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    Session Manager
.FUNCTIONALITY
    Gets the Current User
#>
    [CmdletBinding()]
    Param ()

    Begin {
    }
    Process {
        Try {

            ## Get current user
            #  Get all sessions
            $Sessions = (& query session)
            #  Select active sessions by replacing spaces with ',', convert the result to a CSV object and select only 'Active' connections
            $ActiveSessions = $Sessions -replace ('\s{2,}', ',') | ConvertFrom-Csv | Where-Object -Property 'State' -eq 'Active'
            #  Get current user
            $CurrentUser = $ActiveSessions[0]
            #  Get user SID
            $CurrentUserSID = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI\SessionData\$($CurrentUser.ID)" -Name 'LoggedOnUserSID' -ErrorAction 'SilentlyContinue').LoggedOnUserSID
            #  Get machine domain
            $Domain = [System.Net.Dns]::GetHostByName($Env:ComputerName).HostName.Replace($Env:ComputerName + '.', '')
            #  Build output object
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
    End {
    }
}
#endregion
