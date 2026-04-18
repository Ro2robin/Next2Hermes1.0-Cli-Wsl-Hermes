# Implementation inspection notes for `~/ai-workflow`

Source folders inspected:
- `bin/`
- `logs/`
- `tmp/`

## Files observed

### `bin/`
- `build_copilot_prompt.sh`
- `run_copilot_main.sh`
- `run_codex_task.sh`
- `parse_agent_result.py`
- `hermes_copilot_workflow.md`
- `hermes_skill_manual.md`
- `hermes_copilot_workflow.md:Zone.Identifier`
- `hermes_skill_manual.md:Zone.Identifier`

### `logs/`
- empty at inspection time

### `tmp/`
- `copilot_task.md`

## What the implementation already does well

1. Copilot path is wrapped behind a fixed script.
2. Prompt generation is separated into `build_copilot_prompt.sh`.
3. Copilot runs are timestamped and logged.
4. The parser script provides a simple structured extraction path.
5. Repository `.git` checks already exist in both wrappers.

## Gaps between docs and code

1. The markdown docs describe retry/fallback orchestration, but the wrapper scripts alone do not implement it.
2. `run_codex_task.sh` now writes timestamped output filenames itself.
3. The Codex wrapper can honor `AI_WORKFLOW_HOME` for testability and alternate workflow roots.
4. The parser is strict and depends on exact section headers.
5. There is no dedicated wrapper that manages the full decision loop end-to-end.
   - This gap was later addressed by `run_agent_orchestrator.sh`.

## Notes on non-workflow files

- `*:Zone.Identifier` files are Windows metadata artifacts.
- `tmp/copilot_task.md` appears to be a sample or manually prepared prompt rather than a runtime artifact from the current builder.

## Suggested next iteration

If this workflow is expanded later, a higher-level orchestrator script could:
1. normalize inputs
2. run Copilot
3. validate structured output
4. retry once if needed
5. fall back to Codex when policy allows
6. rename fallback outputs with timestamps for audit retention
