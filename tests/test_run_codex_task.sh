#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_UNDER_TEST="$REPO_ROOT/bin/run_codex_task.sh"

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

extract_value() {
  local key="$1"
  local file="$2"
  awk -F= -v k="$key" '$1 == k { print substr($0, index($0, "=") + 1) }' "$file" | tail -n 1
}

make_harness() {
  local root
  root="$(mktemp -d)"
  mkdir -p "$root/home/ai-workflow/tmp" "$root/repo/.git" "$root/bin"

  cat > "$root/prompt.md" <<'EOF'
SUMMARY:
mock
EOF

  cat > "$root/bin/codex" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
LAST_MESSAGE_FILE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-last-message)
      LAST_MESSAGE_FILE="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done
[[ -n "$LAST_MESSAGE_FILE" ]] || exit 2
cat > "$LAST_MESSAGE_FILE" <<'MSG'
SUMMARY:
Codex raw success.
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
printf '{"type":"result"}\n'
EOF
  chmod +x "$root/bin/codex"

  echo "$root"
}

run_timestamped_output_case() {
  local root output_file output final_file events_file
  root="$(make_harness)"
  output_file="$root/out.txt"

  HOME="$root/home" PATH="$root/bin:$PATH" \
    "$SCRIPT_UNDER_TEST" "$root/repo" "$root/prompt.md" gpt-5.4 > "$output_file"

  output="$(cat "$output_file")"
  assert_contains "$output" "FINAL_MESSAGE_FILE="
  assert_contains "$output" "EVENTS_FILE="

  final_file="$(extract_value FINAL_MESSAGE_FILE "$output_file")"
  events_file="$(extract_value EVENTS_FILE "$output_file")"

  assert_file_exists "$final_file"
  assert_file_exists "$events_file"

  [[ "$final_file" == *"/codex_"*"_final.txt" ]] || fail "expected timestamped final message filename, got: $final_file"
  [[ "$events_file" == *"/codex_"*"_events.jsonl" ]] || fail "expected timestamped events filename, got: $events_file"
  [[ "$final_file" != *"codex_last_message.txt" ]] || fail "final file should no longer use the fixed legacy filename"
  [[ "$events_file" != *"codex_events.jsonl" ]] || fail "events file should no longer use the fixed legacy filename"

  rm -rf "$root"
}

[[ -x "$SCRIPT_UNDER_TEST" ]] || fail "script under test is missing or not executable: $SCRIPT_UNDER_TEST"

run_timestamped_output_case

echo "PASS: run_codex_task.sh"
