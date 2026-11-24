class_name StatBlock
extends Resource
## The stat set from GDD 04: six core stats, three secondary stats and Luck.
## Secondary stats are percentages written as whole numbers (95 = 95%).

## Stat names that statuses and traits can point at.
const ATTACK := &"attack"
const DEFENSE := &"defense"
const RESISTANCE := &"resistance"
const SPEED := &"speed"
const ACCURACY := &"accuracy"
const EVASION := &"evasion"
const CRIT_CHANCE := &"crit_chance"
const LUCK := &"luck"

## Display names used by the battle text ("Bo's Speed went up!").
const DISPLAY_NAMES: Dictionary = {
	ATTACK: "Attack",
	DEFENSE: "Defense",
	RESISTANCE: "Resistance",
	SPEED: "Speed",
	ACCURACY: "Accuracy",
	EVASION: "Evasion",
	CRIT_CHANCE: "Critical chance",
	LUCK: "Luck",
}

@export_group("Core")
@export var max_hp := 50
@export var max_mp := 10
@export var attack := 10.0
@export var defense := 10.0
@export var resistance := 10.0
## Fill rate of the SP gauge (GDD 05). Controls turn order only.
@export var speed := 10.0

@export_group("Secondary")
@export var accuracy := 95.0
@export var evasion := 5.0
@export var crit_chance := 5.0

@export_group("Background")
@export var luck := 5.0


func get_stat(stat: StringName) -> float:
	return float(get(stat))


static func display_name_of(stat: StringName) -> String:
	return DISPLAY_NAMES.get(stat, String(stat).capitalize())
