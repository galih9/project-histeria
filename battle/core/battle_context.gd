class_name BattleContext
extends RefCounted
## The shared battle API. Actions, effects and traits call these methods, and
## this class keeps the rules, the battle text and the visuals in step.
## Every method that shows text is a coroutine: call it with await.

signal attack_resolved(user: Battler, target: Battler, result: HitResult)
signal status_inflicted(user: Battler, target: Battler, status: StatusData)
signal battler_knocked_out(battler: Battler)

var battlers: Array[Battler] = []
var rng := RandomNumberGenerator.new()
var view: BattleView
var dialogue: BattleDialogue
var encounter: EncounterData
var inventory: Inventory
var party_limit := 4
var current_actor: Battler
## The weapon, skill or item being used right now (Overheal needs to know).
var current_ability: ActionData
## Set by DamageEffect so a follow-up ApplyStatusEffect can require a hit.
var last_hit_landed := true
## Set by ApplyStatusEffect when its status landed on the current target.
var last_status_landed := false
## True while a skill with its own outcome line runs (Sit Down): status apply
## lines stay quiet and the outcome line speaks for them.
var quiet_status_text := false
## Set by RunAction.
var escaped := false
## Enemies that joined the party during this battle.
var recruited: Array[Battler] = []
## Enemies that left the battle during the recruit talk.
var left_battle: Array[Battler] = []
## Coins critters handed over during the recruit talk, added after the battle.
var coins_gained := 0
## The party answers recruit questions on its own (auto battle, sims).
var auto_play := false
## Tests can pick recruit answers: func(question: Dictionary, keys: Array[String]) -> String.
var answer_picker := Callable()

var _status_counter := 0
var _knocked_out: Dictionary = {} # Battler -> true, so each KO is announced once


# --- Queries -----------------------------------------------------------------

func is_boss_battle() -> bool:
	return encounter != null and encounter.is_boss


func side_members(side: int, alive_only := true) -> Array[Battler]:
	var result: Array[Battler] = []
	for battler in battlers:
		if battler.side == side and (battler.is_alive() or not alive_only):
			result.append(battler)
	return result


func party(alive_only := true) -> Array[Battler]:
	return side_members(Battler.Side.PARTY, alive_only)


func enemies(alive_only := true) -> Array[Battler]:
	return side_members(Battler.Side.ENEMY, alive_only)


func allies_of(battler: Battler, alive_only := true) -> Array[Battler]:
	return side_members(battler.side, alive_only)


func opponents_of(battler: Battler, alive_only := true) -> Array[Battler]:
	var other := Battler.Side.ENEMY if battler.side == Battler.Side.PARTY else Battler.Side.PARTY
	return side_members(other, alive_only)


func has_party_room() -> bool:
	return party(false).size() < party_limit


func recruitable_enemies() -> Array[Battler]:
	if is_boss_battle():
		return []
	return enemies().filter(func(b: Battler) -> bool: return b.data.recruitable)


## The battlers an action can be aimed at, before the player or AI picks.
## A taunted battler's single-target attacks and skills must hit the taunter (GDD 05).
func candidates_for(user: Battler, action: ActionData) -> Array[Battler]:
	match action.target:
		ActionData.Target.SELF:
			return [user]
		ActionData.Target.SINGLE_ALLY, ActionData.Target.ALL_ALLIES:
			return allies_of(user)
		ActionData.Target.SINGLE_ENEMY:
			var taunter := user.taunter()
			if taunter:
				return [taunter]
	return opponents_of(user)


# --- Text --------------------------------------------------------------------

func say(text: String) -> void:
	if text.is_empty():
		return
	await view.say(text)


# --- Rules -------------------------------------------------------------------

func resolve_damage(user: Battler, target: Battler, effect: DamageEffect) -> HitResult:
	var result := CombatMath.resolve(rng, user, target, effect)
	last_hit_landed = result.hit
	var names := {"user": user.label(), "target": target.label(), "amount": result.damage}

	await view.play_attack(user, target, result, effect)
	if result.lucky_strike:
		await say(BattleText.fill(BattleText.line("LUCKY_STRIKE"), names))
	if not result.hit:
		await say(BattleText.fill(BattleText.line("LUCKY_DODGE") if result.lucky_dodge else BattleText.line("MISS"), names))
		attack_resolved.emit(user, target, result)
		return result

	var old_hp := target.hp
	var absorbed := target.take_damage(result.damage)
	if result.lucky_crit:
		await say(BattleText.line("LUCKY_CRIT"))
	if result.crit:
		await say(BattleText.line("CRIT"))
	if result.crit_blocked:
		await say(BattleText.fill(BattleText.line("CRIT_BLOCKED"), names))
	if result.lucky_guard:
		await say(BattleText.fill(BattleText.line("LUCKY_GUARD"), names))
	await _say_shield_hit(target, absorbed)
	if result.damage > absorbed:
		names.amount = result.damage - absorbed
		await say(BattleText.fill(BattleText.line("DAMAGE"), names))
	for battle_trait in target.data.traits:
		await battle_trait.after_damage_taken(self, target, old_hp)
	attack_resolved.emit(user, target, result)
	return result


## Shield text after a hit: how much it absorbed, and whether it broke.
func _say_shield_hit(target: Battler, absorbed: int) -> void:
	if absorbed <= 0:
		return
	var shield_status := _shield_status()
	var names := {"target": target.label(), "amount": absorbed, "status": shield_status.display_name}
	await say(BattleText.fill(shield_status.trigger_text, names))
	if target.shield <= 0:
		await say(BattleText.fill(shield_status.expire_text, names))
	target.statuses_changed.emit()


## Text and color for the Shield pool. Loaded at runtime, so the text from
## game_text.json is the patched one.
static func _shield_status() -> StatusData:
	return load("res://data/statuses/shield.tres")


## Adds to the target's Shield pool (Overheal: uncapped, no stacks, whole battle).
func add_shield(target: Battler, amount: int) -> void:
	if amount <= 0 or not target.is_alive():
		return
	target.set_shield(target.shield + amount)
	target.statuses_changed.emit()
	var shield_status := _shield_status()
	view.play_status(target, shield_status)
	await say(BattleText.fill(shield_status.apply_text, {"target": target.label(), "amount": amount, "status": shield_status.display_name}))


## Stamps a status, or extends it up to its max stacks (GDD 05).
## Debuffs get the source's Yawn bonuses; Stun follows diminishing returns.
## quiet = skip the apply line (Sit Down shows its own outcome line).
## Returns true when the status landed.
func apply_status(source: Battler, target: Battler, status: StatusData, stacks: int,
		trigger_traits := true, quiet := false) -> bool:
	if status == null or not target.is_alive():
		return false
	var names := {"target": target.label(), "status": status.display_name}
	var strength := 1.0
	if status.is_debuff and source and source.side != target.side:
		strength += source.data.debuff_strength_bonus
		stacks += source.data.debuff_extra_stacks

	if status.kind == StatusData.Kind.STUN:
		stacks -= target.stun_chain
		if stacks <= 0:
			view.play_status(target, status)
			await say(BattleText.fill(status.resisted_text, names))
			return false
		target.stun_chain += 1
		target.stun_free_turns = 0

	var existing := target.find_status(status)
	if existing:
		if existing.stacks >= status.max_stacks:
			if not quiet:
				await say(BattleText.fill(BattleText.line("STATUS_MAXED"), names))
			return false
		existing.stacks = mini(existing.stacks + stacks, status.max_stacks)
		existing.strength = maxf(existing.strength, strength)
		if status.kind == StatusData.Kind.TAUNT:
			existing.source = source # the newest taunter pulls the hits
		target.statuses_changed.emit()
	else:
		_status_counter += 1
		var active := ActiveStatus.new(status, mini(stacks, status.max_stacks), _status_counter, source)
		active.strength = strength
		target.add_status(active)

	view.play_status(target, status)
	if not quiet:
		await say(BattleText.fill(status.apply_text, names))
	status_inflicted.emit(source, target, status)
	if trigger_traits and source:
		for battle_trait in source.data.traits:
			await battle_trait.after_status_inflicted(self, source, target, status)
	return true


## Heals HP. With Overheal on the healer (Ale), healing past max HP from her
## skills becomes Shield.
func heal(target: Battler, amount: int, revive := false, healer: Battler = null) -> void:
	var names := {"target": target.label(), "amount": 0}
	if not target.is_alive() and not revive:
		await say(BattleText.line("HEAL_NOTHING"))
		return
	var was_down := not target.is_alive()
	var old_hp := target.hp
	target.set_hp(target.hp + amount)
	if was_down:
		_knocked_out.erase(target)
	var healed: int = target.hp - old_hp
	names.amount = healed
	var overflow: int = amount - healed
	var shields: bool = overflow > 0 and _has_overheal(healer)
	if healed > 0 or not shields:
		view.play_heal(target, healed)
		await say(BattleText.fill(BattleText.line("REVIVE") if was_down else BattleText.line("HEAL"), names))
	if shields:
		await add_shield(target, overflow)


func _has_overheal(healer: Battler) -> bool:
	if healer == null or not current_ability is SkillData:
		return false
	for battle_trait in healer.data.traits:
		if battle_trait.turns_overheal_into_shield():
			return true
	return false


func restore_mp(target: Battler, amount: int) -> void:
	if not target.is_alive():
		await say(BattleText.line("HEAL_NOTHING"))
		return
	var old_mp := target.mp
	target.set_mp(target.mp + amount)
	view.play_mp(target, target.mp - old_mp)
	await say(BattleText.fill(BattleText.line("MP_RESTORE"), {"target": target.label(), "amount": target.mp - old_mp}))


func cleanse(target: Battler) -> void:
	var removed := false
	for active in target.statuses.duplicate():
		if active.data.is_debuff:
			target.remove_status(active)
			removed = true
	if removed:
		view.play_heal(target, 0)
	await say(BattleText.fill(BattleText.line("CLEANSE") if removed else BattleText.line("CLEANSE_NOTHING"), {"target": target.label()}))


## Moves an enemy over to the party side mid-battle (GDD 02, recruiting).
func recruit(target: Battler) -> void:
	target.side = Battler.Side.PARTY
	target.clear_statuses()
	target.sp = 0.0
	recruited.append(target)
	await view.move_to_party(target)


## Takes an enemy out of the battle without defeating it (recruit talk, "leaves").
func send_away(target: Battler) -> void:
	target.clear_statuses()
	battlers.erase(target)
	left_battle.append(target)
	await view.remove_enemy(target)


# --- Turn steps --------------------------------------------------------------

## Control check (GDD 05, step 2): Stun or a Paralyze roll takes the turn away.
## Returns true when the actor loses this turn. The lost turn still counts as
## the actor's own turn for their timed effects (Q21).
func control_check(actor: Battler) -> bool:
	var stun := actor.find_kind(StatusData.Kind.STUN)
	if stun:
		view.play_status(actor, stun.data)
		await say(BattleText.fill(stun.data.trigger_text, {"target": actor.label(), "status": stun.data.display_name}))
		return true
	actor.stun_free_turns += 1
	if actor.stun_free_turns >= BattleRules.STUN_CHAIN_RESET_TURNS:
		actor.stun_chain = 0
	var paralyze := actor.find_kind(StatusData.Kind.PARALYZE)
	if paralyze and rng.randf() < BattleRules.PARALYZE_LOSE_TURN_CHANCE:
		view.play_status(actor, paralyze.data)
		await say(BattleText.fill(paralyze.data.trigger_text, {"target": actor.label(), "status": paralyze.data.display_name}))
		return true
	return false


## Post-action step (GDD 05, countdown decided Nov 19): damage over time
## triggers and loses a stack at the end of every turn; the actor's own timed
## effects (buffs, debuffs, Taunt, Stun, Paralyze) lose a stack. Order: highest
## stacks first, then the one applied first.
func post_action_step(actor: Battler) -> void:
	var entries: Array = []
	for battler in battlers:
		if battler.is_alive():
			for active in battler.statuses:
				if active.data.counts_every_turn() or battler == actor:
					entries.append([battler, active])
	entries.sort_custom(func(a: Array, b: Array) -> bool:
		var sa: ActiveStatus = a[1]
		var sb: ActiveStatus = b[1]
		if sa.stacks != sb.stacks:
			return sa.stacks > sb.stacks
		return sa.applied_order < sb.applied_order)

	for entry in entries:
		var battler: Battler = entry[0]
		var active: ActiveStatus = entry[1]
		if not battler.is_alive() or not battler.statuses.has(active):
			continue
		var names := {"target": battler.label(), "status": active.data.display_name, "amount": active.data.damage_per_trigger}
		if active.data.kind == StatusData.Kind.DAMAGE_OVER_TIME:
			var old_hp := battler.hp
			var absorbed := battler.take_damage(active.data.damage_per_trigger)
			view.play_status_tick(battler, active.data, active.data.damage_per_trigger)
			await _say_shield_hit(battler, absorbed)
			if active.data.damage_per_trigger > absorbed:
				names.amount = active.data.damage_per_trigger - absorbed
				await say(BattleText.fill(active.data.trigger_text, names))
			for battle_trait in battler.data.traits:
				await battle_trait.after_damage_taken(self, battler, old_hp)
		active.stacks -= 1
		if active.stacks <= 0:
			battler.remove_status(active)
			if battler.is_alive():
				await say(BattleText.fill(active.data.expire_text, names))
		else:
			battler.statuses_changed.emit()
		await resolve_knockouts()


## Announces every battler that dropped to 0 HP since the last check.
func resolve_knockouts() -> void:
	for battler in battlers:
		if battler.is_alive() or _knocked_out.has(battler):
			continue
		_knocked_out[battler] = true
		battler.clear_statuses()
		battler.set_shield(0)
		battler.is_defending = false
		var template := BattleText.line("DEFEATED_ENEMY") if battler.side == Battler.Side.ENEMY else BattleText.line("DEFEATED_PARTY")
		await view.play_defeat(battler)
		await say(BattleText.fill(template, {"target": battler.label()}))
		battler_knocked_out.emit(battler)
