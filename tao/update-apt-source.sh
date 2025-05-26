#!/bin/bash

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root. Please use sudo."
    exit 1
fi

. /etc/os-release
if [[ $ID != "ubuntu" || $VERSION_ID != "22.04" ]]; then
    echo "This script is only for Ubuntu 22.04."
    exit 1
fi

cp /etc/apt/sources.list /etc/apt/sources.list.bak
rm -f /etc/apt/sources.list.d/*

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