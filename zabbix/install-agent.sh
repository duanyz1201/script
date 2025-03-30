#!/bin/bash

zabbix_server="172.28.56.68"
dl_server="172.28.56.68"
dl_port="8080"
agent_hostname=$(ip a|grep -oP '(?<=inet\s)\d+(\.\d+){3}'|grep -E ^'172.(28|30)'|head -n 1)

ubuntu_2004_dl_link="https://repo.zabbix.com/zabbix/6.4/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_6.4+ubuntu20.04_all.deb"
ubuntu_2204_dl_link="https://repo.zabbix.com/zabbix/6.4/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_6.4+ubuntu22.04_all.deb"
rocky_8_dl_link="https://repo.zabbix.com/zabbix/6.4/rhel/8/x86_64/zabbix-release-latest-6.4.el8.noarch.rpm"

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
		wget -q -P "${download_dir}" "${download_link}"
	fi

	if [ -e "$agent_file" ];then
        if [[ ${os_id} = "ubuntu" ]];then
		    dpkg -i "${agent_file}" &>/dev/null
		    apt update &>/dev/null
		    apt install jq zabbix-agent2 zabbix-agent2-plugin-* fping -y &>/dev/null
        elif [[ ${os_id} = "rocky" ]];then
            rpm -Uvh ${agent_file} &>/dev/null
            dnf clean all &>/dev/null
            dnf install zabbix-agent2 zabbix-agent2-plugin-* fping -y &>/dev/null
	    else
		    echo "error: download failed"
		    exit 1
	    fi
    fi
}

init_conf(){
	sed -i -e 's/User=zabbix/User=root/' -e 's/Group=zabbix/Group=root/' /lib/systemd/system/zabbix-agent2.service
	mkdir -p /etc/zabbix/script
	#sed -i 's/^Server=.*/Server='$zabbix_server'/' /etc/zabbix/zabbix_agent2.conf
	#sed -i 's/^ServerActive=.*/ServerActive='$zabbix_server'/' /etc/zabbix/zabbix_agent2.conf
	#sed -i 's/^Hostname=.*/Hostname='$agent_hostname'/' /etc/zabbix/zabbix_agent2.conf
	#sed -i 's/^# Timeout=.*/Timeout=30/' /etc/zabbix/zabbix_agent2.conf
    #echo "AllowKey=system.run[*]" >> /etc/zabbix/zabbix_agent2.conf
    #echo "Plugins.SystemRun.LogRemoteCommands=1" >> /etc/zabbix/zabbix_agent2.conf

cat << EOF > /etc/zabbix/zabbix_agent2.conf
PidFile=/var/run/zabbix/zabbix_agent2.pid
LogFile=/var/log/zabbix/zabbix_agent2.log
LogFileSize=0
Server=${zabbix_server}
ServerActive=${zabbix_server}
Hostname=${agent_hostname}
Timeout=30
Include=/etc/zabbix/zabbix_agent2.d/*.conf
PluginSocket=/run/zabbix/agent.plugin.sock
ControlSocket=/run/zabbix/agent.sock
Include=/etc/zabbix/zabbix_agent2.d/plugins.d/*.conf
AllowKey=system.run[*]
Plugins.SystemRun.LogRemoteCommands=1
EOF

    dl_custom_script

	systemctl daemon-reload
	systemctl restart zabbix-agent2
    systemctl enable zabbix-agent2

}

dl_custom_script(){
    wget -q -r -np -nH --cut-dirs=2 -R "index.html*" "${dl_server}":"${dl_port}"/custom_script/script/ -P /etc/zabbix/script/
    if [[ $? -eq 0 ]];then
        echo "custom script download success"
    else
        echo "custom script download failed"
    fi

    wget -q -r -np -nH --cut-dirs=2 -R "index.html*" "${dl_server}":"${dl_port}"/custom_script/config/ -P /etc/zabbix/zabbix_agent2.d/
    if [[ $? -eq 0 ]];then
        echo "custom config download success"
    else
        echo "custom config download failed"
    fi
}

command -v zabbix_agent2 >/dev/null
if [[ $? == 0 ]];then
    echo "zabbix agent is installed"
    init_conf
    exit 0
fi

get_os_version

case "${os_ver}" in
	"ubuntu_2004")
		download_and_install_zabbix_agent2 "${ubuntu_2004_dl_link}"
		;;
	"ubuntu_2204")
		download_and_install_zabbix_agent2 "${ubuntu_2204_dl_link}"
		;;
    "rocky_810")
        download_and_install_zabbix_agent2 "${rocky_8_dl_link}"
        ;;
	*)
		echo "Unknown OS: ${os_ver}"
		exit 1
		;;
esac

init_conf
