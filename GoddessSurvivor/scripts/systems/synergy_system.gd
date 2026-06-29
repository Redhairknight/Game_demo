## 协同觉醒系统 — 数据驱动，支持三角色
## 挂在 Player 节点下，依赖 ClothingSystem 和 WeaponPivot
class_name SynergySystem
extends Node

# 三角色觉醒配置
const SYNERGY_CONFIG := {
	"rin": {"weapon_name": "BulletRing",     "effect": "rin_heartbeat"},
	"lin": {"weapon_name": "SpinBlade",      "effect": "lin_reverse_scale"},
	"rei": {"weapon_name": "ChainLightning", "effect": "rei_resonance"},
}

var already_awakened: bool = false
var _exp_magnet_timer: float = 0.0
var _rei_aura_timer: float = 0.0
const EXP_MAGNET_INTERVAL: float = 0.5
const REI_AURA_INTERVAL: float = 1.0

var _player: PlayerController = null
var _clothing: ClothingSystem = null
var _flash_overlay: ColorRect = null
var _active_effect: String = ""


func _ready() -> void:
	_player = get_parent() as PlayerController
	if not _player:
		push_error("[SynergySystem] 必须作为 PlayerController 的子节点")
		return
	_clothing = _player.get_node_or_null("ClothingSystem") as ClothingSystem


func _process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	if not already_awakened:
		_check_awakening()

	if already_awakened:
		_update_effects(delta)


func _update_effects(delta: float) -> void:
	match _active_effect:
		"rin_heartbeat":
			_exp_magnet_timer += delta
			if _exp_magnet_timer >= EXP_MAGNET_INTERVAL:
				_exp_magnet_timer = 0.0
				_attract_all_gems()
		"rei_resonance":
			_rei_aura_timer += delta
			if _rei_aura_timer >= REI_AURA_INTERVAL:
				_rei_aura_timer = 0.0
				_apply_rei_defense_aura()


func _check_awakening() -> void:
	var char_id := GameManager.current_character_id
	if not SYNERGY_CONFIG.has(char_id):
		return
	if not _clothing:
		return
	if _clothing.get_current_stage() < 3:
		return

	var cfg: Dictionary = SYNERGY_CONFIG[char_id]
	var pivot := _player.get_node_or_null("WeaponPivot")
	if not pivot:
		return
	var weapon := pivot.get_node_or_null(cfg["weapon_name"])
	if not weapon:
		return
	if not weapon.has_method("awaken"):
		return
	if not "current_level" in weapon or weapon.current_level < 5:
		return

	_trigger_awakening(weapon, char_id, cfg)


func _trigger_awakening(weapon: Node, char_id: String, cfg: Dictionary) -> void:
	already_awakened = true
	_active_effect = cfg["effect"]
	weapon.awaken()
	EventBus.synergy_awakened.emit(char_id, cfg["weapon_name"].to_lower())
	_play_flash_effect()


func _play_flash_effect() -> void:
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


func _apply_rei_defense_aura() -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.has_method("apply_defense_reduction"):
			enemy.apply_defense_reduction(0.3, 1.5)
