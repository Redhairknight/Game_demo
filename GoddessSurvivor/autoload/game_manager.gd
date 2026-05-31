## 游戏管理器 - 全局单例
## 管理游戏状态、时间、统计数据等核心游戏流程
class_name GameManagerClass
extends Node

# ===== 游戏状态枚举 =====
enum GameState {
	MENU,       # 主菜单
	PLAYING,    # 游戏进行中
	PAUSED,     # 暂停
	LEVEL_UP,   # 升级选择界面
	GAME_OVER   # 游戏结束
}

# ===== 信号 =====
signal state_changed(new_state: GameState)
signal time_updated(elapsed_time: float)
signal kill_count_changed(count: int)

# ===== 当前游戏状态 =====
var current_state: GameState = GameState.MENU:
	set(value):
		var old_state = current_state
		current_state = value
		state_changed.emit(current_state)
		_on_state_changed(old_state, current_state)

# ===== 游戏数据 =====
var current_character_id: String = ""   # 当前选择的角色ID
var elapsed_time: float = 0.0           # 游戏经过时间（秒）
var kill_count: int = 0                 # 击杀数
var total_exp: int = 0                  # 总经验值
var current_level: int = 1             # 当前等级
var player_node: CharacterBody2D = null # 玩家节点引用

# ===== 配置 =====
@export var max_game_time: float = 1800.0  # 最大游戏时间30分钟


# ===== 生命周期 =====
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # 确保暂停时也能处理


func _process(delta: float) -> void:
	if current_state == GameState.PLAYING:
		elapsed_time += delta
		time_updated.emit(elapsed_time)

		# 检查是否到达最大时间
		if elapsed_time >= max_game_time:
			_on_max_time_reached()


# ===== 公共接口 =====

## 开始游戏
func start_game(character_id: String) -> void:
	_reset_game_data()
	current_character_id = character_id
	current_state = GameState.PLAYING
	get_tree().paused = false
	print("[GameManager] 游戏开始 - 角色: %s" % character_id)


## 结束游戏
func end_game() -> void:
	current_state = GameState.GAME_OVER
	get_tree().paused = true
	EventBus.game_over.emit(kill_count, elapsed_time)
	print("[GameManager] 游戏结束 - 击杀: %d, 时间: %.1f秒" % [kill_count, elapsed_time])


## 暂停游戏
func pause_game() -> void:
	if current_state == GameState.PLAYING:
		current_state = GameState.PAUSED
		get_tree().paused = true


## 恢复游戏
func resume_game() -> void:
	if current_state == GameState.PAUSED or current_state == GameState.LEVEL_UP:
		current_state = GameState.PLAYING
		get_tree().paused = false


## 进入升级选择状态
func enter_level_up() -> void:
	if current_state == GameState.PLAYING:
		current_state = GameState.LEVEL_UP
		get_tree().paused = true


## 切换暂停（用于暂停按键）
func toggle_pause() -> void:
	if current_state == GameState.PLAYING:
		pause_game()
	elif current_state == GameState.PAUSED:
		resume_game()


## 增加击杀数
func add_kill() -> void:
	kill_count += 1
	kill_count_changed.emit(kill_count)


## 增加经验值
func add_exp(amount: int) -> void:
	total_exp += amount


## 获取格式化的游戏时间字符串
func get_time_string() -> String:
	var minutes := int(elapsed_time) / 60
	var seconds := int(elapsed_time) % 60
	return "%02d:%02d" % [minutes, seconds]


## 获取游戏难度系数（随时间增加）
func get_difficulty_multiplier() -> float:
	return 1.0 + (elapsed_time / 60.0) * 0.5  # 每分钟增加50%难度


# ===== 内部方法 =====

## 重置游戏数据
func _reset_game_data() -> void:
	elapsed_time = 0.0
	kill_count = 0
	total_exp = 0
	current_level = 1
	current_character_id = ""
	player_node = null


## 状态切换时的处理逻辑
func _on_state_changed(_old_state: GameState, new_state: GameState) -> void:
	match new_state:
		GameState.MENU:
			get_tree().paused = false
		GameState.PLAYING:
			get_tree().paused = false
		GameState.PAUSED:
			get_tree().paused = true
		GameState.LEVEL_UP:
			get_tree().paused = true
		GameState.GAME_OVER:
			get_tree().paused = true


func _on_max_time_reached() -> void:
	# 30分钟后可以触发Boss战或胜利
	print("[GameManager] 达到最大游戏时间!")
