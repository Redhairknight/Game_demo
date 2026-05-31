# Nikki Survivors - Sprite Asset List

All sprites use pixel art style. Default filter mode: Nearest (already set in project.godot).

---

## Characters (48x48 pixels each frame)

| Sprite Name | Frames | Animation | Description |
|-------------|--------|-----------|-------------|
| rin_idle | 4 | Loop, 4fps | Rin standing idle, subtle breathing animation |
| rin_walk | 4 | Loop, 8fps | Rin walking cycle (4-direction or flip) |
| lin_idle | 4 | Loop, 4fps | Lin standing idle, hair sway |
| lin_walk | 4 | Loop, 8fps | Lin walking cycle |
| rei_idle | 4 | Loop, 4fps | Rei standing idle, cape flutter |
| rei_walk | 4 | Loop, 8fps | Rei walking cycle |

**Spritesheet format:** Horizontal strip (192x48 for 4 frames)
**Color palette:** Limited 16-color palette per character
**Style reference:** Vampire Survivors character proportions (chibi, 3-head tall)

### Character Color Guide (placeholder)
- **Rin:** Pink/magenta primary, white secondary
- **Lin:** Blue/cyan primary, black secondary
- **Rei:** Purple/gold primary, dark grey secondary

---

## Enemies (32x32 pixels each frame)

| Sprite Name | Frames | Animation | Description |
|-------------|--------|-----------|-------------|
| slime | 2 | Loop, 3fps | Green slime bouncing (squash/stretch) |
| bat | 2 | Loop, 6fps | Purple bat wing flap |
| knight | 2 | Loop, 4fps | Armored knight marching |

**Spritesheet format:** Horizontal strip (64x32 for 2 frames)
**Notes:** Enemies should have clear silhouettes distinguishable at distance

---

## Weapon Effects (16x16 pixels)

| Sprite Name | Frames | Animation | Description |
|-------------|--------|-----------|-------------|
| bullet | 1 | Static | Round pink energy bullet |
| blade | 1 | Static | Crescent blade slash (can be rotated in code) |
| lightning | 1 | Static | Lightning bolt strike |

**Notes:** Weapon effects may be rotated/scaled programmatically. Keep centered on sprite.

---

## Pickups (16x16 pixels)

| Sprite Name | Frames | Animation | Description |
|-------------|--------|-----------|-------------|
| exp_gem | 1 | Static (code bounce) | Blue diamond-shaped experience gem |
| hp_orb | 1 | Static (code bounce) | Red/pink heart or orb for healing |
| clothing_chest | 1 | Static | Golden chest for clothing/equipment drops |

**Notes:** Pickup float animation handled by code (sine wave Y offset)

---

## UI Elements

| Asset Name | Size | Description |
|------------|------|-------------|
| hp_bar_fill | 128x12 | Red gradient fill for HP bar |
| hp_bar_bg | 128x12 | Dark background for HP bar |
| clothing_bar_fill | 128x12 | Pink/magenta gradient fill |
| clothing_bar_bg | 128x12 | Dark background |
| exp_bar_fill | 256x8 | Cyan/blue gradient fill |
| exp_bar_bg | 256x8 | Dark background |
| level_up_panel_bg | 400x500 | Semi-transparent dark panel with border |
| option_button_bg | 360x80 | Button background for level-up options |
| option_button_hover | 360x80 | Highlighted button state |

**Notes:** UI uses Godot's built-in theming where possible. These are optional overrides.

---

## Tilemap / Background

| Asset Name | Size | Description |
|------------|------|-------------|
| ground_tile | 16x16 | Basic grass/ground repeating tile |
| ground_tile_alt | 16x16 | Variation tile for visual variety |

---

## File Naming Convention

```
assets/sprites/characters/rin_idle.png    (192x48 spritesheet)
assets/sprites/characters/rin_walk.png    (192x48 spritesheet)
assets/sprites/characters/lin_idle.png
assets/sprites/characters/lin_walk.png
assets/sprites/characters/rei_idle.png
assets/sprites/characters/rei_walk.png
assets/sprites/enemies/slime.png          (64x32 spritesheet)
assets/sprites/enemies/bat.png            (64x32 spritesheet)
assets/sprites/enemies/knight.png         (64x32 spritesheet)
assets/sprites/weapons/bullet.png         (16x16)
assets/sprites/weapons/blade.png          (16x16)
assets/sprites/weapons/lightning.png      (16x16)
assets/sprites/pickups/exp_gem.png        (16x16)
assets/sprites/pickups/hp_orb.png         (16x16)
assets/sprites/pickups/clothing_chest.png (16x16)
assets/sprites/ui/hp_bar_fill.png
assets/sprites/ui/clothing_bar_fill.png
assets/sprites/ui/exp_bar_fill.png
assets/sprites/ui/level_up_panel_bg.png
```

---

## Import Settings (Godot)

All sprites should use:
- **Filter:** Nearest (set globally in project.godot)
- **Compression:** Lossless
- **Mipmaps:** Off
- **Fix Alpha Border:** Off

Spritesheets should have:
- **Hframes** set appropriately in Sprite2D nodes
- **Animation** handled via AnimationPlayer or AnimatedSprite2D
