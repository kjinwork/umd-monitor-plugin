#!/bin/bash
# umd-monitor: Stop hook

CONFIG_FILE="$HOME/.config/umd/hook-secret"
[ ! -f "$CONFIG_FILE" ] && exit 0

HOOK_SECRET=$(cat "$CONFIG_FILE" | tr -d '[:space:]')
[ -z "$HOOK_SECRET" ] && exit 0

FIREBASE_URL="https://mdviewer-wslabs-default-rtdb.firebaseio.com"
LOG_FILE="$HOME/.config/umd/hook.log"

HOOK_INPUT=$(cat)

extract() { echo "$HOOK_INPUT" | grep -o "\"$1\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | head -1 | sed 's/.*:[[:space:]]*"//;s/"$//'; }
SESSION_ID=$(extract session_id)
[ -z "$SESSION_ID" ] && SESSION_ID="unknown"

TIMESTAMP=$(date +%s)000

curl -s -o /dev/null -X PATCH \
  "${FIREBASE_URL}/hook_data/${HOOK_SECRET}/sessions/${SESSION_ID}.json" \
  -d "{\"status\":\"completed\",\"endTime\":${TIMESTAMP}}"

EVENT_ID=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "evt-${TIMESTAMP}-$$")
curl -s -X PUT \
  "${FIREBASE_URL}/hook_data/${HOOK_SECRET}/sessions/${SESSION_ID}/events/${EVENT_ID}.json" \
  -d "{\"type\":\"session_end\",\"message\":\"Session completed\",\"timestamp\":${TIMESTAMP}}" >> /dev/null 2>&1 &
