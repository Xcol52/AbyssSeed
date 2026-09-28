shader_type spatial;

render_mode blend_mix,
	depth_draw_opaque,
	cull_disabled,
	diffuse_burley,
	specular_schlick_ggx;

const float OCEAN_TAU = 6.28318530718;
const float DEPTH_EPSILON = 0.000001;

uniform sampler2D depth_texture :
	hint_depth_texture,
	repeat_disable,
	filter_nearest;

uniform float camera_near = 0.05;
uniform float camera_far = 900.0;

/*
 * The default wavelengths account for the current 2048-meter,
 * 128-cell ocean grid. They remain large enough for the existing
 * vertex spacing while still producing overlapping low-poly chop.
 */
uniform vec2 wave_direction_a = vec2(0.82, 0.57);
uniform float wave_length_a : hint_range(
	16.0,
	512.0
) = 112.0;
uniform float wave_amplitude_a : hint_range(
	0.0,
	5.0
) = 0.72;
uniform float wave_speed_a : hint_range(
	0.0,
	4.0
) = 0.42;
uniform float wave_steepness_a : hint_range(
	0.0,
	1.0
) = 0.58;
uniform float wave_phase_a = 0.0;

uniform vec2 wave_direction_b = vec2(-0.36, 0.93);
uniform float wave_length_b : hint_range(
	16.0,
	512.0
) = 64.0;
uniform float wave_amplitude_b : hint_range(
	0.0,
	5.0
) = 0.38;
uniform float wave_speed_b : hint_range(
	0.0,
	4.0
) = 0.68;
uniform float wave_steepness_b : hint_range(
	0.0,
	1.0
) = 0.46;
uniform float wave_phase_b = 1.73;

uniform vec2 wave_direction_c = vec2(0.94, -0.34);
uniform float wave_length_c : hint_range(
	16.0,
	512.0
) = 40.0;
uniform float wave_amplitude_c : hint_range(
	0.0,
	5.0
) = 0.16;
uniform float wave_speed_c : hint_range(
	0.0,
	4.0
) = 1.05;
uniform float wave_steepness_c : hint_range(
	0.0,
	1.0
) = 0.32;
uniform float wave_phase_c = 3.91;

uniform float shallow_threshold : hint_range(
	0.0,
	100.0
) = 20.0;

uniform float maximum_extinction_depth : hint_range(
	1.0,
	1000.0
) = 350.0;

uniform vec4 shallow_color : source_color = vec4(
	0.02,
	0.32,
	0.78,
	0.12
);

uniform vec4 deep_color : source_color = vec4(
	0.006,
	0.045,
	0.16,
	0.42
);

uniform vec4 foam_color : source_color = vec4(
	0.64,
	0.94,
	0.88,
	0.94
);

uniform float foam_depth : hint_range(
	0.1,
	20.0
) = 3.0;

uniform float foam_scale : hint_range(
	0.01,
	2.0
) = 0.18;

uniform float foam_speed : hint_range(
	0.0,
	4.0
) = 0.32;

uniform float fresnel_power : hint_range(
	1.0,
	10.0
) = 4.5;

uniform float grazing_alpha : hint_range(
	0.0,
	1.0
) = 0.97;

uniform float downward_roughness : hint_range(
	0.0,
	1.0
) = 0.06;

uniform float grazing_roughness : hint_range(
	0.0,
	1.0
) = 0.22;

varying vec3 ocean_world_position;


/*
 * Returns:
 *
 * X: horizontal world-X displacement
 * Y: vertical displacement
 * Z: horizontal world-Z displacement
 * W: vertical-height derivative magnitude
 *
 * The caller multiplies W by the normalized direction to recover the
 * two-dimensional height slope used for the approximate surface normal.
 */
vec4 sample_gerstner_wave(
	vec2 world_xz,
	vec2 direction,
	float wave_length,
	float amplitude,
	float angular_speed,
	float steepness,
	float phase_offset
) {
	vec2 safe_direction = direction;

	if (length(safe_direction) < DEPTH_EPSILON) {
		safe_direction = vec2(1.0, 0.0);
	}

	safe_direction = normalize(safe_direction);

	float safe_wave_length = max(
		wave_length,
		DEPTH_EPSILON
	);

	float wave_number = OCEAN_TAU / safe_wave_length;

	float phase = (
		wave_number
		* dot(safe_direction, world_xz)
		+ TIME * angular_speed
		+ phase_offset
	);

	float sine_phase = sin(phase);
	float cosine_phase = cos(phase);

	float horizontal_amplitude = (
		amplitude
		* clamp(steepness, 0.0, 1.0)
	);

	vec2 horizontal_displacement = (
		safe_direction
		* horizontal_amplitude
		* cosine_phase
	);

	float height_slope = (
		amplitude
		* wave_number
		* cosine_phase
	);

	return vec4(
		horizontal_displacement.x,
		amplitude * sine_phase,
		horizontal_displacement.y,
		height_slope
	);
}


float linear_view_depth(
	float raw_depth
) {
	float safe_near = max(
		camera_near,
		DEPTH_EPSILON
	);
	float safe_far = max(
		camera_far,
		safe_near + DEPTH_EPSILON
	);
	float safe_raw_depth = clamp(
		raw_depth,
		0.0,
		1.0
	);
	float denominator = (
		safe_raw_depth
		* (safe_far - safe_near)
		+ safe_near
	);
	float safe_denominator = max(
		denominator,
		DEPTH_EPSILON
	);

	return (
		safe_near * safe_far
		/ safe_denominator
	);
}


void vertex() {
	/*
	 * This is the critical recentering contract. Wave phase is sampled
	 * from the vertex's absolute world-space position before wave
	 * displacement, never from VERTEX.xz alone.
	 */
	vec3 base_world_position = (
		MODEL_MATRIX
		* vec4(VERTEX, 1.0)
	).xyz;

	vec2 world_xz = base_world_position.xz;

	vec2 direction_a = normalize(wave_direction_a);
	vec2 direction_b = normalize(wave_direction_b);
	vec2 direction_c = normalize(wave_direction_c);

	vec4 wave_a = sample_gerstner_wave(
		world_xz,
		direction_a,
		wave_length_a,
		wave_amplitude_a,
		wave_speed_a,
		wave_steepness_a,
		wave_phase_a
	);

	vec4 wave_b = sample_gerstner_wave(
		world_xz,
		direction_b,
		wave_length_b,
		wave_amplitude_b,
		wave_speed_b,
		wave_steepness_b,
		wave_phase_b
	);

	vec4 wave_c = sample_gerstner_wave(
		world_xz,
		direction_c,
		wave_length_c,
		wave_amplitude_c,
		wave_speed_c,
		wave_steepness_c,
		wave_phase_c
	);

	vec3 displacement = (
		wave_a.xyz
		+ wave_b.xyz
		+ wave_c.xyz
	);

	vec2 height_slope = (
		direction_a * wave_a.w
		+ direction_b * wave_b.w
		+ direction_c * wave_c.w
	);

	VERTEX += displacement;

	/*
	 * This analytic height normal is intentionally inexpensive. It
	 * captures the visible wave slope without requiring texture-based
	 * normal maps or CPU mesh updates.
	 */
	NORMAL = normalize(
		vec3(
			-height_slope.x,
			1.0,
			-height_slope.y
		)
	);

	ocean_world_position = (
		MODEL_MATRIX
		* vec4(VERTEX, 1.0)
	).xyz;
}


void fragment() {
	float raw_scene_depth = textureLod(
		depth_texture,
		SCREEN_UV,
		0.0
	).r;

	float scene_view_depth = linear_view_depth(
		raw_scene_depth
	);

	float water_view_depth = linear_view_depth(
		FRAGCOORD.z
	);

	float water_column_depth = max(
		scene_view_depth - water_view_depth,
		0.0
	);

	float safe_extinction_depth = max(
		maximum_extinction_depth,
		shallow_threshold + DEPTH_EPSILON
	);

	float extinction_factor = smoothstep(
		shallow_threshold,
		safe_extinction_depth,
		water_column_depth
	);

	vec3 water_color = mix(
		shallow_color.rgb,
		deep_color.rgb,
		extinction_factor
	);

	/*
	 * Intersection foam is restricted to geometry immediately below
	 * the water surface. Two world-space sine fields break up the edge
	 * without requiring a texture asset.
	 */
	float foam_intersection = (
		1.0
		- smoothstep(
			0.05,
			max(foam_depth, 0.051),
			water_column_depth
		)
	);

	float foam_pattern_a = sin(
		(
			ocean_world_position.x
			+ ocean_world_position.z * 0.63
		) * foam_scale
		+ TIME * foam_speed
	);

	float foam_pattern_b = sin(
		(
			ocean_world_position.z
			- ocean_world_position.x * 0.41
		) * foam_scale * 1.73
		- TIME * foam_speed * 0.71
		+ 1.27
	);

	float foam_pattern = smoothstep(
		-0.35,
		0.62,
		foam_pattern_a * foam_pattern_b
	);

	float foam_amount = clamp(
		foam_intersection
		* (0.58 + foam_pattern * 0.42),
		0.0,
		1.0
	);

	vec3 normal_direction = normalize(NORMAL);
	vec3 view_direction = normalize(VIEW);

	/*
	 * Deliberately do not use abs(dot(...)).
	 *
	 * From above, a perpendicular view produces alignment near one and
	 * remains transparent. At grazing angles alignment approaches zero.
	 * From underneath, alignment is negative and clamps to zero, making
	 * the underside opaque rather than exposing the sky background.
	 */
	float view_alignment = clamp(
		dot(normal_direction, view_direction),
		0.0,
		1.0
	);

	float fresnel = pow(
		1.0 - view_alignment,
		max(fresnel_power, 1.0)
	);

	float depth_alpha = mix(
		shallow_color.a,
		deep_color.a,
		extinction_factor
	);

	float surface_alpha = mix(
		depth_alpha,
		grazing_alpha,
		fresnel
	);

	surface_alpha = max(
		surface_alpha,
		foam_amount * foam_color.a
	);

	ALBEDO = mix(
		water_color,
		foam_color.rgb,
		foam_amount
	);

	ROUGHNESS = mix(
		mix(
			downward_roughness,
			grazing_roughness,
			fresnel
		),
		0.68,
		foam_amount
	);

	METALLIC = 0.0;
	SPECULAR = 0.90;

	EMISSION = (
		foam_color.rgb
		* foam_amount
		* 0.24
	);

	ALPHA = clamp(
		surface_alpha,
		0.0,
		1.0
	);
}
