#region Function Set-FileSystemAcl
Function Set-FileSystemAcl {
<#
.SYNOPSIS
    Sets the acl of a file system object.
.DESCRIPTION
    Sets the acl of a file system object, using a specified access rule.
.PARAMETER Path
    Specifies the file system object path
.PARAMETER Action
    Specifies action to perform. Valid options are: 'Add','Remove'
.PARAMETER AccessRule
    Specifies access rule to set as a hashtable.
    [hashtable]@ {
        AccessRule = @{
        IdentityReference = 'NT AUTHORITY\SYSTEM'
        FileSystemRights  = 'Modify'
        InheritanceFlags  = 'ContainerInherit, ObjectInherit'
        PropagationFlags  = 'None'
        AccessControlType = 'Deny'
    }
.PARAMETER WhatIf
    When used, the command reports the expected effect of the command to the console. But does not actually execute the command.
.EXAMPLE
    $Parameters = @{
        Path   = 'D:\Temp'
        Action = 'Remove'
        AccessRule = @{
            IdentityReference = 'NT AUTHORITY\SYSTEM'
            FileSystemRights  = 'Modify'
            InheritanceFlags  = 'ContainerInherit, ObjectInherit'
            PropagationFlags  = 'None'
            AccessControlType = 'Deny'
        }
    }

    Set-FileSystemAcl @Parameters
.INPUTS
    None.
.OUTPUTS
    System.String
    System.Security.AccessControl
.NOTES
    Created by Ioan Popovici
    v1.0.3 - 2021-07-02
    This is an internal script function and should typically not be called directly.
.LINK
    https://MEM.Zone
.LINK
    https://MEM.Zone/GIT
.LINK
    https://MEM.Zone/ISSUES
.COMPONENT
    ACL
.FUNCTIONALITY
    Sets Folder Permissions
#>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true,Position=0)]
        [ValidateNotNullorEmpty()]
        [ValidateScript({ Test-Path -Path $PsItem })]
        [Alias('Location')]
        [string]$Path,
        [Parameter(Mandatory=$true,HelpMessage='Specify action (Add/Remove):',Position=1)]
        [ValidateSet('Add','Remove')]
        [string]$Action,
        [Parameter(Mandatory=$true,HelpMessage='Specify access rule as a hashtable:',Position=2)]
        [ValidateNotNullorEmpty()]
        [array]$AccessRule,
        [switch]$WhatIf
    )

    Begin {

        ## Variable initialization
        [boolean]$AclExists = $false
        $Result = 'AlreadyCompliant'
    }
    Process {
        Try {

            ## Get location ACL
            $AclObject = Get-Acl -Path $Path

            ## Build Access Rule
            $ArObject = New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule(@($AccessRule.IdentityReference, $AccessRule.FileSystemRights, $AccessRule.InheritanceFlags, $AccessRule.PropagationFlags, $AccessRule.AccessControlType))

            ## Check if ACL already exist
            $AclExists = $AclObject.Access | Where-Object {
                $_.FileSystemRights  -eq $ArObject.FileSystemRights  -and
                $_.AccessControlType -eq $ArObject.AccessControlType -and
                $_.IdentityReference -eq $ArObject.IdentityReference -and
                $_.IsInherited       -eq $ArObject.IsInherited       -and
                $_.InheritanceFlags  -eq $ArObject.InheritanceFlags  -and
                $_.PropagationFlags  -eq $ArObject.PropagationFlags
            }

            ## Perform specified action
            switch ($Action) {
                'Add'    {
                    If (-not [string]::IsNullOrWhiteSpace($AclExists)) {

                        ## Set and write ACL
                        $AclObject.AddAccessRule($ArObject)
                        $Result = Set-Acl -Path $Path -AclObject $AclObject -Passthru -WhatIf:$WhatIf
                    }
                    Break
                }
                'Remove' {
                    If ([string]::IsNullOrWhiteSpace($AclExists)) {

                        ## Set and write ACL
                        $AclObject.RemoveAccessRule($ArObject)
                        $Result = Set-Acl -Path $Path -AclObject $AclObject -Passthru -WhatIf:$WhatIf
                    }
                    Break
                }
                Default {}
            }
        }
        Catch {
            $PSCmdlet.ThrowTerminatingError($PSItem)
        }
        Finally {
            Write-Output -InputObject $Result
        }
    }
    End {
    }
}
#endregion