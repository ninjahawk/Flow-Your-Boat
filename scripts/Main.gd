extends Node2D
# Root game world. Builds all visual elements in code and coordinates gameplay.

# ---- Layout constants (540 × 960 viewport) ----
const VW            := 540.0
const VH            := 960.0
const HUD_H         := 76.0
const LANE_TOP      := 88.0
const GATE_Y        := 692.0   # vertical centre of gate row
const BIN_Y         := 812.0   # vertical centre of bin row
const BIN_H         := 96.0
const LANE_MARGIN   := 18.0
const SPAWN_Y       := 64.0    # where items appear

# ---- Runtime refs ----
var _gates:    Array[Gate] = []
var _bins:     Array[Bin]  = []
var _items:    Node2D
var _hud:      CanvasLayer
var _gameover: Node
var _camera:   Camera2D
var _audio:    Node   # GameAudio
var _bg:       Node2D # Background

# Spawn timers per lane
var _spawn_timers: Array[float] = []
var _pending_spawn: Array[bool]  = []

# Preloaded scripts
const FlowItemScript  := preload("res://scripts/FlowItem.gd")
const GateScript      := preload("res://scripts/Gate.gd")
const BinScript       := preload("res://scripts/Bin.gd")
const HUDScript       := preload("res://scripts/HUD.gd")
const GameOverScript  := preload("res://scripts/GameOver.gd")
const BackgroundScript := preload("res://scripts/Background.gd")
const AudioScript      := preload("res://scripts/Audio.gd")

func _ready() -> void:
	_setup_camera()
	_draw_bg()
	_items = Node2D.new()
	add_child(_items)
	GameState.start_game()
	_build_layout()
	_build_hud()
	_build_gameover()
	_connect_signals()
	_init_spawn_timers()
	set_process_input(true)
	_audio = AudioScript.new()
	add_child(_audio)

# ================================================================
#  INPUT — handled centrally here, not in Gate nodes
# ================================================================

var _last_tap_pos  := Vector2(-999.0, -999.0)
var _last_tap_time := -1.0

func _input(event: InputEvent) -> void:
	var tap_vp := Vector2(-1.0, -1.0)

	if event is InputEventScreenTouch and event.pressed:
		tap_vp = event.position
	elif event is InputEventMouseButton \
			and event.pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		tap_vp = event.position

	if tap_vp.x < 0.0:
		return

	# Guard: ignore duplicate events at same position within 0.1s
	# (prevents double-fire from emulate_touch_from_mouse or other quirks)
	var now := Time.get_ticks_msec() / 1000.0
	if tap_vp.distance_to(_last_tap_pos) < 10.0 and now - _last_tap_time < 0.1:
		get_viewport().set_input_as_handled()
		return
	_last_tap_pos  = tap_vp
	_last_tap_time = now

	# Restart from game-over — tap anywhere
	if not GameState.is_running:
		_on_restart()
		get_viewport().set_input_as_handled()
		return

	# event.position is in VIEWPORT pixels (always 0–540 × 0–960 for our fixed viewport).
	# We DON'T apply the camera/canvas transform — the camera uses FIXED_TOP_LEFT
	# so viewport coords == world coords, and event.position is already in that space.
	# Stretch mode "canvas_items" also keeps event coords in virtual-viewport space.
	var vx := tap_vp.x
	var vy := tap_vp.y

	# Gate row: GATE_Y ± 60 px, divided into N equal columns
	if vy >= GATE_Y - 60.0 and vy <= GATE_Y + 60.0:
		var n      := _gates.size()
		var lane_w := (VW - LANE_MARGIN * 2.0) / float(n)
		for i in range(n):
			var gx := LANE_MARGIN + (float(i) + 0.5) * lane_w
			if vx >= gx - lane_w * 0.5 and vx < gx + lane_w * 0.5:
				_gates[i]._toggle()
				get_viewport().set_input_as_handled()
				return

# ================================================================
#  SCENE CONSTRUCTION
# ================================================================

func _draw() -> void:
	# All static visuals: lane panels, divider, routing guides
	# Drawn here so we're guaranteed to render (no inner-class uncertainty)
	var n      := GameState.lane_count
	var lane_w := (VW - LANE_MARGIN * 2.0) / float(n)
	var bin_w  := (VW - LANE_MARGIN * 2.0) / float(n + 1)

	# Lane panels
	for i in range(n):
		var lx   := LANE_MARGIN + (float(i) + 0.5) * lane_w
		var rect := Rect2(lx - (lane_w - 6.0) * 0.5, LANE_TOP, lane_w - 6.0, GATE_Y - LANE_TOP - 12.0)
		Palette.draw_rrect(self, rect, 12.0, Palette.LANE_COLOR)

	# Divider line above gate row
	var div_y := GATE_Y - 38.0
	draw_line(Vector2(LANE_MARGIN, div_y), Vector2(VW - LANE_MARGIN, div_y), Palette.DIVIDER_COLOR, 1.5)

	# Routing guide lines (gate bottom → bin top)
	var guide_color := Palette.DIVIDER_COLOR
	guide_color.a = 0.35
	for i in range(n):
		var gate_x := LANE_MARGIN + (float(i) + 0.5) * lane_w
		var gate_bot := GATE_Y + 32.0
		var left_bin_x  := LANE_MARGIN + (float(i) + 0.5) * bin_w
		var right_bin_x := LANE_MARGIN + (float(i + 1) + 0.5) * bin_w
		var bin_top := BIN_Y - BIN_H * 0.5
		draw_line(Vector2(gate_x, gate_bot), Vector2(left_bin_x, bin_top), guide_color, 1.0)
		draw_line(Vector2(gate_x, gate_bot), Vector2(right_bin_x, bin_top), guide_color, 1.0)

func _setup_camera() -> void:
	_camera = $Camera2D
	# Fixed top-left so world (0,0) maps to screen top-left.
	# Screen shake is done via camera.offset, not position.
	_camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	Effects.register_camera(_camera)

func _draw_bg() -> void:
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -10
	add_child(bg_layer)
	var bg := ColorRect.new()
	bg.color = Palette.BG_COLOR
	bg.position = Vector2.ZERO
	bg.size = Vector2(VW, VH)
	bg_layer.add_child(bg)
	# Animated dot grid above the solid bg
	_bg = BackgroundScript.new()
	_bg.z_index = -5
	add_child(_bg)

func _build_layout() -> void:
	var n := GameState.lane_count
	var lane_w := (VW - LANE_MARGIN * 2.0) / float(n)
	var bin_w  := (VW - LANE_MARGIN * 2.0) / float(n + 1)

	# Static visuals drawn in _draw() — trigger first paint
	queue_redraw()

	# Gates
	_gates.clear()
	for i in range(n):
		var g: Gate = GateScript.new()
		g.lane_index  = i
		g.direction   = -1
		g.gate_width  = lane_w - 10.0
		g.gate_height = 60.0
		g.position    = Vector2(LANE_MARGIN + (float(i) + 0.5) * lane_w, GATE_Y)
		g.z_index     = 5
		add_child(g)
		_gates.append(g)

	# Bins (n+1 bins)
	_bins.clear()
	for i in range(n + 1):
		var b: Bin = BinScript.new()
		b.bin_index  = i
		b.color_id   = GameState.bin_color_ids[i]
		b.bin_width  = bin_w - 6.0
		b.bin_height = BIN_H
		b.position   = Vector2(LANE_MARGIN + (float(i) + 0.5) * bin_w, BIN_Y)
		b.z_index    = 3
		add_child(b)
		b.add_to_group("flow_bins")
		_bins.append(b)

func _build_hud() -> void:
	_hud = HUDScript.new()
	add_child(_hud)

func _build_gameover() -> void:
	_gameover = GameOverScript.new()
	add_child(_gameover)

func _connect_signals() -> void:
	GameState.game_over.connect(_on_game_over)
	GameState.bins_shuffled.connect(_on_bins_shuffled)
	GameState.level_up.connect(_on_level_up)
	_gameover.restart_requested.connect(_on_restart)

# ================================================================
#  SPAWNING
# ================================================================

func _init_spawn_timers() -> void:
	_spawn_timers.clear()
	_pending_spawn.clear()
	for i in range(GameState.lane_count):
		# Stagger initial spawns so lanes don't all fire at once
		_spawn_timers.append(float(i) * (GameState.spawn_interval / float(GameState.lane_count)))
		_pending_spawn.append(false)

func _process(delta: float) -> void:
	if not GameState.is_running:
		return
	for i in range(_spawn_timers.size()):
		_spawn_timers[i] -= delta
		if _spawn_timers[i] <= 0.0 and not _pending_spawn[i]:
			_pending_spawn[i] = true
			_spawn_item(i)

func _spawn_item(lane_idx: int) -> void:
	var n    := GameState.lane_count
	var lane_w := (VW - LANE_MARGIN * 2.0) / float(n)
	var cx   := LANE_MARGIN + (float(lane_idx) + 0.5) * lane_w

	var valid_colors := GameState.get_valid_colors_for_lane(lane_idx)
	var color_id := valid_colors[randi() % valid_colors.size()]

	var item: Node2D = FlowItemScript.new()
	item.color_id   = color_id
	item.lane_index = lane_idx
	item.fall_speed = GameState.fall_speed
	item.gate_y     = GATE_Y
	item.bin_y      = BIN_Y
	item.position   = Vector2(cx, SPAWN_Y)
	item.z_index    = 8

	item.reached_gate.connect(_on_item_reached_gate)
	item.reached_bin.connect(_on_item_reached_bin)
	_items.add_child(item)
	item.add_to_group("flow_items")

# ================================================================
#  ROUTING LOGIC
# ================================================================

func _on_item_reached_gate(item: FlowItem) -> void:
	var lane_idx: int = item.lane_index
	var gate: Gate = _gates[lane_idx]
	# direction -1 = left → bin[lane_idx], direction +1 = right → bin[lane_idx+1]
	var bin_idx: int = lane_idx if gate.direction == -1 else lane_idx + 1
	var target_x: float = _bins[bin_idx].position.x
	item.set_target_bin_x(target_x, bin_idx)
	gate.set_active(false)

func _on_item_reached_bin(item: FlowItem, bin_idx: int) -> void:
	var bin: Bin = _bins[bin_idx]
	var success: bool = bin.receive_item(item.color_id)
	var lane_idx: int = item.lane_index

	if success:
		GameState.increment_combo()
		var pts := 10 + (GameState.combo - 1) * 5
		GameState.add_score(pts)
		Effects.burst_at(item.global_position, Palette.ITEM_COLORS[item.color_id])
		Effects.flash_at(bin.global_position, Palette.ITEM_COLORS[item.color_id])
		item.play_success()
		if _audio: _audio.play_success(GameState.combo)
		if OS.get_name() == "Android":
			Input.vibrate_handheld(20)
	else:
		GameState.reset_combo()
		GameState.lose_life()
		Effects.screen_shake(6.0, 0.25)
		item.play_fail()
		if _audio: _audio.play_fail()
		if OS.get_name() == "Android":
			Input.vibrate_handheld(80)

	# Free item after brief flash
	var timer := get_tree().create_timer(0.18)
	timer.timeout.connect(item.queue_free)

	# Reset lane timer for next spawn
	if lane_idx < _spawn_timers.size():
		_spawn_timers[lane_idx] = GameState.spawn_interval
		_pending_spawn[lane_idx] = false

	# Proximity glow: activate gate when next item is near
	_update_gate_glow()

func _update_gate_glow() -> void:
	# Light up a gate if any live item is within 180px above it
	var gate_active := []
	gate_active.resize(_gates.size())
	gate_active.fill(false)
	for child in _items.get_children():
		var item := child as Node2D
		if not is_instance_valid(item):
			continue
		var dist := GATE_Y - item.position.y
		if dist > 0.0 and dist < 180.0:
			var li: int = item.get("lane_index")
			if li >= 0 and li < _gates.size():
				gate_active[li] = true
	for i in range(_gates.size()):
		_gates[i].set_active(gate_active[i])

# ================================================================
#  LEVEL / STATE EVENTS
# ================================================================

func _on_level_up(_lvl: int) -> void:
	if _audio: _audio.play_level_up()
	if GameState.lane_count != _gates.size():
		_rebuild_for_new_lane_count()

func _on_bins_shuffled() -> void:
	for i in range(_bins.size()):
		if i < GameState.bin_color_ids.size():
			_bins[i].color_id = GameState.bin_color_ids[i]
			_bins[i].queue_redraw()

func _rebuild_for_new_lane_count() -> void:
	# Remove old gates, bins, items
	for g in _gates: g.queue_free()
	for b in _bins:  b.queue_free()
	for c in _items.get_children(): c.queue_free()
	_build_layout()
	queue_redraw()
	_init_spawn_timers()

func _on_game_over() -> void:
	_gameover.update_score(GameState.score)
	_gameover.show_game_over(GameState.score)

func _on_restart() -> void:
	for c in _items.get_children():
		c.queue_free()
	GameState.start_game()
	_on_bins_shuffled()
	queue_redraw()
	_init_spawn_timers()

