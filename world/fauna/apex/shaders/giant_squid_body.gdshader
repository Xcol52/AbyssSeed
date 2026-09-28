shader_type spatial;

render_mode cull_disabled,
	diffuse_burley,
	specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(
	0.78,
	0.76,
	0.78,
	1.0
);

uniform vec4 shadow_color : source_color = vec4(
	0.45,
	0.47,
	0.52,
	1.0
);

uniform vec4 scar_color : source_color = vec4(
	0.28,
	0.14,
	0.18,
	1.0
);

uniform float variation_strength : hint_range(
	0.0,
	0.5
) = 0.16;

uniform float scar_strength : hint_range(
	0.0,
	0.3
) = 0.07;

uniform float roughness : hint_range(
	0.0,
	1.0
) = 0.78;

uniform float specular_level : hint_range(
	0.0,
	1.0
) = 0.18;

varying vec3 body_local_position;


void vertex() {
	body_local_position = VERTEX;
}


void fragment() {
	vec3 local_position = body_local_position;

	/*
	 * Broad deterministic variation breaks up the uniformly white
	 * appearance without requiring a texture asset.
	 */
	float broad_variation = (
		0.5
		+ 0.5
			* sin(
				local_position.z * 0.31
				+ local_position.x * 0.47
			)
			* sin(
				local_position.y * 0.83
				- local_position.z * 0.17
			)
	);

	/*
	 * Slightly darken the lower portion of the mantle. Lighting still
	 * supplies most of the form; this only prevents a flat white read.
	 */
	float underside = (
		1.0
		- smoothstep(
			-2.0,
			2.5,
			local_position.y
		)
	);

	float gray_amount = clamp(
		variation_strength
			* (0.30 + broad_variation * 0.70)
			+ underside * 0.06,
		0.0,
		0.32
	);

	vec3 color = mix(
		base_color.rgb,
		shadow_color.rgb,
		gray_amount
	);

	/*
	 * Two faint, irregular marks on the lateral mantle. They are
	 * intentionally restricted to the sides and should not read as a
	 * major texture feature.
	 */
	float side_mask = smoothstep(
		2.5,
		4.8,
		abs(local_position.x)
	);

	float length_mask = (
		smoothstep(
			-6.5,
			-4.0,
			local_position.z
		)
		* (
			1.0
			- smoothstep(
				4.0,
				6.5,
				local_position.z
			)
		)
	);

	float scar_curve_a = abs(
		local_position.y
		- (
			-0.95
			+ sin(local_position.z * 0.62) * 0.30
		)
	);

	float scar_curve_b = abs(
		local_position.y
		- (
			1.25
			+ sin(
				local_position.z * 0.43
				+ 1.8
			) * 0.22
		)
	);

	float scar_a = (
		1.0
		- smoothstep(
			0.04,
			0.14,
			scar_curve_a
		)
	);

	float scar_b = (
		1.0
		- smoothstep(
			0.03,
			0.11,
			scar_curve_b
		)
	);

	float scar_mask = (
		max(
			scar_a,
			scar_b * 0.65
		)
		* side_mask
		* length_mask
	);

	color = mix(
		color,
		scar_color.rgb,
		scar_mask * scar_strength
	);

	ALBEDO = clamp(
		color,
		vec3(0.0),
		vec3(1.0)
	);

	ROUGHNESS = roughness;
	SPECULAR = specular_level;
}
