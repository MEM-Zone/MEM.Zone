#region  ConvertTo-HashtableFromPsCustomObject
Function ConvertTo-HashtableFromPsCustomObject {
<#
.SYNOPSIS
    Converts a custom object to a hashtable.
.DESCRIPTION
    Converts a custom powershell object to a hashtable.
.PARAMETER PsCustomObject
    Specifies the custom object to be converted.
.EXAMPLE
    ConvertTo-HashtableFromPsCustomObject -PsCustomObject $PsCustomObject
.EXAMPLE
    $PsCustomObject | ConvertTo-HashtableFromPsCustomObject
.INPUTS
    System.Object
.OUTPUTS
    System.Object
.NOTES
    Created Ioan Popovici
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/Issues
.COMPONENT
    Conversion
.FUNCTIONALITY
    Convert custom object to hashtable
#>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,Position=0)]
        [object]$Object
    )
    Begin {
        [hashtable]$Output = [ordered]@{}
    }
    Process {
        [object]$ObjectProperties = Get-Member -InputObject $Object -MemberType 'NoteProperty'
        ForEach ($Property in $ObjectProperties) { $Output.Add($Property.Name, $PsCustomObject.$($Property.Name)) }
        Write-Output -InputObject $Output
    }
}
#endregion