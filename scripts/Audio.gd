class_name GameAudio
extends Node
# Procedural audio — no external files needed.
# Generates tones via AudioStreamGenerator.

var _player : AudioStreamPlayer
var _gen    : AudioStreamGenerator
var _pb     : AudioStreamGeneratorPlayback

const SAMPLE_RATE := 22050.0
const BUF_SIZE    := 512

# Note frequencies
const NOTE_SUCCESS := [523.25, 659.25, 783.99]   # C5 E5 G5 (major arp)
const NOTE_FAIL    := [220.0,  185.0]             # A3 → F#3 (descend)
const NOTE_COMBO   := [783.99, 1046.5]            # G5 C6

func _ready() -> void:
	_gen = AudioStreamGenerator.new()
	_gen.mix_rate   = SAMPLE_RATE
	_gen.buffer_length = 0.1

	_player = AudioStreamPlayer.new()
	_player.stream = _gen
	_player.volume_db = -6.0
	add_child(_player)
	_player.play()
	_pb = _player.get_stream_playback()

func play_success(combo: int) -> void:
	var notes := NOTE_SUCCESS
	if combo >= 5:
		notes = [NOTE_SUCCESS[0], NOTE_SUCCESS[1], NOTE_SUCCESS[2], NOTE_SUCCESS[2] * 2.0]
	_play_arp(notes, 0.06, 0.18, 0.7)

func play_fail() -> void:
	_play_arp(NOTE_FAIL, 0.08, 0.14, 0.5)

func play_level_up() -> void:
	_play_arp([523.25, 659.25, 783.99, 1046.5], 0.05, 0.22, 0.85)

func _play_arp(freqs: Array, note_dur: float, decay: float, vol: float) -> void:
	if _pb == null:
		return
	var total_samples := int(SAMPLE_RATE * (note_dur * freqs.size() + decay))
	var frames := PackedVector2Array()
	frames.resize(total_samples)

	var t := 0.0
	var dt := 1.0 / SAMPLE_RATE

	for i in range(total_samples):
		var note_idx: int   = int(t / note_dur)
		var freq:     float = freqs[clampi(note_idx, 0, freqs.size() - 1)]

		# Envelope: attack per note + overall decay
		var note_t   := fmod(t, note_dur)
		var envelope := minf(note_t / 0.005, 1.0)                    # 5ms attack
		envelope     *= maxf(1.0 - (t / (note_dur * freqs.size() + decay)), 0.0)  # decay

		var sample := sin(t * freq * TAU) * vol * envelope
		# Add slight harmonic
		sample += sin(t * freq * 2.0 * TAU) * vol * 0.15 * envelope
		frames[i] = Vector2(sample, sample)
		t += dt

	_pb.push_buffer(frames)
