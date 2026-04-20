## 2026-04-19

- 存档协议从 1 升到 2，旧存档允许自动迁移，未来再继续追加版本分支。
- 迁移仅负责补默认字段，不引入具体数据重写逻辑，避免过早耦合业务结构。
- T5 世界生成采用 `scripts/world/name_generator.gd` + `scripts/world/world_generator.gd` 双脚本拆分，保证命名逻辑与世界结构逻辑解耦。
- 角色境界字段使用 `mortal/qi_condensing/foundation/golden_core`，与项目现有人类模式境界命名保持一致，避免后续集成时字段映射成本。
