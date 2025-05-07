#!/bin/bash

if [[ $EUID -ne 0 ]]; then
    log ERROR "This script must be run as root. Please use sudo."
    exit 1
fi

if ! grep -q "root soft nofile 1048576" /etc/security/limits.conf;then
    echo -e "root soft nofile 1048576\nroot hard nofile 1048576" >> /etc/security/limits.conf
fi

systemctl disable ufw --now

apt update >/dev/null 2>&1

apt install jq nload lrzsz sysstat tree net-tools unzip lsscsi fping systemd-timesyncd -y >/dev/null 2>&1

echo 'NTP=ntp.aliyun.com' >> /etc/systemd/timesyncd.conf
timedatectl set-timezone Asia/Shanghai
timedatectl set-ntp true
systemctl restart systemd-timesyncd.service
timedatectl set-local-rtc 0