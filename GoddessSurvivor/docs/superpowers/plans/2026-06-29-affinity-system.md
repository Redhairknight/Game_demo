# 亲密度跨局积累系统 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 每局结束时根据表现累积对应角色亲密度，数据持久化到 `user://affinity.json`，结算界面展示本局 +N 和解锁文字占位。

**Architecture:** `AffinityManager` 作为 Autoload 单例负责读写存档；`AffinityCalculator` 节点挂在场景树中监听局内事件、结算时计算增量并调用 Manager；`GameOver` 界面订阅 `EventBus.affinity_updated` 展示结果。三者通过 EventBus 信号完全解耦。

**Tech Stack:** Godot 4.6, GDScript, Godot FileAccess (JSON)

---

## 文件变更总览

| 操作 | 文件 |
|------|------|
| 新建 | `GoddessSurvivor/autoload/affinity_manager.gd` |
| 新建 | `GoddessSurvivor/scripts/systems/affinity_calculator.gd` |
| 修改 | `GoddessSurvivor/autoload/event_bus.gd` |
| 修改 | `GoddessSurvivor/project.godot` |
| 修改 | `GoddessSurvivor/scripts/ui/game_over.gd` |
| 修改 | `GoddessSurvivor/scenes/main/main.tscn` |

---

## Task 1: EventBus 添加 affinity_updated 信号

**Files:**
- Modify: `GoddessSurvivor/autoload/event_bus.gd`

- [ ] **Step 1: 在文件末尾 `synergy_awakened` 信号后追加**

  找到：
  ```gdscript
  ## 协同觉醒触发 (character_id: String, weapon_id: String)
  signal synergy_awakened(character_id: String, weapon_id: String)
  ```
  改为：
  ```gdscript
  ## 协同觉醒触发 (character_id: String, weapon_id: String)
  signal synergy_awakened(character_id: String, weapon_id: String)

  ## 亲密度更新 (char_id, delta, new_total, new_unlocks)
  signal affinity_updated(char_id: String, delta: int, new_total: int, new_unlocks: Array)
  ```

- [ ] **Step 2: Commit**

  ```bash
  git add GoddessSurvivor/autoload/event_bus.gd
  git commit -m "feat(affinity): add affinity_updated signal to EventBus"
  ```

---

## Task 2: 创建 AffinityManager autoload

**Files:**
- Create: `GoddessSurvivor/autoload/affinity_manager.gd`

- [ ] **Step 1: 创建文件**

  ```gdscript
  ## 亲密度管理器 - 全局单例
  ## 负责读写 user://affinity.json，提供 get/add/unlock 接口
  class_name AffinityManagerClass
  extends Node

  const SAVE_PATH := "user://affinity.json"

  # 解锁阈值表（所有角色共用）
  const UNLOCK_TABLE: Array[Dictionary] = [
  	{"threshold": 10,  "id": "voice_1",     "desc": "「语音包1」战斗台词已解锁（待配音）"},
  	{"threshold": 25,  "id": "outfit_1",    "desc": "「专属服装1」已解锁（待美术完成）"},
  	{"threshold": 50,  "id": "animation_1", "desc": "「互动动画」已解锁（待动画完成）"},
  	{"threshold": 75,  "id": "voice_2",     "desc": "「语音包2」暴露台词已解锁（待配音）"},
  	{"threshold": 100, "id": "hidden_char", "desc": "「焰·Homura」隐藏角色已解锁（待实现）"},
  	{"threshold": 150, "id": "final_form",  "desc": "「约定形态」最终造型已解锁（待美术完成）"},
  ]

  var _data: Dictionary = {}   # { "rin": 42, "lin": 0, "rei": 7 }


  func _ready() -> void:
  	_load()


  # ===== 公共接口 =====

  ## 获取角色当前亲密度
  func get_affinity(char_id: String) -> int:
  	return _data.get(char_id, 0)


  ## 增加亲密度并自动持久化
  func add_affinity(char_id: String, amount: int) -> void:
  	_data[char_id] = _data.get(char_id, 0) + amount
  	_save()


  ## 获取角色已解锁的全部内容
  func get_unlocks(char_id: String) -> Array[Dictionary]:
  	var total := get_affinity(char_id)
  	var result: Array[Dictionary] = []
  	for entry in UNLOCK_TABLE:
  		if total >= entry["threshold"]:
  			result.append(entry)
  	return result


  ## 获取本次新解锁内容（old_val < threshold <= new_val）
  func get_pending_unlocks(char_id: String, old_val: int, new_val: int) -> Array[Dictionary]:
  	var result: Array[Dictionary] = []
  	for entry in UNLOCK_TABLE:
  		var t: int = entry["threshold"]
  		if old_val < t and new_val >= t:
  			result.append(entry)
  	return result


  ## 获取下一个解锁阈值（用于 UI 进度显示）
  func get_next_unlock_threshold(char_id: String) -> int:
  	var total := get_affinity(char_id)
  	for entry in UNLOCK_TABLE:
  		if total < entry["threshold"]:
  			return entry["threshold"]
  	return -1  # 已全解锁


  # ===== 内部存档 =====

  func _save() -> void:
  	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
  	if file:
  		file.store_string(JSON.stringify(_data))
  		file.close()


  func _load() -> void:
  	if not FileAccess.file_exists(SAVE_PATH):
  		_data = {}
  		return
  	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
  	if not file:
  		_data = {}
  		return
  	var text := file.get_as_text()
  	file.close()
  	var parsed := JSON.parse_string(text)
  	if parsed is Dictionary:
  		_data = parsed
  	else:
  		_data = {}
  ```

- [ ] **Step 2: Commit**

  ```bash
  git add GoddessSurvivor/autoload/affinity_manager.gd
  git commit -m "feat(affinity): create AffinityManager autoload with JSON persistence"
  ```

---

## Task 3: 注册 AffinityManager 到 project.godot

**Files:**
- Modify: `GoddessSurvivor/project.godot`

- [ ] **Step 1: 在 `[autoload]` 段追加 AffinityManager**

  找到：
  ```ini
  [autoload]

  GameManager="*res://autoload/game_manager.gd"
  EventBus="*res://autoload/event_bus.gd"
  ```
  改为：
  ```ini
  [autoload]

  GameManager="*res://autoload/game_manager.gd"
  EventBus="*res://autoload/event_bus.gd"
  AffinityManager="*res://autoload/affinity_manager.gd"
  ```

- [ ] **Step 2: Commit**

  ```bash
  git add GoddessSurvivor/project.godot
  git commit -m "feat(affinity): register AffinityManager as autoload in project.godot"
  ```

---

## Task 4: 创建 AffinityCalculator 节点

**Files:**
- Create: `GoddessSurvivor/scripts/systems/affinity_calculator.gd`

- [ ] **Step 1: 创建文件**

  ```gdscript
  ## 亲密度计算器 - 局内节点，追踪本局成就，游戏结束时计算并提交亲密度
  class_name AffinityCalculator
  extends Node

  # ===== 本局追踪状态 =====
  var _reached_stage_2: bool = false
  var _reached_stage_3: bool = false
  var _reached_stage_4: bool = false
  var _ultimate_triggered: bool = false
  var _synergy_triggered: bool = false
  var _taunt_kill_count: int = 0
  var _taunt_kill_window: bool = false
  var _taunt_window_timer: float = 0.0
  const TAUNT_WINDOW_DURATION: float = 3.0


  func _ready() -> void:
  	# 连接全局事件
  	EventBus.clothing_stage_changed.connect(_on_clothing_stage_changed)
  	EventBus.synergy_awakened.connect(_on_synergy_awakened)
  	EventBus.taunt_released.connect(_on_taunt_released)
  	EventBus.enemy_killed.connect(_on_enemy_killed)
  	EventBus.game_over.connect(_on_game_over)

  	# ClothingSystem.ultimate_triggered 是本地信号，等一帧后从 player 获取
  	await get_tree().process_frame
  	var player := GameManager.player_node
  	if player:
  		var clothing := player.get_node_or_null("ClothingSystem") as ClothingSystem
  		if clothing:
  			clothing.ultimate_triggered.connect(_on_ultimate_triggered)


  func _process(delta: float) -> void:
  	# 嘲讽击杀窗口计时
  	if _taunt_kill_window:
  		_taunt_window_timer -= delta
  		if _taunt_window_timer <= 0.0:
  			_taunt_kill_window = false


  # ===== 信号回调 =====

  func _on_clothing_stage_changed(new_stage: int, _old_stage: int) -> void:
  	if new_stage >= 2:
  		_reached_stage_2 = true
  	if new_stage >= 3:
  		_reached_stage_3 = true
  	if new_stage >= 4:
  		_reached_stage_4 = true


  func _on_synergy_awakened(_char_id: String, _weapon_id: String) -> void:
  	_synergy_triggered = true


  func _on_ultimate_triggered() -> void:
  	_ultimate_triggered = true


  func _on_taunt_released(charge_level: int, _pos: Vector2) -> void:
  	# 只有满蓄力（level==3 即 ChargeLevel.FULL）才开始计数窗口
  	if charge_level == 3:
  		_taunt_kill_window = true
  		_taunt_window_timer = TAUNT_WINDOW_DURATION


  func _on_enemy_killed(_enemy_data: Dictionary) -> void:
  	if _taunt_kill_window:
  		_taunt_kill_count += 1


  func _on_game_over(_kill_count: int, _elapsed_time: float) -> void:
  	_calculate_and_save()


  # ===== 结算 =====

  func _calculate_and_save() -> void:
  	var char_id := GameManager.current_character_id
  	if char_id.is_empty():
  		return

  	var old_val := AffinityManager.get_affinity(char_id)

  	var delta := 5  # 基础完成
  	if _reached_stage_2:
  		delta += 3
  	if _reached_stage_3:
  		delta += 5
  	if _reached_stage_4:
  		delta += 8
  	if _ultimate_triggered:
  		delta += 10
  	if _synergy_triggered:
  		delta += 15
  	if _taunt_kill_count >= 50:
  		delta += 5

  	AffinityManager.add_affinity(char_id, delta)
  	var new_val := AffinityManager.get_affinity(char_id)
  	var new_unlocks := AffinityManager.get_pending_unlocks(char_id, old_val, new_val)

  	EventBus.affinity_updated.emit(char_id, delta, new_val, new_unlocks)

  	print("[AffinityCalculator] %s 亲密度 +%d → 总计 %d" % [char_id, delta, new_val])
  ```

- [ ] **Step 2: Commit**

  ```bash
  git add GoddessSurvivor/scripts/systems/affinity_calculator.gd
  git commit -m "feat(affinity): create AffinityCalculator — tracks in-game events and calculates delta"
  ```

---

## Task 5: 将 AffinityCalculator 加入 main.tscn

**Files:**
- Modify: `GoddessSurvivor/scenes/main/main.tscn`

当前 `load_steps=14`。

- [ ] **Step 1: load_steps 从 14 改为 15**

  ```
  [gd_scene load_steps=15 format=3 uid="uid://bq1k8m4xvp2fn"]
  ```

- [ ] **Step 2: 在 ext_resource 末尾追加 AffinityCalculator 引用**

  找到：
  ```
  [ext_resource type="Script" path="res://scripts/ui/boss_health_bar.gd" id="13_boss_bar"]
  ```
  改为：
  ```
  [ext_resource type="Script" path="res://scripts/ui/boss_health_bar.gd" id="13_boss_bar"]
  [ext_resource type="Script" path="res://scripts/systems/affinity_calculator.gd" id="14_affinity"]
  ```

- [ ] **Step 3: 在 EnemySpawner 节点后添加 AffinityCalculator**

  找到：
  ```
  [node name="EnemySpawner" type="Node2D" parent="."]
  script = ExtResource("6_spawner")
  ```
  在其后追加：
  ```
  [node name="AffinityCalculator" type="Node" parent="."]
  script = ExtResource("14_affinity")
  ```

- [ ] **Step 4: Commit**

  ```bash
  git add GoddessSurvivor/scenes/main/main.tscn
  git commit -m "feat(affinity): add AffinityCalculator node to main.tscn"
  ```

---

## Task 6: GameOver 界面展示亲密度结算

**Files:**
- Modify: `GoddessSurvivor/scripts/ui/game_over.gd`

当前 `game_over.gd` 在 `_ready` 里监听 `EventBus.game_over`，在 `_build_ui` 里构建面板。需要增加对 `affinity_updated` 的监听，在面板下方追加亲密度区块。

- [ ] **Step 1: 在 `_ready` 里追加 affinity_updated 监听**

  找到：
  ```gdscript
  func _ready() -> void:
  	layer = 30
  	process_mode = Node.PROCESS_MODE_ALWAYS
  	visible = false
  	GameManager.state_changed.connect(_on_state_changed)
  	EventBus.game_over.connect(_on_game_over)
  ```
  改为：
  ```gdscript
  func _ready() -> void:
  	layer = 30
  	process_mode = Node.PROCESS_MODE_ALWAYS
  	visible = false
  	GameManager.state_changed.connect(_on_state_changed)
  	EventBus.game_over.connect(_on_game_over)
  	EventBus.affinity_updated.connect(_on_affinity_updated)
  ```

- [ ] **Step 2: 添加状态变量和 `_on_affinity_updated` 回调**

  在 `_on_game_over` 方法后追加：

  ```gdscript
  var _affinity_panel_parent: VBoxContainer = null

  func _on_affinity_updated(char_id: String, delta: int, new_total: int, new_unlocks: Array) -> void:
  	if not _affinity_panel_parent:
  		return
  	_show_affinity_result(_affinity_panel_parent, char_id, delta, new_total, new_unlocks)


  func _show_affinity_result(vbox: VBoxContainer, char_id: String, delta: int, new_total: int, new_unlocks: Array) -> void:
  	# 分隔线
  	var sep := HSeparator.new()
  	vbox.add_child(sep)

  	# 角色名映射
  	var char_names := {"rin": "铃 (Rin)", "lin": "凛 (Lin)", "rei": "零 (Rei)"}
  	var char_name: String = char_names.get(char_id, char_id)

  	# 亲密度行
  	var affinity_lbl := Label.new()
  	affinity_lbl.text = "亲密度  %s   +%d ★" % [char_name, delta]
  	affinity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  	affinity_lbl.add_theme_font_size_override("font_size", 20)
  	affinity_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
  	vbox.add_child(affinity_lbl)

  	# 当前总量和下一解锁
  	var next_threshold := AffinityManager.get_next_unlock_threshold(char_id)
  	var progress_text: String
  	if next_threshold == -1:
  		progress_text = "当前: %d（已全部解锁！）" % new_total
  	else:
  		progress_text = "当前: %d / 下一解锁: %d" % [new_total, next_threshold]

  	var progress_lbl := Label.new()
  	progress_lbl.text = progress_text
  	progress_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  	progress_lbl.add_theme_font_size_override("font_size", 16)
  	vbox.add_child(progress_lbl)

  	# 新解锁内容
  	for unlock in new_unlocks:
  		var unlock_lbl := Label.new()
  		unlock_lbl.text = "🔓 " + unlock.get("desc", "")
  		unlock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  		unlock_lbl.add_theme_font_size_override("font_size", 16)
  		unlock_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
  		vbox.add_child(unlock_lbl)
  ```

- [ ] **Step 3: 在 `_build_ui` 里保存 vbox 引用，并调整面板尺寸**

  找到 `_build_ui` 里 panel size 设置：
  ```gdscript
  	var panel := PanelContainer.new()
  	panel.set_anchors_preset(Control.PRESET_CENTER)
  	panel.position = Vector2(-200, -180)
  	panel.size = Vector2(400, 360)
  	add_child(panel)

  	var vbox := VBoxContainer.new()
  	vbox.add_theme_constant_override("separation", 16)
  	panel.add_child(vbox)
  ```
  改为（加宽、加高以容纳亲密度区块，并保存 vbox 引用）：
  ```gdscript
  	var panel := PanelContainer.new()
  	panel.set_anchors_preset(Control.PRESET_CENTER)
  	panel.position = Vector2(-240, -220)
  	panel.size = Vector2(480, 460)
  	add_child(panel)

  	var vbox := VBoxContainer.new()
  	vbox.add_theme_constant_override("separation", 16)
  	panel.add_child(vbox)
  	_affinity_panel_parent = vbox
  ```

- [ ] **Step 4: Commit**

  ```bash
  git add GoddessSurvivor/scripts/ui/game_over.gd
  git commit -m "feat(affinity): show affinity delta and unlocks in GameOver screen"
  ```

---

## Task 7: 静态 Review + Push

- [ ] **Step 1: 验证信号流完整**

  追踪：
  1. `EventBus.game_over.emit()` — `game_manager.gd:70` ✓
  2. `AffinityCalculator._on_game_over()` — Task 4，连接 `EventBus.game_over` ✓
  3. `AffinityManager.add_affinity(char_id, delta)` — Task 2 定义，Task 4 调用 ✓
  4. 写文件 `user://affinity.json` — Task 2 `_save()` ✓
  5. `EventBus.affinity_updated.emit(...)` — Task 4 `_calculate_and_save()` ✓
  6. `GameOver._on_affinity_updated()` — Task 6，连接 `EventBus.affinity_updated` ✓
  7. `_show_affinity_result()` 在面板里追加 Labels ✓

- [ ] **Step 2: 验证 `_affinity_panel_parent` 时序安全**

  `game_over` 信号先触发 `_on_game_over` → `_build_ui`（设置 `_affinity_panel_parent`）。

  `affinity_updated` 由 `AffinityCalculator._on_game_over` 触发，而 `AffinityCalculator` 也连接了同一个 `EventBus.game_over`。

  **潜在风险**：两个 `game_over` 回调的执行顺序不确定。如果 `affinity_updated` 在 `_build_ui` 之前触发，`_affinity_panel_parent` 仍为 null，`_on_affinity_updated` 会提前返回，亲密度区块不显示。

  **修复**：在 `_calculate_and_save` 里用 `call_deferred` 延迟一帧 emit，确保 GameOver UI 已构建完毕：

  找到 `affinity_calculator.gd` 里的：
  ```gdscript
  	EventBus.affinity_updated.emit(char_id, delta, new_val, new_unlocks)
  ```
  改为：
  ```gdscript
  	# 延迟一帧，确保 GameOver._build_ui 已执行
  	EventBus.affinity_updated.emit.call_deferred(char_id, delta, new_val, new_unlocks)
  ```

  ```bash
  git add GoddessSurvivor/scripts/systems/affinity_calculator.gd
  git commit -m "fix(affinity): defer affinity_updated emit to ensure GameOver UI is ready"
  ```

- [ ] **Step 3: Push**

  ```bash
  git status  # 应为 clean
  git push origin main
  ```

---

## Self-Review

### Spec 覆盖检查

| 需求 | 实现 Task |
|------|-----------|
| `AffinityManager` autoload + JSON 存档 | Task 2 |
| 注册 autoload | Task 3 |
| `affinity_updated` 信号 | Task 1 |
| `AffinityCalculator` 局内追踪 | Task 4 |
| 衣着阶段 2/3/4 各自标记 | Task 4 `_on_clothing_stage_changed` |
| 极限形态追踪（本地信号）| Task 4 `await + clothing.ultimate_triggered.connect` |
| 协同觉醒追踪 | Task 4 `_on_synergy_awakened` |
| 嘲讽满蓄力击杀 50+ 追踪 | Task 4 `_on_taunt_released(level==3) + _on_enemy_killed` |
| 基础完成 +5 | Task 4 `_calculate_and_save` |
| AffinityCalculator 加入场景 | Task 5 |
| GameOver 展示 +N 和进度 | Task 6 |
| GameOver 展示新解锁文字 | Task 6 `_show_affinity_result` |
| `get_pending_unlocks` 仅显示新解锁 | Task 2 + Task 6 |
| emit 时序修复 | Task 7 Step 2 |

### Placeholder 扫描
无 TBD / TODO / "类似上方"。

### 类型一致性
- `AffinityManager.get_affinity(char_id)` → `int` — Task 2 定义，Task 4/6 调用 ✓
- `AffinityManager.get_pending_unlocks(char_id, old_val, new_val)` → `Array[Dictionary]` — Task 2 定义，Task 4 调用 ✓
- `AffinityManager.get_next_unlock_threshold(char_id)` → `int` — Task 2 定义，Task 6 调用 ✓
- `EventBus.affinity_updated(char_id: String, delta: int, new_total: int, new_unlocks: Array)` — Task 1 定义，Task 4 emit，Task 6 connect ✓
- `_affinity_panel_parent: VBoxContainer` — Task 6 声明为成员变量，`_build_ui` 赋值，`_on_affinity_updated` 使用 ✓
