#!/usr/bin/env bash

region="HEB"
name="ssc"

ip=$(ip route get 223.6.6.6 | head -n 1 | awk '{print $(NF-2)}'|tr '.' '-')
hostname=$(echo $region $ip|awk '{print $1"-"$2}')
echo $hostname

. /etc/os-release

if [[ "$VERSION_ID" = "20.04" ]];then
    hostnamectl set-hostname $hostname
elif [[ "$VERSION_ID" = "22.04" ]];then
    hostnamectl hostname $hostname
else
    echo "unknown os"
    exit 1
fi