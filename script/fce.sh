#!/bin/bash

URL_INPUT="rom.zip"
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

ATTEMPTS=30
COUNT=0
for i in $(seq 1 $ATTEMPTS); do
  ARTIFACTS=$(curl -s "https://api.github.com/repos/offici5l/FCE/actions/runs/$RUN_ID/artifacts")

  if echo "$ARTIFACTS" | jq -e '.artifacts' >/dev/null 2>&1; then
    COUNT=$(echo "$ARTIFACTS" | jq '.artifacts | length')
    if [ "$COUNT" -gt 0 ]; then
      break
    fi
  fi

  sleep 2
done

if [ "$COUNT" -eq 0 ]; then
  echo "No artifacts found."
else
  echo "Artifacts:"
  echo "$ARTIFACTS" | jq -r --arg RUN_ID "$RUN_ID" \
    '.artifacts[] | "  \(.name): https://github.com/offici5l/FCE/actions/runs/\($RUN_ID)/artifacts/\(.id)"'
fi