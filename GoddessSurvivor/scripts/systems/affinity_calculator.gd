## 亲密度计算器 - 局内节点，追踪本局成就，游戏结束时计算并提交亲密度
class_name AffinityCalculator
extends Node

# ===== 本局追踪状态 =====
var _reached_stage_2: bool = false
var _reached_stage_3: bool = false
var _reached_stage_4: bool = false
var _ultimate_triggered: bool = false
var _synergy_triggered: bool = false
var _taunt_kill_count: int = 0
var _taunt_kill_window: bool = false
var _taunt_window_timer: float = 0.0
const TAUNT_WINDOW_DURATION: float = 3.0


func _ready() -> void:
	# 连接全局事件
	EventBus.clothing_stage_changed.connect(_on_clothing_stage_changed)
	EventBus.synergy_awakened.connect(_on_synergy_awakened)
	EventBus.taunt_released.connect(_on_taunt_released)
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.game_over.connect(_on_game_over)

	# ClothingSystem.ultimate_triggered 是本地信号，等一帧后从 player 获取
	await get_tree().process_frame
	var player := GameManager.player_node
	if player:
		var clothing := player.get_node_or_null("ClothingSystem") as ClothingSystem
		if clothing:
			clothing.ultimate_triggered.connect(_on_ultimate_triggered)


func _process(delta: float) -> void:
	# 嘲讽击杀窗口计时
	if _taunt_kill_window:
		_taunt_window_timer -= delta
		if _taunt_window_timer <= 0.0:
			_taunt_kill_window = false


# ===== 信号回调 =====

func _on_clothing_stage_changed(new_stage: int, _old_stage: int) -> void:
	if new_stage >= 2:
		_reached_stage_2 = true
	if new_stage >= 3:
		_reached_stage_3 = true
	if new_stage >= 4:
		_reached_stage_4 = true


func _on_synergy_awakened(_char_id: String, _weapon_id: String) -> void:
	_synergy_triggered = true


func _on_ultimate_triggered() -> void:
	_ultimate_triggered = true


func _on_taunt_released(charge_level: int, _pos: Vector2) -> void:
	# 只有满蓄力（level==3 即 ChargeLevel.FULL）才开始计数窗口
	if charge_level == 3:
		_taunt_kill_window = true
		_taunt_window_timer = TAUNT_WINDOW_DURATION


func _on_enemy_killed(_enemy_data: Dictionary) -> void:
	if _taunt_kill_window:
		_taunt_kill_count += 1


func _on_game_over(_kill_count: int, _elapsed_time: float) -> void:
	_calculate_and_save()


# ===== 结算 =====

func _calculate_and_save() -> void:
	var char_id := GameManager.current_character_id
	if char_id.is_empty():
		return

	var old_val := AffinityManager.get_affinity(char_id)

	var delta := 5  # 基础完成
	if _reached_stage_2:
		delta += 3
	if _reached_stage_3:
		delta += 5
	if _reached_stage_4:
		delta += 8
	if _ultimate_triggered:
		delta += 10
	if _synergy_triggered:
		delta += 15
	if _taunt_kill_count >= 50:
		delta += 5

	AffinityManager.add_affinity(char_id, delta)
	var new_val := AffinityManager.get_affinity(char_id)
	var new_unlocks := AffinityManager.get_pending_unlocks(char_id, old_val, new_val)

	# 延迟一帧，确保 GameOver._build_ui 已执行
	EventBus.affinity_updated.emit.call_deferred(char_id, delta, new_val, new_unlocks)

	print("[AffinityCalculator] %s 亲密度 +%d → 总计 %d" % [char_id, delta, new_val])
