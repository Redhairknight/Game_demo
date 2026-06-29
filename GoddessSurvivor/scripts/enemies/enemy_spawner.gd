## 敌人生成器 - 控制敌人的生成节奏和难度曲线
class_name EnemySpawner
extends Node2D

# ===== 导出属性 =====
@export var spawn_distance: float = 600.0
@export var max_enemies: int = 200
@export var base_spawn_interval: float = 1.0
@export var enemy_hp_scale: float = 0.1
@export var elite_chance_base: float = 0.05
@export var wave_interval: float = 30.0
@export var wave_enemy_count: int = 15

# ===== 状态变量 =====
var enemy_scene: PackedScene = null
var spawn_timer: float = 0.0
var current_enemy_count: int = 0
var wave_number: int = 0
var wave_timer: float = 0.0
var player_ref: CharacterBody2D = null
var has_spawned_initial: bool = false
var has_spawned_boss: bool = false
var is_boss_alive: bool = false


func _ready() -> void:
	enemy_scene = load("res://scenes/enemies/enemy_base.tscn") as PackedScene
	EventBus.enemy_killed.connect(func(_d: Dictionary) -> void: current_enemy_count -= 1)
	EventBus.boss_defeated.connect(func() -> void: is_boss_alive = false)


func _process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	if not is_instance_valid(player_ref):
		player_ref = GameManager.player_node
		if not player_ref:
			return

	# 首次生成
	if not has_spawned_initial:
		has_spawned_initial = true
		for i in range(8):
			_spawn_one()
		return

	# Boss 触发检查（11 分钟 = 660 秒）
	if not has_spawned_boss and GameManager.elapsed_time >= 660.0:
		has_spawned_boss = true
		is_boss_alive = true
		_spawn_boss()

	# Boss 存活期间暂停普通生成
	if is_boss_alive:
		return

	# 定时生成
	spawn_timer += delta
	if spawn_timer >= base_spawn_interval and current_enemy_count < max_enemies:
		spawn_timer = 0.0
		_spawn_one()

	# 波次
	wave_timer += delta
	if wave_timer >= wave_interval:
		wave_timer = 0.0
		wave_number += 1
		for i in range(wave_enemy_count + wave_number * 5):
			if current_enemy_count < max_enemies:
				_spawn_one()


func _spawn_one() -> void:
	if not enemy_scene or not is_instance_valid(player_ref):
		return

	var angle := randf() * TAU
	var pos := player_ref.global_position + Vector2(cos(angle), sin(angle)) * spawn_distance

	var enemy := enemy_scene.instantiate()
	enemy.global_position = pos

	if enemy is EnemyBase:
		var eb := enemy as EnemyBase
		var minutes := GameManager.elapsed_time / 60.0
		eb.max_hp *= (1.0 + minutes * enemy_hp_scale)
		eb.current_hp = eb.max_hp
		if randf() < (elite_chance_base + minutes * 0.02):
			eb.max_hp *= 3.0
			eb.current_hp = eb.max_hp
			eb.move_speed *= 1.3
			eb.scale = Vector2(1.5, 1.5)
		eb.died.connect(func(_e: EnemyBase) -> void: current_enemy_count -= 1)

	get_tree().current_scene.add_child(enemy)
	current_enemy_count += 1


func _spawn_boss() -> void:
	if not is_instance_valid(player_ref):
		return
	var boss := BossEnemy.new()
	boss.global_position = player_ref.global_position + Vector2(400.0, 0.0)
	get_tree().current_scene.add_child(boss)
	EventBus.boss_spawned.emit(boss)
	print("[EnemySpawner] Boss 已生成! 位置: %s" % boss.global_position)
