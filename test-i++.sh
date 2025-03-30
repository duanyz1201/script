#!/bin/bash

#for (( i=0;i<10;i++ ))
#do
#	echo $i
#done

fsid=0

for i in $(seq 0 10)
do
	((fsid++))
	echo $fsid
done
