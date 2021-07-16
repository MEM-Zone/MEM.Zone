#region Function Set-ResumeAfterReboot
Function Set-ResumeAfterReboot {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true,ParameterSetName='Register',Position=0)]
        [Alias('Exec')]
        [string]$Execute,
        [Parameter(Mandatory=$false,ParameterSetName='Register',Position=1)]
        [Alias('Params')]
        [string]$Argument,
        [Parameter(Mandatory=$false,ParameterSetName='UnRegister',Position=0)]
        [Alias('Remove')]
        [switch]$Unregister
    )
    Begin {

        ## Get the name of this function and write header
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
    }
    Process {
        Try {

            If ($($PSCmdlet.ParameterSetName) -eq 'UnRegister' -or $($PSCmdlet.ParameterSetName) -eq 'UnRegister') {
                ##  Remove existing task if present
                $ScheduledTask = $(Get-ScheduledTask -TaskName 'ResumeAtLogon' -ErrorAction 'SilentlyContinue').TaskName
                If ($ScheduledTask) {
                    Unregister-ScheduledTask -TaskName 'ResumeAtLogon' -Confirm:$false -ErrorAction 'Stop'
                    Write-Log -Message "Scheduled task [ResumeAtLogon] removed!" -Severity 1 -Source ${CmdletName}
                }
                Else {
                    Write-Log -Message 'Scheduled task [ResumeAtLogon] not present!' -Severity 1 -Source ${CmdletName}
                }
            }
            Else {
                ##  Register new scheduled task
                If ($($PSCmdlet.ParameterSetName) -eq 'Register') {

                    ## Set Scheduled Task Variables
                    If ($Argument) { $Action = New-ScheduledTaskAction -Execute $Execute -Argument $Argument }
                    Else { $Action = New-ScheduledTaskAction -Execute $Execute }
                    $Trigger = New-ScheduledTaskTrigger -AtLogOn

                    Register-ScheduledTask -TaskName 'ResumeAtLogon' -Description 'Resume operations at logon' -Action $Action -Trigger $Trigger -RunLevel 'Highest' -Force -ErrorAction 'Stop'
                    Write-Log -Message 'Scheduled task [ResumeAtLogon] set!' -Severity 1 -Source ${CmdletName}
                }
            }
        }
        Catch {
            Write-Log -Message "Failed to set scheduled task [ResumeAtLogon]! `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
        }
    }
    End {
        Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
    }
}
#endregion