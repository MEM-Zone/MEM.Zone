<#
.SYNOPSIS
    Adds a certificate to the certificate store.
.DESCRIPTION
    Adds a certificate to the certificate store using the certificate base64 key.
.PARAMETER CertificateBase64
    The certificate in base64 string format.
    Convert the certificate to base64 string using the following command:
    [System.Convert]::ToBase64String($(Get-Content -Path .\Certificate.cer -Encoding Byte))
.PARAMETER StoreLocation
    Specifies the Certificate Store Location to search. Default is: 'LocalMachine'.
    Available Values:
        'CurrentUser'
        'LocalMachine'
.PARAMETER StoreName
    Specifies the Certificate Store Names to search. Default is: 'Root'.
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
    [string]$CertificateBase64 = '
        MIIC7TCCAdWgAwIBAgIQYexQKvQO66dOug2InrN2ZzANBgkqhkiG9w0BAQsFADAm
        xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
        xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
        xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
        xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
        xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
        xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
        xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
        xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
        xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
        xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
        xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
        xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
        xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
        xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
        R1TFx1baj97rlziBt2XVZYG9tEFpPxRPD4A5FjRCix/Q
    '
    Add-Certificate -CertificateBase64 $CertificateBase64 -StoreLocation 'LocalMachine' -StoreName 'Root'
.INPUTS
    None.
.OUTPUTS
    System.String.
.NOTES
    Created by Ioan Popovici
.LINK
    https://MEM.Zone/Manage-Certificate-CREDIT (FTW)
.LINK
    https://MEM.Zone/Manage-Certificate
.LINK
    https://MEM.Zone/Manage-Certificate-CHANGELOG
.LINK
    https://MEM.Zone/Manage-Certificate-GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    Certificate Store
.FUNCTIONALITY
    Add certificate
#>

## Set script requirements
#Requires -Version 3.0

<#
#region Comment section if using inline variables
[CmdletBinding()]
Param (
    [Parameter(Mandatory = $true, HelpMessage = 'Certificate Key in Base64 Format', Position = 1)]
    [ValidateNotNullorEmpty()]
    [Alias('CertificateString')]
    [string]$CertificateBase64,
    [Parameter(Mandatory = $false, HelpMessage = 'Certificate Store Location', Position = 2)]
    [ValidateSet('CurrentUser','LocalMachine')]
    [Alias('Location')]
    [string]$StoreLocation = 'LocalMachine',
    [Parameter(Mandatory = $false, HelpMessage = 'Certifcate Store Name', Position = 3)]
    [ValidateSet('ACRS','SmartCardRoot','Root','Trust','AuthRoot','CA','UserDS','Disallowed','My','TrustedPeople','TrustedPublisher','ClientAuthIssuer')]
    [ValidateSet('TrustedPublisher','ClientAuthIssuer','Remote Desktop','Root','TrustedDevices','WebHosting','CA','WSUS','Request','AuthRoot','TrustedPeople','My','SmartCardRoot','Trust','Disallowed','SMS')]
    [Alias('Store')]
    [string[]]$StoreName = 'Root'
)
#endregion
#>

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

## Inline variables, comment section if using parameters
[string]$CertificateBase64 =
@'
    MIIC7TCCAdWgAwIBAgIQYexQKvQO66dOug2InrN2ZzANBgkqhkiG9w0BAQsFADAm
    xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
    xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
    xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
    xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
    xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
    xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
    xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
    xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
    xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
    xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
    xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
    xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
    xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
    xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
    R1TFx1baj97rlziBt2XVZYG9tEFpPxRPD4A5FjRCix/Q
'@
[string]$StoreLocation = 'LocalMachine'
[string[]]$StoreName = 'Root'

## Initialize variables
$Output = @()

#endregion
##*=============================================
##* END VARIABLE DECLARATION
##*=============================================

##*=============================================
##* FUNCTION LISTINGS
##*=============================================
#region FunctionListings

#region Function Add-Certificate
Function Add-Certificate {
<#
.EXAMPLE
    [string]$CertificateBase64 = '
        MIIC7TCCAdWgAwIBAgIQYexQKvQO66dOug2InrN2ZzANBgkqhkiG9w0BAQsFADAm
        xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
        xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
        xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
        xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
        xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
        xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
        xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
        xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
        xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
        xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
        xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
        xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
        xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
        xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
        R1TFx1baj97rlziBt2XVZYG9tEFpPxRPD4A5FjRCix/Q
    '
    Add-Certificate -CertificateBase64 $CertificateBase64 -StoreLocation 'LocalMachine' -StoreName 'Root'
.INPUTS
    None.
.OUTPUTS
    System.String.
.NOTES
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, HelpMessage = 'Certificate Key in Base64 Format', Position = 1)]
        [ValidateNotNullorEmpty()]
        [Alias('CertificateString')]
        [string]$CertificateBase64,
        [Parameter(Mandatory = $false, HelpMessage = 'Certificate Store Location', Position = 2)]
        [ValidateSet('CurrentUser','LocalMachine')]
        [Alias('Location')]
        [string]$StoreLocation = 'LocalMachine',
        [Parameter(Mandatory = $false, HelpMessage = 'Certifcate Store Name', Position = 3)]
        [ValidateSet('ACRS','SmartCardRoot','Root','Trust','AuthRoot','CA','UserDS','Disallowed','My','TrustedPeople','TrustedPublisher','ClientAuthIssuer')]
        [ValidateSet('TrustedPublisher','ClientAuthIssuer','Remote Desktop','Root','TrustedDevices','WebHosting','CA','WSUS','Request','AuthRoot','TrustedPeople','My','SmartCardRoot','Trust','Disallowed','SMS')]
        [Alias('Store')]
        [string]$StoreName = 'Root'
    )

    ## Create certificate store object
    $CertificateStore = [System.Security.Cryptography.X509Certificates.X509Store]::new($StoreName, $StoreLocation)

    ## Open the certificate store as Read/Write
    $CertificateStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)

    ## Convert the base64 string
    $ByteArray = [System.Convert]::FromBase64String($CertificateBase64)

    ## Create the new certificate object
    $Certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new()

    ## Add the certificate to the store
    $Certificate.Import($ByteArray)
    $CertificateStore.Add($Certificate)

    ## Close the certificate store
    $CertificateStore.Close()
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

## Cycle specified certificate stores and add the specified certificate
ForEach ($Store in $StoreName) {
    Try {

        ## Add the certificate to the specified store
        Add-Certificate -CertificateBase64 $CertificateBase64 -StoreName $Store -ErrorAction 'Stop'
        #  Add OutputProps to Output
        $Output += [psobject]@{
            'Store' = $Store
            'Status'  = 'Add Certificate - Success!'
        }
    }
    Catch {

        ## Assemble error message
        $ErrorProps = [hashtable]@{
            'Store' = $Store
            'Status'  = 'Add Certificate - Failed!'
            'Error' = $PsItem.Exception.Message
        }

        ## Add ErrorMessage hash table to the output object
        $Output += [psobject]$ErrorProps

        ## Return custom error. The error handling is done here in order not to break the ForEach loop and allow it to continue.
        $Exception     = [System.Exception]::new("Error Adding Certificate! $($PsItem.Exception.Message)")
        $ExceptionType = [System.Management.Automation.ErrorCategory]::OperationStopped
        $ErrorRecord   = [System.Management.Automation.ErrorRecord]::new($Exception, $PsItem.FullyQualifiedErrorId, $ExceptionType, $ErrorProps)
        $PSCmdlet.ThrowTerminatingError($ErrorRecord)
    }
    Finally {
        Write-Output -InputObject $($Output | Format-Table -HideTableHeaders | Out-String)
    }
}

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================
