# Turnbased Prototype v2 (2D)

A playable Godot 4.7 prototype of the 2D pixel art GDD (`2d-pixel-art-version/` in the claude.ai project):
EarthBound-style top-down exploration with roaming holograms, and a front-view battle with the SP turn gauge,
Luck rolls, statuses, sub actions, recruiting and Raider dialogue. All art is placeholder shapes drawn in code,
ready to swap for Kiki's sprites.

Native screen: **400×224** with integer scaling (window 1200×672). Block 1 of the build plan
(`2d-pixel-art-version/16-build-blocks.md`) is in: Bo's and Ale's current kits, the Nov 19 status rules, and
every line of text loaded from `data/game_text.json`. The recruit talk from
`2d-pixel-art-version/18-recruit-negotiation.md` (questions, answers, race reactions, mood) is in too.

## Text: `data/game_text.json`

Every player-facing line lives in `data/game_text.json` (the same file as the project's `game_text.json`).
Edit a line there, then run the game (or go back to the title and press Play) to see it.

- The `GameText` autoload reads the file and writes the text into the data resources, matched by `text_id`
  (characters, critters, skills, moves, items, traits) or `id` (statuses). Skills, moves and traits match by
  their `"id"` in the JSON first, then by their name.
- Fields that are still empty in the JSON (Taunt, Stun, Paralyze, Shield text...) show plain stand-ins kept in
  `autoload/game_text.gd` (`STAND_INS`), until the JSON has a line.
- The `.tres` files hold rules and numbers only.

## Recruit talk

**Action → Recruit**, then pick a critter. The critter asks a random question from
`recruiting.negotiation.questions` in `data/game_text.json`, you pick an answer, and its race reacts with a line
and an outcome: `join`, `attack`, `leave`, `ask_again`, `give_money`, `give_item` or `heal_party`.
`ask_again` asks another question; a talk holds at most 3, and when the third ends on `ask_again` the critter leaves.

- **Races:** a critter uses the reactions of its race (`races` in its `.tres`). Each question's `race_set` points a
  race at one of its `reaction_sets`, so two races can share a set. A race still waiting for its reactions (Wanderers, so the
  Machinist) says so and keeps your turn.
- **Language lock:** Souls and Electronics talk only after their language unlock (`GameState.unlock_language()`,
  Yoon's books later). Until then the talk keeps your turn. The DEV menu's **Lang** button opens every language for
  playtests.
- **Mood:** every hostile reaction and every Luck save adds a mood stack (a red "MOOD +1" pop-up). At 3 stacks the
  critter stops responding for the rest of the battle. Mood resets after the battle.
- **Luck:** with Luck 10 or more, each hostile reaction (`attack`, `leave`) rolls Luck × 2% (max 50%, −10% per mood
  stack) to become `ask_again`.
- **Rewards:** coins and the heal scale with the critter's `level`; coins show in the pause menu's Party screen.
  `give_item` drops a Cookie, Fizzy Pop or Mystery Sandwich into the bag for now.
- Narration around the talk (the critter's speech format, "leaves the battle", coins...) uses plain stand-ins in
  `autoload/game_text.gd` (`STAND_INS`); a line with the same key in `battle_narration` replaces it.
- Every number lives in `battle/core/battle_rules.gd` under "Recruit talk".

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
| `autoload/` | `GameText` (loads `data/game_text.json`), `GameState` (party, bag, drives, beaten holograms, story flags, seen conversations), `SceneRouter` (fades + threaded loading screen), `EventBus` (global signals), `UserSettings` (text speed, damage numbers) |
| `scenes/` | Splash, title menu, loading screen |
| `game/` | `Game` (main.tscn): swaps between the world and the battle and applies the result |
| `world/` | Player box, holograms (wander → chase → give up), map section, placeholder blocks, interactables, world HUD, encounter swirl |
| `world/grass/` | `Wind` (the map's wind direction + strength), the grass sway shader, `GrassTuft` (one set of blades) and `GrassArea` (a shape you draw that fills with tufts) |
| `battle/core/` | The rules, with zero visuals: `BattleRules` (every tunable number), `TurnQueue` (SP gauge), `CombatMath` (hit, Luck, crit, damage), `BattleContext` (the battle API: statuses, Shield, control check, own-turn countdown), `BattleText` (narration lookup), `BattleDialogue` (Raider lines and conversations), `RecruitBank` (the recruit talk's question bank) |
| `battle/actions/` | Command objects: ability (weapon/skill/item), defend, recruit talk, run, Humiliate |
| `battle/ai/` | Data-driven move picker (weights and hints live in each skill's `.tres`) |
| `battle/ui/` | Battle view, party windows, enemy sprites, command menu, hit effects, popups, dialogue bubble |
| `data/definitions/` | Resource classes: stats, statuses, skills, items, effects, traits, combatants, encounters, drives |
| `data/*` | The actual content as `.tres` files, editable in the Inspector, plus `game_text.json` |
| `shaders/` | Battle background, hologram, encounter swirl, hit flash / dissolve |
| `ui/` | Theme (Pixelify Sans, OFL) and shared components: `MenuList`, `TextBox`, `PlaceholderArt`; `ui/dev/` holds the developer menu |
| `tests/` | Dev checks (see below) |

## Extending

- **New monster:** duplicate a file in `data/monsters/`, change stats, skills, color and size. Make an
  `EncounterData` in `data/encounters/` and drop a `world/holograms/hologram.tscn` instance on the map with it.
- **New skill:** create a `SkillData` resource and stack effects in its `effects` list
  (`DamageEffect`, `ApplyStatusEffect`, `HealEffect`, `RestoreMpEffect`, `CleanseEffect`). Give it a `text_id`
  and add its name, description and `battle_text` to the owner's `skills` (or `moves`) in `game_text.json`.
  Weapon-bound skills tick `requires_weapon` (locked while the weapon is away); `throws_weapon` and
  `retrieves_weapon` drive Ale's book. A `DamageEffect` can carry an element tag (Fire, Electric, Ice).
- **New kind of effect:** extend `EffectData`, override `apply(ctx, user, target)`, and call `BattleContext` methods.
- **New passive:** extend `TraitData` and override only the hooks you need (see `StoneSkinTrait`, `LaughBoostTrait`).
- **New command:** extend `BattleAction` and add an entry in `battle/ui/command_menu.gd`.
- **Real sprites:** set `battle_frames`, `overworld_frames` and `portrait_frames` (SpriteFrames) on a combatant.
  Battle animations: `idle`, `hurt`, `attack`. Portraits: one animation per expression tag in
  `game_text.json` (`neutral`, `happy`, `worried`, `smug`, `surprised`, `bored`, `angry`, `sad`, `ridicule`).
  The placeholder shape switches off automatically.
- **New conversation:** add an entry to `conversations.entries` in `game_text.json`; no code needed.
- **Real map:** replace `Ground` and the `PlaceholderBlock` nodes with `TileMapLayer`s. Keep `Entities` Y-sorted.
- **Battle background:** make a `BattleBackgroundPreset` (4 colors + wave numbers) and assign it to an encounter.
- **Balance:** every combat number is in `battle/core/battle_rules.gd`.

## Grass and wind

Grass is built from the white blade mask `assets/grassblade.png` (32x32, straight, root at column 16 of the bottom row).
If you redraw the blade with a different root, update `BLADE_ROOT` in `grass_tuft.gd` and `blade_root` / `blade_height`
in `grass_sway.gdshader`.

- **`GrassTuft`** = one set: 1–3 layers, each with 2–5 blades. Back layers sit 2 px higher and use darker colors;
  the front layer always uses the last, lightest color in `layer_colors`. Blades are mirrored at random (`flip_chance`).
- **`GrassArea`** (a Polygon2D) is the way to place grass: a shape you draw in the 2D editor that fills itself.
  Select `Entities`, Add Child Node → `GrassArea` (it starts as a small square), then drag the area to move it and
  drag its corner points to reshape it. The polygon toolbar above the 2D view adds and deletes points. The grass
  refills a moment after each edit. Ctrl+D duplicates an area. The pale green fill shows only in the editor.
  Settings: `density` (tufts per 32x32 block), `patchiness` (clumps), `edge_fade` (soft borders), `pattern_seed`,
  plus the tuft settings above. Areas keep clear of `PlaceholderBlock` footprints and the `Ground` paths; press
  **Rebuild grass** after moving those. Tufts are rebuilt on load, so they stay out of the `.tscn`.
  Keep areas inside the Y-sorted `Entities` node so the player walks through the grass.
- **`GrassField`** is the older rectangle version (size typed in as numbers). The playtest map now uses
  `GrassArea`, so `grass_field.gd` is free to delete.
- **`Wind`** (one per map) holds the wind data and drives the shader each frame.
  `direction_degrees` is where the wind blows TO (0 = east, 90 = south, 180 = west, 270 = north).
  Gameplay code can read `Wind.get_direction()`, `Wind.get_strength()`, `Wind.gust_at(pos)` and
  `Wind.force_at(pos)`, and change it with `Wind.current.blow(degrees, strength, seconds)`.
- **Shader** (`world/grass/grass_sway.gdshader`): steady lean + gust waves that roll across the map in the wind
  direction + a back-and-forth sway that travels downwind (blades swing to both sides of upright) + per-blade
  flutter. Strength 0 = every blade straight and still. Each pixel row shifts by whole pixels (more at the tip), so blades curve and stay
  crisp. Bent blades shorten a little, blades inside a gust get a pale shine, and the player parts the grass
  around their feet. Look settings (curve, droop, shading, shine) live on `world/grass/grass_material.tres`.
  In the editor the grass shows a still lean; the motion starts when the game runs.

### Flat grass tiles + wind folds

`resources/grass-flat-tilemap.tres` is the grass TileSet in one flat light green (`#9fdc6c`), with the same
layout as `grass-tilemap.tres`, so a painted map switches by changing the layer's `tile_set`. The playtest map's
`Grass` layer uses it, with `world/grass/wind_streaks_material.tres` as its Material.

The shader (`world/grass/wind_streaks.gdshader`) draws long, thin dark bands lying across the field at a right angle
to the wind, rolling downwind like the folds a gust pushes through a sea of grass in 3D. Each band tapers toward its
ends (lens or wedge), has a lit line on its downwind side and a mid-green back edge, fades in, rolls for a while,
fades out, and swells inside gusts. The `Wind` node drives it (gusts follow `wind_dir`, the band layout follows the
set `direction_degrees`), so the DEV menu sliders change it live. Bands only cover opaque tile pixels and swap whole
colors, so they stay on the palette.
Ordered (Bayer) dither softens each fold: a light glow ahead of it and a mid-green trail behind it.
Settings live on the material: colors (`fold_color`, `back_color`, `shine_color`), dither (`glow_color`,
`glow_px`, `trail_px`, `dither_strength`; 0 turns the soft edges off), shape (`length_px`,
`thickness_px`, `taper_skew`, `wave_px`, `tilt_degrees`) and amount (`spacing_px`, `lane_px`, `density`,
`calm_share`, `life_px`, `speed_scale`). In the editor the bands show as a frozen snapshot; the motion starts when
the game runs. To return to the detailed tiles, set the `Grass` layer's `tile_set` back to `grass-tilemap.tres`.

### Cloud shadows

`CloudShadows` (`world/weather/cloud_shadows.gd`) shades one map section with clouds that drift downwind. Add it to a
map scene after the `Entities` node and set `area` to the map's bounds (the playtest map has one). It multiplies
everything under a cloud (grass, sand, props, characters) by a cool shade, with a deeper shade in the thick middle;
every pixel is fully shaded or fully lit, and the cloud edges are an ordered dither, so it stays crisp pixel art.
The `Wind` node moves the clouds: `cloud_speed` (px per second at full strength) and `cloud_calm_share` (drift with
no wind) sit in its Clouds group. Look settings live on `world/weather/cloud_shadows_material.tres`:
`shadow_color`, `core_color` (white turns the core off), `cloud_size_px`, `coverage`, `softness` (edge dither width),
`core_inset`, `stretch`, `morph_speed` and `dither_px`. `show_in_editor` hides the frozen shadows while you edit.

## Developer menu

In debug runs (F5 from the editor) a **DEV** button sits in the top-right corner; F1 or the ` key opens it too.
It sets the wind live: direction, strength (Power), gustiness, and Calm / Breeze / Gale presets. The **Lang** button
opens every critter language for the recruit talk. The compass arrow
shows where the wind blows right now. The world keeps moving while it's open and the player waits. Up/Down picks a
slider, Left/Right moves it, X / Esc closes. The menu lives in `ui/dev/dev_menu.gd` and is added in `main.tscn`.

## Dev checks

Run from a terminal in the project folder (or open the scene and press F6):

```
godot --headless res://tests/compile_check.tscn            # loads every script, scene and resource
godot --headless --fixed-fps 60 res://tests/battle_sim.tscn   # 20 AI-vs-AI battles per encounter
godot --headless --fixed-fps 60 res://tests/feature_sim.tscn  # recruit talk + Humiliate stress test
godot --headless --fixed-fps 60 res://tests/negotiation_check.tscn # every recruit talk outcome, mood, Luck, language lock
godot --headless --fixed-fps 60 res://tests/block1_check.tscn # every Block 1 skill, rule, line event and conversation
godot --headless --fixed-fps 60 res://tests/world_run.tscn    # fights every hologram through the real world flow
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
| Recruit talk: Give Money / Give Item actions | Arrive later with the talking skills (GDD 18) |
| Recruit talk: low HP | A critter at 30% HP or less starts the talk with 1 mood stack (begging comes later) |
| Recruit talk: EXP after "leaves" | Arrives with the EXP system (Block 4) |
| Recruit talk: a critter leaves and nobody is left | The battle ends as a win |
| Recruit when the party is full | The Recruit entry is greyed out |
| Where Recruit sits | Action menu (Attack / Skill / Action / Item / Run); Call In and the other Actions come later |
| Paralyze | 50% chance to lose each own turn (`BattleRules.PARALYZE_LOSE_TURN_CHANCE`) |
| Stun chain reset | After 2 own turns free of Stun (`BattleRules.STUN_CHAIN_RESET_TURNS`) |
| Conversation vs single line | When a conversation matches, it plays half the time (`BattleDialogue.CONVERSATION_SHARE`) |
| Chances for the new line events | battle_start_player / enemy 60%, ally_critter_low_hp 50%, ally_critter_downed 90% |
| Bo and Ale skill numbers | Placeholders for the Block 2 balancing pass (MP, power, Sit Down 50% per enemy) |
| A hologram holds | One encounter (1 or more monsters; a "+" tag marks groups) |
