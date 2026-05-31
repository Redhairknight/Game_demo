## 武器系统单元测试
## 测试冷却计时、伤害计算、弹幕数量
extends "res://tests/test_runner.gd".TestSuite

# ========== 模拟武器系统 ==========

# 武器数据结构
class WeaponData:
	var name: String = ""
	var base_damage: float = 10.0
	var damage_per_level: float = 3.0
	var base_cooldown: float = 1.0
	var cooldown_reduction_per_level: float = 0.05
	var min_cooldown: float = 0.2
	var base_projectile_count: int = 1
	var extra_projectiles_per_level: int = 0  # 每几级加一发
	var projectile_level_interval: int = 2    # 每2级加一发弹幕
	var level: int = 1
	var max_level: int = 8
	var current_cooldown: float = 0.0
	var is_ready: bool = true


var weapons: Array[WeaponData] = []


# ========== 辅助方法 ==========
func _reset() -> void:
	weapons.clear()


func _create_weapon(weapon_name: String, base_dmg: float = 10.0, base_cd: float = 1.0) -> WeaponData:
	var w = WeaponData.new()
	w.name = weapon_name
	w.base_damage = base_dmg
	w.base_cooldown = base_cd
	w.level = 1
	w.current_cooldown = 0.0
	w.is_ready = true
	weapons.append(w)
	return w


func _calculate_damage(weapon: WeaponData) -> float:
	"""计算武器当前伤害 = 基础伤害 + (等级-1) * 每级加成"""
	return weapon.base_damage + (weapon.level - 1) * weapon.damage_per_level


func _calculate_cooldown(weapon: WeaponData) -> float:
	"""计算武器当前冷却时间"""
	var cd = weapon.base_cooldown - (weapon.level - 1) * weapon.cooldown_reduction_per_level
	return max(cd, weapon.min_cooldown)


func _calculate_projectile_count(weapon: WeaponData) -> int:
	"""计算武器当前弹幕数量"""
	if weapon.projectile_level_interval <= 0:
		return weapon.base_projectile_count
	var bonus = (weapon.level - 1) / weapon.projectile_level_interval
	return weapon.base_projectile_count + bonus


func _fire_weapon(weapon: WeaponData) -> Dictionary:
	"""尝试开火，返回结果"""
	if not weapon.is_ready:
		return {"fired": false, "damage": 0.0, "projectiles": 0}

	var damage = _calculate_damage(weapon)
	var projectiles = _calculate_projectile_count(weapon)

	# 进入冷却
	weapon.is_ready = false
	weapon.current_cooldown = _calculate_cooldown(weapon)

	return {"fired": true, "damage": damage, "projectiles": projectiles}


func _update_weapon_cooldown(weapon: WeaponData, delta: float) -> void:
	"""更新武器冷却"""
	if weapon.is_ready:
		return
	weapon.current_cooldown -= delta
	if weapon.current_cooldown <= 0.0:
		weapon.current_cooldown = 0.0
		weapon.is_ready = true


func _level_up_weapon(weapon: WeaponData) -> bool:
	"""升级武器"""
	if weapon.level >= weapon.max_level:
		return false
	weapon.level += 1
	return true


# ========== 测试方法 ==========
func before_each() -> void:
	_reset()


## 测试创建武器初始状态
func test_weapon_creation() -> void:
	var w = _create_weapon("星尘射线", 15.0, 1.5)
	assert_eq(w.name, "星尘射线", "武器名称应正确")
	assert_eq(w.base_damage, 15.0, "基础伤害应为15")
	assert_eq(w.base_cooldown, 1.5, "基础冷却应为1.5秒")
	assert_eq(w.level, 1, "初始等级应为1")
	assert_true(w.is_ready, "初始应可开火")


## 测试1级武器伤害
func test_level_1_damage() -> void:
	var w = _create_weapon("测试武器", 10.0)
	var dmg = _calculate_damage(w)
	assert_eq(dmg, 10.0, "1级伤害应为基础伤害10")


## 测试升级后伤害增加
func test_damage_increases_with_level() -> void:
	var w = _create_weapon("测试武器", 10.0)
	w.damage_per_level = 3.0

	_level_up_weapon(w)  # 2级
	assert_near(_calculate_damage(w), 13.0, 0.01, "2级伤害=10+3=13")

	_level_up_weapon(w)  # 3级
	assert_near(_calculate_damage(w), 16.0, 0.01, "3级伤害=10+6=16")

	_level_up_weapon(w)  # 4级
	assert_near(_calculate_damage(w), 19.0, 0.01, "4级伤害=10+9=19")


## 测试满级伤害
func test_max_level_damage() -> void:
	var w = _create_weapon("测试武器", 10.0)
	w.damage_per_level = 3.0
	w.max_level = 8

	# 升到满级
	for i in range(7):  # 升7次到8级
		_level_up_weapon(w)

	assert_eq(w.level, 8, "应为满级8")
	assert_near(_calculate_damage(w), 10.0 + 7 * 3.0, 0.01, "满级伤害=10+21=31")


## 测试武器冷却初始值
func test_initial_cooldown() -> void:
	var w = _create_weapon("测试武器", 10.0, 1.0)
	var cd = _calculate_cooldown(w)
	assert_near(cd, 1.0, 0.01, "1级冷却应为基础冷却1.0秒")


## 测试武器冷却随等级减少
func test_cooldown_decreases_with_level() -> void:
	var w = _create_weapon("测试武器", 10.0, 1.0)
	w.cooldown_reduction_per_level = 0.05

	_level_up_weapon(w)  # 2级
	assert_near(_calculate_cooldown(w), 0.95, 0.01, "2级冷却=1.0-0.05=0.95")

	_level_up_weapon(w)  # 3级
	assert_near(_calculate_cooldown(w), 0.90, 0.01, "3级冷却=1.0-0.10=0.90")


## 测试武器冷却最小值限制
func test_cooldown_minimum_cap() -> void:
	var w = _create_weapon("测试武器", 10.0, 1.0)
	w.cooldown_reduction_per_level = 0.5  # 大幅减少
	w.min_cooldown = 0.2
	w.max_level = 10

	# 升很多级使冷却降到最低
	for i in range(9):
		_level_up_weapon(w)

	var cd = _calculate_cooldown(w)
	assert_near(cd, 0.2, 0.01, "冷却不应低于最小值0.2")


## 测试开火触发冷却
func test_fire_triggers_cooldown() -> void:
	var w = _create_weapon("测试武器", 10.0, 1.0)
	assert_true(w.is_ready, "初始应可开火")

	var result = _fire_weapon(w)
	assert_true(result["fired"], "首次开火应成功")
	assert_false(w.is_ready, "开火后应进入冷却")
	assert_near(w.current_cooldown, 1.0, 0.01, "冷却应为1.0秒")


## 测试冷却期间不能开火
func test_cannot_fire_during_cooldown() -> void:
	var w = _create_weapon("测试武器", 10.0, 1.0)
	_fire_weapon(w)

	var result = _fire_weapon(w)  # 尝试在冷却中开火
	assert_false(result["fired"], "冷却中不应能开火")


## 测试冷却计时器更新
func test_cooldown_timer_update() -> void:
	var w = _create_weapon("测试武器", 10.0, 1.0)
	_fire_weapon(w)

	_update_weapon_cooldown(w, 0.3)
	assert_near(w.current_cooldown, 0.7, 0.01, "更新后剩余0.7秒冷却")
	assert_false(w.is_ready, "冷却未结束不应就绪")


## 测试冷却结束恢复就绪
func test_cooldown_complete_ready() -> void:
	var w = _create_weapon("测试武器", 10.0, 1.0)
	_fire_weapon(w)

	_update_weapon_cooldown(w, 1.0)  # 恰好冷却完毕
	assert_true(w.is_ready, "冷却完毕应就绪")
	assert_eq(w.current_cooldown, 0.0, "冷却应归零")


## 测试冷却过度不会为负
func test_cooldown_no_negative() -> void:
	var w = _create_weapon("测试武器", 10.0, 1.0)
	_fire_weapon(w)

	_update_weapon_cooldown(w, 2.0)  # 超过冷却时间
	assert_eq(w.current_cooldown, 0.0, "冷却不应为负")
	assert_true(w.is_ready, "应恢复就绪")


## 测试1级弹幕数量
func test_level_1_projectile_count() -> void:
	var w = _create_weapon("测试武器")
	w.base_projectile_count = 1
	w.projectile_level_interval = 2

	assert_eq(_calculate_projectile_count(w), 1, "1级应有1发弹幕")


## 测试弹幕数量随等级增加
func test_projectile_count_increases() -> void:
	var w = _create_weapon("测试武器")
	w.base_projectile_count = 1
	w.projectile_level_interval = 2  # 每2级加1发
	w.max_level = 8

	# 1级: 1发
	assert_eq(_calculate_projectile_count(w), 1, "1级=1发")

	_level_up_weapon(w)  # 2级
	assert_eq(_calculate_projectile_count(w), 1, "2级=1发（不足2级间隔）")

	_level_up_weapon(w)  # 3级: (3-1)/2 = 1 额外
	assert_eq(_calculate_projectile_count(w), 2, "3级=2发")

	_level_up_weapon(w)  # 4级: (4-1)/2 = 1 额外
	assert_eq(_calculate_projectile_count(w), 2, "4级=2发")

	_level_up_weapon(w)  # 5级: (5-1)/2 = 2 额外
	assert_eq(_calculate_projectile_count(w), 3, "5级=3发")


## 测试开火返回正确伤害
func test_fire_returns_correct_damage() -> void:
	var w = _create_weapon("测试武器", 10.0)
	w.damage_per_level = 3.0
	_level_up_weapon(w)  # 2级

	var result = _fire_weapon(w)
	assert_near(result["damage"], 13.0, 0.01, "开火返回伤害应为13")


## 测试开火返回正确弹幕数
func test_fire_returns_correct_projectiles() -> void:
	var w = _create_weapon("测试武器")
	w.base_projectile_count = 1
	w.projectile_level_interval = 2
	w.max_level = 8

	# 升到5级
	for i in range(4):
		_level_up_weapon(w)

	var result = _fire_weapon(w)
	assert_eq(result["projectiles"], 3, "5级开火应有3发弹幕")


## 测试武器不能超过满级
func test_cannot_exceed_max_level() -> void:
	var w = _create_weapon("测试武器")
	w.max_level = 3

	assert_true(_level_up_weapon(w), "1->2 应成功")
	assert_true(_level_up_weapon(w), "2->3 应成功")
	assert_false(_level_up_weapon(w), "3->4 应失败（已满级）")
	assert_eq(w.level, 3, "等级应停在3")


## 测试多武器独立冷却
func test_multiple_weapons_independent_cooldown() -> void:
	var w1 = _create_weapon("武器A", 10.0, 1.0)
	var w2 = _create_weapon("武器B", 15.0, 2.0)

	_fire_weapon(w1)
	_fire_weapon(w2)

	_update_weapon_cooldown(w1, 1.0)  # w1冷却完毕
	_update_weapon_cooldown(w2, 1.0)  # w2还需1秒

	assert_true(w1.is_ready, "武器A应冷却完毕")
	assert_false(w2.is_ready, "武器B应仍在冷却")
	assert_near(w2.current_cooldown, 1.0, 0.01, "武器B剩余1秒冷却")


## 测试就绪武器更新冷却无影响
func test_ready_weapon_update_no_effect() -> void:
	var w = _create_weapon("测试武器", 10.0, 1.0)
	assert_true(w.is_ready, "应就绪")

	_update_weapon_cooldown(w, 0.5)
	assert_true(w.is_ready, "就绪状态更新不应改变")
	assert_eq(w.current_cooldown, 0.0, "冷却应保持0")
