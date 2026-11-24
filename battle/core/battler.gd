class_name Battler
extends RefCounted
## A combatant inside one battle: runtime HP, MP, SP and statuses.
## Views listen to the signals; the rules live in BattleContext and CombatMath.

signal hp_changed(old_hp: int, new_hp: int)
signal mp_changed(new_mp: int)
signal statuses_changed
signal shield_changed(shield: int)

enum Side { PARTY, ENEMY }

var data: CombatantData
var side: int ## Side.PARTY or Side.ENEMY
## " A", " B"... when several copies of one monster are in the fight.
var name_suffix := ""
var hp: int
var mp: int
## Turn gauge from 0 to 1 (GDD 05).
var sp := 0.0
var statuses: Array[ActiveStatus] = []
var is_defending := false
## Link back to the persistent party slot; null for enemies.
var party_member: PartyMember
## Sub actions open for this battler's current turn (GDD 06).
var sub_action_offers: Array[SubActionOffer] = []
## Opportunities earned since the last turn; they become offers on the next turn.
var pending_sub_action_offers: Array[SubActionOffer] = []
## Shield pool on top of HP (GDD 05). Damage hits it first. From Ale's Overheal.
var shield := 0
## The signature weapon is out of the user's hands (Ale's thrown book). Resets
## every battle, so the book comes back on its own when the battle ends.
var weapon_away := false
## Stun diminishing returns (GDD 05): stuns received in the current chain, and
## own turns taken free of Stun since the last one.
var stun_chain := 0
var stun_free_turns := 0
## Recruit talk (GDD 18): mood stacks built up this battle, the questions
## already asked, and whether the critter is too angry to respond. A Battler
## lives for one battle, so all of this resets when the battle ends.
var mood := 0
var talk_closed := false
var asked_questions: Array[String] = []
var low_hp_mood_added := false


func _init(combatant: CombatantData, battle_side: int) -> void:
	data = combatant
	side = battle_side
	hp = data.stats.max_hp
	mp = data.stats.max_mp


static func from_party_member(member: PartyMember) -> Battler:
	var battler := Battler.new(member.data, Side.PARTY)
	battler.party_member = member
	battler.hp = member.hp
	battler.mp = member.mp
	return battler


# --- Names -------------------------------------------------------------------

func display_name() -> String:
	return data.display_name + name_suffix


## Name for the small party window.
func window_name() -> String:
	return data.short_name + name_suffix if not data.short_name.is_empty() else display_name()


## Name with the article, for the battle text ("the Big Frog").
func label() -> String:
	return data.article + display_name()


# --- Stats -------------------------------------------------------------------

func max_hp() -> int:
	return data.stats.max_hp


func max_mp() -> int:
	return data.stats.max_mp


func hp_ratio() -> float:
	return float(hp) / maxi(max_hp(), 1)


func base_stat(stat: StringName) -> float:
	return data.stats.get_stat(stat)


## Stat after statuses: multipliers first, then flat bonuses. A status's
## strength scales how far it moves the stat (Yawn + makes debuffs stronger).
func get_stat(stat: StringName) -> float:
	var value := base_stat(stat)
	var flat := 0.0
	for status in statuses:
		if status.data.kind == StatusData.Kind.STAT_MODIFIER and status.data.stat_name() == stat:
			value *= maxf(1.0 + (status.data.multiplier - 1.0) * status.strength, 0.05)
			flat += status.data.flat_bonus * status.strength
	return maxf(value + flat, 0.0)


# --- State -------------------------------------------------------------------

func is_alive() -> bool:
	return hp > 0


func is_player_controlled() -> bool:
	return side == Side.PARTY


func set_hp(value: int) -> void:
	var old := hp
	hp = clampi(value, 0, max_hp())
	if hp != old:
		hp_changed.emit(old, hp)


func set_mp(value: int) -> void:
	var old := mp
	mp = clampi(value, 0, max_mp())
	if mp != old:
		mp_changed.emit(mp)


func can_pay(skill: SkillData) -> bool:
	return mp >= skill.mp_cost


## False while the skill is locked: its weapon is away, or it fetches a weapon
## that is already in hand.
func is_unlocked(action: ActionData) -> bool:
	if action.requires_weapon and weapon_away:
		return false
	if action.retrieves_weapon and not weapon_away:
		return false
	return true


func can_use(skill: SkillData) -> bool:
	return is_unlocked(skill) and can_pay(skill)


func set_shield(value: int) -> void:
	value = maxi(value, 0)
	if value != shield:
		shield = value
		shield_changed.emit(shield)


## Takes damage through the Shield first. Returns the part the Shield absorbed.
func take_damage(amount: int) -> int:
	var absorbed := mini(shield, amount)
	if absorbed > 0:
		set_shield(shield - absorbed)
	set_hp(hp - (amount - absorbed))
	return absorbed


func has_shield() -> bool:
	for battle_trait in data.traits:
		if battle_trait.has_shield(self):
			return true
	return false


# --- Statuses ----------------------------------------------------------------

func find_status(status: StatusData) -> ActiveStatus:
	for active in statuses:
		if active.data == status:
			return active
	return null


func has_debuff() -> bool:
	for active in statuses:
		if active.data.is_debuff:
			return true
	return false


func find_kind(kind: StatusData.Kind) -> ActiveStatus:
	for active in statuses:
		if active.data.kind == kind:
			return active
	return null


## The one who taunted this battler, while that one still stands (GDD 05).
func taunter() -> Battler:
	var taunt := find_kind(StatusData.Kind.TAUNT)
	if taunt and taunt.source and taunt.source.is_alive() and taunt.source.side != side:
		return taunt.source
	return null


func add_status(active: ActiveStatus) -> void:
	statuses.append(active)
	statuses_changed.emit()


func remove_status(active: ActiveStatus) -> void:
	statuses.erase(active)
	statuses_changed.emit()


func clear_statuses() -> void:
	statuses.clear()
	statuses_changed.emit()


## Writes HP and MP back to the party slot after the battle.
func write_back() -> void:
	if party_member:
		party_member.hp = hp
		party_member.mp = mp
