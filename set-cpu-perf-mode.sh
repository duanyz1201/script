#!/bin/bash

apt install cpufrequtils -y

for i in `cat /proc/cpuinfo |awk '/processor/{print $NF}'`;do cpufreq-set -c $i -g performance;done

#cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor|sort |uniq -c
