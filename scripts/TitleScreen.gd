class_name TitleScreen
extends CanvasLayer

signal play_requested

const VW := 540.0
const VH := 960.0

var _root:       Control
var _best_label: Label
var _tap_label:  Label
var _tap_tween:  Tween
var _demo_items: Array = []
var _demo_t:     float = 0.0

func _ready() -> void:
	layer = 30
	visible = true
	add_to_group("title_screen")
	_build_ui()
	_start_demo()

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	# Solid dark background
	var bg := ColorRect.new()
	bg.color = Palette.BG_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)

	# Floating demo blocks (animated in _process via a Node2D overlay)
	var demo_layer := Node2D.new()
	demo_layer.z_index = 1
	_root.add_child(demo_layer)

	# Title
	var title_vbox := VBoxContainer.new()
	title_vbox.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title_vbox.position = Vector2(-160.0, 180.0)
	title_vbox.size = Vector2(320.0, 200.0)
	title_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	title_vbox.add_theme_constant_override("separation", 6)
	_root.add_child(title_vbox)

	var t1 := _lbl("FLOW", 64, Color.WHITE)
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_vbox.add_child(t1)

	var t2 := _lbl("YOUR BOAT", 28, Palette.SUBTEXT_COLOR)
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_vbox.add_child(t2)

	# Decorative colored bar under title
	var bar := ColorRect.new()
	bar.color = Palette.ITEM_COLORS[1]
	bar.size  = Vector2(120.0, 3.0)
	bar.position = Vector2(-60.0, 18.0)
	title_vbox.add_child(bar)

	# Best score
	_best_label = _lbl("BEST  %d" % SaveData.best_score, 18, Palette.SUBTEXT_COLOR)
	_best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_best_label.set_anchors_preset(Control.PRESET_CENTER)
	_best_label.position = Vector2(-120.0, 80.0)
	_best_label.size = Vector2(240.0, 30.0)
	_root.add_child(_best_label)

	# Mini bin preview (3 colored dots showing the mechanic)
	_build_bin_preview()

	# Tap to play
	_tap_label = _lbl("TAP TO PLAY", 22, Color.WHITE)
	_tap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tap_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_tap_label.position = Vector2(-120.0, -130.0)
	_tap_label.size = Vector2(240.0, 36.0)
	_root.add_child(_tap_label)
	_pulse_tap_label()

func _build_bin_preview() -> void:
	# Three small colored tiles showing SORT → BIN idea
	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_CENTER)
	hbox.position = Vector2(-100.0, 160.0)
	hbox.size = Vector2(200.0, 56.0)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 14)
	_root.add_child(hbox)

	for i in range(3):
		var tile := ColorRect.new()
		tile.custom_minimum_size = Vector2(44.0, 44.0)
		var style := StyleBoxFlat.new()
		style.bg_color = Palette.ITEM_COLORS[i]
		style.corner_radius_top_left    = 10
		style.corner_radius_top_right   = 10
		style.corner_radius_bottom_left = 10
		style.corner_radius_bottom_right= 10
		tile.add_theme_stylebox_override("panel", style)
		# Actually ColorRect doesn't use panel stylebox - use modulate
		tile.color = Palette.ITEM_COLORS[i]
		hbox.add_child(tile)
		# Stagger fade-in
		tile.modulate.a = 0.0
		var tw := tile.create_tween()
		tw.tween_interval(float(i) * 0.15)
		tw.tween_property(tile, "modulate:a", 1.0, 0.3)

func _lbl(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _pulse_tap_label() -> void:
	if is_instance_valid(_tap_tween):
		_tap_tween.kill()
	_tap_tween = _tap_label.create_tween().set_loops()
	_tap_tween.tween_property(_tap_label, "modulate:a", 0.25, 0.7)
	_tap_tween.tween_property(_tap_label, "modulate:a", 1.0,  0.7)

func _start_demo() -> void:
	# Animate title elements in
	_root.modulate.a = 0.0
	var tw := _root.create_tween()
	tw.tween_property(_root, "modulate:a", 1.0, 0.6)

func _input(event: InputEvent) -> void:
	var tapped := false
	if event is InputEventScreenTouch and event.pressed:
		tapped = true
	elif event is InputEventMouseButton and event.pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		tapped = true
	if tapped:
		_on_play()

func _on_play() -> void:
	set_process_input(false)
	var tw := _root.create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func():
		visible = false
		play_requested.emit()
	)
