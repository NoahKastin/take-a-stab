extends CharacterBody3D
## Floating eye monster: drifts toward the player, bites when close.
## Builds its own mesh (body sphere, eye, pupil, spikes) with random colors.

const MOVE_SPEED := 2.0
const BITE_RANGE := 1.0
const GRAVITY := 9.8
const FLOAT_HEIGHT := 1.6  # Eye level, matching player camera height
const BOB_AMOUNT := 0.08
const BOB_SPEED := 2.5
const SPIKE_COUNT := 4

var target: Node3D = null
var is_dead := false
var has_bitten := false
var bob_phase := 0.0

var body_node: Node3D
var body_mesh: MeshInstance3D
var eye_mesh: MeshInstance3D
var pupil_mesh: MeshInstance3D
var spike_meshes: Array[MeshInstance3D] = []
var collision_shape: CollisionShape3D
var body_color: Color
var eye_color: Color


func _ready() -> void:
	add_to_group("zombies")

	# Collision: layer 2 (characters), mask 1|2 (env + characters)
	collision_layer = 2
	collision_mask = 3

	# Collision sphere near ground so CharacterBody3D origin stays at floor level
	collision_shape = CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = 0.25
	collision_shape.shape = sphere_shape
	collision_shape.position = Vector3(0, 0.25, 0)  # Bottom of sphere at y=0
	add_child(collision_shape)

	# Body node at float height (all visual meshes are children of this)
	body_node = Node3D.new()
	body_node.name = "Body"
	body_node.position = Vector3(0, FLOAT_HEIGHT, 0)
	add_child(body_node)

	bob_phase = randf() * TAU  # Random start phase so they don't bob in sync

	_build_meshes()
	_randomize_colors()


func _build_meshes() -> void:
	# Main body sphere
	body_mesh = MeshInstance3D.new()
	var body_sphere := SphereMesh.new()
	body_sphere.radius = 0.2
	body_sphere.height = 0.4
	body_mesh.mesh = body_sphere
	body_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body_node.add_child(body_mesh)

	# Eye: flattened sphere protruding from the front
	eye_mesh = MeshInstance3D.new()
	var eye_sphere := SphereMesh.new()
	eye_sphere.radius = 0.1
	eye_sphere.height = 0.12  # Flattened
	eye_mesh.mesh = eye_sphere
	eye_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	eye_mesh.position = Vector3(0, 0, -0.16)  # Protruding forward
	body_node.add_child(eye_mesh)

	# Pupil: small dark sphere in front of the eye
	pupil_mesh = MeshInstance3D.new()
	var pupil_sphere := SphereMesh.new()
	pupil_sphere.radius = 0.04
	pupil_sphere.height = 0.05
	pupil_mesh.mesh = pupil_sphere
	pupil_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pupil_mesh.position = Vector3(0, 0, -0.22)
	body_node.add_child(pupil_mesh)

	# Spikes: triangular prisms pointing outward (PrismMesh point is +Y by default)
	# Each entry: [position offset, rotation to point outward]
	var spike_data := [
		[Vector3(0, 0.22, 0.04), Vector3(0, 0, 0)],                          # Top (point already +Y)
		[Vector3(0, -0.22, 0.04), Vector3(0, 0, deg_to_rad(180))],            # Bottom (flip)
		[Vector3(0.22, 0.04, 0.03), Vector3(0, 0, deg_to_rad(-90))],          # Right
		[Vector3(-0.22, 0.04, 0.03), Vector3(0, 0, deg_to_rad(90))],          # Left
	]
	for data in spike_data:
		var spike := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(0.06, 0.12, 0.06)
		spike.mesh = prism
		spike.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		spike.position = data[0]
		spike.rotation = data[1]
		body_node.add_child(spike)
		spike_meshes.append(spike)

	# Teeth: ring of small sharp prisms around the front-bottom, below the eye
	var tooth_count := 8
	for i in range(tooth_count):
		var tooth := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(0.02, 0.06, 0.02)  # Small, pointy
		tooth.mesh = prism
		tooth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		# Arrange in a semicircle on the front-bottom of the body
		var angle := deg_to_rad(-80 + float(i) / float(tooth_count - 1) * 160.0)
		var ring_radius := 0.14
		tooth.position = Vector3(
			sin(angle) * ring_radius,
			-0.08,
			-cos(angle) * ring_radius - 0.04
		)
		# Point teeth outward/forward: tilt so points face away from center
		tooth.rotation = Vector3(deg_to_rad(-70), angle, 0)

		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.95, 0.92, 0.8)  # Off-white bone
		tooth.set_surface_override_material(0, mat)
		body_node.add_child(tooth)


func _randomize_colors() -> void:
	body_color = Color(randf(), randf(), randf())
	eye_color = Color(randf(), randf(), randf())
	_set_mesh_color(body_mesh, body_color)
	_set_mesh_color(eye_mesh, eye_color)
	_set_mesh_color(pupil_mesh, Color(0.02, 0.02, 0.02))  # Near-black pupil
	for spike in spike_meshes:
		_set_mesh_color(spike, body_color.darkened(0.3))


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

	# Float bob
	bob_phase += delta * BOB_SPEED
	body_node.position.y = FLOAT_HEIGHT + sin(bob_phase) * BOB_AMOUNT

	# Drift toward the player (horizontal only)
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

	# Despawn if too far behind the player
	if global_position.z > target.global_position.z + 10.0:
		is_dead = true
		queue_free()
		return

	# Bite check
	if dist < BITE_RANGE and not has_bitten:
		_bite()


func _bite() -> void:
	has_bitten = true
	GameManager.player_bitten(self)


func get_head_position() -> Vector3:
	return body_node.global_position


func die(blood_color: Color, _blood_dir: Vector3) -> void:
	if is_dead:
		return
	is_dead = true
	set_physics_process(false)

	# Disable collision
	collision_shape.set_deferred("disabled", true)

	# Hide the monster meshes
	body_node.visible = false

	# Explode into small spheres
	_spawn_sphere_explosion(blood_color)

	# Clean up after explosion
	var timer := get_tree().create_timer(0.8)
	timer.timeout.connect(queue_free)


func _spawn_sphere_explosion(color: Color) -> void:
	var origin := body_node.global_position
	var scene_root := get_tree().current_scene
	var sphere_count := 10 + randi() % 6  # 10-15 spheres

	for i in range(sphere_count):
		var particle := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = randf_range(0.02, 0.06)
		sphere.height = sphere.radius * 2.0
		particle.mesh = sphere
		particle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		# Mix blood color with body/eye colors for variety
		var mix := randf()
		var particle_color: Color
		if mix < 0.5:
			particle_color = color
		elif mix < 0.8:
			particle_color = body_color
		else:
			particle_color = eye_color

		var mat := StandardMaterial3D.new()
		mat.albedo_color = particle_color
		particle.set_surface_override_material(0, mat)

		scene_root.add_child(particle)
		particle.global_position = origin

		# Fly outward in all directions
		var direction := Vector3(
			randf_range(-1, 1),
			randf_range(-0.5, 1),  # Bias upward
			randf_range(-1, 1),
		).normalized()
		var target_pos := origin + direction * randf_range(0.3, 1.0)

		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "global_position", target_pos, randf_range(0.3, 0.6)).set_ease(Tween.EASE_OUT)
		tween.tween_property(particle, "scale", Vector3.ZERO, randf_range(0.4, 0.7)).set_delay(0.1)
		tween.set_parallel(false)
		tween.tween_callback(particle.queue_free)
