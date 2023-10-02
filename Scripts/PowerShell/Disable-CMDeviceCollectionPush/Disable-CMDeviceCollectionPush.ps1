<#
.SYNOPSIS
    Disables SCCM push install for a specified collection.
.DESCRIPTION
    Disables SCCM push install for a specified collection using the ExcludeServers registry key.
.PARAMETER CMSiteServer
    Specifies the NetBIOS name of the SCCM Site Server.
.PARAMETER CMCollection
    Specifies the Collection Name to exclude from Push Install.
.PARAMETER DeleteAllCollectionMembers
    Optional switch used to Delete all Collection Device Members and their discovery data using CIM (blazing fast :P).
.EXAMPLE
    Disable-CMPushDeviceCollection.ps1 -CMSiteServer 'SiteServerName' -CMCollection 'Exclude from Push Collection' -DeleteAllCollectionMembers
.INPUTS
    System.String.
.OUTPUTS
    System.String.
.NOTES
    Created by Ioan Popovici
    Requirements
        Configuration Manager
    Important
        This script can be run using SCCM status filter rules, on collection membership change.
        DeleteAllCollectionMembers switch does not remove collection queries.
.LINK
    https://MEMZ.one/Disable-CMDeviceCollectionPush
.LINK
    https://MEMZ.one/Disable-CMDeviceCollectionPush-CHANGELOG
.LINK
    https://MEMZ.one/Disable-CMDeviceCollectionPush-GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    CM
.FUNCTIONALITY
    Disable push install for a CM collection
#>

## Set script requirements
#Requires -Version 3.0

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

## Getting variables from pipeline
Param (
    [Parameter(Mandatory=$True,Position=0)]
    [Alias('CMServer')]
    [String]$CMSiteServer,
    [Parameter(Mandatory=$True,Position=1)]
    [Alias('CMCollection')]
    [String]$CMCollectionName,
    [Parameter(Mandatory=$False,Position=3)]
    [Alias('DeleteAll')]
    [Switch]$DeleteAllCollectionMembers
)

## Get script path and name
[String]$ScriptPath = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Definition)
[String]$ScriptName = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Definition)

## CSV and log files initialization
#  Set the CSV Settings and Data file name
[String]$csvDataFileName = $ScriptName
[String]$csvSettingsFileName = $ScriptName+'Settings'

#  Get CSV Settings and Data file name with extension
[String]$csvDataFileNameWithExtension = $csvDataFileName+'.csv'
[String]$csvSettingsFileNameWithExtension = $csvSettingsFileName+'.csv'

#  Assemble CSV Settings and Data file path
[String]$csvDataFilePath = (Join-Path -Path $ScriptPath -ChildPath $csvDataFileName)+'.csv'
[String]$csvSettingsFilePath = (Join-Path -Path $ScriptPath -ChildPath $csvSettingsFileName)+'.csv'

#  Assemble log file Path
[String]$LogFilePath = (Join-Path -Path $ScriptPath -ChildPath $ScriptName)+'.log'

## Setting registry connection properties
$RegProps = @{
    'Path' = 'HKLM:\Software\Microsoft\SMS\Components\SMS_DISCOVERY_DATA_MANAGER'
    'Name' = 'ExcludeServers'
    'ErrorAction'  = 'Stop'
}

## Global error result array list
[System.Collections.ArrayList]$Global:ErrorResult = @()

#endregion
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
    Writes data to log.
.DESCRIPTION
    Writes data to file log, event log and console.
.PARAMETER EventLogEntryMessage
    The event log entry message.
.PARAMETER EventLogName
    The event log to write to.
.PARAMETER FileLogName
    The file log name to write to.
.PARAMETER EventLogEntrySource
    The event log entry source.
.PARAMETER EventLogEntryID
    The event log entry ID.
.PARAMETER EventLogEntryType
    The event log entry type (Error | Warning | Information | SuccessAudit | FailureAudit).
.PARAMETER SkipEventLog
    Skip writing to event log.
.EXAMPLE
    Write-Log -EventLogEntryMessage 'Operation was successful' -EventLogName 'Configuration Manager' -EventLogEntrySource 'Script' -EventLogEntryID '1' -EventLogEntryType 'Information'
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$False,Position=0)]
        [Alias('Message')]
        [String]$EventLogEntryMessage,
        [Parameter(Mandatory=$False,Position=1)]
        [Alias('EName')]
        [String]$EventLogName = 'Configuration Manager',
        [Parameter(Mandatory=$False,Position=2)]
        [Alias('Source')]
        [String]$EventLogEntrySource = $ScriptName,
        [Parameter(Mandatory=$False,Position=3)]
        [Alias('ID')]
        [int32]$EventLogEntryID = 1,
        [Parameter(Mandatory=$False,Position=4)]
        [Alias('Type')]
        [String]$EventLogEntryType = 'Information',
        [Parameter(Mandatory=$False,Position=5)]
        [Alias('SkipEL')]
        [Switch]$SkipEventLog
    )

    ## Initialization
    #  Getting the date and time
    [String]$LogTime = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss').ToString()

    #  Archive log file if it exists and it's larger than 50 KB
    If ((Test-Path $LogFilePath) -and (Get-Item $LogFilePath).Length -gt 50KB) {
        Get-ChildItem -Path $LogFilePath | Rename-Item -NewName { $_.Name -Replace '.log','.lo_' } -Force
    }

    #  Create event log and event source if they do not exist
    If (-not ([System.Diagnostics.EventLog]::Exists($EventLogName)) -or (-not ([System.Diagnostics.EventLog]::SourceExists($EventLogEntrySource)))) {

        #  Create new event log and/or source
        New-EventLog -LogName $EventLogName -Source $EventLogEntrySource
    }

    ## Error logging
    If ($_.Exception) {

        #  Write to log
        Write-EventLog -LogName $EventLogName -Source $EventLogEntrySource -EventId $EventLogEntryID -EntryType 'Error' -Message "$EventLogEntryMessage `n$_"

        #  Write to console
        Write-Host `n$EventLogEntryMessage -BackgroundColor 'Red' -ForegroundColor 'White'
        Write-Host $_.Exception -BackgroundColor 'Red' -ForegroundColor 'White'

        #  Assemble log file line
        [String]$LogLine = "$LogTime : $_.Exception"

        #  Write to log file
        $LogLine | Out-File -FilePath $LogFilePath -Append -NoClobber -Force -Encoding 'UTF8' -ErrorAction 'Continue'

        #  Add to error result array
        $Global:ErrorResult.Add($LogLine)

        #  Breaking Cycle so we don't get stuck in a loop :)
        Break
    }
    Else {

        #  Skip event log if requested
        If ($SkipEventLog) {

            #  Write to console
            Write-Host $EventLogEntryMessage -BackgroundColor 'White' -ForegroundColor 'Blue'
        }
        Else {

            #  Write to event log
            Write-EventLog -LogName $EventLogName -Source $EventLogEntrySource -EventId $EventLogEntryID -EntryType $EventLogEntryType -Message $EventLogEntryMessage

            #  Write to console
            Write-Host $EventLogEntryMessage -BackgroundColor 'White' -ForegroundColor 'Blue'
        }
    }

    ##  Assemble log file line
    [String]$LogLine = "$LogTime : $EventLogEntryMessage"

    ## Write to log file
    $LogLine | Out-File -FilePath $LogFilePath -Append -NoClobber -Force -Encoding 'UTF8' -ErrorAction 'Continue'
}
#endregion

#region  Function Send-Mail
Function Send-Mail {
<#
.SYNOPSIS
    Send E-Mail to specified address.
.DESCRIPTION
    Send E-Mail body to specified address.
.PARAMETER From
    Source.
.PARAMETER To
    Destination.
.PARAMETER CC
    Carbon copy.
.PARAMETER Body
    E-Mail body.
.PARAMETER Attachments
    E-Mail Attachments.
.PARAMETER SMTPServer
    E-Mail SMTPServer.
.PARAMETER SMTPPort
    E-Mail SMTPPort.
.EXAMPLE
    Send-Mail -From 'test@test.com' -To "test@test.com" -Subject "test" -Body 'Test' -CC 'test@test.com' -Attachments 'C:\Temp\test.log'
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$True,Position=0)]
        [String]$From,
        [Parameter(Mandatory=$True,Position=1)]
        [String]$To,
        [Parameter(Mandatory=$False,Position=2)]
        [String]$CC,
        [Parameter(Mandatory=$True,Position=3)]
        [String]$Subject,
        [Parameter(Mandatory=$True,Position=4)]
        [String]$Body,
        [Parameter(Mandatory=$False,Position=5)]
        $Attachments = $LogFilePath,
        [Parameter(Mandatory=$True,Position=6)]
        [String]$SMTPServer,
        [Parameter(Mandatory=$True,Position=7)]
        [String]$SMTPPort
    )

    ## Send mail with error handling
    Try {

        #  With CC
        If ($CC -ne [String]::Empty -and $CC -ne 'NO') {
            Send-MailMessage -From $From -To $To -Subject $Subject -CC $CC -Body $Body -Attachments $Attachments -SmtpServer $SMTPServer -Port $SMTPPort -ErrorAction 'Stop'
        }

        #  Without CC
        ElseIf ($CC -eq [String]::Empty -or $CC -eq 'NO') {
            Send-MailMessage -From $From -To $To -Subject $Subject -Body $Body -Attachments $Attachments -SmtpServer $SMTPServer -Port $SMTPPort -ErrorAction 'Stop'
        }
    }
    Catch {
        Write-Log -Message 'Send Mail - Failed!'
    }
}
#endregion

#region Function Get-SMSProviderLocation
Function Get-SMSProviderLocation {
<#
.SYNOPSIS
    Used to get SMS Provider Location.
.DESCRIPTION
    Used to get SMS Provider Location from WMI using CIM.
.PARAMETER SiteServer
    Set the Site Server name for which to the SMS Provider Location.
.EXAMPLE
    Get-SMSProviderLocation -SiteServer 'ComputerName'
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$True,Position=0)]
        [Alias('CMServer')]
        [String]$SiteServer
    )

    ## Get SMS provider location
    Try {
        $SMSProvider = Get-CimInstance -Query 'Select * From SMS_ProviderLocation Where ProviderForLocalSite = True' -Namespace 'ROOT\SMS' -ComputerName $SiteServer -ErrorAction 'Stop'
    }
    #  Write to log in case of failure
    Catch {
        Write-Log -Message "Getting SMS Provider Location - Failed!"
    }

    ## Setting Cim connection properties, getting namespace using regex
    $CimProps = @{
        'ComputerName' = $SMSProvider.Machine
        'Namespace'    = ($SMSProvider.NamespacePath | Select-String -Pattern 'root\\\S+').Matches.Value
        'ErrorAction'  = 'Stop'
    }

    ## Returning Cim props
    Return $CimProps
}
#endregion

#region Function Get-CimCollectionMembers
Function Get-CimCollectionMembers {
<#
.SYNOPSIS
    Get device collection members.
.DESCRIPTION
    Get device collection members NetBIOS name.
.PARAMETER CollectionName
    Set the collection name for which to get device collection members.
.EXAMPLE
    Get-CimCollectionMembers -CollectionName 'Computer Collection'
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$True,Position=0)]
        [Alias('Collection')]
        [String]$CollectionName
    )

    ## Get SMS provider location
    $CimProps = Get-SMSProviderLocation -SiteServer $CMSiteServer

    ## Getting collection class name
    Try {
        $CollectionClassName = (Get-CimInstance -ClassName SMS_Collection -Filter "Name=`"$CollectionName`"" @CimProps).MemberClassName
    }
    #  Write to log in case of failure
    Catch {
        Write-Log -Message "Getting CollectionClassName for $CollectionName - Failed!"
    }

    ## Getting servers from collection and sort them by name
    Try {
        $DeviceCollectionMembers = (Get-CimInstance -Query "Select Name From $CollectionClassName" @CimProps).Name | Sort-Object 'Name'
    }

    #  Write to log in case of failure
    Catch {
        Write-Log -Message "Getting Device Collection Members from $CollectionName - Failed!"
    }

    ## Return device collection members
    Return $DeviceCollectionMembers
}
#endregion

#region Function Remove-CimCollectionMembers
Function Remove-CimCollectionMembers {
<#
.SYNOPSIS
    Delete all device collection members.
.DESCRIPTION
    Delete all device members of a specific collection and their discovery data from SCCM.
.PARAMETER CollectionName
    Set the collection name for which to delete all device collection members.
.EXAMPLE
    Remove-CimCollectionMembers  -Collection 'Computer Collection'
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$True,Position=0)]
        [Alias('Collection')]
        [String]$CollectionName
    )

    ## Get SMS provider location
    $CimProps = Get-SMSProviderLocation -SiteServer $CMSiteServer

    ## Deleting all devices and their discovery data from a collection
    Try {
        Get-CimInstance -ClassName SMS_Collection -Filter "Name=`"$CollectionName`"" @CimProps | Invoke-CimMethod -MethodName 'DeleteAllMembers'
        Write-Log "Deleting all Device Members from $CollectionName - Successful!"
    }

    #  Write to log in case of failure
    Catch {
        Write-Log -Message "Deleting all Devices from $CollectionName - Failed!"
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

## Import the Settings CSV file
Try {
    $csvSettingsData = Import-Csv -Path $csvSettingsFilePath -Encoding 'UTF8' -ErrorAction 'Stop'
}
Catch {

    #  Write to log in case of failure
    Write-Log -Message 'Importing Settings CSV Data - Failed!'
}

## Making sure we send report
Try {

    ## Getting devices from registry
    Try {
        $DevicesRegistry = (Get-ItemProperty @RegProps).ExcludeServers
    }

    #  Write to log in case of failure
    Catch {
        Write-Log -Message "Getting Devices from Registry - Failed!"
    }

    ## Getting devices from collection
    $DevicesCollection = Get-CimCollectionMembers -CollectionName $CMCollectionName

    ## If collection is not empty start comparison
    If ($DevicesCollection) {

        #  Check if there are devices in collection but not in registry
        $DeviceDifference = (Compare-Object -ReferenceObject $DevicesRegistry -DifferenceObject $DevicesCollection | Where-Object { $_.SideIndicator -eq '=>' } | Sort-Object InputObject).InputObject

        #  If there are differences between registry and collection write the merged list to registry
        If ($DeviceDifference) {

            #  Merging servers from registry and collection, eliminate duplicates
                $DevicesMerged = (Compare-Object -ReferenceObject $DevicesRegistry -DifferenceObject $DevicesCollection -IncludeEqual | Sort-Object InputObject –Unique).InputObject

            #  Write merged list to registry
            Try {
                Set-ItemProperty -Value $DevicesMerged @RegProps
            }

            #  Write to log in case of failure
            Catch {
                Write-Log -Message 'Write Merged Device List to Registry - Failed!'
            }

            #  Write merged list to csv and log
            Try {
                $DevicesMerged | ConvertFrom-Csv -Header 'Devices Excluded from Push Install' | Export-Csv -Path $csvDataFilePath -Delimiter ',' -Encoding 'UTF8' -NoTypeInformation -Force

                #  Initialize result array
                [Array]$Result = @()

                #  Adding differences device list result header
                $Result+= "`nListing New Devices to be Added:`n"

                #  Parsing differences device list and add formatting
                $DeviceDifference | ForEach-Object { $Result+= " "+$_ }

                #  Adding merged device list result header
                $Result+= "`nListing All Devices Excluded from Push Install:`n"

                #  Parsing merged device list and add formatting
                $DevicesMerged | ForEach-Object { $Result+= " "+$_ }

                #  Convert the result to string and write it to log
                [String]$ResultString = Out-String -InputObject $Result
                Write-Log -Message $ResultString
            }

            #  Write to log in case of failure
            Catch {
                Write-Log -Message "Write Merged Device List to $csvDataFilePath - Failed!"
            }

            #  Remove all collection member devices from SCCM (optional switch)
            If ($DeleteAllCollectionMembers) { Remove-CimCollectionMembers -CollectionName $CMCollectionName }
        }

        #  Write to log
        Else { Write-Log 'Devices already Excluded!' }
    }
}
Catch {

## Not needed, empty
}
Finally {
    ## Send Mail Report if needed
    If ($csvSettingsData.SendMail -eq 'YES' -and -not $Global:ErrorResult -and $DeviceDifference) {

        #  Write to log
        Write-Log -Message 'Sending Mail Report...' -SkipEventLog

        #  Send mail, attach both log and merged device list
        Send-Mail -Subject 'Info: Exclude Devices from Push Install - Success!' -Body $ResultString -From $csvSettingsData.From -To $csvSettingsData.To -CC $csvSettingsData.CC -SMTPServer $csvSettingsData.SMTPServer -SMTPPort $csvSettingsData.SMTPPort -Attachments @($LogFilePath,$csvDataFilePath)

    }
    If ($csvSettingsData.SendMail -eq 'YES' -and $Global:ErrorResult) {

        #  Write to log in case of failure
        Write-Log 'CSV Data Processing - Failed!'

        #  Write to log
        Write-Log -Message "Sending Error Mail Report..."

        #  Send mail, attach only log
        Send-Mail -Subject 'Warning: Exclude Devices from Push Install - Failed!' -Body "Errors: `n $Global:ErrorResult"  -From $csvSettingsData.From -To $csvSettingsData.To -CC $csvSettingsData.CC -SMTPServer $csvSettingsData.SMTPServer -SMTPPort $csvSettingsData.SMTPPort
    }
}

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================
