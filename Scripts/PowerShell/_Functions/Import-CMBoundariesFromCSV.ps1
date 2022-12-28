
$Boundaries = Import-Csv -Path C:\Users\hlp_popovioa1\Desktop\AP-Boundaries.csv

$BoundaryRanges = Get-CimInstance -Namespace Root\SMS\site_AP2 -ClassName SMS_Boundary -Filter "BoundaryType = 3"
$BoundaryGroupMembers = Get-CimInstance -Namespace Root\SMS\site_AP2 -ClassName SMS_BoundaryGroupMembers
$BoundaryGroups = Get-CimInstance -Namespace Root\SMS\site_AP2 -ClassName SMS_BoundaryGroup

ForEach ($Boundary in $Boundaries) {
    ForEach ($BoundaryRange in $BoundaryRanges) {
        If ($Boundary.Subnet -eq $BoundaryRange.Value) {
            Write-Warning "Boundary '$($Boundary.Subnet)' already added '$($BoundaryRange.BoundaryID)'!"
            ForEach ($BoundaryGroupMember in $BoundaryGroupMembers) {
                If ($BoundaryGroupMember.BoundaryID -eq $BoundaryRange.BoundaryID) {
                    $BoundaryMembership = [pscustomObject]@{
                        BoundaryName = $BoundaryRange.DisplayName
                        BoundaryId   = $BoundaryGroupMember.BoundaryID
                        GroupName    = ($BoundaryGroups.Where({ $PsItem.GroupID -eq $BoundaryGroupMember.GroupID})).Name
                        GroupID      = $BoundaryGroupMember.GroupID
                    }
                    Write-Output -InputObject $BoundaryMembership
                }
            }
        }

    }
}



Write-Verbose -Message "$($PSitem.Description) $($PSitem.Subnet)" -Verbose
   New-CMBoundary -Name $($PSitem.Description) -Value $($PSitem.Subnet) -Type IPRange
 }