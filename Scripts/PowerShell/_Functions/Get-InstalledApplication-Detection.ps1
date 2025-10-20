<#
.SYNOPSIS
    Application detection discovery script.
.DESCRIPTION
    Gets the first matching installed application.
.PARAMETER Name
    Specifies the applicaiton name to query.
.EXAMPLE
    Get-InstalledApplication.ps1 -Name 'Java'
.INPUTS
    System.String.
.OUTPUTS
    System.String.
.NOTES
    Created by Ioan Popovici
    2021-03-31 v1.0.0
    Credit to PSAppDeployment Toolkit
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    CM
.FUNCTIONALITY
    Detect Application
#>

## Set script requirements
#Requires -Version 3.0

#*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

## Get script parameters
Param (
    [Parameter(Mandatory=$false,Position=0)]
    [ValidateNotNullorEmpty()]
    [Alias('ApplicationName')]
    [string]$Name,
    [Parameter(Mandatory=$false,Position=1)]
    [ValidateNotNullorEmpty()]
    [Alias('ApplicationVersion')]
    [version]$Version,
    [Parameter(Mandatory = $false)]
    [switch]$Exact
)

#endregion
##*=============================================
##* END VARIABLE DECLARATION
##*=============================================

##*=============================================
##* FUNCTION LISTINGS
##*=============================================
#region FunctionListings

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

    [bool]$Is64Bit = [bool]((Get-WmiObject -Class Win32_Processor | Where-Object { $PSItem.DeviceID -eq 'CPU0' } | Select-Object -ExpandProperty AddressWidth) -eq '64')

    if ($name) {
        #	Write-Host  "Get information for installed Application Name(s) [$($name -join ', ')]..."
    }
    if ($productCode) {
        #	Write-Host  "Get information for installed Product Code [$ProductCode]..."
    }

    [psobject[]]$installedApplication = @()
    foreach ($regKey in $regKeyApplications) {
        try {
            if (Test-Path -Path $regKey -ErrorAction 'Stop') {
                [psobject[]]$regKeyApplication = Get-ChildItem -Path $regKey -ErrorAction 'Stop' | foreach-Object { Get-ItemProperty -LiteralPath $PSItem.PSPath -ErrorAction 'Silentlycontinue' | Where-Object { $PSItem.DisplayName } }
                foreach ($regKeyApp in $regKeyApplication) {
                    try {
                        [string]$appDisplayName = ''
                        [string]$appDisplayVersion = ''
                        [string]$appPublisher = ''

                        ## Bypass any updates or hotfixes
                        if (-not $IncludeUpdatesAndHotfixes) {
                            if ($regKeyApp.DisplayName -match '(?i)kb\d+') { continue }
                            if ($regKeyApp.DisplayName -match 'Cumulative Update') { continue }
                            if ($regKeyApp.DisplayName -match 'Security Update') { continue }
                            if ($regKeyApp.DisplayName -match 'Hotfix') { continue }
                        }

                        ## Remove any control characters which may interfere with logging and creating file path names from these variables
                        $appDisplayName = $regKeyApp.DisplayName -replace '[^\u001F-\u007F]', ''
                        $appDisplayVersion = $regKeyApp.DisplayVersion -replace '[^\u001F-\u007F]', ''
                        $appPublisher = $regKeyApp.Publisher -replace '[^\u001F-\u007F]', ''

                        ## Determine if application is a 64-bit application
                        [boolean]$Is64BitApp = if (($is64Bit) -and ($regKey -notmatch '^HKLM:SOFTWARE\\Wow6432Node')) { $true } Else { $false }

                        if ($ProductCode) {

                            ## Verify if there is a match with the product code passed to the script
                            if ($regKeyApp.PSChildName -match [regex]::Escape($productCode)) {
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

                        if ($name) {

                            ## Verify if there is a match with the application name(s) passed to the script
                            foreach ($application in $Name) {
                                $applicationMatched = $false
                                if ($exact) {
                                    #  Check for an exact application name match
                                    if ($regKeyApp.DisplayName -eq $application) {
                                        $applicationMatched = $true
                                        #	Write-Host  "Found installed application [$appDisplayName] version [$appDisplayVersion] using exact name matching forapplication name [$application]"
                                    }
                                }
                                elseif ($WildCard) {
                                    #  Check for wildcard application name match
                                    if ($regKeyApp.DisplayName -like $application) {
                                        $applicationMatched = $true
                                        #	Write-Host  "Found installed application [$appDisplayName] version [$appDisplayVersion] using wildcard matching for application name [$application]"
                                    }
                                }
                                #  Check for a regex application name match
                                elseif ($regKeyApp.DisplayName -match [regex]::Escape($application)) {
                                    $applicationMatched = $true
                                    #	Write-Host  "Found installed application [$appDisplayName] version [$appDisplayVersion] using regex matching for application name [$application]"
                                }

                                if ($applicationMatched) {
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
                    catch {
                        #	Write-Host  "Failed to resolve application details from registry for [$appDisplayName]. `n$(Resolve-Error)"
                        continue
                    }
                }
            }
        }
        catch {
            #	Write-Host  "Failed to resolve registry path [$regKey]. `n$(Resolve-Error)"
            continue
        }
    }
    Write-Output $installedApplication
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

try {
    $Result = $null
    [bool]$VersionMatch = $false

    ## Get all installed applications that match the specified name
    $IsAppDetected = Get-InstalledApplication -Name $Name -Exact:$Exact

    ## Check if the application version is installed for each detected application
    foreach ($Application in $IsAppDetected) { if ([version]$Application.DisplayVersion -ge $Version) { $VersionMatch = $true } }

    ## if the application version is installed, or only the application name is specified, return 'Detected'
    if ($IsAppDetected -and $Version) {
        if ($VersionMatch) { $Result = 'Detected' }
    }
    elseif ($IsAppDetected) { $Result = 'Detected' }
}
catch {
    throw $PSItem.Exception.Message
}
finally {
    Write-Output -InputObject $Result
}

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================