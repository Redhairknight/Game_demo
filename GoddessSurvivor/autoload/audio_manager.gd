## 音频管理器 - 全局 Autoload
## 管理 SFX 池、UI 音效、BGM；所有音频文件留占位路径，放入对应 .ogg 自动生效
class_name AudioManagerClass
extends Node

# ===== 音频资源路径 =====
const BGM_MAIN_PATH  := "res://audio/bgm/bgm_main.ogg"
const BGM_BOSS_PATH  := "res://audio/bgm/bgm_boss.ogg"
const SFX_PATHS := {
	"enemy_die":    "res://audio/sfx/sfx_enemy_die.ogg",
	"pickup":       "res://audio/sfx/sfx_pickup.ogg",
	"levelup":      "res://audio/sfx/sfx_levelup.ogg",
	"cloth_tear":   "res://audio/sfx/sfx_cloth_tear.ogg",
	"player_hurt":  "res://audio/sfx/sfx_player_hurt.ogg",
	"player_die":   "res://audio/sfx/sfx_player_die.ogg",
	"taunt_small":  "res://audio/sfx/sfx_taunt_small.ogg",
	"taunt_full":   "res://audio/sfx/sfx_taunt_full.ogg",
	"boss_die":     "res://audio/sfx/sfx_boss_die.ogg",
	"synergy":      "res://audio/sfx/sfx_synergy.ogg",
}

const SFX_POOL_SIZE := 8
const BGM_FADE_TIME := 0.5

# ===== 节点 =====
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_pool_index: int = 0
var _ui_player: AudioStreamPlayer = null
var _bgm_player: AudioStreamPlayer = null

# ===== 预加载的音频资源 =====
var _sfx: Dictionary = {}    # key -> AudioStream or null
var _bgm_main: AudioStream = null
var _bgm_boss: AudioStream = null


func _ready() -> void:
	_build_players()
	_load_streams()
	_connect_signals()
	# 游戏启动时播放主 BGM
	call_deferred("play_bgm", _bgm_main)


# ===== 节点构建 =====

func _build_players() -> void:
	# SFX 池
	for i in range(SFX_POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_pool.append(p)

	# UI 专用
	_ui_player = AudioStreamPlayer.new()
	_ui_player.bus = "UI"
	add_child(_ui_player)

	# BGM
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = "BGM"
	_bgm_player.volume_db = 0.0
	add_child(_bgm_player)


# ===== 资源加载 =====

func _load_streams() -> void:
	_bgm_main = _try_load(BGM_MAIN_PATH)
	_bgm_boss = _try_load(BGM_BOSS_PATH)
	for key in SFX_PATHS:
		_sfx[key] = _try_load(SFX_PATHS[key])


func _try_load(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		return load(path) as AudioStream
	return null


# ===== 播放接口 =====

func play_sfx(key: String) -> void:
	var stream: AudioStream = _sfx.get(key, null)
	if not stream:
		return
	# 轮转池：找空闲 player，池满时复用最旧的
	var player := _sfx_pool[_sfx_pool_index]
	_sfx_pool_index = (_sfx_pool_index + 1) % SFX_POOL_SIZE
	player.stream = stream
	player.play()


func play_ui(key: String) -> void:
	var stream: AudioStream = _sfx.get(key, null)
	if not stream:
		return
	_ui_player.stream = stream
	_ui_player.play()


func play_bgm(stream: AudioStream) -> void:
	if not stream:
		return
	if _bgm_player.stream == stream and _bgm_player.playing:
		return
	# 淡出当前，淡入新曲
	var tween := create_tween()
	if _bgm_player.playing:
		tween.tween_property(_bgm_player, "volume_db", -80.0, BGM_FADE_TIME)
		tween.tween_callback(func() -> void:
			_bgm_player.stop()
			_bgm_player.stream = stream
			_bgm_player.volume_db = -80.0
			_bgm_player.play()
			var tween2 := create_tween()
			tween2.tween_property(_bgm_player, "volume_db", 0.0, BGM_FADE_TIME)
		)
	else:
		_bgm_player.stream = stream
		_bgm_player.volume_db = -80.0
		_bgm_player.play()
		tween.tween_property(_bgm_player, "volume_db", 0.0, BGM_FADE_TIME)


func stop_bgm() -> void:
	if not _bgm_player.playing:
		return
	var tween := create_tween()
	tween.tween_property(_bgm_player, "volume_db", -80.0, BGM_FADE_TIME)
	tween.tween_callback(_bgm_player.stop)


# ===== EventBus 信号连接 =====

func _connect_signals() -> void:
	EventBus.enemy_killed.connect(func(_d: Dictionary) -> void: play_sfx("enemy_die"))
	EventBus.exp_collected.connect(func(_a: int) -> void: play_sfx("pickup"))
	EventBus.level_up.connect(func(_l: int) -> void: play_ui("levelup"))
	EventBus.clothing_stage_changed.connect(_on_clothing_stage_changed)
	EventBus.player_damaged.connect(func(_d: float, _s: Node) -> void: play_sfx("player_hurt"))
	EventBus.player_died.connect(func() -> void:
		play_sfx("player_die")
		stop_bgm()
	)
	EventBus.taunt_released.connect(_on_taunt_released)
	EventBus.boss_spawned.connect(func(_n: Node) -> void: play_bgm(_bgm_boss))
	EventBus.boss_defeated.connect(func() -> void:
		play_sfx("boss_die")
		play_bgm(_bgm_main)
	)
	EventBus.synergy_awakened.connect(func(_c: String, _w: String) -> void: play_sfx("synergy"))
	EventBus.game_over.connect(func(_k: int, _t: float) -> void: stop_bgm())


func _on_clothing_stage_changed(new_stage: int, _old_stage: int) -> void:
	if new_stage > 0:
		play_sfx("cloth_tear")


func _on_taunt_released(charge_level: int, _pos: Vector2) -> void:
	if charge_level == 3:
		play_sfx("taunt_full")
	elif charge_level > 0:
		play_sfx("taunt_small")
