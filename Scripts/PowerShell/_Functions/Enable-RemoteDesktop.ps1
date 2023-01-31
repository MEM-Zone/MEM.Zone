<#
.SYNOPSIS
    Enables remote desktop.
.DESCRIPTION
    Enables remote desktop and sets the firewall exception.
.EXAMPLE
    Enable-RemoteDesktop.ps1
.INPUTS
    None.
.OUTPUTS
    System.String.
.NOTES
    Created by Ioan Popovici
.LINK
    https://MEM.Zone/
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    CM
.FUNCTIONALITY
    Enable Remote Desktop
#>

## Set script requirements
#Requires -Version 3.0

##*=============================================
##* SCRIPT BODY
##*=============================================
#region ScriptBody

Begin {}

Process {
    Try {
        Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name 'fDenyTSConnections' -Value '0' -ErrorAction 'Stop'
        Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name 'UserAuthentication' -Value '1' -ErrorAction 'Stop'
        Enable-NetFirewallRule -DisplayGroup 'Remote Desktop' -ErrorAction 'Stop'
        $Result = 'RDP Enabled!'
    }
    Catch {
        $Result = $($PSItem.Exception.Message)
    }
    Finally {
        Write-Output -InputObject $Result
    }
}

End {}

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================