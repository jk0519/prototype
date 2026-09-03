extends Node
var enabled: bool = true
var voices: Array = []
var samples: Dictionary = {}
var cursor: int = 0

func _ready() -> void:
	for i in range(5):
		var voice = AudioStreamPlayer.new()
		voice.volume_db = -15
		add_child(voice)
		voices.append(voice)
	for kind in ["serve", "receive", "set", "spike", "block", "dive", "free", "point", "net"]:
		samples[kind] = make_sound(kind)

func play(kind: String) -> void:
	if not enabled or not samples.has(kind) or voices.is_empty():
		return
	var voice = voices[cursor % voices.size()]
	cursor += 1
	voice.stream = samples[kind]
	voice.play()

func make_sound(kind: String) -> AudioStreamWAV:
	var length = 0.28 if kind == "point" else 0.095
	var rate = 22050
	var count = int(rate * length)
	var data = PackedByteArray()
	data.resize(count * 2)
	var frequency = {"serve": 230, "receive": 290, "set": 420, "spike": 145, "block": 190, "dive": 220, "free": 350, "point": 560, "net": 115}[kind]
	for i in range(count):
		var t = float(i) / rate
		var envelope = pow(1.0 - t / length, 2.5) * minf(t * 1800, 1.0)
		var hz = frequency * (1.0 - t * 2.0) if kind != "point" else frequency * (1.0 + t * 2.0)
		var value = sin(TAU * hz * t) * 0.7 + sin(TAU * hz * 2.7 * t) * 0.18
		data.encode_s16(i * 2, int(value * envelope * 28000))
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	return wav
