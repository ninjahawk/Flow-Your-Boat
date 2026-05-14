# Persists best score across sessions.
extends Node

const PATH := "user://save.json"

var best_score: int = 0

func _ready() -> void:
	_load()

func submit(score: int) -> bool:
	# Returns true if this is a new best
	if score > best_score:
		best_score = score
		_save()
		return true
	return false

func _save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"best": best_score}))

func _load() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if not f:
		return
	var result: Variant = JSON.parse_string(f.get_as_text())
	if result is Dictionary and (result as Dictionary).has("best"):
		best_score = int((result as Dictionary)["best"])
