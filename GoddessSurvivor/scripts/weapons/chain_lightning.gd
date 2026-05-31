## 连锁闪电武器 - 对最近敌人释放可弹射的闪电
## 升级增加弹射次数和伤害
class_name ChainLightning
extends WeaponBase

# ===== 导出属性 =====
@export_group("闪电设置")
@export var chain_count: int = 3               # 弹射次数
@export var chain_range: float = 150.0         # 弹射搜索范围
@export var chain_damage_decay: float = 0.8    # 每次弹射伤害衰减
@export var attack_range: float = 300.0        # 初始攻击范围
@export var chain_delay: float = 0.1           # 弹射间延迟（视觉效果）

@export_group("升级加成")
@export var chains_per_2_levels: int = 1       # 每2级增加弹射次数
@export var range_per_level: float = 20.0      # 每级增加攻击范围

@export_group("视觉效果")
@export var lightning_color: Color = Color(0.5, 0.8, 1.0)  # 闪电颜色
@export var lightning_width: float = 3.0       # 闪电线条宽度

# ===== 初始化 =====
func _ready() -> void:
	super._ready()
	weapon_id = "chain_lightning"
	weapon_name = "连锁闪电"
	base_damage = 12.0
	base_cooldown = 1.2


# ===== 重写攻击逻辑 =====

func _try_attack() -> void:
	var current_range = attack_range + range_per_level * (current_level - 1)
	var target = _get_nearest_enemy_in_range(current_range)

	if target and is_ready:
		_execute_attack(target)
		_start_cooldown()
		weapon_fired.emit()


func _execute_attack(target: Node2D) -> void:
	# 执行连锁闪电
	var total_chains = chain_count + chains_per_2_levels * (current_level / 2)
	_execute_chain(target, total_chains, get_actual_damage())


## 获取范围内最近敌人
func _get_nearest_enemy_in_range(range_radius: float) -> Node2D:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var nearest_dist := INF

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist = global_position.distance_to(enemy.global_position)
		if dist < nearest_dist and dist <= range_radius:
			nearest_dist = dist
			nearest = enemy

	return nearest

## 执行连锁闪电
func _execute_chain(first_target: Node2D, max_chains: int, damage: float) -> void:
	var hit_enemies: Array[Node2D] = []
	var current_target = first_target
	var current_pos = global_position
	var current_damage_val = damage

	for i in range(max_chains + 1):  # +1 包含第一次攻击
		if not is_instance_valid(current_target):
			break

		# 造成伤害
		if current_target.has_method("take_damage"):
			current_target.take_damage(current_damage_val)
		hit_enemies.append(current_target)

		# 绘制闪电视觉效果
		_draw_lightning(current_pos, current_target.global_position)

		# 准备下一次弹射
		current_pos = current_target.global_position
		current_damage_val *= chain_damage_decay

		# 寻找下一个目标
		var next_target = _find_next_chain_target(current_target, hit_enemies)
		if not next_target:
			break
		current_target = next_target

		# 弹射延迟（视觉效果）
		if chain_delay > 0:
			await get_tree().create_timer(chain_delay).timeout

## 寻找下一个弹射目标
func _find_next_chain_target(current: Node2D, excluded: Array[Node2D]) -> Node2D:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var nearest_dist := INF

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy in excluded:
			continue
		var dist = current.global_position.distance_to(enemy.global_position)
		if dist < nearest_dist and dist <= chain_range:
			nearest_dist = dist
			nearest = enemy

	return nearest

## 绘制闪电视觉效果
func _draw_lightning(from_pos: Vector2, to_pos: Vector2) -> void:
	# 创建临时 Line2D 作为闪电视觉
	var line = Line2D.new()
	line.width = lightning_width
	line.default_color = lightning_color
	line.z_index = 10

	# 生成锯齿形闪电路径
	var points: PackedVector2Array = _generate_lightning_points(from_pos, to_pos)
	line.points = points

	get_tree().current_scene.add_child(line)

	# 闪电消失效果
	var tween = line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.3)
	tween.tween_callback(line.queue_free)

## 生成闪电锯齿路径点
func _generate_lightning_points(from: Vector2, to: Vector2) -> PackedVector2Array:
	var points: PackedVector2Array = []
	var segments = randi_range(4, 8)
	var direction = to - from
	var perpendicular = direction.rotated(PI / 2).normalized()

	points.append(from)

	for i in range(1, segments):
		var t = float(i) / segments
		var base_pos = from + direction * t
		var offset = perpendicular * randf_range(-15.0, 15.0)
		points.append(base_pos + offset)

	points.append(to)
	return points
