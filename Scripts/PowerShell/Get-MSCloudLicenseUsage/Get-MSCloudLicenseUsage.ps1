<#
.SYNOPSIS
    Checks the license usage of the specified license.
.DESCRIPTION
    Checks the license usage of the specified license. If the available amount is under the specified MinimumLicenseThreshold it will send a message to a slack webhook.
.PARAMETER TenantID
    Specifies the tenant ID.
.PARAMETER ClientID
    Specifies the application ID.
.PARAMETER ClientSecret
    Specifies the application secret.
.PARAMETER SkuIDs
    Specifies the skuId (GUID) of the license you want to check. This parameter is a Array.
.PARAMETER MinimumLicenseThreshold
    Limit for the minimum value, below this amount it will send a message to slack.
.PARAMETER SlackWebhookURI
    On what slack channel must the message be posted on.
.EXAMPLE
    Get-MSCloudLicenseUsage.ps1 -TenantID $TenantID -ClientID $ClientID -ClientSecret $ClientSecret -skuIds $skuIds -minAmount $minAmount -slackWebhookURI $slackWebhookURI
.INPUTS
    None.
.OUTPUTS
    None.
.NOTES
    Created by Ferry Bodijn
.LINK
    https://MEMZ.one/Get-MSCloudLicenseUsage
.LINK
    https://MEMZ.one/Get-MSCloudLicenseUsage-CHANGELOG
.LINK
    https://MEMZ.one/Get-MSCloudLicenseUsage-GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    MSGraph
.FUNCTIONALITY
    Get Cloud License Usage.
#>

## Set script requirements
#Requires -Version 5.1

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

## Get script parameters
[CmdletBinding(SupportsShouldProcess=$true, DefaultParameterSetName = 'Custom')]
Param (
    [Parameter(Mandatory = $true, ParameterSetName = 'Custom', HelpMessage = 'Specify the tenant ID', Position = 0)]
    [Parameter(Mandatory = $true, ParameterSetName = 'UserAttribute', HelpMessage = 'Enter the tenant ID', Position = 0)]
    [ValidateNotNullorEmpty()]
    [Alias('Tenant')]
    [string]$TenantID,
    [Parameter(Mandatory = $true, ParameterSetName = 'Custom', HelpMessage = 'Specify the Application (Client) ID to use.', Position = 1)]
    [Parameter(Mandatory = $true, ParameterSetName = 'UserAttribute', HelpMessage = 'Specify the Application (Client) ID to use.', Position = 1)]
    [ValidateNotNullorEmpty()]
    [Alias('ApplicationClientID')]
    [string]$ClientID,
    [Parameter(Mandatory = $true, ParameterSetName = 'Custom', HelpMessage = 'Specify the Application (Client) Secret to use.', Position = 2)]
    [Parameter(Mandatory = $true, ParameterSetName = 'UserAttribute', HelpMessage = 'Specify the Application (Client) Secret to use.', Position = 2)]
    [ValidateNotNullorEmpty()]
    [Alias('ApplicationClientSecret')]
    [string]$ClientSecret,
    [Parameter(Mandatory = $true, ParameterSetName = 'Custom', HelpMessage = 'Specify the skuID that can be found on the site: https://learn.microsoft.com/en-us/entra/identity/users/licensing-service-plan-reference.', Position = 2)]
    [Parameter(Mandatory = $true, ParameterSetName = 'UserAttribute', HelpMessage = 'Specify the skuID that can be found on the site: https://learn.microsoft.com/en-us/entra/identity/users/licensing-service-plan-reference.', Position = 2)]
    [ValidateNotNullorEmpty()]
    [Alias('GUID')]
    [array]$SkuIds,
    [Parameter(Mandatory = $true, ParameterSetName = 'Custom', HelpMessage = 'Specify the minimum amount of licenses before a slack message will be posted.', Position = 2)]
    [Parameter(Mandatory = $true, ParameterSetName = 'UserAttribute', HelpMessage = 'Specify the minimum amount of licenses before a slack message will be posted.', Position = 2)]
    [ValidateNotNullorEmpty()]
    [Alias('MinimumAmount')]
    [int]$MinimumLicenseThreshold,
    [Parameter(Mandatory = $true, ParameterSetName = 'Custom', HelpMessage = 'Specify the URL of the slack channel to post on.', Position = 2)]
    [Parameter(Mandatory = $true, ParameterSetName = 'UserAttribute', HelpMessage = 'Specify the URL of the slack channel to post on.', Position = 2)]
    [ValidateNotNullorEmpty()]
    [Alias('SlackWebhookURL')]
    [string]$SlackWebhookURI
)

## Set log name and path
[string]$ScriptName = 'Get-MSCloudLicense'
[string]$ScriptPath = "$ENV:ProgramData"

## SkuID examples
#SkuId: efccb6f7-5641-4e0e-bd10-b4976e1bf68e  - Enterprise Mobility + Security E3 license
#SkuId: 6a0f6da5-0b87-4190-a6ae-9bb5a2b9546a  - Windows 10/11 Enterprise E3

#endregion VariableDeclaration
##*=============================================
##* END VARIABLE DECLARATION
##*=============================================

##*=============================================
##* FUNCTION LISTINGS
##*=============================================
#region FunctionListings

#region Function Write-Log
Function Write-Log {
<#
.SYNOPSIS
    Creates a Log entry and appends it to a Log file.
.DESCRIPTION
    Creates a Log entry and appends it to a Log file.
.PARAMETER Severity
    Specifies the message severity of (Informational, Success or Error).
    Default is: 1.
.PARAMETER Message
    Specifies the log message to append.
.EXAMPLE
    Write-Log -Message 'Installation successful.' -Severity 2
.EXAMPLE
    Write-Log -Message 'Installation failed!' -Severity 3
.INPUTS
    System.Int32Type
    System.String
.OUTPUTS
    .None
.LINK
    https://MEM.Zone
.COMPONENT
    Get-MSCloudLicense
.FUNCTIONALITY
    Creates a Log file entry
#>
    Param (
        [Parameter(Mandatory = $false)]
        [string]$Message,
        [int]$Severity = 1
    )
    [string]$DeviceName = $env:COMPUTERNAME
    $Time = Get-Date -Format 'HH:mm:ss'
    $Date = Get-Date -Format 'yyyy-mm-dd'
    [string]$FilePath = -join ($ScriptPath,$ScriptName.tx)
    Switch ($Severity)
    {
        1 { $MessageSeverity = "INFORMATIONAL" }
        2 { $MessageSeverity = "SUCCESS" }
        3 { $MessageSeverity = "ERROR" }

    }
    $LogMessage = 'Device: {0}, Severity: {1}, Date: {2}, Time: {3}, Message: {4}`n' -f $DeviceName, $MessageSeverity, $Date, $Time, $Message
    $LogMessage | Out-File -Append -Encoding 'UTF8' -FilePath $FilePath -Force
}
#endregion Function Write-Log

#region Function Get-MSGraphAPIAccessToken
Function Get-MSGraphAPIAccessToken {
<#
.SYNOPSIS
    Gets a Microsoft Graph API access token.
.DESCRIPTION
    Gets a Microsoft Graph API access token, by using an application registered in EntraID.
.PARAMETER TenantID
    Specifies the tenant ID.
.PARAMETER ClientID
    Specify the Application Client ID to use.
.PARAMETER Secret
    Specify the Application Client Secret to use.
.PARAMETER Scope
    Specify the scope to use.
    Default is: 'https://graph.microsoft.com/.default'.
.PARAMETER GrantType
    Specify the grant type to use.
    Default is: 'client_credentials'.
.EXAMPLE
    Get-MSGraphAPIAccessToken -TenantID $TenantID -ClientID $ClientID -Secret $Secret -Scope 'https://graph.microsoft.com/.default' -GrantType 'client_credentials'
.EXAMPLE
    Get-MSGraphAPIAccessToken -TenantID $TenantID -ClientID $ClientID -Secret $Secret
.INPUTS
    None.
.OUTPUTS
    System.String
.NOTES
    Created by Ioan Popovici
    v1.0.0 - 2024-01-11
.LINK
    https://MEMZ.one/Invoke-MSGraphAPI
.LINK
    https://MEMZ.one/Invoke-MSGraphAPI-CHANGELOG
.LINK
    https://MEMZ.one/Invoke-MSGraphAPI-GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    MSGraph
.FUNCTIONALITY
    Gets a Microsoft Graph API Access Token.
#>
[CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = 'Specify the tenant ID.', Position = 0)]
        [ValidateNotNullorEmpty()]
        [Alias('Tenant')]
        [string]$TenantID,
        [Parameter(Mandatory = $true, HelpMessage = 'Specify the Application (Client) ID to use.', Position = 1)]
        [ValidateNotNullorEmpty()]
        [Alias('ApplicationClientID')]
        [string]$ClientID,
        [Parameter(Mandatory = $true, HelpMessage = 'Specify the Application (Client) Secret to use.', Position = 2)]
        [ValidateNotNullorEmpty()]
        [Alias('ApplicationClientSecret')]
        [string]$ClientSecret,
        [Parameter(Mandatory = $false, HelpMessage = 'Specify the scope to use.', Position = 3)]
        [ValidateNotNullorEmpty()]
        [Alias('GrantScope')]
        [string]$Scope = 'https://graph.microsoft.com/.default',
        [Parameter(Mandatory = $false, HelpMessage = 'Specify the grant type to use.', Position = 4)]
        [ValidateNotNullorEmpty()]
        [Alias('AccessType')]
        [string]$GrantType = 'client_credentials'
    )

    Begin {

        ## Assemble the token body for the API call. You can store the secrets in Azure Key Vault and retrieve them from there.
        [hashtable]$Body = @{
            client_id     = $ClientID
            scope         = $Scope
            client_secret = $ClientSecret
            grant_type    = $GrantType
        }

        ## Assembly the URI for the API call
        [string]$Uri = -join ('https://login.microsoftonline.com/', $TenantID, '/oauth2/v2.0/token')

        ## Write Debug information
        Write-Debug -Message "Uri: $Uri"
        Write-Debug -Message "Body: $($Body | Out-String)"
    }
    Process {
        Try {

            ## Get the access token
            $Response = Invoke-WebRequest -Method 'Post' -Uri $Uri -ContentType 'application/x-www-form-urlencoded' -Body $Body -UseBasicParsing

            ## Assemble output object
            $Output = [pscustomobject]@{
                access_token = $Response.access_token
                expires_in   = $Response.expires_in
                granted_on   = $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
            }
        }
        Catch {

            ## Write exception to log.
            #  Note that value__ is not a typo.
            [string]$StatusCode = $PsItem.Exception.Response.StatusCode.value__
            [string]$StatusDescription = $PSItem.Exception.Response.StatusDescription
            #  Assemble the error message
            [string]$Message = "Error getting MSGraph API Access Token for TenantID '{0}' with ClientID '{1}'.`n Status code {'2'}, Description {'3'}.`n{4}" -f $TenantID, $ClientID, $StatusCode, $StatusDescription, $PSItem.Exception.Message
            Write-Log -Message $Message -Severity 3
        }
        Finally {
            Write-Output -InputObject $Output
        }
    }
    End {
    }
}
#endregion

#region Function Invoke-MSGraphAPI
Function Invoke-MSGraphAPI {
<#
.SYNOPSIS
    Invokes the Microsoft Graph API.
.DESCRIPTION
    Invokes the Microsoft Graph API with paging support.
.PARAMETER Method
    Specify the method to use.
    Available options are 'GET', 'POST', 'PATCH', 'PUT' and 'DELETE'.
    Default is: 'GET'.
.PARAMETER Token
    Specify the access token to use.
.PARAMETER Version
    Specify the version of the Microsoft Graph API to use.
    Available options are 'Beta' and 'v1.0'.
    Default is: 'Beta'.
.PARAMETER Resource
    Specify the resource to query.
    Default is: 'deviceManagement/managedDevices'.
.PARAMETER Parameter
    Specify the parameter to use. Make sure to use the correct syntax and escape special characters with a backtick.
    Default is: $null.
.PARAMETER Body
    Specify the request body to use.
    Default is: $null.
.PARAMETER ContentType
    Specify the content type to use.
    Default is: 'application/json'.
.EXAMPLE
    Invoke-MSGraphAPI -Method 'GET' -Token $Token -Version 'Beta' -Resource 'deviceManagement/managedDevices' -Parameter "filter=operatingSystem like 'Windows' and deviceName like 'MEM-Zone-PC'"
.EXAMPLE
    Invoke-MSGraphAPI -Token $Token -Resource 'users'
.INPUTS
    None.
.OUTPUTS
    System.Object
.NOTES
    Created by Ioan Popovici
    v1.0.0 - 2024-01-11
.LINK
    https://MEMZ.one/Invoke-MSGraphAPI
.LINK
    https://MEMZ.one/Invoke-MSGraphAPI-CHANGELOG
.LINK
    https://MEMZ.one/Invoke-MSGraphAPI-GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    MSGraph
.FUNCTIONALITY
    Invokes the Microsoft Graph API.
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $false, HelpMessage = 'Specify the method to use.', Position = 0)]
        [ValidateSet('GET', 'POST', 'PATCH', 'PUT', 'DELETE')]
        [Alias('HTTPMethod')]
        [string]$Method = 'GET',
        [Parameter(Mandatory = $true, HelpMessage = 'Specify the access token to use.', Position = 1)]
        [ValidateNotNullorEmpty()]
        [Alias('AccessToken')]
        [string]$Token,
        [Parameter(Mandatory = $false, HelpMessage = 'Specify the version of the Microsoft Graph API to use.', Position = 2)]
        [ValidateSet('Beta', 'v1.0')]
        [Alias('GraphVersion')]
        [string]$Version = 'Beta',
        [Parameter(Mandatory = $true, HelpMessage = 'Specify the resource to query.', Position = 3)]
        [ValidateNotNullorEmpty()]
        [Alias('APIResource')]
        [string]$Resource,
        [Parameter(Mandatory = $false, HelpMessage = 'Specify the parameters to use.', Position = 4)]
        [ValidateNotNullorEmpty()]
        [Alias('QueryParameter')]
        [string]$Parameter,
        [Parameter(Mandatory = $false, HelpMessage = 'Specify the request body to use.', Position = 5)]
        [ValidateNotNullorEmpty()]
        [Alias('RequestBody')]
        [string]$Body,
        [Parameter(Mandatory = $false, HelpMessage = 'Specify the content type to use.', Position = 6)]
        [ValidateNotNullorEmpty()]
        [Alias('Type')]
        [string]$ContentType = 'application/json'
    )

    Begin {

        ## Assemble the URI for the API call
        [string]$Uri = "https://graph.microsoft.com/$Version/$Resource"
        If (-not [string]::IsNullOrWhiteSpace($Parameter)) { $Uri += "`?`$$Parameter" }

        ## Assembly parameters for the API call
        [hashtable]$Parameters = @{
            'Uri'         = $Uri
            'Method'      = $Method
            'Headers'     = @{
                'Content-Type'  = 'application\json'
                'Authorization' = "Bearer $Token"
            }
            'ContentType' = $ContentType
        }
        If (-not [string]::IsNullOrWhiteSpace($Body)) { $Parameters.Add('Body', $Body) }

        ## Write Debug information
        Write-Debug -Message "Uri: $Uri"
    }
    Process {
        Try {

            ## Invoke the MSGraph API
            $Output = Invoke-RestMethod @Parameters

            ## If there are more than 1000 rows, use paging. Only for GET method.
            If (-not [string]::IsNullOrEmpty($Output.'@odata.nextLink')) {
                #  Assign the nextLink to the Uri
                $Parameters.Uri = $Output.'@odata.nextLink'
                [array]$Output += Do {
                    #  Invoke the MSGraph API
                    $OutputPage = Invoke-RestMethod @Parameters
                    #  Assign the nextLink to the Uri
                    $Parameters.Uri = $OutputPage.'@odata.nextLink'
                    #  Write Debug information
                    Write-Debug -Message "Parameters:`n$($Parameters | Out-String)"
                    #  Return the OutputPage
                    $OutputPage
                }
                Until ([string]::IsNullOrEmpty($OutputPage.'@odata.nextLink'))
            }
            Write-Verbose -Message "Got '$($Output.Count)' Output pages."
        }
        Catch {
            [string]$Message = "Error invoking MSGraph API version '{0}' for resource '{1}' using '{2}' method.`n{3}" -f $Version, $Resource, $Method, $Error[0].Exception.Message
            Write-Log -Message $Message -Severity 3
            Write-Error -Message $Message
        }
        Finally {
            $Output = If ($Output.value) { $Output.value } Else { $Output }
            Write-Output -InputObject $Output
        }
    }
    End {
    }
}
#endregion Function Invoke-MSGraphAPI

#region function Send-SlackMessage
Function Send-SlackMessage {

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = 'Specify the header.', Position = 0)]
        [Alias('Title')]
        [string]$Header,
        [Parameter(Mandatory = $true, HelpMessage = 'Total licenses.', Position = 1)]
        [Alias('Total')]
        [string]$AvailableLicenses,
        [Parameter(Mandatory = $true, HelpMessage = 'Used licenses.', Position = 2)]
        [Alias('Used')]
        [string]$UsedLicenses,
        [Parameter(Mandatory = $true, HelpMessage = 'Licenses remaining.', Position = 3)]
        [Alias('Remaining')]
        [string]$RemainingLicenses,
        [Parameter(Mandatory = $true, HelpMessage = 'Slack webhook URL', Position = 4)]
        [Alias('WebhookURI')]
        [string]$slackWebhookURI
    )

    ## Assemble the notification payload
    [string]$Body =
@"
{
    "blocks": [
        {
            "type": "header",
            "text": {
                "type": "plain_text",
                "text": ":alert: $Header :alert:",
                "emoji": true
            }
        },
        {
            "type": "divider"
        },
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": "*Available Licenses:* $AvailableLicenses"
            }
        },
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": "*Used Licenses:* $UsedLicenses"
            }
        },
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": "*Remaining Licenses: $RemainingLicenses*"
            }
        },
        {
            "type": "section",
            "text": {
                "type": "plain_text",
                "text": "Please check if more licenses are required!",
                "emoji": true
            }
        }
    ]
}
"@

    ## Post to slack
    Start-Sleep -Seconds 1
    Try {
        $SlackNotify = Invoke-RestMethod -uri $SlackWebhookURI -Method 'POST' -Body $Body -ContentType 'application/json'

        If ($SlackNotify -ne 'ok') { $Output = "Could not send Slack message! '$SlackNotify'" } Else { $Output = 'Slack Message Sent!' }
    }
    Catch {
        Write-Error -Message "Error Sending Slack Message. $($_.Exception.Message)"
    }
    Finally {
        Write-Output -InputObject $Output
    }
}
#endregion Function Send-SlackMessage

#endregion FunctionListings
##*=============================================
##* END FUNCTION LISTINGS
##*=============================================

##*=============================================
##* SCRIPT BODY
##*=============================================
#region ScriptBody

#First remove old log:
If (Test-Path "$ScriptPath\$ScriptName.txt" -PathType 'Leaf') { Remove-Item -Path "$ScriptPath\$ScriptName.txt" -Force -Confirm:$false -ErrorAction 'SilentlyContinue' }

## Write Start verbose message
Write-Log -Message "Start '$ScriptName'" -Severity 1

## Get API Token
$AccessToken = Get-MSGraphAPIAccessToken -TenantID $TenantID ClientID $ClientID ClientSecret $ClientSecret -ErrorAction 'Stop'
$Token = $AccessToken.access_token


## Get all licenses from the tenant
$AvailableLicenses = Invoke-MSGraphAPI -Method 'GET' -Version 'v1.0' -Token $Token -Resource 'subscribedSkus' -ErrorAction 'Stop'

## Get information from 'https://docs.microsoft.com/en-us/azure/active-directory/users-groups-roles/licensing-service-plan-reference'
Try {

    #  Fetch the content as bytes
    $Response = Invoke-WebRequest -Uri "https://download.microsoft.com/download/e/3/e/e3e9faf2-f28b-490a-9ada-c6089a1fc5b0/Product%20names%20and%20service%20plan%20identifiers%20for%20licensing.csv" -Method 'GET' -ErrorAction 'Stop'

    #  Convert the content from a byte array to a string, assuming it's UTF8 encoded
    $Utf8NoBom = New-Object 'System.Text.UTF8Encoding' $false
    [string]$TranslationTable = $Utf8NoBom.GetString($Response.Content) | ConvertFrom-Csv
}
Catch {
    $Output = "Could not get the translation table!"
    Write-Log -Message $Output -Severity 3
    Write-Verbose -Message $Output -Verbose
}

## Get each license information with the SkuID and check if it is lower then the specific value in $minAmount
Foreach ($SkuID in $SkuIDs) {

    ## Write verbose message
    Write-Verbose = "Checking license: {0}" -f $SkuID

    ## Calculate Token Expiry time
    $TokenExpiryTime = $AccessToken.granted_on.ToUniversalTime().AddSeconds($AccessToken.expires_in)

    ## If token expires in 5 minutes then generate new token
    If ($TokenExpiryTime.AddMinutes(-5) -lt [DateTime]::UtcNow) {

        ## Regenerate token
        $AccessToken = Get-MSGraphAPIAccessToken -TenantID $TenantID ClientID $ClientID ClientSecret $ClientSecret -ErrorAction 'Stop'
        $Token = $AccessToken.access_token
    }

    $SkuIdLicense = $AvailableLicenses | Where-Object { $PsItem.skuId -eq $SkuId }
    $ResolvedSkuName = ($TranslationTable | Where-Object { $PSItem.GUID -eq $SkuID_license.skuId } | Sort-Object -Property 'Product_Display_Name' -Unique).Product_Display_Name

    [int]$AvailableLicenses = $SkuIDLicense.prepaidUnits.enabled
    [int]$UsedLicenses = $SkuIDLicense.consumedUnits
    [int]$RemainingLicenses = $AvailableLicenses - $UsedLicenses

    If ($RemainingLicenses -lt $MinimumLicenseThreshold) {
        [string]$Header = "License: $ResolvedSkuName"
        Send-SlackMessage -Header $Header -AvailableLicenses $AvailableLicenses -UsedLicenses $UsedLicenses -RemainingLicenses $RemainingLicenses -SlackWebhookURI $SlackWebhookURI
        $Output = "The license: {0} is below the amount of: '{1}'. Message to slack has been send." -f $ResolvedSkuName, $MinimumLicenseThreshold
        Write-Log -Message $Output -Severity 2
    }
    Else {
        $Output = "There are {0} {1} licenses left. So it is not below: '{2}'." -f $RemainingLicenses, $ResolvedSkuName, $MinimumLicenseThreshold
        Write-Log -Message $Output -Severity 1
    }
    Write-Verbose -Message $Output -Verbose
}
#endregion ScriptBody
##*=============================================
##* END SCRIPT BODY
##*=============================================