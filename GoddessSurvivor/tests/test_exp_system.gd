## 经验系统单元测试
## 测试经验累加、升级阈值、升级选项概率分布
extends "res://tests/test_runner.gd".TestSuite

# ========== 模拟经验系统 ==========

var current_exp: float = 0.0
var current_level: int = 1
var total_exp_gained: float = 0.0

# 升级选项类型
enum UpgradeType {
	WEAPON,       # 武器 40%
	PASSIVE,      # 被动 30%
	LIBERATION,   # 解放 20%
	SPECIAL       # 特殊 10%
}

# 概率分布（百分比）
const UPGRADE_PROBABILITIES: Dictionary = {
	UpgradeType.WEAPON: 40.0,
	UpgradeType.PASSIVE: 30.0,
	UpgradeType.LIBERATION: 20.0,
	UpgradeType.SPECIAL: 10.0,
}

# 基础升级经验需求
const BASE_EXP_REQUIRED: float = 10.0
# 每级增长系数
const EXP_GROWTH_FACTOR: float = 1.2


# ========== 辅助方法 ==========
func _reset() -> void:
	current_exp = 0.0
	current_level = 1
	total_exp_gained = 0.0


func _get_exp_for_level(level: int) -> float:
	# 升级所需经验 = 基础值 * 增长系数^(等级-1)
	return BASE_EXP_REQUIRED * pow(EXP_GROWTH_FACTOR, level - 1)


func _add_exp(amount: float) -> int:
	"""添加经验，返回升了几级"""
	current_exp += amount
	total_exp_gained += amount
	var levels_gained: int = 0

	while current_exp >= _get_exp_for_level(current_level):
		current_exp -= _get_exp_for_level(current_level)
		current_level += 1
		levels_gained += 1

	return levels_gained


func _roll_upgrade_type(roll_value: float) -> UpgradeType:
	"""根据0-100的随机值确定升级类型"""
	if roll_value < 40.0:
		return UpgradeType.WEAPON
	elif roll_value < 70.0:  # 40 + 30
		return UpgradeType.PASSIVE
	elif roll_value < 90.0:  # 40 + 30 + 20
		return UpgradeType.LIBERATION
	else:
		return UpgradeType.SPECIAL


func _generate_upgrade_options(count: int = 3, rng_seed: int = 0) -> Array[UpgradeType]:
	"""生成指定数量的升级选项"""
	var rng = RandomNumberGenerator.new()
	rng.seed = rng_seed
	var options: Array[UpgradeType] = []
	for i in range(count):
		var roll = rng.randf_range(0.0, 100.0)
		options.append(_roll_upgrade_type(roll))
	return options


# ========== 测试方法 ==========
func before_each() -> void:
	_reset()


## 测试初始状态
func test_initial_state() -> void:
	assert_eq(current_exp, 0.0, "初始经验应为0")
	assert_eq(current_level, 1, "初始等级应为1")
	assert_eq(total_exp_gained, 0.0, "初始总经验应为0")


## 测试经验累加
func test_exp_accumulation() -> void:
	_add_exp(5.0)
	assert_eq(current_exp, 5.0, "经验应累加到5")
	assert_eq(current_level, 1, "经验不足不应升级")

	_add_exp(3.0)
	assert_eq(current_exp, 8.0, "经验应累加到8")
	assert_eq(current_level, 1, "经验不足仍不应升级")


## 测试总经验追踪
func test_total_exp_tracking() -> void:
	_add_exp(5.0)
	_add_exp(10.0)
	_add_exp(3.0)
	assert_eq(total_exp_gained, 18.0, "总经验应正确累计")


## 测试1级升级阈值
func test_level_1_threshold() -> void:
	var required = _get_exp_for_level(1)
	assert_eq(required, 10.0, "1级升级需要10经验")


## 测试升级阈值递增
func test_exp_threshold_growth() -> void:
	var level_1 = _get_exp_for_level(1)
	var level_2 = _get_exp_for_level(2)
	var level_3 = _get_exp_for_level(3)

	assert_eq(level_1, 10.0, "1级阈值=10")
	assert_near(level_2, 12.0, 0.01, "2级阈值=12")
	assert_near(level_3, 14.4, 0.01, "3级阈值=14.4")
	assert_true(level_2 > level_1, "后续阈值应递增")
	assert_true(level_3 > level_2, "后续阈值应持续递增")


## 测试恰好升级
func test_exact_level_up() -> void:
	var levels = _add_exp(10.0)  # 恰好达到1级阈值
	assert_eq(levels, 1, "应升1级")
	assert_eq(current_level, 2, "应升到2级")
	assert_eq(current_exp, 0.0, "溢出经验应为0")


## 测试溢出经验保留
func test_overflow_exp_preserved() -> void:
	var levels = _add_exp(13.0)  # 10需要升级，溢出3
	assert_eq(levels, 1, "应升1级")
	assert_eq(current_level, 2, "应升到2级")
	assert_near(current_exp, 3.0, 0.01, "溢出经验应保留")


## 测试连续升级
func test_multi_level_up() -> void:
	# 1级需要10，2级需要12，总共22
	var levels = _add_exp(22.0)
	assert_eq(levels, 2, "应升2级")
	assert_eq(current_level, 3, "应升到3级")
	assert_near(current_exp, 0.0, 0.01, "溢出经验应为0")


## 测试大量经验一次性升多级
func test_massive_exp_gain() -> void:
	# 1级:10, 2级:12, 3级:14.4, 4级:17.28, 总共约53.68
	var levels = _add_exp(100.0)
	assert_true(levels >= 4, "100经验应至少升4级")
	assert_true(current_level >= 5, "等级应至少为5")


## 测试升级选项 - 武器概率范围
func test_upgrade_roll_weapon() -> void:
	# 0-39.99 应为武器
	assert_eq(_roll_upgrade_type(0.0), UpgradeType.WEAPON, "0应为武器")
	assert_eq(_roll_upgrade_type(20.0), UpgradeType.WEAPON, "20应为武器")
	assert_eq(_roll_upgrade_type(39.99), UpgradeType.WEAPON, "39.99应为武器")


## 测试升级选项 - 被动概率范围
func test_upgrade_roll_passive() -> void:
	# 40-69.99 应为被动
	assert_eq(_roll_upgrade_type(40.0), UpgradeType.PASSIVE, "40应为被动")
	assert_eq(_roll_upgrade_type(55.0), UpgradeType.PASSIVE, "55应为被动")
	assert_eq(_roll_upgrade_type(69.99), UpgradeType.PASSIVE, "69.99应为被动")


## 测试升级选项 - 解放概率范围
func test_upgrade_roll_liberation() -> void:
	# 70-89.99 应为解放
	assert_eq(_roll_upgrade_type(70.0), UpgradeType.LIBERATION, "70应为解放")
	assert_eq(_roll_upgrade_type(80.0), UpgradeType.LIBERATION, "80应为解放")
	assert_eq(_roll_upgrade_type(89.99), UpgradeType.LIBERATION, "89.99应为解放")


## 测试升级选项 - 特殊概率范围
func test_upgrade_roll_special() -> void:
	# 90-100 应为特殊
	assert_eq(_roll_upgrade_type(90.0), UpgradeType.SPECIAL, "90应为特殊")
	assert_eq(_roll_upgrade_type(95.0), UpgradeType.SPECIAL, "95应为特殊")
	assert_eq(_roll_upgrade_type(99.99), UpgradeType.SPECIAL, "99.99应为特殊")


## 测试升级选项生成数量
func test_upgrade_options_count() -> void:
	var options = _generate_upgrade_options(3, 42)
	assert_eq(options.size(), 3, "应生成3个升级选项")


## 测试概率分布统计（大样本）
func test_probability_distribution() -> void:
	var counts = {
		UpgradeType.WEAPON: 0,
		UpgradeType.PASSIVE: 0,
		UpgradeType.LIBERATION: 0,
		UpgradeType.SPECIAL: 0,
	}

	var rng = RandomNumberGenerator.new()
	rng.seed = 12345  # 固定种子保证可重复
	var total_samples: int = 10000

	for i in range(total_samples):
		var roll = rng.randf_range(0.0, 100.0)
		var type = _roll_upgrade_type(roll)
		counts[type] += 1

	# 验证分布（允许5%偏差）
	var weapon_pct = float(counts[UpgradeType.WEAPON]) / total_samples * 100.0
	var passive_pct = float(counts[UpgradeType.PASSIVE]) / total_samples * 100.0
	var liberation_pct = float(counts[UpgradeType.LIBERATION]) / total_samples * 100.0
	var special_pct = float(counts[UpgradeType.SPECIAL]) / total_samples * 100.0

	assert_in_range(weapon_pct, 35.0, 45.0, "武器概率应约40%%")
	assert_in_range(passive_pct, 25.0, 35.0, "被动概率应约30%%")
	assert_in_range(liberation_pct, 15.0, 25.0, "解放概率应约20%%")
	assert_in_range(special_pct, 5.0, 15.0, "特殊概率应约10%%")


## 测试概率总和为100%
func test_probability_sum() -> void:
	var total = 0.0
	for prob in UPGRADE_PROBABILITIES.values():
		total += prob
	assert_near(total, 100.0, 0.01, "概率总和应为100%")


## 测试0经验不升级
func test_zero_exp_no_level_up() -> void:
	var levels = _add_exp(0.0)
	assert_eq(levels, 0, "0经验不应升级")
	assert_eq(current_level, 1, "等级应保持1")
