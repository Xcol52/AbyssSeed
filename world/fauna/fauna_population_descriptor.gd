class_name FaunaPopulationDescriptor
extends RefCounted

## Immutable generated population home.
##
## Runtime position, velocity, population loss, and discovery state do
## not belong here.

var stable_id: int
var species_id: int
var candidate_cell: Vector2i
var owning_chunk: Vector2i

var home_position: Vector3
var initial_population: int

var minimum_altitude: float
var maximum_altitude: float
var home_radius: float

var suitability: float
var carrying_capacity: float
var patch_strength: float

var initial_heading_radians: float
var behavior_seed: int
var ownership_mode: int


func _init(
	new_stable_id: int,
	new_species_id: int,
	new_candidate_cell: Vector2i,
	new_owning_chunk: Vector2i,
	new_home_position: Vector3,
	new_initial_population: int,
	new_minimum_altitude: float,
	new_maximum_altitude: float,
	new_home_radius: float,
	new_suitability: float,
	new_carrying_capacity: float,
	new_patch_strength: float,
	new_initial_heading_radians: float,
	new_behavior_seed: int,
	new_ownership_mode: int
) -> void:
	stable_id = new_stable_id
	species_id = new_species_id
	candidate_cell = new_candidate_cell
	owning_chunk = new_owning_chunk

	home_position = new_home_position
	initial_population = new_initial_population

	minimum_altitude = new_minimum_altitude
	maximum_altitude = new_maximum_altitude
	home_radius = new_home_radius

	suitability = new_suitability
	carrying_capacity = new_carrying_capacity
	patch_strength = new_patch_strength

	initial_heading_radians = new_initial_heading_radians
	behavior_seed = new_behavior_seed
	ownership_mode = new_ownership_mode


func get_validation_error() -> String:
	if species_id < 0 or species_id >= FaunaIds.COUNT:
		return "Fauna population has an invalid species ID."

	if (
		not is_finite(home_position.x)
		or not is_finite(home_position.y)
		or not is_finite(home_position.z)
	):
		return "Fauna population home position must be finite."

	if initial_population < 1:
		return "Fauna population must contain at least one member."

	if minimum_altitude < 0.0:
		return "Fauna minimum altitude cannot be negative."

	if maximum_altitude < minimum_altitude:
		return "Fauna population altitude range is invalid."

	if home_radius <= 0.0:
		return "Fauna population home radius must be positive."

	if suitability < 0.0 or suitability > 1.0:
		return "Fauna suitability must be between zero and one."

	if carrying_capacity < 0.0 or carrying_capacity > 1.0:
		return "Fauna carrying capacity must be between zero and one."

	if patch_strength < 0.0 or patch_strength > 1.0:
		return "Fauna patch strength must be between zero and one."

	if not is_finite(initial_heading_radians):
		return "Fauna initial heading must be finite."

	return ""
