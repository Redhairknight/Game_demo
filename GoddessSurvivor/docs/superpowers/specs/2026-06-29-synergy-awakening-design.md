# 协同觉醒系统设计文档

> 状态：已确认，待实现
> 范围：铃（Rin）× 弹幕环 — 「心跳弹幕·星之告白」

---

## 目标

在现有核心循环（武器升级 + 衣着阶段）之上叠加一个"奖励玩家双线推进"的爆发机制。玩家同时把 BulletRing 升到 Lv5 **且**衣着阶段达到 3 时，触发一次性觉醒，BulletRing 进入永久增强形态，作为本局最高强度的战斗报酬。

---

## 架构

### 新增文件

| 文件 | 职责 |
|------|------|
| `scripts/systems/synergy_system.gd` | 独立节点，挂在 Player 下。轮询觉醒条件，满足时通知武器并播放视觉效果 |

### 修改文件

| 文件 | 修改内容 |
|------|---------|
| `scripts/weapons/bullet_ring.gd` | 添加 `is_awakened: bool`，`awaken()` 方法；在 `_fire_ring()` 中按标志分支 |
| `scenes/main/main.tscn` | 在 Player 下添加 SynergySystem 子节点 |
| `autoload/event_bus.gd` | 添加 `synergy_awakened(character_id, weapon_id)` 信号 |

---

## SynergySystem 行为

```
每帧 (_process):
  if already_awakened: return
  if character_id != "rin": return
  bullet_ring = WeaponPivot 下查找 BulletRing 实例
  if bullet_ring == null: return
  if bullet_ring.current_level < 5: return
  if clothing_system.current_stage < 3: return
  → 触发觉醒
```

**触发觉醒流程：**
1. `already_awakened = true`
2. 调用 `bullet_ring.awaken()`
3. `EventBus.synergy_awakened.emit("rin", "bullet_ring")`
4. 播放全屏闪白 tween（0.5s）
5. HUD 短暂显示觉醒提示文本（"心跳弹幕·星之告白！"，2s 后淡出）

**依赖：**
- `GameManager.player_node`（已有）
- `ClothingSystem.current_stage`（已有，public 属性）
- `WeaponPivot.get_node_or_null("BulletRing")`（P0 已建立命名约定）

---

## BulletRing 觉醒形态

觉醒后 `_fire_ring()` 的行为变化：

### 1. 心形弹幕纹理
子弹 Sprite2D 改用 `PixelSpriteGenerator.create_heart_bullet_texture()`（新增静态方法，12×12 粉红心形）。

### 2. 魅惑效果（Charm）
命中敌人时有 30% 概率调用 `enemy.apply_charm(3.0)`。
- `enemy_base.gd` 新增 `apply_charm(duration)` 方法：设置 `is_charmed = true`，计时器到期后清除。
- 被魅惑的敌人：`_move_towards_player` 改为朝最近其他敌人移动（攻击友军）。

### 3. 经验磁场
觉醒后 SynergySystem 每 0.5s 对场上所有 `exp_gems` 组的节点调用 `gem.attract_to(player_pos, speed=200)`。
- `exp_gem.gd` 新增 `attract_to(target_pos, speed)` 方法：启动 tween 移向目标，抵达后触发 `collect()`。

---

## HUD 觉醒提示

`hud.gd` 连接 `EventBus.synergy_awakened` 信号：
- 创建临时 Label 叠在屏幕中央
- 文本：「✦ 心跳弹幕·星之告白 ✦」
- 动画：scale 0.5→1.2→1.0（0.4s），2s 后淡出销毁

---

## 数据流

```
ClothingSystem.stage_changed
      ↓ (SynergySystem 每帧读 current_stage)
SynergySystem._process → 条件检查
      ↓ 满足
bullet_ring.awaken()          → BulletRing.is_awakened = true
EventBus.synergy_awakened     → HUD 显示提示
SynergySystem._start_exp_magnet_loop  → ExpGem.attract_to()
```

---

## 不在本次范围内

- 凛（Lin）/ 零（Rei）的觉醒形态
- 传统武器进化（武器 + 被动道具 → 进化形态）
- 觉醒后的额外粒子特效（像素风布片飘散）
- 亲密度加成逻辑

---

## 自检

- **占位符**：无 TBD/TODO
- **内部一致性**：SynergySystem 读取的字段（`current_stage`、`current_level`）均为已有 public 属性
- **范围**：单文件 + 两处小改，一次 Plan 可完成
- **歧义**：魅惑敌人"攻击友军"的实现——明确为修改移动目标到最近其他敌人，不是真正触发 enemy 的攻击动画，避免复杂度爆炸
