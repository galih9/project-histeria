class_name BattleController
extends Control
## Runs one battle from start to finish (GDD 05, "Order of one turn"):
##   0. battle start: intro text and pre-action effects (first strike)
##   1. the next actor reaches SP 1, their window rises
##   2. optional sub action (free)
##   3. action
##   4. post-action step: statuses trigger and lose a stack
## Emits `finished` with a BattleResult. Rules live in BattleContext and friends.

signal finished(result: BattleResult)

const HUMILIATE := preload("res://data/sub_actions/humiliate.tres")
const SUFFIXES := ["A", "B", "C", "D"]

## Dev switch: the AI plays the party too. Handy for balance checks.
@export var auto_battle := false

@onready var view: BattleView = %View

var ctx: BattleContext
var _queue := TurnQueue.new()
var _ai := BattleAi.new()


## Call right after adding the scene to the tree.
func start(encounter: EncounterData, party: Array[PartyMember], inventory: Inventory,
		advantage: EncounterData.Advantage, party_limit := 4) -> void:
	ctx = BattleContext.new()
	ctx.rng.randomize()
	ctx.encounter = encounter
	ctx.inventory = inventory
	ctx.party_limit = party_limit
	ctx.view = view
	for member in party:
		ctx.battlers.append(Battler.from_party_member(member))
	_spawn_enemies(encounter)
	ctx.dialogue = BattleDialogue.new(ctx)
	ctx.attack_resolved.connect(_on_attack_resolved)
	ctx.battler_knocked_out.connect(_on_knocked_out)
	view.setup(ctx)
	_run(advantage)


func _run(advantage: EncounterData.Advantage) -> void:
	await get_tree().process_frame # let the layout settle before the first line
	await _battle_start(advantage)
	var outcome := -1
	while outcome < 0:
		var actor := _queue.next_actor(ctx.battlers)
		await _take_turn(actor)
		outcome = _check_outcome()
		if outcome < 0:
			await ctx.post_action_step()
			outcome = _check_outcome()
		ctx.dialogue.on_turn_passed()
	finished.emit(await _finish(outcome as BattleResult.Outcome))


func _spawn_enemies(encounter: EncounterData) -> void:
	var counts: Dictionary = {}
	for data in encounter.enemies:
		counts[data] = counts.get(data, 0) + 1
	var seen: Dictionary = {}
	for data in encounter.enemies:
		var battler := Battler.new(data, Battler.Side.ENEMY)
		if counts[data] > 1:
			battler.name_suffix = " " + SUFFIXES[seen.get(data, 0) % SUFFIXES.size()]
			seen[data] = seen.get(data, 0) + 1
		ctx.battlers.append(battler)


# --- Step 0: battle start ----------------------------------------------------

func _battle_start(advantage: EncounterData.Advantage) -> void:
	var foes := ctx.enemies()
	var leader := foes[0].label()
	var template := BattleText.BATTLE_START_MANY if foes.size() > 1 else BattleText.BATTLE_START
	if ctx.is_boss_battle():
		template = BattleText.BOSS_START
	if not ctx.encounter.intro_text.is_empty():
		template = ctx.encounter.intro_text
	await ctx.say(BattleText.fill(template, {"target": leader}))

	# Pre-action effects run once, before the first turn.
	for battler in ctx.battlers:
		battler.sp = ctx.rng.randf() * BattleRules.START_SP_MAX
	match advantage:
		EncounterData.Advantage.PARTY:
			_queue.first_strike_side = Battler.Side.PARTY
			_boost_side(Battler.Side.PARTY)
			await ctx.say(BattleText.FIRST_STRIKE_PARTY)
		EncounterData.Advantage.ENEMY:
			_queue.first_strike_side = Battler.Side.ENEMY
			_boost_side(Battler.Side.ENEMY)
			await ctx.say(BattleText.FIRST_STRIKE_ENEMY)
	ctx.dialogue.trigger_any(BattleDialogue.BOSS_START if ctx.is_boss_battle() else BattleDialogue.BATTLE_START)


func _boost_side(side: int) -> void:
	for battler in ctx.side_members(side):
		battler.sp = minf(battler.sp + BattleRules.FIRST_STRIKE_SP, 0.99)


# --- Steps 1 to 3: one turn ---------------------------------------------------

func _take_turn(actor: Battler) -> void:
	ctx.current_actor = actor
	actor.is_defending = false # Defend lasts until the character's next turn
	_open_sub_actions(actor)
	view.set_active(actor)
	view.clear_text()
	ctx.dialogue.trigger(BattleDialogue.TURN_START, actor)

	var action: BattleAction
	if actor.is_player_controlled() and not auto_battle:
		action = await _player_action(actor)
	else:
		action = _ai.choose(ctx, actor)
	await action.execute(ctx)
	await ctx.resolve_knockouts()

	actor.sub_action_offers.clear()
	view.set_active(null)
	ctx.current_actor = null


## Lets the player use one free sub action, then pick the real action.
func _player_action(actor: Battler) -> BattleAction:
	while true:
		var action := await view.command_menu.choose(ctx, actor)
		view.dismiss_dialogue() # a new action closes the line on screen
		if action.costs_turn():
			return action
		actor.sub_action_offers.clear() # at most one sub action per turn
		await action.execute(ctx)
	return null


## Opportunities earned since the last turn become menu entries for this turn only.
func _open_sub_actions(actor: Battler) -> void:
	actor.sub_action_offers.clear()
	for offer in actor.pending_sub_action_offers:
		if offer.target.is_alive() and offer.target.side != actor.side and (offer.data.boss_safe or not ctx.is_boss_battle()):
			actor.sub_action_offers.append(offer)
	actor.pending_sub_action_offers.clear()
	if actor.sub_action_offers.size() > 1:
		actor.sub_action_offers.resize(1)


# --- Outcome -----------------------------------------------------------------

func _check_outcome() -> int:
	if ctx.escaped:
		return BattleResult.Outcome.ESCAPED
	if ctx.party().is_empty():
		return BattleResult.Outcome.DEFEAT
	if ctx.enemies().is_empty():
		return BattleResult.Outcome.VICTORY
	return -1


func _finish(outcome: BattleResult.Outcome) -> BattleResult:
	view.set_active(null)
	view.dismiss_dialogue()
	var result := BattleResult.new()
	result.outcome = outcome
	result.party = ctx.party(false)
	result.recruited = ctx.recruited

	match outcome:
		BattleResult.Outcome.VICTORY:
			await ctx.say(BattleText.VICTORY)
			result.drives = DropRoller.roll(ctx.rng, ctx.encounter, _party_luck())
			for drive in result.drives:
				await ctx.say(BattleText.fill(BattleText.DROP, {"item": drive.display_name()}))
		BattleResult.Outcome.DEFEAT:
			await ctx.say(BattleText.DEFEAT)

	for battler in result.party:
		battler.write_back()
	await get_tree().create_timer(0.4).timeout
	return result


func _party_luck() -> float:
	var total := 0.0
	for battler in ctx.party(false):
		total += battler.get_stat(StatBlock.LUCK)
	return total


# --- Event hooks -------------------------------------------------------------

func _on_attack_resolved(user: Battler, target: Battler, result: HitResult) -> void:
	# Humiliate opportunity (GDD 06): an enemy's attack on a party member missed.
	if user.side == Battler.Side.ENEMY and target.side == Battler.Side.PARTY and not result.hit:
		if HUMILIATE.boss_safe or not ctx.is_boss_battle():
			if ctx.rng.randf() < HUMILIATE.availability_chance(target.get_stat(StatBlock.LUCK)):
				target.pending_sub_action_offers.append(SubActionOffer.new(HUMILIATE, user))

	# Raider lines.
	if user.side == Battler.Side.PARTY:
		if result.crit:
			ctx.dialogue.trigger(BattleDialogue.CRIT, user)
		elif not result.hit:
			ctx.dialogue.trigger(BattleDialogue.MISS, user)
	if result.any_lucky():
		var lucky_one := target if (result.lucky_dodge or result.lucky_guard) else user
		ctx.dialogue.trigger(BattleDialogue.LUCKY, lucky_one)
	if target.side == Battler.Side.PARTY and result.hit and target.is_alive() and target.hp_ratio() < 0.3:
		ctx.dialogue.trigger_any(BattleDialogue.ALLY_LOW_HP, target)


func _on_knocked_out(battler: Battler) -> void:
	if battler.side == Battler.Side.PARTY:
		ctx.dialogue.trigger_any(BattleDialogue.ALLY_KO, battler)
	else:
		ctx.dialogue.trigger_any(BattleDialogue.ENEMY_DEFEATED)
