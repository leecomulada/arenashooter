
extends StaticBody3D

@export_group("Pickup Appearance")
@export var gun_model: Node3D
@export var spin_enabled := true
@export var spin_speed := 90.0
@export var float_enabled := true
@export var float_height := 0.12
@export var float_speed := 2.0

@export_group("Interaction")
@export var pickup_name := "G19"

var starting_height := 0.0
var time := 0.0


func _ready() -> void:
	if gun_model == null:
		push_error("G19 Pickup: Assign GunModel in Inspector!")
		set_process(false)
		return

	starting_height = gun_model.position.y
	print("G19 pickup ready!")


func _process(delta: float) -> void:
	time += delta

	if spin_enabled:
		gun_model.rotate_y(deg_to_rad(spin_speed * delta))

	if float_enabled:
		gun_model.position.y = (
			starting_height
			+ sin(time * float_speed) * float_height
		)


func get_interaction_text() -> String:
	return "[E] PICK UP " + pickup_name


func interact(weapon_manager: Node) -> void:
	if weapon_manager == null:
		push_error("G19 Pickup: WeaponManager not found!")
		return

	if not weapon_manager.has_method("pickup_g19"):
		push_error("G19 Pickup: Missing pickup_g19()!")
		return

	if weapon_manager.has_g19:
		print("G19 already collected.")
		return

	weapon_manager.pickup_g19()
	print("G19 successfully picked up!")
	queue_free()
