
- 非阻塞：运行日志仍有多条 GDScript warning（命名冲突、未使用变量、整数除法提示），当前未见导致流程失败。
- QA(2026-04-21): 兼容性风险：当 v1 存档数据形态为 `{simulation_snapshot:{...}}` 时，`SaveService.load_slot()` 会把 payload 升到 v2，但内层快照未执行 `SaveMigration.v1_to_v2`，缺少 v2 字段。
