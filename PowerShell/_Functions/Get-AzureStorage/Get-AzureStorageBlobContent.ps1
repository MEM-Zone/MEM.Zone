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