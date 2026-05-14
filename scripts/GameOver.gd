extends CanvasLayer

signal restart_requested

var _root:        Control
var _score_lbl:   Label
var _best_lbl:    Label
var _new_best_lbl: Label

func _ready() -> void:
	layer = 20
	visible = false
	_build_ui()

func show_game_over(final_score: int) -> void:
	var is_new_best := SaveData.submit(final_score)

	_score_lbl.text = "%d" % final_score
	_best_lbl.text  = "BEST  %d" % SaveData.best_score
	_new_best_lbl.visible = is_new_best

	visible = true
	_root.modulate.a = 0.0
	var tw := _root.create_tween()
	tw.tween_property(_root, "modulate:a", 1.0, 0.35)

	if is_new_best:
		_flash_new_best()

func _flash_new_best() -> void:
	var tw := _new_best_lbl.create_tween().set_loops(3)
	tw.tween_property(_new_best_lbl, "modulate:a", 0.2, 0.18)
	tw.tween_property(_new_best_lbl, "modulate:a", 1.0, 0.18)

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var overlay := ColorRect.new()
	overlay.color = Color(0.04, 0.05, 0.09, 0.90)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(overlay)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.position = Vector2(-150, -180)
	vbox.size = Vector2(300, 360)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	_root.add_child(vbox)

	# Title
	var title := _lbl("FLOW BROKEN", 34, Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_add_spacer(vbox, 8)

	# Score
	_score_lbl = _lbl("0", 52, Color.WHITE)
	_score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_score_lbl)

	# Best
	_best_lbl = _lbl("BEST  0", 16, Palette.SUBTEXT_COLOR)
	_best_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_best_lbl)

	# New best badge
	_new_best_lbl = _lbl("✦ NEW BEST ✦", 15, Palette.ITEM_COLORS[3])
	_new_best_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_new_best_lbl.visible = false
	vbox.add_child(_new_best_lbl)

	_add_spacer(vbox, 16)

	var btn := _make_button("TRY AGAIN")
	btn.pressed.connect(_on_restart_pressed)
	vbox.add_child(btn)

func _lbl(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _add_spacer(parent: VBoxContainer, h: int) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	parent.add_child(s)

func _make_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(220, 56)
	btn.add_theme_font_size_override("font_size", 18)
	var s := StyleBoxFlat.new()
	s.bg_color = Palette.ITEM_COLORS[1]
	for c in ["corner_radius_top_left","corner_radius_top_right","corner_radius_bottom_left","corner_radius_bottom_right"]:
		s.set(c, 14)
	btn.add_theme_stylebox_override("normal", s)
	var sh := s.duplicate() as StyleBoxFlat
	sh.bg_color = Palette.ITEM_COLORS[1].lightened(0.15)
	btn.add_theme_stylebox_override("hover", sh)
	btn.add_theme_color_override("font_color", Color.WHITE)
	return btn

func update_score(final_score: int) -> void:
	if _score_lbl:
		_score_lbl.text = "%d" % final_score

func _on_restart_pressed() -> void:
	restart_requested.emit()
	visible = false
