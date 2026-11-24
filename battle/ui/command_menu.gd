class_name CommandMenu
extends Control
## The party member's turn menu (GDD 03, "Menus"):
##   Attack -> weapon attacks (Melee, Throw Book / Collect the book) and sub actions (highlighted)
##   Skill  -> skills with MP costs, Defend at the bottom
##   Action -> Recruit (Call In and the other Actions come in later blocks)
##   Item   -> the bag
##   Run
## Weapon-bound entries grey out while the weapon is away (Ale's thrown book).
## Cancel steps back one level: target selection -> list -> main menu.
## Every label comes from ui_text in game_text.json.

enum Main { ATTACK, SKILL, ACTION, ITEM, RUN }

const MAIN_FALLBACK: Array[String] = ["Attack", "Skill", "Action", "Item", "Run"]
const RECRUIT := &"recruit"
const RECRUIT_COLOR := Color("8fe3ff")

@onready var _main_list: MenuList = %MainList
@onready var _sub_list: MenuList = %SubList

var _view: BattleView
var _main_index := 0


func _ready() -> void:
	_main_list.add_cancel_entry = false
	_main_list.allow_cancel = false
	_main_list.keep_visible_on_select = true
	hide()


func bind_view(view: BattleView) -> void:
	_view = view


## Waits until the player has picked an action and its targets.
func choose(ctx: BattleContext, actor: Battler) -> BattleAction:
	show()
	_view.text_box.hide()
	_main_index = 0
	var action: BattleAction = null
	while action == null:
		var choice := await _main_list.choose(_main_entries(ctx, actor), _main_index)
		if choice < 0:
			continue
		_main_index = choice
		match choice:
			Main.ATTACK:
				action = await _choose_attack(ctx, actor)
			Main.SKILL:
				action = await _choose_skill(ctx, actor)
			Main.ACTION:
				action = await _choose_action(ctx, actor)
			Main.ITEM:
				action = await _choose_item(ctx, actor)
			Main.RUN:
				action = RunAction.new(actor)
	_main_list.close()
	_sub_list.close()
	hide()
	_view.text_box.clear()
	_view.text_box.show()
	return action


func _main_entries(ctx: BattleContext, actor: Battler) -> Array[MenuEntry]:
	var has_items := ctx.inventory != null and not ctx.inventory.is_empty()
	var labels: Array[String] = []
	for i in MAIN_FALLBACK.size():
		labels.append(GameText.list_item("ui_text.battle_menu", i, MAIN_FALLBACK[i]))
	if not actor.sub_action_offers.is_empty():
		labels[Main.ATTACK] = GameText.text("ui_text.battle_menu_attack_with_sub_action", labels[Main.ATTACK] + "!")
	return [
		MenuEntry.new(labels[Main.ATTACK], Main.ATTACK),
		MenuEntry.new(labels[Main.SKILL], Main.SKILL),
		MenuEntry.new(labels[Main.ACTION], Main.ACTION),
		MenuEntry.new(labels[Main.ITEM], Main.ITEM, "", not has_items),
		MenuEntry.new(labels[Main.RUN], Main.RUN, "", ctx.is_boss_battle()),
	]


func _choose_attack(ctx: BattleContext, actor: Battler) -> BattleAction:
	var entries: Array[MenuEntry] = []
	for weapon in actor.data.weapons:
		if weapon.retrieves_weapon and not actor.weapon_away:
			continue # "Collect the book" shows only while the book is on the ground
		entries.append(MenuEntry.new(weapon.get_menu_label(), weapon, "", not actor.can_use(weapon)))
	for offer in actor.sub_action_offers:
		entries.append(MenuEntry.new(offer.data.display_name, offer, "", false, offer.data.highlight_color))

	var index := 0
	while true:
		index = await _sub_list.choose(entries, index)
		if index < 0:
			return null
		var payload: Variant = entries[index].payload
		if payload is SkillData:
			var targets := await _pick_targets(ctx, actor, payload)
			if not targets.is_empty():
				return AbilityAction.new(actor, payload, targets)
		elif payload is SubActionOffer:
			return HumiliateAction.new(actor, payload)
	return null


func _choose_skill(ctx: BattleContext, actor: Battler) -> BattleAction:
	var entries: Array[MenuEntry] = []
	for skill in actor.data.skills:
		entries.append(MenuEntry.new(skill.get_menu_label(), skill, "%dMP" % skill.mp_cost, not actor.can_use(skill)))
	entries.append(MenuEntry.new(GameText.text("ui_text.skill_submenu_last_entry", "Defend"), &"defend"))

	var index := 0
	while true:
		index = await _sub_list.choose(entries, index)
		if index < 0:
			return null
		var payload: Variant = entries[index].payload
		if payload is SkillData:
			var targets := await _pick_targets(ctx, actor, payload)
			if not targets.is_empty():
				return AbilityAction.new(actor, payload, targets)
		else:
			return DefendAction.new(actor)
	return null


func _choose_action(ctx: BattleContext, actor: Battler) -> BattleAction:
	var can_recruit := ctx.has_party_room() and not ctx.recruitable_enemies().is_empty()
	var entries: Array[MenuEntry] = [
		MenuEntry.new(GameText.list_item("ui_text.action_submenu", 0, "Recruit"), RECRUIT, "", not can_recruit, RECRUIT_COLOR),
	]
	var index := 0
	while true:
		index = await _sub_list.choose(entries, index)
		if index < 0:
			return null
		if entries[index].payload == RECRUIT:
			var picked := await _view.select_targets(ctx.recruitable_enemies(), false)
			if picked.is_empty():
				continue
			# A talk that can't open yet (language lock, no questions for the race)
			# says why and keeps the turn.
			var blocked := RecruitAction.blocker(picked[0])
			if not blocked.is_empty():
				hide()
				await _view.say(BattleText.fill(BattleText.line(blocked), {"target": picked[0].label()}))
				_view.text_box.clear()
				_view.text_box.hide()
				show()
				continue
			return RecruitAction.new(actor, picked)
	return null


func _choose_item(ctx: BattleContext, actor: Battler) -> BattleAction:
	var entries: Array[MenuEntry] = []
	for item in ctx.inventory.items():
		entries.append(MenuEntry.new(item.get_menu_label(), item, "x%d" % ctx.inventory.count_of(item)))

	var index := 0
	while true:
		index = await _sub_list.choose(entries, index)
		if index < 0:
			return null
		var item: ItemData = entries[index].payload
		var targets := await _pick_targets(ctx, actor, item)
		if not targets.is_empty():
			return AbilityAction.new(actor, item, targets)
	return null


func _pick_targets(ctx: BattleContext, actor: Battler, action: ActionData) -> Array[Battler]:
	var candidates := ctx.candidates_for(actor, action)
	if action.target == ActionData.Target.SELF:
		return candidates
	return await _view.select_targets(candidates, action.targets_many())
