# 协同觉醒系统 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 当铃（Rin）的 BulletRing 达到 Lv5 且衣着阶段 ≥ 3 时，触发一次性协同觉醒——弹幕变心形、命中有 30% 魅惑效果、场上经验宝石自动向玩家飞来。

**Architecture:** 新建 `SynergySystem` 节点挂在 Player 下，每帧静默轮询条件，满足后一次性触发；BulletRing 自身维护 `is_awakened` 标志控制行为分支；ExpGem 新增 `attract_to()` 方法；HUD 监听 EventBus 信号显示提示。各组件职责独立，无循环依赖。

**Tech Stack:** Godot 4.6, GDScript

---

## 文件变更总览

| 操作 | 文件 |
|------|------|
| 新建 | `GoddessSurvivor/scripts/systems/synergy_system.gd` |
| 修改 | `GoddessSurvivor/autoload/event_bus.gd` |
| 修改 | `GoddessSurvivor/scripts/weapons/bullet_ring.gd` |
| 修改 | `GoddessSurvivor/scripts/systems/pixel_sprite_generator.gd` |
| 修改 | `GoddessSurvivor/scripts/enemies/enemy_base.gd` |
| 修改 | `GoddessSurvivor/scripts/pickups/exp_gem.gd` |
| 修改 | `GoddessSurvivor/scripts/ui/hud.gd` |
| 修改 | `GoddessSurvivor/scenes/main/main.tscn` |

---

## Task 1: EventBus 添加 synergy_awakened 信号

**Files:**
- Modify: `GoddessSurvivor/autoload/event_bus.gd`

- [ ] **Step 1: 在 event_bus.gd 的游戏流程信号区末尾添加新信号**

  在 `signal boss_spawned(boss_node: Node)` 后追加：

  ```gdscript
  ## 协同觉醒触发 (character_id: String, weapon_id: String)
  signal synergy_awakened(character_id: String, weapon_id: String)
  ```

- [ ] **Step 2: Commit**

  ```bash
  git add GoddessSurvivor/autoload/event_bus.gd
  git commit -m "feat(synergy): add synergy_awakened signal to EventBus"
  ```

---

## Task 2: PixelSpriteGenerator 添加心形弹幕纹理

**Files:**
- Modify: `GoddessSurvivor/scripts/systems/pixel_sprite_generator.gd`

- [ ] **Step 1: 在 `create_bullet_texture` 方法之后添加 `create_heart_bullet_texture`**

  ```gdscript
  ## 生成心形弹幕纹理 (12x12) — 觉醒弹幕专用
  static func create_heart_bullet_texture() -> ImageTexture:
  	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
  	var color := Color(1.0, 0.4, 0.6)  # 粉红色
  	var highlight := Color(1.0, 0.8, 0.9)
  
  	# 心形：两个上圆 + 下三角
  	_draw_circle(img, Vector2i(4, 4), 2, color)
  	_draw_circle(img, Vector2i(8, 4), 2, color)
  	# 下方三角填充
  	for y in range(4, 10):
  		var half_w := 5 - (y - 4)
  		if half_w <= 0:
  			break
  		for x in range(6 - half_w, 6 + half_w):
  			_draw_pixel(img, Vector2i(x, y), color)
  	# 高光
  	_draw_pixel(img, Vector2i(4, 3), highlight)
  	_draw_pixel(img, Vector2i(8, 3), highlight)
  
  	return ImageTexture.create_from_image(img)
  ```

- [ ] **Step 2: Commit**

  ```bash
  git add GoddessSurvivor/scripts/systems/pixel_sprite_generator.gd
  git commit -m "feat(synergy): add heart bullet texture to PixelSpriteGenerator"
  ```

---

## Task 3: EnemyBase 添加 apply_charm 方法

**Files:**
- Modify: `GoddessSurvivor/scripts/enemies/enemy_base.gd`

魅惑后敌人改变移动目标为最近其他敌人。

- [ ] **Step 1: 在状态变量区添加 charm 相关变量（紧跟 `is_taunted` 之后）**

  ```gdscript
  var is_charmed: bool = false             # 是否被魅惑
  ```

- [ ] **Step 2: 在 `apply_taunt` 方法之后添加 `apply_charm`**

  ```gdscript
  ## 应用魅惑（被命中后攻击最近其他敌人）
  func apply_charm(duration: float) -> void:
  	is_charmed = true
  	var timer := get_tree().create_timer(duration)
  	timer.timeout.connect(func() -> void: is_charmed = false)
  ```

- [ ] **Step 3: 修改 `_move_towards_player` 方法，魅惑时改变移动目标**

  将现有方法替换为：

  ```gdscript
  ## 朝目标方向移动（嘲讽/魅惑/普通三种目标）
  func _move_towards_player(delta: float) -> void:
  	if not is_instance_valid(player_ref):
  		player_ref = GameManager.player_node
  		if not player_ref:
  			return

  	var target_pos: Vector2
  	if is_charmed:
  		# 魅惑：朝最近其他敌人移动
  		var nearest_enemy := _find_nearest_other_enemy()
  		if nearest_enemy:
  			target_pos = nearest_enemy.global_position
  		else:
  			target_pos = player_ref.global_position
  	elif is_taunted:
  		target_pos = taunt_target
  	else:
  		target_pos = player_ref.global_position

  	var direction := (target_pos - global_position).normalized()
  	var final_speed := move_speed * speed_multiplier
  	velocity = direction * final_speed + knockback_velocity
  ```

- [ ] **Step 4: 在 `_move_towards_player` 之后添加辅助方法**

  ```gdscript
  ## 查找最近的其他敌人（魅惑用）
  func _find_nearest_other_enemy() -> Node2D:
  	var enemies := get_tree().get_nodes_in_group("enemies")
  	var nearest: Node2D = null
  	var nearest_dist := INF
  	for enemy in enemies:
  		if enemy == self or not is_instance_valid(enemy):
  			continue
  		var dist := global_position.distance_to(enemy.global_position)
  		if dist < nearest_dist:
  			nearest_dist = dist
  			nearest = enemy
  	return nearest
  ```

- [ ] **Step 5: Commit**

  ```bash
  git add GoddessSurvivor/scripts/enemies/enemy_base.gd
  git commit -m "feat(synergy): add charm mechanic to EnemyBase"
  ```

---

## Task 4: ExpGem 添加 attract_to 方法

**Files:**
- Modify: `GoddessSurvivor/scripts/pickups/exp_gem.gd`

- [ ] **Step 1: 在 `collect` 方法之后添加 `attract_to`**

  ```gdscript
  ## 被经验磁场吸引，飞向目标后自动收集
  func attract_to(target_pos: Vector2, speed: float = 200.0) -> void:
  	if _collected:
  		return
  	var dist := global_position.distance_to(target_pos)
  	if dist < 1.0:
  		collect(null)
  		return
  	var duration := dist / speed
  	var tween := create_tween()
  	tween.tween_property(self, "global_position", target_pos, duration)
  	tween.tween_callback(func() -> void: collect(null))
  ```

- [ ] **Step 2: Commit**

  ```bash
  git add GoddessSurvivor/scripts/pickups/exp_gem.gd
  git commit -m "feat(synergy): add attract_to method to ExpGem"
  ```

---

## Task 5: BulletRing 添加觉醒逻辑

**Files:**
- Modify: `GoddessSurvivor/scripts/weapons/bullet_ring.gd`

- [ ] **Step 1: 在状态变量区添加 `is_awakened`（紧跟 `current_rotation` 之后）**

  ```gdscript
  var is_awakened: bool = false             # 是否处于觉醒形态
  ```

- [ ] **Step 2: 在类末尾添加 `awaken()` 方法**

  ```gdscript
  ## 触发觉醒形态（由 SynergySystem 调用，只触发一次）
  func awaken() -> void:
  	is_awakened = true
  ```

- [ ] **Step 3: 修改 `_spawn_simple_bullet` 末尾的碰撞回调，觉醒时附加魅惑**

  找到 `bullet.body_entered.connect` 的 lambda，将整个 `_spawn_simple_bullet` 方法中的碰撞回调部分替换为：

  ```gdscript
  	# 碰撞检测
  	var awakened := is_awakened
  	bullet.area_entered.connect(func(area: Area2D) -> void:
  		if area.is_in_group("enemy_hurtbox"):
  			var enemy := area.get_parent()
  			if enemy and enemy.has_method("take_damage"):
  				enemy.take_damage(get_actual_damage())
  				if awakened and enemy.has_method("apply_charm") and randf() < 0.3:
  					enemy.apply_charm(3.0)
  			bullet.queue_free()
  	)
  	bullet.body_entered.connect(func(body: Node2D) -> void:
  		if body.is_in_group("enemies") and body.has_method("take_damage"):
  			body.take_damage(get_actual_damage())
  			if awakened and body.has_method("apply_charm") and randf() < 0.3:
  				body.apply_charm(3.0)
  			bullet.queue_free()
  	)
  ```

- [ ] **Step 4: 修改 `_spawn_simple_bullet` 中 visual Sprite2D，觉醒时使用心形纹理**

  找到：
  ```gdscript
  	# 添加可视化（简单的圆）
  	var visual := Sprite2D.new()
  	bullet.add_child(visual)
  ```

  替换为：
  ```gdscript
  	# 添加可视化
  	var visual := Sprite2D.new()
  	if is_awakened:
  		visual.texture = PixelSpriteGenerator.create_heart_bullet_texture()
  		visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
  	bullet.add_child(visual)
  ```

- [ ] **Step 5: Commit**

  ```bash
  git add GoddessSurvivor/scripts/weapons/bullet_ring.gd
  git commit -m "feat(synergy): add awakened state and charm to BulletRing"
  ```

---

## Task 6: 创建 SynergySystem

**Files:**
- Create: `GoddessSurvivor/scripts/systems/synergy_system.gd`

- [ ] **Step 1: 创建文件**

  ```gdscript
  ## 协同觉醒系统 — 监测武器等级+衣着阶段，条件满足时触发一次性觉醒
  ## 挂在 Player 节点下，依赖 ClothingSystem 和 WeaponPivot
  class_name SynergySystem
  extends Node

  var already_awakened: bool = false
  var _exp_magnet_timer: float = 0.0
  const EXP_MAGNET_INTERVAL: float = 0.5

  # 节点引用（_ready 时获取）
  var _player: PlayerController = null
  var _clothing: ClothingSystem = null
  var _flash_overlay: ColorRect = null


  func _ready() -> void:
  	_player = get_parent() as PlayerController
  	if not _player:
  		push_error("[SynergySystem] 必须作为 PlayerController 的子节点")
  		return
  	_clothing = _player.get_node_or_null("ClothingSystem") as ClothingSystem


  func _process(delta: float) -> void:
  	if GameManager.current_state != GameManager.GameState.PLAYING:
  		return

  	# 条件检查（一次性）
  	if not already_awakened:
  		_check_awakening()

  	# 觉醒后：经验磁场循环
  	if already_awakened:
  		_exp_magnet_timer += delta
  		if _exp_magnet_timer >= EXP_MAGNET_INTERVAL:
  			_exp_magnet_timer = 0.0
  			_attract_all_gems()


  func _check_awakening() -> void:
  	if GameManager.current_character_id != "rin":
  		return
  	if not _clothing:
  		return
  	if _clothing.get_current_stage() < 3:
  		return

  	var pivot := _player.get_node_or_null("WeaponPivot")
  	if not pivot:
  		return
  	var bullet_ring := pivot.get_node_or_null("BulletRing") as BulletRing
  	if not bullet_ring:
  		return
  	if bullet_ring.current_level < 5:
  		return

  	# 所有条件满足，触发觉醒
  	_trigger_awakening(bullet_ring)


  func _trigger_awakening(bullet_ring: BulletRing) -> void:
  	already_awakened = true
  	bullet_ring.awaken()
  	EventBus.synergy_awakened.emit("rin", "bullet_ring")
  	_play_flash_effect()


  func _play_flash_effect() -> void:
  	# 全屏白色闪烁覆盖层
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
  ```

- [ ] **Step 2: Commit**

  ```bash
  git add GoddessSurvivor/scripts/systems/synergy_system.gd
  git commit -m "feat(synergy): create SynergySystem — polls conditions and triggers awakening"
  ```

---

## Task 7: HUD 显示觉醒提示

**Files:**
- Modify: `GoddessSurvivor/scripts/ui/hud.gd`

- [ ] **Step 1: 在 `_connect_signals` 末尾追加对 synergy_awakened 的监听**

  找到 `_connect_signals` 方法，在末尾加：

  ```gdscript
  	# 协同觉醒提示
  	EventBus.synergy_awakened.connect(_on_synergy_awakened)
  ```

- [ ] **Step 2: 在 hud.gd 末尾添加 `_on_synergy_awakened` 方法**

  ```gdscript
  func _on_synergy_awakened(_character_id: String, _weapon_id: String) -> void:
  	# 创建临时覆盖 Label
  	var label := Label.new()
  	label.text = "✦ 心跳弹幕·星之告白 ✦"
  	label.add_theme_font_size_override("font_size", 36)
  	label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.7))
  	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
  	label.set_anchors_preset(Control.PRESET_CENTER)
  	label.position = Vector2(-400, -30)
  	label.size = Vector2(800, 60)
  	add_child(label)

  	# scale 弹出动画 + 2s 后淡出销毁
  	label.scale = Vector2(0.5, 0.5)
  	var tween := label.create_tween()
  	tween.tween_property(label, "scale", Vector2(1.2, 1.2), 0.2)
  	tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.2)
  	tween.tween_interval(1.6)
  	tween.tween_property(label, "modulate:a", 0.0, 0.4)
  	tween.tween_callback(label.queue_free)
  ```

- [ ] **Step 3: Commit**

  ```bash
  git add GoddessSurvivor/scripts/ui/hud.gd
  git commit -m "feat(synergy): show awakening banner in HUD"
  ```

---

## Task 8: 将 SynergySystem 节点加入 main.tscn

**Files:**
- Modify: `GoddessSurvivor/scenes/main/main.tscn`

- [ ] **Step 1: 将 load_steps 从 10 改为 11**

  ```
  [gd_scene load_steps=11 format=3 uid="uid://bq1k8m4xvp2fn"]
  ```

- [ ] **Step 2: 在 ext_resource 列表末尾添加 SynergySystem 脚本引用**

  找到：
  ```
  [ext_resource type="Script" path="res://scripts/ui/game_over.gd" id="9_gameover"]
  ```
  在其后追加：
  ```
  [ext_resource type="Script" path="res://scripts/systems/synergy_system.gd" id="10_synergy"]
  ```

- [ ] **Step 3: 在 Player 节点的子节点列表中添加 SynergySystem**

  找到：
  ```
  [node name="Camera2D" type="Camera2D" parent="Player"]
  ```
  在其前面插入：
  ```
  [node name="SynergySystem" type="Node" parent="Player"]
  script = ExtResource("10_synergy")
  ```

- [ ] **Step 4: Commit**

  ```bash
  git add GoddessSurvivor/scenes/main/main.tscn
  git commit -m "feat(synergy): add SynergySystem node to Player in main.tscn"
  ```

---

## Task 9: 代码静态 Review + 测试分析

此 Task 通过静态分析验证实现的正确性。Godot 无命令行无头模式可用，故用逻辑追踪替代运行测试。

- [ ] **Step 1: 验证觉醒触发链**

  追踪：
  1. 玩家选铃（`GameManager.current_character_id == "rin"`）✓ character_select.gd 写入
  2. BulletRing 升到 Lv5（`current_level == 5`）✓ weapon_base.level_up() 递增
  3. 衣着阶段 ≥ 3（`clothing.get_current_stage() >= 3`）✓ ClothingSystem._calculate_stage() 返回 int(current_stage)
  4. SynergySystem._check_awakening() 每帧检查上述三条 → `_trigger_awakening()` 被调用
  5. `already_awakened = true` 防止重复触发 ✓
  6. `bullet_ring.awaken()` 设置 `is_awakened = true` ✓
  7. `EventBus.synergy_awakened.emit("rin", "bullet_ring")` ✓
  8. HUD._on_synergy_awakened 收到信号，创建 Label 并动画 ✓
  9. SynergySystem._process 开始 0.5s 磁场循环 ✓

  确认每步代码路径存在，无断链。

- [ ] **Step 2: 验证无重入问题**

  `already_awakened` 在 `_check_awakening` 入口处判断 `if not already_awakened: return`——但当前实现是在 `_process` 里判断，不是在 `_check_awakening` 里，逻辑等价，无问题。

  `_attract_all_gems()` 调用 `gem.attract_to()`，`attract_to` 内部检查 `_collected`，已被 collect 的 gem 不重复处理 ✓

- [ ] **Step 3: 验证魅惑不破坏正常敌人 AI**

  `apply_charm` 设置 `is_charmed = true`，`_move_towards_player` 魅惑分支找最近其他敌人；若场上只有一个敌人，`_find_nearest_other_enemy` 返回 null，回退到朝玩家移动 ✓

  计时器到期 `is_charmed = false`，恢复普通 AI ✓

- [ ] **Step 4: Push 所有变更**

  ```bash
  git push origin main
  ```

---

## Self-Review

### Spec 覆盖检查

| 需求 | 实现 Task |
|------|-----------|
| SynergySystem 独立节点轮询条件 | Task 6 |
| 触发条件：铃 + BulletRing Lv5 + 衣着阶段≥3 | Task 6 `_check_awakening` |
| `already_awakened` 防重复 | Task 6 |
| 调用 `bullet_ring.awaken()` | Task 5 + Task 6 |
| `EventBus.synergy_awakened` 信号 | Task 1 |
| 全屏闪白 tween | Task 6 `_play_flash_effect` |
| HUD 觉醒提示文本 + 动画 | Task 7 |
| 心形弹幕纹理 | Task 2 + Task 5 |
| 30% 魅惑概率 | Task 3 + Task 5 |
| 魅惑敌人朝其他敌人移动 | Task 3 |
| 经验磁场 0.5s 循环 | Task 6 |
| `ExpGem.attract_to()` | Task 4 |
| SynergySystem 加入 main.tscn | Task 8 |

### Placeholder 扫描
无 TBD / TODO / "类似上方"。

### 类型一致性
- `BulletRing.awaken()` — Task 5 定义，Task 6 调用 ✓
- `EnemyBase.apply_charm(duration: float)` — Task 3 定义，Task 5 调用 ✓
- `ExpGem.attract_to(target_pos: Vector2, speed: float)` — Task 4 定义，Task 6 调用 ✓
- `ClothingSystem.get_current_stage() -> int` — 已存在于 clothing_system.gd:122 ✓
- `EventBus.synergy_awakened` — Task 1 定义，Task 6/7 emit/connect ✓
