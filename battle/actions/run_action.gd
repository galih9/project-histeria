class_name RunAction
extends BattleAction
## Tries to escape (GDD 03 proposal). Faster runners get away more often.


func execute(ctx: BattleContext) -> void:
	if ctx.is_boss_battle():
		var leader := ctx.enemies()[0].label() if not ctx.enemies().is_empty() else "it"
		await ctx.say(BattleText.fill(BattleText.line("RUN_BOSS"), {"target": leader}))
		return
	await ctx.say(BattleText.fill(BattleText.line("RUN_TRY"), {"user": user.label()}))
	if ctx.rng.randf() < CombatMath.run_chance(user, ctx.enemies()):
		ctx.escaped = true
		await ctx.say(BattleText.line("RUN_SUCCESS"))
	else:
		await ctx.say(BattleText.line("RUN_FAIL"))
