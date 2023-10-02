<#
.SYNOPSIS
    Adds devices from a txt file to a SCCM device collection.
.DESCRIPTION
    Adds devices from a txt file to a SCCM device collection, triggered when the txt file is saved.
.EXAMPLE
    Add-CMDeviceDirectMemebershipRules.ps1
.INPUTS
    System.String
.OUTPUTS
    System.String.
.NOTES
    Created by Ioan Popovici
    Requirements
        * SCCM client SDK
        * Local file system only
    To do
        * Remove direct membership rules using CIM.
        * Add option to add new devices without removing all direct membership rules first.
.LINK
    https://MEMZ.one/Add-CMDeviceDirectMemebershipRules
.LINK
    https://MEMZ.one/Add-CMDeviceDirectMemebershipRules-CHANGELOG
.LINK
    https://MEMZ.one/Add-CMDeviceDirectMemebershipRules-GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    CM
.FUNCTIONALITY
    Add devices to a collection
#>

## Set script requirements
#Requires -Version 3.0

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

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
        [Parameter(Mandatory=$false,Position=0)]
        [Alias('Message')]
        [String]$EventLogEntryMessage,
        [Parameter(Mandatory=$false,Position=1)]
        [Alias('EName')]
        [String]$EventLogName = 'Configuration Manager',
        [Parameter(Mandatory=$false,Position=2)]
        [Alias('Source')]
        [String]$EventLogEntrySource = $ScriptName,
        [Parameter(Mandatory=$false,Position=3)]
        [Alias('ID')]
        [int32]$EventLogEntryID = 1,
        [Parameter(Mandatory=$false,Position=4)]
        [Alias('Type')]
        [String]$EventLogEntryType = 'Information',
        [Parameter(Mandatory=$false,Position=5)]
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
        [Parameter(Mandatory=$true,Position=0)]
        [String]$From,
        [Parameter(Mandatory=$true,Position=1)]
        [String]$To,
        [Parameter(Mandatory=$false,Position=2)]
        [String]$CC,
        [Parameter(Mandatory=$true,Position=3)]
        [String]$Subject,
        [Parameter(Mandatory=$true,Position=4)]
        [String]$Body,
        [Parameter(Mandatory=$false,Position=5)]
        [String]$Attachments = $LogFilePath,
        [Parameter(Mandatory=$false,Position=6)]
        [String]$SMTPServer = 'mail.datakraftverk.no',
        [Parameter(Mandatory=$false,Position=7)]
        [String]$SMTPPort = "25"
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

#region Function Get-DeviceDirectMembershipRules
Function Get-DeviceDirectMembershipRules {
<#
.SYNOPSIS
    Get ALL existing device direct membership rules.
.DESCRIPTION
    Get ALL existing device direct membership rules from a collection.
.PARAMETER CollectionName
    The collection name for which to get device direct membership rules.
.EXAMPLE
    Get-DeviceDirectMembershipRules -CollectionName 'Computer Collection'
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true,Position=0)]
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

    ## Get collection direct membership
    Try {
        Get-CMDeviceCollectionDirectMembershipRule -CollectionName $CollectionName -ErrorAction 'Stop'
    }
    Catch {

        #  write to log
        Write-Log -Message "Get Device Direct Membership Rules for $CollectionName - Failed!"
    }
}
#endregion

#region Function Remove-DeviceDirectMembershipRule
Function Remove-DeviceDirectMembershipRule {
<#
.SYNOPSIS
    Remove ALL existing device direct membership rules.
.DESCRIPTION
    Remove ALL existing device direct membership rules from a collection.
.PARAMETER CollectionName
    The collection name for which to remove the device direct membership rules.
.EXAMPLE
    Remove-DeviceDirectMembershipRule -CollectionName 'Computer Collection'
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    Blog    : https://MEM.Zone
.LINK
    Github  : https://MEM.Zone/GIT
.LINK
    Issues  : https://MEM.Zone/ISSUES
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true,Position=0)]
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

    ## Get collection direct membership rules and delete them
    Try {
        Get-CMDeviceCollectionDirectMembershipRule -CollectionName $CollectionName -ErrorAction 'Stop' | ForEach-Object {
            Remove-CMDeviceCollectionDirectMembershipRule -CollectionName $CollectionName -ResourceName $_.RuleName -ErrorAction 'Stop' -Force

            #  Write to log
            Write-Log -Message ($_.RuleName+' - Removed!') -SkipEventLog
        }
    }
    Catch {

        #  write to log
        Write-Log -Message "$_.RuleName  - Removal Failed!"
    }
}
#endregion

Function Add-DeviceDirectMembershipRule {
<#
.SYNOPSIS
    Add device direct membership rules.
.DESCRIPTION
    Add device direct membership rules to a collection.
.PARAMETER CollectionName
    The collection name for which add device direct membership rules.
.PARAMETER DeviceName
    The device name for which add the device direct membership rule.
.EXAMPLE
    Add-DeviceDirectMembershipRule -CollectionName 'Computer Collection' -DeviceName 'SomeComputer'
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true,Position=0)]
        [Alias('Collection')]
        [String]$CollectionName,
        [Alias('Device')]
        [String]$DeviceName
    )

    ## Get collection ID
    Try {
        $CollectionID = (Get-CMDeviceCollection -Name $CollectionName -ErrorAction 'Stop').CollectionID
    }
    Catch {
        Write-Log -Message "Getting $CollectionName ID - Failed!"
    }

    ## Add device direct membership rules to the specified collection
    Try {
        Add-CMDeviceCollectionDirectMembershipRule -CollectionName $CollectionName -ResourceID (Get-CMDevice -Name $DeviceName).ResourceID -ErrorAction 'Stop'

            #  Write to log
            Write-Log -Message ($DeviceName+' - Added!') -SkipEventLog
        }
    Catch {

        #  write to log
        Write-Log -Message "Adding $DeviceName to $CollectionName - Failed!"
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

    ## Import the Settings csv file
    Try {
        $csvSettingsData = Import-Csv -Path $csvSettingsFilePath -Encoding 'UTF8' -ErrorAction 'Stop'
    }
    Catch {

        #  write to log
        Write-Log -Message 'Importing Settings CSV Data - Failed!'
    }

    ## Import the Device csv file
    Try {
        $csvDeviceData = Import-Csv -Path $csvDataFilePath -Encoding 'UTF8' -ErrorAction 'Stop'
    }
    Catch {

        #  write to log
        Write-Log -Message 'Importing Device CSV Data - Failed!'
    }

    ## Process imported csv data
    Try {

        #  Remove ALL device direct membership rules from specified unique collections
        $csvDeviceData.CollectionName | Select-Object -Unique | ForEach-Object {
            Remove-DeviceDirectMembershipRule -CollectionName $_
        }

        #  Add device direct membership rules to specified collections
        $csvDeviceData | ForEach-Object {
            Add-DeviceDirectMembershipRule -CollectionName $_.CollectionName -DeviceName $_.DeviceName
        }

        #  Initialize result array
        [array]$Result =@()

        #  Parsing CSV unique collection names
        $csvDeviceData.CollectionName | Select-Object -Unique | ForEach-Object {

            #  Getting maintenance windows for collection (split to new line)
            $DeviceDirectMemebershipRules = Get-DeviceDirectMembershipRules  -CollectionName $_ | ForEach-Object { $_.RuleName+"`n" }

            #  Assemble result with descriptors
            $Result+= "`nListing all Device Direct Memebership Rules for: "+$_+" "+"`n`n "+$DeviceDirectMemebershipRules
        }

        #  Convert the result to String and write it to log
        [String]$ResultString = Out-String -InputObject $Result
        Write-Log -Message $ResultString

        #  Return to Script Path
        Set-Location $ScriptPath

        #  Remove SCCM PSH Module
        Remove-Module 'ConfigurationManager' -Force -ErrorAction 'Continue'
    }
    Catch {

        #  Not needed, empty
    }

    #  Block will always be processed, used for sending e-mail with failure or success reports
    Finally {

        #  Send Mail Report if needed
        If ($csvSettingsData.SendMail -eq 'YES' -and -not $Global:ErrorResult) {

            #  Write to log
            Write-Log -Message "Sending Mail Report..."

            #  Sending mail
            Send-Mail -Subject 'Info: Adding Device Direct Membership Rules to Collection - Success!' -Body $ResultString -From $csvSettingsData.From -To $csvSettingsData.To -CC $csvSettingsData.CC -SMTPServer $csvSettingsData.SMTPServer -SMTPPort $csvSettingsData.SMTPPort
        }
        If ($csvSettingsData.SendMail -eq 'YES' -and $Global:ErrorResult) {

            #  Write to log
            Write-Log 'CSV Data Processing - Failed!'

            #  Write to log
            Write-Log -Message "Sending Error Mail Report..."

            #  Sending mail
            Send-Mail -Subject 'Warning: Adding Device Direct Membership Rules to Collection - Failed!' -Body "Errors: `n $Global:ErrorResult"  -From $csvSettingsData.From -To $csvSettingsData.To -CC $csvSettingsData.CC -SMTPServer $csvSettingsData.SMTPServer -SMTPPort $csvSettingsData.SMTPPort
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
        [Parameter(Mandatory=$true)]
        [Alias('WatchPath')]
        [String]$WatchFilePath,
        [Parameter(Mandatory=$true)]
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
    $FileWatcher.IncludeSubdirectories = $false
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
##*=============================================
##* END SCRIPT BODY
##*=============================================
