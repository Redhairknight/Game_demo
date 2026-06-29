## 挑逗系统单元测试
## mock 与 taunt_system.gd 实现对齐：
##   - ChargeLevel 枚举 (NONE/SMALL/MEDIUM/FULL)
##   - is_charging bool，无 cooldown 状态
##   - 阈值：SMALL=1.0s MEDIUM=2.0s FULL=3.0s
##   - 满蓄力释放：调用 clothing.force_stage_down（mock 中用标志模拟）
extends "res://tests/test_runner.gd".TestSuite

# ===== 对齐真实代码的枚举 =====
enum ChargeLevel {
	NONE   = 0,
	SMALL  = 1,
	MEDIUM = 2,
	FULL   = 3,
}

# ===== 阈值（与 taunt_system.gd 一致）=====
const CHARGE_TIME_SMALL: float  = 1.0
const CHARGE_TIME_MEDIUM: float = 2.0
const CHARGE_TIME_FULL: float   = 3.0

# ===== mock 状态 =====
var is_charging: bool = false
var charge_time: float = 0.0
var can_move: bool = true
var force_stage_down_called: bool = false


# ===== mock 辅助方法 =====
func _reset() -> void:
	is_charging = false
	charge_time = 0.0
	can_move = true
	force_stage_down_called = false


func _start_charging() -> void:
	is_charging = true
	charge_time = 0.0
	can_move = false


func _update_charging(delta: float) -> void:
	if not is_charging:
		return
	charge_time += delta


func _get_charge_level() -> ChargeLevel:
	if charge_time >= CHARGE_TIME_FULL:
		return ChargeLevel.FULL
	elif charge_time >= CHARGE_TIME_MEDIUM:
		return ChargeLevel.MEDIUM
	elif charge_time >= CHARGE_TIME_SMALL:
		return ChargeLevel.SMALL
	else:
		return ChargeLevel.NONE


func _release_charge() -> Dictionary:
	if not is_charging:
		return {"success": false, "level": ChargeLevel.NONE}
	var level := _get_charge_level()
	if level == ChargeLevel.FULL:
		force_stage_down_called = true
	_end_charging()
	return {"success": level != ChargeLevel.NONE, "level": level}


func _interrupt() -> void:
	if is_charging:
		_end_charging()


func _end_charging() -> void:
	is_charging = false
	charge_time = 0.0
	can_move = true


# ===== 测试方法 =====
func before_each() -> void:
	_reset()


## 测试初始状态
func test_initial_state() -> void:
	assert_false(is_charging, "初始不应在蓄力")
	assert_eq(charge_time, 0.0, "初始蓄力时间为0")
	assert_true(can_move, "初始应可移动")


## 测试开始蓄力
func test_start_charging() -> void:
	_start_charging()
	assert_true(is_charging, "应进入蓄力状态")
	assert_eq(charge_time, 0.0, "蓄力时间从0开始")
	assert_false(can_move, "蓄力时不可移动")


## 测试蓄力时间累积
func test_charge_time_accumulation() -> void:
	_start_charging()
	_update_charging(0.5)
	assert_near(charge_time, 0.5, 0.001, "蓄力0.5秒")
	_update_charging(0.5)
	assert_near(charge_time, 1.0, 0.001, "蓄力累计1.0秒")


## 测试蓄力不足为NONE档
func test_charge_level_none() -> void:
	_start_charging()
	_update_charging(0.9)
	assert_eq(_get_charge_level(), ChargeLevel.NONE, "0.9秒应为NONE档")


## 测试SMALL档（1.0s - 2.0s）
func test_charge_level_small() -> void:
	_start_charging()
	_update_charging(1.0)
	assert_eq(_get_charge_level(), ChargeLevel.SMALL, "1.0秒应为SMALL")

	_reset()
	_start_charging()
	_update_charging(1.5)
	assert_eq(_get_charge_level(), ChargeLevel.SMALL, "1.5秒应为SMALL")

	_reset()
	_start_charging()
	_update_charging(1.99)
	assert_eq(_get_charge_level(), ChargeLevel.SMALL, "1.99秒应为SMALL")


## 测试MEDIUM档（2.0s - 3.0s）
func test_charge_level_medium() -> void:
	_start_charging()
	_update_charging(2.0)
	assert_eq(_get_charge_level(), ChargeLevel.MEDIUM, "2.0秒应为MEDIUM")

	_reset()
	_start_charging()
	_update_charging(2.5)
	assert_eq(_get_charge_level(), ChargeLevel.MEDIUM, "2.5秒应为MEDIUM")

	_reset()
	_start_charging()
	_update_charging(2.99)
	assert_eq(_get_charge_level(), ChargeLevel.MEDIUM, "2.99秒应为MEDIUM")


## 测试FULL满蓄力（3.0s+）
func test_charge_level_full() -> void:
	_start_charging()
	_update_charging(3.0)
	assert_eq(_get_charge_level(), ChargeLevel.FULL, "3.0秒应为FULL")

	_reset()
	_start_charging()
	_update_charging(5.0)
	assert_eq(_get_charge_level(), ChargeLevel.FULL, "超时仍应为FULL")


## 测试满蓄力释放触发 force_stage_down
func test_full_release_triggers_stage_down() -> void:
	_start_charging()
	_update_charging(3.0)
	var result := _release_charge()
	assert_true(result["success"], "满蓄力释放应成功")
	assert_eq(result["level"], ChargeLevel.FULL, "应为FULL档")
	assert_true(force_stage_down_called, "满蓄力应调用force_stage_down")


## 测试SMALL/MEDIUM释放不触发 force_stage_down
func test_lower_levels_no_stage_down() -> void:
	_start_charging()
	_update_charging(1.5)
	var result := _release_charge()
	assert_true(result["success"], "SMALL档释放应成功")
	assert_false(force_stage_down_called, "非满蓄力不应调用force_stage_down")


## 测试蓄力不足释放失败
func test_insufficient_charge_release_fails() -> void:
	_start_charging()
	_update_charging(0.5)
	var result := _release_charge()
	assert_false(result["success"], "蓄力不足释放应失败")
	assert_eq(result["level"], ChargeLevel.NONE, "应为NONE档")


## 测试被打断蓄力清零
func test_interrupt_resets_charge() -> void:
	_start_charging()
	_update_charging(2.0)
	_interrupt()
	assert_false(is_charging, "打断后应停止蓄力")
	assert_eq(charge_time, 0.0, "打断后蓄力时间应清零")
	assert_true(can_move, "打断后应可移动")


## 测试蓄力中不可移动
func test_cannot_move_while_charging() -> void:
	assert_true(can_move, "蓄力前可以移动")
	_start_charging()
	assert_false(can_move, "蓄力中不可移动")


## 测试释放后恢复移动
func test_movement_restored_after_release() -> void:
	_start_charging()
	_update_charging(1.0)
	_release_charge()
	assert_true(can_move, "释放后应可移动")


## 测试非蓄力状态更新不累积时间
func test_update_only_when_charging() -> void:
	_update_charging(2.0)
	assert_eq(charge_time, 0.0, "非蓄力状态不应累积时间")


## 测试释放后状态重置
func test_state_reset_after_release() -> void:
	_start_charging()
	_update_charging(1.5)
	_release_charge()
	assert_false(is_charging, "释放后不应在蓄力")
	assert_eq(charge_time, 0.0, "释放后蓄力时间应为0")
