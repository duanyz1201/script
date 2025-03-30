#!/bin/bash 

ip=$(ip addr|awk -F '[ /]+' '/inet/{print $3}'|grep -oP '^172.(16|17)\S+'|head -1)
aleo_ver_name="aleo_prover_0.2.5"
aleo_dir="/root/aleo"
aleo_process_num=$(ps aux |grep ${aleo_ver_name} |grep -v grep -c)
worker_name=$(echo $ip|tr '.' '-')
nvidia_device_ver="NVIDIA-Linux-x86_64-550.107.02.run"
pool="aleo.asia1.zk.work:10003 --pool aleo.hk.zk.work:10003 --pool aleo.jp.zk.work:10003 --pool aleo.eu.zk.work:10003"
dl_server="172.16.101.11"

if [[ ! -e $aleo_dir ]];then
    echo "dir $aleo_dir does not exist,create..."
    mkdir -p $aleo_dir
fi

if [[ ! -e "/root/logs" ]];then
    echo "dir /root/logs does not exist,create..."
    mkdir -p /root/logs
fi

check_nvidia_status() {
        command -V nvidia-smi &>/dev/null
        if [[ ! $? -eq 0 ]];then
                if [[ -e /root/${nvidia_device_ver} ]];then
                        /root/${nvidia_device_ver} -s --dkms --no-opengl-files &>/dev/null
                        if [[ $? -eq 0 ]];then
                                nvidia-smi -pm 1 &>/dev/null
                                if [[ ! $? -eq 0 ]];then
                                        echo "The driver installation failed"
                                        exit 1
                                fi
                                echo "The driver installation was successful"
                        else
                                echo "The driver installation file does not exist. Please check"
                                exit 1
                        fi
                else
                        if ! grep -q "root soft nofile 1048576" /etc/security/limits.conf;then
                                echo -e "root soft nofile 1048576\nroot hard nofile 1048576" >> /etc/security/limits.conf
                        fi

                        echo -e "blacklist nouveau\noptions nouveau modeset=0" > /etc/modprobe.d/blacklist-nouveau.conf

                        apt update &>/dev/null
                        apt install gcc make jq -y &>/dev/null
                        update-initramfs -u

                        wget -q -O "/root/${nvidia_device_ver}" "http://${dl_server}/${nvidia_device_ver}"
                        if [[ -e /root/${nvidia_device_ver} ]];then
                                chmod +x "/root/${nvidia_device_ver}"
                                reboot
                        else
                                echo "Failed to download the driver installation file"
                                exit 1
                        fi
                fi
        fi

        nvidia-smi -pm 1 &>/dev/null
        if [[ $? -eq 9 ]];then
                if [[ -e /root/${nvidia_device_ver} ]];then
                        chmod +x /root/${nvidia_device_ver}
                        /root/${nvidia_device_ver} -s --dkms --no-opengl-files &>/dev/null
                        if [[ $? -eq 0 ]];then
                                nvidia-smi -pm 1 &>/dev/null
                                if [[ ! $? -eq 0 ]];then
                                        echo "The driver installation failed"
                                        exit 1
                                fi
                                echo "The driver installation was successful"
                        fi
                else
                        echo "The driver installation file does not exist. Please check"
                        exit 1
                fi
        fi
}

match_account()
{
    account=$(curl -s http://${dl_server}:80/ip-address|grep -w $ip|awk '{print $2}')

    if [[ $? == 0 && $account ]];then
        echo "match account success"
    else
        echo "match account failed"
        exit 1
    fi
}

dl_mining()
{
wget -q -O "$aleo_dir/$aleo_ver_name" "http://${dl_server}:80/$aleo_ver_name"

if [[ ! $? == 0 ]];then
    echo "download mining file failed"
    exit 1
else
    chmod +x "$aleo_dir/$aleo_ver_name"
fi
}

check_nvidia_status

if [[ $aleo_process_num -ne 0 ]];then
    echo "${aleo_ver_name} process existed"
    exit 1
fi

match_account
dl_mining

[ -f "/root/gpu-index" ] && . /root/gpu-index
if [[ -z ${ZKWORK_GPU_INDEX} ]];then
    setsid $aleo_dir/$aleo_ver_name --pool ${pool} --address ${account} --custom_name ${worker_name} &>/root/logs/zkwork.log &
else
    setsid $aleo_dir/$aleo_ver_name --pool ${pool} --address ${account} --custom_name ${worker_name} ${ZKWORK_GPU_INDEX} &>/root/logs/zkwork.log &
    echo "${ZKWORK_GPU_INDEX}"
fi

sleep 2

aleo_process_num=`ps aux |grep ${aleo_ver_name} |grep -v grep -c`
if [[ $aleo_process_num -gt 0 ]];then
    echo "${aleo_ver_name} start success"
else
    echo "${aleo_ver_name} start failed"
fi

