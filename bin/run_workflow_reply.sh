#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF' >&2
usage: run_workflow_reply.sh [--json] <repo_dir> <task_type> <user_request_file> [copilot_model] [fallback_mode] [codex_model]
EOF
}

OUTPUT_MODE="text"
if [[ "${1:-}" == "--json" ]]; then
  OUTPUT_MODE="json"
  shift
fi

if [[ $# -lt 3 ]]; then
  usage
  exit 2
fi

REPO_DIR="$1"
TASK_TYPE="$2"
USER_REQ_FILE="$3"
COPILOT_MODEL="${4:-auto}"
FALLBACK_MODE="${5:-allow}"
CODEX_MODEL="${6:-gpt-5.4}"

AIWF="${AI_WORKFLOW_HOME:-$HOME/ai-workflow}"
BINDIR="$AIWF/bin"
TMPDIR="$AIWF/tmp"
RUN_ORCHESTRATOR="$BINDIR/run_agent_orchestrator.sh"
FORMAT_REPLY="$BINDIR/format_orchestrator_reply.py"

mkdir -p "$TMPDIR"

[[ -x "$RUN_ORCHESTRATOR" ]] || { echo "missing dependency: $RUN_ORCHESTRATOR" >&2; exit 1; }
[[ -f "$FORMAT_REPLY" ]] || { echo "missing dependency: $FORMAT_REPLY" >&2; exit 1; }

STAMP="$(date +%Y%m%d_%H%M%S)"
RUN_ID="${STAMP}_$$"
ORCH_CAPTURE="$TMPDIR/workflow_reply_${RUN_ID}.out"

"$RUN_ORCHESTRATOR" "$REPO_DIR" "$TASK_TYPE" "$USER_REQ_FILE" "$COPILOT_MODEL" "$FALLBACK_MODE" "$CODEX_MODEL" > "$ORCH_CAPTURE"
REPLY_OUTPUT="$(python3 "$FORMAT_REPLY" "$ORCH_CAPTURE")"

if [[ "$OUTPUT_MODE" == "text" ]]; then
  printf '%s\n' "$REPLY_OUTPUT"
  exit 0
fi

python3 - <<'PY' "$ORCH_CAPTURE" "$REPLY_OUTPUT"
import json
import pathlib
import sys

capture = pathlib.Path(sys.argv[1])
reply = sys.argv[2]
fields = {}
for raw_line in capture.read_text(encoding='utf-8', errors='replace').splitlines():
    line = raw_line.strip()
    if not line or '=' not in line:
        continue
    key, value = line.split('=', 1)
    fields[key] = value

parsed = {}
parsed_path = fields.get('PARSED_JSON_FILE')
if parsed_path:
    path = pathlib.Path(parsed_path)
    if path.is_file():
        try:
            parsed = json.loads(path.read_text(encoding='utf-8', errors='replace'))
        except Exception:
            parsed = {}

payload = {
    'status': fields.get('STATUS'),
    'task_type': fields.get('TASK_TYPE'),
    'executor_used': fields.get('EXECUTOR_USED'),
    'fallback_occurred': fields.get('FALLBACK_OCCURRED') == '1',
    'copilot_attempts': int(fields['COPILOT_ATTEMPTS']) if fields.get('COPILOT_ATTEMPTS', '').isdigit() else fields.get('COPILOT_ATTEMPTS'),
    'reason': fields.get('REASON'),
    'orchestrator_output_file': str(capture),
    'final_message_file': fields.get('FINAL_MESSAGE_FILE'),
    'parsed_json_file': fields.get('PARSED_JSON_FILE'),
    'log_file': fields.get('LOG_FILE'),
    'events_file': fields.get('EVENTS_FILE'),
    'orchestrator_log': fields.get('ORCHESTRATOR_LOG'),
    'missing_dependency': fields.get('MISSING_DEPENDENCY'),
    'reply': reply,
    'summary': parsed.get('summary'),
    'root_cause': parsed.get('root_cause'),
    'changed_files': parsed.get('changed_files'),
    'commands_run': parsed.get('commands_run'),
    'test_result': parsed.get('test_result'),
    'risks': parsed.get('risks'),
    'next_step': parsed.get('next_step'),
}
print(json.dumps(payload, ensure_ascii=False))
PY
