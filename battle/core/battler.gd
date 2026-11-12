class_name Battler
extends RefCounted
## A combatant inside one battle: runtime HP, MP, SP and statuses.
## Views listen to the signals; the rules live in BattleContext and CombatMath.

signal hp_changed(old_hp: int, new_hp: int)
signal mp_changed(new_mp: int)
signal statuses_changed

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


## Stat after statuses: multipliers first, then flat bonuses.
func get_stat(stat: StringName) -> float:
	var value := base_stat(stat)
	var flat := 0.0
	for status in statuses:
		if status.data.kind == StatusData.Kind.STAT_MODIFIER and status.data.stat_name() == stat:
			value *= status.data.multiplier
			flat += status.data.flat_bonus
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
