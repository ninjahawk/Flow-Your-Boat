class_name Gate
extends Node2D
# Tap to toggle routing direction: LEFT (-1) or RIGHT (+1).
# Visually shows an arrow and glows when an item is approaching.

signal toggled(gate: Gate)

var direction: int = -1   # -1 = left, +1 = right
var lane_index: int = 0
var gate_width: float = 120.0
var gate_height: float = 54.0

# Visual state
var _is_active: bool = false   # item is nearby
var _flip_anim: float = 0.0    # 0=done, >0 animating
var _flip_dir: float = 1.0     # which direction the flip goes

const CORNER_R   := 14.0
const ARROW_HALF := 16.0

func _ready() -> void:
	add_to_group("gates")

func _toggle() -> void:
	direction = -direction
	_flip_anim = 1.0
	_flip_dir  = float(direction)
	toggled.emit(self)
	queue_redraw()
	if OS.get_name() == "Android":
		Input.vibrate_handheld(30)

func set_active(active: bool) -> void:
	if _is_active != active:
		_is_active = active
		queue_redraw()

func _process(delta: float) -> void:
	if _flip_anim > 0.0:
		_flip_anim = maxf(_flip_anim - delta * 7.0, 0.0)
		queue_redraw()

func _draw() -> void:
	var bg := Palette.GATE_ACTIVE_BG if _is_active else Palette.GATE_BG
	var rect := Rect2(-gate_width * 0.5, -gate_height * 0.5, gate_width, gate_height)

	# Background
	Palette.draw_rrect(self, rect, CORNER_R, bg)

	# Border glow when active
	if _is_active:
		Palette.draw_rrect_outline(self, rect, CORNER_R, Color(0.8, 0.85, 1.0, 0.45), 2.0)

	# Arrow: draw as two lines forming a chevron
	# Flip animation: scale x from -1 to 1 during transition
	var arrow_scale_x := 1.0
	if _flip_anim > 0.0:
		# Goes from 1 → 0 → -1 then snaps back
		arrow_scale_x = 1.0 - _flip_anim * 2.0
		if arrow_scale_x < -1.0:
			arrow_scale_x = -1.0

	var tip := Vector2(ARROW_HALF * float(direction) * arrow_scale_x, 0.0)
	var wing_top := Vector2(-ARROW_HALF * float(direction) * arrow_scale_x, -ARROW_HALF * 0.65)
	var wing_bot := Vector2(-ARROW_HALF * float(direction) * arrow_scale_x, ARROW_HALF * 0.65)

	var arrow_color := Color.WHITE
	arrow_color.a = 0.85 if not _is_active else 1.0
	draw_line(wing_top, tip, arrow_color, 3.0, true)
	draw_line(wing_bot, tip, arrow_color, 3.0, true)

	# Direction label (small L / R text for clarity)
	var label := "L" if direction == -1 else "R"
	var font := ThemeDB.fallback_font
	var label_color := Palette.SUBTEXT_COLOR
	label_color.a = 0.55
	draw_string(font, Vector2(-5.0, gate_height * 0.5 - 6.0), label,
		HORIZONTAL_ALIGNMENT_CENTER, -1, 14, label_color)
