#!/bin/bash
# umd-monitor: Notification hook

CONFIG_FILE="$HOME/.config/umd/hook-secret"
[ ! -f "$CONFIG_FILE" ] && exit 0

HOOK_SECRET=$(cat "$CONFIG_FILE" | tr -d '[:space:]')
[ -z "$HOOK_SECRET" ] && exit 0

FIREBASE_URL="https://mdviewer-wslabs-default-rtdb.firebaseio.com"
LOG_FILE="$HOME/.config/umd/hook.log"

HOOK_INPUT=$(cat)

extract() { echo "$HOOK_INPUT" | grep -o "\"$1\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | head -1 | sed 's/.*:[[:space:]]*"//;s/"$//'; }
EVENT_TYPE=$(extract event_type)
MESSAGE=$(extract message)
SESSION_ID=$(extract session_id)
[ -z "$EVENT_TYPE" ] && EVENT_TYPE="notification"
[ -z "$MESSAGE" ] && MESSAGE="Agent event"
[ -z "$SESSION_ID" ] && SESSION_ID="unknown"

TIMESTAMP=$(date +%s)000
EVENT_ID=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "evt-${TIMESTAMP}-$$")

curl -s -o /dev/null -X PUT \
  "${FIREBASE_URL}/hook_data/${HOOK_SECRET}/sessions/${SESSION_ID}/events/${EVENT_ID}.json" \
  -d "{\"type\":\"${EVENT_TYPE}\",\"message\":\"${MESSAGE}\",\"timestamp\":${TIMESTAMP}}" 2>> "$LOG_FILE"
