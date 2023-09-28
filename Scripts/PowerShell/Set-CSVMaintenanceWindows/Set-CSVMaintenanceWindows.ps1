<#
.SYNOPSIS
    Sets maintenance windows using a CSV file.
.DESCRIPTION
    Sets maintenance windows using a CSV file and is triggered when the settings CSV file is saved. using file watcher.
.EXAMPLE
    Set-ClientMaintenanceWindows.ps1
.NOTES
    Created by Ioan Popovici
    Uses FileSystemWatcher to see when the CSV file is changed.
    Requirements
        Configuration Manager, Local storage for the configuration file.
    Important
        Configuration file must reside on local storage for the file watcher to work.
.LINK
    https://MEM.Zone/Set-CSVMaintenanceWindows
.LINK
    https://MEM.Zone/Set-CSVMaintenanceWindows-CHANGELOG
.LINK
    https://MEM.Zone/Set-CSVMaintenanceWindows-GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    CM
.FUNCTIONALITY
    Set Maintenance Window
#>

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

## Get script path and name
[String]$ScriptPath = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Definition)
[String]$ScriptName = [System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Definition)

## CSV and log files initialization
#  Set the CSV mail settings and configuration file name
[String]$csvDataFileName = $ScriptName + 'Configuration'
[String]$csvSettingsFileName = $ScriptName + 'MailSettings'

#  Get CSV Settings and Data file name with extension
[String]$csvDataFileNameWithExtension = $csvDataFileName+'.csv'
[String]$csvSettingsFileNameWithExtension = $csvSettingsFileName+'.csv'

#  Assemble CSV Settings and Data file path
[String]$csvDataFilePath = (Join-Path -Path $ScriptPath -ChildPath $csvDataFileName)+'.csv'
[String]$csvSettingsFilePath = (Join-Path -Path $ScriptPath -ChildPath $csvSettingsFileName)+'.csv'

#  Assemble log file Path
[String]$LogFilePath = (Join-Path -Path $ScriptPath -ChildPath $ScriptName)+'.log'

## Initialize last write reference time with current time
[DateTime]$LastWriteTimeReference = (Get-Date)

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
    The event log entry source.
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
        [switch]$SkipEventLog
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
        Write-Host `n$EventLogEntryMessage -BackgroundColor Red -ForegroundColor White
        Write-Host $_.Exception -BackgroundColor Red -ForegroundColor White

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
            Write-Host $EventLogEntryMessage -BackgroundColor White -ForegroundColor Blue
        }
        Else {

            #  Write to event log
            Write-EventLog -LogName $EventLogName -Source $EventLogEntrySource -EventId $EventLogEntryID -EntryType $EventLogEntryType -Message $EventLogEntryMessage

            #  Write to console
            Write-Host $EventLogEntryMessage -BackgroundColor White -ForegroundColor Blue
        }
    }

    ##  Assemble log file line
    [String]$LogLine = "$LogTime : $EventLogEntryMessage"

    ## Write to log file
    $LogLine | Out-File -FilePath $LogFilePath -Append -NoClobber -Force -Encoding 'UTF8' -ErrorAction 'Continue'
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

    ## Get CollectionID
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
    Remove ALL existing maintenance windows.
.DESCRIPTION
    Remove ALL existing maintenance windows from a collection.
.PARAMETER CollectionName
    The collection name for which to remove the maintenance windows.
.EXAMPLE
    Remove-MaintenanceWindows -Collection 'Computer Collection'
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

    ## Get collection ID
    Try {
        $CollectionID = (Get-CMDeviceCollection -Name $CollectionName -ErrorAction 'Stop').CollectionID
    }
    Catch {
        Write-Log -Message "Getting $CollectionName ID - Failed!"
    }

    ## Get collection maintenance windows and delete them
    Try {
        Get-CMMaintenanceWindow -CollectionId $CollectionID | ForEach-Object {
            Remove-CMMaintenanceWindow -CollectionID $CollectionID -Name $_.Name -Force -ErrorAction 'Stop'
            Write-Log -Message ($_.Name+' - Removed!') -SkipEventLog
        }
    }
    Catch {

        #  Write to log in case of failure
        Write-Log -Message "$_.Name  - Removal Failed!"
    }
}
#endregion

#region Function Set-MaintenanceWindows
Function Set-MaintenanceWindows {
<#
.SYNOPSIS
    Set maintenance windows.
.DESCRIPTION
    Set maintenance windows to a collection.
.PARAMETER CollectionName
    The collection name for which to set maintenance windows.
.PARAMETER Date
    The maintenance window date.
.PARAMETER StartTime
    The maintenance window start time.
.PARAMETER StopTime
    The maintenance window stop time.
.PARAMETER ApplyTo
    Maintenance window applicability (Any | SoftwareUpdates | TaskSequences).
.EXAMPLE
    Set-MaintenanceWindows -CollectionName 'Computer Collection' -Date '2017-09-21' -StartTime '01:00'  -StopTime '02:00' -ApplyTo SoftwareUpdates
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
        [String]$CollectionName,
        [Parameter(Mandatory=$True,Position=1)]
        [Alias('Da')]
        [String]$Date,
        [Parameter(Mandatory=$True,Position=2)]
        [Alias('SartT')]
        [String]$StartTime,
        [Parameter(Mandatory=$True,Position=3)]
        [Alias('StopT')]
        [String]$StopTime,
        [Parameter(Mandatory=$True,Position=4)]
        [Alias('Apply')]
        [String]$ApplyTo
    )

    ## Get collection ID
    Try {
        $CollectionID = (Get-CMDeviceCollection -Name $CollectionName -ErrorAction 'Stop').CollectionID
    }
    Catch {

        #  Write to log in case of failure
        Write-Log -Message "Getting $CollectionName ID - Failed!"
    }

    ## Setting maintenance window start and stop times
    Try {
        $MWStartTime = Get-Date -Format 'yyyy-MM-dd HH:mm' -Date ($Date+' '+$StartTime) -ErrorAction 'Stop'
        $MWStopTime = Get-Date -Format 'yyyy-MM-dd HH:mm' -Date ($Date+' '+$StopTime) -ErrorAction 'Stop'
    }
    Catch {

        #  Write to log in case of failure
        Write-Log -Message "Creating Start/Stop token for $CollectionName - Failed!"
    }

    ## Create the schedule token
    Try {
        $MWSchedule = New-CMSchedule -Start $MWStartTime -End $MWStopTime -NonRecurring -ErrorAction 'Stop'
    }
    Catch {

        #  Write to log in case of failure
        Write-Log -Message "Creating schedule token for $CollectionName - Failed!"
    }

    ## Set maintenance window naming convention
    If ($ApplyTo -eq 'Any') { $MWType = 'MWA' }
    ElseIf ($ApplyTo -match 'Software') { $MWType = 'MWU' }
    ElseIf ($ApplyTo -match 'Task') { $MWType = 'MWT' }

    # Set maintenance window name
    $MWName =  $MWType+'.NR.'+(Get-Date -Uformat %Y-%B-%d $MWStartTime -ErrorAction 'Continue')+'_'+$StartTime+'-'+$StopTime
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
        [String]$Attachments = $LogFilePath,
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
        Elseif ($CC -eq [String]::Empty -or $CC -eq 'NO') {
            Send-MailMessage -From $From -To $To -Subject $Subject -Body $Body -Attachments $Attachments -SmtpServer $SMTPServer -Port $SMTPPort -ErrorAction 'Stop'
        }
    }
    Catch {
        Write-Log -Message 'Send Mail - Failed!'
    }
}
#endregion

#region Function Start-DataProcessing
Function Start-DataProcessing {
<#
.SYNOPSIS
    Used for main data processing.
.DESCRIPTION
    Used for main data processing, for this script only.
.EXAMPLE
    Start-DataProcessing
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
#>
    ## Import SCCM PSH module and changing context
    Try {
        Import-Module $env:SMS_ADMIN_UI_PATH.Replace('\bin\i386','\bin\configurationmanager.psd1') -ErrorAction 'Stop'
    }
    Catch {
        Write-Log -Message 'Importing SCCM PSH module - Failed!'
    }

    #  Get the CMSITE SiteCode and change connection context
    $SiteCode = Get-PSDrive -PSProvider CMSITE

    #  Change the connection context
    Set-Location "$($SiteCode.Name):\"

    ## Import the Settings CSV file
    Try {
        $csvSettingsData = Import-Csv -Path $csvSettingsFilePath -Encoding 'UTF8' -ErrorAction 'Stop'
    }
    Catch {

        #  write to log
        Write-Log -Message 'Importing Settings CSV Data - Failed!'
    }

    ## Import the Collection CSV file
    Try {
        $csvCollectionData = Import-Csv -Path $csvDataFilePath -Encoding 'UTF8' -ErrorAction 'Stop'
    }
    Catch {

        #  write to log
        Write-Log -Message 'Importing Collection CSV Data - Failed!'
    }
    ## Process imported CSV file data
    Try {

        #  Process imported CSV file data
        $csvCollectionData | ForEach-Object {

            #  Check if we need to remove existing maintenance windows
            If ($_.RemoveExisting -eq 'YES' ) {

                #  Write to log
                Write-Log -Message ('Removing maintenance windows from:  '+$_.CollectionName) -SkipEventLog

                #  Remove maintenance window
                Remove-MaintenanceWindows -CollectionName $_.CollectionName
            }

            #  Set Maintenance Window
            Set-MaintenanceWindows -CollectionName $_.CollectionName -Date $_.Date -StartTime $_.StartTime -StopTime $_.StopTime -ApplyTo $_.ApplyTo
        }

        #  Initialize result array
        [array]$Result =@()

        #  Parsing CSV unique collection names
        $csvCollectionData.CollectionName | Select-Object -Unique | ForEach-Object {

            #  Getting maintenance windows for collection (split to new line)
            $MaintenanceWindows = Get-MaintenanceWindows -CollectionName $_ | ForEach-Object { $_.Name+"`n" }

            #  Assemble result with descriptors
            $Result+= "`nListing all maintenance windows for: "+$_+" "+"`n`n "+$MaintenanceWindows
        }

        #  Convert the result to String and write it to log
        [String]$ResultString = Out-String -InputObject $Result
        Write-Log -Message $ResultString

        ## Return to Script Path
        Set-Location $ScriptPath

        ## Remove SCCM PSH Module
        Remove-Module 'ConfigurationManager' -Force -ErrorAction 'Continue'
    }
    Catch {

        #  Not needed, empty
    }
    Finally {

        #  Send Mail Report if needed
        If ($csvSettingsData.SendMail -eq 'YES' -and -not $Global:ErrorResult) {

            #  Write to log
            Write-Log -Message "Sending Mail Report..."

            #  Sending mail
            Send-Mail -Subject 'Info: Setting Maintenance Window - Success!' -Body $ResultString -From $csvSettingsData.From -To $csvSettingsData.To -CC $csvSettingsData.CC -SMTPServer $csvSettingsData.SMTPServer -SMTPPort $csvSettingsData.SMTPPort

        }
        If ($csvSettingsData.SendMail -eq 'YES' -and $Global:ErrorResult) {

            #  Write to log
            Write-Log 'CSV Data Processing - Failed!'

            #  Write to log
            Write-Log -Message "Sending Error Mail Report..."

            #  Sending mail
            Send-Mail -Subject 'Warning: Setting Maintenance Window - Failed!' -Body "Errors: `n $Global:ErrorResult"  -From $csvSettingsData.From -To $csvSettingsData.To -CC $csvSettingsData.CC -SMTPServer $csvSettingsData.SMTPServer -SMTPPort $csvSettingsData.SMTPPort
        }
    }
}

#endregion

#region Function Test-FileChangeEvent
Function Test-FileChangeEvent {
<#
.SYNOPSIS
    Workaround for FileSystemWatcher firing multiple events during a write operation.
.DESCRIPTION
    FileSystemWatcher may fire multiple events on a write operation.
    It's a known problem but it's not a bug in FileSystemWatcher.
    This function is discarding events fired more than once a second.
.PARAMETER $WatchFilePath
    Specify file path to be watched.
.PARAMETER $LastWriteTimeReference
    Specify file last read time for reference.
.EXAMPLE
    Test-FileChangeEvent -WatchFilePath $WatchFilePath -LastWriteTimeReference $LastWriteTimeReference
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
        [Alias('WatchPath')]
        [String]$WatchFilePath,
        [Parameter(Mandatory=$True,Position=1)]
        [Alias('WriteTimeReference')]
        [DateTime]$LastWriteTimeReference
    )

    ## Get file last write time
    Try {
        [DateTime]$FileLastWriteTime = (Get-ItemProperty -Path $WatchFilePath).LastWriteTime
    }
    Catch {

        #   write to log
        Write-Log -Message "Reading Last Write Time from $WatchFilePath - Failed!"
    }

    ## Test if the file change event is valid by comparing the file last write time and reference parameter specified time
    If (($FileLastWriteTime - $LastWriteTimeReference).Seconds -ge 1) {

        ## Write to log
        Write-Log -Message "`nFile change - Detected!" -SkipEventLog

        ## Start main data processing and wait for it to finish
        Start-DataProcessing | Out-Null
    }
    Else {

        ## Do nothing, the file change event was fired more than once a second
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

    ## Initialize file watcher and wait for file changes
    $FileWatcher = New-Object System.IO.FileSystemWatcher
    $FileWatcher.Path = $ScriptPath
    $FileWatcher.Filter = $csvDataFileNameWithExtension
    $FileWatcher.IncludeSubdirectories = $False
    $FileWatcher.NotifyFilter = [System.IO.NotifyFilters]::'LastWrite'
    $FileWatcher.EnableRaisingEvents = $True

    #  Register file watcher event
    Register-ObjectEvent -InputObject $FileWatcher -EventName 'Changed' -Action {

        # Test if we really need to start processing
        Test-FileChangeEvent -LastWriteTimeReference $LastWriteTimeReference -WatchFilePath $csvDataFilePath

        #  Reinitialize DateTime variable to be used on next file change event
        $LastWriteTimeReference = (Get-Date)
    }

#endregion

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================
