extends Area3D

@export var damage := 10.0
@export var damage_interval := 0.5   # seconds between hits while you stand inside

var bodies_inside: Array[Node3D] = []
var timer := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	print("Entered: ", body.name, " has take_damage: ", body.has_method("take_damage"))
	if body.has_method("take_damage"):
		bodies_inside.append(body)
		body.take_damage(damage)   # hit right away on contact
		timer = 0.0


func _on_body_exited(body: Node3D) -> void:
	bodies_inside.erase(body)


func _physics_process(delta: float) -> void:
	if bodies_inside.is_empty():
		return

	timer += delta
	if timer >= damage_interval:
		timer = 0.0
		for body in bodies_inside:
			if is_instance_valid(body):
				body.take_damage(damage)
