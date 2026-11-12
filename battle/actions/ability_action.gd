class_name AbilityAction
extends BattleAction
## Uses a weapon attack, a skill or an item: pays the cost, announces it,
## then runs every effect on every target in order.

var ability: ActionData


func _init(acting: Battler, used: ActionData, aimed_at: Array[Battler] = []) -> void:
	super(acting, aimed_at)
	ability = used


func execute(ctx: BattleContext) -> void:
	if not _pay_cost(ctx):
		await ctx.say(BattleText.fill(BattleText.NOT_ENOUGH_MP, {"user": user.label()}))
		return

	var live_targets := _live_targets(ctx)
	var first_target := live_targets[0].label() if not live_targets.is_empty() else ""
	await ctx.say(BattleText.fill(ability.use_text,{"user": user.label(), "action": ability.display_name, "target": first_target}))
	await ctx.view.play_user_action(user)

	for target in live_targets:
		ctx.last_hit_landed = true
		for effect in ability.effects:
			await effect.apply(ctx, user, target)


func _pay_cost(ctx: BattleContext) -> bool:
	if ability is SkillData:
		var skill := ability as SkillData
		if not user.can_pay(skill):
			return false
		user.set_mp(user.mp - skill.mp_cost)
	elif ability is ItemData and ctx.inventory:
		return ctx.inventory.consume(ability as ItemData)
	return true


## Single-target attacks on a fallen enemy move to another one, like EarthBound.
func _live_targets(ctx: BattleContext) -> Array[Battler]:
	var alive := targets.filter(func(b: Battler) -> bool: return b.is_alive())
	var result: Array[Battler] = []
	result.assign(alive)
	if result.is_empty() and not ability.targets_allies():
		var others := ctx.opponents_of(user)
		if not others.is_empty():
			result.append(others[ctx.rng.randi_range(0, others.size() - 1)])
	return result
