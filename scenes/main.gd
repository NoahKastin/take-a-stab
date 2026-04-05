extends Node3D
## Main scene: builds the hallway, manages lighting, spawns player and zombies.

const HALLWAY_WIDTH := 4.0
const HALLWAY_HEIGHT := 3.0
const HALLWAY_LENGTH := 2000.0
const WALL_THICKNESS := 0.2

var player: CharacterBody3D
var zombie_scene: PackedScene = preload("res://scenes/zombie/zombie.tscn")
var player_scene: PackedScene = preload("res://scenes/player/player.tscn")
var spawn_cooldown := 0.0


func _ready() -> void:
	_setup_lighting()
	_build_hallway()
	_spawn_player()
	_spawn_zombie()

	GameManager.zombie_killed.connect(_on_zombie_killed)
	GameManager.player_died.connect(_on_player_died)
	GameManager.game_reset.connect(_on_game_reset)


func _process(delta: float) -> void:
	if not GameManager.is_playing:
		return

	# Maintain minimum zombie count
	spawn_cooldown -= delta
	var active := _get_active_zombie_count()
	if active < 1:
		_spawn_zombie()
		spawn_cooldown = GameManager.get_spawn_interval()
	elif active < GameManager.get_max_zombies() and spawn_cooldown <= 0:
		_spawn_zombie()
		spawn_cooldown = GameManager.get_spawn_interval()


func _setup_lighting() -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -15, 0)
	light.light_energy = 1.0
	light.shadow_enabled = false  # Shadows can be unreliable in web/Compatibility renderer
	add_child(light)

	# Second light from behind for fill
	var fill_light := DirectionalLight3D.new()
	fill_light.rotation_degrees = Vector3(-30, 165, 0)
	fill_light.light_energy = 0.4
	fill_light.shadow_enabled = false
	add_child(fill_light)

	var env_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.08, 0.08, 0.1)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.4, 0.4, 0.45)
	environment.ambient_light_energy = 0.7
	env_node.environment = environment
	add_child(env_node)


func _build_hallway() -> void:
	var half_w := HALLWAY_WIDTH / 2.0
	var half_t := WALL_THICKNESS / 2.0

	# Floor (surface at y=0)
	_add_static_box(
		Vector3(HALLWAY_WIDTH, WALL_THICKNESS, HALLWAY_LENGTH),
		Vector3(0, -half_t, 0),
		Color(0.3, 0.3, 0.3)
	)
	# Ceiling
	_add_static_box(
		Vector3(HALLWAY_WIDTH, WALL_THICKNESS, HALLWAY_LENGTH),
		Vector3(0, HALLWAY_HEIGHT + half_t, 0),
		Color(0.22, 0.22, 0.24)
	)
	# Left wall
	_add_static_box(
		Vector3(WALL_THICKNESS, HALLWAY_HEIGHT, HALLWAY_LENGTH),
		Vector3(-half_w - half_t, HALLWAY_HEIGHT / 2.0, 0),
		Color(0.35, 0.33, 0.32)
	)
	# Right wall
	_add_static_box(
		Vector3(WALL_THICKNESS, HALLWAY_HEIGHT, HALLWAY_LENGTH),
		Vector3(half_w + half_t, HALLWAY_HEIGHT / 2.0, 0),
		Color(0.35, 0.33, 0.32)
	)


func _add_static_box(size: Vector3, pos: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)

	var mesh_inst := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_inst.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh_inst.set_surface_override_material(0, mat)
	body.add_child(mesh_inst)

	add_child(body)


func _spawn_player() -> void:
	player = player_scene.instantiate()
	player.position = Vector3(0, 0, 0)
	add_child(player)


func _spawn_zombie() -> void:
	var zombie := zombie_scene.instantiate()
	var half_w := HALLWAY_WIDTH / 2.0 - 0.5
	var spawn_x := randf_range(-half_w, half_w)
	var spawn_z := player.position.z - randf_range(15.0, 25.0)
	zombie.position = Vector3(spawn_x, 0, spawn_z)
	zombie.target = player
	add_child(zombie)


func _get_active_zombie_count() -> int:
	var count := 0
	for zombie in get_tree().get_nodes_in_group("zombies"):
		if not zombie.is_dead:
			count += 1
	return count


func _on_zombie_killed() -> void:
	spawn_cooldown = GameManager.get_spawn_interval()


func _on_player_died() -> void:
	# Graybox death: brief pause, clear zombies, reset
	# TODO Phase 2: replace with camera pan to watch + "Play Again" button
	for zombie in get_tree().get_nodes_in_group("zombies"):
		if not zombie.is_dead:
			zombie.die(Color.SILVER, Vector3.FORWARD)
	await get_tree().create_timer(1.0).timeout
	if not GameManager.is_playing:
		GameManager.reset_score()


func _on_game_reset() -> void:
	spawn_cooldown = 0.0
	_spawn_zombie()
