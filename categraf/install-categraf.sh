#!/bin/bash

if [[ -z ${1} ]];then
    ip=$(ip addr|awk -F '[ /]+' '/inet/{print $3}'|grep -oP '^172.(20|28|29)\S+|^10.(17)\S+|^172.16\S+|^192.168.(30)\S+'|head -1)
elif [[ ${1} = "ecs" ]];then
    ip=$(curl -s ipinfo.io | jq -r '.ip')
elif [[ ${1} = "custom" ]];then
    ip=$(hostname)
    if [[ -z ${ip} ]];then
        echo "Unknown IP!"
        exit 1
    fi
fi

n9e_server="172.28.56.119,116.182.20.16"
categraf_program="categraf-v0.4.3-nvidia.tar.gz"
file_md5sum="8630dd23e47d255e3d84a5ad89f551eb"

if [[ -z ${ip} ]];then
    echo "Unknown IP!"
    exit 1
fi

pre_ip=$(echo ${ip} | awk -F. '{print $1"."$2"."$3}')

if [[ ${pre_ip} =~ "172.28" ]];then
    region="HEB"
    n9e_server="172.28.56.119"
    dl_server="172.28.56.119"
elif [[ ${pre_ip} =~ "192.168.30" ]];then
    region="QP-158"
    n9e_server="116.182.20.16"
    dl_server="qp.duanyz.net:8088/dl"
elif [[ ${pre_ip} =~ "172.20" ]];then
    region="HA"
    n9e_server="116.182.20.16"
    dl_server="qp.duanyz.net:8088/dl"
elif [[ ${pre_ip} =~ "172.16" || ${pre_ip} =~ "10.17" ]];then
    region="LZ-GZ"
    n9e_server="116.182.20.16"
    dl_server="qp.duanyz.net:8088/dl"
elif [[ ${1} = "ecs" || ${1} = "custom" ]];then
    region="${2}"
    n9e_server="116.182.20.16"
    dl_server="qp.duanyz.net:8088/dl"
fi

if [[ -e /etc/categraf ]];then
    echo "categraf is already installed, exit script..."
    exit 0
fi

curl -s -k -L --max-time 300 http://${dl_server}/${categraf_program} -o /tmp/${categraf_program}

if [[ $? != 0 ]];then
    echo "download categraf failed!"
    exit 1
fi

echo "${file_md5sum} /tmp/${categraf_program}" | md5sum -c

if [[ $? != 0 ]];then
    echo "Abnormal file md5 value"
    exit 1
fi

tar -zxf /tmp/${categraf_program} -C /etc/

if [[ $? != 0 ]];then
    echo "unzip failed!"
    exit 1
fi

mkdir -p /etc/categraf/scripts/logs
sed -i 's/1.1.1.1/'${ip}'/' /etc/categraf/conf/config.toml
sed -i 's/shanghai/'${region}'/' /etc/categraf/conf/config.toml
sed -i 's/172.28.56.119/'${n9e_server}'/g' /etc/categraf/conf/config.toml


cat << EOF > /etc/systemd/system/categraf-new.service
[Unit]
Description=Opensource telemetry collector
ConditionFileIsExecutable=/etc/categraf/categraf

After=network-online.target
Wants=network-online.target

[Service]
StandardOutput=journal
StandardError=journal
StartLimitInterval=3600
StartLimitBurst=10
ExecStart=/etc/categraf/categraf "-configs" "/etc/categraf/conf"

WorkingDirectory=/etc/categraf

ExecReload=/bin/kill -HUP "$MAINPID"



Restart=on-failure

RestartSec=120
EnvironmentFile=-/etc/sysconfig/categraf
KillMode=process
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now categraf-new.service

if [[ $(systemctl is-active categraf-new.service) != "active" ]];then
    echo "categraf install failed! please check..."
    exit 1
else
    echo "categraf install success"
fi