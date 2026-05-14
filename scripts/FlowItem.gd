class_name FlowItem
extends Node2D

signal reached_gate(item: FlowItem)
signal reached_bin(item: FlowItem, bin_index: int)

# ---- Item types ----
enum Type { NORMAL, RUSH, BOMB, DRAIN }

# ---- Config (set before adding to scene) ----
var color_id:   int   = 0
var lane_index: int   = 0
var fall_speed: float = 250.0
var gate_y:     float = 692.0
var bin_y:      float = 812.0
var item_type:  int   = Type.NORMAL

# ---- Internal state ----
var _state:          int   = 0    # 0=falling 1=routing 2=done
var _target_bin_idx: int   = -1
var _approach:       float = 0.0
var _pulse:          float = 0.0
var _pulse_ok:       bool  = true
var _spawn_t:        float = 0.0  # 0→1 scale-in

# ---- Nodes ----
var _visual:    ColorRect
var _mat:       ShaderMaterial
var _trail:     Line2D
var _trail_pts: int = 0

const ITEM_SIZE  := Vector2(72.0, 62.0)
const CORNER_R   := 12.0
const TRAIL_LEN  := 10
const TRAIL_GAP  := 8.0   # pixels between trail points

const ITEM_SHADER := preload("res://shaders/item.gdshader")

func _ready() -> void:
	z_index = 10
	_build_visual()
	_build_trail()

# ================================================================
#  VISUAL SETUP
# ================================================================

func _build_visual() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = ITEM_SHADER
	_mat.set_shader_parameter("item_color",  Palette.ITEM_COLORS[color_id])
	_mat.set_shader_parameter("item_size",   ITEM_SIZE)
	_mat.set_shader_parameter("corner_r",    CORNER_R)
	_mat.set_shader_parameter("item_type",   float(item_type))
	_mat.set_shader_parameter("approach",    0.0)
	_mat.set_shader_parameter("flash",       0.0)
	_mat.set_shader_parameter("flash_ok",    1.0)

	_visual = ColorRect.new()
	_visual.size     = ITEM_SIZE
	_visual.position = -ITEM_SIZE * 0.5
	_visual.material = _mat
	add_child(_visual)

func _build_trail() -> void:
	_trail = Line2D.new()
	_trail.width            = 5.0
	_trail.width_curve      = _make_taper_curve()
	_trail.begin_cap_mode   = Line2D.LINE_CAP_ROUND
	_trail.end_cap_mode     = Line2D.LINE_CAP_ROUND
	_trail.z_index          = -1

	var col := Palette.ITEM_COLORS[color_id]
	var grad := Gradient.new()
	grad.set_color(0, Color(col.r, col.g, col.b, 0.0))
	grad.set_color(1, Color(col.r, col.g, col.b, 0.50))
	_trail.gradient = grad
	add_child(_trail)

func _make_taper_curve() -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.0))
	c.add_point(Vector2(0.6, 0.5))
	c.add_point(Vector2(1.0, 1.0))
	return c

# ================================================================
#  PROCESS
# ================================================================

func _process(delta: float) -> void:
	# Spawn scale-in
	if _spawn_t < 1.0:
		_spawn_t = minf(_spawn_t + delta * 7.0, 1.0)
		scale = Vector2.ONE * _ease_out(_spawn_t)

	# Approach glow
	var dist := gate_y - position.y
	var new_approach := clampf(1.0 - dist / 200.0, 0.0, 1.0) if dist > 0.0 else 0.0
	if absf(new_approach - _approach) > 0.005:
		_approach = new_approach
		_mat.set_shader_parameter("approach", _approach)

	# Pulse decay
	if _pulse > 0.0:
		_pulse = maxf(_pulse - delta * 4.5, 0.0)
		_mat.set_shader_parameter("flash", _pulse)

	# Trail update
	_update_trail()

	match _state:
		0:  # falling
			position.y += fall_speed * delta
			if position.y >= gate_y:
				_state = 1
				reached_gate.emit(self)
		1:  # routing (x tween active, y still falls)
			position.y += fall_speed * delta
			if position.y >= bin_y and _target_bin_idx >= 0:
				_state = 2
				reached_bin.emit(self, _target_bin_idx)

func _update_trail() -> void:
	if _state == 2:
		return
	var pts := _trail.get_point_count()
	if pts == 0:
		_trail.add_point(Vector2.ZERO)
		return
	var last: Vector2 = _trail.get_point_position(pts - 1)
	if Vector2.ZERO.distance_to(last) >= TRAIL_GAP:
		_trail.add_point(Vector2.ZERO)  # local — trails behind in parent space
		if _trail.get_point_count() > TRAIL_LEN:
			_trail.remove_point(0)

# ================================================================
#  PUBLIC API
# ================================================================

func set_target_bin_x(target_x: float, bin_index: int) -> void:
	_target_bin_idx = bin_index
	var fall_time := (bin_y - gate_y) / fall_speed
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "position:x", target_x, fall_time * 0.88)

func play_success() -> void:
	_pulse    = 1.0
	_pulse_ok = true
	_mat.set_shader_parameter("flash",    1.0)
	_mat.set_shader_parameter("flash_ok", 1.0)

func play_fail() -> void:
	_pulse    = 1.0
	_pulse_ok = false
	_mat.set_shader_parameter("flash",    1.0)
	_mat.set_shader_parameter("flash_ok", 0.0)

# ================================================================
#  HELPERS
# ================================================================

func _ease_out(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3.0)

func get_item_type_name() -> String:
	match item_type:
		Type.RUSH:  return "RUSH"
		Type.BOMB:  return "BOMB"
		Type.DRAIN: return "DRAIN"
		_:          return "NORMAL"
