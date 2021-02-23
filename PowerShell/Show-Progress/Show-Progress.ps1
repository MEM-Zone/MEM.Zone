#region Function Show-Progress
Function Show-Progress {
<#
.SYNOPSIS
    Displays progress info.
.DESCRIPTION
    Displays progress info and maximizes code reuse by automatically calculating the progress steps.
.PARAMETER Actity
    Specifies the progress activity. Default: 'Running Install Please Wait...'.
.PARAMETER Status
    Specifies the progress status.
.PARAMETER CurrentOperation
    Specifies the current operation.
.PARAMETER Step
    Specifies the progress step. Default: $Global:Step ++.
.PARAMETER ID
    Specifies the progress bar id.
.PARAMETER Delay
    Specifies the progress delay in milliseconds. Default: 400.
.PARAMETER Loop
    Specifies if the call comes from a loop.
.EXAMPLE
    Show-Progress -Activity 'Running Install Please Wait' -Status 'Uploading Report' -Step ($Step++) -Delay 200
.EXAMPLE
    Show-Progress -Status "Downloading [$File.Name] --> [$($RSDataSource.Name)]" -Loop
.INPUTS
    None.
.OUTPUTS
    None.
.NOTES
    This is an private function should tipically not be called directly.
    Credit to Adam Bertram.

    ## !! IMPORTANT !! ##
    #  You need to tokenize the scripts steps at the begining of the script in order for Show-Progress to work:

    ## Get script path and name
    [string]$ScriptPath = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Definition)
    [string]$ScriptName = [System.IO.Path]::GetFileName($MyInvocation.MyCommand.Definition)
    [string]$ScriptFullName = Join-Path -Path $ScriptPath -ChildPath $ScriptName
    #  Get progress steps
    $ProgressSteps = $(([System.Management.Automation.PsParser]::Tokenize($(Get-Content -Path $ScriptFullName), [ref]$null) | Where-Object { $_.Type -eq 'Command' -and $_.Content -eq 'Show-Progress' }).Count)
    $ForEachSteps = $(([System.Management.Automation.PsParser]::Tokenize($(Get-Content -Path $ScriptFullName), [ref]$null) | Where-Object { $_.Type -eq 'Keyword' -and $_.Content -eq 'ForEach' }).Count)
    #  Set progress steps
    $Script:Steps = $ProgressSteps - $ForEachSteps
    $Script:Step = 0
.LINK
    https://adamtheautomator.com/building-progress-bar-powershell-scripts/
.LINK
    https://MEM.Zone/
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    Powershell
.FUNCTIONALITY
    Show Progress
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$false,Position=0)]
        [ValidateNotNullorEmpty()]
        [Alias('act')]
        [string]$Activity = 'Running Install Please Wait...',
        [Parameter(Mandatory=$true,Position=1)]
        [ValidateNotNullorEmpty()]
        [Alias('sta')]
        [string]$Status,
        [Parameter(Mandatory=$false,Position=2)]
        [ValidateNotNullorEmpty()]
        [Alias('cro')]
        [string]$CurrentOperation,
        [Parameter(Mandatory=$false,Position=3)]
        [ValidateNotNullorEmpty()]
        [Alias('pid')]
        [int]$ID = 0,
        [Parameter(Mandatory=$false,Position=4)]
        [ValidateNotNullorEmpty()]
        [Alias('ste')]
        [int]$Step = $Script:Step ++,
        [Parameter(Mandatory=$false,Position=5)]
        [ValidateNotNullorEmpty()]
        [Alias('del')]
        [string]$Delay = 400,
        [Parameter(Mandatory=$false,Position=5)]
        [ValidateNotNullorEmpty()]
        [Alias('lp')]
        [switch]$Loop
    )
    Begin {
        If ($Loop) { $Script:Steps ++ }
        $PercentComplete = $($($Step / $Steps) * 100)
    }
    Process {
        Try {
            ##  Show progress
            Write-Progress -Activity $Activity -Status $Status -CurrentOperation $CurrentOperation -ID $ID -PercentComplete $PercentComplete
            Start-Sleep -Milliseconds $Delay
        }
        Catch {
            Throw (New-Object System.Exception("Could not Show progress status [$Status]! $($_.Exception.Message)", $_.Exception))
        }
    }
}
#endregion