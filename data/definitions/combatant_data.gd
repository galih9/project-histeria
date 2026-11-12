class_name CombatantData
extends Resource
## Sheet for a playable character or a monster (GDD 02). Recruited monsters
## join the party with this same sheet.

enum PlaceholderShape { BOX, ROUND, DIAMOND, BLOB }

@export var display_name := ""
## Shorter name for the small party window. Empty = display_name.
@export var short_name := ""
## "the " for monsters, so the text reads "Tata bonks the Big Frog!".
## BattleText.fill() capitalizes it at the start of a line.
@export var article := ""
## Race labels from GDD 02 (see Races). A character can carry several.
@export var races: Array[StringName] = []
@export var level := 1
@export var stats: StatBlock
## Entries in the Attack list (Melee, Gun...). Enemies also pick from these.
@export var weapons: Array[SkillData] = []
## Entries in the Skill list. Defend is added at the bottom automatically.
@export var skills: Array[SkillData] = []
@export var traits: Array[TraitData] = []

@export_group("Recruiting")
@export var recruitable := true
## 0 = stubborn, 1 = joins happily. Lower HP makes any monster easier.
@export_range(0.0, 1.0) var temperament := 0.4
## The monster's reply when asked to join ({target} = its name).
@export var negotiation_lines := PackedStringArray()
@export var recruit_success_lines := PackedStringArray()
@export var recruit_fail_lines := PackedStringArray()

@export_group("Raider voice")
## Event name -> lines. Start a line with [happy], [worried], [smug] or
## [surprised] to pick the portrait expression. Events: see BattleDialogue.
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
## 32x32 portrait for dialogue. One animation per expression: neutral, happy, worried, smug, surprised.
@export var portrait_frames: SpriteFrames


func is_raider() -> bool:
	return races.has(Races.RAIDERS)


func label() -> String:
	return article + display_name
