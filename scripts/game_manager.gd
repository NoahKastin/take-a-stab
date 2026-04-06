extends Node
## Autoloaded game state manager.
## Tracks kills, time, difficulty scaling, and game flow signals.

signal zombie_killed
signal player_died
signal game_reset

var kills: int = 0
var time_elapsed: float = 0.0
var is_playing: bool = true
var high_score: int = 0
var biting_zombie: Node = null

const SAVE_PATH := "user://highscore.save"


func _ready() -> void:
	_load_high_score()


func _process(delta: float) -> void:
	if is_playing:
		time_elapsed += delta


func add_kill() -> void:
	kills += 1
	if kills > high_score:
		high_score = kills
		_save_high_score()
	zombie_killed.emit()


func _load_high_score() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			high_score = file.get_32()


func _save_high_score() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_32(high_score)


func player_bitten(zombie: Node = null) -> void:
	if not is_playing:
		return
	biting_zombie = zombie
	is_playing = false
	player_died.emit()


func reset_score() -> void:
	kills = 0
	time_elapsed = 0.0
	biting_zombie = null
	is_playing = true
	game_reset.emit()


func get_max_zombies() -> int:
	# Uncapped: +1 zombie every 5 kills
	return 1 + kills / 5


func get_spawn_interval() -> float:
	# Spawns get faster over time, floor at 1 second
	return maxf(3.0 - kills * 0.1, 1.0)
