## weapon_data.gd
## 武器数据资源类 - 定义武器各等级的属性与特效
## Nikki Survivors - 类Vampire Survivors像素风游戏
class_name WeaponData
extends Resource

# ============================================================
# 武器基础信息
# ============================================================

## 武器内部ID
@export var id: String = ""

## 武器显示名称（中文）
@export var display_name: String = ""

## 武器描述
@export var description: String = ""

## 武器类型标签：ring / spin / chain
@export var weapon_category: String = ""

## 当前等级（1~5）
@export var level: int = 1

## 最大等级
const MAX_LEVEL: int = 5

# ============================================================
# 各等级数值（数组索引 0~4 对应 Lv1~Lv5）
# ============================================================

## 每级基础伤害
@export var damage_per_level: Array[float] = []

## 每级攻击冷却时间（秒）
@export var cooldown_per_level: Array[float] = []

## 每级攻击范围（像素）
@export var range_per_level: Array[float] = []

## 每级投射物/打击次数
@export var projectile_count_per_level: Array[int] = []

## 每级特殊效果描述
@export var special_effect_per_level: Array[String] = []


# ============================================================
# 便捷属性访问（基于当前等级）
# ============================================================

## 获取当前等级的伤害
func get_damage() -> float:
	return damage_per_level[level - 1] if level <= damage_per_level.size() else 0.0


## 获取当前等级的冷却时间
func get_cooldown() -> float:
	return cooldown_per_level[level - 1] if level <= cooldown_per_level.size() else 1.0


## 获取当前等级的范围
func get_range() -> float:
	return range_per_level[level - 1] if level <= range_per_level.size() else 0.0


## 获取当前等级的投射物数量
func get_projectile_count() -> int:
	return projectile_count_per_level[level - 1] if level <= projectile_count_per_level.size() else 1


## 获取当前等级的特殊效果描述
func get_special_effect() -> String:
	return special_effect_per_level[level - 1] if level <= special_effect_per_level.size() else ""


## 尝试升级，返回是否成功
func try_level_up() -> bool:
	if level < MAX_LEVEL:
		level += 1
		return true
	return false


# ============================================================
# 预设武器数据工厂方法
# ============================================================

## 获取所有预设武器数据
static func get_all_weapons() -> Array[WeaponData]:
	return [
		_create_bullet_ring(),
		_create_spin_blade(),
		_create_chain_lightning(),
	]


## 根据ID获取武器数据
static func get_weapon_by_id(weapon_id: String) -> WeaponData:
	for weapon in get_all_weapons():
		if weapon.id == weapon_id:
			return weapon
	return null


## ----------------------------------------------------------------
## 弹幕环(BulletRing) - 围绕角色旋转的多发弹幕
## 特点：全方位覆盖，适合清理周围杂兵
## ----------------------------------------------------------------
static func _create_bullet_ring() -> WeaponData:
	var data = WeaponData.new()
	data.id = "bullet_ring"
	data.display_name = "弹幕环"
	data.description = "围绕角色旋转的环形弹幕，均匀覆盖四周。"
	data.weapon_category = "ring"
	data.level = 1
	# Lv1~Lv5 伤害递增
	data.damage_per_level = [8.0, 12.0, 16.0, 22.0, 30.0]
	# 冷却逐级缩短
	data.cooldown_per_level = [1.8, 1.6, 1.4, 1.2, 0.9]
	# 弹幕环半径（像素）
	data.range_per_level = [80.0, 90.0, 100.0, 115.0, 135.0]
	# 弹幕数量
	data.projectile_count_per_level = [4, 5, 6, 8, 12]
	# 特殊效果
	data.special_effect_per_level = [
		"基础弹幕环绕",
		"弹幕穿透+1",
		"旋转速度提升30%",
		"弹幕附带减速效果",
		"双层弹幕环（内外环反向旋转）",
	]
	return data


## ----------------------------------------------------------------
## 旋转刀刃(SpinBlade) - 近距离大伤害旋转攻击
## 特点：高伤害、低范围，需要贴近敌人
## ----------------------------------------------------------------
static func _create_spin_blade() -> WeaponData:
	var data = WeaponData.new()
	data.id = "spin_blade"
	data.display_name = "旋转刀刃"
	data.description = "在角色周围旋转的利刃，近距离持续切割敌人。"
	data.weapon_category = "spin"
	data.level = 1
	# 近战高伤害
	data.damage_per_level = [15.0, 22.0, 30.0, 40.0, 55.0]
	# 冷却较短（持续旋转型武器）
	data.cooldown_per_level = [1.2, 1.1, 1.0, 0.85, 0.7]
	# 旋转半径（近距离）
	data.range_per_level = [50.0, 55.0, 60.0, 70.0, 85.0]
	# 刀刃数量
	data.projectile_count_per_level = [2, 2, 3, 3, 4]
	# 特殊效果
	data.special_effect_per_level = [
		"基础旋转斩击",
		"击中时回复1HP",
		"刀刃增大20%",
		"暴击率+15%（暴击伤害1.5x）",
		"释放剑气波（每3次旋转发射远程斩击）",
	]
	return data


## ----------------------------------------------------------------
## 连锁闪电(ChainLightning) - 在敌群间弹射的雷电
## 特点：优秀的群体伤害，自动锁定目标
## ----------------------------------------------------------------
static func _create_chain_lightning() -> WeaponData:
	var data = WeaponData.new()
	data.id = "chain_lightning"
	data.display_name = "连锁闪电"
	data.description = "释放雷电弹射至多个敌人，在敌群中造成连锁伤害。"
	data.weapon_category = "chain"
	data.level = 1
	# 法术伤害（单次偏低但弹射多次）
	data.damage_per_level = [10.0, 14.0, 18.0, 24.0, 32.0]
	# 冷却时间
	data.cooldown_per_level = [2.0, 1.8, 1.5, 1.3, 1.0]
	# 初始锁定范围（像素）
	data.range_per_level = [120.0, 140.0, 160.0, 180.0, 220.0]
	# 弹射次数（chain count）
	data.projectile_count_per_level = [3, 4, 5, 7, 10]
	# 特殊效果
	data.special_effect_per_level = [
		"基础连锁弹射",
		"弹射衰减降低（每次弹射仅-5%伤害）",
		"麻痹效果（被击中敌人减速40%持续1秒）",
		"分叉闪电（50%概率产生分支）",
		"雷暴领域（每5秒对范围内所有敌人释放全屏闪电）",
	]
	return data
