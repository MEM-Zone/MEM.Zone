<#
.SYNOPSIS
    Gets the details of a specific certificate.
.DESCRIPTION
    Gets the details of a Specific certificate using the certificate 'Serial Number', 'Subject' or a Filter.
.PARAMETER Subject
    Specifies the Subject of the certificate to be selected.
.PARAMETER SerialNumber
    Specifies the Serial Number of the certificate to be selected.
.PARAMETER Filter
    Specify the filter to use when searching for the certificate. !! You need to use single quotes to specify the filter parameters !!
    Valid Filter Parameters:
        'EnhancedKeyUsageList'
        'DnsNameList'
        'FriendlyName'
        'NotAfter'
        'NotBefore'
        'HasPrivateKey'
        'SerialNumber'
        'Thumbprint'
        'Version'
        'Issuer'
        'Subject'
        'TemplateOID'
    Valid Filter Syntax:
        "Issuer -match '*IssuerName*' -and Subject -match $Env:ComputerName -or Thumbprint -eq '5DA5BAA64650769F1279BF4CF80532AFB471CA7A'"
.PARAMETER StoreLocation
    Specifies the Certificate Store Location to search. Default is: 'LocalMachine'.
    Available Values:
        'CurrentUser'
        'LocalMachine'
.PARAMETER StoreName
    Specifies the Certificate Store Names to search. Default is: 'My'.
    Available Values for CurentUser:
        'ACRS'
        'SmartCardRoot'
        'Root'
        'Trust'
        'AuthRoot'
        'CA'
        'UserDS'
        'Disallowed'
        'My'
        'TrustedPeople'
        'TrustedPublisher'
        'ClientAuthIssuer'
    Available Values for LocalMachine:
        'TrustedPublisher'
        'ClientAuthIssuer'
        'Remote Desktop'
        'Root'
        'TrustedDevices'
        'WebHosting'
        'CA'
        'WSUS'
        'Request'
        'AuthRoot'
        'TrustedPeople'
        'My'
        'SmartCardRoot'
        'Trust'
        'Disallowed'
        'SMS'
.PARAMETER Summarization
    Specifies the Usage of the script.
    Summarization On is used to 'Compliant'/'Non-Compliant'.
    Summarization Off is used to return certificate info or error. Default is: 'On'.
    Available Values:
        'On'
        'Off'
.EXAMPLE
    Select-Certificate.ps1 -SerialNumber '61ec50244f40eeba74eba0d889eb37667' -StoreName "'TrustedPublisher','Root'"
.EXAMPLE
    [hashtable]$ScriptParameters = @{
        Filter         = "Subject -match '$Env:ComputerName' -and Issuer -match 'SomeCA' -and TemplateOID -eq '1.3.6.1.4.1.311.21.8.15345926.10523111.1328283.12369231.6977377.105.13507483.11294707'"
        StoreLocation  = "LocalMachine"
        StoreName      = "My"
        Summarization  = "Off"
    }
    Select-Certificate.ps1 @ScriptParameters
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone/Add-Certificate-CREDIT (FTW)
.LINK
    https://MEM.Zone/Add-Certificate
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/Select-Certificate-CHANGELOG
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    Certificate Store
.FUNCTIONALITY
    Select certificate
#>

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

## Set script requirements
#Requires -Version 3.0

<#
#region Comment section if using inline variables
[CmdletBinding()]
Param (
    [Parameter(Mandatory=$true,ParameterSetName='Subject',Position=1)]
    [ValidateNotNullorEmpty()]
    [Alias('Subject')]
    [string]$SubjectName,
    [Parameter(Mandatory=$true,ParameterSetName='Serial',Position=1)]
    [ValidateNotNullorEmpty()]
    [Alias('Serial')]
    [string]$SerialNumber,
    [Parameter(Mandatory=$true,ParameterSetName='Filter',Position=1)]
    [ValidateNotNullorEmpty()]
    [Alias('Search')]
    [string]$Filter,
    [Parameter(Mandatory=$false,ParameterSetName='Subject',Position=2)]
    [Parameter(Mandatory=$false,ParameterSetName='Serial',Position=2)]
    [Parameter(Mandatory=$false,ParameterSetName='Filter',Position=2)]
    [ValidateSet('CurrentUser','LocalMachine')]
    [Alias('Location')]
    [string]$StoreLocation = "LocalMachine",
    [Parameter(Mandatory=$false,ParameterSetName='Subject',Position=3)]
    [Parameter(Mandatory=$false,ParameterSetName='Serial',Position=3)]
    [Parameter(Mandatory=$false,ParameterSetName='Filter',Position=3)]
    [ValidateSet('ACRS','SmartCardRoot','Root','Trust','AuthRoot','CA','UserDS','Disallowed','My','TrustedPeople','TrustedPublisher','ClientAuthIssuer')]
    [ValidateSet('TrustedPublisher','ClientAuthIssuer','Remote Desktop','Root','TrustedDevices','WebHosting','CA','WSUS','Request','AuthRoot','TrustedPeople','My','SmartCardRoot','Trust','Disallowed','SMS')]
    [Alias('Store')]
    [string[]]$StoreName = "My",
    [Parameter(Mandatory=$false,ParameterSetName='Subject',Position=4)]
    [Parameter(Mandatory=$false,ParameterSetName='Serial',Position=4)]
    [Parameter(Mandatory=$false,ParameterSetName='Filter',Position=4)]
    [ValidateSet('On','Off')]
    [Alias('Summ')]
    [string]$Summarization = "On"
)
#endregion
#>

#region uncomment section if using inline variables, add keys and values
[CmdletBinding()]
Param ()
[hashtable]$ScriptParameters = @{
    Filter         = "Subject -match '$Env:ComputerName' -and Issuer -match 'adidas G2 Sub CA 01' -and TemplateOID -eq '1.3.6.1.4.1.311.21.8.15345926.10523111.1328283.12369231.6977377.105.13507483.11294707'"
    StoreLocation  = "LocalMachine"
    StoreName      = "My"
    Summarization  = "Off"
}

## For testing purposes
#$VerbosePreference = 'Continue'
#endregion

#endregion
##*=============================================
##* END VARIABLE DECLARATION
##*=============================================

##*=============================================
##* FUNCTION LISTINGS
##*=============================================
#region FunctionListings

#region Function Format-Spacer
Function Format-Spacer {
<#
.SYNOPSIS
    Adds padding before and after the specified variable.
.DESCRIPTION
    Adds padding before and after the specified variable to make it more visible.
.PARAMETER Message
    Specifies input message for this function.
.PARAMETER Type
    Specifies message output type.
.PARAMETER AddEmptyRow
    Specifies to add empty row before, after or both before and after the output.
.EXAMPLE
    Format-Spacer -Message $SomeVariable -AddEmptyRow 'Before'
.INPUTS
    System.String
.OUTPUTS
    System.String
.NOTES
    Created by Ioan Popovici
    2021-03-31 v1.0.0
    This is an internal script function and should typically not be called directly.
    Thanks @chrisdent from windadmins for fixing my regex :)
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    Console
.FUNCTIONALITY
    Format Output
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true,ValueFromPipeline,HelpMessage='Specify input:',Position=0)]
        [ValidateNotNullorEmpty()]
        [Alias('Variable')]
        [string]$Message,
        [Parameter(Mandatory=$false,Position=1)]
        [ValidateSet('Console','Verbose')]
        [string]$Type = 'Console',
        [Parameter(Mandatory=$false,Position=2)]
        [ValidateSet('No','Before','After','BeforeAndAfter')]
        [string]$AddEmptyRow = 'No'
    )
    Begin {

        ## Set variables
        [string]$Padding = '#========================================#'
    }
    Process {
        Try {

            ## Trim start/end spaces
            [string]$MessageTrimmed = $Message.TrimStart().TrimEnd()

            ## Calculate the numbers of padding characters to remove
            [int]$RemoveRight = [math]::Floor($MessageTrimmed.Length / 2)
            [int]$RemoveLeft  = [math]::Ceiling($MessageTrimmed.Length / 2)

            ## Remove padding characters
            [string]$PaddingRight = $Padding -replace "(?<=#)={$RemoveRight}"
            [string]$PaddingLeft  = $Padding -replace "(?<=#)={$RemoveLeft}"

            ## Add empty rows to the output
            Switch ($AddEmptyRow) {
                'Before' { If ($Type -ne 'Verbose') { $PaddingRight = -join ("`n", $PaddingRight) } }
                'After'  { If ($Type -ne 'Verbose') { $PaddingLeft  = -join ($PaddingLeft, "`n" ) } }
                'After'  { If ($Type -ne 'Verbose') {
                    $PaddingRight = -join ("`n", $PaddingRight)
                    $PaddingLeft  = -join ($PaddingLeft, "`n" ) }
                }
                Default  {}
            }

            ## Assemble result
            [string]$Result = -join ($PaddingRight, ' ', $MessageTrimmed, ' ', $PaddingLeft)
        }
        Catch {
            $PSCmdlet.ThrowTerminatingError($PSItem)
        }
        Finally {

            ## Write to console
            If ($Type -eq 'Console') { Write-Output -InputObject $Result }

            ## Write verbose and add empty rows if specified
            Else {
                If ($AddEmptyRow -eq 'Before' -or $AddEmptyRow -eq 'BeforeAndAfter') { Write-Verbose -Message '' }
                Write-Verbose -Message $Result
                If ($AddEmptyRow -eq 'After' -or $AddEmptyRow -eq 'BeforeAndAfter') { Write-Verbose -Message '' }
            }
        }
    }
    End {
    }
}
#endregion

#region Function Select-Certificate
Function Select-Certificate {
<#
.SYNOPSIS
    Gets the details of a specific certificate.
.DESCRIPTION
    Gets the details of a Specific certificate using the certificate 'Serial Number', 'Subject' or a Filter.
.PARAMETER Subject
    Specifies the Subject of the certificate to be selected.
.PARAMETER SerialNumber
    Specifies the Serial Number of the certificate to be selected.
.PARAMETER Filter
    Specify the filter to use when searching for the certificate. !! You need to use single quotes to specify the filter parameters !!
    Valid Filter Parameters:
        'EnhancedKeyUsageList'
        'DnsNameList'
        'FriendlyName'
        'NotAfter'
        'NotBefore'
        'HasPrivateKey'
        'SerialNumber'
        'Thumbprint'
        'Version'
        'Issuer'
        'Subject'
        'TemplateOID'
    Valid Filter Syntax:
        "Issuer -match '*IssuerName*' -and Subject -match $Env:ComputerName -or Thumbprint -eq '5DA5BAA64650769F1279BF4CF80532AFB471CA7A'"
.PARAMETER StoreLocation
    Specifies the Certificate Store Location to search. Default is: 'LocalMachine'.
    Available Values:
        'CurrentUser'
        'LocalMachine'
.PARAMETER StoreName
    Specifies the Certificate Store Names to search. Default is: 'My'.
    Available Values for CurentUser:
        'ACRS'
        'SmartCardRoot'
        'Root'
        'Trust'
        'AuthRoot'
        'CA'
        'UserDS'
        'Disallowed'
        'My'
        'TrustedPeople'
        'TrustedPublisher'
        'ClientAuthIssuer'
    Available Values for LocalMachine:
        'TrustedPublisher'
        'ClientAuthIssuer'
        'Remote Desktop'
        'Root'
        'TrustedDevices'
        'WebHosting'
        'CA'
        'WSUS'
        'Request'
        'AuthRoot'
        'TrustedPeople'
        'My'
        'SmartCardRoot'
        'Trust'
        'Disallowed'
        'SMS'
.EXAMPLE
    Select-Certificate.ps1 -SerialNumber '61ec50244f40eeba74eba0d889eb37667' -StoreName "'TrustedPublisher','Root'"
.EXAMPLE
    [hashtable]$ScriptParameters = @{
        Filter         = "Subject -match '$Env:ComputerName' -and Issuer -match 'SomeCA' -and TemplateOID -eq '1.3.6.1.4.1.311.21.8.15345926.10523111.1328283.12369231.6977377.105.13507483.11294707'"
        StoreLocation  = "LocalMachine"
        StoreName      = "My"
        Summarization  = "Off"
    }
    Select-Certificate.ps1 @ScriptParameters
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true,ParameterSetName='Subject',Position=1)]
        [ValidateNotNullorEmpty()]
        [Alias('Subject')]
        [string]$SubjectName,
        [Parameter(Mandatory=$true,ParameterSetName='Serial',Position=1)]
        [ValidateNotNullorEmpty()]
        [Alias('Serial')]
        [string]$SerialNumber,
        [Parameter(Mandatory=$true,ParameterSetName='Filter',Position=1)]
        [ValidateNotNullorEmpty()]
        [Alias('Search')]
        [string]$Filter,
        [Parameter(Mandatory=$false,ParameterSetName='Subject',Position=2)]
        [Parameter(Mandatory=$false,ParameterSetName='Serial',Position=2)]
        [Parameter(Mandatory=$false,ParameterSetName='Filter',Position=2)]
        [ValidateSet('CurrentUser','LocalMachine')]
        [Alias('Location')]
        [string]$StoreLocation = 'LocalMachine',
        [Parameter(Mandatory=$false,ParameterSetName='Subject',Position=3)]
        [Parameter(Mandatory=$false,ParameterSetName='Serial',Position=3)]
        [Parameter(Mandatory=$false,ParameterSetName='Filter',Position=3)]
        [ValidateSet('ACRS','SmartCardRoot','Root','Trust','AuthRoot','CA','UserDS','Disallowed','My','TrustedPeople','TrustedPublisher','ClientAuthIssuer')]
        [ValidateSet('TrustedPublisher','ClientAuthIssuer','Remote Desktop','Root','TrustedDevices','WebHosting','CA','WSUS','Request','AuthRoot','TrustedPeople','My','SmartCardRoot','Trust','Disallowed','SMS')]
        [Alias('Store')]
        [string]$StoreName = 'My'
    )
    Begin {

        ## Set valid filter parameters
        [string[]]$ValidParameters = @('EnhancedKeyUsageList', 'FriendlyName', 'NotAfter', 'NotBefore', 'HasPrivateKey', 'SerialNumber', 'Thumbprint', 'Version', 'Issuer', 'Subject', 'TemplateOID')

        ## Cleanup serial number
        If ($SerialNumber) { $SerialNumber = $SerialNumber -replace '\s','' }

        Try {
            ## Create certificate store object
            $CertificateStore = New-Object System.Security.Cryptography.X509Certificates.X509Store $StoreName, $StoreLocation -ErrorAction 'Stop'

            ## Open the certificate store as ReadOnly
            $CertificateStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)
        }
        Catch {
            $PSCmdlet.ThrowTerminatingError($PSItem)
        }
    }
    Process {
        Try {

            ## Set filter depending on the parameter set
            If ($($PSCmdlet.ParameterSetName) -eq 'Subject') { [string]$FilterResolved = '$PSItem.Subject -eq $SubjectName' }
            If ($($PSCmdlet.ParameterSetName) -eq 'Serial')  { [string]$FilterResolved = '$PSItem.SerialNumber -eq $SerialNumber' }

            ## Build filter by prefixing each valid parameter with '$PSItem.' and then converting the output to a scriptblock.
            #  If 'TemplateOID' is specified, we check if it matches the certificate's template and return the OID for matching with the 'TemplateOID' parameter value.
            If ($($PSCmdlet.ParameterSetName) -eq 'Filter')  {
                #  Split filter into individual items
                [string[]]$FilterParameters = $Filter.Split('')
                Write-Debug -Message "-- Filter Items -- `n$Filter.Split('')"
                #  Check for valid parameters
                [string]$FilterResolved = $(
                    ForEach ($Parameter in $FilterParameters) {
                        #  Prefix parameters with '$PSItem.'
                        If ($Parameter -in $ValidParameters) {
                            #  Check if the parameter is 'TemplateOID' and if so, check if it matches the certificate's Template OID
                            If ($Parameter -eq 'TemplateOID') {
                                #  Extract the template value from the filter
                                [regex]$Pattern = "(?:Template)[^']*.([^']*)"
                                [string]$TemplateOID = ($Filter | Select-String -Pattern $Pattern).Matches.Groups[1].Value
                                #  Build the certificate matching query. This should return the OID of matching certificates.
                                [string]$GetCertificateTemplate = '$(If ($PsItem.Thumbprint -in $($CertificateStore.Certificates.Find(9, $TemplateOID, $false).ThumbPrint)) { $TemplateOID } Else { $null })'
                                $Parameter.Replace($Parameter, $($GetCertificateTemplate))
                            }
                            Else { $Parameter.Replace($Parameter, ('$PsItem.' + $Parameter)) }
                        }
                        #  If the item is not in the valid parameter list, it's probably not a parameter, so just return it so it can be used in the filter.
                        Else { $Parameter }
                    }
                #  Join the filter items back together into a single string
                ) -join ' '
            }

            ## Convert the resolved filter to a scriptblock. Note that we are changing the $Filter variable type from string to scriptblock.
            [scriptblock]$Filter = [scriptblock]::Create($FilterResolved)
            Write-Verbose -Message "-- Filter Resolved -- `n$FilterResolved"

            ## Get the certificate details by running the Filter script block
            $SelectCertificate = $CertificateStore.Certificates | Where-Object { $(&$Filter) } | Select-Object -Property 'EnhancedKeyUsageList', 'DnsNameList', 'FriendlyName', 'NotAfter', 'NotBefore', 'HasPrivateKey', 'SerialNumber', 'Thumbprint', 'Version', 'Issuer', 'Subject'

            ## Add the store name
            $SelectCertificate | Add-Member -MemberType 'NoteProperty' -Name 'Store' -Value $Store -ErrorAction 'SilentlyContinue'

            ## Return certificate details or a 'Certificate Selection - Failed!' string if the certificate does not exist
            If (-not $SelectCertificate) { $SelectCertificate = 'Certificate Selection - Failed!' }
        }
        Catch {
            $PSCmdlet.ThrowTerminatingError($PSItem)
        }
        Finally {
            Write-Output -InputObject $SelectCertificate
        }
    }
    End {
        $CertificateStore.Close()
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

Try {

    ## Select parameters to use
    If ($PSBoundParameters.Count -ne 0) { $ScriptParameters = $PSBoundParameters }

    ## Set default Summarization to 'On' for inline parameters else set specified value
    If ([string]::IsNullOrEmpty($ScriptParameters.Summarization)) { $Summarization = 'On' } Else { $Summarization = $ScriptParameters.Summarization }

    ## Remove the Summarization parameter from the parameters list so it doesn't get passed to the Select-Certificate function
    $null = $ScriptParameters.Remove('Summarization')

    ## Write verbose status
    Format-Spacer -Message "Starting Search" -Type 'Verbose' -AddEmptyRow 'After'

    ## Cycle specified certificate stores
    $Result = ForEach ($Store in $ScriptParameters.StoreName) {

        ## Set the invoke parameter set to the current store
        $InvokeParameters = $ScriptParameters
        $InvokeParameters['StoreName'] = $Store
        Write-Verbose -Message "-- Invoke parameters -- `n$($InvokeParameters | Out-String)"

        ## Get the certificate details and add the store name to the result object
        Write-Verbose "Searching $Store Store..."
        Select-Certificate @InvokeParameters
    }

    ## Workaround for MEMCM Compliance Rule limitation. The remediation checkbox shows up only if 'Equals' rule is specified.
    [string]$ResultString = $Result | Out-String

    ## Check if we have a valid result and set result accordingly
    If (-not [string]::IsNullOrEmpty($ResultString) -and $ResultString -notmatch 'Failed') {
        #  Return 'Compliant'
        If ($Summarization -eq 'On') { $Result = 'Compliant' }
    }
    Else {
        #  Return 'Non-Compliant'
        If ($Summarization -eq 'On') { $Result = 'Non-Compliant' }
    }
}
Catch {
    Throw $PSItem
}
Finally {

    ## Return the result
    Write-Output -InputObject $Result
    Format-Spacer -Message "Operation Completed" -Type 'Verbose' -AddEmptyRow 'Before'
}

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================