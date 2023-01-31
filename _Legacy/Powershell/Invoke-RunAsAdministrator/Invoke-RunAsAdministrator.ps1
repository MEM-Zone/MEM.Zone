# Get the ID and security principal of the current user account
$MyWindowsID=[System.Security.Principal.WindowsIdentity]::GetCurrent()
$MyWindowsPrincipal = New-Object System.Security.Principal.WindowsPrincipal($MyWindowsID)

# Get the security principal for the Administrator role
$AdministratorRole=[System.Security.Principal.WindowsBuiltInRole]::Administrator

# Check to see if we are currently running "as Administrator"
If ($MyWindowsPrincipal.IsInRole($AdministratorRole)) {
    # We are running "as Administrator" - so change the title and background color to indicate this
    $Host.UI.RawUI.WindowTitle = $MyInvocation.MyCommand.Definition + "(Elevated)"
    $Host.UI.RawUI.BackgroundColor = "DarkBlue"
    Clear-Host
}
Else {
    # We are not running "as Administrator" - so relaunch as administrator

    # Create a new process object that starts PowerShell
    $NewProcess = New-Object System.Diagnostics.ProcessStartInfo "PowerShell";

    # Specify the current script path and name as a parameter
    $NewProcess.Arguments = $MyInvocation.MyCommand.Definition;

    # Indicate that the process should be elevated
    $NewProcess.Verb = "runas";

    # Start the new process
    [System.Diagnostics.Process]::Start($NewProcess);

    # Exit from the current, unelevated, process
    Exit
}

# Run your code that needs to be elevated here
Write-Host -NoNewLine "Press any key to continue..."
$Null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

