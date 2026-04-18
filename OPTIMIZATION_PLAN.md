# 项目优化清单（v1）

目标：让仓库从“可用”提升到“可维护、可协作、可持续发布”。

## 优先级 A（本次落地）

- [x] A1. 增加 GitHub Actions CI，自动运行回归测试
- [x] A2. 提供统一本地检查脚本，降低协作门槛
- [x] A3. 强化 `.gitignore`，避免 `tmp/`、`logs/`、虚拟环境等噪音文件进入版本库
- [x] A4. README 增加状态徽章与快速链接（Release / CI / License）
- [x] A5. 增加贡献说明文档（提交流程、验证步骤、提交规范）

## 优先级 B（建议后续）

- [ ] B1. 发布 issue / PR 模板，统一问题描述与变更说明
- [ ] B2. 增加 `CHANGELOG.md` 并约定版本发布流程
- [ ] B3. 对关键 shell 脚本接入 `shellcheck`（若团队环境可用）
- [ ] B4. 增加更真实的端到端样例（含 mock 仓库）

## 验收标准

1. `scripts/ci_check.sh` 在本地可通过。
2. CI 在 `main` push / PR 时自动触发并执行同一套回归脚本。
3. 关键文档齐全：README、OPTIMIZATION_PLAN、CONTRIBUTING。
4. 当前改动已推送到远端主分支。
