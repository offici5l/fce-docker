#!/bin/bash

URL_INPUT="https://ultimateota.d.miui.com/OS2.0.201.0.VNTEUXM/moon_eea_global-ota_full-OS2.0.201.0.VNTEUXM-user-15.0-5e31983d6e.zip?t=1755293681&s=219e32da0eb22c71926089713aefe248"
FILE_INPUT="boot"

UNIQUE_ID="${FILE_INPUT}_$(basename "$URL_INPUT" | cut -d'?' -f1 | cut -d'.' -f1)"
PROXY_URL="https://fce-proxy.vercel.app/api/trigger"

# Function to call the proxy
call_proxy() {
    curl -s -X POST -H "Content-Type: application/json" -d "$1" "$PROXY_URL"
}

# Trigger workflow
RESPONSE=$(call_proxy "{\"action\": \"trigger\", \"url\": \"$URL_INPUT\", \"file\": \"$FILE_INPUT\", \"unique_id\": \"$UNIQUE_ID\"}")

# Parse response
OK=$(echo "$RESPONSE" | jq -r '.ok')
ERROR=$(echo "$RESPONSE" | jq -r '.error // empty')

if [ "$OK" = "true" ]; then
    echo "✅ Workflow triggered successfully (ID: $UNIQUE_ID)"
else
    echo "❌ Failed to trigger workflow"
    if [ -n "$ERROR" ]; then
        echo "Error: $ERROR"
    fi
    exit 1
fi

# Find the workflow run ID
RUN_ID=""
ATTEMPTS=0
while [ -z "$RUN_ID" ] && [ $ATTEMPTS -lt 60 ]; do
    ATTEMPTS=$((ATTEMPTS+1))
    sleep 5
    RESPONSE=$(call_proxy '{"action": "get_runs"}')
    for id in $(echo "$RESPONSE" | jq -r '.workflow_runs[]?.id'); do
        JOBS_RESPONSE=$(call_proxy "{\"action\": \"get_jobs\", \"run_id\": $id}")
        HAS_JOBS=$(echo "$JOBS_RESPONSE" | jq -r 'has("jobs") and (.jobs != null)')
        if [ "$HAS_JOBS" == "true" ]; then
            MATCH=$(echo "$JOBS_RESPONSE" | jq -r --arg UNIQUE_ID "$UNIQUE_ID" '.jobs[] | select(.name == $UNIQUE_ID) | .id')
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
    RESPONSE=$(call_proxy "{\"action\": \"get_run_details\", \"run_id\": $RUN_ID}")
    STATUS=$(echo "$RESPONSE" | jq -r '.status')
    CONCLUSION=$(echo "$RESPONSE" | jq -r '.conclusion')

    JOBS_RESPONSE=$(call_proxy "{\"action\": \"get_jobs\", \"run_id\": $RUN_ID}")
    HAS_JOBS=$(echo "$JOBS_RESPONSE" | jq -r 'has("jobs") and (.jobs != null)')
    if [ "$HAS_JOBS" != "true" ]; then
        echo -ne "\r⌛ Waiting for jobs to start..."
        continue
    fi

    JOB_ID=$(echo "$JOBS_RESPONSE" | jq -r '.jobs[0]?.id')
    if [ -z "$JOB_ID" ] || [ "$JOB_ID" == "null" ]; then
        echo -ne "\r⌛ Waiting for jobs..."
        continue
    fi

    JOB_DETAILS=$(call_proxy "{\"action\": \"get_job_details\", \"job_id\": $JOB_ID}")
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
    RESPONSE=$(call_proxy "{\"action\": \"check_output\", \"output_url\": \"$OUTPUT_URL\"}")
    STATUS=$(echo "$RESPONSE" | jq -r '.status')
    if [ "$STATUS" -eq 200 ]; then
        echo "✅ Output is ready and will be available for 7 days:"
        echo "  $OUTPUT_URL"
        exit 0
    fi
    sleep 5
done

echo "⚠️ Output not found yet. Try later:"
echo "  $OUTPUT_URL"
