#!/bin/bash

input="/var/log/kibana/kibana.log"
config="./config.json"

timestamp=$(jq -r '.timestamp' $config)
line=$(jq -r '.line' $config)
skip=10

startLine=1

headTime=$(head -n 1 $input | jq -r '."@timestamp"')

if [ $timestamp != $headTime ]
then
	timestamp=$headTime
	line=1
	startLine=1
else
	startLine=$line
fi

lastSysTime=$(date +%s)
count=$line
while IFS= read -r line
do
	count=$((count + 1))
	currSysTime=$(date +%s)
	echo $lastSysTime $currSysTime $((currSysTime - lastSysTime)) $skip
	if ((currSysTime - lastSysTime > skip))
	then
		lastSysTime=$currSysTime
		newTime=$(head -n 1 $input | jq -r '."@timestamp"')
		if [ $newTime != $headTime ]
		then
			headTime=$newTime
			count=1
		fi
		echo '{}' | jq --arg timestamp $headTime --arg line $count --arg skip $skip '{timestamp : $timestamp, line : $line}' > $config
	fi

	logtype=$(echo $line | jq .type)
	if [[ $logtype == "\"response\"" ]]
	then
		url=$(echo $line | jq .req.url | cut -d"?" -f 1 | cut -d"\"" -f 2)
		query=$(echo $line | jq .req.url | cut -d"?" -f 2 | cut -d"\"" -f 1)

		echo $line | jq --arg url $url --arg query [$query] '{timestamp : .["@timestamp"], url : $url, query : $query, method : .method, statusCode : .statusCode, reqContentLength : .req.headers."content-length", responseTime : .res.responseTime, contentLength : .res.contentLength}'
	fi

done < <(tail -F $input --line=+$startLine)