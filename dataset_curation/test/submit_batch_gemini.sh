#!/bin/bash

MODEL="gemini-2.5-pro-exp-03-25" #"gemini-2.0-flash"
INPUT_FILE="input/batch2/gemini.jsonl"  # "input/batch/G.jsonl"
OUTPUT_FILE="output/batch2/batch_$MODEL.json"
ENDPOINT_URL="https://generativelanguage.googleapis.com/v1beta/models/$MODEL:generateContent?key=$GEMINI_API_KEY"

> "$OUTPUT_FILE"

line_num=0
success_count=0
error_count=0

jq -c '.' "$INPUT_FILE" | while IFS= read -r json_line; do
  ((line_num++))
  printf "Processing line %d... " "$line_num"

  CUSTOM_ID=$(echo "$json_line" | jq -r '.custom_id')
  MESSAGE=$(echo "$json_line" | jq -r '.text')
  response=$(echo "$json_line" | curl -s -f -X POST \
               -H "Content-Type: application/json" \
               -d "$MESSAGE" \
               "$ENDPOINT_URL")

  curl_exit_status=$?

  if [ $curl_exit_status -eq 0 ]; then
    # Success: Append the raw response body to the output file
    echo "$response" | jq --arg id "$CUSTOM_ID" '. + {"custom_id": $id}' >> "$OUTPUT_FILE"
    echo "OK"
    ((success_count++))
  else
    echo "Failed line $line_num" >&2
    ((error_count++))
  fi
done

jq -c '.' $OUTPUT_FILE > $OUTPUT_FILE.jsonl

echo "--------------------"
echo "Processing complete."
echo "Success: $success_count"
echo "Errors:  $error_count"
echo "Results saved to '$OUTPUT_FILE'"
