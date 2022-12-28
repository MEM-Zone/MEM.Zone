#region Function Resolve-Principal
Function Resolve-Principal {
<#
.SYNOPSIS
    Resolves a Principal or Principals.
.DESCRIPTION
    Resolves a Principal or Principals to SID or Principal Name.
.PARAMETER Principal
    Specifies the Principal to resolve.
.EXAMPLE
    Resolve-Principal -Principal 'CONTOSO\User'
.EXAMPLE
    Resolve-Principal -Principal 'CONTOSO\User', 'CONTOSO\Group', 'BUILTIN\Administrators'
.EXAMPLE
    Resolve-Principal -Principal 'S-1-5-21-1234567890-1234567890-1234567890-500'
.EXAMPLE
    Resolve-Principal -Principal 'S-1-5-21-1234567890-1234567890-1234567890-500', 'S-1-5-21-1234567890-1234567890-1234567890-501'
.INPUTS
    System.Array
.OUTPUTS
    System.Object
    System.Exception
.NOTES
    Created by Ioan Popovici
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    Security Principal
.FUNCTIONALITY
    Resolves a Principal or Principals to SID or Principal Name.
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullorEmpty()]
        [Alias('SecurityPrincipal')]
        [string[]]$Principal
    )
    Begin {

        ## Set SID regex match Pattern
        [regex]$Pattern = 'S-\d-(?:\d+-){1,14}\d+'
    }
    Process {
        Try {

            ## Resolve Principal
            $Output = ForEach ($PrincipalItem in $Principal) {
                Try {
                    #  Set Principal type
                    [string]$SIDMatch = (Select-String -Pattern $Pattern -InputObject $PrincipalItem).Matches.Value
                    [string]$PrincipalType = If ([string]::IsNullOrEmpty($SIDMatch)) { 'PrincipalName' } Else { 'PrincipalSID' }
                    #  Resolve Principal
                    Switch ($PrincipalType) {
                        'PrincipalName' {
                            $NTAccountObject = New-Object System.Security.Principal.NTAccount($PrincipalItem)
                            $NTAccountObject.Translate([System.Security.Principal.SecurityIdentifier]).Value
                            Break
                        }
                        'PrincipalSID' {
                            $SIDObject = New-Object System.Security.Principal.SecurityIdentifier($PrincipalItem.Replace('*',''))
                            $SIDObject.Translate([Security.Principal.NTAccount]).Value
                            Break
                        }
                    }
                }
                Catch {

                    ## Return custom error. The error handling is done here in order not to break the ForEach loop and allow it to continue.
                    $Exception     = [Exception]::new($PsItem.Exception.Message)
                    $ExceptionType = [Management.Automation.ErrorCategory]::ObjectNotFound
                    $ErrorRecord   = [System.Management.Automation.ErrorRecord]::new($Exception, $PsItem.FullyQualifiedErrorId, $ExceptionType, $PrincipalItem)
                    $PSCmdlet.WriteError($ErrorRecord)
                }
            }
        }
        Catch {
            $PSCmdlet.WriteError()
        }
        Finally {
            Write-Output -InputObject $Output
        }
    }
}
#endregion