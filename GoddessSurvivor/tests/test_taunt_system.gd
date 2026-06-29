## 挑逗系统单元测试
## 测试蓄力机制、档位判定、被打断逻辑、移动限制
extends "res://tests/test_runner.gd".TestSuite

# ========== 模拟挑逗系统 ==========

enum TauntState {
	IDLE,       # 空闲
	CHARGING,   # 蓄力中
	RELEASING,  # 释放中
	COOLDOWN,   # 冷却中
}

enum TauntTier {
	NONE,       # 无效（未达到最低蓄力）
	TIER_1,     # 1档：0.5s - 1.0s
	TIER_2,     # 2档：1.0s - 2.0s
	TIER_3,     # 3档：2.0s+（满蓄力）
}

var state: TauntState = TauntState.IDLE
var charge_time: float = 0.0
var is_movement_locked: bool = false
var clothing_damage_on_max: float = 20.0  # 满蓄力消耗衣着1阶段（20%）
var cooldown_time: float = 0.0
var cooldown_duration: float = 1.0

# 蓄力档位阈值 — 与 taunt_system.gd 保持一致
const TIER_1_MIN: float = 1.0
const TIER_2_MIN: float = 2.0
const TIER_3_MIN: float = 3.0
const MAX_CHARGE: float = 3.0


# ========== 辅助方法 ==========
func _reset() -> void:
	state = TauntState.IDLE
	charge_time = 0.0
	is_movement_locked = false
	cooldown_time = 0.0


func _start_charging() -> void:
	if state != TauntState.IDLE:
		return
	state = TauntState.CHARGING
	charge_time = 0.0
	is_movement_locked = true


func _update_charge(delta: float) -> void:
	if state != TauntState.CHARGING:
		return
	charge_time = min(charge_time + delta, MAX_CHARGE)


func _get_current_tier() -> TauntTier:
	if charge_time >= TIER_3_MIN:
		return TauntTier.TIER_3
	elif charge_time >= TIER_2_MIN:
		return TauntTier.TIER_2
	elif charge_time >= TIER_1_MIN:
		return TauntTier.TIER_1
	else:
		return TauntTier.NONE


func _release() -> Dictionary:
	"""释放挑逗，返回结果信息"""
	if state != TauntState.CHARGING:
		return {"success": false, "tier": TauntTier.NONE, "clothing_cost": 0.0}

	var tier = _get_current_tier()
	var clothing_cost: float = 0.0

	if tier == TauntTier.NONE:
		# 蓄力不足，无效释放
		state = TauntState.IDLE
		is_movement_locked = false
		return {"success": false, "tier": tier, "clothing_cost": 0.0}

	if tier == TauntTier.TIER_3:
		clothing_cost = clothing_damage_on_max

	state = TauntState.COOLDOWN
	cooldown_time = cooldown_duration
	is_movement_locked = false

	return {"success": true, "tier": tier, "clothing_cost": clothing_cost}


func _interrupt() -> void:
	"""被打断"""
	if state == TauntState.CHARGING:
		state = TauntState.IDLE
		charge_time = 0.0
		is_movement_locked = false


func _update_cooldown(delta: float) -> void:
	if state != TauntState.COOLDOWN:
		return
	cooldown_time -= delta
	if cooldown_time <= 0.0:
		cooldown_time = 0.0
		state = TauntState.IDLE


func _can_move() -> bool:
	return not is_movement_locked


# ========== 测试方法 ==========
func before_each() -> void:
	_reset()


## 测试初始状态
func test_initial_state() -> void:
	assert_eq(state, TauntState.IDLE, "初始应为空闲状态")
	assert_eq(charge_time, 0.0, "初始蓄力时间为0")
	assert_true(_can_move(), "初始应可移动")


## 测试开始蓄力
func test_start_charging() -> void:
	_start_charging()
	assert_eq(state, TauntState.CHARGING, "应进入蓄力状态")
	assert_eq(charge_time, 0.0, "蓄力时间从0开始")
	assert_false(_can_move(), "蓄力时不可移动")


## 测试蓄力时间累积
func test_charge_time_accumulation() -> void:
	_start_charging()
	_update_charge(0.3)
	assert_near(charge_time, 0.3, 0.001, "蓄力0.3秒")
	_update_charge(0.2)
	assert_near(charge_time, 0.5, 0.001, "蓄力累计0.5秒")


## 测试蓄力上限
func test_charge_time_cap() -> void:
	_start_charging()
	_update_charge(5.0)  # 远超上限
	assert_near(charge_time, MAX_CHARGE, 0.001, "蓄力不应超过上限")


## 测试蓄力不足为无效档
func test_tier_none_insufficient_charge() -> void:
	_start_charging()
	_update_charge(0.5)  # 不足1.0秒
	assert_eq(_get_current_tier(), TauntTier.NONE, "0.5秒应为无效档")


## 测试1档蓄力（1.0s - 2.0s）
func test_tier_1_charge() -> void:
	_start_charging()
	_update_charge(1.0)
	assert_eq(_get_current_tier(), TauntTier.TIER_1, "1.0秒应为1档")

	_reset()
	_start_charging()
	_update_charge(1.5)
	assert_eq(_get_current_tier(), TauntTier.TIER_1, "1.5秒应为1档")

	_reset()
	_start_charging()
	_update_charge(1.99)
	assert_eq(_get_current_tier(), TauntTier.TIER_1, "1.99秒应为1档")


## 测试2档蓄力（2.0s - 3.0s）
func test_tier_2_charge() -> void:
	_start_charging()
	_update_charge(2.0)
	assert_eq(_get_current_tier(), TauntTier.TIER_2, "2.0秒应为2档")

	_reset()
	_start_charging()
	_update_charge(2.5)
	assert_eq(_get_current_tier(), TauntTier.TIER_2, "2.5秒应为2档")

	_reset()
	_start_charging()
	_update_charge(2.99)
	assert_eq(_get_current_tier(), TauntTier.TIER_2, "2.99秒应为2档")


## 测试3档满蓄力（3.0s+）
func test_tier_3_full_charge() -> void:
	_start_charging()
	_update_charge(3.0)
	assert_eq(_get_current_tier(), TauntTier.TIER_3, "3.0秒应为3档（满蓄力）")


## 测试满蓄力消耗衣着1阶段
func test_tier_3_clothing_cost() -> void:
	_start_charging()
	_update_charge(3.0)
	var result = _release()
	assert_true(result["success"], "满蓄力释放应成功")
	assert_eq(result["tier"], TauntTier.TIER_3, "应为3档")
	assert_eq(result["clothing_cost"], 20.0, "满蓄力应消耗20%衣着（1阶段）")


## 测试非满蓄力不消耗衣着
func test_lower_tiers_no_clothing_cost() -> void:
	_start_charging()
	_update_charge(1.5)  # 1档
	var result = _release()
	assert_true(result["success"], "1档释放应成功")
	assert_eq(result["clothing_cost"], 0.0, "非满蓄力不应消耗衣着")


## 测试无效释放（蓄力不足）
func test_release_insufficient_charge() -> void:
	_start_charging()
	_update_charge(0.5)  # 不足最低蓄力1.0s
	var result = _release()
	assert_false(result["success"], "蓄力不足释放应失败")
	assert_eq(result["tier"], TauntTier.NONE, "应为无效档")
	assert_eq(state, TauntState.IDLE, "失败后应回到空闲")


## 测试被打断蓄力清零
func test_interrupt_resets_charge() -> void:
	_start_charging()
	_update_charge(2.5)  # 蓄力2.5秒
	assert_near(charge_time, 2.5, 0.001, "应有2.5秒蓄力")

	_interrupt()  # 被打断
	assert_eq(charge_time, 0.0, "被打断后蓄力应清零")
	assert_eq(state, TauntState.IDLE, "被打断后应回到空闲")
	assert_true(_can_move(), "被打断后应可移动")


## 测试蓄力期间无法移动
func test_cannot_move_while_charging() -> void:
	assert_true(_can_move(), "蓄力前可以移动")
	_start_charging()
	assert_false(_can_move(), "蓄力中不可移动")
	_update_charge(1.0)
	assert_false(_can_move(), "蓄力中持续不可移动")


## 测试释放后恢复移动
func test_movement_restored_after_release() -> void:
	_start_charging()
	_update_charge(1.0)
	assert_false(_can_move(), "蓄力中不可移动")

	_release()
	assert_true(_can_move(), "释放后应可移动")


## 测试冷却状态
func test_cooldown_after_release() -> void:
	_start_charging()
	_update_charge(1.0)
	_release()
	assert_eq(state, TauntState.COOLDOWN, "释放后应进入冷却")
	assert_near(cooldown_time, cooldown_duration, 0.001, "冷却时间应为设定值")


## 测试冷却结束回到空闲
func test_cooldown_ends_to_idle() -> void:
	_start_charging()
	_update_charge(1.0)
	_release()

	_update_cooldown(0.5)
	assert_eq(state, TauntState.COOLDOWN, "冷却未结束仍在冷却")

	_update_cooldown(0.5)
	assert_eq(state, TauntState.IDLE, "冷却结束应回到空闲")


## 测试冷却期间不能重新蓄力
func test_cannot_charge_during_cooldown() -> void:
	_start_charging()
	_update_charge(1.0)
	_release()
	assert_eq(state, TauntState.COOLDOWN, "应在冷却中")

	_start_charging()  # 尝试在冷却中蓄力
	assert_eq(state, TauntState.COOLDOWN, "冷却中不应进入蓄力")


## 测试非蓄力状态更新不影响蓄力时间
func test_charge_update_only_in_charging_state() -> void:
	# 空闲状态
	_update_charge(1.0)
	assert_eq(charge_time, 0.0, "非蓄力状态不应累积时间")
