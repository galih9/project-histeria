class_name CombatMath
extends RefCounted
## Pure combat math (GDD 04): hit roll, Luck flips, critical hits, damage.
## No visuals and no text here, so the rules stay easy to test and tune.


## Order: hit roll -> Lucky Strike / Lucky Dodge -> crit roll -> Lucky Crit ->
## damage -> traits -> Lucky Guard. Each Luck check rolls once per attack.
static func resolve(rng: RandomNumberGenerator, user: Battler, target: Battler, effect: DamageEffect) -> HitResult:
	var result := HitResult.new()

	result.hit = rng.randf() < hit_chance(user, target, effect)
	if not result.hit and roll_luck(rng, user):
		result.hit = true
		result.lucky_strike = true
	elif result.hit and roll_luck(rng, target):
		result.hit = false
		result.lucky_dodge = true
	if not result.hit:
		return result

	var crit_chance := (user.get_stat(StatBlock.CRIT_CHANCE) + effect.crit_bonus) / 100.0
	if target.is_defending:
		result.crit_blocked = rng.randf() < crit_chance
	else:
		result.crit = rng.randf() < crit_chance
		if not result.crit and roll_luck(rng, user):
			result.crit = true
			result.lucky_crit = true

	var amount := raw_damage(user, effect) * defense_factor(target, effect.damage_type)
	amount *= rng.randf_range(1.0 - BattleRules.DAMAGE_VARIANCE, 1.0 + BattleRules.DAMAGE_VARIANCE)
	if result.crit:
		amount *= BattleRules.CRIT_MULTIPLIER
	for battle_trait in target.data.traits:
		amount = battle_trait.modify_incoming_damage(target, amount, effect.damage_type)
	if roll_luck(rng, target):
		amount *= 0.5
		result.lucky_guard = true

	result.damage = maxi(roundi(amount), 1)
	return result


static func hit_chance(user: Battler, target: Battler, effect: DamageEffect) -> float:
	var chance := (user.get_stat(StatBlock.ACCURACY) + effect.accuracy_bonus - target.get_stat(StatBlock.EVASION)) / 100.0
	return clampf(chance, BattleRules.MIN_HIT_CHANCE, BattleRules.MAX_HIT_CHANCE)


static func raw_damage(user: Battler, effect: DamageEffect) -> float:
	return user.get_stat(StatBlock.ATTACK) * effect.power / BattleRules.POWER_DIVISOR


## Share of damage that gets through the target's matching defense.
static func defense_factor(target: Battler, damage_type: DamageEffect.DamageType) -> float:
	var defense := 0.0
	match damage_type:
		DamageEffect.DamageType.PHYSICAL:
			defense = target.get_stat(StatBlock.DEFENSE)
		DamageEffect.DamageType.MAGICAL:
			defense = target.get_stat(StatBlock.RESISTANCE)
		DamageEffect.DamageType.UNIVERSAL:
			return 1.0
	var factor := BattleRules.DEFENSE_SCALE / (BattleRules.DEFENSE_SCALE + defense)
	if target.is_defending and BattleRules.DEFEND_EXTRA_CURVE:
		factor *= factor
	return factor


static func roll_luck(rng: RandomNumberGenerator, battler: Battler) -> bool:
	return rng.randf() < BattleRules.lucky_chance(battler.get_stat(StatBlock.LUCK))


## Recruit talk (GDD 18): the chance that the recruiter's Luck turns a hostile
## reaction ("attack", "leave") into "ask another question". Luck must reach the
## threshold first, then each answer rolls; every mood stack on the critter
## lowers the chance.
static func talk_soften_chance(recruiter: Battler, critter: Battler) -> float:
	var luck := recruiter.get_stat(StatBlock.LUCK)
	if luck < BattleRules.TALK_SOFTEN_LUCK_THRESHOLD:
		return 0.0
	var chance := minf(luck * BattleRules.TALK_SOFTEN_PER_LUCK, BattleRules.TALK_SOFTEN_MAX_CHANCE)
	return maxf(chance - critter.mood * BattleRules.TALK_SOFTEN_MOOD_PENALTY, 0.0)


static func run_chance(runner: Battler, enemies: Array[Battler]) -> float:
	var fastest := 0.0
	for enemy in enemies:
		fastest = maxf(fastest, enemy.get_stat(StatBlock.SPEED))
	var bonus := (runner.get_stat(StatBlock.SPEED) - fastest) * BattleRules.RUN_SPEED_FACTOR
	return clampf(BattleRules.RUN_BASE_CHANCE + bonus, 0.1, 0.95)
