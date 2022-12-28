#region Function Test-EventLogCompliance
Function Test-EventLogCompliance {
<#
.SYNOPSIS
    Tests the EventLog compliance for specific events.
.DESCRIPTION
    Tests the EventLog compliance by getting events and returing a Non-Compliant statement after a specified treshold is reached.
.PARAMETER LogName
    Specifies the LogName to search.
.PARAMETER Source
    Specifies the Source to search.
.PARAMETER EventID
    Specifies the EventID to search.
.PARAMETER EntryType
    Specifies the Entry Type to search. Available options are: ('Information','Warning','Error'). Default is: 'Error'.
.PARAMETER LimitDays
    Specifies the number of days from the current date to limit the search to.
    Default is: 1.
.PARAMETER Threshold
    Specifed the numbers of events after which this functions returns $true.
.EXAMPLE
    Test-EventLogCompliance -LogName 'Application' -Source 'ESENT' -EventID '623' -EntryType 'Error' -LimitDays 3 -Threshold 3
.INPUTS
    None.
.OUTPUTS
    System.Boolean.
.NOTES
    This function can typically be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.COMPONENT
    WindowsUpdate
.FUNCTIONALITY
    Test
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true,Position=0)]
        [ValidateNotNullorEmpty()]
        [string]$LogName,
        [Parameter(Mandatory=$true,Position=1)]
        [ValidateNotNullorEmpty()]
        [string]$Source,
        [Parameter(Mandatory=$true,Position=2)]
        [ValidateNotNullorEmpty()]
        [string]$EventID,
        [Parameter(Mandatory=$false,Position=3)]
        [ValidateSet('Information','Warning','Error')]
        [string]$EntryType = 'Error',
        [Parameter(Mandatory=$false,Position=4)]
        [ValidateNotNullorEmpty()]
        [int]$LimitDays = 1,
        [Parameter(Mandatory=$true,Position=5)]
        [ValidateNotNullorEmpty()]
        [int]$Threshold
    )

    Try {

        ## Set day limit by substracting number of days from the current date
        $After = $((Get-Date).AddDays( - $LimitDays ))

        ## Get events and test treshold
        $Events = Get-EventLog -ComputerName $env:COMPUTERNAME -LogName $LogName -Source $Source -EntryType $EntryType -After $After -ErrorAction 'Stop' | Where-Object { $_.EventID -eq $EventID }

        If ($Events.Count -ge $Threshold) {
            $Compliance = 'Non-Compliant'
        }
        Else {
            $Compliance = 'Compliant'
        }
    }
    Catch {

        ## Set result as 'Compliant' if no matches are found
        If ($($_.Exception.Message) -match 'No matches found') {
            $Compliance =  'Compliant'
        }
        Else {
            $Compliance = "Eventlog [$EventLog] compliance test error. $($_.Exception.Message)"
        }
    }
    Finally {

        ## Return Compliance result
        Write-Output -InputObject $Compliance
    }
}
#endregion