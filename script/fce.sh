#!/bin/bash

URL_INPUT=""
FILE_INPUT="boot"

UNIQUE_ID="${FILE_INPUT}_$(basename "$URL_INPUT" | cut -d'?' -f1 | cut -d'.' -f1)"

# Trigger workflow
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
ATTEMPTS=0
while [ -z "$RUN_ID" ] && [ $ATTEMPTS -lt 60 ]; do
    ATTEMPTS=$((ATTEMPTS+1))
    sleep 5
    RESPONSE=$(curl -s "https://api.github.com/repos/offici5l/FCE/actions/workflows/fce.yml/runs?per_page=10")
    for id in $(echo "$RESPONSE" | jq -r '.workflow_runs[]?.id'); do
        JOBS=$(curl -s "https://api.github.com/repos/offici5l/FCE/actions/runs/$id/jobs")
        HAS_JOBS=$(echo "$JOBS" | jq -r 'has("jobs") and (.jobs != null)')
        if [ "$HAS_JOBS" == "true" ]; then
            MATCH=$(echo "$JOBS" | jq -r --arg UNIQUE_ID "$UNIQUE_ID" '.jobs[] | select(.name == $UNIQUE_ID) | .id')
            if [ -n "$MATCH" ]; then
                RUN_ID=$id
                break
            fi
        fi
    done
done

if [ -z "$RUN_ID" ]; then
    echo "❌ No workflow run detected for $UNIQUE_ID"
    exit 1
fi

echo "Workflow run detected: ID = $RUN_ID"

STATUS="in_progress"
CONCLUSION=""
CURRENT_STEP=""

while [ "$STATUS" != "completed" ]; do
    sleep 3
    RESPONSE=$(curl -s "https://api.github.com/repos/offici5l/FCE/actions/runs/$RUN_ID")
    STATUS=$(echo "$RESPONSE" | jq -r '.status')
    CONCLUSION=$(echo "$RESPONSE" | jq -r '.conclusion')

    JOBS=$(curl -s "https://api.github.com/repos/offici5l/FCE/actions/runs/$RUN_ID/jobs")
    HAS_JOBS=$(echo "$JOBS" | jq -r 'has("jobs") and (.jobs != null)')
    if [ "$HAS_JOBS" != "true" ]; then
        echo -ne "\r⌛ Waiting for jobs to start..."
        continue
    fi

    JOB_ID=$(echo "$JOBS" | jq -r '.jobs[0]?.id')
    if [ -z "$JOB_ID" ] || [ "$JOB_ID" == "null" ]; then
        echo -ne "\r⌛ Waiting for jobs..."
        continue
    fi

    JOB_DETAILS=$(curl -s "https://api.github.com/repos/offici5l/FCE/actions/jobs/$JOB_ID")
    HAS_STEPS=$(echo "$JOB_DETAILS" | jq -r 'has("steps") and (.steps != null)')
    if [ "$HAS_STEPS" != "true" ]; then
        echo -ne "\r⌛ Waiting for steps..."
        continue
    fi

    for step in $(echo "$JOB_DETAILS" | jq -r '.steps[]? | @base64'); do
        STEP_NAME=$(echo "$step" | base64 --decode | jq -r '.name')
        STEP_STATUS=$(echo "$step" | base64 --decode | jq -r '.status')
        STEP_CONCLUSION=$(echo "$step" | base64 --decode | jq -r '.conclusion')

        if [ "$STEP_STATUS" == "in_progress" ] && [ "$CURRENT_STEP" != "$STEP_NAME" ]; then
            echo -ne "\r🔄 Step: $STEP_NAME ...          "
            CURRENT_STEP="$STEP_NAME"
        fi

        if [ "$STEP_STATUS" == "completed" ] && [ "$CURRENT_STEP" == "$STEP_NAME" ]; then
            if [ "$STEP_CONCLUSION" == "success" ]; then
                echo -ne "\r✅ Step: $STEP_NAME - success          "
            else
                echo -e "\r❌ Step: $STEP_NAME - $STEP_CONCLUSION"
                echo "❌ Workflow failed!"
                exit 1
            fi
            CURRENT_STEP=""
        fi
    done
done

echo
echo "Workflow finished with conclusion: $CONCLUSION"

if [ "$CONCLUSION" != "success" ]; then
    echo "❌ Workflow failed. No output will be available."
    exit 1
fi

OUTPUT_URL="https://offici5l.github.io/FCE/$UNIQUE_ID/${FILE_INPUT}.zip"

echo "Checking if output is available..."
for i in {1..30}; do
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" -I "$OUTPUT_URL")
    if [ "$STATUS" -eq 200 ]; then
        echo "✅ Output is ready and will be available for 7 days:"
        echo "  $OUTPUT_URL"
        exit 0
    fi
    sleep 5
done

echo "⚠️ Output not found yet. Try later:"
echo "  $OUTPUT_URL"