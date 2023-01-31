<#
*********************************************************************************************************
* Requires          | Requires PowerShell 4.0                                                           *
* ===================================================================================================== *
* Modified by       |    Date    | Revision | Comments                                                  *
* _____________________________________________________________________________________________________ *
* Ioan Popovici     | 2018-03-05 | v1.0     | First version                                             *
* ===================================================================================================== *
*                                                                                                       *
*********************************************************************************************************

.SYNOPSIS
    This PowerShell Script is used to set send mails when SCCM security scopes change.
.DESCRIPTION
    This PowerShell Script is used to set send mails when SCCM security Production and Quality Security Scopes change.
.EXAMPLE
    C:\Windows\System32\WindowsPowerShell\v1.0\PowerShell.exe -NoExit -NoProfile -File Start-CMStatusMessageProcessing.ps1 -SMDescription 'associated'
.LINK
    https://SCCM-Zone.com
    https://github.com/Ioan-Popovici/SCCMZone
#>

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)]
        [Alias('SM')]
        [ValidateNotNullorEmpty()]
        [string]$SMDescription
    )

#endregion
##*=============================================
##* END VARIABLE DECLARATION
##*=============================================

##*=============================================
##* FUNCTION LISTINGS
##*=============================================
#region FunctionListings

#region Function Send-Mail
Function Send-Mail {
<#
.SYNOPSIS
    Sends a mail.
.DESCRIPTION
    Sends a mail with the specified parameters.
.PARAMETER From
    Mail 'FROM' field.
.PARAMETER To
    Mail 'TO' field.
.PARAMETER CC
    Mail 'CC' field.
.PARAMETER Subject
    Mail 'Subject' field.
.PARAMETER Body
    Mail Body.
.PARAMETER SMTPServer
    SMTPServer to use when sending the mail.
.PARAMETER SMTPPort
    SMTPPort to use when sending the mail.
.EXAMPLE
    Send-MailMessage -From 'John@JohnDoe.com' -To 'Somebody@somedomain.com' -Subject 'Some Subject' -Body 'EmailBody' -SmtpServer 'SomeSMTPServer' -Port 'SomeSMTPPort' -ErrorAction 'Stop'
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://SCCM-Zone.com
    https://github.com/Ioan-Popovici/SCCMZone
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)]
        [string]$From,
        [Parameter(Mandatory=$true)]
        [string]$To,
        [Parameter(Mandatory=$false)]
        [string]$CC = '',
        [Parameter(Mandatory=$false)]
        [string]$Subject = "Info: Quality Check Needed!",
        [Parameter(Mandatory=$true)]
        [string]$Body,
        [Parameter(Mandatory=$true)]
        [string]$SMTPServer,
        [Parameter(Mandatory=$false)]
        [string]$SMTPPort = "25"
    )
    Try {
        Send-MailMessage -From $From -To $To -Subject $Subject -Body $Body -SmtpServer $SMTPServer -Port $SMTPPort -ErrorAction 'Stop'
    }
    Catch {
        Write-Error "Send Mail Failed!"
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

    # Arrays for Name, RegEx, and result object
    $NameArray = @('User','Object','Type','Scope','Action')
    $PatternArray = @('\S+(?<=\\)\S+','(?<=object\s)[^(]+','(?<=Type:\s..._)\w+','(?<=scope:\s)\w+','(associated|deassociated)')
    $InfoArray = @{}

    # RegEx pattern matching
    ForEach ($Item in 0..($NameArray.length -1)){
        $SMDescription | Select-String -Pattern $PatternArray[$Item] -AllMatches | ForEach-Object { $InfoArray.($NameArray[$Item]) = $_.Matches.Value }
    }

    # Building object from result array
    $Result = New-Object -TypeName PSObject -Property $InfoArray
    Write-Output $Result

    # Send diferent mails depending on Scope and action
    If (($Result.Scope -eq "Quality") -and ($Result.Action -eq "associated")) {
        Send-Mail -Body "$($Result.User) $($Result.Action) $($Result.Scope) Scope to the $($Result.Type) named $($Result.Object)"
    }
    ElseIf ($Result.Scope -eq "Production" -and ($Result.Action -eq "associated")) {
        Send-Mail -Subject "Warning: Production Scope Added!" -Body "$($Result.User) $($Result.Action) $($Result.Scope) Scope to the $($Result.Type) named $($Result.Object)"
    }
    Else {
        Write-Host "No actions match, nothing to do..."
    }

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================
