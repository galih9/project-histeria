class_name TurnQueue
extends RefCounted
## SP gauge turn order (GDD 05). Whoever reaches SP 1 first acts.
## time to reach 1 = (1 - SP) / (Speed x K). Everyone else advances by that time.

const EPSILON := 0.000001

## Side that struck first in the overworld, for tie-breaker 4. -1 = nobody.
var first_strike_side := -1


## Picks the next actor, advances every gauge, and resets the actor's SP to 0.
func next_actor(battlers: Array[Battler]) -> Battler:
	var alive := battlers.filter(func(b: Battler) -> bool: return b.is_alive())
	if alive.is_empty():
		return null
	var duel := _is_duel(alive)

	var actor: Battler = null
	var best_time := INF
	for battler: Battler in alive:
		var time := time_to_full(battler, duel)
		if actor == null or time < best_time - EPSILON or (absf(time - best_time) <= EPSILON and _wins_tie(battler, actor)):
			actor = battler
			best_time = time

	for battler: Battler in alive:
		battler.sp = minf(battler.sp + fill_rate(battler, duel) * best_time, 1.0)
	actor.sp = 0.0
	return actor


func time_to_full(battler: Battler, duel := false) -> float:
	return maxf(1.0 - battler.sp, 0.0) / fill_rate(battler, duel)


func fill_rate(battler: Battler, duel := false) -> float:
	var speed := BattleRules.DUEL_SPEED if duel else battler.get_stat(StatBlock.SPEED)
	return maxf(speed, 0.1) * BattleRules.K


## True when exactly one battler stands on each side (turns get normalized).
func _is_duel(alive: Array) -> bool:
	var party := 0
	var enemies := 0
	for battler: Battler in alive:
		if battler.side == Battler.Side.PARTY:
			party += 1
		else:
			enemies += 1
	return party == 1 and enemies == 1


## Tie-breakers: lowest HP, then higher base Speed, then higher level, then first strike side.
func _wins_tie(a: Battler, b: Battler) -> bool:
	if a.hp != b.hp:
		return a.hp < b.hp
	var speed_a := a.base_stat(StatBlock.SPEED)
	var speed_b := b.base_stat(StatBlock.SPEED)
	if not is_equal_approx(speed_a, speed_b):
		return speed_a > speed_b
	if a.data.level != b.data.level:
		return a.data.level > b.data.level
	return a.side == first_strike_side and b.side != first_strike_side
