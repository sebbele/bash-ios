#!/bin/bash
#set -x
# check if snmpwalk is installed
type snmpwalk >/dev/null 2>&1 || { echo >&2 "Error: This script requires snmpwalk but it's not installed. Please install the snmp package using for example:
sudo apt-get install snmp."; exit 1; }

# help message function
usage()
{
cat << EOF
usage: $0 [OPTION] DATA [OPTION] DATA

This script will scan Cisco switches/routers for port information, using snmp v2.
 Email: sebastian@leungs.se

OPTIONS:
        -h, --help
                display this help message
        -c, --community [community]
                set the community string. defaults to "public" if unset
        -f, --file [filename]
                file containing device ip(s). 1 ip address per line. may not be used with -H
        -H, --ip [ip address]
                scan just 1 host. may not be used with -f
        -o, --output [filename]
                output file. output is in csv-format
        -q, --quiet
                don't prepend csv-style header at beginning
EOF
exit 0
}>&2

# convert seconds to day-hour:min:sec
convertsecs2dhms() {
 ((d=${1}/(60*60*24)))
 ((h=(${1}%(60*60*24))/(60*60)))
 ((m=(${1}%(60*60))/60))
 ((s=${1}%60))
 # printf "%02d-%02d:%02d:%02d\n" $d $h $m $s
 # PRETTY OUTPUT: uncomment below printf and comment out above printf if you want prettier output
 printf "%02dd %02dh %02dm %02ds\n" $d $h $m $s
}

quietMode=0

while [[ $# -gt 0 ]] ; do
    case $1 in
        -c|--community) COMMUNITY=$2; shift ;;
        -f|--file) IPFILE=$2; shift;;
        -H|--ip) DEVICEIP=$2; shift ;;
        -q|--quiet) quietMode=1; shift ;;
        -o|--output) RESULTFILE=$2; shift ;;
        -h|--help) usage; shift;;
        --) shift; break;;
        *) printf '%s\n' "Parsing error" >&2 ; exit 1;;
    esac
shift
done

# default community public if unset
if [[ -z $COMMUNITY ]]; then
        COMMUNITY=public
fi

# check if resultfile already exists
if test -f "$RESULTFILE"; then
        echo "ERROR: Output file already exists. Exiting.

" >&2
        usage
fi

# check if both DEVICEIP and IPFILE exists
if [ ! -z "$DEVICEIP" ] && [ ! -z "$IPFILE" ] ; then
        echo "ERROR: -f and -H can't be used together. Exiting."
        usage
fi
# check if neither DEVICEIP nor IPFILE exists
if [ -z "$DEVICEIP" ] && [ -z "$IPFILE" ] ; then
        usage
fi


#main function
freeports() {
IP=$1
if [[ `snmpwalk -v 2c -r 2 -c $COMMUNITY $IP 1.3.6.1.4.1.9.2.1.3 2>/dev/null` ]] ; then

HN=$(snmpwalk -v 2c -c $COMMUNITY $IP 1.3.6.1.4.1.9.2.1.3 | awk '/STRING: / {print substr($4,1)}' | sed 's/"//g')
ifNameQuery=$(snmpwalk -v 2c -r 2 -c $COMMUNITY $IP 1.3.6.1.2.1.31.1.1.1.1)
ifLastChangeQuery=$(snmpwalk -v 2c -r 2 -c $COMMUNITY $IP 1.3.6.1.2.1.2.2.1.9)
ifOperStatusQuery=$(snmpwalk -v 2c -r 2 -c $COMMUNITY $IP 1.3.6.1.2.1.2.2.1.8)
ifAliasQuery=$(snmpwalk -v 2c -r 2 -c $COMMUNITY $IP 1.3.6.1.2.1.31.1.1.1.18)
uptimeMS=$(echo $(snmpwalk -v 2c -c $COMMUNITY $IP .1.3.6.1.6.3.10.2.1.3 | sed -n -e 's/^.*INTEGER: //p' | cut -d " " -f 1)00)
uptimeHr=$(echo "$uptimeMS / 360000" | bc)
uptimeDay=$(echo "$uptimeMS / 8640000" | bc)

ifOperStatusArray=(null up down testing unknown dormant notPresent lowerLayerDown)

# loop through interfaces
while read iface; do
#        ifID=$(echo $iface | sed -e 's/.*[0-9.]*\.\([0-9]*\).*/\1/')
	ifID=$(echo $iface | sed -e 's/.*\.\([0-9]*\) = .*/\1/')
        ifName=$(echo $iface | awk '/STRING: / {print substr($4,1)}' | tr -d \'\")
        ifStatusNum=$(echo "$ifOperStatusQuery" | grep -F ".$ifID = " | sed -n -e 's/^.*INTEGER: //p')
	ifStatus=${ifOperStatusArray[${ifStatusNum}]}
	if [ $ifStatusNum == 1 ] ; then
		ifStatus="up"
	elif [ $ifStatusNum == 2 ]; then
		ifStatus="down"
# if $ifStatus isn't 1 or 2 
	else
		continue
	fi
	ifAlias=$(echo "$ifAliasQuery" | grep "\.${ifID} = " | sed 's/.* =.*"\([^"]*\)"$/\1/')
# filter away anything that isn't Fa or Gi
        if [[ "$ifName" != "Gi"* ]] && [[ "$ifName" != "Fa"* ]]; then
                continue
        fi
# calculate port downtime in hours
# 2017-02-20: removed this if statement. it should show duration of status regardless whether it's up or down.
#        if [[ "$ifStatus" == *2* ]]; then
                ifLastMS=$(echo "$ifLastChangeQuery" | grep -F ".$ifID = " | awk -F "[()]" '{ for (i=2; i<NF; i+=2) print $i }')
                ifDownHr=$(echo "($uptimeMS - $ifLastMS) / 360000" | bc)
#        fi

# 2017-04-24: added hour diff between $ifDownHr and $uptimeHr
uptimeDiff=$(echo "$uptimeHr - $ifDownHr" | bc)

echo "$IP;$HN;$uptimeHr;$ifName;$ifStatus;$ifDownHr;$ifAlias;$uptimeDiff"
done <<< "$ifNameQuery"
fi
}

# action depending if DEVICEIP or IPFILE is used
#PID_ARRAY=()
if [ ! -z "$DEVICEIP" ]; then
        if [ -z "$RESULTFILE" ]; then
		if [ $quietMode != 1 ]; then
                echo "IP;HOSTNAME;Host uptime (hr);Port name;Status;Time since last status change (hr);Alias;Uptime diff (Host uptime - Time since last status change)"
		fi
                freeports $DEVICEIP
        elif [ ! -z "$RESULTFILE" ]; then
		if [ $quietMode != 1 ]; then
                echo "IP;HOSTNAME;Host uptime (hr);Port name;Status;Time since last status change (hr);Alias;Uptime diff (Host uptime - Time since last status change)" >> $RESULTFILE
		fi
                freeports $DEVICEIP >> $RESULTFILE
        fi
elif [ ! -z "$IPFILE" ]; then
        if [ -z "$RESULTFILE" ]; then
		if [ $quietMode != 1 ]; then
                echo "IP;HOSTNAME;Host uptime (hr);Port name;Status;Time since last status change (hr);Alias;Uptime diff (Host uptime - Time since last status change)"
		fi
        elif [ ! -z "$RESULTFILE" ]; then
		if [ $quietMode != 1 ]; then
                echo "IP;HOSTNAME;Host uptime (hr);Port name;Status;Time since last status change (hr);Alias;Uptime diff (Host uptime - Time since last status change)" >> $RESULTFILE
		fi
        fi
        for ipaddr in `cat $IPFILE`; do
                if [ -z "$RESULTFILE" ]; then
#                        freeports $ipaddr &
#                        PID_ARRAY+=($!)
			freeports $ipaddr
                elif [ ! -z "$RESULTFILE" ]; then
#                        freeports $ipaddr >> $RESULTFILE &
			freeports $ipaddr >> $RESULTFILE
#                        PID_ARRAY+=($!)
                fi
        done
#        for i in ${PID_ARRAY[*]}; do
#                wait $i
#        done
fi
