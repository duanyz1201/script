#!/bin/bash

zabbix_server="10.0.0.38"
agent_hostname=$(ip a|grep -oP '(?<=inet\s)\d+(\.\d+){3}'|grep -E ^'172|192'|head -n 1)

ubuntu_2004_dl_link="https://repo.zabbix.com/zabbix/6.4/ubuntu/pool/main/z/zabbix-release/zabbix-release_6.4-1+ubuntu20.04_all.deb"
ubuntu_2204_dl_link="https://repo.zabbix.com/zabbix/6.4/ubuntu/pool/main/z/zabbix-release/zabbix-release_6.4-1+ubuntu22.04_all.deb"


get_os_version(){
	os_id=$(grep '^ID=' /etc/os-release |tr -d '"'|awk -F '=' '{print $NF}')
	os_ver_id=$(grep 'VERSION_ID' /etc/os-release |tr -d '"|.'|awk -F '=' '{print $NF}')
	os_ver="${os_id}_${os_ver_id}"
}

download_and_install_zabbix_agent2(){
	download_link=$1
	download_dir="/tmp"
	agent_file="${download_dir}/$(basename ${download_link})"

	if [ ! -e "$agent_file" ];then
		wget -P "${download_dir}" "${download_link}"
	fi

	if [ -e "$agent_file" ];then
		dpkg -i "${agent_file}"
		apt update
		apt install jq zabbix-agent2 zabbix-agent2-plugin-* -y
	else
		echo "error: download failed"
		exit 1
	fi
}

init_conf(){
	sed -i -e 's/User=zabbix/User=root/' -e 's/Group=zabbix/Group=root/' /lib/systemd/system/zabbix-agent2.service
	mkdir /etc/zabbix/script
	sed -i 's/^Server=.*/Server='$zabbix_server'/' /etc/zabbix/zabbix_agent2.conf
	sed -i 's/^ServerActive=.*/ServerActive='$zabbix_server'/' /etc/zabbix/zabbix_agent2.conf
	sed -i 's/^Hostname=.*/Hostname='$agent_hostname'/' /etc/zabbix/zabbix_agent2.conf
	sed -i 's/^# Timeout=.*/Timeout=30/' /etc/zabbix/zabbix_agent2.conf
	systemctl daemon-reload
	systemctl restart zabbix-agent2.service

}

get_os_version

case "${os_ver}" in
	"ubuntu_2004")
		download_and_install_zabbix_agent2 "$ubuntu_2004_dl_link"
		;;
	"ubuntu_2204")
		download_and_install_zabbix_agent2 "$ubuntu_2204_dl_link"
		;;
	*)
		echo "Unknown OS: ${os_ver}"
		exit 1
		;;
esac

init_conf
