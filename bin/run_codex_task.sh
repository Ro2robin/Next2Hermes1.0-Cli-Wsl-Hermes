#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="${1:?usage: run_codex_task.sh <repo_dir> <prompt_file> [model] }"
PROMPT_FILE="${2:?usage: run_codex_task.sh <repo_dir> <prompt_file> [model] }"
MODEL="${3:-gpt-5.4}"

AIWF="${AI_WORKFLOW_HOME:-$HOME/ai-workflow}"
WORKDIR="$AIWF/tmp"
mkdir -p "$WORKDIR"

STAMP="$(date +%Y%m%d_%H%M%S)"
RUN_ID="${STAMP}_$$"
OUT_TXT="$WORKDIR/codex_${RUN_ID}_final.txt"
OUT_JSONL="$WORKDIR/codex_${RUN_ID}_events.jsonl"

if [[ ! -d "$REPO_DIR/.git" ]]; then
  echo "ERROR: $REPO_DIR is not a git repository" >&2
  exit 2
fi

cd "$REPO_DIR"

codex exec \
  --cd "$REPO_DIR" \
  --model "$MODEL" \
  --json \
  --output-last-message "$OUT_TXT" \
  - < "$PROMPT_FILE" | tee "$OUT_JSONL"

echo "FINAL_MESSAGE_FILE=$OUT_TXT"
echo "EVENTS_FILE=$OUT_JSONL"
