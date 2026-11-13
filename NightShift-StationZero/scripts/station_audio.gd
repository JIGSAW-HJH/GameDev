extends Node
## V0.5 procedural audio: original tones generated locally, no external assets.
## AudioStreamWAV uses signed 16-bit little-endian PCM.
const RATE := 22050
var enabled := true
var alarm_active := false
var alarm_critical := false
var repeat_timer := 0.0
var ambience: AudioStreamPlayer
var effects: AudioStreamPlayer
var alarm: AudioStreamPlayer
var samples: Dictionary = {}

func _ready() -> void:
    ambience = AudioStreamPlayer.new()
    effects = AudioStreamPlayer.new()
    alarm = AudioStreamPlayer.new()
    add_child(ambience)
    add_child(effects)
    add_child(alarm)
    ambience.volume_db = -29.0
    effects.volume_db = -9.0
    alarm.volume_db = -13.0
    samples["click"] = _tone(620.0, 0.075, 0.19, "click")
    samples["breaker"] = _tone(170.0, 0.22, 0.42, "click")
    samples["warning"] = _tone(660.0, 0.28, 0.24, "pulse")
    samples["critical"] = _tone(900.0, 0.50, 0.31, "dual")
    samples["success"] = _tone(520.0, 0.32, 0.20, "success")
    var hum := _tone(56.0, 2.0, 0.12, "hum")
    hum.loop_mode = AudioStreamWAV.LOOP_FORWARD
    hum.loop_begin = 0
    hum.loop_end = int(2.0 * RATE)
    ambience.stream = hum
    ambience.play()

func _process(delta: float) -> void:
    if not enabled or not alarm_active:
        return
    repeat_timer -= delta
    if repeat_timer <= 0.0:
        alarm.stream = samples["critical"] if alarm_critical else samples["warning"]
        alarm.play()
        repeat_timer = 2.4 if alarm_critical else 4.0

func set_alarm(active: bool, critical: bool = false) -> void:
    if active != alarm_active or critical != alarm_critical:
        alarm_active = active
        alarm_critical = critical
        repeat_timer = 0.0
        if not active:
            alarm.stop()

func effect(kind: String) -> void:
    if enabled and samples.has(kind):
        effects.stream = samples[kind]
        effects.play()

func toggle_audio() -> bool:
    enabled = not enabled
    if enabled:
        ambience.play()
        repeat_timer = 0.0
    else:
        ambience.stop()
        effects.stop()
        alarm.stop()
    return enabled

func _tone(frequency: float, seconds: float, amplitude: float, shape: String) -> AudioStreamWAV:
    var frames := int(seconds * RATE)
    var bytes := PackedByteArray()
    bytes.resize(frames * 2)
    for n in range(frames):
        var t := float(n) / float(RATE)
        var phase := TAU * frequency * t
        var wave := sin(phase)
        if shape == "click":
            wave = (sin(phase) + 0.3 * sin(phase * 2.7)) * exp(-t * 22.0)
        elif shape == "pulse":
            wave *= 0.65 + 0.35 * sin(TAU * 7.0 * t)
        elif shape == "dual":
            wave = 0.5 * sin(phase) + 0.5 * sin(phase * 1.38)
        elif shape == "success":
            wave = sin(TAU * (frequency + 550.0 * t) * t)
        elif shape == "hum":
            wave = 0.75 * sin(phase) + 0.25 * sin(phase * 2.0)
        var edge := 1.0
        if shape != "hum":
            edge = minf(1.0, minf(t / 0.008, (seconds - t) / 0.025))
        var value := int(clampf(wave * amplitude * edge, -1.0, 1.0) * 32767.0)
        if value < 0:
            value += 65536
        bytes[n * 2] = value & 255
        bytes[n * 2 + 1] = (value >> 8) & 255
    var clip := AudioStreamWAV.new()
    clip.format = AudioStreamWAV.FORMAT_16_BITS
    clip.mix_rate = RATE
    clip.stereo = false
    clip.data = bytes
    return clip
