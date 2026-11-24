class_name BattleRules
extends RefCounted
## Every tunable number of the combat rules in one place (GDD 04 and 05).
## All values are placeholders for playtesting.

## SP fill constant: SP gained per time unit = Speed x K.
const K := 0.01
## Speed used for both sides in a 1v1, so duels alternate evenly (GDD 05).
const DUEL_SPEED := 10.0

## First strike in the overworld: starting SP bonus for the side that struck (GDD 01).
const FIRST_STRIKE_SP := 0.25
## Random starting SP so the first turn order varies a little.
const START_SP_MAX := 0.3

## Damage before defenses = Attack x power / POWER_DIVISOR.
const POWER_DIVISOR := 10.0
## Defense curve: damage x DEFENSE_SCALE / (DEFENSE_SCALE + defense).
const DEFENSE_SCALE := 20.0
## Damage roll spread (0.1 = 90% to 110%).
const DAMAGE_VARIANCE := 0.1
const CRIT_MULTIPLIER := 1.5
## Defend applies the defense curve a second time, so it scales with Defense.
const DEFEND_EXTRA_CURVE := true

## Hit chance floor and ceiling.
const MIN_HIT_CHANCE := 0.05
const MAX_HIT_CHANCE := 1.0

## Luck (GDD 04): lucky chance = Luck x LUCK_PER_POINT, capped.
const LUCK_PER_POINT := 0.005
const LUCK_CAP := 0.25

## Recruit talk (GDD 18). The answers pick the outcome; these numbers are
## placeholders until Kiki sets the detailed rules.
## Questions in one talk.
const TALK_MAX_QUESTIONS := 3
## Mood stacks that make a critter too angry to respond for the rest of the battle.
const TALK_TOO_ANGRY_STACKS := 3
## Luck softening a hostile reaction: the recruiter needs this much Luck, then
## each answer rolls Luck x TALK_SOFTEN_PER_LUCK (capped). Each mood stack on
## the critter takes TALK_SOFTEN_MOOD_PENALTY off the chance.
const TALK_SOFTEN_LUCK_THRESHOLD := 10.0
const TALK_SOFTEN_PER_LUCK := 0.02
const TALK_SOFTEN_MAX_CHANCE := 0.5
const TALK_SOFTEN_MOOD_PENALTY := 0.1
## A critter at or below this share of HP starts the talk with one mood stack.
const TALK_LOW_HP_RATIO := 0.3
## "Gives money" and "heals the active party" scale with the critter's level.
const TALK_MONEY_BASE := 10
const TALK_MONEY_PER_LEVEL := 5
const TALK_HEAL_BASE := 12
const TALK_HEAL_PER_LEVEL := 4

## Run: base chance plus a bonus for being faster than the enemies.
const RUN_BASE_CHANCE := 0.55
const RUN_SPEED_FACTOR := 0.03

## Paralyze (GDD 05): chance to lose the turn on each own turn.
const PARALYZE_LOSE_TURN_CHANCE := 0.5
## Stun diminishing returns (GDD 05): every new stun in a chain loses 1 stack per
## stun already in the chain; the chain resets after this many own turns free of Stun.
const STUN_CHAIN_RESET_TURNS := 2

## Hit feel (GDD 03): hit-stop freeze and the random slow-mo on critical hits.
const HIT_STOP_SECONDS := 0.07
const CRIT_HIT_STOP_SECONDS := 0.14
const CRIT_SLOWMO_CHANCE := 0.5
const CRIT_SLOWMO_SCALE := 0.25
const CRIT_SLOWMO_SECONDS := 0.45


static func lucky_chance(luck: float) -> float:
	return minf(luck * LUCK_PER_POINT, LUCK_CAP)
