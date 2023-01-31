# Configuration Manager Push Install Errors

| Error Code | Reason                                    | Notes/Possible Fixes
| ---------- | ----------------------------------------- | --------------------
| 2          | The system cannot find the file specified | Check for corrupted Client Package
| 5          | Access denied                             | Check Push Install Account Password
| 52         | You were not connected because a duplicate name exists on the network. | Make sure there is not a duplicate name and that 2 machines don’t have the same IP in DNS
| 53         | Unable to locate - Cannot connect to admin$ | Most common, it's usually firewall. | Add File and print sharing to Exceptions in Firewall, turn file and print on, check that Computer Browser Service is started
| 58         | The specified server cannot perform The requested operation | N/A
| 64         | The specified network name is no longer available. Source: Windows | N/A
| 67         | Network name cannot be found.             | Check if Machine Name resolves in DNS
| 86         | Network password is not correct?          | Check if Machine Name differs from DNS resolved Name.
| 112        | Not enough disk space.                    | N/A
| 120        | Mobile client on the target machine has the same version, and `forced` flag is not turned on | Not processing this CCR, Target machine already has SCCM Client installed and no force install was selected (Always Install)
| 1003       | Cannot complete this function.            | N/A
| 1053       | The service did not respond to the start or control request in a timely fashion | N/A
| 1068       | The dependency service or group failed to start | N/A
| 1130       | Not enough server storage is available to process this command. Source: Windows | N/A
| 1203       | The network path was either typed incorrectly, does not exist, or the network provider is not currently available | Check if Machine Name resolves in DNS
| 1208       | An extended error has occurred. Source: Windows | N/A
| 1326       | Unknown user or bad password              | Push Install Account Password
| 1305       | The revision level is unknown             | N/A
| 1396       | Logon Failure: The target account name is incorrect | NBTSTAT -a reverse lookup, duplicate IP address
| 1450       | Insufficient system resources exist to complete the requested service. Source: Windows | N/A
| 1789       | The trust relationship between this workstation and the primary domain failed | Unjoin/Join Machine to domain or use Powershell to fix it
| 2147023174 | The RPC server is unavailable             | Check if Dynamic Ports are open and that the three way handshake succeedes
| 2147024891 | Access is denied                          | Check Push Install Account Password/Push install account has admin rights
| 2147217406 | Setup failed due to unexpected circumstances | N/A
| 2147418110 | RPC E Call Canceled                       | Cannot connect trough WMI
| 2147749889 | Generic WMI failure                       | Corrupted WMI
| 2147749890 | not found - Source: Windows Management    | Corrupted WMI
| 2147749904 | Invalid class - Source: Windows Management| Corrupted WMI
| 2147749908 | Initialization failure - Source: Windows Management | Corrupted WMI
| 2147942405 | Access is Denied                          | Firewall/Antivirus
| 2147944122 | The RPC server is unavailable             | [DCOM is miss-configured for security](http://support.microsoft.com/kb/899965)
| 2148007941 | Server Execution Failed                   | N/A
