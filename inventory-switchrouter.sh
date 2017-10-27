#!/bin/bash

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT
function ctrl_c() {
        echo "Script exited by user. Cleaning up temp files."
	rm -f *.temp
	exit 2
}

# check if snmpwalk is installed
type snmpwalk >/dev/null 2>&1 || { echo >&2 "Error: This script requires snmpwalk but it's not installed. Please install the snmp package using for example:
sudo apt-get install snmp."; exit 1; }

# some time variables
THEDATE=`date +%Y-%m-%d`
THETIME=`date +%Y-%m-%d_%H:%M:%S`
echo "Start $SECONDS" > /dev/null

# help message function
usage()
{
cat << EOF
usage: $0 [OPTION] DATA [OPTION] DATA

This script will scan Cisco switches/routers for inventory, using snmp v2. Note: This will also work for autonomous access points.
 Email: sebastian@leungs.se

OPTIONS:
 -h, --help	display this help message
 -c COMMUNITY	set the community string. sets community "public" if unset
 -f FILE	file containing device ip(s)
 -H IP		scan just 1 host. may not be used with -f
 -o FILENAME	output file
EOF
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

# variables used from flags
#IPFILE=
#DEVICEIP=
#COMMUNITY=
#RESULTFILE=

# parse script input using getopts
while getopts "hH:f:c:o:" OPTION; do
	case $OPTION in
		h)
		 usage
		 exit 1
		 ;;
	 	\?)
		 echo "Invalid option: -$OPTARG"
		 usage
		 exit 1
      		 ;;
		c)
		 COMMUNITY=$OPTARG
		 ;;
		H)
		 DEVICEIP=$OPTARG
		 ;;
		f)
		 IPFILE=$OPTARG
		 ;;
		o)
		 RESULTFILE=$OPTARG
		 ;;
	esac
done

# check if resultfile already exists
if test -f "$RESULTFILE"; then
 echo "ERROR: Output file already exists. Exiting."
 exit 2
fi

# check if -H and -f was used together
if [[ -v IPFILE ]] && [[ -v DEVICEIP ]]; then
 echo "ERROR: Cannot use -H and -f together. Exiting."
 exit 2
fi

# default community public if unset
if [[ -z $COMMUNITY ]]; then
	COMMUNITY=public
fi

# inform that script is running
#echo "Running script... this can take a moment."

# create resultfile if specified
if ! [[ -z $RESULTFILE ]]; then
 echo "IP;HOSTNAME;MODEL;S/N;Software Version" >> $RESULTFILE
fi

# gather data from input file
if ! [[ -z $IPFILE ]]; then
 for IP in `cat $IPFILE`; do
  if [[ `snmpwalk -v 2c -r 2 -c $COMMUNITY $IP 1.3.6.1.4.1.9.2.1.3` ]]; then
# hostname
HN=$(snmpwalk -v 2c -c $COMMUNITY $IP 1.3.6.1.4.1.9.2.1.3 | awk '/STRING: / {print substr($4,1)}' | sed 's/"//g')

# model depending which OID is responding (it's a different OID on VPN routers)
if [[ `snmpwalk -v 2c -c $COMMUNITY $IP 1.3.6.1.4.1.9.5.1.2.16` != *"No Such"* ]]; then
MODEL=$(snmpwalk -v 2c -c $COMMUNITY $IP 1.3.6.1.4.1.9.5.1.2.16 | awk '/STRING: / {print substr($4,1)}' | sed 's/"//g')
else
MODEL=$(snmpwalk -v 2c -c $COMMUNITY $IP 1.3.6.1.2.1.47.1.1.1.1.7.1 | awk '/STRING: / {print substr($4,1)}' | sed 's/"//g')
fi
# serial number. same check as model, for VPN routers
if [[ `snmpwalk -v 2c -c $COMMUNITY $IP 1.3.6.1.4.1.9.5.1.2.19` != *"No Such"* ]]; then
SERIAL=$(snmpwalk -v 2c -c $COMMUNITY $IP 1.3.6.1.4.1.9.5.1.2.19 | awk '/STRING: / {print substr($4,1)}' | sed 's/"//g')
else
SERIAL=$(snmpwalk -v 2c -c $COMMUNITY $IP 1.3.6.1.2.1.47.1.1.1.1.11.1 | awk '/STRING: / {print substr($4,1)}' | sed 's/"//g')
fi

# software version
IOS=$(snmpwalk -v 2c -c $COMMUNITY $IP 1.3.6.1.2.1.1.1 | grep -i "version" | awk -F ',' 'BEGIN{OFS=FS} {print $3}' | sed s/' Version'/''/g | sed s/' '/''/g)

# print to terminal or file
    if ! [[ -z $RESULTFILE ]]; then
	echo $(echo "$IP;$HN;$MODEL;$SERIAL;$IOS") >> $RESULTFILE
    else
	echo $(echo "$IP;$HN;$MODEL;$SERIAL;$IOS")
    fi
  fi
 unset IP HN MODEL SERIAL IOS
 done
# wrap it up nicely
#echo "Done!"
exit 0
fi

# gather data from single ip
if ! [[ -z $DEVICEIP ]]; then
IP=$DEVICEIP
  if [[ `snmpwalk -v 2c -r 2 -c $COMMUNITY $IP 1.3.6.1.4.1.9.2.1.3` ]]; then
# hostname
HN=$(snmpwalk -v 2c -c $COMMUNITY $IP 1.3.6.1.4.1.9.2.1.3 | awk '/STRING: / {print substr($4,1)}' | sed 's/"//g')

# model depending which OID is responding (it's a different OID on VPN routers)
if [[ `snmpwalk -v 2c -c $COMMUNITY $IP 1.3.6.1.4.1.9.5.1.2.16` != *"No Such"* ]]; then
MODEL=$(snmpwalk -v 2c -c $COMMUNITY $IP 1.3.6.1.4.1.9.5.1.2.16 | awk '/STRING: / {print substr($4,1)}' | sed 's/"//g')
else
MODEL=$(snmpwalk -v 2c -c $COMMUNITY $IP 1.3.6.1.2.1.47.1.1.1.1.7.1 | awk '/STRING: / {print substr($4,1)}' | sed 's/"//g')
fi

# serial number. same check as model, for VPN routers
if [[ `snmpwalk -v 2c -c $COMMUNITY $IP 1.3.6.1.4.1.9.5.1.2.19` != *"No Such"* ]]; then
SERIAL=$(snmpwalk -v 2c -c $COMMUNITY $IP 1.3.6.1.4.1.9.5.1.2.19 | awk '/STRING: / {print substr($4,1)}' | sed 's/"//g')
else
SERIAL=$(snmpwalk -v 2c -c $COMMUNITY $IP 1.3.6.1.2.1.47.1.1.1.1.11.1 | awk '/STRING: / {print substr($4,1)}' | sed 's/"//g')
fi

# software version
IOS=$(snmpwalk -v 2c -c $COMMUNITY $IP 1.3.6.1.2.1.1.1 | grep -i "version" | awk -F ',' 'BEGIN{OFS=FS} {print $3}' | sed s/' Version'/''/g | sed s/' '/''/g)

# print to terminal or file
    if ! [[ -z $RESULTFILE ]]; then
	echo $(echo "$IP;$HN;$MODEL;$SERIAL;$IOS") >> $RESULTFILE
    else
	echo $(echo "$IP;$HN;$MODEL;$SERIAL;$IOS")
    fi
# wrap it up nicely
#echo "Done!"
exit 0
  fi
fi
