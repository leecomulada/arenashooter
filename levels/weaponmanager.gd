




extends Node3D

@export_group("Weapon Scenes")
@export var unarmed_scene: PackedScene
@export var g19_fps_scene: PackedScene

var current_weapon: Node3D = null
var current_weapon_name: String = ""
var has_g19: bool = false


func _ready() -> void:
	equip_unarmed()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("weapon_g19"):
		equip_g19()

	elif event.is_action_pressed("weapon_unarmed"):
		equip_unarmed()


func equip_unarmed() -> void:
	switch_weapon(unarmed_scene, "Unarmed")


func equip_g19() -> void:
	if not has_g19:
		return

	switch_weapon(g19_fps_scene, "g19-fps")


func switch_weapon(scene: PackedScene, weapon_name: String) -> void:
	if scene == null:
		push_warning("Weapon scene not assigned: " + weapon_name)
		return

	if current_weapon_name == weapon_name:
		return

	var new_weapon := scene.instantiate() as Node3D

	if new_weapon == null:
		push_error("Weapon scene must have a Node3D root.")
		return

	if is_instance_valid(current_weapon):
		remove_child(current_weapon)
		current_weapon.queue_free()
		current_weapon = null

	current_weapon = new_weapon
	add_child(current_weapon)

	current_weapon_name = weapon_name


func pickup_g19() -> void:
	if has_g19:
		return

	has_g19 = true
	equip_g19()
