# 音频文件说明

将对应的 .ogg 文件放入此目录，AudioManager 会自动加载。

## BGM 文件（bgm/ 目录）
- bgm_main.ogg   — 主游戏背景音乐（循环）
- bgm_boss.ogg   — Boss 战背景音乐（循环）

## SFX 文件（sfx/ 目录）
- sfx_enemy_die.ogg    — 敌人死亡
- sfx_pickup.ogg       — 经验宝石拾取
- sfx_levelup.ogg      — 升级提示（UI）
- sfx_cloth_tear.ogg   — 衣着阶段变化
- sfx_player_hurt.ogg  — 玩家受伤
- sfx_player_die.ogg   — 玩家死亡
- sfx_taunt_small.ogg  — 嘲讽小/中释放
- sfx_taunt_full.ogg   — 嘲讽满蓄力释放
- sfx_boss_die.ogg     — Boss 击败
- sfx_synergy.ogg      — 协同觉醒触发

## 格式要求
- 格式：OGG Vorbis（Godot 原生支持）
- 采样率：44100 Hz 推荐
- BGM 建议做好循环点（loop_begin / loop_end）
