#!/bin/bash
#set -x

#.SYNOPSIS
#    Starts Intune onboarding.
#.DESCRIPTION
#    Starts Intune onboarding, by installing pre-requisites and Intune Company Portal.
#    At reboot, the Intune Company Portal will start and the user will be prompted to sign in.
#.EXAMPLE
#    start-intune-onboarding.sh
#.NOTES
#    Created by David Natal
#    Revised by Ioan Popovici
#    Company Portal needs to be installed as a pre-requisite.
#    Return Codes:
#    0   - Success
#    5   - CPU Architecture not supported
#    10  - OS version not supported
#.LINK
#    https://MEM.Zone
#.LINK
#    https://MEMZ.one/Linux-Intune-Onboarding-Tool
#.LINK
#    https://MEMZ.one/Linux-Intune-Onboarding-Tool-CHANGELOG
#.LINK
#    https://MEMZ.one/Linux-Intune-Onboarding-Tool-GIT
#.LINK
#    https://MEM.Zone/ISSUES

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

## User Defined variables
COMPANY_NAME='MEM.Zone IT'
DISPLAY_NAME='Intune Onboarding Tool'
DOCUMENTATION_LINK='https://learn.microsoft.com/en-us/mem/intune/user-help/enroll-device-linux'
#  Specify last supported OS major version
SUPPORTED_OS_MAJOR_VERSION=20

## Script variables
#  Version
SCRIPT_VERSION=1.0.0
OS_VERSION=$(lsb_release -ds)
#  Cpu Architecture
CPU_ARCHITECTURE=$(lscpu | awk '/Architecture/ {print $2}')

#  Author
AUTHOR='Ioan Popovici'
#  Script Name
SCRIPT_NAME=$(/usr/bin/basename "$0")
FULL_SCRIPT_NAME="$(realpath "$(dirname "${BASH_SOURCE[0]}")")/${SCRIPT_NAME}"
SCRIPT_NAME_WITHOUT_EXTENSION=$(basename "$0" | sed 's/\(.*\)\..*/\1/')
#  Logging
LOG_NAME=$SCRIPT_NAME_WITHOUT_EXTENSION
LOG_DIR="/Library/Logs/${COMPANY_NAME}/${DISPLAY_NAME}"
LOG_HEADER="Script Version: $SCRIPT_VERSION \n# Author: $AUTHOR \n# OS Version: $OS_VERSION \n# CPU Architecture: $CPU_ARCHITECTURE \n"

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
        echo 'This application must be run as root. Please authenticate!'
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

#region Function checkSupportedOS
function checkSupportedOS() {
#.SYNOPSIS
#    Checks if the OS is supported.
#.DESCRIPTION
#    Checks if the OS is supported and exits if it is not.
#.PARAMETER supportedOSMajorVersion
#    Specify the major version of the OS to check.
#.EXAMPLE
#    checkSupportedOS '20'
#.NOTES
#    This is an internal script function and should typically not be called directly.
#.LINK
#    https://MEM.Zone
#.LINK
#    https://MEM.Zone/ISSUES

    ## Set human readable parameters
    local supportedOSMajorVersion="$1"

    ## Variable declaration
    local OSVersion
    local OSMajorVersion
    local cpuArchitecture

    ## Set variables
    OSVersion=$(lsb_release -rs)
    OSMajorVersion=$(echo "$OSVersion" | cut -d'.' -f1)
    OSName=$(lsb_release -ds)
    cpuArchitecture=$(lscpu | awk '/Architecture/ {print $2}')

    ## Check if CPU is supported
    if [[ "$cpuArchitecture" != "x86_64"   ]] ; then

        #  Display notification and alert
        echo "Unsupported CPU architecture '$cpuArchitecture', please upgrade. Terminating execution!"
        echo "CPU architecture needs to be 'x86_64'"
        exit 5
    fi

    ## Check if OS is supported
    if [[ "$OSMajorVersion" -lt "$supportedOSMajorVersion" ]] ; then

        #  Display notification and alert
        echo "Unsupported OS '$OSName', please upgrade. Terminating execution!"
        echo "OS needs to be at least 'Ubuntu ($supportedOSMajorVersion) LTS'"

        #  Forcefully install latest OS update
        sudo bash -c 'for i in update {,full-}upgrade auto{remove,clean}; do apt-get $i -y; done'
        exit 10
    else
        echo "Supported OS version '$OSName', continuing..."
        return 0
    fi
}
#endregion

#region Function installMsSigningPackage
function installMsSigningPackage() {
#.SYNOPSIS
#    Installs Microsoft Signing package for Ubuntu distributions.
#.DESCRIPTION
#    Installs Microsoft Signing package for Ubuntu distributions depending on version.
#.EXAMPLE
#    installMsSigningPackage
#.NOTES
#    This is an internal script function and should typically not be called directly.
#.LINK
#    https://MEM.Zone
#.LINK
#    https://MEM.Zone/ISSUES

    ## Variable declaration
    local osRelease
    local osCodeName

    ## Set variables
    osRelease=$(lsb_release -rs)
    osCodeName=$(lsb_release -c | grep -oP "Codename:\s+\K\w+")

    ## Install Microsoft Signing package depending on Ubuntu version
    sudo apt install curl gpg -y
    curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
    sudo install -o root -g root -m 644 microsoft.gpg /usr/share/keyrings/
    sudo sh -c "echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/ubuntu/$osRelease/prod $osCodeName main' > /etc/apt/sources.list.d/microsoft-ubuntu-$osCodeName-prod.list"
    sudo rm microsoft.gpg
}
#endregion

#region Function installMsEdge
function installMsEdge() {
#.SYNOPSIS
#    Installs Microsoft Edge package.
#.DESCRIPTION
#    Installs Microsoft Edge package for Ubuntu distributions.
#.EXAMPLE
#    installMsEdge
#.NOTES
#    This is an internal script function and should typically not be called directly.
#.LINK
#    https://MEM.Zone
#.LINK
#    https://MEM.Zone/ISSUES

    ## Variable declaration
    local edgeMajorVersion

    ## Set variables
    edgeMajorVersion=$(dpkg -l | grep -i "microsoft-edge-stable" | awk '{print $3}' | cut -d '.' -f 1)

    ## Install Microsoft Edge if not already installed
    if [[ $edgeMajorVersion -lt 102 ]]; then
        curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
        sudo install -o root -g root -m 644 microsoft.gpg /etc/apt/trusted.gpg.d/
        sudo sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/edge stable main" > /etc/apt/sources.list.d/microsoft-edge.list'
        sudo rm microsoft.gpg
        sudo apt update
        #  Add the missing GPG key if it's not available
        sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys EB3E94ADBE1229CF
        sudo apt-get update
        #  Install Microsoft Edge
        sudo apt install microsoft-edge-stable -y
    else
        echo "Microsoft Edge Web Browser version 102 or newer is already installed."
    fi
}
#endregion

#region Function installMsIntunePortal
function installMsIntunePortal() {
#.SYNOPSIS
#    Installs Microsoft Intune Portal package.
#.DESCRIPTION
#    Installs Microsoft Intune Portal package for Ubuntu distributions.
#.EXAMPLE
#    installMsIntunePortal
#.NOTES
#    This is an internal script function and should typically not be called directly.
#.LINK
#    https://MEM.Zone
#.LINK
#    https://MEM.Zone/ISSUES

    ## Variable declaration
    local appName
    local appExec

    ## Set variables
    appName="intune-portal"
    appExec="/opt/microsoft/intune/bin/intune-portal"

    ## Install Microsoft Edge
    installMsEdge

    ## Install Microsoft Intune Portal
    sudo apt-get install intune-portal -y

    ## Create desktop shortcut
    cat > intunestartup.desktop <<EOF
[Desktop Entry]
Name=${appName}
Exec=${appExec}
Type=Application
Terminal=false
EOF

## Move the desktop file to the appropriate directory
sudo mv intunestartup.desktop /usr/share/applications/

## Set execution permissions for the desktop file
sudo chmod +x /usr/share/applications/intunestartup.desktop

## Create a symbolic link in the autostart directory
sudo ln -s /usr/share/applications/intunestartup.desktop /etc/xdg/autostart/
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
echo "Running $SCRIPT_NAME version $SCRIPT_VERSION"

## Check if OS is supported
checkSupportedOS "$SUPPORTED_OS_MAJOR_VERSION"

## Initializing first repo sync so we get up to date packages
sudo apt update

## Install Microsoft Signing package
installMsSigningPackage

## Install Intune Portal app
installMsIntunePortal

## Workaround to mitigate disk encryption issues
consoleUser=$(who | awk 'NR==1{print $1}')
sudo usermod -a -G disk "$consoleUser"

## Reboot to start Intune Company Portal
sudo reboot

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================