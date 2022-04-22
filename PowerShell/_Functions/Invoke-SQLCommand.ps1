#region Function Invoke-SQLCommand
Function Invoke-SQLCommand {
<#
.SYNOPSIS
    Runs an SQL query.
.DESCRIPTION
    Runs an SQL query without any dependencies except .net.
.PARAMETER ServerInstance
    Specifies a character string or SQL Server Management Objects (SMO) object that specifies the name of an instance of the Database Engine. For default instances, only specify the computer name: MyComputer. For named instances, use the format ComputerName\InstanceName.
.PARAMETER Database
    Specifies the name of a database. This cmdlet connects to this database in the instance that is specified in the ServerInstance parameter.
.PARAMETER Username
    Specifies the login ID for making a SQL Server Authentication connection to an instance of the Database Engine.
    If Username and Password are not specified, this cmdlet attempts a Windows Authentication connection using the Windows account running the Windows PowerShell session. When possible, use Windows Authentication.
.PARAMETER Password
    Specifies the password for the SQL Server Authentication login ID that was specified in the Username parameter.
    If Username and Password are not specified, this cmdlet attempts a Windows Authentication connection using the Windows account running the Windows PowerShell session. When possible, use Windows Authentication.
.PARAMETER Query
    Specifies one or more queries that this cmdlet runs.
.PARAMETER ConnectionTimeout
    Specifies the number of seconds when this cmdlet times out if it cannot successfully connect to an instance of the Database Engine. The timeout value must be an integer value between 0 and 65534. If 0 is specified, connection attempts does not time out.
    Default is: '0'.
.PARAMETER UseSQLAuthentication
    Specifies to use SQL Server Authentication instead of Windows Authentication. You will be asked for credentials if this switch is used.
.EXAMPLE
    Invoke-SQLCommand -ServerInstance 'CM-SQL-RS-01A' -Database 'CM_XXX' -Query 'SELECT * TOP 5 FROM v_UpdateInfo' -ConnectionTimeout 20
.EXAMPLE
    Invoke-SQLCommand -ServerInstance 'CM-SQL-RS-01A' -Database 'CM_XXX' -Query 'SELECT * TOP 5 FROM v_UpdateInfo' -ConnectionTimeout 20 -UseSQLAuthentication
.INPUTS
    None.
.OUTPUTS
    System.Data.DataRow
    System.String
    System.Exception
.NOTES
    This is an private function and should tipically not be called directly.
.LINK
    https://stackoverflow.com/questions/8423541/how-do-you-run-a-sql-server-query-from-powershell
.LINK
    https://MEM.Zone/
.LINK
    https://MEM.Zone/Install-SRSReport-GIT
.LINK
    https://MEM.Zone/Install-SRSReport-ISSUES
.COMPONENT
    RS
.FUNCTIONALITY
    RS Catalog Item Installer
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true,HelpMessage='SQL server and instance name',Position=0)]
        [ValidateNotNullorEmpty()]
        [Alias('Server')]
        [string]$ServerInstance,
        [Parameter(Mandatory=$true,HelpMessage='Database name',Position=1)]
        [ValidateNotNullorEmpty()]
        [Alias('Dbs')]
        [string]$Database,
        [Parameter(Mandatory=$true,Position=4)]
        [ValidateNotNullorEmpty()]
        [Alias('Qry')]
        [string]$Query,
        [Parameter(Mandatory=$false,Position=5)]
        [ValidateNotNullorEmpty()]
        [Alias('Tmo')]
        [int]$ConnectionTimeout = 0,
        [Parameter(Mandatory=$false,Position=6)]
        [ValidateNotNullorEmpty()]
        [Alias('SQLAuth')]
        [switch]$UseSQLAuthentication
    )
    Begin {

        ## Assemble connection string
        [string]$ConnectionString = "Server=$ServerInstance; Database=$Database; "
        #  Set connection string for integrated or non-integrated authentication
        If ($UseSQLAuthentication) {
            # Get credentials if SQL Server Authentication is used
            $Credentials = Get-Credential -Message 'SQL Credentials'
            [string]$Username = $($Credentials.UserName)
            [securestring]$Password = $($Credentials.Password)
            # Set connection string
            $ConnectionString += "User ID=$Username; Password=$Password;"
        }
        Else { $ConnectionString += 'Trusted_Connection=Yes; Integrated Security=SSPI;' }
    }
    Process {
        Try {

            ## Connect to the database
            Write-Verbose -Message "Connecting to [$Database]..."
            $DBConnection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
            $DBConnection.Open()

            ## Assemble query object
            $Command = $DBConnection.CreateCommand()
            $Command.CommandText = $Query
            $Command.CommandTimeout = $ConnectionTimeout

            ## Run query
            Write-Verbose -Message 'Running SQL query...'
            $DataAdapter = New-Object System.Data.SqlClient.SqlDataAdapter -ArgumentList $Command
            $DataSet = New-Object System.Data.DataSet
            $DataAdapter.Fill($DataSet) | Out-Null

            ## Return the first collection of results or an empty array
            If ($null -ne $($DataSet.Tables[0])) { $Table = $($DataSet.Tables[0]) }
            ElseIf ($($Table.Rows.Count) -eq 0) { $Table = New-Object System.Collections.ArrayList }

            ## Close database connection
            $DBConnection.Close()
        }
        Catch {
            Throw (New-Object System.Exception("Error running query! $($_.Exception.Message)", $_.Exception))
        }
        Finally {
            Write-Output $Table
        }
    }
}
#endregion