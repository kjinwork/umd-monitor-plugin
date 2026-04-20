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

# Sync .md files to Firebase (Write/Edit tools only).
# Build the JSON body in a temp file and POST via --data-binary @FILE so the
# file content never goes through the command line (avoids ARG_MAX limits).
if [ "$TOOL_NAME" = "Write" ] || [ "$TOOL_NAME" = "Edit" ]; then
  FILE_PATH=$(extract file_path)
  [ -z "$FILE_PATH" ] && FILE_PATH=$(extract path)
  if [ -n "$FILE_PATH" ] && echo "$FILE_PATH" | grep -qi '\.md$' && [ -f "$FILE_PATH" ]; then
    FILE_NAME=$(basename "$FILE_PATH")
    SIZE_BYTES=$(stat -c%s "$FILE_PATH" 2>/dev/null || stat -f%z "$FILE_PATH" 2>/dev/null || echo 0)
    ENCODED_PATH=$(echo -n "$FILE_PATH" | base64 | tr '+/' '-_' | tr -d '=')
    TMP_JSON=$(mktemp 2>/dev/null || echo "/tmp/umd-sync-$$.json")
    {
      printf '{"path":"%s","filename":"%s","content":"' "$FILE_PATH" "$FILE_NAME"
      # Escape \ and " then join lines with literal \n
      sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/\r//g' "$FILE_PATH" \
        | awk 'BEGIN{first=1} {if(!first)printf "\\n"; printf "%s", $0; first=0}'
      printf '","lastModified":%s,"sizeBytes":%s,"sessionId":"%s"}' \
        "$TIMESTAMP" "$SIZE_BYTES" "$SESSION_ID"
    } > "$TMP_JSON"
    curl -s -o /dev/null -X PUT \
      "${FIREBASE_URL}/hook_data/${HOOK_SECRET}/files/${ENCODED_PATH}.json" \
      --data-binary @"$TMP_JSON" 2>> "$LOG_FILE"
    rm -f "$TMP_JSON"
  fi
fi
