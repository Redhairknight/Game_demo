# Boss 战系统 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在游戏第 11 分钟触发单阶段 Boss 战——Boss 有冲刺和弹幕圈两种攻击，击败后必掉换装宝箱，HUD 顶部显示血条。

**Architecture:** `BossEnemy` 继承 `EnemyBase` 并覆写移动/攻击/死亡逻辑；`EnemySpawner` 负责定时触发并在 Boss 存活期间暂停普通生成；`BossHealthBar` 作为独立 CanvasLayer 监听信号驱动显示。各组件通过 `EventBus.boss_spawned` / `boss_defeated` 解耦。

**Tech Stack:** Godot 4.6, GDScript

---

## 文件变更总览

| 操作 | 文件 |
|------|------|
| 新建 | `GoddessSurvivor/scripts/enemies/boss_enemy.gd` |
| 新建 | `GoddessSurvivor/scripts/ui/boss_health_bar.gd` |
| 修改 | `GoddessSurvivor/autoload/event_bus.gd` |
| 修改 | `GoddessSurvivor/scripts/systems/pixel_sprite_generator.gd` |
| 修改 | `GoddessSurvivor/scripts/enemies/enemy_spawner.gd` |
| 修改 | `GoddessSurvivor/scenes/main/main.tscn` |

---

## Task 1: EventBus 添加 boss_defeated 信号

**Files:**
- Modify: `GoddessSurvivor/autoload/event_bus.gd`

- [ ] **Step 1: 在 `boss_spawned` 信号后追加 `boss_defeated`**

  找到：
  ```gdscript
  ## Boss出现
  signal boss_spawned(boss_node: Node)
  ```
  改为：
  ```gdscript
  ## Boss出现
  signal boss_spawned(boss_node: Node)

  ## Boss被击败
  signal boss_defeated()
  ```

- [ ] **Step 2: Commit**

  ```bash
  git add GoddessSurvivor/autoload/event_bus.gd
  git commit -m "feat(boss): add boss_defeated signal to EventBus"
  ```

---

## Task 2: PixelSpriteGenerator 添加 Boss 占位图

**Files:**
- Modify: `GoddessSurvivor/scripts/systems/pixel_sprite_generator.gd`

- [ ] **Step 1: 在 `create_enemy_texture` 方法后追加 `create_boss_texture`**

  ```gdscript
  ## 生成 Boss 占位纹理 (48x48，放大到 96x96 由 scale 完成)
  static func create_boss_texture() -> ImageTexture:
  	var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
  	var body_color := Color(0.7, 0.1, 0.1)      # 深红色身体
  	var accent_color := Color(1.0, 0.3, 0.0)    # 橙红色装饰
  	var eye_color := Color(1.0, 0.9, 0.0)       # 金色眼睛

  	# 身体（大圆）
  	_draw_circle(img, Vector2i(24, 26), 18, body_color)
  	# 头部
  	_draw_circle(img, Vector2i(24, 14), 12, body_color.lightened(0.1))
  	# 头冠装饰（三角）
  	_draw_triangle(img, Vector2i(12, 6), Vector2i(24, 0), Vector2i(20, 8), accent_color)
  	_draw_triangle(img, Vector2i(36, 6), Vector2i(24, 0), Vector2i(28, 8), accent_color)
  	# 眼睛（发光）
  	_draw_circle(img, Vector2i(19, 13), 3, eye_color)
  	_draw_circle(img, Vector2i(29, 13), 3, eye_color)
  	_draw_pixel(img, Vector2i(19, 13), Color.WHITE)
  	_draw_pixel(img, Vector2i(29, 13), Color.WHITE)
  	# 腿/爪
  	_draw_rect(img, Vector2i(14, 40), Vector2i(6, 7), body_color.darkened(0.2))
  	_draw_rect(img, Vector2i(28, 40), Vector2i(6, 7), body_color.darkened(0.2))

  	return ImageTexture.create_from_image(img)
  ```

- [ ] **Step 2: Commit**

  ```bash
  git add GoddessSurvivor/scripts/systems/pixel_sprite_generator.gd
  git commit -m "feat(boss): add boss placeholder texture to PixelSpriteGenerator"
  ```

---

## Task 3: 创建 BossEnemy 脚本

**Files:**
- Create: `GoddessSurvivor/scripts/enemies/boss_enemy.gd`

- [ ] **Step 1: 创建文件**

  ```gdscript
  ## Boss 敌人 - 继承 EnemyBase，拥有冲刺和弹幕圈两种攻击
  class_name BossEnemy
  extends EnemyBase

  # ===== Boss 专属配置 =====
  const BOSS_HP: float = 5000.0
  const BOSS_DAMAGE: float = 40.0
  const BOSS_SPEED: float = 60.0
  const DASH_INTERVAL: float = 4.0
  const DASH_WARN_DURATION: float = 0.5
  const DASH_SPEED_MULT: float = 5.0
  const DASH_DURATION: float = 0.6
  const BULLET_INTERVAL: float = 6.0
  const BULLET_COUNT: int = 12
  const BULLET_DAMAGE: float = 25.0
  const BULLET_SPEED: float = 300.0
  const BULLET_LIFETIME: float = 2.0

  # ===== 状态 =====
  var _dash_timer: float = DASH_INTERVAL   # 第一次冲刺稍延迟
  var _bullet_timer: float = 3.0           # 第一次弹幕3秒后
  var _is_dashing: bool = false
  var _dash_target: Vector2 = Vector2.ZERO
  var _dash_elapsed: float = 0.0
  var _warn_line: Line2D = null


  func _ready() -> void:
  	# 设置 Boss 属性
  	enemy_type = "boss"
  	max_hp = BOSS_HP
  	current_hp = BOSS_HP
  	contact_damage = BOSS_DAMAGE
  	move_speed = BOSS_SPEED
  	knockback_resistance = 1.0
  	exp_value = 0  # 死亡时用 scatter 掉落，不走普通 exp gem

  	# Boss 体型放大
  	scale = Vector2(3.0, 3.0)

  	add_to_group("enemies")
  	add_to_group("boss")

  	player_ref = GameManager.player_node

  	# 设置像素纹理（不走 EnemyBase._setup_visual，手动设置）
  	await get_tree().process_frame
  	var sprite_node := get_node_or_null("Sprite2D") as Sprite2D
  	if sprite_node:
  		sprite_node.texture = PixelSpriteGenerator.create_boss_texture()
  		sprite_node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

  	# 连接 hitbox
  	var hitbox_node := get_node_or_null("Hitbox") as Area2D
  	if hitbox_node:
  		hitbox_node.body_entered.connect(_on_hitbox_body_entered)

  	print("[BossEnemy] Boss 出现!")


  func _physics_process(delta: float) -> void:
  	if is_dead:
  		return

  	# 攻击计时
  	_dash_timer -= delta
  	_bullet_timer -= delta

  	if _dash_timer <= 0.0 and not _is_dashing:
  		_dash_timer = DASH_INTERVAL
  		_start_dash()

  	if _bullet_timer <= 0.0:
  		_bullet_timer = BULLET_INTERVAL
  		_fire_bullet_ring()

  	# 移动
  	if _is_dashing:
  		_process_dash(delta)
  	else:
  		_move_towards_player(delta)

  	_process_knockback(delta)
  	move_and_slide()
  	_update_facing()


  # ===== 冲刺攻击 =====

  func _start_dash() -> void:
  	if not is_instance_valid(player_ref):
  		return

  	_dash_target = player_ref.global_position

  	# 显示红色警告线
  	_warn_line = Line2D.new()
  	_warn_line.default_color = Color(1.0, 0.0, 0.0, 0.7)
  	_warn_line.width = 4.0
  	_warn_line.z_index = 5
  	_warn_line.add_point(global_position)
  	_warn_line.add_point(_dash_target)
  	get_tree().current_scene.add_child(_warn_line)

  	# 0.5 秒后真正冲刺
  	var timer := get_tree().create_timer(DASH_WARN_DURATION)
  	timer.timeout.connect(_execute_dash)


  func _execute_dash() -> void:
  	if is_dead:
  		return
  	if _warn_line and is_instance_valid(_warn_line):
  		_warn_line.queue_free()
  		_warn_line = null
  	_is_dashing = true
  	_dash_elapsed = 0.0


  func _process_dash(delta: float) -> void:
  	_dash_elapsed += delta
  	if _dash_elapsed >= DASH_DURATION:
  		_is_dashing = false
  		return

  	var dir := (_dash_target - global_position).normalized()
  	velocity = dir * move_speed * DASH_SPEED_MULT


  # ===== 弹幕圈攻击 =====

  func _fire_bullet_ring() -> void:
  	var angle_step := TAU / BULLET_COUNT
  	for i in range(BULLET_COUNT):
  		var angle := i * angle_step
  		var direction := Vector2(cos(angle), sin(angle))
  		_spawn_boss_bullet(global_position, direction)


  func _spawn_boss_bullet(pos: Vector2, direction: Vector2) -> void:
  	var bullet := Area2D.new()
  	bullet.global_position = pos
  	bullet.add_to_group("boss_projectiles")
  	bullet.collision_layer = 8   # Layer 4: Weapons
  	bullet.collision_mask = 1    # Layer 1: Player

  	var col := CollisionShape2D.new()
  	var shape := CircleShape2D.new()
  	shape.radius = 6.0
  	col.shape = shape
  	bullet.add_child(col)

  	var visual := Sprite2D.new()
  	visual.texture = PixelSpriteGenerator.create_bullet_texture(Color(1.0, 0.3, 0.0))
  	visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
  	bullet.add_child(visual)

  	get_tree().current_scene.add_child(bullet)

  	var tween := bullet.create_tween()
  	var end_pos := pos + direction * BULLET_SPEED * BULLET_LIFETIME
  	tween.tween_property(bullet, "global_position", end_pos, BULLET_LIFETIME)
  	tween.tween_callback(bullet.queue_free)

  	bullet.body_entered.connect(func(body: Node2D) -> void:
  		if body is PlayerController:
  			body.take_damage(BULLET_DAMAGE, self)
  			bullet.queue_free()
  	)


  # ===== 覆写死亡（scatter 掉落 + 换装宝箱）=====

  func _drop_exp() -> void:
  	# 散落 10 颗 exp gem，每颗 10 exp
  	for i in range(10):
  		var gem := ExpGem.new()
  		var offset := Vector2(randf_range(-60, 60), randf_range(-60, 60))
  		gem.global_position = global_position + offset
  		gem.set_exp_value(10)
  		get_tree().current_scene.add_child(gem)

  	# 必掉换装宝箱
  	var chest := WardrobeChest.new()
  	chest.global_position = global_position
  	get_tree().current_scene.add_child(chest)


  func _die() -> void:
  	if is_dead:
  		return
  	is_dead = true
  	velocity = Vector2.ZERO

  	EventBus.boss_defeated.emit()
  	EventBus.enemy_killed.emit({
  		"enemy_type": "boss",
  		"position": global_position,
  		"exp_value": 100
  	})
  	GameManager.add_kill()

  	_drop_exp()

  	# 清理警告线
  	if _warn_line and is_instance_valid(_warn_line):
  		_warn_line.queue_free()

  	# 死亡动画
  	var sprite_node := get_node_or_null("Sprite2D") as Sprite2D
  	if sprite_node:
  		var tween := create_tween()
  		tween.tween_property(sprite_node, "modulate:a", 0.0, 0.5)
  		tween.tween_callback(queue_free)
  	else:
  		queue_free()

  	print("[BossEnemy] Boss 被击败!")
  ```

- [ ] **Step 2: Commit**

  ```bash
  git add GoddessSurvivor/scripts/enemies/boss_enemy.gd
  git commit -m "feat(boss): create BossEnemy with dash + bullet ring attacks"
  ```

---

## Task 4: EnemySpawner 添加 Boss 触发逻辑

**Files:**
- Modify: `GoddessSurvivor/scripts/enemies/enemy_spawner.gd`

`enemy_spawner.gd` 当前有以下状态变量（行 14-21）：
```gdscript
var enemy_scene: PackedScene = null
var spawn_timer: float = 0.0
var current_enemy_count: int = 0
var wave_number: int = 0
var wave_timer: float = 0.0
var player_ref: CharacterBody2D = null
var has_spawned_initial: bool = false
```

- [ ] **Step 1: 添加 Boss 相关状态变量（追加到现有变量块末尾）**

  找到：
  ```gdscript
  var has_spawned_initial: bool = false
  ```
  改为：
  ```gdscript
  var has_spawned_initial: bool = false
  var has_spawned_boss: bool = false
  var is_boss_alive: bool = false
  ```

- [ ] **Step 2: 在 `_ready` 里监听 boss_defeated 信号**

  找到：
  ```gdscript
  func _ready() -> void:
  	enemy_scene = load("res://scenes/enemies/enemy_base.tscn") as PackedScene
  	EventBus.enemy_killed.connect(func(_d: Dictionary) -> void: current_enemy_count -= 1)
  ```
  改为：
  ```gdscript
  func _ready() -> void:
  	enemy_scene = load("res://scenes/enemies/enemy_base.tscn") as PackedScene
  	EventBus.enemy_killed.connect(func(_d: Dictionary) -> void: current_enemy_count -= 1)
  	EventBus.boss_defeated.connect(func() -> void: is_boss_alive = false)
  ```

- [ ] **Step 3: 在 `_process` 里插入 Boss 触发检查和暂停逻辑**

  找到 `_process` 方法开头的游戏状态检查之后、首次生成之前：

  现有方法（精简展示关键部分）：
  ```gdscript
  func _process(delta: float) -> void:
  	if GameManager.current_state != GameManager.GameState.PLAYING:
  		return

  	if not is_instance_valid(player_ref):
  		player_ref = GameManager.player_node
  		if not player_ref:
  			return

  	# 首次生成
  	if not has_spawned_initial:
  		...
  	# 定时生成
  	spawn_timer += delta
  	...
  	# 波次
  	wave_timer += delta
  	...
  ```

  在 `if not has_spawned_initial:` 块之前插入 Boss 触发检查，并在 Boss 存活时跳过普通生成：

  完整替换 `_process` 方法为：
  ```gdscript
  func _process(delta: float) -> void:
  	if GameManager.current_state != GameManager.GameState.PLAYING:
  		return

  	if not is_instance_valid(player_ref):
  		player_ref = GameManager.player_node
  		if not player_ref:
  			return

  	# 首次生成
  	if not has_spawned_initial:
  		has_spawned_initial = true
  		for i in range(8):
  			_spawn_one()
  		return

  	# Boss 触发检查（11 分钟 = 660 秒）
  	if not has_spawned_boss and GameManager.elapsed_time >= 660.0:
  		has_spawned_boss = true
  		is_boss_alive = true
  		_spawn_boss()

  	# Boss 存活期间暂停普通生成（spawn_timer 不累加）
  	if is_boss_alive:
  		return

  	# 定时生成
  	spawn_timer += delta
  	if spawn_timer >= base_spawn_interval and current_enemy_count < max_enemies:
  		spawn_timer = 0.0
  		_spawn_one()

  	# 波次
  	wave_timer += delta
  	if wave_timer >= wave_interval:
  		wave_timer = 0.0
  		wave_number += 1
  		for i in range(wave_enemy_count + wave_number * 5):
  			if current_enemy_count < max_enemies:
  				_spawn_one()
  ```

- [ ] **Step 4: 在文件末尾添加 `_spawn_boss` 方法**

  在 `_spawn_one` 方法之后追加：
  ```gdscript
  func _spawn_boss() -> void:
  	if not is_instance_valid(player_ref):
  		return
  	var boss := BossEnemy.new()
  	# 在玩家右方 400px 生成
  	boss.global_position = player_ref.global_position + Vector2(400.0, 0.0)
  	get_tree().current_scene.add_child(boss)
  	EventBus.boss_spawned.emit(boss)
  	print("[EnemySpawner] Boss 已生成! 位置: %s" % boss.global_position)
  ```

- [ ] **Step 5: Commit**

  ```bash
  git add GoddessSurvivor/scripts/enemies/enemy_spawner.gd
  git commit -m "feat(boss): trigger boss at 11min, pause normal spawning while boss alive"
  ```

---

## Task 5: 创建 BossHealthBar UI

**Files:**
- Create: `GoddessSurvivor/scripts/ui/boss_health_bar.gd`

- [ ] **Step 1: 创建文件**

  ```gdscript
  ## Boss 血条 - 顶部居中显示，监听 Boss hp_changed 信号
  class_name BossHealthBar
  extends CanvasLayer

  var _bar: ProgressBar = null
  var _label: Label = null


  func _ready() -> void:
  	layer = 15
  	process_mode = Node.PROCESS_MODE_ALWAYS
  	_build_ui()
  	visible = false

  	EventBus.boss_spawned.connect(_on_boss_spawned)
  	EventBus.boss_defeated.connect(_on_boss_defeated)


  func _build_ui() -> void:
  	var container := Control.new()
  	container.set_anchors_preset(Control.PRESET_TOP_WIDE)
  	container.custom_minimum_size = Vector2(0, 50)
  	add_child(container)

  	# 背景
  	var bg := ColorRect.new()
  	bg.color = Color(0, 0, 0, 0.6)
  	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
  	container.add_child(bg)

  	# Boss 名称标签
  	_label = Label.new()
  	_label.text = "★ BOSS ★"
  	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  	_label.add_theme_font_size_override("font_size", 16)
  	_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))
  	_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
  	_label.position = Vector2(0, 4)
  	_label.size = Vector2(1920, 20)
  	container.add_child(_label)

  	# 血条
  	_bar = ProgressBar.new()
  	_bar.set_anchors_preset(Control.PRESET_HCENTER_WIDE)
  	_bar.position = Vector2(-300, 24)
  	_bar.size = Vector2(600, 20)
  	_bar.max_value = 1.0
  	_bar.value = 1.0
  	_bar.show_percentage = false
  	# 红色样式
  	var style := StyleBoxFlat.new()
  	style.bg_color = Color(0.8, 0.1, 0.1)
  	_bar.add_theme_stylebox_override("fill", style)
  	container.add_child(_bar)


  func _on_boss_spawned(boss_node: Node) -> void:
  	visible = true
  	if boss_node and boss_node.has_signal("hp_changed"):
  		boss_node.hp_changed.connect(_on_boss_hp_changed)
  	if _bar:
  		_bar.value = 1.0


  func _on_boss_defeated() -> void:
  	visible = false


  func _on_boss_hp_changed(current_hp: float, max_hp: float) -> void:
  	if _bar and max_hp > 0:
  		_bar.value = current_hp / max_hp
  ```

- [ ] **Step 2: Commit**

  ```bash
  git add GoddessSurvivor/scripts/ui/boss_health_bar.gd
  git commit -m "feat(boss): add BossHealthBar UI with hp tracking"
  ```

---

## Task 6: 将 BossHealthBar 加入 main.tscn

**Files:**
- Modify: `GoddessSurvivor/scenes/main/main.tscn`

当前 `load_steps=13`。

- [ ] **Step 1: load_steps 从 13 改为 14**

  ```
  [gd_scene load_steps=14 format=3 uid="uid://bq1k8m4xvp2fn"]
  ```

- [ ] **Step 2: 在 ext_resource 末尾追加 BossHealthBar 引用**

  找到：
  ```
  [ext_resource type="Script" path="res://scripts/ui/wardrobe_panel.gd" id="12_wardrobe"]
  ```
  改为：
  ```
  [ext_resource type="Script" path="res://scripts/ui/wardrobe_panel.gd" id="12_wardrobe"]
  [ext_resource type="Script" path="res://scripts/ui/boss_health_bar.gd" id="13_boss_bar"]
  ```

- [ ] **Step 3: 在 WardrobePanel 节点之前插入 BossHealthBar**

  找到：
  ```
  [node name="WardrobePanel" type="CanvasLayer" parent="."]
  script = ExtResource("12_wardrobe")
  ```
  在其前插入：
  ```
  [node name="BossHealthBar" type="CanvasLayer" parent="."]
  script = ExtResource("13_boss_bar")
  ```

- [ ] **Step 4: Commit**

  ```bash
  git add GoddessSurvivor/scenes/main/main.tscn
  git commit -m "feat(boss): add BossHealthBar node to main.tscn"
  ```

---

## Task 7: 静态 Review + Push

- [ ] **Step 1: 验证 Boss 触发链**

  逐步追踪：
  1. `GameManager.elapsed_time >= 660.0` — `game_manager.gd:46` 每帧累加 `elapsed_time` ✓
  2. `EnemySpawner._spawn_boss()` — 新增方法，创建 `BossEnemy.new()` ✓
  3. `EventBus.boss_spawned.emit(boss)` — Task 1 声明信号，Task 4 emit ✓
  4. `BossHealthBar._on_boss_spawned` 连接 `boss.hp_changed` — Task 5 ✓
  5. `BossEnemy.take_damage` → `hp_changed.emit` — 继承自 `EnemyBase:135` ✓
  6. `BossEnemy._die()` 覆写 — 调用 `EventBus.boss_defeated.emit()` ✓
  7. `EnemySpawner` 监听 `boss_defeated` → `is_boss_alive = false` ✓
  8. `BossHealthBar` 监听 `boss_defeated` → `visible = false` ✓
  9. `_drop_exp()` 覆写 → 10×ExpGem + WardrobeChest ✓

- [ ] **Step 2: 验证无重入/无崩溃**

  - `BossEnemy._die()` 有 `if is_dead: return` 防重入（通过 `is_dead` 继承字段）✓
  - `_spawn_boss()` 由 `has_spawned_boss` 标志保护，只触发一次 ✓
  - `_warn_line` 在 `_die()` 和 `_execute_dash()` 都检查 `is_instance_valid` ✓

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
| `boss_defeated` 信号 | Task 1 |
| Boss 96×96 占位图 | Task 2 |
| BossEnemy：HP 5000、伤害 40、速度 60、击退免疫 | Task 3 |
| 冲刺攻击（警告线 0.5s → 冲刺 0.6s） | Task 3 `_start_dash/_execute_dash/_process_dash` |
| 弹幕圈（12 颗，伤害 25，速度 300） | Task 3 `_fire_bullet_ring/_spawn_boss_bullet` |
| `_drop_exp` 覆写：10×ExpGem scatter + WardrobeChest | Task 3 |
| EnemySpawner 11 分钟触发 | Task 4 |
| Boss 存活期间暂停普通生成 | Task 4 `if is_boss_alive: return` |
| boss_defeated 恢复普通生成 | Task 4 `EventBus.boss_defeated.connect` |
| BossHealthBar 顶部居中血条 | Task 5 |
| BossHealthBar 监听 boss_spawned/boss_defeated | Task 5 |
| main.tscn 加 BossHealthBar 节点 | Task 6 |

### Placeholder 扫描
无 TBD / TODO / "类似上方"。

### 类型一致性
- `BossEnemy` 继承 `EnemyBase`，`hp_changed` 信号定义在 `enemy_base.gd:8`，Task 5 connect 该信号 ✓
- `EventBus.boss_spawned(boss_node: Node)` — Task 4 emit 传 boss 实例（`Node` 兼容）✓
- `EventBus.boss_defeated()` — Task 1 定义无参，Task 3/4 emit 无参，Task 5 connect 无参 ✓
- `WardrobeChest` 类名来自 `scripts/pickups/wardrobe_chest.gd`，Task 3 直接 `.new()` ✓
- `ExpGem` 类名来自 `scripts/pickups/exp_gem.gd`，Task 3 直接 `.new()` ✓
- `PixelSpriteGenerator.create_boss_texture()` — Task 2 定义，Task 3 调用 ✓
