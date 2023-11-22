<#
.SYNOPSIS
    Sets the Intune logging options.
.DESCRIPTION
    Sets the Intune log size and history.
.PARAMETER LogMaxSize
    Specifies the log maximum size in MB.
.PARAMETER LogMaxHistory
    Specifies the log maximum history in number of files to keep.
.PARAMETER RestartService
    Specifies whether to restart the Intune Management Extension service to apply the changes.
    I do not recommend using this parameter restarting the Intune Management Extension might cause some issues.
.EXAMPLE
    Set-IntuneLoggingOptions.ps1 -LogMaxSize 10 -LogMaxHistory 10 -RestartService
.INPUTS
    None.
.OUTPUTS
    None.
.NOTES
    Created by Ioan Popovici
.LINK
    https://MEMZ.one/Set-IntuneLoggingOptions
.LINK
    https://MEMZ.one/Set-IntuneLoggingOptions-CHANGELOG
.LINK
    https://MEMZ.one/Set-IntuneLoggingOptions-GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    Intune
.FUNCTIONALITY
    Intune Logging Options
#>

## Set script requirements
#Requires -Version 5.0

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

## Get script parameters
Param (
    [Parameter(Mandatory = $false, Position = 0)]
    [ValidateNotNullorEmpty()]
    [Alias('Size')]
    [string]$LogMaxSize = '10',
    [Parameter(Mandatory = $false, Position = 1)]
    [ValidateNotNullorEmpty()]
    [Alias('History')]
    [string]$LogMaxHistory = '10',
    [Parameter(Mandatory = $false, Position = 3)]
    [switch]$RestartService
)

#endregion
##*=============================================
##* END VARIABLE DECLARATION
##*=============================================

##*=============================================
##* FUNCTION LISTINGS
##*=============================================
#region FunctionListings

#region Function Set-IntuneLoggingOptions
Function Set-IntuneLoggingOptions {
<#
.SYNOPSIS
    Sets the Intune logging options.
.DESCRIPTION
    Sets the Intune log size and history.
.PARAMETER LogMaxSize
    Specifies the log maximum size in MB.
.PARAMETER LogMaxHistory
    Specifies the log maximum history in number of files to keep.
.PARAMETER RestartService
    Specifies whether to restart the Intune Management Extension service to apply the changes.
    I do not recommend using this parameter restarting the Intune Management Extension might cause some issues.
.EXAMPLE
    Set-IntuneLoggingOptions -LogMaxSize 10 -LogMaxHistory 10 -RestartService
.INPUTS
    None.
.OUTPUTS
    None.
.NOTES
    Created by Ioan Popovici
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.COMPONENT
    Intune
.FUNCTIONALITY
    Intune Logging Options
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateNotNullorEmpty()]
        [Alias('Size')]
        [Int16]$LogMaxSize = '10',
        [Parameter(Mandatory = $false, Position = 1)]
        [ValidateNotNullorEmpty()]
        [Alias('History')]
        [int16]$LogMaxHistory = '10',
        [Parameter(Mandatory = $false, Position = 3)]
        [switch]$RestartService
    )

    Begin {
        $LogMaxSizeBytes = $LogMaxSize * 1MB
    }
    Process {
        Try {

            [string]$LogPath = 'HKLM:\SOFTWARE\Microsoft\IntuneWindowsAgent\Logging'
            [boolean]$LogPathExists = Test-Path -Path $LogPath -ErrorAction 'SilentlyContinue'
            If (-not $LogPathExists) { New-Item -Path $LogPath -Force }

            # Set the registry values for logging options
            Set-ItemProperty -Path $LogPath -Name 'LogMaxSize' -Value $LogMaxSizeBytes
            Set-ItemProperty -Path $LogPath -Name 'LogMaxHistory' -Value $LogMaxHistory

            # Restart the Intune Management Extension service to apply the changes
            If ($PSBoundParameters.ContainsKey('RestartService')) {
                Restart-Service -Name 'IntuneManagementExtension' -Force -ErrorAction 'Stop'
            }
        }
        Catch {
            Write-Error -Message $_.Exception.Message
        }
        Finally {
        }
    }
    End {
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

Set-IntuneLoggingOptions -LogMaxSize $LogMaxSize -LogMaxHistory $LogMaxHistory -RestartService:$RestartService

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================
