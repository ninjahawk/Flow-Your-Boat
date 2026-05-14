class_name Bin
extends Node2D
# Receives items routed by gates. Checks color match and plays feedback.

var color_id: int = 0
var bin_index: int = 0
var bin_width: float = 110.0
var bin_height: float = 90.0

const CORNER_R := 16.0
const SWATCH_SIZE := 28.0

# Animation state
var _pulse: float = 0.0
var _pulse_success: bool = true
var _fill: float = 0.0        # 0→1 fill animation on receive
var _shake_offset: Vector2 = Vector2.ZERO
var _shake_timer: float = 0.0

func receive_item(item_color_id: int) -> bool:
	var success := item_color_id == color_id
	_pulse = 1.0
	_pulse_success = success
	if success:
		_fill = 1.0
	else:
		_shake_timer = 0.3
	return success

func _process(delta: float) -> void:
	var dirty := false

	if _pulse > 0.0:
		_pulse = maxf(_pulse - delta * 4.5, 0.0)
		dirty = true

	if _fill > 0.0:
		_fill = maxf(_fill - delta * 3.0, 0.0)
		dirty = true

	if _shake_timer > 0.0:
		_shake_timer -= delta
		_shake_offset = Vector2(
			randf_range(-5.0, 5.0),
			randf_range(-3.0, 3.0)
		) * (_shake_timer / 0.3)
		dirty = true
	else:
		if _shake_offset != Vector2.ZERO:
			_shake_offset = Vector2.ZERO
			dirty = true

	if dirty:
		queue_redraw()

func _draw() -> void:
	var base_color := Palette.ITEM_COLORS[color_id]
	var rect := Rect2(
		-bin_width * 0.5 + _shake_offset.x,
		-bin_height * 0.5 + _shake_offset.y,
		bin_width, bin_height
	)

	# Background
	Palette.draw_rrect(self, rect, CORNER_R, Palette.GATE_BG)

	# Fill animation (success flash from bottom)
	if _fill > 0.0:
		var fill_h := bin_height * _fill
		var fill_rect := Rect2(
			rect.position.x,
			rect.position.y + bin_height - fill_h,
			bin_width,
			fill_h
		)
		var fill_color := base_color
		fill_color.a = _fill * 0.45
		Palette.draw_rrect(self, fill_rect, CORNER_R, fill_color)

	# Border — pulses on receive
	var border_color := base_color
	if _pulse > 0.0:
		border_color = Color.WHITE.lerp(base_color, 1.0 - _pulse * 0.7) if _pulse_success else Color(1.0, 0.2, 0.2).lerp(base_color, 1.0 - _pulse * 0.6)
		border_color.a = 0.5 + _pulse * 0.5
	else:
		border_color.a = 0.55
	Palette.draw_rrect_outline(self, rect, CORNER_R, border_color, 2.5)

	# Color swatch (circle)
	var swatch_center := Vector2(_shake_offset.x, _shake_offset.y - 10.0)
	draw_circle(swatch_center, SWATCH_SIZE * 0.5, base_color)
	# Highlight on swatch
	var hl := Color.WHITE
	hl.a = 0.22
	draw_circle(swatch_center + Vector2(-3.0, -4.0), SWATCH_SIZE * 0.22, hl)

	# Color name label
	var label := Palette.ITEM_NAMES[color_id].to_upper()
	var font := ThemeDB.fallback_font
	var label_color := Color.WHITE
	label_color.a = 0.65
	draw_string(font, Vector2(-bin_width * 0.5 + _shake_offset.x, _shake_offset.y + bin_height * 0.5 - 12.0),
		label, HORIZONTAL_ALIGNMENT_CENTER, bin_width, 13, label_color)
