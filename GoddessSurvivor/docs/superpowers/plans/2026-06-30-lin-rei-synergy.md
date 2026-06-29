# 凛+零协同觉醒 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 SynergySystem 改为数据驱动架构，实现凛（逆鳞之舞·裸剑觉醒）和零（以太共振·雷霆解放）的协同觉醒效果。

**Architecture:** `SYNERGY_CONFIG` 字典统一定义三角色的武器名和效果 id；`_check_awakening` 查表替换硬编码 `"rin"` 逻辑；各武器新增 `awaken()` 方法；EnemyBase 新增 `defense_multiplier` 支持零的降防光环；HUD banner 按 `character_id` 选择文案和颜色。

**Tech Stack:** Godot 4.6, GDScript

---

## 文件变更总览

| 操作 | 文件 |
|------|------|
| 修改 | `GoddessSurvivor/scripts/systems/synergy_system.gd` |
| 修改 | `GoddessSurvivor/scripts/weapons/spin_blade.gd` |
| 修改 | `GoddessSurvivor/scripts/weapons/chain_lightning.gd` |
| 修改 | `GoddessSurvivor/scripts/enemies/enemy_base.gd` |
| 修改 | `GoddessSurvivor/scripts/ui/hud.gd` |

---

## Task 1: EnemyBase 添加 defense_multiplier

**Files:**
- Modify: `GoddessSurvivor/scripts/enemies/enemy_base.gd`

- [ ] **Step 1: 在状态变量区添加 `defense_multiplier`（紧跟 `is_charmed` 之后）**

  找到：
  ```gdscript
  var is_charmed: bool = false                     # 是否被魅惑
  ```
  改为：
  ```gdscript
  var is_charmed: bool = false                     # 是否被魅惑
  var defense_multiplier: float = 1.0              # 伤害接收倍率（<1 = 减伤）
  ```

- [ ] **Step 2: 修改 `take_damage` 方法乘以 defense_multiplier**

  找到：
  ```gdscript
  func take_damage(damage: float) -> void:
  	if is_dead:
  		return

  	current_hp -= damage
  ```
  改为：
  ```gdscript
  func take_damage(damage: float) -> void:
  	if is_dead:
  		return

  	current_hp -= damage * defense_multiplier
  ```

- [ ] **Step 3: 在 `apply_charm` 之后添加 `apply_defense_reduction` 方法**

  ```gdscript
  ## 应用防御削减（amount=0.3 → 受到70%伤害）
  func apply_defense_reduction(amount: float, duration: float) -> void:
  	defense_multiplier = 1.0 - amount
  	get_tree().create_timer(duration).timeout.connect(
  		func() -> void: defense_multiplier = 1.0
  	)
  ```

- [ ] **Step 4: Commit**

  ```bash
  git add GoddessSurvivor/scripts/enemies/enemy_base.gd
  git commit -m "feat(synergy): add defense_multiplier and apply_defense_reduction to EnemyBase"
  ```

---

## Task 2: SpinBlade 添加觉醒逻辑

**Files:**
- Modify: `GoddessSurvivor/scripts/weapons/spin_blade.gd`

- [ ] **Step 1: 在状态变量区添加 `is_awakened`（紧跟 `hit_timers` 之后）**

  找到：
  ```gdscript
  var hit_timers: Dictionary = {}                  # 记录对每个敌人的伤害冷却
  ```
  改为：
  ```gdscript
  var hit_timers: Dictionary = {}                  # 记录对每个敌人的伤害冷却
  var is_awakened: bool = false                    # 是否处于觉醒形态
  ```

- [ ] **Step 2: 修改 `_deal_damage_to`，觉醒时追加弹射伤害**

  找到：
  ```gdscript
  ## 对敌人造成伤害（带冷却）
  func _deal_damage_to(enemy: Node2D) -> void:
  	var enemy_id := enemy.get_instance_id()

  	# 检查冷却
  	if hit_timers.has(enemy_id) and hit_timers[enemy_id] > 0.0:
  		return

  	# 造成伤害
  	enemy.take_damage(get_actual_damage())
  	hit_timers[enemy_id] = hit_cooldown
  ```
  改为：
  ```gdscript
  ## 对敌人造成伤害（带冷却）
  func _deal_damage_to(enemy: Node2D) -> void:
  	var enemy_id := enemy.get_instance_id()

  	# 检查冷却
  	if hit_timers.has(enemy_id) and hit_timers[enemy_id] > 0.0:
  		return

  	# 造成伤害
  	enemy.take_damage(get_actual_damage())
  	hit_timers[enemy_id] = hit_cooldown

  	# 觉醒弹射：在 120px 内找最近其他敌人，造成 50% 伤害
  	if is_awakened:
  		_bounce_damage(enemy)


  ## 觉醒弹射伤害（一次性，不循环）
  func _bounce_damage(source_enemy: Node2D) -> void:
  	var enemies := get_tree().get_nodes_in_group("enemies")
  	var nearest: Node2D = null
  	var nearest_dist := INF
  	for e in enemies:
  		if e == source_enemy or not is_instance_valid(e):
  			continue
  		var d := source_enemy.global_position.distance_to(e.global_position)
  		if d < nearest_dist and d <= 120.0:
  			nearest_dist = d
  			nearest = e
  	if nearest and nearest.has_method("take_damage"):
  		nearest.take_damage(get_actual_damage() * 0.5)
  ```

- [ ] **Step 3: 在文件末尾添加 `awaken()` 方法**

  ```gdscript
  ## 触发觉醒（由 SynergySystem 调用）
  func awaken() -> void:
  	is_awakened = true
  	orbit_radius *= 3.0
  	# 立即刷新所有刀片位置
  	_update_blade_positions()
  ```

- [ ] **Step 4: Commit**

  ```bash
  git add GoddessSurvivor/scripts/weapons/spin_blade.gd
  git commit -m "feat(synergy): add lin awakening to SpinBlade — 3x radius + bounce damage"
  ```

---

## Task 3: ChainLightning 添加觉醒逻辑

**Files:**
- Modify: `GoddessSurvivor/scripts/weapons/chain_lightning.gd`

- [ ] **Step 1: 在 `_ready` 方法之前的变量区末尾添加 `is_awakened`**

  找到：
  ```gdscript
  @export var lightning_width: float = 3.0       # 闪电线条宽度

  # ===== 初始化 =====
  func _ready() -> void:
  ```
  改为：
  ```gdscript
  @export var lightning_width: float = 3.0       # 闪电线条宽度

  # ===== 状态 =====
  var is_awakened: bool = false

  # ===== 初始化 =====
  func _ready() -> void:
  ```

- [ ] **Step 2: 在文件末尾添加 `awaken()` 方法**

  文件末尾当前以 `_generate_lightning_points` 结尾，追加：
  ```gdscript
  ## 触发觉醒（由 SynergySystem 调用）
  func awaken() -> void:
  	is_awakened = true
  	chain_count *= 2
  ```

- [ ] **Step 3: Commit**

  ```bash
  git add GoddessSurvivor/scripts/weapons/chain_lightning.gd
  git commit -m "feat(synergy): add rei awakening to ChainLightning — double chain count"
  ```

---

## Task 4: HUD banner 支持三角色

**Files:**
- Modify: `GoddessSurvivor/scripts/ui/hud.gd`

当前 `_on_synergy_awakened` 忽略 `_character_id` 参数，文案和颜色写死为铃的版本。需要按角色 id 选择。

- [ ] **Step 1: 替换 `_on_synergy_awakened` 方法**

  找到：
  ```gdscript
  func _on_synergy_awakened(_character_id: String, _weapon_id: String) -> void:
  	var label := Label.new()
  	label.text = "✦ 心跳弹幕·星之告白 ✦"
  	label.add_theme_font_size_override("font_size", 36)
  	label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.7))
  ```
  替换整个方法为：
  ```gdscript
  func _on_synergy_awakened(character_id: String, _weapon_id: String) -> void:
  	# 按角色选择文案和颜色
  	var banners := {
  		"rin": {"text": "✦ 心跳弹幕·星之告白 ✦",   "color": Color(1.0, 0.4, 0.7)},
  		"lin": {"text": "✦ 逆鳞之舞·裸剑觉醒 ✦",   "color": Color(0.7, 0.7, 1.0)},
  		"rei": {"text": "✦ 以太共振·雷霆解放 ✦",   "color": Color(0.6, 0.4, 1.0)},
  	}
  	var config: Dictionary = banners.get(character_id, banners["rin"])

  	var label := Label.new()
  	label.text = config["text"]
  	label.add_theme_font_size_override("font_size", 36)
  	label.add_theme_color_override("font_color", config["color"])
  	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
  	label.set_anchors_preset(Control.PRESET_CENTER)
  	label.position = Vector2(-400, -30)
  	label.size = Vector2(800, 60)
  	add_child(label)

  	label.scale = Vector2(0.5, 0.5)
  	var tween := label.create_tween()
  	tween.tween_property(label, "scale", Vector2(1.2, 1.2), 0.2)
  	tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.2)
  	tween.tween_interval(1.6)
  	tween.tween_property(label, "modulate:a", 0.0, 0.4)
  	tween.tween_callback(label.queue_free)
  ```

- [ ] **Step 2: Commit**

  ```bash
  git add GoddessSurvivor/scripts/ui/hud.gd
  git commit -m "feat(synergy): HUD banner supports all 3 character awakening texts and colors"
  ```

---

## Task 5: SynergySystem 改为数据驱动

**Files:**
- Modify: `GoddessSurvivor/scripts/systems/synergy_system.gd`

完整替换整个文件：

- [ ] **Step 1: 用以下内容完整覆写 `synergy_system.gd`**

  ```gdscript
  ## 协同觉醒系统 — 数据驱动，支持三角色
  ## 挂在 Player 节点下，依赖 ClothingSystem 和 WeaponPivot
  class_name SynergySystem
  extends Node

  # 三角色觉醒配置
  const SYNERGY_CONFIG := {
  	"rin": {"weapon_name": "BulletRing",     "effect": "rin_heartbeat"},
  	"lin": {"weapon_name": "SpinBlade",      "effect": "lin_reverse_scale"},
  	"rei": {"weapon_name": "ChainLightning", "effect": "rei_resonance"},
  }

  var already_awakened: bool = false
  var _exp_magnet_timer: float = 0.0
  var _rei_aura_timer: float = 0.0
  const EXP_MAGNET_INTERVAL: float = 0.5
  const REI_AURA_INTERVAL: float = 1.0

  var _player: PlayerController = null
  var _clothing: ClothingSystem = null
  var _flash_overlay: ColorRect = null
  var _active_effect: String = ""


  func _ready() -> void:
  	_player = get_parent() as PlayerController
  	if not _player:
  		push_error("[SynergySystem] 必须作为 PlayerController 的子节点")
  		return
  	_clothing = _player.get_node_or_null("ClothingSystem") as ClothingSystem


  func _process(delta: float) -> void:
  	if GameManager.current_state != GameManager.GameState.PLAYING:
  		return

  	if not already_awakened:
  		_check_awakening()

  	if already_awakened:
  		_update_effects(delta)


  func _update_effects(delta: float) -> void:
  	match _active_effect:
  		"rin_heartbeat":
  			_exp_magnet_timer += delta
  			if _exp_magnet_timer >= EXP_MAGNET_INTERVAL:
  				_exp_magnet_timer = 0.0
  				_attract_all_gems()
  		"rei_resonance":
  			_rei_aura_timer += delta
  			if _rei_aura_timer >= REI_AURA_INTERVAL:
  				_rei_aura_timer = 0.0
  				_apply_rei_defense_aura()


  func _check_awakening() -> void:
  	var char_id := GameManager.current_character_id
  	if not SYNERGY_CONFIG.has(char_id):
  		return
  	if not _clothing:
  		return
  	if _clothing.get_current_stage() < 3:
  		return

  	var cfg: Dictionary = SYNERGY_CONFIG[char_id]
  	var pivot := _player.get_node_or_null("WeaponPivot")
  	if not pivot:
  		return
  	var weapon := pivot.get_node_or_null(cfg["weapon_name"])
  	if not weapon:
  		return
  	if not weapon.has_method("awaken"):
  		return
  	# WeaponBase.current_level
  	if not "current_level" in weapon or weapon.current_level < 5:
  		return

  	_trigger_awakening(weapon, char_id, cfg)


  func _trigger_awakening(weapon: Node, char_id: String, cfg: Dictionary) -> void:
  	already_awakened = true
  	_active_effect = cfg["effect"]
  	weapon.awaken()
  	EventBus.synergy_awakened.emit(char_id, cfg["weapon_name"].to_lower())
  	_play_flash_effect()


  func _play_flash_effect() -> void:
  	var canvas := CanvasLayer.new()
  	canvas.layer = 50
  	get_tree().current_scene.add_child(canvas)

  	_flash_overlay = ColorRect.new()
  	_flash_overlay.color = Color(1, 1, 1, 0.0)
  	_flash_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
  	canvas.add_child(_flash_overlay)

  	var tween := _flash_overlay.create_tween()
  	tween.tween_property(_flash_overlay, "color:a", 0.8, 0.15)
  	tween.tween_property(_flash_overlay, "color:a", 0.0, 0.35)
  	tween.tween_callback(canvas.queue_free)


  func _attract_all_gems() -> void:
  	if not is_instance_valid(_player):
  		return
  	var player_pos := _player.global_position
  	var gems := get_tree().get_nodes_in_group("exp_gems")
  	for gem in gems:
  		if is_instance_valid(gem) and gem.has_method("attract_to"):
  			gem.attract_to(player_pos, 200.0)


  func _apply_rei_defense_aura() -> void:
  	var enemies := get_tree().get_nodes_in_group("enemies")
  	for enemy in enemies:
  		if is_instance_valid(enemy) and enemy.has_method("apply_defense_reduction"):
  			enemy.apply_defense_reduction(0.3, 1.5)
  ```

- [ ] **Step 2: Commit**

  ```bash
  git add GoddessSurvivor/scripts/systems/synergy_system.gd
  git commit -m "feat(synergy): refactor SynergySystem to data-driven config supporting all 3 characters"
  ```

---

## Task 6: 静态 Review + Push

- [ ] **Step 1: 验证三角色触发链**

  **铃（rin）**：
  - `SYNERGY_CONFIG["rin"]["weapon_name"] = "BulletRing"` ✓
  - `pivot.get_node_or_null("BulletRing")` — main_game.gd 设置 `weapon.name = "BulletRing"` ✓
  - `BulletRing.awaken()` — 已在 bullet_ring.gd 实现 ✓
  - `_active_effect = "rin_heartbeat"` → `_attract_all_gems()` ✓

  **凛（lin）**：
  - `SYNERGY_CONFIG["lin"]["weapon_name"] = "SpinBlade"` ✓
  - `pivot.get_node_or_null("SpinBlade")` — level_up_panel.gd 设置 `weapon.name = "SpinBlade"` ✓
  - `SpinBlade.awaken()` — Task 2 实现，radius×3 + 弹射 ✓
  - `_active_effect = "lin_reverse_scale"` → `_update_effects` 无持续效果（match 无对应分支，自然忽略）✓

  **零（rei）**：
  - `SYNERGY_CONFIG["rei"]["weapon_name"] = "ChainLightning"` ✓
  - `ChainLightning.awaken()` — Task 3 实现，chain_count×2 ✓
  - `_active_effect = "rei_resonance"` → 每秒调用 `_apply_rei_defense_aura()` ✓
  - `EnemyBase.apply_defense_reduction(0.3, 1.5)` — Task 1 实现 ✓

- [ ] **Step 2: 验证铃原有行为未回退**

  `_active_effect = "rin_heartbeat"` → `_update_effects` match 命中 `"rin_heartbeat"` 分支，继续调用 `_attract_all_gems()` ✓（与原逻辑等价）

- [ ] **Step 3: Push**

  ```bash
  git status
  git push origin main
  ```

---

## Self-Review

### Spec 覆盖检查

| 需求 | 实现 Task |
|------|-----------|
| EnemyBase defense_multiplier | Task 1 |
| EnemyBase apply_defense_reduction | Task 1 |
| take_damage 乘以 defense_multiplier | Task 1 |
| SpinBlade is_awakened + awaken() + radius×3 | Task 2 |
| SpinBlade 弹射 50% 伤害 120px | Task 2 |
| ChainLightning is_awakened + awaken() + chain_count×2 | Task 3 |
| HUD banner 三角色文案+颜色 | Task 4 |
| SynergySystem SYNERGY_CONFIG 数据驱动 | Task 5 |
| 铃 exp 磁场持续效果保留 | Task 5 `"rin_heartbeat"` 分支 |
| 零 降防光环每 1s 滚动 | Task 5 `"rei_resonance"` 分支 |
| 凛无持续效果（刀刃扩大即可）| Task 5 match 无 `"lin_reverse_scale"` 分支 → 正确忽略 |

### Placeholder 扫描
无 TBD / TODO / 占位文本。

### 类型一致性
- `SpinBlade.awaken()` — Task 2 定义，Task 5 调用 `weapon.awaken()` ✓
- `ChainLightning.awaken()` — Task 3 定义，Task 5 调用 ✓
- `EnemyBase.apply_defense_reduction(0.3, 1.5)` — Task 1 定义，Task 5 调用 ✓
- `SYNERGY_CONFIG["lin"]["effect"] = "lin_reverse_scale"` — Task 5 定义，`_update_effects` match 分支中无此 key（凛无持续效果）— 刻意留空，正确 ✓
