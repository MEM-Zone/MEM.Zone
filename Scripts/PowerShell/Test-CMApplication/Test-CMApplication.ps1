<#
.SYNOPSIS
    Get Specified ConfigMgr Managed Application version.
.DESCRIPTION
    Get Specified ConfigMgr Managed Application version, by querying the
    ConfigMgr Client SDK and optionally check the version.
.PARAMETER Name
    Specifies the name of the application. Supports Wildcards.
.PARAMETER Version
    Specifie the version to check.
.EXAMPLE
    Test-CMApplication.ps1 -Name '*Autocad'
.EXAMPLE
    Test-CMApplication.ps1 -Name '*Autocad' -Version '9.0.0'
.INPUTS
    None.
.OUTPUTS
    None.
.NOTES
    Created by Ioan Popovici
    If more than one application is detected the script will throw 'Multiple Applications (x) Found!' error.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    Configuration Manager
.FUNCTIONALITY
    Gets Managed Application
#>

## Set script requirements
#Requires -Version 3.0

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

## Get script parameters
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $true, HelpMessage = "Enter application name", Position = 0)]
    [ValidateNotNullorEmpty()]
    [SupportsWildcards()]
    [string]$Name,
    [Parameter(Mandatory = $false, HelpMessage = "Enter application version", Position = 1)]
    [ValidateNotNullorEmpty()]
    [string]$Version
)

#endregion
##*=============================================
##* END VARIABLE DECLARATION
##*=============================================

##*=============================================
##* FUNCTION LISTINGS
##*=============================================
#region FunctionListings

#region Function Test-CMApplication
Function Test-CMApplication {
<#
.SYNOPSIS
    Get ConfigMgr Managed Application version.
.DESCRIPTION
    Get ConfigMgr Managed Application version, by querying the
    ConfigMgr Client SDK and optionally check the version.
.PARAMETER Name
    Specifies the name of the application.
.PARAMETER Version
    Specifie the version to check.
.EXAMPLE
    Test-CMApplication -Name '*Autocad'
.EXAMPLE
    Test-CMApplication -Name '*Autocad' -Version '9.0.0'
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
    Gets Managed Application
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = "Enter application name", Position = 0)]
        [ValidateNotNullorEmpty()]
        [string]$Name,
        [Parameter(Mandatory = $false, HelpMessage = "Enter application version", Position = 1)]
        [ValidateNotNullorEmpty()]
        [string]$Version
    )

    Begin {
        [string]$Output = 'Not-Detected'
    }
    Process {
        Try {

            ## Get the application object
            $Application = (Get-CimInstance -ClassName 'CCM_Application' -Namespace 'Root\ccm\ClientSDK').Where({ $PSItem.FullName -like $Name })

            ## Check for multple applications found
            If ( $($Application.FullName).Count -gt 1 ) {

                ## Return custom error
                $Message       = [string]"Multiple Applications ({0}) Found! {1}" -f $($Application.FullName).Count, $($PsItem.Exception.Message)
                $Exception     = [Exception]::new($Message)
                $ExceptionType = [Management.Automation.ErrorCategory]::OperationStopped
                $ErrorRecord   = [System.Management.Automation.ErrorRecord]::new($Exception, $PsItem.FullyQualifiedErrorId, $ExceptionType, $Application)
                $Output = $Message
                $PSCmdlet.ThrowTerminatingError($ErrorRecord)
            }
            If ($Application) {
                $Output = 'Detected'

                ## Compare versions
                If ([string]::IsNullOrEmpty($Version)) {
                    If ([version]$Application.SoftwareVersion -eq [version]$Version) { $Output = 'Detected' } Else { $Output = 'Not-Detected' }
                }
            }
        }
        Catch {

            ## Return custom error
            $Message       = [string]"Error getting application '{0}'.`n{1}" -f $Application, $($PsItem.Exception.Message)
            $Exception     = [Exception]::new($Message)
            $ExceptionType = [Management.Automation.ErrorCategory]::OperationStopped
            $ErrorRecord   = [System.Management.Automation.ErrorRecord]::new($Exception, $PsItem.FullyQualifiedErrorId, $ExceptionType, $Application)
            $Output        = $Message
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

Test-CMApplication @PSBoundParameters

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================
