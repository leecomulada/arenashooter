


extends HBoxContainer

# ==========================================
# PSX WEAPON HUD
# GODOT 4.7
# ==========================================

@export_group("Position")
@export var left_margin := 20.0
@export var bottom_margin := 20.0

@export_group("Layout")
@export var icon_width := 96.0
@export var icon_height := 48.0
@export var spacing := 12
@export var padding := 12

@export_group("PSX Colors")
@export var background_color := Color("#240D12")
@export var border_color := Color("#9E2832")
@export var ammo_text_color := Color("#FF4A55")
@export_range(0.0, 1.0) var background_opacity := 0.9

@export_group("Border")
@export_range(0, 8) var border_width := 2

var background_panel: Panel
var weapon_icon: TextureRect
var ammo_label: Label


# ==========================================
# READY
# ==========================================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	visible = true
	top_level = true
	scale = Vector2.ONE

	# Reset previous oversized layout
	custom_minimum_size = Vector2.ZERO

	add_theme_constant_override(
		"separation",
		spacing
	)

	weapon_icon = get_node_or_null(
		"WeaponIcon"
	) as TextureRect

	ammo_label = get_node_or_null(
		"AmmoLabel"
	) as Label

	# Configure weapon image
	if weapon_icon != null:
		weapon_icon.visible = true
		weapon_icon.custom_minimum_size = Vector2(
			icon_width,
			icon_height
		)
		weapon_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		weapon_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		weapon_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		weapon_icon.modulate = Color.WHITE

	# Configure ammo text
	if ammo_label != null:
		ammo_label.visible = true
		ammo_label.modulate = Color.WHITE
		ammo_label.add_theme_color_override(
			"font_color",
			ammo_text_color
		)

	# Create background behind the HUD
	_create_background()

	# Wait for layout to calculate
	await get_tree().process_frame

	_update_layout()

	get_viewport().size_changed.connect(
		_update_layout
	)

	print("PSX Weapon HUD ready!")


# ==========================================
# CREATE BACKGROUND
# ==========================================

func _create_background() -> void:
	background_panel = Panel.new()
	background_panel.name = "PSXBackground"

	background_panel.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	# Prevent the background from affecting
	# the HBoxContainer's layout.
	background_panel.set_as_top_level(true)

	var style := StyleBoxFlat.new()

	var bg := background_color
	bg.a = background_opacity

	style.bg_color = bg
	style.border_color = border_color
	style.set_border_width_all(border_width)

	# Sharp PS1-style corners
	style.set_corner_radius_all(0)

	background_panel.add_theme_stylebox_override(
		"panel",
		style
	)

	add_child(background_panel)

	# Draw behind the weapon image and ammo
	background_panel.z_index = -1


# ==========================================
# UPDATE POSITION AND SIZE
# ==========================================

func _update_layout() -> void:
	# Reset container size based on contents
	reset_size()

	var screen_size := get_viewport_rect().size

	# Position bottom-left
	position = Vector2(
		left_margin + padding,
		screen_size.y - size.y - bottom_margin - padding
	)

	# Background extends around the contents
	if background_panel != null:
		background_panel.global_position = (
			global_position - Vector2(
				padding,
				padding
			)
		)

		background_panel.size = (
			size + Vector2(
				padding * 2,
				padding * 2
			)
		)

	print("HUD position: ", position)
	print("HUD size: ", size)


# ==========================================
# REFRESH HUD
# ==========================================

func refresh_hud() -> void:
	_update_layout()
