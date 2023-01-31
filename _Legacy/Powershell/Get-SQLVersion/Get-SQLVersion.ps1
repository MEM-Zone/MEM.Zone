<#
*********************************************************************************************************
* Created by Ioan Popovici   | Requires PowerShell 3.0                                                  *
* ===================================================================================================== *
* Modified by   |    Date    | Revision | Comments                                                      *
* _____________________________________________________________________________________________________ *
* Ioan Popovici | 02/09/2016 | v1.0     | First version                                                 *
* ===================================================================================================== *
*                                                                                                       *
*********************************************************************************************************

.SYNOPSIS
    This PowerShell Script is used to Get the SQL Version.
.DESCRIPTION
    This PowerShell Script is used to Get the SQL Version, in use for SCCM Application Discovery and Configuration Items.
.NOTES
    To Fix:
    The Detection also Fails if SQL Native is installed
.NOTES
    SQL Versioning Reference: http://sqlserverbuilds.blogspot.ro/
.LINK
    https://SCCM-Zone.com
    https://github.com/Ioan-Popovici/SCCMZone
#>

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

##  Reference SQL Versions
[System.Version]$SQLVersion =  "12.0.5000.0" #2014 SP2

##  RegEx Pattern for Version Selection
[RegEx]$RegExPattern = "[0-9]+\.[0-9]+\.[0-9]+.[0-9]+"

#endregion
##*=============================================
##* END VARIABLE DECLARATION
##*=============================================

##*=============================================
##* SCRIPT BODY
##*=============================================
#region ScriptBody

## Get SQL Version with Error Handling
Try {
    [System.Version]$GetSQLVersion = (Invoke-Command -ScriptBlock { SQLCMD.exe -Q "Select @@Version" } -ErrorAction Stop | Select-String -Pattern $RegExPattern).Matches.Value
}
Catch {
    Write-Output "SQLCMD.exe Not Found, SQL is not Installed"
    $ErrorMessage = $_.Exception.Message

    #For some reason -ErrorAction Stop does not work using break
    Break
}

## Check if we Got the SQL Version.
If ($GetSQLVersion -eq $Null -and $ErrorMessage -eq $Null) {

    #  For Testing Only, This particular Write-Output needs to be removed for Discovery to work
    #  so it does not create an output which the will be interpreted as "Discovered"
    Write-Output "SQL Version Detection Failed!"
}
Else {

    ## Compare Reference Versions against Detected Version
    If ($GetSQLVersion.Major -eq $SQLVersion.Major -and $GetSQLVersion -ge $SQLVersion) {

        #  SQL Reference Version Already Detected
        Write-Output "SQL Version ($SQLVersion) Already Installed!"
    }
    ElseIf ($GetSQLVersion.Major -ne $SQLVersion.Major -and $GetSQLVersion -lt $SQLVersion) {

        #  For Testing Only, This particular Write-Output needs to be removed for Discovery to work
        #  so it does not create an output which the will be interpreted as "Discovered"
        Write-Output "Detected SQL Version ($GetSQLVersion) Older than Reference Version ($SQLVersion)!"
    }
    ElseIf ($GetSQLVersion.Major -ne $SQLVersion.Major -and $GetSQLVersion -gt $SQLVersion) {

        #  For Testing Only, This particular Write-Output needs to be removed for Discovery to work
        #  so it does not create an output which the will be interpreted as "Discovered"
        Write-Output "Detected SQL Version ($GetSQLVersion) Newer than Reference Version ($SQLVersion)!"
    }
}

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================
