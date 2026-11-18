extends Control

# Attach this to a Control named DashHUD under your HUD/CanvasLayer.
# Set Player Path and Dash Icon in the Inspector.
@export var player_path: NodePath
@export var dash_icon: Texture2D
@export var ring_color := Color(1.0, 0.24, 0.35)
@export var ring_background := Color(0.3, 0.13, 0.18, 0.8)
@export var ring_radius := 34.0
@export var ring_thickness := 5.0
@export var icon_size := Vector2(54, 54)

var player: CharacterBody3D
var icon_rect: TextureRect
var count_label: Label

func _ready() -> void:
	custom_minimum_size = Vector2(130, 90)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect = TextureRect.new()
	icon_rect.texture = dash_icon
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon_rect)
	count_label = Label.new()
	count_label.add_theme_font_size_override("font_size", 26)
	count_label.add_theme_color_override("font_color", ring_color)
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(count_label)
	if not player_path.is_empty():
		player = get_node_or_null(player_path) as CharacterBody3D
	if player == null:
		push_warning("DashHUD: Assign Player Path in Inspector.")
	_update_hud()

func _process(_delta: float) -> void:
	_update_hud()

func _update_hud() -> void:
	icon_rect.texture = dash_icon
	icon_rect.position = Vector2(40, 45) - icon_size * 0.5
	icon_rect.size = icon_size
	if player == null:
		count_label.text = "×0"
		return
	var charges: int = player.get("dash_charges")
	count_label.text = "×%d" % charges
	count_label.position = Vector2(83, 27)
	count_label.size = Vector2(48, 40)
	icon_rect.modulate = Color.WHITE if charges > 0 else Color(0.45, 0.45, 0.45)
	queue_redraw()

func _draw() -> void:
	var center := Vector2(40, 45)
	draw_arc(center, ring_radius, 0.0, TAU, 64, ring_background, ring_thickness, true)
	if player == null:
		return
	var progress: float = player.get_dash_recharge_progress()
	if player.get("dash_charges") >= player.get("dash_max_charges"):
		progress = 1.0
	if progress > 0.0:
		draw_arc(center, ring_radius, -PI / 2.0, -PI / 2.0 + TAU * progress, 64, ring_color, ring_thickness, true)
