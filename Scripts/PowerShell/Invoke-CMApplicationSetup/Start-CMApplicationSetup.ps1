<#
.SYNOPSIS
    Start the installation or uninstallation of a Configuration Manager deployed application.
.DESCRIPTION
    Start the installation or uninstallation of a Configuration Manager deployed application.
.PARAMETER Application
    Specifies the name of the application.
.PARAMETER Method
    Specifies method to invoke.
    Valid values are: 'Install' and 'Uninstall'.
.EXAMPLE
    Start-CMAppInstallation.ps1 -Application 'ApplicationName' -Method 'Install'
.INPUTS
    None.
.OUTPUTS
    None.
.NOTES
    Created by Ioan Popovici
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    Configuration Manager
.FUNCTIONALITY
    Application Installation/Uninstallation
#>

## Set script requirements
#Requires -Version 3.0

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

## Get script parameters
Param (
    [Parameter(Mandatory = $true, HelpMessage = "Valid options are: 'Install' and 'Uninstall'", Position = 0)]
    [string]$Application,
    [ValidateSet('Install', 'Uninstall')]
    [Parameter(Mandatory = $true, Position = 1)]
    [string]$Method
)

#endregion
##*=============================================
##* END VARIABLE DECLARATION
##*=============================================

##*=============================================
##* FUNCTION LISTINGS
##*=============================================
#region FunctionListings

#region Function Start-CMApplicationSetup
Function Start-CMApplicationSetup {
<#
.SYNOPSIS
    Start the installation or uninstallation of a Configuration Manager deployed application.
.DESCRIPTION
    Start the installation or uninstallation of a Configuration Manager deployed application.
.PARAMETER Application
    Specifies the name of the application.
.PARAMETER Method
    Specifies method to invoke.
    Valid values are: 'Install' and 'Uninstall'.
.EXAMPLE
    Start-CMAppInstallation -Application 'App-Name' -Method 'Install'
.INPUTS
    None.
.OUTPUTS
    None.
.NOTES
    Created by Ioan Popovici
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    Configuration Manager
.FUNCTIONALITY
    Application Installation/Uninstallation
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Valid options are: 'Install' and 'Uninstall'", Position = 0)]
        [string]$ApplicationName,
        [ValidateSet('Install', 'Uninstall')]
        [Parameter(Mandatory = $true, Position = 1)]
        [string]$Action
    )

    Begin {
    }
    Process {
        Try {

            ## Get the application object
            $Application = Get-CimInstance -ClassName CCM_Application -Namespace 'Root\ccm\ClientSDK' | Where-Object {$PSItem.Name -like $ApplicationName}

            ## Build the invoke arguments hashtable
            [hashtable]$Arguments = @{
                EnforcePreference = [uint]0
                Id = "$($Application.Id)"
                IsMachineTarget = $Application.IsMachineTarget
                IsRebootIfNeeded = $false
                Priority = 'High'
                Revision = "$($Application.Revision)"
            }

            ## Invoke the wmi method
            Invoke-CimMethod -Namespace 'root\ccm\clientSDK' -ClassName 'CCM_Application' -MethodName $Method -Arguments $Arguments
        }
        Catch {
            $PSCmdlet.WriteError($PSItem)
        }
        Finally {
            Write-Output -InputObject $Output
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

Start-CMApplicationSetup -ApplicationName $ApplicationName -Method $Method

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================