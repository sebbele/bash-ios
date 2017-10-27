# bash-ios
Gathering of bash scripts for gathering various Cisco ios (and WLC) data, using snmp v2.
This is some scripts I've made to make some tasks easier.

## Using the scripts
Help flags are available. Output is mainly csv format with semicolon (;) as delimiter.

### Example:
./inventory-switchrouter -H 10.10.12.132 -c mysnmpcommunity
