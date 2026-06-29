## 玩家控制器 - 挂载在 CharacterBody2D 节点上
## 处理移动、受伤、面朝方向等核心玩家逻辑
class_name PlayerController
extends CharacterBody2D

# ===== 信号 =====
signal hp_changed(current_hp: float, max_hp: float)
signal died()

# ===== 导出属性 =====
@export_group("移动")
@export var move_speed: float = 200.0           # 基础移动速度
@export var acceleration: float = 1500.0         # 加速度
@export var friction: float = 1200.0             # 摩擦力（减速）

@export_group("生命值")
@export var max_hp: float = 100.0               # 最大生命值
@export var invincible_time: float = 0.5         # 受伤无敌时间
@export var flash_interval: float = 0.1          # 闪烁间隔

@export_group("拾取")
@export var pickup_range: float = 80.0           # 拾取范围

# ===== 节点引用 =====
@onready var sprite: Sprite2D = $Sprite2D
@onready var pickup_area: Area2D = $PickupArea
@onready var hurtbox: Area2D = $Hurtbox
@onready var invincible_timer: Timer = $InvincibleTimer
@onready var animation_player: AnimationPlayer = null  # 暂无动画，后续添加

# ===== 状态变量 =====
var current_hp: float
var is_invincible: bool = false
var is_dead: bool = false
var can_move: bool = true                # 是否可以移动（挑逗蓄力时为false）
var speed_multiplier: float = 1.0        # 速度修正系数
var damage_multiplier: float = 1.0       # 全局伤害倍率
var cooldown_multiplier: float = 1.0     # 全局冷却倍率（<1 = 更快）
var nearest_enemy: Node2D = null         # 最近的敌人引用
var facing_direction: Vector2 = Vector2.RIGHT  # 面朝方向


func _ready() -> void:
	current_hp = max_hp
	_setup_pickup_area()
	_setup_timers()

	# 注册到GameManager
	GameManager.player_node = self

	# 连接信号
	if hurtbox:
		hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	if pickup_area:
		pickup_area.area_entered.connect(_on_pickup_area_entered)


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# 处理移动
	if can_move:
		_handle_movement(delta)
	else:
		# 不能移动时施加摩擦力使角色停下
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	move_and_slide()

	# 更新面朝方向（朝向最近敌人）
	_update_facing_direction()


# ===== 移动处理 =====

func _handle_movement(delta: float) -> void:
	# 获取输入方向
	var input_dir := Vector2.ZERO
	input_dir.x = Input.get_axis("move_left", "move_right")
	input_dir.y = Input.get_axis("move_up", "move_down")

	# 归一化防止对角线移动更快
	if input_dir.length() > 1.0:
		input_dir = input_dir.normalized()

	# 应用移动
	if input_dir != Vector2.ZERO:
		var target_velocity := input_dir * move_speed * speed_multiplier
		velocity = velocity.move_toward(target_velocity, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)


# ===== 面朝方向 =====

func _update_facing_direction() -> void:
	# 优先朝向最近敌人
	if is_instance_valid(nearest_enemy):
		facing_direction = (nearest_enemy.global_position - global_position).normalized()
	elif velocity.length() > 10.0:
		facing_direction = velocity.normalized()

	# 翻转精灵
	if sprite:
		sprite.flip_h = facing_direction.x < 0


## 更新最近敌人引用（由外部敌人管理器调用或定时更新）
func update_nearest_enemy(enemy: Node2D) -> void:
	nearest_enemy = enemy


# ===== 生命值管理 =====

## 受到伤害
func take_damage(damage: float, source: Node = null) -> void:
	if is_invincible or is_dead:
		return

	current_hp = clampf(current_hp - damage, 0.0, max_hp)
	hp_changed.emit(current_hp, max_hp)
	EventBus.player_damaged.emit(damage, source)

	# 启动无敌时间
	_start_invincibility()

	# 受伤闪烁
	_flash_effect()

	# 检查死亡
	if current_hp <= 0:
		_die()


## 治疗
func heal(amount: float) -> void:
	if is_dead:
		return
	current_hp = clampf(current_hp + amount, 0.0, max_hp)
	hp_changed.emit(current_hp, max_hp)
	EventBus.player_healed.emit(amount)


## 死亡处理
func _die() -> void:
	is_dead = true
	can_move = false
	velocity = Vector2.ZERO
	died.emit()
	EventBus.player_died.emit()
	GameManager.end_game()

	# 播放死亡动画（如果有）
	if animation_player and animation_player.has_animation("death"):
		animation_player.play("death")


# ===== 无敌和闪烁 =====

func _start_invincibility() -> void:
	is_invincible = true
	invincible_timer.start(invincible_time)


func _flash_effect() -> void:
	# 简单的闪烁效果
	if sprite:
		var tween := create_tween()
		for i in range(int(invincible_time / flash_interval)):
			tween.tween_property(sprite, "modulate:a", 0.3, flash_interval / 2)
			tween.tween_property(sprite, "modulate:a", 1.0, flash_interval / 2)


func _on_invincible_timer_timeout() -> void:
	is_invincible = false
	if sprite:
		sprite.modulate.a = 1.0


# ===== 拾取系统 =====

func _setup_pickup_area() -> void:
	if pickup_area:
		# 动态设置拾取范围
		var collision := pickup_area.get_node_or_null("CollisionShape2D")
		if collision and collision.shape is CircleShape2D:
			collision.shape.radius = pickup_range


func _on_pickup_area_entered(area: Area2D) -> void:
	# 拾取进入范围的物品
	if area.has_method("collect"):
		area.collect(self)


# ===== 碰撞伤害 =====

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy_hitbox"):
		var damage := 10.0  # 默认碰撞伤害
		if area.has_method("get_contact_damage"):
			damage = area.get_contact_damage()
		take_damage(damage, area.get_parent())


# ===== 工具方法 =====

func _setup_timers() -> void:
	if not invincible_timer:
		invincible_timer = Timer.new()
		invincible_timer.name = "InvincibleTimer"
		invincible_timer.one_shot = true
		add_child(invincible_timer)
	invincible_timer.timeout.connect(_on_invincible_timer_timeout)


## 设置是否可以移动（用于挑逗系统锁定移动）
func set_can_move(value: bool) -> void:
	can_move = value
	if not value:
		velocity = Vector2.ZERO


## 获取当前HP百分比
func get_hp_percent() -> float:
	return current_hp / max_hp
