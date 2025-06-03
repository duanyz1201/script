#!/usr/bin/env bash

REDIS_CLI="/usr/bin/redis-cli"    # 根据你的环境调整路径
REDIS_KEY="alerts:pending"

# 读取 JSON 告警数据（单条）
data=$(cat)

# 写入 Redis List（RPUSH 到队列尾）
if [ -n "$data" ]; then
  echo "$data" | $REDIS_CLI -x RPUSH "$REDIS_KEY"
fi