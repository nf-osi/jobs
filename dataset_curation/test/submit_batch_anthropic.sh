#!/bin/bash

FILE=${1:-"input/batch2/sonnet.jsonl"}
jq -cs '{requests: .}' $FILE > temp_payload.json

curl https://api.anthropic.com/v1/messages/batches \
     --header "x-api-key: $ANTHROPIC_API_KEY" \
     --header "anthropic-version: 2023-06-01" \
     --header "content-type: application/json" \
     --data @temp_payload.json
     
rm temp_payload.json 

