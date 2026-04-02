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

# Extract detail from tool_input based on tool type
DETAIL=""
case "$TOOL_NAME" in
  Read)
    DETAIL=$(extract file_path)
    # Shorten to filename
    [ -n "$DETAIL" ] && DETAIL=$(basename "$DETAIL")
    ;;
  Write)
    DETAIL=$(extract file_path)
    [ -n "$DETAIL" ] && DETAIL=$(basename "$DETAIL")
    ;;
  Edit)
    DETAIL=$(extract file_path)
    [ -n "$DETAIL" ] && DETAIL=$(basename "$DETAIL")
    ;;
  Bash)
    DETAIL=$(extract command)
    # Truncate long commands
    [ ${#DETAIL} -gt 80 ] && DETAIL="${DETAIL:0:77}..."
    ;;
  Grep)
    DETAIL=$(extract pattern)
    ;;
  Glob)
    DETAIL=$(extract pattern)
    ;;
  Skill)
    DETAIL=$(extract skill)
    ;;
  Agent)
    DETAIL=$(extract description)
    ;;
  WebSearch|WebFetch)
    DETAIL=$(extract query)
    [ -z "$DETAIL" ] && DETAIL=$(extract url)
    ;;
esac

# Escape double quotes and backslashes in DETAIL for JSON safety
DETAIL=$(echo "$DETAIL" | sed 's/\\/\\\\/g; s/"/\\"/g' | head -c 120)

TIMESTAMP=$(date +%s)000
EVENT_ID=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "evt-${TIMESTAMP}-$$")

# Build message
MESSAGE="Used ${TOOL_NAME}"

# Build JSON payload
if [ -n "$DETAIL" ]; then
  PAYLOAD="{\"type\":\"tool_use\",\"toolName\":\"${TOOL_NAME}\",\"message\":\"${MESSAGE}\",\"detail\":\"${DETAIL}\",\"timestamp\":${TIMESTAMP}}"
else
  PAYLOAD="{\"type\":\"tool_use\",\"toolName\":\"${TOOL_NAME}\",\"message\":\"${MESSAGE}\",\"timestamp\":${TIMESTAMP}}"
fi

curl -s -o /dev/null -X PUT \
  "${FIREBASE_URL}/hook_data/${HOOK_SECRET}/sessions/${SESSION_ID}/events/${EVENT_ID}.json" \
  -d "$PAYLOAD" 2>> "$LOG_FILE"

curl -s -X PATCH \
  "${FIREBASE_URL}/hook_data/${HOOK_SECRET}/sessions/${SESSION_ID}.json" \
  -d "{\"status\":\"running\",\"lastEventAt\":${TIMESTAMP},\"startTime\":${TIMESTAMP}}" >> /dev/null 2>&1 &
