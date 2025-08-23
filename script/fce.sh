#!/bin/bash

URL_INPUT="https://ultimateota.d.miui.com/OS2.0.201.0.VNTEUXM/moon_eea_global-ota_full-OS2.0.201.0.VNTEUXM-user-15.0-5e31983d6e.zip?t=1755293681&s=219e32da0eb22c71926089713aefe248"
FILE_INPUT="boot"
UNIQUE_ID=$(date +%s%N)

RESPONSE=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  -d "{
    \"url\": \"$URL_INPUT\",
    \"file\": \"$FILE_INPUT\",
    \"unique_id\": \"$UNIQUE_ID\"
  }" \
  https://fce-proxy.vercel.app/api/trigger)

echo "$RESPONSE"

RUN_ID=""

while [ -z "$RUN_ID" ]; do
    sleep 5
    RESPONSE=$(curl -s "https://api.github.com/repos/offici5l/FCE/actions/workflows/fce.yml/runs?per_page=10")
    for id in $(echo "$RESPONSE" | jq -r '.workflow_runs[].id'); do
        JOBS=$(curl -s "https://api.github.com/repos/offici5l/FCE/actions/runs/$id/jobs")
        MATCH=$(echo "$JOBS" | jq -r --arg UNIQUE_ID "$UNIQUE_ID" '.jobs[] | select(.name == $UNIQUE_ID) | .id')
        if [ -n "$MATCH" ]; then
            RUN_ID=$id
            break
        fi
    done
done

echo "Workflow run detected: ID = $RUN_ID"

STATUS="in_progress"

while [ "$STATUS" != "completed" ]; do
    sleep 5
    RESPONSE=$(curl -s "https://api.github.com/repos/offici5l/FCE/actions/runs/$RUN_ID")
    STATUS=$(echo "$RESPONSE" | jq -r '.status')
    CONCLUSION=$(echo "$RESPONSE" | jq -r '.conclusion')
    echo "Current workflow status: $STATUS"
    JOBS=$(curl -s "https://api.github.com/repos/offici5l/FCE/actions/runs/$RUN_ID/jobs")
    for job_id in $(echo "$JOBS" | jq -r '.jobs[].id'); do
        JOB_DETAILS=$(curl -s "https://api.github.com/repos/offici5l/FCE/actions/jobs/$job_id")
        JOB_NAME=$(echo "$JOB_DETAILS" | jq -r '.name')
        JOB_STATUS=$(echo "$JOB_DETAILS" | jq -r '.status')
        JOB_CONCLUSION=$(echo "$JOB_DETAILS" | jq -r '.conclusion')
        echo "  Job: $JOB_NAME ($job_id) - $JOB_STATUS ($JOB_CONCLUSION)"
        echo "$JOB_DETAILS" | jq -r '.steps[] | "    Step: \(.name) - Status: \(.status) (\(.conclusion))"'
    done
done

echo "Workflow finished with conclusion: $CONCLUSION"

OUTPUT_URL="https://offici5l.github.io/FCE/$UNIQUE_ID/${FILE_INPUT}.zip"

echo "Checking if output is available..."
for i in {1..30}; do
    if curl -s -I "$OUTPUT_URL" | grep -q "200 OK"; then
        echo "Output is ready:"
        echo "  $OUTPUT_URL"
        exit 0
    fi
    sleep 5
done

echo "Output not found yet. Try later:"
echo "  $OUTPUT_URL"