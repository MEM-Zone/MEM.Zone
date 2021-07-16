#region Function Get-InstalledApplication
Function Get-InstalledApplication {
    <#
.SYNOPSIS
    Retrieves information about installed applications.
.DESCRIPTION
    Retrieves information about installed applications by querying the registry. You can specify an application name, a product code, or both.
    Returns information about application publisher, name & version, product code, uninstall string, install source, location, date, and application architecture.
.PARAMETER Name
    The name of the application to retrieve information for. Performs a regex match on the application display name by default.
.PARAMETER Exact
    Specifies that the named application must be matched using the exact name.
.PARAMETER WildCard
    Specifies that the named application must be matched using a wildcard search.
.PARAMETER ProductCode
    The product code of the application to retrieve information for.
.PARAMETER IncludeUpdatesAndHotfixes
    Include matches against updates and hotfixes in results.
.EXAMPLE
    Get-InstalledApplication -Name 'Adobe Flash'
.EXAMPLE
    Get-InstalledApplication -ProductCode '{1AD147D0-BE0E-3D6C-AC11-64F6DC4163F1}'
.NOTES
.LINK
    http://psappdeploytoolkit.codeplex.com
#>
    Param (
        [Parameter(Mandatory = $false)]
        [ValidateNotNullorEmpty()]
        [string[]]$Name,
        [Parameter(Mandatory = $false)]
        [switch]$Exact = $false,
        [Parameter(Mandatory = $false)]
        [switch]$WildCard = $false,
        [Parameter(Mandatory = $false)]
        [ValidateNotNullorEmpty()]
        [string]$ProductCode,
        [Parameter(Mandatory = $false)]
        [switch]$IncludeUpdatesAndHotfixes
    )

    [string[]]$regKeyApplications = 'HKLM:SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall', 'HKLM:SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall'

    [boolean]$Is64Bit = [boolean]((Get-WmiObject -Class Win32_Processor | Where-Object { $_.DeviceID -eq 'CPU0' } | Select-Object -ExpandProperty AddressWidth) -eq '64')

    If ($name) {
        #	Write-Host  "Get information for installed Application Name(s) [$($name -join ', ')]..."
    }
    If ($productCode) {
        #	Write-Host  "Get information for installed Product Code [$ProductCode]..."
    }

    [psobject[]]$installedApplication = @()
    ForEach ($regKey in $regKeyApplications) {
        Try {
            If (Test-Path -Path $regKey -ErrorAction 'Stop') {
                [psobject[]]$regKeyApplication = Get-ChildItem -Path $regKey -ErrorAction 'Stop' | ForEach-Object { Get-ItemProperty -LiteralPath $_.PSPath -ErrorAction 'SilentlyContinue' | Where-Object { $_.DisplayName } }
                ForEach ($regKeyApp in $regKeyApplication) {
                    Try {
                        [string]$appDisplayName = ''
                        [string]$appDisplayVersion = ''
                        [string]$appPublisher = ''

                        ## Bypass any updates or hotfixes
                        If (-not $IncludeUpdatesAndHotfixes) {
                            If ($regKeyApp.DisplayName -match '(?i)kb\d+') { Continue }
                            If ($regKeyApp.DisplayName -match 'Cumulative Update') { Continue }
                            If ($regKeyApp.DisplayName -match 'Security Update') { Continue }
                            If ($regKeyApp.DisplayName -match 'Hotfix') { Continue }
                        }

                        ## Remove any control characters which may interfere with logging and creating file path names from these variables
                        $appDisplayName = $regKeyApp.DisplayName -replace '[^\u001F-\u007F]', ''
                        $appDisplayVersion = $regKeyApp.DisplayVersion -replace '[^\u001F-\u007F]', ''
                        $appPublisher = $regKeyApp.Publisher -replace '[^\u001F-\u007F]', ''

                        ## Determine if application is a 64-bit application
                        [boolean]$Is64BitApp = If (($is64Bit) -and ($regKey -notmatch '^HKLM:SOFTWARE\\Wow6432Node')) { $true } Else { $false }

                        If ($ProductCode) {
                            ## Verify if there is a match with the product code passed to the script
                            If ($regKeyApp.PSChildName -match [regex]::Escape($productCode)) {
                                #	Write-Host  "Found installed application [$appDisplayName] version [$appDisplayVersion] matching product code [$productCode]"
                                $installedApplication += New-Object -TypeName PSObject -Property @{
                                    ProductCode        = $regKeyApp.PSChildName
                                    DisplayName        = $appDisplayName
                                    DisplayVersion     = $appDisplayVersion
                                    UninstallString    = $regKeyApp.UninstallString
                                    InstallSource      = $regKeyApp.InstallSource
                                    InstallLocation    = $regKeyApp.InstallLocation
                                    InstallDate        = $regKeyApp.InstallDate
                                    Publisher          = $appPublisher
                                    Is64BitApplication = $Is64BitApp
                                }
                            }
                        }

                        If ($name) {
                            ## Verify if there is a match with the application name(s) passed to the script
                            ForEach ($application in $Name) {
                                $applicationMatched = $false
                                If ($exact) {
                                    #  Check for an exact application name match
                                    If ($regKeyApp.DisplayName -eq $application) {
                                        $applicationMatched = $true
                                        #	Write-Host  "Found installed application [$appDisplayName] version [$appDisplayVersion] using exact name matching forapplication name [$application]"
                                    }
                                }
                                ElseIf ($WildCard) {
                                    #  Check for wildcard application name match
                                    If ($regKeyApp.DisplayName -like $application) {
                                        $applicationMatched = $true
                                        #	Write-Host  "Found installed application [$appDisplayName] version [$appDisplayVersion] using wildcard matching for application name [$application]"
                                    }
                                }
                                #  Check for a regex application name match
                                ElseIf ($regKeyApp.DisplayName -match [regex]::Escape($application)) {
                                    $applicationMatched = $true
                                    #	Write-Host  "Found installed application [$appDisplayName] version [$appDisplayVersion] using regex matching for application name [$application]"
                                }

                                If ($applicationMatched) {
                                    $installedApplication += New-Object -TypeName PSObject -Property @{
                                        ProductCode        = $regKeyApp.PSChildName
                                        DisplayName        = $appDisplayName
                                        DisplayVersion     = $appDisplayVersion
                                        UninstallString    = $regKeyApp.UninstallString
                                        InstallSource      = $regKeyApp.InstallSource
                                        InstallLocation    = $regKeyApp.InstallLocation
                                        InstallDate        = $regKeyApp.InstallDate
                                        Publisher          = $appPublisher
                                        Is64BitApplication = $Is64BitApp
                                    }
                                }
                            }
                        }
                    }
                    Catch {
                        #	Write-Host  "Failed to resolve application details from registry for [$appDisplayName]. `n$(Resolve-Error)"
                        Continue
                    }
                }
            }
        }
        Catch {
            #	Write-Host  "Failed to resolve registry path [$regKey]. `n$(Resolve-Error)"
            Continue
        }
    }
    Write-Output $installedApplication
}
#endregion