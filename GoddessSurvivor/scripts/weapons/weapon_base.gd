## 武器基类 - 所有自动武器的父类
## 提供冷却、等级、瞄准等基础功能
class_name WeaponBase
extends Node2D

# ===== 信号 =====
signal weapon_fired()
signal weapon_leveled_up(new_level: int)

# ===== 导出属性 =====
@export_group("基础属性")
@export var weapon_id: String = "base_weapon"    # 武器唯一标识
@export var weapon_name: String = "基础武器"      # 武器显示名称
@export var base_damage: float = 10.0            # 基础伤害
@export var base_cooldown: float = 1.5           # 基础冷却时间（秒）
@export var max_level: int = 8                   # 最大等级

@export_group("升级加成")
@export var damage_per_level: float = 3.0        # 每级伤害增加
@export var cooldown_reduction: float = 0.1      # 每级冷却减少（秒）

# ===== 状态变量 =====
var current_level: int = 1
var current_cooldown: float = 0.0
var is_ready: bool = true                        # 是否可以攻击
var player_ref: CharacterBody2D = null           # 玩家引用


func _ready() -> void:
	# 获取玩家引用（武器应该是玩家的子节点）
	player_ref = get_parent() as CharacterBody2D
	if not player_ref:
		# 尝试向上查找
		var parent := get_parent()
		while parent and not parent is CharacterBody2D:
			parent = parent.get_parent()
		player_ref = parent as CharacterBody2D


func _process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	# 冷却计时
	if not is_ready:
		current_cooldown -= delta
		if current_cooldown <= 0.0:
			is_ready = true

	# 尝试攻击
	if is_ready:
		_try_attack()


# ===== 攻击逻辑（子类重写） =====

## 尝试攻击 - 子类重写此方法实现具体攻击逻辑
func _try_attack() -> void:
	var target := _find_nearest_enemy()
	if target:
		_execute_attack(target)
		_start_cooldown()
		weapon_fired.emit()


## 执行攻击 - 子类重写
func _execute_attack(_target: Node2D) -> void:
	pass  # 子类实现具体攻击行为


# ===== 冷却系统 =====

## 开始冷却
func _start_cooldown() -> void:
	is_ready = false
	current_cooldown = get_actual_cooldown()


## 获取实际冷却时间（考虑等级减少）
func get_actual_cooldown() -> float:
	var cd := base_cooldown - (current_level - 1) * cooldown_reduction
	return maxf(cd, 0.2)  # 最低0.2秒


# ===== 伤害计算 =====

## 获取实际伤害（考虑等级和衣着加成）
func get_actual_damage() -> float:
	var dmg := base_damage + (current_level - 1) * damage_per_level

	# 获取衣着系统的攻击加成
	if player_ref:
		var clothing := player_ref.get_node_or_null("ClothingSystem") as ClothingSystem
		if clothing:
			dmg *= clothing.get_attack_multiplier()

	return dmg


# ===== 升级 =====

## 升级武器
func level_up() -> void:
	if current_level >= max_level:
		return

	current_level += 1
	weapon_leveled_up.emit(current_level)
	EventBus.weapon_upgraded.emit(weapon_id, current_level)
	print("[%s] 升级到 Lv.%d" % [weapon_name, current_level])


## 是否已满级
func is_max_level() -> bool:
	return current_level >= max_level


# ===== 瞄准系统 =====

## 查找最近的敌人
func _find_nearest_enemy() -> Node2D:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var nearest_dist := INF

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist := global_position.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy

	return nearest


## 查找范围内的所有敌人
func _find_enemies_in_range(range_radius: float) -> Array[Node2D]:
	var result: Array[Node2D] = []
	var enemies := get_tree().get_nodes_in_group("enemies")

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist := global_position.distance_to(enemy.global_position)
		if dist <= range_radius:
			result.append(enemy)

	return result


## 获取武器信息字典（用于UI显示）
func get_weapon_info() -> Dictionary:
	return {
		"id": weapon_id,
		"name": weapon_name,
		"level": current_level,
		"max_level": max_level,
		"damage": get_actual_damage(),
		"cooldown": get_actual_cooldown()
	}
