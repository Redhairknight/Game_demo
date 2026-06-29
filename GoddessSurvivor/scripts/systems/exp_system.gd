## 经验系统 - 管理经验收集、等级计算、升级选项生成
## 挂载在玩家节点上或作为独立系统
class_name ExpSystem
extends Node

# ===== 信号 =====
signal exp_changed(current_exp: int, needed_exp: int)
signal leveled_up(new_level: int)

# ===== 导出属性 =====
@export_group("经验曲线")
@export var base_exp_needed: int = 10             # 1级升2级所需经验
@export var exp_growth_rate: float = 1.2          # 经验需求增长率
@export var max_level: int = 50                   # 最大等级

@export_group("升级选项概率")
@export var weapon_chance: float = 0.40           # 武器选项概率 40%
@export var passive_chance: float = 0.30          # 被动选项概率 30%
@export var liberation_chance: float = 0.20       # 解放选项概率 20%
@export var special_chance: float = 0.10          # 特殊选项概率 10%

@export_group("选项设置")
@export var options_count: int = 3                # 每次升级显示的选项数量

# ===== 状态变量 =====
var current_level: int = 1
var current_exp: int = 0
var exp_to_next_level: int = 10

# ===== 升级选项类型 =====
enum OptionType {
	WEAPON,      # 武器升级/新武器
	PASSIVE,     # 被动增益
	LIBERATION,  # 解放技能
	SPECIAL      # 特殊选项
}


func _ready() -> void:
	exp_to_next_level = base_exp_needed

	# 连接事件总线
	EventBus.exp_collected.connect(_on_exp_collected)
	EventBus.enemy_killed.connect(_on_enemy_killed)


# ===== 经验收集 =====

## 收集经验值
func add_exp(amount: int) -> void:
	current_exp += amount
	GameManager.add_exp(amount)
	exp_changed.emit(current_exp, exp_to_next_level)

	# 检查升级
	while current_exp >= exp_to_next_level:
		_level_up()


## 事件：经验被收集
func _on_exp_collected(amount: int) -> void:
	add_exp(amount)


## 事件：敌人被击杀（自动获得经验）
func _on_enemy_killed(enemy_data: Dictionary) -> void:
	# 经验由宝石收集处理，这里不重复加
	pass


# ===== 升级逻辑 =====

## 执行升级
func _level_up() -> void:
	current_exp -= exp_to_next_level
	current_level += 1
	exp_to_next_level = _calculate_exp_needed(current_level)

	GameManager.current_level = current_level
	leveled_up.emit(current_level)
	EventBus.level_up.emit(current_level)

	# 暂停游戏并显示升级面板
	GameManager.enter_level_up()

	print("[ExpSystem] 升级! Lv.%d -> Lv.%d | 下一级需要: %d" % [current_level - 1, current_level, exp_to_next_level])


## 计算指定等级所需经验
func _calculate_exp_needed(level: int) -> int:
	return int(base_exp_needed * pow(exp_growth_rate, level - 1))


# ===== 升级选项生成 =====

## 生成升级选项数组
func generate_level_up_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []

	for i in range(options_count):
		var option := _generate_single_option()
		# 避免重复选项
		var attempts := 0
		while _is_duplicate(option, options) and attempts < 10:
			option = _generate_single_option()
			attempts += 1
		options.append(option)

	return options


## 生成单个选项
func _generate_single_option() -> Dictionary:
	var option_type := _roll_option_type()

	match option_type:
		OptionType.WEAPON:
			return _generate_weapon_option()
		OptionType.PASSIVE:
			return _generate_passive_option()
		OptionType.LIBERATION:
			return _generate_liberation_option()
		OptionType.SPECIAL:
			return _generate_special_option()

	return _generate_weapon_option()  # 默认返回武器


## 根据概率选择选项类型
func _roll_option_type() -> OptionType:
	var roll := randf()
	var cumulative := 0.0

	cumulative += weapon_chance
	if roll < cumulative:
		return OptionType.WEAPON

	cumulative += passive_chance
	if roll < cumulative:
		return OptionType.PASSIVE

	cumulative += liberation_chance
	if roll < cumulative:
		return OptionType.LIBERATION

	return OptionType.SPECIAL


## 生成武器选项
func _generate_weapon_option() -> Dictionary:
	# 获取玩家当前武器
	var player := GameManager.player_node
	if not player:
		return {"type": "weapon", "id": "bullet_ring", "name": "弹幕环", "description": "获得弹幕环武器", "is_new": true}

	var weapon_pivot := player.get_node_or_null("WeaponPivot")
	var weapons := []
	if weapon_pivot:
		weapons = weapon_pivot.get_children().filter(func(child: Node) -> bool:
			return child is WeaponBase
		)

	# 50%概率升级现有武器，50%获得新武器
	if weapons.size() > 0 and randf() < 0.5:
		# 升级现有武器
		var weapon: WeaponBase = weapons[randi() % weapons.size()]
		if not weapon.is_max_level():
			return {
				"type": "weapon",
				"id": weapon.weapon_id,
				"name": weapon.weapon_name + " Lv.%d" % (weapon.current_level + 1),
				"description": "伤害 +%.0f, 冷却 -%.1fs" % [weapon.damage_per_level, weapon.cooldown_reduction],
				"is_new": false,
				"target_node": weapon
			}

	# 新武器
	var available_weapons := ["bullet_ring", "spin_blade", "chain_lightning"]
	var new_weapon_id: String = available_weapons[randi() % available_weapons.size()]
	return {
		"type": "weapon",
		"id": new_weapon_id,
		"name": _get_weapon_name(new_weapon_id),
		"description": "获得新武器",
		"is_new": true
	}


## 生成被动选项
func _generate_passive_option() -> Dictionary:
	var passives := [
		{"id": "max_hp_up", "name": "生命强化", "description": "最大HP +20", "stat": "max_hp", "value": 20.0},
		{"id": "speed_up", "name": "疾步", "description": "移动速度 +10%", "stat": "move_speed", "value": 0.1},
		{"id": "pickup_range_up", "name": "磁力", "description": "拾取范围 +30%", "stat": "pickup_range", "value": 0.3},
		{"id": "damage_up", "name": "力量", "description": "全伤害 +15%", "stat": "damage", "value": 0.15},
		{"id": "cooldown_down", "name": "急速", "description": "冷却时间 -10%", "stat": "cooldown", "value": -0.1},
		{"id": "armor_up", "name": "护甲", "description": "衣着耐久消耗 -20%", "stat": "armor", "value": 0.2},
	]

	var selected: Dictionary = passives[randi() % passives.size()]
	selected["type"] = "passive"
	return selected


## 生成解放选项
func _generate_liberation_option() -> Dictionary:
	return {
		"type": "liberation",
		"id": "clothing_restore",
		"name": "衣着修复",
		"description": "恢复30点衣着耐久度"
	}


## 生成特殊选项
func _generate_special_option() -> Dictionary:
	var specials := [
		{"id": "heal_full", "name": "完全回复", "description": "HP恢复至满"},
		{"id": "exp_magnet", "name": "经验磁铁", "description": "吸收场上所有经验"},
		{"id": "bomb", "name": "清屏炸弹", "description": "消灭屏幕内所有敌人"},
	]

	var selected: Dictionary = specials[randi() % specials.size()]
	selected["type"] = "special"
	return selected


# ===== 辅助方法 =====

## 检查是否重复选项
func _is_duplicate(option: Dictionary, existing: Array[Dictionary]) -> bool:
	for existing_opt in existing:
		if existing_opt.get("id", "") == option.get("id", ""):
			return true
	return false


## 获取武器名称
func _get_weapon_name(weapon_id: String) -> String:
	match weapon_id:
		"bullet_ring": return "弹幕环"
		"spin_blade": return "旋转刀刃"
		"chain_lightning": return "连锁闪电"
		_: return "未知武器"


## 获取经验百分比
func get_exp_percent() -> float:
	if exp_to_next_level <= 0:
		return 1.0
	return float(current_exp) / float(exp_to_next_level)
