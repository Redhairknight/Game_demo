## 敌人生成器单元测试
## mock 与 enemy_spawner.gd 实现对齐：
##   - max_enemies = 200，base_spawn_interval = 1.0
##   - spawn_distance = 600.0（固定，非 min/max）
##   - 精英：base_chance=0.05，每分钟+0.02
##   - 波次：每30秒一波，当前波次×5额外敌人
extends "res://tests/test_runner.gd".TestSuite

# ===== 与真实代码匹配的常量 =====
const MAX_ENEMIES: int = 200
const SPAWN_DISTANCE: float = 600.0
const BASE_SPAWN_INTERVAL: float = 1.0
const ELITE_CHANCE_BASE: float = 0.05
const ELITE_CHANCE_PER_MINUTE: float = 0.02
const WAVE_INTERVAL: float = 30.0
const WAVE_ENEMY_COUNT: int = 15

# ===== mock 状态 =====
var current_enemy_count: int = 0
var elapsed_time: float = 0.0


# ===== 辅助方法 =====
func _reset() -> void:
	current_enemy_count = 0
	elapsed_time = 0.0


func _can_spawn() -> bool:
	return current_enemy_count < MAX_ENEMIES


func _spawn_one() -> bool:
	if not _can_spawn():
		return false
	current_enemy_count += 1
	return true


func _remove_enemy() -> void:
	if current_enemy_count > 0:
		current_enemy_count -= 1


func _get_elite_chance(elapsed_seconds: float) -> float:
	var minutes := elapsed_seconds / 60.0
	return ELITE_CHANCE_BASE + minutes * ELITE_CHANCE_PER_MINUTE


func _get_wave_count(wave_number: int) -> int:
	return WAVE_ENEMY_COUNT + wave_number * 5


func _calculate_spawn_position(player_pos: Vector2, angle: float) -> Vector2:
	return player_pos + Vector2(cos(angle), sin(angle)) * SPAWN_DISTANCE


# ===== 测试方法 =====
func before_each() -> void:
	_reset()


## 测试初始状态
func test_initial_state() -> void:
	assert_eq(current_enemy_count, 0, "初始敌人数量为0")
	assert_true(_can_spawn(), "初始应可生成")


## 测试最大敌人数量限制（200）
func test_max_enemy_limit() -> void:
	for i in range(MAX_ENEMIES):
		assert_true(_spawn_one(), "第%d个敌人应能生成" % (i + 1))
	assert_eq(current_enemy_count, MAX_ENEMIES, "敌人数量应达到上限200")
	assert_false(_can_spawn(), "达到上限后不应能继续生成")
	assert_false(_spawn_one(), "超过上限生成应失败")


## 测试移除后可继续生成
func test_spawn_after_remove() -> void:
	for i in range(MAX_ENEMIES):
		_spawn_one()
	assert_false(_can_spawn(), "应满了")
	_remove_enemy()
	assert_true(_can_spawn(), "移除后应可生成")
	assert_true(_spawn_one(), "移除后生成应成功")


## 测试敌人计数不为负
func test_enemy_count_not_negative() -> void:
	_remove_enemy()
	assert_eq(current_enemy_count, 0, "敌人计数不应为负")


## 测试生成距离固定600
func test_spawn_distance() -> void:
	var player_pos := Vector2(0, 0)
	for angle in [0.0, PI / 4, PI / 2, PI]:
		var pos := _calculate_spawn_position(player_pos, angle)
		assert_near(pos.distance_to(player_pos), SPAWN_DISTANCE, 0.01,
			"生成距离应为%.0f" % SPAWN_DISTANCE)


## 测试0秒精英概率=5%
func test_elite_chance_at_start() -> void:
	assert_near(_get_elite_chance(0.0), 0.05, 0.001, "开始时精英概率应为5%")


## 测试1分钟精英概率=7%
func test_elite_chance_at_1_minute() -> void:
	assert_near(_get_elite_chance(60.0), 0.07, 0.001, "1分钟时精英概率应为7%")


## 测试精英概率随时间增加
func test_elite_chance_increases_with_time() -> void:
	var chance_0 := _get_elite_chance(0.0)
	var chance_60 := _get_elite_chance(60.0)
	var chance_300 := _get_elite_chance(300.0)
	assert_true(chance_60 > chance_0, "1分钟时精英概率应大于开始")
	assert_true(chance_300 > chance_60, "5分钟时精英概率应大于1分钟")


## 测试精英概率在合理范围
func test_elite_chance_valid_range() -> void:
	for t in [0.0, 60.0, 180.0, 300.0, 600.0]:
		var chance := _get_elite_chance(t)
		assert_true(chance >= 0.0, "精英概率不应为负")
		assert_true(chance <= 1.0, "精英概率不应超过1")


## 测试第1波敌人数量=15+1×5=20
func test_wave_1_count() -> void:
	assert_eq(_get_wave_count(1), 20, "第1波应有20个敌人")


## 测试第2波敌人数量=15+2×5=25
func test_wave_2_count() -> void:
	assert_eq(_get_wave_count(2), 25, "第2波应有25个敌人")


## 测试波次数量随波数增加
func test_wave_count_increases() -> void:
	assert_true(_get_wave_count(2) > _get_wave_count(1), "后续波次应比前一波更多")
	assert_true(_get_wave_count(3) > _get_wave_count(2), "波次数量应单调递增")
