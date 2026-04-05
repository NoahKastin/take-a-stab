extends Node
## Autoloaded game state manager.
## Tracks kills, time, difficulty scaling, and game flow signals.

signal zombie_killed
signal player_died
signal game_reset

var kills: int = 0
var time_elapsed: float = 0.0
var is_playing: bool = true


func _process(delta: float) -> void:
	if is_playing:
		time_elapsed += delta


func add_kill() -> void:
	kills += 1
	zombie_killed.emit()


func player_bitten() -> void:
	# Soft reset: score/time reset, game continues immediately
	kills = 0
	time_elapsed = 0.0
	player_died.emit()


func reset_score() -> void:
	kills = 0
	time_elapsed = 0.0
	is_playing = true
	game_reset.emit()


func get_max_zombies() -> int:
	# Uncapped: +1 zombie every 5 kills
	return 1 + kills / 5


func get_spawn_interval() -> float:
	# Spawns get faster over time, floor at 1 second
	return maxf(3.0 - kills * 0.1, 1.0)
