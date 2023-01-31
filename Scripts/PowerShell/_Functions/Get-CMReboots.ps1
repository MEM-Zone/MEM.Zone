<#
.SYNOPSIS
    Gets the Configuration Manager Client reboots.
.DESCRIPTION
    Gets the reboots initiated by the Configuration Manager Client.
.PARAMETER LastNHours
    Specifies how many hours in the past to look.
.EXAMPLE
    Get-CMReboots.ps1 -LastNHours '4'
.INPUTS
    System.String.
.OUTPUTS
    System.String.
.NOTES
    Created by Ioan Popovici
.LINK
    https://MEM.Zone/
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    CM
.FUNCTIONALITY
    Reboot info
#>

## Set script requirements
#Requires -Version 3.0

##*=============================================
##* SCRIPT BODY
##*=============================================
#region ScriptBody

Param (
    [Parameter(Mandatory=$true,Position=0)]
    [ValidateNotNullorEmpty()]
    [Alias('hrs')]
    [string]$LastNHours
)
Begin {
    [datetime]$LookupHours = (Get-Date).AddHours(- $LastNHours)
}

Process {
    Try {
        $GetRebootEvents = Get-WinEvent -FilterHashtable @{LogName = 'System'; ID = '1074'} | Where-Object {
            $PSItem.Message -like '*ccm*' -and $PSItem.TimeCreated -gt $LookupHours
        }
        $Result = "$($GetRebootEvents.Count) reboots (Last $LastNHours hrs)"
    }
    Catch {
        $Result = $($PSItem.Exception.Message)
    }
    Finally {
        Write-Output -InputObject $Result
    }
}

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================