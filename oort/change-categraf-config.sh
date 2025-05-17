/usr/bin/env bash

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

categraf_status=$(systemctl is-active categraf-new)
if [[ $? -ne 0 || $categraf_status != "active" ]];then
    log ERROR "categraf is not running!"
    exit 1
fi

if [[ ! -d /root/.ssh ]]; then
    mkdir -p /root/.ssh
    chmod 700 /root/.ssh
    log INFO "/root/.ssh directory created."
fi

ssh_key="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC7x4hA+rrhRSunWOqycokNon2WZ34igm1sUt3tcw3+F/I/0ctqB1aD8p/cT8WaX1t7NQ61mOf08fnlqv69uH/EHwfHflLqn/IkSoKKmrVs15Iy3rMtH4G3cKOnNWM8nP8opJsXH5KftJYwXrkAX5iAHpROLu9i5pGJYGscTDTXP8TI1V2ctJBuAlToV/1flKzpLgINAN0OBncvsSjMfk4p4HERS8rH4hnDZfT8RIQHZDOw/8Dvuwv+pPfrMzeplPT9aHz2ulNnrRKNr21wnbGJQCDqeq8o79tixewIh+VUZSpFIjaejSEQ9Z7PBCsapxCXkKPnozhDtXHrtPNRQKL5We1PpASd0bAD5s9HkMVuwxmDOGfos6v9ao+/Xq3KpQ7MoyDO0j8yCVnmbi9VP2IgJ076uLxV+rxmxnm86W1zV3M+DTExFsYbRIsHRovJ7rCIB7bnMa2KMa9aZq2nqacuRcoF9r5A64XdhgGmFom367UYZGvntywbS305G41VratTHQ4eyV5x4iQvhYcRYkF4EuKpJPMjLCY2tkKSE7IKeCVvrVEyAV51vpdXGnMQJbslLbClMENy2cGDEEzPKg3pLmjuxGSgTwb1urUwXKHrKRVOLLwlWaLMt1CLvGom+HLXOyk8Udjy23WGHPGXav5tFtNfnqaNKigVCPS6Iaxj+Q== remote-center"

if [[ ! grep -q "$ssh_key" /root/.ssh/authorized_keys ]]; then
    echo $ssh_key > /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys
fi

mkdir -p /etc/categraf/scripts/logs

curl -s -k -L --max-time 60 http://qp.duanyz.net:8088/dl/get-oort-machine-info.sh -o /etc/categraf/scripts/get-oort-machine-info.sh
if [[ $? -ne 0 ]];then
    log ERROR "download get-oort-machine-info.sh failed!"
    exit 1
fi
chmod +x /etc/categraf/scripts/get-oort-machine-info.sh

cat << EOF > /etc/categraf/conf/input.exec/exec.toml
interval = 15

[[instances]]
commands = [
    "/etc/categraf/scripts/get-oort-machine-info.sh"
]
timeout = 55
interval_times = 4
data_format = "influx"
EOF
if [[ $? -ne 0 ]];then
    log ERROR "write exec.toml failed!"
    exit 1
fi
systemctl restart categraf-new
if [[ $? -ne 0 ]];then
    log ERROR "restart categraf failed!"
    exit 1
fi
log INFO "categraf config changed successfully!"