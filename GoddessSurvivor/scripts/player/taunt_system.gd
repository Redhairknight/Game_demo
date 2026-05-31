## 挑逗系统 - 作为子节点挂载在玩家身上
## 按住E键蓄力，释放时根据蓄力等级产生不同AOE效果
class_name TauntSystem
extends Node

# ===== 信号 =====
signal charge_started()
signal charge_level_changed(level: int)
signal charge_released(level: int)
signal charge_interrupted()

# ===== 蓄力等级枚举 =====
enum ChargeLevel {
	NONE = 0,     # 未蓄力
	SMALL = 1,    # 1秒 - 小击退
	MEDIUM = 2,   # 2秒 - 中伤害+减速
	FULL = 3      # 3秒 - 满蓄大范围秒杀
}

# ===== 导出属性 =====
@export_group("蓄力设置")
@export var charge_time_small: float = 1.0       # 达到1档所需时间
@export var charge_time_medium: float = 2.0      # 达到2档所需时间
@export var charge_time_full: float = 3.0        # 达到满蓄所需时间
@export var durability_cost_per_sec: float = 1.0 # 蓄力期间每秒消耗衣着耐久度

@export_group("效果范围")
@export var range_small: float = 100.0           # 1档效果范围
@export var range_medium: float = 180.0          # 2档效果范围
@export var range_full: float = 300.0            # 满蓄效果范围

@export_group("伤害设置")
@export var damage_medium: float = 50.0          # 2档伤害
@export var knockback_force_small: float = 200.0 # 1档击退力度
@export var slow_duration: float = 3.0           # 减速持续时间
@export var slow_amount: float = 0.5             # 减速比例 (50%)

@export_group("嘲讽效果")
@export var taunt_range: float = 250.0           # 蓄力期间嘲讽吸引范围
@export var taunt_speed_reduction: float = 0.5   # 被嘲讽敌人移速降低50%

# ===== 状态变量 =====
var is_charging: bool = false
var charge_time: float = 0.0
var current_charge_level: ChargeLevel = ChargeLevel.NONE
var player: PlayerController = null
var clothing_system: ClothingSystem = null

# ===== 节点引用 =====
var taunt_area: Area2D = null  # 嘲讽吸引范围，从玩家获取


func _ready() -> void:
	# 获取父节点（玩家控制器）
	player = get_parent() as PlayerController
	if not player:
		push_error("[TauntSystem] 必须作为PlayerController的子节点!")
		return

	# 获取衣着系统引用
	clothing_system = player.get_node_or_null("ClothingSystem") as ClothingSystem

	# 获取嘲讽区域（在Player下）
	taunt_area = player.get_node_or_null("TauntArea") as Area2D

	# 设置嘲讽区域
	_setup_taunt_area()


func _process(delta: float) -> void:
	if not player or player.is_dead:
		return

	# 检测E键输入
	if Input.is_action_just_pressed("taunt") and not is_charging:
		_start_charging()
	elif Input.is_action_pressed("taunt") and is_charging:
		_update_charging(delta)
	elif Input.is_action_just_released("taunt") and is_charging:
		_release_charge()


# ===== 蓄力逻辑 =====

## 开始蓄力
func _start_charging() -> void:
	is_charging = true
	charge_time = 0.0
	current_charge_level = ChargeLevel.NONE

	# 锁定玩家移动
	player.set_can_move(false)

	# 发出信号
	charge_started.emit()
	EventBus.taunt_charge_started.emit()

	print("[TauntSystem] 开始蓄力")


## 更新蓄力状态
func _update_charging(delta: float) -> void:
	charge_time += delta

	# 消耗衣着耐久度
	if clothing_system:
		clothing_system.reduce_durability(durability_cost_per_sec * delta)

	# 更新蓄力等级
	var new_level := _get_charge_level()
	if new_level != current_charge_level:
		current_charge_level = new_level
		charge_level_changed.emit(int(current_charge_level))

	# 嘲讽周围敌人（吸引并减速）
	_apply_taunt_effect()


## 释放蓄力
func _release_charge() -> void:
	var release_level := _get_charge_level()

	# 执行对应等级的AOE效果
	match release_level:
		ChargeLevel.SMALL:
			_execute_small_release()
		ChargeLevel.MEDIUM:
			_execute_medium_release()
		ChargeLevel.FULL:
			_execute_full_release()
		ChargeLevel.NONE:
			pass  # 蓄力时间不足，无效果

	# 满蓄释放时衣着降一阶段
	if release_level == ChargeLevel.FULL and clothing_system:
		clothing_system.force_stage_down()

	# 重置状态
	_end_charging()

	# 发出信号
	charge_released.emit(int(release_level))
	EventBus.taunt_released.emit(int(release_level), player.global_position)

	print("[TauntSystem] 释放蓄力 - 等级: %d" % int(release_level))


## 被攻击打断
func interrupt() -> void:
	if not is_charging:
		return

	_end_charging()
	charge_interrupted.emit()
	EventBus.taunt_interrupted.emit()
	print("[TauntSystem] 蓄力被打断!")


## 结束蓄力状态（通用清理）
func _end_charging() -> void:
	is_charging = false
	charge_time = 0.0
	current_charge_level = ChargeLevel.NONE

	# 恢复玩家移动
	player.set_can_move(true)


# ===== 蓄力等级判定 =====

func _get_charge_level() -> ChargeLevel:
	if charge_time >= charge_time_full:
		return ChargeLevel.FULL
	elif charge_time >= charge_time_medium:
		return ChargeLevel.MEDIUM
	elif charge_time >= charge_time_small:
		return ChargeLevel.SMALL
	else:
		return ChargeLevel.NONE


# ===== AOE效果执行 =====

## 1档：小范围击退
func _execute_small_release() -> void:
	var enemies := _get_enemies_in_range(range_small)
	for enemy in enemies:
		if enemy.has_method("apply_knockback"):
			var dir: Vector2 = (enemy.global_position - player.global_position).normalized()
			enemy.apply_knockback(dir * knockback_force_small)


## 2档：中范围伤害 + 减速
func _execute_medium_release() -> void:
	var enemies := _get_enemies_in_range(range_medium)
	for enemy in enemies:
		if enemy.has_method("take_damage"):
			enemy.take_damage(damage_medium)
		if enemy.has_method("apply_slow"):
			enemy.apply_slow(slow_amount, slow_duration)


## 3档满蓄：大范围秒杀
func _execute_full_release() -> void:
	var enemies := _get_enemies_in_range(range_full)
	for enemy in enemies:
		if enemy.has_method("take_damage"):
			# 秒杀 - 施加极大伤害
			enemy.take_damage(99999.0)


# ===== 嘲讽吸引效果 =====

func _apply_taunt_effect() -> void:
	# 获取嘲讽范围内的敌人
	if not taunt_area:
		return

	var bodies := taunt_area.get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("enemies"):
			# 应用减速和吸引效果
			if body.has_method("apply_taunt"):
				body.apply_taunt(player.global_position, taunt_speed_reduction)


# ===== 辅助方法 =====

func _get_enemies_in_range(range_radius: float) -> Array:
	var enemies: Array = []
	var all_enemies := get_tree().get_nodes_in_group("enemies")
	for enemy in all_enemies:
		if is_instance_valid(enemy):
			var dist := player.global_position.distance_to(enemy.global_position)
			if dist <= range_radius:
				enemies.append(enemy)
	return enemies


func _setup_taunt_area() -> void:
	if taunt_area:
		var collision := taunt_area.get_node_or_null("CollisionShape2D")
		if collision and collision.shape is CircleShape2D:
			collision.shape.radius = taunt_range


## 获取蓄力进度 (0.0 - 1.0)
func get_charge_progress() -> float:
	return clampf(charge_time / charge_time_full, 0.0, 1.0)
