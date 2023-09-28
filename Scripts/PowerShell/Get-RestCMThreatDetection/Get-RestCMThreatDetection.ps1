<#
.SYNOPSIS
    Gets the threat detection data from Configuration Manager.
.DESCRIPTION
    Gets the threat detection data from Configuration Manager using the Admin Service REST API.
.PARAMETER ProviderFQDN
    The FQDN of the Configuration Manager SMS provider.
.PARAMETER DaysAgo
    The number of days to go back in time to get the threat detection data.
    Default is: '360' days.
.EXAMPLE
    Get-RestCMThreatDetection.ps1 -ProviderFQDN 'CM01.contoso.com' -DaysAgo 7
.INPUTS
    None.
.OUTPUTS
    System.Object
.NOTES
    Created by Ioan Popovici
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    Configuration Manager
.FUNCTIONALITY
    Gets the threat detection data
#>

## Set script requirements
#Requires -Version 3.0

<#[CmdletBinding()]
Param (
    [Parameter(Mandatory = $true, HelpMessage = 'SMSProvider FQDN:', Position = 0)]
    [ValidateNotNullorEmpty()]
    [Alias('Provider')]
    [string]$ProviderFQDN,
    [Parameter(Mandatory = $false, Position = 1)]
    [ValidateNotNullorEmpty()]
    [Alias('Days')]
    [int16]$DaysAgo = 360
)
#>

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

#endregion
##*=============================================
##* END VARIABLE DECLARATION
##*=============================================

##*=============================================
##* FUNCTION LISTINGS
##*=============================================
#region FunctionListings

#region Function Get-RestCMThreatDetection
Function Get-RestCMThreatDetection {
    <#
    .SYNOPSIS
        Gets the threat detection data from Configuration Manager.
    .DESCRIPTION
        Gets the threat detection data from Configuration Manager using the Admin Service REST API.
    .PARAMETER ProviderFQDN
        The FQDN of the Configuration Manager SMS provider.
    .PARAMETER DaysAgo
        The number of days to go back in time to get the threat detection data.
        Default is: '360' days.
    .EXAMPLE
        Get-RestCMThreatDetection -ProviderFQDN ' -ProviderFQDN 'CM01.contoso.com' -DaysAgo 7
    .INPUTS
        None.
    .OUTPUTS
        System.Object.
    .NOTES
        Created by Ioan Popovici
    .LINK
        https://MEM.Zone
    .LINK
        https://MEM.Zone/ISSUES
    .COMPONENT
        Configuration Manager
    .FUNCTIONALITY
        Gets the threat detection data
    #>
        [CmdletBinding()]
        Param (
            [Parameter(Mandatory = $true, HelpMessage = 'SMSProvider FQDN:', Position = 0)]
            [ValidateNotNullorEmpty()]
            [Alias('Provider')]
            [string]$ProviderFQDN,
            [Parameter(Mandatory = $false, Position = 1)]
            [ValidateNotNullorEmpty()]
            [Alias('Days')]
            [int16]$DaysAgo = 360
        )

        Begin {

            ## Set history threshold
            [datetime]$Date = (Get-Date).AddDays(-$DaysAgo)
            #  Set EDM date format
            [string]$EdmDate = Get-Date -Format 'yyyy-MM-ddThh:mm.ssZ' $Date
            #  Set the date filter
            $Filter = "DetectionTime ge $EdmDate"

            ## Assemble the URI
            $Uri = 'https://{0}/AdminService/wmi/SMS_G_System_Threats?$filter={2}' -f $ProviderFQDN, $Table, $Filter

            ## Set Column Mappings
            #  Category
            [hashtable]$CategoryMapping = @{
                1 = 'Adware'
                2 = 'Spyware'
                3 = 'Password Stealer'
                4 = 'Trojan Downloader'
                5 = 'Worm'
                6 = 'Backdoor'
                8 = 'Trojan'
                9 = 'Email Flooder'
                11 = 'Dialer'
                12 = 'Monitoring Software'
                13 = 'Browser Modifier'
                19 = 'Joke Program'
                21 = 'Software Bundler'
                22 = 'Trojan Notifier'
                23 = 'Settings Modifier'
                27 = 'Potentially Unwanted Software'
                30 = 'Exploit'
                32 = 'Malware Creation Tool'
                33 = 'Remote Control Software'
                34 = 'Tool'
                36 = 'Trojan Denial of Service'
                37 = 'Trojan Dropper'
                39 = 'Trojan Monitoring Software'
                40 = 'Trojan Proxy Server'
                42 = 'Virus'
                43 = 'Permitted'
                44 = 'Not Yet Classified'
                46 = 'Suspicious Behavior'
                49 = 'Enterprise Unwanted Software'
                50 = 'Ransomware'
            }
            #  DetectionSource
            [hashtable]$DetectionSourceMapping = @{
                1 = 'User'
                2 = 'System'
                3 = 'Realtime'
                4 = 'IOAV'
                5 = 'NIS'
                6 = 'BHO'
                7 = 'ELAM'
                8 = 'Local Attestation'
                9 = 'Remote Attestation'
                10 = 'AMSI'
                11 = 'UAC'
            }
            #  ExecutionStatus
            [hashtable]$ExecutionStatusMapping = @{
                0 = 'Unknown'
                1 = 'Blocked'
                2 = 'Allowed'
                3 = 'Executing'
                4 = 'NotExecuting'
            }
            #  CleaningAction
            [hashtable]$CleaningActionMapping = @{
                0 = 'Unknown'
                1 = 'Clean'
                2 = 'Quarantine'
                3 = 'Remove'
                6 = 'Allow'
                8 = 'UserDefined'
                9 = 'NoAction'
                10 = 'Block'
            }
            #  Severity
            [hashtable]$SeverityMapping = @{
                0 = 'Not Yet Classified'
                1 = 'Low'
                2 = 'Medium'
                4 = 'High'
                5 = 'Severe'
            }
            #  PendingActions bitmask
            [Flags()]Enum PendingActionsBitmask {
                None                = 0
                FullScanRequired    = 2
                RebootRequired      = 3
                ManualStepsRequired = 4
                OfflineScanRequired = 15
            }
        }
        Process {
            Try {

                ## Get the threat data
                $Threats = (Invoke-RestMethod -Method 'Get' -Uri $Uri -UseDefaultCredentials -ErrorAction 'Stop').Value

                ## Loop through the threats and map set the values from the mapping tables
                $Output = ForEach ($Threat in $Threats) {
                    [string]$Category                      = $CategoryMapping[$Threat.CategoryID]
                    [string]$DetectionSource               = $DetectionSourceMapping[$Threat.DetectionSource]
                    [string]$ExecutionStatus               = $ExecutionStatusMapping[$Threat.ExecutionStatus]
                    [string]$CleaningAction                = $CleaningActionMapping[$Threat.CleaningAction]
                    [PendingActionsBitmask]$PendingActions = $Threat.PendingActions
                    [string]$Severity                       = $SeverityMapping[$Threat.SeverityID]
                    [string]$Uri                           = 'https://{0}/AdminService/wmi/SMS_R_System({1})' -f $ProviderFQDN, $Threat.ResourceId
                    [string]$Device                        = (Invoke-RestMethod -Method 'Get' -Uri $Uri -UseDefaultCredentials -ErrorAction 'Stop').Value.Name

                    [PSCustomObject]@{
                        GUID            = (New-Guid).Guid
                        ActionSuccess   = $Threat.ActionSuccess
                        ActionTime      = $Threat.ActionTime
                        Category        = $Category
                        CleaningAction  = $CleaningAction
                        DetectionId     = $Threat.DetectionId
                        DetectionSource = $DetectionSource
                        DetectionTime   = $Threat.DetectionTime
                        ErrorCode       = $Threat.ErrorCode
                        ExecutionStatus = $ExecutionStatus
                        Path            = $Threat.Path
                        PendingActions  = $PendingActions
                        Process         = $Threat.Process
                        ProductVersion  = $Threat.ProductVersion
                        ResourceId      = $Threat.ResourceId
                        Device          = $Device
                        Severity        = $Severity
                        ThreatID        = $Threat.ThreatID
                        ThreatName      = $Threat.ThreatName
                        UserName        = $Threat.UserName
                    }
                }
            }
            Catch {
                $PSCmdlet.ThrowTerminatingError($PSItem)
            }
            Finally {
                Write-Output -InputObject $Output
            }
        }
        End {
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

        Get-RestCMThreatDetection -ProviderFQDN 'VIT-MEM-PSS-001.ADM.DATAKRAFTVERK.NO' -DaysAgo 360

    #endregion
    ##*=============================================
    ##* END SCRIPT BODY
    ##*=============================================
