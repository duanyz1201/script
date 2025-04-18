#!/bin/bash

log_file="/etc/categraf/scripts/logs/check_ports.log"

log() {
    local level="$1"
    local message="$2"
    echo "$(date '+%FT%T.%3N') $level - $message" >> "$log_file"
}

if [[ -z "$1" ]]; then
    log ERROR "Usage: $0 <target_file>"
    log ERROR "The target file should contain lines in the format: <IP> <PORT>"
    exit 1
fi

TARGET_FILE="$1"

if ! command -v nc &> /dev/null; then
    log ERROR "nc (Netcat) is not installed. Please install it and try again."
    exit 1
fi



while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^# ]] && continue

    IP=$(echo "$line" | awk -F ':' '{print $1}')
    PORT=$(echo "$line" | awk -F ':' '{print $2}')

    if [[ -z "$IP" || -z "$PORT" ]]; then
        log ERROR "Invalid line: $line"
        continue
    fi

    nc -z -w 3 "$IP" "$PORT" &> /dev/null
    if [[ $? -eq 0 ]]; then
        log INFO  "SUCCESS: $IP:$PORT is open"
        echo "server_port_check,ip=${IP},port=${PORT} open=1"
    else
        log ERROR "FAILURE: $IP:$PORT is not open"
        echo "server_port_check,ip=${IP},port=${PORT} open=0"
    fi
done < "$TARGET_FILE"