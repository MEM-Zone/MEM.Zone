<#
.SYNOPSIS
    This script is a template that allows you to extend the toolkit with your own custom functions.
    # LICENSE #
    PowerShell App Deployment Toolkit - Provides a set of functions to perform common application deployment tasks on Windows.
    Copyright (C) 2017 - Sean Lillis, Dan Cunningham, Muhammad Mashwani, Aman Motazedian.
    This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation, either version 3 of the License, or any later version. This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
    You should have received a copy of the GNU Lesser General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.
.DESCRIPTION
    The script is automatically dot-sourced by the AppDeployToolkitMain.ps1 script.
.NOTES
    Toolkit Exit Code Ranges:
    60000 - 68999: Reserved for built-in exit codes in Deploy-Application.ps1, Deploy-Application.exe, and AppDeployToolkitMain.ps1
    69000 - 69999: Recommended for user customized exit codes in Deploy-Application.ps1
    70000 - 79999: Recommended for user customized exit codes in AppDeployToolkitExtensions.ps1
.LINK
    http://psappdeploytoolkit.com
#>
[CmdletBinding()]
Param (
)

##*===============================================
##* VARIABLE DECLARATION
##*===============================================

# Variables: Script
[string]$appDeployToolkitExtName = 'PSAppDeployToolkitExt'
[string]$appDeployExtScriptFriendlyName = 'App Deploy Toolkit Extensions'
[version]$appDeployExtScriptVersion = [version]'3.8.2'
[string]$appDeployExtScriptDate = '08/05/2020'
[hashtable]$appDeployExtScriptParameters = $PSBoundParameters

##*===============================================
##* FUNCTION LISTINGS
##*===============================================

#region Function Get-AdsiComputer
Function Get-AdsiComputer {
<#
.SYNOPSIS
    The Get-AdsiComputer function allows you to get information from an Active Directory Computer object using ADSI.
.DESCRIPTION
    The Get-AdsiComputer function allows you to get information from an Active Directory Computer object using ADSI.
    You can specify: how many result you want to see, which credentials to use and/or which domain to query.
.PARAMETER ComputerName
    Specifies the name(s) of the Computer(s) to query
.PARAMETER SizeLimit
    Specifies the number of objects to output. Default is 100000.
.PARAMETER DomainDN
    Specifies the path of the Domain to query.
    Examples:   "FX.LAB"
                "DC=FX,DC=LAB"
                "Ldap://FX.LAB"
                "Ldap://DC=FX,DC=LAB"
.PARAMETER Credential
    Specifies the alternate credentials to use.
.EXAMPLE
    Get-AdsiComputer
    This will show all the computers in the current domain
.EXAMPLE
    Get-AdsiComputer -ComputerName "Workstation001"
    This will query information for the computer Workstation001.
.EXAMPLE
    Get-AdsiComputer -ComputerName "Workstation001","Workstation002"
    This will query information for the computers Workstation001 and Workstation002.
.EXAMPLE
    Get-Content -Path c:\WorkstationsList.txt | Get-AdsiComputer
    This will query information for all the workstations listed inside the WorkstationsList.txt file.
.EXAMPLE
    Get-AdsiComputer -ComputerName "Workstation0*" -SizeLimit 10 -Verbose
    This will query information for computers starting with 'Workstation0', but only show 10 results max.
    The Verbose parameter allow you to track the progression of the script.
.EXAMPLE
    Get-AdsiComputer -ComputerName "Workstation0*" -SizeLimit 10 -Verbose -DomainDN "DC=FX,DC=LAB" -Credential (Get-Credential -Credential FX\Administrator)
    This will query information for computers starting with 'Workstation0' from the domain FX.LAB with the account FX\Administrator.
    Only show 10 results max and the Verbose parameter allows you to track the progression of the script.
.NOTES
    NAME:    FUNCT-AD-COMPUTER-Get-AdsiComputer.ps1
    AUTHOR:  Francois-Xavier CAT
    DATE:    2013/10/26
    WWW:     www.lazywinadmin.com
    TWITTER: @lazywinadmin
    VERSION HISTORY:
    1.0 2013.10.26
    Initial Version
#>

    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true)]
        [Alias('Computer')]
        [String[]]$ComputerName,
        [Alias('ResultLimit', 'Limit')]
        [int]$SizeLimit='100000',
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [Alias('Domain')]
        [String]$DomainDN=$(([adsisearcher]"").Searchroot.path),
        [Alias('RunAs')]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty
    )
    Begin {
        ## Get the name of this function and write header
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
    }
    Process {
        If ($ComputerName) {
            Write-Verbose -Message "One or more ComputerName specified"
            ForEach ($item in $ComputerName) {
                Try {

                    ## Building the basic search object with some parameters
                    Write-Log -Message "COMPUTERNAME: $item" -Severity 1 -Source ${CmdletName}
                    $Searcher = New-Object -TypeName 'System.DirectoryServices.DirectorySearcher' -ErrorAction 'Stop' -ErrorVariable 'ErrProcessNewObjectSearcher'
                    $Searcher.Filter = "(&(objectCategory=Computer)(name=$item))"
                    $Searcher.SizeLimit = $SizeLimit
                    $Searcher.SearchRoot = $DomainDN

                    ## Specify a different domain to query
                    If ($PSBoundParameters['DomainDN']) {
                        If ($DomainDN -notlike 'LDAP://*') { $DomainDN = "LDAP://$DomainDN" }
                        Write-Log -Message "Different Domain specified: $DomainDN" -Severity 1 -Source ${CmdletName}
                        $Searcher.SearchRoot = $DomainDN
                    }

                    ## Alternate Credentials
                    If ($PSBoundParameters['Credential']) {
                        Write-Log -Message "Different Credential specified: $($Credential.UserName)" -Severity 1 -Source ${CmdletName}
                        $Domain = New-Object -TypeName 'System.DirectoryServices.DirectoryEntry' -ArgumentList $DomainDN,$($Credential.UserName),$($Credential.GetNetworkCredential().Password) -ErrorAction 'Stop' -ErrorVariable 'ErrProcessNewObjectCred'
                        $Searcher.SearchRoot = $Domain
                    }

                    # Querying the Active Directory
                    Write-Log -Message "Starting the ADSI Search..." -Severity 1 -Source ${CmdletName}
                    ForEach ($Computer in $($Searcher.FindAll())) {
                        Write-Log -Message "$($Computer.properties.name)" -Severity 1 -Source ${CmdletName}
                        New-Object -TypeName 'PSObject' -ErrorAction 'Stop' -ErrorVariable 'ErrProcessNewObjectOutput' -Property @{
                            'Name'              = $($Computer.properties.name)
                            'DNShostName'       = $($Computer.properties.dnshostname)
                            'Description'       = $($Computer.properties.description)
                            'OperatingSystem'   = $($Computer.properties.operatingsystem)
                            'WhenCreated'       = $($Computer.properties.whencreated)
                            'DistinguishedName' = $($Computer.properties.distinguishedname)
                        }
                    }
                    Write-Log -Message 'ADSI Search completed' -Severity 1 -Source ${CmdletName}
                }
                Catch {
                    If ($ErrProcessNewObjectSearcher) {
                        Write-Log -Message "Error during the creation of the searcher object! `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
                        Throw "Error during the creation of the searcher object: $($_.Exception.Message)"
                    }
                    ElseIf ($ErrProcessNewObjectCred) {
                        Write-Log -Message "Error during the creation of the alternate credential object! `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
                        Throw "Error during the creation of the alternate credential object: $($_.Exception.Message)"
                    }
                    ElseIf ($ErrProcessNewObjectOutput) {
                        Write-Log -Message "Error during the creation of the output object! `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
                        Throw "Error during the creation of the output object: $($_.Exception.Message)"
                    }
                    Else {
                        Write-Log -Message "Something Wrong happened! `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
                        Throw "Something Wrong happened: $($_.Exception.Message)"
                    }
                }
            }
        }
        Else {
            Try {

                ## Building the basic search object with some parameters
                $Searcher = New-Object -TypeName 'System.DirectoryServices.DirectorySearcher' -ErrorAction 'Stop' -ErrorVariable 'ErrProcessNewObjectSearcherALL'
                $Searcher.Filter = "(objectCategory=Computer)"
                $Searcher.SizeLimit = $SizeLimit

                ## Specify a different domain to query
                If ($PSBoundParameters['DomainDN']) {
                    $DomainDN = "LDAP://$DomainDN"
                    Write-Log -Message "Different Domain specified: $DomainDN" -Severity 1 -Source ${CmdletName}
                    $Searcher.SearchRoot = $DomainDN
                }

                ## Alternate Credentials
                If ($PSBoundParameters['Credential']) {
                    Write-Log -Message "Different Credential specified: $($Credential.UserName)" -Severity 1 -Source ${CmdletName}
                    $Domain = New-Object -TypeName 'System.DirectoryServices.DirectoryEntry' -ArgumentList $DomainDN, $Credential.UserName,$Credential.GetNetworkCredential().Password -ErrorAction 'Stop' -ErrorVariable 'ErrProcessNewObjectCredALL'
                    $Searcher.SearchRoot = $Domain
                }

                ## Querying the Active Directory
                Write-Log -Message 'Starting the ADSI Search...' -Severity 1 -Source ${CmdletName}
                ForEach ($Computer in $($Searcher.FindAll())) {
                    Try {
                        Write-Verbose -Message "$($Computer.Properties.Name)"
                        New-Object -TypeName 'PSObject' -ErrorAction 'Stop' -Property @{
                            'Name'              = $($Computer.properties.name)
                            'DNShostName'       = $($Computer.properties.dnshostname)
                            'Description'       = $($Computer.properties.description)
                            'OperatingSystem'   = $($Computer.properties.operatingsystem)
                            'WhenCreated'       = $($Computer.properties.whencreated)
                            'DistinguishedName' = $($Computer.properties.distinguishedname)
                        }
                    }
                    Catch {
                        Write-Log -Message $('{0}: {1}' -f $Computer) -Severity 3 -Source ${CmdletName}
                        Write-Log -Message "Error during the creation of the output object! `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
                        Throw "Error during the creation of the output object: $($_.Exception.Message)"
                    }
                }
                Write-Log -Message 'ADSI Search completed' -Severity 1 -Source ${CmdletName}
            }
            Catch {
                If ($ErrProcessNewObjectSearcherALL) {
                    Write-Log -Message "Error during the creation of the searcher object! `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
                    Throw "Error during the creation of the searcher object: $($_.Exception.Message)"
                }
                ElseIf ($ErrProcessNewObjectCredALL) {
                    Write-Log -Message "Error during the creation of the alternate credential object! `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
                    Throw "Error during the creation of the alternate credential object: `$($_.Exception.Message)"
                }
                Else {
                    Write-Log -Message "Something Wrong happened! `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
                    Throw "Something Wrong happened: $($_.Exception.Message)"
                }
            }
        }
    }
    End {
        Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
    }
}
#endregion

#region Function Get-AvailableComputerName
Function Get-AvailableComputerName {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true,Position=0)]
        [Alias('Srv')]
        [string]$Server,
        [Parameter(Mandatory=$true,Position=1)]
        [Alias('DomainName')]
        [string]$Domain,
        [Parameter(Mandatory=$true,Position=2)]
        [Alias('OU','Location')]
        [string]$OUPath,
        [Parameter(Mandatory=$true,Position=3)]
        [Alias('Name')]
        [string]$NamingConvention,
        [Parameter(Mandatory=$true,Position=4)]
        [Alias('Cred')]
        [pscredential]$Credential
    )
    Begin {

        ## Get the name of this function and write header
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header

        ## Variable Declaration
        [string]$Filter = $NamingConvention + '*'
        If ($Server) { [string]$DomainDN = $Server + '/' + $OUPath } Else { [string]$DomainDN = $OUPath }
    }
    Process {
        Try {

            ## Get an available computername by checking AD for the highest running number and increment it by 1
            [int[]]$ComputerIndexes = Get-AdsiComputer -DomainDN $DomainDN -ComputerName $Filter -Credential $Credential -ErrorAction 'Stop' | Select-Object -ExpandProperty 'Name' | ForEach-Object { ($_ -Split '-')[3]}
            #  Select the highest running number
            [int]$LastIndex = [int]($ComputerIndexes | Measure-Object -Maximum).Maximum
            #  Add 4 zeroes lead padding and increment the running number
            [string]$CurrentIndex = '{0:0000}' -f $($LastIndex + 1)
            #  Assemble new computer name
            [string]$NewComputerName = -Join ($NamingConvention,$CurrentIndex)
            #  Return computer name and wite it to the log
            Write-Log -Message "New ComputerName [$NewComputerName] resolved." -Severity 1 -Source ${CmdletName}
            Write-Output -InputObject $NewComputerName
        }
        Catch {
            Write-Log -Message "Failed to get computer name! `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
            Throw "Failed to get computer name: $($_.Exception.Message)"
        }
    }
    End {}
}
#endregion

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

#region Function Get-Certificate
Function Get-Certificate {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true,ParameterSetName='Serial',Position=0)]
        [Alias('Serial')]
        [string]$SerialNumber,
        [Parameter(Mandatory=$true,ParameterSetName='Name',Position=1)]
        [Alias('Certificate')]
        [string]$Name,
        [Parameter(Mandatory=$false,ParameterSetName='Serial',Position=1)]
        [Parameter(Mandatory=$false,ParameterSetName='Name',Position=1)]
        [Alias('Location')]
        [string]$StoreLocation = 'LocalMachine',
        [Parameter(Mandatory=$true,ParameterSetName='Serial',Position=2)]
        [Parameter(Mandatory=$true,ParameterSetName='Name',Position=2)]
        [Alias('Store')]
        [string]$StoreName
    )
    Begin {

        ## Get the name of this function and write header
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header

    }
    Process {
        Try {

            ## Create certificate store object
            $Store = New-Object System.Security.Cryptography.X509Certificates.X509Store $StoreName, $StoreLocation -ErrorAction 'Stop'

            ## Open the certificate store as ReadOnly
            $Store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)

            ## Get the certificate details
            If ($($PSCmdlet.ParameterSetName) -eq 'Serial') {
                $Result = $Store.Certificates | Where-Object { $_.SerialNumber -eq $SerialNumber }  | Select-Object SerialNumber,Thumbprint,Subject,Issuer,NotBefore,NotAfter
            }
            Else {
                $Result = $Store.Certificates | Where-Object { $_.Subject -eq $("CN=" + $Name) } | Select-Object SerialNumber,Thumbprint,Subject,Issuer,NotBefore,NotAfter
            }
            ## Close the certificate Store
            $Store.Close()

            ## Return certificate details or a 'Certificate Selection - Failed!' string if the certificate does not exist
            If ($Result) {
                Write-Output -InputObject $Result
            }
            Else {
                Write-Log -Message 'No certificate found!' -Severity 3 -Source ${CmdletName}
                Throw 'No certificate found!'
            }
        }
        Catch {
            Write-Log -Message "Failed to get certificate! `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
            Throw "Failed to get certificate: $($_.Exception.Message)"
        }
    }
    End {
        Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
    }
}
#endregion

#region Function Start-DomainOnboarding
Function Start-DomainOnboarding {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true,Position=0)]
        [Alias('Srv')]
        [string]$Server,
        [Parameter(Mandatory=$true,Position=1)]
        [Alias('DomainName')]
        [string]$Domain,
        [Parameter(Mandatory=$true,Position=2)]
        [Alias('OU','Location')]
        [string]$OUPath,
        [Parameter(Mandatory=$true,Position=3)]
        [Alias('Name')]
        [string]$NamingConvention,
        [Parameter(Mandatory=$true,Position=4)]
        [Alias('Cred')]
        [pscredential]$Credential
    )
    Begin {

        ## Get the name of this function and write header
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header
    }
    Process {
        Try {

            ## Get next available computer name
            $NewComputerName = Get-AvailableComputerName -Server $Server -Domain $Domain -OUPath $OUPath -NamingConvention $NamingConvention -Credential $Credential -ErrorAction 'Stop'

            ## Remove computer from current domain
            [bool]$IsDomainJoined = $((Get-CimInstance -ClassName 'Win32_ComputerSystem').PartOfDomain)
            If ($IsDomainJoined) {
                Remove-Computer -Force -PassThru -ErrorAction 'Stop'
                Write-Log -Message "Computer [$env:COMPUTERNAME] removed from domain [$env:USERDNSDOMAIN]" -Severity 1 -Source ${CmdletName}
                Start-Sleep -Seconds 5
            }

            ## Rename computer
            If ($env:COMPUTERNAME -ne $NewComputerName) {
                Rename-Computer -NewName $NewComputerName -Force -PassThru -ErrorAction 'Stop'
                Write-Log -Message "Computer [$env:COMPUTERNAME] renamed [$NewComputerName]" -Severity 1 -Source ${CmdletName}
                Start-Sleep -Seconds 5
            }
            Else { Write-Log -Message "Computer [$NewComputerName] is already renamed" -Severity 1 -Source ${CmdletName} }

            ## Write variables to log
            Write-Log -Message "Server [$Server]`nDomainName [$Domain]`nOUPath [$OUPath]`nOptions ['JoinWithNewName,AccountCreate']"

            ## Join computer to new domain
            Add-Computer -Server $Server -DomainName $Domain -OUPath $OUPath -Options 'JoinWithNewName','AccountCreate' -Credential $Credential -Force -PassThru -ErrorAction 'Stop'

            ## Write success
            Write-Log -Message 'Domain onboarding successful.' -Severity 1 -Source ${CmdletName}
        }
        Catch {
            Write-Log -Message "Domain onboarding failed! `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
            Throw "Domain onboarding failed: $($_.Exception.Message)"
        }
    }
    End {
        Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
    }
}
#endregion

#region Function Set-KMSClientSetupKey
Function Set-KMSClientSetupKey {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true,Position=0)]
        [Alias('KMSKey')]
        [string]$Key,
        [Parameter(Mandatory=$false,Position=1)]
        [Alias('OS')]
        [string]$OSName,
        [Parameter(Mandatory=$false,Position=2)]
        [Alias('ato')]
        [switch]$Activate
    )
    Begin {

        ## Get the name of this function and write header
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
        Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -CmdletBoundParameters $PSBoundParameters -Header

        ## Initialize variables
        [bool]$ShouldRun = $true
    }
    Process {
        Try {

            ## Check if Local OS Name matches the provided name
            If ($OSName) {
                #  Set $ShouldRun
                [string]$InstalledOSName = $(Get-CimInstance -ClassName 'Win32_OperatingSystem' -ErrorAction 'Stop').Caption
                If ($InstalledOSName -eq  $OSName) {
                    $ShouldRun = $false
                    Write-Log -Message "OS name [$OSName] match, skipping KMS client setup key step." -Severity 1 -Source ${CmdletName}
                }
            }

            ## Set KMS client setup key and activate
            If ($ShouldRun) {
                #  Set KMS key
                [wmi]$KMSObject = Get-WmiObject -Class 'SoftwareLicensingService' -ErrorAction 'Stop'
                $null = $KMSObject.InstallProductKey($Key)
                Write-Log -Message "KMS client setup key [$Key] set!" -Severity 1 -Source ${CmdletName}
                #  Activate OS
                If ($Activate) {
                    $null = $KMSObject.RefreshLicenseStatus()
                    Write-Log -Message 'Activation successful!' -Severity 1 -Source ${CmdletName}
                }
            }
        }
        Catch {
            Write-Log -Message "Failed to set or activate KMS client setup key [$Key]! `n$(Resolve-Error)" -Severity 3 -Source ${CmdletName}
        }
    }
    End {
        Write-FunctionHeaderOrFooter -CmdletName ${CmdletName} -Footer
    }
}
#endregion

##*===============================================
##* END FUNCTION LISTINGS
##*===============================================

##*===============================================
##* SCRIPT BODY
##*===============================================

If ($scriptParentPath) {
    Write-Log -Message "Script [$($MyInvocation.MyCommand.Definition)] dot-source invoked by [$(((Get-Variable -Name MyInvocation).Value).ScriptName)]" -Source $appDeployToolkitExtName
} Else {
    Write-Log -Message "Script [$($MyInvocation.MyCommand.Definition)] invoked directly" -Source $appDeployToolkitExtName
}

##*===============================================
##* END SCRIPT BODY
##*===============================================
