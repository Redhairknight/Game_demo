## 游戏结束界面
class_name GameOver
extends CanvasLayer

var _affinity_panel_parent: VBoxContainer = null


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	GameManager.state_changed.connect(_on_state_changed)
	EventBus.game_over.connect(_on_game_over)
	EventBus.affinity_updated.connect(_on_affinity_updated)


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
	panel.position = Vector2(-240, -220)
	panel.size = Vector2(480, 460)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)
	_affinity_panel_parent = vbox

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


func _on_affinity_updated(char_id: String, delta: int, new_total: int, new_unlocks: Array) -> void:
	if not _affinity_panel_parent:
		return
	_show_affinity_result(_affinity_panel_parent, char_id, delta, new_total, new_unlocks)


func _show_affinity_result(vbox: VBoxContainer, char_id: String, delta: int, new_total: int, new_unlocks: Array) -> void:
	var sep := HSeparator.new()
	vbox.add_child(sep)

	var char_names := {"rin": "铃 (Rin)", "lin": "凛 (Lin)", "rei": "零 (Rei)"}
	var char_name: String = char_names.get(char_id, char_id)

	var affinity_lbl := Label.new()
	affinity_lbl.text = "亲密度  %s   +%d ★" % [char_name, delta]
	affinity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	affinity_lbl.add_theme_font_size_override("font_size", 20)
	affinity_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	vbox.add_child(affinity_lbl)

	var next_threshold := AffinityManager.get_next_unlock_threshold(char_id)
	var progress_text: String
	if next_threshold == -1:
		progress_text = "当前: %d（已全部解锁！）" % new_total
	else:
		progress_text = "当前: %d / 下一解锁: %d" % [new_total, next_threshold]

	var progress_lbl := Label.new()
	progress_lbl.text = progress_text
	progress_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_lbl.add_theme_font_size_override("font_size", 16)
	vbox.add_child(progress_lbl)

	for unlock in new_unlocks:
		var unlock_lbl := Label.new()
		unlock_lbl.text = "🔓 " + unlock.get("desc", "")
		unlock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		unlock_lbl.add_theme_font_size_override("font_size", 16)
		unlock_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.6))
		vbox.add_child(unlock_lbl)
