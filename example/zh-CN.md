# 示例（简体中文）

这个目录提供一些最常见的使用方式，方便你快速测试这个 skill。

## 1. 让 Hermes 直接使用自然语言

你可以直接对 Hermes 说：

```text
在 ~/code/myrepo 里检查登录失败问题，做最小必要修复并运行最相关测试。优先用 Copilot，必要时允许 fallback 到 Codex。最后直接给我中文结论，不要贴原始日志。
```

如果只是分析、不改代码：

```text
在 ~/code/myrepo 里分析用户注册时报错的根因，不要修改文件。优先用 Copilot，必要时允许 fallback。最后给我结论、风险和下一步建议。
```

如果你只想用 Copilot：

```text
在 ~/code/myrepo 里 review 当前改动，只用 Copilot，不要 fallback 到 Codex。最后给我结论。
```

## 2. 直接使用 one-key 脚本

先准备请求文件：

```bash
cat > ~/ai-workflow/tmp/user_request.txt <<'EOF'
请检查当前仓库中的登录失败问题，做最小必要修改，并运行最相关的验证命令。
EOF
```

然后运行：

```bash
~/ai-workflow/bin/run_workflow_reply.sh ~/code/myrepo fix ~/ai-workflow/tmp/user_request.txt auto allow gpt-5.4
```

## 3. 拿 JSON 结果

```bash
~/ai-workflow/bin/run_workflow_reply.sh --json ~/code/myrepo fix ~/ai-workflow/tmp/user_request.txt auto allow gpt-5.4
```

这会返回：
- `reply`
- `status`
- `task_type`
- `executor_used`
- `reason`
- `summary`
- `root_cause`
- `changed_files`
- `test_result`
- 以及相关输出路径

## 4. 常见 task_type

- `analyze`：只分析，不改文件
- `fix`：最小必要修复
- `implement`：实现新功能
- `review`：只审查当前改动
