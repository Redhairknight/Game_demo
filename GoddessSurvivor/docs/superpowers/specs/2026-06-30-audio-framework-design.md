# 音效/BGM 框架设计文档

> 状态：已确认，待实现
> 范围：AudioManager autoload + 事件驱动挂载 + 占位音频目录，无需真实音频文件

---

## 目标

搭建完整的音频框架：所有触发逻辑代码就绪，音频文件留空占位，后续补充真实资源无需改代码。

---

## 架构

### AudioManager（新 Autoload）

三类通道：
- **SFX**：8 个 AudioStreamPlayer 轮转池，同时播放多路短音效
- **UI**：独立单路，升级/解锁提示音
- **BGM**：单路循环，支持淡入淡出切换（tween 0.5s）

所有 `AudioStream` 变量初始为 `null`，`null` 检查跳过播放，不报错。

### 音频文件路径约定

```
GoddessSurvivor/audio/bgm/bgm_main.ogg
GoddessSurvivor/audio/bgm/bgm_boss.ogg
GoddessSurvivor/audio/sfx/sfx_enemy_die.ogg
GoddessSurvivor/audio/sfx/sfx_pickup.ogg
GoddessSurvivor/audio/sfx/sfx_levelup.ogg
GoddessSurvivor/audio/sfx/sfx_cloth_tear.ogg
GoddessSurvivor/audio/sfx/sfx_player_hurt.ogg
GoddessSurvivor/audio/sfx/sfx_player_die.ogg
GoddessSurvivor/audio/sfx/sfx_taunt_small.ogg
GoddessSurvivor/audio/sfx/sfx_taunt_full.ogg
GoddessSurvivor/audio/sfx/sfx_boss_die.ogg
GoddessSurvivor/audio/sfx/sfx_synergy.ogg
```

放入对应路径的 .ogg 文件后，下次运行自动生效。

---

## 信号→音效映射

| EventBus 信号 | 条件 | 音效 |
|---------------|------|------|
| `enemy_killed` | — | `sfx_enemy_die`（SFX池）|
| `exp_collected` | — | `sfx_pickup`（SFX池）|
| `level_up` | — | `sfx_levelup`（UI）|
| `clothing_stage_changed` | new_stage > 0 | `sfx_cloth_tear`（SFX池）|
| `player_damaged` | — | `sfx_player_hurt`（SFX池）|
| `player_died` | — | `sfx_player_die`（SFX池）|
| `taunt_released` | charge_level == 3 | `sfx_taunt_full`（SFX池）|
| `taunt_released` | charge_level < 3 | `sfx_taunt_small`（SFX池）|
| `boss_spawned` | — | `sfx_boss_die` 不播，切换 BGM 为 boss |
| `boss_defeated` | — | `sfx_boss_die`（SFX池）+ 切换 BGM 回 main |
| `synergy_awakened` | — | `sfx_synergy`（SFX池）|
| `game_over` | — | BGM 淡出停止 |

BGM 状态：game start → `bgm_main` → `boss_spawned` → `bgm_boss` → `boss_defeated` → `bgm_main` → `game_over` → 停止

---

## AudioManager 接口

```gdscript
func play_sfx(stream: AudioStream) -> void   # 从池中取一个空闲 player 播放
func play_ui(stream: AudioStream) -> void    # UI 专用 player
func play_bgm(stream: AudioStream) -> void   # 淡入淡出切换 BGM
func stop_bgm() -> void                      # 淡出停止
```

---

## 自检

- **占位符**：无 TBD/TODO，所有路径明确
- **内部一致性**：null 检查统一在 `play_sfx/play_ui/play_bgm` 入口，不在各信号回调里重复
- **范围**：1 个新文件 + project.godot 注册，适合单次计划
- **歧义**：SFX 池满时（8 个都在播放）— 最旧的 player 被复用（stop 后立即播新音效）
