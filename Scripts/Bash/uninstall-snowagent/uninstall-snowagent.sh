#!/bin/bash
#set -x

#.SYNOPSIS
#    Uninstalls snow agent.
#.DESCRIPTION
#    Uninstalls snow agent by running a specific uninstall procedure.
#.EXAMPLE
#    uninstall-snowagent.sh
#.INPUTS
#    None.
#.OUTPUTS
#    None.
#.NOTES
#    Created by Ioan Popovici
#.LINK
#    https://MEM.Zone
#.LINK
#    https://MEM.Zone/GIT

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

## User Defined variables
COMPANY_NAME='MEM.Zone'
DISPLAY_NAME='Snow Agent Uninstall'

## Script variables
#  Version
SCRIPT_VERSION=1.0.0
OS_VERSION=$(sw_vers -productVersion)
#  Author
AUTHOR='Ioan Popovici'
#  Script Name
SCRIPT_NAME=$(/usr/bin/basename "$0")
FULL_SCRIPT_NAME="$(realpath "$(dirname "${BASH_SOURCE[0]}")")/${SCRIPT_NAME}"
SCRIPT_NAME_WITHOUT_EXTENSION=$(basename "$0" | sed 's/\(.*\)\..*/\1/')
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
function runAsRoot() {
#.SYNOPSIS
#    Checks for root privileges.
#.DESCRIPTION
#    Checks for root privileges and asks for elevation.
#.EXAMPLE
#    runAsRoot
#.INPUTS
#    None.
#.OUTPUTS
#    None.
#.NOTES
#    This is an internal script function and should typically not be called directly.
#.LINK
#    https://MEM.Zone
#.LINK
#    https://MEM.Zone/GIT

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
        exit
    fi
}
#endregion

#region Function startLogging
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
#    startLogging "logName" "logDir"
#.INPUTS
#    None.
#.OUTPUTS
#    File.
#    STDOUT.
#.NOTES
#    This is an internal script function and should typically not be called directly.
#.LINK
#    https://MEM.Zone
#.LINK
#    https://MEM.Zone/GIT

    ## Set human readable parameters
    local logName="$1"
    local logDir="$2"
    local logHeader="$3"

    ## Set log file path
    logFullName="${logDir}/${logName}.log"

    ## Creating log directory
    if [[ ! -d "$logDir" ]]; then
        echo "$(date) | Creating [$logDir] to store logs"
        sudo mkdir -p "$logDir"
    fi

    ## Start logging to log file
    exec &> >(sudo tee -a "$logFullName")

    ## Write log header
    echo   ""
    echo   "##*====================================================================================="
    echo   "# $(date) | Logging run of [$logName] to log file"
    echo   "# Log Path: [$logFullName]"
    printf "# ${logHeader}"
    echo   "##*====================================================================================="
    echo   ""
}
#endregion

#region Function displayNotification
function displayNotification() {
#.SYNOPSIS
#    Displays a notification.
#.DESCRIPTION
#    Displays a notification to the user.
#.PARAMETER messageText
#    Specifies the message of the notification.
#.PARAMETER messageTitle
#    Specifies the title of the notification. Defaults to $messageTitle.
#.PARAMETER messageSubtitle
#    Specifies the subtitle of the notification. Defaults to $messageSubtitle.
#.PARAMETER messageDuration
#    Specifies the minimum duration of the notification in seconds. Defaults to 2.
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
#.INPUTS
#    None.
#.OUTPUTS
#    None.
#.NOTES
#    This is an internal script function and should typically not be called directly.
#.LINK
#    https://MEM.Zone
#.LINK
#    https://MEM.Zone/GIT

    ## Set human readable parameters
    local messageText
    local messageTitle
    local messageSubtitle
    local messageDuration
    local suppressTerminal
    local suppressNotification
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
        messageDuration=2
    else messageDuration="${4}"
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
    #echo "messageText: $messageText; messageTitle: $messageTitle; messageSubtitle: $messageSubtitle; messageDuration: $messageDuration ; suppressNotification: $suppressNotification ; suppressTerminal: $suppressTerminal"

    ## Display notification
    if [[ "$suppressNotification" == 'false' ]]; then
        osascript -e "display notification \"${messageText}\" with title \"${messageTitle}\" subtitle \"${messageSubtitle}\""
        sleep "$messageDuration"
    fi

    ## Display notification in terminal
    if [[ "$suppressTerminal" == 'false' ]]; then echo "$(date) | $messageText" ; fi
}
#endregion


#region Function startSnowAgentUninstall
function startSnowAgentUninstall() {
#.SYNOPSIS
#    Starts snow agent uninstall.
#.DESCRIPTION
#    Starts snow agent uninstall, removing binaries and launch daemons.
#.EXAMPLE
#    startSnowAgentUninstall
#.INPUTS
#    None.
#.OUTPUTS
#    None.
#.NOTES
#    This is an internal script function and should typically not be called directly.
#.LINK
#    https://MEM.Zone
#.LINK
#    https://MEM.Zone/GIT

    ## Check if Snow Agent is installed
    isSnowInstalled=$(pkgutil --pkgs=com.snowsoftware.snowagent)
    if [ -z "$isSnowInstalled" ]; then
        displayNotification 'Snow Agent is not installed! Skipping uninstall...' '' '' '' 'skipNotification'
        exit 0
    fi

    ## Stop Snow Agent
    displayNotification 'Stopping Snow Agent...' '' '' '' 'skipNotification'
    launchctl unload /Library/LaunchDaemons/com.snowsoftware.Inventory.plist
    launchctl unload /Library/LaunchDaemons/com.snowsoftware.Metering.plist
    launchctl unload /Library/LaunchDaemons/com.snowsoftware.Cloudmetering.plist

    ## Remove Snow Agent
    displayNotification 'Removing Snow Agent...' '' '' '' 'skipNotification'
    rm -fR /opt/snow
    rm /Library/LaunchDaemons/com.snowsoftware.Inventory.plist
    rm /Library/LaunchDaemons/com.snowsoftware.Metering.plist
    rm /Library/LaunchDaemons/com.snowsoftware.Cloudmetering.plist
    pkgutil --forget com.snowsoftware.snowagent
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

## Start snow agent uninstall
startSnowAgentUninstall

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================
