extends Node2D

const VW          := 540.0
const VH          := 960.0
const LANE_TOP    := 88.0
const GATE_Y      := 692.0
const BIN_Y       := 812.0
const BIN_H       := 96.0
const LANE_MARGIN := 18.0
const SPAWN_Y     := 64.0

var _gates:   Array[Gate] = []
var _bins:    Array[Bin]  = []
var _items:   Node2D
var _hud:     CanvasLayer
var _gameover:Node
var _camera:  Camera2D
var _audio:   Node
var _bg:      Node2D
var _title:   Node

var _spawn_timers:    Array[float] = []
var _active_per_lane: Array[int]  = []   # how many items currently in-flight per lane

var _last_tap_pos  := Vector2(-999.0, -999.0)
var _last_tap_time := -1.0
var _draw_t:       float = 0.0   # for _draw() animations

const FlowItemScript   := preload("res://scripts/FlowItem.gd")
const GateScript       := preload("res://scripts/Gate.gd")
const BinScript        := preload("res://scripts/Bin.gd")
const HUDScript        := preload("res://scripts/HUD.gd")
const GameOverScript   := preload("res://scripts/GameOver.gd")
const BackgroundScript  := preload("res://scripts/Background.gd")
const AudioScript       := preload("res://scripts/Audio.gd")
const TitleScript       := preload("res://scripts/TitleScreen.gd")

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
	set_process_input(true)
	_audio = AudioScript.new()
	add_child(_audio)
	# Show title screen — spawning starts only after play is tapped
	_title = TitleScript.new()
	add_child(_title)
	_title.play_requested.connect(_on_title_play)
	# Don't init spawn timers yet — wait for title dismiss
	GameState.is_running = false

func _on_title_play() -> void:
	GameState.is_running = true
	_active_per_lane.clear()
	_init_spawn_timers()

# ================================================================
#  INPUT
# ================================================================

func _input(event: InputEvent) -> void:
	var tap_vp := Vector2(-1.0, -1.0)
	if event is InputEventScreenTouch and event.pressed:
		tap_vp = event.position
	elif event is InputEventMouseButton and event.pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		tap_vp = event.position
	if tap_vp.x < 0.0:
		return

	var now := Time.get_ticks_msec() / 1000.0
	if tap_vp.distance_to(_last_tap_pos) < 10.0 and now - _last_tap_time < 0.1:
		get_viewport().set_input_as_handled()
		return
	_last_tap_pos  = tap_vp
	_last_tap_time = now

	# Game over screen handles restart via its own button — don't restart on any tap here
	if not GameState.is_running:
		return

	if tap_vp.y >= GATE_Y - 60.0 and tap_vp.y <= GATE_Y + 60.0:
		var n      := _gates.size()
		var lane_w := (VW - LANE_MARGIN * 2.0) / float(n)
		for i in range(n):
			var gx := LANE_MARGIN + (float(i) + 0.5) * lane_w
			if tap_vp.x >= gx - lane_w * 0.5 and tap_vp.x < gx + lane_w * 0.5:
				_gates[i]._toggle()
				get_viewport().set_input_as_handled()
				return

# ================================================================
#  STATIC VISUALS
# ================================================================

func _draw() -> void:
	var n      := GameState.lane_count
	var lane_w := (VW - LANE_MARGIN * 2.0) / float(n)
	var bin_w  := (VW - LANE_MARGIN * 2.0) / float(n + 1)

	for i in range(n):
		var lx   := LANE_MARGIN + (float(i) + 0.5) * lane_w
		var rect := Rect2(lx - (lane_w - 6.0) * 0.5, LANE_TOP, lane_w - 6.0, GATE_Y - LANE_TOP - 12.0)
		Palette.draw_rrect(self, rect, 12.0, Palette.LANE_COLOR)

	var div_y := GATE_Y - 38.0
	draw_line(Vector2(LANE_MARGIN, div_y), Vector2(VW - LANE_MARGIN, div_y), Palette.DIVIDER_COLOR, 1.5)

	var gc := Palette.DIVIDER_COLOR
	gc.a = 0.3
	for i in range(n):
		var gx      := LANE_MARGIN + (float(i) + 0.5) * lane_w
		var gbot    := GATE_Y + 32.0
		var lbx     := LANE_MARGIN + (float(i) + 0.5) * bin_w
		var rbx     := LANE_MARGIN + (float(i + 1) + 0.5) * bin_w
		var bin_top := BIN_Y - BIN_H * 0.5
		draw_line(Vector2(gx, gbot), Vector2(lbx, bin_top), gc, 1.0)
		draw_line(Vector2(gx, gbot), Vector2(rbx, bin_top), gc, 1.0)

	# Speed lines: drawn in lane when a RUSH item is present
	_draw_speed_lines(n, lane_w)

func _draw_speed_lines(n: int, lane_w: float) -> void:
	# Check each lane for RUSH items
	for child in _items.get_children():
		var item := child as Node2D
		if not is_instance_valid(item):
			continue
		if item.get("item_type") != FlowItem.Type.RUSH:
			continue
		if item.get("_state") != 0:
			continue
		var li: int = item.get("lane_index")
		var lx := LANE_MARGIN + (float(li) + 0.5) * lane_w
		var col := Palette.ITEM_COLORS[item.get("color_id") as int]
		col.a = 0.18
		# 4 vertical streaks at different offsets, scrolling fast
		for s in range(4):
			var offset_x := lx + float(s - 1.5) * (lane_w * 0.18)
			var speed_y  := _draw_t * 680.0 + float(s) * 74.0
			var streak_y := fmod(speed_y, 680.0) + LANE_TOP
			var streak_len := 35.0 + float(s) * 12.0
			draw_line(
				Vector2(offset_x, streak_y),
				Vector2(offset_x, minf(streak_y + streak_len, GATE_Y - 8.0)),
				col, 2.0)

func _setup_camera() -> void:
	_camera = $Camera2D
	_camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	Effects.register_camera(_camera)

func _draw_bg() -> void:
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -10
	add_child(bg_layer)
	var bg := ColorRect.new()
	bg.color    = Palette.BG_COLOR
	bg.position = Vector2.ZERO
	bg.size     = Vector2(VW, VH)
	bg_layer.add_child(bg)
	_bg = BackgroundScript.new()
	_bg.z_index = -5
	add_child(_bg)

func _build_layout() -> void:
	var n      := GameState.lane_count
	var lane_w := (VW - LANE_MARGIN * 2.0) / float(n)
	var bin_w  := (VW - LANE_MARGIN * 2.0) / float(n + 1)
	queue_redraw()

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
		b.overflowed.connect(_on_bin_overflowed)
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
	_active_per_lane.clear()
	for i in range(GameState.lane_count):
		# Stagger initial spawns across lanes
		_spawn_timers.append(float(i) * (GameState.spawn_interval / float(GameState.lane_count)))
		_active_per_lane.append(0)

func _process(delta: float) -> void:
	_draw_t += delta
	_check_redraw()
	_update_background()
	if not GameState.is_running:
		return
	for i in range(_spawn_timers.size()):
		_spawn_timers[i] -= delta
		var active := _active_per_lane[i] if i < _active_per_lane.size() else 0
		if _spawn_timers[i] <= 0.0 and active < GameState.max_per_lane:
			_spawn_item(i)
			_spawn_timers[i] = GameState.spawn_interval

func _check_redraw() -> void:
	# Redraw static layer when RUSH items are in flight (animated speed lines)
	for child in _items.get_children():
		if child.get("item_type") == FlowItem.Type.RUSH and child.get("_state") == 0:
			queue_redraw()
			return

func _update_background() -> void:
	if not is_instance_valid(_bg):
		return
	var bg := _bg as Background
	if bg == null:
		return
	# Combo heat: 0 at combo<3, rises to 1 at combo 12+
	bg.combo_heat  = clampf(float(maxi(GameState.combo - 3, 0)) / 9.0, 0.0, 1.0)
	# Danger heat: max bin pressure above 0.6
	var max_p := 0.0
	for b in _bins:
		max_p = maxf(max_p, b.pressure)
	bg.danger_heat = clampf((max_p - 0.6) / 0.4, 0.0, 1.0)
	# Level speed: 1.0 at level 0, up to 2.5 at level 8
	bg.level_speed = 1.0 + float(GameState.level) * 0.19

func _spawn_item(lane_idx: int) -> void:
	var n      := GameState.lane_count
	var lane_w := (VW - LANE_MARGIN * 2.0) / float(n)
	var cx     := LANE_MARGIN + (float(lane_idx) + 0.5) * lane_w

	var valid_colors := GameState.get_valid_colors_for_lane(lane_idx)
	var color_id     := valid_colors[randi() % valid_colors.size()]

	# Gather bin pressures for smart DRAIN spawning
	var pressures: Array = []
	for b in _bins:
		pressures.append(b.pressure)

	var itype := GameState.roll_item_type(pressures)
	var speed := GameState.fall_speed
	if itype == FlowItem.Type.RUSH:
		speed *= 2.5

	var item: FlowItem = FlowItemScript.new()
	item.color_id   = color_id
	item.lane_index = lane_idx
	item.fall_speed = speed
	item.gate_y     = GATE_Y
	item.bin_y      = BIN_Y
	item.item_type  = itype
	item.position   = Vector2(cx, SPAWN_Y)
	item.z_index    = 8

	item.reached_gate.connect(_on_item_reached_gate)
	item.reached_bin.connect(_on_item_reached_bin)
	_items.add_child(item)
	item.add_to_group("flow_items")
	if lane_idx < _active_per_lane.size():
		_active_per_lane[lane_idx] += 1

# ================================================================
#  ROUTING
# ================================================================

func _on_item_reached_gate(item: FlowItem) -> void:
	var lane_idx : int  = item.lane_index
	var gate     : Gate = _gates[lane_idx]
	var bin_idx  : int  = lane_idx if gate.direction == -1 else lane_idx + 1
	var target_x : float = _bins[bin_idx].position.x
	item.set_target_bin_x(target_x, bin_idx)
	gate.set_active(false)

func _on_item_reached_bin(item: FlowItem, bin_idx: int) -> void:
	var bin          : Bin  = _bins[bin_idx]
	var is_drain     : bool = item.item_type == FlowItem.Type.DRAIN
	var was_disabled : bool = bin.is_disabled
	var success      : bool = bin.receive_item(item.color_id, is_drain)
	var lane_idx     : int  = item.lane_index

	if success:
		GameState.increment_combo()
		var base_pts := 10 + (GameState.combo - 1) * 5
		match item.item_type:
			FlowItem.Type.RUSH:  base_pts = int(base_pts * 1.5)
			FlowItem.Type.BOMB:  base_pts = int(base_pts * 2.0)
			FlowItem.Type.DRAIN: base_pts = int(base_pts * 1.2)
		GameState.add_score(base_pts)
		Effects.burst_at(item.global_position, Palette.ITEM_COLORS[item.color_id])
		Effects.flash_at(bin.global_position,  Palette.ITEM_COLORS[item.color_id])
		item.play_success()
		if _audio: _audio.play_success(GameState.combo)
		if OS.get_name() == "Android":
			Input.vibrate_handheld(20)
	else:
		GameState.reset_combo()
		var shake_amt := 8.0 if item.item_type == FlowItem.Type.BOMB else 6.0
		Effects.screen_shake(shake_amt, 0.28)
		Effects.shatter_at(item.global_position, Palette.ITEM_COLORS[item.color_id])
		item.play_fail()
		if _audio: _audio.play_fail()
		if OS.get_name() == "Android":
			Input.vibrate_handheld(80)

		# BOMB: force-overflow the bin (if not already overflowed by receive_item)
		if item.item_type == FlowItem.Type.BOMB:
			if not bin.is_disabled:
				bin._trigger_overflow()
			# Overflow signal already handles lose_life — don't double-penalise
		else:
			# Only lose a life from wrong sort if overflow wasn't already triggered
			if bin.is_disabled and not was_disabled:
				pass  # overflow inside receive_item already fired lose_life via signal
			else:
				GameState.lose_life()

	var timer := get_tree().create_timer(0.18)
	timer.timeout.connect(item.queue_free)

	# Decrement active count so new spawns can happen
	if lane_idx < _active_per_lane.size():
		_active_per_lane[lane_idx] = maxi(_active_per_lane[lane_idx] - 1, 0)

	_update_gate_glow()

func _on_bin_overflowed(bin_index: int) -> void:
	GameState.lose_life()
	Effects.screen_shake(10.0, 0.4)
	if _audio: _audio.play_overflow()
	var bin_pos := _bins[bin_index].global_position
	Effects.shatter_at(bin_pos, Palette.ITEM_COLORS[GameState.bin_color_ids[bin_index]])
	if OS.get_name() == "Android":
		Input.vibrate_handheld(120)

func _update_gate_glow() -> void:
	var gate_active := []
	gate_active.resize(_gates.size())
	gate_active.fill(false)
	for child in _items.get_children():
		var item := child as Node2D
		if not is_instance_valid(item):
			continue
		var dist := GATE_Y - item.position.y
		if dist > 0.0 and dist < 200.0:
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
	# Update gate sizes if lane count changed
	if GameState.lane_count != _gates.size():
		_rebuild_for_new_lane_count()

func _on_bins_shuffled() -> void:
	for i in range(_bins.size()):
		if i < GameState.bin_color_ids.size():
			_bins[i].update_color(GameState.bin_color_ids[i])

func _rebuild_for_new_lane_count() -> void:
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
	for b in _bins:
		b.pressure    = 0.0
		b.is_disabled = false
		b.queue_redraw()
	queue_redraw()
	_active_per_lane.fill(0)
	_init_spawn_timers()
