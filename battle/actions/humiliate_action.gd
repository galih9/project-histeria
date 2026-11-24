class_name HumiliateAction
extends BattleAction
## Humiliate sub action (GDD 06): a free taunt that lowers one random stat of
## the enemy who missed. Costs no turn.

var offer: SubActionOffer


func _init(acting: Battler, open_offer: SubActionOffer) -> void:
	super(acting, [open_offer.target])
	offer = open_offer


func costs_turn() -> bool:
	return false


func execute(ctx: BattleContext) -> void:
	var target := offer.target
	var config := offer.data
	if not target.is_alive() or config.debuff_pool.is_empty():
		return
	var names := {"user": user.label(), "target": target.label()}
	var taunt := BattleText.pick(user.data.humiliate_lines, ctx.rng, config.fallback_text)
	await ctx.say(BattleText.fill(taunt, names))
	ctx.view.play_react(target)
	await ctx.say(BattleText.fill(config.react_text, names))
	var status := config.debuff_pool[ctx.rng.randi_range(0, config.debuff_pool.size() - 1)]
	await ctx.apply_status(user, target, status, config.stacks)
	ctx.dialogue.trigger(BattleDialogue.HUMILIATE, user)
