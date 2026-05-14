class_name Bin
extends Node2D

signal overflowed(bin_index: int)

var color_id:   int   = 0
var bin_index:  int   = 0
var bin_width:  float = 110.0
var bin_height: float = 90.0

# ---- Pressure ----
var pressure:    float = 0.0
var is_disabled: bool  = false
var _disable_timer: float = 0.0
const DISABLE_DURATION  := 8.0
const PRESSURE_PER_SORT := 0.13
const PRESSURE_DRAIN    := 0.007
const OVERFLOW_THRESHOLD := 1.0
const DRAIN_ITEM_AMOUNT  := 0.45

# ---- Visual animation state ----
var _pulse:    float = 0.0
var _pulse_ok: bool  = true
var _shake_x:  float = 0.0
var _shake_t:  float = 0.0
var _fill_anim:float = 0.0   # brief fill flash on receive
var _t:        float = 0.0   # for TIME-like shader effects in _draw

func _ready() -> void:
	add_to_group("flow_bins")
	_shake_x = position.x   # must match actual x; default 0 was resetting all bins

func _process(delta: float) -> void:
	_t += delta
	var dirty := false

	if not is_disabled and pressure > 0.0:
		pressure = maxf(pressure - PRESSURE_DRAIN * delta, 0.0)
		dirty = true

	if is_disabled:
		_disable_timer -= delta
		if _disable_timer <= 0.0:
			is_disabled = false
			dirty = true
		else:
			dirty = true  # redraw every frame for countdown

	if _pulse > 0.0:
		_pulse = maxf(_pulse - delta * 4.0, 0.0)
		dirty = true

	if _fill_anim > 0.0:
		_fill_anim = maxf(_fill_anim - delta * 3.5, 0.0)
		dirty = true

	if _shake_t > 0.0:
		_shake_t -= delta
		position.x = _shake_x + sin(_shake_t * 55.0) * _shake_t * 7.0
		dirty = true
	elif position.x != _shake_x:
		position.x = _shake_x
		dirty = true

	# Animate danger border when pressure is high
	if pressure > 0.65:
		dirty = true

	if dirty:
		queue_redraw()

func _draw() -> void:
	var col := Palette.ITEM_COLORS[color_id]
	var hw     := bin_width  * 0.5
	var hh     := bin_height * 0.5
	var rect   := Rect2(-hw, -hh, bin_width, bin_height)
	const CR   := 16.0

	# ---- Background ----
	var bg_base := Color(0.22, 0.23, 0.36)
	var bg := bg_base.lerp(Color(bg_base.r + col.r*0.12, bg_base.g + col.g*0.12, bg_base.b + col.b*0.12), 1.0)
	if is_disabled:
		bg = bg.darkened(0.65)
	Palette.draw_rrect(self, rect, CR, bg)

	# ---- Pressure fill (from bottom) ----
	if pressure > 0.0 and not is_disabled:
		var fill_h := bin_height * pressure
		var fill_rect := Rect2(-hw, hh - fill_h, bin_width, fill_h)
		var fill_col := col.darkened(0.45)
		if pressure > 0.65:
			var danger := (pressure - 0.65) / 0.35
			var blink := sin(_t * 9.0) * 0.5 + 0.5
			fill_col = fill_col.lerp(Color(0.9, 0.12, 0.05), danger * blink)
		Palette.draw_rrect(self, fill_rect, minf(CR, fill_h * 0.5), fill_col)

	# ---- Fill flash (success receive) ----
	if _fill_anim > 0.0 and not is_disabled:
		var fc := col
		fc.a = _fill_anim * 0.35
		Palette.draw_rrect(self, rect, CR, fc)

	# ---- Color swatch circle ----
	var cr_r := minf(bin_width, bin_height) * 0.24
	var swatch_pos := Vector2(0.0, bin_height * 0.06)
	if not is_disabled:
		draw_circle(swatch_pos, cr_r, col)
		# Swatch highlight
		var hl := Color(1.0, 1.0, 1.0, 0.25)
		draw_circle(swatch_pos + Vector2(-cr_r*0.28, -cr_r*0.32), cr_r * 0.4, hl)
	else:
		draw_circle(swatch_pos, cr_r, col.darkened(0.7))

	# ---- Border ----
	var bw := 3.0
	var bc := col
	if pressure > 0.65 and not is_disabled:
		bw = 4.5 + sin(_t * 9.0) * 1.5
		var danger := (pressure - 0.65) / 0.35
		bc = col.lerp(Color(1.0, 0.12, 0.05), danger * (sin(_t * 9.0) * 0.5 + 0.5))
	var border_a := 0.88 + _pulse * 0.12
	if is_disabled:
		border_a = 0.25
	var border_col := bc
	border_col.a = border_a
	Palette.draw_rrect_outline(self, rect, CR, border_col, bw)

	# ---- Pulse flash ----
	if _pulse > 0.0:
		var fc2 := Color(1.0, 0.12, 0.12) if not _pulse_ok else Color(1.0, 1.0, 1.0)
		fc2.a = _pulse * 0.22
		Palette.draw_rrect(self, rect, CR, fc2)

	# ---- Disabled countdown ----
	if is_disabled and _disable_timer > 0.0:
		var secs_left : int = int(ceilf(_disable_timer))
		var font      := ThemeDB.fallback_font
		var warn      := secs_left <= 3 and sin(_t * 8.0) > 0.0
		var cd_col    := Color(1.0, 0.28, 0.28) if warn else Color(1.0, 1.0, 1.0, 0.55)
		draw_string(font,
			Vector2(-bin_width * 0.5, bin_height * 0.25),
			str(secs_left),
			HORIZONTAL_ALIGNMENT_CENTER, bin_width, 30, cd_col)

# ================================================================
#  PUBLIC API
# ================================================================

func receive_item(item_color_id: int, is_drain: bool = false) -> bool:
	if is_disabled:
		return false
	var success := item_color_id == color_id
	if success:
		if is_drain:
			pressure = maxf(pressure - DRAIN_ITEM_AMOUNT, 0.0)
		else:
			pressure = minf(pressure + PRESSURE_PER_SORT, OVERFLOW_THRESHOLD)
		_pulse     = 1.0
		_pulse_ok  = true
		_fill_anim = 1.0
	else:
		pressure   = minf(pressure + 0.04, OVERFLOW_THRESHOLD)
		_pulse     = 1.0
		_pulse_ok  = false
		_shake_x   = position.x
		_shake_t   = 0.3
	if pressure >= OVERFLOW_THRESHOLD:
		_trigger_overflow()
	queue_redraw()
	return success

func _trigger_overflow() -> void:
	pressure       = 0.0
	is_disabled    = true
	_disable_timer = DISABLE_DURATION
	overflowed.emit(bin_index)
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(1.5, 0.3, 0.3), 0.08)
	tw.tween_property(self, "modulate", Color(1.0, 1.0, 1.0), 0.45)

func update_color(new_color_id: int) -> void:
	color_id = new_color_id
	queue_redraw()
