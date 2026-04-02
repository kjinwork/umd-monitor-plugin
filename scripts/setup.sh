#!/bin/bash
# umd-monitor: Configure hookSecret
# Usage: bash setup.sh <hookSecret>

if [ -z "$1" ]; then
  echo "Usage: bash setup.sh <hookSecret>"
  echo ""
  echo "Get your hookSecret from the umd app:"
  echo "  1. Open umd app → Add Agent → Configure"
  echo "  2. Copy the hookSecret shown on screen"
  exit 1
fi

CONFIG_DIR="$HOME/.config/umd"
mkdir -p "$CONFIG_DIR"
echo "$1" > "$CONFIG_DIR/hook-secret"
echo "hookSecret saved to $CONFIG_DIR/hook-secret"
echo ""

# Test connection
TIMESTAMP=$(date +%s)000
RESULT=$(curl -s -X PUT \
  "https://mdviewer-wslabs-default-rtdb.firebaseio.com/hook_data/$1/sessions/connection-test/events/test-${TIMESTAMP}.json" \
  -d "{\"type\":\"notification\",\"message\":\"Plugin setup complete\",\"timestamp\":${TIMESTAMP}}" 2>&1)

if echo "$RESULT" | grep -q "error"; then
  echo "WARNING: Connection test failed. Check your hookSecret."
else
  echo "SUCCESS! Connection verified. Open umd app to confirm."
fi
