extends CanvasLayer

const HEART_FULL  := "♥"
const HEART_EMPTY := "♡"
const MAX_LIVES   := 3

var _score_label:  Label
var _lives_label:  Label
var _combo_label:  Label
var _level_label:  Label
var _combo_tween:  Tween
var _danger_edges: Array = []  # 4 thin border rects for last-life warning
var _level_banner: Label       # "LEVEL UP" flash
var _root:         Control

func _ready() -> void:
	layer = 10
	_build_ui()
	GameState.score_changed.connect(_on_score_changed)
	GameState.lives_changed.connect(_on_lives_changed)
	GameState.combo_changed.connect(_on_combo_changed)
	GameState.level_up.connect(_on_level_up)
	GameState.score_milestone.connect(_on_score_milestone)

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	# Danger edges — 4 thin panels around the screen perimeter
	var edge_thickness := 6.0
	var edge_color := Color(1.0, 0.18, 0.18, 0.0)
	var edges_data := [
		# [anchor_left, anchor_right, anchor_top, anchor_bottom, offset overrides]
		[0.0, 1.0, 0.0, 0.0, 0.0, edge_thickness],   # top
		[0.0, 1.0, 1.0, 1.0, -edge_thickness, 0.0],   # bottom
		[0.0, 0.0, 0.0, 1.0, 0.0, edge_thickness],    # left (w)
		[1.0, 1.0, 0.0, 1.0, -edge_thickness, 0.0],   # right (w)
	]
	for i in range(4):
		var e := ColorRect.new()
		e.color = edge_color
		e.mouse_filter = Control.MOUSE_FILTER_IGNORE
		e.set_anchors_preset(Control.PRESET_FULL_RECT)
		_root.add_child(e)
		_danger_edges.append(e)
	# Top
	_danger_edges[0].anchor_bottom = 0.0; _danger_edges[0].offset_bottom = edge_thickness
	# Bottom
	_danger_edges[1].anchor_top = 1.0; _danger_edges[1].offset_top = -edge_thickness
	# Left
	_danger_edges[2].anchor_right = 0.0; _danger_edges[2].offset_right = edge_thickness
	# Right
	_danger_edges[3].anchor_left = 1.0; _danger_edges[3].offset_left = -edge_thickness

	# Score
	_score_label = _lbl("0", 30, Color.WHITE)
	_score_label.anchor_left = 0.0; _score_label.anchor_right = 1.0
	_score_label.offset_top = 14.0; _score_label.offset_bottom = 56.0
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_score_label)

	# Lives
	_lives_label = _lbl(_hearts(MAX_LIVES), 22, Color(1.0, 0.35, 0.45))
	_lives_label.anchor_left = 1.0; _lives_label.anchor_right = 1.0
	_lives_label.offset_left = -120.0; _lives_label.offset_right = -10.0
	_lives_label.offset_top = 18.0; _lives_label.offset_bottom = 54.0
	_lives_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_root.add_child(_lives_label)

	# Level
	_level_label = _lbl("LVL 1", 14, Palette.SUBTEXT_COLOR)
	_level_label.anchor_left = 0.0; _level_label.anchor_right = 0.0
	_level_label.offset_left = 16.0; _level_label.offset_right = 96.0
	_level_label.offset_top = 22.0; _level_label.offset_bottom = 52.0
	_root.add_child(_level_label)

	# Combo
	_combo_label = _lbl("", 38, Color(1.0, 0.85, 0.25))
	_combo_label.anchor_left = 0.5; _combo_label.anchor_right = 0.5
	_combo_label.anchor_top = 0.5; _combo_label.anchor_bottom = 0.5
	_combo_label.offset_left = -130.0; _combo_label.offset_right = 130.0
	_combo_label.offset_top = -230.0; _combo_label.offset_bottom = -175.0
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combo_label.modulate.a = 0.0
	_root.add_child(_combo_label)

	# Level-up banner
	_level_banner = _lbl("", 28, Color(1.0, 0.85, 0.25))
	_level_banner.anchor_left = 0.0; _level_banner.anchor_right = 1.0
	_level_banner.anchor_top = 0.5; _level_banner.anchor_bottom = 0.5
	_level_banner.offset_top = -80.0; _level_banner.offset_bottom = -40.0
	_level_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_banner.modulate.a = 0.0
	_root.add_child(_level_banner)

func _lbl(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func _hearts(count: int) -> String:
	var s := ""
	for i in range(MAX_LIVES):
		s += HEART_FULL if i < count else HEART_EMPTY
	return s

func _on_score_changed(new_score: int) -> void:
	_score_label.text = str(new_score)
	var tw := _score_label.create_tween()
	tw.tween_property(_score_label, "scale", Vector2(1.18, 1.18), 0.07)
	tw.tween_property(_score_label, "scale", Vector2(1.0, 1.0), 0.12)

func _on_lives_changed(new_lives: int) -> void:
	_lives_label.text = _hearts(new_lives)
	if new_lives < MAX_LIVES:
		var tw := _lives_label.create_tween()
		tw.tween_property(_lives_label, "position:x", _lives_label.position.x - 10.0, 0.05)
		tw.tween_property(_lives_label, "position:x", _lives_label.position.x + 10.0, 0.05)
		tw.tween_property(_lives_label, "position:x", _lives_label.position.x, 0.05)

	# Danger glow when on last life
	if new_lives == 1:
		_start_danger_pulse()
	else:
		for e in _danger_edges:
			(e as ColorRect).color.a = 0.0

func _start_danger_pulse() -> void:
	for e in _danger_edges:
		var tw := (e as ColorRect).create_tween().set_loops()
		tw.tween_property(e, "color:a", 0.85, 0.4)
		tw.tween_property(e, "color:a", 0.15, 0.4)

func _on_combo_changed(new_combo: int) -> void:
	if new_combo < 3:
		_combo_label.modulate.a = 0.0
		_combo_label.scale = Vector2.ONE
		return

	# Scale text size and color with combo intensity
	var font_size := 38 + mini((new_combo - 3) * 3, 28)  # 38 at x3 → 66 at x13+
	_combo_label.add_theme_font_size_override("font_size", font_size)

	# Color: white → gold → orange → red as combo grows
	var combo_color: Color
	if new_combo < 6:
		combo_color = Color.WHITE.lerp(Color(1.0, 0.85, 0.2), float(new_combo - 3) / 3.0)
	elif new_combo < 10:
		combo_color = Color(1.0, 0.85, 0.2).lerp(Color(1.0, 0.45, 0.1), float(new_combo - 6) / 4.0)
	else:
		combo_color = Color(1.0, 0.45, 0.1).lerp(Color(1.0, 0.1, 0.1), minf(float(new_combo - 10) / 5.0, 1.0))
	_combo_label.add_theme_color_override("font_color", combo_color)

	_combo_label.text = "x%d" % new_combo if new_combo >= 10 else "x%d  COMBO" % new_combo

	if is_instance_valid(_combo_tween):
		_combo_tween.kill()

	# Pop scale punch on each new combo hit
	_combo_label.scale = Vector2(1.35, 1.35)
	_combo_tween = _combo_label.create_tween()
	_combo_tween.set_ease(Tween.EASE_OUT)
	_combo_tween.set_trans(Tween.TRANS_BACK)
	_combo_tween.tween_property(_combo_label, "scale", Vector2.ONE, 0.18)
	_combo_tween.tween_property(_combo_label, "modulate:a", 1.0, 0.0)
	_combo_tween.tween_interval(0.5 + minf(float(new_combo) * 0.04, 0.4))
	_combo_tween.tween_property(_combo_label, "modulate:a", 0.0, 0.3)

func _on_score_milestone(threshold: int) -> void:
	# Burst the score label + brief screen flash
	var tw := _score_label.create_tween()
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_BACK)
	tw.tween_property(_score_label, "scale", Vector2(1.6, 1.6), 0.10)
	tw.tween_property(_score_label, "scale", Vector2(1.0, 1.0), 0.22)

	# Milestone text flash (reuse level banner node)
	_level_banner.text = "★ %d ★" % threshold
	_level_banner.add_theme_font_size_override("font_size", 26)
	_level_banner.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	_level_banner.scale = Vector2(0.5, 0.5)
	_level_banner.modulate.a = 0.0
	var btw := _level_banner.create_tween()
	btw.set_ease(Tween.EASE_OUT)
	btw.set_trans(Tween.TRANS_BACK)
	btw.tween_property(_level_banner, "scale", Vector2.ONE, 0.18)
	btw.parallel().tween_property(_level_banner, "modulate:a", 1.0, 0.10)
	btw.tween_interval(0.6)
	btw.tween_property(_level_banner, "modulate:a", 0.0, 0.3)

func _on_level_up(new_level: int) -> void:
	_level_label.text = "LVL %d" % (new_level + 1)
	var ltw := _level_label.create_tween()
	ltw.tween_property(_level_label, "modulate", Color(1.0, 0.85, 0.25), 0.12)
	ltw.tween_property(_level_label, "scale", Vector2(1.3, 1.3), 0.08)
	ltw.tween_property(_level_label, "scale", Vector2(1.0, 1.0), 0.2)
	ltw.tween_property(_level_label, "modulate", Color(1.0, 1.0, 1.0), 0.5)

	# Full banner with speed info
	_level_banner.text = "LEVEL  %d" % (new_level + 1)
	_level_banner.add_theme_font_size_override("font_size", 32)
	_level_banner.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))

	if is_instance_valid(_combo_tween):
		_combo_tween.kill()

	# Scale punch in, hold, fade out
	_level_banner.scale = Vector2(0.6, 0.6)
	_level_banner.modulate.a = 0.0
	var btw := _level_banner.create_tween()
	btw.set_ease(Tween.EASE_OUT)
	btw.set_trans(Tween.TRANS_BACK)
	btw.tween_property(_level_banner, "scale", Vector2.ONE, 0.22)
	btw.parallel().tween_property(_level_banner, "modulate:a", 1.0, 0.12)
	btw.tween_interval(1.1)
	btw.tween_property(_level_banner, "modulate:a", 0.0, 0.4)
