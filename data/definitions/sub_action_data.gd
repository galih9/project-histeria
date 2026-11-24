class_name SubActionData
extends Resource
## Settings for a sub action (GDD 06): a free, Luck-gated flourish.

## Matches the sub action "id" in game_text.json.
@export var text_id: StringName = &"humiliate"
@export var display_name := "Humiliate"
## Allowed in boss battles.
@export var boss_safe := false
## Chance = base_chance + Luck x luck_factor, capped at max_chance.
@export_range(0.0, 1.0) var base_chance := 0.4
@export var luck_factor := 0.005
@export_range(0.0, 1.0) var max_chance := 0.8
## The menu color that makes sub actions easy to spot.
@export var highlight_color := Color("ff7ad9")

@export_group("Humiliate")
## Humiliate lowers one random stat from this pool.
@export var debuff_pool: Array[StatusData] = []
@export_range(1, 5) var stacks := 2
@export var react_text := "{target} feels deeply insulted!"
## Shown when the opening appears. Filled from game_text.json.
var open_text := ""
## Used when the Raider has no humiliate_lines.
var fallback_text := "{user} makes a rude face at {target}!"


func availability_chance(luck: float) -> float:
	return minf(base_chance + luck * luck_factor, max_chance)
