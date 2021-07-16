#region Function Send-GHCWebhookMessage
Function Send-GHCWebhookMessage {
    [CmdletBinding()]
    Param (
        # uri
        [Parameter(Mandatory=$true)]
        [string]
        $URI,
        # Message
        [Parameter(Mandatory)]
        [hashtable]
        $Message
    )

    Begin {
    }

    Process {
        $JSON = ConvertTo-Json $Message -Depth 50
        $JSON

        Invoke-WebRequest -UseBasicParsing -Uri $URI -Method POST -Headers @{"Content-Type" = 'Application/json; charset=UTF-8'} -Body $JSON
    }

    End {
    }
}
#endregion