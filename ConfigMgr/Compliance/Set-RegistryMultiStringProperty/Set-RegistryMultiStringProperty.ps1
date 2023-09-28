<#
.SYNOPSIS
    Sets a registry MultiString value if it is not detected.
.DESCRIPTION
    Sets a registry MultiString value to a specified value if it is not detected.
.PARAMETER Path
    Specifies the registry key path.
.PARAMETER Name
    Specifies the registry key property name.
.PARAMETER Value
    Specifies the registry key property value to compare.
.EXAMPLE
    $Value = @(
    '"1"="[*.]somedomain.dk"'
    '"2"="[*.]somedomain.com"'
    )
    Set-RegistryMultiStringProperty -Path 'HKLM:\\SOFTWARE\Policies\Microsoft\Edge' -Name 'LegacySameSiteCookieBehaviorEnabledForDomainList' -Value $Value
.INPUTS
    System.String.
.OUTPUTS
    System.String. Returns 'Compliant' or 'NonCompliant'
.NOTES
    Created by Ioan Popovici
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    CM Compliance
.FUNCTIONALITY
    Registry MultiString Comparison
#>

## Set script requirements
#Requires -Version 3.0

#*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

## Get script parameters
Param (
    [Parameter(Mandatory=$false,Position=0)]
    [ValidateNotNullorEmpty()]
    [string]$Path,
    [Parameter(Mandatory=$false,Position=1)]
    [ValidateNotNullorEmpty()]
    [string]$Name,
    [Parameter(Mandatory=$false,Position=2)]
    [ValidateNotNullorEmpty()]
    [string[]]$Value
)

## Set script variables.
[string]$Path = 'HKLM:\\SOFTWARE\Policies\Microsoft\Edge'
[string]$Name = 'LegacySameSiteCookieBehaviorEnabledForDomainList'
[string[]]$Value = @(
   '"1"="[*.]somedomain.dk"'
   '"2"="[*.]somedomain.com"'
)
## Set remediation to $true if used in a remediation script
[bool]$Remediate = $true

#endregion
##*=============================================
##* END VARIABLE DECLARATION
##*=============================================

##*=============================================
##* FUNCTION LISTINGS
##*=============================================
#region FunctionListings

#region Detect-RegistryMultiStringProperty
Function Detect-RegistryMultiStringProperty {
<#
.SYNOPSIS
    Detects if a registry MultiString value is present.
.DESCRIPTION
    Detects if a registry MultiString value is present, or equal to a specified value.
.PARAMETER Path
    Specifies the registry key path.
.PARAMETER Name
    Specifies the registry key property name.
.PARAMETER Value
    Specifies the registry key property value to compare.
.EXAMPLE
    $Value = @(
    '"1"="[*.]somedomain.dk"'
    '"2"="[*.]somedomain.com"'
    )
    Detect-RegistryMultiStringProperty -Path 'HKLM:\\SOFTWARE\Policies\Microsoft\Edge' -Name 'LegacySameSiteCookieBehaviorEnabledForDomainList' -Value $Value
.INPUTS
    System.String.
.OUTPUTS
    System.String. Retunrs 'Compliant' or 'NonCompliant'
.NOTES
    Created by Ioan Popovici
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    CM Compliance
.FUNCTIONALITY
    Registry MultiString Comparison
#>

    [cmdletbinding()]
    Param (
        [Parameter(Mandatory=$true,Position=0)]
        [ValidateNotNullorEmpty()]
        [string]$Path,
        [Parameter(Mandatory=$true,Position=1)]
        [ValidateNotNullorEmpty()]
        [string]$Name,
        [Parameter(Mandatory=$true,Position=2)]
        [ValidateNotNullorEmpty()]
        [string[]]$Value
    )

    Begin {
        $ErrorActionPreference = 'SilentlyContinue'
    }
    Process {
        Try {

            ## Get the registry property value
            $RegistryValue = Get-ItemProperty -Path $Path -Name $Name | Select-Object -ExpandProperty $Name

            If ($RegistryValue) {

                ## Compare values
                $EqualValues = Compare-Object -ReferenceObject $Value -DifferenceObject $RegistryValue -IncludeEqual -ExcludeDifferent

                ## Store result
                If ($EqualValues.Count -eq $Value.Count) { $Result = 'Compliant' } Else { $Result = 'NonCompliant' }
            }
            Else { $Result = 'NonCompliant' }

        }
        Catch {
            $Result = "Could not compare specified value [$Value] with registry [$($Path + '\' + $Name)] value [$RegistryValue]. `n$($_.Exception.Message)"
        }
        Finally {
            Write-Output $Result
        }
    }
    End {
        $ErrorActionPreference = 'Continue'
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

Try {
    $DetectMultistringValue = Detect-RegistryMultiStringProperty -Path $Path -Name $Name -Value $Value
    If ($DetectMultistringValue -eq 'NonCompliant' -and $Remediate) {
        $null = New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType 'MultiString' -Force
    }
}
Catch {
    Throw "Remediation failed. `n$($_.Exception.Message)"
}
Finally {
    Write-Output -InputObject $DetectMultistringValue
}

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================