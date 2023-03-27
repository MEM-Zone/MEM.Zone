#!/bin/bash
#set -x

#.SYNOPSIS
#    Unmanages JAMF devices in bulk.
#.DESCRIPTION
#    Unmanages JAMF devices in bulk, by sending the 'UnmanageDevice' command trough the JAMF API.
#.EXAMPLE
#    bulkUnmanageJAMFDevices.sh
#.NOTES
#    Created by Ioan Popovici
#    A JAMF search group needs to be created as a pre-requisite, with the devices you wish to unmanage, adding the serial number to the search display result so it can be queried by the script.
#    You then need to add the search group ID to the script. The script will then loop through the computer search group and send the 'UnanamgeDevice' command to the devices.
#    Return Codes:
#    0   - Success
#    10  - OS version not supported
#    11  - Company Portal application not installed
#    120 - Failed to display notification
#    130 - Failed to display dialog
#    131 - User cancelled dialog
#    140 - Failed to display alert
#    141 - User cancelled alert
#    150 - OS version not supported
#    200 - Failed to get JAMF API token
#    201 - Failed to invalidate JAMF API token
#    202 - Invalid JAMF API token action
#    210 - Failed to perform JAMF send command action
#    211 - Invalid JAMF device id
#.LINK
#    https://MEM.Zone
#.LINK
#    https://MEM.Zone/macOS-JAMF-Bulk-Unmanage
#.LINK
#    https://MEM.Zone/macOS-JAMF-Bulk-Unmanage-CHANGELOG
#.LINK
#    https://MEM.Zone/GIT
#.LINK
#    https://MEM.Zone/ISSUES

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

## User Defined variables
COMPANY_NAME='MEM.Zone IT'
DISPLAY_NAME='JAMF Bulk Unmanaging Tool'
#  Specify last supported OS major version
SUPPORTED_OS_MAJOR_VERSION=12
#  JAMF API MDM Removal.
JAMF_API_URL=''
JAMF_API_USER=''
JAMF_API_PASSWORD=''
#  JAMF Search Group ID. Please se notes above.
JAMF_SEARCH_GROUPID=''

## Script variables
#  Version
SCRIPT_VERSION=5.0.1
OS_VERSION=$(sw_vers -productVersion)
#  Author
AUTHOR='Ioan Popovici'
#  Script Name
SCRIPT_NAME=$(/usr/bin/basename "$0")
FULL_SCRIPT_NAME="$(realpath "$(dirname "${BASH_SOURCE[0]}")")/${SCRIPT_NAME}"
SCRIPT_NAME_WITHOUT_EXTENSION=$(basename "$0" | sed 's/\(.*\)\..*/\1/')
#  JAMF API Variables
BEARER_TOKEN=''
TOKEN_EXPIRATION_EPOCH=0
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

#region Function checkOSVersion

#region Function startLogging
#Assigned Error Codes: 110 - 119
function startLogging() {
#.SYNOPSIS
#    Starts logging.
#.DESCRIPTION
#    Starts loggign to to log file and STDOUT.
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
#    Specifies the subtitle of the notification. Defaults to $$MESSAGE_SUBTITLE.
#.PARAMETER notificationDelay
#    Specifies the minimum delay between the notifications in seconds. Defaults to 2.
#.PARAMETER supressNotification
#    Suppresses the notification. Defaults to false.
#.PARAMETER supressTerminal
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
    local supressTerminal
    local supressNotification
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
    #  Supress notification
    if [[ -z "${5}" ]]; then
        supressNotification='false'
    else supressNotification="${5}"
    fi
    #  Supress terminal
    if [[ -z "${6}" ]]; then
        supressTerminal='false'
    else supressTerminal="${6}"
    fi

    ## Debug variables
    #echo "messageText: $messageText; messageTitle: $messageTitle; messageSubtitle: $messageSubtitle; notificationDelay: $notificationDelay ; supressNotification: $supressNotification ; supressTerminal: $supressTerminal"

    ## Display notification
    if [[ "$supressNotification" = 'false' ]]; then
        osascript -e "display notification \"${messageText}\" with title \"${messageTitle}\" subtitle \"${messageSubtitle}\""
        executionStatus=$?
        sleep "$notificationDelay"
    fi

    ## Display notification in terminal
    if [[ "$supressTerminal" = 'false' ]]; then echo "$(date) | $messageText" ; fi

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
#    Specifies the subtitle of the notification. Defaults to $MESAGE_SUBTITLE.
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
#    Avaliable options:
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
#    Avaliable options:
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

#region Function invokeJamfApiTokenAction
#Assigned Error Codes: 200 - 209
function invokeJamfApiTokenAction() {
#.SYNOPSIS
#    Performs a JAMF API token action.
#.DESCRIPTION
#    Performs a JAMF API token action, such as getting, checking validity or invalidating a token.
#.PARAMETER apiUrl
#    Specifies the JAMF API server url.
#.PARAMETER apiUser
#    Specifies the JAMF API username.
#.PARAMETER apiPassword
#    Specifies the JAMF API password.
#.PARAMETER tokenAction
#    Specifies the action to perform.
#    Possible values: get, check, invalidate
#.EXAMPLE
#    invokeJamfApiTokenAction 'memzone@jamfcloud.com' 'jamf-api-user' 'strongpassword' 'get'
#.NOTES
#    Returns the token and the token expiration epoch in the global variables BEARER_TOKEN and TOKEN_EXPIRATION_EPOCH.
#    This is an internal script function and should typically not be called directly.
#.LINK
#    https://MEM.Zone
#.LINK
#    https://MEM.Zone/ISSUES
#.LINK
#    https://developer.jamf.com/reference/jamf-pro/

    ## Variable declarations
    local apiUrl
    local apiUser
    local apiPassword
    local tokenAction
    local response
    local responseCode
    local nowEpochUTC

    ## Set variable values
    if [[ -z "${1}" ]] || [[ -z "${2}" ]] || [[ -z "${3}" ]] ; then
        apiUrl="$JAMF_API_URL"
        apiUser="$JAMF_API_USER"
        apiPassword="$JAMF_API_PASSWORD"
    else
        apiUrl="${1}"
        apiUser="${2}"
        apiPassword="${3}"
    fi
    tokenAction="${4}"

    #region Inline Functions
    getBearerToken() {
        response=$(curl -s -u "$apiUser":"$apiPassword" "$apiUrl"/api/v1/auth/token -X POST)
        BEARER_TOKEN=$(echo "$response" | plutil -extract token raw -)
        tokenExpiration=$(echo "$response" | plutil -extract expires raw - | awk -F . '{print $1}')
        TOKEN_EXPIRATION_EPOCH=$(date -j -f "%Y-%m-%dT%T" "$tokenExpiration" +"%s")
        if [[ -z "$BEARER_TOKEN" ]] ; then
            displayNotification "Failed to get a valid API token!" '' '' '' 'suppressNotification'
            return 200
        else
            displayNotification "API token successfully retrieved!" '' '' '' 'suppressNotification'
        fi
    }

    checkTokenExpiration() {
        nowEpochUTC=$(date -j -f "%Y-%m-%dT%T" "$(date -u +"%Y-%m-%dT%T")" +"%s")
        if [[ TOKEN_EXPIRATION_EPOCH -gt nowEpochUTC ]] ; then
            displayNotification "API token valid until the following epoch time: $TOKEN_EXPIRATION_EPOCH" '' '' '' 'suppressNotification'
        else
            displayNotification "No valid API token available..." '' '' '' 'suppressNotification'
            getBearerToken
        fi
    }

    invalidateToken() {
        responseCode=$(curl -w "%{http_code}" -H "Authorization: Bearer ${BEARER_TOKEN}" "$apiUrl"/api/v1/auth/invalidate-token -X POST -s -o /dev/null)
        if [[ ${responseCode} == 204 ]] ; then
            displayNotification "Token successfully invalidated!" '' '' '' 'suppressNotification'
            BEARER_TOKEN=''
            TOKEN_EXPIRATION_EPOCH=0
        elif [[ ${responseCode} == 401 ]] ; then
            displayNotification "Token already invalid!" '' '' '' 'suppressNotification'
        else
            displayNotification "An unknown error occurred invalidating the token!" '' '' '' 'suppressNotification'
            return 201
        fi
    }
    #endregion

    ## Perform token action
    case "$tokenAction" in
        get)
            displayNotification "Getting new token..." '' '' '' 'suppressNotification'
            getBearerToken
            ;;
        check)
            displayNotification "Checking token validity..." '' '' '' 'suppressNotification'
            checkTokenExpiration
            ;;
        invalidate)
            displayNotification "Invalidating token..." '' '' '' 'suppressNotification'
            invalidateToken
            ;;
        *)
            displayNotification "Invalid token action '$tokenAction' specified! Terminating execution..."
            exit 202
            ;;
    esac
}
#endregion

#region Function invokeSendJamfCommand
#Assigned Error Codes: 210 - 219
function invokeSendJamfCommand() {
#.SYNOPSIS
#    Performs a JAMF API send command.
#.DESCRIPTION
#    Performs a JAMF API send command, with the specified command and device serial number.
#.PARAMETER apiUrl
#    Specifies the JAMF API server url.
#.PARAMETER apiUser
#    Specifies the JAMF API username.
#.PARAMETER apiPassword
#    Specifies the JAMF API password.
#.PARAMETER serialNumber
#    Specifies the device serial number.
#.PARAMETER command
#    Specifies the command to perform, keep in mind that you need to specify the command and the parameters in one string.
#.EXAMPLE
#    invokeSendJamfCommand 'memzone@jamfcloud.com' 'jamf-api-user' 'strongpassword' 'FVFHX12QQ6LY' 'UnmanageDevice'
#.EXAMPLE
#    invokeSendJamfCommand 'memzone@jamfcloud.com' 'jamf-api-user' 'strongpassword' 'FVFHX12QQ6LY' 'EraseDevice/passcode/123456'
#.NOTES
#    This is an internal script function and should typically not be called directly.
#.LINK
#    https://MEM.Zone
#.LINK
#    https://MEM.Zone/ISSUES
#.LINK
#    https://developer.jamf.com/reference/jamf-pro/

    ## Variable declarations
    local apiUrl
    local apiUser
    local apiPassword
    local command
    local serialNumber
    local deviceId
    local result

    ## Set variable values
    if [[ -z "${1}" ]] || [[ -z "${2}" ]] || [[ -z "${3}" ]] ; then
        apiUrl="$JAMF_API_URL"
        apiUser="$JAMF_API_USER"
        apiPassword="$JAMF_API_PASSWORD"
    else
        apiUrl="${1}"
        apiUser="${2}"
        apiPassword="${3}"
    fi
    serialNumber="${4}"
    command="${5}"

    ## Get API token
    invokeJamfApiTokenAction "$apiUrl" "$apiUser" "$apiPassword" 'get'

    ## Get JAMF device ID
    deviceId=$(curl --request GET \
        --url "${apiUrl}"/JSSResource/computers/serialnumber/"${serialNumber}"/subset/general \
        --header 'Accept: application/xml' \
        --header "Authorization: Bearer ${BEARER_TOKEN}" \
        --silent --show-error --fail | xmllint --xpath '//computer/general/id/text()' -
    )

    ## Perform action
    if [[ $deviceId -gt 0 ]]; then
       result=$(curl -s -o /dev/null -I -w "%{http_code}" \
            --request POST \
            --url "${apiUrl}"/JSSResource/computercommands/command/"${command}"/id/"${deviceId}" \
            --header 'Content-Type: application/xml' \
            --header "Authorization: Bearer ${BEARER_TOKEN}" \
        )
        ## Check result (201 = Created/Success)
        if [[ $result -eq 201 ]]; then
            displayNotification "Successfully performed command '${command}' on device '${serialNumber} [${deviceId}]'!" '' '' '' 'suppressNotification'
            return 0
        else
            displayNotification "Failed to perform command '${command}' on device '${serialNumber} [${deviceId}]'!" '' '' '' 'suppressNotification'
            return 210
        fi
    else
        displayNotification "Invalid device id '${deviceId} [${serialNumber}]'. Skipping '${command}'..." '' '' '' 'suppressNotification'
        return 211
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

## Check if script is running as root
runAsRoot "$FULL_SCRIPT_NAME"

## Start logging
startLogging "$LOG_NAME" "$LOG_DIR" "$LOG_HEADER"

## Show script version and suppress terminal output
displayNotification "Running $SCRIPT_NAME version $SCRIPT_VERSION" '' '' '' '' 'suppressTerminal'

## Check if OS is supported
checkSupportedOS "$SUPPORTED_OS_MAJOR_VERSION"

## Get API token
invokeJamfApiTokenAction "$apiUrl" "$apiUser" "$apiPassword" 'get'

## Get all devices in a specific advanced search group
computerList=$(curl --request GET \
    --url "https://visma.jamfcloud.com/JSSResource/advancedcomputersearches/id/${JAMF_SEARCH_GROUPID}" \
    --header 'Accept: application/xml' \
    --header "Authorization: Bearer ${BEARER_TOKEN}" \
    --silent --show-error --fail | xmllint --xpath '//Serial_Number/text() ' -
)

for computer in $computerList ; do
    invokeSendJamfCommand "$apiUrl" "$apiUser" "$apiPassword" "$computer" "UnmanageDevice"
done

## Invalidate API token
invokeJamfApiTokenAction "$apiUrl" "$apiUser" "$apiPassword" 'invalidate'

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================