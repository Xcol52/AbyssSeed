shader_type spatial;

render_mode unshaded, cull_disabled;

const float TWO_PI = 6.28318530718;

uniform vec4 cold_color : source_color = vec4(
	0.1,
	0.25,
	0.3,
	1.0
);

uniform vec4 warm_color : source_color = vec4(
	0.5,
	0.7,
	0.3,
	1.0
);

uniform float tail_amplitude : hint_range(
	0.0,
	0.5
) = 0.08;

uniform float tail_speed : hint_range(
	0.0,
	20.0
) = 7.0;

uniform float roughness : hint_range(
	0.0,
	1.0
) = 0.72;

uniform float specular_level : hint_range(
	0.0,
	1.0
) = 0.28;

varying vec4 fish_vertex_color;
varying float fish_palette_factor;


void vertex() {
	fish_vertex_color = COLOR;
	fish_palette_factor = clamp(
		INSTANCE_CUSTOM.g,
		0.0,
		1.0
	);

	float animation_phase = (
		INSTANCE_CUSTOM.r * TWO_PI
	);

	float tail_weight = clamp(
		COLOR.a,
		0.0,
		1.0
	);

	float movement = sin(
		TIME * tail_speed
		+ animation_phase
		- VERTEX.z * 7.0
	);

	VERTEX.x += (
		movement
		* tail_amplitude
		* tail_weight
		* max(INSTANCE_CUSTOM.b, 0.25)
	);
}


void fragment() {
	vec3 palette_color = mix(
		cold_color.rgb,
		warm_color.rgb,
		fish_palette_factor
	);

	vec3 base_color = (
		palette_color
		* fish_vertex_color.rgb
	);

	ALBEDO = base_color;
	ROUGHNESS = roughness;
	SPECULAR = specular_level;
}