class_name BattleBackgroundPreset
extends Resource
## Settings for the EarthBound-style animated background shader (GDD 03).
## One shader, many looks: change the palette and the wave numbers.

@export_group("Palette")
## Four colors, cycled over time from dark to light.
@export var color_a := Color("1b1446")
@export var color_b := Color("5b2a6e")
@export var color_c := Color("d9577a")
@export var color_d := Color("ffa25c")

@export_group("Pattern")
@export var pattern_scale := 6.0
@export var palette_cycle_speed := 0.15
@export var scroll := Vector2(0.01, 0.02)

@export_group("Waves")
## Horizontal wave per line, the classic EarthBound wobble.
@export var wave_x_amplitude := 0.03
@export var wave_x_frequency := 18.0
@export var wave_y_amplitude := 0.01
@export var wave_y_frequency := 9.0
@export var wave_speed := 1.4


func apply_to(material: ShaderMaterial) -> void:
	material.set_shader_parameter("color_a", color_a)
	material.set_shader_parameter("color_b", color_b)
	material.set_shader_parameter("color_c", color_c)
	material.set_shader_parameter("color_d", color_d)
	material.set_shader_parameter("pattern_scale", pattern_scale)
	material.set_shader_parameter("cycle_speed", palette_cycle_speed)
	material.set_shader_parameter("scroll", scroll)
	material.set_shader_parameter("wave_x_amplitude", wave_x_amplitude)
	material.set_shader_parameter("wave_x_frequency", wave_x_frequency)
	material.set_shader_parameter("wave_y_amplitude", wave_y_amplitude)
	material.set_shader_parameter("wave_y_frequency", wave_y_frequency)
	material.set_shader_parameter("wave_speed", wave_speed)
