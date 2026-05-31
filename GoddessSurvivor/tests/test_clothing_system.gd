## 衣着系统单元测试
## 测试衣着耐久度、阶段变化、极限形态触发等核心逻辑
extends "res://tests/test_runner.gd".TestSuite

# ========== 模拟衣着系统（用于测试） ==========
# 当实际的 ClothingSystem 实现后，替换为真实引用

## 衣着阶段定义
## 阶段0: 100% - 81%（完好）
## 阶段1: 80% - 61%（轻微破损）
## 阶段2: 60% - 41%（中度破损）
## 阶段3: 40% - 21%（严重破损）
## 阶段4: 20% - 1%（濒临极限）
## 极限形态: 0%

var max_durability: float = 100.0
var current_durability: float = 100.0
var current_stage: int = 0
var is_ultimate_form: bool = false

# 阶段阈值（百分比）
const STAGE_THRESHOLDS: Array[float] = [81.0, 61.0, 41.0, 21.0, 1.0]


# ========== 辅助方法 ==========
func _reset() -> void:
	current_durability = max_durability
	current_stage = 0
	is_ultimate_form = false


func _get_durability_percent() -> float:
	return (current_durability / max_durability) * 100.0


func _calculate_stage() -> int:
	var percent = _get_durability_percent()
	if percent <= 0.0:
		return -1  # 极限形态
	for i in range(STAGE_THRESHOLDS.size()):
		if percent >= STAGE_THRESHOLDS[i]:
			return i
	return STAGE_THRESHOLDS.size()


func _apply_damage(amount: float) -> void:
	current_durability = max(0.0, current_durability - amount)
	var new_stage = _calculate_stage()
	if new_stage == -1:
		is_ultimate_form = true
		current_stage = 5
	else:
		current_stage = new_stage
		is_ultimate_form = false


func _restore_durability(amount: float) -> void:
	current_durability = min(max_durability, current_durability + amount)
	is_ultimate_form = false
	current_stage = _calculate_stage()


func _full_reset() -> void:
	_reset()


# ========== 测试方法 ==========
func before_each() -> void:
	_reset()


## 测试初始状态
func test_initial_state_full_durability() -> void:
	assert_eq(current_durability, 100.0, "初始耐久度应为100")
	assert_eq(_get_durability_percent(), 100.0, "初始百分比应为100%")
	assert_eq(current_stage, 0, "初始阶段应为0")
	assert_false(is_ultimate_form, "初始不应为极限形态")


## 测试阶段0边界（100% - 81%）
func test_stage_0_boundary() -> void:
	# 在81%时仍为阶段0
	_apply_damage(19.0)  # 100 -> 81
	assert_eq(_get_durability_percent(), 81.0, "耐久应为81%")
	assert_eq(current_stage, 0, "81%时应为阶段0")


## 测试阶段0到阶段1的转变（80%）
func test_stage_0_to_1_transition() -> void:
	_apply_damage(20.0)  # 100 -> 80
	assert_eq(_get_durability_percent(), 80.0, "耐久应为80%")
	assert_eq(current_stage, 1, "80%时应为阶段1")


## 测试阶段1边界（80% - 61%）
func test_stage_1_boundary() -> void:
	_apply_damage(39.0)  # 100 -> 61
	assert_eq(_get_durability_percent(), 61.0, "耐久应为61%")
	assert_eq(current_stage, 1, "61%时应为阶段1")


## 测试阶段1到阶段2的转变（60%）
func test_stage_1_to_2_transition() -> void:
	_apply_damage(40.0)  # 100 -> 60
	assert_eq(_get_durability_percent(), 60.0, "耐久应为60%")
	assert_eq(current_stage, 2, "60%时应为阶段2")


## 测试阶段2边界（60% - 41%）
func test_stage_2_boundary() -> void:
	_apply_damage(59.0)  # 100 -> 41
	assert_eq(_get_durability_percent(), 41.0, "耐久应为41%")
	assert_eq(current_stage, 2, "41%时应为阶段2")


## 测试阶段2到阶段3的转变（40%）
func test_stage_2_to_3_transition() -> void:
	_apply_damage(60.0)  # 100 -> 40
	assert_eq(_get_durability_percent(), 40.0, "耐久应为40%")
	assert_eq(current_stage, 3, "40%时应为阶段3")


## 测试阶段3边界（40% - 21%）
func test_stage_3_boundary() -> void:
	_apply_damage(79.0)  # 100 -> 21
	assert_eq(_get_durability_percent(), 21.0, "耐久应为21%")
	assert_eq(current_stage, 3, "21%时应为阶段3")


## 测试阶段3到阶段4的转变（20%）
func test_stage_3_to_4_transition() -> void:
	_apply_damage(80.0)  # 100 -> 20
	assert_eq(_get_durability_percent(), 20.0, "耐久应为20%")
	assert_eq(current_stage, 4, "20%时应为阶段4")


## 测试阶段4边界（20% - 1%）
func test_stage_4_boundary() -> void:
	_apply_damage(99.0)  # 100 -> 1
	assert_eq(_get_durability_percent(), 1.0, "耐久应为1%")
	assert_eq(current_stage, 4, "1%时应为阶段4")


## 测试极限形态触发（0%）
func test_ultimate_form_trigger() -> void:
	_apply_damage(100.0)  # 100 -> 0
	assert_eq(_get_durability_percent(), 0.0, "耐久应为0%")
	assert_true(is_ultimate_form, "0%时应触发极限形态")
	assert_eq(current_stage, 5, "极限形态阶段应为5")


## 测试过度伤害不会使耐久度为负
func test_over_damage_clamp() -> void:
	_apply_damage(150.0)  # 超过最大值
	assert_eq(current_durability, 0.0, "耐久度不应为负数")
	assert_true(is_ultimate_form, "应触发极限形态")


## 测试恢复耐久度
func test_restore_durability() -> void:
	_apply_damage(50.0)  # 100 -> 50
	assert_eq(current_stage, 2, "50%应为阶段2")

	_restore_durability(30.0)  # 50 -> 80
	assert_eq(_get_durability_percent(), 80.0, "恢复后应为80%")
	assert_eq(current_stage, 1, "恢复后应为阶段1")


## 测试恢复不超过最大值
func test_restore_clamp_to_max() -> void:
	_apply_damage(20.0)  # 100 -> 80
	_restore_durability(50.0)  # 80 -> 100（不超过上限）
	assert_eq(current_durability, 100.0, "恢复不应超过最大耐久度")
	assert_eq(current_stage, 0, "满耐久应为阶段0")


## 测试换装重置逻辑
func test_full_reset_on_outfit_change() -> void:
	_apply_damage(70.0)  # 模拟大量伤害
	assert_true(current_stage > 0, "应不在阶段0")

	_full_reset()  # 换装重置
	assert_eq(current_durability, 100.0, "换装后耐久度应满")
	assert_eq(current_stage, 0, "换装后阶段应为0")
	assert_false(is_ultimate_form, "换装后不应为极限形态")


## 测试从极限形态恢复
func test_restore_from_ultimate_form() -> void:
	_apply_damage(100.0)  # 触发极限形态
	assert_true(is_ultimate_form, "应为极限形态")

	_restore_durability(50.0)  # 恢复到50%
	assert_false(is_ultimate_form, "恢复后不应为极限形态")
	assert_eq(current_stage, 2, "50%应为阶段2")


## 测试多次小伤害累积
func test_cumulative_small_damage() -> void:
	for i in range(10):
		_apply_damage(5.0)  # 每次5点，共50点
	assert_eq(_get_durability_percent(), 50.0, "10次5点伤害应减至50%")
	assert_eq(current_stage, 2, "50%应为阶段2")
