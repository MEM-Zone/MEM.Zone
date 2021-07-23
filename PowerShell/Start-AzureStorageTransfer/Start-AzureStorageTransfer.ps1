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

#region Function Start-AzureBlobStorageTransfer
Function Start-AzureBlobStorageTransfer {
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
    Start-AzureBlobStorageTransfer -Url 'https://<storageaccount>.blob.core.windows.net/<Containter>' -SasToken '<AccessToken>' -Path 'D:\Temp' -Force
.EXAMPLE
    Start-AzureBlobStorageTransfer -Url 'https://<storageaccount>.blob.core.windows.net/<Container>/<Blob>' -SasToken 'SomeAccessToken' -ContentOnly
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
    Downloads to local storage
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true,ParameterSetName='GetBlobs',HelpMessage='Containter or Blob URL:',Position=0)]
        [Parameter(Mandatory=$true,ParameterSetName='GetContent',HelpMessage='Containter or Blob URL:',Position=0)]
        [ValidateNotNullorEmpty()]
        [Alias('Location')]
        [string]$Url,
        [Parameter(Mandatory=$true,ParameterSetName='GetBlobs',HelpMessage='Containter or Blob SAS Token:',Position=1)]
        [Parameter(Mandatory=$true,ParameterSetName='GetContent',HelpMessage='Containter or Blob SAS Token:',Position=1)]
        [ValidateNotNullorEmpty()]
        [Alias('Sas')]
        [string]$SasToken,
        [Parameter(Mandatory=$true,ParameterSetName='GetBlobs',HelpMessage='Local Download Path:',Position=2)]
        [Parameter(Mandatory=$false,ParameterSetName='GetContent',HelpMessage='Local Download Path:',Position=2)]
        [Alias('Destination')]
        [string]$Path,
        [Parameter(Mandatory=$false,ParameterSetName='GetBlobs')]
        [Alias('Overwrite')]
        [switch]$Force,
        [Parameter(Mandatory=$false,ParameterSetName='GetContent')]
        [Alias('GetContent')]
        [switch]$ContentOnly
    )
    Begin {

        ## Remove the '?' from the SAS string if needed
        If ($SasToken[0] -eq '?') { $SasToken = $SasToken -replace ('\?', '') }
    }
    Process {
        Try {

            ## Get azure blob list
            $AzureBlobList = Get-AzureBlobStorageItem -Url $Url -Sas $SasToken

            ## If $GetContent is specified and there is just one blob, get blob content.
            If ($PSCmdlet.ParameterSetName -eq 'GetContent') {
                #  Check if just one item is found
                If (($AzureBlobList | Measure-Object).Count -eq 1) {
                    #  Build URI
                    [string]$Uri = '{0}?{1}' -f ($Url, $SasToken)
                    #  Invoke REST API
                    $Result = Invoke-RestMethod -Uri $Uri -Method 'Get' -UseBasicParsing
                }
                Else { Throw 'Cannot get content for more than one blob at a time!' }
            }
            Else {

                ## Get local blob list
                $LocalBlobList = Get-ChildItem -Path $Path -File -ErrorAction 'SilentlyContinue' | Select-Object -Property 'Name', @{Name = 'Size(KB)'; Expression = {'{0:N2}' -f ($_.Length / 1KB)}}

                ## Create destination folder
                New-Item -Path $Path -ItemType 'Directory' -ErrorAction 'SilentlyContinue' | Out-Null

                ## Process blobs one by one
                $Result = ForEach ($Blob in $AzureBlobList) {

                    ## If the blob is already present and the same size, set the 'Skip' flag.
                    [psobject]$LocalBlobLookup = $LocalBlobList | Where-Object { $_.Name -eq $Blob.Name -and $_.'Size(KB)' -eq $Blob.'Size(KB)' } | Select-Object -Property 'Name'
                    [boolean]$SkipBlob = [boolean](-not [string]::IsNullOrEmpty($LocalBlobLookup))

                    ## Assemble Destination and URI
                    [string]$Destination = Join-Path -Path $Path -ChildPath $Blob.Name
                    [string]$Uri = '{0}?{1}' -f ($Blob.Url, $SasToken)
                    [boolean]$Overwite = $Force -and $SkipBlob

                    ## Tansfer blob using BITS
                    If (-not $SkipBlob -or $Force) { Start-BitsTransfer -Source $Uri -Destination $Destination -HttpMethod 'Get' -Description $Destination -DisplayName $Blob.Url -ErrorAction 'Stop' }

                    ## Check if last operation was successful and set error message
                    [boolean]$ShowError = If ($?) { $false; $ErrorMessage = $null } else { $true; $ErrorMessage = -join ('Error: ', $Error[0].Exception.Message) };

                    ## Build output object
                    [pscustomobject]@{
                        'Name'      = $Blob.Name
                        'Size(KB)'  = '{0:N2}' -f ($Blob.'Size(KB)')
                        'Url'       = $Blob.Url
                        'Path'      = $Path
                        'Operation' = Switch ($true) {
                            $ShowError { $ErrorMessage; break }
                            $Overwite  { 'Overwritten'; break }
                            $SkipBlob  { 'Skipped' ; break }
                            Default    { 'Downloaded' }
                        }
                    }
                }
            }
        }
        Catch {
            $PSCmdlet.ThrowTerminatingError($PSItem)
        }
        Finally {
            Write-Output -InputObject $Result
        }
    }
    End {
    }
}
#endregion

#region Function Start-AzureFileStorageTransfer
Function Start-AzureFileStorageTransfer {
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
    Start-AzureFileStorageTransfer -Url 'https://<storageaccount>.file.core.windows.net/<Share>/<FolderPath>' -SasToken '<AccessToken>' -Path 'D:\Temp' -Force
.EXAMPLE
    Start-AzureFileStorageTransfer -Url 'https://<storageaccount>.file.core.windows.net/<Share/<FilePath>' -SasToken '<AccessToken>' -ContentOnly
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
    Downloads to local storage
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true,ParameterSetName='GetFiles',HelpMessage='Share URL:',Position=0)]
        [Parameter(Mandatory=$true,ParameterSetName='GetContent',HelpMessage='Share URL:',Position=0)]
        [ValidateNotNullorEmpty()]
        [Alias('Location')]
        [string]$Url,
        [Parameter(Mandatory=$true,ParameterSetName='GetFiles',HelpMessage='Share SAS Token:',Position=1)]
        [Parameter(Mandatory=$true,ParameterSetName='GetContent',HelpMessage='Share SAS Token:',Position=1)]
        [ValidateNotNullorEmpty()]
        [Alias('Sas')]
        [string]$SasToken,
        [Parameter(Mandatory=$true,ParameterSetName='GetFiles',HelpMessage='Local Download Path:',Position=2)]
        [Parameter(Mandatory=$false,ParameterSetName='GetContent',HelpMessage='Local Download Path:',Position=2)]
        [Alias('Destination')]
        [string]$Path,
        [Parameter(Mandatory=$false,ParameterSetName='GetFiles')]
        [Alias('Overwrite')]
        [switch]$Force,
        [Parameter(Mandatory=$false,ParameterSetName='GetContent')]
        [Alias('GetContent')]
        [switch]$ContentOnly
    )
    Begin {

        ## Remove the '?' from the SAS string if needed
        If ($SasToken[0] -eq '?') { $SasToken = $SasToken -replace ('\?', '') }
    }
    Process {
        Try {

            ## Get azure file list
            $AzureFileList = Get-AzureFileStorageItem -Url $Url -Sas $SasToken

            ## If $GetContent is specified and there is just one file, get file content.
            If ($PSCmdlet.ParameterSetName -eq 'GetContent') {
                #  Check if just one item is found
                If (($AzureBlobList | Measure-Object).Count -eq 1) {
                    #  Build URI
                    [string]$Uri = '{0}?{1}' -f ($Url, $SasToken)
                    #  Invoke REST API
                    $Result = Invoke-RestMethod -Uri $Uri -Method 'Get' -UseBasicParsing
                }
                Else { Throw 'Cannot get content for more than one blob at a time!' }
            }
            Else {

                ## Get local file list
                $LocalFileList = Get-ChildItem -Path $Path -File -ErrorAction 'SilentlyContinue' | Select-Object -Property 'Name', @{Name = 'Size(KB)'; Expression = {'{0:N2}' -f ($_.Length / 1KB)}}

                ## Create destination folder
                New-Item -Path $Path -ItemType 'Directory' -ErrorAction 'SilentlyContinue' | Out-Null

                ## Process files one by one
                $Result = ForEach ($File in $AzureFileList) {

                    ## If the file is already present and the same size, set the 'Skip' flag.
                    [psobject]$LocalFileLookup = $LocalFileList | Where-Object { $_.Name -eq $File.Name -and $_.'Size(KB)' -eq $File.'Size(KB)' } | Select-Object -Property 'Name'
                    [boolean]$SkipFile = [boolean](-not [string]::IsNullOrEmpty($LocalFileLookup))

                    ## Assemble Destination and URI
                    [string]$Destination = Join-Path -Path $Path -ChildPath $File.Name
                    [string]$Uri = '{0}?{1}' -f ($File.Url, $SasToken)
                    [boolean]$Overwite = $Force -and $SkipFile

                    ## Tansfer file using BITS
                    If (-not $SkipFile -or $Force) { Start-BitsTransfer -Source $Uri -Destination $Destination -HttpMethod 'Get' -Description $Destination -DisplayName $File.Url -ErrorAction 'Stop' }

                    ## Check if last operation was successful and set error message
                    [boolean]$ShowError = If ($?) { $false; $ErrorMessage = $null } else { $true; $ErrorMessage = -join ('Error: ', $Error[0].Exception.Message) };

                    ## Build output object
                    [pscustomobject]@{
                        'Name'      = $File.Name
                        'Size(KB)'  = '{0:N2}' -f ($File.'Size(KB)')
                        'Url'       = $File.Url
                        'Path'      = $Path
                        'Operation' = Switch ($true) {
                            $ShowError { $ErrorMessage; break }
                            $Overwite  { 'Overwritten'; break }
                            $SkipFile  { 'Skipped' ; break }
                            Default    { 'Downloaded' }
                        }
                    }
                }
            }
        }
        Catch {
            $PSCmdlet.ThrowTerminatingError($PSItem)
        }
        Finally {
            Write-Output -InputObject $Result
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