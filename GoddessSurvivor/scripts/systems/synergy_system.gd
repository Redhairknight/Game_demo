## 协同觉醒系统 — 监测武器等级+衣着阶段，条件满足时触发一次性觉醒
## 挂在 Player 节点下，依赖 ClothingSystem 和 WeaponPivot
class_name SynergySystem
extends Node

var already_awakened: bool = false
var _exp_magnet_timer: float = 0.0
const EXP_MAGNET_INTERVAL: float = 0.5

# 节点引用（_ready 时获取）
var _player: PlayerController = null
var _clothing: ClothingSystem = null
var _flash_overlay: ColorRect = null


func _ready() -> void:
	_player = get_parent() as PlayerController
	if not _player:
		push_error("[SynergySystem] 必须作为 PlayerController 的子节点")
		return
	_clothing = _player.get_node_or_null("ClothingSystem") as ClothingSystem


func _process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	# 条件检查（一次性）
	if not already_awakened:
		_check_awakening()

	# 觉醒后：经验磁场循环
	if already_awakened:
		_exp_magnet_timer += delta
		if _exp_magnet_timer >= EXP_MAGNET_INTERVAL:
			_exp_magnet_timer = 0.0
			_attract_all_gems()


func _check_awakening() -> void:
	if GameManager.current_character_id != "rin":
		return
	if not _clothing:
		return
	if _clothing.get_current_stage() < 3:
		return

	var pivot := _player.get_node_or_null("WeaponPivot")
	if not pivot:
		return
	var bullet_ring := pivot.get_node_or_null("BulletRing") as BulletRing
	if not bullet_ring:
		return
	if bullet_ring.current_level < 5:
		return

	# 所有条件满足，触发觉醒
	_trigger_awakening(bullet_ring)


func _trigger_awakening(bullet_ring: BulletRing) -> void:
	already_awakened = true
	bullet_ring.awaken()
	EventBus.synergy_awakened.emit("rin", "bullet_ring")
	_play_flash_effect()


func _play_flash_effect() -> void:
	# 全屏白色闪烁覆盖层
	var canvas := CanvasLayer.new()
	canvas.layer = 50
	get_tree().current_scene.add_child(canvas)

	_flash_overlay = ColorRect.new()
	_flash_overlay.color = Color(1, 1, 1, 0.0)
	_flash_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(_flash_overlay)

	var tween := _flash_overlay.create_tween()
	tween.tween_property(_flash_overlay, "color:a", 0.8, 0.15)
	tween.tween_property(_flash_overlay, "color:a", 0.0, 0.35)
	tween.tween_callback(canvas.queue_free)


func _attract_all_gems() -> void:
	if not is_instance_valid(_player):
		return
	var player_pos := _player.global_position
	var gems := get_tree().get_nodes_in_group("exp_gems")
	for gem in gems:
		if is_instance_valid(gem) and gem.has_method("attract_to"):
			gem.attract_to(player_pos, 200.0)
