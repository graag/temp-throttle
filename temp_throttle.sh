#!/bin/bash

# Usage: temp_throttle.sh max_temp
# USE CELSIUS TEMPERATURES.
# version 2.11

cat << EOF
Author: Sepero 2013 (sepero 111 @ gmx . com)
URL: http://github.com/Sepero/temp-throttle/

EOF

# Additional Links
# http://seperohacker.blogspot.com/2012/10/linux-keep-your-cpu-cool-with-frequency.html

# Additional Credits
# Wolfgang Ocker <weo AT weo1 DOT de> - Patch for unspecified cpu frequencies.

# License: GNU GPL 2.0

# Generic  function for printing an error and exiting.
err_exit () {
	echo ""
	echo "Error: $@" 1>&2
	exit 128
}

if [ "$#" -ne "1" ] && [ "$#" -ne "2" ]; then
	echo $#
	# If temperature wasn't given, then print a message and exit.
	echo "${0} TT [FT]" 1>&2
	echo "" 1>&2
	echo "Manage CPU throttle and CPU fan speed based on CPU temperature." 1>&2
	echo "" 1>&2
	echo "Parameters:" 1>&2
	echo " TT - Throttle Threshold: " 1>&2
	echo "      maximum desired temperature in Celsius above which CPU is throtteled." 1>&2
	echo " FT - Fan Threshold:" 1>&2
	echo "      maximum desired temperature in Celsius above which CPU Fan speed is set to maximum." 1>&2
	echo "" 1>&2
	echo "For example:" 1>&2
	echo " ${0} 60" 1>&2
	echo " ${0} 70 60" 1>&2
	echo "" 1>&2
	echo "Configuration:" 1>&2
	echo "${0} can be customized via settings stored in $HOME/.config/temp-throttle" 1>&2
	exit 2
else
	#Set the first argument as the maximum desired temperature.
	MAX_TEMP=$1
	MAX_FAN_TEMP=999
	if [ $# -eq 2 ]; then
		MAX_FAN_TEMP=$2
	fi
fi


### START Initialize Global variables.

# Load user config
if [ -f $HOME/.config/temp-throttle ]; then
	. $HOME/.config/temp-throttle
fi

# The frequency will increase when low temperature is reached.
LOW_TEMP=$((MAX_TEMP - 5))
LOW_FAN_TEMP=$((MAX_FAN_TEMP - 5))

CORES=$(nproc) # Get number of CPU cores.
echo -e "Number of CPU cores detected: $CORES\n"
CORES=$((CORES - 1)) # Subtract 1 from $CORES for easier counting later.

# Temperatures internally are calculated to the thousandth.
MAX_TEMP=${MAX_TEMP}000
LOW_TEMP=${LOW_TEMP}000
MAX_FAN_TEMP=${MAX_FAN_TEMP}000
LOW_FAN_TEMP=${LOW_FAN_TEMP}000

FREQ_FILE=${FREQ_FILE:-/sys/devices/system/cpu/cpu0/cpufreq/scaling_available_frequencies}
FREQ_MIN=${FREQ_MIN:-/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_min_freq}
FREQ_MAX=${FREQ_MAX:-/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq}

# Store available cpu frequencies in a space separated string FREQ_LIST.
if [ -f $FREQ_FILE ]; then
	# If $FREQ_FILE exists, get frequencies from it.
	FREQ_LIST=$(cat $FREQ_FILE) || err_exit "Could not read available cpu frequencies from file $FREQ_FILE"
elif [ -f $FREQ_MIN -a -f $FREQ_MAX ]; then
	# Else if $FREQ_MIN and $FREQ_MAX exist, generate a list of frequencies between them.
	FREQ_LIST=$(seq $(cat $FREQ_MAX) -100000 $(cat $FREQ_MIN)) || err_exit "Could not compute available cpu frequencies"
else
	err_exit "Could not determine available cpu frequencies"
fi

FREQ_LIST_LEN=$(echo $FREQ_LIST | wc -w)

# CURRENT_FREQ will save the index of the currently used frequency in FREQ_LIST.
CURRENT_FREQ=2

# This is a list of possible locations to read the current system temperature.
TEMPERATURE_FILES="
/sys/class/thermal/thermal_zone0/temp
/sys/class/thermal/thermal_zone1/temp
/sys/class/thermal/thermal_zone2/temp
/sys/class/hwmon/hwmon0/temp1_input
/sys/class/hwmon/hwmon1/temp1_input
/sys/class/hwmon/hwmon2/temp1_input
/sys/class/hwmon/hwmon0/device/temp1_input
/sys/class/hwmon/hwmon1/device/temp1_input
/sys/class/hwmon/hwmon2/device/temp1_input
null
"

COOLING_DEVICE=${COOLING_DEVICE:-/sys/class/thermal/cooling_device0}

# Store the first temperature location that exists in the variable TEMP_FILE.
# The location stored in $TEMP_FILE will be used for temperature readings.
if [ -z $TEMP_FILE ]; then
	for file in $TEMPERATURE_FILES; do
		TEMP_FILE=$file
		[ -f $TEMP_FILE ] && break
	done
fi

[ $TEMP_FILE == "null" ] && err_exit "The location for temperature reading was not found."


### END Initialize Global variables.


### START define script functions.

# Set the maximum frequency for all cpu cores.
set_freq () {
	# From the string FREQ_LIST, we choose the item at index CURRENT_FREQ.
	FREQ_TO_SET=$(echo $FREQ_LIST | cut -d " " -f $CURRENT_FREQ)
	echo $FREQ_TO_SET
	for i in $(seq 0 $CORES); do
		echo $FREQ_TO_SET > /sys/devices/system/cpu/cpu$i/cpufreq/scaling_max_freq
	done
}

# Will reduce the frequency of cpus if possible.
throttle () {
	if [ $CURRENT_FREQ -lt $FREQ_LIST_LEN ]; then
		CURRENT_FREQ=$((CURRENT_FREQ + 1))
		echo -n "throttle "
		set_freq $CURRENT_FREQ
	fi
}

# Will increase the frequency of cpus if possible.
unthrottle () {
	if [ $CURRENT_FREQ -ne 1 ]; then
		CURRENT_FREQ=$((CURRENT_FREQ - 1))
		echo -n "unthrottle "
		set_freq $CURRENT_FREQ
	fi
}

# Will speedup fans.
throttle_fan () {
	echo "speedup fan"
	# Store current fan speed
	FAN_STATE=$(cat $COOLING_DEVICE/cur_state)
	echo $(cat $COOLING_DEVICE/max_state) > $COOLING_DEVICE/cur_state
}

# Will slow down fans.
unthrottle_fan () {
	echo "slowdown fan"
	# Restore fan speed
	echo $FAN_STATE > $COOLING_DEVICE/cur_state
}

get_temp () {
	# Get the system temperature.

	LAST_TEMP=$TEMP	
	TEMP=$(cat $TEMP_FILE)
}

### END define script functions.

TEMP=0
FAN_STATE=0

# Mainloop
while true; do
	get_temp # Gets the current tempurature and set it to the variable TEMP.

	if   [ $TEMP -gt $MAX_TEMP ]; then # Throttle if too hot.
		throttle
	elif [ $TEMP -le $LOW_TEMP ]; then # Unthrottle if cool.
		unthrottle
	fi

	if   [ $TEMP -gt $MAX_FAN_TEMP ] && [ $LAST_TEMP -le $MAX_FAN_TEMP ]; then # Speed up fan if too hot.
		throttle_fan
	elif [ $TEMP -le $LOW_FAN_TEMP ] && [ $LAST_TEMP -gt $LOW_FAN_TEMP ]; then # Slow down fan if cool.
		unthrottle_fan
	fi
	sleep 3 # The amount of time between checking tempuratures.
done
