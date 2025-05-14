#!/bin/bash

ELECTRICITY_COST="0.4"
MINER_PRICE="19000"
POOL_FEE="0.04"
SERVICE_FEE="0"

CNY_USD_response=$(curl -s --compressed --max-time 10 --retry 3 'https://www.binance.com/bapi/asset/v1/public/asset-service/product/currency')
if [[ $? != 0 || -z "${CNY_USD_response}" ]]; then
    echo "Failed to fetch CNY_USD_response rate"
    exit 1
fi
CNY_USD=$(echo "${CNY_USD_response}" | jq -r '.data[]|select(.pair == "CNY_USD")|.rate')
echo "CNY_USD: ${CNY_USD}"

f2pool_btc_info=$(curl -s --max-time 10 --retry 3 -X POST 'https://www.f2pool.com/coins-chart' --data-raw 'currency_code=btc&history_days=30d&interval=60m')
if [[ $? != 0 || -z "${f2pool_btc_info}" ]]; then
    echo "Failed to fetch f2pool_btc_info"
    exit 1
fi

# 获取全网算力
network_hashrate=$(echo "${f2pool_btc_info}" | jq -r '.data.network_hashrate' | awk '{printf "%.0f\n", $1}')
# 获取当前难度
difficulty=$(echo "${f2pool_btc_info}" | jq -r '.data.difficulty' | awk '{printf "%.0f\n", $1}')
# 获取单T日理论收益
estimated_profit_usd=$(echo "${f2pool_btc_info}" | jq -r '.data.estimated_profit_usd')
# 获取BTC价格
btc_price_response=$(echo "${f2pool_btc_info}" | jq -r '.data.price')
# BTC美元价格转换人民币
btc_price=$(echo "${btc_price_response} ${CNY_USD}" | awk '{printf "%.0f\n", $1 * $2}')

# 全网算力单位转换
# 1 EH/s = 1e18 H/s
network_hashrate_EH=$(echo "${network_hashrate}" | awk '{printf "%.2f\n", $1 / 1000000000000000000}')
# 日理论收益扣除矿池手续费
# 1%手续费
estimated_profit_usd_fee=$(echo "${estimated_profit_usd} ${CNY_USD} ${POOL_FEE}" | awk '{printf "%.4f\n", $1 * $2 * (1 - $3)}')

# 按照单T收益计算矿机单日收益
day_income=$(echo "257 ${estimated_profit_usd_fee}" | awk '{printf "%.2f\n", $1 * $2}')
# 按照矿机功耗计算矿机单日电费
day_df=$(echo "5345 ${ELECTRICITY_COST}" | awk '{printf "%.2f\n", $1 / 1000 * 24 * $2}')
# 日利润扣除服务费抽成
day_profit=$(echo "${day_income} ${day_df} ${SERVICE_FEE}" | awk '{printf "%.2f\n", ($1 - $2) * (1 - $3)}')
# 计算回本周期
payback_period=$(echo "${day_profit} ${MINER_PRICE}" | awk '{printf "%.0f\n", $2 / $1}')


push_txt="$(date '+%F %T')\n
品牌型号:  蚂蚁S19 XP Hyd
算力:  257T
功耗:  5345w
价格:  ${MINER_PRICE}元
电价:  ${ELECTRICITY_COST}元
币价:  ${btc_price}元
全网算力:  ${network_hashrate_EH} EH/s
单T收益:  ${estimated_profit_usd_fee}元 (矿池${POOL_FEE}费率)
单日收益:  ${day_income}元
单日电费:  ${day_df}元
单日利润:  ${day_profit}元 (${SERVICE_FEE}抽成)
回本周期:  ${payback_period}天"

echo "${push_txt}" 

# curl -s 'https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=f358e0b3-0843-45c6-b513-4ec32d958d89' \
   -H 'Content-Type: application/json' \
   -d '
   {
    	"msgtype": "text",
    	"text": {
        	"content": "'"${push_txt}"'"
    	}
   }'