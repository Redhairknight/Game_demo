## HUD - 游戏内界面显示
## 显示HP条、衣着耐久条、经验条、时间、击杀数等信息
class_name HUD
extends CanvasLayer

# ===== 节点引用（使用find方式，更健壮） =====
var hp_bar: ProgressBar = null
var clothing_bar: ProgressBar = null
var exp_bar: ProgressBar = null
var time_label: Label = null
var kill_label: Label = null
var level_label: Label = null
var clothing_stage_label: Label = null
var taunt_bar: ProgressBar = null

# ===== 状态 =====
var player_ref: PlayerController = null
var clothing_ref: ClothingSystem = null
var taunt_ref: TauntSystem = null
var exp_ref: ExpSystem = null


func _ready() -> void:
	# 等待一帧确保所有节点已创建
	await get_tree().process_frame
	_find_ui_nodes()
	_find_references()
	_connect_signals()

	# 初始化显示
	if taunt_bar:
		taunt_bar.visible = false


func _process(_delta: float) -> void:
	# 更新时间显示
	if time_label:
		time_label.text = GameManager.get_time_string()

	# 更新挑逗蓄力条
	_update_taunt_bar()


# ===== 查找UI节点 =====

func _find_ui_nodes() -> void:
	hp_bar = _find_node_by_name("HPBar") as ProgressBar
	clothing_bar = _find_node_by_name("ClothingBar") as ProgressBar
	exp_bar = _find_node_by_name("ExpBar") as ProgressBar
	time_label = _find_node_by_name("TimeLabel") as Label
	kill_label = _find_node_by_name("KillLabel") as Label
	level_label = _find_node_by_name("LevelLabel") as Label
	clothing_stage_label = _find_node_by_name("ClothingStageLabel") as Label
	taunt_bar = _find_node_by_name("TauntBar") as ProgressBar


func _find_node_by_name(node_name: String) -> Node:
	return _recursive_find(self, node_name)


func _recursive_find(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child in node.get_children():
		var result := _recursive_find(child, target_name)
		if result:
			return result
	return null


# ===== 查找引用 =====

func _find_references() -> void:
	player_ref = GameManager.player_node as PlayerController
	if player_ref:
		clothing_ref = player_ref.get_node_or_null("ClothingSystem") as ClothingSystem
		taunt_ref = player_ref.get_node_or_null("TauntSystem") as TauntSystem
		exp_ref = player_ref.get_node_or_null("ExpSystem") as ExpSystem


# ===== 信号连接 =====

func _connect_signals() -> void:
	# 玩家HP
	if player_ref:
		player_ref.hp_changed.connect(_on_hp_changed)
		_on_hp_changed(player_ref.current_hp, player_ref.max_hp)

	# 衣着系统
	if clothing_ref:
		clothing_ref.durability_changed.connect(_on_clothing_changed)
		clothing_ref.stage_changed.connect(_on_clothing_stage_changed)

	# 经验系统
	if exp_ref:
		exp_ref.exp_changed.connect(_on_exp_changed)
		exp_ref.leveled_up.connect(_on_level_changed)

	# 击杀数
	GameManager.kill_count_changed.connect(_on_kill_count_changed)

	# 挑逗系统
	if taunt_ref:
		taunt_ref.charge_started.connect(_on_taunt_started)
		taunt_ref.charge_released.connect(_on_taunt_released)
		taunt_ref.charge_interrupted.connect(_on_taunt_interrupted)

	# 协同觉醒提示
	EventBus.synergy_awakened.connect(_on_synergy_awakened)


# ===== 更新回调 =====

func _on_hp_changed(current_hp: float, max_hp: float) -> void:
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = current_hp


func _on_clothing_changed(current: float, max_value: float) -> void:
	if clothing_bar:
		clothing_bar.max_value = max_value
		clothing_bar.value = current


func _on_clothing_stage_changed(new_stage: int, _old_stage: int) -> void:
	if clothing_stage_label:
		var stage_names := ["完好", "轻微破损", "中度破损", "严重破损", "极限!"]
		if new_stage < stage_names.size():
			clothing_stage_label.text = stage_names[new_stage]

		# 根据阶段变色
		var stage_colors := [Color.GREEN, Color.YELLOW_GREEN, Color.YELLOW, Color.ORANGE, Color.RED]
		if new_stage < stage_colors.size():
			clothing_stage_label.modulate = stage_colors[new_stage]


func _on_exp_changed(current_exp: int, needed_exp: int) -> void:
	if exp_bar:
		exp_bar.max_value = needed_exp
		exp_bar.value = current_exp


func _on_level_changed(new_level: int) -> void:
	if level_label:
		level_label.text = "Lv.%d" % new_level


func _on_kill_count_changed(count: int) -> void:
	if kill_label:
		kill_label.text = "击杀: %d" % count


# ===== 挑逗条更新 =====

func _on_taunt_started() -> void:
	if taunt_bar:
		taunt_bar.visible = true


func _on_taunt_released(_level: int) -> void:
	if taunt_bar:
		taunt_bar.visible = false
		taunt_bar.value = 0


func _on_taunt_interrupted() -> void:
	if taunt_bar:
		taunt_bar.visible = false
		taunt_bar.value = 0


func _update_taunt_bar() -> void:
	if taunt_ref and taunt_ref.is_charging and taunt_bar:
		taunt_bar.value = taunt_ref.get_charge_progress() * 100.0


func _on_synergy_awakened(character_id: String, _weapon_id: String) -> void:
	var banners := {
		"rin": {"text": "✦ 心跳弹幕·星之告白 ✦",   "color": Color(1.0, 0.4, 0.7)},
		"lin": {"text": "✦ 逆鳞之舞·裸剑觉醒 ✦",   "color": Color(0.7, 0.7, 1.0)},
		"rei": {"text": "✦ 以太共振·雷霆解放 ✦",   "color": Color(0.6, 0.4, 1.0)},
	}
	var config: Dictionary = banners.get(character_id, banners["rin"])

	var label := Label.new()
	label.text = config["text"]
	label.add_theme_font_size_override("font_size", 36)
	label.add_theme_color_override("font_color", config["color"])
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.position = Vector2(-400, -30)
	label.size = Vector2(800, 60)
	add_child(label)

	label.scale = Vector2(0.5, 0.5)
	var tween := label.create_tween()
	tween.tween_property(label, "scale", Vector2(1.2, 1.2), 0.2)
	tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.2)
	tween.tween_interval(1.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.4)
	tween.tween_callback(label.queue_free)
