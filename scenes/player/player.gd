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
var is_in_death_sequence := false
var waiting_for_play_again := false
var play_again_label: Label
var flash_tween: Tween

# Scene nodes (built in _ready)
var camera_pivot: Node3D
var camera: Camera3D
var left_arm: Node3D
var right_arm: Node3D
var left_knife_blade: MeshInstance3D
var right_knife_blade: MeshInstance3D
var watch_viewport: SubViewport
var watch_mesh: MeshInstance3D
var time_label: Label
var highscore_label: Label
var bracelet_spheres: Array[MeshInstance3D] = []
var bracelet_colors: Array[Color] = []
var bracelet_kill_index := 0
const BRACELET_COUNT := 4
const BRACELET_DEFAULT_COLOR := Color(0.85, 0.7, 0.1)  # Gold


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

	var left_knife := _create_knife()
	left_knife.rotation.y = deg_to_rad(15)  # Tip angled rightward (inward)
	left_arm.add_child(left_knife)
	left_knife_blade = left_knife.get_child(0)  # The blade MeshInstance3D

	# Right arm + knife (positioned lower-right of camera view)
	right_arm = Node3D.new()
	right_arm.name = "RightArm"
	right_arm.position = Vector3(0.25, -0.25, -0.35)
	camera_pivot.add_child(right_arm)

	var right_knife := _create_knife()
	right_knife.rotation.y = deg_to_rad(-15)  # Tip angled leftward (inward)
	right_arm.add_child(right_knife)
	right_knife_blade = right_knife.get_child(0)  # The blade MeshInstance3D

	_setup_watch()
	_setup_bracelet()

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	GameManager.player_died.connect(_on_died)
	GameManager.game_reset.connect(_on_game_reset)


func _setup_watch() -> void:
	# SubViewport renders the watch face as a 2D UI
	watch_viewport = SubViewport.new()
	watch_viewport.size = Vector2i(200, 200)
	watch_viewport.transparent_bg = false
	watch_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(watch_viewport)

	# Gold bezel (drawn as background in the viewport)
	var border := ColorRect.new()
	border.color = Color(0.85, 0.7, 0.1)
	border.size = Vector2(200, 200)
	watch_viewport.add_child(border)

	# Dark screen inset
	var screen := ColorRect.new()
	screen.color = Color(0.02, 0.02, 0.04)
	screen.position = Vector2(8, 8)
	screen.size = Vector2(184, 184)
	watch_viewport.add_child(screen)

	# Time elapsed (large, now the primary display)
	time_label = Label.new()
	time_label.text = "0:00"
	time_label.position = Vector2(16, 20)
	time_label.add_theme_font_size_override("font_size", 44)
	time_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.2))
	watch_viewport.add_child(time_label)

	# High score
	highscore_label = Label.new()
	highscore_label.text = "HI: 0"
	highscore_label.position = Vector2(16, 140)
	highscore_label.add_theme_font_size_override("font_size", 28)
	highscore_label.add_theme_color_override("font_color", Color(0.7, 0.6, 0.15))
	watch_viewport.add_child(highscore_label)

	# "Play Again" (hidden until death sequence)
	play_again_label = Label.new()
	play_again_label.text = "► PLAY AGAIN"
	play_again_label.position = Vector2(16, 80)
	play_again_label.add_theme_font_size_override("font_size", 28)
	play_again_label.add_theme_color_override("font_color", Color(1, 0.25, 0.2))
	play_again_label.visible = false
	watch_viewport.add_child(play_again_label)

	# Watch is a child of left_arm — jerks forward with stab
	var watch_node := Node3D.new()
	watch_node.name = "Watch"
	watch_node.position = Vector3(0.05, 0.06, 0.05)  # Above and slightly behind knife
	left_arm.add_child(watch_node)

	# Watch body (gold box behind the face)
	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.06, 0.06, 0.01)
	body.mesh = body_mesh
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.85, 0.7, 0.1)
	body_mat.metallic = 0.8
	body.set_surface_override_material(0, body_mat)
	watch_node.add_child(body)

	# Watch face (viewport texture, slightly in front of body)
	watch_mesh = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.05, 0.05)
	watch_mesh.mesh = quad
	watch_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	watch_mesh.position = Vector3(0, 0, 0.006)

	var watch_mat := StandardMaterial3D.new()
	watch_mat.albedo_texture = watch_viewport.get_texture()
	watch_mat.emission_enabled = true
	watch_mat.emission = Color(1, 1, 1)
	watch_mat.emission_energy_multiplier = 0.5
	watch_mat.emission_texture = watch_viewport.get_texture()
	watch_mesh.set_surface_override_material(0, watch_mat)
	watch_node.add_child(watch_mesh)


func _setup_bracelet() -> void:
	# Ring of spheres around the right wrist in a rough square shape
	var bracelet_node := Node3D.new()
	bracelet_node.name = "Bracelet"
	bracelet_node.position = Vector3(0.03, 0, -0.02)  # Around blade base
	right_arm.add_child(bracelet_node)

	var sphere_radius := 0.012
	var ring_radius := 0.03

	for i in range(BRACELET_COUNT):
		var angle := float(i) / float(BRACELET_COUNT) * TAU + TAU / 8.0
		var sphere_mesh := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = sphere_radius
		sphere.height = sphere_radius * 2.0
		sphere_mesh.mesh = sphere
		sphere_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sphere_mesh.position = Vector3(cos(angle) * ring_radius, sin(angle) * ring_radius, 0)
		_set_sphere_color(sphere_mesh, BRACELET_DEFAULT_COLOR)
		bracelet_node.add_child(sphere_mesh)
		bracelet_spheres.append(sphere_mesh)
		bracelet_colors.append(BRACELET_DEFAULT_COLOR)

		# Number label on each sphere
		var label := Label3D.new()
		label.text = str(i + 1)
		label.font_size = 32
		label.pixel_size = 0.0004
		label.position = Vector3(0, 0, sphere_radius + 0.001)  # Just in front of sphere
		label.modulate = Color.BLACK
		label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sphere_mesh.add_child(label)


func _process(_delta: float) -> void:
	# Update watch display
	var minutes := int(GameManager.time_elapsed) / 60
	var seconds := int(GameManager.time_elapsed) % 60
	time_label.text = "%d:%02d" % [minutes, seconds]
	highscore_label.text = "HI: %d" % GameManager.high_score



func _create_pyramid_mesh(base_size: float, height: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := base_size / 2.0
	var b0 := Vector3(-h, 0, -h)
	var b1 := Vector3(h, 0, -h)
	var b2 := Vector3(h, 0, h)
	var b3 := Vector3(-h, 0, h)
	var apex := Vector3(0, height, 0)
	# Side faces (CCW from outside)
	for tri in [[b1, b0, apex], [b2, b1, apex], [b3, b2, apex], [b0, b3, apex]]:
		st.add_vertex(tri[0])
		st.add_vertex(tri[1])
		st.add_vertex(tri[2])
	# Base
	st.add_vertex(b0)
	st.add_vertex(b1)
	st.add_vertex(b2)
	st.add_vertex(b0)
	st.add_vertex(b2)
	st.add_vertex(b3)
	st.generate_normals()
	return st.commit()


func _create_knife() -> Node3D:
	var root := Node3D.new()

	# Blade: square pyramid pointing forward (-Z)
	var blade := MeshInstance3D.new()
	blade.mesh = _create_pyramid_mesh(0.04, 0.25)
	blade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	blade.rotation.x = deg_to_rad(-90)  # Rotate so the apex points forward (-Z)
	blade.position = Vector3(0, 0, -0.155)  # Centered ahead of handle
	var blade_mat := StandardMaterial3D.new()
	blade_mat.albedo_color = DEFAULT_KNIFE_COLOR
	blade.set_surface_override_material(0, blade_mat)
	root.add_child(blade)

	return root


func _unhandled_input(event: InputEvent) -> void:
	# ESC toggles mouse capture (always available)
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		return

	# Click to capture mouse (required for web)
	if event is InputEventMouseButton and event.pressed and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		return

	# During death sequence, any click triggers "Play Again"
	if waiting_for_play_again:
		if event is InputEventMouseButton and event.pressed:
			waiting_for_play_again = false
		return

	if not GameManager.is_playing:
		return

	# Mouse look
	if event is InputEventMouseMotion:
		camera_rotation.x -= event.relative.y * MOUSE_SENSITIVITY
		camera_rotation.y -= event.relative.x * MOUSE_SENSITIVITY
		camera_rotation.x = clampf(camera_rotation.x, -CAMERA_CLAMP, CAMERA_CLAMP)
		camera_rotation.y = clampf(camera_rotation.y, -CAMERA_CLAMP, CAMERA_CLAMP)
		camera_pivot.rotation.x = camera_rotation.x
		camera_pivot.rotation.y = camera_rotation.y

	# Knife color from bracelet: hold Q (left) or E (right), press 1-8
	if event is InputEventKey and event.pressed and not event.echo:
		var slot := _key_to_bracelet_slot(event.keycode)
		if slot >= 0 and bracelet_colors[slot] != BRACELET_DEFAULT_COLOR:
			if Input.is_key_pressed(KEY_Q):
				left_knife_color = bracelet_colors[slot]
				_set_knife_color(left_knife_blade, left_knife_color)
				return
			elif Input.is_key_pressed(KEY_E):
				right_knife_color = bracelet_colors[slot]
				_set_knife_color(right_knife_blade, right_knife_color)
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

	# Recolor the used knife blade
	var knife := left_knife_blade if is_left else right_knife_blade
	if is_left:
		left_knife_color = blood_color
	else:
		right_knife_color = blood_color
	_set_knife_color(knife, blood_color)

	# Advance bracelet kill counter — color one sphere with the blood color
	if bracelet_spheres.size() > 0:
		_set_sphere_color(bracelet_spheres[bracelet_kill_index], blood_color)
		bracelet_colors[bracelet_kill_index] = blood_color
		bracelet_kill_index = (bracelet_kill_index + 1) % bracelet_spheres.size()

	GameManager.add_kill()


func _set_knife_color(knife: MeshInstance3D, color: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	knife.set_surface_override_material(0, mat)


func _key_to_bracelet_slot(keycode: Key) -> int:
	match keycode:
		KEY_1: return 0
		KEY_2: return 1
		KEY_3: return 2
		KEY_4: return 3
		_: return -1


func _set_sphere_color(sphere: MeshInstance3D, color: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	sphere.set_surface_override_material(0, mat)


# ── Death / Reset ──────────────────────────────────────────────────────────

func reset_knives() -> void:
	left_knife_color = DEFAULT_KNIFE_COLOR
	right_knife_color = DEFAULT_KNIFE_COLOR
	_set_knife_color(left_knife_blade, DEFAULT_KNIFE_COLOR)
	_set_knife_color(right_knife_blade, DEFAULT_KNIFE_COLOR)
	# Reset bracelet
	bracelet_kill_index = 0
	for i in range(bracelet_spheres.size()):
		_set_sphere_color(bracelet_spheres[i], BRACELET_DEFAULT_COLOR)
		bracelet_colors[i] = BRACELET_DEFAULT_COLOR


func _on_died() -> void:
	is_in_death_sequence = true
	_death_sequence()


func _death_sequence() -> void:
	# Reset camera pivot (undo any mouse-look offset)
	var reset_tween := create_tween()
	reset_tween.tween_property(camera_pivot, "rotation", Vector3.ZERO, 0.4).set_ease(Tween.EASE_IN_OUT)
	await reset_tween.finished

	# Compute look-at rotation toward the watch on the left arm
	var watch_dir := left_arm.position.normalized()
	var target_rot := Vector3(
		asin(watch_dir.y),  # Pitch down (negative y → negative rotation → look down)
		atan2(-watch_dir.x, -watch_dir.z),  # Yaw left (negative x → positive rotation → look left)
		0
	)

	# Pan camera down-left to the watch
	var pan_tween := create_tween()
	pan_tween.tween_property(camera, "rotation", target_rot, 0.6) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	await pan_tween.finished

	# Show pulsing "PLAY AGAIN" on watch face
	time_label.visible = false
	play_again_label.visible = true
	flash_tween = create_tween().set_loops()
	flash_tween.tween_property(play_again_label, "modulate:a", 0.3, 0.5)
	flash_tween.tween_property(play_again_label, "modulate:a", 1.0, 0.5)

	# Wait for click
	waiting_for_play_again = true
	while waiting_for_play_again:
		await get_tree().process_frame

	# Clean up watch display
	if flash_tween:
		flash_tween.kill()
		flash_tween = null
	play_again_label.visible = false
	play_again_label.modulate.a = 1.0
	time_label.visible = true

	# Pan camera back to center
	var return_tween := create_tween()
	return_tween.tween_property(camera, "rotation", Vector3.ZERO, 0.4) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	await return_tween.finished

	# Auto-stab the biting zombie (silver blood = distinct from normal kills)
	var zombie = GameManager.biting_zombie
	if zombie and is_instance_valid(zombie) and not zombie.is_dead:
		var blood_dir: Vector3 = (zombie.global_position - global_position).normalized()
		zombie.die(Color.SILVER, blood_dir)

	# Reset and resume
	camera_rotation = Vector2.ZERO
	is_in_death_sequence = false
	GameManager.reset_score()


func _on_game_reset() -> void:
	reset_knives()
