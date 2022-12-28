# Repair-CMCollectionReference release history

## 1.0.0 - 2022-06-20

* Fixed `Direct Membership` including members from previous steps
* Fixed `Include Collection Membership` including collections from previous steps
* Fixed `Exclude Collection Membership` including collections from previous steps or from `Include Collection Membership`
* Changed logging to happen during processing instead of the end of the script

## 0.1.0pre - 2022-03-28

### First version (Pre-Release)

* Repairs the MEMCM Collection Membership references, by querying the membership rules by name and then updating the membership rules.
