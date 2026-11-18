extends Node

@export var target: Node3D                       # drag your g19 node here
@export_range(0.0, 1.0) var depth_squash := 0.9  # higher = gun is pushed further in front of the world

const SHADER_CODE := """
shader_type spatial;

uniform sampler2D albedo_tex : source_color, filter_nearest;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform bool use_texture = true;
uniform float squash = 0.9;

void vertex() {
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * MODEL_MATRIX * vec4(VERTEX, 1.0);
	// Godot 4.3+ uses reversed depth, so pulling z toward w moves the model to the near plane
	POSITION.z = mix(POSITION.z, POSITION.w, squash);
}

void fragment() {
	vec4 c = albedo_color;
	if (use_texture) {
		c *= texture(albedo_tex, UV);
	}
	ALBEDO = c.rgb;
	ROUGHNESS = 1.0;
}
"""


func _ready() -> void:
	if target == null:
		push_warning("viewmodel_fix: drag your gun node into the Target slot")
		return

	var shader := Shader.new()
	shader.code = SHADER_CODE
	_apply(target, shader)


func _apply(node: Node, shader: Shader) -> void:
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for i in mi.get_surface_override_material_count():
			var src := mi.get_active_material(i)
			var mat := ShaderMaterial.new()
			mat.shader = shader
			mat.set_shader_parameter("squash", depth_squash)

			if src is BaseMaterial3D:
				mat.set_shader_parameter("albedo_color", src.albedo_color)
				if src.albedo_texture:
					mat.set_shader_parameter("albedo_tex", src.albedo_texture)
					mat.set_shader_parameter("use_texture", true)
				else:
					mat.set_shader_parameter("use_texture", false)
			else:
				mat.set_shader_parameter("use_texture", false)

			mi.set_surface_override_material(i, mat)

	for child in node.get_children():
		_apply(child, shader)
