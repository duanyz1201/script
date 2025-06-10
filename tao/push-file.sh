#!/usr/bin/env bash

MODEL_DIR="/var/snap/cache/hub"
IP_LIST=("10.254.20.11" "10.254.20.12" "10.254.20.13" "10.254.20.14" "10.254.20.15" "10.254.20.16" "10.254.20.17" "10.254.20.18" "10.254.20.19" "10.254.20.20" "10.254.20.21" "10.254.20.22" "10.254.20.23" "10.254.20.24" "10.254.20.25" "10.254.20.26")

# 获取本机的模型目录名列表
MODEL_NAMES=$(ls -1 "$MODEL_DIR" | grep '^models--')

for model in $MODEL_NAMES; do
    echo "🔍 正在处理模型: $model"

    model_open_num=$(lsof +D "$MODEL_DIR/$model" | wc -l)
    if [ "$model_open_num" -gt 0 ]; then
        echo "   ⚠️  本地模型 $model 正在被占用，跳过分发"
        continue
    fi

    for host in "${IP_LIST[@]}"; do
        echo "   - 检查 $host 是否已有该模型..."
        ssh "$host" "test -d '$MODEL_DIR/$model'" >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo "     ✅ $host 已有 $model,跳过"
        else
            echo "     ⏬ 分发 $model 到 $host"
            rsync -a --progress --no-compress "$MODEL_DIR/$model" "$host:$MODEL_DIR/" && echo "     ✅ 分发成功" || echo "     ❌ 分发失败"
        fi
    done
done