<#
.SYNOPSIS
    Invokes a configuration manager compliance action
.DESCRIPTION
    Invokes a configuration manager compliance action. Set/Remove item.
.PARAMETER Action
    Specifies the action to take if detection returns $true.
    Available actions: 'Report', 'Set', 'Remove'.
.PARAMETER ComplianceRule
    Specifies the required detection result for the compliance rule. The script will return 'Compliant' or 'NotCompliant' based on this rule.
    Available values: 'Detected', 'NotDetected'. Default is: 'Detected'.
.PARAMETER Provider
    Specifies the resource provider.
    Available values: 'Registry', 'FileSystem'.
.PARAMETER Path
    Specifies the item path.
.PARAMETER Name
    Specifies the item name.
.PARAMETER Value
    Specifies the item value.
.PARAMETER Type
    Specifies the item property type.
.EXAMPLE
    Invoke-ComplianceAction -Action 'Set' -ComplianceRule 'NotDetected' -Provider 'Registry' -Path 'HKLM:\\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'InactivityTimeoutSecs' -Type 'DWord' -Value '0'
.INPUTS
    System.String.
.OUTPUTS
    System.String. Returns 'Compliant', 'NonCompliant'.
.NOTES
    Created by Ioan Popovici
    You will need to customize the script variables in the ScriptParameters hashtable below.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    CM Compliance
.FUNCTIONALITY
    Invokes CM Compliance Action
#>

## Set script requirements
#Requires -Version 3.0

#*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

## Set verbose preference
#$VerbosePreference = 'Continue'

## Set script parameters
## Supported values
#  Action         : Report/Set/Remove
#  ComplianceRule : Detected/NotDetected
#  Type           : String/ExpandString/Binary/DWord/MultiString/Qword
#  String = REG_SZ, ExpandString = REG_EXPAND_SZ
[hashtable]$ScriptParameters = @{
    Action         = 'Set'
    ComplianceRule = 'Detected'
    Provider       = 'Registry'
    Path           = 'HKLM:\\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
    Name           = 'InactivityTimeoutSecs'
    Type           = 'DWord'
    Value          = '500'
}

#endregion
##*=============================================
##* END VARIABLE DECLARATION
##*=============================================

##*=============================================
##* FUNCTION LISTINGS
##*=============================================
#region FunctionListings

#region Get-RegistryItem
Function Get-RegistryItem {
<#
.SYNOPSIS
    Gets a registry item.
.DESCRIPTION
    Gets a registry item, and checks if the property value matches the specified value.
.PARAMETER Path
    Specifies the registry key path.
.PARAMETER Name
    Specifies the registry key property name.
.PARAMETER Value
    Specifies the registry key property value.
.EXAMPLE
    Get-RegistryItem -Path 'HKLM:\\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'InactivityTimeoutSecs' -Value '0'
.INPUTS
    System.String.
.OUTPUTS
    System.String. Returns 'Detected' or 'NotDetected'
.NOTES
    Created by Ioan Popovici
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    CM Compliance
.FUNCTIONALITY
    Registry Item Detection
#>

    [cmdletbinding()]
    Param (
        [Parameter(Mandatory=$true,Position=0)]
        [ValidateNotNullorEmpty()]
        [string]$Path,
        [Parameter(Mandatory=$false,Position=1)]
        [string]$Name,
        [Parameter(Mandatory=$false,Position=2)]
        [string]$Value
    )

    Begin {
        [string]$Result = 'NotDetected'
    }
    Process {
        Try {

            ## If $Name was not specified check if path exists
            [bool]$PathExists = Test-Path -Path $Path
            If (-not $Name -and $PathExists) { $Result = 'Detected' }

            ## Get the registry property value
            Else { $RegistryItem = Get-ItemProperty -Path $Path -Name $Name -ErrorAction 'SilentlyContinue' }

            ## If value was specified check if it matches the registry value, else check if the reigistry item was found
            If (-not [string]::IsNullOrWhiteSpace($Value) -and $Value -eq $RegistryItem.$Name) { $Result = 'Detected' }
            ElseIf (-not [string]::IsNullOrWhiteSpace($RegistryItem)) { $Result = 'Detected' }
        }
        Catch {
            Throw "Could not Get property [$Path][$Name].`n$($_.Exception.Message)"
        }
        Finally {
            Write-Verbose -Message $Result
            Write-Output -InputObject $Result
        }
    }
    End {
    }
}
#endregion

#region Set-RegistryItem
Function Set-RegistryItem {
<#
.SYNOPSIS
    Sets a registry item.
.DESCRIPTION
    Sets a registry item key, property or value.
.PARAMETER Path
    Specifies the registry key path.
.PARAMETER Name
    Specifies the registry key property name.
.PARAMETER Value
    Specifies the registry key property value.
.PARAMETER Type
    Specifies the registry key property type. Default is 'DWORD'.
.EXAMPLE
    Set-RegistryItem -Path 'HKLM:\\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'InactivityTimeoutSecs' -Value '0' -Type 'DWORD'
.INPUTS
    System.String.
.OUTPUTS
    System.String.
.NOTES
    Created by Ioan Popovici
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    CM Compliance
.FUNCTIONALITY
    Sets a Registry Item
#>

    [cmdletbinding()]
    Param (
        [Parameter(Mandatory=$true,Position=0)]
        [ValidateNotNullorEmpty()]
        [string]$Path,
        [Parameter(Mandatory=$false,Position=1)]
        [ValidateNotNullorEmpty()]
        [string]$Name,
        [Parameter(Mandatory=$false,Position=3)]
        [ValidateNotNullorEmpty()]
        [string]$Value,
        [Parameter(Mandatory=$false,Position=4)]
        [ValidateNotNullorEmpty()]
        [string]$Type = 'DWord'
    )

    Begin {
    }
    Process {
        Try {

            ## Create the key if it does not exist
            If (-not (Test-Path -Path $Path)) { New-Item -Path $Path -Force -ErrorAction 'Stop' }

            ## Set the item property name and value
            If ($Name) { Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force -ErrorAction 'Stop' }

            ## Return Result
            $Result = 'Succesfully set registry item.'

        }
        Catch {
            $Result = "Could not set registry item [$Path][$Name][$Value][$Type].`n$($_.Exception.Message)"
            Throw $Result
        }
        Finally {
            Write-Verbose -Message $Result
            Write-Output -InputObject $Result
        }
    }
    End {
    }
}
#endregion

#region Remove-RegistryItem
Function Remove-RegistryItem {
<#
.SYNOPSIS
    Removes a registry item.
.DESCRIPTION
    Removes a registry item key or property
.PARAMETER Path
    Specifies the registry key path.
.PARAMETER Name
    Specifies the registry key property name.
.EXAMPLE
    Set-RegistryItem -Path 'HKLM:\\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'InactivityTimeoutSecs' -Value '0' -Type 'DWORD'
.INPUTS
    System.String.
.OUTPUTS
    System.String.
.NOTES
    Created by Ioan Popovici
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    CM Compliance
.FUNCTIONALITY
    Removes a Registry Item
#>

    [cmdletbinding()]
    Param (
        [Parameter(Mandatory=$true,Position=0)]
        [ValidateNotNullorEmpty()]
        [string]$Path,
        [Parameter(Mandatory=$false,Position=1)]
        [string]$Name
    )

    Begin {
    }
    Process {
        Try {

            ## Remove the item property
            If ($Name) { Remove-ItemProperty -Path $Path -Name $Name -Force -ErrorAction 'SilentlyContinue' }

            ## Remove the key if it exists and not property name has been specified
            If (-not $Name -and (Test-Path -Path $Path)) { Remove-Item -Path $Path -Force -ErrorAction 'SilentlyContinue' }

            ## Return Result
            $Result = 'Succesfully removed registry item.'

        }
        Catch {
            $Result = "Could not remove registry item [$Path][$Name].`n$($_.Exception.Message)"
            Throw $Result
        }
        Finally {
            Write-Verbose -Message $Result
            Write-Output -InputObject $Result
        }
    }
    End {
    }
}
#endregion

#region Invoke-ComplianceAction
Function Invoke-ComplianceAction {
<#
.SYNOPSIS
    Invokes a configuration manager compliance action
.DESCRIPTION
    Invokes a configuration manager compliance action. Set/Remove item.
.PARAMETER Action
    Specifies the action to take if detection returns $true.
    Available actions: 'Report', 'Set', 'Remove'.
.PARAMETER ComplianceRule
    Specifies the required detection result for the compliance rule. The script will return 'Compliant' or 'NotCompliant' based on this rule.
    Available values: 'Detected', 'NotDetected'. Default is: 'Detected'.
.PARAMETER Provider
    Specifies the resource provider.
    Available values: 'Registry', 'FileSystem'.
.PARAMETER Path
    Specifies the item path.
.PARAMETER Name
    Specifies the item name.
.PARAMETER Type
    Specifies the item property type.
.PARAMETER Value
    Specifies the item value.
.EXAMPLE
    Invoke-ComplianceAction -Action 'Set' -ComplianceRule 'NotDetected' -Provider 'Registry' -Path 'HKLM:\\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'InactivityTimeoutSecs' -Type 'DWord' -Value '0'
.INPUTS
    System.String.
.OUTPUTS
    System.String. Returns 'Compliant', 'NonCompliant'.
.NOTES
    Created by Ioan Popovici
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    CM Compliance
.FUNCTIONALITY
    Invokes Compliance Action
#>

    [cmdletbinding()]
    Param (
        [Parameter(Mandatory=$true,HelpMessage="Enter a valid Action to perform.",Position=0)]
        [ValidateNotNullorEmpty()]
        [ValidateSet('Report','Set','Remove')]
        [string]$Action,
        [Parameter(Mandatory=$false,Position=1)]
        [ValidateSet('Detected','NotDetected')]
        [string]$ComplianceRule = 'Detected',
        [Parameter(Mandatory=$true,HelpMessage="Enter a valid Provider.",Position=2)]
        [ValidateNotNullorEmpty()]
        [ValidateSet('Registry','FileSystem')]
        [string]$Provider,
        [Parameter(Mandatory=$true,HelpMessage="Enter a valid Path.",Position=3)]
        [ValidateNotNullorEmpty()]
        [string]$Path,
        [Parameter(Mandatory=$false,Position=4)]
        [string]$Name,
        [Parameter(Mandatory=$false,Position=5)]
        [string]$Type = 'DWord',
        [Parameter(Mandatory=$false,Position=6)]
        [string]$Value
    )

    Begin {
        If ([string]::IsNullOrWhiteSpace($ComplianceRule)) { $ComplianceRule = 'Detected' }
        If ([string]::IsNullOrWhiteSpace($Provider)) { $Provider = 'Registry' }
        If ([string]::IsNullOrWhiteSpace($Type)) { $Type = 'DWord' }
    }
    Process {
        Try {

            ## Select the Resource Provider
            Switch ($Provider) {
                'Registry' {
                    $DetectionResult = Get-RegistryItem -Path $Path -Name $Name -Value $Value

                    ## Run selected action if NonCompliance is detected
                    If ($ComplianceRule -ne $DetectionResult) {
                        Switch ($Action) {
                            'Report' {
                                $Result = 'NonCompliant'
                                Break
                            }
                            'Set' {
                                $null = Set-RegistryItem -Path $Path -Name $Name -Value $Value -Type $Type
                                $DetectionResult = Get-RegistryItem -Path $Path -Name $Name -Value $Value
                                Break
                            }
                            'Remove' {
                                $null = Remove-RegistryItem -Path $Path -Name $Name
                                $DetectionResult = Get-RegistryItem -Path $Path -Name $Name -Value $Value
                                Break
                            }
                            Default { Throw 'NotImplemented' }
                        }
                    }
                    Break
                }
                Default { Throw 'NotImplemented' }
            }
        }
        Catch {
            Write-Verbose $($_.Exception.Message)
            Throw "Remediation failed. `n$($_.Exception.Message)"
        }
        Finally {
            If ($DetectionResult -eq $ComplianceRule) { $Result = 'Compliant' } Else { $Result = 'NonCompliant' }
            Write-Output -InputObject $Result
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

Invoke-ComplianceAction @ScriptParameters

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================