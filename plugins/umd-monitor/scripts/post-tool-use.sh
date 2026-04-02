#!/bin/bash
# umd-monitor: PostToolUse hook
# Sends tool usage events to Firebase RTDB for real-time mobile monitoring.
# No jq dependency — uses grep/sed for JSON parsing.

CONFIG_FILE="$HOME/.config/umd/hook-secret"
[ ! -f "$CONFIG_FILE" ] && exit 0

HOOK_SECRET=$(cat "$CONFIG_FILE" | tr -d '[:space:]')
[ -z "$HOOK_SECRET" ] && exit 0

FIREBASE_URL="https://mdviewer-wslabs-default-rtdb.firebaseio.com"
LOG_FILE="$HOME/.config/umd/hook.log"

HOOK_INPUT=$(cat)

# Parse JSON without jq
extract() { echo "$HOOK_INPUT" | grep -o "\"$1\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | head -1 | sed 's/.*:[[:space:]]*"//;s/"$//'; }
TOOL_NAME=$(extract tool_name)
SESSION_ID=$(extract session_id)
[ -z "$TOOL_NAME" ] && TOOL_NAME="unknown"
[ -z "$SESSION_ID" ] && SESSION_ID="unknown"

TIMESTAMP=$(date +%s)000
EVENT_ID=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "evt-${TIMESTAMP}-$$")

curl -s -o /dev/null -X PUT \
  "${FIREBASE_URL}/hook_data/${HOOK_SECRET}/sessions/${SESSION_ID}/events/${EVENT_ID}.json" \
  -d "{\"type\":\"tool_use\",\"toolName\":\"${TOOL_NAME}\",\"message\":\"Used ${TOOL_NAME}\",\"timestamp\":${TIMESTAMP}}" 2>> "$LOG_FILE"

curl -s -X PATCH \
  "${FIREBASE_URL}/hook_data/${HOOK_SECRET}/sessions/${SESSION_ID}.json" \
  -d "{\"status\":\"running\",\"lastEventAt\":${TIMESTAMP},\"startTime\":${TIMESTAMP}}" >> /dev/null 2>&1 &
