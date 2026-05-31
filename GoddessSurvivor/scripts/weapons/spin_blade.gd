## 旋转刀刃 - 围绕玩家高速旋转的刀片
## 持续对接触的敌人造成伤害
class_name SpinBlade
extends WeaponBase

# ===== 导出属性 =====
@export_group("旋转刀刃设置")
@export var base_blade_count: int = 2            # 基础刀片数量
@export var blades_per_level: int = 1            # 每级增加刀片数
@export var orbit_radius: float = 80.0           # 公转半径
@export var orbit_speed: float = 4.0             # 公转速度（弧度/秒）
@export var radius_per_level: float = 10.0       # 每级增加半径
@export var blade_size: float = 20.0             # 刀片碰撞大小
@export var hit_cooldown: float = 0.3            # 对同一敌人的伤害间隔

# ===== 状态变量 =====
var current_angle: float = 0.0
var blade_areas: Array[Area2D] = []              # 刀片区域节点
var hit_timers: Dictionary = {}                  # 记录对每个敌人的伤害冷却


func _ready() -> void:
	super._ready()
	weapon_id = "spin_blade"
	weapon_name = "旋转刀刃"
	base_damage = 15.0
	base_cooldown = 0.0  # 旋转刀刃无冷却，持续伤害

	# 创建刀片
	_create_blades()


func _process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	# 旋转
	current_angle += orbit_speed * delta

	# 更新刀片位置
	_update_blade_positions()

	# 清理过期的伤害冷却记录
	_cleanup_hit_timers(delta)


# ===== 重写攻击逻辑 =====

## 旋转刀刃是持续性武器，不需要主动攻击
func _try_attack() -> void:
	pass  # 通过碰撞检测处理伤害


# ===== 刀片管理 =====

## 创建刀片节点
func _create_blades() -> void:
	# 清除旧刀片
	for blade in blade_areas:
		if is_instance_valid(blade):
			blade.queue_free()
	blade_areas.clear()

	# 创建新刀片
	var count := get_blade_count()
	for i in range(count):
		var blade := _create_single_blade()
		blade_areas.append(blade)
		add_child(blade)


## 创建单个刀片区域
func _create_single_blade() -> Area2D:
	var blade := Area2D.new()
	blade.collision_layer = 8  # Layer 4: Weapons
	blade.collision_mask = 2   # Layer 2: Enemies
	blade.add_to_group("player_weapons")

	# 碰撞形状
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = blade_size
	collision.shape = shape
	blade.add_child(collision)

	# 连接碰撞信号
	blade.body_entered.connect(_on_blade_hit_enemy)
	blade.area_entered.connect(_on_blade_hit_area)

	return blade


## 更新刀片位置
func _update_blade_positions() -> void:
	var count := blade_areas.size()
	if count == 0:
		return

	var actual_radius := get_actual_radius()
	var angle_step := TAU / count

	for i in range(count):
		if not is_instance_valid(blade_areas[i]):
			continue
		var angle := current_angle + i * angle_step
		blade_areas[i].position = Vector2(cos(angle), sin(angle)) * actual_radius


# ===== 伤害处理 =====

## 刀片碰到敌人Body
func _on_blade_hit_enemy(body: Node2D) -> void:
	if body.is_in_group("enemies") and body.has_method("take_damage"):
		_deal_damage_to(body)


## 刀片碰到敌人Area
func _on_blade_hit_area(area: Area2D) -> void:
	if area.is_in_group("enemy_hurtbox"):
		var enemy := area.get_parent()
		if enemy and enemy.has_method("take_damage"):
			_deal_damage_to(enemy)


## 对敌人造成伤害（带冷却）
func _deal_damage_to(enemy: Node2D) -> void:
	var enemy_id := enemy.get_instance_id()

	# 检查冷却
	if hit_timers.has(enemy_id) and hit_timers[enemy_id] > 0.0:
		return

	# 造成伤害
	enemy.take_damage(get_actual_damage())
	hit_timers[enemy_id] = hit_cooldown


## 清理伤害冷却计时器
func _cleanup_hit_timers(delta: float) -> void:
	var to_remove: Array = []
	for enemy_id in hit_timers:
		hit_timers[enemy_id] -= delta
		if hit_timers[enemy_id] <= 0.0:
			to_remove.append(enemy_id)

	for key in to_remove:
		hit_timers.erase(key)


# ===== 升级 =====

## 重写升级，需要重新创建刀片
func level_up() -> void:
	super.level_up()
	_create_blades()  # 重建刀片以增加数量


# ===== 属性计算 =====

## 获取当前刀片数量
func get_blade_count() -> int:
	return base_blade_count + (current_level - 1) * blades_per_level


## 获取实际旋转半径
func get_actual_radius() -> float:
	return orbit_radius + (current_level - 1) * radius_per_level
