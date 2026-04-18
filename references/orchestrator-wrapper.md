# Orchestrator wrapper notes

Wrapper added:
- `~/ai-workflow/bin/run_agent_orchestrator.sh`

Test file added:
- `~/ai-workflow/tests/test_run_agent_orchestrator.sh`

## Interface

```bash
~/ai-workflow/bin/run_agent_orchestrator.sh <repo_dir> <task_type> <user_request_file> [copilot_model] [fallback_mode] [codex_model]
```

Defaults:
- `copilot_model=auto`
- `fallback_mode=allow`
- `codex_model=gpt-5.4`

## Implemented behavior

1. Validate repo dir, `.git`, task type, fallback mode, and dependency scripts.
2. Archive the user request into `tmp/`.
3. Run Copilot up to two attempts.
4. Validate output by requiring:
   - non-empty final file
   - all exact section headers
   - successful parse via `parse_agent_result.py`
   - non-empty `summary`
5. If allowed and needed, build a fallback prompt and run Codex.
6. Reuse the timestamped Codex outputs emitted by `run_codex_task.sh` directly.
7. Emit machine-readable key=value lines for Hermes to consume, including:
   - `TASK_TYPE=...` for downstream reply formatting
   - `REASON=...` for stable failure categorization
   - `MISSING_DEPENDENCY=...` when dependency validation fails

## Verified scenarios

Executed with:
```bash
bash /home/rorobin/ai-workflow/tests/test_run_agent_orchestrator.sh
```

Verified:
- Copilot succeeds on first attempt
- Copilot fails twice and Codex fallback succeeds
- Orchestrator reuses the Codex wrapper's emitted output paths directly
- `copilot_output_invalid` is emitted when fallback is disabled after invalid Copilot output
- `copilot_timeout` is emitted when fallback is disabled after timeout
- `codex_output_invalid` is emitted when fallback output is unparseable
- `dependency_missing` plus `MISSING_DEPENDENCY` are emitted when a required script is absent
- `no-fallback` mode fails without invoking Codex

## Important limitation

The orchestrator's output validation is intentionally strict. If prompt format changes and section headers drift from the expected exact names, the orchestrator may treat an otherwise useful response as invalid and trigger fallback or failure.
