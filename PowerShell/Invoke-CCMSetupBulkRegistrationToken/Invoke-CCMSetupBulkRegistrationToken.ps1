<#
.SYNOPSIS
    Invokes CCMSetup.exe with an MEMCM bulk client registration Token.
.DESCRIPTION
    Invokes CCMSetup.exe from %SystemRoot%\ccmsetup with an MEMCM bulk client registration Token stored in Azure Blob Storage.
    The installation is scheduled as a one time scheduled task on first boot.
.PARAMETER Url
    Specifies the blob to upload the token file URL.
.PARAMETER SasToken
    Specifies the azure blob SAS token. Specifies the azure blob SAS token. If this parameter is not specified, no authentication is used.
.PARAMETER CMGAddress
    Specifies the Cloud Management Gateway address. Do not specify 'https://' prefix.
.EXAMPLE
    Invoke-CCMSetupBulkRegistrationToken.ps1 -Url 'https://mystorage.blob.core.windows.net/mycontainer' -SasToken '?sv=2015-12-11&st=2017-01-01T00:00:00Z&se=2017-01-01T00:00:00Z&sr=c&sp=rw&sig=mySasToken' -CMGAddress 'mycmg.domain.com/CCM_Proxy_MutualAuth/72057594037928022'
.INPUTS
    None.
.OUTPUTS
    System.Object
.NOTES
    Created by Ioan Popovici
    'New-CMClientBulkRegistrationToken' needs to run on the server side to generate the token and upload it to Azure Blob Storage.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/CCMSetupBulkRegistrationToken
.LINK
    https://MEM.Zone/CCMSetupBulkRegistrationToken-GIT
.LINK
    https://MEM.Zone/CCMSetupBulkRegistrationToken-CHANGELOG
.LINK
    https://MEM.Zone/Issues
.COMPONENT
    MEMCM
.FUNCTIONALITY
    Installs the CCMClient installation using a Bulk Registration Token.
#>

## Set script requirements
#Requires -Version 5.0

## Get script parameters
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $true, HelpMessage = 'Blob URL:', Position = 0)]
    [Alias('BlobUrl')]
    [string]$Url,
    [Parameter(HelpMessage = 'Blob SAS Token:', Position = 1)]
    [Alias('Sas')]
    [string]$SasToken,
    [Parameter(Mandatory = $true, HelpMessage = 'CMG Address:', Position = 2)]
    [Alias('CMG')]
    [string]$CMGaddress
)

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

<#
## Set inline parameters if needed
[string]$Url        = 'https://company.blob.core.windows.net/memcmtoken/New-CMClientBulkRegistrationToken.json'
[string]$SASToken   = 'sp=racwd&st=2022-06-22T06:00:00Z&se=2023-06-22T06:00:00Z&spr=https&sv=2021-06-08&sr=c&sig=6Wn1nYb0aj9pwdf0FRhviF3EwVwewk5tv22qbqwQZuc%3D'
[string]$CMGAddress = 'CMG.COMPANY.COM/CCM_Proxy_MutualAuth/72067594037928032'
#>

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

#endregion
##*=============================================
##* END FUNCTION LISTINGS
##*=============================================

##*=============================================
##* SCRIPT BODY
##*=============================================
#region ScriptBody

Try {

    ## Download Token
    $Response = Start-RestAzureBlobStorageTransfer -Url $Url -SasToken $SasToken -ContentOnly

    ## Check validity and output token
    [boolean]$IsValid = [datetime]$Response.Content.Validity -gt (Get-Date).AddMinutes(10)
    If ($IsValid) { $Output = $Response.Content.Value } Else { Throw 'Token is no longer valid!' }

    ## Set scheduled task variables
    [string]$TaskName      = 'Invoke-CCMTokenInstall'
    [string]$Execute       = 'C:\WINDOWS\System32\WindowsPowerShell\v1.0\powershell.exe'
    [string]$CCMSetupPath  = Join-Path -Path $env:SystemRoot -ChildPath 'ccmsetup\ccmsetup.exe'
    [string]$ArgumentList  = "/mp:https://$CMGAddress CCMHOSTNAME=$CMGAddress /regtoken:$Output"

    ## Assemble scheduled task command which triggers CCM setup using the token and then unregisters the scheudled task
    [string]$TaskCommand =
@"
    Start-Process -WindowStyle 'Hidden' -FilePath `'$CCMSetupPath`' -ArgumentList `'$ArgumentList`' -Wait
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:`$false
"@

    ## Create scheduled command scriptblock
    [scriptblock]$ScriptBlock = [ScriptBlock]::Create($TaskCommand)

    ## Set the scheduled task arguments
    $Argument = "-WindowStyle Hidden -NonInteractive -Command `"Invoke-Command -ScriptBlock { $ScriptBlock }`""

    ## Build the scheduled task
    $Action    = New-ScheduledTaskAction -Execute $Execute -Argument $Argument
    $Trigger   = New-ScheduledTaskTrigger -AtStartup
    $Settings  = New-ScheduledTaskSettingsSet -DontStopIfGoingOnBatteries -AllowStartIfOnBatteries
    $Principal = New-ScheduledTaskPrincipal -UserId 'NT Authority\System'

    ## Create the scheduled task
    Register-ScheduledTask -TaskName $TaskName -Trigger $Trigger -Action $Action -Settings $Settings -Principal $Principal
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