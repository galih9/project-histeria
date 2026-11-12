class_name LaughBoostTrait
extends TraitData
## Laughing Mannequin trait (GDD 02): it gets a boost when it humiliates an
## opponent, which here means landing a debuff on one.

@export var boost: StatusData
@export_range(1, 10) var stacks := 2
@export var boost_text := "{user} laughs so hard it gets pumped up!"


func after_status_inflicted(ctx: BattleContext, owner: Battler, target: Battler, status: StatusData) -> void:
	if boost == null or not status.is_debuff or target.side == owner.side:
		return
	await ctx.say(BattleText.fill(boost_text, {"user": owner.label()}))
	await ctx.apply_status(owner, owner, boost, stacks, false)
