## Boss 敌人 - 继承 EnemyBase，拥有冲刺和弹幕圈两种攻击
## 通过代码直接实例化，内部手动创建所需子节点
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

# ===== 攻击状态 =====
var _dash_timer: float = DASH_INTERVAL
var _bullet_timer: float = 3.0
var _is_dashing: bool = false
var _dash_target: Vector2 = Vector2.ZERO
var _dash_elapsed: float = 0.0
var _warn_line: Line2D = null


func _ready() -> void:
	# 在父类 _ready 之前，手动创建场景节点
	_build_nodes()

	# 设置 Boss 属性（父类 _ready 会读 max_hp/contact_damage 等）
	enemy_type = "boss"
	max_hp = BOSS_HP
	contact_damage = BOSS_DAMAGE
	move_speed = BOSS_SPEED
	knockback_resistance = 1.0
	exp_value = 0

	# 调用父类初始化（会设置 current_hp、add_to_group、连接 hitbox 等）
	super._ready()

	# Boss 体型放大（父类 _ready 之后设置，不影响碰撞形状）
	scale = Vector2(3.0, 3.0)

	# 设置 Boss 纹理（覆盖父类 _setup_visual 的结果）
	if sprite:
		sprite.texture = PixelSpriteGenerator.create_boss_texture()
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	print("[BossEnemy] Boss 已生成，HP: %.0f" % BOSS_HP)


## 手动创建 EnemyBase 依赖的子节点（脚本直接 .new() 时无场景树）
func _build_nodes() -> void:
	# Sprite2D
	var spr := Sprite2D.new()
	spr.name = "Sprite2D"
	add_child(spr)

	# 碰撞形状
	var col_shape := CollisionShape2D.new()
	col_shape.name = "CollisionShape2D"
	var circle := CircleShape2D.new()
	circle.radius = 20.0
	col_shape.shape = circle
	add_child(col_shape)

	# Hitbox（对玩家造成伤害）
	var hitbox_node := Area2D.new()
	hitbox_node.name = "Hitbox"
	hitbox_node.collision_layer = 2
	hitbox_node.collision_mask = 1
	var hb_col := CollisionShape2D.new()
	var hb_rect := RectangleShape2D.new()
	hb_rect.size = Vector2(40, 40)
	hb_col.shape = hb_rect
	hitbox_node.add_child(hb_col)
	add_child(hitbox_node)

	# HurtBox（接受武器伤害）
	var hurtbox_node := Area2D.new()
	hurtbox_node.name = "HurtBox"
	hurtbox_node.collision_layer = 2
	hurtbox_node.collision_mask = 8
	var hurt_col := CollisionShape2D.new()
	var hurt_rect := RectangleShape2D.new()
	hurt_rect.size = Vector2(40, 40)
	hurt_col.shape = hurt_rect
	hurtbox_node.add_child(hurt_col)
	add_child(hurtbox_node)

	# 物理碰撞（CharacterBody2D 自身）
	collision_layer = 2
	collision_mask = 1


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
		player_ref = GameManager.player_node
	if not is_instance_valid(player_ref):
		return

	_dash_target = player_ref.global_position

	# 红色警告线
	_warn_line = Line2D.new()
	_warn_line.default_color = Color(1.0, 0.0, 0.0, 0.7)
	_warn_line.width = 4.0
	_warn_line.z_index = 5
	_warn_line.add_point(global_position)
	_warn_line.add_point(_dash_target)
	get_tree().current_scene.add_child(_warn_line)

	# 0.5s 后执行冲刺
	get_tree().create_timer(DASH_WARN_DURATION).timeout.connect(_execute_dash)


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
		_spawn_boss_bullet(global_position, Vector2(cos(angle), sin(angle)))


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
	tween.tween_property(bullet, "global_position", pos + direction * BULLET_SPEED * BULLET_LIFETIME, BULLET_LIFETIME)
	tween.tween_callback(bullet.queue_free)

	bullet.body_entered.connect(func(body: Node2D) -> void:
		if body is PlayerController:
			body.take_damage(BULLET_DAMAGE, self)
			bullet.queue_free()
	)


# ===== 覆写掉落（scatter exp + 换装宝箱）=====

func _drop_exp() -> void:
	for i in range(10):
		var gem := ExpGem.new()
		gem.global_position = global_position + Vector2(randf_range(-80, 80), randf_range(-80, 80))
		gem.set_exp_value(10)
		get_tree().current_scene.add_child(gem)

	var chest := WardrobeChest.new()
	chest.global_position = global_position
	get_tree().current_scene.add_child(chest)


# ===== 覆写死亡 =====

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
		_warn_line = null

	# 死亡动画
	if sprite:
		var tween := create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
		tween.tween_callback(queue_free)
	else:
		queue_free()

	print("[BossEnemy] Boss 被击败!")
