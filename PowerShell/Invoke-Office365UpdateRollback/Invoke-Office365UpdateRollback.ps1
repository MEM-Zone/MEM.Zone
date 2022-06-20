## Set Location
Set-Location -Path 'C:\Program Files\Common Files\microsoft shared\ClickToRun\'

## Change Channel (Not Tested)
<# Values to Use
Monthly Channel (Targeted)    | Channel="FirstReleaseCurrent"
Monthly Channel               | Channel="Current"
SemiAnnual Channel (Targeted) | Channel="FirstReleaseDeferred"
Semi-Annual Channel           | Channel="Deferred"
#>
&OfficeC2RClient.exe /changesetting Channel=Current

## Downgrade to 16.0.14430.20342
<#
	displaylevel     | show/hide GUI from user
	forceappshutdown | forceclose opem 365 apps before upgrade
	updatepromptuser | prompt user to upgrade or perform upgrade non-interactively
	updatetoversion  | target version to upgrade/downgrade
#>
&OfficeC2RClient.exe" /update USER displaylevel=true forceappshutdown=true updatepromptuser=false updatetoversion=16.0.14430.20342
