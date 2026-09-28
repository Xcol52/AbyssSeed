class_name DebugDepthGauge
extends Control

const UPDATE_INTERVAL_SECONDS: float = 0.2

const PANEL_SIZE: Vector2 = Vector2(
	320.0,
	210.0
)

const PANEL_MARGIN: float = 16.0

const GAUGE_X: float = 25.0
const GAUGE_TOP: float = 37.0
const GAUGE_BOTTOM: float = 181.0

const TITLE_COLOR: Color = Color(
	0.78,
	0.95,
	1.0,
	1.0
)

const TEXT_COLOR: Color = Color(
	0.90,
	0.94,
	0.96,
	1.0
)

const MUTED_COLOR: Color = Color(
	0.58,
	0.66,
	0.70,
	1.0
)

const SEA_COLOR: Color = Color(
	0.18,
	0.76,
	1.0,
	1.0
)

const OBSERVER_COLOR: Color = Color(
	1.0,
	0.78,
	0.20,
	1.0
)

const SEAFLOOR_COLOR: Color = Color(
	0.30,
	0.88,
	0.56,
	1.0
)

const WARNING_COLOR: Color = Color(
	1.0,
	0.30,
	0.24,
	1.0
)

const CAUTION_COLOR: Color = Color(
	1.0,
	0.72,
	0.22,
	1.0
)


var _world: OceanWorld
var _observer: Node3D

var _update_timer: Timer
var _monitoring_enabled: bool = true

var _observer_position: Vector3 = Vector3.ZERO
var _sea_level_meters: float = 0.0
var _surface_result: TerrainSurfaceQueryResult


func configure(
	world: OceanWorld,
	observer: Node3D
) -> void:
	_world = world
	_observer = observer

	if is_node_ready():
		_refresh_reading()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	anchor_left = 1.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 0.0

	offset_left = (
		-PANEL_SIZE.x
		- PANEL_MARGIN
	)

	offset_top = PANEL_MARGIN
	offset_right = -PANEL_MARGIN

	offset_bottom = (
		PANEL_MARGIN
		+ PANEL_SIZE.y
	)

	_update_timer = Timer.new()
	_update_timer.name = "DepthGaugeUpdateTimer"
	_update_timer.wait_time = UPDATE_INTERVAL_SECONDS
	_update_timer.one_shot = false

	_update_timer.timeout.connect(
		_refresh_reading
	)

	add_child(_update_timer)

	if _monitoring_enabled:
		_update_timer.start()
		_refresh_reading()


func set_monitoring_enabled(
	enabled: bool
) -> void:
	_monitoring_enabled = enabled
	visible = enabled

	if not is_node_ready():
		return

	if enabled:
		_update_timer.start()
		_refresh_reading()
	else:
		_update_timer.stop()


func _refresh_reading() -> void:
	if (
		_world == null
		or not is_instance_valid(_world)
		or _observer == null
		or not is_instance_valid(_observer)
	):
		return

	_observer_position = _observer.global_position

	_sea_level_meters = (
		_world.get_sea_level_meters()
	)

	_surface_result = (
		_world.query_active_seafloor(
			_observer_position
		)
	)

	queue_redraw()


func _draw() -> void:
	var panel_rect := Rect2(
		Vector2.ZERO,
		size
	)

	draw_rect(
		panel_rect,
		Color(
			0.015,
			0.026,
			0.034,
			0.90
		),
		true
	)

	draw_rect(
		panel_rect,
		Color(
			0.18,
			0.38,
			0.46,
			0.92
		),
		false,
		1.0
	)

	var font: Font = ThemeDB.fallback_font

	_draw_text(
		font,
		Vector2(12.0, 22.0),
		"DEPTH / SCALE",
		TITLE_COLOR,
		14
	)

	var observer_depth := (
		WorldScaleContract
		.depth_below_sea_level(
			_sea_level_meters,
			_observer_position.y
		)
	)

	var surface_available := (
		_surface_result != null
		and _surface_result.available
	)

	var seafloor_elevation: float = 0.0
	var seafloor_depth: float = 0.0
	var clearance: float = 0.0

	if surface_available:
		seafloor_elevation = (
			_surface_result
			.surface_elevation_meters
		)

		seafloor_depth = (
			WorldScaleContract
			.depth_below_sea_level(
				_sea_level_meters,
				seafloor_elevation
			)
		)

		clearance = (
			WorldScaleContract
			.bottom_clearance(
				_observer_position.y,
				seafloor_elevation
			)
		)

	var required_depth := maxf(
		0.0,
		observer_depth
	)

	if surface_available:
		required_depth = maxf(
			required_depth,
			maxf(
				0.0,
				seafloor_depth
			)
		)

	var depth_limit := (
		WorldScaleContract
		.get_nice_depth_limit(
			required_depth
		)
	)

	_draw_gauge(
		font,
		observer_depth,
		seafloor_depth,
		depth_limit,
		surface_available
	)

	var text_x: float = 78.0
	var text_y: float = 44.0
	var row_height: float = 22.0

	_draw_text(
		font,
		Vector2(text_x, text_y),
		(
			"Sea level: %s"
			% WorldScaleContract.format_distance(
				_sea_level_meters
			)
		),
		TEXT_COLOR
	)

	text_y += row_height

	_draw_text(
		font,
		Vector2(text_x, text_y),
		(
			"Observer Y: %s"
			% WorldScaleContract.format_distance(
				_observer_position.y
			)
		),
		TEXT_COLOR
	)

	text_y += row_height

	_draw_text(
		font,
		Vector2(text_x, text_y),
		(
			"Observer depth: %s"
			% WorldScaleContract.format_depth(
				observer_depth
			)
		),
		OBSERVER_COLOR
	)

	text_y += row_height

	if surface_available:
		_draw_text(
			font,
			Vector2(text_x, text_y),
			(
				"Seafloor Y: %s"
				% WorldScaleContract.format_distance(
					seafloor_elevation
				)
			),
			TEXT_COLOR
		)
	else:
		_draw_text(
			font,
			Vector2(text_x, text_y),
			"Seafloor Y: loading",
			MUTED_COLOR
		)

	text_y += row_height

	if surface_available:
		_draw_text(
			font,
			Vector2(text_x, text_y),
			(
				"Seafloor depth: %s"
				% WorldScaleContract.format_depth(
					seafloor_depth
				)
			),
			SEAFLOOR_COLOR
		)
	else:
		_draw_text(
			font,
			Vector2(text_x, text_y),
			"Seafloor depth: --",
			MUTED_COLOR
		)

	text_y += row_height

	if surface_available:
		var clearance_color := TEXT_COLOR

		if clearance < 0.0:
			clearance_color = WARNING_COLOR
		elif clearance < 50.0:
			clearance_color = CAUTION_COLOR

		_draw_text(
			font,
			Vector2(text_x, text_y),
			(
				"Bottom clearance: %s"
				% WorldScaleContract.format_distance(
					clearance
				)
			),
			clearance_color
		)
	else:
		_draw_text(
			font,
			Vector2(text_x, text_y),
			"Bottom clearance: --",
			MUTED_COLOR
		)

	text_y += row_height

	var chunk_coordinate := Vector2i.ZERO

	if _surface_result != null:
		chunk_coordinate = (
			_surface_result.chunk_coordinate
		)
	elif (
		_world != null
		and is_instance_valid(_world)
	):
		chunk_coordinate = (
			_world
			.get_chunk_coordinate_for_world_position(
				_observer_position
			)
		)

	_draw_text(
		font,
		Vector2(text_x, text_y),
		(
			"Chunk: (%d, %d)"
			% [
				chunk_coordinate.x,
				chunk_coordinate.y
			]
		),
		TEXT_COLOR
	)


func _draw_gauge(
	font: Font,
	observer_depth: float,
	seafloor_depth: float,
	depth_limit: float,
	surface_available: bool
) -> void:
	draw_line(
		Vector2(GAUGE_X, GAUGE_TOP),
		Vector2(GAUGE_X, GAUGE_BOTTOM),
		Color(
			0.38,
			0.48,
			0.52,
			1.0
		),
		4.0
	)

	for tick_index in range(5):
		var fraction := (
			float(tick_index)
			/ 4.0
		)

		var tick_y := lerpf(
			GAUGE_TOP,
			GAUGE_BOTTOM,
			fraction
		)

		draw_line(
			Vector2(
				GAUGE_X - 5.0,
				tick_y
			),
			Vector2(
				GAUGE_X + 5.0,
				tick_y
			),
			Color(
				0.56,
				0.65,
				0.69,
				1.0
			),
			1.0
		)

	_draw_text(
		font,
		Vector2(
			39.0,
			GAUGE_TOP + 4.0
		),
		"0 m",
		MUTED_COLOR,
		11
	)

	_draw_text(
		font,
		Vector2(
			39.0,
			GAUGE_BOTTOM + 4.0
		),
		WorldScaleContract.format_distance(
			depth_limit
		),
		MUTED_COLOR,
		11
	)

	_draw_marker(
		font,
		GAUGE_TOP,
		SEA_COLOR,
		"S"
	)

	var observer_y := _depth_to_gauge_y(
		observer_depth,
		depth_limit
	)

	_draw_marker(
		font,
		observer_y,
		OBSERVER_COLOR,
		"O"
	)

	if surface_available:
		var seafloor_y := _depth_to_gauge_y(
			seafloor_depth,
			depth_limit
		)

		_draw_marker(
			font,
			seafloor_y,
			SEAFLOOR_COLOR,
			"F"
		)


func _draw_marker(
	font: Font,
	marker_y: float,
	color: Color,
	label: String
) -> void:
	draw_line(
		Vector2(
			GAUGE_X - 8.0,
			marker_y
		),
		Vector2(
			GAUGE_X + 11.0,
			marker_y
		),
		color,
		3.0
	)

	_draw_text(
		font,
		Vector2(
			8.0,
			marker_y + 4.0
		),
		label,
		color,
		11
	)


func _depth_to_gauge_y(
	depth_meters: float,
	depth_limit: float
) -> float:
	var fraction := clampf(
		depth_meters / depth_limit,
		0.0,
		1.0
	)

	return lerpf(
		GAUGE_TOP,
		GAUGE_BOTTOM,
		fraction
	)


func _draw_text(
	font: Font,
	text_position: Vector2,
	text: String,
	color: Color,
	font_size: int = 13
) -> void:
	draw_string(
		font,
		text_position,
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size,
		color
	)
