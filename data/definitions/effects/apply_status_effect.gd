class_name ApplyStatusEffect
extends EffectData
## Stamps a status with stacks. Reapplying extends it up to the status's max_stacks.
## Each target rolls its own chance (Sit Down, Q10). A chance of 0 keeps the
## effect as a hook for a later upgrade (Electro +: Paralyze chance).

@export var status: StatusData
@export_range(1, 10) var stacks := 3
@export_range(0.0, 1.0) var chance := 1.0
## When true, the status only lands if the previous damage effect hit.
@export var requires_hit := false


func apply(ctx: BattleContext, user: Battler, target: Battler) -> void:
	if not target.is_alive():
		return
	if requires_hit and not ctx.last_hit_landed:
		return
	if chance <= 0.0 or ctx.rng.randf() > chance:
		return
	if await ctx.apply_status(user, target, status, stacks, true, ctx.quiet_status_text):
		ctx.last_status_landed = true
