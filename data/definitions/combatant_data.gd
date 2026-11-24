class_name CombatantData
extends Resource
## Sheet for a playable character or a critter (GDD 02). Recruited critters
## join the party with this same sheet. Names and every line of text come from
## game_text.json (matched by text_id); this file holds the rules and numbers.

enum PlaceholderShape { BOX, ROUND, DIAMOND, BLOB }

## The character or critter "id" in game_text.json ("bo", "big_frog").
@export var text_id: StringName
@export var display_name := ""
## Shorter name for the small party window. Empty = display_name.
@export var short_name := ""
## "the " for critters, so the text reads "Bo bonks the Big Frog!".
## BattleText.fill() capitalizes it at the start of a line.
@export var article := ""
## Race labels from GDD 02 (see Races). A character can carry several.
@export var races: Array[StringName] = []
@export var level := 1
@export var stats: StatBlock
## Entries in the Attack list (Melee, Throw Book...). Enemies also pick from these.
@export var weapons: Array[SkillData] = []
## Entries in the Skill list. Defend is added at the bottom automatically.
@export var skills: Array[SkillData] = []
@export var traits: Array[TraitData] = []

@export_group("Perks")
## Yawn + (GDD 13): every debuff this character applies is this much stronger.
## 0.5 = 50% stronger. Set by the skill tree later; 0 for now.
@export var debuff_strength_bonus := 0.0
## Yawn ++ (GDD 13): every debuff this character applies lasts this many turns longer.
@export var debuff_extra_stacks := 0

## Filled from game_text.json.
var signature_weapon := ""
var battle_intro := ""
var defend_text := ""

@export_group("Recruiting")
## Can be asked to join with Action > Recruit. The talk itself (questions and
## race reactions) lives in game_text.json, recruiting.negotiation (GDD 18).
@export var recruitable := true

@export_group("Raider voice")
## Event name -> lines, filled from game_text.json. A line can start with an
## expression tag like [happy] to pick the portrait face. Events: see BattleDialogue.
@export var battle_lines: Dictionary = {}
## Taunts used by the Humiliate sub action. {target} = the enemy.
@export var humiliate_lines := PackedStringArray()

@export_group("Visuals")
## Placeholder look until real sprites arrive.
@export var color := Color.WHITE
@export var placeholder_shape := PlaceholderShape.BOX
## Battle sprite size from the EarthBound set: 32x32, 64x32, 32x64, 64x64, bosses up to 128x128.
@export var battle_size := Vector2i(64, 64)
## Overworld size: 16x24 for main characters, 16x16 to 32x32 for holograms.
@export var overworld_size := Vector2i(16, 24)
## Optional real art. When set, it replaces the placeholder box.
## Battle animations: "idle", "hurt", "attack". Overworld: "idle", "walk".
@export var battle_frames: SpriteFrames
@export var overworld_frames: SpriteFrames
## 32x32 portrait for dialogue. One animation per expression tag in game_text.json
## (neutral, happy, worried, smug, surprised, bored, angry, sad, ridicule).
@export var portrait_frames: SpriteFrames


func is_raider() -> bool:
	return races.has(Races.RAIDERS)


func label() -> String:
	return article + display_name
