#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF' >&2
usage: run_agent_orchestrator.sh <repo_dir> <task_type> <user_request_file> [copilot_model] [fallback_mode] [codex_model]

fallback_mode:
  allow        allow retry + Codex fallback (default)
  no-fallback  retry Copilot once, then fail
EOF
}

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
LOGDIR="$AIWF/logs"
PARSER="$BINDIR/parse_agent_result.py"
PROMPT_BUILDER="$BINDIR/build_copilot_prompt.sh"
RUN_COPILOT="$BINDIR/run_copilot_main.sh"
RUN_CODEX="$BINDIR/run_codex_task.sh"

mkdir -p "$TMPDIR" "$LOGDIR"

STAMP="$(date +%Y%m%d_%H%M%S)"
RUN_ID="${STAMP}_$$"
ORCHESTRATOR_LOG="$LOGDIR/orchestrator_${RUN_ID}.log"
REQUEST_ARCHIVE="$TMPDIR/user_request_${RUN_ID}.txt"
FALLBACK_PROMPT_FILE="$TMPDIR/fallback_prompt_${RUN_ID}.md"
REQUIRED_HEADERS=(SUMMARY ROOT_CAUSE CHANGED_FILES COMMANDS_RUN TEST_RESULT RISKS NEXT_STEP)

log_note() {
  printf '%s %s\n' "[$(date +%Y-%m-%dT%H:%M:%S%z)]" "$*" >> "$ORCHESTRATOR_LOG"
}

emit_result() {
  local status="$1"
  local executor="$2"
  local fallback="$3"
  local attempts="$4"
  local final_file="${5:-}"
  local parsed_json="${6:-}"
  local log_file="${7:-}"
  local events_file="${8:-}"
  local reason="${9:-}"
  local extra_key="${10:-}"
  local extra_value="${11:-}"

  echo "STATUS=$status"
  echo "TASK_TYPE=$TASK_TYPE"
  echo "EXECUTOR_USED=$executor"
  echo "FALLBACK_OCCURRED=$fallback"
  echo "COPILOT_ATTEMPTS=$attempts"
  [[ -n "$final_file" ]] && echo "FINAL_MESSAGE_FILE=$final_file"
  [[ -n "$parsed_json" ]] && echo "PARSED_JSON_FILE=$parsed_json"
  [[ -n "$log_file" ]] && echo "LOG_FILE=$log_file"
  [[ -n "$events_file" ]] && echo "EVENTS_FILE=$events_file"
  [[ -n "$reason" ]] && echo "REASON=$reason"
  [[ -n "$extra_key" ]] && echo "$extra_key=$extra_value"
  echo "ORCHESTRATOR_LOG=$ORCHESTRATOR_LOG"
}

extract_output_var() {
  local key="$1"
  local file="$2"
  awk -F= -v k="$key" '$1 == k { print substr($0, index($0, "=") + 1) }' "$file" | tail -n 1
}

validate_inputs() {
  [[ -d "$REPO_DIR" ]] || { emit_result failed none 0 0 "" "" "" "" "repo_dir_missing"; exit 1; }
  [[ -d "$REPO_DIR/.git" ]] || { emit_result failed none 0 0 "" "" "" "" "repo_not_git"; exit 1; }
  [[ -f "$USER_REQ_FILE" ]] || { emit_result failed none 0 0 "" "" "" "" "user_request_missing"; exit 1; }

  case "$TASK_TYPE" in
    analyze|fix|implement|review) ;;
    *) emit_result failed none 0 0 "" "" "" "" "invalid_task_type"; exit 1 ;;
  esac

  case "$FALLBACK_MODE" in
    allow|no-fallback) ;;
    *) emit_result failed none 0 0 "" "" "" "" "invalid_fallback_mode"; exit 1 ;;
  esac

  local dep
  for dep in "$PARSER" "$PROMPT_BUILDER" "$RUN_COPILOT" "$RUN_CODEX"; do
    [[ -x "$dep" ]] || { emit_result failed none 0 0 "" "" "" "" "dependency_missing" "MISSING_DEPENDENCY" "$dep"; exit 1; }
  done
}

validate_structured_output() {
  local file="$1"
  local json_out="$2"
  [[ -s "$file" ]] || return 1

  local header
  for header in "${REQUIRED_HEADERS[@]}"; do
    grep -Eq "^${header}:\s*$" "$file" || return 1
  done

  python3 "$PARSER" "$file" > "$json_out" || return 1

  python3 - "$json_out" <<'PY'
import json, pathlib, sys
path = pathlib.Path(sys.argv[1])
data = json.loads(path.read_text(encoding='utf-8'))
summary = (data.get('summary') or '').strip()
raise SystemExit(0 if summary else 1)
PY
}

run_copilot_attempt() {
  local attempt="$1"
  local wrapper_capture="$LOGDIR/orchestrator_${RUN_ID}_copilot_attempt_${attempt}.out"
  local final_file=""
  local log_file=""
  local parsed_json="$TMPDIR/copilot_${RUN_ID}_attempt_${attempt}.json"
  local exit_status=0

  log_note "starting copilot attempt ${attempt}"
  if "$RUN_COPILOT" "$REPO_DIR" "$TASK_TYPE" "$REQUEST_ARCHIVE" "$COPILOT_MODEL" > "$wrapper_capture" 2>&1; then
    log_note "copilot attempt ${attempt} exited 0"
  else
    exit_status=$?
    log_note "copilot attempt ${attempt} exited ${exit_status}"
  fi

  final_file="$(extract_output_var FINAL_MESSAGE_FILE "$wrapper_capture")"
  log_file="$(extract_output_var LOG_FILE "$wrapper_capture")"

  if [[ -n "$final_file" ]] && validate_structured_output "$final_file" "$parsed_json"; then
    COPILOT_FINAL_FILE="$final_file"
    COPILOT_LOG_FILE="$log_file"
    COPILOT_PARSED_JSON="$parsed_json"
    COPILOT_LAST_REASON=""
    log_note "copilot attempt ${attempt} produced a valid structured result"
    return 0
  fi

  if [[ "$exit_status" -eq 124 ]]; then
    COPILOT_LAST_REASON="copilot_timeout"
  elif [[ -n "$final_file" && -f "$final_file" ]]; then
    COPILOT_LAST_REASON="copilot_output_invalid"
  elif [[ "$exit_status" -ne 0 ]]; then
    COPILOT_LAST_REASON="copilot_execution_failed"
  else
    COPILOT_LAST_REASON="copilot_output_missing"
  fi

  log_note "copilot attempt ${attempt} did not produce a valid structured result: ${COPILOT_LAST_REASON}"
  COPILOT_FINAL_FILE="$final_file"
  COPILOT_LOG_FILE="$log_file"
  COPILOT_PARSED_JSON=""
  return 1
}

run_codex_fallback() {
  local wrapper_capture="$LOGDIR/orchestrator_${RUN_ID}_codex.out"
  local raw_final_file=""
  local raw_events_file=""
  local parsed_json="$TMPDIR/codex_${RUN_ID}.json"
  local exit_status=0

  "$PROMPT_BUILDER" "$TASK_TYPE" "$REQUEST_ARCHIVE" "$FALLBACK_PROMPT_FILE"
  log_note "starting codex fallback"

  if "$RUN_CODEX" "$REPO_DIR" "$FALLBACK_PROMPT_FILE" "$CODEX_MODEL" > "$wrapper_capture" 2>&1; then
    log_note "codex fallback exited 0"
  else
    exit_status=$?
    log_note "codex fallback exited ${exit_status}"
  fi

  raw_final_file="$(extract_output_var FINAL_MESSAGE_FILE "$wrapper_capture")"
  raw_events_file="$(extract_output_var EVENTS_FILE "$wrapper_capture")"

  if [[ -n "$raw_final_file" && -f "$raw_final_file" ]] && [[ -z "$raw_events_file" || -f "$raw_events_file" ]] && validate_structured_output "$raw_final_file" "$parsed_json"; then
    CODEX_FINAL_FILE="$raw_final_file"
    CODEX_EVENTS_FILE="$raw_events_file"
    CODEX_PARSED_JSON="$parsed_json"
    CODEX_LAST_REASON=""
    return 0
  fi

  if [[ "$exit_status" -eq 124 ]]; then
    CODEX_LAST_REASON="codex_timeout"
  elif [[ -n "$raw_final_file" && -f "$raw_final_file" ]]; then
    CODEX_LAST_REASON="codex_output_invalid"
  elif [[ "$exit_status" -ne 0 ]]; then
    CODEX_LAST_REASON="codex_execution_failed"
  else
    CODEX_LAST_REASON="codex_output_missing"
  fi

  CODEX_FINAL_FILE="$raw_final_file"
  CODEX_EVENTS_FILE="$raw_events_file"
  CODEX_PARSED_JSON=""
  return 1
}

validate_inputs
cp "$USER_REQ_FILE" "$REQUEST_ARCHIVE"
log_note "request archived to $REQUEST_ARCHIVE"

COPILOT_FINAL_FILE=""
COPILOT_LOG_FILE=""
COPILOT_PARSED_JSON=""
COPILOT_LAST_REASON=""
CODEX_FINAL_FILE=""
CODEX_EVENTS_FILE=""
CODEX_PARSED_JSON=""
CODEX_LAST_REASON=""

for attempt in 1 2; do
  if run_copilot_attempt "$attempt"; then
    emit_result success copilot 0 "$attempt" "$COPILOT_FINAL_FILE" "$COPILOT_PARSED_JSON" "$COPILOT_LOG_FILE"
    exit 0
  fi
  COPILOT_ATTEMPTS="$attempt"
done

if [[ "$FALLBACK_MODE" == "no-fallback" ]]; then
  emit_result failed copilot 0 "${COPILOT_ATTEMPTS:-2}" "$COPILOT_FINAL_FILE" "" "$COPILOT_LOG_FILE" "" "${COPILOT_LAST_REASON:-copilot_output_invalid}"
  exit 1
fi

if run_codex_fallback; then
  emit_result success codex 1 "${COPILOT_ATTEMPTS:-2}" "$CODEX_FINAL_FILE" "$CODEX_PARSED_JSON" "$COPILOT_LOG_FILE" "$CODEX_EVENTS_FILE"
  exit 0
fi

emit_result failed codex 1 "${COPILOT_ATTEMPTS:-2}" "$CODEX_FINAL_FILE" "" "$COPILOT_LOG_FILE" "$CODEX_EVENTS_FILE" "${CODEX_LAST_REASON:-codex_output_invalid}"
exit 1
