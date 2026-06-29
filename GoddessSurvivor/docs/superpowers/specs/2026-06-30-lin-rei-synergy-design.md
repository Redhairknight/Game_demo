# 凛+零协同觉醒系统设计文档

> 状态：已确认，待实现
> 范围：扩展 SynergySystem 为数据驱动，新增凛（逆鳞之舞）和零（以太共振）觉醒形态

---

## 目标

将现有仅支持铃的 SynergySystem 扩展为三角色通用架构，同时实现凛和零各自的觉醒效果。

---

## 架构：数据驱动扩展

将 `synergy_system.gd` 中硬编码的 `"rin"` / `BulletRing` 改为配置字典，每个角色定义触发武器名和觉醒效果 id。`_check_awakening` 查表处理，流程代码不变。

```gdscript
const SYNERGY_CONFIG := {
    "rin": {"weapon_name": "BulletRing",     "effect": "rin_heartbeat"},
    "lin": {"weapon_name": "SpinBlade",      "effect": "lin_reverse_scale"},
    "rei": {"weapon_name": "ChainLightning", "effect": "rei_resonance"},
}
```

`_trigger_awakening` 根据 `effect` id 调用对应武器的 `awaken()` 方法，并启动角色专属的持续效果。

---

## 文件变更

| 操作 | 文件 | 修改内容 |
|------|------|---------|
| 修改 | `scripts/systems/synergy_system.gd` | 改为数据驱动；新增凛的 `_start_lin_effect`（降防光环循环）和零的 `_start_rei_effect`（无需额外持续，链数已在武器内） |
| 修改 | `scripts/weapons/spin_blade.gd` | 添加 `is_awakened`、`awaken()`：觉醒后 `orbit_radius *= 3`，刀片命中后弹射 |
| 修改 | `scripts/weapons/chain_lightning.gd` | 添加 `is_awakened`、`awaken()`：觉醒后 `chain_count *= 2` |
| 修改 | `scripts/enemies/enemy_base.gd` | 添加 `defense_multiplier: float = 1.0`；`take_damage` 乘以它；添加 `apply_defense_reduction(amount, duration)` 方法 |

---

## 凛的觉醒效果：「逆鳞之舞·裸剑觉醒」

**触发条件**：角色 id = `"lin"` + SpinBlade Lv5 + 衣着阶段 ≥ 3

**SpinBlade 觉醒后行为**：

1. **刀刃范围 ×3**：`awaken()` 调用时 `orbit_radius *= 3.0`，立即重新定位所有刀片
2. **弹射伤害**：`_deal_damage_to(enemy)` 命中后，在 120px 范围内寻找最近其他敌人，对其造成 50% 伤害（一次性弹射，不循环）

**SynergySystem 持续效果**：凛没有全局持续效果（刀刃扩大已足够），仅播放全屏闪白 + HUD banner。

---

## 零的觉醒效果：「以太共振·雷霆解放」

**触发条件**：角色 id = `"rei"` + ChainLightning Lv5 + 衣着阶段 ≥ 3

**ChainLightning 觉醒后行为**：

1. **链数 ×2**：`awaken()` 调用时 `chain_count *= 2`，后续每次攻击链数翻倍

**SynergySystem 持续效果**：每 1 秒对场上所有敌人调用 `apply_defense_reduction(0.3, 1.5)`（降防 30%，持续 1.5s，保持滚动覆盖），模拟「全体敌人降防光环」。

---

## EnemyBase 防御系统

```gdscript
var defense_multiplier: float = 1.0  # 1.0 = 无减免；0.7 = 受到 70% 伤害

func apply_defense_reduction(amount: float, duration: float) -> void:
    defense_multiplier = 1.0 - amount  # amount=0.3 → multiplier=0.7
    get_tree().create_timer(duration).timeout.connect(
        func() -> void: defense_multiplier = 1.0
    )

# take_damage 修改：
func take_damage(damage: float) -> void:
    if is_dead:
        return
    current_hp -= damage * defense_multiplier
    ...
```

**注意**：多次调用 `apply_defense_reduction` 会覆盖前一次的计时器（每次都重置 multiplier 并新建计时器），滚动调用（每 1s 一次，持续 1.5s）保证降防永不过期。

---

## HUD Banner 文案

| 角色 | 文案 |
|------|------|
| 凛 | ✦ 逆鳞之舞·裸剑觉醒 ✦ |
| 零 | ✦ 以太共振·雷霆解放 ✦ |

颜色：凛用 `Color(0.7, 0.7, 1.0)`（银蓝），零用 `Color(0.6, 0.4, 1.0)`（紫色）。

---

## 信号流

```
SynergySystem._check_awakening()
  → 查 SYNERGY_CONFIG[current_character_id]
  → 找到对应武器节点 (SpinBlade / ChainLightning)
  → weapon.awaken()
  → EventBus.synergy_awakened.emit(char_id, weapon_id)
      → HUD banner (char_id 决定文案和颜色)
  → _play_flash_effect()
  → 如果 char_id == "rei": _start_rei_defense_aura()
```

---

## 自检

- **占位符**：无 TBD/TODO
- **内部一致性**：defense_multiplier 初始值 1.0 不影响现有敌人；apply_defense_reduction 覆盖写法不需要 stacking 逻辑
- **范围**：4 个文件，一次 Plan 可完成
- **歧义**：SpinBlade 弹射一次性（不是链式），明确为命中后找最近其他敌人打 50% 伤害，不再继续弹
