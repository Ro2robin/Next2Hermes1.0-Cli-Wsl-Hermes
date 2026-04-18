#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="${1:?usage: run_copilot_main.sh <repo_dir> <task_type> <user_request_file> [model] }"
TASK_TYPE="${2:?usage: run_copilot_main.sh <repo_dir> <task_type> <user_request_file> [model] }"
USER_REQ_FILE="${3:?usage: run_copilot_main.sh <repo_dir> <task_type> <user_request_file> [model] }"
MODEL="${4:-auto}"

WORKDIR="$HOME/ai-workflow/tmp"
LOGDIR="$HOME/ai-workflow/logs"
mkdir -p "$WORKDIR" "$LOGDIR"

STAMP="$(date +%Y%m%d_%H%M%S)"
PROMPT_FILE="$WORKDIR/prompt_${STAMP}.md"
OUT_TXT="$WORKDIR/copilot_${STAMP}_final.txt"
OUT_LOG="$LOGDIR/copilot_${STAMP}.log"

if [[ ! -d "$REPO_DIR/.git" ]]; then
  echo "ERROR: $REPO_DIR is not a git repository" >&2
  exit 2
fi

"$HOME/ai-workflow/bin/build_copilot_prompt.sh" "$TASK_TYPE" "$USER_REQ_FILE" "$PROMPT_FILE"

case "$TASK_TYPE" in
  analyze|review)
    TOOL_ARGS=(
      "--allow-tool=read"
      "--allow-tool=shell(git status)"
      "--allow-tool=shell(git diff:*)"
      "--allow-tool=shell(ls:*)"
      "--allow-tool=shell(cat:*)"
      "--deny-tool=write"
      "--deny-tool=shell(rm:*)"
      "--deny-tool=shell(git push)"
      "--deny-tool=url(*)"
    )
    ;;
  fix|implement)
    TOOL_ARGS=(
      "--allow-tool=read"
      "--allow-tool=write"
      "--allow-tool=shell(git status)"
      "--allow-tool=shell(git diff:*)"
      "--allow-tool=shell(ls:*)"
      "--allow-tool=shell(cat:*)"
      "--allow-tool=shell(pytest:*)"
      "--allow-tool=shell(python:*)"
      "--allow-tool=shell(npm test:*)"
      "--allow-tool=shell(node:*)"
      "--deny-tool=shell(rm:*)"
      "--deny-tool=shell(git push)"
      "--deny-tool=url(*)"
    )
    ;;
  *)
    echo "Unknown task_type: $TASK_TYPE" >&2
    exit 2
    ;;
esac

cd "$REPO_DIR"

{
  echo "=== REPO ==="
  pwd
  echo
  echo "=== TASK TYPE ==="
  echo "$TASK_TYPE"
  echo
  echo "=== GIT STATUS BEFORE ==="
  git status --short || true
  echo
  echo "=== PROMPT FILE ==="
  echo "$PROMPT_FILE"
  echo
  echo "=== COPILOT OUTPUT ==="
} | tee "$OUT_LOG"

copilot \
  -p "$(cat "$PROMPT_FILE")" \
  --model "$MODEL" \
  --silent \
  --stream=off \
  --no-ask-user \
  "${TOOL_ARGS[@]}" \
  | tee "$OUT_TXT" | tee -a "$OUT_LOG"

{
  echo
  echo "=== GIT STATUS AFTER ==="
  git status --short || true
  echo
  echo "=== CHANGED FILES ==="
  git diff --name-only || true
} | tee -a "$OUT_LOG"

echo "FINAL_MESSAGE_FILE=$OUT_TXT"
echo "LOG_FILE=$OUT_LOG"
