## character_data.gd
## 角色数据资源类 - 定义所有可选角色的基础属性与暴露阶段加成
## Nikki Survivors - 角色配置层
##
## 设计说明：
##   每个角色绑定专属武器和独特的暴露路线（4阶段）。
##   暴露加成由玩家主动选择触发，遵循"暴露=力量"的核心理念。

class_name CharacterData
extends Resource

# ============================================================
# 枚举定义
# ============================================================

## 角色原型（战斗风格）
enum Archetype {
	BALANCED,  ## 均衡型
	MELEE,     ## 近战型
	MAGE,      ## 法师型
}

# ============================================================
# 导出属性 - 基础信息
# ============================================================

## 角色内部ID（英文标识）
@export var id: String = ""

## 角色显示名称（中文）
@export var display_name: String = ""

## 角色显示名称（英文）
@export var display_name_en: String = ""

## 角色原型
@export var archetype: Archetype = Archetype.BALANCED

## 角色描述
@export_multiline var description: String = ""

## 角色外观/服装描述（美术参考）
@export var costume_description: String = ""

# ============================================================
# 导出属性 - 基础数值
# ============================================================

@export_group("Base Stats")
## 基础生命值
@export var base_hp: int = 100
## 基础移动速度（像素/秒）
@export var base_speed: float = 200.0
## 基础伤害倍率（1.0 = 100%）
@export var base_damage: float = 1.0
## 基础护甲（减伤百分比 0.0~1.0）
@export var base_armor: float = 0.0
## 经验拾取范围（像素）
@export var base_pickup_range: float = 50.0

# ============================================================
# 导出属性 - 武器与服装
# ============================================================

@export_group("Weapon & Outfit")
## 专属武器类型ID（对应 WeaponData.id）
@export var weapon_type: String = ""
## 初始服装ID
@export var default_outfit: String = ""

# ============================================================
# 导出属性 - 暴露阶段加成
# ============================================================

## 暴露阶段加成（4个阶段，对应衣着阶段1~4的专属效果）
## 每个元素为 Dictionary：
##   - stage: int           阶段编号
##   - visual: String       视觉描述
##   - description: String  效果描述
##   - attack_speed_bonus: float  攻速加成
##   - damage_bonus: float        伤害加成
##   - speed_bonus: float         移速加成
##   - special: String            特殊效果标识（由逻辑层解释）
@export_group("Exposure System")
@export var exposure_bonuses: Array[Dictionary] = []

# ============================================================
# 静态工厂方法 - 创建预设角色数据
# ============================================================

## 获取所有预设角色数据
static func get_all_characters() -> Array[CharacterData]:
	return [
		_create_rin(),
		_create_lin(),
		_create_rei(),
	]


## 根据ID获取角色数据
static func get_character_by_id(character_id: String) -> CharacterData:
	for character in get_all_characters():
		if character.id == character_id:
			return character
	return null


## ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
## 铃(Rin) - 弹幕环，均衡型，学院制服
## 设计理念：弹幕密度型，暴露让弹幕从"多"变成"智能"
## ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
static func _create_rin() -> CharacterData:
	var data := CharacterData.new()
	data.id = "rin"
	data.display_name = "铃"
	data.display_name_en = "Rin"
	data.archetype = Archetype.BALANCED
	data.description = "学院的元气少女，擅长弹幕攻击。\n暴露越多，弹幕越聪明！"
	data.costume_description = "学院制服 - 清爽的白蓝配色水手服，短裙与长筒袜"

	# 均衡型数值
	data.base_hp = 100
	data.base_speed = 200.0
	data.base_damage = 1.0
	data.base_armor = 0.0
	data.base_pickup_range = 50.0

	data.weapon_type = "bullet_ring"
	data.default_outfit = "school_uniform"

	# 暴露路线：学院制服 → 「甜心轰炸」
	data.exposure_bonuses = [
		{
			"stage": 1,
			"visual": "裙摆破损",
			"description": "弹幕环发射频率+15%",
			"attack_speed_bonus": 0.15,
			"damage_bonus": 0.0,
			"speed_bonus": 0.0,
			"special": "fire_rate_up",
		},
		{
			"stage": 2,
			"visual": "上衣肩部破损",
			"description": "弹幕环获得追踪属性",
			"attack_speed_bonus": 0.15,
			"damage_bonus": 0.0,
			"speed_bonus": 0.0,
			"special": "homing_bullets",
		},
		{
			"stage": 3,
			"visual": "制服大面积碎裂",
			"description": "经验吸取范围×2",
			"attack_speed_bonus": 0.15,
			"damage_bonus": 0.0,
			"speed_bonus": 0.0,
			"special": "exp_range_double",
		},
		{
			"stage": 4,
			"visual": "极限（内衣状态）",
			"description": "弹幕变心形，魅惑敌人互攻",
			"attack_speed_bonus": 0.15,
			"damage_bonus": 0.20,
			"speed_bonus": 0.0,
			"special": "charm_bullets",
		},
	]

	return data


## ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
## 凛(Lin) - 旋转刀刃，近战型，骑士甲胄
## 设计理念：重甲脱甲=解放力量，叙事天然合理
## ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
static func _create_lin() -> CharacterData:
	var data := CharacterData.new()
	data.id = "lin"
	data.display_name = "凛"
	data.display_name_en = "Lin"
	data.archetype = Archetype.MELEE
	data.description = "不苟言笑的骑士少女，善用旋转刀刃近身作战。\n脱下甲胄，解放真正的力量！"
	data.costume_description = "骑士甲胄 - 银白色轻型板甲，红色披风与护腿"

	# 近战型数值：高HP、高伤害、低速度
	data.base_hp = 140
	data.base_speed = 170.0
	data.base_damage = 1.2
	data.base_armor = 0.1
	data.base_pickup_range = 40.0

	data.weapon_type = "spin_blade"
	data.default_outfit = "knight_armor"

	# 暴露路线：骑士甲胄 → 「逆鳞觉醒」
	data.exposure_bonuses = [
		{
			"stage": 1,
			"visual": "肩甲脱落",
			"description": "受伤时反弹30%伤害",
			"attack_speed_bonus": 0.0,
			"damage_bonus": 0.0,
			"speed_bonus": 0.05,
			"special": "damage_reflect_30",
		},
		{
			"stage": 2,
			"visual": "胸甲裂开",
			"description": "每5秒免疫一次攻击",
			"attack_speed_bonus": 0.0,
			"damage_bonus": 0.10,
			"speed_bonus": 0.05,
			"special": "block_every_5s",
		},
		{
			"stage": 3,
			"visual": "甲胄大片剥落",
			"description": "近身敌人持续受到灼烧光环伤害",
			"attack_speed_bonus": 0.0,
			"damage_bonus": 0.10,
			"speed_bonus": 0.10,
			"special": "burn_aura",
		},
		{
			"stage": 4,
			"visual": "极限（锁骨以上覆甲）",
			"description": "无敌冲锋，碰撞即杀",
			"attack_speed_bonus": 0.15,
			"damage_bonus": 0.25,
			"speed_bonus": 0.15,
			"special": "invincible_charge",
		},
	]

	return data


## ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
## 零(Rei) - 连锁闪电，法师型，魔法礼裙
## 设计理念：衣服是封印，越脱魔力越失控
## ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
static func _create_rei() -> CharacterData:
	var data := CharacterData.new()
	data.id = "rei"
	data.display_name = "零"
	data.display_name_en = "Rei"
	data.archetype = Archetype.MAGE
	data.description = "沉默的魔法少女，以连锁闪电消灭群敌。\n礼裙是封印魔力的枷锁……"
	data.costume_description = "魔法礼裙 - 深紫色星纹长裙，发光的魔法纹章与尖帽"

	# 法师型数值：低HP、高伤害、中等速度、大拾取范围
	data.base_hp = 75
	data.base_speed = 190.0
	data.base_damage = 1.4
	data.base_armor = 0.0
	data.base_pickup_range = 65.0

	data.weapon_type = "chain_lightning"
	data.default_outfit = "magic_dress"

	# 暴露路线：魔法礼裙 → 「以太共振」
	data.exposure_bonuses = [
		{
			"stage": 1,
			"visual": "裙摆碎裂",
			"description": "闪电链跳跃次数+2",
			"attack_speed_bonus": 0.0,
			"damage_bonus": 0.0,
			"speed_bonus": 0.0,
			"special": "chain_count_plus_2",
		},
		{
			"stage": 2,
			"visual": "手套/袖口消失",
			"description": "手部释放连续小范围电弧",
			"attack_speed_bonus": 0.10,
			"damage_bonus": 0.10,
			"speed_bonus": 0.0,
			"special": "arc_discharge",
		},
		{
			"stage": 3,
			"visual": "礼服大面积消失",
			"description": "暴露皮肤发光，全体敌人降防30%",
			"attack_speed_bonus": 0.10,
			"damage_bonus": 0.10,
			"speed_bonus": 0.0,
			"special": "enemy_def_reduce_30",
		},
		{
			"stage": 4,
			"visual": "纯魔力形态",
			"description": "全身电弧，触碰即死区域",
			"attack_speed_bonus": 0.20,
			"damage_bonus": 0.30,
			"speed_bonus": 0.10,
			"special": "death_aura",
		},
	]

	return data

# ============================================================
# 实例辅助方法
# ============================================================

## 根据暴露阶段获取当前阶段加成（阶段0无加成）
func get_exposure_bonus(stage: int) -> Dictionary:
	if stage <= 0 or stage > exposure_bonuses.size():
		return {}
	return exposure_bonuses[stage - 1]


## 获取指定阶段的特殊效果ID
func get_special_effect(stage: int) -> String:
	var bonus := get_exposure_bonus(stage)
	if bonus.is_empty():
		return ""
	return bonus.get("special", "")


## 计算指定暴露阶段的累积总加成（叠加所有已解锁阶段）
func get_cumulative_bonus(current_stage: int) -> Dictionary:
	var total := {
		"attack_speed_bonus": 0.0,
		"damage_bonus": 0.0,
		"speed_bonus": 0.0,
		"specials": [] as Array[String],
	}

	for i in range(mini(current_stage, exposure_bonuses.size())):
		var bonus: Dictionary = exposure_bonuses[i]
		total["attack_speed_bonus"] += bonus.get("attack_speed_bonus", 0.0)
		total["damage_bonus"] += bonus.get("damage_bonus", 0.0)
		total["speed_bonus"] += bonus.get("speed_bonus", 0.0)
		if bonus.has("special"):
			total["specials"].append(bonus["special"])

	return total


## 获取角色原型的中文名称
func get_archetype_name() -> String:
	match archetype:
		Archetype.BALANCED:
			return "均衡型"
		Archetype.MELEE:
			return "近战型"
		Archetype.MAGE:
			return "法师型"
	return "未知"
