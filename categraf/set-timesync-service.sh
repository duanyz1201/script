#!/usr/bin/env bash

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root. Please use sudo."
    exit 1
fi

log() {
    local level=$1
    shift
    local message=$@
    local timestamp=$(date +"%FT%T.%3N")
    echo "$timestamp $level - $message"
}



echo 'NTP=ntp.aliyun.com' >> /etc/systemd/timesyncd.conf
timedatectl set-timezone Asia/Shanghai
timedatectl set-ntp true
systemctl restart systemd-timesyncd.service
timedatectl set-local-rtc 0