extends BattleController
## Test-only controller: plays the party with a policy that loves sub actions
## and recruiting, so those paths get exercised.

var log_lines: Array[String] = []

func _player_action(actor: Battler) -> BattleAction:
	ctx.auto_play = true # recruit answers are picked at random
	if not actor.sub_action_offers.is_empty():
		var offer := actor.sub_action_offers[0]
		actor.sub_action_offers.clear()
		var sub := HumiliateAction.new(actor, offer)
		await sub.execute(ctx)
		log_lines.append("[test] used Humiliate")
	var recruitable := ctx.recruitable_enemies()
	if ctx.has_party_room() and not recruitable.is_empty() and ctx.rng.randf() < 0.6:
		recruitable.sort_custom(func(a: Battler, b: Battler) -> bool: return a.hp_ratio() < b.hp_ratio())
		return RecruitAction.new(actor, [recruitable[0]])
	return _ai.choose(ctx, actor)
