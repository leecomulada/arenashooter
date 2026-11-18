



extends CanvasLayer

# ==========================================
# PSX RED PAUSE MENU
# GODOT 4
# ==========================================

@export_group("Colors")
@export var background_color := Color(0.035, 0.01, 0.015, 0.85)
@export var panel_color := Color("#240D12")
@export var border_color := Color("#9E2832")
@export var bright_red := Color("#FF4A55")
@export var faded_red := Color("#A65A60")
@export var dark_red := Color("#18090C")

@export_group("Font")
@export var pixel_font: Font

@export_group("Layout")
@export var menu_width := 320.0
@export var button_height := 48.0
@export var button_spacing := 12


# ==========================================
# VARIABLES
# ==========================================

var menu: Control
var background: ColorRect
var center_container: CenterContainer
var panel: PanelContainer
var button_container: VBoxContainer
var title_label: Label
var resume_button: Button
var quit_button: Button

var is_paused := false


# ==========================================
# READY
# ==========================================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Build menu automatically
	_create_menu()

	# Connect buttons
	resume_button.pressed.connect(resume_game)
	quit_button.pressed.connect(quit_game)

	# Start hidden
	menu.hide()

	print("PSX Pause Menu ready!")


# ==========================================
# CREATE MENU
# ==========================================

func _create_menu() -> void:
	# Hide old manually created menu if present
	for child in get_children():
		if child is Control:
			child.hide()
			child.queue_free()

	# Main fullscreen Control
	menu = Control.new()
	menu.name = "PauseControl"
	menu.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	add_child(menu)

	# Fullscreen dark overlay
	background = ColorRect.new()
	background.name = "Background"
	background.color = background_color
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	menu.add_child(background)
	background.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	# Centering container
	center_container = CenterContainer.new()
	center_container.name = "CenterContainer"
	menu.add_child(center_container)
	center_container.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	# Panel
	panel = PanelContainer.new()
	panel.name = "PausePanel"
	panel.custom_minimum_size.x = menu_width
	center_container.add_child(panel)

	_style_panel()

	# Vertical button layout
	button_container = VBoxContainer.new()
	button_container.name = "VBoxContainer"
	button_container.add_theme_constant_override(
		"separation", button_spacing
	)
	panel.add_child(button_container)

	# Title
	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "P A U S E D"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override(
		"font_color", bright_red
	)
	title_label.add_theme_font_size_override(
		"font_size", 28
	)

	if pixel_font != null:
		title_label.add_theme_font_override(
			"font", pixel_font
		)

	button_container.add_child(title_label)

	# Resume button
	resume_button = Button.new()
	resume_button.name = "ResumeButton"
	resume_button.text = "RESUME"
	button_container.add_child(resume_button)
	_style_button(resume_button)

	# Quit button
	quit_button = Button.new()
	quit_button.name = "QuitButton"
	quit_button.text = "QUIT"
	button_container.add_child(quit_button)
	_style_button(quit_button)


# ==========================================
# INPUT
# ==========================================

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE:
				if is_paused:
					resume_game()
				else:
					pause_game()

				get_viewport().set_input_as_handled()


# ==========================================
# PAUSE GAME
# ==========================================

func pause_game() -> void:
	is_paused = true

	menu.show()
	get_tree().paused = true

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	resume_button.grab_focus()


# ==========================================
# RESUME GAME
# ==========================================

func resume_game() -> void:
	is_paused = false

	get_tree().paused = false

	menu.hide()

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# ==========================================
# QUIT GAME
# ==========================================

func quit_game() -> void:
	get_tree().paused = false
	get_tree().quit()


# ==========================================
# PANEL STYLE
# ==========================================

func _style_panel() -> void:
	var style := StyleBoxFlat.new()

	style.bg_color = panel_color
	style.border_color = border_color
	style.set_border_width_all(2)
	style.set_content_margin_all(24)

	panel.add_theme_stylebox_override(
		"panel", style
	)


# ==========================================
# BUTTON STYLE
# ==========================================

func _style_button(button: Button) -> void:
	button.custom_minimum_size = Vector2(
		menu_width - 48,
		button_height
	)

	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Font
	button.add_theme_color_override(
		"font_color", faded_red
	)
	button.add_theme_color_override(
		"font_hover_color", bright_red
	)
	button.add_theme_color_override(
		"font_focus_color", bright_red
	)
	button.add_theme_color_override(
		"font_pressed_color", Color.WHITE
	)
	button.add_theme_font_size_override(
		"font_size", 18
	)

	if pixel_font != null:
		button.add_theme_font_override(
			"font", pixel_font
		)

	# Normal style
	var normal := StyleBoxFlat.new()
	normal.bg_color = dark_red
	normal.border_color = Color("#562025")
	normal.set_border_width_all(1)

	button.add_theme_stylebox_override(
		"normal", normal
	)

	# Hover style
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color("#4C151B")
	hover.border_color = bright_red
	hover.set_border_width_all(2)

	button.add_theme_stylebox_override(
		"hover", hover
	)

	# Pressed style
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = border_color
	pressed.border_color = bright_red
	pressed.set_border_width_all(2)

	button.add_theme_stylebox_override(
		"pressed", pressed
	)

	# Focus style
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = bright_red
	focus.set_border_width_all(1)

	button.add_theme_stylebox_override(
		"focus", focus
	)
