#!/bin/bash

speed_value=${1}

if [[ -n ${speed_value} && ${speed_value} =~ ^[0-9]+$ && ${speed_value} -le 100 ]];then
	conversion_value=$(printf "0x%x" ${speed_value})

	for region_num in $(seq 0 3)
	do
		ipmitool raw 0x30 0x70 0x66 0x01 0x0${region_num} ${conversion_value} >/dev/null 2>&1
		if [[ $? -eq 0 ]];then
			echo "set region ${region_num} fan speed success"
		else
			echo "set region ${region_num} fan speed failed"
			exit 1
		fi
	done
else
	echo "${speed_value} Not between 1 and 100"
	exit 1
fi
