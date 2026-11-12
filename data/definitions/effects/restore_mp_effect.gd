class_name RestoreMpEffect
extends EffectData
## Restores MP.

@export var amount := 10


func apply(ctx: BattleContext, _user: Battler, target: Battler) -> void:
	await ctx.restore_mp(target, amount)
