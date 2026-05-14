extends Node
# Automated gameplay driver.
# Two modes:
#   SMART  = reads item colors + bin layout, sets gates correctly, verifies scoring
#   RANDOM = random gate taps (stress test)
# Uses Input.parse_input_event() to test the REAL input path, not just _toggle() directly.

const ENABLED    := false   # master switch — always false in committed code
const QUIT_TIME  := 12.0
const SHOT_TIMES := [1.5, 4.0, 8.0]
const SMART_MODE := true    # false = random taps

var _t          := 0.0
var _shots_done := {}
var _log        := []
var _think_timer := 0.0
const THINK_INTERVAL := 0.25   # how often we re-evaluate gate directions

func _ready() -> void:
	if not ENABLED:
		set_process(false)
		return
	GameState.score_changed.connect(func(s): _log.append("t=%.1f SCORE→%d" % [_t, s]))
	GameState.lives_changed.connect(func(l): _log.append("t=%.1f LIVES→%d" % [_t, l]))
	GameState.game_over.connect(func():      _log.append("t=%.1f GAME OVER" % _t))

func _process(delta: float) -> void:
	_t            += delta
	_think_timer  += delta

	# Dismiss title screen on first frame
	if _t < 0.2 and not GameState.is_running:
		var titles := get_tree().get_nodes_in_group("title_screen")
		if titles.is_empty():
			GameState.is_running = true
		else:
			titles[0]._on_play()

	for st in SHOT_TIMES:
		if not _shots_done.has(st) and _t >= st:
			_shots_done[st] = true
			_screenshot("shot_%.0f.png" % st)

	if _think_timer >= THINK_INTERVAL and _t > 0.8 and GameState.is_running:
		_think_timer = 0.0
		if SMART_MODE:
			_play_smart()
		else:
			_play_random()

	if _t >= QUIT_TIME:
		_finish()

# ----------------------------------------------------------------
#  Smart play: for each item falling, calculate the correct gate
#  direction and simulate a click on the gate if it's wrong.
# ----------------------------------------------------------------
func _play_smart() -> void:
	var gates := get_tree().get_nodes_in_group("gates")
	var bins  := get_tree().get_nodes_in_group("flow_bins")
	var items := get_tree().get_nodes_in_group("flow_items")

	if gates.is_empty() or bins.is_empty():
		return

	# Build a color→bin_index map
	var color_to_bin := {}
	for b in bins:
		color_to_bin[b.color_id] = b.bin_index

	# For each falling item, determine the correct gate direction
	for child in items:
		var item := child as FlowItem
		if not is_instance_valid(item):
			continue
		# Only act when item is above the gate (state 0 = falling)
		if item.get("_state") != 0:
			continue
		var lane_idx: int = item.lane_index
		if lane_idx >= gates.size():
			continue

		var gate: Gate = null
		for g in gates:
			if g.lane_index == lane_idx:
				gate = g
				break
		if gate == null:
			continue

		var item_color: int = item.color_id
		# Correct direction: LEFT (-1) → bin[lane_idx], RIGHT (+1) → bin[lane_idx+1]
		var correct_dir: int = -1
		if color_to_bin.has(item_color):
			var target_bin_idx: int = color_to_bin[item_color]
			if target_bin_idx == lane_idx + 1:
				correct_dir = 1
			# else correct_dir stays -1 (left)

		if gate.direction != correct_dir:
			_simulate_click_on(gate)
			_log.append("t=%.1f SMART: gate[%d] set to %s for color %d" % [
				_t, lane_idx, ("R" if correct_dir == 1 else "L"), item_color
			])

# ----------------------------------------------------------------
#  Random play (stress test)
# ----------------------------------------------------------------
func _play_random() -> void:
	var gates := get_tree().get_nodes_in_group("gates")
	if gates.is_empty():
		return
	var gate: Gate = gates[randi() % gates.size()]
	_simulate_click_on(gate)

# ----------------------------------------------------------------
#  Simulate a real mouse click at the gate's screen position.
#  This exercises the full _input → _check_world path.
# ----------------------------------------------------------------
func _simulate_click_on(gate: Gate) -> void:
	# Input.parse_input_event() does NOT call Node._input() — it only routes actions.
	# get_viewport().push_input() correctly triggers the full Node._input() chain.
	var vp_pos := gate.global_position  # viewport coords == world coords with fixed camera

	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed      = true
	down.position     = vp_pos
	get_viewport().push_input(down, true)   # true = call_input_filter

	var up := down.duplicate() as InputEventMouseButton
	up.pressed = false
	get_viewport().push_input(up, true)

# ----------------------------------------------------------------

func _screenshot(fname: String) -> void:
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://" + fname)
	_log.append("t=%.1f SCREENSHOT %s" % [_t, fname])

func _finish() -> void:
	set_process(false)
	_log.append("--- FINAL: score=%d lives=%d ---" % [GameState.score, GameState.lives])
	for line in _log:
		print(line)
	get_tree().quit()
