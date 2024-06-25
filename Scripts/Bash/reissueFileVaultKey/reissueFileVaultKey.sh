#!/bin/bash
#set -x

#.SYNOPSIS
#    Reissues the FileVault key.
#.DESCRIPTION
#    Reissues the FileVault key with user interaction to allow MDM key management.
#.EXAMPLE
#    reissueFileVaultKey.sh
#.NOTES
#    Created by Ioan Popovici
#    Return Codes:
#    0   - Success
#    10  - OS version not supported
#    120 - Failed to display notification
#    130 - Failed to display dialog
#    131 - User cancelled dialog
#    140 - Failed to display alert
#    141 - User cancelled alert
#    150 - Invalid FileVault action
#    151 - Unauthorized FileVault user
#    152 - FileVault is already enabled
#    153 - FileVault is not enabled
#    155 - Failed to perform FileVault action
#    154 - User cancelled FileVault action
#.LINK
#    https://MEM.Zone
#.LINK
#    https://MEMZ.one/ReissueFileVaultKey
#.LINK
#    https://MEMZ.one/ReissueFileVaultKey-CHANGELOG
#.LINK
#    https://MEMZ.one/ReissueFileVaultKey-GIT
#.LINK
#    https://MEM.Zone/ISSUES

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

## User Defined variables
COMPANY_NAME='MEM.Zone IT'
DISPLAY_NAME='Reissue FileVault Key'
#  Specify last supported OS major version
SUPPORTED_OS_MAJOR_VERSION=12

## Script variables
#  Version
SCRIPT_VERSION=3.0.0
OS_VERSION=$(sw_vers -productVersion)
#  Author
AUTHOR='Ioan Popovici'
#  Script Name
SCRIPT_NAME=$(/usr/bin/basename "$0")
FULL_SCRIPT_NAME="$(realpath "$(dirname "${BASH_SOURCE[0]}")")/${SCRIPT_NAME}"
SCRIPT_NAME_WITHOUT_EXTENSION=$(basename "$0" | sed 's/\(.*\)\..*/\1/')
#  Messages
MESSAGE_TITLE=$COMPANY_NAME
MESSAGE_SUBTITLE=$DISPLAY_NAME
#  Logging
LOG_NAME=$SCRIPT_NAME_WITHOUT_EXTENSION
LOG_DIR="/Library/Logs/${COMPANY_NAME}/${DISPLAY_NAME}"
LOG_HEADER="Script Version: $SCRIPT_VERSION \n# Author: $AUTHOR \n# OS Version: $OS_VERSION \n"

#endregion
##*=============================================
##* END VARIABLE DECLARATION
##*=============================================

##*=============================================
##* FUNCTION LISTINGS
##*=============================================
#region FunctionListings

#region Function runAsRoot
#Assigned Error Codes: 100 - 109
function runAsRoot() {
#.SYNOPSIS
#    Checks for root privileges.
#.DESCRIPTION
#    Checks for root privileges and asks for elevation.
#.EXAMPLE
#    runAsRoot
#.NOTES
#    This is an internal script function and should typically not be called directly.
#.LINK
#    https://MEM.Zone
#.LINK
#    https://MEM.Zone/ISSUES

    ## Set human readable parameters
    local scriptPath="$1"

    ## Check if the script is run as root
    if [[ $EUID -ne 0 ]]; then
        displayNotification 'This application must be run as root. Please authenticate!'
        if [[ -t 1 ]]; then
            sudo "$scriptPath"
        else
            gksu "$scriptPath"
        fi
        exit 0
    fi
}
#endregion

#region Function startLogging
#Assigned Error Codes: 110 - 119
function startLogging() {
#.SYNOPSIS
#    Starts logging.
#.DESCRIPTION
#    Starts logging to to log file and STDOUT.
#.PARAMETER logName
#    Specifies the name of the log file.
#.PARAMETER logDir
#    Specifies the folder of the log file.
#.PARAMETER logHeader
#    Specifies additional header information to be added to the log file.
#.EXAMPLE
#    startLogging "logName" "logDir" "logHeader"
#.NOTES
#    This is an internal script function and should typically not be called directly.
#.LINK
#    https://MEM.Zone
#.LINK
#    https://MEM.Zone/ISSUES

    ## Set human readable parameters
    local logName="$1"
    local logDir="$2"
    local logHeader="$3"

    ## Set log file path
    logFullName="${logDir}/${logName}.log"

    ## Creating log directory
    if [[ ! -d "$logDir" ]]; then
        echo "$(date) | Creating '$logDir' to store logs"
        sudo mkdir -p "$logDir"
    fi

    ## Start logging to log file
    exec &> >(sudo tee -a "$logFullName")

    ## Write log header
    echo   ""
    echo   "##*====================================================================================="
    echo   "# $(date) | Logging run of '$logName' to log file"
    echo   "# Log Path: '$logFullName'"
    printf "# ${logHeader}"
    echo   "##*====================================================================================="
    echo   ""
}
#endregion

#region Function displayNotification
#Assigned Error Codes: 120 - 129
function displayNotification() {
#.SYNOPSIS
#    Displays a notification.
#.DESCRIPTION
#    Displays a notification to the user.
#.PARAMETER messageText
#    Specifies the message of the notification.
#.PARAMETER messageTitle
#    Specifies the title of the notification. Defaults to $MESSAGE_TITLE.
#.PARAMETER messageSubtitle
#    Specifies the subtitle of the notification. Defaults to $MESSAGE_SUBTITLE.
#.PARAMETER notificationDelay
#    Specifies the minimum delay between the notifications in seconds. Defaults to 2.
#.PARAMETER suppressNotification
#    Suppresses the notification. Defaults to false.
#.PARAMETER suppressTerminal
#    Suppresses the notification in the terminal. Defaults to false.
#.EXAMPLE
#    displayNotification 'message' 'title' 'subtitle' 'duration'
#.EXAMPLE
#    displayNotification 'message' 'title' 'subtitle' '' '' 'suppressTerminal'
#.EXAMPLE
#    displayNotification 'message' 'title' 'subtitle' '' 'suppressNotification' ''
#.EXAMPLE
#    displayNotification 'message'
#.NOTES
#    This is an internal script function and should typically not be called directly.
#.LINK
#    https://MEM.Zone
#.LINK
#    https://MEM.Zone/ISSUES

    ## Set human readable parameters
    local messageText
    local messageTitle
    local messageSubtitle
    local notificationDelay
    local suppressTerminal
    local suppressNotification
    local executionStatus=0
    #  Message
    messageText="${1}"
    #  Title
    if [[ -z "${2}" ]]; then
        messageTitle="${MESSAGE_TITLE}"
    else messageTitle="${2}"
    fi
    #  Subtitle
    if [[ -z "${3}" ]]; then
        messageSubtitle="${MESSAGE_SUBTITLE}"
    else messageSubtitle="${3}"
    fi
    #  Duration
    if [[ -z "${4}" ]]; then
        notificationDelay=2
    else notificationDelay="${4}"
    fi
    #  Suppress notification
    if [[ -z "${5}" ]]; then
        suppressNotification='false'
    else suppressNotification="${5}"
    fi
    #  Suppress terminal
    if [[ -z "${6}" ]]; then
        suppressTerminal='false'
    else suppressTerminal="${6}"
    fi

    ## Debug variables
    #echo "messageText: $messageText; messageTitle: $messageTitle; messageSubtitle: $messageSubtitle; notificationDelay: $notificationDelay ; suppressNotification: $suppressNotification ; suppressTerminal: $suppressTerminal"

    ## Display notification
    if [[ "$suppressNotification" = 'false' ]]; then
        osascript -e "display notification \"${messageText}\" with title \"${messageTitle}\" subtitle \"${messageSubtitle}\""
        executionStatus=$?
        sleep "$notificationDelay"
    fi

    ## Display notification in terminal
    if [[ "$suppressTerminal" = 'false' ]]; then echo "$(date) | $messageText" ; fi

    ## Return execution status
    if [[ "$executionStatus" -ne 0 ]]; then
        echo "$(date) | Failed to display notification. Error: '$executionStatus'"
        return 120
    fi
}
#endregion

#region Function displayDialog
#Assigned Error Codes: 130 - 139
function displayDialog() {
#.SYNOPSIS
#    Displays a dialog box.
#.DESCRIPTION
#    Displays a dialog box with customizable buttons and optional password prompt.
#.PARAMETER messageTitle
#    Specifies the title of the dialog. Defaults to $MESSAGE_TITLE.
#.PARAMETER messageText
#    Specifies the message of the dialog.
#.PARAMETER messageSubtitle
#    Specifies the subtitle of the notification. Defaults to $MESSAGE_SUBTITLE.
#.PARAMETER buttonNames
#    Specifies the names of the buttons. Defaults to '{Cancel, Ok}'.
#.PARAMETER defaultButton
#    Specifies the default button. Defaults to '1'.
#.PARAMETER cancelButton
#    Specifies the button to exit on. Defaults to ''.
#.PARAMETER messageIcon
#    Specifies the dialog icon as:
#       * 'stop', 'note', 'caution'
#       * the name of one of the system icons
#       * the resource name or ID of the icon
#       * the icon POSIX file path
#   Defaults to ''.
#.PARAMETER promptType
#    Specifies the type of prompt.
#    Available options:
#        'buttonPrompt'   - Button prompt.
#        'textPrompt'     - Text prompt.
#        'passwordPrompt' - Password prompt.
#    Defaults to 'buttonPrompt'.
#.EXAMPLE
#    displayDialog 'messageTitle' 'messageSubtitle' 'messageText' '{"Ok", "Agree"}' '1' '' '' 'buttonPrompt' 'stop'
#.EXAMPLE
#    displayDialog 'messageTitle' 'messageSubtitle' 'messageText' '{"Ok", "Stop"}' '1' 'Stop' '/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/FinderIcon.icns' 'textPrompt'
#.EXAMPLE
#    displayDialog 'messageTitle' 'messageSubtitle' 'messageText' "{\"Ok\", \"Don't Continue\"}" '1' "Don't Continue" '/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/FinderIcon.icns' 'passwordPrompt'
#.NOTES
#    This is an internal script function and should typically not be called directly.
#.LINK
#    https://MEM.Zone
#.LINK
#    https://MEM.Zone/ISSUES

    ## Set human readable parameters
    local messageTitle
    local messageSubtitle
    local messageText
    local buttonNames
    local defaultButton
    local cancelButton
    local messageIcon
    local promptType
    local commandOutput
    local executionStatus=0

    ## Set parameter values
    #  Title
    if [[ -z "${1}" ]] ; then
        messageTitle="${MESSAGE_TITLE}"
    else messageTitle="${1}"
    fi
    #  Subtitle
    if [[ -z "${2}" ]] ; then
        messageSubtitle="${MESSAGE_SUBTITLE}"
    else messageSubtitle="${2}"
    fi
    #  Message
    messageText="${3}"
    #  Button names
    if [[ -z "${4}" ]] ; then
        buttonNames='{"Cancel", "Ok"}'
    else buttonNames="${4}"
    fi
    #  Default button
    if [[ -z "${5}" ]] ; then
        defaultButton='1'
    else defaultButton="${5}"
    fi
    #  Cancel button
    if [[ -z "${6}" ]] ; then
        cancelButton=''
    else cancelButton="cancel button \"${6}\""
    fi
    #  Icon
    if [[ -z "${7}" ]] ; then
        messageIcon=''
    elif [[ "${7}" = *'/'* ]] ; then
        messageIcon="with icon POSIX file \"${7}\""
    else messageIcon="with icon ${7}"
    fi
    #  Prompt type
    case "${8}" in
        'buttonPrompt')
            promptType='buttonPrompt'
        ;;
        'textPrompt')
            promptType='textPrompt'
        ;;
        'passwordPrompt')
            promptType='passwordPrompt'
        ;;
        *)
            promptType='buttonPrompt'
        ;;
    esac

    ## Debug variables
    #echo "messageTitle: $messageTitle; messageSubtitle: $messageSubtitle; messageText: $messageText; buttonNames: $buttonNames; defaultButton: $defaultButton; cancelButton: $cancelButton; messageIcon: $messageIcon; promptType: $promptType"

    ## Display dialog box
    case "$promptType" in
        'buttonPrompt')
            #  Display dialog with no input. Returns button pressed.
            commandOutput=$(osascript -e "
                on run
                    display dialog \"${messageSubtitle}\n${messageText}\" with title \"${messageTitle}\" buttons ${buttonNames} default button ${defaultButton} ${cancelButton} ${messageIcon}
                    set commandOutput to button returned of the result
                    return commandOutput
                end run
            ")
            executionStatus=$?
        ;;
        'textPrompt')
            #  Display dialog with text input. Returns text.
            commandOutput=$(osascript -e "
                on run
                    display dialog \"${messageSubtitle}\n${messageText}\" default answer \"\" with title \"${messageTitle}\" with text and answer buttons ${buttonNames} default button ${defaultButton} ${cancelButton} ${messageIcon}
                    set commandOutput to text returned of the result
                    return commandOutput
                end run
            ")
            executionStatus=$?
        ;;
        'passwordPrompt')
            #  Display dialog with hidden password input. Returns text.
            commandOutput=$(osascript -e "
                on run
                    display dialog \"${messageSubtitle}\n${messageText}\" default answer \"\" with title \"${messageTitle}\" with text and hidden answer buttons ${buttonNames} default button ${defaultButton} ${cancelButton} ${messageIcon}
                    set commandOutput to text returned of the result
                    return commandOutput
                end run
            ")
            executionStatus=$?
        ;;
    esac

    ## Exit on error
    if [[ $commandOutput = *"Error"* ]] ; then
        displayNotification "Failed to display alert. Error: '$commandOutput'" '' '' '' 'suppressNotification'
        return 130
    fi

    ## Return cancel if pressed
    if [[ $executionStatus != 0 ]] ; then
        displayNotification "User cancelled dialog." '' '' '' 'suppressNotification'
        return 131
    fi

    ## Return commandOutput. Remember to assign the result to a variable, if you print it to the terminal, it will be logged.
    echo "$commandOutput"
}
#endregion

#region Function displayAlert
#Assigned Error Codes: 140 - 149
function displayAlert() {
#.SYNOPSIS
#    Displays a alert box.
#.DESCRIPTION
#    Displays a alert box with customizable buttons and icon.
#.PARAMETER alertText
#    Specifies the alert text.
#.PARAMETER messageText
#    Specifies the message text.
#.PARAMETER alertCriticality
#    Specifies the alert criticality.
#    Available options:
#        'informational' - Informational alert.
#        'critical'      - Critical alert.
#        'warning'       - Warning alert.
#    Defaults to 'informational'.
#.PARAMETER buttonNames
#    Specifies the names of the buttons. Defaults to '{Cancel, Ok}'.
#.PARAMETER defaultButton
#    Specifies the default button. Defaults to '1'.
#.PARAMETER cancelButton
#    Specifies the button to exit on. Defaults to ''.
#.PARAMETER givingUpAfter
#    Specifies the number of seconds to wait before dismissing the alert. Defaults to ''.
#.EXAMPLE
#   displayAlert 'alertText' 'messageText' 'critical' "{\"Don't Continue\", \"Dismiss Alert\"}" '1' "Don't Continue" '5'
#.NOTES
#    This is an internal script function and should typically not be called directly.
#.LINK
#    https://MEM.Zone
#.LINK
#    https://MEM.Zone/ISSUES

    ## Set human readable parameters
    local alertText
    local messageText
    local alertCriticality
    local buttonNames
    local defaultButton
    local cancelButton
    local givingUpAfter=''
    local commandOutput
    local executionStatus=0

    #  Alert text
    alertText="${1}"
    #  Message text
    messageText="${2}"
    #  Alert criticality
    case "${3}" in
        'informational')
            alertCriticality='as informational'
        ;;
        'critical')
            alertCriticality='as critical'
        ;;
        'warning')
            alertCriticality='as warning'
        ;;
        *)
            alertCriticality='informational'
        ;;
    esac
    #  Button names
    if [[ -z "${4}" ]] ; then
        buttonNames="{'Cance', 'Ok'}"
    else buttonNames="${4}"
    fi
    #  Default button
    if [[ -z "${5}" ]] ; then
        defaultButton='1'
    else defaultButton="${5}"
    fi
    #  Cancel button
    if [[ -z "${6}" ]] ; then
        cancelButton=''
    else cancelButton="cancel button \"${6}\""
    fi
    #  Giving up after
    if [[ -z "${7}" ]] ; then
        givingUpAfter=''
    else givingUpAfter="giving up after ${7}"
    fi

    ## Debug variables
    #echo "alertText: $alertText; messageText: $messageText; alertCriticality: $alertCriticality; buttonNames: $buttonNames; defaultButton: $defaultButton; cancelButton: $cancelButton; givingUpAfter: $givingUpAfter"

    ## Display the alert.
    commandOutput=$(osascript -e "
        on run
            display alert \"${alertText}\" message \"${messageText}\" ${alertCriticality} buttons ${buttonNames} default button ${defaultButton} ${cancelButton} ${givingUpAfter}
            set commandOutput to alert reply of the result
            return commandOutput
        end run
    ")
    executionStatus=$?

    ## Exit on error
    if [[ $commandOutput = *"Error"* ]] ; then
        displayNotification "Failed to display alert. Error: '$commandOutput'" '' '' '' 'suppressNotification'
        return 140
    fi

    ## Return cancel if pressed
    if [[ $executionStatus != 0 ]] ; then
        displayNotification "User cancelled alert." '' '' '' 'suppressNotification'
        return 141
    fi

    ## Return commandOutput. Remember to assign the result to a variable, if you print it to the terminal, it will be logged.
    echo "$commandOutput"
}
#endregion

#region Function invokeFileVaultAction
#Assigned Error Codes: 150 - 159
function invokeFileVaultAction() {
#.SYNOPSIS
#    Invokes a FileVault action.
#.DESCRIPTION
#    Invokes a FileVault action for the current user by prompting for the password, and populating answers for the fdesetup prompts.
#.PARAMETER action
#    Specify the action to invoke. Valid values are 'enable', 'disable', and 'reissueKey'.
#.EXAMPLE
#    invokeFileVaultAction 'enable'
#.EXAMPLE
#    invokeFileVaultAction 'disable'
#.EXAMPLE
#    invokeFileVaultAction 'reissueKey'
#.NOTES
#    This is an internal script function and should typically not be called directly.
#.LINK
#    https://github.com/jamf/FileVault2_Scripts/blob/master/reissueKey.sh (Original script and copyright notice)
#.LINK
#    https://MEM.Zone
#.LINK
#    https://MEM.Zone/ISSUES

    ## Variable declaration
    local fileVaultIcon
    local userName
    local userNameUUID
    local isFileVaultUser
    local isFileVaultOn
    local loopCounter=1
    local action
    local actionMessage
    local actionTitle
    local actionSubtitle
    local actionButtons
    local checkFileVaultStatus

    ## Set action
    case "$1" in
        'enable')
            action="$1"
            actionTitle='Enable FileVault'
            actionSubtitle='FileVault needs to be enabled!'
            actionButtons='{"Cancel", "Enable FileVault")'
            checkFileVaultStatus='On'
        ;;
        'disable')
            action="$1"
            actionTitle='Disable FileVault'
            actionSubtitle='FileVault needs to be disabled!'
            actionButtons='{"Cancel", "Disable FileVault"}'
            checkFileVaultStatus='Off'

        ;;
        'reissueKey')
            action='changerecovery -personal'
            actionTitle='Reissue FileVault Key'
            actionSubtitle='FileVault needs to reissue the key!'
            actionButtons='{"Cancel", "Reissue Key"}'
            checkFileVaultStatus='NotNeeded'
        ;;
        *)
            displayNotification "Invalid FileVault action '$1'. Skipping '$actionTitle'..." '' '' '' 'suppressNotification'
            exit 150
        ;;
    esac

    ## Set filevault icon
    fileVaultIcon='/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/FileVaultIcon.icns'

    ## Get the logged in user's name
    userName=$(/usr/bin/stat -f%Su /dev/console)

    ## Get the user's UUID
    userNameUUID=$(dscl . -read /Users/"$userName"/ GeneratedUID | awk '{print $2}')

    ## Check if user is an authorized FileVault user
    isFileVaultUser=$(fdesetup list | awk -v usrN="$userNameUUID" -F, 'match($0, usrN) {print $1}')
    if [ "${isFileVaultUser}" != "${userName}" ]; then
        displayNotification "${userName} is not a FileVault authorized user. Skipping '$actionTitle'..."
        exit 151
    fi

    ## Check to see if the encryption has finished
    isFileVaultOn=$(fdesetup status | grep "FileVault is On.")

    ## Check FileVault status
    if [ "$checkFileVaultStatus" = 'On' ]; then
        if [ -n "$isFileVaultOn" ]; then
            displayNotification "FileVault is already enabled. Skipping '$actionTitle'..."
            exit 152
        fi
    else
        if [ -z "$isFileVaultOn" ]; then
            displayNotification "FileVault is not enabled. Skipping '$actionTitle'..."
            exit 153
        fi
    fi

    ## Disable FileVault
    while true; do

        ## Get the logged in user's password via a prompt
        actionMessage="Enter $userName's password:"
        userPassword=$(displayDialog "$actionTitle" "$actionSubtitle" "$actionMessage" "$actionButtons" '2' 'Cancel' "$fileVaultIcon" 'passwordPrompt')

        ## Check if the user cancelled the prompt (return code 131)
        if [ $? = 131 ]; then
            displayNotification "User cancelled '$actionTitle' action!"
            exit 154
        fi

        displayNotification "Attempting FileVault action '$actionTitle'..." '' '' '1'

        ## Automatically populate answers for the fdesetup prompts
        output=$(
            expect -c "
            log_user 0
            spawn fdesetup $action
            expect \"Enter the user name:\"
            send {${userName}}
            send \r
            expect \"Enter a password for '/', or the recovery key:\"
            send {${userPassword}}
            send \r
            log_user 1
            expect eof
        ")

        if [[ $output = *'Error'* ]] || [[ $output = *'FileVault was not disabled'* ]] ; then
            displayNotification "Error performing FileVault action '$actionTitle' Attempt (${loopCounter}/3). $output"
            if [ $loopCounter -ge 3 ] ; then
                displayNotification "A maximum of 3 retries has been reached.\nContinuing without performing FileVault action '$action'..."
                exit 155
            fi
            ((loopCounter++))
        else
            displayNotification "Sucessfully performed FileVault action '$actionTitle'!"
            return 0
        fi
    done
}
#endregion

#region Function checkSupportedOS
#Assigned Error Codes: 150 - 159
function checkSupportedOS() {
#.SYNOPSIS
#    Checks if the OS is supported.
#.DESCRIPTION
#    Checks if the OS is supported and exits if it is not.
#.PARAMETER supportedOSMajorVersion
#    Specify the major version of the OS to check.
#.EXAMPLE
#    checkSupportedOS '13'
#.NOTES
#    This is an internal script function and should typically not be called directly.
#.LINK
#    https://MEM.Zone
#.LINK
#    https://MEM.Zone/ISSUES

    ## Set human readable parameters
    local supportedOSMajorVersion="$1"

    ## Variable declaration
    local macOSVersion
    local macOSMajorVersion
    local macOSAllLatestVersions
    local macOSSupportedName
    local macOSName

    ## Set variables
    macOSVersion=$(sw_vers -productVersion)
    macOSMajorVersion=$(echo "$macOSVersion" | cut -d'.' -f1)

    ## Set display notification and alert variables
    #  Get all supported OS versions
    macOSAllLatestVersions=$( (echo "<table>" ; curl -sfLS "https://support.apple.com/en-us/HT201260" \
        | tidy --tidy-mark no --char-encoding utf8 --wrap 0 --show-errors 0 --show-warnings no --clean yes --force-output yes --output-xhtml yes --quiet yes \
        | sed -e '1,/<table/d; /<\/table>/,$d' -e 's#<br />##g' ; echo "</table>" ) \
        | xmllint --html --xpath "//table/tbody/tr/td/text()" - 2>/dev/null
    )
    #  Get supported OS display name
    macOSSupportedName=$(echo "$macOSAllLatestVersions" | awk "/^${supportedOSMajorVersion}/{getline; print}")
    #  Get current installed OS display name
    macOSName=$(echo "$macOSAllLatestVersions" | awk "/^${macOSMajorVersion}/{getline; print}")

    ## Check if OS is supported
    if [[ "$macOSMajorVersion" -lt "$supportedOSMajorVersion" ]] ; then

        #  Display notification and alert
        displayNotification "Unsupported OS '$macOSName ($macOSVersion)', please upgrade. Terminating execution!"
        displayAlert "OS needs to be at least '$macOSSupportedName ($supportedOSMajorVersion)'" 'Please upgrade and try again!' 'critical' '{"Upgrade macOS"}'

        #  Forcefully install latest OS update
        sudo softwareupdate -i -a
        exit 150
    else
        displayNotification "Supported OS version '$macOSName ($macOSVersion)', continuing..."
        return 0
    fi
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

## Set script variables
alertNoteIcon='/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertNoteIcon.icns'
toolbarCustomizeIcon='/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ToolbarCustomizeIcon.icns'

## Check if script is running as root
runAsRoot "$FULL_SCRIPT_NAME"

## Start logging
startLogging "$LOG_NAME" "$LOG_DIR" "$LOG_HEADER"

## Show script version and suppress terminal output
displayNotification "Running $SCRIPT_NAME version $SCRIPT_VERSION" '' '' '' '' 'suppressTerminal'

## Check if OS is supported
checkSupportedOS "$SUPPORTED_OS_MAJOR_VERSION"

## Reissue FileVault Key
displayDialog '' 'Intune is unable to manage FileVault.' 'Please follow this process to remediate the issue.\n\nIf you have any questions or concerns, contact our Endpoint Management Team.' '{"Continue"}' '' '' "${toolbarCustomizeIcon}"
invokeFileVaultAction 'reissueKey'
displayDialog '' 'Intune is now able to manage FileVault.' '\nIf you have any questions or concerns, contact our Endpoint Management Team.' '{"Done"}' '' '' "${alertNoteIcon}"

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================