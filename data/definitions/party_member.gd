class_name PartyMember
extends RefCounted
## A character in the player's party, with HP and MP that carry over between battles.
## Battles build a Battler from this and write the results back at the end.

var data: CombatantData
var hp: int
var mp: int


func _init(combatant: CombatantData) -> void:
	data = combatant
	restore()


func restore() -> void:
	hp = data.stats.max_hp
	mp = data.stats.max_mp


func is_alive() -> bool:
	return hp > 0
