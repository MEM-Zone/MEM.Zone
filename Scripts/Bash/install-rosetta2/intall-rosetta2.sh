#!/bin/bash
#set -x

#.SYNOPSIS
#    Installs Rosetta2.
#.DESCRIPTION
#    Installs Rosetta2 where applicable.
#.EXAMPLE
#    install-rosetta2.sh
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
COMPANY_NAME='Company Name'
DISPLAY_NAME='Display Name'

## Script variables
#  Version
SCRIPT_VERSION=1.0.0
OS_VERSION=$(sw_vers -productVersion)
#  Author
AUTHOR='Author Name'
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
#    Starts loggign to to log file and STDOUT.
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
#.PARAMETER supressTerminal
#    Suppresses the notification in the terminal. Defaults to false.
#.EXAMPLE
#    displayNotification "message" "title" "subtitle" "duration"
#.EXAMPLE
#    displayNotification "message" "title" "subtitle" '' 'true'
#.EXAMPLE
#    displayNotification "message"
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
    #  Supress terminal
    if [[ -z "${5}" ]]; then
        supressTerminal='false'
    else supressTerminal="${5}"
    fi

    ## Debug variables
    #echo "messageText: $messageText; messageTitle: $messageTitle; messageSubtitle: $messageSubtitle; messageDuration: $messageDuration"

    ## Display notification
    osascript -e "display notification \"${messageText}\" with title \"${messageTitle}\" subtitle \"${messageSubtitle}\""
    sleep "$messageDuration"

    ## Display notification in terminal
    if [[ "$supressTerminal" == 'false' ]]; then echo "$messageText" ; fi
}
#endregion

#region Function waitForProcess
function waitForProcess() {
#.SYNOPSIS
#    Waits for a process.
#.DESCRIPTION
#    Waits for a process to finish.
#.PARAMETER processName
#    Specifies the name of the process to check.
#.PARAMETER fixedDelay
#    Specifies the detection delay. If it's not specified a random amount of time between 10 and 60 seconds will be used.
#.PARAMETER terminate
#    Specify to wait for the process to finish or to terminate it imediately. Defaults to false.
#.EXAMPLE
#    waitForProcess '/usr/sbin/softwareupdate'
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
    local processName=$1
    local fixedDelay=$2
    local terminate=$3

    ## Debug variables
    #echo "processName: $processName; fixedDelay: $fixedDelay; terminate: $terminate"

    echo "Waiting for [$processName]..."
    while ps aux | grep "$processName" | grep -v grep &>/dev/null; do

        if [[ $terminate == 'true' ]]; then
            echo "Terminating [$processName]..."
            pkill -f "$processName"
            return
        fi

        # If we've been passed a delay we should use it, otherwise we'll create a random delay each run
        if [[ ! $fixedDelay ]]; then
            delay=$(( $RANDOM % 50 + 10 ))
        else
            delay=$fixedDelay
        fi

        echo "[$processName] is running, waiting [$delay] seconds"
        sleep $delay
    done
}
#endregion

#region Function installRosetta2
function installRosetta2() {
#.SYNOPSIS
#    Installs rosetta 2.
#.DESCRIPTION
#    Installs for rosetta 2 where applicable.
#.EXAMPLE
#    installRosetta2
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

    ## If Software update is already running, wait for it to finish
    waitForProcess "/usr/sbin/softwareupdate"

    ## Note, Rosetta detection code from https://derflounder.wordpress.com/2020/11/17/installing-rosetta-2-on-apple-silicon-macs/
    OLDIFS=$IFS
    IFS='.' read -r osvers_major osvers_minor osvers_dot_version <<< "$(/usr/bin/sw_vers -productVersion)"
    IFS=$OLDIFS

    if [[ ${osvers_major} -ge 11 ]]; then

        ## Check to see if the Mac needs Rosetta installed by testing the processor
        processor=$(/usr/sbin/sysctl -n machdep.cpu.brand_string | grep -o "Intel")

        if [[ -n "$processor" ]]; then
            echo "$processor processor installed. No need to install Rosetta."
        else

            ## Check for Rosetta "oahd" process. If not found, perform a non-interactive install of Rosetta.
            if /usr/bin/pgrep oahd >/dev/null 2>&1; then
                echo "Rosetta is already installed and running. Nothing to do."
            else
                /usr/sbin/softwareupdate –install-rosetta –agree-to-license

                if [[ $? -eq 0 ]]; then
                    echo "Rosetta has been successfully installed."
                else
                    echo "Rosetta installation failed!"
                    exit 1
                fi
            fi
        fi
    else
        echo "Mac is running macOS $osvers_major.$osvers_minor.$osvers_dot_version."
        echo "No need to install Rosetta on this version of macOS."
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
displayNotification "Running $SCRIPT_NAME version $SCRIPT_VERSION" '' '' '' 'true'

## Install Rosetta 2
installRosetta2

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================