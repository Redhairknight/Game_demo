## 换装面板 - 3选1换装界面
## 暂停游戏，显示3套服装选项，玩家选择后恢复
class_name WardrobePanel
extends CanvasLayer

signal outfit_selected(outfit_id: String, restore_durability: bool)

# 换装选项数据（美术资产留空，后续补充）
const OUTFITS_BY_CHARACTER := {
	"rin": [
		{"id": "school_uniform",  "name": "学院制服",   "desc": "均衡·裙摆破损路线",      "color": Color(0.3, 0.5, 0.9)},
		{"id": "swimsuit",        "name": "学校泳装",   "desc": "攻速+30%·起始阶段2",     "color": Color(0.9, 0.5, 0.7)},
		{"id": "cheerleader",     "name": "啦啦队服",   "desc": "移速+25%·裙摆路线",      "color": Color(0.9, 0.3, 0.3)},
	],
	"lin": [
		{"id": "knight_armor",    "name": "骑士甲胄",   "desc": "高HP·肩甲脱落路线",      "color": Color(0.7, 0.7, 0.8)},
		{"id": "battle_bikini",   "name": "战斗比基尼", "desc": "伤害+20%·直接阶段2",     "color": Color(0.8, 0.4, 0.2)},
		{"id": "maid_armor",      "name": "女仆护甲",   "desc": "冷却-15%",               "color": Color(0.2, 0.2, 0.3)},
	],
	"rei": [
		{"id": "magic_dress",     "name": "魔法礼裙",   "desc": "均衡·裙摆碎裂路线",      "color": Color(0.5, 0.3, 0.8)},
		{"id": "mage_robe",       "name": "法师长袍",   "desc": "伤害+25%·经验+30%",     "color": Color(0.2, 0.6, 0.9)},
		{"id": "witch_outfit",    "name": "女巫装",     "desc": "技能范围+20%",           "color": Color(0.8, 0.2, 0.8)},
	],
}

var _pending_chest: WardrobeChest = null


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func show_panel(chest: WardrobeChest) -> void:
	_pending_chest = chest
	GameManager.pause_game()
	_build_ui()
	visible = true


func _build_ui() -> void:
	# 清除旧内容
	for child in get_children():
		child.queue_free()

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-480, -200)
	panel.size = Vector2(960, 400)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "✦ 换装宝箱 ✦"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "选择新服装（衣着耐久重置至满），或保持当前（恢复25%耐久）"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	vbox.add_child(subtitle)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(hbox)

	var char_id := GameManager.current_character_id
	var outfits: Array = OUTFITS_BY_CHARACTER.get(char_id, OUTFITS_BY_CHARACTER["rin"])

	for outfit in outfits:
		hbox.add_child(_create_outfit_card(outfit))

	# "不换"选项
	var keep_btn := Button.new()
	keep_btn.text = "保持当前服装（恢复25%耐久）"
	keep_btn.add_theme_font_size_override("font_size", 18)
	keep_btn.pressed.connect(func() -> void: _on_keep_outfit())
	vbox.add_child(keep_btn)


func _create_outfit_card(outfit: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(200, 200)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)

	# 占位服装图（纯色色块，后续替换真实美术）
	var tex_rect := ColorRect.new()
	tex_rect.color = outfit.get("color", Color.GRAY)
	tex_rect.custom_minimum_size = Vector2(100, 100)
	tex_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(tex_rect)

	# 服装名
	var name_lbl := Label.new()
	name_lbl.text = outfit.get("name", "???")
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 18)
	vbox.add_child(name_lbl)

	# 效果描述
	var desc_lbl := Label.new()
	desc_lbl.text = outfit.get("desc", "")
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_lbl)

	# 选择按钮
	var btn := Button.new()
	btn.text = "选择"
	btn.add_theme_font_size_override("font_size", 16)
	var outfit_id: String = outfit.get("id", "")
	btn.pressed.connect(func() -> void: _on_outfit_selected(outfit_id))
	vbox.add_child(btn)

	return card


func _on_outfit_selected(outfit_id: String) -> void:
	outfit_selected.emit(outfit_id, false)
	_close()


func _on_keep_outfit() -> void:
	outfit_selected.emit("", true)
	_close()


func _close() -> void:
	visible = false
	if _pending_chest and is_instance_valid(_pending_chest):
		_pending_chest.queue_free()
	_pending_chest = null
	GameManager.resume_game()
