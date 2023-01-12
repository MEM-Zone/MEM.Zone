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
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [pscustomobject]$PsCustomObject
    )
    Begin {

        ## Preservers hashtable parameter order
        [System.Collections.Specialized.OrderedDictionary]$Output = @{}
    }
    Process {

        ## The '.PsObject.Members' method preservers the order of the members, Get-Member does not.
        [object]$ObjectProperties = $PsCustomObject.PsObject.Members | Where-Object -Property 'MemberType' -EQ 'NoteProperty'
        ForEach ($Property in $ObjectProperties) { $Output.Add($Property.Name, $PsCustomObject.$($Property.Name)) }
        Write-Output -InputObject $Output
    }
}
#endregion