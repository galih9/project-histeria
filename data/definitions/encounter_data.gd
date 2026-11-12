class_name EncounterData
extends Resource
## What a roaming hologram holds: the monsters you fight and how the battle looks.

## Who struck first in the overworld (GDD 01, "First strike").
enum Advantage { NEUTRAL, PARTY, ENEMY }

@export var enemies: Array[CombatantData] = []
@export var is_boss := false
@export var background: BattleBackgroundPreset
## Optional opening line. Empty = "{first enemy} blocks the way!".
@export var intro_text := ""
## 0 = no drive drop, 1 = always drops one.
@export_range(0.0, 1.0) var drive_drop_chance := 0.5


func leader() -> CombatantData:
	return enemies[0] if not enemies.is_empty() else null
