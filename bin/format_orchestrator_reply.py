#!/usr/bin/env python3
import json
import pathlib
import sys


def load_key_values(path: pathlib.Path) -> dict[str, str]:
    data: dict[str, str] = {}
    for raw_line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = raw_line.strip()
        if not line or "=" not in line:
            continue
        key, value = line.split("=", 1)
        data[key] = value
    return data


def load_json(path_str: str | None) -> dict:
    if not path_str:
        return {}
    path = pathlib.Path(path_str)
    if not path.is_file():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8", errors="replace"))
    except Exception:
        return {}


def format_task_judgment(task_type: str, executor: str, fallback_occurred: str) -> str:
    task_type = task_type or "unknown"
    executor = executor or "unknown"
    if fallback_occurred == "1" and executor not in {"", "none", "unknown"}:
        return f"任务判断：{task_type}（由 {executor} 完成，Copilot 已回退）"
    if executor not in {"", "none", "unknown"}:
        return f"任务判断：{task_type}（由 {executor} 完成）"
    return f"任务判断：{task_type}"


def failure_explanation(reason: str) -> str:
    mapping = {
        "dependency_missing": "工作流缺少必要依赖文件。",
        "repo_dir_missing": "指定的仓库目录不存在。",
        "repo_not_git": "指定目录不是 Git 仓库。",
        "user_request_missing": "用户请求文件不存在。",
        "invalid_task_type": "任务类型不受支持。",
        "invalid_fallback_mode": "fallback 模式配置无效。",
        "copilot_timeout": "主执行器 Copilot 已超时。",
        "copilot_output_invalid": "Copilot 已运行，但返回结果无法按预期结构解析。",
        "copilot_execution_failed": "Copilot 执行过程中直接失败。",
        "copilot_output_missing": "Copilot 没有产出可读取的结果文件。",
        "codex_timeout": "备用执行器 Codex 已超时。",
        "codex_output_invalid": "备用执行器已运行，但返回结果无法按预期结构解析。",
        "codex_execution_failed": "Codex 执行过程中直接失败。",
        "codex_output_missing": "Codex 没有产出可读取的结果文件。",
    }
    return mapping.get(reason, "执行失败，但未识别到更具体的原因。")


def failure_suggestion(reason: str) -> str:
    mapping = {
        "dependency_missing": "先补齐缺失脚本或解析器，再重新执行工作流。",
        "repo_dir_missing": "检查 repo_dir 是否正确，并确认路径在当前环境中可访问。",
        "repo_not_git": "确认目标目录包含 .git，或先在正确仓库目录下执行。",
        "user_request_missing": "重新生成 user_request 文件，再重试。",
        "invalid_task_type": "将任务类型限定为 analyze/fix/implement/review 之一。",
        "invalid_fallback_mode": "将 fallback_mode 改为 allow 或 no-fallback。",
        "copilot_timeout": "可以缩小任务范围、降低单次工作量，或允许 fallback 到 Codex。",
        "copilot_output_invalid": "检查 FINAL_MESSAGE_FILE 的原始输出，并确认 SUMMARY/ROOT_CAUSE 等固定段落标题是否完整。",
        "copilot_execution_failed": "检查 Copilot 的日志输出与权限配置，确认命令本身能正常执行。",
        "copilot_output_missing": "检查 Copilot wrapper 是否正常输出 FINAL_MESSAGE_FILE。",
        "codex_timeout": "缩小 fallback 任务范围，或检查 Codex 当前执行环境是否异常缓慢。",
        "codex_output_invalid": "检查 FINAL_MESSAGE_FILE 的原始输出，并确认 SUMMARY/ROOT_CAUSE 等固定段落标题是否完整。",
        "codex_execution_failed": "检查 Codex 的日志输出、模型配置和当前仓库状态。",
        "codex_output_missing": "检查 Codex wrapper 是否正常输出 FINAL_MESSAGE_FILE。",
    }
    return mapping.get(reason, "查看 ORCHESTRATOR_LOG 与原始输出文件，进一步定位失败原因。")


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: format_orchestrator_reply.py <orchestrator_output_file>", file=sys.stderr)
        return 2

    source = pathlib.Path(sys.argv[1])
    fields = load_key_values(source)

    status = fields.get("STATUS", "")
    task_type = fields.get("TASK_TYPE", "unknown")
    executor = fields.get("EXECUTOR_USED", "unknown")
    fallback = fields.get("FALLBACK_OCCURRED", "0")
    reason = fields.get("REASON", "")
    parsed = load_json(fields.get("PARSED_JSON_FILE"))

    lines: list[str] = []
    if status == "success":
        lines.append(format_task_judgment(task_type, executor, fallback))
        lines.append("执行状态：成功")
        summary = (parsed.get("summary") or "").strip()
        root_cause = (parsed.get("root_cause") or "").strip()
        changed_files = (parsed.get("changed_files") or "").strip()
        test_result = (parsed.get("test_result") or "").strip()
        risks = (parsed.get("risks") or "").strip()
        next_step = (parsed.get("next_step") or "").strip()

        if summary:
            lines.append(f"任务概览：{summary}")
        if root_cause:
            lines.append(f"根因：{root_cause}")
        if changed_files:
            lines.append(f"修改内容：{changed_files}")
        if test_result:
            lines.append(f"验证情况：{test_result}")
        if risks:
            lines.append(f"风险点：{risks}")
        if next_step:
            lines.append(f"下一步建议：{next_step}")
    else:
        lines.append("任务判断：执行失败")
        lines.append(f"执行状态：失败（{reason or 'unknown'}）")
        lines.append(f"失败说明：{failure_explanation(reason)}")
        if reason == "dependency_missing" and fields.get("MISSING_DEPENDENCY"):
            lines.append(f"缺失依赖：{fields['MISSING_DEPENDENCY']}")
        lines.append(f"建议：{failure_suggestion(reason)}")

    print("\n".join(lines))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
