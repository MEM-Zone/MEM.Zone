<#
.SYNOPSIS
    Starts an azure storage transfer.
.DESCRIPTION
    Starts an azure blob or file storage transfer using bits or outputs a single blob or file content to the pipeline.
.PARAMETER Url
    Specifies the azure containter/blob/share/path URL.
.PARAMETER SasToken
    Specifies the azure blob/container/share SAS security token.
.PARAMETER Path
    Specifies the destination path for the dowloaded items.
.PARAMETER Force
    Overwrites the existing blob/file even if it has the same name and size. I can't think why this would be needed but I added it anyway.
.PARAMETER ContentOnly
    This switch specifies return the content of the blob/file to the pipeline if the azure URL points to a single blob/file.
.EXAMPLE
    Start-AzureBlobStorageTransfer -Url 'https://<storageaccount>.blob.core.windows.net/<Containter>' -SasToken '<AccessToken>' -Path 'D:\Temp' -Force
.EXAMPLE
    Start-AzureBlobStorageTransfer -Url 'https://<storageaccount>.blob.core.windows.net/<Container>/<Blob>' -SasToken 'SomeAccessToken' -ContentOnly
.EXAMPLE
    Start-AzureFileStorageTransfer -Url 'https://<storageaccount>.file.core.windows.net/<Share>/<FolderPath>' -SasToken '<AccessToken>' -Path 'D:\Temp' -Force
.EXAMPLE
    Start-AzureFileStorageTransfer -Url 'https://<storageaccount>.file.core.windows.net/<Share/<FilePath>' -SasToken '<AccessToken>' -ContentOnly
.INPUTS
    None.
.OUTPUTS
    System.Array.
    System.String.
.NOTES
    If the blob/file is already present and has the same size, Operation will return 'Skipped'.
    If the blob/file is already present and has the same size, but 'Force' parameter has been specified, Operation will return 'Overwritten'.
.NOTES
    Credit to Roger Zander.
    Created by Ioan Popovici.
    This script can be called directly.
.LINK
    https://MEM.Zone/Start-AzureStorageTransfer
.LINK
    https://MEM.Zone/Start-AzureStorageTransfer-CHANGELOG
.LINK
    https://MEM.Zone/Start-AzureStorageTransfer-GIT
.LINK
    https://rzander.azurewebsites.net/download-files-from-azure-blob-storage-with-powershell/
.COMPONENT
    Azure Storage Rest API
.FUNCTIONALITY
    Downloads items to local storage
#>

[CmdletBinding()]
Param (
    [Parameter(Mandatory=$true,ParameterSetName='GetItems',HelpMessage='Item URL:',Position=0)]
    [Parameter(Mandatory=$true,ParameterSetName='GetContent',HelpMessage='Item URL:',Position=0)]
    [ValidateNotNullorEmpty()]
    [Alias('Location')]
    [string]$Url,
    [Parameter(Mandatory=$true,ParameterSetName='GetItems',HelpMessage='Item/Share SAS Token:',Position=1)]
    [Parameter(Mandatory=$true,ParameterSetName='GetContent',HelpMessage='Item/Share SAS Token:',Position=1)]
    [ValidateNotNullorEmpty()]
    [Alias('Sas')]
    [string]$SasToken,
    [Parameter(Mandatory=$true,ParameterSetName='GetItems',HelpMessage='Local Download Path:',Position=2)]
    [Parameter(Mandatory=$false,ParameterSetName='GetContent',HelpMessage='Local Download Path:',Position=2)]
    [Alias('Destination')]
    [string]$Path,
    [Parameter(Mandatory=$false,ParameterSetName='GetItems')]
    [Alias('Overwrite')]
    [switch]$Force,
    [Parameter(Mandatory=$false,ParameterSetName='GetContent')]
    [Alias('GetContent')]
    [switch]$ContentOnly
)

## Set script requirements
#Requires -Version 3.0

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

#endregion
##*=============================================
##* END VARIABLE DECLARATION
##*=============================================

##*=============================================
##* FUNCTION LISTINGS
##*=============================================
#region FunctionListings

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

#region Function Get-RestAzureFileStorageItem
Function Get-RestAzureFileStorageItem {
<#
.SYNOPSIS
    Lists directories and files for a azure file storage path.
.DESCRIPTION
    Lists directories and files for a azure file storage path using REST API.
.PARAMETER Url
    Specifies the azure share URL.
.PARAMETER SasToken
    Specifies the azure share SAS token. Specifies the azure share SAS token. If this parameter is not specified, no authentication is used.
.EXAMPLE
    Get-RestAzureFileStorageItem -Url 'https://<storageaccount>.file.core.windows.net/<SomeShare/SomeFolder>' -SasToken 'SomeAccessToken'
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
    List Azure File Storage Items
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = 'Share URL:', Position = 0)]
        [ValidateNotNullorEmpty()]
        [Alias('Location')]
        [string]$Url,
        [Parameter(Mandatory = $false, HelpMessage = 'Share SAS Token:', Position = 1)]
        [ValidateNotNullorEmpty()]
        [Alias('Sas')]
        [string]$SasToken
    )

    Begin {

        ## Check if no security token is provided
        $IsSecure = [boolean](-not [string]::IsNullOrEmpty($SasToken))

        ## Remove the '?' from the SAS string if needed
        If ($SasToken[0] -eq '?') { $SasToken = $SasToken -replace ('\?', '') }

        ## Set file name regex pattern
        [regex]$RegexPattern = '[^\/]+\.[A-Za-z0-9]{1,3}$'
    }
    Process {
        Try {

            ## Extract file name from the URL if it exist
            $FileName = $($Url | Select-String -AllMatches -Pattern $RegexPattern | Select-Object -ExpandProperty 'Matches').Value

            ## If URL is a file, get the properties
            If (-not [string]::IsNullOrEmpty($FileName)) {

                ## Build URI
                [string]$Uri = If ($IsSecure) { '{0}?{1}' -f ($Url, $SasToken) } Else { $Url }

                ## Invoke REST API
                $Response = Invoke-WebRequest -Uri $Uri -Method 'Head' -UseBasicParsing

                ##  Build the output object
                $Output = [pscustomobject]@{
                    'Name'     = $FileName
                    'Size(KB)' = '{0:N2}' -f ($Response.Headers.'Content-Length' / 1KB)
                    'Url'      = $Url
                }
            }

            ## Else list the directory content
            Else {

                ## Build URI
                [string]$Uri = If ($IsSecure) { '{0}?{1}&{2}' -f ($Url, 'restype=directory&comp=list', $SasToken) } Else { '{0}?{1}' -f ($Url, 'restype=directory&comp=list') }

                ## Invoke REST API
                $Response = Invoke-RestMethod -Uri $Uri -Method 'Get' -Verbose:$false

                ## Cleanup response and convert to XML
                $Xml = [xml]$Response.Substring($Response.IndexOf('<'))

                ## Get the file objects
                $Files = $Xml.ChildNodes.Entries.File

                ## Build the output object
                $Output = ForEach ($File in $Files) {
                    [pscustomobject]@{
                        'Name'     = $File.Name
                        'Size(KB)' = '{0:N2}' -f ($File.Properties.'Content-Length' / 1KB)
                        'Url'      = '{0}/{1}' -f ($Url, $File.Name)
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

#region Function Start-RestAzureBlobStorageTransfer
Function Start-RestAzureBlobStorageTransfer {
<#
.SYNOPSIS
    Starts an azure blob storage transfer.
.DESCRIPTION
    Starts an azure blob storage transfer using bits or outputs a single blob content to the pipeline.
.PARAMETER Url
    Specifies the azure containter URL.
.PARAMETER SasToken
    Specifies the azure blob/container SAS security token.
.PARAMETER Path
    Specifies the destination path for the dowloaded blobs.
.PARAMETER Force
    Overwrites the existing blob even if it has the same name and size. I can't think why this would be needed but I added it anyway.
.PARAMETER ContentOnly
    This switch specifies return the content of the blob to the pipeline if the azure URL points to a single blob.
.EXAMPLE
    Start-RestAzureBlobStorageTransfer -Url 'https://<storageaccount>.blob.core.windows.net/<Containter>' -SasToken '<AccessToken>' -Path 'D:\Temp' -Force
.EXAMPLE
    Start-RestAzureBlobStorageTransfer -Url 'https://<storageaccount>.blob.core.windows.net/<Container>/<Blob>' -SasToken 'SomeAccessToken' -ContentOnly
.INPUTS
    None.
.OUTPUTS
    System.Array.
    System.String.
.NOTES
    If the blob is already present and has the same size, Operation will return 'Skipped'.
    If the blob is already present and has the same size, but 'Force' parameter has been specified, Operation will return 'Overwritten'.
    This is an internal script function and should typically not be called directly.
    Credit to Roger Zander
.LINK
    https://rzander.azurewebsites.net/download-files-from-azure-blob-storage-with-powershell/
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    Azure Blob Storage Rest API
.FUNCTIONALITY
    Downloads to Local Storage
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, ParameterSetName = 'GetBlobs', HelpMessage = 'Containter or Blob URL:', Position = 0)]
        [Parameter(Mandatory = $true, ParameterSetName='GetContent', HelpMessage = 'Containter or Blob URL:', Position = 0)]
        [ValidateNotNullorEmpty()]
        [Alias('Location')]
        [string]$Url,
        [Parameter(Mandatory = $true, ParameterSetName = 'GetBlobs', HelpMessage = 'Containter or Blob SAS Token:', Position = 1)]
        [Parameter(Mandatory = $true, ParameterSetName = 'GetContent', HelpMessage = 'Containter or Blob SAS Token:', Position = 1)]
        [ValidateNotNullorEmpty()]
        [Alias('Sas')]
        [string]$SasToken,
        [Parameter(Mandatory = $true, ParameterSetName = 'GetBlobs', HelpMessage = 'Local Download Path:', Position = 2)]
        [Parameter(Mandatory = $false, ParameterSetName = 'GetContent', HelpMessage = 'Local Download Path:', Position = 2)]
        [Alias('Destination')]
        [string]$Path,
        [Parameter(Mandatory = $false, ParameterSetName = 'GetBlobs')]
        [Alias('Overwrite')]
        [switch]$Force,
        [Parameter(Mandatory = $false, ParameterSetName = 'GetContent')]
        [Alias('GetContent')]
        [switch]$ContentOnly
    )
    Begin {

        ## Check if no security token is provided
        $IsSecure = [boolean](-not [string]::IsNullOrEmpty($SasToken))

        ## Remove the '?' from the SAS string if needed
        If ($SasToken[0] -eq '?') { $SasToken = $SasToken -replace ('\?', '') }
    }
    Process {
        Try {

            ## Get azure blob list
            $AzureBlobList = Get-RestAzureBlobStorageItem -Url $Url -Sas $SasToken

            ## If $GetContent is specified and there is just one blob, get blob content.
            If ($PSCmdlet.ParameterSetName -eq 'GetContent') {

                ## Check if just one item is found
                If (($AzureBlobList | Measure-Object).Count -eq 1) {

                    ## Build URI
                    [string]$Uri = If ($IsSecure) { '{0}?{1}' -f ($Url, $SasToken) } Else { $Url }

                    ## Invoke REST API
                    $Response = Invoke-RestMethod -Uri $Uri -Method 'Get' -UseBasicParsing -ErrorAction 'Continue'

                    ## Check if last operation was successful and set error message
                    [boolean]$ShowError = If ($?) { $false; $ErrorMessage = $null } Else { $true; $ErrorMessage = -join ('Error: ', $Error[0].Exception.Message) };

                    ## Build output object
                    $Output = [pscustomobject]@{
                        'Name'      = $AzureBlobList.Name
                        'Size(KB)'  = '{0:N2}' -f ($AzureBlobList.'Size(KB)')
                        'Url'       = $AzureBlobList.Url
                        'Operation' = Switch ($true) {
                            $ShowError { $ErrorMessage; Break }
                            Default    { 'Downloaded' }
                        }
                        'Content'   = $Response
                    }
                }
                Else { Throw 'Cannot get content for more than one blob at a time!' }
            }
            Else {

                ## Get local file list
                $LocalBlobList = Get-ChildItem -Path $Path -File -ErrorAction 'SilentlyContinue' | Select-Object -Property 'Name', @{
                    Name = 'Size(KB)'; Expression = {'{0:N2}' -f ($PSItem.Length / 1KB)}
                }

                ## Create destination folder
                New-Item -Path $Path -ItemType 'Directory' -ErrorAction 'SilentlyContinue' | Out-Null

                ## Process blobs one by one
                $Output = ForEach ($Blob in $AzureBlobList) {

                    ## If the blob is already present and the same size, set the 'Skip' flag.
                    [psobject]$LocalBlobLookup = $LocalBlobList | Where-Object { $_.Name -eq $Blob.Name -and $_.'Size(KB)' -eq $Blob.'Size(KB)' } | Select-Object -Property 'Name'
                    [boolean]$SkipBlob = [boolean](-not [string]::IsNullOrEmpty($LocalBlobLookup))

                    ## Assemble Destination and URI
                    [string]$Destination = Join-Path -Path $Path -ChildPath $Blob.Name
                    [string]$Uri = If ($IsSecure) { '{0}?{1}' -f ($Blob.Url, $SasToken) } Else { $Blob.Url }
                    [boolean]$Overwite = $Force -and $SkipBlob

                    ## Tansfer blob using BITS
                    If (-not $SkipBlob -or $Force) { Start-BitsTransfer -Source $Uri -Destination $Destination -HttpMethod 'Get' -Description $Destination -DisplayName $Blob.Url -ErrorAction 'Continue' }

                    ## Check if last operation was successful and set error message
                    [boolean]$ShowError = If ($?) { $false; $ErrorMessage = $null } Else { $true; $ErrorMessage = -join ('Error: ', $Error[0].Exception.Message) };

                    ## Build output object
                    [pscustomobject]@{
                        'Name'      = $Blob.Name
                        'Size(KB)'  = '{0:N2}' -f ($Blob.'Size(KB)')
                        'Url'       = $Blob.Url
                        'Path'      = $Path
                        'Operation' = Switch ($true) {
                            $ShowError { $ErrorMessage; Break }
                            $Overwite  { 'Overwritten'; Break }
                            $SkipBlob  { 'Skipped' ; Break }
                            Default    { 'Downloaded' }
                        }
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

#region Function Start-RestAzureFileStorageTransfer
Function Start-RestAzureFileStorageTransfer {
<#
.SYNOPSIS
    Starts an azure file storage transfer.
.DESCRIPTION
    Starts an azure file storage transfer using bits or outputs a single file content to the pipeline.
.PARAMETER Url
    Specifies the azure share URL.
.PARAMETER SasToken
    Specifies the azure share SAS security token.
.PARAMETER Path
    Specifies the destination path for the dowloaded files.
.PARAMETER Force
    Overwrites the existing file even if it has the same name and size. I can't think why this would be needed but I added it anyway.
.PARAMETER ContentOnly
    This switch specifies return the content of the file to the pipeline if the azure share URL points to a single file.
.EXAMPLE
    Start-RestAzureFileStorageTransfer -Url 'https://<storageaccount>.file.core.windows.net/<Share>/<FolderPath>' -SasToken '<AccessToken>' -Path 'D:\Temp' -Force
.EXAMPLE
    Start-RestAzureFileStorageTransfer -Url 'https://<storageaccount>.file.core.windows.net/<Share/<FilePath>' -SasToken '<AccessToken>' -ContentOnly
.INPUTS
    None.
.OUTPUTS
    System.Array.
    System.String.
.NOTES
    If the file is already present and has the same size, Operation will return 'Skipped'.
    If the file is already present and has the same size, but 'Force' parameter has been specified, Operation will return 'Overwritten'.
    This is an internal script function and should typically not be called directly.
    Credit to Roger Zander
.LINK
    https://rzander.azurewebsites.net/download-files-from-azure-blob-storage-with-powershell/
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    Azure File Storage Rest API
.FUNCTIONALITY
    Downloads to Local Storage
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, ParameterSetName = 'GetFiles', HelpMessage = 'Share URL:', Position = 0)]
        [Parameter(Mandatory = $true, ParameterSetName = 'GetContent',HelpMessage = 'Share URL:', Position = 0)]
        [ValidateNotNullorEmpty()]
        [Alias('Location')]
        [string]$Url,
        [Parameter(Mandatory = $true, ParameterSetName = 'GetFiles', HelpMessage = 'Share SAS Token:', Position = 1)]
        [Parameter(Mandatory = $true, ParameterSetName = 'GetContent', HelpMessage = 'Share SAS Token:', Position = 1)]
        [ValidateNotNullorEmpty()]
        [Alias('Sas')]
        [string]$SasToken,
        [Parameter(Mandatory = $true, ParameterSetName = 'GetFiles', HelpMessage = 'Local Download Path:', Position = 2)]
        [Parameter(Mandatory = $false, ParameterSetName = 'GetContent', HelpMessage = 'Local Download Path:', Position = 2)]
        [Alias('Destination')]
        [string]$Path,
        [Parameter(Mandatory = $false, ParameterSetName = 'GetFiles')]
        [Alias('Overwrite')]
        [switch]$Force,
        [Parameter(Mandatory = $false, ParameterSetName = 'GetContent')]
        [Alias('GetContent')]
        [switch]$ContentOnly
    )
    Begin {

        ## Check if no security token is provided
        $IsSecure = [boolean](-not [string]::IsNullOrEmpty($SasToken))

        ## Remove the '?' from the SAS string if needed
        If ($SasToken[0] -eq '?') { $SasToken = $SasToken -replace ('\?', '') }
    }
    Process {
        Try {

            ## Get azure file list
            $AzureFileList = Get-RestAzureFileStorageItem -Url $Url -Sas $SasToken

            ## If $GetContent is specified and there is just one file, get file content.
            If ($PSCmdlet.ParameterSetName -eq 'GetContent') {

                ## Check if just one item is found
                If (($AzureFileList | Measure-Object).Count -eq 1) {

                    ## Build URI
                    [string]$Uri = If ($IsSecure) { '{0}?{1}' -f ($Url, $SasToken) } Else { $Url }

                    ## Invoke REST API
                    $Response = Invoke-RestMethod -Uri $Uri -Method 'Get' -UseBasicParsing -ErrorAction 'Continue'

                    ## Check if last operation was successful and set error message
                    [boolean]$ShowError = If ($?) { $false; $ErrorMessage = $null } Else { $true; $ErrorMessage = -join ('Error: ', $Error[0].Exception.Message) };

                    ## Build output object
                    $Output = [pscustomobject]@{
                        'Name'      = $AzureFileList.Name
                        'Size(KB)'  = '{0:N2}' -f ($AzureFileList.'Size(KB)')
                        'Url'       = $AzureFileList.Url
                        'Operation' = Switch ($true) {
                            $ShowError { $ErrorMessage; Break }
                            Default    { 'Downloaded' }
                        }
                        'Content'   = $Response
                    }
                }
                Else { Throw 'Cannot get content for more than one file at a time!' }
            }
            Else {

                ## Get local file list
                $LocalFileList = Get-ChildItem -Path $Path -File -ErrorAction 'SilentlyContinue' | Select-Object -Property 'Name', @{Name = 'Size(KB)'; Expression = {'{0:N2}' -f ($PSItem.Length / 1KB)}}

                ## Create destination folder
                New-Item -Path $Path -ItemType 'Directory' -ErrorAction 'SilentlyContinue' | Out-Null

                ## Process files one by one
                $Output = ForEach ($File in $AzureFileList) {

                    ## If the file is already present and the same size, set the 'Skip' flag.
                    [psobject]$LocalFileLookup = $LocalFileList | Where-Object { $PSItem.Name -eq $File.Name -and $PSItem.'Size(KB)' -eq $File.'Size(KB)' } | Select-Object -Property 'Name'
                    [boolean]$SkipFile = [boolean](-not [string]::IsNullOrEmpty($LocalFileLookup))

                    ## Assemble Destination and URI
                    [string]$Destination = Join-Path -Path $Path -ChildPath $File.Name
                    [string]$Uri = If ($IsSecure) { '{0}?{1}' -f ($File.Url, $SasToken) } Else { $File.Url }
                    [boolean]$Overwite = $Force -and $SkipFile

                    ## Tansfer file using BITS
                    If (-not $SkipFile -or $Force) { Start-BitsTransfer -Source $Uri -Destination $Destination -HttpMethod 'Get' -Description $Destination -DisplayName $File.Url -ErrorAction 'Stop' }

                    ## Check if last operation was successful and set error message
                    [boolean]$ShowError = If ($?) { $false; $ErrorMessage = $null } Else { $true; $ErrorMessage = -join ('Error: ', $Error[0].Exception.Message) };

                    ## Build output object
                    [pscustomobject]@{
                        'Name'      = $File.Name
                        'Size(KB)'  = '{0:N2}' -f ($File.'Size(KB)')
                        'Url'       = $File.Url
                        'Path'      = $Path
                        'Operation' = Switch ($true) {
                            $ShowError { $ErrorMessage; Break }
                            $Overwite  { 'Overwritten'; Break }
                            $SkipFile  { 'Skipped' ; Break }
                            Default    { 'Downloaded' }
                        }
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

#endregion
##*=============================================
##* END FUNCTION LISTINGS
##*=============================================

##*=============================================
##* SCRIPT BODY
##*=============================================
#region ScriptBody

## Call blob or file storage functions depending on the specified url
Switch ($Url) {
   ($Url -contains 'blob.core.windows.net') { Start-AzureBlobStorageTransfer -Url $Url -Sas $SasToken -Destination $Path -Force:$Force -ContentOnly:$ContentOnly; Break }
   ($Url -contains 'file.core.windows.net') { Start-AzureFileStorageTransfer -Url $Url -Sas $SasToken -Destination $Path -Force:$Force -ContentOnly:$ContentOnly; Break }
   Default { Throw ('Invalid Url. Needs to be an Azure Blob or File Storage Url!') }
}

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================