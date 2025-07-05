#!/usr/bin/env bash

# 初始奖励
R0="727.390719066559305"
# 衰减率
decay="0.00000012096"
# 每个周期的区块数
blocks_per_period=20160

# 设置 bc 精度
scale=18

echo "周期编号, 区块高度, 奖励值"

for i in $(seq 0 50); do
  height=$(echo "$i * $blocks_per_period" | bc)
  exponent=$(echo "-1 * $decay * $height" | bc -l)
  e_exponent=$(echo "e($exponent)" | bc -l)
  reward=$(echo "$R0 * $e_exponent" | bc -l)
  printf "%d, %d, %.18f\n" "$i" "$height" "$reward"
done