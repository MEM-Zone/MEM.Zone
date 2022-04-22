#!/bin/bash
#set -x

<<'#'
.SYNOPSIS
    Starts JAMF offboarding.
.DESCRIPTION
    Starts JAMF offboarding, removing certificates, profiles and binaries.
.EXAMPLE
    Start-JamfOffboarding.sh
.INPUTS
    None.
.OUTPUTS
    None.
.NOTES
    Created by Ioan Popovici
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
#

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

# User Defined variables
logname="Start-JamfOffboarding"
logdir="/Library/Logs/Visma IT/Start-JamfOffboarding"
companyportal = '/Applications/Company Portal.app/'

# Generated variables
tempdir=$(mktemp -d)
log="$logdir/$logname.log"

#endregion
##*=============================================
##* END VARIABLE DECLARATION
##*=============================================

##*=============================================
##* FUNCTION LISTINGS
##*=============================================
#region FunctionListings

#region Function startLog
function startLog() {
<<'#'
.SYNOPSIS
    Starts logging.
.DESCRIPTION
    Starts loggign to to log file and STDOUT.
.EXAMPLE
    startLog
.INPUTS
    None.
.OUTPUTS
    File.
    STDOUT.
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
#

    ## Creating log directory
    if [[ ! -d "$logdir" ]]; then
        echo "$(date) | Creating [$logdir] to store logs"
        sudo mkdir -p "$logdir"
    fi

    ## Start logging to log file
    exec &> >(sudo tee -a "$log")

    ## Write log header
    echo ""
    echo "##*================================================================================="
    echo "# $(date) | Logging run of [$logname] to log file"
    echo "# [$log]"
    echo "##*================================================================================="
    echo ""
}
#endregion

#region Function startJamfOffboarding
function startJamfOffboarding() {
<<'#'
.SYNOPSIS
    Starts JAMF offboarding.
.DESCRIPTION
    Starts JAMF offboarding, removing certificates, profiles and binaries.
.EXAMPLE
    startJamfOffboarding
.INPUTS
    None.
.OUTPUTS
    None.
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
#

    ## Quit Self-Service.
    echo "Stopping self Service Process..."
    killall "Self Service"
    echo ""

    ## Remove all system profiles
    echo "Removing System Profiles..."
    for identifier in $(/usr/bin/profiles -L | awk "/attribute/" | awk '{print $4}'); do
        /usr/bin/profiles -R -p "$identifier" >/dev/null 2>&1
        echo "System profile [$identifier] removed!"
    done
    if [[ ! $identifier ]]; then
        echo "Nothing to remove!"
    fi
    echo ""

    ## Remove MDM Profiles
    echo "Removing MDM Profiles..."
    sudo /usr/local/jamf/bin/jamf removeMdmProfile
    echo ""

    ## Remove JAMF Framework
    echo "Removing JAMF Binaries..."
    sudo /usr/local/jamf/bin/jamf removeFramework
    echo ""

    ## Remove Configuration Profiles
    echo "Removing Configuration Profiles..."
    profiles remove -forced -all -v
    echo ""

    ## Remove AD join
    echo "Unjoining from Active Directory!"
    dsconfigad -force -remove -u johndoe -p nopasswordhere
    echo ""
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

## Initiate logging
startLog

## If Company Portal is installed, continue, otherwise quit
if open -Ra "Company Portal" ; then
    echo 'The 'Company Portal' application is installed, continuing...'
else
    echo 'Please install the 'Company Portal' app in order to continue, aborting!'
    exit 1
fi

## Start JAMF Offboarding
startJamfOffboarding

## Start Company Portal
echo "Starting Company Portal..."
open -a /Applications/Company\ Portal.app

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================
