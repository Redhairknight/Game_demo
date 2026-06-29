## 经验宝石 - 敌人死亡后掉落，玩家靠近自动收集
class_name ExpGem
extends Area2D

var exp_value: int = 1
var _collected: bool = false


func _ready() -> void:
	add_to_group("exp_gems")
	collision_layer = 4   # Layer 3 = pickups (bit 2)
	collision_mask = 0

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 8.0
	shape.shape = circle
	add_child(shape)

	var sprite := Sprite2D.new()
	sprite.texture = PixelSpriteGenerator.create_exp_gem_texture()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)


func set_exp_value(value: int) -> void:
	exp_value = value


## 被玩家拾取区域触发
func collect(_collector: Node) -> void:
	if _collected:
		return
	_collected = true
	EventBus.exp_collected.emit(exp_value)
	queue_free()
