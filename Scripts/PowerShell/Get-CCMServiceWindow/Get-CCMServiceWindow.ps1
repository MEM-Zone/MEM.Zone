<#
.SYNOPSIS
    Retrieves Configuration Manager service windows from the local or remote client.
.DESCRIPTION
    This function queries the CCM_ServiceWindow WMI (Configuration Manager Client SDK) class to retrieve maintenance windows
    configured on the Configuration Manager client, including their schedules and types.
    The function supports both local and remote computer queries and provides detailed
    information about each service window including duration calculations.
.PARAMETER ComputerName
    Specifies the name of the computer to query. Defaults to the local computer.
.PARAMETER Type
    Specifies the type(s) of service windows to retrieve. Valid values are:
    'All Deployments', 'Program', 'Reboot', 'Software Updates', 'Task Sequence', 'User-defined'
    If not specified, all service window types are returned.
.PARAMETER MinimumDurationHours
    Specifies the minimum duration in hours for service windows to be included in results.
    Service windows shorter than this duration will be excluded. Default is 0 (no filtering).
.EXAMPLE
    Get-CCMServiceWindow

    Retrieves all service windows from the local computer.
.EXAMPLE
    Get-CCMServiceWindow -ComputerName 'Server01'

    Retrieves all service windows from the specified remote computer.
.EXAMPLE
    Get-CCMServiceWindow -Type 'Software Updates', 'Reboot'

    Retrieves only Software Updates and Reboot maintenance windows from the local computer.
.EXAMPLE
    Get-CCMServiceWindow -MinimumDurationHours 1

    Retrieves all service windows that are at least 1 hour long, excluding shorter windows.
.EXAMPLE
    Get-CCMServiceWindow -Type 'Software Updates' -MinimumDurationHours 2

    Retrieves only Software Updates maintenance windows that are at least 2 hours long.
.EXAMPLE
    'Server01', 'Server02' | Get-CCMServiceWindow -Type 'Task Sequence'

    Retrieves only Task Sequence maintenance windows from multiple computers via pipeline.
.INPUTS
    System.String. Computer names can be piped to this function.
.OUTPUTS
    PSCustomObject. Returns objects with properties: ComputerName, ID, Type, StartTime, EndTime, DurationH.
.NOTES
    Created by Ioan Popovici 2020-03-06
    Requires Configuration Manager client to be installed on target computer(s).
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    Configuration Manager Client SDK
.FUNCTIONALITY
    Retrieves Service Windows
#>

## Set script requirements
#Requires -Version 5.0

##*=============================================
##* FUNCTION LISTINGS
##*=============================================
#region FunctionListings

#region function Get-CCMServiceWindow
function Get-CCMServiceWindow {
<#
.SYNOPSIS
    Retrieves Configuration Manager service windows from the local or remote client.
.DESCRIPTION
    This function queries the CCM_ServiceWindow WMI class to retrieve maintenance windows
    configured on the Configuration Manager client, including their schedules and types.
.PARAMETER ComputerName
    Specifies the name of the computer to query. Defaults to the local computer.
.PARAMETER Type
    Specifies the type(s) of service windows to retrieve.
.PARAMETER MinimumDurationHours
    Specifies the minimum duration in hours for service windows to be included.
.EXAMPLE
    Get-CCMServiceWindow -ComputerName 'Server01'
.INPUTS
    System.String.
.OUTPUTS
    PSCustomObject.
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
#>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ComputerName = $env:COMPUTERNAME,

        [Parameter()]
        [ValidateSet('All Deployments', 'Program', 'Reboot', 'Software Updates', 'Task Sequence', 'User-defined')]
        [string[]]$Type,

        [Parameter()]
        [ValidateRange(0, 24)]
        [double]$MinimumDurationHours = 0
    )

    begin {

        ## Add required assemblies
        Add-Type -AssemblyName System.Management

        ## Define service window type mapping
        $ServiceWindowTypeMap = @{
            1 = 'All Deployments'
            2 = 'Program'
            3 = 'Reboot'
            4 = 'Software Updates'
            5 = 'Task Sequence'
            6 = 'User-defined'
        }

        ## Initialize date time converter
        $DateTimeConverter = [System.Management.ManagementDateTimeConverter]
    }

    process {
        try {

            ## Set WMI scope path based on computer name
            $ScopePath = if ($ComputerName -eq $env:COMPUTERNAME) {
                '\\.\root\ccm\ClientSDK'
            }
            else {
                "\\$ComputerName\root\ccm\ClientSDK"
            }

            ## Create WMI scope and connect
            $Scope = New-Object System.Management.ManagementScope($ScopePath)
            $Scope.Connect()

            ## Create WMI searcher for service windows
            $Searcher = New-Object System.Management.ManagementObjectSearcher(
                $Scope, (New-Object System.Management.ObjectQuery('SELECT * FROM CCM_ServiceWindow'))
            )

            ## Process each service window
            $ServiceWindows = $Searcher.Get() | ForEach-Object {

                ## Convert WMI datetime to .NET DateTime
                $StartTime = $DateTimeConverter::ToDateTime($PSitem.Properties['StartTime'].Value)
                $EndTime   = $DateTimeConverter::ToDateTime($PSitem.Properties['EndTime'].Value)
                $DurationInHours = [math]::Round( ($PSitem.Properties['Duration'].Value) / 3600, 2 )

                ## Get service window type
                $ServiceWindowType = $ServiceWindowTypeMap[[int]$PSitem.Properties['Type'].Value]

                ## Create output object
                [pscustomobject]@{
                    ComputerName    = $ComputerName
                    ID              = $PSitem.Properties['ID'].Value
                    Type            = $ServiceWindowType
                    StartTime       = $StartTime
                    EndTime         = $EndTime
                    DurationInHours = $DurationInHours
                }
            }

            ## Filter by type if specified
            if ($Type) {
                $ServiceWindows = $ServiceWindows | Where-Object { $_.Type -in $Type }
            }

            ## Filter by minimum duration if specified
            if ($MinimumDurationHours -gt 0) {
                $ServiceWindows = $ServiceWindows | Where-Object { $_.DurationInHours -ge $MinimumDurationHours }
            }

            ## Return sorted results
            $ServiceWindows | Sort-Object StartTime
        }
        catch {
            Write-Error "Failed to retrieve service windows from [$ComputerName]. $($PSitem.Exception.Message)"
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

Get-CCMServiceWindow -Type 'Software Updates', 'All Deployments' -MinimumDurationHours 1

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================