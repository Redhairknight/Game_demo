## 主游戏场景控制器 - 整合所有系统
## 负责初始化游戏、设置像素纹理、管理武器分配等
class_name MainGame
extends Node2D

@onready var player: PlayerController = $Player
@onready var enemy_spawner: EnemySpawner = $EnemySpawner
@onready var camera: Camera2D = $Player/Camera2D


func _ready() -> void:
	# 设置玩家像素图
	_setup_player_visual()

	# 给玩家添加初始武器
	_add_starting_weapon()

	# 设置摄像机
	_setup_camera()

	# 绘制地面背景
	_create_background()

	# 开始游戏！
	if GameManager.current_character_id.is_empty():
		GameManager.start_game("rin")
	else:
		GameManager.start_game(GameManager.current_character_id)

	print("[MainGame] 游戏场景初始化完成")


func _process(_delta: float) -> void:
	# 更新摄像机跟随玩家
	if camera and player:
		camera.global_position = player.global_position

	# 更新最近敌人引用
	_update_nearest_enemy()


## 设置玩家视觉
func _setup_player_visual() -> void:
	if not player:
		return
	var char_id := GameManager.current_character_id
	if char_id.is_empty():
		char_id = "rin"
	var sprite := player.get_node_or_null("Sprite2D") as Sprite2D
	if sprite:
		sprite.texture = PixelSpriteGenerator.create_character_texture(char_id)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## 添加初始武器
func _add_starting_weapon() -> void:
	if not player:
		return

	var weapon := BulletRing.new()
	weapon.name = "BulletRing"
	player.get_node("WeaponPivot").add_child(weapon)


## 设置摄像机
func _setup_camera() -> void:
	if camera:
		camera.zoom = Vector2(1.5, 1.5)  # 1080p下合适的缩放
		camera.position_smoothing_enabled = true
		camera.position_smoothing_speed = 10.0


## 创建背景
func _create_background() -> void:
	# 简单的深色背景 - 使用一个大的ColorRect替代平铺
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.12, 0.12, 0.18)
	bg.size = Vector2(10000, 10000)
	bg.position = Vector2(-5000, -5000)
	bg.z_index = -100
	add_child(bg)
	move_child(bg, 0)


## 更新最近敌人引用
func _update_nearest_enemy() -> void:
	if not player:
		return

	var enemies := get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var nearest_dist := INF

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist: float = player.global_position.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy

	player.update_nearest_enemy(nearest)
