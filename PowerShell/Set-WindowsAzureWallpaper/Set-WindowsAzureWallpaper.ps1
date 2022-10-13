<#
.SYNOPSIS
    Sets the wallpaper for windows 10.
.DESCRIPTION
    Sets the wallpaper for windows 10, by downloading the necessary wallpaper files from Azure File Storage and activating the default wallpaper.
.PARAMETER Path
    Specifies the destination path for the wallpapers.
.PARAMETER DefaultResolution
    Specifies the default wallpaper resolution. This will be used if no matches for the monitor resolution are found in azure file storage.
.PARAMETER Position
    Specifies the wallpaper position or style on the screen. Acceptable values are: 'Center, Tile, Stretch, Fit, Fill, Span'.
.PARAMETER SlideShowOptions
    Specifies whether the wallpaper slide show should be shuffled or not. Acceptable values are: 'EnableShuffle', 'DisableShuffle'.
.PARAMETER SlideShowInterval
    Specifies the interval between wallpaper slides in seconds.
.PARAMETER Url
    Specifies the azure file storage share URL.
.PARAMETER SasToken
    Specifies the azure file storage share SAS token. If the SAS token is not specified, the theme file will be downloaded from Azure File Storage without authentication.
.PARAMETER Force
    Overwrite the existing wallpaper even if it is already assigned.
.EXAMPLE
    [hashtable]$Parameters = @{
        Path              = Join-Path -Path $env:ProgramData -ChildPath 'SomeCompany\Wallpapers'
        DefaultResolution = '1920x1200'
        Position          = 'Stretch'
        Url               = 'https://testcmspublic.file.core.windows.net/public/SomeCompany/Branding/Wallpapers'
        SasToken          = '?sv=2020-02-10&ss=f&srt=co&sp=rl&se=2022-02-23T16:50:56Z&st=2021-02-23T08:50:56Z&spr=https&sig=U1ksjwFS7x970xYezvG%2B%2FfIQYoX6k12VY95xOVfDm6Y%3D'
        Force             = $false
        Verbose           = $true
    }
    Set-WindowsAzureWallpaper.ps1 @Parameters
.EXAMPLE
    [hashtable]$Parameters = @{
        Path               = Join-Path -Path $env:ProgramData -ChildPath 'SomeCompany\Wallpapers'
        DefaultResolution  = '1920x1200'
        SlideShowOptions   = 'EnableShuffle'
        SlideShowInterval  =  1800
        Url                = 'https://testcmspublic.file.core.windows.net/public/SomeCompany/Branding/Wallpapers'
        SasToken           = '?sv=2020-02-10&ss=f&srt=co&sp=rl&se=2022-02-23T16:50:56Z&st=2021-02-23T08:50:56Z&spr=https&sig=U1ksjwFS7x970xYezvG%2B%2FfIQYoX6k12VY95xOVfDm6Y%3D'
        Force              = $false
        Verbose            = $true
    }
    Set-WindowsAzureWallpaper.ps1 @Parameters
.INPUTS
    None.
.OUTPUTS
    System.String
.NOTES
    Created by Ioan Popovici
    Wallpaper files need to have the resolution specified in the file name.(e.g. xxx1920x1200xxx.jpg).
    If you have MEMCM you can run the SQL query linked below (Get-ScreenResolution-SQL) in order to get the most common resolutions used in your environment.
    You can use this script in a baseline as a MEMCM 'Detection' script.
.LINK
    https://MEM.Zone/Set-WindowsAzureWallpaper
.LINK
    https://MEM.Zone/Set-WindowsAzureWallpaper-CHANGELOG
.LINK
    https://MEM.Zone/Set-WindowsAzureWallpaper-GIT
.LINK
    https://MEM.Zone/Get-ScreenResolution-SQL
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    Desktop
.FUNCTIONALITY
    Change Wallpaper
#>

## Set script requirements
#Requires -Version 3.0

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

## !! Comment the region below if using in-script parameter values. You can set the parameters in the SCRIPT BODY region at the end of the script !!
#region ScriptParameters
[CmdletBinding(DefaultParameterSetName = 'Wallpaper')]
Param (
    [Parameter(Mandatory = $true, ParameterSetName = 'Wallpaper', HelpMessage = 'Destination Path:', Position = 0)]
    [Parameter(Mandatory = $true, ParameterSetName = 'Slideshow', HelpMessage = 'Destination and Slideshow Path:', Position = 0)]
    [ValidateNotNullorEmpty()]
    [Alias('Destination')]
    [string]$Path,
    [Parameter(Mandatory = $true, ParameterSetName = 'Wallpaper', HelpMessage = 'Default Wallpaper Resolution:', Position = 1)]
    [Parameter(Mandatory = $true, ParameterSetName = 'Slideshow', HelpMessage = 'Default Wallpaper Resolution:', Position = 1)]
    [Alias('Default')]
    [string]$DefaultResolution,
    [Parameter(Mandatory = $false, ParameterSetName = 'Wallpaper', HelpMessage = 'Wallpaper Position (Center, Tile, Stretch, Fit, Fill, Span):', Position = 2)]
    [ValidateSet('Center', 'Tile', 'Stretch', 'Fit', 'Fill', 'Span')]
    [Alias('Style')]
    [string]$Position = 'Stretch',
    [Parameter(Mandatory = $true, ParameterSetName = 'Slideshow', HelpMessage = 'Enable Slideshow Shuffle? (EnableShuffle / DisableShuffle)', Position = 2)]
    [ValidateSet('EnableShuffle', 'DisableShuffle')]
    [Alias('Shuffle')]
    [string]$SlideShowOptions,
    [Parameter(Mandatory = $true, ParameterSetName = 'Slideshow', HelpMessage = 'Slideshow Advance Interval (Seconds):', Position = 3)]
    [ValidateSet('EnableShuffle', 'DisableShuffle')]
    [Alias('Interval')]
    [string]$SlideShowInterval,
    [Parameter(Mandatory = $true, ParameterSetName = 'Wallpaper', HelpMessage = 'Share URL:', Position = 3)]
    [Parameter(Mandatory = $true, ParameterSetName = 'Slideshow', HelpMessage = 'Share URL:', Position = 4)]
    [ValidateNotNullorEmpty()]
    [Alias('Location')]
    [string]$Url,
    [Parameter(Mandatory = $true, ParameterSetName = 'Wallpaper', HelpMessage = 'Share SAS Token:', Position = 4)]
    [Parameter(Mandatory = $true, ParameterSetName = 'Slideshow', HelpMessage = 'Share SAS Token:', Position = 5)]
    [ValidateNotNullorEmpty()]
    [Alias('Sas')]
    [string]$SasToken,
    [Parameter(ParameterSetName = 'Wallpaper')]
    [Parameter(ParameterSetName = 'Slideshow')]
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
        [Parameter(Mandatory = $false,  Position = 1)]
        [ValidateSet('Console', 'Verbose')]
        [string]$Type = 'Console',
        [Parameter(Mandatory = $false,  Position = 2)]
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
            $PSCmdlet.ThrowTerminatingError($PSItem)
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
        [Parameter(Mandatory = $true, ParameterSetName = 'GetContent', HelpMessage = 'Share URL:', Position = 0)]
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

#region Function Import-Win32IDesktopAPI
Function Import-Win32IDesktopAPI {
<#
.SYNOPSIS
    Imports the Win32 IDesktop interface.
.DESCRIPTION
    Imports the Win32 IDesktop API so it can be used in PowerShell.
.EXAMPLE
    Import-Win32IDesktopAPI
.EXAMPLE
    [string]$SlideshowDirection = 'Forward'
    [string]$WallpaperPath = 'C:\Windows\Web\Screen'
    [string]$WallpaperPosition = 'Stretch'
    [string]$WallpaperFolder = 'SomePath'
    [string]$SlideshowOptions = 'EnableShuffle'
    [int]$DisplayIndex = 0
    [int]$AdvanceIntervalInSeconds = 1800
    [array]$ShellItemArray = $null

    Import-Win32IDesktopAPI

    ## Monitor Command
    $MonitorCommand = New-Object -TypeName 'MEMZone.MonitorCommand'

    $MonitorCommand::GetMonitor()
    $MonitorCommand::GetMonitorCount()
    $MonitorCommand::GetMonitorID($DisplayIndex)
    $MonitorCommand::GetMonitorRECT($DisplayIndex)

    ## Wallpaper Command
    $WallpaperCommand = New-Object -TypeName 'MEMZone.WallpaperCommand'

    $WallpaperCommand::SetWallpaper($DisplayIndex, $WallpaperPath, $WallpaperPosition)
    $WallpaperCommand::GetWallpaper($DisplayIndex)
    $WallpaperCommand::GetWallpaperPosition()
    $WallpaperCommand::SetWallpaperPosition($WallpaperPosition)
    $WallpaperCommand::SetBackgroundColor(0)
    $WallpaperCommand::GetBackgroundColor()
    $WallpaperCommand::AdvanceSlideshow(0, $SlideshowDirection)
    $WallpaperCommand::EnableWallpaper(0)
    $WallpaperCommand::GetSlideshowStatus()
    $WallpaperCommand::SetSlideshowOptions($SlideshowOptions, $AdvanceIntervalInSeconds)
    $WallpaperCommand::SetSlideshowPath($WallpaperFolder)

    ## File System Command (Not applicable to the SetSlideshowPath method, as it already has this built-in)
    $FileSystemCommand = New-Object -TypeName 'MEMZone.FileSystemCommand'

    $FileSystemCommand::ILCreateFromPath($WallpaperFolder)
    $FileSystemCommand::SHCreateShellItemArrayFromIDLists(1, $FileSystemCommand::ILCreateFromPath($WallpaperFolder), [ref]$ShellItemArray)
.INPUTS
    None.
.OUTPUTS
    None.
.NOTES
    Created by Ioan Popovici
    Credit to Adrian Hum and Federico Paolillo

    This is an private function should tipically not be called directly.
.LINK
    https://docs.microsoft.com/en-us/windows/win32/api/shobjidl_core/nn-shobjidl_core-idesktopwallpaper
.LINK
    https://gist.github.com/LGM-AdrianHum/5dd61cd64377e725393a6b5b62b1d431
.LINK
    https://github.com/federico-paolillo/set-wallpaper
.LINK
    https://MEM.Zone/Import-Win32IDesktopAPI
.LINK
    https://MEM.Zone/Import-Win32IDesktopAPI-CHANGELOG
.LINK
    https://MEM.Zone/Import-Win32IDesktopAPI-GIT
.LINK
    https://MEM.Zone/Issues
.COMPONENT
    Win32 API
.FUNCTIONALITY
    Import IDesktop API
#>
    [CmdletBinding()]
    Param ()

    Begin {

        #region VariableDeclaration
        [string[]]$ReferencedAssemblies = @('System.Windows.Forms', 'System.Drawing', 'System.Management', 'System.Management.Automation')
        [string]$TypeDefinition =
@'
        using System.Collections.Generic;
        using System;
        using System.IO;
        using System.Text;
        using System.Drawing;
        using System.Globalization;
        using System.Windows.Forms;
        using System.Runtime.InteropServices;
        using System.Management;
        using System.Management.Automation;
        using System.Linq;
        using Microsoft.Win32;
        using MEMZone;
        using MEMZone.Helpers;
        using MEMZone.COM;
        using MEMZone.Output;

        namespace MEMZone.Helpers {

            // <summary>
            //     This structure used to resolve HRESULT responses.
            // </summary>
            public enum HRESULT : int {
                S_OK = 0,
                S_FALSE = 1,
                E_ABORT = unchecked((int)0x80004004),
                E_ACCESSDENIED = unchecked((int)0x80070005),
                E_FAIL = unchecked((int)0x80004005),
                E_HANDLE = unchecked((int)0x80070006),
                E_INVALIDARG = unchecked((int)0x80070057),
                E_NOINTERFACE = unchecked((int)0x80004002),
                E_NOTIMPL = unchecked((int)0x80004001),
                E_OUTOFMEMORY = unchecked((int)0x8007000E),
                E_POINTER = unchecked((int)0x80004003),
                E_UNEXPECTED = unchecked((int)0x8000FFFF),
            }

            // <summary>
            //     This structure used to get the display rectangle coordinates.
            // </summary>
            [StructLayout(LayoutKind.Sequential)]
            public struct Rect {
                public int Left;
                public int Top;
                public int Right;
                public int Bottom;
            }

            // <summary>
            //     This enumeration indicates the wallpaper position for all monitors. (This includes when slideshows are running.)
            //     The wallpaper position specifies how the image that is assigned to a monitor should be displayed.
            // </summary>
            public enum WallpaperPosition {
                Center = 0,
                Tile = 1,
                Stretch = 2,
                Fit = 3,
                Fill = 4,
                Span = 5,
            }

            // <summary>
            //     This enumeration is used to set and get slideshow options.
            // </summary>
            public enum SlideshowOptions {
                DisableShuffle = 0,
                EnableShuffle = 0x01,
            }

            // <summary>
            //     This enumeration is used by GetStatus to indicate the current status of the slideshow.
            // </summary>
            [Flags]
            public enum SlideshowState {
                Disabled = 0,
                Enabled = 1,
                Slideshow = 2,
                DisabledByRemoteSession = 4,
            }

            // <summary>
            //     This enumeration is used by the AdvanceSlideshow method to indicate whether to advance the slideshow forward or backward.
            // </summary>
            public enum SlideshowDirection {
                Forward = 0,
                Backward = 1,
            }

            // <summary>
            //     This enumeration is used in the IShellItem interface by the GetDisplayName method.
            // </summary>
            public enum SIGDN : int {
                SIGDN_NORMALDISPLAY = 0x0,
                SIGDN_PARENTRELATIVEPARSING = unchecked((int)0x80018001),
                SIGDN_DESKTOPABSOLUTEPARSING = unchecked((int)0x80028000),
                SIGDN_PARENTRELATIVEEDITING = unchecked((int)0x80031001),
                SIGDN_DESKTOPABSOLUTEEDITING = unchecked((int)0x8004C000),
                SIGDN_FILESYSPATH = unchecked((int)0x80058000),
                SIGDN_URL = unchecked((int)0x80068000),
                SIGDN_PARENTRELATIVEFORADDRESSBAR = unchecked((int)0x8007C001),
                SIGDN_PARENTRELATIVE = unchecked((int)0x80080001)
            }

            // <summary>
            //     This enumeration is used in the IShellItemArray interface by the GetPropertyStore method.
            // </summary>
            public enum GETPROPERTYSTOREFLAGS {
                GPS_DEFAULT = 0,
                GPS_HANDLERPROPERTIESONLY = 0x1,
                GPS_READWRITE = 0x2,
                GPS_TEMPORARY = 0x4,
                GPS_FASTPROPERTIESONLY = 0x8,
                GPS_OPENSLOWITEM = 0x10,
                GPS_DELAYCREATION = 0x20,
                GPS_BESTEFFORT = 0x40,
                GPS_NO_OPLOCK = 0x80,
                GPS_PREFERQUERYPROPERTIES = 0x100,
                GPS_EXTRINSICPROPERTIES = 0x200,
                GPS_EXTRINSICPROPERTIESONLY = 0x400,
                GPS_MASK_VALID = 0x7FF
            }

            // <summary>
            //     This enumeration is used in the IShellItemArray interface by the GetAttributes method.
            // </summary>
            public enum SIATTRIBFLAGS {
                SIATTRIBFLAGS_AND = 0x1,
                SIATTRIBFLAGS_OR = 0x2,
                SIATTRIBFLAGS_APPCOMPAT = 0x3,
                SIATTRIBFLAGS_MASK = 0x3,
                SIATTRIBFLAGS_ALLITEMS = 0x4000
            }

            // <summary>
            //     This enumeration is used in the IShellItemArray interface by the GetPropertyDescriptionList method.
            // </summary>
            [StructLayout(LayoutKind.Sequential, Pack = 4)]
            public struct REFPROPERTYKEY {
                private Guid fmtid;
                private int pid;
                public Guid FormatId {
                    get { return this.fmtid; }
                }
                public int PropertyId {
                    get { return this.pid; }
                }
                public REFPROPERTYKEY(Guid formatId, int propertyId) {
                    this.fmtid = formatId;
                    this.pid = propertyId;
                }
                public static readonly REFPROPERTYKEY PKEY_DateCreated = new REFPROPERTYKEY(new Guid("B725F130-47EF-101A-A5F1-02608C9EEBAC"), 15);
            }
        }

        namespace MEMZone.COM {

            [ComImport]
            [Guid("B92B56A9-8B55-4E14-9A89-0199BBB6F93B")]
            [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
            public interface IDesktopWallpaper {

                HRESULT SetWallpaper([MarshalAs(UnmanagedType.LPWStr)] string monitorID, [MarshalAs(UnmanagedType.LPWStr)] string wallpaper);

                [return: MarshalAs(UnmanagedType.LPWStr)]
                string GetWallpaper([MarshalAs(UnmanagedType.LPWStr)] string monitorID);

                [return: MarshalAs(UnmanagedType.LPWStr)]
                string GetMonitorDevicePathAt(uint monitorIndex);

                [return: MarshalAs(UnmanagedType.U4)]
                uint GetMonitorDevicePathCount();

                [return: MarshalAs(UnmanagedType.Struct)]
                Rect GetMonitorRECT([MarshalAs(UnmanagedType.LPWStr)] string monitorID);

                HRESULT SetBackgroundColor([MarshalAs(UnmanagedType.U4)] uint color);

                [return: MarshalAs(UnmanagedType.U4)]
                uint GetBackgroundColor();

                HRESULT SetPosition([MarshalAs(UnmanagedType.I4)] WallpaperPosition position);

                [return: MarshalAs(UnmanagedType.I4)]
                WallpaperPosition GetPosition();

                HRESULT SetSlideshow(IShellItemArray items);

                IShellItemArray GetSlideshow();

                HRESULT SetSlideshowOptions(SlideshowOptions slideshowOptions, uint slideshowTick);

                [PreserveSig]
                HRESULT GetSlideshowOptions(out SlideshowOptions slideshowOptions, out uint slideshowTick);

                HRESULT AdvanceSlideshow([MarshalAs(UnmanagedType.LPWStr)] string monitorID, [MarshalAs(UnmanagedType.I4)] SlideshowDirection direction);

                SlideshowState GetStatus();

                HRESULT Enable([MarshalAs(UnmanagedType.Bool)] bool enable);
            }

            [ComImport]
            [Guid("C2CF3110-460E-4fc1-B9D0-8A1C0C9CC4BD")]
            public class DesktopWallpaper { }

            [ComImport()]
            [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
            [Guid("b63ea76d-1f85-456f-a19c-48159efa858b")]
            public interface IShellItemArray {
                HRESULT BindToHandler(IntPtr pbc, ref Guid bhid, ref Guid riid, ref IntPtr ppvOut);
                HRESULT GetPropertyStore(GETPROPERTYSTOREFLAGS flags, ref Guid riid, ref IntPtr ppv);
                HRESULT GetPropertyDescriptionList(REFPROPERTYKEY keyType, ref Guid riid, ref IntPtr ppv);
                HRESULT GetAttributes(SIATTRIBFLAGS AttribFlags, int sfgaoMask, ref int psfgaoAttribs);
                HRESULT GetCount(ref int pdwNumItems);
                HRESULT GetItemAt(int dwIndex, ref IShellItem ppsi);
                HRESULT EnumItems(ref IntPtr ppenumShellItems);
            }

            [ComImport()]
            [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
            [Guid("43826D1E-E718-42EE-BC55-A1E261C37BFE")]
            public interface IShellItem {
                [PreserveSig()]
                HRESULT BindToHandler(IntPtr pbc, ref Guid bhid, ref Guid riid, ref IntPtr ppv);
                HRESULT GetParent(ref IShellItem ppsi);
                HRESULT GetDisplayName(SIGDN sigdnName, ref System.Text.StringBuilder ppszName);
                HRESULT GetAttributes(uint sfgaoMask, ref uint psfgaoAttribs);
                HRESULT Compare(IShellItem psi, uint hint, ref int piOrder);
            }
        }

        namespace MEMZone.Output {

            // <summary>
            //     Information about a computer monitor installed in this system.
            // </summary>
            public sealed class Monitor {

                public Monitor(uint index, string name, string id, string resolution) {
                    Index = index;
                    Name = name;
                    ID = id;
                    Resolution = resolution;
                }

                public uint Index { get; set; }
                public string Name { get; set; }
                public string ID { get; set; }
                public string Resolution { get; set; }
            }

            // <summary>
            //     Information about a wallpaper currently set on a specific monitor.
            // </summary>
            public sealed class Wallpaper {

                public Wallpaper(uint index, string name, string path, WallpaperPosition position) {
                    Index = index;
                    Name = name;
                    Path = path;
                    Position = position;
                }

                public uint Index { get; set; }
                public string Name { get; set; }
                public string Path { get; set; }
                public WallpaperPosition Position { get; set; }
            }
        }

        namespace  MEMZone {

            // <summary>
            //     Gets monitor information.
            // </summary>
            public class MonitorCommand {

                // <summary>
                //     Gets information for specified or all attached monitors.
                // </summary>
                public static List<Monitor> GetMonitor(uint monitorIndex = 99) {

                    // Variable declaration
                    IDesktopWallpaper desktopWallpaper = null;
                    desktopWallpaper = (IDesktopWallpaper) new DesktopWallpaper();
                    uint monitorsCount = 0;
                    var monitors = new List<Monitor>();

                    // Get number of monitors
                    monitorsCount = desktopWallpaper.GetMonitorDevicePathCount();
                    // Console.WriteLine("Found {0} monitors.", monitorsCount);

                    // Query all monitors if no monitor index is provided
                    if (monitorIndex == 99) {

                        // Set monitorIndex to 0
                        monitorIndex = 0;

                        foreach (Screen screen in Screen.AllScreens) {

                            // Get monitor name
                            string monitorName = screen.DeviceName.ToString().Split('\\').Last();

                            // Get monitor id
                            string monitorID = GetMonitorID(monitorIndex);

                            // Get monitor bounds
                            string screenBoundsWidth  = screen.Bounds.Width.ToString();
                            string screenBoundsHeight = screen.Bounds.Height.ToString();

                            // Assemble monitor resolution
                            string monitorResolution = screenBoundsWidth + 'x' + screenBoundsHeight;

                            // Build monitor object
                            Monitor monitor = new Monitor(monitorIndex, monitorName, monitorID, monitorResolution);

                            // Add monitor object to monitor list
                            monitors.Add(monitor);

                            // Increment monitor index
                            monitorIndex ++;
                        }
                    }
                    else {

                        // Get monitor name
                        string monitorName =  Screen.PrimaryScreen.DeviceName.ToString().Split('\\').Last();

                        // Get monitor ID
                        string monitorID = GetMonitorID(monitorIndex);

                        // Get monitor bounds
                        string screenBoundsWidth  = Screen.PrimaryScreen.Bounds.Width.ToString();
                        string screenBoundsHeight = Screen.PrimaryScreen.Bounds.Height.ToString();

                        // Assemble monitor resolution
                        string monitorResolution = screenBoundsWidth + 'x' + screenBoundsHeight;

                        // Build monitor object
                        Monitor monitor = new Monitor(monitorIndex, monitorName, monitorID, monitorResolution);

                        // Add monitor object to monitor list
                        monitors.Add(monitor);
                    }

                    // Release COM object
                    Marshal.ReleaseComObject(desktopWallpaper);

                    // Return monitor list
                    return monitors;
                }

                // <summary>
                //     Gets monitor rectangle coordinates.
                // </summary>
                public static Rect GetMonitorRECT(uint monitorIndex) {

                    // Assign variables
                    IDesktopWallpaper desktopWallpaper = null;
                    desktopWallpaper = (IDesktopWallpaper) new DesktopWallpaper();

                    // Get monitorID
                    string monitorID = GetMonitorID(monitorIndex);

                    // Get monitor display rectangle
                    Rect displayRectangle = desktopWallpaper.GetMonitorRECT(monitorID);

                    // Release COM object
                    Marshal.ReleaseComObject(desktopWallpaper);

                    // Return wallpaperPosition object
                    return displayRectangle;
                }

                // <summary>
                //     Gets the monitor hardware id.
                // </summary>
                public static string GetMonitorID(uint monitorIndex) {

                    // Assign variables
                    IDesktopWallpaper desktopWallpaper = null;
                    desktopWallpaper = (IDesktopWallpaper) new DesktopWallpaper();

                    // Get monitor id
                    string monitorID = desktopWallpaper.GetMonitorDevicePathAt(monitorIndex).ToString();

                    // Release COM object
                    Marshal.ReleaseComObject(desktopWallpaper);

                    // Return wallpaperPosition object
                    return monitorID;
                }

                // <summary>
                //     Gets the total attached monitor count.
                // </summary>
                public static uint GetMonitorCount() {

                    // Assign variables
                    IDesktopWallpaper desktopWallpaper = null;
                    desktopWallpaper = (IDesktopWallpaper) new DesktopWallpaper();

                    // Getmonitor counts
                    uint monitorCount = desktopWallpaper.GetMonitorDevicePathCount();

                    // Release COM object
                    Marshal.ReleaseComObject(desktopWallpaper);

                    // Return wallpaperPosition object
                    return monitorCount;
                }
            }

            // <summary>
            //     Gets and sets wallpaper information.
            // </summary>
            public class WallpaperCommand {

                // <summary>
                //     Gets the wallpaper for specified or all attached monitors.
                // </summary>
                public static List<Wallpaper> GetWallpaper(uint monitorIndex = 99) {

                    // Assign variables
                    IDesktopWallpaper desktopWallpaper = null;
                    desktopWallpaper = (IDesktopWallpaper) new DesktopWallpaper();
                    uint monitorsCount = 0;
                    var wallpapers = new List<Wallpaper>();

                    // Query all monitors if no monitor index is provided
                    if (monitorIndex == 99) {

                        // Set monitorIndex to 0
                        monitorIndex = 0;

                        // Get number of monitors
                        monitorsCount = MonitorCommand.GetMonitorCount();
                        // Console.WriteLine("Found {0} monitors.", monitorsCount);

                        // Cycle trough all monitors and get monitor info
                        foreach (Screen screen in Screen.AllScreens) {

                            // Get monitor ID
                            string monitorID = MonitorCommand.GetMonitorID(monitorIndex);

                            // Get wallpaper path
                            string wallpaperPath = desktopWallpaper.GetWallpaper(monitorID);

                            // Get wallpaper position
                            WallpaperPosition wallpaperPosition = GetWallpaperPosition();

                            // Get monitor Name
                            string monitorName = screen.DeviceName.ToString().Split('\\').Last();

                            // Build wallpaper object
                            Wallpaper wallpaper = new Wallpaper(monitorIndex, monitorName, wallpaperPath, wallpaperPosition);

                            // Add wallpaper object to wallpapers list
                            wallpapers.Add(wallpaper);

                            // Increment monitor index
                            monitorIndex ++;
                        }
                    }
                    else {

                        // Get monitor ID
                        string monitorID = MonitorCommand.GetMonitorID(monitorIndex);

                        // Get wallpaper path
                        string wallpaperPath = desktopWallpaper.GetWallpaper(monitorID);

                        // Get wallpaper position
                        WallpaperPosition wallpaperPosition = GetWallpaperPosition();

                        // Get monitor Name
                        string monitorName =  Screen.PrimaryScreen.DeviceName.ToString().Split('\\').Last();

                        // Build result object
                        Wallpaper wallpaper = new Wallpaper(monitorIndex, monitorName, wallpaperPath, wallpaperPosition);

                        // Add wallpaper object to wallpapers list
                        wallpapers.Add(wallpaper);
                    }

                    // Release COM object
                    Marshal.ReleaseComObject(desktopWallpaper);

                    // Write wallpaper list
                    return wallpapers;
                }

                // <summary>
                //     Gets the wallpaper position.
                // </summary>
                public static WallpaperPosition GetWallpaperPosition() {

                    // Assign variables
                    IDesktopWallpaper desktopWallpaper = null;
                    desktopWallpaper = (IDesktopWallpaper) new DesktopWallpaper();

                    // Get wallpaper position
                    WallpaperPosition wallpaperPosition = desktopWallpaper.GetPosition();

                    // Release Com Object
                    Marshal.ReleaseComObject(desktopWallpaper);

                    // Return wallpaperPosition object
                    return wallpaperPosition;
                }

                // <summary>
                //     Gets the background color.
                // </summary>
                public static uint GetBackgroundColor() {

                    // Assign variables
                    IDesktopWallpaper desktopWallpaper = null;
                    desktopWallpaper = (IDesktopWallpaper) new DesktopWallpaper();

                    // Get background color
                    uint backgroundColor = desktopWallpaper.GetBackgroundColor();

                    // Release COM object
                    Marshal.ReleaseComObject(desktopWallpaper);

                    // Write backgroundColor value
                    return backgroundColor;
                }

                // <summary>
                //     Gets the slideshow state.
                // </summary>
                public static SlideshowState GetSlideshowStatus() {

                    // Assign variables
                    IDesktopWallpaper desktopWallpaper = null;
                    desktopWallpaper = (IDesktopWallpaper) new DesktopWallpaper();

                    // Get slideshow state
                    SlideshowState slideshowState = desktopWallpaper.GetStatus();


                    // Release COM object
                    Marshal.ReleaseComObject(desktopWallpaper);

                    // Write slideshowState value
                    return slideshowState;
                }

                // <summary>
                //     Sets the wallpaper and wallpaper position for a specific monitor.
                // </summary>
                public static HRESULT SetWallpaper(uint monitorIndex, string wallpaperPath, string wallpaperPosition) {

                    // Assign variables
                    IDesktopWallpaper desktopWallpaper = null;
                    desktopWallpaper = (IDesktopWallpaper) new DesktopWallpaper();
                    HRESULT hResult;

                    // Get monitor ID
                    string monitorID = MonitorCommand.GetMonitorID(monitorIndex);

                    // Set wallpaper and position
                    hResult = desktopWallpaper.SetWallpaper(monitorID, wallpaperPath);
                    hResult = SetWallpaperPosition(wallpaperPosition);

                    // Release COM object
                    Marshal.ReleaseComObject(desktopWallpaper);

                    // Write info to console
                    // Console.WriteLine("MonitorIndex: {0}\nMonitorID: {1}\nWallpaperPath: {2}", monitorIndex, monitorID, wallpaperPath);

                    // Return hResult
                    return hResult;
                }

                // <summary>
                //     Sets the wallpaper position.
                // </summary>
                public static HRESULT SetWallpaperPosition(string wallpaperPosition) {

                    // Assign variables
                    IDesktopWallpaper desktopWallpaper = null;
                    desktopWallpaper = (IDesktopWallpaper) new DesktopWallpaper();
                    TextInfo txtInfo = new CultureInfo("en-us", false).TextInfo;
                    HRESULT hResult;

                    // Convert position to titlecase
                    wallpaperPosition = txtInfo.ToTitleCase(wallpaperPosition);

                    // Get wallpaper position enum number value
                    WallpaperPosition wallpaperPositionValue = (WallpaperPosition)Enum.Parse(typeof(WallpaperPosition), wallpaperPosition);

                    // Set wallpaper position
                    hResult = desktopWallpaper.SetPosition(wallpaperPositionValue);

                    // Release COM object
                    Marshal.ReleaseComObject(desktopWallpaper);

                    // Write info to console
                    // Console.WriteLine("Position: {0}", wallpaperPositionValue);

                    // Return hResult
                    return hResult;
                }

                // <summary>
                //     Sets the background color.
                // </summary>
                public static HRESULT SetBackgroundColor(uint color) {

                    // Assign variables
                    IDesktopWallpaper desktopWallpaper = null;
                    desktopWallpaper = (IDesktopWallpaper) new DesktopWallpaper();
                    HRESULT hResult;

                    // Set background color
                    hResult = desktopWallpaper.SetBackgroundColor(color);

                    // Release COM object
                    Marshal.ReleaseComObject(desktopWallpaper);

                    // Write info to console
                    Console.WriteLine("BackgroundColor: {0}", color);

                    // Return hResult
                    return hResult;
                }

                // <summary>
                //     Sets the wallpaper state to enabled or disabled.
                // </summary>
                public static HRESULT EnableWallpaper(bool enable) {

                    // Assign variables
                    IDesktopWallpaper desktopWallpaper = null;
                    desktopWallpaper = (IDesktopWallpaper) new DesktopWallpaper();
                    HRESULT hResult;

                    // Set background color
                    hResult = desktopWallpaper.Enable(enable);

                    // Release COM object
                    Marshal.ReleaseComObject(desktopWallpaper);

                    // Write info to console
                    Console.WriteLine("Enable wallpaper: {0}", enable);

                    // Return hResult
                    return hResult;
                }

                // <summary>
                //     Sets the wallpaper slideshow image shuffle and speed.
                // </summary>
                public static HRESULT SetSlideshowOptions(string slideshowOptions, uint slideshowTick) {

                    // Assign variables
                    IDesktopWallpaper desktopWallpaper = null;
                    desktopWallpaper = (IDesktopWallpaper) new DesktopWallpaper();
                    HRESULT hResult;

                    // Set slideshow options enum number value
                    SlideshowOptions slideshowOptionsValue = (SlideshowOptions)Enum.Parse(typeof(SlideshowOptions), slideshowOptions);

                    // Convert slideshowTick from seconds to milliseconds
                    uint slideshowTickValue = slideshowTick * 1000;

                    // Set slideshow options
                    hResult = desktopWallpaper.SetSlideshowOptions(slideshowOptionsValue, slideshowTickValue);

                    // Release COM object
                    Marshal.ReleaseComObject(desktopWallpaper);

                    // Write info to console
                    Console.WriteLine("Set slideshow options:\nShuffleImages: {0}\nIntervalInSconds: {1}", slideshowOptions, slideshowTick);

                    // Return hResult
                    return hResult;
                }

                // <summary>
                //     Switches the wallpaper on a specified monitor to the next image in the slideshow.
                // </summary>
                public static HRESULT AdvanceSlideshow(uint monitorIndex, string slideshowDirection) {

                    // Assign variables
                    IDesktopWallpaper desktopWallpaper = null;
                    desktopWallpaper = (IDesktopWallpaper) new DesktopWallpaper();
                    HRESULT hResult;

                    // Get monitor ID
                    string monitorID = MonitorCommand.GetMonitorID(monitorIndex);

                    // Get slideshow direction enum number value
                    SlideshowDirection slideshowDirectionValue = (SlideshowDirection)Enum.Parse(typeof(SlideshowDirection), slideshowDirection);
                    Console.WriteLine("Slideshow direction value: {0}", slideshowDirectionValue);

                    // Advance slideshow. I've put 'null' for the monitorID parameter because specifying a monitorID does not wrk anymore.
                    // With the 'null' as the monitorid parameter, the slideshow advances on the first index monitor.
                    // Will fix this if microsoft updates this method
                    hResult = desktopWallpaper.AdvanceSlideshow(null, slideshowDirectionValue);

                    // Release COM object
                    Marshal.ReleaseComObject(desktopWallpaper);

                    // Write info to console
                    Console.WriteLine("Advance slideshow:\nMonitorIndex: {0}\nMonitorID: {1}\nSlideshowDirection: {2}", monitorIndex, monitorID, slideshowDirection);

                    // Return hResult
                    return hResult;
                }

                // <summary>
                //     Sets the wallpaper slideshow image source folder path.
                // </summary>
                public static HRESULT SetSlideshowPath(string path) {

                    // Assign variables
                    IDesktopWallpaper desktopWallpaper = null;
                    desktopWallpaper = (IDesktopWallpaper) new DesktopWallpaper();
                    HRESULT hResult;
                    IShellItem pShellItem = null;
                    IShellItemArray pShellItemArray = null;

                    // Create shell item object
                    hResult = FileSystemCommand.SHCreateItemFromParsingName(path, IntPtr.Zero, typeof(IShellItem).GUID, out pShellItem);

                    // Create shell item object array
                    hResult = FileSystemCommand.SHCreateShellItemArrayFromShellItem(pShellItem, typeof(IShellItemArray).GUID, out pShellItemArray);

                    // Set slideshow folder
                    desktopWallpaper.SetSlideshow(pShellItemArray);

                    // Release COM object
                    Marshal.ReleaseComObject(desktopWallpaper);

                    // Return hResult
                    return hResult;
                }
            }

            // <summary>
            //     Performs file system operations.
            // </summary>
            public class FileSystemCommand {

                [DllImport("Shell32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
                public static extern IntPtr ILCreateFromPath([In, MarshalAs(UnmanagedType.LPWStr)] string pszPath);

                [DllImport("Shell32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
                public static extern HRESULT SHCreateShellItemArrayFromIDLists(uint cidl, [In, MarshalAs(UnmanagedType.LPArray, SizeParamIndex = 0)] IntPtr[] rgpidl, out IShellItemArray ppsiItemArray);

                [DllImport("Shell32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
                public static extern HRESULT SHCreateItemFromParsingName(string pszPath, IntPtr pbc, [In, MarshalAs(UnmanagedType.LPStruct)] Guid riid, out IShellItem ppv);

                [DllImport("Shell32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
                public static extern HRESULT SHCreateShellItemArrayFromShellItem(IShellItem psi, [In, MarshalAs(UnmanagedType.LPStruct)] Guid riid, out IShellItemArray ppv);
            }
        }
'@
        #endregion
    }
    Process {
        Try {
            $Win32API = Add-Type -TypeDefinition $TypeDefinition -ReferencedAssemblies $ReferencedAssemblies -ErrorAction 'Stop'
            Write-Verbose -Message 'Successfully imported Win32 IDesktop API.'
        }
        Catch {
            $PSCmdlet.WriteError($PSItem)
        }
        Finally {
            Write-Output -InputObject $Win32API
        }
    }
    End {
    }
}
#endregion

#region Function Set-WindowsAzureWallpaper
Function Set-WindowsAzureWallpaper {
<#
.SYNOPSIS
    Sets the wallpaper for windows 10.
.DESCRIPTION
    Sets the wallpaper for windows 10, by downloading the necessary wallpaper files from Azure File Storage and activating the wallpaper or wallpaper slideshow.
.PARAMETER Path
    Specifies the destination path for the wallpapers.
.PARAMETER DefaultResolution
    Specifies the default wallpaper resolution. This will be used if no matches for the monitor resolution are found in azure file storage.
.PARAMETER Position
    Specifies the wallpaper position or style on the screen. Acceptable values are: 'Center, Tile, Stretch, Fit, Fill, Span'.
.PARAMETER SlideShowOptions
    Specifies whether the wallpaper slide show should be shuffled or not. Acceptable values are: 'EnableShuffle', 'DisableShuffle'.
.PARAMETER SlideShowInterval
    Specifies the interval between wallpaper slides in seconds.
.PARAMETER Url
    Specifies the azure file storage share URL.
.PARAMETER SasToken
    Specifies the azure file storage share SAS token.
.PARAMETER Force
    Overwrite the existing wallpaper even if it is already assigned.
.EXAMPLE
    [hashtable]$Parameters = @{
        Path              = Join-Path -Path $env:ProgramData -ChildPath 'SomeCompany\Wallpapers'
        DefaultResolution = '1920x1200'
        Position          = 'Stretch'
        Url               = 'https://testcmspublic.file.core.windows.net/public/SomeCompany/Branding/Wallpapers'
        SasToken          = '?sv=2020-02-10&ss=f&srt=co&sp=rl&se=2022-02-23T16:50:56Z&st=2021-02-23T08:50:56Z&spr=https&sig=U1ksjwFS7x970xYezvG%2B%2FfIQYoX6k12VY95xOVfDm6Y%3D'
        Force             = $false
        Verbose           = $true
    }
    Set-WindowsAzureWallpaper.ps1 @Parameters
.EXAMPLE
    [hashtable]$Parameters = @{
        Path               = Join-Path -Path $env:ProgramData -ChildPath 'SomeCompany\Wallpapers'
        DefaultResolution  = '1920x1200'
        SlideShowOptions   = 'EnableShuffle'
        SlideShowInterval  =  1800
        Url                = 'https://testcmspublic.file.core.windows.net/public/SomeCompany/Branding/Wallpapers'
        SasToken           = '?sv=2020-02-10&ss=f&srt=co&sp=rl&se=2022-02-23T16:50:56Z&st=2021-02-23T08:50:56Z&spr=https&sig=U1ksjwFS7x970xYezvG%2B%2FfIQYoX6k12VY95xOVfDm6Y%3D'
        Force              = $false
        Verbose            = $true
    }
    Set-WindowsAzureWallpaper @Parameters
.INPUTS
    None.
.OUTPUTS
    System.String
.NOTES
    Created by Ioan Popovici
    If you have MEMCM you can run the SQL query linked below (Set-WindowsAzureWallpaper-SQL) in order to get the most common resolutions used in your environment.
    You can use this script in a baseline as a MEMCM 'Detection' script.
.LINK
    https://MEM.Zone/Set-WindowsAzureWallpaper
.LINK
    https://MEM.Zone/Set-WindowsAzureWallpaper-CHANGELOG
.LINK
    https://MEM.Zone/Set-WindowsAzureWallpaper-GIT
.LINK
    https://MEM.Zone/Set-WindowsAzureWallpaper-SQL
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    Desktop
.FUNCTIONALITY
    Change Wallpaper
#>
    [CmdletBinding(DefaultParameterSetName = 'Wallpaper')]
    Param (
        [Parameter(Mandatory = $true, ParameterSetName = 'Wallpaper', HelpMessage = 'Destination Path:', Position = 0)]
        [Parameter(Mandatory = $true, ParameterSetName = 'Slideshow', HelpMessage = 'Destination and Slideshow Path:', Position = 0)]
        [ValidateNotNullorEmpty()]
        [Alias('Destination')]
        [string]$Path,
        [Parameter(Mandatory = $true, ParameterSetName = 'Wallpaper', HelpMessage = 'Default Wallpaper Resolution:', Position = 1)]
        [Parameter(Mandatory = $true, ParameterSetName = 'Slideshow', HelpMessage = 'Default Wallpaper Resolution:', Position = 1)]
        [Alias('Default')]
        [string]$DefaultResolution,
        [Parameter(Mandatory = $false, ParameterSetName = 'Wallpaper', HelpMessage = 'Wallpaper Position (Center, Tile, Stretch, Fit, Fill, Span):', Position = 2)]
        [ValidateSet('Center', 'Tile', 'Stretch', 'Fit', 'Fill', 'Span')]
        [Alias('Style')]
        [string]$Position = 'Stretch',
        [Parameter(Mandatory = $true, ParameterSetName = 'Slideshow', HelpMessage = 'Enable Slideshow Shuffle? (EnableShuffle / DisableShuffle)', Position = 2)]
        [ValidateSet('EnableShuffle', 'DisableShuffle')]
        [Alias('Shuffle')]
        [string]$SlideShowOptions,
        [Parameter(Mandatory = $true, ParameterSetName = 'Slideshow', HelpMessage = 'Slideshow Advance Interval (Seconds):', Position = 3)]
        [ValidateNotNullorEmpty()]
        [Alias('Interval')]
        [string]$SlideShowInterval,
        [Parameter(Mandatory = $true, ParameterSetName = 'Wallpaper', HelpMessage = 'Share URL:', Position = 3)]
        [Parameter(Mandatory = $true, ParameterSetName = 'Slideshow', HelpMessage = 'Share URL:', Position = 4)]
        [ValidateNotNullorEmpty()]
        [Alias('Location')]
        [string]$Url,
        [Parameter(Mandatory = $false, ParameterSetName = 'Wallpaper', HelpMessage = 'Share SAS Token:', Position = 4)]
        [Parameter(Mandatory = $false, ParameterSetName = 'Slideshow', HelpMessage = 'Share SAS Token:', Position = 5)]
        [Alias('Sas')]
        [string]$SasToken,
        [Parameter(ParameterSetName = 'Wallpaper')]
        [Parameter(ParameterSetName = 'Slideshow')]
        [Alias('Overwrite')]
        [switch]$Force
    )
    Begin {

        ## Import IDesktop API
        Format-Spacer -Message 'Initialization' -Type 'Verbose' -AddEmptyRow 'After'
        Import-Win32IDesktopAPI

        ## Set namespace variables
        $MonitorCommand   = New-Object -TypeName 'MEMZone.MonitorCommand'
        $WallpaperCommand = New-Object -TypeName 'MEMZone.WallpaperCommand'
    }
    Process {
        Try {

            ## Get Azure wallpapers depending on the storage account type
            If ($Url -match '.blob.') { [psobject]$AzureWallpaperFiles = Get-AzureBlobStorageItem -Url $Url -SasToken $SasToken -ErrorAction 'Stop' }
            Else { [psobject]$AzureWallpaperFiles = Get-AzureFileStorageItem -Url $Url -SasToken $SasToken -ErrorAction 'Stop' }

            ## If Wallpaper Parameter Set is used, set wallpaper otherwise set slideshow
            If ($PsCmdlet.ParameterSetName -eq 'Wallpaper') {

                ## Get monitors
                $Monitors = $MonitorCommand::GetMonitor()
                Format-Spacer -Message 'Monitor List' -Type 'Verbose' -AddEmptyRow 'Before'
                Write-Verbose -Message $($Monitors | Out-String)

                ## Show Azure wallpaper list
                Format-Spacer -Message 'Azure Wallpaper List' -Type 'Verbose'
                Write-Verbose -Message $($AzureWallpaperFiles | Out-String)

                ## Set default wallpaper based on specified resolution, if multiple matches are found the first one is selected
                [psobject]$DefaultWallpaper = $AzureWallpaperFiles | Where-Object -Property 'Name' -match $DefaultResolution | Select-Object -First 1
                Format-Spacer -Message 'Default Wallpaper' -Type 'Verbose'
                Write-Verbose -Message $($DefaultWallpaper | Out-String)

                ## Set assumed local wallpaper path in order to check if it's already downloaded and set
                [string]$LocalWallpaperPath = Join-Path -Path $Path -ChildPath $DefaultWallpaper.Name

                ## Cycle trough all monitors
                Format-Spacer -Message 'Processing Monitors' -Type 'Verbose'
                ForEach ($Monitor in $Monitors) {

                    ## Write verbose monitor name
                    Format-Spacer -Message $($Monitor.Name) -Type 'Verbose' -AddEmptyRow 'After'

                    ## Get monitor assigned wallpaper path
                    $MonitorWallpaperPath = $WallpaperCommand::GetWallpaper($Monitor.Index) | Select-Object -ExpandProperty 'Path'
                    Write-Verbose -Message "Current Wallpaper Path is $MonitorWallpaperPath"

                    ## Match azure wallpaper name with monitor resolution and select only the first match
                    $AzureWallpaperMatch = $AzureWallpaperFiles | Where-Object -Property 'Name' -match $Monitor.Resolution | Select-Object -First 1
                    Format-Spacer -Message 'Matching Azure Wallpaper' -Type 'Verbose' -AddEmptyRow 'BeforeAndAfter'

                    ## If there's no match, use the default wallpaper list
                    If (-not $AzureWallpaperMatch) {
                        Write-Warning -Message "No Wallpapers matching monitor resolution were found. Setting default wallpaper..."
                        $LocalWallpaperPath = Join-Path -Path $Path -ChildPath $DefaultWallpaper.Name
                    }
                    Else { Write-Verbose -Message $($AzureWallpaperMatch | Out-String) }

                    ## If wallpaper does not match, download and set default wallpaper if its not already assigned or the 'Force' is specified
                    If (($MonitorWallpaperPath -ne $LocalWallpaperPath) -or $Force) {

                        ## Download wallpaper
                        Format-Spacer -Message 'Downloading Wallpaper' -Type 'Verbose' -AddEmptyRow 'BeforeAndAfter'
                        $DownloadWallpaper = Start-AzureStorageFileTransfer -Url $($DefaultWallpaper.Url) -SasToken $SasToken -Path $Path -Force:$Force -ErrorAction 'Stop'
                        Write-Verbose -Message $($DownloadWallpaper | Out-String)

                        ## Set wallpaper
                        Format-Spacer -Message 'Setting Wallpaper' -Type 'Verbose' -AddEmptyRow 'After'
                        Write-Verbose -Message "Setting Wallpaper [$($DefaultWallpaper.Url)] with Position [$Position], on Monitor [$($Monitor.Name)]..."
                        $SetWallpaper = $WallpaperCommand::SetWallpaper($Monitor.Index, $LocalWallpaperPath, $Position) -Replace('S_OK', 'Successful')

                        ## Set default output hashtable
                        $Output = [ordered]@{ 'SetWallpaper' = $SetWallpaper }

                        ## Throw error if setting wallpaper fails
                        If ($SetWallpaper -ne 'Successful') { Throw $($Output | Out-String) }
                    }
                    Else { $Output = "`nWallpaper [$LocalWallpaperPath] with Position [$Position] on Monitor [$($Monitor.Name)] is already set!" }
                }
            }

            ## If Slideshow Parameter Set is used, set slideshow
            ElseIf ($PsCmdlet.ParameterSetName -eq 'SlideShow') {

                ## Get primary monitor
                $PrimaryMonitor = $MonitorCommand::GetMonitor() | Where-Object -Property  'Index' -eq 0
                Format-Spacer -Message 'Primary Monitor' -Type 'Verbose' -AddEmptyRow 'Before'
                Write-Verbose -Message $($PrimaryMonitor | Out-String)

                ## Show Azure wallpaper list
                Format-Spacer -Message 'Azure Wallpaper List' -Type 'Verbose'
                Write-Verbose -Message $($AzureWallpaperFiles | Out-String)

                ## Get the default wallpaper list based on specified resolution
                [psobject]$DefaultWallpaperList = $AzureWallpaperFiles | Where-Object -Property 'Name' -match $DefaultResolution
                Format-Spacer -Message 'Default Azure Wallpaper List' -Type 'Verbose'
                Write-Verbose -Message $($DefaultWallpaperList | Out-String)

                ## Match azure wallpaper names with monitor resolution
                $AzureWallpaperMatch = $AzureWallpaperFiles | Where-Object -Property 'Name' -match $PrimaryMonitor.Resolution
                Format-Spacer -Message 'Matching Azure Wallpaper List' -Type 'Verbose' -AddEmptyRow 'After'

                ## If there's no match, use the default wallpaper list
                If ([string]::IsNullOrWhiteSpace($AzureWallpaperMatch)) {
                    Write-Warning -Message "No Wallpapers matching monitor resolution were found. Setting default wallpaper list..."
                    $AzureWallpaperMatch = $DefaultWallpaperList
                }
                Else { Write-Verbose -Message $($AzureWallpaperMatch | Out-String) }

                ## Download the specified wallpaper set
                Format-Spacer -Message 'Downloading Wallpaper' -Type 'Verbose' -AddEmptyRow 'BeforeAndAfter'
                ForEach ($AzureWallpaper in $AzureWallpaperMatch) {
                    $DownloadWallpaper = Start-AzureStorageFileTransfer -Url $AzureWallpaper.Url -SasToken $SasToken -Path $Path -Force:$Force -ErrorAction 'Stop'
                    Write-Verbose -Message $($DownloadWallpaper | Out-String)
                }

                ## Set the wallpaper slideshow
                Format-Spacer -Message 'Setting Wallpaper SlideShow' -Type 'Verbose' -AddEmptyRow 'After'
                Write-Verbose "Setting slideshow, on $($PrimaryMonitor.Name) to $Path with SlideShowOptions [$SlideShowOptions] and AdvanceInterval [$SlideShowInterval] (Seconds)..."
                $SetWallpaperSlideShowOptions = $WallpaperCommand::SetSlideshowOptions($SlideShowOptions, $SlideShowInterval) -Replace('S_OK', 'Successful')
                $SetWallpaperSlideShow = $WallpaperCommand::SetSlideshowPath($Path) -Replace('S_OK', 'Successful')

                ## Set default output hashtable
                $Output = [ordered]@{
                    'SetWallpaperSlideShowOptions' = $SetWallpaperSlideShowOptions
                    'SetWallpaperSlideShow'        = $SetWallpaperSlideShow
                }

                ## Throw error if the operation failed
                If ($SetWallpaperSlideShowOptions -ne 'Successful' -or $SetWallpaperSlideShow -ne 'Successful') { Throw $($Output | Out-String) }
            }
        }
        Catch {
            $PsCmdlet.WriteError($PSItem)
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
        DefaultResolution  = $DefaultResolution
        Position           = $Position
        Url                = $Url
        SasToken           = $SasToken
        SlideShowShuffle   = $SlideShowShuffle
        SlideShowInterval  = $SlideShowInterval
        Force              = $Force
        Verbose            = $VerbosePreference
    }

    ## Call Set-WindowsAzureWallpaper with declared parameters
    Set-WindowsAzureWallpaper @Parameters
}
Catch {
    Throw $PSItem
}

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================