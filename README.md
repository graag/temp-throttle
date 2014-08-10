temp-throttle
=============

A shell script for throttling system CPU frequency based on a desired maximum temperature.

Set a desired maximum temperature for your system using this script. If the maximum temperature is exceeded, the script will limit the speed of your CPU cores incrementally until the system is again below your desired maximum temperature. (If your system remains above maximum temperature after completely limiting your CPU cores, it will simply stay limited until temperatures drop below the maximum desired.)


This script must be run with root or sudo privileges. Only Celsius temperatures are supported. This example will limit system temperatures to 80 Celsius:

    sudo ./temp_throttle 80

The script can in addition adjust CPU fan speed. When a temperature threshold is exceeded the CPU fan speed is set to maximum. When CPU cools down the fan speed is reset to the previous value.

Configuration of the script can be altered using $HOME/.config/temp-throttle settings file. Supported settings:
# File defining available CPU frequencies 
FREQ_FILE=/sys/devices/system/cpu/cpu0/cpufreq/scaling_available_frequencies
# Files defining available frequency range. Used when FREQ_FILE is not available.
FREQ_MIN=/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_min_freq
FREQ_MAX=/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq
# Temperature sensor
TEMP_FILE=/sys/class/thermal/thermal_zone0/temp
# CPU fan device
COOLING_DEVICE=/sys/class/thermal/cooling_device0


For more instructions, see here:  
http://seperohacker.blogspot.com/2012/10/linux-keep-your-cpu-cool-with-frequency.html


Author: Sepero (sepero 111 @ gmx . com)

Links: http://github.com/Sepero/temp-throttle/  
Links: http://seperohacker.blogspot.com/2012/10/linux-keep-your-cpu-cool-with-frequency.html  

License: GNU GPL 2.0

Usage CPU throttle:                        `temp_throttle.sh max_temp`  
Usage CPU throttle + fan speed adjustment: `temp_throttle.sh max_temp max_fan_temp`
USE CELSIUS TEMPERATURES
