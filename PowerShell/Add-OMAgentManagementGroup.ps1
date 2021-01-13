<#
.SYNOPSIS
    Adds a management group to the Operations Manager agent
.DESCRIPTION
    Adds a default or an additional management group to the Operations Manager agent
.PARAMETER Server
    Specifies the Operations Manager management server name.
.PARAMETER Group
    Specifies the Operations Manager management group name.
.PARAMETER Port
    Specifies the Operations Manager management port name.
.EXAMPLE
    Add-OMAgentManagementGroup.ps1 -Server 'SCOM01.domain' -Group 'SCOMMG' -Port '666' -Force
.EXAMPLE
    Add-OMAgentManagementGroup.ps1
.INPUTS
    None.
.OUTPUTS
    None.
.NOTES
    Created by Ioan Popovici
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/Issues
.COMPONENT
    Operations Manager
.FUNCTIONALITY
    Adds Operations Manager management group
#>

## Set script requirements
#Requires -Version 3.0

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

## Get script parameters
Param (
    [Parameter(Mandatory=$false,HelpMessage='Management server',Position=0)]
    [Alias('ManagementServer')]
    [string]$Server = '' ,
    [Parameter(Mandatory=$false,HelpMessage='Management group',Position=1)]
    [Alias('ManagementGroup')]
    [string]$Group = '',
    [Parameter(Mandatory=$false,HelpMessage='Management port',Position=2)]
    [Alias('ManagementPort')]
    [int]$Port = 5723,
    [Parameter(Mandatory=$false,Position=3)]
    [Alias('Overwrite')]
    [string]$Force = $true
    #[switch]$Force = $true
)

## Switch parameter is not supported by the run script feature
If ($Force -eq 'True') {
    Remove-Variable -Name 'Force'
    [switch]$Force = $true
}
Else {
    Remove-Variable -Name 'Force'
    [Switch]$Force = $false
}

#endregion
##*=============================================
##* END VARIABLE DECLARATION
##*=============================================

##*=============================================
##* FUNCTION LISTINGS
##*=============================================
#region FunctionListings

#region Function Add-OMAgentManagementGroup
Function  Add-OMAgentManagementGroup {
<#
.SYNOPSIS
    Adds a management group to the Operations Manager agent
.DESCRIPTION
    Adds a default or an additional management group to the Operations Manager agent
.PARAMETER Server
    Specifies the Operations Manager management server name.
.PARAMETER Group
    Specifies the Operations Manager management group name.
.PARAMETER Port
    Specifies the Operations Manager management port name.
.EXAMPLE
    Add-OMAgentManagementGroup.ps1 -Server 'SCOM01.domain' -Group 'SCOMMG' -Port '666' -Force
.EXAMPLE
    Add-OMAgentManagementGroup.ps1
.INPUTS
    None.
.OUTPUTS
    None.
.NOTES
    Created by Ioan Popovici
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/Issues
.COMPONENT
    Operations Manager
.FUNCTIONALITY
    Adds Operations Manager management group
#>

## Set script requirements
#Requires -Version 3.0

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

## Get script parameters
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$false,HelpMessage='Management server',Position=0)]
        [Alias('ManagementServer')]
        [string]$Server = 'ipvitscomgm001.adm.datakraftverk.no' ,
        [Parameter(Mandatory=$false,HelpMessage='Management group',Position=1)]
        [Alias('ManagementGroup')]
        [string]$Group = 'vitscomg',
        [Parameter(Mandatory=$false,HelpMessage='Management port',Position=2)]
        [Alias('ManagementPort')]
        [int]$Port = 5723,
        [Parameter(Mandatory=$false,Position=3)]
        [Alias('Overwrite')]
        [switch]$Force
    )

    Begin {
        [bool]$IsInstalled = If (Get-Service -Name 'HealthService' -ErrorAction 'SilentlyContinue') { $true } Else { $false }
        [string]$Result = $null
        [string]$ComputerFullName = -join ($env:ComputerName, $env:USERDNSDOMAIN)
    }
    Process {
        Try {
            If ($IsInstalled) {

                ## Initialize obiect
                [System.MarshalByRefObject]$Agent = New-Object -ComObject 'AgentConfigManager.MgmtSvcCfg' -ErrorAction 'Stop'

                ## Check if group is present
                [System.MarshalByRefObject]$ConfiguredGroupName = $Agent.GetManagementGroups() | Where-Object -Property managementGroupName -eq $Group
                [bool]$GroupExists = If ($ConfiguredGroupName) { $true } Else { $false }
                If ($GroupExists -and $Force) {
                    Write-Warning -Message "Management group [$Group] already exists, removing..."
                    $Agent.RemoveManagementGroup($Group)
                }

                ## Adding MG to the agent
                $Agent.AddManagementGroup($Group, $Server, $Port)

                ## Restart service
                Write-Warning -Message "Restarting the SCOM agent service..."
                Restart-Service -Name 'HealthService'

                ## Store result
                $Result = "Succesfuly added management server [$Server], group [$Group] and port [$Port] to computer [$ComputerFullName]."
            }
            Else { $Result = 'SCOM Agent not present!' }
        }
        Catch {
            Write-Error -Message "Failed to add management server [$Server], group [$Group] and port [$Port] to computer [$ComputerFullName].`n$_" -ErrorAction 'Stop'

        }
        Finally {
            $ManagementGroups = $Agent.GetManagementGroups() | Out-String
            Write-Output -InputObject "$Result $ManagementGroups"
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

Add-OMAgentManagementGroup -Server $Server -Group $Group -Port $Port -Force:$Force

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================