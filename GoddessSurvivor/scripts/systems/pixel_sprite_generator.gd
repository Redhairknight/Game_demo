## 像素精灵生成器 - 运行时生成占位像素图
## 用于开发阶段，无需实际美术素材即可测试游戏
class_name PixelSpriteGenerator
extends Node

# ===== 颜色配置 =====
const COLORS := {
	# 角色
	"rin": Color(1.0, 0.6, 0.7),       # 粉色
	"lin": Color(0.4, 0.6, 1.0),       # 蓝色
	"rei": Color(0.7, 0.5, 1.0),       # 紫色
	# 敌人
	"slime": Color(0.3, 0.9, 0.3),     # 绿色
	"bat": Color(0.5, 0.3, 0.5),       # 暗紫
	"knight": Color(0.6, 0.6, 0.7),    # 银灰
	"elite": Color(1.0, 0.2, 0.2),     # 红色
	# 特效
	"bullet": Color(1.0, 0.9, 0.3),    # 金黄
	"exp_gem": Color(0.3, 1.0, 0.6),   # 翠绿
	"hp_orb": Color(1.0, 0.3, 0.3),    # 红色
}


## 生成角色纹理 (48x48)
static func create_character_texture(character_id: String) -> ImageTexture:
	var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	var color: Color = COLORS.get(character_id, Color.WHITE)

	# 身体（圆形）
	_draw_circle(img, Vector2i(24, 26), 14, color)
	# 头（圆形）
	_draw_circle(img, Vector2i(24, 12), 10, color.lightened(0.2))
	# 眼睛
	_draw_pixel(img, Vector2i(20, 11), Color.WHITE)
	_draw_pixel(img, Vector2i(28, 11), Color.WHITE)
	_draw_pixel(img, Vector2i(20, 12), Color.BLACK)
	_draw_pixel(img, Vector2i(28, 12), Color.BLACK)
	# 头发高光
	_draw_circle(img, Vector2i(24, 7), 4, color.darkened(0.3))
	# 腿
	_draw_rect(img, Vector2i(18, 38), Vector2i(5, 8), color.darkened(0.2))
	_draw_rect(img, Vector2i(26, 38), Vector2i(5, 8), color.darkened(0.2))
	# 裙子/衣服轮廓
	_draw_circle(img, Vector2i(24, 32), 10, color.darkened(0.1))

	var texture := ImageTexture.create_from_image(img)
	return texture


## 生成敌人纹理 (32x32)
static func create_enemy_texture(enemy_type: String) -> ImageTexture:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var color: Color = COLORS.get(enemy_type, Color(0.3, 0.9, 0.3))

	match enemy_type:
		"slime":
			# 史莱姆 - 椭圆形
			_draw_ellipse(img, Vector2i(16, 20), 12, 8, color)
			_draw_ellipse(img, Vector2i(16, 16), 10, 10, color.lightened(0.2))
			_draw_pixel(img, Vector2i(12, 14), Color.WHITE)
			_draw_pixel(img, Vector2i(20, 14), Color.WHITE)
		"bat":
			# 蝙蝠 - 小身体+翅膀
			_draw_circle(img, Vector2i(16, 16), 6, color)
			_draw_triangle(img, Vector2i(4, 12), Vector2i(12, 16), Vector2i(8, 8), color.lightened(0.2))
			_draw_triangle(img, Vector2i(28, 12), Vector2i(20, 16), Vector2i(24, 8), color.lightened(0.2))
			_draw_pixel(img, Vector2i(14, 14), Color.RED)
			_draw_pixel(img, Vector2i(18, 14), Color.RED)
		"knight":
			# 骑士 - 方形身体+头盔
			_draw_rect(img, Vector2i(10, 12), Vector2i(12, 16), color)
			_draw_rect(img, Vector2i(12, 6), Vector2i(8, 8), color.lightened(0.1))
			# 头盔缝
			_draw_rect(img, Vector2i(12, 9), Vector2i(8, 2), Color(0.2, 0.2, 0.2))
			# 剑
			_draw_rect(img, Vector2i(24, 10), Vector2i(2, 14), Color(0.8, 0.8, 0.9))
		_:
			_draw_circle(img, Vector2i(16, 16), 10, color)

	var texture := ImageTexture.create_from_image(img)
	return texture


## 生成弹幕纹理 (8x8)
static func create_bullet_texture(color: Color = Color(1.0, 0.9, 0.3)) -> ImageTexture:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	_draw_circle(img, Vector2i(4, 4), 3, color)
	_draw_pixel(img, Vector2i(4, 4), Color.WHITE)  # 中心高光

	var texture := ImageTexture.create_from_image(img)
	return texture


## 生成心形弹幕纹理 (12x12) — 觉醒弹幕专用
static func create_heart_bullet_texture() -> ImageTexture:
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	var color := Color(1.0, 0.4, 0.6)  # 粉红色
	var highlight := Color(1.0, 0.8, 0.9)

	# 心形：两个上圆 + 下三角
	_draw_circle(img, Vector2i(4, 4), 2, color)
	_draw_circle(img, Vector2i(8, 4), 2, color)
	# 下方三角填充
	for y in range(4, 10):
		var half_w := 5 - (y - 4)
		if half_w <= 0:
			break
		for x in range(6 - half_w, 6 + half_w):
			_draw_pixel(img, Vector2i(x, y), color)
	# 高光
	_draw_pixel(img, Vector2i(4, 3), highlight)
	_draw_pixel(img, Vector2i(8, 3), highlight)

	return ImageTexture.create_from_image(img)


## 生成经验宝石纹理 (12x12)
static func create_exp_gem_texture() -> ImageTexture:
	var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	var color := Color(0.3, 1.0, 0.6)
	# 菱形
	_draw_diamond(img, Vector2i(6, 6), 5, color)
	_draw_pixel(img, Vector2i(6, 5), Color.WHITE)  # 高光

	var texture := ImageTexture.create_from_image(img)
	return texture


# ===== 像素绘制工具 =====

static func _draw_pixel(img: Image, pos: Vector2i, color: Color) -> void:
	if pos.x >= 0 and pos.x < img.get_width() and pos.y >= 0 and pos.y < img.get_height():
		img.set_pixelv(pos, color)


static func _draw_circle(img: Image, center: Vector2i, radius: int, color: Color) -> void:
	for x in range(center.x - radius, center.x + radius + 1):
		for y in range(center.y - radius, center.y + radius + 1):
			if Vector2i(x, y).distance_to(center) <= radius:
				_draw_pixel(img, Vector2i(x, y), color)


static func _draw_ellipse(img: Image, center: Vector2i, rx: int, ry: int, color: Color) -> void:
	for x in range(center.x - rx, center.x + rx + 1):
		for y in range(center.y - ry, center.y + ry + 1):
			var dx := float(x - center.x) / float(rx)
			var dy := float(y - center.y) / float(ry)
			if dx * dx + dy * dy <= 1.0:
				_draw_pixel(img, Vector2i(x, y), color)


static func _draw_rect(img: Image, pos: Vector2i, size: Vector2i, color: Color) -> void:
	for x in range(pos.x, pos.x + size.x):
		for y in range(pos.y, pos.y + size.y):
			_draw_pixel(img, Vector2i(x, y), color)


static func _draw_diamond(img: Image, center: Vector2i, radius: int, color: Color) -> void:
	for x in range(center.x - radius, center.x + radius + 1):
		for y in range(center.y - radius, center.y + radius + 1):
			if abs(x - center.x) + abs(y - center.y) <= radius:
				_draw_pixel(img, Vector2i(x, y), color)


static func _draw_triangle(img: Image, p1: Vector2i, p2: Vector2i, p3: Vector2i, color: Color) -> void:
	# 简化三角形填充
	var min_x := mini(p1.x, mini(p2.x, p3.x))
	var max_x := maxi(p1.x, maxi(p2.x, p3.x))
	var min_y := mini(p1.y, mini(p2.y, p3.y))
	var max_y := maxi(p1.y, maxi(p2.y, p3.y))

	for x in range(min_x, max_x + 1):
		for y in range(min_y, max_y + 1):
			if _point_in_triangle(Vector2(x, y), Vector2(p1), Vector2(p2), Vector2(p3)):
				_draw_pixel(img, Vector2i(x, y), color)


static func _point_in_triangle(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var d1 := _sign_tri(p, a, b)
	var d2 := _sign_tri(p, b, c)
	var d3 := _sign_tri(p, c, a)
	var has_neg := (d1 < 0) or (d2 < 0) or (d3 < 0)
	var has_pos := (d1 > 0) or (d2 > 0) or (d3 > 0)
	return !(has_neg and has_pos)


static func _sign_tri(p1: Vector2, p2: Vector2, p3: Vector2) -> float:
	return (p1.x - p3.x) * (p2.y - p3.y) - (p2.x - p3.x) * (p1.y - p3.y)
