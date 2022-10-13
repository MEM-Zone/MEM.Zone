Function Start-RestAzureFileStorageTransfer {
<#
.SYNOPSIS
    Starts an azure storage transfer.
.DESCRIPTION
    Starts an azure storage transfer using bits or outputs a single file or blob content to the pipeline.
.PARAMETER Url
    Specifies the azure share URL.
.PARAMETER SasToken
    Specifies the azure share SAS security token.
.PARAMETER Path
    Specifies the destination path for the dowloaded files or blob.
.PARAMETER Force
    Overwrites the existing file even if it has the same name and size. I can't think why this would be needed but I added it anyway.
.PARAMETER ContentOnly
    This switch specifies return the content of the file or blob to the pipeline if the azure share URL points to a single file or blob.
.EXAMPLE
    Start-RestAzureStorageTransfer -Url 'https://<storageaccount>.file.core.windows.net/<Share>/<FolderPath>' -SasToken '<AccessToken>' -Path 'D:\Temp' -Force
.EXAMPLE
    Start-RestAzureStorageTransfer -Url 'https://<storageaccount>.file.core.windows.net/<Share/<FilePath>' -SasToken '<AccessToken>' -ContentOnly
.EXAMPLE
    Start-RestAzureStorageTransfer -Url 'https://<storageaccount>.blob.core.windows.net/<Containter>' -SasToken '<AccessToken>' -Path 'D:\Temp' -Force
.EXAMPLE
    Start-RestAzureStorageTransfer -Url 'https://<storageaccount>.blob.core.windows.net/<Container>/<Blob>' -SasToken '<AccessToken>' -ContentOnly
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
    Azure Storage Rest API
.FUNCTIONALITY
    Downloads File or Blob to Local Storage
#>
    [CmdletBinding(DefaultParameterSetName = 'GetItem')]
    Param (
        [Parameter(Mandatory = $true, ParameterSetName = 'GetItem', HelpMessage = 'Share URL:', Position = 0)]
        [Parameter(Mandatory = $true, ParameterSetName = 'GetContent',HelpMessage = 'Share URL:', Position = 0)]
        [ValidateNotNullorEmpty()]
        [Alias('Location')]
        [string]$Url,
        [Parameter(Mandatory = $true, ParameterSetName = 'GetItem', HelpMessage = 'Share SAS Token:', Position = 1)]
        [Parameter(Mandatory = $true, ParameterSetName = 'GetContent', HelpMessage = 'Share SAS Token:', Position = 1)]
        [ValidateNotNullorEmpty()]
        [Alias('Sas')]
        [string]$SasToken,
        [Parameter(Mandatory = $true, ParameterSetName = 'GetItem', HelpMessage = 'Local Download Path:', Position = 2)]
        [Parameter(Mandatory = $false, ParameterSetName = 'GetContent', HelpMessage = 'Local Download Path:', Position = 2)]
        [Alias('Destination')]
        [string]$Path,
        [Parameter(Mandatory = $false, ParameterSetName = 'GetItem')]
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

            ## Get azure storage item list depending on the storage type
            If ($Url -match '.blob.') { $AzureItemList = Get-RestAzureBlobStorageItem -Url $Url -Sas $SasToken }
            Else { $AzureItemList = Get-RestAzureFileStorageItem -Url $Url -Sas $SasToken }

            ## If $GetContent is specified and there is just one blob, get blob content.
            If ($PSCmdlet.ParameterSetName -eq 'GetContent') {

                ## Check if just one item is found
                If (($AzureItemList | Measure-Object).Count -eq 1) {

                    ## Build URI
                    [string]$Uri = If ($IsSecure) { '{0}?{1}' -f ($Url, $SasToken) } Else { $Url }

                    ## Invoke REST API
                    $Response = Invoke-RestMethod -Uri $Uri -Method 'Get' -UseBasicParsing -ErrorAction 'Continue'

                    ## Check if last operation was successful and set error message
                    [boolean]$ShowError = If ($?) { $false; $ErrorMessage = $null } Else { $true; $ErrorMessage = -join ('Error: ', $Error[0].Exception.Message) };

                    ## Build output object
                    $Output = [pscustomobject]@{
                        'Name'      = $AzureItemList.Name
                        'Size(KB)'  = '{0:N2}' -f ($AzureItemList.'Size(KB)')
                        'Url'       = $AzureItemList.Url
                        'Operation' = Switch ($true) {
                            $ShowError { $ErrorMessage; Break }
                            Default    { 'Downloaded' }
                        }
                        'Content'   = $Response
                    }
                }
                Else { Throw 'Cannot get content for more than one file or blob at a time!' }
            }
            Else {

                ## Get local file list
                $LocalFileList = Get-ChildItem -Path $Path -ErrorAction 'SilentlyContinue' | Select-Object -Property 'Name', @{
                    Name = 'Size(KB)'; Expression = {'{0:N2}' -f ($PSItem.Length / 1KB)}
                }

                ## Create destination folder
                If (-not [System.IO.Directory]::Exists($Path)) { [System.IO.Directory]::CreateDirectory($Path) }

                ## Process items one by one
                $Output = ForEach ($AzureItem in $AzureItemList) {

                    ## If the file is already present and the same size, set the 'Skip' flag.
                    [psobject]$LocalFileLookup = $LocalFileList | Where-Object { $PSItem.Name -eq $AzureItem.Name -and $PSItem.'Size(KB)' -eq $AzureItem.'Size(KB)' } | Select-Object -Property 'Name'
                    $SkipItem = [boolean](-not [string]::IsNullOrEmpty($LocalFileLookup))

                    ## Assemble Destination and URI
                    [string]$Destination = Join-Path -Path $Path -ChildPath $AzureItem.Name
                    [string]$Uri = If ($IsSecure) { '{0}?{1}' -f ($AzureItem.Url, $SasToken) } Else { $AzureItem.Url }
                    $Overwrite = [boolean]($Force -and $SkipItem)

                    ## Tansfer file using BITS
                    If (-not $SkipItem -or $Force) { Start-BitsTransfer -Source $Uri -Destination $Destination -HttpMethod 'Get' -Description $Destination -DisplayName $AzureItem.Url -ErrorAction 'Continue' }

                    ## Check if last operation was successful and set error message
                    [boolean]$ShowError = If ($?) { $false; $ErrorMessage = $null } Else { $true; $ErrorMessage = -join ('Error: ', $Error[0].Exception.Message) };

                    ## Build output object
                    [pscustomobject]@{
                        'Name'      = $AzureItem.Name
                        'Size(KB)'  = '{0:N2}' -f ($AzureItem.'Size(KB)')
                        'Url'       = $AzureItem.Url
                        'Path'      = $Path
                        'Operation' = Switch ($true) {
                            $ShowError { $ErrorMessage; Break }
                            $Overwrite { 'Overwritten'; Break }
                            $SkipItem  { 'Skipped' ; Break }
                            Default    { 'Transfered' }
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