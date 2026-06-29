# 亲密度跨局积累系统设计文档

> 状态：已确认，待实现
> 范围：存档 + 局内计算 + 结算展示，解锁内容为文字占位

---

## 目标

每局结束时根据本局表现向当前角色累积亲密度，数据持久化到本地文件，结算界面展示本局得分和解锁状态（文字占位，无需美术资产）。

---

## 架构

### 新增文件

| 文件 | 职责 |
|------|------|
| `autoload/affinity_manager.gd` | Autoload 单例：读写 `user://affinity.json`，提供 get/add 接口 |
| `scripts/systems/affinity_calculator.gd` | 局内节点：监听事件追踪本局成就，局结束时计算增量调用 AffinityManager |

### 修改文件

| 文件 | 修改内容 |
|------|---------|
| `project.godot` | 注册 `AffinityManager` autoload |
| `scripts/ui/game_over.gd` | 展示本局亲密度 +N、当前总计、新解锁提示 |
| `scenes/main/main.tscn` | 添加 AffinityCalculator 子节点（load_steps +1） |

---

## 亲密度来源（与设计文档 §9.1 对应）

| 事件 | 亲密度 | 追踪方式 |
|------|--------|---------|
| 每局基础完成 | +5 | 游戏结束时固定给予 |
| 达到衣着阶段 2 | +3 | `EventBus.clothing_stage_changed(new_stage >= 2)` |
| 达到衣着阶段 3 | +5 | `EventBus.clothing_stage_changed(new_stage >= 3)` |
| 达到衣着阶段 4 | +8 | `EventBus.clothing_stage_changed(new_stage >= 4)` |
| 触发极限形态 | +10 | `ClothingSystem.ultimate_triggered`（从 player 节点获取）|
| 触发协同觉醒 | +15 | `EventBus.synergy_awakened` |
| 嘲讽击杀 50+ | +5 | `EventBus.taunt_released` + `enemy_killed` 计数 |

**阶段奖励累积规则**：阶段 3 的 +5 包含阶段 2 的 +3，即达到阶段 3 时总共得 +3+5=+8（各自独立标记，不重复）。

---

## AffinityManager 接口

```gdscript
# 文件路径
const SAVE_PATH = "user://affinity.json"

# 存档格式
# { "rin": 42, "lin": 0, "rei": 7 }

func get_affinity(char_id: String) -> int
func add_affinity(char_id: String, amount: int) -> void  # 自动持久化
func get_unlocks(char_id: String) -> Array[Dictionary]   # 返回已解锁的描述列表
func get_pending_unlocks(char_id: String, old_val: int, new_val: int) -> Array[Dictionary]  # 本次新解锁
```

---

## 解锁阈值与描述（文字占位）

| 亲密度 | id | 描述文字 |
|--------|-----|---------|
| 10 | voice_1 | 「语音包1」战斗台词已解锁（待配音）|
| 25 | outfit_1 | 「专属服装1」已解锁（待美术完成）|
| 50 | animation_1 | 「互动动画」已解锁（待动画完成）|
| 75 | voice_2 | 「语音包2」暴露台词已解锁（待配音）|
| 100 | hidden_char | 「焰·Homura」隐藏角色已解锁（待实现）|
| 150 | final_form | 「约定形态」最终造型已解锁（待美术完成）|

---

## AffinityCalculator 行为

```
_ready():
  等待 player_ref 就绪后连接信号

连接信号:
  EventBus.clothing_stage_changed  → 记录 max_stage（flag: reached_2/3/4）
  EventBus.synergy_awakened        → synergy_triggered = true
  ClothingSystem.ultimate_triggered → ultimate_triggered = true
  EventBus.taunt_released(level)   → if level==3: taunt_kills_window=true（开始计数）
  EventBus.enemy_killed            → if taunt_kills_window: taunt_kill_count++
  EventBus.game_over               → _calculate_and_save()

_calculate_and_save():
  var char_id = GameManager.current_character_id
  var old_val = AffinityManager.get_affinity(char_id)
  var delta = 5  # 基础完成
  if reached_stage_2: delta += 3
  if reached_stage_3: delta += 5
  if reached_stage_4: delta += 8
  if ultimate_triggered: delta += 10
  if synergy_triggered: delta += 15
  if taunt_kill_count >= 50: delta += 5
  AffinityManager.add_affinity(char_id, delta)
  var new_val = AffinityManager.get_affinity(char_id)
  # 通知 GameOver 界面
  EventBus.affinity_updated.emit(char_id, delta, new_val,
      AffinityManager.get_pending_unlocks(char_id, old_val, new_val))
```

---

## GameOver 界面扩展

在现有统计（时间/击杀/等级）下方追加：

```
────────────────────────────
亲密度  铃 (Rin)   +23 ★
        当前: 65 / 下一解锁: 75
────────────────────────────
新解锁：「专属服装1」已解锁（待美术完成）
```

`EventBus.affinity_updated` 触发后调用 `_show_affinity_result()`。

---

## 信号流

```
game_over.emit()
  → AffinityCalculator._calculate_and_save()
      → AffinityManager.add_affinity()  →  写 user://affinity.json
      → EventBus.affinity_updated.emit(char_id, delta, new_total, new_unlocks)
          → GameOver._show_affinity_result()  →  展示 +N 和解锁列表
```

---

## 新增 EventBus 信号

```gdscript
signal affinity_updated(char_id: String, delta: int, new_total: int, new_unlocks: Array)
```

---

## 自检

- **占位符**：无 TBD/TODO
- **内部一致性**：`ultimate_triggered` 是 ClothingSystem 本地信号，AffinityCalculator 通过 player_ref 获取，不走 EventBus——需要等 player 就绪后连接
- **范围**：适合单次计划实现
- **歧义**：嘲讽击杀计数——明确为 `ChargeLevel.FULL`（level==3）释放后的击杀才算，窗口为 3 秒（与 taunt AOE 持续时间一致）
