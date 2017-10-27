# bash-ios
Gathering of bash scripts for gathering various Cisco ios (and WLC) data, using snmp v2.
This is some scripts I've made to make some tasks easier.
Some scripts are older than others and should probably be updated sometime in the future.

## Using the scripts
Help flags are available. Output is mainly csv format with semicolon (;) as delimiter.
./inventory-ap.sh --help

### Example:
./inventory-switchrouter -H 10.10.12.132 -c mysnmpcommunity
