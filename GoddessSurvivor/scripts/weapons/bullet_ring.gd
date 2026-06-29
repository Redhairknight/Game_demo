## 弹幕环 - 围绕玩家旋转发射弹幕
## 升级增加弹幕数量和伤害
class_name BulletRing
extends WeaponBase

# ===== 导出属性 =====
@export_group("弹幕环设置")
@export var bullet_scene: PackedScene = null      # 弹幕场景
@export var ring_radius: float = 60.0             # 环半径
@export var rotation_speed: float = 2.0           # 旋转速度（弧度/秒）
@export var base_bullet_count: int = 3            # 基础弹幕数量
@export var bullets_per_level: int = 1            # 每级增加弹幕数
@export var bullet_speed: float = 400.0           # 弹幕飞行速度
@export var bullet_lifetime: float = 2.0          # 弹幕存活时间
@export var fire_range: float = 500.0             # 射程范围

# ===== 状态变量 =====
var current_rotation: float = 0.0                 # 当前旋转角度
var is_awakened: bool = false                      # 是否处于觉醒形态
var _homing_bullets: Array[Area2D] = []           # 追踪弹幕列表


func _ready() -> void:
	super._ready()
	weapon_id = "bullet_ring"
	weapon_name = "弹幕环"
	base_damage = 8.0
	base_cooldown = 1.2


func _process(delta: float) -> void:
	super._process(delta)

	if GameManager.current_state == GameManager.GameState.PLAYING:
		current_rotation += rotation_speed * delta
		_update_homing_bullets(delta)


## 每帧更新追踪弹幕朝向
func _update_homing_bullets(delta: float) -> void:
	var to_remove: Array[Area2D] = []
	for bullet in _homing_bullets:
		if not is_instance_valid(bullet):
			to_remove.append(bullet)
			continue
		var enemies := get_tree().get_nodes_in_group("enemies")
		var nearest: Node2D = null
		var nd := INF
		for e in enemies:
			if is_instance_valid(e):
				var d := bullet.global_position.distance_to(e.global_position)
				if d < nd:
					nd = d
					nearest = e
		if nearest:
			var dir := (nearest.global_position - bullet.global_position).normalized()
			bullet.global_position += dir * bullet_speed * delta
	for b in to_remove:
		_homing_bullets.erase(b)


# ===== 重写攻击逻辑 =====

func _try_attack() -> void:
	var enemies := _find_enemies_in_range(fire_range)
	if enemies.size() > 0 and is_ready:
		_execute_attack(null)
		_start_cooldown()
		weapon_fired.emit()


func _execute_attack(_target: Node2D) -> void:
	_fire_ring()


## 发射一圈弹幕
func _fire_ring() -> void:
	var bullet_count := get_bullet_count()
	var angle_step := TAU / bullet_count

	for i in range(bullet_count):
		var angle := current_rotation + i * angle_step
		var spawn_offset := Vector2(cos(angle), sin(angle)) * ring_radius
		var spawn_pos := global_position + spawn_offset
		var direction := Vector2(cos(angle), sin(angle))
		_spawn_bullet(spawn_pos, direction)


## 生成单个弹幕
func _spawn_bullet(pos: Vector2, direction: Vector2) -> void:
	if not bullet_scene:
		_spawn_simple_bullet(pos, direction)
		return

	var bullet := bullet_scene.instantiate()
	bullet.global_position = pos
	if bullet.has_method("setup"):
		bullet.setup(direction, bullet_speed, get_actual_damage(), bullet_lifetime)
	get_tree().current_scene.add_child(bullet)


## 简易弹幕（无需场景）
func _spawn_simple_bullet(pos: Vector2, direction: Vector2) -> void:
	var bullet := Area2D.new()
	bullet.global_position = pos
	bullet.add_to_group("player_projectiles")

	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 5.0
	collision.shape = shape
	bullet.add_child(collision)

	var visual := Sprite2D.new()
	if is_awakened:
		visual.texture = PixelSpriteGenerator.create_heart_bullet_texture()
		visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bullet.add_child(visual)

	bullet.collision_layer = 8
	bullet.collision_mask = 2

	get_tree().current_scene.add_child(bullet)

	# 判断是否追踪（阶段2特效 homing_bullets）
	var is_homing := player_ref != null and "active_specials" in player_ref \
		and (player_ref as PlayerController).active_specials.has("homing_bullets")

	if is_homing:
		_homing_bullets.append(bullet)
		var timer := get_tree().create_timer(bullet_lifetime)
		timer.timeout.connect(func() -> void:
			_homing_bullets.erase(bullet)
			if is_instance_valid(bullet):
				bullet.queue_free()
		)
	else:
		var tween := bullet.create_tween()
		var end_pos := pos + direction * bullet_speed * bullet_lifetime
		tween.tween_property(bullet, "global_position", end_pos, bullet_lifetime)
		tween.tween_callback(bullet.queue_free)

	var awakened := is_awakened
	bullet.area_entered.connect(func(area: Area2D) -> void:
		if area.is_in_group("enemy_hurtbox"):
			var enemy := area.get_parent()
			if enemy and enemy.has_method("take_damage"):
				enemy.take_damage(get_actual_damage())
				if awakened and enemy.has_method("apply_charm") and randf() < 0.3:
					enemy.apply_charm(3.0)
			_homing_bullets.erase(bullet)
			bullet.queue_free()
	)
	bullet.body_entered.connect(func(body: Node2D) -> void:
		if body.is_in_group("enemies") and body.has_method("take_damage"):
			body.take_damage(get_actual_damage())
			if awakened and body.has_method("apply_charm") and randf() < 0.3:
				body.apply_charm(3.0)
			_homing_bullets.erase(bullet)
			bullet.queue_free()
	)


## 获取当前弹幕数量
func get_bullet_count() -> int:
	return base_bullet_count + (current_level - 1) * bullets_per_level


## 触发觉醒形态（由 SynergySystem 调用，只触发一次）
func awaken() -> void:
	is_awakened = true
