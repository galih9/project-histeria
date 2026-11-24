class_name AbilityAction
extends BattleAction
## Uses a weapon attack, a skill or an item: pays the cost, announces it,
## then runs every effect on every target in order. Handles the signature
## weapon (Book Throw sends Ale's book away, Collect Book brings it back) and
## the outcome line of chance-based skills (Sit Down).

var ability: ActionData


func _init(acting: Battler, used: ActionData, aimed_at: Array[Battler] = []) -> void:
	super(acting, aimed_at)
	ability = used


func execute(ctx: BattleContext) -> void:
	if not user.is_unlocked(ability):
		return
	if not _pay_cost(ctx):
		await ctx.say(BattleText.fill(BattleText.line("NOT_ENOUGH_MP"), {"user": user.label()}))
		return

	var live_targets := _live_targets(ctx)
	var first_target := live_targets[0].label() if not live_targets.is_empty() else ""
	var names := {"user": user.label(), "action": ability.display_name, "target": first_target}
	ctx.current_ability = ability
	await ctx.say(BattleText.fill(ability.use_text, names))
	await ctx.view.play_user_action(user)

	var has_outcome := not (ability.outcome_success_lines.is_empty() and ability.outcome_fail_lines.is_empty())
	ctx.quiet_status_text = has_outcome
	var landed: Array[Battler] = []
	for target in live_targets:
		ctx.last_hit_landed = true
		ctx.last_status_landed = false
		for effect in ability.effects:
			await effect.apply(ctx, user, target)
		if ctx.last_status_landed:
			landed.append(target)
	ctx.quiet_status_text = false

	if ability.throws_weapon:
		user.weapon_away = true
	if ability.retrieves_weapon:
		user.weapon_away = false
	if has_outcome:
		await _say_outcome(ctx, landed)
	ctx.current_ability = null


## Sit Down style outcome: a success line naming the one target that reacted,
## a group line when several did, or a fail line when nobody did.
func _say_outcome(ctx: BattleContext, landed: Array[Battler]) -> void:
	var line := ""
	if landed.is_empty():
		line = BattleText.pick(ability.outcome_fail_lines, ctx.rng)
	else:
		var named := Array(ability.outcome_success_lines).filter(func(l: String) -> bool: return l.contains("{target}"))
		var group := Array(ability.outcome_success_lines).filter(func(l: String) -> bool: return not l.contains("{target}"))
		var pool: Array = named if landed.size() == 1 else group
		if pool.is_empty():
			pool = Array(ability.outcome_success_lines)
		line = BattleText.pick(PackedStringArray(pool), ctx.rng)
	var labels := landed.map(func(b: Battler) -> String: return b.label())
	await ctx.say(BattleText.fill(line, {"user": user.label(), "target": " and ".join(labels)}))


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
		var others := ctx.candidates_for(user, ability)
		if not others.is_empty():
			result.append(others[ctx.rng.randi_range(0, others.size() - 1)])
	return result
