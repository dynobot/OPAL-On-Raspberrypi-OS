#!/bin/bash

# Set I/O scheduler to none for the SD card
echo none > /sys/block/mmcblk0/queue/scheduler

# Set RPS CPUs for wlan0
echo 7 > /sys/class/net/wlan0/queues/rx-0/rps_cpus
