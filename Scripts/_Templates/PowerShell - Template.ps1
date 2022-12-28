<#
.SYNOPSIS
    ShortDescription.
.DESCRIPTION
    LongDescription.
.PARAMETER ParameterName
    Specifies what is does.
.EXAMPLE
    ApprovedVerb-WhatItDoes(Use Singular).ps1
.INPUTS
    None.
.OUTPUTS
    None.
.NOTES
    Created by
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    --
.FUNCTIONALITY
    --
#>

## Set script requirements
#Requires -Version 3.0

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

## Get script parameters
Param (
    [Parameter(Mandatory = $false, HelpMessage = "Valid options are: '--','--' and '--'", Position = 0)]
    [ValidateNotNullorEmpty()]
    [ValidateSet('--','--','--')]
    [Alias('--')]
    [string]$-- = '--'
)

#endregion
##*=============================================
##* END VARIABLE DECLARATION
##*=============================================

##*=============================================
##* FUNCTION LISTINGS
##*=============================================
#region FunctionListings

#region Function --
Function Verb- {
<#
.SYNOPSIS
    --.
.DESCRIPTION
    --.
.PARAMETER --
    --.
.EXAMPLE
    --
.INPUTS
    None.
.OUTPUTS
    None.
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.COMPONENT
    --
.FUNCTIONALITY
    --
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullorEmpty()]
        [ValidateSet('--','--','--')]
        [Alias('--')]
        [string]$-- = '--'
    )

    Begin {
    }
    Process {
        Try {
        }
        Catch {
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

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================
