#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_UNDER_TEST="$REPO_ROOT/bin/run_workflow_reply.sh"

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
  mkdir -p "$root/home/ai-workflow/bin" "$root/home/ai-workflow/tmp" "$root/repo/.git"

  cat > "$root/request.txt" <<'EOF'
Please fix the auth flow.
EOF

  cat > "$root/home/ai-workflow/bin/run_agent_orchestrator.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
AIWF="${AI_WORKFLOW_HOME:?}"
printf '%s\n' "$@" > "$AIWF/tmp/orchestrator_args.txt"
cat > "$AIWF/tmp/orchestrator_output.out" <<OUT
STATUS=success
TASK_TYPE=$2
EXECUTOR_USED=codex
FALLBACK_OCCURRED=1
COPILOT_ATTEMPTS=2
PARSED_JSON_FILE=$AIWF/tmp/parsed.json
ORCHESTRATOR_LOG=$AIWF/tmp/orchestrator.log
OUT
cat > "$AIWF/tmp/parsed.json" <<JSON
{"summary":"已修复登录流程。","root_cause":"配置错误。","changed_files":"src/auth.py","commands_run":"pytest -q","test_result":"1 passed","risks":"低","next_step":"继续观察。"}
JSON
cat "$AIWF/tmp/orchestrator_output.out"
EOF
  chmod +x "$root/home/ai-workflow/bin/run_agent_orchestrator.sh"

  cat > "$root/home/ai-workflow/bin/format_orchestrator_reply.py" <<'EOF'
#!/usr/bin/env python3
import pathlib, sys
source = pathlib.Path(sys.argv[1])
print("任务判断：fix（由 codex 完成，Copilot 已回退）")
print("执行状态：成功")
print(f"来源文件：{source}")
EOF
  chmod +x "$root/home/ai-workflow/bin/format_orchestrator_reply.py"

  echo "$root"
}

run_success_case() {
  local root output meta_file
  root="$(make_harness)"

  output="$(AI_WORKFLOW_HOME="$root/home/ai-workflow" "$SCRIPT_UNDER_TEST" "$root/repo" fix "$root/request.txt" auto allow gpt-5.4)"

  assert_contains "$output" "任务判断：fix（由 codex 完成，Copilot 已回退）"
  assert_contains "$output" "执行状态：成功"
  assert_contains "$output" "来源文件：$root/home/ai-workflow/tmp/workflow_reply_"

  meta_file="$(find "$root/home/ai-workflow/tmp" -maxdepth 1 -type f -name 'workflow_reply_*.out' | head -n 1)"
  [[ -n "$meta_file" ]] || fail "expected one-key entry to save orchestrator output under tmp/workflow_reply_*.out"
  assert_file_exists "$meta_file"
  assert_contains "$(cat "$root/home/ai-workflow/tmp/orchestrator_args.txt")" "$root/repo"
  assert_contains "$(cat "$root/home/ai-workflow/tmp/orchestrator_args.txt")" "fix"
  assert_contains "$(cat "$root/home/ai-workflow/tmp/orchestrator_args.txt")" "$root/request.txt"

  rm -rf "$root"
}

run_json_case() {
  local root json_output
  root="$(make_harness)"

  json_output="$(AI_WORKFLOW_HOME="$root/home/ai-workflow" "$SCRIPT_UNDER_TEST" --json "$root/repo" fix "$root/request.txt" auto allow gpt-5.4)"

  python3 - <<'PY' "$json_output" "$root"
import json, sys
payload = json.loads(sys.argv[1])
root = sys.argv[2]
assert payload["status"] == "success", payload
assert payload["task_type"] == "fix", payload
assert payload["executor_used"] == "codex", payload
assert payload["fallback_occurred"] is True, payload
assert payload["reason"] in (None, ""), payload
assert payload["summary"] == "已修复登录流程。", payload
assert payload["root_cause"] == "配置错误。", payload
assert payload["changed_files"] == "src/auth.py", payload
assert payload["test_result"] == "1 passed", payload
assert payload["next_step"] == "继续观察。", payload
assert payload["reply"].startswith("任务判断：fix（由 codex 完成，Copilot 已回退）"), payload
assert payload["orchestrator_output_file"].startswith(f"{root}/home/ai-workflow/tmp/workflow_reply_"), payload
print("json-ok")
PY

  rm -rf "$root"
}

[[ -x "$SCRIPT_UNDER_TEST" ]] || fail "script under test is missing or not executable: $SCRIPT_UNDER_TEST"

run_success_case
run_json_case

echo "PASS: run_workflow_reply.sh"
