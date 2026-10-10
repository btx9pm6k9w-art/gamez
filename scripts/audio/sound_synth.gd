class_name SoundSynth
## Procedural sound design used until recorded assets land in res://audio/.
## Every sound is layered the way a sound designer would build it: a sharp
## transient, a body, a low-end tail and texture (crackle, debris, hiss).
## All functions are static and thread-safe so Audio can render in the
## background at startup.

const RATE := 44100
const MUSIC_RATE := 22050


static func to_wav(samples: PackedFloat32Array, rate: int, loop := false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	var peak := 0.0001
	for s in samples:
		peak = maxf(peak, absf(s))
	var gain := 0.89 / peak # normalise to about -1 dBFS
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i] * gain, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


static func _buffer(seconds: float, rate := RATE) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * rate))
	b.fill(0.0)
	return b


## One-pole low-pass filter whose cutoff follows a curve from start to end.
static func _lowpass(buf: PackedFloat32Array, cutoff_start: float, cutoff_end: float, rate := RATE) -> void:
	var y := 0.0
	var n := buf.size()
	for i in n:
		var fc := lerpf(cutoff_start, cutoff_end, float(i) / n)
		var a := 1.0 - exp(-TAU * fc / rate)
		y += a * (buf[i] - y)
		buf[i] = y


static func _highpass(buf: PackedFloat32Array, cutoff: float, rate := RATE) -> void:
	var a := exp(-TAU * cutoff / rate)
	var prev_x := 0.0
	var y := 0.0
	for i in buf.size():
		var x := buf[i]
		y = a * (y + x - prev_x)
		prev_x = x
		buf[i] = y


static func _mix(dst: PackedFloat32Array, src: PackedFloat32Array, gain: float, offset := 0) -> void:
	for i in src.size():
		var j := i + offset
		if j >= dst.size():
			break
		dst[j] += src[i] * gain


static func _noise(seconds: float, decay: float, rng: RandomNumberGenerator, rate := RATE) -> PackedFloat32Array:
	var b := _buffer(seconds, rate)
	for i in b.size():
		var t := float(i) / rate
		b[i] = rng.randf_range(-1.0, 1.0) * exp(-t * decay)
	return b


## Sine with an exponential pitch drop: the "boom" and "thump" layer.
static func _sweep(seconds: float, f0: float, f1: float, decay: float, rate := RATE) -> PackedFloat32Array:
	var b := _buffer(seconds, rate)
	var phase := 0.0
	for i in b.size():
		var t := float(i) / rate
		var f := f1 + (f0 - f1) * exp(-t * 6.0)
		phase += TAU * f / rate
		b[i] = sin(phase) * exp(-t * decay)
	return b


## Sparse crackles and falling debris for explosion tails.
static func _crackle(seconds: float, density: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var b := _buffer(seconds)
	var i := int(0.08 * RATE)
	while i < b.size():
		var t := float(i) / RATE
		var amp := rng.randf_range(0.2, 1.0) * exp(-t * 1.6)
		var burst := rng.randi_range(40, 400)
		for k in burst:
			if i + k < b.size():
				b[i + k] += rng.randf_range(-1.0, 1.0) * amp * exp(-float(k) / (burst * 0.3))
		i += int(RATE / (density * rng.randf_range(0.4, 1.6)))
	_highpass(b, 900.0)
	return b


static func explosion(seed_value: int, size: float) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var dur := 1.6 + size * 0.9
	var out := _buffer(dur)
	var blast := _noise(dur, 2.2 / size, rng)
	_lowpass(blast, 5000.0, 160.0)
	_mix(out, blast, 1.0)
	var transient := _noise(0.05, 70.0, rng)
	_mix(out, transient, 0.9)
	var boom := _sweep(dur, 95.0, 32.0, 2.0 / size)
	_mix(out, boom, 1.3)
	var debris := _crackle(dur, 22.0, rng)
	_mix(out, debris, 0.35)
	# Soft saturation glues the layers like a real recording at close range.
	for i in out.size():
		out[i] = tanh(out[i] * 1.6)
	return to_wav(out, RATE)


static func cannon(seed_value: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out := _buffer(1.5)
	var crack := _noise(0.08, 45.0, rng)
	_mix(out, crack, 1.0)
	var body := _noise(1.5, 4.0, rng)
	_lowpass(body, 2200.0, 120.0)
	_mix(out, body, 1.1)
	_mix(out, _sweep(1.5, 140.0, 40.0, 3.5), 1.4)
	# Short slap-back echo off the terrain.
	var echo := out.duplicate()
	_lowpass(echo, 1200.0, 600.0)
	_mix(out, echo, 0.28, int(0.19 * RATE))
	for i in out.size():
		out[i] = tanh(out[i] * 1.4)
	return to_wav(out, RATE)


static func rifle(seed_value: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out := _buffer(0.45)
	var crack := _noise(0.45, 38.0, rng)
	_highpass(crack, 1400.0)
	_mix(out, crack, 1.0)
	var body := _noise(0.45, 18.0, rng)
	_lowpass(body, 1800.0, 300.0)
	_mix(out, body, 0.8)
	_mix(out, _sweep(0.3, 220.0, 90.0, 22.0), 0.5)
	var echo := out.duplicate()
	_lowpass(echo, 900.0, 500.0)
	_mix(out, echo, 0.2, int(0.11 * RATE))
	return to_wav(out, RATE)


static func laser() -> AudioStreamWAV:
	var out := _buffer(0.5)
	var phase := 0.0
	var mod := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var f := 2600.0 * exp(-t * 4.0) + 420.0
		mod += TAU * 37.0 / RATE
		phase += TAU * f * (1.0 + 0.04 * sin(mod)) / RATE
		var env := minf(t * 300.0, 1.0) * exp(-t * 6.0)
		out[i] = (sin(phase) * 0.7 + sin(phase * 2.01) * 0.3) * env
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var hiss := _noise(0.5, 8.0, rng)
	_highpass(hiss, 4000.0)
	_mix(out, hiss, 0.15)
	return to_wav(out, RATE)


## The Shahed's two-stroke engine: a raspy pulse around 55 Hz with jitter.
## Seamless loop.
static func drone_engine() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var out := _buffer(2.0)
	var phase := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var f := 58.0 + sin(TAU * t * 0.5) * 2.0
		phase += f / RATE
		var p := fmod(phase, 1.0)
		var pulse := 1.0 if p < 0.22 else -0.3
		out[i] = pulse + rng.randf_range(-0.25, 0.25)
	_lowpass(out, 1400.0, 1400.0)
	_crossfade_loop(out, int(0.1 * RATE))
	return to_wav(out, RATE, true)


static func engine_rumble() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var out := _buffer(3.0)
	var phase := 0.0
	for i in out.size():
		var t := float(i) / RATE
		phase += TAU * (32.0 + sin(TAU * t * 0.33) * 1.5) / RATE
		out[i] = sin(phase) * 0.6 + sin(phase * 2.0) * 0.25 + sin(phase * 3.0) * 0.15 + rng.randf_range(-0.4, 0.4)
	_lowpass(out, 500.0, 500.0)
	_crossfade_loop(out, int(0.2 * RATE))
	return to_wav(out, RATE, true)


static func missile_whoosh() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var out := _noise(3.0, 0.0, rng)
	for i in out.size():
		var t := float(i) / RATE
		out[i] *= pow(t / 3.0, 2.0)
	_lowpass(out, 300.0, 6000.0)
	return to_wav(out, RATE)


## Fighter jet pass: broadband roar, low rumble and a turbine whine. Looped;
## the 3D player's doppler tracking supplies the pitch drop as it passes.
static func jet() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var roar := _noise(3.0, 0.0, rng)
	_lowpass(roar, 2600.0, 2600.0)
	var out := _buffer(3.0)
	var phase := 0.0
	var whine := 0.0
	for i in out.size():
		var t := float(i) / RATE
		phase += TAU * (48.0 + sin(TAU * t * 0.7) * 3.0) / RATE
		whine += TAU * (3150.0 + sin(TAU * t * 1.3) * 40.0) / RATE
		out[i] = roar[i] * 1.2 + sin(phase) * 0.35 + sin(whine) * 0.05
	_crossfade_loop(out, int(0.25 * RATE))
	return to_wav(out, RATE, true)


## Falling bomb: a descending whistle that swells as it nears the ground.
static func bomb_whistle() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 37
	var dur := 1.7
	var out := _buffer(dur)
	var phase := 0.0
	for i in out.size():
		var t := float(i) / RATE
		var f := lerpf(1900.0, 650.0, pow(t / dur, 0.8)) + sin(TAU * t * 7.0) * 12.0
		phase += TAU * f / RATE
		var env := pow(t / dur, 1.5) * (1.0 - smoothstep(dur - 0.04, dur, t))
		out[i] = (sin(phase) * 0.8 + rng.randf_range(-0.25, 0.25)) * env
	return to_wav(out, RATE)


## Burning wreck or crater: crackles and pops over a low roar of flame.
static func fire() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var out := _noise(4.0, 0.0, rng)
	_lowpass(out, 380.0, 380.0)
	for i in out.size():
		out[i] *= 0.9 + 0.3 * sin(TAU * float(i) / RATE * 0.8)
	var pops := _buffer(4.0)
	var k := 0
	while k < pops.size():
		var amp := rng.randf_range(0.15, 1.0)
		var burst := rng.randi_range(30, 260)
		for j in burst:
			if k + j < pops.size():
				pops[k + j] += rng.randf_range(-1.0, 1.0) * amp * exp(-float(j) / (burst * 0.25))
		k += int(RATE / rng.randf_range(6.0, 30.0))
	_highpass(pops, 1200.0)
	_mix(out, pops, 0.7)
	_crossfade_loop(out, int(0.2 * RATE))
	return to_wav(out, RATE, true)


static func blip(freqs: Array, note_len: float) -> AudioStreamWAV:
	var out := _buffer(note_len * freqs.size() + 0.05)
	for n in freqs.size():
		var start := int(n * note_len * RATE)
		for i in int(note_len * RATE):
			var t := float(i) / RATE
			var env := minf(t * 400.0, 1.0) * exp(-t * 18.0)
			out[start + i] += (sin(TAU * float(freqs[n]) * t) + 0.3 * sin(TAU * float(freqs[n]) * 2.0 * t)) * env
	return to_wav(out, RATE)


## Radio squelch: a burst of band-passed static before an alert.
static func radio() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var out := _noise(0.35, 6.0, rng)
	_highpass(out, 1200.0)
	_lowpass(out, 3500.0, 3500.0)
	var tone := blip([880.0, 660.0], 0.12)
	var w := PackedFloat32Array()
	w.resize(tone.data.size() / 2)
	for i in w.size():
		w[i] = tone.data.decode_s16(i * 2) / 32767.0
	_mix(out, w, 0.6, int(0.05 * RATE))
	return to_wav(out, RATE)


## Desert coast ambience: gusting wind and slow surf, seamless loop.
static func ambience() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var dur := 16.0
	var wind := _noise(dur, 0.0, rng, MUSIC_RATE)
	_lowpass(wind, 500.0, 500.0, MUSIC_RATE)
	var surf := _noise(dur, 0.0, rng, MUSIC_RATE)
	_lowpass(surf, 900.0, 900.0, MUSIC_RATE)
	var out := _buffer(dur, MUSIC_RATE)
	for i in out.size():
		var t := float(i) / MUSIC_RATE
		var gust := 0.55 + 0.45 * sin(TAU * t / 8.0) * sin(TAU * t / 5.33)
		var wave := pow(maxf(sin(TAU * t / 8.0), 0.0), 3.0)
		out[i] = wind[i] * gust * 0.8 + surf[i] * (0.15 + wave * 0.9)
	_crossfade_loop(out, int(1.0 * MUSIC_RATE))
	return to_wav(out, MUSIC_RATE, true)


static func _crossfade_loop(buf: PackedFloat32Array, fade: int) -> void:
	var n := buf.size()
	for i in fade:
		var a := float(i) / fade
		buf[i] = buf[i] * a + buf[n - fade + i] * (1.0 - a)
	buf.resize(n - fade)


# --- Adaptive music stems -------------------------------------------------
# Three stems of the same 8 bars (90 BPM, D minor: Dm - Bb - F - C) that the
# Audio manager crossfades by combat intensity: calm pad, tension ostinato,
# combat percussion.

const BPM := 90.0
const BARS := 8
const CHORDS := [[50, 53, 57], [46, 50, 53], [53, 57, 60], [48, 52, 55]] # MIDI


static func _midi_hz(n: float) -> float:
	return 440.0 * pow(2.0, (n - 69.0) / 12.0)


static func _saw_table() -> PackedFloat32Array:
	var t := PackedFloat32Array()
	t.resize(2048)
	for i in 2048:
		var x := 0.0
		for h in range(1, 14):
			x += sin(TAU * h * i / 2048.0) / h
		t[i] = x * 0.55
	return t


static func _beats_len() -> float:
	return BARS * 4.0 * 60.0 / BPM


static func music_pad() -> AudioStreamWAV:
	var table := _saw_table()
	var dur := _beats_len()
	var out := _buffer(dur, MUSIC_RATE)
	var bar_len := 4.0 * 60.0 / BPM
	var phases := PackedFloat32Array()
	phases.resize(18)
	for i in out.size():
		var t := float(i) / MUSIC_RATE
		var bar := int(t / bar_len)
		var chord: Array = CHORDS[(bar / 2) % 4]
		var local := fmod(t, bar_len * 2.0)
		var env := minf(local / 1.2, 1.0) * minf((bar_len * 2.0 - local) / 0.6 + 0.25, 1.0)
		var s := 0.0
		var k := 0
		for note: int in chord:
			for detune in [-0.09, 0.0, 0.08]:
				var f := _midi_hz(note + detune)
				phases[k] = fmod(phases[k] + f * 2048.0 / MUSIC_RATE, 2048.0)
				s += table[int(phases[k])]
				k += 1
		# Low root an octave down for weight.
		var fr := _midi_hz(float(chord[0]) - 12.0)
		phases[17] = fmod(phases[17] + fr * 2048.0 / MUSIC_RATE, 2048.0)
		s += table[int(phases[17])] * 1.5
		out[i] = s * env
	_lowpass(out, 1400.0, 1400.0, MUSIC_RATE)
	_add_reverb(out, MUSIC_RATE)
	return to_wav(out, MUSIC_RATE, true)


static func music_ostinato() -> AudioStreamWAV:
	var table := _saw_table()
	var dur := _beats_len()
	var out := _buffer(dur, MUSIC_RATE)
	var eighth := 30.0 / BPM
	var pattern := [0, 0, 2, 0, 1, 0, 2, 1] # chord-tone index per eighth note
	var rng := RandomNumberGenerator.new()
	rng.seed = 51
	var steps := int(dur / eighth)
	for s in steps:
		var bar := int(s / 8)
		var chord: Array = CHORDS[(bar / 2) % 4]
		var note: float = float(chord[pattern[s % 8]]) - 12.0
		var f := _midi_hz(note)
		var start := int(s * eighth * MUSIC_RATE)
		var length := int(eighth * MUSIC_RATE)
		var ph := 0.0
		for i in length:
			var t := float(i) / MUSIC_RATE
			ph = fmod(ph + f * 2048.0 / MUSIC_RATE, 2048.0)
			out[start + i] += table[int(ph)] * exp(-t * 9.0) * (1.0 if s % 2 == 0 else 0.7)
		# Ticking hi-hat on sixteenths.
		for half in 2:
			var hs := start + half * length / 2
			for i in 900:
				if hs + i < out.size():
					out[hs + i] += rng.randf_range(-1, 1) * exp(-float(i) / 120.0) * 0.12
	_lowpass(out, 2600.0, 2600.0, MUSIC_RATE)
	_add_reverb(out, MUSIC_RATE)
	return to_wav(out, MUSIC_RATE, true)


static func music_drums() -> AudioStreamWAV:
	var dur := _beats_len()
	var out := _buffer(dur, MUSIC_RATE)
	var beat := 60.0 / BPM
	var rng := RandomNumberGenerator.new()
	rng.seed = 61
	# Taiko-style pattern in sixteenths per bar: big hits, ghost hits, snares.
	var taiko := [1.0, 0, 0, 0.4, 0, 0, 0.8, 0, 1.0, 0, 0.35, 0, 0, 0.5, 0.7, 0.4]
	var snare := [0, 0, 0, 0, 1.0, 0, 0, 0, 0, 0, 0, 0, 1.0, 0, 0, 0.3]
	var steps := BARS * 16
	for s in steps:
		var start := int(s * beat * 0.25 * MUSIC_RATE)
		var tv: float = taiko[s % 16]
		if tv > 0.0:
			var ph := 0.0
			for i in int(0.7 * MUSIC_RATE):
				var t := float(i) / MUSIC_RATE
				ph += TAU * (48.0 + 90.0 * exp(-t * 18.0)) / MUSIC_RATE
				if start + i < out.size():
					out[start + i] += (sin(ph) + rng.randf_range(-0.15, 0.15) * exp(-t * 40.0)) * exp(-t * 5.0) * tv
		var sv: float = snare[s % 16]
		if sv > 0.0:
			for i in int(0.3 * MUSIC_RATE):
				var t := float(i) / MUSIC_RATE
				if start + i < out.size():
					out[start + i] += (rng.randf_range(-1, 1) * 0.6 + sin(TAU * 190.0 * t) * 0.4) * exp(-t * 14.0) * sv * 0.6
	_add_reverb(out, MUSIC_RATE)
	return to_wav(out, MUSIC_RATE, true)


## Cheap stereo-free hall: a few feedback delay taps.
static func _add_reverb(buf: PackedFloat32Array, rate: int) -> void:
	var src := buf.duplicate()
	for tap in [[0.037, 0.35], [0.071, 0.28], [0.113, 0.22], [0.173, 0.16], [0.241, 0.1]]:
		_mix(buf, src, tap[1], int(float(tap[0]) * rate))
