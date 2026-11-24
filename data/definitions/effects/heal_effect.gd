class_name HealEffect
extends EffectData
## Restores HP. Healing a downed character only works with revive switched on.

@export var amount := 30
## Adds a share of the user's Attack, so Ale's heals grow with her buffs.
@export var attack_scaling := 0.0
@export var revive := false


func apply(ctx: BattleContext, user: Battler, target: Battler) -> void:
	var total := amount + roundi(user.get_stat(StatBlock.ATTACK) * attack_scaling)
	await ctx.heal(target, total, revive, user)
