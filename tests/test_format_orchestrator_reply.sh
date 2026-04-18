#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_UNDER_TEST="$REPO_ROOT/bin/format_orchestrator_reply.py"

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

make_harness() {
  local root
  root="$(mktemp -d)"

  cat > "$root/parsed_success.json" <<'EOF'
{
  "summary": "已完成最小修复，并确认主流程恢复。",
  "root_cause": "环境变量名称拼写错误，导致认证配置没有生效。",
  "changed_files": "src/config.py\nsrc/auth.py",
  "commands_run": "pytest tests/test_auth.py -q",
  "test_result": "1 passed",
  "risks": "还有一处旧配置路径未清理。",
  "next_step": "建议补一条配置回归测试。"
}
EOF

  cat > "$root/success.out" <<EOF
STATUS=success
TASK_TYPE=fix
EXECUTOR_USED=codex
FALLBACK_OCCURRED=1
COPILOT_ATTEMPTS=2
FINAL_MESSAGE_FILE=$root/codex_final.txt
PARSED_JSON_FILE=$root/parsed_success.json
LOG_FILE=$root/copilot.log
EVENTS_FILE=$root/codex.jsonl
ORCHESTRATOR_LOG=$root/orchestrator.log
EOF

  cat > "$root/failure.out" <<EOF
STATUS=failed
TASK_TYPE=fix
EXECUTOR_USED=codex
FALLBACK_OCCURRED=1
COPILOT_ATTEMPTS=2
REASON=codex_output_invalid
FINAL_MESSAGE_FILE=$root/codex_bad.txt
LOG_FILE=$root/copilot.log
EVENTS_FILE=$root/codex.jsonl
ORCHESTRATOR_LOG=$root/orchestrator.log
EOF

  cat > "$root/dependency_failure.out" <<EOF
STATUS=failed
TASK_TYPE=fix
EXECUTOR_USED=none
FALLBACK_OCCURRED=0
COPILOT_ATTEMPTS=0
REASON=dependency_missing
MISSING_DEPENDENCY=/home/rorobin/ai-workflow/bin/run_codex_task.sh
ORCHESTRATOR_LOG=$root/orchestrator.log
EOF

  echo "$root"
}

run_success_case() {
  local root output
  root="$(make_harness)"
  output="$(python3 "$SCRIPT_UNDER_TEST" "$root/success.out")"

  assert_contains "$output" "任务判断：fix（由 codex 完成，Copilot 已回退）"
  assert_contains "$output" "执行状态：成功"
  assert_contains "$output" "根因：环境变量名称拼写错误，导致认证配置没有生效。"
  assert_contains "$output" "修改内容：src/config.py"
  assert_contains "$output" "验证情况：1 passed"
  assert_contains "$output" "风险点：还有一处旧配置路径未清理。"
  assert_contains "$output" "下一步建议：建议补一条配置回归测试。"

  rm -rf "$root"
}

run_failure_case() {
  local root output
  root="$(make_harness)"
  output="$(python3 "$SCRIPT_UNDER_TEST" "$root/failure.out")"

  assert_contains "$output" "任务判断：执行失败"
  assert_contains "$output" "执行状态：失败（codex_output_invalid）"
  assert_contains "$output" "失败说明：备用执行器已运行，但返回结果无法按预期结构解析。"
  assert_contains "$output" "建议：检查 FINAL_MESSAGE_FILE 的原始输出，并确认 SUMMARY/ROOT_CAUSE 等固定段落标题是否完整。"

  rm -rf "$root"
}

run_dependency_failure_case() {
  local root output
  root="$(make_harness)"
  output="$(python3 "$SCRIPT_UNDER_TEST" "$root/dependency_failure.out")"

  assert_contains "$output" "任务判断：执行失败"
  assert_contains "$output" "执行状态：失败（dependency_missing）"
  assert_contains "$output" "失败说明：工作流缺少必要依赖文件。"
  assert_contains "$output" "缺失依赖：/home/rorobin/ai-workflow/bin/run_codex_task.sh"

  rm -rf "$root"
}

[[ -f "$SCRIPT_UNDER_TEST" ]] || fail "script under test is missing: $SCRIPT_UNDER_TEST"

run_success_case
run_failure_case
run_dependency_failure_case

echo "PASS: format_orchestrator_reply.py"
