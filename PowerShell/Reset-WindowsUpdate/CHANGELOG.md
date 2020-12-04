# Reset-WindowsUpdate release history

## 3.0.0 - 2020-12-04

* Renamed script and function to `Reset-WindowsUpdate`
* Added full reset functionality (will not work if update component files are corrupted)

## 2.0.0 - 2018-05-24

### Changes

* Fixed logical bugs that forced a NULL return
* Generalized so it can be used for multiple error cases
* Added standalone repair option to use without detection
* Added kill windows update service by PID

## 1.0.0 - 2018-03-28

### First version

* Detects and repairs a corrupted WU DataStore.
* Detection is done by testing the eventlog with the specified parameters.
* Repairs are performed by removing and reinitializing the corrupted DataStore.
* The specified eventlog is backed up and cleared in order not to triger the detection again before the repair step.
* The backup of the specified eventlog is stored in 'SystemRoot\Temp' folder.
* Defaults are configured for the ESENT '623' error.