extends CharacterBody3D
## Zombie: walks toward the player, bites when close.
## Builds its own mesh (body + head) with random colors.

const MOVE_SPEED := 2.0
const BITE_RANGE := 1.0
const GRAVITY := 9.8

var target: Node3D = null
var is_dead := false
var has_bitten := false

var head_node: Node3D
var body_mesh: MeshInstance3D
var head_mesh: MeshInstance3D
var collision_shape: CollisionShape3D


func _ready() -> void:
	add_to_group("zombies")

	# Collision: layer 2 (characters), mask 1|2 (env + characters)
	collision_layer = 2
	collision_mask = 3

	# Body collision (capsule covering full height)
	collision_shape = CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.25
	capsule.height = 1.8
	collision_shape.shape = capsule
	collision_shape.position = Vector3(0, 0.9, 0)
	add_child(collision_shape)

	# Body visual (box: torso + legs)
	body_mesh = MeshInstance3D.new()
	var body_box := BoxMesh.new()
	body_box.size = Vector3(0.5, 1.4, 0.3)
	body_mesh.mesh = body_box
	body_mesh.position = Vector3(0, 0.7, 0)
	add_child(body_mesh)

	# Head (positioned at player camera height for straight-ahead stabbing)
	head_node = Node3D.new()
	head_node.name = "Head"
	head_node.position = Vector3(0, 1.6, 0)
	add_child(head_node)

	head_mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.15
	sphere.height = 0.3
	head_mesh.mesh = sphere
	head_node.add_child(head_mesh)

	_randomize_colors()


func _randomize_colors() -> void:
	# Each zombie gets random hex colors for body and head
	var body_color := Color(randf(), randf(), randf())
	var head_color := Color(randf(), randf(), randf())
	_set_mesh_color(body_mesh, body_color)
	_set_mesh_color(head_mesh, head_color)


func _set_mesh_color(mesh: MeshInstance3D, color: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.set_surface_override_material(0, mat)


func _physics_process(delta: float) -> void:
	if is_dead or target == null or not GameManager.is_playing:
		return

	# Gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	# Walk toward the player (horizontal only)
	var to_player := target.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()

	if dist > 0.1:
		var direction := to_player.normalized()
		velocity.x = direction.x * MOVE_SPEED
		velocity.z = direction.z * MOVE_SPEED

		# Face the player (horizontal only)
		var look_target := Vector3(target.global_position.x, global_position.y, target.global_position.z)
		look_at(look_target, Vector3.UP)
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	move_and_slide()

	# Bite check
	if dist < BITE_RANGE and not has_bitten:
		_bite()


func _bite() -> void:
	has_bitten = true
	# Auto-stab: zombie dies with default knife color blood, score resets
	var blood_dir: Vector3 = (global_position - target.global_position).normalized()
	die(Color.SILVER, blood_dir)
	GameManager.player_bitten()


func get_head_position() -> Vector3:
	return head_node.global_position


func die(blood_color: Color, blood_dir: Vector3) -> void:
	if is_dead:
		return
	is_dead = true
	set_physics_process(false)

	# Disable collision so the corpse doesn't block anything
	collision_shape.set_deferred("disabled", true)

	_spawn_blood(blood_color, blood_dir)

	# Crumple downward out of view
	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y - 2.5, 0.4).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)


func _spawn_blood(color: Color, direction: Vector3) -> void:
	## Spawn a burst of colored circles out the far side of the head.
	var origin := get_head_position()
	var scene_root := get_tree().current_scene

	for i in range(12):
		var particle := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = randf_range(0.03, 0.09)
		sphere.height = sphere.radius * 2.0
		particle.mesh = sphere

		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		particle.set_surface_override_material(0, mat)

		scene_root.add_child(particle)
		particle.global_position = origin

		# Fly outward with spread
		var spread := Vector3(
			randf_range(-0.4, 0.4),
			randf_range(-0.2, 0.5),
			randf_range(-0.4, 0.4),
		)
		var target_pos := origin + (direction + spread).normalized() * randf_range(0.4, 1.2)

		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "global_position", target_pos, randf_range(0.2, 0.5)).set_ease(Tween.EASE_OUT)
		tween.tween_property(particle, "scale", Vector3.ZERO, randf_range(0.3, 0.6)).set_delay(0.15)
		tween.set_parallel(false)
		tween.tween_callback(particle.queue_free)
