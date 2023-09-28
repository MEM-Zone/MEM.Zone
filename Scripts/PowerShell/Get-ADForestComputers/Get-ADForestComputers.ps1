<#
.SYNOPSIS
    Gets AD computer information from a list of forests.
.DESCRIPTION
    Gets AD computer name, operating system and domain from a list of forests.
.EXAMPLE
    Get-AdForestComputers.ps1
.INPUTS
    System.String.
.OUTPUTS
    System.Object.
.LINK
    https://MEM.Zone/Get-ADForestComputers
.LINK
    https://MEM.Zone/Get-ADForestComputers-CHANGELOG
.LINK
    https://MEM.Zone/Get-ADForestComputers-GIT
.LINK
    https://MEM.Zone/ISSUES
#>

## Set script requirements
#Requires -Version 3.0

##*=============================================
##* INITIALIZATION
##*=============================================
#region Initialization

## Add Assemblies
Add-Type -AssemblyName 'System.Drawing'
Add-Type -AssemblyName 'System.Windows.Forms'

## Initialize Logging
$ResultPath = Join-Path -Path $PSScriptRoot -ChildPath '\Results'
$ErrorLog   = Join-Path -Path $PSScriptRoot -ChildPath '\GetADForestComputers.log'

## Create Result Directory
New-Item -Path $ResultPath -Type 'Directory' -ErrorAction 'SilentlyContinue'

## Clean Result Directory
Remove-Item $ResultPath\* -Recurse -Force -ErrorAction 'SilentlyContinue'

## Clean Log
Get-Date | Out-File $ErrorLog -Force

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
    Write messages to a log file in CMTrace.exe compatible format or Legacy text file format.
.DESCRIPTION
    Write messages to a log file in CMTrace.exe compatible format or Legacy text file format and optionally display in the console.
.PARAMETER Message
    The message to write to the log file or output to the console.
.EXAMPLE
    Write-Log -Message "Error"
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true,Position=0)]
        [Alias('Text')]
        [string]$Message
    )

    ## Getting the Date and time
    $DateAndTime = Get-Date

    ### Writing to log file
    "$DateAndTime : $Message" | Out-File $ErrorLog -Append
    "$DateAndTime : $_" | Out-File $ErrorLog -Append

    ## Writing to Console
    Write-Host -Message $Message -ForegroundColor 'Red' -BackgroundColor 'White'
    Write-Host -Message "$($_.Exception)`n" -ForegroundColor 'White' -BackgroundColor 'Red'
}
#endregion

#region Function Remove-InvalidCharacters
Function Remove-InvalidCharacters {
<#
.SYNOPSIS
    Removes invalid characters from a string.
.DESCRIPTION
    Removes invalid characters from a string.
.PARAMETER TextString
    Text string to clean.
.EXAMPLE
    Remove-InvalidCharacters -String 'Domains or Domain Controllers'
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
        [ValidateNotNullorEmpty()]
        [string]$TextString
    )

    $invalidCharacters = [IO.Path]::GetInvalidFileNameChars() -join ''
    $RegEx = "[{0}]" -f [RegEx]::Escape($invalidCharacters)
    $Result = $TextString -replace $RegEx
    Write-Output -InputObject $Result
}
#endregion

#region Function Show-InputPrompt
Function Show-InputPrompt {
<#
.SYNOPSIS
    Displays a custom input prompt with optional buttons.
.DESCRIPTION
    Any combination of Left, Middle or Right buttons can be displayed. The return value of the button clicked by the user is the button text specified.
.PARAMETER Title
    Title of the prompt.
.PARAMETER Label
    Label text to be included in the prompt.
.PARAMETER LabelAlignment
    Alignment of the label text. Options: Left, Center, Right. Default: Left.
.PARAMETER Text
    Text to be included in the Text box prompt
.PARAMETER TextAlignment
    Alignment of the Text Box text. Options: Left, Center, Right. Default: Left.
.PARAMETER ButtonLeftText
    Show a button on the left of the prompt with the specified text.
.PARAMETER ButtonRightText
    Show a button on the right of the prompt with the specified text.
.PARAMETER ButtonMiddleText
    Show a button in the middle of the prompt with the specified text.
.PARAMETER MinimizeWindows
    Specifies whether to minimize other windows when displaying prompt. Default: $false.
.EXAMPLE
    Show-InputPrompt -Title 'Domains or Domain Controllers' -Label 'Input Domains or Domain Controllers:' -Text 'Domains go here.' -ButtonRightText 'Ok' -ButtonLeftText 'Cancel'
.NOTES
    Function modified from original source
.LINK
    http://psappdeploytoolkit.com
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$false)]
        [ValidateNotNullorEmpty()]
        [string]$Title = '',
        [Parameter(Mandatory=$false)]
        [string]$Label = '',
        [Parameter(Mandatory=$false)]
        [ValidateSet('Left','Center','Right')]
        [string]$LabelAlignment = 'Left',
        [Parameter(Mandatory=$false)]
        [string]$Text = '',
        [Parameter(Mandatory=$false)]
        [ValidateSet('Left','Center','Right')]
        [string]$TextAlignment = 'Left',
        [Parameter(Mandatory=$false)]
        [string]$ButtonRightText = '',
        [Parameter(Mandatory=$false)]
        [string]$ButtonLeftText = '',
        [Parameter(Mandatory=$false)]
        [string]$ButtonMiddleText = '',
        [Parameter(Mandatory=$false)]
        [ValidateNotNullorEmpty()]
        [boolean]$MinimizeWindows = $false
    )

    [Windows.Forms.Application]::EnableVisualStyles()
    $formInputPrompt = New-Object -TypeName 'System.Windows.Forms.Form'
    $labelText = New-Object -TypeName 'System.Windows.Forms.Label'
    $textBox = New-Object -TypeName 'System.Windows.Forms.TextBox'
    $buttonRight = New-Object -TypeName 'System.Windows.Forms.Button'
    $buttonMiddle = New-Object -TypeName 'System.Windows.Forms.Button'
    $buttonLeft = New-Object -TypeName 'System.Windows.Forms.Button'
    $buttonAbort = New-Object -TypeName 'System.Windows.Forms.Button'
    $InitialformInputPromptWindowState = New-Object -TypeName 'System.Windows.Forms.FormWindowState'

    [scriptblock]$Form_Cleanup_FormClosed = {
        ## Remove all event handlers from the controls
        Try {
            $labelText.remove_Click($handler_labelText_Click)
            $textBox.remove_Click($handler_textBox_Click)
            $buttonLeft.remove_Click($buttonLeft_OnClick)
            $buttonRight.remove_Click($buttonRight_OnClick)
            $buttonMiddle.remove_Click($buttonMiddle_OnClick)
            $buttonAbort.remove_Click($buttonAbort_OnClick)
            $formInputPrompt.remove_Load($Form_StateCorrection_Load)
            $formInputPrompt.remove_FormClosed($Form_Cleanup_FormClosed)
        }
        Catch { }
    }

    [scriptblock]$Form_StateCorrection_Load = {
        ## Correct the initial state of the form to prevent the .NET maximized form issue
        $formInputPrompt.WindowState = 'Normal'
        $formInputPrompt.AutoSize = $true
        $formInputPrompt.TopMost = $true
        $formInputPrompt.BringToFront()
        # Get the start position of the form so we can return the form to this position if PersistPrompt is enabled
        Set-Variable -Name 'formInputPromptStartPosition' -Value $formInputPrompt.Location -Scope 'Script'
    }

    ## Form
    ##----------------------------------------------
    ## Create padding object
    $paddingNone = New-Object -TypeName 'System.Windows.Forms.Padding'
    $paddingNone.Top = 0
    $paddingNone.Bottom = 0
    $paddingNone.Left = 0
    $paddingNone.Right = 0

    ## Generic Label properties
    $labelPadding = '20,0,20,0'

    ## Generic Text properties
    $textPadding = '20,0,20,0'

    ## Generic Button properties
    $buttonWidth = 110
    $buttonHeight = 23
    $buttonPadding = 50
    $buttonSize = New-Object -TypeName 'System.Drawing.Size'
    $buttonSize.Width = $buttonWidth
    $buttonSize.Height = $buttonHeight
    $buttonPadding = New-Object -TypeName 'System.Windows.Forms.Padding'
    $buttonPadding.Top = 0
    $buttonPadding.Bottom = 5
    $buttonPadding.Left = 50
    $buttonPadding.Right = 0

    ## Label Text
    $labelText.DataBindings.DefaultDataSourceUpdateMode = 0
    $labelText.Name = 'labelText'
    $System_Drawing_Size = New-Object -TypeName 'System.Drawing.Size'
    $System_Drawing_Size.Height = 20
    $System_Drawing_Size.Width = 455
    $labelText.Size = $System_Drawing_Size
    $System_Drawing_Point = New-Object -TypeName 'System.Drawing.Point'
    $System_Drawing_Point.X = 4
    $System_Drawing_Point.Y = 20
    $labelText.Location = $System_Drawing_Point
    $labelText.Margin = '0,0,0,0'
    $labelText.Padding = $labelPadding
    $labelText.TabIndex = 1
    $labelText.Text = $Label
    $labelText.TextAlign = "Middle$($LabelAlignment)"
    $labelText.Anchor = 'Top'
    $labelText.add_Click($handler_labelText_Click)

    ## Text Box
    $textBox.DataBindings.DefaultDataSourceUpdateMode = 0
    $textBox.Name = 'textBox'
    $System_Drawing_Size = New-Object -TypeName 'System.Drawing.Size'
    $System_Drawing_Size.Height = 330
    $System_Drawing_Size.Width = 390
    $textBox.Size = $System_Drawing_Size
    $System_Drawing_Point = New-Object -TypeName 'System.Drawing.Point'
    $System_Drawing_Point.X = 25
    $System_Drawing_Point.Y = 45
    $textBox.Location = $System_Drawing_Point
    $textBox.Margin = '0,0,0,0'
    $textBox.Padding = $textPadding
    $textBox.TabIndex = 2
    $textBox.Text = $Text
    $textBox.TextAlign = $TextAlignment
    $textBox.Anchor = 'Top'
    $textBox.AcceptsReturn = $true
    $textBox.AcceptsTab = $false
    $textBox.Multiline = $true
    $textBox.ScrollBars = 'Both'
    $textBox.add_Click($handler_textBox_Click)

    ## Button Left
    $buttonLeft.DataBindings.DefaultDataSourceUpdateMode = 0
    $buttonLeft.Location = '15,400'
    $buttonLeft.Name = 'buttonLeft'
    $buttonLeft.Size = $buttonSize
    $buttonLeft.TabIndex = 3
    $buttonLeft.Text = $buttonLeftText
    $buttonLeft.DialogResult = 'No'
    $buttonLeft.AutoSize = $false
    $buttonLeft.UseVisualStyleBackColor = $true
    $buttonLeft.add_Click($buttonLeft_OnClick)

    ## Button Middle
    $buttonMiddle.DataBindings.DefaultDataSourceUpdateMode = 0
    $buttonMiddle.Location = '170,400'
    $buttonMiddle.Name = 'buttonMiddle'
    $buttonMiddle.Size = $buttonSize
    $buttonMiddle.TabIndex = 4
    $buttonMiddle.Text = $buttonMiddleText
    $buttonMiddle.DialogResult = 'Ignore'
    $buttonMiddle.AutoSize = $true
    $buttonMiddle.UseVisualStyleBackColor = $true
    $buttonMiddle.add_Click($buttonMiddle_OnClick)

    ## Button Right
    $buttonRight.DataBindings.DefaultDataSourceUpdateMode = 0
    $buttonRight.Location = '325,400'
    $buttonRight.Name = 'buttonRight'
    $buttonRight.Size = $buttonSize
    $buttonRight.TabIndex = 5
    $buttonRight.Text = $ButtonRightText
    $buttonRight.DialogResult = 'Yes'
    $buttonRight.AutoSize = $true
    $buttonRight.UseVisualStyleBackColor = $true
    $buttonRight.add_Click($buttonRight_OnClick)

    ## Button Abort (Hidden)
    $buttonAbort.DataBindings.DefaultDataSourceUpdateMode = 0
    $buttonAbort.Name = 'buttonAbort'
    $buttonAbort.Size = '1,1'
    $buttonAbort.DialogResult = 'Abort'
    $buttonAbort.TabStop = $false
    $buttonAbort.UseVisualStyleBackColor = $true
    $buttonAbort.add_Click($buttonAbort_OnClick)

    ## Form Input Prompt
    $System_Drawing_Size = New-Object -TypeName 'System.Drawing.Size'
    $System_Drawing_Size.Height = 400
    $System_Drawing_Size.Width = 455
    $formInputPrompt.Size = $System_Drawing_Size
    $formInputPrompt.Padding = '0,0,0,10'
    $formInputPrompt.Margin = $paddingNone
    $formInputPrompt.DataBindings.DefaultDataSourceUpdateMode = 0
    $formInputPrompt.Name = 'WelcomeForm'
    $formInputPrompt.Text = $title
    $formInputPrompt.StartPosition = 'CenterScreen'
    $formInputPrompt.FormBorderStyle = 'FixedDialog'
    $formInputPrompt.MaximizeBox = $false
    $formInputPrompt.MinimizeBox = $false
    $formInputPrompt.TopMost = $true
    $formInputPrompt.TopLevel = $true
    $formInputPrompt.Controls.Add($labelText)
    $formInputPrompt.Controls.Add($textBox)
    $formInputPrompt.Controls.Add($buttonAbort)
    If ($buttonLeftText) { $formInputPrompt.Controls.Add($buttonLeft) }
    If ($buttonMiddleText) { $formInputPrompt.Controls.Add($buttonMiddle) }
    If ($buttonRightText) { $formInputPrompt.Controls.Add($buttonRight) }

    ## Save the initial state of the form
    $InitialformInputPromptWindowState = $formInputPrompt.WindowState
    ## Init the OnLoad event to correct the initial state of the form
    $formInputPrompt.add_Load($Form_StateCorrection_Load)
    ## Clean up the control events
    $formInputPrompt.add_FormClosed($Form_Cleanup_FormClosed)

    ## Show the prompt synchronously. If user cancels, then keep showing it until user responds using one of the buttons and enters some text.
    $showDialog = $true
    While ($showDialog) {
        # Minimize all other windows
        If ($minimizeWindows) { $null = $shellApp.MinimizeAll() }
        # Show the Form
        $result = $formInputPrompt.ShowDialog()
        If (($result -eq 'Yes' -and $textBox.Text) -or ($result -eq 'No') -or ($result -eq 'Ignore') -or ($result -eq 'Abort')) {
            $showDialog = $false
        }
    }

    $formInputPrompt.Dispose()

    If ($textBox.Text) {
        $cleanText = $($textBox.Text.Trim() -split '\n' | ForEach-Object { Remove-InvalidCharacters -TextString $_ })
    }

    Switch ($result) {
        'Yes' { Write-Output -InputObject @($buttonRightText,$cleanText) }
        'No' { Write-Output -InputObject $buttonLeftText }
        'Ignore' { Write-Output -InputObject $buttonMiddleText }
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

## Initialize forest counter
$ProgressCounterForest = 0

## Get input for Forests
$GetForestList = Show-InputPrompt -Title 'Forests' -Label 'Input Forests:' -ButtonRightText 'Ok' -ButtonLeftText 'Cancel'

## Skip the first entry as it is the Button value
$Forests = $GetForestList | Select-Object -skip '1'

## Exit script if user has selected Cancel Button
If ($GetForestList -eq 'Cancel') {
    Write-Host -Message 'Canceled. Exiting... `n' -ForegroundColor 'Red' -BackgroundColor 'Black'
    Start-Sleep -Seconds 10
    Exit
}

## Process Imported CSV Forest List
ForEach ($Forest in $Forests) {

    #  Initialize variables
    $ADForest = $null
    $ADForestDomains = $null
    $Domain = $null
    $ProgressCounterDomain = 0

    #  Show Forest progress bar
    If ($Forests.Count -gt 0) {
        $ProgressCounterForest++
        $PercentCompleteForest = (($ProgressCounterForest / $Forests.Count) * 100)
        Write-Progress -Id 1 -Activity "Processing Forest: $Forest" -Status "$ProgressCounterForest of $($Forests.Count) Forests" -CurrentOperation "$PercentCompleteForest% complete" -PercentComplete $PercentCompleteForest
    }

      #  Get AD Forest domains
    Try {
        $ADForest = Get-ADForest $Forest -ErrorAction SilentlyContinue -ErrorVariable Error1
        $ADForestDomains = $ADForest.Domains
    }
    Catch {
       Write-Log -Message "Failed to connect to forest: $Forest, $ErrorVar"
    }

    ## Process Forest domains with error handling
    ForEach ($Domain in $ADForestDomains) {
        Try {

            ## Show Domain progress bar
            $ProgressCounterDomain++
            $PercentCompleteDomain = (($ProgressCounterDomain / $ADForestDomains.Count) * 100)
            Write-Progress -Id 2 -Activity "Processing Domain: $Domain" -Status "$ProgressCounterDomain of $($ADForestDomains.Count) Forest Domains" -CurrentOperation "$PercentCompleteDomain% complete" -PercentComplete $PercentCompleteDomain

            ## Get domain computers
            $ADComputers = Get-ADComputer -Server $Domain -Filter {Enabled -eq $true} -Property * -ErrorVariable $ErrorVar | Select-Object Name, OperatingSystem, @{Name='Domain';Expression={$Domain}}

            ## Reset computer progress bar
            $ProgressCounterComputers = 0

            ## Export computers to CSV file
            ForEach ($Computer in $ADComputers) {

                ## Show Domain progress bar
                $ProgressCounterComputers++
                $PercentCompleteComputer = '{0:N0}' -f (($ProgressCounterComputers / $($ADComputers.Count)) * 100)
                Write-Progress -Id 3 -Activity "Processing Computer: $($Computer.Name)" -Status "$ProgressCounterComputers of $($ADComputers.Count) Domain Computers" -CurrentOperation "$PercentCompleteComputer% complete" -PercentComplete $PercentCompleteComputer

                ## Write Computer to CSV file
                $Computer | Export-Csv "$ResultPath\ADForestComputers.csv" -Delimiter ';' -Encoding 'UTF8' -NoTypeInformation -Append
            }
        }
        Catch {
            Write-Log -Message "No permissions to domain: $Domain, $ErrorVar"
        }

    }
}
Write-Log -Message "`nProcessing Finished!"

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================
