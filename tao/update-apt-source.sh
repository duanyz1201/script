#!/bin/bash

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root. Please use sudo."
    exit 1
fi

. /etc/os-release
if [[ $ID != "ubuntu" ]]; then
    echo "This script is only for Ubuntu systems."
    exit 1
fi

cp /etc/apt/sources.list /etc/apt/sources.list.bak
rm -f /etc/apt/sources.list.d/*

VERSION_2004() {
cat << EOF > /etc/apt/sources.list
deb https://mirrors.aliyun.com/ubuntu/ focal main restricted universe multiverse
deb-src https://mirrors.aliyun.com/ubuntu/ focal main restricted universe multiverse

deb https://mirrors.aliyun.com/ubuntu/ focal-security main restricted universe multiverse
deb-src https://mirrors.aliyun.com/ubuntu/ focal-security main restricted universe multiverse

deb https://mirrors.aliyun.com/ubuntu/ focal-updates main restricted universe multiverse
deb-src https://mirrors.aliyun.com/ubuntu/ focal-updates main restricted universe multiverse

# deb https://mirrors.aliyun.com/ubuntu/ focal-proposed main restricted universe multiverse
# deb-src https://mirrors.aliyun.com/ubuntu/ focal-proposed main restricted universe multiverse

deb https://mirrors.aliyun.com/ubuntu/ focal-backports main restricted universe multiverse
deb-src https://mirrors.aliyun.com/ubuntu/ focal-backports main restricted universe multiverse
EOF
}

VERSION_2204() {
cat << EOF > /etc/apt/sources.list
deb https://archive.ubuntu.com/ubuntu/ jammy main restricted universe multiverse
deb-src https://archive.ubuntu.com/ubuntu/ jammy main restricted universe multiverse

deb https://archive.ubuntu.com/ubuntu/ jammy-security main restricted universe multiverse
deb-src https://archive.ubuntu.com/ubuntu/ jammy-security main restricted universe multiverse

deb https://archive.ubuntu.com/ubuntu/ jammy-updates main restricted universe multiverse
deb-src https://archive.ubuntu.com/ubuntu/ jammy-updates main restricted universe multiverse

# deb https://archive.ubuntu.com/ubuntu/ jammy-proposed main restricted universe multiverse
# deb-src https://archive.ubuntu.com/ubuntu/ jammy-proposed main restricted universe multiverse

deb https://archive.ubuntu.com/ubuntu/ jammy-backports main restricted universe multiverse
deb-src https://archive.ubuntu.com/ubuntu/ jammy-backports main restricted universe multiverse
EOF
}

if [[ $VERSION_ID == "20.04" ]]; then
    VERSION_2004
elif [[ $VERSION_ID == "22.04" ]]; then
    VERSION_2204
else
    echo "Unsupported Ubuntu version: $VERSION_ID"
    exit 1
fi