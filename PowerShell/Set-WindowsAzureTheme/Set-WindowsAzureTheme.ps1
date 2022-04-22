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
    https://MEM.Zone/Set-WindowsAzureTheme-SQL
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
    [Parameter(Mandatory=$true,HelpMessage='Destination Path:',Position=0)]
    [ValidateNotNullorEmpty()]
    [Alias('Destination')]
    [string]$Path,
    [Parameter(Mandatory=$true,HelpMessage='Share URL:',Position=1)]
    [ValidateNotNullorEmpty()]
    [Alias('Location')]
    [string]$Url,
    [Parameter(Mandatory=$false,HelpMessage='Share SAS Token:',Position=2)]
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
        [Parameter(Mandatory=$true,ValueFromPipeline,HelpMessage='Specify input:',Position=0)]
        [ValidateNotNullorEmpty()]
        [Alias('Variable')]
        [string]$Message,
        [Parameter(Mandatory=$false,Position=1)]
        [ValidateSet('Console','Verbose')]
        [string]$Type = 'Console',
        [Parameter(Mandatory=$false,Position=2)]
        [ValidateSet('No','Before','After','BeforeAndAfter')]
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

#region Function Get-AzureBlobStorageItem
Function Get-AzureBlobStorageItem {
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
    Get-AzureBlobStorageItem -Url 'https://<storageaccount>.blob.core.windows.net/<Container>' -SasToken 'SomeAccessToken'
.EXAMPLE
    Get-AzureBlobStorageItem -Url 'https://<storageaccount>.blob.core.windows.net/<Container>/<blob>' -SasToken 'SomeAccessToken'
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
        [Parameter(Mandatory=$true,HelpMessage='Blob URL:',Position=0)]
        [ValidateNotNullorEmpty()]
        [Alias('Location')]
        [string]$Url,
        [Parameter(Mandatory=$false,HelpMessage='Blob SAS Token:',Position=1)]
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
                #  Build URI
                [string]$Uri = If ($IsSecure) { '{0}?{1}' -f ($Url, $SasToken) } Else { $Url }
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
                [string]$Uri = If ($IsSecure) { '{0}?{1}&{2}' -f ($Url, 'restype=container&comp=list', $SasToken) } Else { '{0}?{1}' -f ($Url, 'restype=container&comp=list') }
                #  Invoke REST API
                $Response = Invoke-RestMethod -Uri $Uri -Method 'Get' -Verbose:$false
                #  Cleanup response and convert to XML
                $Xml = [xml]$Response.Substring($Response.IndexOf('<'))
                #  Get the file objects
                $Blobs = $Xml.ChildNodes.Blobs.Blob
                #  Build the output object
                $AzureBlobList = ForEach ($Blob in $Blobs) {
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
    Lists directories and files for a path.
.DESCRIPTION
    Lists directories and files for a path storage using REST API.
.PARAMETER Url
    Specifies the azure share URL.
.PARAMETER SasToken
    Specifies the azure share SAS token. Specifies the azure share SAS token. If this parameter is not specified, no authentication is used.
.EXAMPLE
    Get-AzureFileStorageItem -Url 'https://<storageaccount>.file.core.windows.net/<SomeShare/SomeFolder>' -SasToken 'SomeAccessToken'
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
    List Items
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true,HelpMessage='Share URL:',Position=0)]
        [ValidateNotNullorEmpty()]
        [Alias('Location')]
        [string]$Url,
        [Parameter(Mandatory=$false,HelpMessage='Share SAS Token:',Position=1)]
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

            ## Extract file name from the URL if it exist
            $FileName = $($Url | Select-String -AllMatches -Pattern $RegexPattern | Select-Object -ExpandProperty 'Matches').Value

            ## If URL is a file, get the properties
            If (-not [string]::IsNullOrEmpty($FileName)) {
                #  Build URI
                [string]$Uri = If ($IsSecure) { '{0}?{1}' -f ($Url, $SasToken) } Else { $Url }
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
                [string]$Uri = If ($IsSecure) { '{0}?{1}&{2}' -f ($Url, 'restype=directory&comp=list', $SasToken) } Else { '{0}?{1}' -f ($Url, 'restype=directory&comp=list') }
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
            $PSCmdlet.WriteError($PSItem)
        }
        Finally {
            Write-Output -InputObject $AzureFileList
        }
    }
    End {
    }
}
#endregion

#region Function Start-AzureStorageFileTransfer
Function Start-AzureStorageFileTransfer {
<#
.SYNOPSIS
    Transfers the contents of a file.
.DESCRIPTION
    Transfers the contents of a file from Azure File or Blob storage using BITS.
.PARAMETER Url
    Specifies the azure share URL.
.PARAMETER SasToken
    Specifies the azure share SAS security token. If this parameter is not specified no authentication is performed.
.PARAMETER Path
    Specifies the destination path.
.PARAMETER Force
    Overwrites the existing file even if it has the same name and size. I can't think why this would be needed but I added it anyway.
.EXAMPLE
    Start-AzureStorageFileTransfer -Url 'https://<storageaccount>.file.core.windows.net/<SomeShare/SomeFolder>' -SasToken 'SomeAccessToken' -Path 'D:\Temp'
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
.COMPONENT
    Azure File Storage Rest API
.FUNCTIONALITY
    Transfer to local storage
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true,HelpMessage='Share URL:',Position=0)]
        [ValidateNotNullorEmpty()]
        [Alias('Location')]
        [string]$Url,
        [Parameter(Mandatory=$false,HelpMessage='Share SAS Token:',Position=1)]
        [Alias('Sas')]
        [string]$SasToken,
        [Parameter(Mandatory=$true,HelpMessage='Local Transfer Path:',Position=2)]
        [Alias('Destination')]
        [string]$Path,
        [Alias('Overwrite')]
        [switch]$Force
    )

    Begin {

        ## Check if no security token is provided
        $IsSecure = [boolean](-not [string]::IsNullOrEmpty($SasToken))

        ## Remove the '?' from the SAS string if needed
        If ($SasToken[0] -eq '?') { $SasToken = $SasToken -replace ('\?', '') }
    }
    Process {
        Try {

            ## Get azure file list depending on the storage type
            If ($Url -match '.blob.') { $AzureFileList = Get-AzureBlobStorageItem -Url $Url -Sas $SasToken }
            Else { $AzureFileList = Get-AzureFileStorageItem -Url $Url -Sas $SasToken }

            ## Get local file list
            $LocalFileList = Get-ChildItem -Path $Path -ErrorAction 'SilentlyContinue' | Select-Object -Property 'Name', @{Name = 'Size(KB)'; Expression = {'{0:N2}' -f ($PSItem.Length / 1KB)}}

            ## Create destination folder
            If (-not [System.IO.Directory]::Exists($Path)) { [System.IO.Directory]::CreateDirectory($Path) }

            ## Process files one by one
            $CopiedFileList = ForEach ($File in $AzureFileList) {

                ## If the file is already present and the same size, set the 'Skip' flag.
                [psobject]$LocalFileLookup = $LocalFileList | Where-Object { $PSItem.Name -eq $File.Name -and $PSItem.'Size(KB)' -eq $File.'Size(KB)' } | Select-Object -Property 'Name'
                $SkipFile = [boolean](-not [string]::IsNullOrEmpty($LocalFileLookup))

                ## Assemble Destination and URI
                [string]$Destination = Join-Path -Path $Path -ChildPath $File.Name
                [string]$Uri = If ($IsSecure) { '{0}?{1}' -f ($File.Url, $SasToken) } Else { $File.Url }
                $Overwrite = [boolean]($Force -and $SkipFile)

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
                        $Overwrite { 'Overwritten'; Break }
                        $SkipFile  { 'Skipped' ; Break }
                        Default    { 'Transfered' }
                    }
                }
            }
        }
        Catch {
            $PSCmdlet.WriteError($PSItem)
        }
        Finally {
            Write-Output -InputObject $CopiedFileList
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
        [Parameter(Mandatory=$true,HelpMessage='Destination Path:',Position=0)]
        [ValidateNotNullorEmpty()]
        [Alias('Destination')]
        [string]$Path,
        [Parameter(Mandatory=$true,HelpMessage='Share URL:',Position=1)]
        [ValidateNotNullorEmpty()]
        [Alias('Location')]
        [string]$Url,
        [Parameter(Mandatory=$false,HelpMessage='Share SAS Token:',Position=2)]
        [Alias('Sas')]
        [string]$SasToken,
        [Alias('Overwrite')]
        [switch]$Force
    )
    Begin {

        ## Import IDesktop API
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
            If ($Url -match '.blob.') { [psobject]$AzureThemeFile = Get-AzureBlobStorageItem -Url $Url -SasToken $SasToken -ErrorAction 'Stop' }
            Else { [psobject]$AzureThemeFile = Get-AzureStorageFile -Url $Url -SasToken $SasToken -ErrorAction 'Stop' }

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
                $DownloadTheme = Start-AzureStorageFileTransfer -Url $Url -SasToken $SasToken -Path $Path -Force:$Force -ErrorAction 'Stop'
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
