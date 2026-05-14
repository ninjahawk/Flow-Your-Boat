class_name TitleScreen
extends CanvasLayer

signal play_requested

var _root:        Control
var _best_label:  Label
var _float_items: Array = []   # drifting background blocks
var _t:           float = 0.0

func _ready() -> void:
	layer = 30
	visible = true
	add_to_group("title_screen")
	_build_ui()
	_spawn_float_items()

func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_update_float_items(delta)

# ================================================================
#  BUILD
# ================================================================

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	# Background
	var bg := ColorRect.new()
	bg.color = Palette.BG_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)

	# ---- Title block ----
	var title_lbl := _lbl("FLOW", 72, Color.WHITE)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.anchor_left   = 0.0
	title_lbl.anchor_right  = 1.0
	title_lbl.anchor_top    = 0.0
	title_lbl.anchor_bottom = 0.0
	title_lbl.offset_top    = 195.0
	title_lbl.offset_bottom = 285.0
	_root.add_child(title_lbl)

	var sub_lbl := _lbl("YOUR  BOAT", 22, Palette.SUBTEXT_COLOR)
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.anchor_left   = 0.0
	sub_lbl.anchor_right  = 1.0
	sub_lbl.anchor_top    = 0.0
	sub_lbl.anchor_bottom = 0.0
	sub_lbl.offset_top    = 288.0
	sub_lbl.offset_bottom = 320.0
	_root.add_child(sub_lbl)

	# Colored accent bar
	var bar := ColorRect.new()
	bar.color = Palette.ITEM_COLORS[1]
	bar.anchor_left = 0.5; bar.anchor_right = 0.5
	bar.anchor_top = 0.0;  bar.anchor_bottom = 0.0
	bar.offset_left = -55.0; bar.offset_right = 55.0
	bar.offset_top = 326.0; bar.offset_bottom = 329.0
	_root.add_child(bar)

	# ---- Best score ----
	_best_label = _lbl("BEST  %d" % SaveData.best_score, 17, Palette.SUBTEXT_COLOR)
	_best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_best_label.anchor_left   = 0.0
	_best_label.anchor_right  = 1.0
	_best_label.anchor_top    = 0.0
	_best_label.anchor_bottom = 0.0
	_best_label.offset_top    = 345.0
	_best_label.offset_bottom = 375.0
	_root.add_child(_best_label)

	# ---- Color tile preview ----
	for i in range(4):
		_add_color_tile(i)

	# ---- TAP TO PLAY ----
	var tap_lbl := _lbl("TAP  TO  PLAY", 20, Color.WHITE)
	tap_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tap_lbl.anchor_left   = 0.0
	tap_lbl.anchor_right  = 1.0
	tap_lbl.anchor_top    = 1.0
	tap_lbl.anchor_bottom = 1.0
	tap_lbl.offset_top    = -145.0
	tap_lbl.offset_bottom = -110.0
	_root.add_child(tap_lbl)
	var tw := tap_lbl.create_tween().set_loops()
	tw.tween_property(tap_lbl, "modulate:a", 0.25, 0.75)
	tw.tween_property(tap_lbl, "modulate:a", 1.0,  0.75)

	# Fade in everything
	_root.modulate.a = 0.0
	_root.create_tween().tween_property(_root, "modulate:a", 1.0, 0.5)

func _add_color_tile(i: int) -> void:
	# Rounded tiles using Panel + StyleBoxFlat
	var panel := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.ITEM_COLORS[i]
	style.corner_radius_top_left     = 12
	style.corner_radius_top_right    = 12
	style.corner_radius_bottom_left  = 12
	style.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", style)

	var tile_w := 52.0
	var spacing := 14.0
	var total := tile_w * 4.0 + spacing * 3.0
	var start_x := (540.0 - total) * 0.5

	panel.anchor_left = 0.0; panel.anchor_right = 0.0
	panel.anchor_top  = 0.0; panel.anchor_bottom = 0.0
	panel.offset_left   = start_x + float(i) * (tile_w + spacing)
	panel.offset_right  = panel.offset_left + tile_w
	panel.offset_top    = 430.0
	panel.offset_bottom = 430.0 + tile_w
	_root.add_child(panel)

	# Stagger fade in
	panel.modulate.a = 0.0
	var tw := panel.create_tween()
	tw.tween_interval(float(i) * 0.12)
	tw.tween_property(panel, "modulate:a", 1.0, 0.25)

func _lbl(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

# ================================================================
#  FLOATING DEMO BLOCKS
# ================================================================

func _spawn_float_items() -> void:
	for i in range(6):
		var item := ColorRect.new()
		item.size = Vector2(44.0, 38.0)
		var style := StyleBoxFlat.new()
		var col := Palette.ITEM_COLORS[i % Palette.ITEM_COLORS.size()]
		col.a = 0.18
		style.bg_color = col
		style.corner_radius_top_left     = 8
		style.corner_radius_top_right    = 8
		style.corner_radius_bottom_left  = 8
		style.corner_radius_bottom_right = 8
		item.add_theme_stylebox_override("panel", style)
		item.color = Color(col.r, col.g, col.b, 0.18)
		var start_x := randf_range(40.0, 500.0)
		var start_y := randf_range(-200.0, 900.0)
		item.position = Vector2(start_x, start_y)
		item.z_index  = -1
		_root.add_child(item)
		_float_items.append({
			"node": item,
			"x": start_x,
			"speed": randf_range(28.0, 65.0),
			"drift": randf_range(-8.0, 8.0),
			"phase": randf() * TAU,
		})

func _update_float_items(delta: float) -> void:
	for d in _float_items:
		var node := d["node"] as ColorRect
		if not is_instance_valid(node):
			continue
		node.position.y += float(d["speed"]) * delta
		node.position.x  = float(d["x"]) + sin(_t * 0.4 + float(d["phase"])) * float(d["drift"])
		if node.position.y > 1020.0:
			node.position.y = -60.0
			d["x"] = randf_range(40.0, 500.0)

# ================================================================
#  INPUT
# ================================================================

func _input(event: InputEvent) -> void:
	if not visible:
		return
	var tapped := false
	if event is InputEventScreenTouch and event.pressed:
		tapped = true
	elif event is InputEventMouseButton and event.pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		tapped = true
	if tapped:
		_on_play()

func _on_play() -> void:
	if not visible:
		return
	set_process_input(false)
	var tw := _root.create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.28)
	tw.tween_callback(func():
		visible = false
		play_requested.emit()
	)
