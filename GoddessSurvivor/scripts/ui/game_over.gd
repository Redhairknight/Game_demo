## 游戏结束界面
class_name GameOver
extends CanvasLayer


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	GameManager.state_changed.connect(_on_state_changed)
	EventBus.game_over.connect(_on_game_over)


func _on_game_over(kill_count: int, elapsed_time: float) -> void:
	_build_ui(kill_count, elapsed_time)
	visible = true


func _on_state_changed(new_state: GameManager.GameState) -> void:
	if new_state != GameManager.GameState.GAME_OVER:
		visible = false


func _build_ui(kill_count: int, elapsed_time: float) -> void:
	# 清除旧 UI（再来一局时会重建）
	for child in get_children():
		child.queue_free()

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-200, -180)
	panel.size = Vector2(400, 360)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "游戏结束"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	vbox.add_child(title)

	# 统计
	var minutes := int(elapsed_time) / 60
	var seconds := int(elapsed_time) % 60
	var time_str := "%02d:%02d" % [minutes, seconds]

	for stat: String in [
		"存活时间: " + time_str,
		"击杀数: %d" % kill_count,
		"最终等级: Lv.%d" % GameManager.current_level,
	]:
		var lbl := Label.new()
		lbl.text = stat
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 22)
		vbox.add_child(lbl)

	var retry_btn := Button.new()
	retry_btn.text = "再来一局"
	retry_btn.add_theme_font_size_override("font_size", 22)
	retry_btn.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/main/boot.tscn")
	)
	vbox.add_child(retry_btn)

	var quit_btn := Button.new()
	quit_btn.text = "退出到桌面"
	quit_btn.add_theme_font_size_override("font_size", 22)
	quit_btn.pressed.connect(func() -> void: get_tree().quit())
	vbox.add_child(quit_btn)
