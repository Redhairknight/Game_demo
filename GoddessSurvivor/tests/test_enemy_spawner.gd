## 敌人生成器单元测试
## 测试难度曲线、最大数量限制、生成位置
extends "res://tests/test_runner.gd".TestSuite

# ========== 模拟敌人生成系统 ==========

# 难度配置
const MAX_ENEMIES: int = 150
const SPAWN_RADIUS_MIN: float = 600.0  # 最小生成距离（屏幕外）
const SPAWN_RADIUS_MAX: float = 900.0  # 最大生成距离
const GAME_DURATION: float = 900.0     # 15分钟 = 900秒
const VIEWPORT_HALF_WIDTH: float = 640.0
const VIEWPORT_HALF_HEIGHT: float = 360.0

# 难度曲线定义（时间 -> 生成参数）
# spawn_rate: 每秒生成数量
# enemy_hp_mult: 敌人血量乘数
# elite_chance: 精英怪概率
var difficulty_curve: Array[Dictionary] = [
	{"time": 0.0, "spawn_rate": 0.5, "enemy_hp_mult": 1.0, "elite_chance": 0.0},
	{"time": 60.0, "spawn_rate": 1.0, "enemy_hp_mult": 1.2, "elite_chance": 0.05},
	{"time": 180.0, "spawn_rate": 2.0, "enemy_hp_mult": 1.5, "elite_chance": 0.10},
	{"time": 300.0, "spawn_rate": 3.0, "enemy_hp_mult": 2.0, "elite_chance": 0.15},
	{"time": 480.0, "spawn_rate": 4.0, "enemy_hp_mult": 3.0, "elite_chance": 0.20},
	{"time": 600.0, "spawn_rate": 5.0, "enemy_hp_mult": 4.0, "elite_chance": 0.25},
	{"time": 780.0, "spawn_rate": 7.0, "enemy_hp_mult": 5.0, "elite_chance": 0.30},
]

var current_enemy_count: int = 0
var game_time: float = 0.0


# ========== 辅助方法 ==========
func _reset() -> void:
	current_enemy_count = 0
	game_time = 0.0


func _get_difficulty_params(time: float) -> Dictionary:
	"""根据游戏时间获取当前难度参数（线性插值）"""
	# 找到当前时间段
	var lower = difficulty_curve[0]
	var upper = difficulty_curve[0]

	for i in range(difficulty_curve.size()):
		if time >= difficulty_curve[i]["time"]:
			lower = difficulty_curve[i]
			if i + 1 < difficulty_curve.size():
				upper = difficulty_curve[i + 1]
			else:
				upper = difficulty_curve[i]

	# 如果恰好在某个节点上
	if lower["time"] == upper["time"] or time >= upper["time"]:
		return lower.duplicate()

	# 线性插值
	var t = (time - lower["time"]) / (upper["time"] - lower["time"])
	return {
		"time": time,
		"spawn_rate": lerp(lower["spawn_rate"], upper["spawn_rate"], t),
		"enemy_hp_mult": lerp(lower["enemy_hp_mult"], upper["enemy_hp_mult"], t),
		"elite_chance": lerp(lower["elite_chance"], upper["elite_chance"], t),
	}


func _can_spawn() -> bool:
	"""是否可以生成新敌人"""
	return current_enemy_count < MAX_ENEMIES


func _calculate_spawn_position(player_pos: Vector2, angle: float, distance: float) -> Vector2:
	"""计算生成位置（基于角度和距离）"""
	return player_pos + Vector2(cos(angle), sin(angle)) * distance


func _is_position_offscreen(pos: Vector2, player_pos: Vector2) -> bool:
	"""检查位置是否在屏幕外"""
	var relative = pos - player_pos
	return abs(relative.x) > VIEWPORT_HALF_WIDTH or abs(relative.y) > VIEWPORT_HALF_HEIGHT


func _spawn_enemy() -> bool:
	"""尝试生成一个敌人"""
	if not _can_spawn():
		return false
	current_enemy_count += 1
	return true


func _remove_enemy() -> void:
	"""移除一个敌人"""
	if current_enemy_count > 0:
		current_enemy_count -= 1


# ========== 测试方法 ==========
func before_each() -> void:
	_reset()


## 测试初始难度参数（游戏开始）
func test_initial_difficulty() -> void:
	var params = _get_difficulty_params(0.0)
	assert_near(params["spawn_rate"], 0.5, 0.01, "开始时生成率应为0.5/秒")
	assert_near(params["enemy_hp_mult"], 1.0, 0.01, "开始时HP乘数应为1.0")
	assert_near(params["elite_chance"], 0.0, 0.01, "开始时精英概率应为0")


## 测试1分钟难度
func test_difficulty_at_1_minute() -> void:
	var params = _get_difficulty_params(60.0)
	assert_near(params["spawn_rate"], 1.0, 0.01, "1分钟时生成率应为1.0/秒")
	assert_near(params["enemy_hp_mult"], 1.2, 0.01, "1分钟时HP乘数应为1.2")
	assert_near(params["elite_chance"], 0.05, 0.01, "1分钟时精英概率应为5%")


## 测试3分钟难度
func test_difficulty_at_3_minutes() -> void:
	var params = _get_difficulty_params(180.0)
	assert_near(params["spawn_rate"], 2.0, 0.01, "3分钟时生成率应为2.0/秒")
	assert_near(params["enemy_hp_mult"], 1.5, 0.01, "3分钟时HP乘数应为1.5")


## 测试中间时刻插值（30秒应在0秒和60秒之间）
func test_difficulty_interpolation() -> void:
	var params = _get_difficulty_params(30.0)
	assert_in_range(params["spawn_rate"], 0.5, 1.0, "30秒时生成率应在0.5-1.0之间")
	assert_in_range(params["enemy_hp_mult"], 1.0, 1.2, "30秒时HP乘数应在1.0-1.2之间")


## 测试难度曲线单调递增
func test_difficulty_monotonic_increase() -> void:
	var prev_rate: float = 0.0
	var prev_hp: float = 0.0

	for time_point in [0.0, 60.0, 180.0, 300.0, 480.0, 600.0, 780.0]:
		var params = _get_difficulty_params(time_point)
		assert_gte(params["spawn_rate"], prev_rate, "生成率应递增")
		assert_gte(params["enemy_hp_mult"], prev_hp, "HP乘数应递增")
		prev_rate = params["spawn_rate"]
		prev_hp = params["enemy_hp_mult"]


## 测试最大敌人数量限制
func test_max_enemy_limit() -> void:
	# 生成到上限
	for i in range(MAX_ENEMIES):
		assert_true(_spawn_enemy(), "第%d个敌人应能生成" % (i + 1))

	assert_eq(current_enemy_count, MAX_ENEMIES, "敌人数量应为上限")
	assert_false(_can_spawn(), "达到上限后不应能继续生成")
	assert_false(_spawn_enemy(), "超过上限生成应失败")


## 测试移除敌人后可以继续生成
func test_spawn_after_remove() -> void:
	# 填满
	for i in range(MAX_ENEMIES):
		_spawn_enemy()
	assert_false(_can_spawn(), "应满了")

	# 移除一个
	_remove_enemy()
	assert_true(_can_spawn(), "移除后应可以生成")
	assert_true(_spawn_enemy(), "移除后生成应成功")


## 测试生成位置在屏幕外 - 最小距离
func test_spawn_position_offscreen_min() -> void:
	var player_pos = Vector2(0, 0)
	# 测试多个角度
	for angle in [0.0, PI / 4, PI / 2, PI, 3 * PI / 2]:
		var pos = _calculate_spawn_position(player_pos, angle, SPAWN_RADIUS_MIN)
		assert_true(
			_is_position_offscreen(pos, player_pos),
			"最小距离生成应在屏幕外 (angle=%.2f)" % angle
		)


## 测试生成位置在屏幕外 - 最大距离
func test_spawn_position_offscreen_max() -> void:
	var player_pos = Vector2(100, 50)
	for angle in [0.0, PI / 3, PI, 5 * PI / 3]:
		var pos = _calculate_spawn_position(player_pos, angle, SPAWN_RADIUS_MAX)
		assert_true(
			_is_position_offscreen(pos, player_pos),
			"最大距离生成应在屏幕外 (angle=%.2f)" % angle
		)


## 测试生成距离范围
func test_spawn_distance_range() -> void:
	var player_pos = Vector2(0, 0)
	var angle = 0.0

	var pos_min = _calculate_spawn_position(player_pos, angle, SPAWN_RADIUS_MIN)
	var pos_max = _calculate_spawn_position(player_pos, angle, SPAWN_RADIUS_MAX)

	var dist_min = pos_min.distance_to(player_pos)
	var dist_max = pos_max.distance_to(player_pos)

	assert_near(dist_min, SPAWN_RADIUS_MIN, 0.01, "最小距离应为600")
	assert_near(dist_max, SPAWN_RADIUS_MAX, 0.01, "最大距离应为900")


## 测试屏幕内位置判定
func test_position_inside_screen() -> void:
	var player_pos = Vector2(0, 0)
	var inside_pos = Vector2(300, 200)  # 在视口内
	assert_false(
		_is_position_offscreen(inside_pos, player_pos),
		"屏幕内的位置不应被判定为屏幕外"
	)


## 测试游戏结束时的难度（超过最大曲线时间）
func test_difficulty_beyond_max_time() -> void:
	var params = _get_difficulty_params(900.0)  # 15分钟
	# 应该使用最后一个节点的值
	assert_gte(params["spawn_rate"], 5.0, "超时后生成率应至少为最后节点值")


## 测试敌人计数不为负
func test_enemy_count_not_negative() -> void:
	_remove_enemy()  # 尝试在0时移除
	assert_eq(current_enemy_count, 0, "敌人计数不应为负")


## 测试精英怪概率范围
func test_elite_chance_valid_range() -> void:
	for time_point in [0.0, 60.0, 180.0, 300.0, 480.0, 600.0, 780.0]:
		var params = _get_difficulty_params(time_point)
		assert_in_range(
			params["elite_chance"], 0.0, 1.0,
			"精英概率应在0-1范围内 (time=%.0f)" % time_point
		)
