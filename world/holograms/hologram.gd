class_name Hologram
extends CharacterBody2D
## A roaming enemy hologram (GDD 01). Wanders near home, chases the player
## inside its detect radius, gives up past the give-up radius, and starts a
## battle on contact. Hitting it first with a swing gives the party a first
## strike; catching the player from behind gives the enemies one.

enum State { WANDER, CHASE, RETURN, STUNNED }

@export var encounter: EncounterData
## Unique id so a beaten hologram stays gone. Empty = the node name.
@export var hologram_id: StringName
@export var detect_radius := 64.0
@export var give_up_radius := 120.0
## How far from home it wanders, and how far it follows before turning back.
@export var leash_radius := 56.0
@export var max_chase_distance := 200.0
@export var wander_speed := 20.0
@export var chase_speed := 44.0
## Stationary holograms (bosses) wait at home until the player comes close.
@export var stationary := false

const ARRIVE_DISTANCE := 3.0
const ALERT_SECONDS := 0.6

var state := State.WANDER

var _home := Vector2.ZERO
var _wander_target := Vector2.ZERO
var _pause := 0.0
var _stun := 0.0
var _alert := 0.0
var _time := 0.0
var _player: Player

@onready var _visual: Node2D = $Visual
@onready var _contact: Area2D = $ContactArea


func _ready() -> void:
	if hologram_id.is_empty():
		hologram_id = StringName(name)
	if GameState.is_hologram_cleared(hologram_id):
		queue_free()
		return
	_home = global_position
	_wander_target = _home
	_pause = randf_range(0.2, 1.2)
	_time = randf() * TAU
	_contact.body_entered.connect(_on_contact)
	_visual.draw.connect(_draw_visual)
	_fit_contact_to_body()


func _physics_process(delta: float) -> void:
	_time += delta
	_alert = maxf(_alert - delta, 0.0)
	if _player == null:
		_player = get_tree().get_first_node_in_group(&"player") as Player

	match state:
		State.WANDER:
			_wander(delta)
			if _sees_player():
				_start_chase()
		State.CHASE:
			_move_toward(_player.global_position, chase_speed)
			var too_far := global_position.distance_to(_player.global_position) > give_up_radius
			var off_leash := global_position.distance_to(_home) > max_chase_distance
			if too_far or off_leash or _player.is_invulnerable():
				state = State.RETURN
		State.RETURN:
			_move_toward(_home, wander_speed * 1.5)
			if global_position.distance_to(_home) <= ARRIVE_DISTANCE:
				state = State.WANDER
			elif _sees_player() and global_position.distance_to(_home) < max_chase_distance * 0.5:
				_start_chase()
		State.STUNNED:
			velocity = Vector2.ZERO
			_stun -= delta
			if _stun <= 0.0:
				state = State.RETURN
	move_and_slide()
	_visual.position.y = roundf(sin(_time * 3.0) * 1.5) - 2.0
	_visual.queue_redraw()


## The player's swing landed first (GDD 01, "First strike").
func on_struck(_by: Player) -> void:
	if state == State.STUNNED:
		return
	EventBus.encounter_requested.emit(self, EncounterData.Advantage.PARTY)


## After an escape: frozen for a moment so the player can walk away.
func stun(seconds: float) -> void:
	state = State.STUNNED
	_stun = seconds


func defeat() -> void:
	set_physics_process(false)
	_contact.set_deferred("monitoring", false)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)


func _on_contact(body: Node2D) -> void:
	if not body is Player or state == State.STUNNED:
		return
	var player := body as Player
	if player.is_invulnerable():
		return
	if player.is_swinging():
		on_struck(player)
		return
	var advantage := EncounterData.Advantage.ENEMY if player.is_behind(global_position) else EncounterData.Advantage.NEUTRAL
	EventBus.encounter_requested.emit(self, advantage)


func _wander(delta: float) -> void:
	if stationary:
		velocity = Vector2.ZERO
		return
	if _pause > 0.0:
		_pause -= delta
		velocity = Vector2.ZERO
		return
	_move_toward(_wander_target, wander_speed)
	if global_position.distance_to(_wander_target) <= ARRIVE_DISTANCE or get_slide_collision_count() > 0:
		_pause = randf_range(0.6, 1.8)
		_wander_target = _home + Vector2.from_angle(randf() * TAU) * randf_range(8.0, leash_radius)


func _move_toward(point: Vector2, move_speed: float) -> void:
	var to_point := point - global_position
	velocity = Vector2.ZERO if to_point.length() <= ARRIVE_DISTANCE else to_point.normalized() * move_speed


func _sees_player() -> bool:
	return _player != null and not _player.is_invulnerable() \
		and global_position.distance_to(_player.global_position) <= detect_radius


## Bigger monsters get a bigger touch area. The shape is shared between
## instances in the scene file, so each hologram works on its own copy.
func _fit_contact_to_body() -> void:
	if encounter == null or encounter.leader() == null:
		return
	var body_size := Vector2(encounter.leader().overworld_size)
	var shape_node := _contact.get_node("Shape") as CollisionShape2D
	var rect := shape_node.shape.duplicate() as RectangleShape2D
	rect.size = body_size * 0.85
	shape_node.shape = rect
	_contact.position.y = -body_size.y / 2.0


func _start_chase() -> void:
	state = State.CHASE
	_alert = ALERT_SECONDS


func _draw() -> void:
	# Ground shadow, drawn without the hologram shader.
	var width := 12.0
	if encounter and encounter.leader():
		width = encounter.leader().overworld_size.x * 0.8
	draw_rect(Rect2(-width / 2.0, -2, width, 3), Color(0, 0, 0, 0.22))


func _draw_visual() -> void:
	if encounter == null or encounter.leader() == null:
		return
	var leader := encounter.leader()
	var body_size := Vector2(leader.overworld_size)
	var rect := Rect2(Vector2(-body_size.x / 2.0, -body_size.y), body_size)
	var expression := &"surprised" if _alert > 0.0 else &"happy"
	PlaceholderArt.draw_creature(_visual, rect, leader.color, leader.placeholder_shape, expression)
	if encounter.enemies.size() > 1:
		# A small "+" tag means the hologram holds a group.
		_visual.draw_rect(Rect2(rect.end.x - 1, rect.position.y - 1, 5, 1), Color.WHITE)
		_visual.draw_rect(Rect2(rect.end.x + 1, rect.position.y - 3, 1, 5), Color.WHITE)
	if _alert > 0.0:
		var top := Vector2(0, rect.position.y - 10)
		_visual.draw_rect(Rect2(top + Vector2(-1, 0), Vector2(2, 5)), Color.WHITE)
		_visual.draw_rect(Rect2(top + Vector2(-1, 6), Vector2(2, 2)), Color.WHITE)
