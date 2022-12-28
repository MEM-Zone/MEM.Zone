#region Function Get-Certificate
Function Get-Certificate {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true,ParameterSetName='Serial',Position=0)]
        [Alias('Serial')]
        [string]$SerialNumber,
        [Parameter(Mandatory=$true,ParameterSetName='Name',Position=1)]
        [Alias('Certificate')]
        [string]$Name,
        [Parameter(Mandatory=$false,ParameterSetName='Serial',Position=1)]
        [Parameter(Mandatory=$false,ParameterSetName='Name',Position=1)]
        [Alias('Location')]
        [string]$StoreLocation = 'LocalMachine',
        [Parameter(Mandatory=$true,ParameterSetName='Serial',Position=2)]
        [Parameter(Mandatory=$true,ParameterSetName='Name',Position=2)]
        [Alias('Store')]
        [string]$StoreName
    )
    Begin {

        ## Get the name of this function and write header
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header

    }
    Process {
        Try {

            ## Create certificate store object
            $Store = New-Object System.Security.Cryptography.X509Certificates.X509Store $StoreName, $StoreLocation -ErrorAction 'Stop'

            ## Open the certificate store as ReadOnly
            $Store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)

            ## Get the certificate details
            If ($($PSCmdlet.ParameterSetName) -eq 'Serial') {
                $Result = $Store.Certificates | Where-Object { $_.SerialNumber -eq $SerialNumber }  | Select-Object SerialNumber,Thumbprint,Subject,Issuer,NotBefore,NotAfter
            }
            Else {
                $Result = $Store.Certificates | Where-Object { $_.Subject -eq $("CN=" + $Name) } | Select-Object SerialNumber,Thumbprint,Subject,Issuer,NotBefore,NotAfter
            }
            ## Close the certificate Store
            $Store.Close()

            ## Return certificate details or a 'Certificate Selection - Failed!' string if the certificate does not exist
            If ($Result) {
                Write-Output -InputObject $Result
            }
            Else {
                Write-Log -Message 'No certificate found!' -Severity 3 -Source ${CmdletName}
                Throw 'No certificate found!'
            }
        }
        Catch {
            Write-Log -Message "Failed to get certificate! `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
            Throw "Failed to get certificate: $($_.Exception.Message)"
        }
    }
    End {
        Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
    }
}
#endregion