<#
.SYNOPSIS
    Exports SCCM status message localization strings from dlls.
.DESCRIPTION
    Exports SCCM status message localization strings from specified dlls and saves them to a csv file.
.PARAMETER DllList
    Specifies the dlls to be processed.
    Valid dll names are: 'srvmsgs.dll','provmsgs.dll' and 'climsgs.dll'.
    Default is:  @('srvmsgs.dll','provmsgs.dll','climsgs.dll').
.PARAMETER DllPath
    Specifies the dll path to search. Default is: $Env:SMS_ADMIN_UI_PATH
.PARAMETER ExportPath
    Specifies the csv export path. Default is: 'Script Run Location'
.EXAMPLE
    [String[]]$DllList =  @('srvmsgs.dll','provmsgs.dll','climsgs.dll')
    Export-CMStatusMessageStrings -DllList $DllList -DllPath 'SomePath' -ExportPath 'SomeExportPath'
.INPUTS
    System.Array.
    System.String.
.OUTPUTS
    System.String. This script outputs to a csv file
.NOTES
    Created by
        Ioan Popovici
    Credit to SaudM, Vadims Podāns
.LINK
    https://gallery.technet.microsoft.com/scriptcenter/Enumerate-status-message-6e7e1761
.LINK
    https://www.sysadmins.lv/blog-en/retrieve-text-messages-for-win32-errors.aspx
.LINK
    https://msdn.microsoft.com/en-us/library/windows/desktop/ms679351
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    CM
.FUNCTIONALITY
    Export CM status messages
#>

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

## Get script parameters
Param (
    [Parameter(Mandatory=$false,HelpMessage="Valid options are: 'srvmsgs','provmsgs' and 'climsgs'",Position=0)]
    [ValidateNotNullorEmpty()]
    [ValidateSet('srvmsgs','provmsgs','climsgs')]
    [string[]]$DllList = @('srvmsgs.dll','provmsgs.dll','climsgs.dll'),
    [Parameter(Mandatory=$false,Position=1)]
    [ValidateNotNullorEmpty()]
    [string]$DllPath = $Env:SMS_ADMIN_UI_PATH,
    [Parameter(Mandatory=$false,Position=2)]
    [ValidateNotNullorEmpty()]
    [string]$ExportPath
)

## Get script path and name
[string]$ScriptPath = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Definition)
[string]$ScriptName = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Definition)

## Set export path if $null
If (-not $ExportPath) { $ExportPath = $ScriptPath }

#endregion
##*=============================================
##* END VARIABLE DECLARATION
##*=============================================

##*=============================================
##* FUNCTION LISTINGS
##*=============================================
#region FunctionListings

#region Function Get-Message
Function Get-Message {
<#
.SYNOPSIS
    Reads a message string.
.DESCRIPTION
    Reads a message string. The function requires a message definition as input. The message definition can come from a buffer passed into the function.
    It can come from a message table resource in an already-loaded module. Or the caller can ask the function to search the system's message table resource(s)
    for the message definition. The function finds the message definition in a message table resource based on a message identifier and a language identifier.
    The function copies the formatted message text to an output buffer, processing any embedded insert sequences if requested.
.PARAMETER Flags
    The formatting options, and how to interpret the Source parameter. The low-order byte of Flags specifies how the function handles line breaks in the output buffer.
    The low-order byte can also specify the maximum width of a formatted output line.

    This parameter can be one or more of the following values.
        0x00000100 = FORMAT_MESSAGE_ALLOCATE_BUFFER
        0x00002000 = FORMAT_MESSAGE_ARGUMENT_ARRAY
        0x00000800 = FORMAT_MESSAGE_FROM_HMODULE
        0x00000400 = FORMAT_MESSAGE_FROM_STRING
        0x00001000 = FORMAT_MESSAGE_FROM_SYSTEM
        0x00000200 = FORMAT_MESSAGE_IGNORE_INSERTS

    The low-order byte of Flags can specify the maximum width of a formatted output line. The following are possible values of the low-order byte.
        0          = There are no output line width restrictions. The function stores line breaks that are in the message definition text into the output buffer.
        0x000000FF = FORMAT_MESSAGE_MAX_WIDTH_MASK
    Default is: 0x00000800 -bor 0x00000200.
.PARAMETER Source
    The location of the message definition. The type of this parameter depends upon the settings in the Flags parameter.

    0x00000800 = FORMAT_MESSAGE_FROM_HMODULE
    0x00000400 = FORMAT_MESSAGE_FROM_STRING
.PARAMETER MessageID
    The message identifier for the requested message. This parameter is ignored if Flags includes FORMAT_MESSAGE_FROM_STRING.
    Default is: 0.
.PARAMETER LanguageID
    The language identifier for the requested message. This parameter is ignored if Flags includes FORMAT_MESSAGE_FROM_STRING.
.PARAMETER BufferSize
    If the FORMAT_MESSAGE_ALLOCATE_BUFFER flag is not set, this parameter specifies the size of the output buffer, in TCHARs.
    If FORMAT_MESSAGE_ALLOCATE_BUFFER is set, this parameter specifies the minimum number of TCHARs to allocate for an output buffer.
    Default is: 16384.
.PARAMETER Arguments
    An array of values that are used as insert values in the formatted message. A %1 in the format string indicates the first value in
    the Arguments array; a %2 indicates the second argument; and so on.

    The interpretation of each value depends on the formatting information associated with the insert in the message definition.
    The default is to treat each value as a pointer to a null-terminated string.
    Default is: { "%1", "%2", "%3", "%4", "%5", "%6", "%7", "%8", "%9" }
.PARAMETER CleanString
    This switch is used to clean the output string of ('%11', '%12', '%3%4%5%6%7%8%9%10',' .', CR, LF or TAB)
    Default is: $false.
.EXAMPLE
    $Arguments = { "%1", "%2", "%3", "%4", "%5", "%6", "%7", "%8", "%9" }
    Get-Message -Flags $(0x00000800 -bor 0x00000200) -Source $SomeHandle -MessageID 1073741824 -BufferSize 16384 -Arguments $Arguments -CleanString
.INPUTS
    System.Int.
    System.IntPtr.
    System.Array.
.OUTPUTS
    System.String.
.NOTES
    This is an internal module function and should not typically be called directly.
    Credit to SaudM, Vadims Podāns
.LINK
    https://gallery.technet.microsoft.com/scriptcenter/Enumerate-status-message-6e7e1761
.LINK
    https://www.sysadmins.lv/blog-en/retrieve-text-messages-for-win32-errors.aspx
.LINK
    https://msdn.microsoft.com/en-us/library/windows/desktop/ms679351
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    Message Tables
.FUNCTIONALITY
    Read and Format Messages
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$false,Position=0)]
        [ValidateNotNullorEmpty()]
        [int]$Flags = 0x00000800 -bor 0x00000200,
        [Parameter(Mandatory=$true,Position=1)]
        [ValidateNotNullorEmpty()]
        [System.IntPtr]$Source,
        [Parameter(Mandatory=$false,Position=2)]
        [ValidateNotNullorEmpty()]
        [long]$MessageID,
        [Parameter(Mandatory=$false,Position=3)]
        [ValidateNotNullorEmpty()]
        [int]$LanguageID = 0,
        [Parameter(Mandatory=$false,Position=4)]
        [ValidateNotNullorEmpty()]
        [int]$BufferSize = 16384,
        [Parameter(Mandatory=$false,Position=5)]
        [ValidateNotNullorEmpty()]
        [string[]]$Arguments = { "%1", "%2", "%3", "%4", "%5", "%6", "%7", "%8", "%9" },
        [Parameter(Mandatory=$false,Position=6)]
        [ValidateNotNullorEmpty()]
        [switch]$CleanString = $false
    )
    Begin {

        ## Variable declaration
        #  Ceate output buffer
        [System.Text.StringBuilder]$OutputBuffer = $BufferSize
        #  Set regex pattern for string cleanup (matches: '%11', '%12', '%3%4%5%6%7%8%9%10',' .', CR, LF or TAB)
        [regex]$RegExPattern = '\%([1-9][1-2])|(\%\d){7}\%10|\t|\n|\r| \.'
    }
    Process {
        Try {

            ## Read message
            $ReadMessage = $Win32FormatMessage::FormatMessage($Flags, $Source, $MessageID, $LanguageID, $OutputBuffer, $BufferSize, $Arguments)

            ## Check if succesfull
            If ($ReadMessage -le 0) {
                Throw 'Error during read operation'
            }
        }
        Catch {
            Write-Error -Message "Could not get message. `n $PSItem" -Category 'NotSpecified'
        }
        Finally {

            ## Clean message string if specified
            If ($CleanString) {
                [string]$MessageString = $OutputBuffer.ToString() -Replace ($RegExPattern, '')
            }
            Else {
                [string]$MessageString = $OutputBuffer.ToString()
            }

            ## Return string to pipeline
            Write-Output -InputObject $MessageString
        }
    }
    End {

        ## Clearing memory, most probably not needed
        Remove-Variable -Name 'Flags', 'Source', 'MessageID', 'LanguageID', 'BufferSize', 'OutputBuffer', 'Arguments'
    }
}
#endregion

#region Function Get-Messages
Function Get-Messages {
<#
.SYNOPSIS
    Reads all message strings.
.DESCRIPTION
    Reads all message strings. The function requires a message definition as input. The message definition can come from a buffer passed into the function.
    It can come from a message table resource in an already-loaded module. Or the caller can ask the function to search the system's message table resource(s)
    for the message definition. The function finds the message definition in a message table resource based on a message identifier and a language identifier.
    The function copies the formatted message text to an output buffer, processing any embedded insert sequences if requested.
.PARAMETER Flags
    The formatting options, and how to interpret the Source parameter. The low-order byte of Flags specifies how the function handles line breaks in the output buffer.
    The low-order byte can also specify the maximum width of a formatted output line.

    This parameter can be one or more of the following values.
        0x00000100 = FORMAT_MESSAGE_ALLOCATE_BUFFER
        0x00002000 = FORMAT_MESSAGE_ARGUMENT_ARRAY
        0x00000800 = FORMAT_MESSAGE_FROM_HMODULE
        0x00000400 = FORMAT_MESSAGE_FROM_STRING
        0x00001000 = FORMAT_MESSAGE_FROM_SYSTEM
        0x00000200 = FORMAT_MESSAGE_IGNORE_INSERTS

    The low-order byte of Flags can specify the maximum width of a formatted output line. The following are possible values of the low-order byte.
        0          = There are no output line width restrictions. The function stores line breaks that are in the message definition text into the output buffer.
        0x000000FF = FORMAT_MESSAGE_MAX_WIDTH_MASK
    Default is: 0x00000800 -bor 0x00000200.
.PARAMETER Source
    The location of the message definition. The type of this parameter depends upon the settings in the Flags parameter.

    0x00000800 = FORMAT_MESSAGE_FROM_HMODULE
    0x00000400 = FORMAT_MESSAGE_FROM_STRING
.PARAMETER MessageIDBase
    The base message identifier position for the requested messages. This parameter is ignored if Flags includes FORMAT_MESSAGE_FROM_STRING.
    Default is: 0.
.PARAMETER MessageIDTotal
    Specifies the number of incremental searches to perform before giving up. Since not all MessageIDs are used this number represents the total MessageIDs to query.
    Default is: 99999.
.PARAMETER Severity
    Specifies the severity of the message. This is used for output only and must be user specified.
.PARAMETER LanguageID
    The language identifier for the requested message. This parameter is ignored if Flags includes FORMAT_MESSAGE_FROM_STRING.
.PARAMETER BufferSize
    If the FORMAT_MESSAGE_ALLOCATE_BUFFER flag is not set, this parameter specifies the size of the output buffer, in TCHARs.
    If FORMAT_MESSAGE_ALLOCATE_BUFFER is set, this parameter specifies the minimum number of TCHARs to allocate for an output buffer.
    Default is: 16384.
.PARAMETER Arguments
    An array of values that are used as insert values in the formatted message. A %1 in the format string indicates the first value in
    the Arguments array; a %2 indicates the second argument; and so on.

    The interpretation of each value depends on the formatting information associated with the insert in the message definition.
    The default is to treat each value as a pointer to a null-terminated string.
    Default is: { "%1", "%2", "%3", "%4", "%5", "%6", "%7", "%8", "%9" }
.PARAMETER SourceLabel
    Source label indicator for messages being searched.
    Default is: 'Unknown'.
.PARAMETER CleanString
    This switch is used to clean the output string of ('%11', '%12', '%3%4%5%6%7%8%9%10',' .', CR, LF or TAB)
    Default is: $false.
.EXAMPLE
    $Arguments = { "%1", "%2", "%3", "%4", "%5", "%6", "%7", "%8", "%9" }
    Get-Message -Flags $(0x00000800 -bor 0x00000200) -Source $SomeHandle -MessageIDBase 1073741824 -MessageIDTotal 99999 -Severity 'Infomational' -BufferSize 16384 -SourceLabel 'SomePath\some.dll' -Arguments $Arguments -CleanString
.INPUTS
    System.Int.
    System.IntPtr.
    System.Array.
.OUTPUTS
    System.Array.
.NOTES
    This function can typically be called directly.
    Credit to SaudM, Vadims Podāns
.LINK
    https://gallery.technet.microsoft.com/scriptcenter/Enumerate-status-message-6e7e1761
.LINK
    https://www.sysadmins.lv/blog-en/retrieve-text-messages-for-win32-errors.aspx
.LINK
    https://msdn.microsoft.com/en-us/library/windows/desktop/ms679351
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    Message Tables
.FUNCTIONALITY
    Read and Format Messages
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$false,Position=0)]
        [ValidateNotNullorEmpty()]
        [int]$Flags = 0x00000800 -bor 0x00000200,
        [Parameter(Mandatory=$true,Position=1)]
        [ValidateNotNullorEmpty()]
        [System.IntPtr]$Source,
        [Parameter(Mandatory=$true,Position=2)]
        [ValidateNotNullorEmpty()]
        [long]$MessageIDBase,
        [Parameter(Mandatory=$false,Position=3)]
        [ValidateNotNullorEmpty()]
        [int]$MessageIDTotal = 99999,
        [Parameter(Mandatory=$true,Position=4)]
        [ValidateNotNullorEmpty()]
        [string]$Severity,
        [Parameter(Mandatory=$false,Position=5)]
        [ValidateNotNullorEmpty()]
        [int]$LanguageID = 0,
        [Parameter(Mandatory=$false,Position=6)]
        [ValidateNotNullorEmpty()]
        [int]$BufferSize = 16384,
        [Parameter(Mandatory=$true,Position=7)]
        [ValidateNotNullorEmpty()]
        [string]$SourceLabel = 'Unknown',
        [Parameter(Mandatory=$false,Position=8)]
        [ValidateNotNullorEmpty()]
        [string[]]$Arguments = { "%1", "%2", "%3", "%4", "%5", "%6", "%7", "%8", "%9" },
        [Parameter(Mandatory=$false,Position=9)]
        [ValidateNotNullorEmpty()]
        [switch]$CleanString = $false
    )
    Begin {

        ## Variable declaration
        [int]$Iteration = 99999
        [PSCustomObject]$MessageObject = @()
        #  Ceate output buffer
        [System.Text.StringBuilder]$OutputBuffer = $BufferSize
        #  Set regex pattern for string cleanup (matches: '%11', '%12', '%3%4%5%6%7%8%9%10',' .', CR, LF or TAB)
        [regex]$RegExPattern = '\%([1-9][1-2])|(\%\d){7}\%10|\t|\n|\r| \.'
    }
    Process {
        Try {

            ## Search for messages
            For ($MessageID = 1; $MessageID -le $MessageIDTotal; $MessageID++) {

                #  Shift MessageID position
                $MessageIDBitShift = $MessageIDBase -bor $MessageID

                #  Read messages
                $ReadMessage = $Win32FormatMessage::FormatMessage($Flags, $Source, $MessageIDBitShift, $LanguageID, $OutputBuffer, $BufferSize, $Arguments)

                #  Check if message was found
                If ($ReadMessage -gt 0) {

                    #  Write progress only when a message is found for performance reasons
                    $PercentComplete = ($MessageID / $MessageIDTotal * 100)
                    Write-Progress -Activity "Exporting $Severity Messages from $SourceLabel" -Status 'Please wait.' -PercentComplete $PercentComplete

                    ## Clean message string if specified
                    If ($CleanString) {
                        [string]$MessageString = $OutputBuffer.ToString() -Replace ($RegExPattern, '')
                    }
                    Else {
                        [string]$MessageString = $OutputBuffer.ToString()
                    }

                    #  Assemble message string props
                    [hashtable]$MessageProps = [ordered]@{
                        MessageID = $MessageID
                        MessageString = $MessageString
                        Severity = $Severity
                    }
                    #  Add MessageProps to result
                    $MessageObject += [PSCustomObject]$MessageProps
                }
            }
        }
        Catch {
            Write-Error -Message "Could not get $Severity Messages from $SourceLabel. `n $PSItem" -Category 'NotSpecified'
        }
        Finally {

            ## Return string object to pipeline
            Write-Output -InputObject $MessageObject
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

Try {

    ## If SCCM console is not installed throw an error
    If (-not $DllPath) {
        Throw 'SCCM Console is not installed.'
    }

    ## Call native windows APIs. No space is allowed in the call hence the different formating
    $SignatureFormatMessage = @'
        [DllImport("kernel32.dll")]
        public static extern uint FormatMessage(uint Flags, IntPtr source, uint messageId, uint langId, StringBuilder buffer, uint size, string[] arguments);
'@
    $SignatureGetModuleHandle = @'
        [DllImport("kernel32.dll")]
        public static extern IntPtr GetModuleHandle(string lpModuleName);
'@
    $SignatureLoadLibrary = @'
        [DllImport("kernel32.dll")]
        public static extern IntPtr LoadLibrary(string lpFileName);
'@

    ## Add methods
    $Win32FormatMessage = Add-Type -MemberDefinition $SignatureFormatMessage -Name 'Win32FormatMessage' -Namespace 'Win32Functions' -PassThru -Using 'System.Text'
    $Win32GetModuleHandle = Add-Type -MemberDefinition $SignatureGetModuleHandle -Name 'Win32GetModuleHandle' -Namespace 'Win32Functions' -PassThru -Using 'System.Text'
    $Win32LoadLibrary = Add-Type -MemberDefinition $SignatureLoadLibrary -Name 'Win32LoadLibrary' -Namespace 'Win32Functions' -PassThru -Using 'System.Text'


    ## Process dlls
    ForEach($Dll in $DllList) {

        ## Initialize result message object
        [PSCustomObject]$MessageObject = @()

        #  Get dll path
        [string]$DllPathResolved = (Get-ChildItem -Path $DllPath -Recurse | Where-Object { $PSItem.PSIsContainer -eq $false -and $PSItem.Name -match $Dll }).FullName

        If (-not $DllPathResolved) {
            Write-Error -Message "Path not found for $Dll." -Category 'ObjectNotFound' -ErrorAction 'Continue'
        }
        Else {

            #  Load status message lookup Dll and get memory handle
            $null = $Win32LoadLibrary::LoadLibrary($DllPathResolved)
            $ModuleHandle = $Win32GetModuleHandle::GetModuleHandle($DllPathResolved)
        }

        #  Get informational status messages
        $MessageObject = Get-Messages -Source $ModuleHandle -MessageIDBase 1073741824 -Severity 'Informational' -SourceLabel $DllPathResolved -CleanString

        #  Get warning status messages
        $MessageObject += Get-Messages -Source $ModuleHandle -MessageIDBase 2147483648 -Severity 'Warning' -SourceLabel $DllPathResolved -CleanString

        #  Get error status messages
        $MessageObject += Get-Messages -Source $ModuleHandle -MessageIDBase 3221225472 -Severity 'Error' -SourceLabel $DllPathResolved -CleanString

        ## Export to CSV
        Try {

            #  Set file path and filename
            [string]$FileName = $Dll -replace ('.dll','.csv')
            [string]$FilePath = Join-Path -Path $ExportPath -ChildPath $FileName

            #  Export to csv
            $MessageObject | Select-Object 'MessageID', 'MessageString', 'Severity' | Export-CSV -Path $FilePath -Encoding 'UTF8' -NoTypeInformation -Force

        }
        Catch {
            Write-Error -Message "Failed to export to csv file [$FilePath].`n$PSItem" -Category 'NotSpecified'
        }
    }
}
Catch {
    Write-Error -Message "Could not get status messages from dll [$DllPath]. `n$PSItem" -Category 'NotSpecified' -ErrorAction 'Stop'
}
Finally {

    ## Return result
    Write-Host 'Processing finished.' -BackgroundColor 'Black' -ForegroundColor 'Yellow'
}
#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================