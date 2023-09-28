<#
.SYNOPSIS
    Starts a MEMCM task sequence.
.DESCRIPTION
    Starts a MEMCM task sequence by triggering te schedule for that task sequence.
.PARAMETER TaskSequenceName
    Specifies the task sequence name.
.EXAMPLE
    Start-CMTaskSequence.ps1 -Name 'TS-App-Install'
.INPUTS
    None.
.OUTPUTS
    None.
.NOTES
    Credit to Nickolaj Andersen
    Switched to CIM cmdlets and reformatting by Ioan Popovici
.LINK
    https://www.scconfigmgr.com/2019/02/14/how-to-rerun-a-task-sequence-in-configmgr-using-powershell/
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    CM
.FUNCTIONALITY
    Start Task Sequence
#>

## Set script requirements
#Requires -Version 3.0

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

## Get script parameters
Param (
    [Parameter(Mandatory=$true,HelpMessage='Specify the name of the task sequence',Position=0)]
    [ValidateNotNullorEmpty()]
    [Alias('Name')]
    [string]$TaskSequenceName
)

#endregion
##*=============================================
##* END VARIABLE DECLARATION
##*=============================================

##*=============================================
##* FUNCTION LISTINGS
##*=============================================
#region FunctionListings

#region Function Start-CMTaskSequence
Function Start-CMTaskSequence {
<#
.SYNOPSIS
    Starts a MEMCM task sequence.
.DESCRIPTION
    Starts a MEMCM task sequence by triggering te schedule for that task sequence.
.PARAMETER TaskSequenceName
    Specifies the task sequence name.
.EXAMPLE
    Start-CMTaskSequence -Name 'TS-App-Install'
.INPUTS
    None.
.OUTPUTS
    None.
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/CM-SRS-Dashboards-GIT
.LINK
    https://MEM.Zone/CM-SRS-Dashboards-ISSUES
.COMPONENT
    CM
.FUNCTIONALITY
    Start Task Sequence
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true,HelpMessage='Specify the name of the task sequence',Position=0)]
        [ValidateNotNullorEmpty()]
        [Alias('Name')]
        [string]$TaskSequenceName
    )

    Process {
        Try {
            ## Retrieve the PackageID and AdvertisementID from the machine actual policy
            $SoftwareDistributionPolicy = Get-CimInstance -Namespace 'root\ccm\policy\machine\actualconfig' -ClassName 'CCM_SoftwareDistribution' | Where-Object { $PSItem.PKG_Name -like $TaskSequenceName } | Select-Object -Property 'PKG_PackageID', 'ADV_AdvertisementID'

            ## Retrieve the ScheduleID used for triggering a new required assignment for task sequence
            $ScheduleID = Get-CimInstance -Namespace 'root\ccm\scheduler' -ClassName 'CCM_Scheduler_History' | Where-Object { $PSItem.ScheduleID -like "*$($SoftwareDistributionPolicy.PKG_PackageID)*" } | Select-Object -ExpandProperty 'ScheduleID'

            ## Check if the RepeatRunBehavior is set to RerunAlways, if not change the value
            $TaskSequencePolicy = Get-CimInstance -Namespace 'root\ccm\policy\machine\actualconfig' -ClassName 'CCM_TaskSequence' | Where-Object { $PSItem.ADV_AdvertisementID -like $SoftwareDistributionPolicy.ADV_AdvertisementID }
            If ($($TaskSequencePolicy.ADV_RepeatRunBehavior) -NotLike 'RerunAlways') {
                $TaskSequencePolicy.ADV_RepeatRunBehavior = 'RerunAlways'
            }

            ## Set the mandatory assignment property to true mimicing it contains assignments
            $TaskSequencePolicy.ADV_MandatoryAssignments = $true

            ## Invoke the mandatory assignment
            Invoke-CimMethod -Namespace 'root\ccm' -ClassName 'SMS_Client' -Name 'TriggerSchedule' -Arguments @{sScheduleID = $ScheduleID}
            [string]$Output = "Successfully started task sequence [$TaskSequenceName]"
        }
        Catch {
            [string]$Output = "Could not start task sequence [$TaskSequenceName], $PSItem.ErrorMessage"
            $PSCmdlet.WriteError($PSItem)
        }
        Finally {
            Write-Output -InputObject $Output
        }
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

Start-CMTaskSequence -TaskSequenceName $TaskSequenceName

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================