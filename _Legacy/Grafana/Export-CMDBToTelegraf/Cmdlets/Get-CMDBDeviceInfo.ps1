#region Function Get-CMDBDeviceInfo
Function Get-CMDBDeviceInfo {
<#
.SYNOPSIS
    Gets device information.
.DESCRIPTION
    Gets device information from the SCCM database.
.PARAMETER Server
    Specifies the server name.
.PARAMETER Database
    Specifies the database name.
.PARAMETER CollectionID
    Specifies the CollectionID to query.
.EXAMPLE
    Get-CMDBDeviceInfo -Server 'SomeServer' -Database 'CM_SomeSiteCode' -CollectionID 'SomeCollectionID'
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://SCCM.Zone
.LINK
    https://SCCM.Zone/Git
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullorEmpty()]
        [Alias('Srv')]
        [string]$Server,
        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateNotNullorEmpty()]
        [Alias('Dbs')]
        [string]$Database,
        [Parameter(Mandatory = $true, Position = 2)]
        [ValidateNotNullorEmpty()]
        [Alias('CID')]
        [string]$CollectionID
    )
    Begin {

        ## Query definition
        [string]$Query =
        "
            DECLARE @CollectionID NVARCHAR(16)= '$CollectionID';
            DECLARE @UserSIDs NVARCHAR(16)= 'Disabled';
            SELECT
                Client_Version = Systems.Client_Version0
                , Count = COUNT(*)
            FROM fn_rbac_R_System(@UserSIDs) AS SYS
                LEFT JOIN fn_rbac_FullCollectionMembership(@UserSIDs) AS CollectionMembership ON CollectionMembership.ResourceID = Systems.ResourceID
            WHERE Systems.Client0 = 1
                AND CollectionMembership.CollectionID = @CollectionID
            GROUP BY
                Systems.Client_Version0
                , Systems.Client_Type0
            ORDER BY
                Systems.Client_Version0
                , Systems.Client_Type0
        "
    }
    Process {
        Try {

            ## Run SQL query
            [psobject]$Result = Invoke-Sqlcmd -Query $Query -Server $Server -Database $Database -ErrorAction 'Stop'
        }
        Catch {
            Write-Error -Message "Query Error: `n $_.ErrorMessage"
        }
        Finally {

            ## Output result
            Write-Output -InputObject $Result
        }
    }
    End {
    }
}
#endregion