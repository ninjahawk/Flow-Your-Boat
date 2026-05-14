extends Node
# Debug screenshot tool.
# QUIT_AFTER = true  → headless CI mode: screenshot then quit
# QUIT_AFTER = false → live mode: screenshot only, game keeps running
# Set ENABLED = false to disable entirely for release builds.

const DELAY      := 1.5
const FILENAME   := "user://debug_screenshot.png"
const ENABLED    := false  # master switch — OFF for normal play
const QUIT_AFTER := false  # only true when running headless for CI

var _timer := 0.0
var _done  := false

func _ready() -> void:
	if not ENABLED:
		set_process(false)

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= DELAY and not _done:
		_done = true
		_capture()

func _capture() -> void:
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(FILENAME)
	if err == OK:
		print("DebugCapture: saved to ", ProjectSettings.globalize_path(FILENAME))
	else:
		print("DebugCapture: FAILED to save, error ", err)
	if QUIT_AFTER:
		get_tree().quit()

func enable_headless() -> void:
	# Called by CI runner to activate screenshot + quit mode
	set_process(true)
	_done  = false
	_timer = 0.0
