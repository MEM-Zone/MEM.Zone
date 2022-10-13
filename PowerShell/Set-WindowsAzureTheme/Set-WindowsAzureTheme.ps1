<#
.SYNOPSIS
    Sets and activates the theme for windows.
.DESCRIPTION
    Sets and activates the theme for windows, by downloading the theme file from Azure File or Blob Storage.
.PARAMETER Path
    Specifies the destination path for the theme.
.PARAMETER Url
    Specifies the azure file storage share URL.
.PARAMETER SasToken
    Specifies the azure file storage share SAS token. If the SAS token is not specified, the theme file will be downloaded from Azure File Storage without authentication.
.PARAMETER Force
    Overwrite the existing local theme file.
.EXAMPLE
    [hashtable]$Parameters = @{
        Path              = Join-Path -Path $env:ProgramData -ChildPath 'SomeCompany\Themes'
        Url               = 'https://testcmspublic.file.core.windows.net/public/SomeCompany/Branding/Themes/ThemeFile.theme'
        SasToken          = '?sv=2020-02-10&ss=f&srt=co&sp=rl&se=2022-02-23T16:50:56Z&st=2021-02-23T08:50:56Z&spr=https&sig=U1ksjwFS7x970xYezvG%2B%2FfIQYoX6k12VY95xOVfDm6Y%3D'
        Force             = $false
        Verbose           = $true
    }
    Set-WindowsAzureTheme.ps1 @Parameters
.INPUTS
    None.
.OUTPUTS
    System.String
.NOTES
    Created by Ioan Popovici
    You can use this script in a baseline as a MEMCM 'Detection' script.
.LINK
    https://MEM.Zone/Set-WindowsAzureTheme
.LINK
    https://MEM.Zone/Set-WindowsAzureTheme-CHANGELOG
.LINK
    https://MEM.Zone/Set-WindowsAzureTheme-GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    Desktop
.FUNCTIONALITY
    Change Windows Theme
#>

## Set script requirements
#Requires -Version 3.0

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

## !! Comment the reqion below if using in-script parameter values. You can set the parameters in the SCRIPT BODY region at the end of the script !!
#region ScriptParameters
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $true, HelpMessage = 'Destination Path:', Position = 0)]
    [ValidateNotNullorEmpty()]
    [Alias('Destination')]
    [string]$Path,
    [Parameter(Mandatory = $true, HelpMessage = 'Share URL:', Position = 1)]
    [ValidateNotNullorEmpty()]
    [Alias('Location')]
    [string]$Url,
    [Parameter(Mandatory = $false, HelpMessage = 'Share SAS Token:', Position = 2)]
    [Alias('Sas')]
    [string]$SasToken,
    [Alias('Overwrite')]
    [switch]$Force
)
#endregion

#endregion
##*=============================================
##* END VARIABLE DECLARATION
##*=============================================

##*=============================================
##* FUNCTION LISTINGS
##*=============================================
#region FunctionListings

#region Function Format-Spacer
Function Format-Spacer {
<#
.SYNOPSIS
    Adds padding before and after the specified variable.
.DESCRIPTION
    Adds padding before and after the specified variable in order to make it more visible.
.PARAMETER Message
    Specifies input message for this function.
.PARAMETER Type
    Specifies message output type.
.PARAMETER AddEmptyRow
    Specifies to add empty row before, after or both before and after the output.
.EXAMPLE
    Format-Spacer -Message $SomeVariable -AddEmptyRow 'Before'
.INPUTS
    System.String
.OUTPUTS
    System.String
.NOTES
    This is an internal script function and should typically not be called directly.
    Thanks @chrisdent from windadmins for fixing my regex :)
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    Console
.FUNCTIONALITY
    Format Output
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, ValueFromPipeline, HelpMessage = 'Specify input:', Position = 0)]
        [ValidateNotNullorEmpty()]
        [Alias('Variable')]
        [string]$Message,
        [Parameter(Mandatory = $false, Position = 1)]
        [ValidateSet('Console', 'Verbose')]
        [string]$Type = 'Console',
        [Parameter(Mandatory = $false, Position = 2)]
        [ValidateSet('No', 'Before', 'After', 'BeforeAndAfter')]
        [string]$AddEmptyRow = 'No'
    )
    Begin {

        ## Set variables
        [string]$Padding = '#========================================#'
    }
    Process {
        Try {

            ## Trim start/end spaces
            [string]$MessageTrimmed = $Message.TrimStart().TrimEnd()

            ## Calculate the numbers of padding characters to remove
            [int]$RemoveRight = [math]::Floor($MessageTrimmed.Length / 2)
            [int]$RemoveLeft  = [math]::Ceiling($MessageTrimmed.Length / 2)

            ## Remove padding characters
            [string]$PaddingRight = $Padding -replace "(?<=#)={$RemoveRight}"
            [string]$PaddingLeft  = $Padding -replace "(?<=#)={$RemoveLeft}"

            ## Add empty rows to the output
            Switch ($AddEmptyRow) {
                'Before' { If ($Type -ne 'Verbose') { $PaddingRight = -join ("`n", $PaddingRight) } }
                'After'  { If ($Type -ne 'Verbose') { $PaddingLeft  = -join ($PaddingLeft, "`n" ) } }
                'After'  { If ($Type -ne 'Verbose') {
                    $PaddingRight = -join ("`n", $PaddingRight)
                    $PaddingLeft  = -join ($PaddingLeft, "`n" ) }
                }
                Default  {}
            }

            ## Assemble result
            [string]$Result = -join ($PaddingRight, ' ', $MessageTrimmed, ' ', $PaddingLeft)
        }
        Catch {
            $PSCmdlet.WriteError($PSItem)
        }
        Finally {

            ## Write to console
            If ($Type -eq 'Console') { Write-Output -InputObject $Result }

            ## Write verbose and add empty rows if specified
            Else {
                If ($AddEmptyRow -eq 'Before' -or $AddEmptyRow -eq 'BeforeAndAfter') { Write-Verbose -Message '' }
                Write-Verbose -Message $Result
                If ($AddEmptyRow -eq 'After' -or $AddEmptyRow -eq 'BeforeAndAfter') { Write-Verbose -Message '' }
            }
        }
    }
    End {
    }
}
#endregion

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

#region Function Start-RestAzureStorageTransfer
Function Start-RestAzureStorageTransfer {
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
#endregion

#region Function Set-WindowsAzureTheme
Function Set-WindowsAzureTheme {
<#
.SYNOPSIS
    Sets and activates the theme for windows.
.DESCRIPTION
    Sets and activates the theme for windows, by downloading the theme file from Azure File or Blob Storage.
.PARAMETER Path
    Specifies the destination path for the theme.
.PARAMETER Url
    Specifies the azure file or blob storage share URL.
.PARAMETER SasToken
    Specifies the azure file or blob storage share SAS token. If the SAS token is not specified, the theme file will be downloaded from Azure without authentication.
.PARAMETER Force
    Overwrite the existing local theme file.
.EXAMPLE
    [hashtable]$Parameters = @{
        Path              = Join-Path -Path $env:ProgramData -ChildPath 'SomeCompany\Themes'
        Url               = 'https://testcmspublic.file.core.windows.net/public/SomeCompany/Branding/Themes/ThemeFile.theme'
        SasToken          = '?sv=2020-02-10&ss=f&srt=co&sp=rl&se=2022-02-23T16:50:56Z&st=2021-02-23T08:50:56Z&spr=https&sig=U1ksjwFS7x970xYezvG%2B%2FfIQYoX6k12VY95xOVfDm6Y%3D'
        Force             = $false
        Verbose           = $true
    }
    Set-WindowsAzureTheme.ps1 @Parameters
.INPUTS
    None.
.OUTPUTS
    System.Array.
.NOTES
    Created by Ioan Popovici
    You can use this script in a baseline as a MEMCM 'Detection' script.
.LINK
    https://MEM.Zone/Set-WindowsAzureTheme
.LINK
    https://MEM.Zone/Set-WindowsAzureTheme-CHANGELOG
.LINK
    https://MEM.Zone/Set-WindowsAzureTheme-GIT
.LINK
    https://MEM.Zone/Set-WindowsAzureTheme-SQL
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    Desktop
.FUNCTIONALITY
    Set Windows Theme
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = 'Destination Path:', Position = 0)]
        [ValidateNotNullorEmpty()]
        [Alias('Destination')]
        [string]$Path,
        [Parameter(Mandatory = $true, HelpMessage = 'Share URL:', Position = 1)]
        [ValidateNotNullorEmpty()]
        [Alias('Location')]
        [string]$Url,
        [Parameter(Mandatory = $false, HelpMessage = 'Share SAS Token:', Position = 2)]
        [Alias('Sas')]
        [string]$SasToken,
        [Alias('Overwrite')]
        [switch]$Force
    )
    Begin {
        Format-Spacer -Message 'Initialization' -Type 'Verbose' -AddEmptyRow 'After'

        ## Set default output hashtable
        $Output = [ordered]@{
            'Theme' = 'N/A'
            'Operation' = 'N/A'
        }
    }
    Process {
        Try {

            ## Get Azure theme depending on the storage account type
            If ($Url -match '.blob.') { [psobject]$AzureThemeFile = Get-RestAzureBlobStorageItem -Url $Url -SasToken $SasToken -ErrorAction 'Stop' }
            Else { [psobject]$AzureThemeFile = Get-RestAzureFileStorageItem -Url $Url -SasToken $SasToken -ErrorAction 'Stop' }

            ## Show Azure theme list
            Format-Spacer -Message 'Azure Theme' -Type 'Verbose'
            Write-Verbose -Message $($AzureThemeFile | Out-String)

            ## Set variables
            [scriptblock]$IsSystemSettingsStarted = { [boolean](Get-Process -Name 'SystemSettings' -ErrorAction 'SilentlyContinue') }
            [scriptblock]$CurrentThemeName        = {
                $CurrentThemePath = $(Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\' -Name 'CurrentTheme').CurrentTheme
                $(Split-Path -Path $CurrentThemePath -Leaf).Split('.')[0]
            }
            [string]$AzureThemeName   = $($AzureThemeFile.Name).Split('.')[0]
            [string]$ThemeLocalPath   = Join-Path -Path $Path -ChildPath $AzureThemeFile.Name
            $Output.Theme             = $AzureThemeName

            ## Set the theme if its not already assigned or the 'Force' switch is specified
            If ($(& $CurrentThemeName) -ne $AzureThemeName -or $Force) {

                ## Download the theme file
                $Output.Operation = 'Downloading'
                Format-Spacer -Message 'Downloading Theme' -Type 'Verbose' -AddEmptyRow 'BeforeAndAfter'
                $DownloadTheme = Start-RestAzureStorageTransfer -Url $Url -SasToken $SasToken -Path $Path -Force:$Force -ErrorAction 'Stop'
                Write-Verbose -Message $($DownloadTheme | Out-String)

                ## Set Theme
                $Output.Operation = 'Applying'
                Format-Spacer -Message 'Setting Theme' -Type 'Verbose' -AddEmptyRow 'After'
                Write-Verbose -Message "Setting Theme ($AzureThemeName)..."
                #  Stop the 'SystemSettings' process if started
                Stop-Process -Name 'SystemSettings' -ErrorAction 'SilentlyContinue' -Force
                #  Install and apply theme
                Invoke-Expression -Command $ThemeLocalPath | Out-Null
                #  Kill the SystemSettings process only after the theme is detected as installed in order to apply the theme.
                For ($Counter = 0, 100, $Counter++) {
                    If ($(& $CurrentThemeName) -eq $AzureThemeName -and $(& $IsSystemSettingsStarted)) { Break }
                }
                #  Stop the SystemSettings process to apply the theme.
                Stop-Process -Name 'SystemSettings' -ErrorAction 'SilentlyContinue' -Force
                $Output.Operation = 'Success'

                ## Throw error if setting Theme fails
                If (-not $?) {
                    $Output.Operation = 'Failed'
                    Throw $($Output | Out-String)
                }
            }
            Else { $Output.Operation = 'Already set!' }
        }
        Catch {
            Throw $PSItem
        }
        Finally {
            Write-Output -InputObject $($Output | Out-String)
            Format-Spacer -Message 'Exit Script' -Type 'Verbose'
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

    ## Set parameters according to script parameters.
    ## !! Add parameters values here if using in-script parameters. Don't forget to comment the script parameter section !!
    [hashtable]$Parameters = @{
        Path               = $Path
        Url                = $Url
        SasToken           = $SasToken
        Force              = $Force
        Verbose            = $VerbosePreference
    }

    ## Call Set-WindowsAzureTheme with declared parameters
    Set-WindowsAzureTheme @Parameters
}
Catch {
    Throw $PSItem
}

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================
