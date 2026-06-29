## 换装宝箱生成器 - 每3-4分钟在玩家附近生成一个宝箱
class_name ChestSpawner
extends Node

const INTERVAL_MIN: float = 180.0  # 3分钟
const INTERVAL_MAX: float = 240.0  # 4分钟
const SPAWN_OFFSET: float = 150.0  # 距玩家距离

var _timer: float = 0.0
var _next_interval: float = 0.0


func _ready() -> void:
	_next_interval = randf_range(INTERVAL_MIN, INTERVAL_MAX)


func _process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	_timer += delta
	if _timer >= _next_interval:
		_timer = 0.0
		_next_interval = randf_range(INTERVAL_MIN, INTERVAL_MAX)
		_spawn_chest()


func _spawn_chest() -> void:
	var player := GameManager.player_node
	if not player:
		return

	var angle := randf() * TAU
	var pos := player.global_position + Vector2(cos(angle), sin(angle)) * SPAWN_OFFSET

	var chest := WardrobeChest.new()
	chest.global_position = pos
	get_tree().current_scene.add_child(chest)
