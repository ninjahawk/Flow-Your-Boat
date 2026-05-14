class_name FlowItem
extends Node2D
# A single colored block that falls through a lane and gets routed to a bin.

signal reached_gate(item: FlowItem)
signal reached_bin(item: FlowItem, bin_index: int)

var color_id: int = 0
var lane_index: int = 0
var fall_speed: float = 250.0
var gate_y: float = 680.0
var bin_y: float = 800.0
var target_bin_index: int = -1

const ITEM_SIZE := Vector2(72.0, 62.0)
const CORNER_R  := 14.0

# Internal state
var _state: int = 0  # 0=falling, 1=routing, 2=done
var _scale_anim: float = 0.0     # 0→1 spawn scale-in
var _pulse: float = 0.0          # success/fail flash
var _pulse_success: bool = true
var _approach_glow: float = 0.0  # brightens as item nears gate

func _ready() -> void:
	_scale_anim = 0.0
	z_index = 10

func _process(delta: float) -> void:
	# Spawn scale-in
	if _scale_anim < 1.0:
		_scale_anim = minf(_scale_anim + delta * 6.0, 1.0)
		scale = Vector2.ONE * _scale_anim

	# Approach glow ramps up in the 200px above gate
	var dist_to_gate := gate_y - position.y
	if dist_to_gate < 200.0 and dist_to_gate > 0.0:
		_approach_glow = 1.0 - (dist_to_gate / 200.0)
	else:
		_approach_glow = 0.0

	# Pulse decay
	if _pulse > 0.0:
		_pulse = maxf(_pulse - delta * 4.0, 0.0)

	queue_redraw()

	match _state:
		0:  # falling
			position.y += fall_speed * delta
			if position.y >= gate_y:
				_state = 1
				reached_gate.emit(self)

		1:  # routing — x tween handled by Main, y still falls
			position.y += fall_speed * delta
			if position.y >= bin_y and target_bin_index >= 0:
				_state = 2
				reached_bin.emit(self, target_bin_index)

func set_target_bin_x(target_x: float, bin_index: int) -> void:
	target_bin_index = bin_index
	# Tween x to target over the fall time remaining to bin_y
	var fall_time := (bin_y - gate_y) / fall_speed
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "position:x", target_x, fall_time * 0.9)

func play_success() -> void:
	_pulse = 1.0
	_pulse_success = true
	queue_redraw()

func play_fail() -> void:
	_pulse = 1.0
	_pulse_success = false
	queue_redraw()

func _draw() -> void:
	var base_color := Palette.ITEM_COLORS[color_id]
	var glow_color := Palette.GLOW_COLORS[color_id]

	# Outer glow shadow (larger rect, very low alpha)
	if _approach_glow > 0.0:
		var glow_rect := Rect2(
			-ITEM_SIZE * 0.5 - Vector2(8, 8),
			ITEM_SIZE + Vector2(16, 16)
		)
		var gc := glow_color
		gc.a = _approach_glow * 0.35
		Palette.draw_rrect(self, glow_rect, CORNER_R + 6.0, gc)

	# Pulse flash overlay
	var draw_color := base_color
	if _pulse > 0.0:
		var flash := Color.WHITE if _pulse_success else Color(1.0, 0.2, 0.2)
		draw_color = base_color.lerp(flash, _pulse * 0.6)

	# Main body
	var rect := Rect2(-ITEM_SIZE * 0.5, ITEM_SIZE)
	Palette.draw_rrect(self, rect, CORNER_R, draw_color)

	# Inner highlight (top strip)
	var highlight_rect := Rect2(
		-ITEM_SIZE.x * 0.5 + 6.0,
		-ITEM_SIZE.y * 0.5 + 5.0,
		ITEM_SIZE.x - 12.0,
		ITEM_SIZE.y * 0.28
	)
	var highlight := Color.WHITE
	highlight.a = 0.18
	Palette.draw_rrect(self, highlight_rect, 7.0, highlight)
