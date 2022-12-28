#region New-GHCTextMessage
Function New-GHCTextMessage {
    [CmdletBinding()]
    Param (
        # Text Message
        [Parameter(Mandatory)]
        [string]
        $Message
    )

    Begin {
    }

    Process {
        $TextMessage = @{'text' = $message}
        $TextMessage
    }

    End {
    }
}
#endregion