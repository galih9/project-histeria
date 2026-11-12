class_name RecruitAction
extends BattleAction
## Asks an enemy to join the party (GDD 02). Costs the turn, success or not.
## The exchange plays in the battle text, where the monster shows its personality.


func execute(ctx: BattleContext) -> void:
	var target := targets[0]
	if not target.is_alive():
		return
	var names := {"user": user.label(), "target": target.label()}

	await ctx.say(BattleText.fill(BattleText.RECRUIT_ASK, names))
	ctx.view.play_react(target)
	await ctx.say(BattleText.fill(BattleText.pick(target.data.negotiation_lines, ctx.rng), names))

	if not ctx.has_party_room():
		await ctx.say(BattleText.fill(BattleText.RECRUIT_NO_ROOM, names))
		return

	if ctx.rng.randf() < CombatMath.recruit_chance(user, target):
		await ctx.say(BattleText.fill(BattleText.pick(target.data.recruit_success_lines, ctx.rng), names))
		await ctx.recruit(target)
		await ctx.say(BattleText.fill(BattleText.RECRUIT_JOIN, names))
		ctx.dialogue.trigger(BattleDialogue.RECRUIT_SUCCESS, user)
	else:
		ctx.view.play_react(target)
		await ctx.say(BattleText.fill(BattleText.pick(target.data.recruit_fail_lines, ctx.rng), names))
		await ctx.say(BattleText.fill(BattleText.RECRUIT_REFUSE, names))
		ctx.dialogue.trigger(BattleDialogue.RECRUIT_FAIL, user)
