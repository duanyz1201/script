#!/bin/bash
set -e

ubuntu()
{
if ! grep -q "root soft nofile 1048576" /etc/security/limits.conf;then
    echo -e "root soft nofile 1048576\nroot hard nofile 1048576" >> /etc/security/limits.conf
fi

systemctl disable ufw --now &>/dev/null && echo 'disable ufw successful' || echo 'disable ufw failed!'

systemctl disable --now apt-daily.timer apt-daily.service apt-daily-upgrade.timer apt-daily-upgrade.service

killall -9 unattended-upgrade &>/dev/null && echo 'kill unattended-upgrade successful'
systemctl disable unattended-upgrades.service --now &>/dev/null && echo 'disable unattended-upgrades successful' || echo 'disable unattended-upgrades failed!'

if ! grep -q "PermitRootLogin yes" /etc/ssh/sshd_config;then
    echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
fi

echo 'root:OORT@2233.xxx' |chpasswd
echo 'zero:OORT@2233.xxx' |chpasswd

systemctl restart sshd

#if grep swap.img /etc/fstab |grep -v '^#' ;then
#    sed -i '/swap.img/ s/^/# /' /etc/fstab
#fi

. /etc/os-release
os_id="${NAME}_${VERSION_ID}"

if [[ "${os_id}" = Ubuntu_20.04 ]];then
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
elif [[ "${os_id}" = Ubuntu_22.04 ]];then
cat << EOF > /etc/apt/sources.list
deb https://mirrors.aliyun.com/ubuntu/ jammy main restricted universe multiverse
deb-src https://mirrors.aliyun.com/ubuntu/ jammy main restricted universe multiverse

deb https://mirrors.aliyun.com/ubuntu/ jammy-security main restricted universe multiverse
deb-src https://mirrors.aliyun.com/ubuntu/ jammy-security main restricted universe multiverse

deb https://mirrors.aliyun.com/ubuntu/ jammy-updates main restricted universe multiverse
deb-src https://mirrors.aliyun.com/ubuntu/ jammy-updates main restricted universe multiverse

# deb https://mirrors.aliyun.com/ubuntu/ jammy-proposed main restricted universe multiverse
# deb-src https://mirrors.aliyun.com/ubuntu/ jammy-proposed main restricted universe multiverse

deb https://mirrors.aliyun.com/ubuntu/ jammy-backports main restricted universe multiverse
deb-src https://mirrors.aliyun.com/ubuntu/ jammy-backports main restricted universe multiverse
EOF
else
    echo "${os_id}!!!"
    exit 1
fi

apt-get update >/dev/null && echo 'apt update successful' || echo 'apt update failed!'

apt-get install jq nload lrzsz sysstat tree net-tools unzip lsscsi systemd-timesyncd fping -y >/dev/null && echo 'Packages installed successfully' || echo 'Package installation failed!'

if ! grep -q "NTP=ntp.aliyun.com" /etc/systemd/timesyncd.conf;then
    echo 'NTP=ntp.aliyun.com' >> /etc/systemd/timesyncd.conf
fi

timedatectl set-timezone Asia/Shanghai
timedatectl set-ntp true
systemctl restart systemd-timesyncd.service


#cat >> /lib/systemd/system/rc-local.service << EOF
#
#[Install]
#WantedBy=multi-user.target
#Alias=rc-local.service
#EOF
#
#rm -f /etc/systemd/system/rc-local.service
#ln -s /lib/systemd/system/rc-local.service /etc/systemd/system/
#touch /etc/rc.local
#echo '#!/bin/bash' > /etc/rc.local
#chmod +x /etc/rc.local
#systemctl daemon-reload
#systemctl restart rc-local.service
}

. /etc/os-release 
os_id="${NAME_}_${VERSION_ID}"

os=$(grep "^NAME" /etc/os-release |awk -F '[=| ]' '{print $2}'|tr -d '"')

if [ $os = Ubuntu ];then
	ubuntu
else
	echo "unknown os"
fi
