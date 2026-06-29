## Boss 血条 - 顶部居中显示，监听 Boss hp_changed 信号
class_name BossHealthBar
extends CanvasLayer

var _bar: ProgressBar = null
var _label: Label = null


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false

	EventBus.boss_spawned.connect(_on_boss_spawned)
	EventBus.boss_defeated.connect(_on_boss_defeated)


func _build_ui() -> void:
	var container := Control.new()
	container.set_anchors_preset(Control.PRESET_TOP_WIDE)
	container.custom_minimum_size = Vector2(0, 50)
	add_child(container)

	# 背景
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.add_child(bg)

	# Boss 名称标签
	_label = Label.new()
	_label.text = "★ BOSS ★"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))
	_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_label.position = Vector2(0, 4)
	_label.size = Vector2(1920, 20)
	container.add_child(_label)

	# 血条
	_bar = ProgressBar.new()
	_bar.set_anchors_preset(Control.PRESET_HCENTER_WIDE)
	_bar.position = Vector2(-300, 24)
	_bar.size = Vector2(600, 20)
	_bar.max_value = 1.0
	_bar.value = 1.0
	_bar.show_percentage = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.8, 0.1, 0.1)
	_bar.add_theme_stylebox_override("fill", style)
	container.add_child(_bar)


func _on_boss_spawned(boss_node: Node) -> void:
	visible = true
	if boss_node and boss_node.has_signal("hp_changed"):
		boss_node.hp_changed.connect(_on_boss_hp_changed)
	if _bar:
		_bar.value = 1.0


func _on_boss_defeated() -> void:
	visible = false


func _on_boss_hp_changed(current_hp: float, max_hp: float) -> void:
	if _bar and max_hp > 0:
		_bar.value = current_hp / max_hp
