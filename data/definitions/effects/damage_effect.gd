class_name DamageEffect
extends EffectData
## Deals damage of one type (GDD 04: Physical, Magical, Universal).

enum DamageType {
	PHYSICAL, ## reduced by Defense
	MAGICAL, ## reduced by Resistance
	UNIVERSAL, ## ignores both
}

## Which hit effect plays on the target. Flavor only, the math stays the same.
enum HitFx { BLUNT, SLASH, MAGIC, POISON }

@export var damage_type := DamageType.PHYSICAL
## Damage before defenses = Attack x power / 10.
@export var power := 10.0
@export_range(1, 8) var hits := 1
@export var accuracy_bonus := 0.0
@export var crit_bonus := 0.0
@export var hit_fx := HitFx.BLUNT


func apply(ctx: BattleContext, user: Battler, target: Battler) -> void:
	for i in hits:
		if not target.is_alive():
			return
		await ctx.resolve_damage(user, target, self)
