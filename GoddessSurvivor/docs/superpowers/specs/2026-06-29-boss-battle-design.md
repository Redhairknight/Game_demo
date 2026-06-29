# Boss 战系统设计文档

> 状态：已确认，待实现
> 范围：单阶段 Boss，11 分钟触发，冲刺 + 弹幕圈双攻击模式

---

## 目标

在 11 分钟节点引入一个高强度 Boss 敌人，作为单局的核心高潮时刻。Boss 击败后必掉换装宝箱，为剩余时间提供战略奖励。

---

## 架构

### 新增文件

| 文件 | 职责 |
|------|------|
| `scripts/enemies/boss_enemy.gd` | Boss 脚本，继承 EnemyBase，覆写移动和双攻击逻辑 |
| `scripts/ui/boss_health_bar.gd` | Boss 血条 CanvasLayer，顶部居中显示，监听 hp_changed 信号 |

### 修改文件

| 文件 | 修改内容 |
|------|---------|
| `scripts/enemies/enemy_spawner.gd` | 新增 11 分钟触发逻辑，Boss 存活期间停止普通生成 |
| `scripts/systems/pixel_sprite_generator.gd` | 新增 `create_boss_texture()` 96×96 占位图 |
| `autoload/event_bus.gd` | 新增 `boss_defeated` 信号 |
| `scenes/main/main.tscn` | 新增 BossHealthBar CanvasLayer 节点（load_steps +2） |

---

## Boss 属性

| 属性 | 值 |
|------|-----|
| HP | 5000（固定，不随时间缩放） |
| 体型 | scale Vector2(3, 3)，视觉 96×96px |
| 接触伤害 | 40 |
| 移速（巡逻） | 60 px/s |
| 击退抗性 | 1.0（完全免疫） |
| 死亡经验 | 100 |
| enemy_type | "boss" |

---

## 攻击模式

两种攻击由各自独立计时器驱动，互不干扰。

### 攻击 1：冲刺（Dash）
- 间隔：每 **4 秒** 执行一次
- 流程：
  1. 预判玩家当前位置，记为 `dash_target`
  2. 显示红色警告线（Line2D，0.5s 后消失）
  3. 0.5s 后以 `move_speed × 5`（= 300 px/s）高速冲向 `dash_target`
  4. 冲刺持续 **0.6s**，之后恢复普通追踪移动
- 冲刺期间：仍可触发接触伤害（contact_damage = 40）
- 冲刺期间：忽略击退

### 攻击 2：弹幕圈（BulletRing）
- 间隔：每 **6 秒** 执行一次
- 从 Boss 位置向四周均匀发射 **12 颗子弹**
- 子弹伤害：**25**，速度：300 px/s，存活：2s
- 子弹逻辑复用 `_spawn_simple_bullet` 的 Area2D 模式（不依赖 BulletRing 类）
- 子弹碰撞层：Layer 4（Weapons），遮罩：Layer 1（Player）

---

## 触发与结束

### 触发（EnemySpawner）
- 在 `_process` 里检查 `GameManager.elapsed_time >= 660.0`（11 分钟）
- 仅触发一次（`boss_spawned: bool` 标志）
- 触发时：
  1. spawn `BossEnemy` 在玩家右方 400px
  2. `EventBus.boss_spawned.emit(boss)`
  3. 设置 `is_boss_alive = true`，普通生成暂停

### 结束（BossEnemy._die() 覆写）
1. `EventBus.boss_defeated.emit()`
2. 掉落 **100 颗经验宝石**（分 10 次 loop 每次 10 exp，scatter 效果）
3. 在 Boss 位置 spawn 一个 `WardrobeChest`
4. 调用 `super._die()`（不掉普通 exp gem，覆写 `_drop_exp`）

### EnemySpawner 恢复
- 监听 `EventBus.boss_defeated`，设置 `is_boss_alive = false`，恢复普通生成

---

## HUD：Boss 血条

- `BossHealthBar` 继承 `CanvasLayer`（layer = 15）
- `_ready` 时 `visible = false`
- 监听 `EventBus.boss_spawned`：显示血条，连接 Boss 的 `hp_changed` 信号
- 监听 `EventBus.boss_defeated`：隐藏血条
- 布局：屏幕顶部居中，宽 600px，高 24px，红色进度条 + "BOSS" 标签

---

## 信号流

```
EnemySpawner (t=660s)
  → BossEnemy.new() → get_tree().current_scene.add_child()
  → EventBus.boss_spawned(boss)
      → BossHealthBar.show + connect boss.hp_changed

BossEnemy.take_damage()
  → hp_changed(current_hp, max_hp)
      → BossHealthBar 更新进度

BossEnemy._die()
  → EventBus.boss_defeated()
      → EnemySpawner 恢复普通生成
      → BossHealthBar 隐藏
  → 掉落 10×ExpGem(10) scatter
  → spawn WardrobeChest at boss_pos
```

---

## 自检

- **占位符**：无 TBD/TODO
- **内部一致性**：子弹碰撞层 Layer 4 mask Layer 1（Player），与现有玩家 hurtbox Layer 1 一致
- **范围**：6 个文件，一次 Plan 可完成
- **歧义**：Boss 期间普通生成"暂停"的定义——明确为 `spawn_timer` 不累加（而非清零），Boss 死后继续从当前计时恢复
