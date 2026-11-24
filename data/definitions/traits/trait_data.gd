class_name TraitData
extends Resource
## A passive rule attached to a combatant (Stone Skin, Laugh Boost...).
## Each hook has a neutral default, so a trait overrides only what it needs.
## Traits keep no state of their own: one trait resource can serve many battlers.

## Matches the trait "id" in game_text.json.
@export var text_id: StringName
@export var display_name := ""
@export_multiline var description := ""


## Called while damage is calculated, before Lucky Guard.
func modify_incoming_damage(_owner: Battler, amount: float, _damage_type: DamageEffect.DamageType) -> float:
	return amount


## Called after the owner loses HP.
func after_damage_taken(_ctx: BattleContext, _owner: Battler, _old_hp: int) -> void:
	pass


## Called after the owner stamps a status on someone.
func after_status_inflicted(_ctx: BattleContext, _owner: Battler, _target: Battler, _status: StatusData) -> void:
	pass


## True while the trait gives a visible shield (the battle sprite shimmers).
func has_shield(_owner: Battler) -> bool:
	return false


## Receives the trait's battle_text from game_text.json.
func set_battle_text(_text: String) -> void:
	pass


## Ale's Overheal answers true (see OverhealTrait).
func turns_overheal_into_shield() -> bool:
	return false
