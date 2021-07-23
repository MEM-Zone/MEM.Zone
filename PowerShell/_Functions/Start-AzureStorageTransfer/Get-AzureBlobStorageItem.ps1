#region Function Get-AzureBlobStorageItem
Function Get-AzureBlobStorageItem {
<#
.SYNOPSIS
    Lists blobs for an azure blob storage path.
.DESCRIPTION
    Lists blobs for an azure blob storage path using REST API.
.PARAMETER Url
    Specifies the azure share URL.
.PARAMETER SasToken
    Specifies the azure share SAS token.
.EXAMPLE
    Get-AzureBlobStorageItem -Url 'https://<storageaccount>.blob.core.windows.net/<Container>' -Sas 'SomeAccessToken'
.EXAMPLE
    Get-AzureBlobStorageItem -Url 'https://<storageaccount>.blob.core.windows.net/<Container>/<blob>' -Sas 'SomeAccessToken'
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
    Azure Blob Storage Rest API
.FUNCTIONALITY
    List Blob Items
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

            ## Extract blob name from the URL if it exist
            $BlobName = $($Url | Select-String -AllMatches -Pattern $RegexPattern | Select-Object -ExpandProperty 'Matches').Value

            ## If URL is a single blob, get the properties
            If (-not [string]::IsNullOrEmpty($BlobName)) {
                #  Build URI
                [string]$Uri = '{0}?{1}' -f ($Url, $SasToken)
                #  Invoke REST API
                $Blob = Invoke-WebRequest -Uri $Uri -Method 'Head' -UseBasicParsing
                #  Build the output object
                $AzureBlobList = [pscustomobject]@{
                    'Name'     = $BlobName
                    'Size(KB)' = '{0:N2}' -f ($Blob.Headers.'Content-Length' / 1KB)
                    'Url'      = $Url
                }
            }

            ## Else list the directory content
            Else {
                #  Build URI
                [string]$Uri = '{0}?{1}&{2}' -f ($Url, 'restype=container&comp=list', $SasToken)
                #  Invoke REST API
                $Response = Invoke-RestMethod -Uri $Uri -Method 'Get' -Verbose:$false
                #  Cleanup response and convert to XML
                $Xml = [xml]$Response.Substring($Response.IndexOf('<'))
                #  Get the file objects
                $Blobs = $Xml.ChildNodes.Blobs.Blob
                #  Build the output object
                $AzureBlobList = ForEach ($Blob in $Blobs) {
                    [pscustomobject]@{
                        'Name'     = $Blob.Name
                        'Size(KB)' = '{0:N2}' -f ($Blob.Properties.'Content-Length' / 1KB)
                        'Url'      = '{0}/{1}' -f ($Url, $Blob.Name)
                    }
                }
            }
        }
        Catch {
            $PSCmdlet.ThrowTerminatingError($PSItem)
        }
        Finally {
            Write-Output -InputObject $AzureBlobList
        }
    }
    End {
    }
}
#endregion