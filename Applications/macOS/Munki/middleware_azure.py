#!/usr/bin/env python

"""
Author: Oliver Kieselbach (oliverkieselbach.com)
Script: middleware_azure_sas.py

Description:
This module is meant to plug into munki as a middleware.
https://github.com/munki/munki/wiki

The script will use the Shared Access Signature from the blob storage account.

Configuration:
Defaults must be in place (replace with your account and example assumes containername = munki):

sudo defaults write /Library/Preferences/ManagedInstalls SoftwareRepoURL 'http://yourstorageaccount.blob.core.windows.net/munki'
sudo defaults write /Library/Preferences/ManagedInstalls SharedAccessSignature 'XXX'

Configuration via MDM profile (plist) is possible:
<key>SoftwareRepoURL</key>
<string>http://yourstorageaccount.blob.core.windows.net/munki</string>
<key>SharedAccessSignature</key>
<string>XXX</string>

Use Powershell output from below to convert the Shared Access Signature (SAS) to be correctly escaped for usage in xml MDM profile above:
[Security.SecurityElement]::Escape("?sp=r&st=2021-09-07T07:25:56Z&se=2025-09-07T15:25:56Z&spr=https&sv=2020-08-04&sr=c&sig=ThIsIsEnExAmPlEThIsIsEnExAmPlEThIsIsEnExAmPlE")

Check the macOS GitHub https://github.com/okieselbach/Intune/tree/master/macOS repo for a sample MDM .mobileconfig file.

Location:
copy to '/usr/local/munki/middleware_azure.py'

Permissions:
sudo chown root /usr/local/munki/middleware*.py
sudo chmod 600 /usr/local/munki/middleware*.py

Debugging:
log files for munki are stored here:
/Library/Managed Installs/Logs/

If required set LoggingLevel higher than 1 e.g. 2 or 3
sudo defaults write /Library/Preferences/ManagedInstalls LoggingLevel -int 3

Further reading:
If you are interested in a blog article detailing a bit more of the middleware in action with Microsoft Intune then have a look here:
https://oliverkieselbach.com/2021/07/14/comprehensive-guide-to-managing-macos-with-intune/

Release notes:
Version 1.0: 2021-09-07 - Original published version.

Credits and many thanks to @MaxXyzzy for triggering me to evaluate the SAS version once again.

The script is provided "AS IS" with no warranties.
"""

# pylint: disable=E0611
from Foundation import CFPreferencesCopyAppValue
# pylint: enable=E0611

__version__ = '1.0'
BUNDLE_ID = 'ManagedInstalls'


def pref(pref_name):
    # Return a preference. See munkicommon.py for details
    pref_value = CFPreferencesCopyAppValue(pref_name, BUNDLE_ID)
    return pref_value


SHARED_ACCESS_SIGNATURE = pref('SharedAccessSignature')
AZURE_ENDPOINT = pref('AzureEndpoint') or 'blob.core.windows.net'


def process_request_options(options):
    # This is the fuction that munki calls.
    if AZURE_ENDPOINT in options['url']:
        options['url'] = options['url'] + SHARED_ACCESS_SIGNATURE

    return options