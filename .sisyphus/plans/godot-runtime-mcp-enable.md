# Godot Runtime MCP 启用实施计划

## TL;DR
> **Summary**: 在不扩展到 EditorPlugin/GDExtension 的前提下，为当前 Godot 4.6 项目接入 `godot-mcp-runtime` 的最小可复现链路，覆盖环境校验、启动配置、健康检查、失败路径和 CI 证据归档。  
> **Deliverables**:
> - MCP 启用配置模板与运行脚本（含本地/CI）
> - `smoke_runner` 最小 MCP 健康检查任务
> - 失败路径断言与统一错误码输出
> - CI 任务与 artifact 证据归档
> - 运维/开发文档（不含密钥）
> **Effort**: Short  
> **Parallel**: YES - 3 waves  
> **Critical Path**: 1 → 2 → 4 → 7 → 8

## Context
### Original Request
当前项目是否能够启用 godot-runtime-mcp，并要求生成可执行计划。

### Interview Summary
- 已确认项目是 Godot 4.6，具备成熟的 headless CLI 运行入口。
- 已确认仓库缺少 `addons/plugin.cfg/export_presets.cfg`，因此不采用插件化重构路线。
- 目标是“最小可行启用 + 可复现验证 + CI 可判定”，而非大规模架构改造。

### Metis Review (gaps addressed)
- 加入范围防膨胀护栏：本次不做 EditorPlugin/GDExtension/导出流程重构。
- 固化 `.mcp` 忽略导致的共享策略：使用 `.mcp.example` + 脚本复制，不提交真实凭据。
- 增加失败路径断言：必须有固定错误字符串与非零退出码。
- 所有验证改为“命令 + 输出关键字 + 证据文件路径”的自动化形式。

## Work Objectives
### Core Objective
让执行代理在当前仓库中完成 godot-runtime-mcp 的最小启用链路，并通过自动化命令证明“可连通、可失败、可复现”。

### Deliverables
1. 环境与版本检查脚本（Godot/Node/godot-mcp-runtime）。
2. MCP 配置模板（无密钥）与本地启动脚本。
3. `scripts/dev/smoke_runner.gd` MCP 健康检查任务（仅 health/ping）。
4. 失败场景断言（runtime 缺失、端口冲突、初始化超时）。
5. CI job + evidence artifact 归档。
6. README/运行文档（中文）。

### Definition of Done (verifiable conditions with commands)
- `godot --version` 输出包含 `4.6`，退出码为 0。
- `node --version` 主版本 `>=18`。
- MCP 健康检查命令退出码为 0 且输出 `MCP_HEALTH_OK`。
- 故障注入命令退出码非 0 且输出预期错误码文本（如 `MCP_RUNTIME_NOT_FOUND`）。
- CI 上传 `.sisyphus/evidence/godot-runtime-mcp/*.log` artifact。

### Must Have
- 不提交 `.mcp` 真配置，改为模板化。
- 所有任务均包含 happy/edge QA 场景。
- 验证全过程无需人工点击 Godot 编辑器。

### Must NOT Have (guardrails, AI slop patterns, scope boundaries)
- 不新增 EditorPlugin、不开发 GDExtension。
- 不改动游戏主玩法逻辑与资源结构。
- 不使用“目测通过”“手工点按钮”作为验收条件。
- 不把密钥/token 写入仓库。

## Verification Strategy
> ZERO HUMAN INTERVENTION - all verification is agent-executed.
- Test decision: tests-after（基于现有 Godot headless smoke + Bash）
- QA policy: 每个任务必须包含 happy + failure 两类场景
- Evidence: `.sisyphus/evidence/task-{N}-{slug}.{ext}`

## Execution Strategy
### Parallel Execution Waves
> Target: 5-8 tasks per wave. <3 per wave (except final) = under-splitting.

Wave 1（基础探测与规范）: #1 #2 #3  
Wave 2（接入与验证）: #4 #5 #6  
Wave 3（CI与文档固化）: #7 #8

### Dependency Matrix (full, all tasks)
- #1 → #2, #4
- #2 → #4, #5, #7
- #3 → #8
- #4 → #5, #7
- #5 → #7
- #6 → #7
- #7 → #8

### Agent Dispatch Summary (wave → task count → categories)
- Wave 1 → 3 tasks → quick / unspecified-low
- Wave 2 → 3 tasks → quick / unspecified-high
- Wave 3 → 2 tasks → writing / quick

## TODOs
> Implementation + Test = ONE task. Never separate.

- [ ] 1. 建立环境基线探测脚本

  **What to do**:
  - 新增 `scripts/dev/check_mcp_env.sh`（或等价脚本）用于检查 Godot、Node、npx、godot-mcp-runtime 可用性。
  - 输出固定前缀日志：`MCP_ENV_OK` / `MCP_ENV_FAIL:<reason>`。
  - 将执行结果写入 `.sisyphus/evidence/task-1-mcp-env.log`。
  **Must NOT do**:
  - 不修改现有游戏逻辑脚本。

  **Recommended Agent Profile**:
  - Category: `quick` - Reason: 单文件脚本与命令校验。
  - Skills: `[]` - 不需要额外技能。
  - Omitted: `godot4-plugin-csharp-gdextension` - 本任务无原生扩展。

  **Parallelization**: Can Parallel: YES | Wave 1 | Blocks: #2 #4 | Blocked By: none

  **References**:
  - Pattern: `scripts/dev/smoke_runner.gd:72-106` - CLI 参数解析与失败输出风格。
  - Pattern: `.sisyphus/evidence/task-12-e2e-regression.txt` - 现有 headless 命令格式。
  - External: `https://github.com/Erodenn/godot-mcp-runtime` - runtime 安装与调用方式。

  **Acceptance Criteria**:
  - [ ] `bash scripts/dev/check_mcp_env.sh` 退出码 0，输出包含 `MCP_ENV_OK`。
  - [ ] 证据文件存在：`.sisyphus/evidence/task-1-mcp-env.log`。

  **QA Scenarios**:
  ```
  Scenario: Happy path 环境满足
    Tool: Bash
    Steps: 运行 `bash scripts/dev/check_mcp_env.sh | tee .sisyphus/evidence/task-1-mcp-env.log`
    Expected: 日志含 `MCP_ENV_OK`，并列出 Godot 4.6 与 Node>=18
    Evidence: .sisyphus/evidence/task-1-mcp-env.log

  Scenario: Failure - Node 不满足
    Tool: Bash
    Steps: 用临时 PATH 屏蔽 node 后执行脚本
    Expected: 非零退出，日志含 `MCP_ENV_FAIL:NODE_MISSING_OR_TOO_OLD`
    Evidence: .sisyphus/evidence/task-1-mcp-env-error.log
  ```

  **Commit**: YES | Message: `chore(mcp): 添加运行环境探测脚本` | Files: `scripts/dev/check_mcp_env.sh`

- [ ] 2. 落地 MCP 配置模板与启动入口

  **What to do**:
  - 新增 `.mcp.example`，定义 `godot-mcp-runtime` 的最小配置（无密钥）。
  - 新增 `scripts/dev/run_mcp_runtime.sh`，按模板启动 runtime 并打印连接信息。
  - 约定端口与超时默认值（如 `MCP_BRIDGE_PORT=9900`，可覆写）。
  **Must NOT do**:
  - 不提交 `.mcp` 真实配置。

  **Recommended Agent Profile**:
  - Category: `quick` - Reason: 配置模板 + 启动脚本。
  - Skills: `[]`
  - Omitted: `godot4-feature-dev` - 非玩法开发。

  **Parallelization**: Can Parallel: YES | Wave 1 | Blocks: #4 #5 #7 | Blocked By: #1

  **References**:
  - Pattern: `.gitignore:1-2` - `.mcp` 已被忽略，必须模板化共享。
  - External: `https://www.npmjs.com/package/godot-mcp-runtime` - 命令参数与版本。

  **Acceptance Criteria**:
  - [ ] `.mcp.example` 存在并可被脚本消费。
  - [ ] `bash scripts/dev/run_mcp_runtime.sh --dry-run` 退出码 0。

  **QA Scenarios**:
  ```
  Scenario: Happy path 模板可加载
    Tool: Bash
    Steps: 执行 `bash scripts/dev/run_mcp_runtime.sh --dry-run | tee .sisyphus/evidence/task-2-mcp-template.log`
    Expected: 输出包含 `MCP_RUNTIME_CONFIG_OK`
    Evidence: .sisyphus/evidence/task-2-mcp-template.log

  Scenario: Failure - 模板缺失字段
    Tool: Bash
    Steps: 构造缺失 command 字段的临时模板并运行
    Expected: 非零退出，输出 `MCP_RUNTIME_CONFIG_INVALID`
    Evidence: .sisyphus/evidence/task-2-mcp-template-error.log
  ```

  **Commit**: YES | Message: `chore(mcp): 增加配置模板与运行脚本` | Files: `.mcp.example`, `scripts/dev/run_mcp_runtime.sh`

- [ ] 3. 统一 MCP 日志与错误码规范

  **What to do**:
  - 定义错误码清单（`MCP_RUNTIME_NOT_FOUND`、`MCP_PORT_CONFLICT`、`MCP_INIT_TIMEOUT`、`MCP_HEALTH_OK`）。
  - 在文档中写明每个错误码触发条件与处理建议。
  **Must NOT do**:
  - 不引入“自由文本错误描述”作为唯一判定依据。

  **Recommended Agent Profile**:
  - Category: `writing` - Reason: 规范文档与可机读错误码定义。
  - Skills: `[]`
  - Omitted: `unspecified-high` - 不需高复杂编码。

  **Parallelization**: Can Parallel: YES | Wave 1 | Blocks: #8 | Blocked By: none

  **References**:
  - Pattern: `scripts/dev/smoke_runner.gd:104-105` - 既有错误输出风格（固定中文+退出码）。

  **Acceptance Criteria**:
  - [ ] 文档包含错误码表与机器可断言字符串。
  - [ ] 任一错误码可映射到具体修复动作。

  **QA Scenarios**:
  ```
  Scenario: Happy path 规范完整
    Tool: Bash
    Steps: grep 文档检查 4 个必需错误码均存在
    Expected: 命令退出码 0
    Evidence: .sisyphus/evidence/task-3-mcp-errorcode.log

  Scenario: Failure - 缺失关键错误码
    Tool: Bash
    Steps: 删除临时副本中 `MCP_INIT_TIMEOUT` 后跑校验脚本
    Expected: 非零退出并提示缺失项
    Evidence: .sisyphus/evidence/task-3-mcp-errorcode-error.log
  ```

  **Commit**: YES | Message: `docs(mcp): 统一错误码与日志规范` | Files: `README.md`（或等价文档路径）

- [ ] 4. 在 smoke_runner 增加 mcp_health 任务

  **What to do**:
  - 在 `scripts/dev/smoke_runner.gd` 新增 `task=mcp_health` 分支。
  - 实现最小健康检查：验证 runtime 可达，并输出 `MCP_HEALTH_OK`。
  - 健康检查不得耦合业务事件推进。
  **Must NOT do**:
  - 不改变现有 `boot/resources/day_tick/task7...` 行为。

  **Recommended Agent Profile**:
  - Category: `unspecified-high` - Reason: GDScript 逻辑改动且需兼容既有任务。
  - Skills: [`godot4-feature-dev`] - 保障 Godot 4.6 语法与场景运行模式。
  - Omitted: [`godot4-plugin-csharp-gdextension`] - 非插件/原生扩展。

  **Parallelization**: Can Parallel: NO | Wave 2 | Blocks: #5 #7 | Blocked By: #1 #2

  **References**:
  - Pattern: `scripts/dev/smoke_runner.gd:72-103` - 任务分派结构。
  - Pattern: `scripts/dev/smoke_runner.gd:526-552` - 参数解析规范。
  - API/Type: `project.godot:17-24` - Autoload 服务清单。

  **Acceptance Criteria**:
  - [ ] `godot --headless --path . --script scripts/dev/smoke_runner.gd -- --task=mcp_health` 返回 0。
  - [ ] 输出包含 `MCP_HEALTH_OK`。

  **QA Scenarios**:
  ```
  Scenario: Happy path MCP 可达
    Tool: Bash
    Steps: 先启动 runtime，再执行 mcp_health 命令并 tee 到日志
    Expected: 退出码 0，日志含 `MCP_HEALTH_OK`
    Evidence: .sisyphus/evidence/task-4-mcp-health.log

  Scenario: Failure - runtime 未启动
    Tool: Bash
    Steps: 不启动 runtime 直接执行 mcp_health
    Expected: 非零退出，日志含 `MCP_RUNTIME_NOT_FOUND`
    Evidence: .sisyphus/evidence/task-4-mcp-health-error.log
  ```

  **Commit**: YES | Message: `feat(smoke): 增加mcp健康检查任务` | Files: `scripts/dev/smoke_runner.gd`

- [ ] 5. 增加端口冲突与超时保护

  **What to do**:
  - 在 runtime 启动与健康检查流程中加入端口冲突检测、初始化超时控制。
  - 明确输出 `MCP_PORT_CONFLICT`、`MCP_INIT_TIMEOUT`。
  **Must NOT do**:
  - 不用无限等待/阻塞主流程。

  **Recommended Agent Profile**:
  - Category: `unspecified-high` - Reason: 涉及进程与网络异常路径处理。
  - Skills: [`godot4-feature-dev`] - 保证 Godot 端时序正确。
  - Omitted: [`writing`] - 不只是文档修改。

  **Parallelization**: Can Parallel: NO | Wave 2 | Blocks: #7 | Blocked By: #2 #4

  **References**:
  - Pattern: `scripts/game_root.gd:156-177` - 已有计时器/节拍机制，可参考超时策略。
  - External: `https://github.com/Erodenn/godot-mcp-runtime` - runtime 初始化行为说明。

  **Acceptance Criteria**:
  - [ ] 端口占用时返回非零且打印 `MCP_PORT_CONFLICT`。
  - [ ] 超时场景返回非零且打印 `MCP_INIT_TIMEOUT`。

  **QA Scenarios**:
  ```
  Scenario: Happy path 无冲突快速初始化
    Tool: Bash
    Steps: 正常启动 runtime + mcp_health
    Expected: 退出码 0，初始化耗时 <= 设定阈值
    Evidence: .sisyphus/evidence/task-5-timeout-guard.log

  Scenario: Failure - 端口冲突
    Tool: Bash
    Steps: 先用 nc 占用端口，再启动 runtime/health
    Expected: 非零退出，日志含 `MCP_PORT_CONFLICT`
    Evidence: .sisyphus/evidence/task-5-timeout-guard-error.log
  ```

  **Commit**: YES | Message: `fix(mcp): 增加端口冲突与超时保护` | Files: `scripts/dev/run_mcp_runtime.sh`, `scripts/dev/smoke_runner.gd`

- [ ] 6. 约束 autoload 接入边界（可选接入点）

  **What to do**:
  - 仅在需要时新增轻量 `autoload/mcp_service.gd`（或等效入口），用于桥接健康检查，不接入业务命令。
  - 明确初始化顺序与失败策略（默认 fail-fast 用于 CI）。
  **Must NOT do**:
  - 不接入角色/事件等业务写操作。

  **Recommended Agent Profile**:
  - Category: `unspecified-high` - Reason: 涉及启动顺序与单例生命周期。
  - Skills: [`godot4-feature-dev`]
  - Omitted: [`godot4-architecture`] - 本次不是全局重构。

  **Parallelization**: Can Parallel: YES | Wave 2 | Blocks: #7 | Blocked By: #4

  **References**:
  - API/Type: `project.godot:17-24` - Autoload 配置入口。
  - Pattern: `scripts/game_root.gd:126-139` - 单例绑定方式。

  **Acceptance Criteria**:
  - [ ] 新增 autoload（如采用）后，`boot` 与 `day_tick` 既有任务仍通过。
  - [ ] 无业务逻辑回归。

  **QA Scenarios**:
  ```
  Scenario: Happy path autoload 不影响现有任务
    Tool: Bash
    Steps: 依次运行 boot 与 day_tick smoke
    Expected: 均退出码 0
    Evidence: .sisyphus/evidence/task-6-autoload-compat.log

  Scenario: Failure - 初始化失败
    Tool: Bash
    Steps: 注入错误配置触发 mcp_service 初始化失败
    Expected: 非零退出并输出约定错误码
    Evidence: .sisyphus/evidence/task-6-autoload-compat-error.log
  ```

  **Commit**: YES | Message: `feat(mcp): 增加autoload桥接服务` | Files: `autoload/mcp_service.gd`, `project.godot`（如需）

- [ ] 7. CI 接入 mcp 启用验证并归档证据

  **What to do**:
  - 在现有 CI 中新增 mcp runtime 验证 job（Linux headless）。
  - 执行 #1/#4/#5 关键命令并上传 evidence 日志 artifact。
  - 失败时在摘要中输出失败错误码。
  **Must NOT do**:
  - 不依赖人工 rerun 才能通过。

  **Recommended Agent Profile**:
  - Category: `quick` - Reason: CI 配置与命令编排。
  - Skills: [`git-master`] - 规范化仓库工作流（可选）。
  - Omitted: [`playwright`] - 非浏览器任务。

  **Parallelization**: Can Parallel: NO | Wave 3 | Blocks: #8 | Blocked By: #2 #4 #5 #6

  **References**:
  - Pattern: `.sisyphus/evidence/task-12-e2e-regression.txt` - 既有自动化证据风格。

  **Acceptance Criteria**:
  - [ ] CI job 成功时 artifact 包含 `task-1/4/5` 对应日志。
  - [ ] CI job 失败时能从日志提取标准错误码。

  **QA Scenarios**:
  ```
  Scenario: Happy path CI 全链路通过
    Tool: Bash
    Steps: 本地模拟执行 CI 命令序列
    Expected: 返回 0，证据目录文件齐全
    Evidence: .sisyphus/evidence/task-7-ci-mcp.log

  Scenario: Failure - runtime 缺失
    Tool: Bash
    Steps: 卸载/屏蔽 runtime 后执行 CI 序列
    Expected: 非零退出，输出 `MCP_RUNTIME_NOT_FOUND`
    Evidence: .sisyphus/evidence/task-7-ci-mcp-error.log
  ```

  **Commit**: YES | Message: `ci(mcp): 增加runtime启用验证任务` | Files: `.github/workflows/*`（或等效CI配置）

- [ ] 8. 文档收口与操作手册

  **What to do**:
  - 更新 README（或 `docs/`）加入：环境要求、配置模板复制、启动命令、错误码说明、CI 证据位置。
  - 增加“本次范围不含”章节，防止后续误解。
  **Must NOT do**:
  - 不写含糊描述；每步必须可复制执行。

  **Recommended Agent Profile**:
  - Category: `writing` - Reason: 文档整合与可操作性。
  - Skills: `[]`
  - Omitted: [`unspecified-high`] - 无复杂代码。

  **Parallelization**: Can Parallel: NO | Wave 3 | Blocks: none | Blocked By: #3 #7

  **References**:
  - Pattern: `scripts/dev/smoke_runner.gd:104-105` - 错误输出语义风格。
  - External: `https://github.com/Erodenn/godot-mcp-runtime` - 官方使用说明。

  **Acceptance Criteria**:
  - [ ] 文档包含从 0 到验证通过的完整命令序列。
  - [ ] 文档包含故障排查对照表（错误码→处理动作）。

  **QA Scenarios**:
  ```
  Scenario: Happy path 文档命令可复现
    Tool: Bash
    Steps: 严格按文档命令执行一遍
    Expected: 最终出现 `MCP_HEALTH_OK`
    Evidence: .sisyphus/evidence/task-8-doc-replay.log

  Scenario: Failure - 文档遗漏步骤
    Tool: Bash
    Steps: 运行文档校验脚本（检查必要命令段）
    Expected: 非零退出并指明缺失段落
    Evidence: .sisyphus/evidence/task-8-doc-replay-error.log
  ```

  **Commit**: YES | Message: `docs(mcp): 完善启用与排障手册` | Files: `README.md`（或等效文档）

## Final Verification Wave (MANDATORY — after ALL implementation tasks)
> 4 review agents run in PARALLEL. ALL must APPROVE. Present consolidated results to user and get explicit "okay" before completing.
> **Do NOT auto-proceed after verification. Wait for user's explicit approval before marking work complete.**
> **Never mark F1-F4 as checked before getting user's okay.** Rejection or user feedback -> fix -> re-run -> present again -> wait for okay.

- [ ] F1. Plan Compliance Audit — oracle
- [ ] F2. Code Quality Review — unspecified-high
- [ ] F3. Real Manual QA — unspecified-high (+ playwright if UI)
- [ ] F4. Scope Fidelity Check — deep

## Commit Strategy
- 每个 TODO 原子提交一次，避免跨任务混改。
- 提交信息使用中文语义化前缀：`chore/fix/feat/docs/ci(scope): 描述`。
- 失败修复使用新提交，不 amend 历史。

## Success Criteria
- 启用链路可在无编辑器交互下完成（headless + 脚本）。
- 成功与失败路径都可由固定错误码判定。
- CI 可稳定复现并输出证据。
- 文档可让新成员在单次执行内完成接入验证。
