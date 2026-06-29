## 亲密度管理器 - 全局单例
## 负责读写 user://affinity.json，提供 get/add/unlock 接口
class_name AffinityManagerClass
extends Node

const SAVE_PATH := "user://affinity.json"

# 解锁阈值表（所有角色共用）
const UNLOCK_TABLE: Array[Dictionary] = [
	{"threshold": 10,  "id": "voice_1",     "desc": "「语音包1」战斗台词已解锁（待配音）"},
	{"threshold": 25,  "id": "outfit_1",    "desc": "「专属服装1」已解锁（待美术完成）"},
	{"threshold": 50,  "id": "animation_1", "desc": "「互动动画」已解锁（待动画完成）"},
	{"threshold": 75,  "id": "voice_2",     "desc": "「语音包2」暴露台词已解锁（待配音）"},
	{"threshold": 100, "id": "hidden_char", "desc": "「焰·Homura」隐藏角色已解锁（待实现）"},
	{"threshold": 150, "id": "final_form",  "desc": "「约定形态」最终造型已解锁（待美术完成）"},
]

var _data: Dictionary = {}   # { "rin": 42, "lin": 0, "rei": 7 }


func _ready() -> void:
	_load()


# ===== 公共接口 =====

## 获取角色当前亲密度
func get_affinity(char_id: String) -> int:
	return _data.get(char_id, 0)


## 增加亲密度并自动持久化
func add_affinity(char_id: String, amount: int) -> void:
	_data[char_id] = _data.get(char_id, 0) + amount
	_save()


## 获取角色已解锁的全部内容
func get_unlocks(char_id: String) -> Array[Dictionary]:
	var total := get_affinity(char_id)
	var result: Array[Dictionary] = []
	for entry in UNLOCK_TABLE:
		if total >= entry["threshold"]:
			result.append(entry)
	return result


## 获取本次新解锁内容（old_val < threshold <= new_val）
func get_pending_unlocks(char_id: String, old_val: int, new_val: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in UNLOCK_TABLE:
		var t: int = entry["threshold"]
		if old_val < t and new_val >= t:
			result.append(entry)
	return result


## 获取下一个解锁阈值（用于 UI 进度显示）
func get_next_unlock_threshold(char_id: String) -> int:
	var total := get_affinity(char_id)
	for entry in UNLOCK_TABLE:
		if total < entry["threshold"]:
			return entry["threshold"]
	return -1  # 已全解锁


# ===== 内部存档 =====

func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_data))
		file.close()


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_data = {}
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		_data = {}
		return
	var text := file.get_as_text()
	file.close()
	var parsed := JSON.parse_string(text)
	if parsed is Dictionary:
		_data = parsed
	else:
		_data = {}
