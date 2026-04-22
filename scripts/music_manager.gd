extends Node
## Autoloaded adaptive music engine.
## Scans stems/ at startup, drives intensity from kill rate,
## layers instruments vertically and swaps energy tiers at per-stem loop boundaries.

const BAR_DURATION := 2.4  # 1 bar at 100 BPM (4 beats / 100 BPM * 60s)

# Intensity tuning
const KILL_BOOST := 0.15
const DECAY_RATE := 0.94  # Per-second multiplicative decay (slower = intensity lingers longer)

# Vertical mixing: intensity at which each instrument becomes audible
const VERT_THRESHOLDS := {
	"drums": 0.0,
	"bass": 0.0,
	"keys": 0.0,
	"lead": 0.0,
}

const TIERS := ["low", "med", "high", "peak"]
const TIER_BREAKS := [0.0, 0.15, 0.35, 0.6]
const INSTRUMENTS := ["drums", "bass", "keys", "lead"]

const VOL_SPEED := 3.0       # Linear volume change per second
const CHANNEL_DB := -6.0     # Max dB per channel (headroom for 4 simultaneous layers)
const DEATH_DRUM_VOL := 0.3  # Reduced drum level during death sequence

var intensity := 0.0
var is_dead := false

var catalog := {}       # { inst: { tier: [path, ...] } }
var players := {}       # inst -> AudioStreamPlayer
var vol_cur := {}       # inst -> float (0.0-1.0)
var vol_tgt := {}       # inst -> float (0.0-1.0)
var loop_timers := {}   # inst -> float (seconds until this instrument's next loop point)


func _ready() -> void:
	_build_catalog()
	_create_channels()
	GameManager.zombie_killed.connect(_on_kill)
	GameManager.player_died.connect(_on_death)
	GameManager.game_reset.connect(_on_reset)
	_begin_all()


func _build_catalog() -> void:
	for inst in INSTRUMENTS:
		catalog[inst] = {}
		for tier in TIERS:
			catalog[inst][tier] = []
	var dir := DirAccess.open("res://stems/")
	if not dir:
		push_warning("MusicManager: cannot open res://stems/")
		return
	# Enumerate .wav.import files: these exist in both the editor and exported
	# builds, whereas raw .wav files are stripped from the PCK at export time
	# (converted to .sample files under res://.godot/imported/).
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if f.ends_with(".wav.import"):
			var wav_name := f.trim_suffix(".import")  # "foo.wav"
			var base := wav_name.get_basename()       # "foo"
			var parts := base.rsplit("_", false, 2)
			if parts.size() >= 3:
				var inst: String = parts[parts.size() - 2]
				var tier: String = parts[parts.size() - 1]
				if inst in INSTRUMENTS and tier in TIERS:
					catalog[inst][tier].append("res://stems/" + wav_name)
		f = dir.get_next()


func _create_channels() -> void:
	for inst in INSTRUMENTS:
		var p := AudioStreamPlayer.new()
		p.volume_db = -80.0
		add_child(p)
		players[inst] = p
		vol_cur[inst] = 0.0
		vol_tgt[inst] = 0.0
		loop_timers[inst] = 0.0


func _process(delta: float) -> void:
	# Keep processing during death for the fade-out
	if not GameManager.is_playing and not is_dead:
		return

	# Decay intensity
	if not is_dead:
		intensity *= pow(DECAY_RATE, delta)
		if intensity < 0.001:
			intensity = 0.0

	# Volume targets
	if is_dead:
		for inst in INSTRUMENTS:
			vol_tgt[inst] = DEATH_DRUM_VOL if inst == "drums" else 0.0
	else:
		for inst in INSTRUMENTS:
			vol_tgt[inst] = 1.0

	# Interpolate volumes
	for inst in INSTRUMENTS:
		vol_cur[inst] = move_toward(vol_cur[inst], vol_tgt[inst], VOL_SPEED * delta)
		if vol_cur[inst] > 0.001:
			players[inst].volume_db = linear_to_db(vol_cur[inst]) + CHANNEL_DB
		else:
			players[inst].volume_db = -80.0

	# Per-instrument loop boundaries
	for inst in INSTRUMENTS:
		loop_timers[inst] -= delta
		if loop_timers[inst] <= 0.0:
			_loop_instrument(inst)


func _loop_instrument(inst: String) -> void:
	var tier := _tier()
	var pool: Array = catalog[inst][tier]
	if pool.is_empty():
		pool = _fallback(inst, tier)
	if pool.is_empty():
		loop_timers[inst] = BAR_DURATION  # Retry next bar
		return
	var stream = load(pool[randi() % pool.size()])
	if stream:
		players[inst].stream = stream
		players[inst].play()
		# Round stem length to nearest bar boundary to trim reverb tails
		var bars := maxf(roundf(stream.get_length() / BAR_DURATION), 1.0)
		loop_timers[inst] = bars * BAR_DURATION
	else:
		loop_timers[inst] = BAR_DURATION


func _begin_all() -> void:
	for inst in INSTRUMENTS:
		_loop_instrument(inst)


func _tier() -> String:
	for i in range(TIER_BREAKS.size() - 1, -1, -1):
		if intensity >= TIER_BREAKS[i]:
			return TIERS[i]
	return "low"


func _fallback(inst: String, from_tier: String) -> Array:
	var idx := TIERS.find(from_tier)
	for i in range(idx - 1, -1, -1):
		if not catalog[inst][TIERS[i]].is_empty():
			return catalog[inst][TIERS[i]]
	return []


func _on_kill() -> void:
	if not is_dead:
		intensity = minf(intensity + KILL_BOOST, 1.0)


func _on_death() -> void:
	is_dead = true
	intensity = 0.0


func _on_reset() -> void:
	is_dead = false
	intensity = 0.0
	_begin_all()
