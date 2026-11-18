


extends Node3D

enum FireMode { SEMI, AUTO }

# ==========================================
# WEAPON SETTINGS
# ==========================================

@export var fire_mode: FireMode = FireMode.SEMI
@export var damage := 25
@export var fire_rate := 0.12
@export var mag_size := 12
@export var reserve_ammo := 60
@export var reload_time := 1.5
@export var debug_markers := false


# ==========================================
# WEAPON HUD
# ==========================================

@export_group("Weapon HUD")
@export var weapon_icon: Texture2D
@export var weapon_icon_size := Vector2(96, 48)
@export var ammo_label_path: NodePath
@export var weapon_icon_path: NodePath

var ammo_label: Label
var weapon_icon_rect: TextureRect


# ==========================================
# AUDIO
# ==========================================

@export_group("Audio")
@export var shoot_sounds: Array[AudioStream] = []
@export_range(-40.0, 6.0) var shoot_volume_db := 0.0
@export var shoot_pitch_variation := 0.04

@export var reload_sound: AudioStream
@export var reload_finish_sound: AudioStream
@export var match_reload_time_to_sound := false
@export_range(-40.0, 6.0) var reload_volume_db := 0.0

@export var empty_click_sound: AudioStream
@export var switch_mode_sound: AudioStream


# ==========================================
# MUZZLE FLASH
# ==========================================

@export_group("Muzzle Flash")
@export var flash_enabled := true
@export var flash_color := Color(1.0, 0.75, 0.3)
@export var flash_size := 0.5
@export var flash_duration := 0.05
@export var flash_light_energy := 4.0
@export var flash_light_range := 8.0
@export var flash_texture: Texture2D
@export var flash_offset := Vector3.ZERO


# ==========================================
# ADS
# ==========================================

@export_group("ADS")
@export var ads_enabled := true
@export var ads_position := Vector3(0.0, 0.05, -0.2)
@export var ads_rotation_degrees := Vector3.ZERO
@export var ads_transition_time := 0.2


# ==========================================
# WEAPON MODEL RECOIL
# ==========================================

@export_group("Weapon Model Recoil")
@export var recoil_enabled := true
@export var recoil_kickback := 0.055
@export var recoil_pitch_degrees := 3.0
@export var recoil_kick_speed := 26.0
@export var recoil_return_speed := 12.0
@export var recoil_ads_multiplier := 0.55
@export var recoil_max_shots := 3.0


# ==========================================
# PROCEDURAL WALK BOB
# ==========================================

@export_group("Procedural Walk Bob")
@export var walk_bob_enabled := true
@export var walk_bob_frequency := 9.0
@export var walk_bob_vertical := 0.018
@export var walk_bob_horizontal := 0.012
@export var walk_bob_roll_degrees := 0.8
@export var walk_bob_smoothing := 10.0
@export var walk_bob_speed_reference := 95.0
@export var walk_bob_ads_multiplier := 0.25
@export var walk_bob_airborne := false


# ==========================================
# PROCEDURAL SPRINT MOVEMENT
# ==========================================

@export_group("Procedural Sprint Movement")
@export var sprint_movement_enabled := true
@export var sprint_key: Key = KEY_SHIFT

@export var sprint_bob_frequency := 12.0
@export var sprint_bob_vertical := 0.018
@export var sprint_bob_horizontal := 0.025
@export var sprint_bob_roll_degrees := 1.5

@export var sprint_position_offset := Vector3(-0.08, -0.28, -0.10)
@export var sprint_rotation_degrees := Vector3(-15.0, -2.0, -6.0)

@export var sprint_transition_speed := 12.0


# ==========================================
# TRACERS
# ==========================================

@export_group("Tracer")
@export var tracer_enabled := true
@export var tracer_every := 1
@export var tracer_color := Color(1.0, 0.9, 0.5)
@export var tracer_width := 0.03
@export var tracer_length := 1.5
@export var tracer_speed := 400.0


# ==========================================
# WEAPON ANIMATIONS
# ==========================================

@export_group("Weapon Animations")
@export var animation_player_path: NodePath
@export var idle_animation: StringName = &"Idle"
@export var walk_animation: StringName = &"Walk"
@export var sprint_animation: StringName = &"Sprint"
@export var reload_animation: StringName = &"Reload"
@export var sprint_action: StringName = &"sprint"
@export var animation_blend_time := 0.15
@export var use_reload_animation_length := false

var weapon_animation_player: AnimationPlayer
var current_weapon_animation: StringName = &""

# ==========================================
# NODE REFERENCES
# ==========================================

@onready var raycast: RayCast3D = $"../RayCast3D"
@onready var muzzle: Node3D = get_node_or_null("Muzzle")

var ammo := 0
var can_shoot := true
var reloading := false
var shot_count := 0

var shot_players: Array[AudioStreamPlayer] = []
var shot_player_index := 0
var shoot_sound_index := -1

var reload_player: AudioStreamPlayer
var extra_player: AudioStreamPlayer

var flash_mesh: MeshInstance3D
var flash_light: OmniLight3D
var flash_id := 0

var is_aiming := false
var hip_position: Vector3
var hip_rotation: Vector3
var ads_tween: Tween
var recoil_amount := 0.0
var recoil_display := 0.0
var ads_blend := 0.0
var walk_bob_phase := 0.0
var walk_bob_weight := 0.0
var sprint_visual_blend := 0.0


# ==========================================
# READY
# ==========================================

func _ready() -> void:
	hip_position = position
	hip_rotation = rotation
	ads_blend = 0.0
	ammo = mag_size

	_find_hud_nodes()

	for i in range(4):
		var p := AudioStreamPlayer.new()
		add_child(p)
		shot_players.append(p)

	reload_player = AudioStreamPlayer.new()
	add_child(reload_player)

	extra_player = AudioStreamPlayer.new()
	add_child(extra_player)

	_build_muzzle_flash()
	_setup_weapon_animations()
	_update_hud()
	_update_weapon_icon()

	print("Gun ready: ", name)


# ==========================================
# ANIMATION HELPERS
# ==========================================

func _setup_weapon_animations() -> void:
	if not animation_player_path.is_empty():
		weapon_animation_player = get_node_or_null(animation_player_path) as AnimationPlayer
	if weapon_animation_player == null:
		weapon_animation_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	if weapon_animation_player == null:
		push_warning("Weapon animations: Assign Animation Player Path in the Inspector.")
		return

	# Imported GLB animations can be named "Idle" or "LibraryName/Idle".
	var idle_name := _resolve_weapon_animation(idle_animation)
	if idle_name != &"":
		# Set the loop on the actual imported animation resource.
		weapon_animation_player.get_animation(idle_name).loop_mode = Animation.LOOP_LINEAR
		print("Weapon Idle animation found: ", idle_name)
		weapon_animation_player.play(idle_name)
		current_weapon_animation = idle_name
	else:
		push_warning("Weapon Idle not found. Available: %s" % [weapon_animation_player.get_animation_list()])

	_update_movement_animation()


func _resolve_weapon_animation(animation_name: StringName) -> StringName:
	if weapon_animation_player == null or animation_name == &"":
		return &""
	if weapon_animation_player.has_animation(animation_name):
		return animation_name
	for available_name in weapon_animation_player.get_animation_list():
		if String(available_name).get_slice("/", 1) == String(animation_name):
			return available_name
	return &""


func _play_weapon_animation(animation_name: StringName) -> void:
	if weapon_animation_player == null:
		return
	var resolved_name := _resolve_weapon_animation(animation_name)
	if resolved_name == &"":
		return
	if current_weapon_animation == resolved_name and weapon_animation_player.is_playing():
		return
	current_weapon_animation = resolved_name
	weapon_animation_player.play(resolved_name, animation_blend_time)


func _update_movement_animation() -> void:
	if weapon_animation_player == null or reloading:
		return
	# Freeze the breathing pose while aiming; don't restart it each frame.
	if is_aiming:
		if weapon_animation_player.is_playing():
			weapon_animation_player.pause()
		return
	var player := get_parent()
	while player != null and not (player is CharacterBody3D):
		player = player.get_parent()
	if player == null:
		_play_weapon_animation(idle_animation)
		return
	var velocity_3d: Vector3 = player.velocity
	var horizontal_speed := Vector2(velocity_3d.x, velocity_3d.z).length()
	if horizontal_speed < 0.15:
		_play_weapon_animation(idle_animation)
	elif not sprint_movement_enabled and InputMap.has_action(sprint_action) and Input.is_action_pressed(sprint_action) and _resolve_weapon_animation(sprint_animation) != &"":
		_play_weapon_animation(sprint_animation)
	elif not walk_bob_enabled and _resolve_weapon_animation(walk_animation) != &"":
		_play_weapon_animation(walk_animation)
	else:
		# Until Walk/Sprint are imported, keep breathing Idle running.
		_play_weapon_animation(idle_animation)


# ==========================================
# FIND HUD NODES
# ==========================================

func _find_hud_nodes() -> void:
	# First try manually assigned node paths.
	if not ammo_label_path.is_empty():
		ammo_label = get_node_or_null(ammo_label_path) as Label

	if not weapon_icon_path.is_empty():
		weapon_icon_rect = get_node_or_null(
			weapon_icon_path
		) as TextureRect

	# Search the current gameplay scene.
	var scene := get_tree().current_scene

	if scene != null:
		if ammo_label == null:
			ammo_label = scene.find_child(
				"AmmoLabel", true, false
			) as Label

		if weapon_icon_rect == null:
			weapon_icon_rect = scene.find_child(
				"WeaponIcon", true, false
			) as TextureRect

	# Debug messages
	if ammo_label == null:
		push_warning(
			"Gun HUD: AmmoLabel not found!"
		)
	else:
		print(
			"AmmoLabel found: ",
			ammo_label.get_path()
		)

	if weapon_icon_rect == null:
		push_warning(
			"Gun HUD: WeaponIcon not found!"
		)
	else:
		print(
			"WeaponIcon found: ",
			weapon_icon_rect.get_path()
		)

	if weapon_icon == null:
		push_warning(
			"Gun HUD: No weapon icon PNG assigned!"
		)


# ==========================================
# INPUT
# ==========================================

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and not event.echo:
			if event.keycode == KEY_B:
				fire_mode = (
					FireMode.AUTO
					if fire_mode == FireMode.SEMI
					else FireMode.SEMI
				)

				_play_extra(switch_mode_sound)
				_update_hud()


# ==========================================
# PROCESS
# ==========================================

func _process(delta: float) -> void:
	_update_movement_animation()
	if ads_enabled and InputMap.has_action("aim"):
		var wants_aim := Input.is_action_pressed("aim")

		if wants_aim != is_aiming:
			_set_ads(wants_aim)

	var wants_shot := false

	if fire_mode == FireMode.AUTO:
		wants_shot = Input.is_action_pressed("shoot")
	else:
		wants_shot = Input.is_action_just_pressed("shoot")

	if wants_shot:
		shoot()

	if Input.is_action_just_pressed("reload"):
		reload()

	_update_weapon_visual_transform(delta)


# ==========================================
# SHOOT
# ==========================================

func shoot() -> void:
	if not can_shoot or reloading:
		return

	if ammo <= 0:
		if reserve_ammo > 0:
			reload()
		else:
			_play_extra(empty_click_sound)
			can_shoot = false
			await get_tree().create_timer(0.3).timeout
			can_shoot = true
		return

	ammo -= 1
	shot_count += 1
	can_shoot = false

	_update_hud()
	_play_shot()
	_show_flash()
	_apply_weapon_recoil()

	raycast.force_raycast_update()

	var end_point: Vector3 = raycast.to_global(
		raycast.target_position
	)

	if raycast.is_colliding():
		var target := raycast.get_collider()
		end_point = raycast.get_collision_point()

		print(
			"Hit: ", target.name,
			" at ", end_point
		)

		if target.has_method("take_damage"):
			target.take_damage(damage)

		if debug_markers:
			_spawn_marker(end_point)

	if tracer_enabled:
		if shot_count % max(tracer_every, 1) == 0:
			var start: Vector3 = (
				muzzle.global_position
				if muzzle != null
				else raycast.global_position
			)

			_spawn_tracer(start, end_point)

	await get_tree().create_timer(fire_rate).timeout
	can_shoot = true


# ==========================================
# RELOAD
# ==========================================

func reload() -> void:
	if reloading or ammo == mag_size or reserve_ammo <= 0:
		return

	reloading = true
	_play_weapon_animation(reload_animation)
	_update_hud()

	var duration := reload_time

	if reload_sound != null:
		reload_player.stream = reload_sound
		reload_player.volume_db = reload_volume_db
		reload_player.play()

		if match_reload_time_to_sound:
			duration = reload_sound.get_length()

	if use_reload_animation_length and weapon_animation_player != null:
		var resolved_reload := _resolve_weapon_animation(reload_animation)
		if resolved_reload != &"":
			duration = weapon_animation_player.get_animation(resolved_reload).length

	await get_tree().create_timer(duration).timeout

	var needed := mag_size - ammo
	var taken: int = min(needed, reserve_ammo)

	ammo += taken
	reserve_ammo -= taken
	reloading = false
	_update_movement_animation()

	_play_extra(reload_finish_sound)
	_update_hud()


# ==========================================
# AIM DOWN SIGHTS
# ==========================================

func _set_ads(aiming: bool) -> void:
	is_aiming = aiming

	if not reloading and weapon_animation_player != null:
		if aiming:
			weapon_animation_player.pause()
		else:
			current_weapon_animation = &""
			_update_movement_animation()


# ==========================================
# WEAPON VISUAL RECOIL + ADS
# ==========================================

func _apply_weapon_recoil() -> void:
	if not recoil_enabled:
		return
	var strength := recoil_ads_multiplier if is_aiming else 1.0
	recoil_amount = minf(recoil_amount + strength, maxf(recoil_max_shots, 1.0))


func _update_weapon_visual_transform(delta: float) -> void:
	# Read the player's actual horizontal movement, not just key presses.
	var player := get_parent()
	while player != null and not (player is CharacterBody3D):
		player = player.get_parent()
	var horizontal_speed := 0.0
	var moving := false
	if player is CharacterBody3D:
		horizontal_speed = Vector2(player.velocity.x, player.velocity.z).length()
		moving = horizontal_speed > 0.5 and (walk_bob_airborne or player.is_on_floor())

	# Match the player controller's physical Shift sprint input.
	# Sprint visuals only activate while moving on the ground and not aiming.
	var sprinting := (
		sprint_movement_enabled
		and moving
		and not is_aiming
		and Input.is_physical_key_pressed(sprint_key)
	)
	var sprint_target := 1.0 if sprinting else 0.0
	sprint_visual_blend = move_toward(
		sprint_visual_blend, sprint_target,
		maxf(sprint_transition_speed, 0.01) * delta
	)

	var bob_target := 1.0 if (walk_bob_enabled or sprint_movement_enabled) and moving else 0.0
	walk_bob_weight = move_toward(walk_bob_weight, bob_target, maxf(walk_bob_smoothing, 0.01) * delta)
	if moving and (walk_bob_enabled or sprint_movement_enabled):
		var speed_factor := clampf(horizontal_speed / maxf(walk_bob_speed_reference, 0.01), 0.2, 2.0)
		var frequency := lerpf(walk_bob_frequency, sprint_bob_frequency, sprint_visual_blend)
		walk_bob_phase += delta * frequency * speed_factor

	var bob_ads_scale := lerpf(1.0, walk_bob_ads_multiplier, ads_blend)
	var walk_strength := 1.0 if walk_bob_enabled else 0.0
	var sprint_strength := 1.0 if sprint_movement_enabled else 0.0
	var bob_enabled_strength := lerpf(walk_strength, sprint_strength, sprint_visual_blend)
	var bob_strength := walk_bob_weight * bob_ads_scale * bob_enabled_strength
	var horizontal := lerpf(walk_bob_horizontal, sprint_bob_horizontal, sprint_visual_blend)
	var vertical := lerpf(walk_bob_vertical, sprint_bob_vertical, sprint_visual_blend)
	var roll_degrees := lerpf(walk_bob_roll_degrees, sprint_bob_roll_degrees, sprint_visual_blend)
	var bob_offset := Vector3(
		sin(walk_bob_phase) * horizontal,
		cos(walk_bob_phase * 2.0) * vertical,
		0.0
	) * bob_strength
	var bob_roll := deg_to_rad(roll_degrees) * sin(walk_bob_phase) * bob_strength
	# Compose ADS and recoil on the weapon root so their tweens
	# never fight over the same position or rotation properties.
	var ads_target := 1.0 if is_aiming and ads_enabled else 0.0
	var ads_rate := 1.0 / maxf(ads_transition_time, 0.001)
	ads_blend = move_toward(ads_blend, ads_target, ads_rate * delta)
	var eased_ads := ads_blend * ads_blend * (3.0 - 2.0 * ads_blend)

	var recoil_rate := recoil_kick_speed if recoil_display < recoil_amount else recoil_return_speed
	recoil_display = move_toward(recoil_display, recoil_amount, maxf(recoil_rate, 0.01) * delta)
	recoil_amount = move_toward(recoil_amount, 0.0, maxf(recoil_return_speed, 0.01) * delta)

	var ads_offset := ads_position * eased_ads
	var ads_angles := Vector3(
		deg_to_rad(ads_rotation_degrees.x),
		deg_to_rad(ads_rotation_degrees.y),
		deg_to_rad(ads_rotation_degrees.z)
	) * eased_ads

	# Positive local Z is backward for a forward-facing FPS gun.
	position = hip_position + ads_offset + bob_offset + sprint_position_offset * sprint_visual_blend + Vector3(0.0, 0.0, recoil_kickback * recoil_display)
	rotation = hip_rotation + ads_angles + sprint_rotation_degrees * (PI / 180.0) * sprint_visual_blend + Vector3(deg_to_rad(recoil_pitch_degrees) * recoil_display, 0.0, bob_roll)


# ==========================================
# MUZZLE FLASH
# ==========================================

func _build_muzzle_flash() -> void:
	if muzzle == null:
		if flash_enabled:
			push_warning(
				"gun.gd: Add a Marker3D named Muzzle."
			)
		return

	if not flash_enabled:
		return

	flash_light = OmniLight3D.new()
	flash_light.light_color = flash_color
	flash_light.light_energy = flash_light_energy
	flash_light.omni_range = flash_light_range
	flash_light.shadow_enabled = false
	flash_light.visible = false
	flash_light.position = flash_offset

	muzzle.add_child(flash_light)

	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * flash_size

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = flash_color
	mat.albedo_texture = (
		flash_texture
		if flash_texture != null
		else _make_soft_glow()
	)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	flash_mesh = MeshInstance3D.new()
	flash_mesh.mesh = quad
	flash_mesh.material_override = mat
	flash_mesh.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	flash_mesh.visible = false
	flash_mesh.position = flash_offset

	muzzle.add_child(flash_mesh)


func _make_soft_glow() -> Texture2D:
	var image := Image.create(
		64, 64, false, Image.FORMAT_RGBA8
	)

	var center := Vector2(32.0, 32.0)

	for y in range(64):
		for x in range(64):
			var distance := Vector2(
				float(x), float(y)
			).distance_to(center)

			var strength := clampf(
				1.0 - distance / 32.0,
				0.0,
				1.0
			)

			strength = pow(strength, 2.5)

			image.set_pixel(
				x, y,
				Color(1.0, 1.0, 1.0, strength)
			)

	return ImageTexture.create_from_image(image)


func _show_flash() -> void:
	if flash_mesh == null:
		return

	flash_id += 1
	var my_id := flash_id

	var parent_scale := (
		muzzle.global_transform.basis.get_scale()
	)

	var inverse_scale := Vector3(
		1.0 / max(parent_scale.x, 0.0001),
		1.0 / max(parent_scale.y, 0.0001),
		1.0 / max(parent_scale.z, 0.0001)
	)

	flash_mesh.scale = (
		inverse_scale * randf_range(0.7, 1.3)
	)

	flash_mesh.visible = true
	flash_light.visible = true

	await get_tree().create_timer(
		flash_duration
	).timeout

	if my_id == flash_id:
		flash_mesh.visible = false
		flash_light.visible = false


# ==========================================
# BULLET TRACERS
# ==========================================

func _spawn_tracer(from: Vector3, to: Vector3) -> void:
	var dist := from.distance_to(to)

	if dist < 0.5:
		return

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = tracer_color

	var box := BoxMesh.new()
	box.size = Vector3(
		tracer_width,
		tracer_width,
		tracer_length
	)

	var tracer := MeshInstance3D.new()
	tracer.mesh = box
	tracer.material_override = mat
	tracer.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)

	get_tree().current_scene.add_child(tracer)
	tracer.global_position = from

	var up := Vector3.UP

	if abs(
		(to - from).normalized().dot(Vector3.UP)
	) > 0.99:
		up = Vector3.RIGHT

	tracer.look_at(to, up)

	var tween := tracer.create_tween()

	tween.tween_property(
		tracer,
		"global_position",
		to,
		dist / tracer_speed
	)

	tween.tween_callback(tracer.queue_free)


# ==========================================
# SHOOT AUDIO
# ==========================================

func _play_shot() -> void:
	if shoot_sounds.is_empty():
		return

	var next := shoot_sound_index

	if shoot_sounds.size() > 1:
		while next == shoot_sound_index:
			next = randi() % shoot_sounds.size()
	else:
		next = 0

	shoot_sound_index = next

	var p := shot_players[shot_player_index]

	shot_player_index = (
		shot_player_index + 1
	) % shot_players.size()

	p.stream = shoot_sounds[shoot_sound_index]
	p.volume_db = shoot_volume_db

	p.pitch_scale = 1.0 + randf_range(
		-shoot_pitch_variation,
		shoot_pitch_variation
	)

	p.play()


func _play_extra(stream: AudioStream) -> void:
	if stream == null:
		return

	extra_player.stream = stream
	extra_player.volume_db = reload_volume_db
	extra_player.play()


# ==========================================
# DEBUG HIT MARKER
# ==========================================

func _spawn_marker(point: Vector3) -> void:
	var marker := MeshInstance3D.new()
	var sphere := SphereMesh.new()

	sphere.radius = 0.05
	sphere.height = 0.1

	marker.mesh = sphere

	get_tree().current_scene.add_child(marker)
	marker.global_position = point

	await get_tree().create_timer(2.0).timeout
	marker.queue_free()


# ==========================================
# UPDATE AMMO HUD
# ==========================================

func _update_hud() -> void:
	if ammo_label == null:
		return

	if reloading:
		ammo_label.text = "Reloading..."
	else:
		var mode_text := (
			"AUTO"
			if fire_mode == FireMode.AUTO
			else "SEMI"
		)

		ammo_label.text = (
			"%d / %d  [%s]"
			% [ammo, reserve_ammo, mode_text]
		)


# ==========================================
# UPDATE WEAPON ICON
# ==========================================

func _update_weapon_icon() -> void:
	if weapon_icon_rect == null:
		push_warning(
			"Gun HUD: Cannot update missing WeaponIcon!"
		)
		return

	if weapon_icon == null:
		push_warning(
			"Gun HUD: Assign a PNG to Weapon Icon in Inspector!"
		)
		weapon_icon_rect.hide()
		return

	weapon_icon_rect.texture = weapon_icon
	weapon_icon_rect.show()

	weapon_icon_rect.custom_minimum_size = (
		weapon_icon_size
	)

	weapon_icon_rect.expand_mode = (
		TextureRect.EXPAND_IGNORE_SIZE
	)

	weapon_icon_rect.stretch_mode = (
		TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	)

	weapon_icon_rect.texture_filter = (
		CanvasItem.TEXTURE_FILTER_NEAREST
	)

	weapon_icon_rect.modulate = Color.WHITE

	print(
		"Weapon icon updated: ",
		weapon_icon.resource_path
	)


# ==========================================
# WEAPON EQUIP
# ==========================================

func equip_weapon() -> void:
	_find_hud_nodes()
	_update_hud()
	_update_weapon_icon()
