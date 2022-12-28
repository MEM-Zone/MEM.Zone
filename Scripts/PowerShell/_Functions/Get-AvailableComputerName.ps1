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