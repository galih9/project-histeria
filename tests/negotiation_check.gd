extends Node
## Recruit talk check (GDD 18): the question bank in game_text.json, every
## outcome, mood stacks, the Luck save, the language lock and the 3-question limit.
## Run headless:
##   godot --headless --fixed-fps 60 res://tests/negotiation_check.tscn
## Prints PASS / FAIL per check and quits with the number of failures.

const BATTLE := preload("res://battle/battle_scene.tscn")
const PAIR := preload("res://data/encounters/mannequin_pair.tres")
const STONE := preload("res://data/encounters/stone_thing.tres")
const ORB := preload("res://data/encounters/orb_and_mannequin.tres")
const CREW := preload("res://data/encounters/machinist_crew.tres")
const RACES_WITH_LINES: Array[String] = ["idols", "kits", "monuments", "ferrals", "souls"]
const OUTCOMES: Array[String] = ["join", "attack", "leave", "ask_again", "give_money", "give_item", "heal_party"]

var _failures := 0
var _narration: Array[String] = []


func _ready() -> void:
	UserSettings.text_speed = UserSettings.TextSpeed.INSTANT
	_check_bank()
	_check_luck_math()
	await _check_join()
	await _check_attack_and_too_angry()
	await _check_leave()
	await _check_three_questions()
	await _check_gifts()
	await _check_locks()
	await _check_softened()
	await _check_low_hp()
	print("NEGOTIATION CHECK DONE, %d failures" % _failures)
	get_tree().quit(_failures)


func _check(ok: bool, label: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		_failures += 1


func _count(fragment: String) -> int:
	return _narration.filter(func(l: String) -> bool: return l.contains(fragment)).size()


## A battle with the view and context ready, and the turn loop left off.
func _setup(encounter: EncounterData) -> BattleController:
	GameState.new_game()
	GameState.dev_all_languages = false
	var battle: BattleController = BATTLE.instantiate()
	add_child(battle)
	var ctx := BattleContext.new()
	ctx.rng.seed = 11
	ctx.encounter = encounter
	ctx.inventory = GameState.inventory
	ctx.view = battle.view
	for member in GameState.party:
		ctx.battlers.append(Battler.from_party_member(member))
	battle.ctx = ctx
	battle._spawn_enemies(encounter)
	ctx.dialogue = BattleDialogue.new(ctx)
	battle.view.setup(ctx)
	_narration.clear()
	battle.view.narrated.connect(func(t: String) -> void: _narration.append(t))
	await get_tree().process_frame
	return battle


func _done(battle: BattleController) -> void:
	battle.queue_free()
	await get_tree().process_frame


func _find(ctx: BattleContext, id: StringName) -> Battler:
	for b in ctx.battlers:
		if b.data.text_id == id:
			return b
	return null


## A copy of Bo with the given Luck, so the Luck save can be switched on or off.
func _recruiter(luck: float) -> Battler:
	var bo: CombatantData = load("res://data/characters/bo.tres")
	var data: CombatantData = bo.duplicate()
	data.stats = bo.stats.duplicate()
	data.stats.luck = luck
	return Battler.new(data, Battler.Side.PARTY)


## Marks every question without `outcome` for this race as asked, so the talk
## picks only questions where the outcome exists.
func _steer(critter: Battler, outcome: String) -> void:
	for q: Dictionary in RecruitBank.questions_for(critter.data.races):
		var has_it := false
		for key in RecruitBank.answer_keys(q):
			if RecruitBank.reaction(q, critter.data.races, key).get("outcome", "") == outcome:
				has_it = true
		if not has_it:
			critter.asked_questions.append(String(q.get("id", "")))


## An answer picker that always gives the answer leading to `outcome`.
func _picker(critter: Battler, outcome: String) -> Callable:
	return func(q: Dictionary, keys: Array[String]) -> String:
		for key in keys:
			if RecruitBank.reaction(q, critter.data.races, key).get("outcome", "") == outcome:
				return key
		return keys[0]


func _talk(ctx: BattleContext, user: Battler, critter: Battler) -> void:
	await RecruitAction.new(user, [critter]).execute(ctx)
	await ctx.resolve_knockouts()


# --- Data ---------------------------------------------------------------------

func _check_bank() -> void:
	var questions := RecruitBank.questions()
	_check(questions.size() == 10, "The question bank loads 10 questions from game_text.json")
	var complete := true
	var outcomes_ok := true
	for q: Dictionary in questions:
		var keys := RecruitBank.answer_keys(q)
		if keys.size() < 2:
			complete = false
		for race in RACES_WITH_LINES:
			var races: Array[StringName] = [StringName(race.capitalize())]
			for key in keys:
				var r := RecruitBank.reaction(q, races, key)
				if String(r.get("line", "")).is_empty():
					complete = false
				if not OUTCOMES.has(String(r.get("outcome", ""))):
					outcomes_ok = false
	_check(complete, "Every question has a line for Idols, Kits, Monuments, Ferrals and Souls on every answer")
	_check(outcomes_ok, "Every reaction uses a known outcome")
	var wanderers: Array[StringName] = [&"Wanderers"]
	_check(RecruitBank.questions_for(wanderers).is_empty(), "Wanderers have no reactions yet")

	# Two races pointing at one reaction set share it.
	var shared := {
		"answers": {"A": "a"},
		"reaction_sets": {"one": {"A": {"line": "shared line", "outcome": "join"}}},
		"race_set": {"idols": "one", "kits": "one"},
	}
	var kits: Array[StringName] = [&"Kits"]
	_check(RecruitBank.reaction(shared, kits, "A").get("line", "") == "shared line", "Races pointing at the same reaction set share its lines")


func _check_luck_math() -> void:
	var critter := Battler.new(load("res://data/monsters/laughing_mannequin.tres"), Battler.Side.ENEMY)
	_check(is_zero_approx(CombatMath.talk_soften_chance(_recruiter(5.0), critter)), "Luck below the threshold never softens a reaction")
	_check(is_equal_approx(CombatMath.talk_soften_chance(_recruiter(25.0), critter), 0.5), "High Luck softens at the capped chance")
	critter.mood = 2
	_check(is_equal_approx(CombatMath.talk_soften_chance(_recruiter(25.0), critter), 0.3), "Each mood stack lowers the Luck chance")


# --- Outcomes -----------------------------------------------------------------

func _check_join() -> void:
	var battle := await _setup(PAIR)
	var ctx := battle.ctx
	var bo := _find(ctx, &"bo")
	var critter := ctx.enemies()[0]
	ctx.answer_picker = _picker(critter, "join")
	await _talk(ctx, bo, critter)
	_check(ctx.recruited.has(critter) and critter.side == Battler.Side.PARTY, "join: the Mannequin (Idols) joins the party")
	_check(_count("joins the party") == 1, "join: the join line plays")
	_check(_count(": \"") == 2, "join: one question and one reaction are said")
	await _done(battle)


func _check_attack_and_too_angry() -> void:
	var battle := await _setup(PAIR)
	var ctx := battle.ctx
	var critter := ctx.enemies()[0]
	var hits := [0]
	ctx.attack_resolved.connect(func(u: Battler, _t: Battler, _r: HitResult) -> void:
		if u == critter:
			hits[0] += 1)
	_steer(critter, "attack")
	ctx.answer_picker = _picker(critter, "attack")
	await _talk(ctx, _recruiter(0.0), critter)
	_check(critter.mood == 1, "attack: a hostile reaction adds a mood stack")
	_check(hits[0] >= 1, "attack: the critter attacks at once")
	_check(_count("refuses") == 1, "attack: the refuse line plays")

	critter.mood = 2
	critter.asked_questions.clear()
	_steer(critter, "attack")
	await _talk(ctx, _recruiter(0.0), critter)
	_check(critter.talk_closed, "too angry: the third mood stack closes the talk")
	_narration.clear()
	await _talk(ctx, _recruiter(0.0), critter)
	_check(_count("did not respond") == 1 and _count(": \"") == 0, "too angry: the next talk gets no response")
	await _done(battle)


func _check_leave() -> void:
	var battle := await _setup(STONE)
	var ctx := battle.ctx
	var critter := ctx.enemies()[0]
	_steer(critter, "leave")
	ctx.answer_picker = _picker(critter, "leave")
	await _talk(ctx, _recruiter(0.0), critter)
	_check(not ctx.battlers.has(critter) and ctx.left_battle.has(critter), "leave: the Stone Thing (Monuments) leaves the battle")
	_check(ctx.enemies().is_empty(), "leave: nobody is left to fight, so the battle can end")
	await _done(battle)


func _check_three_questions() -> void:
	var battle := await _setup(PAIR)
	var ctx := battle.ctx
	var critter := ctx.enemies()[0]
	_steer(critter, "ask_again")
	ctx.answer_picker = _picker(critter, "ask_again")
	await _talk(ctx, _find(ctx, &"bo"), critter)
	_check(_count(": \"") == 6, "ask_again: three questions and three reactions, then the talk stops")
	_check(ctx.left_battle.has(critter), "ask_again: after the third question the critter leaves")
	var asked := critter.asked_questions.duplicate()
	var unique := {}
	for id in asked:
		unique[id] = true
	_check(unique.size() == asked.size(), "ask_again: no question repeats inside one talk")
	await _done(battle)


func _check_gifts() -> void:
	# Money from a Monument, scaled by level.
	var battle := await _setup(STONE)
	var ctx := battle.ctx
	var critter := ctx.enemies()[0]
	_steer(critter, "give_money")
	ctx.answer_picker = _picker(critter, "give_money")
	await _talk(ctx, _find(ctx, &"bo"), critter)
	var expected := BattleRules.TALK_MONEY_BASE + BattleRules.TALK_MONEY_PER_LEVEL * critter.data.level
	_check(ctx.coins_gained == expected, "give_money: %d coins for a level %d critter" % [expected, critter.data.level])
	_check(ctx.battlers.has(critter), "give_money: the critter stays in the battle")
	await _done(battle)

	# Item and heal from a Soul, once its language is open.
	battle = await _setup(ORB)
	ctx = battle.ctx
	GameState.unlock_language(Races.SOULS)
	var orb := _find(ctx, &"funny_looking_orb")
	var bag_before := 0
	for item in ctx.inventory.items():
		bag_before += ctx.inventory.count_of(item)
	_steer(orb, "give_item")
	ctx.answer_picker = _picker(orb, "give_item")
	await _talk(ctx, _find(ctx, &"bo"), orb)
	var bag_after := 0
	for item in ctx.inventory.items():
		bag_after += ctx.inventory.count_of(item)
	_check(bag_after == bag_before + 1, "give_item: the Orb (Souls) adds an item to the bag")

	var bo := _find(ctx, &"bo")
	var ale := _find(ctx, &"ale")
	bo.set_hp(10)
	ale.set_hp(10)
	orb.asked_questions.clear()
	_steer(orb, "heal_party")
	ctx.answer_picker = _picker(orb, "heal_party")
	await _talk(ctx, bo, orb)
	_check(bo.hp > 10 and ale.hp > 10, "heal_party: every active party member recovers HP")
	await _done(battle)


func _check_locks() -> void:
	var battle := await _setup(ORB)
	var ctx := battle.ctx
	var orb := _find(ctx, &"funny_looking_orb")
	_check(RecruitAction.blocker(orb) == "RECRUIT_LANGUAGE_LOCKED", "Souls: the talk stays closed before the language unlock")
	await _talk(ctx, _find(ctx, &"bo"), orb)
	_check(_count(": \"") == 0, "Souls: no question is asked while the language is locked")
	GameState.dev_all_languages = true
	_check(RecruitAction.blocker(orb).is_empty(), "DEV Lang switch opens every language")
	GameState.dev_all_languages = false
	await _done(battle)

	battle = await _setup(CREW)
	ctx = battle.ctx
	var machinist := _find(ctx, &"machinist")
	_check(RecruitAction.blocker(machinist) == "RECRUIT_NO_WORDS", "Wanderers: the talk waits until their reactions are written")
	await _done(battle)


func _check_softened() -> void:
	var seen := false
	for attempt in 30:
		var battle := await _setup(PAIR)
		var ctx := battle.ctx
		ctx.rng.seed = 100 + attempt
		var critter := ctx.enemies()[0]
		_steer(critter, "attack")
		ctx.answer_picker = _picker(critter, "attack")
		await _talk(ctx, _recruiter(25.0), critter)
		if _count("keeps talking") > 0:
			seen = true
			_check(critter.mood >= 1, "Luck save: softening a hostile reaction adds a mood stack")
			await _done(battle)
			break
		await _done(battle)
	_check(seen, "Luck save: a high Luck turns a hostile reaction into another question")


func _check_low_hp() -> void:
	var battle := await _setup(PAIR)
	var ctx := battle.ctx
	var critter := ctx.enemies()[0]
	critter.set_hp(1)
	ctx.answer_picker = _picker(critter, "join")
	await _talk(ctx, _find(ctx, &"bo"), critter)
	_check(critter.mood == 1, "Low HP: the critter starts the talk with one mood stack")
	await _done(battle)
	var fresh := Battler.new(critter.data, Battler.Side.ENEMY)
	_check(fresh.mood == 0 and not fresh.talk_closed, "Mood resets with the next battle")
