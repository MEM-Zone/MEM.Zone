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
.PARAMETER FileContentOnly
    This switch specifies return the content of the file to the pipeline if the azure share URL points to a single file.
.EXAMPLE
    Start-AzureFileStorageTransfer -Url 'https://<storageaccount>.file.core.windows.net/<Share>/<FolderPath>' -SasToken '<AccessToken>' -Path 'D:\Temp' -Force
.EXAMPLE
    Start-AzureFileStorageTransfer -Url 'https://<storageaccount>.file.core.windows.net/<Share/<FilePath>' -SasToken '<AccessToken>' -FileContentOnly
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
        [switch]$FileContentOnly
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