#!/usr/bin/env bash

LOG_FILE="/root/script/ini/address_monitor.log"

log() {
    local level=$1
    shift
    local message=$@
    local timestamp=$(date +"%FT%T.%3N")
    echo "$timestamp $level - $message" | tee -a "$LOG_FILE"
}

ADDRESSES=(
  "0xe1cb106a748154aa5cd829f0ed8e6af609df97b3"
  "0xaa547a298a0b8471103a606145249b329d267b86"
)

INTERVAL=300
WECOM_WEBHOOK="https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=f751a289-bbba-4bc2-a927-e79a908551a1"
API_BASE="https://explorer-api.inichain.com/api/address/address_tx_list"

while true; do
  for ADDR in "${ADDRESSES[@]}"; do
    log INFO "📡 正在检查地址：$ADDR"
    KNOWN_FILE="/root/script/ini/${ADDR}.txt"
    touch "$KNOWN_FILE"

    # 获取交易记录（最多 20 条）
    RESP=$(curl -s --retry 3 --retry-delay 2 ${API_BASE} -H 'content-type: application/json' --data-raw '{"offset":0,"limit":20,"address":"'${ADDR}'","isContract":false}')
    if [[ -z "$RESP" ]]; then
      log ERROR "❌ 无法获取地址 $ADDR 的交易记录，跳过"
      continue
    fi

    echo "$RESP" | jq -c '.list[]' | while read -r tx; do
      TO=$(echo "$tx" | jq -r '.to')
      HASH=$(echo "$tx" | jq -r '.hash')
      FROM=$(echo "$tx" | jq -r '.from')
      VALUE_WEI=$(echo "$tx" | jq -r '.value')
      BLOCK=$(echo "$tx" | jq -r '.blockNumber')
      BLOCK_TIME=$(echo "$tx" | jq -r '.blockTime')
      BLOCK_TIME=$(date '+%F %T' -d "@${BLOCK_TIME}")

      if [[ "$TO" == "${ADDR,,}" ]] && ! grep -Fxq "$HASH" "$KNOWN_FILE"; then
        echo "$HASH" >> "$KNOWN_FILE"
        VALUE=$(awk "BEGIN { printf \"%.4f\", $VALUE_WEI / 1e18 }")
        

        log INFO "✅ 新交易：$HASH, 时间: $BLOCK_TIME 金额：$VALUE INI"

        curl -s "${WECOM_WEBHOOK}" \
        -H 'Content-Type: application/json' \
        -d '
        {
    	    "msgtype": "text",
    	    "text": {
        	"content": "新交易通知:\n发送方: '"$FROM"'\n接收方: '"$TO"'\n金额: '"$VALUE"' INI\n区块高度: '"$BLOCK"'\n区块时间: '"$BLOCK_TIME"'"
    	    }
        }'
      fi
    done
  done

  log INFO "⏱️ 等待 $INTERVAL 秒后继续..."
  sleep "$INTERVAL"
done