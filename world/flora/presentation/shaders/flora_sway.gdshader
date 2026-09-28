shader_type spatial;

render_mode cull_disabled,
	diffuse_burley,
	specular_schlick_ggx;

const float TWO_PI = 6.28318530718;

uniform vec4 albedo_tint : source_color = vec4(
	1.0,
	1.0,
	1.0,
	1.0
);

uniform float roughness : hint_range(
	0.0,
	1.0
) = 0.85;

uniform float specular_level : hint_range(
	0.0,
	1.0
) = 0.24;

uniform float emission_strength : hint_range(
	0.0,
	0.2
) = 0.018;

uniform vec2 current_direction = vec2(
	1.0,
	0.25
);

uniform float sway_strength : hint_range(
	0.0,
	1.0
) = 0.2;

uniform float sway_speed : hint_range(
	0.0,
	4.0
) = 0.8;

uniform float sway_spatial_frequency : hint_range(
	0.0,
	2.0
) = 0.35;

uniform float secondary_wave_strength : hint_range(
	0.0,
	1.0
) = 0.30;

uniform float model_height : hint_range(
	0.01,
	20.0
) = 1.0;

uniform float bend_start : hint_range(
	0.0,
	5.0
) = 0.05;

uniform float sway_enabled : hint_range(
	0.0,
	1.0
) = 1.0;

uniform float instance_phase_scale : hint_range(
	0.0,
	4.0
) = 1.0;

/*
 * Temperature-color controls.
 *
 * Giant-kelp materials enable temperature_color_strength.
 * Other species leave it at zero and retain their original colors.
 */
uniform vec4 cold_temperature_color : source_color = vec4(
	0.025,
	0.14,
	0.27,
	1.0
);

uniform vec4 warm_temperature_color : source_color = vec4(
	0.72,
	1.00,
	0.10,
	1.0
);

uniform float temperature_color_strength : hint_range(
	0.0,
	1.0
) = 0.0;

varying vec4 flora_vertex_color;
varying float instance_temperature_factor;
varying float instance_depth_factor;


void vertex() {
	flora_vertex_color = COLOR;

	/*
	 * INSTANCE_CUSTOM channel contract:
	 *
	 * R: deterministic sway phase
	 * G: normalized environmental temperature for giant kelp
	 * B: normalized kelp depth growth factor
	 * A: placement probability
	 *
	 * Non-kelp materials use a temperature strength of zero, so their
	 * G channel does not affect their appearance.
	 */
	instance_temperature_factor = clamp(
		INSTANCE_CUSTOM.g,
		0.0,
		1.0
	);

	instance_depth_factor = clamp(
		INSTANCE_CUSTOM.b,
		0.0,
		1.0
	);

	float usable_height = max(
		model_height - bend_start,
		0.001
	);

	float height_ratio = clamp(
		(VERTEX.y - bend_start)
			/ usable_height,
		0.0,
		1.0
	);

	/*
	 * Smoothly fixes the base while allowing progressively greater
	 * displacement toward the upper parts of the model.
	 */
	float bend_weight = (
		height_ratio
		* height_ratio
		* (3.0 - 2.0 * height_ratio)
	);

	bend_weight *= bend_weight;

	vec2 current = current_direction;

	if (length(current) < 0.0001) {
		current = vec2(1.0, 0.0);
	}

	current = normalize(current);

	vec2 perpendicular = vec2(
		-current.y,
		current.x
	);

	vec3 world_origin = (
		MODEL_MATRIX
		* vec4(0.0, 0.0, 0.0, 1.0)
	).xyz;

	float spatial_phase = dot(
		world_origin.xz,
		vec2(0.071, 0.113)
	) * sway_spatial_frequency;

	float instance_phase = (
		INSTANCE_CUSTOM.x
		* TWO_PI
		* instance_phase_scale
	);

	float base_phase = (
		TIME * sway_speed
		+ spatial_phase
		+ instance_phase
	);

	/*
	 * Height-dependent phase offsets stop the whole plant from moving
	 * like one rigid lever. Different vertical sections bend at
	 * different points in the wave.
	 */
	float height_phase = (
		height_ratio * 2.35
		+ VERTEX.y * 0.09
	);

	float local_phase = dot(
		VERTEX.xz,
		vec2(1.37, -1.83)
	);

	float primary_wave = sin(
		base_phase - height_phase
	);

	float secondary_wave = sin(
		base_phase * 1.61
		+ height_phase * 1.48
		+ local_phase * 0.32
		+ 0.91
	);

	float detail_wave = sin(
		base_phase * 2.37
		- height_phase * 2.12
		+ local_phase * 0.76
		- 0.37
	);

	float cross_wave = sin(
		base_phase * 0.79
		+ height_phase * 0.72
		+ local_phase * 0.23
	);

	float slow_modulation = (
		0.84
		+ 0.16 * sin(
			base_phase * 0.31
			+ instance_phase
			+ 1.24
		)
	);

	float directional_wave = (
		primary_wave * 0.68
		+ secondary_wave
			* secondary_wave_strength
			* 0.72
		+ detail_wave
			* secondary_wave_strength
			* 0.24
	);

	float perpendicular_wave = (
		cross_wave
		* secondary_wave_strength
		* 0.28
	);

	float active_strength = (
		sway_strength
		* sway_enabled
		* bend_weight
		* slow_modulation
	);

	vec2 displacement = (
		current * directional_wave
		+ perpendicular * perpendicular_wave
	) * active_strength;

	VERTEX.x += displacement.x;
	VERTEX.z += displacement.y;
}


void fragment() {
	NORMAL = faceforward(
		normalize(NORMAL),
		-VIEW,
		normalize(NORMAL)
	);

	vec3 base_color = (
		flora_vertex_color.rgb
		* albedo_tint.rgb
	);

	/*
	 * Depth factor zero:
	 * dark green deep kelp.
	 *
	 * Depth factor one:
	 * bright green-yellow shallow kelp.
	 */
	vec3 temperature_color = mix(
		cold_temperature_color.rgb,
		warm_temperature_color.rgb,
		clamp(
			instance_depth_factor,
			0.0,
			1.0
		)
	);

	/*
	 * Preserve some of the procedural stalk/blade shading after the
	 * temperature color is applied. Otherwise every part of a kelp
	 * instance would become a completely flat color.
	 */
	float vertex_brightness = max(
		dot(
			flora_vertex_color.rgb,
			vec3(
				0.2126,
				0.7152,
				0.0722
			)
		),
		0.04
	);

	float preserved_shading = clamp(
		vertex_brightness / 0.30,
		0.45,
		1.35
	);

	vec3 temperature_tinted_color = (
		temperature_color
		* albedo_tint.rgb
		* preserved_shading
	);

	base_color = mix(
		base_color,
		temperature_tinted_color,
		clamp(
			temperature_color_strength,
			0.0,
			1.0
		)
	);

	base_color = clamp(
		base_color,
		vec3(0.0),
		vec3(1.0)
	);

	ALBEDO = base_color;
	ROUGHNESS = roughness;
	SPECULAR = specular_level;

	float view_alignment = clamp(
		abs(
			dot(
				normalize(NORMAL),
				normalize(VIEW)
			)
		),
		0.0,
		1.0
	);

	float rim = pow(
		1.0 - view_alignment,
		2.0
	);

	EMISSION = (
		base_color
		* emission_strength
		* (0.30 + rim * 0.70)
	);
}