# Contributing

感谢你改进这个仓库。

## 适用范围

本项目主要包含 shell / Python wrapper 与测试脚本。目标是保持行为稳定、输出结构稳定、回归成本低。

## 开发前提

- Linux / WSL 环境
- `bash`、`python3`、`git`

## 推荐流程

1. 新建分支

```bash
git checkout -b feat/your-change
```

2. 修改代码或文档

3. 运行本地回归检查

```bash
scripts/ci_check.sh
```

4. 提交

```bash
git add -A
git commit -m "feat: your concise summary"
```

5. 推送并发起 PR

```bash
git push -u origin HEAD
```

## 提交信息建议

建议使用 Conventional Commits：

- `feat:` 新功能
- `fix:` 缺陷修复
- `docs:` 文档更新
- `test:` 测试相关
- `chore:` 杂项维护

## 质量要求

- 不要破坏既有输出协议（例如 orchestrator 的 key=value 字段）。
- 新增行为优先补测试，再补实现。
- 若改动影响 README / SKILL，请同步更新文档。

## 安全与隐私

- 不要提交 token、密钥、个人敏感信息。
- `tmp/`、`logs/`、本地虚拟环境目录不应进入版本库。
