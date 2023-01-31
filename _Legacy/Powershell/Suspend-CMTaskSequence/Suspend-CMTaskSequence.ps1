<#
*********************************************************************************************************
* Requires          | Requires PowerShell 4.0, ConfigMgr TS Environment                                 *
* ===================================================================================================== *
* Modified by       |    Date    | Revision | Comments                                                  *
* _____________________________________________________________________________________________________ *
* Ioan Popovici     | 2018-03-05 | v1.0     | First version                                             *
* ===================================================================================================== *
*                                                                                                       *
*********************************************************************************************************

.SYNOPSIS
    Suspends a ConfigMgr Task Sequence.
.DESCRIPTION
    Suspends a ConfigMgr Task Sequence and optionaly starts cmtrace on Task Sequence error.
.PARAMETER MsgBoxTitle
    Specifies the message box title. Default is: 'Task Sequence Suspended'
.PARAMETER MsgBoxText
    Specifies the message box text. Default is: 'Task Sequence [$SMSTSPackageName] has been suspended on [$OSDComputerName]! `nClick ok to review the logs.'.
.EXAMPLE
    Suspend-CMTaskSequence -MsgBoxTitle 'Mesage Box Title' -MsgBoxText 'Message Box Text'
.INPUTS
    System.String.
.OUTPUTS
    None. This function has no outputs.
.NOTES
    This function can typically be called directly.
.LINK
    https://SCCM-Zone.com
.LINK
    https://github.com/Ioan-Popovici/SCCMZone
.COMPONENT
    SCCM
.FUNCTIONALITY
    SCCM Management
#>

##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VariableDeclaration

## Get script parameters
Param (
    [Parameter(Mandatory=$false,Position=0)]
    [ValidateNotNullorEmpty()]
    [string]$Title = 'Task Sequence Suspended',
    [Parameter(Mandatory=$false,Position=1)]
    [ValidateNotNullorEmpty()]
    [string]$Text = "Task Sequence [$SMSTSPackageName] has failed on [$OSDComputerName]! `nClick ok to review the logs."
)

#endregion
##*=============================================
##* END VARIABLE DECLARATION
##*=============================================

##*=============================================
##* FUNCTION LISTINGS
##*=============================================
#region FunctionListings

#region Function Suspend-CMTaskSequence
Function Suspend-CMTaskSequence {
<#
.SYNOPSIS
    Suspends a ConfigMgr Task Sequence.
.DESCRIPTION
    Suspends a ConfigMgr Task Sequence and optionaly starts cmtrace on Task Sequence error.
.PARAMETER MsgBoxTitle
    Specifies the message box title. Default is: 'Task Sequence Suspended'
.PARAMETER MsgBoxText
    Specifies the message box text. Default is: 'Task Sequence [$SMSTSPackageName] has failed on [$OSDComputerName]! `nClick ok to review the logs.'.
.EXAMPLE
    Suspend-CMTaskSequence -MsgBoxTitle 'Mesage Box Title' -MsgBoxText 'Message Box Text' -Timeout 60
.INPUTS
    System.String.
.OUTPUTS
    None. This function has no outputs.
.NOTES
    This function can typically be called directly.
.LINK
    https://SCCM-Zone.com
.LINK
    https://github.com/Ioan-Popovici/SCCMZone
.COMPONENT
    SCCM
.FUNCTIONALITY
    SCCM Management
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$false,Position=0)]
        [ValidateNotNullorEmpty()]
        [string]$MsgBoxTitle = 'Task Sequence Suspended',
        [Parameter(Mandatory=$true,ValueFromPipeline=$false,Position=1)]
        [ValidateNotNullorEmpty()]
        [string]$MsgBoxText = "Task Sequence [$SMSTSPackageName] has failed on [$OSDComputerName]! `nClick ok to review the logs."
    )

    Begin {

        ## Add Assemblies
        Add-Type -AssemblyName 'System.Windows.Forms'

        ## Create the Task Sequence Environment and TS ProgressUI objects
        $TsEnvironment = New-Object -ComObject 'Microsoft.SMS.TSEnvironment'
        $TsProgressUI = New-Object -ComObject 'Microsoft.SMS.TsProgressUI'
        #  Set Task Sequence variable names 
        $SMSTSPackageName = $TsEnvironment.Value("_SMSTSPackageName")
        $OSDComputerName = $TsEnvironment.Value("OSDComputerName")
        $SMSTSLogPath = $TsEnvironment.Value( $(Join-Path -Path "_SMSTSLogPath" -ChildPath '\smsts.log') )

        ## Hide progress dialog in order to make the message box visible
        $TsProgressUI.CloseProgressDialog()

        ## Make CMTrace the default viewer
        Set-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Trace32' -Name 'Register File Types' -Value '0' -ErrorAction 'SilentlyContinue'
    }
    Process {
        Try {

            ## Show message box
            $MsgBoxReturn = [System.Windows.Forms.MessageBox]::Show($MsgBoxText, $MsgBoxTitle, [System.Windows.Forms.MessageBoxButtons]::OKCancel, 'Information')

            ## Handle message box actions
            Switch ($MsgBoxReturn) {
                'OK' {

                    # Start CMTrace
                    Start-Process -FilePath cmtrace.exe -ArgumentList $SMSTSLogPath

                    # Mark task sequence as failed
                    $TsEnvironment.Value("TSFailed") = 'True'
                }
                Default {

                    # Mark task sequence as not failed
                    $TsEnvironment.Value("TSFailed") = 'False'
                }
            }
        }
        Catch {
            Write-Output -InputObject "Failed to show Message Box. `n$_.Error[0].Exception"
            Break
        }
    }
    End {
        $TsProgressUI.OpenProgressDialog()
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

## Call Suspend-CMTaskSequence function
Suspend-CMTaskSequence -MsgBoxTitle $Title -MsgBoxText $Text

#endregion
##*=============================================
##* END SCRIPT BODY
##*=============================================
