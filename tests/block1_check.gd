extends Node
## Block 1 check (GDD 16): every Bo and Ale skill, the Nov 19 rules, every
## battle line event, every conversation, and the game_text.json loading.
## Run headless:
##   godot --headless --fixed-fps 60 res://tests/block1_check.tscn
## Prints PASS / FAIL per check and quits with the number of failures.

const BATTLE := preload("res://battle/battle_scene.tscn")
const PAIR := preload("res://data/encounters/mannequin_pair.tres")
const FROG := preload("res://data/encounters/big_frog_boss.tres")
const ATTACK_UP := preload("res://data/statuses/attack_up.tres")
const POISON := preload("res://data/statuses/poison.tres")
const STUN := preload("res://data/statuses/stun.tres")
const PARALYZE := preload("res://data/statuses/paralyze.tres")
const TAUNT := preload("res://data/statuses/taunt.tres")

var _failures := 0
var _narration: Array[String] = []


func _ready() -> void:
	UserSettings.text_speed = UserSettings.TextSpeed.INSTANT
	await _check_text_loading()
	await _check_rules()
	await _check_kits()
	await _check_lines()
	print("BLOCK 1 CHECK DONE, %d failures" % _failures)
	get_tree().quit(_failures)


func _check(ok: bool, label: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		_failures += 1


func _said(fragment: String) -> bool:
	for line in _narration:
		if line.contains(fragment):
			return true
	return false


## A battle with the view and context ready, and the turn loop left off,
## so the checks can drive every step by hand.
func _setup(encounter: EncounterData) -> BattleController:
	GameState.new_game()
	var battle: BattleController = BATTLE.instantiate()
	add_child(battle)
	var ctx := BattleContext.new()
	ctx.rng.seed = 7
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


func _find(ctx: BattleContext, id: StringName) -> Battler:
	for b in ctx.battlers:
		if b.data.text_id == id:
			return b
	return null


func _skill(b: Battler, id: StringName) -> SkillData:
	for s in b.data.weapons + b.data.skills:
		if s.text_id == id:
			return s
	return null


# --- 1.4 text --------------------------------------------------------------

func _check_text_loading() -> void:
	var bo: CombatantData = load("res://data/characters/bo.tres")
	_check(bo.display_name == "Bo", "Bo's name comes from game_text.json")
	_check(bo.battle_lines.has("battle_start_player"), "Bo's battle lines load (battle_start_player)")
	var slash := bo.weapons[0]
	_check(slash.use_text == "{user} slashes {target} with twin blades!", "Double Slash battle text loads")
	_check(slash.get_menu_label() == "Melee", "Double Slash sits under Attack > Melee")
	var sit: SkillData = load("res://data/skills/bo_sit_down.tres")
	_check(sit.outcome_success_lines.size() == 2 and sit.outcome_fail_lines.size() == 1, "Sit Down outcome lines load")
	var stun: StatusData = load("res://data/statuses/stun.tres") # load(): a const's fields are frozen at compile time
	_check(stun.apply_text == "{target} is stunned.", "Empty Stun text uses the plain stand-in")
	var frog: CombatantData = load("res://data/monsters/big_frog.tres")
	_check(frog.article == "the " and frog.display_name == "Big Frog", "Critter name and article load")
	_check(frog.battle_intro.contains("hops out of the pond"), "Big Frog battle intro loads")
	_check(BattleText.line("DEFEATED_PARTY") == "{target} is downed!", "Narration loads from battle_narration")
	_check(GameText.sign_pages(&"welcome_sign").size() == 4, "Sign pages load")

	# Editing a line in the JSON changes it in the game.
	var original := GameText.text("battle_narration.MISS")
	GameText.data.battle_narration.MISS = "{target} edited!"
	_check(BattleText.line("MISS") == "{target} edited!", "A changed line shows up in the game")
	var bo_lines: Dictionary = (GameText.character(&"bo").battle_lines as Dictionary)
	bo_lines.crit = ["[angry] edited crit line"]
	GameText.patch(bo)
	_check(bo.battle_lines.crit[0] == "[angry] edited crit line", "A changed Raider line patches into Bo")
	GameText.reload()
	_check(BattleText.line("MISS") == original and bo.battle_lines.crit[0] != "[angry] edited crit line", "Reload brings back the file's text")


# --- 1.3 rules ----------------------------------------------------------------

func _check_rules() -> void:
	var battle := await _setup(PAIR)
	var ctx := battle.ctx
	var bo := _find(ctx, &"bo")
	var ale := _find(ctx, &"ale")
	var foe := ctx.enemies()[0]

	# Own-turn countdown: Attack Up counts on Ale's own turns, Poison every turn.
	await ctx.apply_status(ale, ale, ATTACK_UP, 3)
	await ctx.apply_status(foe, bo, POISON, 3)
	await ctx.post_action_step(foe)
	_check(ale.find_status(ATTACK_UP).stacks == 3, "Timed effects keep their stacks on someone else's turn")
	_check(bo.find_status(POISON).stacks == 2, "Poison ticks on every turn")
	await ctx.post_action_step(ale)
	_check(ale.find_status(ATTACK_UP).stacks == 2, "Timed effects lose a stack on the owner's own turn")

	# Stun: skipped turn counts as own turn; diminishing returns.
	await ctx.apply_status(ale, foe, STUN, 2)
	_check(foe.find_status(STUN).stacks == 2, "First stun lands in full")
	var lost := await ctx.control_check(foe)
	_check(lost, "Stunned character loses the turn")
	await ctx.post_action_step(foe)
	_check(foe.find_status(STUN).stacks == 1, "The stunned turn counts as the character's own turn (Q21)")
	await ctx.post_action_step(foe)
	await ctx.apply_status(ale, foe, STUN, 2)
	_check(foe.find_status(STUN) != null and foe.find_status(STUN).stacks == 1, "Second stun in a chain is 1 shorter")
	foe.remove_status(foe.find_status(STUN))
	await ctx.apply_status(ale, foe, STUN, 2)
	_check(foe.find_status(STUN) == null and _said("resists the stun"), "Third stun in a chain is resisted")
	await ctx.control_check(foe)
	await ctx.control_check(foe)
	_check(foe.stun_chain == 0, "Stun chain resets after 2 free own turns")

	# Paralyze: 50% roll per own turn.
	await ctx.apply_status(ale, foe, PARALYZE, 3)
	var losses := 0
	for i in 40:
		if await ctx.control_check(foe):
			losses += 1
	_check(losses > 8 and losses < 32, "Paralyze takes about half the turns (%d/40)" % losses)

	# Taunt: single-target picks must aim at the taunter.
	var slap := foe.data.weapons[0]
	await ctx.apply_status(bo, foe, TAUNT, 2)
	var picks := ctx.candidates_for(foe, slap)
	_check(picks.size() == 1 and picks[0] == bo, "A taunted enemy can only aim at Bo")
	var ai_ok := true
	for i in 20:
		var action := battle._ai.choose(ctx, foe)
		if action is AbilityAction and (action as AbilityAction).ability.target == ActionData.Target.SINGLE_ENEMY:
			ai_ok = ai_ok and action.targets == [bo]
	_check(ai_ok, "Enemy AI attacks the taunter")

	# Shield absorbs damage first; poison too.
	ale.set_shield(10)
	var absorbed := ale.take_damage(4)
	_check(absorbed == 4 and ale.shield == 6 and ale.hp == ale.max_hp(), "Shield absorbs damage before HP")
	absorbed = ale.take_damage(10)
	_check(absorbed == 6 and ale.shield == 0 and ale.hp == ale.max_hp() - 4, "Damage past the Shield reaches HP")

	# Defend for Raiders: blocks crits and cuts damage.
	await DefendAction.new(bo).execute(ctx)
	_check(bo.is_defending and _said("gets ready to block"), "Basic Defend works for a Raider")

	# Yawn hooks: stronger and longer debuffs from Bo.
	var ad: StatusData = load("res://data/statuses/attack_down.tres")
	var base_attack := ctx.enemies()[1].get_stat(StatBlock.ATTACK)
	bo.data.debuff_strength_bonus = 1.0
	bo.data.debuff_extra_stacks = 1
	await ctx.apply_status(bo, ctx.enemies()[1], ad, 2)
	var debuffed := ctx.enemies()[1].get_stat(StatBlock.ATTACK)
	_check(ctx.enemies()[1].find_status(ad).stacks == 3, "Yawn ++ hook: Bo's debuffs last longer")
	_check(debuffed < base_attack * 0.75 - 0.01, "Yawn + hook: Bo's debuffs are stronger")
	bo.data.debuff_strength_bonus = 0.0
	bo.data.debuff_extra_stacks = 0

	# Races and the Gun.
	var mannequin: CombatantData = load("res://data/monsters/laughing_mannequin.tres")
	_check(mannequin.races == [Races.IDOLS], "Laughing Mannequin is an Idol")
	var labels := ale.data.weapons.map(func(s: SkillData) -> String: return s.get_menu_label())
	_check(not labels.has("Gun") and labels.has("Throw Book"), "Gun is gone from the Attack menu")
	battle.queue_free()
	await get_tree().process_frame


# --- 1.3 kits -----------------------------------------------------------------

func _check_kits() -> void:
	var battle := await _setup(PAIR)
	var ctx := battle.ctx
	var bo := _find(ctx, &"bo")
	var ale := _find(ctx, &"ale")
	var foes := ctx.enemies()

	# Bo
	await AbilityAction.new(bo, _skill(bo, &"double_slash"), [foes[0]]).execute(ctx)
	var hits := _narration.filter(func(l: String) -> bool: return l.contains("damage!") or l.contains("dodged")).size()
	_check(_said("slashes the Laughing Mannequin A with twin blades") and hits == 2, "Double Slash hits 2 times")
	await AbilityAction.new(bo, _skill(bo, &"thumbs_down"), [foes[0]]).execute(ctx)
	_check(foes[0].find_status(load("res://data/statuses/attack_down.tres")) != null, "Thumbs Down lowers one enemy's Attack")
	await AbilityAction.new(bo, _skill(bo, &"juggle_sword"), foes).execute(ctx)
	var dd: StatusData = load("res://data/statuses/defense_down.tres")
	_check(foes[0].find_status(dd) != null and foes[1].find_status(dd) != null, "Juggle Sword lowers every enemy's Defense")

	var sit := _skill(bo, &"sit_down")
	var seen := {"one": false, "group": false, "fail": false}
	for i in 30:
		for f in foes:
			var t := f.find_status(TAUNT)
			if t:
				f.remove_status(t)
		bo.mp = bo.max_mp()
		_narration.clear()
		await AbilityAction.new(bo, sit, foes).execute(ctx)
		var taunted := foes.filter(func(f: Battler) -> bool: return f.find_status(TAUNT) != null).size()
		if taunted == 1 and _said("is suddenly enraged"):
			seen.one = true
		if taunted == 2 and _said("Enemies are enraged"):
			seen.group = true
		if taunted == 0 and _said("Enemies aren't bothered"):
			seen.fail = true
	_check(seen.one and seen.group and seen.fail, "Sit Down: each enemy rolls, with one / group / fail text " + str(seen))

	# Ale
	var fire := _skill(ale, &"fire_incantation")
	var throw := _skill(ale, &"book_throw")
	var collect := _skill(ale, &"collect_book")
	var band_aid := _skill(ale, &"band_aid")
	_check(not ale.is_unlocked(collect), "Collect Book is hidden while Ale holds the book")
	await AbilityAction.new(ale, throw, [foes[1]]).execute(ctx)
	_check(ale.weapon_away and _said("throws her book"), "Book Throw puts the book on the ground")
	_check(not ale.can_use(fire) and not ale.can_use(throw), "Spellbook skills lock while the book is thrown")
	_check(ale.can_use(band_aid), "Band-Aid works while the book is on the ground (Q12)")
	await AbilityAction.new(ale, collect, [ale]).execute(ctx)
	_check(not ale.weapon_away and _said("gets her book back"), "Collect Book takes the book back")

	var foe := foes[1]
	foe.set_hp(foe.max_hp())
	await AbilityAction.new(ale, fire, [foe]).execute(ctx)
	_check(_said("throws a fireball"), "Fire Incantation deals fire damage")
	_check(fire.effects[0].fx_kind() == DamageEffect.HitFx.FIRE, "Fire tag picks the fire hit effect")
	var electro := _skill(ale, &"electro_incantation")
	_check(electro.effects[0].element == DamageEffect.Element.ELECTRIC and electro.effects[1].status == PARALYZE, "Electro Incantation: Electric tag, Paralyze hook for Electro +")
	var frost := _skill(ale, &"frost_incantation")
	ale.mp = ale.max_mp()
	foe.set_hp(foe.max_hp())
	foe.stun_chain = 0
	var stunned := false
	for i in 6:
		ale.mp = ale.max_mp()
		var s := foe.find_status(STUN)
		if s:
			foe.remove_status(s)
		foe.stun_chain = 0
		foe.set_hp(foe.max_hp())
		await AbilityAction.new(ale, frost, [foe]).execute(ctx)
		if foe.find_status(STUN) and foe.find_status(STUN).stacks == 1:
			stunned = true
	_check(stunned, "Frost Incantation stuns for 1 turn")

	# Overheal: healing past max HP becomes Shield (uncapped, whole battle).
	bo.set_hp(bo.max_hp() - 5)
	ale.mp = ale.max_mp()
	await AbilityAction.new(ale, band_aid, [bo]).execute(ctx)
	_check(bo.hp == bo.max_hp() and bo.shield > 0 and _said("gains a shield"), "Overheal turns extra healing into Shield (%d)" % bo.shield)
	var first := bo.shield
	ale.mp = ale.max_mp()
	await AbilityAction.new(ale, band_aid, [bo]).execute(ctx)
	_check(bo.shield > first, "Overheal Shield is uncapped (%d)" % bo.shield)
	var cookie: ItemData = load("res://data/items/cookie.tres")
	var before := bo.shield
	await AbilityAction.new(ale, cookie, [bo]).execute(ctx)
	_check(bo.shield == before, "Items skip Overheal (only Ale's own skills)")
	battle.queue_free()
	await get_tree().process_frame


# --- 1.4 lines ----------------------------------------------------------------

func _check_lines() -> void:
	var battle := await _setup(PAIR)
	var ctx := battle.ctx
	var bo := _find(ctx, &"bo")
	var ale := _find(ctx, &"ale")
	var shown := {}
	ctx.dialogue.line_shown.connect(func(event: StringName, speaker: StringName, text: String) -> void:
		shown["%s:%s" % [speaker, event]] = text)
	BattleDialogue.force_lines = true

	# Every event with lines for Bo and Ale, single lines only.
	var missing: Array[String] = []
	for raider in [bo, ale]:
		for event: String in raider.data.battle_lines:
			BattleDialogue.force_conversations = false
			var key := "%s:%s" % [raider.data.text_id, event]
			for attempt in 10:
				if shown.has(key):
					break
				ctx.dialogue._fire(StringName(event), raider, raider, null)
				await get_tree().process_frame
				while ctx.dialogue.is_busy():
					await get_tree().process_frame
			if not shown.has(key):
				missing.append(key)
	_check(missing.is_empty(), "Every Bo and Ale line event shows a line " + str(missing))
	for event in ["battle_start_player", "battle_start_enemy", "ally_critter_low_hp", "ally_critter_downed"]:
		_check(shown.has("bo:" + event) and shown.has("ale:" + event), "New event %s plays" % event)

	# Expressions.
	var tags := ["bored", "angry", "sad", "ridicule"]
	for tag in tags:
		_check(BattleDialogue.parse_line("[%s] hi" % tag).expression == StringName(tag), "Expression tag [%s] picks its face" % tag)

	# Conversations.
	var played: Array[String] = []
	ctx.dialogue.conversation_played.connect(func(id: String) -> void: played.append(id))
	BattleDialogue.force_conversations = true
	for entry in GameText.conversations():
		var actor := _find(ctx, StringName(entry.conditions.actor))
		var want: String = entry.id
		for attempt in 20:
			if played.has(want):
				break
			ctx.dialogue._fire(StringName(entry.event), actor, actor, null)
			while ctx.dialogue.is_busy():
				await get_tree().process_frame
	var all_ids := GameText.conversations().map(func(e: Dictionary) -> String: return e.id)
	var not_played := all_ids.filter(func(id: String) -> bool: return not played.has(id))
	_check(not_played.is_empty(), "Every conversation plays " + str(played))
	_check(shown.has("bo:recruit_fail") and shown.has("ale:recruit_fail"), "Conversation lines come from both speakers")

	# Conditions: without Bo in the party, Ale's recruit-fail conversations stay off.
	bo.set_hp(0)
	_check(ctx.dialogue.matching_conversations(&"recruit_fail", ale, null).is_empty(), "Conversations need everyone listed in the active party")
	BattleDialogue.force_lines = false
	BattleDialogue.force_conversations = false

	# Humiliate uses each Raider's lines.
	bo.set_hp(bo.max_hp())
	var offer := SubActionOffer.new(load("res://data/sub_actions/humiliate.tres"), ctx.enemies()[0])
	_narration.clear()
	await HumiliateAction.new(ale, offer).execute(ctx)
	_check(_said("'yo mama' jokes"), "Humiliate uses Ale's humiliate_lines")
	battle.queue_free()
	await get_tree().process_frame
