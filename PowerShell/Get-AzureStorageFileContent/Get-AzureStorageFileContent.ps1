<#
.SYNOPSIS
    Gets items from azure file storage.
.DESCRIPTION
    Gets items from azure file storage using REST API and BITS.
.PARAMETER Url
    Specifies the azure share URL.
.PARAMETER SasToken
    Specifies the azure share SAS security token.
.PARAMETER Path
    Specifies the destination path.
.EXAMPLE
    Get-AzureStorageFile.ps1 -Url 'https://<storageaccount>.file.core.windows.net/<SomeShare/SomeFolder>' -SasToken 'SomeAccessToken' -Path 'D:\Temp'
.INPUTS
    None.
.OUTPUTS
    System.Array
.NOTES
    Created by Ioan Popovici
    This script can be called directly.
.LINK
    https://MEM.Zone/Get-AzStorageContent
.LINK
    https://MEM.Zone/Get-AzStorageContent-CHANGELOG
.LINK
    https://MEM.Zone/Get-AzStorageContent-GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    Azure File Storage Rest API
.FUNCTIONALITY
    Copies Items to local storage
#>

## Set script requirements
#Requires -Version 3.0

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

## Get script parameters
Param (
    [Parameter(Mandatory=$true,HelpMessage='Share URL:',Position=0)]
    [ValidateNotNullorEmpty()]
    [Alias('Location')]
    [string]$Url,
    [Parameter(Mandatory=$true,HelpMessage='Share SAS Token:',Position=1)]
    [ValidateNotNullorEmpty()]
    [Alias('Sas')]
    [string]$SasToken,
    [Parameter(Mandatory=$true,HelpMessage='Local Download Path:',Position=2)]
    [ValidateNotNullorEmpty()]
    [Alias('Destination')]
    [string]$Path
)

#endregion
##*=============================================
##* END VARIABLE DECLARATION
##*=============================================

##*=============================================
##* FUNCTION LISTINGS
##*=============================================
#region FunctionListings

#region Function Get-AzureStorageFile
Function Get-AzureStorageFile {
<#
.SYNOPSIS
    Lists directories and files for a path.
.DESCRIPTION
    Lists directories and files for a path storage using REST API.
.PARAMETER Url
    Specifies the azure share URL.
.PARAMETER SasToken
    Specifies the azure share SAS token.
.EXAMPLE
    Get-AzureStorageFile -Url 'https://<storageaccount>.file.core.windows.net/<SomeShare/SomeFolder>' -Sas 'SomeAccessToken'
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
..COMPONENT
    Azure File Storage Rest API
.FUNCTIONALITY
    List Items
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
        [regex]$RegexPattern = '[\w]+\.[A-Za-z0-9]{1,3}$'
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

#region Function Get-AzureStorageFileContent
Function Get-AzureStorageFileContent {
<#
.SYNOPSIS
    Downloads the contents of a file.
.DESCRIPTION
    Downloads the contents of a file from Azure File storage using BITS.
.PARAMETER Url
    Specifies the azure share URL.
.PARAMETER SasToken
    Specifies the azure share SAS security token.
.PARAMETER Path
    Specifies the destination path.
.PARAMETER Force
    Overwrites the existing file even if it has the same name and size. I can't think why this would be needed but I added it anyway.
.PARAMETER GetFileContent
    This switch specifies return the content of the file if the azure share URL points to a single file.
.EXAMPLE
    Get-AzureStorageFile -Url 'https://<storageaccount>.file.core.windows.net/<SomeShare/SomeFolder>' -SasToken 'SomeAccessToken' -Path 'D:\Temp'
.INPUTS
    None.
.OUTPUTS
    System.Array.
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
..COMPONENT
    Azure File Storage Rest API
.FUNCTIONALITY
    Copies to local storage
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
        [string]$SasToken,
        [Parameter(Mandatory=$true,HelpMessage='Local Download Path:',Position=2)]
        [Alias('Destination')]
        [string]$Path,
        [Alias('Overwrite')]
        [switch]$Force,
        [Parameter(Mandatory=$true,HelpMessage='Get only file content?',Position=3)]
        [Alias('GetContent')]
        [switch]$GetFileContent
    )

    Begin {

        ## Remove the '?' from the SAS string if needed
        If ($SasToken[0] -eq '?') { $SasToken = $SasToken -replace ('\?', '') }
    }
    Process {
        Try {

            ## Get azure file list
            $AzureFileList = Get-AzureStorageFile -Url $Url -Sas $SasToken

            ## Get local file list
            $LocalFileList = Get-ChildItem -Path $Path -File -ErrorAction 'SilentlyContinue' | Select-Object -Property 'Name', @{Name = 'Size(KB)'; Expression = {'{0:N2}' -f ($_.Length / 1KB)}}

            ## Create destination folder
            New-Item -Path $Path -ItemType 'Directory' -ErrorAction 'SilentlyContinue' | Out-Null

            ## Process files one by one
            $CopiedFileList = ForEach ($File in $AzureFileList) {

                ## If the file is already present and the same size, set the 'Skip' flag.
                [psobject]$LocalFileLookup = $LocalFileList | Where-Object { $_.Name -eq $File.Name -and $_.'Size(KB)' -eq $File.'Size(KB)' } | Select-Object -Property 'Name'
                [boolean]$SkipFile = [boolean](-not [string]::IsNullOrEmpty($LocalFileLookup))

                ## Assemble Destination and URI
                [string]$Destination = Join-Path -Path $Path -ChildPath $File.Name
                [string]$Uri = '{0}?{1}' -f ($File.Url, $SasToken)
                [boolean]$Overwite = $Force -and $SkipFile

                ## Get content of the file if specifies
                If ($AzureFileList.Count -eq 1 -and $GetFileContent){ Invoke-WebRequest -Uri $Uri -UseBasicParsing }
                Else {

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
            Write-Output -InputObject $CopiedFileList
        }
    }
    End {
    }
}
#endregion

#region Function Get-AzureStorageBlobContent
Function Get-AzureStorageBlobContent {
<#
.SYNOPSIS
    Gets the contents of a blob storage object.
.DESCRIPTION
    Gets the contents of a blob storage object, using REST API and returns it to the pipeline.
    Use for small blobs only.
.PARAMETER Url
    Specifies the azure share URL.
.PARAMETER SasToken
    Specifies the azure share SAS security token.
.EXAMPLE
    Get-AzureStorageBlobContent -Url 'https://<storageaccount>.file.core.windows.net/<blobcontainer>/<blobobject>' -SasToken 'SomeAccessToken'
.INPUTS
    None.
.OUTPUTS
    System.String.
.NOTES
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
..COMPONENT
    Azure Blob Storage REST API
.FUNCTIONALITY
    Gets blob content
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

        ## Assemble URI
        [string]$Uri = '{0}?{1}' -f ($Url, $SasToken)
    }
    Process {
        Try {

            ## Get blob content
            [byte[]]$BlobContent = (Invoke-WebRequest -Uri $Uri -Method 'Get' -UseBasicParsing).Content

            ## Convert octet stream to string
            [string]$Result = [System.Text.Encoding]::Unicode.GetString($BlobContent)
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

Get-AzureStorageFileContent -Url $Url -SasToken $SasToken -Path $Path

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================