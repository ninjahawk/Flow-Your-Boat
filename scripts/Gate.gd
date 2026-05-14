class_name Gate
extends Node2D

signal toggled(gate: Gate)

var direction:   int   = -1   # -1=left  +1=right
var lane_index:  int   = 0
var gate_width:  float = 120.0
var gate_height: float = 60.0

var _is_active:  bool  = false
var _flip_t:     float = 0.0  # 1→0 flip animation

var _visual: ColorRect
var _mat:    ShaderMaterial

const GATE_SHADER := preload("res://shaders/gate.gdshader")

func _ready() -> void:
	add_to_group("gates")
	_build_visual()

func _build_visual() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = GATE_SHADER
	_mat.set_shader_parameter("direction",  float(direction))
	_mat.set_shader_parameter("is_active",  0.0)
	_mat.set_shader_parameter("flip_t",     0.0)
	_mat.set_shader_parameter("gate_size",  Vector2(gate_width, gate_height))
	_mat.set_shader_parameter("corner_r",   14.0)

	_visual = ColorRect.new()
	_visual.size     = Vector2(gate_width, gate_height)
	_visual.position = Vector2(-gate_width * 0.5, -gate_height * 0.5)
	_visual.material = _mat
	add_child(_visual)

func _process(delta: float) -> void:
	if _flip_t > 0.0:
		_flip_t = maxf(_flip_t - delta * 8.0, 0.0)
		_mat.set_shader_parameter("flip_t", _flip_t)

func _toggle() -> void:
	direction = -direction
	_flip_t   = 1.0
	_mat.set_shader_parameter("direction", float(direction))
	_mat.set_shader_parameter("flip_t",    1.0)
	toggled.emit(self)
	_tap_flash()
	if OS.get_name() == "Android":
		Input.vibrate_handheld(28)

func _tap_flash() -> void:
	# Bright white overlay that decays in 0.12s
	var flash := ColorRect.new()
	flash.size     = Vector2(gate_width, gate_height)
	flash.position = Vector2(-gate_width * 0.5, -gate_height * 0.5)
	flash.color    = Color(1.0, 1.0, 1.0, 0.55)
	flash.z_index  = 10
	add_child(flash)
	var tw := flash.create_tween()
	tw.tween_property(flash, "color:a", 0.0, 0.14)
	tw.tween_callback(flash.queue_free)
	# Tiny spark burst at gate center
	Effects.burst_at(global_position, Color(0.75, 0.82, 1.0), 8)

func set_active(active: bool) -> void:
	if _is_active == active:
		return
	_is_active = active
	_mat.set_shader_parameter("is_active", 1.0 if active else 0.0)
