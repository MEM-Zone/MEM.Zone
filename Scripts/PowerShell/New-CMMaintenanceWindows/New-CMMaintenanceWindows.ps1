<#
.SYNOPSIS
    Creates maintenance windows on SCCM collections.
.DESCRIPTION
    Creates maintenance windows on SCCM collections based on patch tuesday.
.EXAMPLE
    New-MaintenanceWindows.ps1
.NOTES
    Written in collaboration with my good friend Octavian Cordos.
.INPUTS
    System.String.
.OUTPUTS
    System.String.
.NOTES
    Created by Ioan Popovici and Octavian Cordos.
.LINK
    https://MEM.Zone/New-CMMaintenanceWindows
.LINK
    https://MEM.Zone/New-CMMaintenanceWindows-CHANGELOG
.LINK
    https://MEM.Zone/New-CMMaintenanceWindows-GIT
.LINK
    https://MEM.Zone/Issues
.COMPONENT
    CM
.FUNCTIONALITY
    Create new CM maintenance window
#>

##*=============================================
##* INITIALIZATION
##*=============================================
#region Initialization

## Get script path and name
[string]$ScriptPath = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Definition)
[string]$ScriptName = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Definition)

## CSV and log file initialization
#  Set the CSV file name
[string]$csvFileName = $ScriptName

#  Get CSV file name with extension
[string]$csvFileNameWithExtension = Join-Path -Path $ScriptName -ChildPath '.csv'

#  Assemble CSV and log file path
[string]$csvFilePath = Join-Path -Path $ScriptPath -ChildPath $csvFileName -AdditionalChildPath '.csv'
[string]$LogFilePath = Join-Path -Path $ScriptPath -ChildPath $ScriptName -AdditionalChildPath '.log'

#endregion
##*=============================================
##* END INITIALIZATION
##*=============================================

##*=============================================
##* FUNCTION LISTINGS
##*=============================================
#region FunctionListings

#region Function Write-Log
Function Write-Log {
<#
.SYNOPSIS
    Writes data to file log, event log and console.
.DESCRIPTION
    Writes data to file log, event log and console.
.PARAMETER EventLogEntryMessage
    The event log entry message.
.PARAMETER EventLogName
    The event log to write to.
.PARAMETER FileLogName
    The file log name to write to.
.PARAMETER EventLogEntrySource
    The event log entry source
.PARAMETER EventLogEntryID
    The event log entry ID.
.PARAMETER EventLogEntryType
    The event log entry type (Error | Warning | Information | SuccessAudit | FailureAudit).
.PARAMETER SkipEventLog
    Skip writing to event log.
.EXAMPLE
    Write-Log -EventLogEntryMessage 'Set-ClientMW was successful' -EventLogName 'Configuration Manager' -EventLogEntrySource 'Script' -EventLogEntryID '1' -EventLogEntryType 'Information'
.NOTES
    This is an internal script function and should typically not be called directly.
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/Git
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$false,Position=0)]
        [Alias('Message')]
        [string]$EventLogEntryMessage,
        [Parameter(Mandatory=$false,Position=1)]
        [Alias('EName')]
        [string]$EventLogName = 'Configuration Manager',
        [Parameter(Mandatory=$false,Position=2)]
        [Alias('Source')]
        [string]$EventLogEntrySource = $ScriptName,
        [Parameter(Mandatory=$false,Position=3)]
        [Alias('ID')]
        [int32]$EventLogEntryID = 1,
        [Parameter(Mandatory=$false,Position=4)]
        [Alias('Type')]
        [string]$EventLogEntryType = 'Information',
        [Parameter(Mandatory=$false,Position=5)]
        [Alias('SkipEL')]
        [switch]$SkipEventLog
    )

    ## Initialization
    #  Getting the date and time
    [string]$LogTime = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss').ToString()

    #  Archive log file if it exists and it's larger than 50 KB
    If ((Test-Path $LogFilePath) -and (Get-Item $LogFilePath).Length -gt 50KB) {
        Get-ChildItem -Path $LogFilePath | Rename-Item -NewName { $PSItem.Name -Replace '.log','.lo_' } -Force
    }

    #  Create event log and event source if they do not exist
    If (-not ([System.Diagnostics.EventLog]::Exists($EventLogName)) -or (-not ([System.Diagnostics.EventLog]::SourceExists($EventLogEntrySource)))) {

        #  Create new event log and/or source
        New-EventLog -LogName $EventLogName -Source $EventLogEntrySource
    }

    ## Error logging
    If ($PSItem.Exception) {

        #  Write to log
        Write-EventLog -LogName $EventLogName -Source $EventLogEntrySource -EventId $EventLogEntryID -EntryType 'Error' -Message "$EventLogEntryMessage `n$PSItem"

        #  Write to console
        Write-Host `n$EventLogEntryMessage -BackgroundColor Red -ForegroundColor White
        Write-Host $PSItem.Exception -BackgroundColor Red -ForegroundColor White
    }
    Else {

        #  Skip event log if requested
        If ($SkipEventLog) {

            #  Write to console
            Write-Host $EventLogEntryMessage -BackgroundColor White -ForegroundColor Blue
        }
        Else {

            #  Write to event log
            Write-EventLog -LogName $EventLogName -Source $EventLogEntrySource -EventId $EventLogEntryID -EntryType $EventLogEntryType -Message $EventLogEntryMessage

            #  Write to console
            Write-Host $EventLogEntryMessage -BackgroundColor White -ForegroundColor Blue
        }
    }

    ##  Assemble log line
    [string]$LogLine = "$LogTime : $EventLogEntryMessage"

    ## Write to log file
    $LogLine | Out-File -FilePath $LogFilePath -Append -NoClobber -Force -Encoding 'UTF8' -ErrorAction 'Continue'
}
#endregion

#region Function Get-PatchTuesday
Function Get-PatchTuesday {
<#
.SYNOPSIS
    Get Microsoft patch Tuesday.
.DESCRIPTION
    Get Microsoft patch Tuesday for a specific month and return it to the pipeline.
.PARAMETER Year
    Set the year for which to calculate Patch Tuesday.
.PARAMETER Month
    Set the month for which to calculate Patch Tuesday.
.EXAMPLE
    Get-PatchTuesday -Year 2015 -Month 3
.INPUTS
    System.String
.OUTPUTS
    System.DateTime.
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/Git
.COMPONENT
    CM
.FUNCTIONALITY
    Get patch tuesday
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true,Position=0)]
        [Alias('Yr')]
        [string]$Year,
        [Parameter(Mandatory=$true,Position=1)]
        [Alias('Mo')]
        [string]$Month
    )
    Begin {

        ## Build Target Month
        [DateTime]$StartingMonth = $Month + '/1/' + $Year
    }
    Process {
        ## Search for First Tuesday
        While ($StartingMonth.DayofWeek -ine 'Tuesday') {
            $StartingMonth = $StartingMonth.AddDays(1)
        }

        ## Set Second Tuesday of the month by adding 7 days
        $PatchTuesday = $StartingMonth.AddDays(7)

        ## Return Patch Tuesday
        Return $PatchTuesday
    }
    End {
    }
 }
#endregion

#region Function Get-MaintenanceWindows
Function Get-MaintenanceWindows {
<#
.SYNOPSIS
    Get existing maintenance windows.
.DESCRIPTION
    Get the existing maintenance windows for a collection.
.PARAMETER CollectionName
    Set the collection name for which to list the maintenance Windows.
.EXAMPLE
    Get-MaintenanceWindows -Collection 'Computer Collection'
.INPUTS
    System.String.
.OUTPUTS
    System.Object.
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/Git
.COMPONENT
    CM
.FUNCTIONALITY
    Get collection maintenance windows
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true,Position=0)]
        [Alias('Collection')]
        [string]$CollectionName
    )

    ## Get collection ID
    Try {
        $CollectionID = (Get-CMDeviceCollection -Name $CollectionName -ErrorAction 'Stop').CollectionID
    }

    #  Write to log in case of failure
    Catch {
        Write-Log -Message "Getting $CollectionName ID - Failed!"
    }

    ## Get collection maintenance windows
    Try {
        Get-CMMaintenanceWindow -CollectionId $CollectionID -ErrorAction 'Stop'
    }

    #  Write to log in case of failure
    Catch {
        Write-Log -Message "Get maintenance windows for $CollectionName - Failed!"
    }
}
#endregion

#region Function Remove-MaintenanceWindows
Function Remove-MaintenanceWindows {
<#
.SYNOPSIS
    Remove existing maintenance windows.
.DESCRIPTION
    Remove all existing maintenance windows from a collection.
.PARAMETER CollectionName
    The collection name for which to remove the maintenance windows.
.EXAMPLE
    Remove-MaintenanceWindows -Collection 'Computer Collection'
.INPUTS
    System.String.
.OUTPUTS
    System.String.
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/Git
.COMPONENT
    CM
.FUNCTIONALITY
    Remove maintenance windows
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true,Position=0)]
        [Alias('Collection')]
        [string]$CollectionName
    )

    ## Get collection ID
    Try {
        $CollectionID = (Get-CMDeviceCollection -Name $CollectionName -ErrorAction 'Stop').CollectionID
    }
    Catch {

        #  Write to log in case of failure
        Write-Log -Message "Getting $CollectionName ID - Failed!"
    }

    ## Get collection maintenance windows and delete them
    Try {
        Get-CMMaintenanceWindow -CollectionId $CollectionID | ForEach-Object {
            Remove-CMMaintenanceWindow -CollectionID $CollectionID -Name $PSItem.Name -Force -ErrorAction 'Stop'
            Write-Log -Message ($PSItem.Name + ' - Removed!') -SkipEventLog
        }
    }
    Catch {

        #  Write to log in case of failure
        Write-Log -Message "$PSItem.Name  - Removal Failed!"
    }
}
#endregion

#region Function New-MaintenanceWindows
Function New-MaintenanceWindows {
<#
.SYNOPSIS
    Set maintenance windows.
.DESCRIPTION
    Set Maintenance Windows to a Collection.
.PARAMETER CollectionName
    Specifies the collection name for which to set maintenance windows.
.PARAMETER Year
    Specifies the maintenance window year.
.PARAMETER Month
    Specifies the maintenance window month.
.PARAMETER OffsetWeeks
    Specifies the maintenance window offset number of weeks after patch Tuesday.
.PARAMETER OffsetDays
    Specifies the maintenance window offset number of days after path Tuesday.
.PARAMETER StartTime
    Specifies the maintenance window start time.
.PARAMETER StopTime
    Specifies the maintenance window stop time.
.PARAMETER ApplyTo
    Specifies the maintenance window type to ( Any | SoftwareUpdates | TaskSequences).
.EXAMPLE
    New-MaintenanceWindows -CollectionName 'Computer Collection' -Year 2015 -Month 3 -OffsetWeeks 3 -OffsetDays 2 -StartTime '01:00' -StopTime '02:00' -ApplyTo SoftwareUpdates
.INPUTS
    System.String.
.OUTPUTS
    System.String.
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/Git
.COMPONENT
    CM
.FUNCTIONALITY
    Create new maintenance window
#>
    Param (
        [Parameter(Mandatory=$true,Position=0)]
        [Alias('Collection')]
        [string]$CollectionName,
        [Parameter(Mandatory=$true,Position=1)]
        [Alias('Yr')]
        [int16]$Year,
        [Parameter(Mandatory=$true,Position=2)]
        [Alias('Mo')]
        [int16]$Month,
        [Parameter(Mandatory=$true,Position=3)]
        [Alias('Weeks')]
        [int16]$OffsetWeeks,
        [Parameter(Mandatory=$true,Position=4)]
        [Alias('Days')]
        [int16]$OffsetDays,
        [Parameter(Mandatory=$true,Position=5)]
        [Alias('Start')]
        [string]$StartTime,
        [Parameter(Mandatory=$true,Position=6)]
        [Alias('Stop')]
        [string]$StopTime,
        [Parameter(Mandatory=$true,Position=7)]
        [Alias('Apply')]
        [string]$ApplyTo
    )

    ## Get CollectionID
    Try {
        $CollectionID = (Get-CMDeviceCollection -Name $CollectionName -ErrorAction 'Stop').CollectionID
    }
    Catch {

        #  Write to log in case of failure
        Write-Log -Message "Getting $CollectionName ID - Failed!"
    }

    ## Get PatchTuesday
    [DateTime]$PatchTuesday = Get-PatchTuesday -Year $Year -Month $Month

    ## Setting Patch Day, adding offset days and weeks, reformatting date
    $PatchDay = $PatchTuesday.AddDays($OffsetDays+($OffsetWeeks*7)) | Get-Date -Format 'yyyy-MM-dd'

    ## Check if we got ourselves in the next year and return to the main script if true
    If ($PatchDay.Year -gt $Year) {
        Write-Log -Message 'Year threshold detected! Ending cycle...' -SkipEventLog
        Return
    }

    ## Setting maintenance window start and stop times
    $MWStartTime = Get-Date -Format 'yyyy-MM-dd HH:mm' -Date ($PatchDay+' '+$StartTime)
    $MWStopTime = Get-Date -Format 'yyyy-MM-dd HH:mm' -Date ($PatchDay+' '+$StopTime)

    ## Create the schedule token
    $MWSchedule = New-CMSchedule -Start $MWStartTime -End $MWStopTime -NonRecurring

    ## Set Maintenance Window Naming Convention for MW
    If ($ApplyTo -eq 'Any') { $MWType = 'MWA' }
    ElseIf ($ApplyTo -match 'Software') { $MWType = 'MWU' }
    ElseIf ($ApplyTo -match 'Task') { $MWType = 'MWT' }

    # Set maintenance window name
    $MWName =  $MWType+' - NR - '+(Get-Date -Uformat %Y-%m-%d $MWStartTime)+' '+$StartTime+'-'+$StopTime

    ## Set maintenance window on collection
    Try {
        $SetNewMW = New-CMMaintenanceWindow -CollectionID $CollectionID -Schedule $MWSchedule -Name $MWName -ApplyTo $ApplyTo -ErrorAction 'Stop'

        #  Write to log
        Write-Log -Message "$MWName - Set!" -SkipEventLog
    }
    Catch {

        #  Write to log in case of failure
        Write-Log -Message "Setting $MWName on $CollectionName - Failed!"
    }
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
.PARAMETER SMTPServer
    E-Mail SMTPServer.
.PARAMETER SMTPPort
    E-Mail SMTPPort.
.EXAMPLE
    Set-Mail -Body 'Test' -CC 'email@domain.com'
.INPUTS
    System.String.
.OUTPUTS
    System.String.
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/Git
.COMPONENT
    Mail
.FUNCTIONALITY
    Send mail
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$false,Position=0)]
        [string]$From = 'SCCM Site Server <noreply@domain.com>',
        [Parameter(Mandatory=$false,Position=1)]
        [string]$To = 'SCCM Team <email@domain.com>',
        [Parameter(Mandatory=$false,Position=2)]
        [string]$CC,
        [Parameter(Mandatory=$false,Position=3)]
        [string]$Subject = 'Info: Maintenance Window Set!',
        [Parameter(Mandatory=$true,Position=4)]
        [string]$Body,
        [Parameter(Mandatory=$false,Position=5)]
        [string]$SMTPServer = 'smtpserver.domain.no',
        [Parameter(Mandatory=$false,Position=6)]
        [string]$SMTPPort = "25"
    )

    Try {
        If ($CC) {
            Send-MailMessage -From $From -To $To -Subject $Subject -CC $CC -Body $Body -SmtpServer $SMTPServer -Port $SMTPPort -ErrorAction 'Stop'
        }
        Else {
            Send-MailMessage -From $From -To $To -Subject $Subject -Body $Body -SmtpServer $SMTPServer -Port $SMTPPort -ErrorAction 'Stop'
        }
    }
    Catch {
        Write-Log -Message 'Send Mail - Failed!'
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

## Import SCCM PSH module and changing context
Try {
    Import-Module $env:SMS_ADMIN_UI_PATH.Replace('\bin\i386','\bin\configurationmanager.psd1') -ErrorAction 'Stop'
}
Catch {
    Write-Log -Message 'Importing SCCM PSH module - Failed!'
}

#  Get the CMSITE SiteCode and change connection context
$SiteCode = Get-PSDrive -PSProvider 'CMSITE'

#  Change the connection context
Set-Location "$($SiteCode.Name):\"

##  Import the CSV file
Try {
    $csvFileData = Import-Csv -Path $csvFilePath -Encoding 'UTF8' -ErrorAction 'Stop'
}
Catch {
    Write-Log -Message 'Importing CSV Data - Failed!'
}

## Process imported CSV file data
$csvFileData | ForEach-Object {

    #  Check if we need the remove existing maintenance windows
    If ($PSItem.RemoveExisting -eq 'YES' ) {

        #  Write to log
        Write-Log -Message ('Removing maintenance windows from:  ' + $PSItem.CollectionName) -SkipEventLog

        #  Remove maintenance window
        Remove-MaintenanceWindows $PSItem.CollectionName
    }

    #  Check if we need to set maintenance windows for the whole year
    If ($PSItem.SetForWholeYear -eq 'YES') {

        #  Write to log
        Write-Log -Message ('Setting maintenance windows on: ' + $PSItem.CollectionName) -SkipEventLog

        #  Set maintenance windows for 12 months
        For ($Month = [int]$PSItem.Month; $Month -le 12; $Month++) {
            New-MaintenanceWindows -CollectionName $PSItem.CollectionName -Year $PSItem.Year -Month $Month -OffsetWeeks $PSItem.OffsetWeeks -OffsetDays $PSItem.OffsetDays -StartTime $PSItem.StartTime -StopTime $PSItem.StopTime -ApplyTo $PSItem.ApplyTo
        }
    }
    Else {

        #  Write to log
        Write-Log -Message $('Setting maintenance window on: ' + $PSItem.CollectionName) -SkipEventLog

        #  Run without removing maintenance windows and set just one maintenance window
        New-MaintenanceWindows -CollectionName $PSItem.CollectionName -Year $PSItem.Year -Month $PSItem.Month -OffsetWeeks $PSItem.OffsetWeeks -OffsetDays $PSItem.OffsetDays -StartTime $PSItem.StartTime -StopTime $PSItem.StopTime -ApplyTo $PSItem.ApplyTo
    }
}

## Get maintenance windows for unique collections
#  Initialize result array
[array]$Result = @()

#  Parsing CSV collection names
$csvFileData.CollectionName | Select-Object -Unique | ForEach-Object {

    #  Getting maintenance windows for collection (split to new line)
    $MaintenanceWindows = Get-MaintenanceWindows -CollectionName $PSItem | ForEach-Object { $PSItem.Name + "`n" }

    #  Assemble result with descriptors
    $Result += "`n Listing all maintenance windows for: " + $PSItem + " " + "`n " + $MaintenanceWindows
}

#  Convert the result to string and write it to log
[string]$ResultString = Out-String -InputObject $Result
Write-Log -Message $ResultString

## E-Mail result
#Send-Mail -Body $ResultString

## Return to Script Path
Set-Location $ScriptPath

## Remove SCCM PSH Module
Remove-Module 'ConfigurationManager' -Force -ErrorAction 'Continue'

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================