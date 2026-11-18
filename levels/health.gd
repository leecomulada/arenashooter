extends Node

signal health_changed(current: float, maximum: float)
signal died

@export var bar: ProgressBar                 # drag your HealthBar into this slot
@export var max_health := 100.0
@export var regen_enabled := true
@export var regen_delay := 4.0               # seconds after last hit before regen starts
@export var regen_rate := 20.0               # health per second while regenerating
@export var low_health_fraction := 0.5       # "low" sound threshold (0.5 = below half)
@export var debug_keys := true               # H = take 10 damage, J = heal 10

@export_group("Bar Colors")
@export var normal_color := Color(1.0, 0.3, 0.237, 1.0)    # healthy color (cyan)
@export var low_color := Color(0.475, 0.0, 0.005, 1.0)       # low-health color (red)
@export_range(0.0, 1.0) var color_threshold := 0.3   # below this fraction the bar turns toward low_color
@export var smooth_color := false                    # true = fade between colors, false = instant switch
@export var bg_color := Color(0.282, 0.0, 0.0, 0.549)         # empty part of the bar
@export var border_color := Color(0.639, 0.0, 0.0, 0.702)

@export_group("Audio")
@export var hurt_sounds: Array[AudioStream] = []     # add 3 (or more) hurt sounds
@export var random_order := false                    # false = rotate in order, true = random
@export var break_sound: AudioStream                 # first hit from full health
@export var low_health_sound: AudioStream            # when you drop below half
@export var death_sound: AudioStream                 # optional
@export var recharge_sound: AudioStream              # plays while health is recharging
@export var recharge_loop := false                    # restart the recharge sound until you're full
@export var recharge_done_sound: AudioStream         # optional: plays when fully recharged
@export_range(-40.0, 6.0) var sound_volume_db := 0.0
@export var pitch_variation := 0.05

var health := 0.0
var time_since_damage := 0.0
var dead := false
var regenerating := false
var bar_tween: Tween
var fill_style := StyleBoxFlat.new()
var hurt_player: AudioStreamPlayer
var alert_player: AudioStreamPlayer
var recharge_player: AudioStreamPlayer
var hurt_index := -1


func _ready() -> void:
	health = max_health

	hurt_player = AudioStreamPlayer.new()
	add_child(hurt_player)
	alert_player = AudioStreamPlayer.new()
	add_child(alert_player)
	recharge_player = AudioStreamPlayer.new()
	add_child(recharge_player)

	print("Health ready. health: ", health, " bar: ", bar)

	if bar:
		bar.min_value = 0.0
		bar.max_value = max_health
		bar.value = health
		bar.show_percentage = false
		_style_bar()
		_update_color()


func _unhandled_input(event: InputEvent) -> void:
	if not debug_keys:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_H:
			take_damage(10.0)
		elif event.keycode == KEY_J:
			heal(10.0)


func _process(delta: float) -> void:
	if dead:
		return

	time_since_damage += delta

	if regen_enabled and health < max_health and time_since_damage >= regen_delay:
		if not regenerating:
			_start_recharge()
		health = min(health + regen_rate * delta, max_health)
		_update_bar(false)

		# keep the sound going while recharging
		if recharge_loop and not recharge_player.playing:
			recharge_player.play()

		if health >= max_health:
			_finish_recharge()


func take_damage(amount: float) -> void:
	if dead:
		return

	_stop_recharge()

	var previous := health
	var low_line := max_health * low_health_fraction

	health = max(health - amount, 0.0)
	time_since_damage = 0.0
	_update_bar(true)

	if health <= 0.0:
		var stream: AudioStream = death_sound if death_sound else _next_hurt_sound()
		_play(hurt_player, stream, true)
		_die()
		return

	_play(hurt_player, _next_hurt_sound(), true)

	if previous >= max_health:
		_play(alert_player, break_sound, false)

	if previous >= low_line and health < low_line:
		_play(alert_player, low_health_sound, false)


func heal(amount: float) -> void:
	if dead:
		return
	health = min(health + amount, max_health)
	_update_bar(true)


func _start_recharge() -> void:
	regenerating = true
	if recharge_sound:
		recharge_player.stream = recharge_sound
		recharge_player.volume_db = sound_volume_db
		recharge_player.pitch_scale = 1.0
		recharge_player.play()


func _stop_recharge() -> void:
	regenerating = false
	if recharge_player and recharge_player.playing:
		recharge_player.stop()


func _finish_recharge() -> void:
	_stop_recharge()
	_play(alert_player, recharge_done_sound, false)


func _next_hurt_sound() -> AudioStream:
	if hurt_sounds.is_empty():
		return null
	if hurt_sounds.size() == 1:
		return hurt_sounds[0]

	if random_order:
		var next := hurt_index
		while next == hurt_index:
			next = randi() % hurt_sounds.size()
		hurt_index = next
	else:
		hurt_index = (hurt_index + 1) % hurt_sounds.size()

	return hurt_sounds[hurt_index]


func _play(player: AudioStreamPlayer, stream: AudioStream, vary_pitch: bool) -> void:
	if stream == null:
		return
	player.stream = stream
	player.volume_db = sound_volume_db
	player.pitch_scale = 1.0 + (randf_range(-pitch_variation, pitch_variation) if vary_pitch else 0.0)
	player.play()


func _die() -> void:
	dead = true
	_stop_recharge()
	died.emit()
	print("Player died")
	await get_tree().create_timer(2.0).timeout
	get_tree().reload_current_scene()


func _update_bar(animate: bool) -> void:
	health_changed.emit(health, max_health)
	if bar == null:
		return

	_update_color()

	if bar_tween:
		bar_tween.kill()
	if animate:
		bar_tween = create_tween()
		bar_tween.tween_property(bar, "value", health, 0.25)
	else:
		bar.value = health


func _update_color() -> void:
	var fraction := health / max_health
	if smooth_color:
		var t: float = clamp(fraction / max(color_threshold, 0.001), 0.0, 1.0)
		fill_style.bg_color = low_color.lerp(normal_color, t)
	else:
		fill_style.bg_color = low_color if fraction < color_threshold else normal_color


func _style_bar() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = bg_color
	bg.set_border_width_all(2)
	bg.border_color = border_color

	fill_style.bg_color = normal_color

	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill_style)
