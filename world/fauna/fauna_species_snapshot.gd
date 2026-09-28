class_name FaunaSpeciesSnapshot
extends RefCounted

## Immutable by convention after catalog construction.

var species_id: int
var display_name: String

var presentation_mode: int
var trophic_role: int
var model_mode: int
var ownership_mode: int

## Deterministic population-home placement.
var candidate_spacing: float
var jitter_fraction: float
var base_spawn_probability: float
var minimum_suitability: float
var patch_size: float
var patchiness: float

## Authoritative population range.
var minimum_population: int
var maximum_population: int

## Runtime presentation never needs to instantiate every authoritative
## population member.
var maximum_representatives: int

## Movement and home-region behavior.
var home_radius: float
var minimum_altitude: float
var maximum_altitude: float
var cruise_speed: float
var flee_speed: float
var turn_rate: float
var threat_distance: float
var pursuit_distance: float

## Procedural presentation.
var body_length: float
var procedural_variant_count: int
var cold_color: Color
var warm_color: Color


func get_validation_error() -> String:
	if species_id < 0 or species_id >= FaunaIds.COUNT:
		return "Fauna species has an invalid species ID."

	if display_name.is_empty():
		return "Fauna species requires a display name."

	if (
		presentation_mode
		!= FaunaTypes.PresentationMode.SCHOOL_AGGREGATE
		and presentation_mode
		!= FaunaTypes.PresentationMode.INDIVIDUAL
	):
		return "Fauna species has an invalid presentation mode."

	if (
		trophic_role < FaunaTypes.TrophicRole.HERBIVORE
		or trophic_role > FaunaTypes.TrophicRole.APEX_PREDATOR
	):
		return "Fauna species has an invalid trophic role."

	if (
		model_mode < FaunaTypes.ModelMode.PROCEDURAL_VARIANTS
		or model_mode > FaunaTypes.ModelMode.AUTHORED_MESH
	):
		return "Fauna species has an invalid model mode."

	if candidate_spacing <= 0.0:
		return "Fauna candidate spacing must be positive."

	if jitter_fraction < 0.0 or jitter_fraction > 1.0:
		return "Fauna jitter fraction must be between zero and one."

	if (
		base_spawn_probability < 0.0
		or base_spawn_probability > 1.0
	):
		return "Fauna spawn probability must be between zero and one."

	if (
		minimum_suitability < 0.0
		or minimum_suitability > 1.0
	):
		return "Fauna minimum suitability must be between zero and one."

	if minimum_population < 1:
		return "Fauna minimum population must be at least one."

	if maximum_population < minimum_population:
		return "Fauna maximum population is below its minimum."

	if maximum_representatives < 1:
		return "Fauna requires at least one representative."

	if minimum_altitude < 0.0:
		return "Fauna minimum altitude cannot be negative."

	if maximum_altitude < minimum_altitude:
		return "Fauna altitude range is invalid."

	if home_radius <= 0.0:
		return "Fauna home radius must be positive."

	if cruise_speed <= 0.0:
		return "Fauna cruise speed must be positive."

	if flee_speed < cruise_speed:
		return "Fauna flee speed cannot be below cruise speed."

	if turn_rate <= 0.0:
		return "Fauna turn rate must be positive."

	if body_length <= 0.0:
		return "Fauna body length must be positive."

	if procedural_variant_count < 1:
		return "Fauna requires at least one procedural variant."

	return ""
