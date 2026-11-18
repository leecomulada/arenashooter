

extends Area3D

# ==========================================
# AMMO PICKUP SETTINGS
# ==========================================

@export_group("Ammo Pickup")
@export_range(1, 999, 1) var ammo_amount := 24
@export var pickup_only_when_needed := false
@export var max_reserve_ammo := 180


# ==========================================
# AUDIO SETTINGS
# ==========================================

@export_group("Audio")
@export var pickup_sound: AudioStream
@export_range(-40.0, 6.0) var pickup_volume_db := 0.0


# ==========================================
# VARIABLES
# ==========================================

var collected := false


# ==========================================
# READY
# ==========================================

func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_body_entered)
	print("Ammo box ready: ", name)


# ==========================================
# PLAYER PICKUP DETECTION
# ==========================================

func _on_body_entered(body: Node3D) -> void:
	if collected:
		return

	var gun := _find_gun(body)

	if gun == null:
		print("Ammo box: No gun found on ", body.name)
		return

	var current_reserve: int = gun.reserve_ammo
	var available_space: int = maxi(
		max_reserve_ammo - current_reserve,
		0
	)

	if pickup_only_when_needed and available_space <= 0:
		return

	var ammo_to_add: int = mini(
		ammo_amount,
		available_space
	)

	if ammo_to_add <= 0:
		return

	collected = true
	gun.reserve_ammo += ammo_to_add

	# Update the ammo HUD
	if gun.has_method("_update_hud"):
		gun._update_hud()

	# Trigger the ammo screen flash
	var ammo_flash := body.find_child(
		"AmmoFlash",
		true,
		false
	)

	if ammo_flash != null and ammo_flash.has_method("play_flash"):
		ammo_flash.play_flash()
	else:
		print("AmmoFlash not found under Player")

	# Play pickup sound
	_play_pickup_sound()

	print(
		"Ammo collected! Added: ",
		ammo_to_add,
		" | Reserve: ",
		gun.reserve_ammo
	)

	# Remove pickup
	_hide_pickup()
	queue_free()


# ==========================================
# FIND PLAYER GUN
# ==========================================

func _find_gun(node: Node) -> Node:
	if (
		"reserve_ammo" in node
		and "mag_size" in node
		and "ammo" in node
	):
		return node

	for child in node.get_children():
		var result := _find_gun(child)

		if result != null:
			return result

	return null


# ==========================================
# PICKUP SOUND
# ==========================================

func _play_pickup_sound() -> void:
	if pickup_sound == null:
		return

	var scene := get_tree().current_scene

	if scene == null:
		return

	var sound_player := AudioStreamPlayer.new()
	scene.add_child(sound_player)

	sound_player.stream = pickup_sound
	sound_player.volume_db = pickup_volume_db

	sound_player.finished.connect(
		sound_player.queue_free
	)

	sound_player.play()


# ==========================================
# HIDE PICKUP
# ==========================================

func _hide_pickup() -> void:
	visible = false
	set_deferred("monitoring", false)

	var collision := get_node_or_null(
		"CollisionShape3D"
	) as CollisionShape3D

	if collision != null:
		collision.set_deferred("disabled", true)
