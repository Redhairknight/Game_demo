## 换装宝箱 - 玩家靠近触发3选1换装界面
## 美术资产留空，由外部传入或生成占位图
class_name WardrobeChest
extends Area2D

signal chest_opened(chest: WardrobeChest)

var _collected: bool = false


func _ready() -> void:
	add_to_group("wardrobe_chests")
	collision_layer = 4  # Layer 3: Pickups
	collision_mask = 0

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(32, 32)
	shape.shape = rect
	add_child(shape)

	# 占位视觉：黄色宝箱方块
	var sprite := Sprite2D.new()
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(1.0, 0.85, 0.1))
	# 宝箱盖
	for x in range(32):
		for y in range(0, 10):
			img.set_pixel(x, y, Color(0.9, 0.6, 0.0))
	# 锁扣
	for x in range(12, 20):
		for y in range(12, 20):
			img.set_pixel(x, y, Color(0.7, 0.5, 0.0))
	sprite.texture = ImageTexture.create_from_image(img)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)

	# 轻微上下浮动动画
	var tween := create_tween().set_loops()
	tween.tween_property(sprite, "position:y", -4.0, 0.8).set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "position:y", 0.0, 0.8).set_trans(Tween.TRANS_SINE)


## 被玩家拾取区域触发
func collect(_collector: Node) -> void:
	if _collected:
		return
	_collected = true
	chest_opened.emit(self)
	# 收集后隐藏，等 UI 关闭后删除
	visible = false
