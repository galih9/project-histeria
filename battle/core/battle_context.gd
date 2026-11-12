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
## Set by DamageEffect so a follow-up ApplyStatusEffect can require a hit.
var last_hit_landed := true
## Set by RunAction.
var escaped := false
## Enemies that joined the party during this battle.
var recruited: Array[Battler] = []

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
func candidates_for(user: Battler, action: ActionData) -> Array[Battler]:
	match action.target:
		ActionData.Target.SELF:
			return [user]
		ActionData.Target.SINGLE_ALLY, ActionData.Target.ALL_ALLIES:
			return allies_of(user)
		_:
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
		await say(BattleText.fill(BattleText.LUCKY_STRIKE, names))
	if not result.hit:
		await say(BattleText.fill(BattleText.LUCKY_DODGE if result.lucky_dodge else BattleText.MISS, names))
		attack_resolved.emit(user, target, result)
		return result

	var old_hp := target.hp
	target.set_hp(target.hp - result.damage)
	if result.lucky_crit:
		await say(BattleText.LUCKY_CRIT)
	if result.crit:
		await say(BattleText.CRIT)
	if result.crit_blocked:
		await say(BattleText.fill(BattleText.CRIT_BLOCKED, names))
	if result.lucky_guard:
		await say(BattleText.fill(BattleText.LUCKY_GUARD, names))
	await say(BattleText.fill(BattleText.DAMAGE, names))
	for battle_trait in target.data.traits:
		await battle_trait.after_damage_taken(self, target, old_hp)
	attack_resolved.emit(user, target, result)
	return result


## Stamps a status, or extends it up to its max stacks (GDD 05).
func apply_status(source: Battler, target: Battler, status: StatusData, stacks: int, trigger_traits := true) -> void:
	if status == null or not target.is_alive():
		return
	var names := {"target": target.label(), "status": status.display_name}
	var existing := target.find_status(status)
	if existing:
		if existing.stacks >= status.max_stacks:
			await say(BattleText.fill(BattleText.STATUS_MAXED, names))
			return
		existing.stacks = mini(existing.stacks + stacks, status.max_stacks)
		target.statuses_changed.emit()
	else:
		_status_counter += 1
		target.add_status(ActiveStatus.new(status, mini(stacks, status.max_stacks), _status_counter, source))

	view.play_status(target, status)
	await say(BattleText.fill(status.apply_text, names))
	status_inflicted.emit(source, target, status)
	if trigger_traits and source:
		for battle_trait in source.data.traits:
			await battle_trait.after_status_inflicted(self, source, target, status)


func heal(target: Battler, amount: int, revive := false) -> void:
	var names := {"target": target.label(), "amount": 0}
	if not target.is_alive() and not revive:
		await say(BattleText.HEAL_NOTHING)
		return
	var was_down := not target.is_alive()
	var old_hp := target.hp
	target.set_hp(target.hp + amount)
	if was_down:
		_knocked_out.erase(target)
	names.amount = target.hp - old_hp
	view.play_heal(target, names.amount)
	await say(BattleText.fill(BattleText.REVIVE if was_down else BattleText.HEAL, names))


func restore_mp(target: Battler, amount: int) -> void:
	if not target.is_alive():
		await say(BattleText.HEAL_NOTHING)
		return
	var old_mp := target.mp
	target.set_mp(target.mp + amount)
	view.play_mp(target, target.mp - old_mp)
	await say(BattleText.fill(BattleText.MP_RESTORE, {"target": target.label(), "amount": target.mp - old_mp}))


func cleanse(target: Battler) -> void:
	var removed := false
	for active in target.statuses.duplicate():
		if active.data.is_debuff:
			target.remove_status(active)
			removed = true
	if removed:
		view.play_heal(target, 0)
	await say(BattleText.fill(BattleText.CLEANSE if removed else BattleText.CLEANSE_NOTHING, {"target": target.label()}))


## Moves an enemy over to the party side mid-battle (GDD 02, Monster Recruiting).
func recruit(target: Battler) -> void:
	target.side = Battler.Side.PARTY
	target.clear_statuses()
	target.sp = 0.0
	recruited.append(target)
	await view.move_to_party(target)


# --- Turn steps --------------------------------------------------------------

## Post-action step (GDD 05): every status triggers once, highest stacks first,
## then the one applied first. Each loses one stack right after it triggers.
func post_action_step() -> void:
	var entries: Array = []
	for battler in battlers:
		if battler.is_alive():
			for active in battler.statuses:
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
			battler.set_hp(battler.hp - active.data.damage_per_trigger)
			view.play_status_tick(battler, active.data, active.data.damage_per_trigger)
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
		battler.is_defending = false
		var template := BattleText.DEFEATED_ENEMY if battler.side == Battler.Side.ENEMY else BattleText.DEFEATED_PARTY
		await view.play_defeat(battler)
		await say(BattleText.fill(template, {"target": battler.label()}))
		battler_knocked_out.emit(battler)
