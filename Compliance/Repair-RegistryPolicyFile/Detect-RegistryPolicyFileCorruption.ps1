<#
.SYNOPSIS
    Repairs the local registry policy file.
.DESCRIPTION
    Repairs the local registry policy file if corruption is detected.
.PARAMETER Path
    Specifies the Path to the policy file.
.EXAMPLE
    Repair-RegistryPolicyFile
.EXAMPLE
    Repair-RegistryPolicyFile -Path 'C:\Windows\System32\GroupPolicy\Machine\Registry.pol'
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
    Repair Registry Policy File
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
    [string]$Path = $(Join-Path $env:WinDir 'System32\GroupPolicy\Machine\Registry.pol')
)

#endregion
##*=============================================
##* END VARIABLE DECLARATION
##*=============================================

##*=============================================
##* FUNCTION LISTINGS
##*=============================================
#region FunctionListings

#region Test-RegistryPolicyFile
Function Test-RegistryPolicyFile {
<#
.SYNOPSIS
    Tests the local registry policy file.
.DESCRIPTION
    Tests the local registry policy file for corruption.
.PARAMETER Path
    Specifies the Path to the policy file.
.EXAMPLE
    Test-RegistryPolicyFile
.EXAMPLE
    Test-RegistryPolicyFile -Path 'C:\Windows\System32\GroupPolicy\Machine\Registry.pol'
.INPUTS
    System.String.
.OUTPUTS
    System.String.
.NOTES
    Modified by Ioan Popovici
.LINK
    https://itinlegal.wordpress.com/2017/09/09/psa-locating-badcorrupt-registry-pol-files/
.LINK
    https://MEM.Zone/
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    CM
.FUNCTIONALITY
    Test Registry Policy File
#>
    [cmdletbinding()]
    Param (
        [Parameter(Mandatory=$false)]
        [string]$Path = $(Join-Path $env:WinDir 'System32\GroupPolicy\Machine\Registry.pol')
    )
    Begin {

        ## Declare health file header value
        [Byte[]]$HealthyFileHeader = @(80, 82, 101, 103)
    }
    Process {
        Try {

            ## Check if registry.pol file exists
            [bool]$RegistryPolExists = Test-Path -Path $Path -PathType 'Leaf'
            If($RegistryPolExists) {

                ## Get Registry file header
                [Byte[]]$FileHeader = Get-Content -Encoding 'Byte' -Path $Path -TotalCount 4

                ## Compare file header with reference
                $FileIsCorrupt = Compare-Object -ReferenceObject $HealthyFileHeader -DifferenceObject $FileHeader
                If($FileIsCorrupt) { $Result = 'NonCompliant' } Else { $Result = 'Compliant' }
            }
            Else { $Result = "Registry.pol [$Path] not found!" }
        }
        Catch {
            $Result = "Could not test Registry.pol [$Path]. `n$($_.Exception.Message)"
        }
        Finally {
            Write-Output $Result
        }
    }
    End {}
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

## Check for corruption. Compliance Rule must equal 'Compliant'
$TestRegistryPolicyFile = Test-RegistryPolicyFile -Path $Path -ErrorAction 'Stop'
Write-Output -InputObject $TestRegistryPolicyFile

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================
