class_name DefendAction
extends BattleAction
## Defend (GDD 03): lasts until the character's next turn. Reduces damage based
## on Defense and Resistance, and blocks critical hits.


func execute(ctx: BattleContext) -> void:
	user.is_defending = true
	ctx.view.refresh_battler(user)
	await ctx.say(BattleText.fill(BattleText.DEFEND, {"user": user.label()}))
