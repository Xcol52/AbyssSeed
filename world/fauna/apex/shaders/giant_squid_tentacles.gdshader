shader_type spatial;

render_mode cull_disabled,
	diffuse_burley,
	specular_schlick_ggx;

const float TWO_PI = 6.28318530718;

uniform vec4 base_color : source_color = vec4(
	0.78,
	0.75,
	0.77,
	1.0
);

uniform vec4 tip_color : source_color = vec4(
	0.47,
	0.43,
	0.49,
	1.0
);

uniform float movement_amplitude : hint_range(
	0.0,
	5.0
) = 1.35;

uniform float movement_speed : hint_range(
	0.0,
	4.0
) = 0.28;

/*
 * Overall movement magnitude selected by the current behavior state.
 */
uniform float activity : hint_range(
	0.0,
	2.0
) = 0.24;

/*
 * Zero allows loose independent phases.
 * One makes the tentacles move more deliberately as a group.
 */
uniform float coordination : hint_range(
	0.0,
	1.0
) = 0.18;

/*
 * Controls slower radial curling, especially in the distal region.
 */
uniform float curl_strength : hint_range(
	0.0,
	1.5
) = 0.30;

/*
 * Adds a subtle longitudinal pull during forceful movement.
 */
uniform float contraction : hint_range(
	0.0,
	1.0
) = 0.12;

uniform float color_variation : hint_range(
	0.0,
	0.4
) = 0.12;

varying float tentacle_length_factor;
varying float tentacle_identifier;
varying vec3 tentacle_local_position;


void vertex() {
	/*
	 * Existing vertex-color contract:
	 *
	 * R: deterministic tentacle phase
	 * G: normalized distance from tentacle base
	 * B: normalized tentacle index
	 * A: reserved
	 */
	float individual_phase = COLOR.r * TWO_PI;

	tentacle_length_factor = clamp(
		COLOR.g,
		0.0,
		1.0
	);

	tentacle_identifier = clamp(
		COLOR.b,
		0.0,
		1.0
	);

	tentacle_local_position = VERTEX;

	float length_factor = tentacle_length_factor;

	/*
	 * Smooth base lock. The base remains stable while motion grows
	 * progressively toward the distal end.
	 */
	float base_lock = smoothstep(
		0.03,
		0.22,
		length_factor
	);

	base_lock *= base_lock;

	/*
	 * Alert states reduce the phase difference between tentacles.
	 * A small residual offset remains so the result never becomes a
	 * perfectly synchronized mechanical fan.
	 */
	float coordinated_phase = (
		tentacle_identifier
		* TWO_PI
		* 0.12
	);

	float phase = mix(
		individual_phase,
		coordinated_phase,
		coordination
	);

	float time_value = TIME * movement_speed;

	/*
	 * These are three overlapping animation zones, not rigid geometry
	 * segments. Their overlap creates continuous curvature without
	 * hinges or separate tentacle Nodes.
	 */
	float proximal_weight = (
		smoothstep(
			0.04,
			0.20,
			length_factor
		)
		* (
			1.0
			- smoothstep(
				0.52,
				0.72,
				length_factor
			)
		)
	);

	float middle_weight = (
		smoothstep(
			0.18,
			0.42,
			length_factor
		)
		* (
			1.0
			- smoothstep(
				0.76,
				0.96,
				length_factor
			)
		)
	);

	float distal_weight = smoothstep(
		0.54,
		0.94,
		length_factor
	);

	float proximal_wave = sin(
		time_value * 0.68
		+ phase * 0.34
		- length_factor * 2.10
	);

	float middle_wave = sin(
		time_value * 1.03
		+ phase * 0.70
		- length_factor * 4.55
		+ 0.72
	);

	float distal_wave = sin(
		time_value * 1.34
		+ phase
		- length_factor * 7.60
		- 0.38
	);

	float weight_sum = max(
		proximal_weight
			+ middle_weight
			+ distal_weight,
		0.001
	);

	float section_wave = (
		proximal_wave
			* proximal_weight
			* 0.52
		+ middle_wave
			* middle_weight
			* 0.82
		+ distal_wave
			* distal_weight
	) / weight_sum;

	/*
	 * Passive tentacles retain more independent tip movement. As
	 * coordination rises, this secondary flutter becomes restrained.
	 */
	float independent_detail = sin(
		time_value * 1.67
		+ individual_phase * 2.31
		- length_factor * 10.2
	);

	independent_detail *= (
		distal_weight
		* (
			0.18
			+ (1.0 - coordination) * 0.42
		)
	);

	/*
	 * A shared low-frequency surge makes alert and aggressive movement
	 * read as intentional rather than merely faster.
	 */
	float coordinated_surge = sin(
		time_value * 0.54
		- length_factor * 3.15
		+ 0.65
	);

	coordinated_surge *= (
		coordination
		* middle_weight
		* 0.48
	);

	float radial_angle = (
		tentacle_identifier * TWO_PI
	);

	vec2 radial_axis = vec2(
		cos(radial_angle),
		sin(radial_angle)
	);

	vec2 lateral_axis = vec2(
		-radial_axis.y,
		radial_axis.x
	);

	float lateral_displacement = (
		section_wave
		+ independent_detail
		+ coordinated_surge
	);

	float curl_wave = sin(
		time_value * 0.61
		+ individual_phase * 0.47
		+ length_factor * 5.20
	);

	float radial_displacement = (
		curl_wave
		* curl_strength
		* (
			middle_weight * 0.28
			+ distal_weight * 0.72
		)
	);

	float active_amplitude = (
		movement_amplitude
		* activity
		* base_lock
	);

	vec2 displacement = (
		lateral_axis * lateral_displacement
		+ radial_axis * radial_displacement
	) * active_amplitude;

	VERTEX.x += displacement.x;
	VERTEX.y += displacement.y;

	/*
	 * Very small axial movement gives forceful states a pulling and
	 * gathering quality. This does not alter the authoritative scale.
	 */
	float axial_wave = sin(
		time_value * 0.77
		+ phase * 0.55
		- length_factor * 4.0
	);

	VERTEX.z += (
		axial_wave
		* contraction
		* activity
		* base_lock
		* length_factor
		* movement_amplitude
		* 0.20
	);
}


void fragment() {
	vec3 color = mix(
		base_color.rgb,
		tip_color.rgb,
		tentacle_length_factor
	);

	float mottle = (
		0.5
		+ 0.5
			* sin(
				tentacle_local_position.z * 0.43
				+ tentacle_identifier * 11.7
			)
			* sin(
				tentacle_local_position.x * 0.71
				- tentacle_local_position.y * 0.39
			)
	);

	vec3 gray_tone = color * vec3(
		0.76,
		0.78,
		0.84
	);

	color = mix(
		color,
		gray_tone,
		mottle * color_variation
	);

	ALBEDO = clamp(
		color,
		vec3(0.0),
		vec3(1.0)
	);

	ROUGHNESS = 0.82;
	SPECULAR = 0.16;
}
