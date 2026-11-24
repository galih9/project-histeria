class_name Wind
extends Node
## The wind for one map section: a direction and a strength that the grass
## shader follows and that any gameplay code can read. Put one Wind node in
## each map scene.
##
## Read it from anywhere:
##   Wind.get_direction()        unit Vector2, where the wind blows TO
##   Wind.get_strength()         0..1
##   Wind.gust_at(world_pos)     0..1, the same gust wave the grass shows there
##   Wind.force_at(world_pos)    direction * (steady + gust), handy for leaves,
##                               particles, smoke, cloth
## Change it from anywhere:
##   Wind.current.blow(180.0, 0.9, 3.0)   # turn west, stronger, over 3 seconds

signal wind_changed(direction: Vector2, strength: float)

const GRASS_MATERIAL := preload("res://world/grass/grass_material.tres")
## Darker strokes that slide over flat grass tiles (see wind_streaks.gdshader).
const STREAK_MATERIAL := preload("res://world/grass/wind_streaks_material.tres")
## Cloud shadows over the map (see world/weather/cloud_shadows.gd).
const CLOUD_MATERIAL := preload("res://world/weather/cloud_shadows_material.tres")
## How the bend splits up: steady lean, gusts, and the back-and-forth sway.
const STEADY_SHARE := 0.25
const GUST_SHARE := 0.75
const SWAY_SHARE := 0.5

static var current: Wind

## Where the wind blows TO, in degrees: 0 = right (east), 90 = down (south),
## 180 = left (west), 270 = up (north).
@export_range(0.0, 360.0, 1.0, "degrees") var direction_degrees := 15.0:
	set(value):
		direction_degrees = value
		_announce()
@export_range(0.0, 1.0, 0.01) var strength := 0.7:
	set(value):
		strength = value
		_announce()

@export_group("Gusts")
## How fast gust waves roll across the ground at full strength, in px per second.
@export var gust_speed := 70.0
## Distance between gust waves, in px.
@export var gust_size := 120.0
## 0 = steady breeze only, 1 = normal gusts, 2 = stormy.
@export_range(0.0, 2.0, 0.05) var gustiness := 1.0

@export_group("Natural drift")
## The direction slowly swings this many degrees each way.
@export_range(0.0, 90.0, 1.0) var wander_degrees := 10.0
## Seconds for one full swing.
@export var wander_seconds := 30.0

@export_group("Grass")
## How far a blade tip leans at full strength in a full gust, in px.
@export_range(0.0, 13.0, 0.5) var max_bend_px := 12.0
## Speed of the left-right sway, in radians per second (2.6 = one swing every ~2.4 s).
@export var sway_speed := 2.6
@export var flutter_px := 0.8
@export var flutter_speed := 6.0
## The player parts the grass inside this radius (px, measured from the feet).
@export var push_radius := 14.0
@export var push_bend_px := 6.0

@export_group("Clouds")
## How fast cloud shadows drift downwind at full strength, in px per second.
@export var cloud_speed := 18.0
## Drift speed with no wind, as a share of cloud_speed (high clouds still move).
@export_range(0.0, 1.0, 0.05) var cloud_calm_share := 0.3

var _time := 0.0
var _phase := 0.0
var _dir := Vector2.RIGHT
var _cloud_offset := Vector2.ZERO
var _blend: Tween


func _enter_tree() -> void:
	current = self


func _exit_tree() -> void:
	if current == self:
		current = null


func _ready() -> void:
	_time = randf() * 100.0
	_update_direction()
	_push_to_shader()


func _process(delta: float) -> void:
	_time += delta
	_phase += gust_speed * lerpf(0.35, 1.0, strength) * delta
	var set_dir := Vector2.from_angle(deg_to_rad(direction_degrees))
	_cloud_offset += set_dir * cloud_speed * lerpf(cloud_calm_share, 1.0, strength) * delta
	_update_direction()
	_push_to_shader()


## Change the wind smoothly. `seconds` = 0 changes it at once.
func blow(degrees: float, new_strength: float, seconds := 2.0) -> void:
	if _blend:
		_blend.kill()
	if seconds <= 0.0:
		direction_degrees = fposmod(degrees, 360.0)
		strength = clampf(new_strength, 0.0, 1.0)
		return
	var from_deg := direction_degrees
	var to_deg := from_deg + wrapf(degrees - from_deg, -180.0, 180.0)
	_blend = create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	_blend.tween_method(func(d: float) -> void: direction_degrees = fposmod(d, 360.0), from_deg, to_deg, seconds)
	_blend.tween_property(self, "strength", clampf(new_strength, 0.0, 1.0), seconds)


static func get_direction() -> Vector2:
	return current._dir if is_instance_valid(current) else Vector2.RIGHT


static func get_strength() -> float:
	return current.strength if is_instance_valid(current) else 0.0


## 0 = calm, 1 = full gust at this world position. Mirrors gust_at() in
## grass_sway.gdshader, so what you read here matches what the grass shows.
static func gust_at(world_pos: Vector2) -> float:
	if not is_instance_valid(current):
		return 0.0
	var dir := current._dir
	var perp := Vector2(-dir.y, dir.x)
	var a := (world_pos.dot(dir) - current._phase) / current.gust_size
	var b := world_pos.dot(perp) / current.gust_size
	var w := sin(a * TAU + sin(b * 2.1 + current._time * 0.23) * 1.6) * 0.65 \
			+ sin(a * TAU * 0.53 - b * 1.3 + 1.7) * 0.35
	return smoothstep(0.2, 0.95, w * 0.5 + 0.5)


## Wind push at a world position: direction scaled by strength, steady part plus gust.
static func force_at(world_pos: Vector2) -> Vector2:
	if not is_instance_valid(current):
		return Vector2.ZERO
	var gust := gust_at(world_pos) * current.gustiness
	return current._dir * current.strength * (STEADY_SHARE + GUST_SHARE * gust)


func _update_direction() -> void:
	var drift := 0.0
	if wander_seconds > 0.0:
		drift = sin(_time * TAU / wander_seconds) * wander_degrees
	_dir = Vector2.from_angle(deg_to_rad(direction_degrees + drift))


func _push_to_shader() -> void:
	var m := GRASS_MATERIAL
	m.set_shader_parameter(&"wind_dir", _dir)
	m.set_shader_parameter(&"wind_phase", _phase)
	m.set_shader_parameter(&"wind_time", _time)
	m.set_shader_parameter(&"wind_strength", strength)
	m.set_shader_parameter(&"gust_size", gust_size)
	m.set_shader_parameter(&"base_bend", max_bend_px * strength * STEADY_SHARE)
	m.set_shader_parameter(&"gust_bend", max_bend_px * strength * GUST_SHARE * gustiness)
	m.set_shader_parameter(&"sway_px", max_bend_px * strength * SWAY_SHARE)
	m.set_shader_parameter(&"sway_speed", sway_speed)
	# Flutter fades out with the wind, so strength 0 means perfectly still grass.
	m.set_shader_parameter(&"flutter_px", flutter_px * clampf(strength * 2.0, 0.0, 1.0))
	m.set_shader_parameter(&"flutter_speed", flutter_speed)
	m.set_shader_parameter(&"push_radius", push_radius)
	m.set_shader_parameter(&"push_bend", push_bend_px)
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	var feet := player.global_position if player else Vector2(-100000.0, -100000.0)
	m.set_shader_parameter(&"pusher_pos", feet)

	var s := STREAK_MATERIAL
	s.set_shader_parameter(&"wind_dir", _dir)
	s.set_shader_parameter(&"band_dir", Vector2.from_angle(deg_to_rad(direction_degrees)))
	s.set_shader_parameter(&"wind_phase", _phase)
	s.set_shader_parameter(&"wind_time", _time)
	s.set_shader_parameter(&"wind_strength", strength)
	s.set_shader_parameter(&"gust_size", gust_size)
	s.set_shader_parameter(&"gustiness", gustiness)

	var c := CLOUD_MATERIAL
	c.set_shader_parameter(&"cloud_offset", _cloud_offset)
	c.set_shader_parameter(&"cloud_time", _time)


func _announce() -> void:
	if is_node_ready():
		_update_direction()
		wind_changed.emit(_dir, strength)
