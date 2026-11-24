class_name BattleAi
extends RefCounted
## Simple, data-driven move picker for enemies (and for the party in auto battle).
## Each weapon and skill carries ai_weight and ai_hint, so tuning a monster's
## behavior happens in its .tres files.

const HURT_THRESHOLD := 0.6


func choose(ctx: BattleContext, actor: Battler) -> BattleAction:
	var options: Array[SkillData] = []
	var weights: Array[float] = []
	for skill in actor.data.weapons + actor.data.skills:
		if skill.ai_weight <= 0.0 or not actor.can_use(skill):
			continue
		if _pick_targets(ctx, actor, skill).is_empty():
			continue
		options.append(skill)
		weights.append(skill.ai_weight)

	if options.is_empty():
		return DefendAction.new(actor)
	var chosen := options[ctx.rng.rand_weighted(weights)]
	return AbilityAction.new(actor, chosen, _pick_targets(ctx, actor, chosen))


func _pick_targets(ctx: BattleContext, actor: Battler, skill: SkillData) -> Array[Battler]:
	var candidates := ctx.candidates_for(actor, skill)
	match skill.ai_hint:
		ActionData.AiHint.WHEN_ALLY_HURT:
			candidates = candidates.filter(func(b: Battler) -> bool: return b.hp_ratio() < HURT_THRESHOLD)
		ActionData.AiHint.WHEN_ALLY_DEBUFFED:
			candidates = candidates.filter(func(b: Battler) -> bool: return b.has_debuff())
		ActionData.AiHint.WHEN_TARGET_LACKS_STATUS:
			var status := skill.first_applied_status()
			candidates = candidates.filter(func(b: Battler) -> bool: return status == null or b.find_status(status) == null)

	var result: Array[Battler] = []
	if candidates.is_empty():
		return result
	if skill.targets_many() or skill.target == ActionData.Target.SELF:
		result.assign(candidates)
	elif skill.ai_hint == ActionData.AiHint.WHEN_ALLY_HURT:
		candidates.sort_custom(func(a: Battler, b: Battler) -> bool: return a.hp_ratio() < b.hp_ratio())
		result.append(candidates[0])
	else:
		result.append(candidates[ctx.rng.randi_range(0, candidates.size() - 1)])
	return result
