



extends Area3D

# ==========================================
# HEALTH PICKUP SETTINGS
# ==========================================

@export_group("Health Pickup")
@export var pickup_only_when_injured := false


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
	# Enable collision detection
	monitoring = true

	# Connect pickup detection
	body_entered.connect(_on_body_entered)

	print("Health box ready: ", name)


# ==========================================
# PLAYER PICKUP DETECTION
# ==========================================

func _on_body_entered(body: Node3D) -> void:
	if collected:
		return

	# Find the player's Health component
	var health_node = body.get_node_or_null("Health")

	if health_node == null:
		print("Health node not found on: ", body.name)
		return

	# Check that healing is supported
	if not health_node.has_method("heal"):
		return

	# Don't heal dead players
	if health_node.dead:
		return

	# Optionally require missing health
	if pickup_only_when_injured:
		if health_node.health >= health_node.max_health:
			return

	# Prevent collecting more than once
	collected = true

	# ======================================
	# RESTORE FULL HEALTH
	# ======================================

	var missing_health: float = (
		health_node.max_health - health_node.health
	)

	health_node.heal(missing_health)

	print("Health restored to full!")

	# ======================================
	# PLAY HEALING SCREEN FLASH
	# ======================================

	var heal_flash = body.find_child(
		"HealFlash",
		true,
		false
	)

	if heal_flash != null:
		if heal_flash.has_method("play_flash"):
			heal_flash.play_flash()
		else:
			print("HealFlash has no play_flash() method")
	else:
		print("HealFlash not found under Player")

	# ======================================
	# PLAY PICKUP SOUND
	# ======================================

	_play_pickup_sound()

	# ======================================
	# REMOVE HEALTH BOX
	# ======================================

	_hide_pickup()
	queue_free()


# ==========================================
# PICKUP AUDIO
# ==========================================

func _play_pickup_sound() -> void:
	if pickup_sound == null:
		return

	# Create sound outside pickup so
	# deleting the box won't stop audio.
	var sound_player := AudioStreamPlayer.new()

	var scene = get_tree().current_scene
	if scene == null:
		return

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
	# Hide model and visual children
	visible = false

	# Disable further pickup detection
	set_deferred("monitoring", false)

	# Disable collision shape
	var collision = get_node_or_null("CollisionShape3D")

	if collision != null:
		collision.set_deferred("disabled", true)
