#!/bin/bash

if [[ ! -e "/disk" ]];then
	mkdir /disk
fi

os_disk=$(lsblk |grep -w /|grep -oP 'sd[a-z]+|nvme[0-9a-z]+')

for disk in `lsblk -d|awk '{print $1}'|grep -oP 'sd[a-z]+|nvme[0-9a-z]+'|grep -v $os_disk`
do
	mount_path="/disk/$disk"

	if df -h |grep -q "$mount_path";then
		echo "$mount_path mounted"
		continue
	fi


	if [[ ! -e "$mount_path" ]];then
		mkdir -p /disk/$disk
	fi

	if ! mount /dev/$disk "$mount_path";then
		echo "mount /dev/$disk to $mount_path failed"
	else
		echo "mount /dev/$disk to $mount_path success"
	fi
done
