#!/bin/bash
#set -x

#.SYNOPSIS
#    Starts Intune onboarding.
#.DESCRIPTION
#    Starts Intune onboarding, converting mobile accounts, removing AD binding and JAMF management
#    and setting admin rights.
#.EXAMPLE
#    start-intune-onboarding.sh
#.INPUTS
#    None.
#.OUTPUTS
#    None.
#.NOTES
#    Created by Ioan Popovici
#    Company Portal needs to be installed as a pre-requisite.
#.LINK
#    https://MEM.Zone
#.LINK
#    https://MEM.Zone/macOS-Intune-Onboarding-Tool
#.LINK
#    https://MEM.Zone/GIT

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

## User Defined variables
COMPANY_NAME='MEM.Zone IT'
DISPLAY_NAME='Intune Onboarding Tool'
SUPPORT_LINK='https://google.com'
DOCUMENTATION_LINK='https://google.com'
COMPANY_PORTAL_PATH='/Applications/Company Portal.app/'
CONVERT_MOBILE_ACCOUNTS='YES'
REMOVE_FROM_AD='YES'
SET_ADMIN_RIGHTS='YES'
OFFBOARD_JAMF='YES'

## Script variables
#  Version
SCRIPT_VERSION=2.0.2
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

#region Function unbindFromAD
function unbindFromAD() {
#.SYNOPSIS
#    Unbinds device from AD.
#.DESCRIPTION
#     Unbinds device from AD and removes search paths.
#.EXAMPLE
#    unbindFromAD
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

    ## Variable declaration
    local searchPath
    local isAdJoined

    ## Check for AD binding and unbind if found.
    isAdJoined=$(/usr/bin/dscl localhost -list . | grep 'Active Directory')
    if [[ -z "$isAdJoined" ]]; then
        displayNotification 'Not bound to Active Directory...'
        return 1
    fi

    ## Display notification
    displayNotification 'Unbinding from Active Directory...'

    ## Set search path
    searchPath=$(/usr/bin/dscl /Search -read . CSPSearchPath | grep Active\ Directory | sed 's/^ //')

    ## Force unbind from Active Directory
    /usr/sbin/dsconfigad -remove -force -u none -p none

    ## Delete the Active Directory domain from the custom /Search and /Search/Contacts paths
    /usr/bin/dscl /Search/Contacts -delete . CSPSearchPath "$searchPath"
    /usr/bin/dscl /Search -delete . CSPSearchPath "$searchPath"

    ## Change the /Search and /Search/Contacts path type from Custom to Automatic
    /usr/bin/dscl /Search -change . SearchPolicy dsAttrTypeStandard:CSPSearchPath dsAttrTypeStandard:NSPSearchPath
    /usr/bin/dscl /Search/Contacts -change . SearchPolicy dsAttrTypeStandard:CSPSearchPath dsAttrTypeStandard:NSPSearchPath
}
#endregion

#region Function migrateUserPassword
function migrateUserPassword() {
#.SYNOPSIS
#    Migrates the user password to the local account.
#.DESCRIPTION
#    Migrates the user password to the local account by removing the Kerberos and LocalCachedUser user values from the AuthenticationAuthority array.
#.PARAMETER userName
#    Specifies the name of the user.
#.EXAMPLE
#    migrateUserPassword "username"
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

    ## Set human readable variables
    local userName="${1}"

    # Variable declaration
    local AuthenticationAuthority
    local Kerberosv5
    local localCachedUser

    ## Display notification
    displayNotification "Migrating $userName password..."

    # macOS 10.14.4 will remove the the actual ShadowHashData key immediately if the AuthenticationAuthority array value which references the ShadowHash is removed from the AuthenticationAuthority array.
    # To address this, the existing AuthenticationAuthority array will be modified to remove the Kerberos and LocalCachedUser user values.

    ## Get AuthenticationAuthority
    AuthenticationAuthority=$(/usr/bin/dscl -plist . -read /Users/"$userName" AuthenticationAuthority)

    ## Get Kerberosv5 and LocalCachedUser
    Kerberosv5=$(echo "${AuthenticationAuthority}" | xmllint --xpath 'string(//string[contains(text(),"Kerberosv5")])' -)
    localCachedUser=$(echo "${AuthenticationAuthority}" | xmllint --xpath 'string(//string[contains(text(),"LocalCachedUser")])' -)

    ## Remove Kerberosv5 value
    if [[ -n "${Kerberosv5}" ]]; then
        /usr/bin/dscl -plist . -delete /Users/"$userName" AuthenticationAuthority "${Kerberosv5}"
    fi

    ## Remove LocalCachedUser value
    if [[ -n "${localCachedUser}" ]]; then
        /usr/bin/dscl -plist . -delete /Users/"$userName" AuthenticationAuthority "${localCachedUser}"
    fi
}
#endregion

#region Function convertMobileAccount
function convertMobileAccount() {
#.SYNOPSIS
#    Converts mobile account to local account.
#.DESCRIPTION
#    Converts mobile account to local account, by removing mobile account properties and  migrating the user password to the local account.
#.PARAMETER userName
#    Specifies the name of the user.
#.PARAMETER makeAdmin
#    Specifies whether the user should be made a local admin.
#.EXAMPLE
#    convertMobileAccount "username" "YES"
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
    local userName="${1}"
    local makeAdmin="${2}"

    ## Variable declaration
    local accountType
    local isMobileUser
    local attributesToRemove
    local attributeToRemove
    local homeDirectory

    ## Set variable values
    attributesToRemove=(
        cached_groups
        cached_auth_policy
        CopyTimestamp
        AltSecurityIdentities
        SMBPrimaryGroupSID
        OriginalAuthenticationAuthority
        OriginalNodeName
        SMBSID
        SMBScriptPath
        SMBPasswordLastSet
        SMBGroupRID
        PrimaryNTDomain
        AppleMetaRecordName
        MCXSettings
        MCXFlags
    )

    ## Get account type
    accountType=$(/usr/bin/dscl . -read /Users/"$userName" AuthenticationAuthority | head -2 | awk -F'/' '{print $2}' | tr -d '\n')

    ## Check if account is a mobile account
    if [[ "$accountType" = "Active Directory" ]]; then
        isMobileUser=$(/usr/bin/dscl . -read /Users/"$userName" AuthenticationAuthority | head -2 | awk -F'/' '{print $1}' | tr -d '\n' | sed 's/^[^:]*: //' | sed s/\;/""/g)
        if [[ "$isMobileUser" = "LocalCachedUser" ]]; then
            displayNotification "Converting $userName to a local account..."
        fi
    else
        /usr/bin/printf "The $userName account is not a AD mobile account\n"
        return
    fi

    ## Remove the account attributes that identify it as an Active Directory mobile account
    for attributeToRemove in "${attributesToRemove[@]}"; do
        if [[ ! $(/usr/bin/dscl . -delete /users/"$userName" "$attributeToRemove") ]]; then
            displayNotification "Failed to remove account attribute ${attributeToRemove}"
        fi
    done

    ## Migrate password
    migrateUserPassword "$userName"

    ## Refresh Directory Services
    /usr/bin/killall opendirectoryd
    sleep 20

    ## Check if account is a mobile account
    accountType=$(/usr/bin/dscl . -read /Users/"$userName" AuthenticationAuthority | head -2 | awk -F'/' '{print $2}' | tr -d '\n')
    if [[ "$accountType" = "Active Directory" ]]; then
        displayNotification "Error converting the $userName account! Exiting..."
        exit 1
    else
        displayNotification "$userName was successfully converted to a local account."
    fi

    ## Update home folder and permissions for the account. This could take a while.
    homeDirectory=$(/usr/bin/dscl . -read /Users/"$userName" NFSHomeDirectory | awk '{print $2}')
    if [[ "$homeDirectory" != "" ]]; then
        displayNotification "Updating $homeDirectory permissions for the $userName account, this could take a while..."
        /usr/sbin/chown -R "$1" "$homeDirectory"
    fi

    ## Add user to the staff group on the Mac
    displayNotification "Adding $userName to the staff group..."
    /usr/sbin/dseditgroup -o edit -a "$userName" -t user staff

    ## Add user to the admin group on the Mac
    if [[ "$makeAdmin" = "YES" ]]; then
        displayNotification "Granting admin rights to $userName..."
        /usr/sbin/dseditgroup -o edit -a "$userName" -t user admin
    fi
}
#endregion

#region Function startJamfOffboarding
function startJamfOffboarding() {
#.SYNOPSIS
#    Starts JAMF offboarding.
#.DESCRIPTION
#    Starts JAMF offboarding, removing certificates, profiles and binaries.
#.EXAMPLE
#    startJamfOffboarding
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

    ## Check if JAMF binaries are present
    hasJamfBinaries=$(which jamf)
    if [[ -z "$hasJamfBinaries" ]]; then
        displayNotification "JAMF binaries are not present on this Mac..."
        return 1
    fi

    ## Display notification
    displayNotification 'JAMF offboarding has started...'

    ## Get current user
    currentUser=$(stat -f '%Su' /dev/console)

    ## Quit Self-Service.
    displayNotification 'Stopping self Service Process...'
    killall "Self Service"

    ## Remove all system profiles
    displayNotification 'Removing System Profiles...'
    for identifier in $(/usr/bin/profiles -L | awk '/attribute/' | awk '{print $4}'); do
        sudo -u "$currentUser" profiles -R -p "$identifier" >/dev/null 2>&1
        echo "System profile [$identifier] removed!"
    done
    if [[ ! $identifier ]]; then
        echo "Nothing to remove!"
    fi

    ## Remove MDM Profiles
    displayNotification 'Removing MDM Profiles...'
    jamf removeMdmProfile

    ## Remove JAMF Framework
    displayNotification 'Removing JAMF Framework...'
    jamf removeFramework

    ## Remove Configuration Profiles
    displayNotification 'Removing Configuration Profiles...'
    sudo -u "$currentUser" profiles remove -forced -all -v

    ## Display notification
    displayNotification 'JAMF Offboarding is complete!'
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

## If Company Portal is installed, continue, otherwise quit
if open -Ra 'Company Portal'; then
    displayNotification 'Company Portal application is installed, continuing...'
else
    echo 'Company Portal is not installed, contact service desk!'
    displayNotification 'Company Portal application not installed, contact support!'
        osascript -e 'display alert "Error installing Company Portal app. \n \nIn order to continue, contact support!" buttons {"Contact Support"} as critical'
    open "$SUPPORT_LINK"
    exit 1
fi

## Unbind from AD
if [[ $REMOVE_FROM_AD = 'YES' ]] ; then unbindFromAD ; fi

## Convert mobile accounts to local accounts
if [[ $CONVERT_MOBILE_ACCOUNTS = 'YES' ]] ; then
    localUsers=$(/usr/bin/dscl . list /Users UniqueID | awk '$2 > 1000 {print $1}')
    for localUser in $localUsers; do
        convertMobileAccount "$localUser" "$SET_ADMIN_RIGHTS"
    done
fi

## Offboard JAMF
if [[ $OFFBOARD_JAMF = 'YES' ]] ; then startJamfOffboarding ; fi

## Start Company Portal
displayNotification 'Starting Company Portal...'
open -a "$COMPANY_PORTAL_PATH"

## Display documentation
displayNotification 'Displaying documentation...'
open -gj "${DOCUMENTATION_LINK}"

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================