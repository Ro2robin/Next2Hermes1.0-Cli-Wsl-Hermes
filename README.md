# WSL Copilot Primary Workflow

简体中文 | English | 日本語

---

## 简体中文

这是一个面向 Hermes / CLI agent 的 WSL 原生工作流项目。

它的核心目标是：
- 以 GitHub Copilot CLI 作为主执行器
- 以 Codex CLI 作为备用执行器
- 使用固定 wrapper、结构化结果和稳定的用户回复格式
- 在 WSL 环境中完成 analyze / fix / implement / review 类任务

这个仓库包含：
- 可直接加载的 `SKILL.md`
- 一组可运行的 shell / Python wrapper
- 一个 one-key 入口 `bin/run_workflow_reply.sh`
- 多个回归测试脚本
- 示例说明文档

### 适用场景

适合以下需求：
- 想在 WSL 中稳定编排 Copilot CLI 与 Codex CLI
- 想让 Hermes / agent 根据任务类型自动重试、fallback、格式化答复
- 想把“执行器输出”转换成可直接发给用户的中文结果
- 想要一个既可文本输出、又可 JSON 输出的统一入口

### 主要特性

- Copilot primary / Codex fallback
- 支持 `analyze / fix / implement / review`
- 结构化失败原因分类
- one-key 入口脚本
- `--json` 模式，直接返回 reply + metadata + parsed 字段
- MIT License

### 仓库结构

```text
SKILL.md                     # 可直接加载的 Hermes skill
README.md                    # 项目说明（中 / 英 / 日）
LICENSE                      # MIT License
bin/                         # 工作流脚本
tests/                       # 回归测试
example/                     # 使用示例（中 / 英）
references/                  # 补充说明文档
```

### 快速开始

1. 根据你的实际环境，把脚本放到合适目录（默认文档假设 `~/ai-workflow`）。
2. 确保以下工具已可用：
   - `copilot`
   - `codex`
   - `python3`
   - `git`
3. 准备一个 Git 仓库路径和用户请求文件。
4. 运行 one-key 入口：

```bash
~/ai-workflow/bin/run_workflow_reply.sh ~/code/myrepo fix ~/ai-workflow/tmp/user_request.txt auto allow gpt-5.4
```

5. 如果想拿结构化结果：

```bash
~/ai-workflow/bin/run_workflow_reply.sh --json ~/code/myrepo fix ~/ai-workflow/tmp/user_request.txt auto allow gpt-5.4
```

### 你会得到什么

默认模式：
- 最终中文答复

JSON 模式：
- `reply`
- `status`
- `task_type`
- `executor_used`
- `reason`
- `summary`
- `root_cause`
- `changed_files`
- `test_result`
- 以及相关输出文件路径

### 注意

这个 skill 默认假设在 WSL 内运行，并且偏向以下目录约定：
- 工作流目录：`~/ai-workflow`
- 仓库目录：`~/code/<repo>`

如果你的环境不同，可以按自己的目录结构调整脚本或环境变量。

---

## English

This repository provides a WSL-native workflow for Hermes / CLI agents.

Its main goal is to:
- use GitHub Copilot CLI as the primary executor
- use Codex CLI as the fallback executor
- keep execution grounded through fixed wrappers and structured outputs
- turn workflow output into stable user-facing replies

This repository includes:
- a loadable `SKILL.md`
- runnable shell / Python wrappers
- a one-key entrypoint: `bin/run_workflow_reply.sh`
- regression tests
- usage examples

### Good fit for

Use this project if you want to:
- orchestrate Copilot CLI and Codex CLI reliably inside WSL
- classify tasks as analyze / fix / implement / review
- retry Copilot, fall back to Codex, and format the final response
- expose both a text interface and a JSON interface to higher-level agents

### Key features

- Copilot primary / Codex fallback
- task routing: `analyze / fix / implement / review`
- structured failure reasons
- one-key entrypoint script
- `--json` mode returning reply + metadata + parsed fields
- MIT License

### Repository layout

```text
SKILL.md                     # loadable Hermes skill
README.md                    # project introduction (ZH / EN / JA)
LICENSE                      # MIT License
bin/                         # workflow scripts
tests/                       # regression tests
example/                     # usage examples (ZH / EN)
references/                  # supporting notes
```

### Quick start

1. Put the scripts in the path layout you want to use (the default docs assume `~/ai-workflow`).
2. Make sure these commands are available:
   - `copilot`
   - `codex`
   - `python3`
   - `git`
3. Prepare a Git repository path and a user request file.
4. Run the one-key entrypoint:

```bash
~/ai-workflow/bin/run_workflow_reply.sh ~/code/myrepo fix ~/ai-workflow/tmp/user_request.txt auto allow gpt-5.4
```

5. If you want structured output:

```bash
~/ai-workflow/bin/run_workflow_reply.sh --json ~/code/myrepo fix ~/ai-workflow/tmp/user_request.txt auto allow gpt-5.4
```

### Output

Default mode:
- final Chinese user-facing reply

JSON mode:
- `reply`
- `status`
- `task_type`
- `executor_used`
- `reason`
- `summary`
- `root_cause`
- `changed_files`
- `test_result`
- plus related output-file paths

### Notes

This skill is designed for WSL-first usage and assumes these conventions by default:
- workflow directory: `~/ai-workflow`
- repo directory: `~/code/<repo>`

If your environment differs, adjust paths or environment variables accordingly.

---

## 日本語

このリポジトリは、Hermes / CLI エージェント向けの WSL ネイティブなワークフローを提供します。

主な目的は次のとおりです。
- GitHub Copilot CLI を主実行器として使う
- Codex CLI をフォールバック実行器として使う
- 固定 wrapper と構造化出力で安定した実行フローを作る
- 実行結果を、そのままユーザーに返せる安定した返答に変換する

このリポジトリには以下が含まれます。
- 読み込み可能な `SKILL.md`
- 実行可能な shell / Python wrapper
- one-key エントリーポイント `bin/run_workflow_reply.sh`
- 回帰テスト
- 使用例ドキュメント

### 主な特長

- Copilot primary / Codex fallback
- `analyze / fix / implement / review` のタスク分類
- 構造化された失敗理由
- one-key エントリースクリプト
- `--json` モードで reply + metadata + parsed fields を返す
- MIT License

### クイックスタート

```bash
~/ai-workflow/bin/run_workflow_reply.sh ~/code/myrepo fix ~/ai-workflow/tmp/user_request.txt auto allow gpt-5.4
```

JSON が必要な場合:

```bash
~/ai-workflow/bin/run_workflow_reply.sh --json ~/code/myrepo fix ~/ai-workflow/tmp/user_request.txt auto allow gpt-5.4
```

### 補足

デフォルトでは以下のディレクトリ規約を想定しています。
- ワークフローディレクトリ: `~/ai-workflow`
- リポジトリディレクトリ: `~/code/<repo>`

必要に応じて環境に合わせて調整してください。
