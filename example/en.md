# Examples (English)

This directory contains a few practical ways to test and use the skill.

## 1. Natural-language usage through Hermes

You can simply say to Hermes:

```text
In ~/code/myrepo, investigate the login failure, apply the minimal necessary fix, and run the most relevant tests. Prefer Copilot, but allow fallback to Codex if needed. Give me a clean Chinese conclusion and do not paste raw logs.
```

Analysis only, no edits:

```text
In ~/code/myrepo, analyze the root cause of the user registration error. Do not modify files. Prefer Copilot, and allow fallback if needed. Give me the conclusion, risks, and next-step suggestions.
```

Copilot only:

```text
In ~/code/myrepo, review the current changes using Copilot only. Do not fall back to Codex. Give me the conclusion.
```

## 2. Use the one-key script directly

Prepare a request file first:

```bash
cat > ~/ai-workflow/tmp/user_request.txt <<'EOF'
Please inspect the login failure in the current repository, apply the minimal necessary fix, and run the most relevant validation command.
EOF
```

Then run:

```bash
~/ai-workflow/bin/run_workflow_reply.sh ~/code/myrepo fix ~/ai-workflow/tmp/user_request.txt auto allow gpt-5.4
```

## 3. Get JSON output

```bash
~/ai-workflow/bin/run_workflow_reply.sh --json ~/code/myrepo fix ~/ai-workflow/tmp/user_request.txt auto allow gpt-5.4
```

This returns fields such as:
- `reply`
- `status`
- `task_type`
- `executor_used`
- `reason`
- `summary`
- `root_cause`
- `changed_files`
- `test_result`
- plus related output paths

## 4. Common task types

- `analyze`: read-only analysis
- `fix`: minimal necessary fix
- `implement`: new feature work
- `review`: review current changes only
