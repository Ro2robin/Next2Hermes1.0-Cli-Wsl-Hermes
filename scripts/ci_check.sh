#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

echo "[ci] python=$(python3 --version)"
echo "[ci] bash=$(bash --version | head -n 1)"

echo "[ci] running tests/test_run_codex_task.sh"
bash tests/test_run_codex_task.sh

echo "[ci] running tests/test_run_agent_orchestrator.sh"
bash tests/test_run_agent_orchestrator.sh

echo "[ci] running tests/test_format_orchestrator_reply.sh"
bash tests/test_format_orchestrator_reply.sh

echo "[ci] running tests/test_run_workflow_reply.sh"
bash tests/test_run_workflow_reply.sh

echo "[ci] all checks passed"
