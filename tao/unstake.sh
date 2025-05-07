#!/bin/bash

export hotkey="5DPB6bPAqBC7JMBMzdwyA4k4WsreoGpHkixZh1QZS7R9pFyr"
export wallet_name="sg-5"
export password="123456"

/usr/bin/expect ./unstake.exp > output.txt 2>&1

Received=$(grep -A 4 "Received (Τ)" output.txt |tail -n 1|awk '{print $18}')

echo ${Received}