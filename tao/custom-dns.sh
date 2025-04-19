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

rm /etc/resolv.conf

cat << EOF > /etc/resolv.conf
nameserver 8.8.8.8
nameserver 1.1.1.1
EOF

systemctl disable systemd-resolved
systemctl stop systemd-resolved