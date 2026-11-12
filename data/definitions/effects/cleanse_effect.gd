class_name CleanseEffect
extends EffectData
## Removes every debuff from the target (the Machinist's cleanse, GDD 02).


func apply(ctx: BattleContext, _user: Battler, target: Battler) -> void:
	await ctx.cleanse(target)
