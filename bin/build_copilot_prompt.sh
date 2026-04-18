#!/usr/bin/env bash
set -euo pipefail

TASK_TYPE="${1:?usage: build_copilot_prompt.sh <task_type> <user_request_file> <output_prompt_file>}"
USER_REQ_FILE="${2:?usage: build_copilot_prompt.sh <task_type> <user_request_file> <output_prompt_file>}"
OUT_FILE="${3:?usage: build_copilot_prompt.sh <task_type> <user_request_file> <output_prompt_file>}"

USER_REQ="$(cat "$USER_REQ_FILE")"

case "$TASK_TYPE" in
  analyze)
    MODE_RULES=$'你只做分析，不修改文件。\n除非绝对必要，不运行耗时命令。\n'
    ;;
  fix)
    MODE_RULES=$'你可以做最小必要修改。\n你可以运行最相关的验证命令。\n'
    ;;
  implement)
    MODE_RULES=$'你可以新增或修改必要文件。\n你可以运行最相关的验证命令。\n'
    ;;
  review)
    MODE_RULES=$'你只审查现有代码和改动，不修改文件。\n'
    ;;
  *)
    echo "Unknown task_type: $TASK_TYPE" >&2
    exit 2
    ;;
esac

cat > "$OUT_FILE" <<PROMPT
你在一个真实项目仓库中工作。

任务类型：
$TASK_TYPE

用户请求：
$USER_REQ

工作要求：
1. 先理解问题和上下文
2. 再决定是否需要查看文件、运行命令、修改代码
3. 只做与当前任务直接相关的操作
4. 最终只输出下面结构，不要输出额外前言

SUMMARY:
ROOT_CAUSE:
CHANGED_FILES:
COMMANDS_RUN:
TEST_RESULT:
RISKS:
NEXT_STEP:

模式限制：
$MODE_RULES

全局约束：
- 不要推送代码
- 不要访问无关外部资源
- 不要修改无关文件
- 如果不确定，明确写出不确定点
PROMPT
