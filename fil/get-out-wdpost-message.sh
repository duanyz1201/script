#!/bin/bash

ts=`date +"%F %T"`

if [ -z "$1" ]; then
    echo "$ts miss params..."
    exit 1
fi

for id in $(/usr/local/bin/lotus mpool find --from ${1} | jq -r '.[].Message.CID."/"')
do
        new_cid=`lotus mpool replace --auto --fee-limit=2FIL $id`
        echo "$ts replace cid old=$id new=$new_cid"
done