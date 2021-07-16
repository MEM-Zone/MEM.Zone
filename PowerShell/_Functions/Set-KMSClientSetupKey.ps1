#region Function Set-KMSClientSetupKey
Function Set-KMSClientSetupKey {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true,Position=0)]
        [Alias('KMSKey')]
        [string]$Key,
        [Parameter(Mandatory=$false,Position=1)]
        [Alias('OS')]
        [string]$OSName,
        [Parameter(Mandatory=$false,Position=2)]
        [Alias('ato')]
        [switch]$Activate
    )
    Begin {

        ## Get the name of this function and write header
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header

        ## Initialize variables
        [bool]$ShouldRun = $true
    }
    Process {
        Try {

            ## Check if Local OS Name matches the provided name
            If ($OSName) {
                #  Set $ShouldRun
                [string]$InstalledOSName = $(Get-CimInstance -ClassName 'Win32_OperatingSystem' -ErrorAction 'Stop').Caption
                If ($InstalledOSName -eq  $OSName) {
                    $ShouldRun = $false
                    Write-Log -Message "OS name [$OSName] match, skipping KMS client setup key step." -Severity 1 -Source ${CmdletName}
                }
            }

            ## Set KMS client setup key and activate
            If ($ShouldRun) {
                #  Set KMS key
                [wmi]$KMSObject = Get-WmiObject -Class 'SoftwareLicensingService' -ErrorAction 'Stop'
                $null = $KMSObject.InstallProductKey($Key)
                Write-Log -Message "KMS client setup key [$Key] set!" -Severity 1 -Source ${CmdletName}
                #  Activate OS
                If ($Activate) {
                    $null = $KMSObject.RefreshLicenseStatus()
                    Write-Log -Message 'Activation successful!' -Severity 1 -Source ${CmdletName}
                }
            }
        }
        Catch {
            Write-Log -Message "Failed to set or activate KMS client setup key [$Key]! `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
        }
    }
    End {
        Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
    }
}
#endregion