extends Node

var _shake_amount:   float = 0.0
var _shake_timer:    float = 0.0
var _shake_duration: float = 0.001
var _camera: Camera2D = null

func _process(delta: float) -> void:
	if _shake_timer > 0.0:
		_shake_timer -= delta
		var falloff := maxf(_shake_timer / _shake_duration, 0.0)
		var cam := _get_camera()
		if cam != null:
			cam.offset = Vector2(
				randf_range(-_shake_amount, _shake_amount),
				randf_range(-_shake_amount, _shake_amount)
			) * falloff
		if _shake_timer <= 0.0:
			var c := _get_camera()
			if c != null:
				c.offset = Vector2.ZERO

func screen_shake(amount: float, duration: float) -> void:
	_shake_amount   = amount
	_shake_timer    = duration
	_shake_duration = maxf(duration, 0.001)

# ---- High-density particle burst ----
func burst_at(pos: Vector2, color: Color, count: int = 28) -> void:
	var root := get_tree().current_scene
	if root == null:
		return

	# Outer fast burst
	_spawn_cpu_burst(root, pos, color, count, 180.0, 340.0, 0.45, 4.0, 9.0)
	# Inner slow glow puff
	var dim := Color(color.r, color.g, color.b, 0.6)
	_spawn_cpu_burst(root, pos, dim, 10, 40.0, 100.0, 0.7, 6.0, 14.0)

func _spawn_cpu_burst(
		root: Node, pos: Vector2, color: Color,
		count: int, v_min: float, v_max: float,
		lifetime: float, s_min: float, s_max: float) -> void:
	var p := CPUParticles2D.new()
	p.emitting        = true
	p.one_shot        = true
	p.explosiveness   = 0.95
	p.amount          = count
	p.lifetime        = lifetime
	p.spread          = 180.0
	p.initial_velocity_min = v_min
	p.initial_velocity_max = v_max
	p.gravity         = Vector2(0, 420)
	p.scale_amount_min = s_min
	p.scale_amount_max = s_max
	p.color           = color

	var gr := Gradient.new()
	gr.set_color(0, color)
	gr.set_color(1, Color(color.r, color.g, color.b, 0.0))
	p.color_ramp = gr

	p.position = pos
	p.z_index  = 20
	root.add_child(p)
	get_tree().create_timer(lifetime + 0.1).timeout.connect(p.queue_free)

# ---- Ring flash (correct sort) ----
func flash_at(pos: Vector2, color: Color) -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	var ring := _RingFlash.new()
	ring.position    = pos
	ring.flash_color = color
	ring.z_index     = 18
	root.add_child(ring)

# ---- Shatter (wrong sort — called by FlowItem on play_fail) ----
func shatter_at(pos: Vector2, color: Color) -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	# Darker, more chaotic burst
	var dark := Color(color.r * 0.5, color.g * 0.5, color.b * 0.5, 1.0)
	_spawn_cpu_burst(root, pos, dark, 20, 80.0, 200.0, 0.5, 3.0, 8.0)
	_spawn_cpu_burst(root, pos, Color(1.0, 1.0, 1.0, 0.8), 8, 120.0, 260.0, 0.3, 2.0, 5.0)

func _get_camera() -> Camera2D:
	if is_instance_valid(_camera):
		return _camera
	_camera = get_tree().get_first_node_in_group("main_camera")
	return _camera

func register_camera(cam: Camera2D) -> void:
	_camera = cam
	cam.add_to_group("main_camera")

# ================================================================
#  Ring flash node
# ================================================================

class _RingFlash extends Node2D:
	var flash_color: Color = Color.WHITE
	var _t: float = 0.0
	const DURATION   := 0.30
	const MAX_RADIUS := 52.0

	func _process(delta: float) -> void:
		_t += delta / DURATION
		if _t >= 1.0:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var ease := 1.0 - pow(1.0 - _t, 2.5)
		var radius := MAX_RADIUS * ease
		var alpha  := (1.0 - _t) * 0.85
		var c := flash_color
		c.a = alpha
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, c, 3.5, true)
		# Second smaller ring
		var c2 := flash_color
		c2.a = alpha * 0.4
		draw_arc(Vector2.ZERO, radius * 0.55, 0.0, TAU, 28, c2, 2.0, true)
