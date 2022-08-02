#region Function Get-RestAzureBlobStorageItem
Function Get-RestAzureBlobStorageItem {
    <#
.SYNOPSIS
    Lists blobs for an azure blob storage path.
.DESCRIPTION
    Lists blobs for an azure blob storage path using REST API.
.PARAMETER Url
    Specifies the azure blob URL.
.PARAMETER SasToken
    Specifies the azure blob SAS token. If this parameter is not specified, no authentication is used.
.EXAMPLE
    Get-RestAzureBlobStorageItem -Url 'https://<storageaccount>.blob.core.windows.net/<Container>' -SasToken 'SomeAccessToken'
.EXAMPLE
    Get-RestAzureBlobStorageItem -Url 'https://<storageaccount>.blob.core.windows.net/<Container>/<blob>' -SasToken 'SomeAccessToken'
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
        [Parameter(Mandatory = $true, HelpMessage = 'Blob URL:', Position = 0)]
        [ValidateNotNullorEmpty()]
        [Alias('Location')]
        [string]$Url,
        [Parameter(Mandatory = $false, HelpMessage = 'Blob SAS Token:', Position = 1)]
        [Alias('Sas')]
        [string]$SasToken
    )

    Begin {

        ## Check if no security token is provided
        $IsSecure = [boolean](-not [string]::IsNullOrEmpty($SasToken))

        ## Remove the '?' from the SAS string if needed
        If ($SasToken[0] -eq '?') { $SasToken = $SasToken -replace ('\?', '') }

        ## Set file name regex pattern
        [regex]$RegexPattern = '[^\/]+\.[A-Za-z0-9]*$'
    }
    Process {
        Try {

            ## Extract blob name from the URL if it exist
            $BlobName = $($Url | Select-String -AllMatches -Pattern $RegexPattern | Select-Object -ExpandProperty 'Matches').Value

            ## If URL is a single blob, get the properties
            If (-not [string]::IsNullOrEmpty($BlobName)) {

                ## Build URI
                [string]$Uri = If ($IsSecure) { '{0}?{1}' -f ($Url, $SasToken) } Else { $Url }

                ## Invoke REST API
                $Response = Invoke-WebRequest -Uri $Uri -Method 'Head' -UseBasicParsing

                ## Build the output object
                $Output = [pscustomobject]@{
                    'Name'     = $BlobName
                    'Size(KB)' = '{0:N2}' -f ($Response.Headers.'Content-Length' / 1KB)
                    'Url'      = $Url
                }
            }

            ## Else list the directory content
            Else {

                ## Build URI
                [string]$Uri = If ($IsSecure) { '{0}?{1}&{2}' -f ($Url, 'restype=container&comp=list', $SasToken) } Else { '{0}?{1}' -f ($Url, 'restype=container&comp=list') }

                ## Invoke REST API
                $Response = Invoke-RestMethod -Uri $Uri -Method 'Get' -Verbose:$false

                ## Cleanup response and convert to XML
                $Xml = [xml]$Response.Substring($Response.IndexOf('<'))

                ## Get the file objects
                $Blobs = $Xml.ChildNodes.Blobs.Blob

                ## Build the output object
                $Output = ForEach ($Blob in $Blobs) {
                    [pscustomobject]@{
                        'Name'     = $($Blob.Name | Split-Path -Leaf)
                        'Size(KB)' = '{0:N2}' -f ($Blob.Properties.'Content-Length' / 1KB)
                        'Url'      = '{0}/{1}' -f ($Url, $Blob.Name)
                    }
                }
            }
        }
        Catch {
            $PSCmdlet.WriteError($PSItem)
        }
        Finally {
            Write-Output -InputObject $Output
        }
    }
    End {
    }
}
#endregion