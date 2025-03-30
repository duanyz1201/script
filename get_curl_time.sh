#!/bin/bash

url="$1"

if [ $url ];then
#	code_time=$(/usr/bin/curl --head --connect-timeout 6 -w "%{http_code} %{time_total}" -o /dev/null -s -L "$url")
	code_time=$(/usr/bin/curl --head --max-time 6 -w "%{http_code} %{time_total}" -o /dev/null -s -L "$url")
	echo -e "$(date +%Y/%m/%d-%H:%M:%S)\t$url\t$code_time" >> /var/log/zabbix/get_curl.log
	if [ "$(echo $code_time|awk '{print $1}')" -eq 200 ];then
		curl_time=$(echo $code_time|awk '{print $2}')
	else
		curl_time="0"
	fi
fi
echo $curl_time
