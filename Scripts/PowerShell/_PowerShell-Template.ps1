<#
.SYNOPSIS
    ShortDescription.
.DESCRIPTION
    LongDescription.
.PARAMETER ParameterName
    ParameterDescription.
.EXAMPLE
    ApprovedVerb-WhatItDoes(Use Singular).ps1
.INPUTS
    None.
.OUTPUTS
    None.
.NOTES
    Created by Ioan Popovici
.LINK
    https://MEM.Zone/PS-Template
.LINK
    https://MEM.Zone/PS-Template-CHANGELOG
.LINK
    https://MEM.Zone/PS-Template-GIT
.LINK
    https://MEM.Zone/Issues
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
    [Parameter(Mandatory=$false,HelpMessage="Valid options are: '--','--' and '--'",Position=0)]
    [ValidateNotNullorEmpty()]
    [ValidateSet('--','--','--')]
    [Alias('--')]
    [string]$ParameterName = '--'
)

## Get script path and name
[string]$ScriptPath = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Definition)
[string]$ScriptName = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Definition)

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
    ShortDescription.
.DESCRIPTION
    LongDescription.
.PARAMETER ParameterName
    ParameterDescription.
.EXAMPLE
    ApprovedVerb-WhatItDoes(Use Singular).ps1
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
        [Parameter(Mandatory=$true,Position=0)]
        [ValidateNotNullorEmpty()]
        [ValidateSet('--','--','--')]
        [Alias('--')]
        [string]$ParameterName = '--'
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
