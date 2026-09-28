class_name GeologyDebugPalette
extends RefCounted


static func get_color(
	data: GeologyChunkData,
	index: int,
	mode: int
) -> Color:
	match mode:
		GeologyDebugMode.PLATE_ID:
			return _plate_color(
				data.primary_plate_ids[index]
			)

		GeologyDebugMode.CONTINENTAL_AFFINITY:
			return Color(0.01, 0.06, 0.18).lerp(
				Color(0.55, 0.70, 0.38),
				data.continental_affinity[index]
			)

		GeologyDebugMode.BOUNDARY_PROXIMITY:
			return _scalar_color(
				data.boundary_proximity[index],
				Color.WHITE
			)

		GeologyDebugMode.COMPRESSION:
			return _scalar_color(
				data.compression_strength[index],
				Color(1.0, 0.12, 0.05)
			)

		GeologyDebugMode.EXTENSION:
			return _scalar_color(
				data.extension_strength[index],
				Color(0.05, 0.85, 1.0)
			)

		GeologyDebugMode.SHEAR:
			return _scalar_color(
				data.shear_strength[index],
				Color(0.85, 0.15, 1.0)
			)

		GeologyDebugMode.RIDGE_POTENTIAL:
			return _scalar_color(
				data.ridge_potential[index],
				Color(1.0, 0.75, 0.08)
			)

		GeologyDebugMode.TRENCH_POTENTIAL:
			return _scalar_color(
				data.trench_potential[index],
				Color(0.30, 0.02, 0.65)
			)

		GeologyDebugMode.VOLCANIC_POTENTIAL:
			return _scalar_color(
				data.volcanic_potential[index],
				Color(1.0, 0.30, 0.02)
			)

		GeologyDebugMode.SEDIMENT_POTENTIAL:
			return _scalar_color(
				data.sediment_potential[index],
				Color(0.72, 0.65, 0.38)
			)

		GeologyDebugMode.MACRO_ELEVATION:
			var elevation_factor := clampf(
				inverse_lerp(
					-450.0,
					-10.0,
					data.macro_elevation[index]
				),
				0.0,
				1.0
			)

			return Color(0.005, 0.01, 0.08).lerp(
				Color(0.20, 0.75, 0.60),
				elevation_factor
			)

	return Color.MAGENTA


static func _scalar_color(
	value: float,
	target: Color
) -> Color:
	return Color(0.005, 0.008, 0.012).lerp(
		target,
		clampf(value, 0.0, 1.0)
	)


static func _plate_color(plate_id: int) -> Color:
	var mixed := StableSeed.derive_channel_seed(
		plate_id,
		1901
	)

	var hue_bits: int = mixed & 0xFFFF
	var hue := float(hue_bits) / 65535.0

	return Color.from_hsv(hue, 0.72, 0.90)
