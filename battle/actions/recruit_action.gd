class_name RecruitAction
extends BattleAction
## The recruit talk (GDD 18, modeled on the demon negotiation of Shin Megami
## Tensei 4). Costs the turn.
##   1. The critter asks a random question from the bank (game_text.json).
##   2. The player picks an answer.
##   3. The critter's race reacts with a line and an outcome.
##   4. "ask_again" loops back to 1; any other outcome ends the talk.
##   5. A talk holds at most BattleRules.TALK_MAX_QUESTIONS questions; when the
##      last one ends on "ask_again", the critter leaves.
## Mood: every hostile reaction (and every Luck save) adds a mood stack to the
## critter. Enough stacks and it stops responding for the rest of the battle.
## Luck: a high Luck can turn "attack" or "leave" into "ask_again".
## Mood and asked questions live on the Battler, so they reset after the battle.

## Placeholder gift pool for the "give_item" outcome, until critters get their own.
const GIFT_ITEMS: Array[ItemData] = [
	preload("res://data/items/cookie.tres"),
	preload("res://data/items/fizzy_pop.tres"),
	preload("res://data/items/mystery_sandwich.tres"),
]

var _ai := BattleAi.new()


## The narration key that keeps the talk from opening with this critter, or ""
## when the talk can open. The menu checks it first, so a blocked talk costs no turn.
static func blocker(critter: Battler) -> String:
	if not GameState.can_understand(critter.data):
		return "RECRUIT_LANGUAGE_LOCKED"
	if RecruitBank.questions_for(critter.data.races).is_empty():
		return "RECRUIT_NO_WORDS"
	return ""


func execute(ctx: BattleContext) -> void:
	var critter := targets[0]
	if not critter.is_alive() or not ctx.battlers.has(critter) or critter.side == user.side:
		return
	var names := {"user": user.label(), "target": critter.label()}

	await ctx.say(BattleText.fill(BattleText.line("RECRUIT_ASK"), names))
	ctx.view.play_react(critter)
	var blocked := blocker(critter)
	if not blocked.is_empty():
		await ctx.say(BattleText.fill(BattleText.line(blocked), names))
		return
	if critter.talk_closed:
		await ctx.say(BattleText.fill(RecruitBank.too_angry_text(), names))
		return
	if not ctx.has_party_room():
		await ctx.say(BattleText.fill(BattleText.line("RECRUIT_NO_ROOM"), names))
		return

	# Placeholder (GDD 18, Claude's item 2): low HP starts the talk with one mood stack.
	if critter.hp_ratio() <= BattleRules.TALK_LOW_HP_RATIO and not critter.low_hp_mood_added:
		critter.low_hp_mood_added = true
		await _add_mood(ctx, critter)
		if critter.talk_closed:
			ctx.dialogue.trigger(BattleDialogue.RECRUIT_FAIL, user, critter)
			return

	for _asked in BattleRules.TALK_MAX_QUESTIONS:
		var question := _pick_question(ctx, critter)
		critter.asked_questions.append(String(question.get("id", "")))
		ctx.view.play_react(critter)
		await ctx.say(_critter_says(critter, question.get("text", "")))

		var key := await _answer(ctx, question)
		var reaction := RecruitBank.reaction(question, critter.data.races, key)
		var outcome := StringName(reaction.get("outcome", RecruitBank.ASK_AGAIN))
		ctx.view.play_react(critter)
		await ctx.say(_critter_says(critter, reaction.get("line", "")))

		if RecruitBank.HOSTILE.has(outcome) and ctx.rng.randf() < CombatMath.talk_soften_chance(user, critter):
			await ctx.say(BattleText.fill(BattleText.line("RECRUIT_SOFTENED"), names))
			outcome = RecruitBank.ASK_AGAIN
			await _add_mood(ctx, critter)
			if critter.talk_closed:
				ctx.dialogue.trigger(BattleDialogue.RECRUIT_FAIL, user, critter)
				return

		if outcome != RecruitBank.ASK_AGAIN:
			await _resolve(ctx, critter, outcome, names)
			return

	# The last question ended with no closing outcome: the critter leaves.
	await _resolve(ctx, critter, RecruitBank.LEAVE, names)


func _resolve(ctx: BattleContext, critter: Battler, outcome: StringName, names: Dictionary) -> void:
	match outcome:
		RecruitBank.JOIN:
			if not ctx.has_party_room():
				await ctx.say(BattleText.fill(BattleText.line("RECRUIT_NO_ROOM"), names))
				return
			await ctx.recruit(critter)
			await ctx.say(BattleText.fill(BattleText.line("RECRUIT_JOIN"), names))
			ctx.dialogue.trigger(BattleDialogue.RECRUIT_SUCCESS, user, critter)
		RecruitBank.ATTACK:
			await ctx.say(BattleText.fill(BattleText.line("RECRUIT_REFUSE"), names))
			await _add_mood(ctx, critter, false)
			ctx.dialogue.trigger(BattleDialogue.RECRUIT_FAIL, user, critter)
			await _attack_now(ctx, critter)
		RecruitBank.LEAVE:
			await ctx.send_away(critter)
			await ctx.say(BattleText.fill(BattleText.line("RECRUIT_LEAVE"), names))
			ctx.dialogue.trigger(BattleDialogue.RECRUIT_FAIL, user, critter)
		RecruitBank.GIVE_MONEY:
			var coins := BattleRules.TALK_MONEY_BASE + BattleRules.TALK_MONEY_PER_LEVEL * critter.data.level
			ctx.coins_gained += coins
			ctx.view.play_coins(critter, coins)
			await ctx.say(BattleText.fill(BattleText.line("RECRUIT_GIVE_MONEY"), {"target": critter.label(), "amount": coins}))
		RecruitBank.GIVE_ITEM:
			var item := GIFT_ITEMS[ctx.rng.randi_range(0, GIFT_ITEMS.size() - 1)]
			if ctx.inventory:
				ctx.inventory.add(item)
			await ctx.say(BattleText.fill(BattleText.line("RECRUIT_GIVE_ITEM"), {"target": critter.label(), "item": item.display_name}))
		RecruitBank.HEAL_PARTY:
			var amount := BattleRules.TALK_HEAL_BASE + BattleRules.TALK_HEAL_PER_LEVEL * critter.data.level
			await ctx.say(BattleText.fill(BattleText.line("RECRUIT_HEAL_PARTY"), names))
			for member in ctx.party():
				await ctx.heal(member, amount)
		_:
			push_warning("RecruitAction: unknown outcome '%s' in game_text.json" % outcome)


## A random question with a reaction for this critter's race. Questions not yet
## asked in this battle come first.
func _pick_question(ctx: BattleContext, critter: Battler) -> Dictionary:
	var pool := RecruitBank.questions_for(critter.data.races)
	var fresh := pool.filter(func(q: Dictionary) -> bool: return not critter.asked_questions.has(String(q.get("id", ""))))
	if fresh.is_empty():
		fresh = pool
	return fresh[ctx.rng.randi_range(0, fresh.size() - 1)]


## The player's answer key. Tests and auto battle pick without the menu.
func _answer(ctx: BattleContext, question: Dictionary) -> String:
	var keys := RecruitBank.answer_keys(question)
	if ctx.answer_picker.is_valid():
		return String(ctx.answer_picker.call(question, keys))
	if ctx.auto_play or not user.is_player_controlled():
		return keys[ctx.rng.randi_range(0, keys.size() - 1)]
	var labels: Array[String] = []
	for key in keys:
		labels.append(RecruitBank.answer_text(question, key))
	var index := await ctx.view.choose_answer(labels)
	return keys[index]


## Adds one mood stack. At the limit the critter stops responding; `announce`
## says so right away (the "attack" outcome lets the attack speak first).
func _add_mood(ctx: BattleContext, critter: Battler, announce := true) -> void:
	critter.mood += 1
	ctx.view.play_mood(critter)
	if critter.mood >= BattleRules.TALK_TOO_ANGRY_STACKS and not critter.talk_closed:
		critter.talk_closed = true
		if announce:
			await ctx.say(BattleText.fill(RecruitBank.too_angry_text(), {"target": critter.label()}))


## "Immediately attacks": the critter swings its first usable weapon at once.
func _attack_now(ctx: BattleContext, critter: Battler) -> void:
	if not critter.is_alive() or ctx.party().is_empty():
		return
	var action: BattleAction = null
	for weapon in critter.data.weapons:
		if not critter.can_use(weapon):
			continue
		var pool := ctx.candidates_for(critter, weapon)
		if pool.is_empty():
			continue
		var aimed: Array[Battler] = []
		if weapon.targets_many():
			aimed = pool
		else:
			aimed.append(pool[ctx.rng.randi_range(0, pool.size() - 1)])
		action = AbilityAction.new(critter, weapon, aimed)
		break
	if action == null:
		action = _ai.choose(ctx, critter)
	await action.execute(ctx)


func _critter_says(critter: Battler, line: String) -> String:
	return BattleText.fill(BattleText.line("RECRUIT_CRITTER_SAYS"), {"target": critter.label(), "line": line})
