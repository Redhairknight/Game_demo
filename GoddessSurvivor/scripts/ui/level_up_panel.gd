## 升级选择面板 - 显示升级选项供玩家选择
## 暂停时显示，选择后恢复游戏
class_name LevelUpPanel
extends Control

# ===== 信号 =====
signal option_selected(option_data: Dictionary)

# ===== 导出属性 =====
@export var option_button_scene: PackedScene = null  # 选项按钮场景
@export var animation_duration: float = 0.3          # 动画时长

# ===== 节点引用 =====
@onready var title_label: Label = $PanelContainer/VBoxContainer/TitleLabel
@onready var options_container: VBoxContainer = $PanelContainer/VBoxContainer/OptionsContainer
@onready var panel_container: PanelContainer = $PanelContainer

# ===== 状态 =====
var current_options: Array[Dictionary] = []
var exp_system: ExpSystem = null


func _ready() -> void:
	# 默认隐藏
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS  # 暂停时也能交互

	# 连接GameManager状态变化
	GameManager.state_changed.connect(_on_game_state_changed)

	# 等待一帧后获取经验系统
	await get_tree().process_frame
	if GameManager.player_node:
		exp_system = GameManager.player_node.get_node_or_null("ExpSystem") as ExpSystem


# ===== 显示/隐藏 =====

## 显示升级面板
func show_panel() -> void:
	# 生成选项
	if exp_system:
		current_options = exp_system.generate_level_up_options()
	else:
		current_options = _generate_default_options()

	# 清除旧选项按钮
	_clear_options()

	# 创建选项按钮
	for i in range(current_options.size()):
		_create_option_button(current_options[i], i)

	# 更新标题
	if title_label:
		title_label.text = "等级提升! Lv.%d" % GameManager.current_level

	# 显示动画
	visible = true
	_play_show_animation()


## 隐藏面板
func hide_panel() -> void:
	_play_hide_animation()


# ===== 选项按钮 =====

## 创建选项按钮
func _create_option_button(option_data: Dictionary, index: int) -> void:
	if option_button_scene:
		# 使用自定义按钮场景
		var button := option_button_scene.instantiate()
		if button.has_method("setup"):
			button.setup(option_data)
		if button.has_signal("pressed"):
			button.pressed.connect(func() -> void: _on_option_pressed(index))
		options_container.add_child(button)
	else:
		# 使用默认按钮
		var button := Button.new()
		button.text = "%s\n%s" % [option_data.get("name", "???"), option_data.get("description", "")]
		button.custom_minimum_size = Vector2(300, 80)
		button.pressed.connect(func() -> void: _on_option_pressed(index))

		# 简单样式
		button.add_theme_font_size_override("font_size", 16)
		options_container.add_child(button)


## 清除所有选项按钮
func _clear_options() -> void:
	if options_container:
		for child in options_container.get_children():
			child.queue_free()


# ===== 选项处理 =====

## 选项被点击
func _on_option_pressed(index: int) -> void:
	if index < 0 or index >= current_options.size():
		return

	var selected_option := current_options[index]
	print("[LevelUpPanel] 选择: %s" % selected_option.get("name", "???"))

	# 应用选项效果
	_apply_option(selected_option)

	# 发出信号
	option_selected.emit(selected_option)

	# 隐藏面板并恢复游戏
	hide_panel()
	GameManager.resume_game()


## 应用选项效果
func _apply_option(option: Dictionary) -> void:
	var option_type: String = option.get("type", "")
	var player := GameManager.player_node

	match option_type:
		"weapon":
			_apply_weapon_option(option, player)
		"passive":
			_apply_passive_option(option, player)
		"liberation":
			_apply_liberation_option(option, player)
		"special":
			_apply_special_option(option, player)


## 应用武器选项
func _apply_weapon_option(option: Dictionary, player: Node) -> void:
	if not player:
		return

	if option.get("is_new", false):
		# 新武器 - 需要添加武器节点（简化处理）
		print("[LevelUpPanel] 新武器: %s (需要实例化场景)" % option.get("id", ""))
	else:
		# 升级现有武器
		var target: WeaponBase = option.get("target_node", null)
		if target and is_instance_valid(target):
			target.level_up()


## 应用被动选项
func _apply_passive_option(option: Dictionary, player: Node) -> void:
	if not player:
		return

	var stat: String = option.get("stat", "")
	var value: float = option.get("value", 0.0)

	match stat:
		"max_hp":
			if player is PlayerController:
				player.max_hp += value
				player.current_hp += value
				player.hp_changed.emit(player.current_hp, player.max_hp)
		"move_speed":
			if player is PlayerController:
				player.move_speed *= (1.0 + value)
		"pickup_range":
			if player is PlayerController:
				player.pickup_range *= (1.0 + value)
		"damage":
			# 全局伤害加成（通过衣着系统或独立变量）
			pass
		"cooldown":
			# 全局冷却缩减
			pass
		"armor":
			# 衣着耐久消耗减少
			pass


## 应用解放选项
func _apply_liberation_option(option: Dictionary, player: Node) -> void:
	if not player:
		return

	var clothing := player.get_node_or_null("ClothingSystem") as ClothingSystem
	if clothing:
		match option.get("id", ""):
			"clothing_restore":
				clothing.restore_durability(30.0)


## 应用特殊选项
func _apply_special_option(option: Dictionary, player: Node) -> void:
	if not player:
		return

	match option.get("id", ""):
		"heal_full":
			if player is PlayerController:
				player.heal(player.max_hp)
		"exp_magnet":
			# 吸收所有经验宝石
			var gems := player.get_tree().get_nodes_in_group("exp_gems")
			for gem in gems:
				if gem.has_method("collect"):
					gem.collect(player)
		"bomb":
			# 清屏
			var enemies := player.get_tree().get_nodes_in_group("enemies")
			for enemy in enemies:
				if enemy.has_method("take_damage"):
					enemy.take_damage(99999.0)


# ===== 动画 =====

func _play_show_animation() -> void:
	if panel_container:
		panel_container.modulate.a = 0.0
		panel_container.scale = Vector2(0.8, 0.8)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(panel_container, "modulate:a", 1.0, animation_duration)
		tween.tween_property(panel_container, "scale", Vector2.ONE, animation_duration).set_trans(Tween.TRANS_BACK)


func _play_hide_animation() -> void:
	if panel_container:
		var tween := create_tween()
		tween.tween_property(panel_container, "modulate:a", 0.0, animation_duration * 0.5)
		tween.tween_callback(func() -> void: visible = false)
	else:
		visible = false


# ===== 状态监听 =====

func _on_game_state_changed(new_state: GameManager.GameState) -> void:
	if new_state == GameManager.GameState.LEVEL_UP:
		show_panel()


# ===== 默认选项（备用） =====

func _generate_default_options() -> Array[Dictionary]:
	return [
		{"type": "passive", "id": "max_hp_up", "name": "生命强化", "description": "最大HP +20", "stat": "max_hp", "value": 20.0},
		{"type": "passive", "id": "speed_up", "name": "疾步", "description": "移动速度 +10%", "stat": "move_speed", "value": 0.1},
		{"type": "passive", "id": "damage_up", "name": "力量", "description": "全伤害 +15%", "stat": "damage", "value": 0.15},
	]
