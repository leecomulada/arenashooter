
extends ColorRect

@export_group("Healing Flash")
@export var flash_color := Color(0.269, 0.689, 0.0, 1.0)
@export_range(0.0, 1.0) var flash_opacity := 0.18
@export_range(0.05, 2.0) var fade_duration := 0.35

var flash_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = flash_color
	modulate.a = 0.0


func play_flash() -> void:
	if flash_tween:
		flash_tween.kill()

	color = flash_color
	modulate.a = flash_opacity

	flash_tween = create_tween()
	flash_tween.tween_property(
		self,
		"modulate:a",
		0.0,
		fade_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
