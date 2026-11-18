extends Control
## Attach to a Control node under your HUD CanvasLayer.
## The crosshair stays at the center of the viewport at any resolution.

@export_group("Crosshair Image")
@export var crosshair_texture: Texture2D:
	set(value):
		crosshair_texture = value
		queue_redraw()
@export var crosshair_size := Vector2(32.0, 32.0):
	set(value):
		crosshair_size = value
		queue_redraw()
@export var crosshair_color := Color.WHITE:
	set(value):
		crosshair_color = value
		queue_redraw()
@export_range(0.0, 1.0, 0.01) var crosshair_opacity := 1.0:
	set(value):
		crosshair_opacity = value
		queue_redraw()

@export_group("Crosshair Position")
@export var center_offset := Vector2.ZERO:
	set(value):
		center_offset = value
		queue_redraw()
@export var pixel_perfect := true:
	set(value):
		pixel_perfect = value
		queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_viewport().size_changed.connect(queue_redraw)
	queue_redraw()

func _draw() -> void:
	if crosshair_texture == null:
		return
	var size_to_draw := Vector2(maxf(crosshair_size.x, 1.0), maxf(crosshair_size.y, 1.0))
	var top_left := size * 0.5 + center_offset - size_to_draw * 0.5
	if pixel_perfect:
		top_left = top_left.round()
	var tint := crosshair_color
	tint.a *= crosshair_opacity
	draw_texture_rect(crosshair_texture, Rect2(top_left, size_to_draw), false, tint)
