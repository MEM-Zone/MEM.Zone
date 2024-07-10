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

        ## Get the name of this function and write verbose header
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

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
            $Response = Invoke-RestMethod -Method 'POST' -Uri $Uri -ContentType 'application/x-www-form-urlencoded' -Body $Body -UseBasicParsing

            ## Assemble output object
            $Output = [pscustomobject]@{
                access_token = $Response.access_token
                expires_in   = $Response.expires_in
                granted_on   = $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
            }
        }
        Catch {
            [string]$Message = "Error getting MSGraph API Access Token for TenantID '{0}' with ClientID '{1}'.`n{2}" -f $TenantID, $ClientID, $PSItem.Exception.Message
            Write-Error -Message $Message
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

        ## Get the name of this function and write verbose header
        [string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

        ## Assemble the URI for the API call
        [string]$Uri = -join ("https://graph.microsoft.com/", $Version, "/", $Resource)
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
            [string]$Message = "Error invoking MSGraph API version '{0}' for resource '{1}' using '{2}' method.`n{3}" -f $Version, $Resource, $Method, $PSItem.Exception.Message
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
#endregion