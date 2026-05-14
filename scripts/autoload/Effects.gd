extends Node

# Accessed by anything needing screen-level effects.
# Screen shake is applied to the Camera2D found in the scene tree.

var _shake_amount: float = 0.0
var _shake_timer: float = 0.0
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
	_shake_amount = amount
	_shake_timer = duration
	_shake_duration = maxf(duration, 0.001)

func burst_at(pos: Vector2, color: Color, count: int = 18) -> void:
	var root := get_tree().current_scene
	if root == null:
		return

	var p := CPUParticles2D.new()
	p.emitting = true
	p.one_shot = true
	p.amount = count
	p.lifetime = 0.55
	p.explosiveness = 0.95
	p.spread = 180.0
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 260.0
	p.gravity = Vector2(0, 300)
	p.scale_amount_min = 4.0
	p.scale_amount_max = 8.0
	p.color = color
	p.position = pos
	root.add_child(p)

	# Auto-free after particles finish
	var timer := get_tree().create_timer(1.2)
	timer.timeout.connect(p.queue_free)

func flash_at(pos: Vector2, color: Color) -> void:
	# A brief bright ring expanding outward
	var root := get_tree().current_scene
	if root == null:
		return

	var ring := _RingFlash.new()
	ring.position = pos
	ring.flash_color = color
	root.add_child(ring)

func _get_camera() -> Camera2D:
	if is_instance_valid(_camera):
		return _camera
	_camera = get_tree().get_first_node_in_group("main_camera")
	return _camera

func register_camera(cam: Camera2D) -> void:
	_camera = cam
	cam.add_to_group("main_camera")

# ---- Inner helper node for ring flash ----
class _RingFlash extends Node2D:
	var flash_color: Color = Color.WHITE
	var _t: float = 0.0
	const DURATION := 0.35
	const MAX_RADIUS := 48.0

	func _process(delta: float) -> void:
		_t += delta / DURATION
		if _t >= 1.0:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var progress := _t
		var radius := MAX_RADIUS * progress
		var alpha := (1.0 - progress) * 0.8
		var c := flash_color
		c.a = alpha
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, c, 3.0, true)
