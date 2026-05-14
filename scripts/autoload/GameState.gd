extends Node

signal score_changed(new_score: int)
signal combo_changed(new_combo: int)
signal lives_changed(new_lives: int)
signal level_up(new_level: int)
signal game_over
signal bins_shuffled

# --- Game state ---
var score: int = 0
var lives: int = 3
var combo: int = 0
var level: int = 0
var is_running: bool = false

# --- Difficulty ---
var fall_speed: float = 220.0
var spawn_interval: float = 1.6   # tighter — keeps lanes busy
var lane_count: int = 3

# --- Bin color layout ---
# For N lanes there are N+1 bins.
# bin_color_ids[i] is an index into Palette.ITEM_COLORS.
# Layout is fixed per level, shuffled on level-up.
var bin_color_ids: Array[int] = []

# How many levels until difficulty thresholds
const LEVEL_THRESHOLDS = {
	1: {"fall_speed": 280.0, "spawn_interval": 2.0},
	2: {"fall_speed": 320.0, "spawn_interval": 1.8},
	3: {"fall_speed": 370.0, "spawn_interval": 1.6},
	4: {"fall_speed": 420.0, "spawn_interval": 1.4, "lane_count": 4},
	6: {"fall_speed": 480.0, "spawn_interval": 1.2},
	8: {"fall_speed": 540.0, "spawn_interval": 1.0, "lane_count": 5},
}

# Time-based level-up: seconds per level
const SECONDS_PER_LEVEL: float = 30.0
var _level_timer: float = 0.0

func start_game() -> void:
	score = 0
	lives = 3
	combo = 0
	level = 0
	is_running = true
	fall_speed = 250.0
	spawn_interval = 2.2
	lane_count = 3
	_level_timer = 0.0
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
		if t.has("fall_speed"):
			fall_speed = t["fall_speed"]
		if t.has("spawn_interval"):
			spawn_interval = t["spawn_interval"]
		if t.has("lane_count"):
			lane_count = t["lane_count"]
	_assign_bin_colors()
	level_up.emit(level)
	bins_shuffled.emit()

func _assign_bin_colors() -> void:
	# N lanes → N+1 bins, each bin gets a unique color
	var n_bins = lane_count + 1
	var color_count = Palette.ITEM_COLORS.size()
	bin_color_ids.clear()
	# Shuffle first N+1 colors
	var pool: Array[int] = []
	for i in range(color_count):
		pool.append(i)
	pool.shuffle()
	for i in range(n_bins):
		bin_color_ids.append(pool[i % color_count])

func get_valid_colors_for_lane(lane_idx: int) -> Array[int]:
	# A lane can route to bin[lane_idx] (gate LEFT) or bin[lane_idx+1] (gate RIGHT)
	return [bin_color_ids[lane_idx], bin_color_ids[lane_idx + 1]]

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
