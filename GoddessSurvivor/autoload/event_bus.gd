## 事件总线 - 全局信号中心
## 使用信号实现各系统间的松耦合通信
class_name EventBusClass
extends Node

# ===== 战斗相关信号 =====

## 敌人被击杀时发出 {enemy_type: String, position: Vector2, exp_value: int}
signal enemy_killed(enemy_data: Dictionary)

## 经验值被收集 (amount: int)
signal exp_collected(amount: int)

## 玩家升级 (new_level: int)
signal level_up(new_level: int)

# ===== 衣着系统信号 =====

## 衣着阶段变化 (new_stage: int, old_stage: int)
signal clothing_stage_changed(new_stage: int, old_stage: int)

## 衣着耐久度变化 (current: float, max_value: float)
signal clothing_durability_changed(current: float, max_value: float)

# ===== 武器系统信号 =====

## 武器升级 (weapon_id: String, new_level: int)
signal weapon_upgraded(weapon_id: String, new_level: int)

# ===== 挑逗系统信号 =====

## 挑逗释放 (charge_level: int, position: Vector2)
signal taunt_released(charge_level: int, position: Vector2)

## 挑逗开始蓄力
signal taunt_charge_started()

## 挑逗被打断
signal taunt_interrupted()

# ===== 游戏流程信号 =====

## 游戏结束 (kill_count: int, survival_time: float)
signal game_over(kill_count: int, survival_time: float)

## 玩家受伤 (damage: float, source: Node)
signal player_damaged(damage: float, source: Node)

## 玩家死亡
signal player_died()

## 玩家治疗 (amount: float)
signal player_healed(amount: float)

# ===== 拾取相关信号 =====

## 物品拾取 (item_type: String, value: Variant)
signal item_picked_up(item_type: String, value: Variant)

# ===== 波次系统信号 =====

## 新波次开始 (wave_number: int)
signal wave_started(wave_number: int)

## Boss出现
signal boss_spawned(boss_node: Node)

## Boss被击败
signal boss_defeated()

## 协同觉醒触发 (character_id: String, weapon_id: String)
signal synergy_awakened(character_id: String, weapon_id: String)

## 亲密度更新 (char_id, delta, new_total, new_unlocks)
signal affinity_updated(char_id: String, delta: int, new_total: int, new_unlocks: Array)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[EventBus] 事件总线已就绪")
