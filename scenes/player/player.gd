extends CharacterBody3D
## First-person player controller.
## Builds the camera, arms, and knives in code.
## Handles movement (WASD), camera (±20° mouse), and dual-knife stab mechanic.

# -- Movement --
const MOVE_SPEED := 6.0
const GRAVITY := 9.8

# -- Camera --
const MOUSE_SENSITIVITY := 0.002
const CAMERA_CLAMP := deg_to_rad(20.0)

# -- Combat --
const STAB_REACH := 1.8        # Arm + knife length
const STAB_DURATION := 0.25    # Total stab animation time (seconds)
const STAB_FORWARD := 0.4      # How far forward the knife lunges
const STAB_INWARD := 0.25      # How far inward (crossing midline) the knife sweeps
const STAB_UP := 0.1           # Slight upward arc on the stab

# Hit detection: asymmetric cone per knife (camera-local X direction)
# Left knife sweeps rightward -> better for targets right of center
# Right knife sweeps leftward -> better for targets left of center
const LEFT_KNIFE_X_MIN := -0.4
const LEFT_KNIFE_X_MAX := 0.8
const RIGHT_KNIFE_X_MIN := -0.8
const RIGHT_KNIFE_X_MAX := 0.4
const STAB_Z_THRESHOLD := -0.2  # Must be at least this far forward (-Z is forward)
const STAB_Y_TOLERANCE := 0.15  # Vertical tolerance — must be aimed at the head

const DEFAULT_KNIFE_COLOR := Color.SILVER

var camera_rotation := Vector2.ZERO
var left_stabbing := false
var right_stabbing := false
var left_knife_color := DEFAULT_KNIFE_COLOR
var right_knife_color := DEFAULT_KNIFE_COLOR

# Scene nodes (built in _ready)
var camera_pivot: Node3D
var camera: Camera3D
var left_arm: Node3D
var right_arm: Node3D
var left_knife_mesh: MeshInstance3D
var right_knife_mesh: MeshInstance3D


func _ready() -> void:
	# Collision: layer 2 (characters), mask 1|2 (env + characters)
	collision_layer = 2
	collision_mask = 3

	# Body collision capsule
	var col := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.7
	col.shape = capsule
	col.position = Vector3(0, 0.85, 0)
	add_child(col)

	# Camera pivot at eye height
	camera_pivot = Node3D.new()
	camera_pivot.name = "CameraPivot"
	camera_pivot.position = Vector3(0, 1.6, 0)
	add_child(camera_pivot)

	camera = Camera3D.new()
	camera.current = true
	camera_pivot.add_child(camera)

	# Left arm + knife (positioned lower-left of camera view)
	left_arm = Node3D.new()
	left_arm.name = "LeftArm"
	left_arm.position = Vector3(-0.25, -0.25, -0.35)
	camera_pivot.add_child(left_arm)

	left_knife_mesh = _create_knife()
	left_knife_mesh.rotation.y = deg_to_rad(15)  # Tip angled rightward (inward)
	left_arm.add_child(left_knife_mesh)

	# Right arm + knife (positioned lower-right of camera view)
	right_arm = Node3D.new()
	right_arm.name = "RightArm"
	right_arm.position = Vector3(0.25, -0.25, -0.35)
	camera_pivot.add_child(right_arm)

	right_knife_mesh = _create_knife()
	right_knife_mesh.rotation.y = deg_to_rad(-15)  # Tip angled leftward (inward)
	right_arm.add_child(right_knife_mesh)

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	GameManager.player_died.connect(_on_died)
	GameManager.game_reset.connect(_on_game_reset)


func _create_knife() -> MeshInstance3D:
	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.03, 0.02, 0.3)  # Thin blade extending forward (-Z)
	mesh_inst.mesh = box
	mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.albedo_color = DEFAULT_KNIFE_COLOR
	mesh_inst.set_surface_override_material(0, mat)
	return mesh_inst


func _unhandled_input(event: InputEvent) -> void:
	# ESC toggles mouse capture (for debugging)
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		return

	if not GameManager.is_playing:
		return

	# Mouse look
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		camera_rotation.x -= event.relative.y * MOUSE_SENSITIVITY
		camera_rotation.y -= event.relative.x * MOUSE_SENSITIVITY
		camera_rotation.x = clampf(camera_rotation.x, -CAMERA_CLAMP, CAMERA_CLAMP)
		camera_rotation.y = clampf(camera_rotation.y, -CAMERA_CLAMP, CAMERA_CLAMP)
		camera_pivot.rotation.x = camera_rotation.x
		camera_pivot.rotation.y = camera_rotation.y

	# Click to capture mouse first (required for web — browsers ignore capture without a user gesture)
	if event is InputEventMouseButton and event.pressed and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		return

	# Stab inputs
	if event.is_action_pressed("stab_left") and not left_stabbing:
		_do_stab(true)
	elif event.is_action_pressed("stab_right") and not right_stabbing:
		_do_stab(false)


func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	if not GameManager.is_playing:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	# Movement: world-space (not camera-relative). WASD maps directly to hallway axes.
	var input_dir := Vector2.ZERO
	if Input.is_action_pressed("move_forward"):
		input_dir.y -= 1.0
	if Input.is_action_pressed("move_backward"):
		input_dir.y += 1.0
	if Input.is_action_pressed("strafe_left"):
		input_dir.x -= 1.0
	if Input.is_action_pressed("strafe_right"):
		input_dir.x += 1.0
	input_dir = input_dir.normalized()

	velocity.x = input_dir.x * MOVE_SPEED
	velocity.z = input_dir.y * MOVE_SPEED

	move_and_slide()


# ── Stab Mechanic ──────────────────────────────────────────────────────────

func _do_stab(is_left: bool) -> void:
	var arm: Node3D = left_arm if is_left else right_arm
	if is_left:
		left_stabbing = true
	else:
		right_stabbing = true

	var start_pos := arm.position
	var inward := 1.0 if is_left else -1.0  # Left sweeps +X, right sweeps -X
	var stab_target := start_pos + Vector3(STAB_INWARD * inward, STAB_UP, -STAB_FORWARD)

	var tween := create_tween()
	tween.tween_property(arm, "position", stab_target, STAB_DURATION * 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(_check_stab_hit.bind(is_left))
	tween.tween_property(arm, "position", start_pos, STAB_DURATION * 0.65).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(func() -> void:
		if is_left:
			left_stabbing = false
		else:
			right_stabbing = false
	)


func _check_stab_hit(is_left: bool) -> void:
	## At the peak of the stab, check if any zombie head is within reach
	## and in the correct angular zone for this knife.
	for zombie in get_tree().get_nodes_in_group("zombies"):
		if zombie.is_dead:
			continue

		var head_pos: Vector3 = zombie.get_head_position()
		var to_head: Vector3 = head_pos - camera.global_position
		var distance := to_head.length()

		if distance > STAB_REACH:
			continue

		# Direction to head in camera-local space
		var local_dir := camera.global_transform.basis.inverse() * to_head.normalized()

		# Must be in front (-Z is forward in camera space)
		if local_dir.z > STAB_Z_THRESHOLD:
			continue

		# Must be aimed roughly at head height (not looking at floor/ceiling)
		if absf(local_dir.y) > STAB_Y_TOLERANCE:
			continue

		# Check horizontal zone for this knife
		var x_min: float = LEFT_KNIFE_X_MIN if is_left else RIGHT_KNIFE_X_MIN
		var x_max: float = LEFT_KNIFE_X_MAX if is_left else RIGHT_KNIFE_X_MAX

		if local_dir.x >= x_min and local_dir.x <= x_max:
			_kill_zombie(zombie, is_left)
			return


func _kill_zombie(zombie: Node, is_left: bool) -> void:
	var blood_color := Color(randf(), randf(), randf())
	var blood_dir: Vector3 = (zombie.global_position - global_position).normalized()
	zombie.die(blood_color, blood_dir)

	# Recolor the used knife
	var knife := left_knife_mesh if is_left else right_knife_mesh
	if is_left:
		left_knife_color = blood_color
	else:
		right_knife_color = blood_color
	_set_knife_color(knife, blood_color)

	GameManager.add_kill()


func _set_knife_color(knife: MeshInstance3D, color: Color) -> void:
	var mat := knife.get_surface_override_material(0) as StandardMaterial3D
	if mat:
		mat.albedo_color = color
	else:
		mat = StandardMaterial3D.new()
		mat.albedo_color = color
		knife.set_surface_override_material(0, mat)


# ── Death / Reset ──────────────────────────────────────────────────────────

func reset_knives() -> void:
	left_knife_color = DEFAULT_KNIFE_COLOR
	right_knife_color = DEFAULT_KNIFE_COLOR
	_set_knife_color(left_knife_mesh, DEFAULT_KNIFE_COLOR)
	_set_knife_color(right_knife_mesh, DEFAULT_KNIFE_COLOR)


func _on_died() -> void:
	pass  # Graybox: movement stops via is_playing check


func _on_game_reset() -> void:
	reset_knives()
