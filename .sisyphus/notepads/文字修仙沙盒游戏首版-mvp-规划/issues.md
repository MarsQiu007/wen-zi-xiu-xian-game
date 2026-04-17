## 任务 1 遇到的问题

- `save_service.gd` 中 `JSON.parse_string()` 返回值触发了 Variant 推断警告，Godot 4.6 会按错误处理，需要显式标注变量类型。
- `lsp_diagnostics` 当前无法连上 Godot LSP，报初始化超时；但 headless 启动验证已成功，可作为本任务主要验证依据。

## 任务 2 遇到的问题

- `godot4` 命令在本机不可用，实际可执行文件是 `/home/mars/.local/bin/godot`，后续 headless 验证需要用真实路径。
- 首版资源加载验证里，`class_name` / 基类依赖在 headless 入口下出现加载顺序问题，因此最终改成了字段名驱动的验证方式。
- `String(...)`、`String(int)` 和 `?:` 这些写法在 GDScript 4.6 中会触发解析/调用错误，烟雾脚本需要用 `str()` 和 `a if cond else b`。

## 任务 3 遇到的问题

- `SceneTree._initialize()` 里实例化的节点未必已经挂入场景树，直接 `get_tree()` 或绝对路径取 `/root/...` 可能得到空值；需要改成服务显式注入或在树就绪后再取。
- Autoload 脚本自身如果直接引用其他 Autoload 名称，在 headless smoke 编译阶段也可能失败；应改成运行时节点查找或回退默认值。
- 当前环境下 `lsp_diagnostics` 无法对 GDScript 目录给出有效结果，因此任务 3 的主验证依赖真实 headless 运行、结构化日志与证据文件，而不是 LSP 静态检查。

## 任务 6 遇到的问题

- 统一 smoke runner 初版如果在脚本顶层直接 `preload("res://scenes/main/game_root.tscn")`，会把 `game_root.gd` / `ui_root.gd` 一并提前编译，污染无头验证输出；需要改成运行时 `load` 或纯文本读取场景摘要。
- 当前环境中最可靠的完成判定仍然是真实 headless 运行结果与证据文件，而不是依赖 Godot LSP 对新增 GDScript 给出静态诊断。

## 任务 4 遇到的问题

- `WorldDataCatalog.validate_required_fields()` 目前只校验基础字段是否存在，不校验世界布局语义；因此任务 4 必须额外引入 `scripts/dev/world_validate.gd`，专门验证区域类型覆盖、势力总部与领地引用是否成立。
- 绝地传闻点在首版是“高风险传闻挂点”而不是可稳定占领区域，因此 `controlling_faction_id` 允许为空；校验脚本需要接受这一点，而不是机械要求所有区域都有控制势力。
