#/!bin/bash

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
# variable for background looping
PID_ARRAY=()

# help message function
usage()
{
cat << EOF
usage: $0 [OPTION] DATA [OPTION] DATA

This script will scan Cisco WLC(s) for AP inventory, using snmp v2.
 Email: sebastian@leungs.se

OPTIONS:
 -h, --help	display this help message
 -c COMMUNITY	set the community string. sets community "public" if unset
 -f FILE	file containing wlc ip(s)
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

# variables used
#WLCFILE=
#WLCIP=
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
		 WLCIP=$OPTARG
		 ;;
		f)
		 WLCFILE=$OPTARG
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
if [[ -v WLCFILE ]] && [[ -v WLCIP ]]; then
 echo "ERROR: Cannot use -H and -f together. Exiting."
 exit 2
fi

# default community public if unset
if [[ -z $COMMUNITY ]]; then
	COMMUNITY=public
fi

# inform that script is running
echo "Running script... this can take a moment."

# initial line to resultfile if needed
if ! [[ -z $RESULTFILE ]]; then
 echo "AP IP;HOSTNAME;MODEL;S/N;AP Software Version;WLC IP" >> $RESULTFILE
fi

apscanner() {
# gather data from wlc
 WLC=$1
 NAME=$(snmpwalk -v 2c -c $COMMUNITY $WLC 1.3.6.1.4.1.14179.2.2.1.1.3)
 DEVICE=$(snmpwalk -v 2c -c $COMMUNITY $WLC 1.3.6.1.4.1.14179.2.2.1.1.16)
 SERIAL=$(snmpwalk -v 2c -c $COMMUNITY $WLC 1.3.6.1.4.1.14179.2.2.1.1.17)
 IP=$(snmpwalk -v 2c -c $COMMUNITY $WLC 1.3.6.1.4.1.14179.2.2.1.1.19)
 VER=$(snmpwalk -v 2c -c $COMMUNITY $WLC 1.3.6.1.4.1.14179.2.2.1.1.8)
 PROCESS_ARRAY=()

# process data
 while read -r APNAME; do
  ID=$(echo "$APNAME" | sed -n 's/.*14179\.2\.2\.1\.1\.3\.\([0-9.]\+\).*/\1/p')
  HN=$(echo "$APNAME" | grep "$ID " | awk '/STRING: / {print substr($4,1)}' | sed 's/"//g')
  DEV=$(echo "$DEVICE" | grep "$ID " | awk '/STRING: / {print substr($4,1)}' | sed 's/"//g')
  SN=$(echo "$SERIAL" | grep "$ID " | awk '/STRING: / {print substr($4,1)}' | sed 's/"//g')
  APIP=$(echo "$IP" | grep "$ID " | awk '/IpAddress: / {print substr($4,1)}' | sed 's/"//g')
  APVER=$(echo "$VER" | grep "$ID " | awk '/STRING: / {print substr($4,1)}' | sed 's/"//g')
# print result
  echo "$APIP;$HN;$DEV;$SN;$APVER;$WLC" 
 done <<< "$NAME"
}

# do different actions if -H or -f was used, and if output file is chosen
if ! [[ -z $WLCIP ]]; then
 if ! [[ -z $RESULTFILE ]]; then
  apscanner $WLCIP >> $RESULTFILE
 elif [[ -z $RESULTFILE ]] ; then
  apscanner $WLCIP
 fi
echo "Done!"
exit 0
elif ! [[ -z $WLCFILE ]]; then
 for i in `cat $WLCFILE`; do
# add each background PID to an array
  if ! [[ -z $RESULTFILE ]]; then
   apscanner $i >> $RESULTFILE &
   PID_ARRAY+=($!)
  elif [[ -z $RESULTFILE ]] ; then
   apscanner $i &
   PID_ARRAY+=($!)
  fi
 done
# wait for each background PID to finish
 for i in ${PID_ARRAY[*]} ; do
  wait $i
 done

echo "Done!"
exit 0
fi
