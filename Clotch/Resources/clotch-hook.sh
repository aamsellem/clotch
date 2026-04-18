#!/bin/bash
# Clotch hook for Claude Code
# Sends events to /tmp/clotch.sock via Unix domain socket
# Receives hook event JSON on stdin from Claude Code

SOCKET="/tmp/clotch.sock"

# Exit silently if socket doesn't exist (Clotch not running)
[ ! -S "$SOCKET" ] && exit 0

# Read stdin (hook event JSON from Claude Code)
INPUT=$(cat)

# Export for python subprocesses
export CLOTCH_RAW_INPUT="$INPUT"
export CLOTCH_EVENT_TYPE="${CLAUDE_HOOK_EVENT_NAME:-unknown}"
export CLOTCH_SESSION="${CLAUDE_SESSION_ID:-unknown}"

# Build payload and send to socket — all in one python3 call for reliability
python3 -c "
import json, os, socket, time

raw = os.environ.get('CLOTCH_RAW_INPUT', '')
event_type = os.environ.get('CLOTCH_EVENT_TYPE', 'unknown')
session_id = os.environ.get('CLOTCH_SESSION', 'unknown')
sock_path = os.environ.get('SOCKET', '/tmp/clotch.sock')

try:
    data = json.loads(raw) if raw.strip() else {}
except Exception:
    data = {}

payload = {
    'session_id': data.get('session_id', session_id),
    'event': event_type,
    'tool': data.get('tool_name', data.get('tool', None)),
    'tool_input': None,
    'user_prompt': data.get('user_prompt', data.get('prompt', None)),
    'cwd': data.get('cwd', None),
    'cmux_panel_id': os.environ.get('CMUX_PANEL_ID'),
    'cmux_workspace_id': os.environ.get('CMUX_WORKSPACE_ID'),
    'timestamp': int(time.time())
}

ti = data.get('tool_input')
if ti:
    try:
        payload['tool_input'] = json.dumps(ti) if not isinstance(ti, str) else ti
    except Exception:
        pass

msg = json.dumps(payload)

try:
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(2)
    s.connect(sock_path)
    s.sendall(msg.encode())
    s.close()
except Exception:
    pass
" &

exit 0
