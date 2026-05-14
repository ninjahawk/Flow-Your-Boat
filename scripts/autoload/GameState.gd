extends Node

signal score_changed(new_score: int)
signal combo_changed(new_combo: int)
signal lives_changed(new_lives: int)
signal level_up(new_level: int)
signal game_over
signal bins_shuffled
signal bin_overflowed(bin_index: int)

# --- Game state ---
var score:      int   = 0
var lives:      int   = 3
var combo:      int   = 0
var level:      int   = 0
var is_running: bool  = false

# --- Difficulty ---
var fall_speed:     float = 220.0
var spawn_interval: float = 1.6
var lane_count:     int   = 3

# --- Bin color layout ---
var bin_color_ids: Array[int] = []

# --- Special item spawn weights (Normal / Rush / Bomb / Drain) ---
# Weights by level: [normal, rush, bomb, drain]
const SPAWN_WEIGHTS_BY_LEVEL := [
	[100, 0,  0,  0],   # level 0
	[88,  8,  4,  0],   # level 1
	[82,  9,  6,  3],   # level 2
	[76,  10, 9,  5],   # level 3
	[70,  12, 12, 6],   # level 4+
]

const LEVEL_THRESHOLDS := {
	1: {"fall_speed": 260.0, "spawn_interval": 1.5},
	2: {"fall_speed": 300.0, "spawn_interval": 1.35},
	3: {"fall_speed": 350.0, "spawn_interval": 1.2},
	4: {"fall_speed": 400.0, "spawn_interval": 1.05, "lane_count": 4},
	6: {"fall_speed": 460.0, "spawn_interval": 0.9},
	8: {"fall_speed": 520.0, "spawn_interval": 0.78, "lane_count": 5},
}

const SECONDS_PER_LEVEL: float = 30.0
var _level_timer: float = 0.0

func start_game() -> void:
	score          = 0
	lives          = 3
	combo          = 0
	level          = 0
	is_running     = true
	fall_speed     = 220.0
	spawn_interval = 1.6
	lane_count     = 3
	_level_timer   = 0.0
	_assign_bin_colors()
	score_changed.emit(score)
	lives_changed.emit(lives)
	combo_changed.emit(combo)

func _process(delta: float) -> void:
	if not is_running:
		return
	_level_timer += delta
	if _level_timer >= SECONDS_PER_LEVEL:
		_level_timer = 0.0
		_advance_level()

func _advance_level() -> void:
	level += 1
	if LEVEL_THRESHOLDS.has(level):
		var t = LEVEL_THRESHOLDS[level]
		if t.has("fall_speed"):     fall_speed     = t["fall_speed"]
		if t.has("spawn_interval"): spawn_interval = t["spawn_interval"]
		if t.has("lane_count"):     lane_count     = t["lane_count"]
	_assign_bin_colors()
	level_up.emit(level)
	bins_shuffled.emit()

func _assign_bin_colors() -> void:
	var n_bins      := lane_count + 1
	var color_count := Palette.ITEM_COLORS.size()
	bin_color_ids.clear()
	var pool: Array[int] = []
	for i in range(color_count):
		pool.append(i)
	pool.shuffle()
	for i in range(n_bins):
		bin_color_ids.append(pool[i % color_count])

func get_valid_colors_for_lane(lane_idx: int) -> Array[int]:
	return [bin_color_ids[lane_idx], bin_color_ids[lane_idx + 1]]

# Returns FlowItem.Type value using weighted random
func roll_item_type(bin_pressures: Array) -> int:
	var w_idx    : int   = mini(level, SPAWN_WEIGHTS_BY_LEVEL.size() - 1)
	var weights  : Array = SPAWN_WEIGHTS_BY_LEVEL[w_idx]

	var max_p    : float = 0.0
	for p in bin_pressures:
		max_p = maxf(max_p, float(p))
	var drain_w  : int   = int(weights[3])
	if max_p > 0.6:
		drain_w = int(float(weights[3]) * (1.0 + (max_p - 0.6) * 5.0))

	var total : int = int(weights[0]) + int(weights[1]) + int(weights[2]) + drain_w
	var roll  : int = randi() % total
	var acc   : int = 0
	acc += int(weights[0]); if roll < acc: return 0
	acc += int(weights[1]); if roll < acc: return 1
	acc += int(weights[2]); if roll < acc: return 2
	return 3

func add_score(points: int) -> void:
	score += points
	score_changed.emit(score)

func increment_combo() -> void:
	combo += 1
	combo_changed.emit(combo)

func reset_combo() -> void:
	combo = 0
	combo_changed.emit(combo)

func lose_life() -> void:
	lives -= 1
	lives_changed.emit(lives)
	if lives <= 0:
		is_running = false
		game_over.emit()
