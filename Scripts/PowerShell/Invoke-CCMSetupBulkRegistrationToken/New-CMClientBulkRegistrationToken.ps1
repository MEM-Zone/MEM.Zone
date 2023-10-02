<#
.SYNOPSIS
    Generates a new MEMCM Client Bulk Registration Token.
.DESCRIPTION
    Generates a new MEMCM Client Bulk Registration Token, and optionally uploads it to Azure Blob Storage.
.PARAMETER Lifetime
    Specifies the Lifetime in minutes for the generated token.
    Default value is 1440 minutes (1 day).
.PARAMETER File
    Specifies the path to export the token file.
.PARAMETER Url
    Specifies the blob to upload the token file URL.
.PARAMETER SasToken
    Specifies the azure blob SAS token. Specifies the azure blob SAS token. If this parameter is not specified, no authentication is used.
.EXAMPLE
    New-CMClientBulkRegistrationToken.ps1 -Lifetime 10 -File 'C:\temp\token.json'
.EXAMPLE
    New-CMClientBulkRegistrationToken.ps1 -Lifetime 10 -File 'C:\temp\token.json' -Url 'https://mystorageaccount.blob.core.windows.net/mycontainer' -SasToken '?sv=2015-12-11&st=2017-01-01T00:00:00Z&se=2017-01-01T00:00:00Z&sr=c&sp=rw&sig=mySasToken'
.INPUTS
    None.
.OUTPUTS
    System.Object
.NOTES
    Created by Ioan Popovici
    Requires Local Administrator Access on the CM Site Server.
.LINK
    https://MEM.Zone
.LINK
    https://MEMZ.one/CCMSetupBulkRegistrationToken
.LINK
    https://MEMZ.one/CCMSetupBulkRegistrationToken-GIT
.LINK
    https://MEMZ.one/CCMSetupBulkRegistrationToken-CHANGELOG
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    MEMCM
.FUNCTIONALITY
    Generates a Client Bulk Registration Token
#>

## Set script requirements
#Requires -Version 5.0

## Get script parameters
[CmdletBinding(DefaultParameterSetName = 'Default')]
Param (
    [Parameter(ParameterSetName = 'Default', HelpMessage = 'Bulk Registration Token Lifetime in minutes', Position = 0)]
    [Parameter(ParameterSetName = 'File', HelpMessage = 'Bulk Registration Token Lifetime in minutes', Position = 0)]
    [Parameter(ParameterSetName = 'UploadToBlob', HelpMessage = 'Bulk Registration Token Lifetime in minutes', Position = 0)]
    [Alias('Validity')]
    [int32]$Lifetime = 1440,
    [Parameter(Mandatory = $true, ParameterSetName = 'File', HelpMessage = 'Token Output File Path:', Position = 1)]
    [Parameter(Mandatory = $true, ParameterSetName = 'UploadToBlob', HelpMessage = 'Token Output File Path:', Position = 1)]
    [Alias('Path')]
    [string]$File,
    [Parameter(Mandatory = $true, ParameterSetName = 'UploadToBlob', HelpMessage = 'Blob URL:', Position = 2)]
    [Alias('BlobUrl')]
    [string]$Url,
    [Parameter(ParameterSetName = 'UploadToBlob', HelpMessage = 'Blob SAS Token:', Position = 3)]
    [Alias('Sas')]
    [string]$SasToken
)

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
        [Parameter(HelpMessage = 'Share SAS Token:', Position = 2)]
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

#region Function New-CMClientBulkRegistrationToken
Function New-CMClientBulkRegistrationToken {
<#
.SYNOPSIS
    Creates a new MEMCM bulk client registration token.
.DESCRIPTION
    Creates a new MEMCM bulk client registration token using the bulkregistrationtokentool.exe tool.
.PARAMETER Lifetime
    Specifies the Lifetime in minutes for the generated token.
    Default value is 1440 minutes (1 day).
.EXAMPLE
    New-CMClientBulkRegistrationToken -LifeTime 10
.INPUTS
    None.
.OUTPUTS
    System.Object.
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.COMPONENT
    Microsoft Endpoint Management Configuration Manager
.FUNCTIONALITY
    Generate Bulk Registration Token
#>
    [CmdletBinding()]
    Param (
        [Parameter(HelpMessage = 'Bulk Registration Token Lifetime in minutes', Position = 0)]
        [ValidateNotNullorEmpty()]
        [Alias('Validity')]
        [int32]$Lifetime = 1440
    )

    Begin {

        ## Assemble bulk registration token tool path
        $BulkRegistrationTokenToolPath = $($ENV:SMS_ADMIN_UI_PATH).Replace('\AdminConsole\','\').Replace('i386', 'X64\bulkregistrationtokentool.exe')
    }
    Process {
        Try {

            ## Generate token
            $Result = & $BulkRegistrationTokenToolPath /lifetime $Lifetime /new

            ## Extract token info
            [string]$ID       = ($Result | Select-String -Pattern '.{8}-.{4}-.{4}-.{4}-.{12}').Matches.Value
            [string]$Validity = ($Result | Select-String -Pattern '(?<=Token\sis\svalid\suntil\s)(.*)(?=\.)').Matches.Value
            [string]$Value    = ($Result | Select-String -Pattern '.*\z').Matches.Value[4]

            ## Build the output object
            $Output = [pscustomobject]@{
                ID       = $ID
                Validity = (Get-Date $Validity -Format 'o')
                Value    = $Value
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

Try {

    ## Display ParameterSet Used
    Write-Debug -Message "Selected '$($PSCmdlet.ParameterSetName)' ParameterSet."

    ## Generate a new token
    $Output = New-CMClientBulkRegistrationToken

    ## Remove BOM from OTF8 Encoding and output to file
    If ($($PSCmdlet.ParameterSetName) -in ('File','UploadToBlob' )) {
        $Content = $Output | ConvertTo-Json -Depth 4
        $Utf8NoBomEncoding = [System.Text.UTF8Encoding]::new($false)
        [System.IO.File]::WriteAllLines($File, $Content, $Utf8NoBomEncoding)
    }

    ## Upload file to Azure Blob Storage
    If ($($PSCmdlet.ParameterSetName) -eq 'UploadToBlob') {
        $Output = Set-RestAzureBlobStorageContent -File $File -Url $Url -SasToken $SasToken -ErrorAction 'Stop'
    ## Remove Token File
    Remove-Item -Path $File -Force -ErrorAction 'SilentlyContinue'
    }
}
Catch {
    Throw $PSItem
}
Finally {
    Write-Output -InputObject $Output
}

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================