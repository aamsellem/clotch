#!/bin/bash
# Clotch PermissionRequest hook for Claude Code.
# Sends the permission payload to Clotch via Unix socket, waits for the user's
# decision, then outputs the decision JSON on stdout for Claude Code.
#
# If Clotch isn't running or times out, we output {"behavior":"deny"} to be safe.

SOCKET="/tmp/clotch.sock"
TIMEOUT=55  # leave buffer before Claude Code's own timeout

INPUT=$(cat)
if [ ! -S "$SOCKET" ]; then
    # Socket missing — don't block Claude Code. Emit no decision so the default dialog shows.
    exit 0
fi

export CLOTCH_RAW_INPUT="$INPUT"
export CLOTCH_CMUX_PANEL_ID="${CMUX_PANEL_ID:-}"
export CLOTCH_CMUX_WORKSPACE_ID="${CMUX_WORKSPACE_ID:-}"
export CLOTCH_TIMEOUT="$TIMEOUT"

python3 <<'PYEOF'
import json, os, socket, sys, uuid

raw = os.environ.get('CLOTCH_RAW_INPUT', '')
timeout = int(os.environ.get('CLOTCH_TIMEOUT', '55'))
try:
    data = json.loads(raw) if raw.strip() else {}
except Exception:
    data = {}

request_id = str(uuid.uuid4())
payload = {
    'kind': 'permission_request',
    'request_id': request_id,
    'session_id': data.get('session_id', 'unknown'),
    'tool_name': data.get('tool_name'),
    'tool_input': data.get('tool_input'),
    'permission_suggestions': data.get('permission_suggestions', []),
    'cwd': data.get('cwd'),
    'cmux_panel_id': os.environ.get('CLOTCH_CMUX_PANEL_ID') or None,
    'cmux_workspace_id': os.environ.get('CLOTCH_CMUX_WORKSPACE_ID') or None,
}

try:
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(timeout)
    s.connect('/tmp/clotch.sock')
    s.sendall((json.dumps(payload) + '\n').encode())
    # Wait for the response line
    buf = b''
    while b'\n' not in buf:
        chunk = s.recv(4096)
        if not chunk:
            break
        buf += chunk
    s.close()
    line = buf.split(b'\n', 1)[0].decode()
    resp = json.loads(line) if line else {}
    decision = resp.get('decision')
    if not decision:
        # Unknown response → let default dialog show
        sys.exit(0)
    out = {
        'hookSpecificOutput': {
            'hookEventName': 'PermissionRequest',
            'decision': decision
        }
    }
    sys.stdout.write(json.dumps(out))
    sys.exit(0)
except Exception:
    # Any error → fall back to default dialog
    sys.exit(0)
PYEOF
