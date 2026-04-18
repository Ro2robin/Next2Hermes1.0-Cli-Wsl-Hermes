#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_UNDER_TEST="$REPO_ROOT/bin/run_agent_orchestrator.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  if [[ "$haystack" != *"$needle"* ]]; then
    fail "expected output to contain: $needle"
  fi
}

assert_file_exists() {
  local path="$1"
  [[ -f "$path" ]] || fail "expected file to exist: $path"
}

make_harness() {
  local root
  root="$(mktemp -d)"

  mkdir -p "$root/home/ai-workflow/bin" "$root/home/ai-workflow/tmp" "$root/home/ai-workflow/logs" "$root/repo/.git"
  cat > "$root/request.txt" <<'EOF'
Please run the workflow.
EOF

  cat > "$root/home/ai-workflow/bin/build_copilot_prompt.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
TASK_TYPE="$1"
USER_REQ_FILE="$2"
OUT_FILE="$3"
printf 'PROMPT FOR %s\n' "$TASK_TYPE" > "$OUT_FILE"
cat "$USER_REQ_FILE" >> "$OUT_FILE"
EOF
  chmod +x "$root/home/ai-workflow/bin/build_copilot_prompt.sh"

  cat > "$root/home/ai-workflow/bin/parse_agent_result.py" <<'EOF'
#!/usr/bin/env python3
import json, pathlib, re, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding='utf-8', errors='replace')
keys = ["SUMMARY", "ROOT_CAUSE", "CHANGED_FILES", "COMMANDS_RUN", "TEST_RESULT", "RISKS", "NEXT_STEP"]
result = {k.lower(): "" for k in keys}
pattern = re.compile(r'^(SUMMARY|ROOT_CAUSE|CHANGED_FILES|COMMANDS_RUN|TEST_RESULT|RISKS|NEXT_STEP):\s*$', re.M)
matches = list(pattern.finditer(text))
for i, m in enumerate(matches):
    key = m.group(1).lower()
    start = m.end()
    end = matches[i+1].start() if i + 1 < len(matches) else len(text)
    result[key] = text[start:end].strip()
print(json.dumps(result, ensure_ascii=False))
EOF
  chmod +x "$root/home/ai-workflow/bin/parse_agent_result.py"

  cat > "$root/home/ai-workflow/bin/run_copilot_main.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
REPO_DIR="$1"
TASK_TYPE="$2"
USER_REQ_FILE="$3"
MODEL="${4:-auto}"
AIWF="${AI_WORKFLOW_HOME:?}"
ATTEMPT_FILE="$AIWF/tmp/copilot_attempt_count"
ATTEMPT=0
if [[ -f "$ATTEMPT_FILE" ]]; then
  ATTEMPT="$(cat "$ATTEMPT_FILE")"
fi
ATTEMPT=$((ATTEMPT + 1))
printf '%s' "$ATTEMPT" > "$ATTEMPT_FILE"
FINAL_FILE="$AIWF/tmp/copilot_attempt_${ATTEMPT}.txt"
LOG_FILE="$AIWF/logs/copilot_attempt_${ATTEMPT}.log"
MODE="${TEST_COPILOT_MODE:-success}"
case "$MODE" in
  success)
    cat > "$FINAL_FILE" <<'MSG'
SUMMARY:
Copilot success.
ROOT_CAUSE:
Known.
CHANGED_FILES:
none
COMMANDS_RUN:
none
TEST_RESULT:
not run
RISKS:
low
NEXT_STEP:
none
MSG
    ;;
  retry-success)
    if [[ "$ATTEMPT" -eq 1 ]]; then
      printf 'garbage output\n' > "$FINAL_FILE"
    else
      cat > "$FINAL_FILE" <<'MSG'
SUMMARY:
Copilot second attempt success.
ROOT_CAUSE:
Known after retry.
CHANGED_FILES:
none
COMMANDS_RUN:
none
TEST_RESULT:
not run
RISKS:
low
NEXT_STEP:
none
MSG
    fi
    ;;
  always-invalid)
    printf 'garbage output\n' > "$FINAL_FILE"
    ;;
  timeout)
    printf 'copilot timed out\n' > "$LOG_FILE"
    exit 124
    ;;
  *)
    echo "unknown TEST_COPILOT_MODE=$MODE" >&2
    exit 2
    ;;
esac
printf 'copilot attempt %s model=%s task=%s\n' "$ATTEMPT" "$MODEL" "$TASK_TYPE" > "$LOG_FILE"
echo "FINAL_MESSAGE_FILE=$FINAL_FILE"
echo "LOG_FILE=$LOG_FILE"
EOF
  chmod +x "$root/home/ai-workflow/bin/run_copilot_main.sh"

  cat > "$root/home/ai-workflow/bin/run_codex_task.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
AIWF="${AI_WORKFLOW_HOME:?}"
FINAL_FILE="$AIWF/tmp/codex_wrapper_001_final.txt"
EVENTS_FILE="$AIWF/tmp/codex_wrapper_001_events.jsonl"
MODE="${TEST_CODEX_MODE:-success}"
case "$MODE" in
  success)
    cat > "$FINAL_FILE" <<'MSG'
SUMMARY:
Codex fallback success.
ROOT_CAUSE:
Copilot invalid.
CHANGED_FILES:
none
COMMANDS_RUN:
none
TEST_RESULT:
not run
RISKS:
low
NEXT_STEP:
none
MSG
    printf '{"type":"result"}\n' > "$EVENTS_FILE"
    ;;
  invalid)
    printf 'garbage output\n' > "$FINAL_FILE"
    printf '{"type":"result"}\n' > "$EVENTS_FILE"
    ;;
  *)
    echo "unknown TEST_CODEX_MODE=$MODE" >&2
    exit 2
    ;;
esac
printf '1' > "$AIWF/tmp/codex_called"
echo "FINAL_MESSAGE_FILE=$FINAL_FILE"
echo "EVENTS_FILE=$EVENTS_FILE"
EOF
  chmod +x "$root/home/ai-workflow/bin/run_codex_task.sh"

  echo "$root"
}

extract_value() {
  local key="$1"
  local file="$2"
  awk -F= -v k="$key" '$1 == k { print substr($0, index($0, "=") + 1) }' "$file" | tail -n 1
}

run_success_case() {
  local root output_file output final_file parsed_file
  root="$(make_harness)"
  output_file="$root/out.txt"

  AI_WORKFLOW_HOME="$root/home/ai-workflow" \
  TEST_COPILOT_MODE="success" \
  "$SCRIPT_UNDER_TEST" "$root/repo" analyze "$root/request.txt" auto allow gpt-5.4 > "$output_file"

  output="$(cat "$output_file")"
  assert_contains "$output" "STATUS=success"
  assert_contains "$output" "TASK_TYPE=analyze"
  assert_contains "$output" "EXECUTOR_USED=copilot"
  assert_contains "$output" "FALLBACK_OCCURRED=0"
  assert_contains "$output" "COPILOT_ATTEMPTS=1"

  final_file="$(extract_value FINAL_MESSAGE_FILE "$output_file")"
  parsed_file="$(extract_value PARSED_JSON_FILE "$output_file")"
  assert_file_exists "$final_file"
  assert_file_exists "$parsed_file"
  [[ ! -f "$root/home/ai-workflow/tmp/codex_called" ]] || fail "codex should not have been called"

  rm -rf "$root"
}

run_fallback_case() {
  local root output_file output final_file events_file
  root="$(make_harness)"
  output_file="$root/out.txt"

  AI_WORKFLOW_HOME="$root/home/ai-workflow" \
  TEST_COPILOT_MODE="always-invalid" \
  "$SCRIPT_UNDER_TEST" "$root/repo" fix "$root/request.txt" auto allow gpt-5.4 > "$output_file"

  output="$(cat "$output_file")"
  assert_contains "$output" "STATUS=success"
  assert_contains "$output" "TASK_TYPE=fix"
  assert_contains "$output" "EXECUTOR_USED=codex"
  assert_contains "$output" "FALLBACK_OCCURRED=1"
  assert_contains "$output" "COPILOT_ATTEMPTS=2"

  final_file="$(extract_value FINAL_MESSAGE_FILE "$output_file")"
  events_file="$(extract_value EVENTS_FILE "$output_file")"
  assert_file_exists "$final_file"
  assert_file_exists "$events_file"
  [[ "$final_file" == "$root/home/ai-workflow/tmp/codex_wrapper_001_final.txt" ]] || fail "orchestrator should reuse Codex final output path directly"
  [[ "$events_file" == "$root/home/ai-workflow/tmp/codex_wrapper_001_events.jsonl" ]] || fail "orchestrator should reuse Codex events path directly"
  [[ ! -e "$root/home/ai-workflow/logs/codex_wrapper_001_events.jsonl" ]] || fail "orchestrator should not duplicate Codex events into logs"
  [[ -f "$root/home/ai-workflow/tmp/codex_called" ]] || fail "codex should have been called"

  rm -rf "$root"
}

run_no_fallback_case() {
  local root output_file
  root="$(make_harness)"
  output_file="$root/out.txt"

  set +e
  AI_WORKFLOW_HOME="$root/home/ai-workflow" \
  TEST_COPILOT_MODE="always-invalid" \
  "$SCRIPT_UNDER_TEST" "$root/repo" review "$root/request.txt" auto no-fallback gpt-5.4 > "$output_file" 2>&1
  local status=$?
  set -e

  [[ "$status" -ne 0 ]] || fail "expected no-fallback mode to fail when copilot remains invalid"
  assert_contains "$(cat "$output_file")" "STATUS=failed"
  assert_contains "$(cat "$output_file")" "EXECUTOR_USED=copilot"
  assert_contains "$(cat "$output_file")" "REASON=copilot_output_invalid"
  [[ ! -f "$root/home/ai-workflow/tmp/codex_called" ]] || fail "codex should not run in no-fallback mode"

  rm -rf "$root"
}

run_timeout_reason_case() {
  local root output_file
  root="$(make_harness)"
  output_file="$root/out.txt"

  set +e
  AI_WORKFLOW_HOME="$root/home/ai-workflow" \
  TEST_COPILOT_MODE="timeout" \
  "$SCRIPT_UNDER_TEST" "$root/repo" review "$root/request.txt" auto no-fallback gpt-5.4 > "$output_file" 2>&1
  local status=$?
  set -e

  [[ "$status" -ne 0 ]] || fail "expected timeout case to fail when fallback is disabled"
  assert_contains "$(cat "$output_file")" "STATUS=failed"
  assert_contains "$(cat "$output_file")" "REASON=copilot_timeout"
  [[ ! -f "$root/home/ai-workflow/tmp/codex_called" ]] || fail "codex should not run in timeout no-fallback mode"

  rm -rf "$root"
}

run_codex_invalid_reason_case() {
  local root output_file
  root="$(make_harness)"
  output_file="$root/out.txt"

  set +e
  AI_WORKFLOW_HOME="$root/home/ai-workflow" \
  TEST_COPILOT_MODE="always-invalid" \
  TEST_CODEX_MODE="invalid" \
  "$SCRIPT_UNDER_TEST" "$root/repo" fix "$root/request.txt" auto allow gpt-5.4 > "$output_file" 2>&1
  local status=$?
  set -e

  [[ "$status" -ne 0 ]] || fail "expected invalid codex output to fail"
  assert_contains "$(cat "$output_file")" "STATUS=failed"
  assert_contains "$(cat "$output_file")" "EXECUTOR_USED=codex"
  assert_contains "$(cat "$output_file")" "REASON=codex_output_invalid"

  rm -rf "$root"
}

run_missing_dependency_reason_case() {
  local root output_file
  root="$(make_harness)"
  output_file="$root/out.txt"
  rm -f "$root/home/ai-workflow/bin/run_codex_task.sh"

  set +e
  AI_WORKFLOW_HOME="$root/home/ai-workflow" \
  "$SCRIPT_UNDER_TEST" "$root/repo" fix "$root/request.txt" auto allow gpt-5.4 > "$output_file" 2>&1
  local status=$?
  set -e

  [[ "$status" -ne 0 ]] || fail "expected missing dependency to fail"
  assert_contains "$(cat "$output_file")" "STATUS=failed"
  assert_contains "$(cat "$output_file")" "REASON=dependency_missing"
  assert_contains "$(cat "$output_file")" "MISSING_DEPENDENCY=$root/home/ai-workflow/bin/run_codex_task.sh"

  rm -rf "$root"
}

[[ -x "$SCRIPT_UNDER_TEST" ]] || fail "script under test is missing or not executable: $SCRIPT_UNDER_TEST"

run_success_case
run_fallback_case
run_no_fallback_case
run_timeout_reason_case
run_codex_invalid_reason_case
run_missing_dependency_reason_case

echo "PASS: run_agent_orchestrator.sh"
