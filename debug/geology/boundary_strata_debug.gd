extends Control

const BACKGROUND_COLOR: Color = Color(
	0.018,
	0.025,
	0.032,
	1.0
)

const GRID_COLOR: Color = Color(
	0.12,
	0.16,
	0.18,
	1.0
)

const RAW_COLOR: Color = Color(
	0.72,
	0.76,
	0.80,
	1.0
)

const WEAK_COLOR: Color = Color(
	0.25,
	0.68,
	0.86,
	1.0
)

const MODERATE_COLOR: Color = Color(
	0.90,
	0.67,
	0.22,
	1.0
)

const FULL_COLOR: Color = Color(
	0.95,
	0.28,
	0.20,
	1.0
)

const TEXT_COLOR: Color = Color(
	0.88,
	0.92,
	0.94,
	1.0
)

const DRAW_MARGIN: float = 64.0
const SAMPLE_COUNT: int = 512

const MINIMUM_ELEVATION: float = -240.0
const MAXIMUM_ELEVATION: float = -15.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	draw_rect(
		Rect2(Vector2.ZERO, size),
		BACKGROUND_COLOR,
		true
	)

	var graph_rect: Rect2 = Rect2(
		Vector2(
			DRAW_MARGIN,
			DRAW_MARGIN
		),
		Vector2(
			maxf(
				size.x - DRAW_MARGIN * 2.0,
				1.0
			),
			maxf(
				size.y - DRAW_MARGIN * 2.0,
				1.0
			)
		)
	)

	_draw_grid(graph_rect)

	_draw_profile(
		graph_rect,
		0.0,
		0.0,
		RAW_COLOR
	)

	_draw_profile(
		graph_rect,
		1.0,
		0.20,
		WEAK_COLOR
	)

	_draw_profile(
		graph_rect,
		1.0,
		0.55,
		MODERATE_COLOR
	)

	_draw_profile(
		graph_rect,
		1.0,
		1.0,
		FULL_COLOR
	)

	_draw_legend()


func _draw_grid(
	graph_rect: Rect2
) -> void:
	var terrace_height: float = (
		GeologySampler.BOUNDARY_STRATA_TERRACE_HEIGHT
	)

	var elevation: float = (
		floor(
			MINIMUM_ELEVATION
				/ terrace_height
		) * terrace_height
	)

	while elevation <= MAXIMUM_ELEVATION:
		var normalized_height: float = inverse_lerp(
			MINIMUM_ELEVATION,
			MAXIMUM_ELEVATION,
			elevation
		)

		var draw_y: float = (
			graph_rect.end.y
				- normalized_height
					* graph_rect.size.y
		)

		draw_line(
			Vector2(
				graph_rect.position.x,
				draw_y
			),
			Vector2(
				graph_rect.end.x,
				draw_y
			),
			GRID_COLOR,
			1.0
		)

		elevation += terrace_height

	draw_rect(
		graph_rect,
		GRID_COLOR,
		false,
		2.0
	)


func _draw_profile(
	graph_rect: Rect2,
	boundary_proximity: float,
	tectonic_activity: float,
	line_color: Color
) -> void:
	var previous_point: Vector2 = Vector2.ZERO
	var has_previous_point: bool = false

	for sample_index in range(SAMPLE_COUNT):
		var normalized_x: float = (
			float(sample_index)
				/ float(SAMPLE_COUNT - 1)
		)

		var raw_elevation: float = lerpf(
			MINIMUM_ELEVATION,
			MAXIMUM_ELEVATION,
			normalized_x
		)

		var displayed_elevation: float = raw_elevation

		if boundary_proximity > 0.0:
			displayed_elevation = (
				GeologySampler._apply_boundary_strata(
					raw_elevation,
					boundary_proximity,
					tectonic_activity,
					Vector2(
						normalized_x * 1000.0,
						0.0
					)
				)
			)

		var normalized_y: float = inverse_lerp(
			MINIMUM_ELEVATION,
			MAXIMUM_ELEVATION,
			displayed_elevation
		)

		var current_point: Vector2 = Vector2(
			graph_rect.position.x
				+ normalized_x
					* graph_rect.size.x,
			graph_rect.end.y
				- normalized_y
					* graph_rect.size.y
		)

		if has_previous_point:
			draw_line(
				previous_point,
				current_point,
				line_color,
				2.0,
				true
			)

		previous_point = current_point
		has_previous_point = true


func _draw_legend() -> void:
	var display_font: Font = ThemeDB.fallback_font
	var text_position: Vector2 = Vector2(
		DRAW_MARGIN,
		28.0
	)

	draw_string(
		display_font,
		text_position,
		"Boundary Strata Debug",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		20,
		TEXT_COLOR
	)

	var legend_y: float = size.y - 24.0

	_draw_legend_item(
		Vector2(DRAW_MARGIN, legend_y),
		RAW_COLOR,
		"Raw elevation"
	)

	_draw_legend_item(
		Vector2(DRAW_MARGIN + 170.0, legend_y),
		WEAK_COLOR,
		"Weak activity"
	)

	_draw_legend_item(
		Vector2(DRAW_MARGIN + 335.0, legend_y),
		MODERATE_COLOR,
		"Moderate activity"
	)

	_draw_legend_item(
		Vector2(DRAW_MARGIN + 535.0, legend_y),
		FULL_COLOR,
		"Full activity"
	)


func _draw_legend_item(
	draw_position: Vector2,
	line_color: Color,
	label_text: String
) -> void:
	var display_font: Font = ThemeDB.fallback_font

	draw_line(
		draw_position,
		draw_position + Vector2(24.0, 0.0),
		line_color,
		3.0
	)

	draw_string(
		display_font,
		draw_position + Vector2(32.0, 5.0),
		label_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		14,
		TEXT_COLOR
	)
