# Turnbased Prototype v2 (2D)

A playable Godot 4.7 prototype of the 2D pixel art GDD (`2d-pixel-art-version/` in the claude.ai project):
EarthBound-style top-down exploration with roaming holograms, and a front-view battle with the SP turn gauge,
Luck rolls, statuses, sub actions, recruiting and Raider dialogue. All art is placeholder shapes drawn in code,
ready to swap for Kiki's sprites.

## Run it

Open the project in Godot 4.7 and press **F5**. Flow: splash → title menu → loading screen → playtest map.

| Action | Keys | Gamepad |
| --- | --- | --- |
| Move | Arrows / WASD | D-pad / left stick |
| Confirm, talk, swing | Z / Enter / Space | A |
| Cancel (steps back one menu level) | X / Esc / Backspace | B |
| Pause menu (overworld) | Tab / C / Esc | Start |

In the overworld: walk into a hologram to fight it. Swing (Z) at it first for a **first strike** (green swirl,
party starts with +0.25 SP). Get touched from behind and the enemies get the jump (red swirl).
The hot dog stand restores the party. The Big Frog boss waits by the pond in the top right.

## Folder map

| Folder | What lives there |
| --- | --- |
| `autoload/` | `GameState` (party, bag, drives, beaten holograms), `SceneRouter` (fades + threaded loading screen), `EventBus` (global signals), `UserSettings` (text speed, damage numbers) |
| `scenes/` | Splash, title menu, loading screen |
| `game/` | `Game` (main.tscn): swaps between the world and the battle and applies the result |
| `world/` | Player box, holograms (wander → chase → give up), map section, placeholder blocks, interactables, world HUD, encounter swirl |
| `battle/core/` | The rules, with zero visuals: `BattleRules` (every tunable number), `TurnQueue` (SP gauge), `CombatMath` (hit, Luck, crit, damage), `BattleContext` (the battle API), `BattleText` (all narration), `BattleDialogue` |
| `battle/actions/` | Command objects: ability (weapon/skill/item), defend, recruit, run, Humiliate |
| `battle/ai/` | Data-driven move picker (weights and hints live in each skill's `.tres`) |
| `battle/ui/` | Battle view, party windows, enemy sprites, command menu, hit effects, popups, dialogue bubble |
| `data/definitions/` | Resource classes: stats, statuses, skills, items, effects, traits, combatants, encounters, drives |
| `data/*` | The actual content as `.tres` files, editable in the Inspector |
| `shaders/` | Battle background, hologram, encounter swirl, hit flash / dissolve |
| `ui/` | Theme (Pixelify Sans, OFL) and shared components: `MenuList`, `TextBox`, `PlaceholderArt` |
| `tests/` | Dev checks (see below) |

## Extending

- **New monster:** duplicate a file in `data/monsters/`, change stats, skills, color and size. Make an
  `EncounterData` in `data/encounters/` and drop a `world/holograms/hologram.tscn` instance on the map with it.
- **New skill:** create a `SkillData` resource and stack effects in its `effects` list
  (`DamageEffect`, `ApplyStatusEffect`, `HealEffect`, `RestoreMpEffect`, `CleanseEffect`).
- **New kind of effect:** extend `EffectData`, override `apply(ctx, user, target)`, and call `BattleContext` methods.
- **New passive:** extend `TraitData` and override only the hooks you need (see `StoneSkinTrait`, `LaughBoostTrait`).
- **New command:** extend `BattleAction` and add an entry in `battle/ui/command_menu.gd`.
- **Real sprites:** set `battle_frames`, `overworld_frames` and `portrait_frames` (SpriteFrames) on a combatant.
  Battle animations: `idle`, `hurt`, `attack`. Portraits: one animation per expression
  (`neutral`, `happy`, `worried`, `smug`, `surprised`). The placeholder shape switches off automatically.
- **Real map:** replace `Ground` and the `PlaceholderBlock` nodes with `TileMapLayer`s. Keep `Entities` Y-sorted.
- **Battle background:** make a `BattleBackgroundPreset` (4 colors + wave numbers) and assign it to an encounter.
- **Balance:** every combat number is in `battle/core/battle_rules.gd`.

## Dev checks

Run from a terminal in the project folder (or open the scene and press F6):

```
godot --headless res://tests/compile_check.tscn            # loads every script, scene and resource
godot --headless --fixed-fps 60 res://tests/battle_sim.tscn   # 20 AI-vs-AI battles per encounter
godot --headless --fixed-fps 60 res://tests/feature_sim.tscn  # recruiting + Humiliate stress test
```

`BattleController.auto_battle` (Inspector) lets the AI play the party too.

## Placeholder answers to open GDD questions

These keep the prototype playable; each is one constant or resource away from changing.

| Open question | Prototype choice |
| --- | --- |
| How to strike first | Swing button (option A); touching from behind gives the enemies the jump |
| First strike bonus | +0.25 SP for the whole side |
| Encounter transition | Swirl shader: green party, red enemy, purple neutral |
| Defeat | Party wakes up at the spawn point, fully restored |
| Recovery outside battle | The hot dog stand on the map |
| Run | In the menu, faster runners escape more often, disabled in boss battles |
| Rolling HP counter | On (visual only; `PartyWindow.rolling_hp`) |
| Status icons on party windows | Tiny colored pips |
| Damage numbers | On, with a toggle in the title menu |
| Damage formula | Attack × power / 10 × 20 / (20 + defense), ±10% |
| Accuracy | Accuracy − Evasion, clamped to 5–100% |
| Recruit chance | temperament × (0.25 + 0.75 × missing HP) + Luck × 0.3% |
| Recruit when the party is full | The Recruit entry is greyed out |
| A hologram holds | One encounter (1 or more monsters; a "+" tag marks groups) |
