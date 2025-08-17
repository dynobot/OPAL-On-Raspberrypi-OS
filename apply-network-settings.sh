#!/bin/bash

# Wait for the network interface to be up
/bin/sleep 5

# Apply network queue length
/sbin/ifconfig wlan0 txqueuelen 2000

# Disable Wi-Fi power management
/sbin/iwconfig wlan0 power off
