# User reply formatter notes

Formatter added:
- `~/ai-workflow/bin/format_orchestrator_reply.py`

Test file added:
- `~/ai-workflow/tests/test_format_orchestrator_reply.sh`

## Interface

```bash
python3 ~/ai-workflow/bin/format_orchestrator_reply.py <orchestrator_output_file>
```

Input:
- a file containing the key=value output emitted by `run_agent_orchestrator.sh`

Important consumed fields:
- `STATUS`
- `TASK_TYPE`
- `EXECUTOR_USED`
- `FALLBACK_OCCURRED`
- `PARSED_JSON_FILE`
- `REASON`
- `MISSING_DEPENDENCY`

## Success behavior

When `STATUS=success`, the formatter prefers `PARSED_JSON_FILE` and emits stable Chinese sections such as:
- `任务判断：...`
- `执行状态：成功`
- `任务概览：...`
- `根因：...`
- `修改内容：...`
- `验证情况：...`
- `风险点：...`
- `下一步建议：...`

If fallback occurred, the formatter explicitly notes that Copilot already fell back.

## Failure behavior

When `STATUS=failed`, the formatter uses `REASON` to produce a human-readable explanation and suggestion.

Examples:
- `copilot_timeout` → primary executor timed out
- `copilot_output_invalid` → Copilot returned unusable structured output
- `codex_output_invalid` → fallback also returned unusable structured output
- `dependency_missing` → includes `缺失依赖：...` from `MISSING_DEPENDENCY`

## Verified scenarios

Executed with:
```bash
bash /home/rorobin/ai-workflow/tests/test_format_orchestrator_reply.sh
```

Verified:
- success reply formatting from parsed JSON
- failure reply formatting from `REASON`
- dependency failure formatting from `MISSING_DEPENDENCY`

## Important limitation

The formatter is intentionally template-driven. If downstream users want a different tone or section order, update the formatter script rather than trying to reconstruct replies from raw orchestrator logs in ad-hoc ways.
