## 角色选择界面
class_name CharacterSelect
extends Control

# 三个角色数据（与 character_data.gd 对应）
const CHARACTERS := [
	{
		"id": "rin",
		"name": "凛 (Rin)",
		"desc": "均衡型 · 攻速爆发\n极限形态：攻击范围翻倍",
		"color": Color(1.0, 0.6, 0.7)
	},
	{
		"id": "lin",
		"name": "鳞 (Lin)",
		"desc": "近战型 · 高伤低速\n极限形态：护甲强化",
		"color": Color(0.4, 0.6, 1.0)
	},
	{
		"id": "rei",
		"name": "零 (Rei)",
		"desc": "法术型 · 冷却最短\n极限形态：技能范围+50%",
		"color": Color(0.7, 0.5, 1.0)
	},
]


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	# 全屏深色背景
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 标题
	var title := Label.new()
	title.text = "选择角色"
	title.add_theme_font_size_override("font_size", 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-200, 80)
	title.size = Vector2(400, 60)
	add_child(title)

	# 角色卡片容器（居中水平排列）
	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_CENTER)
	hbox.position = Vector2(-420, -120)
	hbox.size = Vector2(840, 280)
	hbox.add_theme_constant_override("separation", 40)
	add_child(hbox)

	for char_data in CHARACTERS:
		hbox.add_child(_create_char_card(char_data))


func _create_char_card(char_data: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(240, 280)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# 角色像素图
	var texture_rect := TextureRect.new()
	texture_rect.texture = PixelSpriteGenerator.create_character_texture(char_data["id"])
	texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.custom_minimum_size = Vector2(120, 120)
	texture_rect.self_modulate = char_data["color"]
	vbox.add_child(texture_rect)

	# 角色名
	var name_label := Label.new()
	name_label.text = char_data["name"]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(name_label)

	# 描述
	var desc_label := Label.new()
	desc_label.text = char_data["desc"]
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_label)

	# 选择按钮
	var btn := Button.new()
	btn.text = "选择"
	btn.add_theme_font_size_override("font_size", 18)
	var char_id: String = char_data["id"]
	btn.pressed.connect(func() -> void: _on_character_selected(char_id))
	vbox.add_child(btn)

	return panel


func _on_character_selected(char_id: String) -> void:
	GameManager.current_character_id = char_id
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")
