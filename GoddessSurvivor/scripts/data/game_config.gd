## game_config.gd
## 全局游戏配置 - 定义游戏核心系统参数
## Nikki Survivors - 类Vampire Survivors像素风游戏
class_name GameConfig
extends Resource

# ============================================================
# 单局基础设置
# ============================================================

## 单局总时长（秒）= 15分钟
const ROUND_DURATION: float = 900.0

## 单局总时长（分钟）
const ROUND_DURATION_MINUTES: float = 15.0

## 最大玩家等级
const MAX_PLAYER_LEVEL: int = 50

# ============================================================
# 经验值系统
# ============================================================

## 每级所需经验值表（索引0=Lv1→Lv2所需经验，以此类推）
## 设计思路：前期升级快（让玩家快速体验升级乐趣），后期放缓
const EXP_TABLE: Array[int] = [
	5,    # Lv 1 → 2
	8,    # Lv 2 → 3
	12,   # Lv 3 → 4
	17,   # Lv 4 → 5
	23,   # Lv 5 → 6
	30,   # Lv 6 → 7
	38,   # Lv 7 → 8
	47,   # Lv 8 → 9
	57,   # Lv 9 → 10
	68,   # Lv 10 → 11
	80,   # Lv 11 → 12
	93,   # Lv 12 → 13
	107,  # Lv 13 → 14
	122,  # Lv 14 → 15
	138,  # Lv 15 → 16
	155,  # Lv 16 → 17
	173,  # Lv 17 → 18
	192,  # Lv 18 → 19
	212,  # Lv 19 → 20
	235,  # Lv 20 → 21
	260,  # Lv 21 → 22
	287,  # Lv 22 → 23
	316,  # Lv 23 → 24
	347,  # Lv 24 → 25
	380,  # Lv 25 → 26
	415,  # Lv 26 → 27
	452,  # Lv 27 → 28
	491,  # Lv 28 → 29
	532,  # Lv 29 → 30
	576,  # Lv 30 → 31
	622,  # Lv 31 → 32
	670,  # Lv 32 → 33
	720,  # Lv 33 → 34
	773,  # Lv 34 → 35
	828,  # Lv 35 → 36
	886,  # Lv 36 → 37
	946,  # Lv 37 → 38
	1009, # Lv 38 → 39
	1075, # Lv 39 → 40
	1144, # Lv 40 → 41
	1216, # Lv 41 → 42
	1291, # Lv 42 → 43
	1369, # Lv 43 → 44
	1450, # Lv 44 → 45
	1534, # Lv 45 → 46
	1621, # Lv 46 → 47
	1711, # Lv 47 → 48
	1804, # Lv 48 → 49
	1900, # Lv 49 → 50
]

## 获取指定等级升级所需经验值
static func get_exp_required(current_level: int) -> int:
	var index = current_level - 1
	if index >= 0 and index < EXP_TABLE.size():
		return EXP_TABLE[index]
	# 超出表范围时使用公式：基础值 * 1.08^等级
	return int(1900 * pow(1.08, current_level - MAX_PLAYER_LEVEL))


# ============================================================
# 衣着耐久度系统（核心机制：衣着破损 → 属性提升）
# ============================================================

## 衣着阶段枚举
enum ClothingStage {
	PRISTINE = 0,    ## 完好（100%~76%）
	DAMAGED = 1,     ## 损伤（75%~51%）
	TORN = 2,        ## 破损（50%~26%）
	TATTERED = 3,    ## 残破（25%~1%）
	EXPOSED = 4,     ## 解放（0%）
}

## 衣着阶段阈值（百分比，从上到下递减）
## 当衣着耐久度 <= 阈值时，进入对应阶段
const CLOTHING_THRESHOLDS: Dictionary = {
	"pristine_min": 76,   # 76%~100% = 完好
	"damaged_min": 51,    # 51%~75% = 损伤
	"torn_min": 26,       # 26%~50% = 破损
	"tattered_min": 1,    # 1%~25% = 残破
	"exposed_min": 0,     # 0% = 解放
}

## 根据耐久度百分比获取当前阶段
static func get_clothing_stage(durability_percent: int) -> int:
	if durability_percent >= 76:
		return ClothingStage.PRISTINE
	elif durability_percent >= 51:
		return ClothingStage.DAMAGED
	elif durability_percent >= 26:
		return ClothingStage.TORN
	elif durability_percent >= 1:
		return ClothingStage.TATTERED
	else:
		return ClothingStage.EXPOSED


# ============================================================
# 升级选项概率系统
# ============================================================

## 升级时各选项出现的权重（百分比）
const LEVELUP_OPTION_WEIGHTS: Dictionary = {
	"weapon": 40,      ## 武器升级/获取新武器
	"passive": 30,     ## 被动技能（移速、HP、拾取范围等）
	"liberation": 20,  ## 解放技能（主动降低衣着换取强力效果）
	"special": 10,     ## 特殊选项（全屏清怪、回血、临时无敌等）
}

## 每次升级提供的选项数量
const LEVELUP_OPTIONS_COUNT: int = 3

## 根据权重随机获取一个选项类型
static func roll_levelup_option_type() -> String:
	var total_weight: int = 0
	for weight in LEVELUP_OPTION_WEIGHTS.values():
		total_weight += weight

	var roll = randi() % total_weight
	var cumulative: int = 0
	for option_type in LEVELUP_OPTION_WEIGHTS.keys():
		cumulative += LEVELUP_OPTION_WEIGHTS[option_type]
		if roll < cumulative:
			return option_type

	return "weapon"  # 兜底返回


# ============================================================
# 换装宝箱系统
# ============================================================

## 换装宝箱最小间隔（秒）= 3分钟
const CHEST_INTERVAL_MIN: float = 180.0

## 换装宝箱最大间隔（秒）= 4分钟
const CHEST_INTERVAL_MAX: float = 240.0

## 获取随机宝箱生成间隔
static func get_random_chest_interval() -> float:
	return randf_range(CHEST_INTERVAL_MIN, CHEST_INTERVAL_MAX)

## 宝箱提供的衣着恢复量（百分比）
const CHEST_CLOTHING_RESTORE: int = 25

## 宝箱是否提供换装选择（true=可选择不同造型）
const CHEST_OFFERS_COSTUME_CHANGE: bool = true


# ============================================================
# 难度缩放配置
# ============================================================

## 敌人生成速率（每分钟递增倍率）
const SPAWN_RATE_SCALE_PER_MINUTE: float = 0.12

## 初始每秒生成敌人数
const BASE_SPAWN_RATE: float = 0.8

## 最大每秒生成敌人数
const MAX_SPAWN_RATE: float = 8.0

## 精英敌人出现概率（从第3分钟开始，每分钟+2%）
const ELITE_CHANCE_PER_MINUTE: float = 0.02

## 精英概率上限
const ELITE_CHANCE_MAX: float = 0.25

## 根据游戏时间计算当前生成速率
static func get_spawn_rate(elapsed_minutes: float) -> float:
	var rate = BASE_SPAWN_RATE * (1.0 + SPAWN_RATE_SCALE_PER_MINUTE * elapsed_minutes)
	return minf(rate, MAX_SPAWN_RATE)


# ============================================================
# 其他全局参数
# ============================================================

## 经验宝石吸附速度（像素/秒）
const EXP_GEM_ATTRACT_SPEED: float = 300.0

## 经验宝石自然消失时间（秒）
const EXP_GEM_LIFETIME: float = 30.0

## 玩家无敌帧时长（秒）
const PLAYER_INVINCIBILITY_DURATION: float = 0.5

## 屏幕外敌人生成距离（像素，距离屏幕边缘）
const ENEMY_SPAWN_DISTANCE: float = 80.0

## 最大同屏敌人数量
const MAX_ENEMIES_ON_SCREEN: int = 200
