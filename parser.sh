#!/bin/bash

input="/var/log/kibana/kibana.log"
config="./config.json"

timestamp=$(jq -r '.timestamp' $config)
line=$(jq -r '.line' $config)
skip=$(jq -r '.skip' $config)

startLine=1

headTime=$(head -n 1 $input | jq -r '."@timestamp"')

if [ $timestamp != $headTime ]
then
	# echo inside
	timestamp=$headTime
	line=1
	startLine=1
else
	startLine=$line
fi


count=$line
while IFS= read -r line
do
	count=$((count + 1))

	if ! ((count % skip))
	then
		newTime=$(head -n 1 $input | jq -r '."@timestamp"')
		if [ $newTime != $headTime ]
		then
			headTime=$newTime
			count=1
		fi
		echo '{}' | jq --arg timestamp $headTime --arg line $count --arg skip $skip '{timestamp : $timestamp, line : $line, skip : $skip}' > $config
	fi

	logtype=$(echo $line | jq .type)
	if [ $logtype == "\"response\"" ]
	then

		url=$(echo $line | jq .req.url | cut -d"?" -f 1 | cut -d"\"" -f 2)
		query=$(echo $line | jq .req.url | cut -d"?" -f 2 | cut -d"\"" -f 1)

		echo $line | jq --arg url $url --arg query [$query] '{timestamp : .["@timestamp"], url : $url, query : $query, method : .method, statusCode : .statusCode, resContentLength : .req.headers."content-length", responseTime : .res.responseTime, contentLength : .res.contentLength}'
	fi

done < <(tail -F $input --line=+$startLine | grep response)