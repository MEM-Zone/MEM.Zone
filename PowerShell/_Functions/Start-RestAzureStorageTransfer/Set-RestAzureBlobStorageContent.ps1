#region Function Set-RestAzureBlobStorageContent
Function Set-RestAzureBlobStorageContent {
<#
.SYNOPSIS
    Uploads a local file to an Azure Storage Blob.
.DESCRIPTION
    Uploads a local file to an Azure Storage Blob using REST API.
.PARAMETER File
    Specifies the file to upload.
.PARAMETER Url
    Specifies the blob URL.
.PARAMETER SasToken
    Specifies the azure blob SAS token. Specifies the azure blob SAS token. If this parameter is not specified, no authentication is used.
.EXAMPLE
    Set-RestAzureBlobStorageContent -File 'C:\FileToUpload.txt' '-Url 'https://<storageaccount>.file.core.windows.net/SomeBlob>' -SasToken 'SomeAccessToken'
.INPUTS
    None.
.OUTPUTS
    System.Object.
.NOTES
    This is an internal script function and should typically not be called directly.
    Credit to Roger Zander
.LINK
    https://rzander.azurewebsites.net/upload-file-to-azure-blob-storage-with-powershell/
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.COMPONENT
    Azure File Storage Rest API
.FUNCTIONALITY
    Upload local file to Azure Storage
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = 'File Path:', Position = 0)]
        [ValidateNotNullorEmpty()]
        [Alias('Path')]
        [string]$File,
        [Parameter(Mandatory = $true, HelpMessage = 'Share URL:', Position = 1)]
        [ValidateNotNullorEmpty()]
        [Alias('Location')]
        [string]$Url,
        [Parameter(Mandatory = $false, HelpMessage = 'Share SAS Token:', Position = 2)]
        [Alias('Sas')]
        [string]$SasToken
    )

    Begin {

        ## Check if no security token is provided
        $IsSecure = [boolean](-not [string]::IsNullOrEmpty($SasToken))

        ## Remove the '?' from the SAS string if needed
        If ($SasToken[0] -eq '?') { $SasToken = $SasToken -replace ('\?', '') }

        ## Declare Headers
        $Headers = @{ 'x-ms-blob-type' = 'BlockBlob' }
    }
    Process {
        Try {

            ## Get the file info
            $FileInfo = Get-Item -Path $File -ErrorAction 'Stop'
            $FileName = $FileInfo.Name

            ## Build URI
            [string]$Uri = If ($IsSecure) { '{0}/{1}?{2}' -f ($Url, $FileName, $SasToken) } Else { '{0}/{1}' -f ($Url, $FileName) }

            ## Invoke REST API
            $Response = Invoke-WebRequest -Uri $Uri -Method 'Put' -Headers $Headers -InFile $File

            ## Build the output object
            $Output = [pscustomobject]@{
                'Name'     = $FileName
                'Size(KB)' = '{0:N2}' -f ($FileInfo.Length / 1KB)
                'Url'      = $Url
                'Status'   = $Response.StatusDescription
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