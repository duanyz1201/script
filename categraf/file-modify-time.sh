#!/bin/bash

exec 2>/dev/null

fileName=("/etc/passwd" "/root/.ssh/authorized_keys")

for file in "${fileName[@]}"
do
    path="${file}"
    modifyTime=$(stat --format='%y' "${path}")
    unixTime=$(date -d "${modifyTime}" +"%s.%N")
    echo "file_modify,path=${path} time=${unixTime:-0}"
done