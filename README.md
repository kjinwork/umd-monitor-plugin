# umd-monitor

A [Claude Code](https://claude.ai/code) plugin that streams your coding sessions to the **umd** mobile app in real-time.

Monitor what your AI agent is doing — tool calls, file changes, session status — all from your phone.

## Overview

When Claude Code uses a tool, sends a notification, or finishes a session, this plugin automatically sends the event to Firebase Realtime Database. The umd mobile app listens for these events and displays them as a live activity feed.

```
Claude Code (Desktop/CLI)          umd App (Mobile)
        |                               |
        |-- PostToolUse event --------->|  "Used Read on main.dart"
        |-- PostToolUse event --------->|  "Used Edit on api.dart"
        |-- Notification --------------->|  "Build completed"
        |-- Stop ----------------------->|  "Session ended"
```

## Install

### 1. Add the plugin marketplace

```
/plugin marketplace add kjinwork/umd-monitor-plugin
```

### 2. Install the plugin

```
/plugin install umd-monitor
```

### 3. Configure your hookSecret

Get your hookSecret from the umd app (see [App Setup](#app-setup)), then run:

```bash
mkdir -p ~/.config/umd
echo "YOUR_HOOK_SECRET" > ~/.config/umd/hook-secret
```

### 4. Restart Claude Code

Hooks are loaded at startup. Restart Claude Code to activate the plugin.

### 5. Verify

Open `/hooks` in Claude Code. You should see:

```
PostToolUse (1)
Notification (1)
Stop (1)
```

## App Setup

1. Download the **umd** app from [Google Play Store](#) or [App Store](#).
2. Open the app and go to the **Monitor** tab.
3. Tap **Add Agent** and select **Claude Code**.
4. The app generates a unique **hookSecret** — this links your Claude Code to the app.
5. Share the hookSecret to your dev machine (copy, QR code, or share button).
6. Follow the [Install](#install) steps above using your hookSecret.
7. Done! Start using Claude Code and events will appear in the app.

## What gets monitored

| Event | Data sent |
|-------|-----------|
| **Tool Use** | Tool name (Read, Edit, Bash, etc.), session ID, timestamp |
| **Notification** | Event type, message, session ID, timestamp |
| **Session End** | Session ID, end timestamp, completion status |

## Privacy

- Only tool **names** are sent, not file contents or code.
- Events are tied to an anonymous hookSecret, not your identity.
- Data is stored in Firebase RTDB under a path only you can read.
- You can revoke access anytime from the umd app.

## Requirements

- `curl` (pre-installed on macOS, Linux, and Git Bash on Windows)
- `bash` (available on all platforms including Windows via Git Bash)
- No `jq` or other dependencies

## Troubleshooting

### Hooks not firing

Check that `/hooks` shows the plugin hooks. If not, restart Claude Code.

### Events not appearing in the app

Check the log file:

```bash
cat ~/.config/umd/hook.log
```

### Test the connection manually

```bash
HOOK_SECRET=$(cat ~/.config/umd/hook-secret)
TIMESTAMP=$(date +%s)000
curl -s -X PUT \
  "https://mdviewer-wslabs-default-rtdb.firebaseio.com/hook_data/${HOOK_SECRET}/sessions/connection-test/events/test.json" \
  -d "{\"type\":\"notification\",\"message\":\"Test\",\"timestamp\":${TIMESTAMP}}"
```

If you see `{"error":"Unauthorized request."}`, your hookSecret may be deactivated. Re-register in the umd app.

## License

MIT
