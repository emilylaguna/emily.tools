#!/bin/bash

input=$(cat)
transcript=$(echo "$input" | jq -r ".transcript_path")

if [[ ! -f "$transcript" ]]; then
    exit 0
fi

if ! command -v jq &> /dev/null; then
    exit 0
fi

read -r model token_usage < <(jq -rs '
    sort_by(.timestamp) | reverse | unique_by(.message.id) | sort_by(.timestamp) |
    map({"model": .message.model, "usage": ((.message.usage.input_tokens + .message.usage.cache_creation_input_tokens + .message.usage.cache_read_input_tokens + .message.usage.output_tokens))
    }) 
    | map(select(.model != null))
    | "\(.[-1].model) \(.[-1].usage // 0)"
    ' "$transcript")

# Default 200k
max_context=200000

# Opus and 1m models, not super accurate but close enough
if [[ "$model" == *"[1m]"* || "$model" == *"opus"* ]]; then
    max_context=1000000
fi

remaining=$(awk "BEGIN { printf \"%.2f\", (${max_context} - ${token_usage}) }")
remaining_percent=$(awk "BEGIN { printf \"%.2f\", (${remaining} / ${max_context}) * 100 }")

remaining_int=${remaining_percent%.*}

if (( remaining_int < 10 )); then
    echo "Remaining context is CRITICALLY LOW (<10%)! You NEED to finish any in-flight work then insist on starting a new session before continuing"
elif (( remaining_int < 30 )); then
    echo "Remaining context is VERY LOW (<30%)! It's time to start wrapping up the session! Finish up in-flight work, and suggest starting a new session before starting any new work."
fi

exit 0