extends CharacterBody3D

# ==========================================
# MOVEMENT SETTINGS
# ==========================================
@export_group("Movement")
@export var WALK_SPEED := 95.0
@export var SPRINT_SPEED := 140.0
@export var JUMP_VELOCITY := 60.0
@export var GRAVITY_MULT := 12.0
@export var ACCEL := 85.0
@export var AIR_CONTROL := 1.5
@export var FRICTION := 10.0
@export var Sensitivity := 0.003

# ==========================================
# DASH (DOUBLE-TAP W/A/S/D)
# ==========================================
@export_group("Dash")
@export var dash_enabled := true
@export var dash_speed := 185.0
@export var dash_duration := 0.16
@export var dash_cooldown := 0.65
@export_range(1, 5, 1) var dash_max_charges := 2
@export var dash_recharge_time := 2.0

signal dash_charges_changed(charges: int, maximum: int, recharge_progress: float)
var dash_charges := 2
var dash_recharge_remaining := 0.0
@export var dash_double_tap_window := 0.25
@export var dash_allow_in_air := false
@export var dash_sound: AudioStream
@export_range(-40.0, 6.0, 0.5) var dash_volume_db := 0.0

var dash_player: AudioStreamPlayer
var dash_remaining := 0.0
var dash_cooldown_remaining := 0.0
var dash_direction := Vector3.ZERO
var last_tap_times := {"w": -100.0, "a": -100.0, "s": -100.0, "d": -100.0}
var dash_clock := 0.0

# ==========================================
# SINGLE JUMP
# ==========================================
@export_group("Single Jump")
@export var jump_sound: AudioStream
@export_range(-40.0, 6.0) var jump_volume_db := 0.0
var jump_player: AudioStreamPlayer

# ==========================================
# DOUBLE JUMP
# ==========================================
@export_group("Double Jump")
@export var double_jump_enabled := true
@export var double_jump_velocity := 5.0
@export var double_jump_sound: AudioStream
@export_range(-40.0, 6.0) var double_jump_volume_db := 0.0
var jumps_used := 0
var double_jump_player: AudioStreamPlayer

# ==========================================
# SPRINT AND FOOTSTEP AUDIO
# ==========================================
@export_group("Audio")
@export var sprint_sound: AudioStream
@export_range(-40.0, 6.0) var sprint_volume_db := 0.0
@export var footstep_sounds: Array[AudioStream] = []
@export_range(-40.0, 6.0) var footstep_volume_db := -6.0
@export var walk_step_interval := 0.3
@export var sprint_step_interval := 0.2
@export var footsteps_when_sprinting := true
@export var footstep_pitch_variation := 0.09

# ==========================================
# LANDING AUDIO
# ==========================================
@export_subgroup("Landing")
@export var landing_sounds: Array[AudioStream] = []
@export_range(-40.0, 6.0) var landing_volume_db := 0.0
@export var min_fall_speed := 55.0 # Landing loudness starts increasing above this speed
@export var hard_landing_speed := 80.0
@export var soft_landing_reduction_db := 12.0
@export var landing_pitch_variation := 0.06

# ==========================================
# VARIABLES
# ==========================================
@onready var Head: Node3D = $Head

# G19 PICKUP
@onready var pickup_ray: RayCast3D = $Head/Camera3D/RayCast3D
@onready var weapon_manager: Node3D = $Head/Camera3D/WeaponManager
@export_group("Weapon Pickup")
@export var pickup_debug := true
@export var pickup_prompt_text := "[E] PICK UP G19"
var pickup_prompt: Label

var sprint_player: AudioStreamPlayer
var footstep_player: AudioStreamPlayer
var landing_player: AudioStreamPlayer
var step_timer := 0.0
var step_index := -1
var landing_index := -1
var was_on_floor := true
var fall_speed := 0.0
var was_sprinting := false

# ==========================================
# READY
# ==========================================
func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	jump_player = AudioStreamPlayer.new()
	jump_player.stream = jump_sound
	jump_player.volume_db = jump_volume_db
	add_child(jump_player)

	double_jump_player = AudioStreamPlayer.new()
	double_jump_player.stream = double_jump_sound
	double_jump_player.volume_db = double_jump_volume_db
	add_child(double_jump_player)

	sprint_player = AudioStreamPlayer.new()
	sprint_player.stream = sprint_sound
	sprint_player.volume_db = sprint_volume_db
	add_child(sprint_player)

	footstep_player = AudioStreamPlayer.new()
	footstep_player.volume_db = footstep_volume_db
	add_child(footstep_player)

	landing_player = AudioStreamPlayer.new()
	add_child(landing_player)

	dash_charges = maxi(dash_max_charges, 1)
	dash_player = AudioStreamPlayer.new()
	dash_player.volume_db = dash_volume_db
	add_child(dash_player)

	was_on_floor = is_on_floor()

	# Configure the existing camera ray for pickup detection.
	pickup_ray.enabled = true
	pickup_ray.target_position = Vector3(0.0, 0.0, -3.0)
	pickup_ray.collide_with_bodies = true
	pickup_ray.add_exception(self)
	_create_pickup_prompt()


# ==========================================
# MOUSE LOOK AND DOUBLE-TAP DETECTION
# ==========================================
func _unhandled_input(event: InputEvent) -> void:
	# Clicking inside the game recaptures the mouse if another UI released it.
	# This does not stop an actual crash or a quit action bound to mouse click.
	if event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
			return

	# Handle interaction before dash input's early returns.
	if event.is_action_pressed("interact") and not event.is_echo():
		try_pickup()
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * Sensitivity)
		Head.rotate_x(-event.relative.y * Sensitivity)
		Head.rotation.x = clamp(Head.rotation.x, deg_to_rad(-89), deg_to_rad(89))

	if not dash_enabled or not event is InputEventKey:
		return
	if not event.pressed or event.echo:
		return

	var key := ""
	match event.physical_keycode:
		KEY_W: key = "w"
		KEY_A: key = "a"
		KEY_S: key = "s"
		KEY_D: key = "d"
		_: return

	if dash_clock - float(last_tap_times[key]) <= dash_double_tap_window:
		_attempt_dash(key)
		# Require two fresh presses for the next dash.
		last_tap_times[key] = -100.0
	else:
		last_tap_times[key] = dash_clock

func _attempt_dash(key: String) -> void:
	if dash_remaining > 0.0 or dash_cooldown_remaining > 0.0 or dash_charges <= 0:
		return
	if not dash_allow_in_air and not is_on_floor():
		return

	var local_direction := Vector3.ZERO
	match key:
		"w": local_direction = Vector3.FORWARD
		"s": local_direction = Vector3.BACK
		"a": local_direction = Vector3.LEFT
		"d": local_direction = Vector3.RIGHT

	dash_direction = (global_transform.basis * local_direction).normalized()
	dash_direction.y = 0.0
	dash_direction = dash_direction.normalized()
	if dash_direction == Vector3.ZERO:
		return

	dash_charges -= 1
	if dash_charges < dash_max_charges and dash_recharge_remaining <= 0.0:
		dash_recharge_remaining = maxf(dash_recharge_time, 0.01)
	_emit_dash_status()
	dash_remaining = maxf(dash_duration, 0.01)
	dash_cooldown_remaining = maxf(dash_cooldown, 0.0)
	if dash_sound != null:
		dash_player.stream = dash_sound
		dash_player.volume_db = dash_volume_db
		dash_player.play()

# ==========================================
# G19 PICKUP AND ON-SCREEN PROMPT
# ==========================================
func _create_pickup_prompt() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "PickupPromptLayer"
	add_child(canvas)

	pickup_prompt = Label.new()
	pickup_prompt.name = "PickupPrompt"
	pickup_prompt.text = pickup_prompt_text
	pickup_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pickup_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pickup_prompt.set_anchors_preset(Control.PRESET_CENTER)
	pickup_prompt.offset_left = -180.0
	pickup_prompt.offset_right = 180.0
	pickup_prompt.offset_top = 45.0
	pickup_prompt.offset_bottom = 85.0
	pickup_prompt.add_theme_font_size_override("font_size", 22)
	pickup_prompt.add_theme_color_override("font_color", Color.WHITE)
	pickup_prompt.add_theme_color_override("font_shadow_color", Color.BLACK)
	pickup_prompt.add_theme_constant_override("shadow_offset_x", 2)
	pickup_prompt.add_theme_constant_override("shadow_offset_y", 2)
	pickup_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pickup_prompt.visible = false
	canvas.add_child(pickup_prompt)


func _process(_delta: float) -> void:
	if not is_instance_valid(pickup_prompt):
		return
	pickup_prompt.visible = _get_aimed_pickup() != null


func _get_aimed_pickup() -> Node:
	if not is_instance_valid(pickup_ray) or not is_instance_valid(weapon_manager):
		return null
	if weapon_manager.get("has_g19") == true:
		return null
	pickup_ray.force_raycast_update()
	if not pickup_ray.is_colliding():
		return null
	var target := pickup_ray.get_collider() as Node
	if target != null and target.has_method("interact"):
		return target
	return null


func try_pickup() -> void:
	if not is_instance_valid(pickup_ray):
		push_warning("PickupRay not found: expected Head/Camera3D/RayCast3D")
		return
	if not is_instance_valid(weapon_manager):
		push_warning("WeaponManager not found: expected Head/Camera3D/WeaponManager")
		return
	if weapon_manager.get("has_g19") == true:
		if pickup_debug:
			print("PICKUP: G19 already owned")
		return

	pickup_ray.force_raycast_update()
	if not pickup_ray.is_colliding():
		if pickup_debug:
			print("PICKUP: Ray hit nothing. Check distance, collision shape, and collision mask.")
		return

	var target := pickup_ray.get_collider() as Node
	if target == null:
		return
	if pickup_debug:
		print("PICKUP: Ray hit ", target.name, " (", target.get_class(), ")")
	if not target.has_method("interact"):
		if pickup_debug:
			print("PICKUP: Hit object has no interact() method. Attach g19pickup.gd to its StaticBody3D root.")
		return

	target.interact(weapon_manager)
	if pickup_debug:
		print("PICKUP: Interaction called. has_g19 = ", weapon_manager.get("has_g19"))


# ==========================================
# PHYSICS PROCESS
# ==========================================
func _physics_process(delta: float) -> void:
	dash_clock += delta
	if dash_charges < dash_max_charges:
		dash_recharge_remaining -= delta
		if dash_recharge_remaining <= 0.0:
			dash_charges += 1
			dash_recharge_remaining = maxf(dash_recharge_time, 0.01) if dash_charges < dash_max_charges else 0.0
		_emit_dash_status()
	dash_cooldown_remaining = maxf(dash_cooldown_remaining - delta, 0.0)

	if not is_on_floor():
		velocity += get_gravity() * GRAVITY_MULT * delta

	if Input.is_action_just_pressed("quit"):
		get_tree().quit()

	if is_on_floor():
		jumps_used = 0

	if Input.is_action_just_pressed("ui_accept"):
		if is_on_floor():
			velocity.y = JUMP_VELOCITY
			jumps_used = 1
			if jump_sound != null:
				jump_player.play()
		elif double_jump_enabled and jumps_used == 1:
			velocity.y = double_jump_velocity
			jumps_used = 2
			if double_jump_sound != null:
				double_jump_player.play()

	var input_dir := Input.get_vector("a", "d", "w", "s")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var sprinting_key := Input.is_physical_key_pressed(KEY_SHIFT)
	var speed := SPRINT_SPEED if sprinting_key else WALK_SPEED
	var rate := ACCEL if is_on_floor() else AIR_CONTROL

	if dash_remaining > 0.0:
		# Override only horizontal velocity; keep jumping/gravity intact.
		velocity.x = dash_direction.x * dash_speed
		velocity.z = dash_direction.z * dash_speed
		dash_remaining = maxf(dash_remaining - delta, 0.0)
	elif direction != Vector3.ZERO:
		velocity.x = move_toward(velocity.x, direction.x * speed, rate * speed * delta)
		velocity.z = move_toward(velocity.z, direction.z * speed, rate * speed * delta)
	elif is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * speed * delta)
		velocity.z = move_toward(velocity.z, 0.0, FRICTION * speed * delta)

	fall_speed = -velocity.y
	move_and_slide()
	_update_landing()
	_update_sprint_sound(direction, sprinting_key)
	_update_footsteps(delta, direction, sprinting_key)

# ==========================================
# LANDING DETECTION
# ==========================================
func _update_landing() -> void:
	var on_floor := is_on_floor()
	if on_floor and not was_on_floor:
		jumps_used = 0
		# Every airborne-to-ground transition triggers a landing sound.
		# Even a small hop is audible, but much quieter than a hard fall.
		_play_landing(maxf(fall_speed, 0.0))
	was_on_floor = on_floor

func _play_landing(impact_speed: float) -> void:
	if landing_sounds.is_empty():
		return
	var next := landing_index
	if landing_sounds.size() > 1:
		while next == landing_index:
			next = randi() % landing_sounds.size()
	else:
		next = 0
	landing_index = next
	# Scale loudness smoothly from soft landings to hard impacts.
	# Landings below min_fall_speed play at the quietest level.
	var t: float = clampf(
		(impact_speed - min_fall_speed) / maxf(hard_landing_speed - min_fall_speed, 0.001),
		0.0,
		1.0
	)
	landing_player.stream = landing_sounds[landing_index]
	landing_player.volume_db = landing_volume_db - soft_landing_reduction_db * (1.0 - t)
	landing_player.pitch_scale = 1.0 + randf_range(-landing_pitch_variation, landing_pitch_variation)
	landing_player.play()
	step_timer = walk_step_interval * 0.5

# ==========================================
# SPRINT AUDIO - PLAY ONCE
# ==========================================
func _update_sprint_sound(direction: Vector3, sprinting_key: bool) -> void:
	var sprinting := sprinting_key and direction != Vector3.ZERO and is_on_floor()
	if sprinting and not was_sprinting:
		if sprint_sound != null:
			sprint_player.stream = sprint_sound
			sprint_player.volume_db = sprint_volume_db
			sprint_player.play()
	was_sprinting = sprinting

# ==========================================
# FOOTSTEP SYSTEM
# ==========================================
func _update_footsteps(delta: float, direction: Vector3, sprinting_key: bool) -> void:
	if footstep_sounds.is_empty():
		return
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var moving := is_on_floor() and direction != Vector3.ZERO and horizontal_speed > 1.0
	var sprinting := sprinting_key and moving
	if not moving or (sprinting and not footsteps_when_sprinting):
		step_timer = 0.0
		return
	step_timer -= delta
	if step_timer <= 0.0:
		_play_footstep()
		step_timer = sprint_step_interval if sprinting else walk_step_interval

func _play_footstep() -> void:
	if footstep_sounds.is_empty():
		return
	var next := step_index
	if footstep_sounds.size() > 1:
		while next == step_index:
			next = randi() % footstep_sounds.size()
	else:
		next = 0
	step_index = next
	footstep_player.stream = footstep_sounds[step_index]
	footstep_player.volume_db = footstep_volume_db
	footstep_player.pitch_scale = 1.0 + randf_range(-footstep_pitch_variation, footstep_pitch_variation)
	footstep_player.play()

# ==========================================
# DAMAGE SYSTEM
# ==========================================
func take_damage(amount: float) -> void:
	var health := get_node_or_null("Health")
	if health:
		health.take_damage(amount)

# ==========================================
# DASH HUD DATA
# ==========================================
func get_dash_recharge_progress() -> float:
	if dash_charges >= dash_max_charges:
		return 1.0
	return clampf(1.0 - dash_recharge_remaining / maxf(dash_recharge_time, 0.01), 0.0, 1.0)

func _emit_dash_status() -> void:
	dash_charges_changed.emit(dash_charges, dash_max_charges, get_dash_recharge_progress())
