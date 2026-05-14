class_name Background
extends Node2D

const DOT_COLS    := 12
const DOT_ROWS    := 22
const DOT_R       := 1.5

var _t       := 0.0
var _dots    : Array = []

# Game-state-driven parameters (set by Main each frame)
var combo_heat:    float = 0.0   # 0-1, hot at high combo
var danger_heat:   float = 0.0   # 0-1, any bin near overflow
var level_speed:   float = 1.0   # multiplier based on level

func _ready() -> void:
	randomize()
	var w := 540.0
	var h := 960.0
	for row in range(DOT_ROWS):
		for col in range(DOT_COLS):
			_dots.append({
				"bx":    (col + 0.5) * (w / DOT_COLS),
				"by":    (row + 0.5) * (h / DOT_ROWS),
				"phase": randf() * TAU,
				"speed": randf_range(0.3, 1.0),
			})

func _process(delta: float) -> void:
	_t += delta * level_speed
	queue_redraw()

func _draw() -> void:
	for d in _dots:
		var drift := 6.0 + combo_heat * 4.0 + danger_heat * 3.0
		var drift_speed := 0.04 + combo_heat * 0.03
		var px : float = d["bx"] + sin(_t * drift_speed * d["speed"] + d["phase"]) * drift
		var py : float = d["by"] + cos(_t * drift_speed * d["speed"] * 0.8 + d["phase"] * 1.3) * (drift * 0.65)

		# Base brightness rises with combo/danger
		var base_bright := 0.07 + combo_heat * 0.08 + danger_heat * 0.06
		var brightness  := base_bright + 0.05 * sin(_t * 0.6 * d["speed"] + d["phase"])

		# Color shifts: normal=blue, combo=warm gold, danger=red
		var r := brightness * (0.55 + combo_heat * 0.9 + danger_heat * 1.2)
		var g := brightness * (0.65 + combo_heat * 0.55 - danger_heat * 0.3)
		var b := brightness * 1.15

		draw_circle(Vector2(px, py), DOT_R + combo_heat * 0.8, Color(r, g, b))
