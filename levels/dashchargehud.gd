extends Control
## Two-segment dash charge bar, shown after dashing and hidden when recharged.
## Attach to DashHUD (Control), directly under your HUD CanvasLayer.

@export_group("Player")
@export var player_path: NodePath
@export_range(1, 5, 1) var max_charges_fallback: int = 2

@export_group("Bar Appearance")
@export_range(20.0, 400.0, 1.0) var bar_width: float = 110.0
@export_range(2.0, 40.0, 1.0) var bar_height: float = 8.0
@export_range(0.0, 40.0, 1.0) var segment_gap: float = 6.0
@export var filled_color: Color = Color("ff5264")
@export var empty_color: Color = Color("33343c")
@export var border_color: Color = Color("a94b57")
@export_range(0.0, 5.0, 0.5) var border_width: float = 1.0

@export_group("Position")
## Match Crosshair's Center Offset X if you have moved your crosshair.
@export var crosshair_offset: Vector2 = Vector2(0, 40)
@export var crosshair_path: NodePath

@export_group("Visibility")
@export_range(0.0, 5.0, 0.1) var full_charge_hold_time: float = 0.35
@export_range(0.0, 3.0, 0.05) var fade_out_time: float = 0.35

var _previous_charges: int = -1
var _has_dashed: bool = false
var _fade_tween: Tween
var _hide_delay: float = -1.0

var crosshair: Control
var player: Node
var _charges: int = 2
var _maximum: int = 2
var _progress: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Full-screen drawing surface: avoids double-counting a centered anchor.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_find_player()
	_find_crosshair()
	_refresh()
	_previous_charges = _charges

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		_find_player()
	if not is_instance_valid(crosshair):
		_find_crosshair()
	_refresh()
	_update_visibility(delta)

func _find_player() -> void:
	player = null
	if not player_path.is_empty():
		player = get_node_or_null(player_path)
	if player == null:
		var scene := get_tree().current_scene
		if scene != null:
			player = scene.find_child("Player", true, false)

func _find_crosshair() -> void:
	crosshair = null
	if not crosshair_path.is_empty():
		crosshair = get_node_or_null(crosshair_path) as Control
	if crosshair == null and get_parent() != null:
		crosshair = get_parent().get_node_or_null("Crosshair") as Control

func _bar_center_local() -> Vector2:
	# Convert the actual crosshair center to this Control's coordinates.
	# This works even if the two Controls have different anchors/offsets.
	var screen_center: Vector2
	if is_instance_valid(crosshair):
		var crosshair_center := crosshair.size * 0.5
		var crosshair_adjustment: Variant = _read_property(crosshair, "center_offset", Vector2.ZERO)
		if crosshair_adjustment is Vector2:
			crosshair_center += crosshair_adjustment
		screen_center = crosshair.get_global_transform_with_canvas() * crosshair_center
	else:
		screen_center = get_viewport_rect().size * 0.5
	return get_global_transform_with_canvas().affine_inverse() * screen_center

func _read_property(object: Object, property_name: String, fallback: Variant) -> Variant:
	if not is_instance_valid(object):
		return fallback
	for info in object.get_property_list():
		if info.name == property_name:
			return object.get(property_name)
	return fallback

func _refresh() -> void:
	_maximum = maxi(1, int(_read_property(player, "dash_max_charges", max_charges_fallback)))
	_charges = clampi(int(_read_property(player, "dash_charges", _maximum)), 0, _maximum)
	_progress = 0.0
	if is_instance_valid(player) and player.has_method("get_dash_recharge_progress"):
		_progress = clampf(float(player.call("get_dash_recharge_progress")), 0.0, 1.0)
	else:
		var remaining = _read_property(player, "dash_recharge_remaining", null)
		var duration = _read_property(player, "dash_recharge_time", null)
		if remaining != null and duration != null and float(duration) > 0.0:
			_progress = clampf(1.0 - float(remaining) / float(duration), 0.0, 1.0)
	queue_redraw()

func _update_visibility(delta: float) -> void:
	if _previous_charges < 0:
		_previous_charges = _charges
		return

	if _charges < _previous_charges:
		_has_dashed = true
		_hide_delay = -1.0
		if is_instance_valid(_fade_tween):
			_fade_tween.kill()
		modulate.a = 1.0
		visible = true

	_previous_charges = _charges
	if not _has_dashed:
		return

	# Keep showing while any dash charge is still regenerating.
	if _charges < _maximum:
		_hide_delay = -1.0
		if is_instance_valid(_fade_tween) and _fade_tween.is_running():
			_fade_tween.kill()
			modulate.a = 1.0
		return

	# All charges restored: hold briefly, then fade out.
	if _hide_delay < 0.0:
		_hide_delay = full_charge_hold_time
	if _hide_delay > 0.0:
		_hide_delay = maxf(0.0, _hide_delay - delta)
		return
	if is_instance_valid(_fade_tween) and _fade_tween.is_running():
		return
	if not visible:
		return
	if fade_out_time <= 0.0:
		visible = false
		_has_dashed = false
		return
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 0.0, fade_out_time)
	_fade_tween.tween_callback(_finish_hiding)

func _finish_hiding() -> void:
	visible = false
	modulate.a = 1.0
	_has_dashed = false
	_hide_delay = -1.0

func _draw() -> void:
	# Use the same viewport-center calculation as crosshair_hud.gd.
	var top_left := _bar_center_local() + crosshair_offset - Vector2(bar_width * 0.5, 0.0)
	var count := _maximum
	var width_per_segment := maxf(1.0, (bar_width - segment_gap * float(count - 1)) / float(count))
	for i in range(count):
		var rect := Rect2(top_left + Vector2(float(i) * (width_per_segment + segment_gap), 0.0), Vector2(width_per_segment, bar_height))
		draw_rect(rect, empty_color, true)
		var fill_fraction := 0.0
		if i < _charges:
			fill_fraction = 1.0
		elif i == _charges and _charges < _maximum:
			fill_fraction = _progress
		if fill_fraction > 0.0:
			draw_rect(Rect2(rect.position, Vector2(rect.size.x * fill_fraction, rect.size.y)), filled_color, true)
		if border_width > 0.0:
			draw_rect(rect, border_color, false, border_width)
