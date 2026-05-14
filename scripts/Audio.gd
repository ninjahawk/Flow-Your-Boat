class_name GameAudio
extends Node

var _player: AudioStreamPlayer
var _pb:     AudioStreamGeneratorPlayback

const SAMPLE_RATE := 22050.0

# Base note frequencies (C major pentatonic)
const NOTES := [261.63, 293.66, 329.63, 392.00, 440.00,
                523.25, 587.33, 659.25, 783.99, 880.00]

func _ready() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate       = SAMPLE_RATE
	gen.buffer_length  = 0.12

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
	# Pitch rises with combo — each sort steps up the scale
	var note_idx : int   = clampi((combo - 1) % NOTES.size(), 0, NOTES.size() - 1)
	var freq     : float = float(NOTES[note_idx])

	if combo >= 5:
		# Arpeggio burst on big combos
		_push_arp([freq, freq * 1.26, freq * 1.5], 0.055, 0.20, 0.55)
	else:
		_push_tone(freq, 0.18, 0.55, 0.65)

func play_fail() -> void:
	_push_arp([180.0, 140.0], 0.09, 0.18, 0.5)

func play_level_up() -> void:
	_push_arp([NOTES[0], NOTES[2], NOTES[4], NOTES[7], NOTES[9]],
	          0.06, 0.28, 0.75)

func play_overflow() -> void:
	# Low impact boom
	_push_noise_burst(0.22, 0.45)

# ================================================================
#  SYNTHESIS HELPERS
# ================================================================

func _push_tone(freq: float, dur: float, vol: float, decay: float) -> void:
	if _pb == null: return
	var n     := int(SAMPLE_RATE * (dur + decay))
	var buf   := PackedVector2Array()
	buf.resize(n)
	var t     := 0.0
	var dt    := 1.0 / SAMPLE_RATE
	for i in range(n):
		var env := minf(t / 0.004, 1.0) * maxf(1.0 - (t - dur) / decay, 0.0)
		var s   := (sin(t * freq * TAU)
		          + sin(t * freq * 2.0 * TAU) * 0.18
		          + sin(t * freq * 3.0 * TAU) * 0.06) * vol * env
		buf[i] = Vector2(s, s)
		t += dt
	_pb.push_buffer(buf)

func _push_arp(freqs: Array, note_dur: float, decay: float, vol: float) -> void:
	if _pb == null: return
	var total := int(SAMPLE_RATE * (note_dur * freqs.size() + decay))
	var buf   := PackedVector2Array()
	buf.resize(total)
	var t  := 0.0
	var dt := 1.0 / SAMPLE_RATE
	for i in range(total):
		var ni:   int   = int(t / note_dur)
		var freq: float = float(freqs[clampi(ni, 0, freqs.size() - 1)])
		var nt  := fmod(t, note_dur)
		var env := minf(nt / 0.004, 1.0) \
		         * maxf(1.0 - (t / (note_dur * freqs.size() + decay)), 0.0)
		var s   := (sin(t * freq * TAU) + sin(t * freq * 2.0 * TAU) * 0.15) * vol * env
		buf[i] = Vector2(s, s)
		t += dt
	_pb.push_buffer(buf)

func _push_noise_burst(dur: float, vol: float) -> void:
	if _pb == null: return
	var n  := int(SAMPLE_RATE * dur)
	var buf := PackedVector2Array()
	buf.resize(n)
	var t  := 0.0
	var dt := 1.0 / SAMPLE_RATE
	# Low rumble: filtered noise on a 60Hz bass tone
	for i in range(n):
		var env := maxf(1.0 - t / dur, 0.0)
		env = env * env
		var s   := (randf_range(-1.0, 1.0) * 0.4 + sin(t * 60.0 * TAU) * 0.6) * vol * env
		buf[i] = Vector2(s, s)
		t += dt
	_pb.push_buffer(buf)
