#!/bin/bash

ip=$(ip addr|awk -F '[ /]+' '/inet/{print $3}'|grep -oP '^172.(28|29|30|31)\S+'|head -1)
dl_farmer_program_name="autonomys-farmer-oula-0307"
dl_node_program_name="autonomys-node-oula"
ai3_net="ai3-mainnet"
ai3_dir="/root/ai3"
nats_program_name="nats-server-v2.10.22-linux-amd64.tar.gz"
nats_dir="/root/nats"
log_dir="/root/logs"
config_file="/root/ai3-cluster-config.json"

check_and_create_dir() {
    dir=$1
    if [[ ! -d $dir ]]; then
        echo "dir $dir does not exist, creating..."
        mkdir -p $dir
    fi
}

check_and_create_dir $ai3_dir
check_and_create_dir $log_dir

if [[ ! -f $config_file ]];then
    echo "config file not exist,exit script..."
    exit 1
fi

check_dependency() {
    command -v $1 &>/dev/null
    if [[ $? -ne 0 ]]; then
        echo "$1 is not installed, installing..."
        apt-get update &>/dev/null
        apt-get install -y $1 &>/dev/null
        if [[ $? -eq 0 ]]; then
            echo "$1 installed successfully"
        else
            echo "Failed to install $1, please check"
            exit 1
        fi
    fi
}

check_dependency jq
check_dependency numactl

match_dl_server() {
    random_num=$((RANDOM % 2))

    if [[ $ip ]];then
        ip_prefix=$(echo $ip|awk -F '.' '{print $1"."$2}')
        if [[ "$ip_prefix" = "172.28" ]];then
            dl_servers=("172.28.110.43" "172.28.110.43")
            dl_server=${dl_servers[$random_num]}
        else
            echo "unknown ip prefix"
            exit 1
        fi
    else
        echo "unknown ip addr: $ip"
        exit 1
    fi
}

match_wallet_addr() {
    address=$(curl -s --max-time 3 http://${dl_server}/ai3-wallet.txt|grep -w $ip|awk '{print $2}')

    if [[ $? == 0 && $address ]];then
        echo "match wallet addr success"
    else
        echo "match wallet addr failed"
        exit 1
    fi
}

match_cluster_info() {
    cluster_local_info=$(cat ${config_file} |jq -r --arg ip "$ip" '.clusters[]|{name: .name, role: (to_entries[] |select(.value | .. | select(. == $ip)) |.key)}')
    if [[ $? -ne 0 || -z $cluster_local_info ]]; then
        echo "Failed to parse cluster info for IP: $ip"
        exit 1
    fi

    cluster_name=$(echo $cluster_local_info|jq -rs '.[0].name')
    if [[ -z $cluster_name ]]; then
        echo "Failed to find cluster name for IP: $ip"
        exit 1
    fi

    nats_server_ip=$(cat ${config_file}|jq -r --arg cluster_name "$cluster_name" '.clusters[]|select (.name == $cluster_name)|.nats_seed_nodes[],.nats_nodes[]')
    node_ip=$(cat ${config_file}|jq -r --arg cluster_name "$cluster_name" '.clusters[]|select (.name == $cluster_name)|.ai3_node[]' | shuf -n 1)

    if [[ ! $nats_server_ip || ! $node_ip ]];then
        echo "failed to find nats_server or node_ip"
        exit 1
    fi

    nats_server=""
    for nats_ip in $nats_server_ip
    do
        nats_server+="--nats-server nats://$nats_ip:4222 "
    done
}

get_nvme_disk() {
. /etc/os-release

if [[ "$VERSION_ID" = "20.04" ]];then
    os_disk=$(lsblk -lna -o name,fstype,rota,mountpoint|awk '$4 == "/" {print $1}'|grep -oP 'sd[a-z]+|nvme[n0-9]+')
    if [[ $os_disk ]];then
        ssd_nvme_disk=$(lsblk -lna -o name,fstype,rota,mountpoint|grep -Pv "loop|linux_raid_member|$os_disk\d?"|awk '$3 == 0 && $4 != "" {print $4}')
    else
        echo "os disk is unknown"
        exit 1
    fi
elif [[ "$VERSION_ID" = "22.04" ]];then
    os_disk=$(lsblk -lna -o name,fstype,rota,mountpoints|awk '$4 == "/" {print $1}'|grep -oP 'sd[a-z]+|nvme[n0-9]+')
    if [[ $os_disk ]];then
        ssd_nvme_disk=$(lsblk -lna -o name,fstype,rota,mountpoints|grep -Pv "loop|linux_raid_member|$os_disk\d?"|awk '$3 == 0 && $4 != "" {print $4}')
    else
        echo "os disk is unknown"
        exit 1
    fi
else
    echo "unknown os"
    exit 1
fi
}

get_plot_client_paths() {
paths=""

for i in $ssd_nvme_disk
do
#    if [[ -d "$i/$ai3_net" ]];then
#        farmer_dir=$(ls -d $i/$ai3_net/farmer*|xargs)
#        if [[ -z $farmer_dir ]];then
#            echo "Error: please check dir ${i}"
#            exit 1
#        fi
#
#        for ii in $farmer_dir
#        do
#            size=$(($(jq .[].allocatedSpace $ii/single_disk_farm.json)/1024/1024/1024))
#
#            if [[ $? -ne 0 || ! $size || $size -lt 300 ]];then
#                echo "Error: unable to get size for $ii"
#                exit 1
#            fi
#
#            paths+="path=$ii,sectors=${size} "
#        done
#    else
        available_space=$(df -BG ${i}|grep "${i}"|awk '{print $2}'|sed 's/G//')
        if [[ ! $available_space || $available_space -le 300 ]];then
            echo "skiped dir ${i}"
            continue
        fi

       # plot_size=$(($available_space - 10))
        plot_size=$(echo $available_space |awk '{print int($1 / 0.985)}')
        mkdir -p "${i}/$ai3_net"
        farm_dir="${i}/$ai3_net/farmer-1"
        paths+="path=${farm_dir},sectors=${plot_size} "
#    fi
done
}

start_nats() {
    nats_process_num=$(ps aux |awk '{print $11}'|grep nats-server|grep -v grep -c)
    if [[ ${nats_process_num} -ne 0 ]];then
        echo "The process already exists, exit the script..."
        exit 1
    fi

    check_and_create_dir $nats_dir

    wget -q -O /tmp/${nats_program_name} "http://${dl_server}/${nats_program_name}"

    if [[ ! $? -eq 0 ]];then
        echo "download nats server file failed"
        exit 1
    else
        echo "download success,start unzip..."
        tar --strip-components=1 -zxf /tmp/${nats_program_name} -C ${nats_dir}
        if [[ ! $? -eq 0 ]];then
            echo "unzip failed,please check~~~"
            exit 1
        fi
        echo "unzip success~~~"
    fi

    cluster_info=$(cat ${config_file}| jq -r --arg ip "${ip}" '.clusters[] | select((.nats_seed_nodes | any(. == $ip)) or (.nats_nodes | any(. == $ip)))| {name: .name, role: (if (.nats_seed_nodes | any(. == $ip)) then "nats_seed_nodes" else "nats_nodes" end)}')
    cluster_name=$(echo ${cluster_info}| jq -r .name)
    local_role=$(echo ${cluster_info}| jq -r .role)

    if [[ ${local_role} = "nats_seed_nodes" ]];then
        routes_ip=$(cat ${config_file}|jq -r --arg cluster_name "${cluster_name}" '.clusters[]|select (.name == $cluster_name)|.nats_seed_nodes[]'|grep -v "${ip}")
        routes_ip="nats-route://${routes_ip}:4248"
    elif [[ ${local_role} = "nats_nodes" ]];then
        routes_ip=$(cat ${config_file}|jq -r --arg cluster_name "${cluster_name}" '.clusters[]|select (.name == $cluster_name)|.nats_seed_nodes[]' | shuf -n 1)
        routes_ip="nats-route://${routes_ip}:4248"
    else
        echo "Please check if the NATS role is correct"
        exit 1
    fi

cat << EOF > ${nats_dir}/nats.conf
server_name: "${ip}"
port: 4222
host: 0.0.0.0
http_port: 8222

jetstream {
  store_dir: "/root/nats"
}

cluster {
  name: ${cluster_name}
  host: '0.0.0.0'
  port: 4248

  routes = [${routes_ip}]
}

debug:  false
trace:  false
logtime: true
log_file: "${log_dir}/nats.log"

pid_file: "/tmp/nats.pid"

max_connections: 3000
max_control_line: 512
max_payload: 3MB
max_pending: 268435456
EOF

    setsid ${nats_dir}/nats-server -c ${nats_dir}/nats.conf &>/dev/null &

    sleep 2

    nats_process_num=$(ps aux |awk '{print $11}'|grep nats-server|grep -v grep -c)
    if [[ ${nats_process_num} -eq 1 ]];then
        echo "nats-server start success"
    else
        echo "nats-server start failed"
    fi
}

start_node() {
    node_program_name="ai3-node"
    node_dir="/data/autonomys-node"
    node_name=$(echo $ip|tr '.' '-')
    node_process_num=$(ps aux |grep ${node_program_name}|grep -v grep -c)
    
    if [[ ${node_process_num} -ne 0 ]];then
        echo "${node_program_name} process already exists, exit the script..."
        exit 1
    fi

    if [[ ! -e $node_dir ]];then
        echo "${node_dir} not exists,check system disk available space..."
        mkdir -p /data
        available_space=$(df -BG /data|awk 'NR > 1 {print $4}'|sed 's/G//')
        if [[ $available_space -gt 60 ]];then
            echo "available space is greater than 60GB,create node dir..."
            mkdir -p $node_dir
        else
            echo "Insufficient system disk space, unable to start node"
            exit 1
        fi
    fi

    wget -q -O "$ai3_dir/$node_program_name" "$dl_server/$dl_node_program_name"

    if [[ ! $? == 0 ]];then
        echo "download mining file failed"
        exit 1
    else
        chmod +x "$ai3_dir/$node_program_name"
    fi

    setsid $ai3_dir/$node_program_name run --chain mainnet --base-path $node_dir --name $node_name --farmer --rpc-listen-on 0.0.0.0:9944 --rpc-methods unsafe --sync snap --rpc-max-connections 1000 --rpc-cors all --prometheus-listen-on 0.0.0.0:6061 --listen-on /ip4/0.0.0.0/tcp/30333 --in-peers 80 --out-peers 80 --dsn-listen-on /ip4/0.0.0.0/tcp/30433 --allow-private-ips &>${log_dir}/ai3-node.log &

    sleep 2

    node_process_num=$(ps aux |grep $node_program_name|grep -v grep -c)

    if [[ ${node_process_num} -eq 1 ]];then
        echo "${node_program_name} started successfully"
    else
        echo "${node_program_name} started failed,exit script..."
        exit 1
    fi
}

start_controller() {
    controller_program_name="ai3-controller"

    controller_process_num=$(ps aux |grep $controller_program_name|grep -v grep -c)

    if [[ $controller_process_num -ne 0 ]];then
        echo "${controller_program_name} process already exists, exit the script..."
        exit 1
    fi

    wget -q -O "$ai3_dir/$controller_program_name" "$dl_server/$dl_farmer_program_name"
 
    if [[ ! $? == 0 ]];then
        echo "download proof server file failed"
        exit 1
    else
        chmod +x "$ai3_dir/$controller_program_name"
    fi

     setsid $ai3_dir/$controller_program_name cluster ${nats_server} controller --retain-metadata --tmp --node-rpc-url ws://${node_ip}:9944 &>${log_dir}/ai3-controller.log &

    sleep 2

    controller_process_num=$(ps aux |grep $controller_program_name|grep -v grep -c)

    if [[ $controller_process_num -eq 1 ]];then
        echo "${controller_program_name}started successfully"
    else
        echo "${controller_program_name} startup failed,exit script..."
        exit 1
    fi 
}

start_proof_server() {
    proof_server_program_name="ai3-proof-server"

    proof_server_process_num=$(ps aux |grep $proof_server_program_name|grep -v grep -c)

    if [[ $proof_server_process_num -ne 0 ]];then
        echo "${proof_server_program_name} process already exists, exit the script..."
        exit 1
    fi

    wget -q -O "$ai3_dir/$proof_server_program_name" "$dl_server/$dl_farmer_program_name"

    if [[ ! $? == 0 ]];then
        echo "download mining file failed"
        exit 1
    else
        chmod +x "$ai3_dir/$proof_server_program_name"
    fi

    if [[ -e /root/gpu-index ]];then
        . /root/gpu-index
            if [[ -z $AUTO_GPU_INDEX ]];then
                echo "GPU index error: AUTO_GPU_INDEX is not set"
                exit 1
            else
                gpu_process_name=$(nvidia-smi -i ${AUTO_GPU_INDEX} --query-compute-apps=process_name --format=csv,noheader)
                if [[ -z ${gpu_process_name} ]];then
                    echo "select gpu index: $AUTO_GPU_INDEX"
                else
                    echo "gpu index ${AUTO_GPU_INDEX}: ${gpu_process_name}"
                    exit 1
                fi
            fi
    else
        echo "gpu-index file not exists"
        exit 1
    fi

     setsid env CUDA_VISIBLE_DEVICES=${AUTO_GPU_INDEX} env RUST_LOG="info,subspace_farmer::cluster::sharded_cluster_item_getter=debug" $ai3_dir/$proof_server_program_name cluster ${nats_server} proof-server --exporter-endpoint http://172.28.56.111:9091/metrics/job/proof_server --exporter-internal 15 --proof-label ${cluster_name} &>${log_dir}/ai3-proof-server.log &

    proof_server_process_num=$(ps aux |grep $proof_server_program_name|grep -v grep -c)

    if [[ $proof_server_process_num -eq 1 ]];then
        echo "${proof_server_program_name} started successfully"
    else
        echo "${proof_server_program_name} startup failed,exit script..."
        exit 1
    fi 
}

start_cache() {
    full_cache_program_name="ai3-full-cache"
    sharded_cache_program_name="ai3-sharded-cache"

    if [[ ! $ssd_nvme_disk ]];then
            echo "No available disk detected"
            exit 1
    else
        cache_disk=$(echo ${ssd_nvme_disk}|awk '{print $1}')
        full_cache_dir="${cache_disk}/autonomys-full-cache"
        sharded_cache_dir="${cache_disk}/autonomys-sharded-cache"
    fi

    full_cache_process_num=$(ps aux |grep $full_cache_program_name|grep -v grep -c)
    sharded_cache_process_num=$(ps aux |grep $sharded_cache_program_name|grep -v grep -c)

    if [[ $full_cache_process_num -ne 0 || $sharded_cache_process_num -ne 0 ]];then
        echo "${full_cache_program_name} or ${sharded_cache_program_name} process already exists, exit the script..."
        exit 1
    fi

    if [[ ! -e $full_cache_dir ]];then
        echo "${full_cache_dir} dir not exists,check system disk available space..."
        available_space=$(df -BG |grep -w "${cache_disk}"|awk '{print $4}'|sed 's/G//')
        if [[ $available_space -gt 100 ]];then
            echo "available space is greater than 100GB,create node dir..."
            mkdir -p $full_cache_dir
            mkdir -p $sharded_cache_dir
        else
            echo "Insufficient system disk space, unable to start node"
            exit 1
        fi
    fi

    wget -q -O "$ai3_dir/$full_cache_program_name" "$dl_server/$dl_farmer_program_name"
 
    if [[ ! $? == 0 ]];then
        echo "download mining file failed"
        exit 1
    else
        chmod +x "$ai3_dir/$full_cache_program_name"
        cp "$ai3_dir/$full_cache_program_name" "$ai3_dir/$sharded_cache_program_name"
    fi

    #setsid $ai3_dir/$full_cache_program_name cluster ${nats_server} full-piece-sharded-cache --visible path=${full_cache_dir} &>${log_dir}/ai3-full-cache.log &
    setsid $ai3_dir/$full_cache_program_name cluster ${nats_server} full-piece-sharded-cache path=${full_cache_dir} &>${log_dir}/ai3-full-cache.log &

    sleep 10

    setsid $ai3_dir/$sharded_cache_program_name cluster ${nats_server} sharded-cache --mem-cache path=${sharded_cache_dir} &>${log_dir}/ai3-sharded-cache.log &

    sleep 2

    full_cache_process_num=$(ps aux |grep $full_cache_program_name|grep -v grep -c)
    sharded_cache_process_num=$(ps aux |grep $sharded_cache_program_name|grep -v grep -c)

    if [[ $full_cache_process_num -eq 1 && $sharded_cache_process_num -eq 1 ]];then
        echo "${full_cache_program_name} and ${sharded_cache_program_name} started successfully"
    else
        echo "${full_cache_program_name} and ${sharded_cache_program_name} startup failed,exit script..."
        exit 1
    fi 
}

start_plot_server() {
    plot_server_program_name="ai3-plot-server"
    plot_server_process_num=$(ps aux |grep $plot_server_program_name|grep -v grep -c)

    if [[ -e /root/gpu-index ]];then
        . /root/gpu-index
            if [[ -z $AUTO_GPU_INDEX ]];then
                echo "GPU index error: AUTO_GPU_INDEX is not set"
                exit 1
            else
                gpu_process_name=$(nvidia-smi -i ${AUTO_GPU_INDEX} --query-compute-apps=process_name --format=csv,noheader)
                if [[ -z ${gpu_process_name} ]];then
                    echo "select gpu index: $AUTO_GPU_INDEX"
                    start_gpu_index=$(echo "${AUTO_GPU_INDEX}" | tr ',' ' ')
                else
                    echo "gpu index ${AUTO_GPU_INDEX}: ${gpu_process_name}"
                    exit 1
                fi
            fi
    else
        echo "gpu-index file not exists"
        exit 1
    fi

    if [[ ${plot_server_process_num} -ne 0 ]];then
        echo "${plot_server_process_num} process already exists, exit the script..."
        exit 1
    fi

    wget -q -O "$ai3_dir/$plot_server_program_name" "$dl_server/$dl_farmer_program_name"

    if [[ ! $? == 0 ]];then
        echo "download mining file failed"
        exit 1
    else
        chmod +x "$ai3_dir/$plot_server_program_name"
    fi

    start_process_num="0"
    plot_server_port="9966"
    > ${log_dir}/ai3-plot-server.log

    for index in ${start_gpu_index}
    do
        #cpu_affinity=$(nvidia-smi topo -m |awk '$1 == "'GPU${index}'" {print $(NF-2)}'|awk -F ',' '{print $1}')
        cpu_affinity=$(nvidia-smi topo -m |awk '$1 == "'GPU${index}'" {print $(NF-2)}')
        if [[ ! $? -eq 0 ]];then
            echo "CPU Affinity Get Failed,Please Check..."
            exit 1
        fi

        mkdir -p /tmp/autonomys-plot-server-${index}

	setsid numactl -C ${cpu_affinity} -l env CUDA_VISIBLE_DEVICES=${index} "$ai3_dir/$plot_server_program_name" cluster ${nats_server} plot-server --priority-cache --listen-port ${plot_server_port} /tmp/autonomys-plot-server-${index} &>>${log_dir}/ai3-plot-server.log &
        ((start_process_num++))
        ((plot_server_port++))
    done

    sleep 2

    plot_server_process_num=$(ps aux |grep $plot_server_program_name|grep -v grep -c)

    if [[ $plot_server_process_num -eq $start_process_num ]];then
        echo "${plot_server_program_name} started successfully"
    else
        echo "${plot_server_program_name} started failed,exit script..."
        exit 1
    fi
}


start_plot_client() {
    plot_client_program_name="ai3-plot-client"
    plot_client_process_num=$(ps aux |grep $plot_client_program_name|grep -v grep -c)

    if [[ ${plot_client_process_num} -ne 0 ]];then
        echo "${plot_client_program_name} process already exists, exit the script..."
        exit 1
    fi

    wget -q -O "$ai3_dir/$plot_client_program_name" "$dl_server/$dl_farmer_program_name"

    if [[ ! $? == 0 ]];then
        echo "download mining file failed"
        exit 1
    else
        chmod +x "$ai3_dir/$plot_client_program_name"
    fi

#    paths=($paths)
#    total=${#paths[@]}
#    half=$((total / 2))
#
#    IP=$(echo ${ip} | tr '.' '_')

    setsid env FARMING_WITH_DIO=1 "$ai3_dir/$plot_client_program_name" cluster $nats_server plot-client --endpoint http://172.28.56.111:9091/metrics/job/farmer --internal 15 --farmer-label ${cluster_name} --reward-address $address $paths &>${log_dir}/ai3-plot-client.log &
#    setsid "$ai3_dir/$plot_client_program_name" cluster $nats_server plot-client --endpoint http://172.28.56.111:9091/metrics/job/farmer-${IP}-01 --internal 15 --farmer-label process-01 --reward-address $address ${paths[@]:0:half} &>>${log_dir}/ai3-plot-client.log &

#    sleep 2
    
#    setsid "$ai3_dir/$plot_client_program_name" cluster $nats_server plot-client --endpoint http://172.28.56.111:9091/metrics/job/farmer-${IP}-02 --internal 15 --farmer-label process-02 --reward-address $address ${paths[@]:half} &>>${log_dir}/ai3-plot-client.log &

    sleep 2

    plot_client_process_num=$(ps aux |grep $plot_client_program_name|grep -v grep -c)

    if [[ $plot_client_process_num -eq 1 ]];then
        echo "${plot_client_program_name} started successfully"
    else
        echo "${plot_client_program_name} started failed,exit script..."
        exit 1
    fi
}

match_dl_server

case $1 in
    nats)
        start_nats
        ;;
    node)
        start_node
        ;;
    controller)
        match_cluster_info
        start_controller
        ;;
    proof-server)
        match_cluster_info
        start_proof_server
        ;;
    cache)
        match_cluster_info
        get_nvme_disk
        start_cache
        ;;
    plot-server)
        match_cluster_info
        start_plot_server
        ;;
    plot-client)
        match_wallet_addr
        match_cluster_info
        get_nvme_disk
        get_plot_client_paths
        start_plot_client
        ;;
    *)
        echo "Usage: $0 {nats|node|controller|proof-server|cache|plot-server|plot-client}"
        exit 1
        ;;
esac
