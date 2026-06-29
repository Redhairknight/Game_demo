## 敌人基类 - 所有敌人类型的父类
## 提供基础的追踪、生命值、受伤、掉落等功能
class_name EnemyBase
extends CharacterBody2D

# ===== 信号 =====
signal died(enemy: EnemyBase)
signal hp_changed(current_hp: float, max_hp: float)

# ===== 导出属性 =====
@export_group("基础属性")
@export var enemy_type: String = "normal"        # 敌人类型标识
@export var max_hp: float = 30.0                 # 最大生命值
@export var move_speed: float = 80.0             # 移动速度
@export var contact_damage: float = 10.0         # 接触伤害
@export var exp_value: int = 5                   # 死亡掉落经验值

@export_group("击退")
@export var knockback_resistance: float = 0.0    # 击退抗性 (0-1)
@export var knockback_decay: float = 800.0       # 击退衰减速度

@export_group("掉落")
@export var drop_scene: PackedScene = null       # 经验宝石场景

# ===== 节点引用 =====
@onready var sprite: Sprite2D = $Sprite2D
@onready var hitbox: Area2D = $Hitbox            # 对玩家造成伤害的区域
@onready var hurtbox: Area2D = $HurtBox          # 接受伤害的区域

# ===== 状态变量 =====
var current_hp: float
var is_dead: bool = false
var player_ref: CharacterBody2D = null           # 玩家引用
var knockback_velocity: Vector2 = Vector2.ZERO   # 击退速度
var speed_multiplier: float = 1.0                # 速度修正（受减速影响）
var is_taunted: bool = false                     # 是否被嘲讽
var taunt_target: Vector2 = Vector2.ZERO         # 嘲讽目标位置
var is_charmed: bool = false                     # 是否被魅惑
var defense_multiplier: float = 1.0              # 伤害接收倍率（<1 = 减伤）


func _ready() -> void:
	current_hp = max_hp
	add_to_group("enemies")

	# 获取玩家引用
	player_ref = GameManager.player_node

	# 设置像素纹理
	_setup_visual()

	# 连接碰撞信号
	if hitbox:
		hitbox.body_entered.connect(_on_hitbox_body_entered)


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# 处理移动
	_move_towards_player(delta)

	# 处理击退衰减
	_process_knockback(delta)

	# 最终移动
	move_and_slide()

	# 更新朝向
	_update_facing()


# ===== 移动逻辑 =====

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


## 处理击退衰减
func _process_knockback(delta: float) -> void:
	if knockback_velocity.length() > 0:
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_decay * delta)


## 更新面朝方向
func _update_facing() -> void:
	if sprite and velocity.x != 0:
		sprite.flip_h = velocity.x < 0


# ===== 伤害系统 =====

## 受到伤害
func take_damage(damage: float) -> void:
	if is_dead:
		return

	current_hp -= damage * defense_multiplier
	hp_changed.emit(current_hp, max_hp)

	# 受伤闪白效果
	_flash_white()

	# 检查死亡
	if current_hp <= 0:
		_die()


## 应用击退
func apply_knockback(force: Vector2) -> void:
	knockback_velocity = force * (1.0 - knockback_resistance)


## 应用减速
func apply_slow(slow_percent: float, duration: float) -> void:
	speed_multiplier = 1.0 - slow_percent
	# 创建计时器恢复速度
	var timer := get_tree().create_timer(duration)
	timer.timeout.connect(_on_slow_ended)


## 应用嘲讽（被吸引到某个位置）
func apply_taunt(target_position: Vector2, speed_reduction: float) -> void:
	is_taunted = true
	taunt_target = target_position
	speed_multiplier = 1.0 - speed_reduction


## 应用魅惑（被命中后攻击最近其他敌人）
func apply_charm(duration: float) -> void:
	is_charmed = true
	var timer := get_tree().create_timer(duration)
	timer.timeout.connect(func() -> void: is_charmed = false)


## 应用防御削减（amount=0.3 → 受到70%伤害）
func apply_defense_reduction(amount: float, duration: float) -> void:
	defense_multiplier = 1.0 - amount
	get_tree().create_timer(duration).timeout.connect(
		func() -> void: defense_multiplier = 1.0
	)


## 减速结束
func _on_slow_ended() -> void:
	if not is_taunted:
		speed_multiplier = 1.0


## 获取接触伤害（供玩家碰撞检测调用）
func get_contact_damage() -> float:
	return contact_damage


# ===== 死亡和掉落 =====

## 死亡处理
func _die() -> void:
	is_dead = true
	velocity = Vector2.ZERO

	# 发出事件
	died.emit(self)
	var enemy_data := {
		"enemy_type": enemy_type,
		"position": global_position,
		"exp_value": exp_value
	}
	EventBus.enemy_killed.emit(enemy_data)
	GameManager.add_kill()

	# 掉落经验宝石
	_drop_exp()

	# 死亡动画后删除
	_death_animation()


## 掉落经验宝石
func _drop_exp() -> void:
	var gem := ExpGem.new()
	gem.global_position = global_position
	gem.set_exp_value(exp_value)
	get_tree().current_scene.add_child(gem)


## 死亡动画
func _death_animation() -> void:
	if sprite:
		var tween := create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 0.2)
		tween.tween_callback(queue_free)
	else:
		queue_free()


## 受伤闪白效果
func _flash_white() -> void:
	if sprite:
		sprite.modulate = Color.RED
		var tween := create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.15)


# ===== 碰撞处理 =====

func _on_hitbox_body_entered(body: Node2D) -> void:
	if body is PlayerController:
		body.take_damage(contact_damage, self)


# ===== 视觉设置 =====

func _setup_visual() -> void:
	if sprite:
		sprite.texture = PixelSpriteGenerator.create_enemy_texture(enemy_type)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
