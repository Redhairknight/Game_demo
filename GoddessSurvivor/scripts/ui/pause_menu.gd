## 暂停菜单
class_name PauseMenu
extends CanvasLayer

var _panel: PanelContainer


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false
	GameManager.state_changed.connect(_on_state_changed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_just_pressed("pause"):
		if GameManager.current_state == GameManager.GameState.PLAYING:
			GameManager.pause_game()
		elif GameManager.current_state == GameManager.GameState.PAUSED:
			GameManager.resume_game()


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.position = Vector2(-160, -120)
	_panel.size = Vector2(320, 240)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	_panel.add_child(vbox)

	var title := Label.new()
	title.text = "暂停"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	vbox.add_child(title)

	var resume_btn := Button.new()
	resume_btn.text = "继续游戏"
	resume_btn.add_theme_font_size_override("font_size", 22)
	resume_btn.pressed.connect(GameManager.resume_game)
	vbox.add_child(resume_btn)

	var quit_btn := Button.new()
	quit_btn.text = "退出到桌面"
	quit_btn.add_theme_font_size_override("font_size", 22)
	quit_btn.pressed.connect(func() -> void: get_tree().quit())
	vbox.add_child(quit_btn)


func _on_state_changed(new_state: GameManager.GameState) -> void:
	visible = (new_state == GameManager.GameState.PAUSED)
