#region Function Get-AzureFileStorageItem
Function Get-AzureFileStorageItem {
<#
.SYNOPSIS
    Lists directories and files for an azure file storage path.
.DESCRIPTION
    Lists directories and files for an azure file storage path using REST API.
.PARAMETER Url
    Specifies the azure share URL.
.PARAMETER SasToken
    Specifies the azure share SAS token.
.EXAMPLE
    Get-AzureFileStorageItem -Url 'https://<storageaccount>.file.core.windows.net/<SomeShare/SomeFolder>' -Sas 'SomeAccessToken'
.INPUTS
    None.
.OUTPUTS
    System.Array.
.NOTES
    This is an internal script function and should typically not be called directly.
    Credit to Roger Zander
.LINK
    https://rzander.azurewebsites.net/download-files-from-azure-blob-storage-with-powershell/
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.COMPONENT
    Azure File Storage Rest API
.FUNCTIONALITY
    List File Items
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true,HelpMessage='Share URL:',Position=0)]
        [ValidateNotNullorEmpty()]
        [Alias('Location')]
        [string]$Url,
        [Parameter(Mandatory=$true,HelpMessage='Share SAS Token:',Position=1)]
        [ValidateNotNullorEmpty()]
        [Alias('Sas')]
        [string]$SasToken
    )

    Begin {

        ## Remove the '?' from the SAS string if needed
        If ($SasToken[0] -eq '?') { $SasToken = $SasToken -replace ('\?', '') }

        ## Set file name regex pattern
        [regex]$RegexPattern = '[\w]+\.[A-Za-z0-9]*$'
    }
    Process {
        Try {

            ## Extract file name from the URL if it exist
            $FileName = $($Url | Select-String -AllMatches -Pattern $RegexPattern | Select-Object -ExpandProperty 'Matches').Value

            ## If URL is a file, get the properties
            If (-not [string]::IsNullOrEmpty($FileName)) {
                #  Build URI
                [string]$Uri = '{0}?{1}' -f ($Url, $SasToken)
                #  Invoke REST API
                $File = Invoke-WebRequest -Uri $Uri -Method 'Head' -UseBasicParsing
                #  Build the output object
                $AzureFileList = [pscustomobject]@{
                    'Name'     = $FileName
                    'Size(KB)' = '{0:N2}' -f ($File.Headers.'Content-Length' / 1KB)
                    'Url'      = $Url
                }
            }

            ## Else list the directory content
            Else {
                #  Build URI
                [string]$Uri = '{0}/?{1}&{2}' -f ($Url, 'restype=directory&comp=list', $SasToken)
                #  Invoke REST API
                $Response = Invoke-RestMethod -Uri $Uri -Method 'Get' -Verbose:$false
                #  Cleanup response and convert to XML
                $Xml = [xml]$Response.Substring($Response.IndexOf('<'))
                #  Get the file objects
                $Files = $Xml.ChildNodes.Entries.File
                #  Build the output object
                $AzureFileList = ForEach ($File in $Files) {
                    [pscustomobject]@{
                        'Name'     = $File.Name
                        'Size(KB)' = '{0:N2}' -f ($File.Properties.'Content-Length' / 1KB)
                        'Url'      = '{0}/{1}' -f ($Url, $File.Name)
                    }
                }
            }
        }
        Catch {
            $PSCmdlet.ThrowTerminatingError($PSItem)
        }
        Finally {
            Write-Output -InputObject $AzureFileList
        }
    }
    End {
    }
}
#endregion