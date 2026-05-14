class_name GameAudio
extends Node

var _player: AudioStreamPlayer
var _pb:     AudioStreamGeneratorPlayback

const RATE := 22050.0

# Pentatonic scale — pitches rise with combo
const SCALE := [261.63, 293.66, 329.63, 392.00, 440.00,
                523.25, 587.33, 659.25, 783.99, 880.00, 1046.5]

func _ready() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate      = RATE
	gen.buffer_length = 0.15
	_player = AudioStreamPlayer.new()
	_player.stream    = gen
	_player.volume_db = -4.0
	add_child(_player)
	_player.play()
	_pb = _player.get_stream_playback()

# ================================================================
#  PUBLIC
# ================================================================

func play_success(combo: int) -> void:
	if _pb == null: return
	var idx  : int   = clampi(combo - 1, 0, SCALE.size() - 1)
	var freq : float = float(SCALE[idx])
	# Bright pluck: quick attack, harmonic-rich
	_push_pluck(freq, 0.22, 0.6)
	# At high combo: add a sparkle overtone
	if combo >= 6:
		_push_pluck(freq * 2.0, 0.12, 0.3)

func play_fail() -> void:
	if _pb == null: return
	# Low thud + descending crunch
	_push_thud(90.0, 0.18, 0.55)
	_push_sweep(260.0, 150.0, 0.15, 0.35)

func play_level_up() -> void:
	if _pb == null: return
	# Triumphant ascending arpeggio
	var freqs := [SCALE[0], SCALE[2], SCALE[4], SCALE[7], SCALE[9]]
	_push_arp_fancy(freqs, 0.07, 0.32, 0.65)

func play_overflow() -> void:
	if _pb == null: return
	# Low explosion rumble
	_push_thud(55.0, 0.35, 0.7)
	_push_noise_hit(0.25, 0.4)

# ================================================================
#  SYNTHESIS PRIMITIVES
# ================================================================

# Pluck: fast attack, exponential decay, harmonics
func _push_pluck(freq: float, dur: float, vol: float) -> void:
	var n   := int(RATE * dur)
	var buf := PackedVector2Array()
	buf.resize(n)
	var t := 0.0; var dt := 1.0 / RATE
	for i in range(n):
		var env := exp(-t * 14.0)
		var s   := (sin(t * freq * TAU) * 0.6
		          + sin(t * freq * 2.0 * TAU) * 0.25
		          + sin(t * freq * 3.0 * TAU) * 0.10
		          + sin(t * freq * 5.0 * TAU) * 0.05) * vol * env
		buf[i] = Vector2(s, s)
		t += dt
	_pb.push_buffer(buf)

# Thud: sine at low freq, fast attack, slower decay
func _push_thud(freq: float, dur: float, vol: float) -> void:
	var n   := int(RATE * dur)
	var buf := PackedVector2Array()
	buf.resize(n)
	var t := 0.0; var dt := 1.0 / RATE
	for i in range(n):
		var env := exp(-t * 9.0)
		# Pitch descends quickly (classic thud)
		var f   := freq * (1.0 + exp(-t * 25.0) * 0.5)
		var s   := (sin(t * f * TAU)
		          + sin(t * f * 1.5 * TAU) * 0.3) * vol * env
		buf[i] = Vector2(s, s)
		t += dt
	_pb.push_buffer(buf)

# Sweep: frequency descends from start to end
func _push_sweep(f_start: float, f_end: float, dur: float, vol: float) -> void:
	var n   := int(RATE * dur)
	var buf := PackedVector2Array()
	buf.resize(n)
	var t := 0.0; var dt := 1.0 / RATE
	for i in range(n):
		var frac := t / dur
		var f    := f_start + (f_end - f_start) * frac
		var env  := (1.0 - frac) * exp(-t * 4.0)
		var s    := sin(t * f * TAU) * vol * env
		buf[i] = Vector2(s, s)
		t += dt
	_pb.push_buffer(buf)

# Arpeggio with pluck timbre per note
func _push_arp_fancy(freqs: Array, note_dur: float, decay: float, vol: float) -> void:
	var total := int(RATE * (note_dur * freqs.size() + decay))
	var buf   := PackedVector2Array()
	buf.resize(total)
	var t := 0.0; var dt := 1.0 / RATE
	for i in range(total):
		var ni   : int   = int(t / note_dur)
		var freq : float = float(freqs[clampi(ni, 0, freqs.size() - 1)])
		var nt   := fmod(t, note_dur)
		var env  := exp(-nt * 12.0) * maxf(1.0 - t / (note_dur * freqs.size() + decay), 0.0)
		var s    := (sin(t * freq * TAU) * 0.65
		           + sin(t * freq * 2.0 * TAU) * 0.2
		           + sin(t * freq * 3.0 * TAU) * 0.1) * vol * env
		buf[i] = Vector2(s, s)
		t += dt
	_pb.push_buffer(buf)

# Noise burst (impact feel)
func _push_noise_hit(dur: float, vol: float) -> void:
	var n   := int(RATE * dur)
	var buf := PackedVector2Array()
	buf.resize(n)
	var t := 0.0; var dt := 1.0 / RATE
	for i in range(n):
		var env := exp(-t * 18.0)
		var s   := randf_range(-1.0, 1.0) * vol * env
		buf[i] = Vector2(s, s)
		t += dt
	_pb.push_buffer(buf)
