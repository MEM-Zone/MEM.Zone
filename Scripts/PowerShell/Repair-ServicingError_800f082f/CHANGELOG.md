# Repair-ServicingError_800f082f release history

## 1.1.0 - 2018-10-17

* Fixed $ScriptName variable
* Throw error if image not in the same folder

## 1.0 - 2017-08-31

### First version

* Repairs he 0x800f082f~ error encountered during offline servicing by setting the `HKLM:\Microsoft\Windows\CurrentVersion\Component Based Servicing\SessionsPending\Exclusive` value to 0.
