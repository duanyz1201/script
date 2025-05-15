/usr/bin/env bash

log() {
    local level=$1
    shift
    local message=$@
    local timestamp=$(date +"%FT%T.%3N")
    echo "$timestamp $level - $message"
}

categraf_status=$(systemctl is-active categraf)
if [[ $? -ne 0 || $categraf_status != "active" ]];then
    log ERROR "categraf is not running!"
    exit 1
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
timeout = 15
interval_times = 4
data_format = "influx"
EOF
if [[ $? -ne 0 ]];then
    log ERROR "write exec.toml failed!"
    exit 1
fi
systemctl restart categraf
if [[ $? -ne 0 ]];then
    log ERROR "restart categraf failed!"
    exit 1
fi
log INFO "categraf config changed successfully!"