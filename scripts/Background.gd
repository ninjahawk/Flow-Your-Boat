class_name Background
extends Node2D
# Animated dot-grid background. Subtle depth without distraction.

const DOT_COLS    := 12
const DOT_ROWS    := 22
const DOT_R       := 1.4
const DRIFT_SPEED := 18.0
const PULSE_SPEED := 0.6

var _t        := 0.0
var _dots     : Array = []  # Array of {pos, phase, brightness}

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
				"drift": Vector2(randf_range(-1.0, 1.0), randf_range(-0.3, 0.3)).normalized()
			})

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	for d in _dots:
		var px : float = d["bx"] + sin(_t * DRIFT_SPEED * d["speed"] * 0.04 + d["phase"]) * 6.0
		var py : float = d["by"] + cos(_t * DRIFT_SPEED * d["speed"] * 0.03 + d["phase"] * 1.3) * 4.0
		var brightness : float = 0.08 + 0.06 * sin(_t * PULSE_SPEED * d["speed"] + d["phase"])
		var col := Color(brightness * 0.6, brightness * 0.7, brightness * 1.2)
		draw_circle(Vector2(px, py), DOT_R, col)
