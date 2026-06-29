## 衣着系统 - 管理衣着耐久度和阶段变化
## 作为子节点挂载在玩家身上
class_name ClothingSystem
extends Node

# ===== 信号 =====
signal durability_changed(current: float, max_value: float)
signal stage_changed(new_stage: int, old_stage: int)
signal ultimate_triggered()  # 极限形态触发

# ===== 衣着阶段枚举 =====
enum ClothingStage {
	INTACT = 0,     # 完好
	SLIGHT = 1,     # 轻微破损
	MODERATE = 2,   # 中度破损
	SEVERE = 3,     # 严重破损
	EXTREME = 4     # 极限形态
}

# ===== 导出属性 =====
@export_group("耐久度设置")
@export var max_durability: float = 100.0        # 最大耐久度
@export var stage_thresholds: Array[float] = [80.0, 60.0, 40.0, 20.0, 0.0]  # 阶段阈值

@export_group("极限形态")
@export var ultimate_duration: float = 30.0      # 极限形态持续时间
@export var ultimate_invincible: bool = true     # 极限形态无敌

@export_group("阶段加成")
## 每阶段的攻击加成系数 [完好, 轻微, 中度, 严重, 极限]
@export var attack_bonus: Array[float] = [1.0, 1.1, 1.25, 1.5, 2.0]
## 每阶段的速度加成系数
@export var speed_bonus: Array[float] = [1.0, 1.0, 1.05, 1.1, 1.3]
## 每阶段的防御加成系数（越破损防御越低）
@export var defense_bonus: Array[float] = [1.0, 0.95, 0.85, 0.7, 0.5]

# ===== 状态变量 =====
var current_durability: float
var current_stage: ClothingStage = ClothingStage.INTACT
var is_in_ultimate: bool = false        # 是否在极限形态中
var player: PlayerController = null

# ===== 节点引用 =====
var ultimate_timer: Timer = null


func _ready() -> void:
	current_durability = max_durability

	# 获取玩家引用
	player = get_parent() as PlayerController

	# 设置极限形态计时器
	_setup_ultimate_timer()


# ===== 公共接口 =====

## 减少耐久度
func reduce_durability(amount: float) -> void:
	if is_in_ultimate:
		return  # 极限形态不减耐久

	var old_durability := current_durability
	current_durability = clampf(current_durability - amount, 0.0, max_durability)

	durability_changed.emit(current_durability, max_durability)
	EventBus.clothing_durability_changed.emit(current_durability, max_durability)

	# 检查阶段变化
	_check_stage_change()

	# 检查是否触发极限形态
	if current_durability <= 0.0 and old_durability > 0.0:
		_trigger_ultimate()


## 恢复耐久度
func restore_durability(amount: float) -> void:
	if is_in_ultimate:
		return

	current_durability = clampf(current_durability + amount, 0.0, max_durability)
	durability_changed.emit(current_durability, max_durability)
	EventBus.clothing_durability_changed.emit(current_durability, max_durability)
	_check_stage_change()


## 强制降低一个阶段（满蓄挑逗释放时使用）
func force_stage_down() -> void:
	if current_stage < ClothingStage.EXTREME:
		# 将耐久度降至下一阶段的阈值
		var next_stage := int(current_stage) + 1
		if next_stage < stage_thresholds.size():
			current_durability = stage_thresholds[next_stage]
			durability_changed.emit(current_durability, max_durability)
			EventBus.clothing_durability_changed.emit(current_durability, max_durability)
			_check_stage_change()


## 获取当前攻击力加成
func get_attack_multiplier() -> float:
	return attack_bonus[int(current_stage)]


## 获取当前速度加成
func get_speed_multiplier() -> float:
	return speed_bonus[int(current_stage)]


## 获取当前防御加成
func get_defense_multiplier() -> float:
	return defense_bonus[int(current_stage)]


## 获取耐久度百分比
func get_durability_percent() -> float:
	return current_durability / max_durability


## 获取当前阶段 (0-4)
func get_current_stage() -> int:
	return int(current_stage)


# ===== 内部方法 =====

## 检查阶段变化
func _check_stage_change() -> void:
	var new_stage := _calculate_stage()
	if new_stage != current_stage:
		var old_stage := current_stage
		current_stage = new_stage
		_apply_stage_effects(new_stage)
		stage_changed.emit(int(new_stage), int(old_stage))
		EventBus.clothing_stage_changed.emit(int(new_stage), int(old_stage))
		print("[ClothingSystem] 衣着阶段变化: %d -> %d" % [int(old_stage), int(new_stage)])


## 根据耐久度计算当前阶段
func _calculate_stage() -> ClothingStage:
	for i in range(stage_thresholds.size()):
		if current_durability > stage_thresholds[i]:
			return i as ClothingStage
	return ClothingStage.EXTREME


## 应用阶段效果
func _apply_stage_effects(stage: ClothingStage) -> void:
	if not player:
		return

	# 更新内置速度加成
	player.speed_multiplier = speed_bonus[int(stage)]

	# 读取角色专属暴露加成
	var char_data := CharacterData.get_character_by_id(GameManager.current_character_id)
	if not char_data:
		return

	var cumulative := char_data.get_cumulative_bonus(int(stage))

	# 伤害倍率（累积 damage_bonus）
	player.damage_multiplier = 1.0 + cumulative.get("damage_bonus", 0.0)

	# 攻速 → 冷却倍率（cumulative attack_speed_bonus 换算：+15% 攻速 = 冷却 × 0.87）
	var atk_spd: float = cumulative.get("attack_speed_bonus", 0.0)
	player.cooldown_multiplier = 1.0 / (1.0 + atk_spd) if atk_spd > 0.0 else 1.0

	# 速度：叠加角色专属移速加成到内置加成上
	var extra_spd: float = cumulative.get("speed_bonus", 0.0)
	player.speed_multiplier = speed_bonus[int(stage)] * (1.0 + extra_spd)

	# 特殊效果列表
	var specials: Array = cumulative.get("specials", [])
	player.active_specials = specials

	# exp_range_double：经验拾取范围翻倍
	var has_exp_double := specials.has("exp_range_double")
	var base_range := player.pickup_range
	var pickup_area := player.get_node_or_null("PickupArea") as Area2D
	if pickup_area:
		var col := pickup_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if col and col.shape is CircleShape2D:
			(col.shape as CircleShape2D).radius = base_range * (2.0 if has_exp_double else 1.0)


## 触发极限形态
func _trigger_ultimate() -> void:
	is_in_ultimate = true
	ultimate_triggered.emit()

	# 玩家无敌
	if player and ultimate_invincible:
		player.is_invincible = true

	# 应用极限状态加成
	if player:
		player.speed_multiplier = speed_bonus[int(ClothingStage.EXTREME)]

	# 开始计时
	ultimate_timer.start(ultimate_duration)

	print("[ClothingSystem] 极限形态触发! 持续 %.1f 秒" % ultimate_duration)


## 极限形态结束
func _on_ultimate_timer_timeout() -> void:
	is_in_ultimate = false

	# 恢复一定耐久度（恢复到严重破损）
	current_durability = stage_thresholds[int(ClothingStage.SEVERE)]
	durability_changed.emit(current_durability, max_durability)
	_check_stage_change()

	# 取消无敌
	if player:
		player.is_invincible = false

	print("[ClothingSystem] 极限形态结束")


## 设置极限形态计时器
func _setup_ultimate_timer() -> void:
	ultimate_timer = Timer.new()
	ultimate_timer.name = "UltimateTimer"
	ultimate_timer.one_shot = true
	add_child(ultimate_timer)
	ultimate_timer.timeout.connect(_on_ultimate_timer_timeout)
