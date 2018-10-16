#!/bin/bash

# check if snmpwalk is installed
type snmpwalk >/dev/null 2>&1 || { echo >&2 "Error: This script requires snmpwalk but it's not installed. Please install the snmp package using for example:
sudo apt-get install snmp."; exit 1; }

usage()
{
cat << EOF
usage: $0 [OPTION] DATA [OPTION] DATA

This script uses snmp to scan HP switches for port expansion modules.
 Contact: sebastian@leungs.se

OPTIONS:
  -h, --help            display this message
  -H                    target host
  -v 1|2c|3             snmp version
SNMP Version 1 or 2c specific
  -c COMMUNITY          set the community string
SNMP Version 3 specific
  -a PROTOCOL           set authentication protocol (MD5|SHA)
  -A PASSPHRASE         set authentication protocol pass phrase
  -e ENGINE-ID          set security engine ID (e.g. 800000020109840301)
  -E ENGINE-ID          set context engine ID (e.g. 800000020109840301)
  -l LEVEL              set security level (noAuthNoPriv|authNoPriv|authPriv)
  -n CONTEXT            set context name (e.g. bridge1)
  -u USER-NAME          set security name (e.g. bert)
  -x PROTOCOL           set privacy protocol (DES|AES)
  -X PASSPHRASE         set privacy protocol pass phrase
  -Z BOOTS,TIME         set destination engine boots/time
EOF
exit 1
}

# send help message for --help
if [ "$1" == "--help" ] ; then
    usage
    exit 1
fi
# help message if no flags were given
if [ $# == 0 ] ; then
    usage
    exit 2
fi

# get flags
while getopts "h:H:v:c:a:A:e:E:l:n:u:x:X:z:" OPTION; do
    case $OPTION in
        h) usage ;;
        \?) echo "Invalid option: -$OPTARG"
         usage ;;
        c) snmp_options="$snmp_options -c $OPTARG" ;;
        H) target=$OPTARG ;;
        v) snmp_options="$snmp_options -v $OPTARG" ;;
        a) snmp_options="$snmp_options -a $OPTARG" ;;
        A) snmp_options="$snmp_options -A $OPTARG" ;;
        e) snmp_options="$snmp_options -e $OPTARG" ;;
        E) snmp_options="$snmp_options -E $OPTARG" ;;
        l) snmp_options="$snmp_options -l $OPTARG" ;;
        n) snmp_options="$snmp_options -n $OPTARG" ;;
        u) snmp_options="$snmp_options -u $OPTARG" ;;
        x) snmp_options="$snmp_options -x $OPTARG" ;;
        X) snmp_options="$snmp_options -X $OPTARG" ;;
        z) snmp_options="$snmp_options -z $OPTARG" ;;
     esac
done

if [[ `snmpwalk -r 2 $snmp_options $target 1.3.6.1.2.1.1.1.0` ]]; then
    model=$(snmpwalk -O qv $snmp_options $target 1.3.6.1.2.1.1.1.0 | grep -i "switch" | cut -d ',' -f 1)
    model=$(cat -v <<< "$model" | tr -d "^M")
    hostname=$(snmpwalk -O qv $snmp_options $target 1.3.6.1.2.1.1.5)
    modules=$(snmpwalk -O qv $snmp_options $target 1.3.6.1.2.1.47.1.1.1.1.2 | grep -i "[0-9]\+p" | grep -iv "Management\|slot" | tr -d '"' | uniq -c)
    if [[ -n $modules ]]; then
        while read module; do
            trimmed_line=$(echo "$module" | xargs)
            count=$(echo "$trimmed_line" | cut -d " " -f 1)
            module_name=$(echo "$trimmed_line" | cut -d " " -f 2-)
            total_modules="$total_modules;${count};${module_name}"
            module_count=$((module_count + $count))
        done <<< "$modules"
        echo "${hostname};${model};${module_count}$total_modules"
    else
        echo "${hostname};${model};0"
    fi
else
    echo "Unable to connect to target using snmp"
    exit 1
fi
