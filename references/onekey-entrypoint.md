# One-key entry script notes

Entry script added:
- `~/ai-workflow/bin/run_workflow_reply.sh`

Test file added:
- `~/ai-workflow/tests/test_run_workflow_reply.sh`

## Interface

```bash
~/ai-workflow/bin/run_workflow_reply.sh [--json] <repo_dir> <task_type> <user_request_file> [copilot_model] [fallback_mode] [codex_model]
```

## Behavior

1. Resolve `AI_WORKFLOW_HOME` or default to `~/ai-workflow`.
2. Validate that these dependencies exist:
   - `bin/run_agent_orchestrator.sh`
   - `bin/format_orchestrator_reply.py`
3. Run the orchestrator and save its key=value output to:
   - `tmp/workflow_reply_<timestamp>_<pid>.out`
4. Pass that saved file to the formatter.
5. In default mode, print the final Chinese user-facing reply to stdout.
6. In `--json` mode, print a JSON object that includes:
   - `reply`
   - `status`
   - `task_type`
   - `executor_used`
   - `fallback_occurred`
   - `reason`
   - `orchestrator_output_file`
   - and related output-file metadata
7. When `PARSED_JSON_FILE` is present and readable, inline common parsed fields too:
   - `summary`
   - `root_cause`
   - `changed_files`
   - `commands_run`
   - `test_result`
   - `risks`
   - `next_step`

## Why this layer exists

It removes the last bit of glue logic from Hermes.
Instead of:
- run orchestrator
- capture output
- save it
- call formatter
- return formatter stdout

Hermes can now just call one script and forward stdout.

## Verified scenarios

Executed with:
```bash
bash /home/rorobin/ai-workflow/tests/test_run_workflow_reply.sh
```

Verified:
- orchestrator is invoked with the original arguments
- orchestrator output is saved under `tmp/workflow_reply_*.out`
- formatter is invoked against that saved file
- final reply is printed to stdout
- `--json` mode returns reply text together with workflow metadata in a single JSON object
- `--json` mode also inlines parsed fields from `PARSED_JSON_FILE` when available
