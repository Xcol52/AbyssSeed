class_name DiveSuitHUD
extends Control

## Diegetic single-value depth display for the atmospheric dive suit.
##
## The gauge reads only the suit's authoritative world-space Y position.
## Camera bobbing therefore does not affect the displayed depth.


const PANEL_SIZE: Vector2 = Vector2(
	260.0,
	140.0
)

const VIEWPORT_MARGIN: float = 28.0
const FRAME_THICKNESS: float = 18.0

const RIVET_RADIUS: float = 4.5
const RIVET_INSET: float = 10.0

const SCANLINE_SPACING: float = 4.0
const SEGMENT_DIGIT_WIDTH: float = 30.0
const SEGMENT_DIGIT_HEIGHT: float = 54.0
const SEGMENT_GAP: float = 7.0
const SEGMENT_THICKNESS: float = 4.0
const SEGMENT_UNIT_GAP: float = 11.0
const SEGMENT_UNIT_WIDTH: float = 25.0


const METAL_OUTER_COLOR: Color = Color(
	0.105,
	0.105,
	0.100,
	1.0
)

const METAL_SHADOW_COLOR: Color = Color(
	0.055,
	0.050,
	0.045,
	1.0
)

const RUST_BASE_COLOR: Color = Color(
	0.275,
	0.125,
	0.055,
	1.0
)

const RUST_LIGHT_COLOR: Color = Color(
	0.480,
	0.215,
	0.070,
	1.0
)

const RUST_DARK_COLOR: Color = Color(
	0.145,
	0.065,
	0.035,
	1.0
)

const OXIDATION_COLOR: Color = Color(
	0.095,
	0.105,
	0.095,
	1.0
)

const RIVET_OUTER_COLOR: Color = Color(
	0.025,
	0.025,
	0.025,
	1.0
)

const RIVET_INNER_COLOR: Color = Color(
	0.155,
	0.145,
	0.125,
	1.0
)

const SCREEN_COLOR: Color = Color(
	0.0,
	0.0,
	0.0,
	1.0
)

const SCREEN_EDGE_COLOR: Color = Color(
	0.025,
	0.050,
	0.035,
	1.0
)

const SCANLINE_COLOR: Color = Color(
	0.075,
	0.090,
	0.080,
	0.72
)

const TEXT_GLOW_WIDE_COLOR: Color = Color(
	0.0,
	0.80,
	0.20,
	0.10
)

const TEXT_GLOW_NEAR_COLOR: Color = Color(
	0.0,
	1.0,
	0.25,
	0.28
)

const TEXT_COLOR: Color = Color(
	0.18,
	1.0,
	0.32,
	1.0
)

const BOTTOM_TEXT_COLOR: Color = Color(
	0.12,
	0.72,
	0.28,
	1.0
)


## Optional path resolved relative to this Control. Explicit configuration
## through configure() takes precedence.
@export var dive_suit_path: NodePath = NodePath()


var _dive_suit: Node3D
var _world: OceanWorld
var _observer: Node3D
var _displayed_depth_meters: int = 0
var _displayed_clearance_meters: int = 0
var _has_clearance_reading: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE

	_configure_layout()

	if _dive_suit == null:
		_dive_suit = _resolve_dive_suit()

	_refresh_depth()
	queue_redraw()


func configure(
	world: OceanWorld,
	observer: Node3D
) -> bool:
	if world == null or observer == null:
		push_error("DiveSuitHUD requires a world and observer.")
		return false

	if (
		not is_instance_valid(world)
		or not is_instance_valid(observer)
	):
		push_error("DiveSuitHUD received an invalid world or observer.")
		return false

	_world = world
	_observer = observer
	_dive_suit = observer
	_refresh_depth()

	return true


func set_monitoring_enabled(
	enabled: bool
) -> void:
	visible = enabled
	set_process(enabled)


func _process(
	_delta: float
) -> void:
	if (
		_dive_suit == null
		or not is_instance_valid(_dive_suit)
	):
		_dive_suit = _resolve_dive_suit()

		if _dive_suit == null:
			return

	var depth_source: Node3D = _observer
	if depth_source == null or not is_instance_valid(depth_source):
		depth_source = _dive_suit

	if depth_source == null or not is_instance_valid(depth_source):
		return

	var current_depth_meters: int = roundi(
		absf(depth_source.global_position.y)
	)

	if current_depth_meters == _displayed_depth_meters:
		return

	_displayed_depth_meters = current_depth_meters
	_refresh_clearance(depth_source)
	queue_redraw()


func _configure_layout() -> void:
	anchor_left = 1.0
	anchor_top = 1.0
	anchor_right = 1.0
	anchor_bottom = 1.0

	offset_left = (
		-PANEL_SIZE.x
		- VIEWPORT_MARGIN
	)

	offset_top = (
		-PANEL_SIZE.y
		- VIEWPORT_MARGIN
	)

	offset_right = -VIEWPORT_MARGIN
	offset_bottom = -VIEWPORT_MARGIN

	custom_minimum_size = PANEL_SIZE


func _resolve_dive_suit() -> Node3D:
	if dive_suit_path != NodePath():
		var path_node: Node = get_node_or_null(
			dive_suit_path
		)

		var path_suit: Node3D = (
			path_node as Node3D
		)

		if path_suit != null:
			return path_suit

	## Support a HUD placed beneath the suit through an intermediate
	## CanvasLayer without requiring a brittle fixed relative path.
	var ancestor_node: Node = get_parent()

	while ancestor_node != null:
		var ancestor_suit: AtmosphericDiveSuit = (
			ancestor_node as AtmosphericDiveSuit
		)

		if ancestor_suit != null:
			return ancestor_suit

		ancestor_node = ancestor_node.get_parent()

	## Main designates AtmosphericDiveSuit with the player group. This
	## fallback supports a HUD installed as a sibling CanvasLayer.
	var scene_tree: SceneTree = get_tree()

	if scene_tree == null:
		return null

	var grouped_node: Node = (
		scene_tree.get_first_node_in_group(&"player")
	)

	var grouped_suit: Node3D = (
		grouped_node as Node3D
	)

	return grouped_suit


func _refresh_depth() -> void:
	if (
		_dive_suit == null
		or not is_instance_valid(_dive_suit)
	):
		return

	_displayed_depth_meters = roundi(
		absf(_dive_suit.global_position.y)
	)
	_refresh_clearance(_dive_suit)

	queue_redraw()


func _refresh_clearance(observer: Node3D) -> void:
	if _world == null or not is_instance_valid(_world):
		return

	var surface_result := _world.query_active_seafloor(
		observer.global_position
	)

	if surface_result == null or not surface_result.available:
		_has_clearance_reading = false
		return

	_displayed_clearance_meters = roundi(
		WorldScaleContract.bottom_clearance(
			observer.global_position.y,
			surface_result.surface_elevation_meters
		)
	)
	_has_clearance_reading = true


func _draw() -> void:
	var panel_rect: Rect2 = Rect2(
		Vector2.ZERO,
		size
	)

	_draw_chassis(panel_rect)

	var screen_rect: Rect2 = Rect2(
		Vector2(
			FRAME_THICKNESS,
			FRAME_THICKNESS
		),
		Vector2(
			maxf(
				0.0,
				size.x - FRAME_THICKNESS * 2.0
			),
			maxf(
				0.0,
				size.y - FRAME_THICKNESS * 2.0
			)
		)
	)

	_draw_screen(screen_rect)
	_draw_depth_value(screen_rect)


func _draw_chassis(
	panel_rect: Rect2
) -> void:
	draw_rect(
		panel_rect,
		METAL_OUTER_COLOR,
		true
	)

	draw_rect(
		panel_rect,
		METAL_SHADOW_COLOR,
		false,
		3.0
	)

	var rust_layer_rect: Rect2 = panel_rect.grow(
		-3.0
	)

	draw_rect(
		rust_layer_rect,
		RUST_BASE_COLOR,
		true
	)

	draw_rect(
		rust_layer_rect,
		RUST_LIGHT_COLOR,
		false,
		2.0
	)

	var oxidized_layer_rect: Rect2 = panel_rect.grow(
		-7.0
	)

	draw_rect(
		oxidized_layer_rect,
		OXIDATION_COLOR,
		false,
		5.0
	)

	## Fixed corrosion marks keep the panel deterministic and avoid
	## allocating procedural texture resources.
	draw_line(
		Vector2(26.0, 7.0),
		Vector2(82.0, 7.0),
		RUST_DARK_COLOR,
		3.0
	)

	draw_line(
		Vector2(101.0, 8.0),
		Vector2(151.0, 8.0),
		METAL_SHADOW_COLOR,
		2.0
	)

	draw_line(
		Vector2(size.x - 78.0, 7.0),
		Vector2(size.x - 26.0, 7.0),
		RUST_LIGHT_COLOR,
		2.0
	)

	draw_line(
		Vector2(30.0, size.y - 7.0),
		Vector2(92.0, size.y - 7.0),
		METAL_SHADOW_COLOR,
		3.0
	)

	draw_line(
		Vector2(118.0, size.y - 8.0),
		Vector2(size.x - 32.0, size.y - 8.0),
		RUST_DARK_COLOR,
		2.0
	)

	draw_line(
		Vector2(7.0, 29.0),
		Vector2(7.0, 66.0),
		RUST_DARK_COLOR,
		2.0
	)

	draw_line(
		Vector2(size.x - 7.0, 35.0),
		Vector2(size.x - 7.0, 77.0),
		RUST_LIGHT_COLOR,
		2.0
	)

	_draw_rivet(
		Vector2(
			RIVET_INSET,
			RIVET_INSET
		)
	)

	_draw_rivet(
		Vector2(
			size.x - RIVET_INSET,
			RIVET_INSET
		)
	)

	_draw_rivet(
		Vector2(
			RIVET_INSET,
			size.y - RIVET_INSET
		)
	)

	_draw_rivet(
		Vector2(
			size.x - RIVET_INSET,
			size.y - RIVET_INSET
		)
	)


func _draw_rivet(
	rivet_center: Vector2
) -> void:
	draw_circle(
		rivet_center,
		RIVET_RADIUS,
		RIVET_OUTER_COLOR
	)

	draw_circle(
		rivet_center + Vector2(-0.8, -0.8),
		RIVET_RADIUS * 0.48,
		RIVET_INNER_COLOR
	)


func _draw_screen(
	screen_rect: Rect2
) -> void:
	draw_rect(
		screen_rect.grow(3.0),
		METAL_SHADOW_COLOR,
		true
	)

	draw_rect(
		screen_rect.grow(1.0),
		SCREEN_EDGE_COLOR,
		true
	)

	draw_rect(
		screen_rect,
		SCREEN_COLOR,
		true
	)

	var scanline_y: float = (
		screen_rect.position.y
		+ 2.0
	)

	var scanline_end_y: float = (
		screen_rect.position.y
		+ screen_rect.size.y
		- 1.0
	)

	var scanline_start_x: float = (
		screen_rect.position.x
		+ 1.0
	)

	var scanline_end_x: float = (
		screen_rect.position.x
		+ screen_rect.size.x
		- 1.0
	)

	while scanline_y < scanline_end_y:
		draw_line(
			Vector2(
				scanline_start_x,
				scanline_y
			),
			Vector2(
				scanline_end_x,
				scanline_y
			),
			SCANLINE_COLOR,
			1.0
		)

		scanline_y += SCANLINE_SPACING


func _draw_depth_value(
	screen_rect: Rect2
) -> void:
	## Several low-alpha passes approximate CRT phosphor bloom without
	## introducing a texture, shader, or external font asset.
	_draw_segment_display(
		screen_rect,
		Vector2(-2.0, 0.0),
		TEXT_GLOW_WIDE_COLOR
	)

	_draw_segment_display(
		screen_rect,
		Vector2(2.0, 0.0),
		TEXT_GLOW_WIDE_COLOR
	)

	_draw_segment_display(
		screen_rect,
		Vector2(0.0, -2.0),
		TEXT_GLOW_WIDE_COLOR
	)

	_draw_segment_display(
		screen_rect,
		Vector2(0.0, 2.0),
		TEXT_GLOW_WIDE_COLOR
	)

	_draw_segment_display(
		screen_rect,
		Vector2(-1.0, 0.0),
		TEXT_GLOW_NEAR_COLOR
	)

	_draw_segment_display(
		screen_rect,
		Vector2(1.0, 0.0),
		TEXT_GLOW_NEAR_COLOR
	)

	_draw_segment_display(
		screen_rect,
		Vector2.ZERO,
		TEXT_COLOR
	)

	var font: Font = ThemeDB.fallback_font
	var clearance_text := "BOTTOM --"
	if _has_clearance_reading:
		clearance_text = "BOTTOM %dm" % _displayed_clearance_meters

	draw_string(
		font,
		Vector2(
			screen_rect.position.x + 10.0,
			screen_rect.end.y - 8.0
		),
		clearance_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		screen_rect.size.x - 20.0,
		11,
		BOTTOM_TEXT_COLOR
	)


func _draw_segment_display(
	screen_rect: Rect2,
	text_offset: Vector2,
	text_color: Color
) -> void:
	var depth_text: String = str(_displayed_depth_meters)
	var digit_count: int = depth_text.length()
	var display_width: float = (
		float(digit_count) * SEGMENT_DIGIT_WIDTH
		+ float(maxi(digit_count - 1, 0)) * SEGMENT_GAP
		+ SEGMENT_UNIT_GAP
		+ SEGMENT_UNIT_WIDTH
	)
	var display_origin := Vector2(
		screen_rect.position.x
			+ (screen_rect.size.x - display_width) * 0.5
			+ text_offset.x,
		screen_rect.position.y
			+ (screen_rect.size.y - SEGMENT_DIGIT_HEIGHT) * 0.5
			+ text_offset.y
	)

	for digit_index in range(digit_count):
		var digit: int = int(depth_text[digit_index])
		var digit_origin := Vector2(
			display_origin.x
				+ float(digit_index)
					* (SEGMENT_DIGIT_WIDTH + SEGMENT_GAP),
			display_origin.y
		)

		_draw_segment_digit(
			digit_origin,
			digit,
			text_color
		)

	_draw_segment_unit(
		Vector2(
			display_origin.x
				+ float(digit_count)
					* SEGMENT_DIGIT_WIDTH
				+ float(maxi(digit_count - 1, 0))
					* SEGMENT_GAP
				+ SEGMENT_UNIT_GAP,
			display_origin.y
		),
		text_color
	)


func _draw_segment_digit(
	origin: Vector2,
	digit: int,
	segment_color: Color
) -> void:
	var segments: Array[bool] = _get_digit_segments(digit)
	var half_height: float = SEGMENT_DIGIT_HEIGHT * 0.5
	var inset: float = SEGMENT_THICKNESS
	var points: Array[PackedVector2Array] = [
		PackedVector2Array([
			origin + Vector2(inset, 0.0),
			origin + Vector2(SEGMENT_DIGIT_WIDTH - inset, 0.0),
		]),
		PackedVector2Array([
			origin + Vector2(SEGMENT_DIGIT_WIDTH, inset),
			origin + Vector2(SEGMENT_DIGIT_WIDTH, half_height - inset),
		]),
		PackedVector2Array([
			origin + Vector2(SEGMENT_DIGIT_WIDTH, half_height + inset),
			origin + Vector2(SEGMENT_DIGIT_WIDTH, SEGMENT_DIGIT_HEIGHT - inset),
		]),
		PackedVector2Array([
			origin + Vector2(inset, SEGMENT_DIGIT_HEIGHT),
			origin + Vector2(SEGMENT_DIGIT_WIDTH - inset, SEGMENT_DIGIT_HEIGHT),
		]),
		PackedVector2Array([
			origin + Vector2(0.0, half_height + inset),
			origin + Vector2(0.0, SEGMENT_DIGIT_HEIGHT - inset),
		]),
		PackedVector2Array([
			origin + Vector2(0.0, inset),
			origin + Vector2(0.0, half_height - inset),
		]),
		PackedVector2Array([
			origin + Vector2(inset, half_height),
			origin + Vector2(SEGMENT_DIGIT_WIDTH - inset, half_height),
		]),
	]

	for segment_index in range(segments.size()):
		if not segments[segment_index]:
			continue

		var segment_points: PackedVector2Array = points[segment_index]
		draw_line(
			segment_points[0],
			segment_points[1],
			segment_color,
			SEGMENT_THICKNESS,
			true
		)


func _draw_segment_unit(
	origin: Vector2,
	segment_color: Color
) -> void:
	var unit_height: float = SEGMENT_DIGIT_HEIGHT * 0.58
	var top_y: float = (
		origin.y + (SEGMENT_DIGIT_HEIGHT - unit_height) * 0.5
	)
	var bottom_y: float = top_y + unit_height
	var center_x: float = origin.x + SEGMENT_UNIT_WIDTH * 0.5

	draw_line(
		Vector2(origin.x, top_y),
		Vector2(origin.x, bottom_y),
		segment_color,
		SEGMENT_THICKNESS,
		true
	)
	draw_line(
		Vector2(origin.x, top_y),
		Vector2(center_x, bottom_y),
		segment_color,
		SEGMENT_THICKNESS,
		true
	)
	draw_line(
		Vector2(center_x, bottom_y),
		Vector2(origin.x + SEGMENT_UNIT_WIDTH, top_y),
		segment_color,
		SEGMENT_THICKNESS,
		true
	)
	draw_line(
		Vector2(origin.x + SEGMENT_UNIT_WIDTH, bottom_y),
		Vector2(origin.x + SEGMENT_UNIT_WIDTH, top_y),
		segment_color,
		SEGMENT_THICKNESS,
		true
	)


static func _get_digit_segments(
	digit: int
) -> Array[bool]:
	match digit:
		0:
			return [true, true, true, true, true, true, false]
		1:
			return [false, true, true, false, false, false, false]
		2:
			return [true, true, false, true, true, false, true]
		3:
			return [true, true, true, true, false, false, true]
		4:
			return [false, true, true, false, false, true, true]
		5:
			return [true, false, true, true, false, true, true]
		6:
			return [true, false, true, true, true, true, true]
		7:
			return [true, true, true, false, false, false, false]
		8:
			return [true, true, true, true, true, true, true]
		9:
			return [true, true, true, true, false, true, true]
		_:
			return [false, false, false, false, false, false, false]
