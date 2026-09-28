class_name PlateInteriorReliefDescriptor
extends RefCounted

## One deterministic, cached descriptor is created for each plate site.

var hill_centers := PackedVector2Array()
var hill_radii := PackedVector2Array()
var hill_angles := PackedFloat32Array()
var hill_heights := PackedFloat32Array()
var hill_shape_powers := PackedFloat32Array()
var hill_relief_cap: float = 0.0

var terrace_centers := PackedVector2Array()
var terrace_half_lengths := PackedFloat32Array()
var terrace_half_widths := PackedFloat32Array()
var terrace_transition_widths := PackedFloat32Array()
var terrace_angles := PackedFloat32Array()
var terrace_relief := PackedFloat32Array()
var terrace_tilts := PackedFloat32Array()

var massif_enabled: bool = false
var massif_center: Vector2 = Vector2.ZERO
var massif_radii: Vector2 = Vector2.ONE
var massif_angle: float = 0.0
var massif_height: float = 0.0
var massif_secondary_offset: Vector2 = Vector2.ZERO

var depression_enabled: bool = false
var depression_center: Vector2 = Vector2.ZERO
var depression_radii: Vector2 = Vector2.ONE
var depression_angle: float = 0.0
var depression_depth: float = 0.0
