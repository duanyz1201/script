#!/usr/bin/env bash

log_file="/root/logs/notify_redis.log"

log() {
    local level=$1
    shift
    local message=$@
    local timestamp=$(date +"%FT%T.%3N")
    echo "$timestamp $level - $message" >> "$log_file"
}

REDIS_CLI="/usr/bin/redis-cli"

# 读取 JSON 告警
alert=$(cat)
if [[ -z "$alert" ]]; then
    log ERROR "No alert data received."
    exit 1
fi

# 提取告警等级
severity=$(echo "$alert" | jq -r '.event.severity')
if [[ -z "$severity" ]]; then
    log ERROR "Failed to extract severity from alert."
    exit 1
fi

# 映射到 Redis key
case "$severity" in
  1) REDIS_KEY="alerts:pending:s1" ;;
  2) REDIS_KEY="alerts:pending:s2" ;;
  3) REDIS_KEY="alerts:pending:s3" ;;
esac

# 写入 Redis
echo "$alert" | $REDIS_CLI -x RPUSH "$REDIS_KEY"
if [[ $? -ne 0 ]]; then
    log ERROR "Failed to write alert to Redis key: $REDIS_KEY"
    exit 1
else
    log INFO "Alert written to Redis key: $REDIS_KEY"
fi