## enemy_data.gd
## 敌人数据资源类 - 定义各类敌人的基础属性与行为参数
## Nikki Survivors - 类Vampire Survivors像素风游戏
class_name EnemyData
extends Resource

# ============================================================
# 敌人基础信息
# ============================================================

## 敌人内部ID
@export var id: String = ""

## 敌人显示名称（中文）
@export var display_name: String = ""

## 敌人描述
@export var description: String = ""

## 敌人类型标签：fodder(杂兵) / fast(快速) / elite(精英)
@export var enemy_class: String = "fodder"

# ============================================================
# 战斗数值
# ============================================================

## 基础生命值
@export var base_hp: int = 20

## 移动速度（像素/秒）
@export var move_speed: float = 80.0

## 接触伤害（碰到玩家时造成的伤害）
@export var contact_damage: int = 5

## 攻击冷却（秒，每次碰撞伤害间隔）
@export var attack_cooldown: float = 1.0

## 击退抗性（0.0=完全击退，1.0=完全免疫）
@export var knockback_resistance: float = 0.0

# ============================================================
# 掉落与生成
# ============================================================

## 击杀经验值
@export var exp_value: int = 1

## 出现的最早时间（游戏开始后的秒数）
@export var spawn_after_seconds: float = 0.0

## 生成权重（数值越高越容易被选中生成）
@export var spawn_weight: float = 1.0

## 是否为BOSS级敌人
@export var is_boss: bool = false

# ============================================================
# 随时间缩放（难度递增）
# ============================================================

## 每分钟HP增长比例（例如0.1 = 每分钟+10%）
@export var hp_scale_per_minute: float = 0.08

## 每分钟伤害增长比例
@export var damage_scale_per_minute: float = 0.05

## 每分钟速度增长比例（上限不超过 max_speed_multiplier）
@export var speed_scale_per_minute: float = 0.02

## 速度增长上限倍率
@export var max_speed_multiplier: float = 1.5


# ============================================================
# 运行时辅助方法
# ============================================================

## 根据游戏经过时间（分钟）计算当前HP
func get_scaled_hp(elapsed_minutes: float) -> int:
	var multiplier = 1.0 + (hp_scale_per_minute * elapsed_minutes)
	return int(base_hp * multiplier)


## 根据游戏经过时间（分钟）计算当前伤害
func get_scaled_damage(elapsed_minutes: float) -> int:
	var multiplier = 1.0 + (damage_scale_per_minute * elapsed_minutes)
	return int(contact_damage * multiplier)


## 根据游戏经过时间（分钟）计算当前速度
func get_scaled_speed(elapsed_minutes: float) -> float:
	var multiplier = 1.0 + (speed_scale_per_minute * elapsed_minutes)
	multiplier = minf(multiplier, max_speed_multiplier)
	return move_speed * multiplier


# ============================================================
# 预设敌人数据工厂方法
# ============================================================

## 获取所有预设敌人数据
static func get_all_enemies() -> Array[EnemyData]:
	return [
		_create_slime(),
		_create_bat(),
		_create_knight(),
	]


## 根据ID获取敌人数据
static func get_enemy_by_id(enemy_id: String) -> EnemyData:
	for enemy in get_all_enemies():
		if enemy.id == enemy_id:
			return enemy
	return null


## 获取指定时间点可以生成的敌人列表
static func get_spawnable_enemies(elapsed_seconds: float) -> Array[EnemyData]:
	var result: Array[EnemyData] = []
	for enemy in get_all_enemies():
		if elapsed_seconds >= enemy.spawn_after_seconds:
			result.append(enemy)
	return result


## ----------------------------------------------------------------
## 史莱姆(Slime) - 基础杂兵，缓慢但数量多
## 游戏初期主要敌人，用于让玩家熟悉操作
## ----------------------------------------------------------------
static func _create_slime() -> EnemyData:
	var data = EnemyData.new()
	data.id = "slime"
	data.display_name = "史莱姆"
	data.description = "黏糊糊的基础怪物，行动迟缓但成群出没。"
	data.enemy_class = "fodder"
	data.base_hp = 20
	data.move_speed = 60.0
	data.contact_damage = 5
	data.attack_cooldown = 1.0
	data.knockback_resistance = 0.0
	data.exp_value = 1
	data.spawn_after_seconds = 0.0
	data.spawn_weight = 10.0
	data.is_boss = false
	data.hp_scale_per_minute = 0.08
	data.damage_scale_per_minute = 0.04
	data.speed_scale_per_minute = 0.02
	data.max_speed_multiplier = 1.4
	return data


## ----------------------------------------------------------------
## 蝙蝠(Bat) - 快速单位，血量低但难以命中
## 中期开始出现，考验玩家的走位能力
## ----------------------------------------------------------------
static func _create_bat() -> EnemyData:
	var data = EnemyData.new()
	data.id = "bat"
	data.display_name = "蝙蝠"
	data.description = "快速飞行的夜行生物，来去如风难以捕捉。"
	data.enemy_class = "fast"
	data.base_hp = 12
	data.move_speed = 140.0
	data.contact_damage = 8
	data.attack_cooldown = 0.8
	data.knockback_resistance = 0.2
	data.exp_value = 2
	data.spawn_after_seconds = 60.0  # 1分钟后开始出现
	data.spawn_weight = 6.0
	data.is_boss = false
	data.hp_scale_per_minute = 0.06
	data.damage_scale_per_minute = 0.05
	data.speed_scale_per_minute = 0.015
	data.max_speed_multiplier = 1.3
	return data


## ----------------------------------------------------------------
## 骑士(Knight) - 精英单位，高血量高伤害
## 后期威胁，需要集中火力击杀
## ----------------------------------------------------------------
static func _create_knight() -> EnemyData:
	var data = EnemyData.new()
	data.id = "knight"
	data.display_name = "骑士"
	data.description = "全副武装的重甲战士，拥有惊人的耐久力和攻击力。"
	data.enemy_class = "elite"
	data.base_hp = 80
	data.move_speed = 45.0
	data.contact_damage = 20
	data.attack_cooldown = 1.5
	data.knockback_resistance = 0.7
	data.exp_value = 8
	data.spawn_after_seconds = 180.0  # 3分钟后开始出现
	data.spawn_weight = 2.0
	data.is_boss = false
	data.hp_scale_per_minute = 0.12
	data.damage_scale_per_minute = 0.06
	data.speed_scale_per_minute = 0.01
	data.max_speed_multiplier = 1.2
	return data
