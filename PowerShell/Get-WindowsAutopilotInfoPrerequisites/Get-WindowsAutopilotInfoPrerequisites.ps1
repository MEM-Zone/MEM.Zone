<#
.SYNOPSIS
    Gets the Get-WindowsAutopilotInfo.ps1 script prerequisites.
.DESCRIPTION
    Gets the Get-WindowsAutopilotInfo.ps1 script prerequisites, saves them to the specified path and modifies them so they can be executed locally.
.PARAMETER Path
    Specifies path to save the prerequisites to. Default is the current directory.
.EXAMPLE
    Get-WindowsAutopilotInfoPrerequisites.ps1 -Path 'C:\Temp'
.INPUTS
    None.
.OUTPUTS
    System.String
.NOTES
    Created by Ioan Popovici
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/Issues
.COMPONENT
    Autopilot
.FUNCTIONALITY
    Gets the Get-WindowsAutopilotInfo.ps1 script prerequisites.
#>

## Set script requirements
#Requires -Version 3.0

[CmdletBinding()]
Param (
    [Parameter(Mandatory=$false,HelpMessage='Destination path:')]
    [ValidateNotNullorEmpty()]
    [Alias('Location')]
    [string]$Path
)

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

## Get script path and name
[string]$ScriptPath     = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Definition)
[string]$ScriptName     = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Definition)

## Set path if not specified
If ([string]::IsNullOrEmpty($Path)) { $Path = $ScriptPath }

## Display script path and name
Write-Verbose -Message "Downloading prerequisites to $Path" -Verbose

#endregion
##*=============================================
##* END VARIABLE DECLARATION
##*=============================================


##*=============================================
##* SCRIPT BODY
##*=============================================
#region ScriptBody

Try {

    ## Install NUGet Package Provider if it's not already installed
    $IsNuGetInstalled = [boolean](Get-PackageProvider 'NuGet' -ErrorAction 'SilentlyContinue')
    If (-not $IsNuGetInstalled) {
        Write-Verbose -Message "Installing NuGet Package Provider..."
        Find-PackageProvider -Name 'NuGet' -ForceBootstrap -IncludeDependencies
    }

    ## Set prerequisites scriptblock
    [scriptblock]$Prerequisites = {
        Save-Script -Name 'Get-WindowsAutopilotInfo' -Path $Path -Force
        Save-Module -Name 'WindowsAutopilotIntune'   -Path $Path -Force
        Save-Module -Name 'Microsoft.Graph.Intune'   -Path $Path -Force
        Save-Module -Name 'AzureAD'                  -Path $Path -Force
    }

    ## Execute prerequisites scriptblock
    & $Prerequisites
    Write-Verbose -Message "Prerequisites ['Get-WindowsAutopilotInfo', 'WindowsAutopilotIntune', Microsoft.Graph.Intune', 'AzureAD'] were downloaded successfully in $ScriptPath" -Verbose

    ## Modify WindowsAutoPilotIntune.psm1
    [string]$AutoPilotModulePath = (Get-ChildItem -Path $Path -Recurse -File | Where-Object { $PsItem.Name -eq 'WindowsAutoPilotIntune.psm1' }).FullName
    $AutoPilotModuleContent = [System.IO.File]::ReadAllText($AutoPilotModulePath).Replace('Import-Module Microsoft.Graph.Intune', '# Commented By Set-WindowsAutopilotConfiguration Import-Module Microsoft.Graph.Intune')
    [System.IO.File]::WriteAllText($AutoPilotModulePath, $AutoPilotModuleContent)

    ## Modify WindowsAutoPilotIntune.psd1
    [string]$AutoPilotModuleManifestPath = (Get-ChildItem -Path $Path -Recurse -File | Where-Object { $PsItem.Name -eq 'WindowsAutoPilotIntune.psd1' }).FullName
    $AutoPilotModuleManifestContent = [System.IO.File]::ReadAllText($AutoPilotModuleManifestPath).Replace('RequiredModules', '# Commented By Set-WindowsAutopilotConfiguration RequiredModules')
    [System.IO.File]::WriteAllText($AutoPilotModuleManifestPath, $AutoPilotModuleManifestContent)

    ## Modify Get-WindowsAutopilotInfo.ps1
    [string]$WindowsAutopilotInfoPath  = (Get-ChildItem -Path $Path -Recurse -File | Where-Object { $PsItem.Name -eq 'Get-WindowsAutopilotInfo.ps1' }).FullName
    [string]$ModulePath = '$Path = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Definition)'
    [string]$ImportModules = 'Get-ChildItem -Path $Path -Recurse -File | Where-Object { $PsItem.Extension -eq ".psd1" } | ForEach-Object { Import-Module -Name $PsItem.FullName -Global -PassThru }'
    [string]$CommentBegin = '<# Commented By Set-WindowsAutopilotConfiguration' + "`n" + '        # Get NuGet'
    [string]$CommentEnd = '#>' + "`n`n" + '        # Added by Set-WindowsAutopilotConfiguration' + "`n        " + $ModulePath + "`n        " + $ImportModules + "`n`n" + '        # Connect'
    $WindowsAutopilotInfoContent = [System.IO.File]::ReadAllText($WindowsAutopilotInfoPath).Replace('# Get NuGet', $CommentBegin).Replace('# Connect', $CommentEnd)
    [System.IO.File]::WriteAllText($WindowsAutopilotInfoPath, $WindowsAutopilotInfoContent)
    Write-Verbose -Message ("Successfully modified files:`n{0}`n{1}`n{2}" -f $AutoPilotModulePath, $AutoPilotModuleManifestPath, $WindowsAutopilotInfoPath) -Verbose

    ## Set output to success
    $Output = "$ScriptName completed successfully!"
}
Catch {
    $Output = $($PsItem.Exception.Message)
    Throw $Output
}
Finally {
    Write-Output -InputObject $Output
}

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================