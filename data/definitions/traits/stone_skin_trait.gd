class_name StoneSkinTrait
extends TraitData
## Flying Stone Thing passive (GDD 02): strong against Physical and Magical
## damage while HP is above the threshold. At or below it, full damage.

@export_range(0.0, 1.0) var hp_threshold := 0.5
## Share of Physical and Magical damage that gets through while the skin holds.
@export_range(0.0, 1.0) var damage_taken := 0.35
@export var break_text := "{target}'s stony shell cracks! It looks squishy now!"


func is_active(owner: Battler) -> bool:
	return owner.hp_ratio() > hp_threshold


func modify_incoming_damage(owner: Battler, amount: float, damage_type: DamageEffect.DamageType) -> float:
	if is_active(owner) and damage_type != DamageEffect.DamageType.UNIVERSAL:
		return amount * damage_taken
	return amount


func after_damage_taken(ctx: BattleContext, owner: Battler, old_hp: int) -> void:
	var was_active := float(old_hp) / owner.max_hp() > hp_threshold
	if was_active and not is_active(owner) and owner.is_alive():
		ctx.view.refresh_battler(owner)
		await ctx.say(BattleText.fill(break_text, {"target": owner.label()}))


func has_shield(owner: Battler) -> bool:
	return is_active(owner)
