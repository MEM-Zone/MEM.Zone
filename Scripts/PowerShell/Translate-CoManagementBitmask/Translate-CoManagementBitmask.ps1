<#
.SYNOPSIS
    Translates the Configuration Manager Co-Management bitmask value.
.DESCRIPTION
    Translates the Configuration Manager Co-Management bitmask value to a human readable string.
.PARAMETER CoManagementBitmask
    Specifies the CoMamangementValue to be translated.
.PARAMETER Legacy
    Specifies the if the site version is below 2111.
.EXAMPLE
    Translate-CoManagementBitmask.ps1 -CoManagementBitmask 8193 -Legacy
.INPUTS
    None.
.OUTPUTS
    System.String
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
    Co-Management Value Translation
#>

## Set script requirements
#Requires -Version 3.0

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

## Get script parameters
Param (
    [Parameter(Mandatory = $true, HelpMessage = 'Comanagement Bitmask Value', Position = 0)]
    [ValidateNotNullorEmpty()]
    [Alias('CoManagementValue')]
    [int]$CoManagementBitmask,
    [switch]$Legacy
)

#endregion
##*=============================================
##* END VARIABLE DECLARATION
##*=============================================

##*=============================================
##* FUNCTION LISTINGS
##*=============================================
#region FunctionListings

#region Function Translate-CoManagementBitmask
Function Translate-CoManagementBitmask {
<#
.SYNOPSIS
    Translates the Configuration Manager Co-Management bitmask value.
.DESCRIPTION
    Translates the Configuration Manager Co-Management bitmask value to a human readable string.
.PARAMETER CoManagementBitmask
    Specifies the CoMamangementValue to be translated.
.PARAMETER Legacy
    Specifies the if the site version is below 2111.
.EXAMPLE
    Translate-CoManagementBitmask -CoManagementBitmask 8193 -Legacy
.INPUTS
    None.
.OUTPUTS
    System.String
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
    Co-Management Value Translation
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = 'Comanagement Bitmask Value', Position = 0)]
        [ValidateNotNullorEmpty()]
        [Alias('CoManagementValue')]
        [int]$CoManagementBitmask,
        [switch]$Legacy
    )

    Begin {
        If ($PSBoundParameters['Legacy']) {
            [Flags()]Enum CoManagementWorkloadsLegacy {
                ConfiguredNoWorkloads    = 1
                CompliancePolicies       = 2
                ResourceAccessPolicies   = 4
                DeviceConfiguration      = 8
                WindowsUpdatesPolicies   = 16
                EndpointProtection       = 32
                ClientApps               = 64
                OfficeClicktoRunApps     = 128
            }
        }
        Else {
            [Flags()]Enum CoManagementWorkloads {
                ConfiguredNoWorkloads    = 8193
                CompliancePolicies       = 2
                ResourceAccessPolicies   = 4
                DeviceConfiguration      = 8
                WindowsUpdatesPolicies   = 16
                EndpointProtection       = 4128
                ClientApps               = 64
                OfficeClicktoRunApps     = 128
            }
        }
    }
    Process {
        Try {
            If ($PSBoundParameters['Legacy']) {
                $Output = [CoManagementWorkloadsLegacy]$CoManagementBitmask
            }
            Else {
                $Output = [CoManagementWorkloads]$CoManagementBitmask
            }
        }
        Catch {
            ## Return custom error. The error handling is done here in order not to break the ForEach loop and allow it to continue.
            $Message       = [string]"Error translating '{0}'.`n{1}" -f $CoManagementBitmask, $($PsItem.Exception.Message)
            $Exception     = [Exception]::new($Message)
            $ExceptionType = [Management.Automation.ErrorCategory]::OperationStopped
            $ErrorRecord   = [System.Management.Automation.ErrorRecord]::new($Exception, $PsItem.FullyQualifiedErrorId, $ExceptionType, $CoManagementBitmask)
            $PSCmdlet.ThrowTerminatingError($ErrorRecord)
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

Translate-CoManagementBitmask @PSBoundParameters

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================