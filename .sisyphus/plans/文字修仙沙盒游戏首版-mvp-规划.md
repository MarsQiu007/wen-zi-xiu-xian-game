# 文字修仙沙盒游戏首版 MVP 工作计划

## TL;DR

> **Quick Summary**：先在 Godot 4.6 中落地一个“小而活”的文字修仙沙盒：同一套世界底层规则同时支撑人类模式与神明模式，第一版聚焦“村镇 + 小宗门 + 一座小城”的单活跃区域，验证 NPC 活人感、凡人到炼气的成长、神眷者长期培养与教团雏形。
>
> **Deliverables**：
> - Godot 4.6 文字优先 MVP 工程骨架
> - NPC 人生模拟核心（时间、需求、目标、道德、事件日志）
> - 人类模式最小闭环（开局、生存、求仙、继承）
> - 神明模式最小闭环（信仰点、神谕、主神眷者培养、教团雏形）
> - 单活跃区域世界数据（村镇 / 小宗门 / 小城 / 资源区 / 妖兽区 / 鬼怪点 / 秘境入口）
>
> **Estimated Effort**：Large
> **Parallel Execution**：YES - 3 个主波次
> **Critical Path**：世界与数据骨架 → 时间/模拟核心 → 人类模式最小闭环 → 神明模式最小闭环 → 整体联调与验证

---

## Context

### Original Request
使用 Godot 4 做一款文字修仙沙盒游戏。NPC 要有人生、需求、目标、道德与际遇，会主动行动。游戏包含神明模式与人类模式；神明可培养神眷者、发起神教，人类模式强调单角色继承视角、家族与血脉延续。世界包含人间、鬼域、仙界三层；修仙正统是主流，神道是强力但非主流异端路线。

### Interview Summary
**关键讨论结论**：
- 双模式共享同一套世界底层规则，但默认独立存档，后期可解锁共享宇宙。
- 神明可走正神 / 邪神 / 灰度神格路线；神教必须由神眷者发起。
- 人类模式始终保持单角色继承视角，不转为家族管理视角。
- 凡俗婚姻与修仙道侣分离；继承人直系优先，但允许特殊合法继承人。
- 修仙正统是主流，神道不是主流；高阶修士可镇压甚至斩神明在人间依托。
- 第一版活跃区域结构确定为“村镇 + 小宗门 + 一座小城”。
- 第一版双模式都做最小闭环，但人类模式稍优先。

**Research Findings**：
- RimWorld / Dwarf Fortress 说明“事件驱动 + 抽象呈现”足以支撑强叙事沙盒。
- Utility AI + GOAP 适合做“需求排序 + 目标路径”混合决策。
- CK3 的家族传承、Godhood/Reus 的神明资源循环适合分别映射人类模式与神明模式。
- Oracle 建议首版必须收敛到“单活跃区域、日级推进、事件驱动”，避免范围失控。

### Metis Review
**Gap Review**：
- 已尝试两次 Metis 审阅，但会话超时；因此改为按同等严格清单自审并补入计划。
- 已自补默认项：
  - **测试策略**：首版默认“不引入完整自动化测试框架”，但每个任务都必须具备 Agent-Executed QA 场景与可复现的 smoke runner / debug scene。
  - **模式优先级**：双模式都进 MVP，但人类模式体验更完整。
  - **神教层级**：第一版做到“教团雏形”。
- 已锁定的范围风险：仙界、鬼域深度玩法、多平行人间大世界、金丹以上完整生态均延期。

---

## Work Objectives

### Core Objective
在 Godot 4.6 中完成一个可玩的文字修仙沙盒首版 MVP：玩家能在人类模式中体验从凡俗人生迈向修仙门槛的成长与继承，也能在神明模式中用有限信仰点培养一名主神眷者，并在同一活世界中看到明确的因果反馈。

### Concrete Deliverables
- `project.godot` 与首版目录骨架
- `autoload/` 下的世界时间、运行态、存档入口与事件日志入口
- `resources/` 下的人物、家族、宗门、神教、区域、事件等数据资源
- `scenes/ui/` 下的文字日志、状态面板、事件弹窗、模式入口界面
- `scripts/sim/` 下的时间推进、NPC 需求/目标/道德/事件结算核心
- `scripts/modes/human/` 与 `scripts/modes/deity/` 下的两套模式控制器
- 最小 smoke runner / debug scene，用于日推进与关键选择验证

### Definition of Done
- [ ] 神明模式可从少量初始信徒开始，稳定获得信仰点，并培养 1 名主神眷者。
- [ ] 人类模式可从凡人开局，经历生存/家族/求仙分歧，并至少能走到炼气前后。
- [ ] 单活跃区域中至少能稳定运行 12~20 名焦点 NPC 与 30~50 名半焦点 NPC 的日级事件模拟。
- [ ] 关键事件具备暂停与选择；普通事件能写入日志并可追溯原因。
- [ ] 人类角色死亡后，若存在合法继承人，可继续游玩。

### Must Have
- 人类模式稍优先，但神明模式不能缺席。
- NPC 行为必须可解释，不能只是随机噪音。
- 神明必须通过神眷者深度影响世界，不能凭空建教。
- 修仙正统与神道异端的张力要能在事件与势力关系里体现出来。

### Must NOT Have (Guardrails)
- 不做完整仙界可玩层。
- 不做多个平行人间大世界的正式切换。
- 不做金丹以上完整生态与完整飞升长线。
- 不把人类模式做成家族经营器。
- 不把神明模式做成无风险万能上帝视角。

---

## Verification Strategy

> **ZERO HUMAN INTERVENTION** - 所有验证都必须由执行代理完成。

### Test Decision
- **Infrastructure exists**：NO
- **Automated tests**：None（首版默认不先引入完整测试框架）
- **Framework**：none（但每个系统需提供 smoke runner / debug scene / deterministic seed 验证入口）
- **Agent-Executed QA**：MANDATORY

### QA Policy
- **Godot 启动验证**：使用 Bash 运行 Godot headless 或 debug scene，检查项目可打开、关键场景可实例化、日志不报致命错误。
- **模拟验证**：使用 Bash 运行专用 smoke runner，推进固定天数，断言关键状态变化与事件日志存在。
- **文字 UI 验证**：使用 Bash 启动 Godot 并通过截图/日志文件确认面板、事件弹窗、状态页与日志页工作正常。
- **模式验证**：对人类模式与神明模式分别执行一轮固定剧本 smoke path。
- 证据输出统一落在 `.sisyphus/evidence/`。

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1（基础骨架，可立即并行）
├── Task 1: 搭建 Godot 项目骨架与 Autoload 框架
├── Task 2: 设计世界/角色/势力 Resource 数据层
├── Task 3: 实现时间推进、事件日志、固定种子骨架
├── Task 4: 落地单活跃区域世界数据与势力布局
├── Task 5: 搭建文字 UI 主框架与事件弹窗
└── Task 6: 建立 smoke runner / debug 验证入口

Wave 2（在 Wave 1 完成后最大化并行）
├── Task 7: 实现 NPC 需求/目标/道德/焦点分层核心
├── Task 8: 实现人类模式开局与早期成长循环
├── Task 9: 实现家族、婚姻/道侣、继承最小闭环
├── Task 10: 实现修仙入门、炼气前后与突破失败雏形
├── Task 11: 实现神明模式信仰点循环与神谕干预
└── Task 12: 实现主神眷者培养线与教团雏形

Wave 3（整合与打磨）
├── Task 13: 整合双模式、区域事件与势力反馈
├── Task 14: 加入修仙正统 vs 神道异端敌意与镇压事件
├── Task 15: 平衡首版数值、补充内容种子与新手引导

Wave FINAL（并行验证）
├── Task F1: Plan Compliance Audit（oracle）
├── Task F2: Code Quality Review（unspecified-high）
├── Task F3: Automated QA / smoke playthrough（unspecified-high）
└── Task F4: Scope Fidelity Check（deep）
```

### Dependency Matrix
- **1**：- → 7, 8, 11, 13
- **2**：- → 7, 8, 9, 10, 11, 12, 13
- **3**：- → 7, 8, 10, 11, 13, 15
- **4**：- → 8, 11, 12, 13, 14
- **5**：- → 8, 11, 12, 13, 15
- **6**：- → 7-15
- **7**：1,2,3 → 8, 9, 10, 11, 12, 13, 14
- **8**：1,2,3,4,5,7 → 13, 15
- **9**：2,7 → 13, 15
- **10**：2,3,7 → 13, 14, 15
- **11**：1,2,3,4,5,7 → 12, 13, 14, 15
- **12**：2,4,5,7,11 → 13, 14, 15
- **13**：8-12 → 14, 15, F1-F4
- **14**：10,11,12,13 → 15, F1-F4
- **15**：13,14 → F1-F4

### Agent Dispatch Summary
- **Wave 1**：6 个任务
  - T1 → `quick`
  - T2 → `quick`
  - T3 → `deep`
  - T4 → `writing`
  - T5 → `visual-engineering`
  - T6 → `quick`
- **Wave 2**：6 个任务
  - T7 → `deep`
  - T8 → `deep`
  - T9 → `unspecified-high`
  - T10 → `deep`
  - T11 → `unspecified-high`
  - T12 → `deep`
- **Wave 3**：3 个任务
  - T13 → `deep`
  - T14 → `unspecified-high`
  - T15 → `writing`
- **FINAL**：4 个任务
  - F1 → `oracle`
  - F2 → `unspecified-high`
  - F3 → `unspecified-high`
  - F4 → `deep`

---

## TODOs

- [x] 1. 搭建 Godot 项目骨架与 Autoload 框架

  **What to do**：
  - 建立 Godot 4.6 项目目录结构：`autoload/`、`resources/`、`scenes/ui/`、`scripts/sim/`、`scripts/modes/`、`scripts/dev/`
  - 建立最小 Autoload：时间入口、运行态入口、存档入口、事件日志入口
  - 保证场景树以 `GameRoot + UIRoot + SimulationRunner` 为核心

  **Must NOT do**：
  - 不要在第一版引入庞大服务容器或泛用事件总线
  - 不要让 Autoload 承担全部业务逻辑

  **Recommended Agent Profile**：
  - **Category**: `quick`
    - Reason: 属于项目骨架搭建，清晰且边界明确
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - `godot4-architecture`: 已在规划阶段吸收其原则，执行时不必额外加载

  **Parallelization**：
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1（与 2,3,4,5,6 并行）
  - **Blocks**: 7, 8, 11, 13
  - **Blocked By**: None

  **References**：
  - `.sisyphus/drafts/文字修仙沙盒初步策划.md` - 全部策划上下文来源，执行者需严格按此骨架落目录
  - `Context: “Godot 4.6 文字优先 + SimulationRunner + UIRoot + Resource 驱动”` - 这是首版架构硬约束

  **Acceptance Criteria**：
  - [ ] 项目可在 Godot 4.6 正常打开
  - [ ] Autoload 节点完成注册并无致命报错
  - [ ] 存在主入口场景，可实例化 `SimulationRunner` 与 `UIRoot`

  **QA Scenarios**：
  ```
  Scenario: 项目骨架成功启动
    Tool: Bash
    Preconditions: Godot 4.6 可用，项目骨架已创建
    Steps:
      1. 运行 `godot4 --headless --path . --quit`
      2. 检查退出码为 0
      3. 检查日志中无 “Parser Error” / “Invalid get index” / “Autoload not found” 等致命错误
    Expected Result: 项目正常初始化并退出
    Failure Indicators: Godot 启动失败、Autoload 缺失、主场景无法加载
    Evidence: .sisyphus/evidence/task-1-project-boot.txt

  Scenario: 主入口场景可实例化
    Tool: Bash
    Preconditions: 主入口场景已配置
    Steps:
      1. 运行专用 smoke scene 实例化脚本
      2. 输出 GameRoot / SimulationRunner / UIRoot 节点树摘要
    Expected Result: 三个核心节点均存在
    Evidence: .sisyphus/evidence/task-1-root-scene.txt
  ```

  **Commit**: YES
  - Message: `feat(mvp): 搭建 Godot 项目骨架与自动加载入口`
  - Files: `project.godot`, `autoload/*`, `scenes/*`, `scripts/*`
  - Pre-commit: `godot4 --headless --path . --quit`

- [x] 2. 设计世界/角色/势力 Resource 数据层

  **What to do**：
  - 建立角色、家族、势力、区域、事件、教义、神格等基础 Resource 定义
  - 让数据层支持人类模式、神明模式共享读取
  - 为后续单活跃区域、NPC 模拟、神教雏形、人类继承预留字段

  **Must NOT do**：
  - 不要一次性实现所有高阶境界、仙界、鬼域完整字段
  - 不要把运行态状态全部塞进静态 Resource

  **Recommended Agent Profile**：
  - **Category**: `quick`
    - Reason: 以清晰数据结构定义为主
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - `godot4-architecture`: 原则已吸收，执行期按规划字段落地即可

  **Parallelization**：
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1
  - **Blocks**: 7, 8, 9, 10, 11, 12, 13
  - **Blocked By**: None

  **References**：
  - `## 人物属性系统（重设计初稿）` - 定义角色字段边界
  - `## 家族与血脉继承系统（初稿）` - 定义家族与继承字段
  - `## 神眷者培养线（初稿）` 与 `## 神教势力形成与扩张系统（初稿）` - 定义神明/神教字段

  **Acceptance Criteria**：
  - [ ] 至少存在：角色、家族、势力、区域、事件模板 Resource
  - [ ] 字段能覆盖首版 MVP 所需信息，不缺关键字段
  - [ ] 数据定义支持人类与神明模式复用

  **QA Scenarios**：
  ```
  Scenario: Resource 能正常加载
    Tool: Bash
    Preconditions: 基础 Resource 脚本与样例资源已创建
    Steps:
      1. 运行 `godot4 --headless --path . --script res://scripts/dev/load_resources_smoke.gd`
      2. 加载全部样例资源
      3. 输出每类资源关键字段摘要
    Expected Result: 所有资源加载成功，无字段缺失错误
    Evidence: .sisyphus/evidence/task-2-resource-load.txt

  Scenario: 双模式共享字段可用
    Tool: Bash
    Preconditions: 存在角色/势力/区域样例资源
    Steps:
      1. 分别以人类模式和神明模式控制器读取同一角色资源
      2. 输出读取结果差异
    Expected Result: 同一底层数据可被两模式解释使用
    Evidence: .sisyphus/evidence/task-2-shared-data.txt
  ```

  **Commit**: YES
  - Message: `feat(data): 定义世界角色与势力资源结构`
  - Files: `resources/*`, `scripts/resources/*`
  - Pre-commit: `godot4 --headless --path . --script res://scripts/dev/load_resources_smoke.gd`

- [x] 3. 实现时间推进、事件日志、固定种子骨架

  **What to do**：
  - 建立日级推进系统
  - 建立事件日志记录与查询结构
  - 支持固定随机种子，以便重现实验与 smoke 测试
  - 为关键节点暂停与普通事件自动推进提供统一入口

  **Must NOT do**：
  - 不要一开始做小时级、分钟级高频排程
  - 不要把日志只做成纯文本拼接，必须保留原因字段

  **Recommended Agent Profile**：
  - **Category**: `deep`
    - Reason: 时间推进与日志结构会影响所有系统，是高耦合核心
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - `godot4-feature-dev`: 当前是底层机制实现，不是单功能开发

  **Parallelization**：
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1
  - **Blocks**: 7, 8, 10, 11, 13, 15
  - **Blocked By**: None

  **References**：
  - `## NPC 行为决策流（初稿）` - 时间推进与事件阶段顺序定义
  - `## 第一版核心循环与最小可玩内容（MVP）定义` - 指定日级推进与日志的 MVP 角色

  **Acceptance Criteria**：
  - [x] 可推进单日并触发基础事件结算
  - [x] 日志可记录事件标题、涉及角色、直接原因、结果
  - [x] 固定种子下重复运行可得到一致输出

  **QA Scenarios**：
  ```
  Scenario: 固定种子日推进可复现
    Tool: Bash
    Preconditions: 日推进与随机源已实现
    Steps:
      1. 运行两次 `godot4 --headless --path . --script res://scripts/dev/day_tick_smoke.gd -- --seed=42 --days=10`
      2. 对比两次输出日志摘要
    Expected Result: 关键事件顺序与结果一致
    Failure Indicators: 同种子下事件不同、日志缺因果说明
    Evidence: .sisyphus/evidence/task-3-seeded-days.txt

  Scenario: 关键事件可暂停
    Tool: Bash
    Preconditions: 存在至少一种关键节点模板
    Steps:
      1. 运行固定剧本推进到关键事件
      2. 检查系统是否输出“暂停等待选择”状态
    Expected Result: 关键事件不被自动吞掉
    Evidence: .sisyphus/evidence/task-3-pause-event.txt
  ```

  **Commit**: YES
  - Message: `feat(sim): 实现日级推进与事件日志骨架`
  - Files: `autoload/*`, `scripts/sim/*`, `scripts/dev/*`
  - Pre-commit: `godot4 --headless --path . --script res://scripts/dev/day_tick_smoke.gd -- --seed=42 --days=10`

- [x] 4. 落地单活跃区域世界数据与势力布局

  **What to do**：
  - 按“村镇 + 小宗门 + 一座小城”搭建首版活跃区域
  - 额外补齐资源森林 / 山脉、妖兽区、鬼怪异变点、秘境入口、绝地传闻点
  - 配置家族、宗门、官府、庙宇 / 神教雏形等势力落点

  **Must NOT do**：
  - 不要扩展到多个大世界
  - 不要提前做完整鬼域与仙界地图

  **Recommended Agent Profile**：
  - **Category**: `writing`
    - Reason: 以世界设计落地与数据编排为主
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - `godot4-architecture`: 当前重点是内容布局，不是架构取舍

  **Parallelization**：
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1
  - **Blocks**: 8, 11, 12, 13, 14
  - **Blocked By**: None

  **References**：
  - `## 世界区域与势力结构（初稿）` - 首版区域组合与势力布局准绳
  - `第一版活跃区域结构（已确认）` - 明确不可偏离的区域骨架

  **Acceptance Criteria**：
  - [x] 活跃区域包含 1 村镇、1 小宗门、1 小城
  - [x] 存在至少 1 个妖兽区、1 个鬼怪点、1 个秘境入口
  - [x] 势力关系可在数据中读出

  **QA Scenarios**：
  ```
  Scenario: 活跃区域数据完整
    Tool: Bash
    Preconditions: 区域与势力资源已配置
    Steps:
      1. 运行区域校验脚本
      2. 输出所有区域类型与关联势力摘要
    Expected Result: 必需区域全部存在，且关系可解析
    Evidence: .sisyphus/evidence/task-4-world-layout.txt

  Scenario: 势力落点能生成事件钩子
    Tool: Bash
    Preconditions: 势力与区域挂钩完成
    Steps:
      1. 推进 7 天
      2. 检查是否生成至少 1 条家族 / 宗门 / 神教相关事件
    Expected Result: 区域布局真正参与事件系统
    Evidence: .sisyphus/evidence/task-4-faction-hooks.txt
  ```

  **Commit**: YES
  - Message: `feat(world): 构建首版活跃区域与势力布局`
  - Files: `resources/world/*`, `resources/factions/*`
  - Pre-commit: `godot4 --headless --path . --script res://scripts/dev/world_validate.gd`

- [ ] 5. 搭建文字 UI 主框架与事件弹窗

  **What to do**：
  - 实现模式入口、主日志面板、角色状态面板、事件弹窗、基础选择界面
  - 保证文字信息可读，能显示因果与关键选项
  - 预留神明模式与人类模式的差异化入口区

  **Must NOT do**：
  - 不做复杂美术风格与重交互动画
  - 不把 UI 与模拟逻辑强耦合

  **Recommended Agent Profile**：
  - **Category**: `visual-engineering`
    - Reason: 属于文字 UI 信息架构与面板交互设计
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - `frontend-ui-ux`: 当前在 Godot UI 内实现，不做 Web 风格复杂设计

  **Parallelization**：
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1
  - **Blocks**: 8, 11, 12, 13, 15
  - **Blocked By**: None

  **References**：
  - `文字优先 + 日志驱动 + 关键节点暂停` - UI 核心原则
  - `## 第一版核心循环与最小可玩内容（MVP）定义` - 明确 UI 必须支撑双模式最小闭环

  **Acceptance Criteria**：
  - [ ] 存在可用的主日志面板
  - [ ] 存在关键事件弹窗，可呈现选项
  - [ ] 可在 UI 中查看主角色或主神眷者的核心状态摘要

  **QA Scenarios**：
  ```
  Scenario: 主 UI 可正常显示
    Tool: Bash
    Preconditions: 主场景与 UI 已连接
    Steps:
      1. 启动 Godot 并自动打开主界面
      2. 截图主 UI
      3. 检查截图中存在日志区、状态区、操作区
    Expected Result: UI 三大区域可见且未错位
    Evidence: .sisyphus/evidence/task-5-main-ui.png

  Scenario: 关键事件弹窗可交互
    Tool: Bash
    Preconditions: 存在固定关键事件剧本
    Steps:
      1. 推进到关键事件
      2. 截图弹窗并选择一个选项
      3. 检查日志中出现选后反馈
    Expected Result: 事件弹窗与结果更新正常
    Evidence: .sisyphus/evidence/task-5-event-modal.png
  ```

  **Commit**: YES
  - Message: `feat(ui): 搭建文字日志面板与关键事件弹窗`
  - Files: `scenes/ui/*`, `scripts/ui/*`
  - Pre-commit: `godot4 --headless --path . --script res://scripts/dev/ui_smoke.gd -- --capture-main-ui --capture-event-ui`

- [x] 6. 建立 smoke runner 与调试验证入口

  **What to do**：
  - 提供 headless smoke runner
  - 提供模式级 debug scene / debug command
  - 让执行代理能无人工操作地推进固定天数并输出结构化结果

  **Must NOT do**：
  - 不依赖人工点击完成基础验证
  - 不把验证逻辑散落在业务代码里难以重复调用

  **Recommended Agent Profile**：
  - **Category**: `quick`
    - Reason: 边界清晰，主要是验证入口搭建
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - `review-work`: 当前还未进入完整实现后复核阶段

  **Parallelization**：
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1
  - **Blocks**: 7-15
  - **Blocked By**: None

  **References**：
  - `## Verification Strategy` - 指明所有任务必须 Agent-Executed QA
  - `## 第一版核心循环与最小可玩内容（MVP）定义` - 说明 smoke runner 是 MVP 验收底座

  **Acceptance Criteria**：
  - [x] 存在统一 smoke runner 入口
  - [x] 可传 seed / days / mode 参数
  - [x] 输出结构化日志与状态摘要

  **QA Scenarios**：
  ```
  Scenario: Smoke runner 支持双模式
    Tool: Bash
    Preconditions: smoke runner 已实现
    Steps:
      1. 运行 human 模式 smoke
      2. 运行 deity 模式 smoke
      3. 检查两次输出均成功结束
    Expected Result: 两模式都能通过统一入口验证
    Evidence: .sisyphus/evidence/task-6-runner-dual.txt

  Scenario: Smoke runner 支持参数化日推进
    Tool: Bash
    Preconditions: 参数读取已实现
    Steps:
      1. 运行 `--days=3`
      2. 运行 `--days=30`
      3. 检查输出天数一致
    Expected Result: 参数生效，适合后续所有任务复用
    Evidence: .sisyphus/evidence/task-6-runner-params.txt
  ```

  **Commit**: YES
  - Message: `chore(dev): 建立双模式 smoke runner 与调试入口`
  - Files: `scripts/dev/*`, `scenes/dev/*`
  - Pre-commit: `godot4 --headless --path . --script res://scripts/dev/smoke_runner.gd -- --mode=human --days=3`

- [x] 7. 实现 NPC 需求/目标/道德/焦点分层核心

  **What to do**：
  - 实现 NPC 的基础需求系统、人生目标系统、道德值系统与焦点分层
  - 建立“需求 + 目标 + 道德 + 身份”生成候选行为的简化逻辑
  - 允许焦点 / 半焦点 / 背景 NPC 采用不同精度推进

  **Must NOT do**：
  - 不要做完整人类级复杂模拟
  - 不要在首版做多目标冲突树与海量情绪网络

  **Recommended Agent Profile**：
  - **Category**: `deep`
    - Reason: 这是活人感核心，需要高质量抽象与边界控制
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - `godot4-feature-dev`: 当前是沙盒底层 AI 机制，不是单功能 UI

  **Parallelization**：
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2（与 8,9,10,11,12 并行）
  - **Blocks**: 8, 9, 10, 11, 12, 13, 14
  - **Blocked By**: 1, 2, 3, 6

  **References**：
  - `## NPC 人生目标系统初稿`
  - `## NPC 焦点分层与人格保真机制（初稿）`
  - `## NPC 需求系统（初稿）`
  - `## NPC 行为决策流（初稿）`
  - `## 道德值系统（重设计初稿）`

  **Acceptance Criteria**：
  - [x] NPC 能根据当前需求与目标生成基础行动方向
  - [x] 道德值能改变“采取什么手段”而非只是标签
  - [x] 焦点分层能明显影响更新精度与日志密度

  **QA Scenarios**：
  ```
  Scenario: 不同道德值导致不同行为手段
    Tool: Bash
    Preconditions: 已有 3 个相同处境但道德不同的测试 NPC
    Steps:
      1. 让三者都处于高饥饿状态
      2. 推进 1 天
      3. 比较三者选择：求助 / 交换 / 偷窃 / 抢夺等差异
    Expected Result: 行为手段体现道德差异
    Evidence: .sisyphus/evidence/task-7-morality-choices.txt

  Scenario: 焦点等级影响模拟细度
    Tool: Bash
    Preconditions: 同区域存在焦点 NPC 与背景 NPC
    Steps:
      1. 推进 5 天
      2. 检查日志中焦点 NPC 事件密度明显更高
    Expected Result: 分层生效且可读
    Evidence: .sisyphus/evidence/task-7-focus-density.txt
  ```

  **Commit**: YES
  - Message: `feat(sim): 实现 NPC 需求目标道德与焦点分层核心`
  - Files: `scripts/sim/*`, `resources/*`
  - Pre-commit: `godot4 --headless --path . --script res://scripts/dev/npc_behavior_smoke.gd`

- [x] 8. 实现人类模式开局与早期成长循环

  **What to do**：
  - 实现少年 / 青年 / 成年三类开局
  - 实现生存、家族、婚配、学艺、求仙分歧的前期循环
  - 实现“灵根测试需主动接触修仙圈层”的触发逻辑

  **Must NOT do**：
  - 不要把修仙入口做成固定发券事件
  - 不要跳过凡俗生存阶段直接进入纯修仙爬塔

  **Recommended Agent Profile**：
  - **Category**: `deep`
    - Reason: 这是人类模式首版主体验核心
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - `writing`: 需要真实机制落地，不只是文案组织

  **Parallelization**：
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2
  - **Blocks**: 13, 15
  - **Blocked By**: 1,2,3,4,5,7

  **References**：
  - `## 人类模式开局与早期成长循环（初稿）`
  - `### 灵根测试触发规则（已确认）`
  - `### 开局年龄规则（已确认）`

  **Acceptance Criteria**：
  - [x] 人类模式至少支持三类年龄开局
  - [x] 前期可在生存/家族/求仙之间形成真实分歧
  - [x] 玩家必须主动接触修仙圈层才能进入灵根测试 / 入门机会

  **QA Scenarios**：
  ```
  Scenario: 三类年龄开局可运行
    Tool: Bash
    Preconditions: 人类模式开局配置已完成
    Steps:
      1. 分别运行少年、青年、成年开局 smoke
      2. 推进 5 天
      3. 输出各自初始压力与可选路径摘要
    Expected Result: 三类开局存在明显差异
    Evidence: .sisyphus/evidence/task-8-age-openings.txt

  Scenario: 求仙机会需要主动争取
    Tool: Bash
    Preconditions: 至少存在一条主动接触修仙圈层路径
    Steps:
      1. 运行“不主动接触修仙圈层”剧本 10 天
      2. 运行“主动寻找宗门/高人”剧本 10 天
      3. 对比是否触发灵根测试机会
    Expected Result: 只有主动接触路径才稳定出现求仙机会
    Evidence: .sisyphus/evidence/task-8-cultivation-entry.txt
  ```

  **Commit**: YES
  - Message: `feat(human): 实现开局选择与早期成长循环`
  - Files: `scripts/modes/human/*`, `scenes/ui/*`
  - Pre-commit: `godot4 --headless --path . --script res://scripts/dev/smoke_runner.gd -- --mode=human --days=10`

- [ ] 9. 实现家族、婚姻/道侣、继承最小闭环

  **What to do**：
  - 实现核心家庭、直系血脉、婚姻与道侣分离逻辑
  - 实现继承人判定：直系优先，允许特殊合法继承人
  - 让主角死亡后可在合法继承人中继续游戏

  **Must NOT do**：
  - 不把人类模式转成家族管理面板
  - 不做复杂全自动家族分支经营系统

  **Recommended Agent Profile**：
  - **Category**: `unspecified-high`
    - Reason: 关系与继承规则较多，需细致实现与验证
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - `writing`: 关系系统需真实状态转移与死亡后承接逻辑

  **Parallelization**：
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2
  - **Blocks**: 13, 15
  - **Blocked By**: 2,7

  **References**：
  - `## 家族与血脉继承系统（初稿）`
  - `### 婚姻与道侣关系规则（已确认）`
  - `### 继承人资格规则（已确认）`

  **Acceptance Criteria**：
  - [ ] 婚姻与道侣在数据和逻辑上可区分
  - [ ] 子嗣与直系血脉可生成并参与继承判定
  - [ ] 主角死亡后，若存在合法继承人，可继续游戏而非直接结束

  **QA Scenarios**：
  ```
  Scenario: 婚姻与道侣分离生效
    Tool: Bash
    Preconditions: 存在一组婚姻关系样例与一组道侣关系样例
    Steps:
      1. 读取关系状态
      2. 触发家庭相关事件和修行相关事件
      3. 检查不同关系各自参与的事件不同
    Expected Result: 婚姻与道侣不是同一套状态别名
    Evidence: .sisyphus/evidence/task-9-relationship-split.txt

  Scenario: 死亡后合法继承人接班
    Tool: Bash
    Preconditions: 主角色有直系或特殊合法继承人
    Steps:
      1. 触发主角色死亡事件
      2. 检查继承人列表
      3. 选择其中一人继续推进 3 天
    Expected Result: 游戏不中断，部分家族/资源/关系被承接
    Evidence: .sisyphus/evidence/task-9-inheritance.txt
  ```

  **Commit**: YES
  - Message: `feat(family): 实现婚姻道侣分离与继承闭环`
  - Files: `scripts/modes/human/*`, `scripts/sim/*`, `resources/*`
  - Pre-commit: `godot4 --headless --path . --script res://scripts/dev/inheritance_smoke.gd`

- [ ] 10. 实现修仙入门、炼气前后与突破失败雏形

  **What to do**：
  - 实现凡人到炼气的修炼入口
  - 实现灵根、体质、悟性、修为进度与基础突破判定
  - 实现最小突破失败后果：虚弱、折寿、跌境、走火入魔（可先低概率简化）

  **Must NOT do**：
  - 不追求完整金丹以上生态
  - 不做过多高阶邪法分支

  **Recommended Agent Profile**：
  - **Category**: `deep`
    - Reason: 修仙成长是首版主卖点之一，且要与寿命/突破/事件深度耦合
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - `godot4-feature-dev`: 当前是系统性成长规则，不是单玩法功能

  **Parallelization**：
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2
  - **Blocks**: 13, 14, 15
  - **Blocked By**: 2,3,7

  **References**：
  - `## 修为境界系统（初稿）`
  - `## 境界数值与寿命规则（初稿）`
  - `## 境界突破与失败后果（初稿）`

  **Acceptance Criteria**：
  - [ ] 可从凡人进入炼气前后
  - [ ] 炼气阶段寿命与修为变化可见
  - [ ] 至少一种突破失败后果能稳定触发并写入日志

  **QA Scenarios**：
  ```
  Scenario: 从凡人到炼气的成长可达成
    Tool: Bash
    Preconditions: 存在主动求仙成功的剧本或测试角色
    Steps:
      1. 运行 30 天成长剧本
      2. 检查角色境界从凡人变为炼气前/中/后任一阶段
      3. 输出寿命上限与修为变化摘要
    Expected Result: 修仙成长线跑通
    Evidence: .sisyphus/evidence/task-10-cultivation-growth.txt

  Scenario: 突破失败会留下代价
    Tool: Bash
    Preconditions: 存在低准备度冲关样例角色
    Steps:
      1. 强制触发低准备度突破
      2. 检查结果是否出现虚弱 / 折寿 / 跌境 / 走火入魔之一
    Expected Result: 失败不是无事发生
    Evidence: .sisyphus/evidence/task-10-breakthrough-failure.txt
  ```

  **Commit**: YES
  - Message: `feat(cultivation): 实现炼气前后成长与突破失败雏形`
  - Files: `scripts/sim/*`, `resources/*`
  - Pre-commit: `godot4 --headless --path . --script res://scripts/dev/cultivation_smoke.gd`

- [ ] 11. 实现神明模式信仰点循环与神谕干预

  **What to do**：
  - 实现浅信徒 / 信徒 / 狂信徒的信仰点日收益
  - 实现基础神谕、赐福、点化等神明动作
  - 让神明能在关键节点中消耗信仰点影响结果
  - 区分正神 / 邪神 / 灰度神格的行为风格差异（首版可轻量）

  **Must NOT do**：
  - 不做万能神明直接统治世界逻辑
  - 不让神明绕过神眷者直接建教

  **Recommended Agent Profile**：
  - **Category**: `unspecified-high`
    - Reason: 涉及资源循环、关键事件和神格差异，需要兼顾规则与可玩性
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - `writing`: 不是文案系统，而是资源与事件作用逻辑

  **Parallelization**：
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2
  - **Blocks**: 12, 13, 14, 15
  - **Blocked By**: 1,2,3,4,5,7

  **References**：
  - `## 一、神明模式核心循环`
  - `### 神明神格倾向（新增优化）`
  - `## 修仙正统、神道异端与世界秩序关系（初稿）`

  **Acceptance Criteria**：
  - [ ] 不同层级信徒可稳定产出信仰点
  - [ ] 神明能用信仰点执行至少 3 类干预
  - [ ] 神格倾向会影响神谕风格或目标偏好

  **QA Scenarios**：
  ```
  Scenario: 信仰点每日稳定增长
    Tool: Bash
    Preconditions: 存在浅信徒、信徒、狂信徒样例
    Steps:
      1. 推进 10 天
      2. 读取信仰点总量
      3. 对照理论收益区间
    Expected Result: 信仰点增长符合设定
    Evidence: .sisyphus/evidence/task-11-faith-income.txt

  Scenario: 神谕会改变关键事件结果
    Tool: Bash
    Preconditions: 存在可被干预的关键节点事件
    Steps:
      1. 先运行不干预剧本并记录结果
      2. 再运行相同种子下干预剧本
      3. 比较结果差异
    Expected Result: 神明干预带来可解释的结果变化
    Evidence: .sisyphus/evidence/task-11-divine-intervention.txt
  ```

  **Commit**: YES
  - Message: `feat(deity): 实现信仰点循环与基础神谕干预`
  - Files: `scripts/modes/deity/*`, `scripts/sim/*`, `resources/*`
  - Pre-commit: `godot4 --headless --path . --script res://scripts/dev/smoke_runner.gd -- --mode=deity --days=10`

- [ ] 12. 实现主神眷者培养线与教团雏形

  **What to do**：
  - 实现 1 名主神眷者的选中、引导、扶持、绑定、扩张阶段
  - 实现神眷者能带出“信众圈 → 教团雏形”的最小组织成长
  - 确保神教必须通过神眷者发起

  **Must NOT do**：
  - 不做完整地区级神教政治系统
  - 不做多个核心神眷者并行培养

  **Recommended Agent Profile**：
  - **Category**: `deep`
    - Reason: 这是神明模式的特色卖点与情感核心
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - `writing`: 需要事件链、资源消耗与组织成长真实联动

  **Parallelization**：
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2
  - **Blocks**: 13, 14, 15
  - **Blocked By**: 2,4,5,7,11

  **References**：
  - `## 神眷者培养线（初稿）`
  - `### 神眷者数量规则（已确认）`
  - `## 神教势力形成与扩张系统（初稿）`
  - `### 神教势力建立规则（已确认）`
  - `### 神教教义生成方式（已确认）`

  **Acceptance Criteria**：
  - [ ] 神明可指定 1 名主神眷者并长期跟踪其成长阶段
  - [ ] 神眷者事件链能至少推进到“教团雏形”
  - [ ] 无神眷者时，神教不能直接建立

  **QA Scenarios**：
  ```
  Scenario: 主神眷者培养线可推进
    Tool: Bash
    Preconditions: 神明模式已可运行，存在可培养候选人
    Steps:
      1. 选定 1 名主神眷者候选
      2. 在 30 天内执行至少 3 次关键干预
      3. 检查其状态从普通信徒/凡人推进到更高绑定阶段
    Expected Result: 神眷者成长链可见且有事件反馈
    Evidence: .sisyphus/evidence/task-12-chosen-growth.txt

  Scenario: 神教必须由神眷者发起
    Tool: Bash
    Preconditions: 一个有神眷者剧本，一个无神眷者剧本
    Steps:
      1. 在无神眷者剧本中尝试建教
      2. 在有神眷者剧本中推进到信众圈/教团雏形
    Expected Result: 前者失败，后者成功
    Evidence: .sisyphus/evidence/task-12-cult-foundation.txt
  ```

  **Commit**: YES
  - Message: `feat(deity): 实现主神眷者培养线与教团雏形`
  - Files: `scripts/modes/deity/*`, `scripts/sim/*`, `resources/*`
  - Pre-commit: `godot4 --headless --path . --script res://scripts/dev/deity_chosen_smoke.gd`

- [ ] 13. 整合双模式、区域事件与势力反馈

  **What to do**：
  - 把人类模式、神明模式、区域事件、势力关系统一接到同一模拟底层
  - 保证双模式进入同一世界规则，而非两套分裂逻辑
  - 让家族、宗门、官府、神教、妖祟事件能互相影响

  **Must NOT do**：
  - 不做默认共享宇宙存档
  - 不引入第二套独立事件系统给另一模式单独使用

  **Recommended Agent Profile**：
  - **Category**: `deep`
    - Reason: 这是首版最关键的系统整合任务
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - `godot4-architecture`: 规划已给出边界，当前重点是实现对接

  **Parallelization**：
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Sequential
  - **Blocks**: 14, 15, F1-F4
  - **Blocked By**: 8, 9, 10, 11, 12

  **References**：
  - `## 双模式核心循环（初稿）`
  - `## 世界区域与势力结构（初稿）`
  - `## 第一版核心循环与最小可玩内容（MVP）定义`

  **Acceptance Criteria**：
  - [ ] 双模式共享同一套日推进 / 事件 / 势力反馈逻辑
  - [ ] 家族、宗门、神教、妖祟事件能彼此影响
  - [ ] 两模式切换后（独立开局）不会因底层逻辑差异出现明显设定冲突

  **QA Scenarios**：
  ```
  Scenario: 双模式共享底层规则
    Tool: Bash
    Preconditions: 双模式均已可运行
    Steps:
      1. 运行 human 模式 15 天并记录区域事件
      2. 运行 deity 模式 15 天并记录区域事件
      3. 对比事件类型是否来自同一事件池与势力关系逻辑
    Expected Result: 模式不同，但世界规则一致
    Evidence: .sisyphus/evidence/task-13-shared-world.txt

  Scenario: 势力事件存在互相影响
    Tool: Bash
    Preconditions: 至少有家族、宗门、神教雏形三类势力存在
    Steps:
      1. 推进 20 天
      2. 检查是否发生跨势力连锁事件（如家族求助宗门、神教吸纳边缘人、宗门警惕神教）
    Expected Result: 势力不是孤立模块
    Evidence: .sisyphus/evidence/task-13-faction-feedback.txt
  ```

  **Commit**: YES
  - Message: `feat(integration): 整合双模式与区域势力反馈`
  - Files: `scripts/sim/*`, `scripts/modes/*`, `resources/*`
  - Pre-commit: `godot4 --headless --path . --script res://scripts/dev/integration_smoke.gd`

- [ ] 14. 加入修仙正统与神道异端敌意与镇压事件

  **What to do**：
  - 实现修仙正统为主流、神道为异端的敌意机制
  - 加入高阶修士 / 宗门对神教、神迹、神眷者的警惕与镇压事件雏形
  - 让人类模式主动寻神更容易遭遇代价与冲突

  **Must NOT do**：
  - 不做完整斩神大战系统
  - 不把正神直接写成完全合法主流势力

  **Recommended Agent Profile**：
  - **Category**: `unspecified-high`
    - Reason: 涉及世界秩序关系、敌意值、事件反馈，需避免设定空转
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - `writing`: 需要真实事件机制支撑，而非仅设定文本

  **Parallelization**：
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Sequential
  - **Blocks**: 15, F1-F4
  - **Blocked By**: 10, 11, 12, 13

  **References**：
  - `## 修仙正统、神道异端与世界秩序关系（初稿）`
  - `### 信仰接触与修仙世界主流关系（新增优化）`

  **Acceptance Criteria**：
  - [ ] 神教或明显神迹会提升正统修仙势力敌意
  - [ ] 至少存在一类镇压或调查事件
  - [ ] 人类角色主动求神时，不会轻易得到“完美无代价”路线

  **QA Scenarios**：
  ```
  Scenario: 神教扩张引发正统敌意
    Tool: Bash
    Preconditions: 教团雏形已形成
    Steps:
      1. 推进神教增长剧本 20 天
      2. 检查宗门或高阶修士是否触发警惕/调查/镇压事件
    Expected Result: 神道扩张会触发正统反应
    Evidence: .sisyphus/evidence/task-14-orthodox-hostility.txt

  Scenario: 主动寻神存在价值冲突
    Tool: Bash
    Preconditions: 人类模式存在寻神事件链
    Steps:
      1. 让一名高善角色主动寻神
      2. 检查接触到的神明或神迹选项是否带来道德冲突/代价提示
    Expected Result: 信仰不是稳定无风险最优解
    Evidence: .sisyphus/evidence/task-14-faith-conflict.txt
  ```

  **Commit**: YES
  - Message: `feat(world): 加入正统修仙与神道异端冲突事件`
  - Files: `scripts/sim/*`, `resources/events/*`
  - Pre-commit: `godot4 --headless --path . --script res://scripts/dev/faith_conflict_smoke.gd`

- [ ] 15. 平衡首版数值、补充内容种子与新手引导

  **What to do**：
  - 调整首版关键数值：信仰点收益、前期生存压力、求仙门槛、炼气成长速度、神眷者培养节奏
  - 补充首版事件模板与内容种子
  - 为双模式加入最小新手引导与说明

  **Must NOT do**：
  - 不追求完整数值平衡
  - 不在首版加入过多教程文本压垮节奏

  **Recommended Agent Profile**：
  - **Category**: `writing`
    - Reason: 以内容收束、数值修整、引导落地为主
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - `review-work`: 当前是实现内的首轮收口，不是独立审查阶段

  **Parallelization**：
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Sequential
  - **Blocks**: F1-F4
  - **Blocked By**: 13, 14

  **References**：
  - `## 第一版核心循环与最小可玩内容（MVP）定义`
  - 所有“已确认”边界条款 - 用于避免引导和内容种子偏离方向

  **Acceptance Criteria**：
  - [ ] 前期 10~30 天内可稳定产出清晰事件与成长反馈
  - [ ] 新玩家可理解两模式的基本操作与目标
  - [ ] 事件种子足以支撑至少一次 20 天 smoke playthrough 不明显枯竭

  **QA Scenarios**：
  ```
  Scenario: 人类模式前 20 天节奏可读
    Tool: Bash
    Preconditions: 人类模式闭环完成
    Steps:
      1. 运行人类模式 20 天 smoke
      2. 检查是否出现生存、关系、求仙或家族相关关键节点
      3. 检查日志是否能读出清晰成长脉络
    Expected Result: 前期不是空转，也不是信息爆炸
    Evidence: .sisyphus/evidence/task-15-human-first20.txt

  Scenario: 神明模式前 20 天能形成培养目标
    Tool: Bash
    Preconditions: 神明模式闭环完成
    Steps:
      1. 运行神明模式 20 天 smoke
      2. 检查是否稳定形成主神眷者培养目标
      3. 检查信仰点与教团雏形推进是否可感知
    Expected Result: 神明模式前期目标明确
    Evidence: .sisyphus/evidence/task-15-deity-first20.txt
  ```

  **Commit**: YES
  - Message: `feat(mvp): 完成首版引导、内容种子与数值收束`
  - Files: `resources/events/*`, `resources/text/*`, `scripts/ui/*`, `scripts/sim/*`
  - Pre-commit: `godot4 --headless --path . --script res://scripts/dev/smoke_runner.gd -- --mode=human --days=20`
---

## Final Verification Wave

> 4 个审查任务并行执行，全部通过后才算首版 MVP 达标。

- [ ] F1. **计划符合性审计** — `oracle`
  对照本计划逐项核查：双模式最小闭环、单活跃区域、主神眷者、继承闭环、正统/神道冲突是否都已落地。核查证据文件是否齐全。
  输出：`Must Have [N/N] | Must NOT Have [N/N] | Tasks [N/N] | VERDICT`

  **QA Scenario**：
  ```
  Scenario: 计划符合性自动审计
    Tool: Task (oracle) + Bash
    Preconditions: 全部实现任务完成，.sisyphus/evidence/ 已生成对应证据
    Steps:
      1. 使用 oracle 审阅本计划文件与证据目录索引
      2. 用 Bash 列出 `.sisyphus/evidence/` 证据文件
      3. 对照 Must Have / Must NOT Have / Task 完成情况输出审计摘要
    Expected Result: 给出明确 VERDICT，且能指出缺失证据或范围偏移
    Evidence: .sisyphus/evidence/f1-plan-compliance.txt
  ```

- [ ] F2. **代码与结构质量审查** — `unspecified-high`
  检查 Godot 项目结构、脚本组织、Resource 划分、Autoload 边界、是否出现首版范围外的大量提前实现；运行 smoke runner 与 Godot 启动检查。
  输出：`Boot [PASS/FAIL] | Smoke [PASS/FAIL] | Structure [CLEAN/ISSUES] | VERDICT`

  **QA Scenario**：
  ```
  Scenario: 代码结构与启动质量审查
    Tool: Bash + Task (unspecified-high)
    Preconditions: Godot 项目可启动，smoke runner 可执行
    Steps:
      1. 运行 `godot4 --headless --path . --quit`
      2. 运行 `godot4 --headless --path . --script res://scripts/dev/smoke_runner.gd -- --mode=human --days=5`
      3. 运行 `godot4 --headless --path . --script res://scripts/dev/smoke_runner.gd -- --mode=deity --days=5`
      4. 使用审查代理检查目录边界、Autoload 边界、Resource 组织是否清晰
    Expected Result: 启动通过，双模式 smoke 通过，结构无重大越界
    Evidence: .sisyphus/evidence/f2-code-quality.txt
  ```

- [ ] F3. **自动化玩法 QA 演练** — `unspecified-high`
  分别执行一轮人类模式和神明模式的 20 天 smoke playthrough，验证玩家能否感受到活人世界、求仙分歧、神眷者培养与教团雏形。
  输出：`Human Loop [PASS/FAIL] | Deity Loop [PASS/FAIL] | Evidence [N/N] | VERDICT`

  **QA Scenario**：
  ```
  Scenario: 双模式 20 天自动化演练
    Tool: Bash
    Preconditions: smoke runner 支持双模式与天数参数，UI smoke 脚本可输出截图
    Steps:
      1. 运行 `godot4 --headless --path . --script res://scripts/dev/smoke_runner.gd -- --mode=human --days=20`
      2. 运行 `godot4 --headless --path . --script res://scripts/dev/smoke_runner.gd -- --mode=deity --days=20`
      3. 分别运行 `godot4 --headless --path . --script res://scripts/dev/ui_smoke.gd -- --capture-main-ui --capture-event-ui --mode=human`
      4. 分别运行 `godot4 --headless --path . --script res://scripts/dev/ui_smoke.gd -- --capture-main-ui --capture-event-ui --mode=deity`
      5. 汇总事件日志、关键截图与状态摘要
    Expected Result: Human Loop 与 Deity Loop 均可在 20 天内产出清晰成长/培养反馈，无人工点击
    Evidence: .sisyphus/evidence/f3-automated-playthrough.txt
  ```

- [ ] F4. **范围忠实度检查** — `deep`
  检查首版是否错误扩张到仙界完整可玩层、多大世界联动、金丹以上完整生态或家族经营器化。核查是否仍符合“MVP 收束”原则。
  输出：`Scope [PASS/FAIL] | Creep [NONE/N issues] | VERDICT`

  **QA Scenario**：
  ```
  Scenario: MVP 范围忠实度自动检查
    Tool: Task (deep) + Bash
    Preconditions: 实现已完成，目录结构与主要资源可读取
    Steps:
      1. 使用 deep 审查实现与本计划的 Must NOT Have 列表
      2. 用 Bash 列出项目中的高阶目录与关键资源命名
      3. 检查是否出现仙界完整层、多大世界切换、金丹以上完整生态、家族经营器化等越界实现
    Expected Result: 范围保持在 MVP 约束内，若越界则明确指出
    Evidence: .sisyphus/evidence/f4-scope-fidelity.txt
  ```

## Commit Strategy

- Wave 1：`feat(mvp): 搭建 Godot 项目骨架与世界数据底座`
- Wave 2A：`feat(sim): 实现 NPC 模拟、人类模式与家族继承闭环`
- Wave 2B：`feat(deity): 实现神明模式、神眷者与教团雏形`
- Wave 3：`feat(integration): 完成双模式整合、敌意事件与首版引导`

## Success Criteria

### Verification Commands
```bash
godot4 --headless --path . --script res://scripts/dev/smoke_runner.gd
godot4 --headless --path . --script res://scripts/dev/ui_smoke.gd -- --capture-main-ui --capture-event-ui
```

### Final Checklist
- [ ] 双模式都能进入并跑通最小闭环
- [ ] 单活跃区域能稳定推进多个日循环
- [ ] 神眷者培养、家族继承、求仙转折都可触发
- [ ] 事件日志能解释关键因果链
- [ ] 神道与修仙正统的冲突能在事件中体现
