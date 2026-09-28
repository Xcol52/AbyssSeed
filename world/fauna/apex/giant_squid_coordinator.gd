class_name GiantSquidCoordinator
extends Node

@export_range(100.0, 10000.0, 10.0)
var activation_distance: float = 1800.0

@export_range(100.0, 12000.0, 10.0)
var deactivation_distance: float = 2400.0

@export_range(1, 256, 1)
var maximum_cached_descriptors: int = 64

@export_range(0.05, 5.0, 0.05)
var activation_check_interval: float = 0.50

var _initialized: bool = false

var _observer: Node3D
var _presentation_root: Node3D
var _catalog: FaunaCatalogSnapshot

var _ocean_height: float = 0.0
var _surface_query: Callable = Callable()

# stable population ID -> FaunaPopulationDescriptor
var _descriptors: Dictionary = {}

# stable population ID -> GiantSquidController
var _active_controllers: Dictionary = {}

var _activation_accumulator: float = 0.0


func _ready() -> void:
	set_process(false)


func initialize(
	observer: Node3D,
	presentation_root: Node3D,
	catalog: FaunaCatalogSnapshot,
	ocean_height: float,
	surface_query: Callable = Callable()
) -> bool:
	if _initialized:
		return false

	if observer == null or not is_instance_valid(observer):
		return false

	if (
		presentation_root == null
		or not is_instance_valid(presentation_root)
	):
		return false

	if catalog == null:
		return false

	var squid_species: FaunaSpeciesSnapshot = (
		catalog.get_species(
			FaunaIds.GIANT_SQUID
		)
	)

	if squid_species == null:
		push_error(
			"GiantSquidCoordinator could not find "
			+ "the giant squid catalog entry."
		)
		return false

	_observer = observer
	_presentation_root = presentation_root
	_catalog = catalog
	_ocean_height = ocean_height
	_surface_query = surface_query

	_initialized = true
	set_process(true)

	return true


func register_descriptor(
	descriptor: FaunaPopulationDescriptor
) -> bool:
	if not _initialized:
		return false

	if descriptor == null:
		return false

	if descriptor.species_id != FaunaIds.GIANT_SQUID:
		return false

	if (
		descriptor.ownership_mode
		!= FaunaTypes.OwnershipMode.REGIONAL_HOME
	):
		return false

	_descriptors[descriptor.stable_id] = descriptor

	_prune_descriptor_cache()
	_update_activation()

	return true


func unregister_descriptor(
	stable_id: int
) -> void:
	_deactivate(stable_id)
	_descriptors.erase(stable_id)


func get_descriptor_count() -> int:
	return _descriptors.size()


func get_active_count() -> int:
	return _active_controllers.size()


func get_active_controller(
	stable_id: int
) -> GiantSquidController:
	return (
		_active_controllers.get(stable_id)
		as GiantSquidController
	)


func force_debug_encounter(
	home_position: Vector3,
	debug_seed: int = 910001
) -> int:
	if not _initialized:
		return 0

	if (
		not is_finite(home_position.x)
		or not is_finite(home_position.y)
		or not is_finite(home_position.z)
	):
		return 0

	var stable_id: int = (
		StableSeed.derive_channel_seed(
			debug_seed,
			441
		)
	)

	var descriptor: FaunaPopulationDescriptor = (
		FaunaPopulationDescriptor.new(
			stable_id,
			FaunaIds.GIANT_SQUID,
			Vector2i.ZERO,
			Vector2i.ZERO,
			home_position,
			1,
			35.0,
			220.0,
			1800.0,
			1.0,
			1.0,
			1.0,
			0.0,
			debug_seed,
			FaunaTypes.OwnershipMode.REGIONAL_HOME
		)
	)

	# A fixed debug seed deliberately produces a fixed stable ID.
	# Remove any active controller using that ID before replacing its
	# descriptor so repeated commands move the encounter as expected.
	_deactivate(stable_id)

	_descriptors[stable_id] = descriptor
	_activate(descriptor)

	return stable_id


func _process(
	delta: float
) -> void:
	if not _initialized:
		return

	_activation_accumulator += delta

	if (
		_activation_accumulator
		< activation_check_interval
	):
		return

	_activation_accumulator = 0.0
	_update_activation()


func _update_activation() -> void:
	if (
		_observer == null
		or not is_instance_valid(_observer)
	):
		return

	var observer_position: Vector3 = (
		_observer.global_position
	)

	var activation_squared: float = (
		activation_distance
		* activation_distance
	)

	var deactivation_squared: float = (
		deactivation_distance
		* deactivation_distance
	)

	var active_ids: Array[int] = []

	for id_value: Variant in _active_controllers.keys():
		active_ids.append(int(id_value))

	for stable_id: int in active_ids:
		var descriptor: FaunaPopulationDescriptor = (
			_descriptors.get(stable_id)
			as FaunaPopulationDescriptor
		)

		if descriptor == null:
			_deactivate(stable_id)
			continue

		var distance_squared: float = (
			descriptor.home_position
			.distance_squared_to(
				observer_position
			)
		)

		if distance_squared > deactivation_squared:
			_deactivate(stable_id)

	for descriptor_value: Variant in _descriptors.values():
		var descriptor: FaunaPopulationDescriptor = (
			descriptor_value
			as FaunaPopulationDescriptor
		)

		if descriptor == null:
			continue

		if _active_controllers.has(
			descriptor.stable_id
		):
			continue

		var distance_squared: float = (
			descriptor.home_position
			.distance_squared_to(
				observer_position
			)
		)

		if distance_squared <= activation_squared:
			_activate(descriptor)


func _activate(
	descriptor: FaunaPopulationDescriptor
) -> void:
	if descriptor == null:
		return

	if _active_controllers.has(
		descriptor.stable_id
	):
		return

	var species: FaunaSpeciesSnapshot = (
		_catalog.get_species(
			FaunaIds.GIANT_SQUID
		)
	)

	if species == null:
		return

	var controller: GiantSquidController = (
		GiantSquidController.new()
	)

	_presentation_root.add_child(controller)

	if not controller.initialize(
		descriptor,
		species,
		_observer,
		_ocean_height,
		_surface_query
	):
		controller.queue_free()
		return

	_active_controllers[
		descriptor.stable_id
	] = controller


func _deactivate(
	stable_id: int
) -> void:
	var controller: GiantSquidController = (
		_active_controllers.get(stable_id)
		as GiantSquidController
	)

	_active_controllers.erase(stable_id)

	if (
		controller != null
		and is_instance_valid(controller)
	):
		controller.queue_free()


func _prune_descriptor_cache() -> void:
	while (
		_descriptors.size()
		> maximum_cached_descriptors
	):
		var selected_id: int = 0
		var selected_distance: float = -1.0
		var found: bool = false

		for id_value: Variant in _descriptors.keys():
			var stable_id: int = int(id_value)

			if _active_controllers.has(stable_id):
				continue

			var descriptor: FaunaPopulationDescriptor = (
				_descriptors.get(stable_id)
				as FaunaPopulationDescriptor
			)

			if descriptor == null:
				selected_id = stable_id
				found = true
				break

			var distance_squared: float = 0.0

			if (
				_observer != null
				and is_instance_valid(_observer)
			):
				distance_squared = (
					descriptor.home_position
					.distance_squared_to(
						_observer.global_position
					)
				)

			if (
				not found
				or distance_squared
				> selected_distance
			):
				found = true
				selected_id = stable_id
				selected_distance = distance_squared

		if not found:
			break

		_descriptors.erase(selected_id)


func _exit_tree() -> void:
	set_process(false)

	var active_ids: Array[int] = []

	for id_value: Variant in _active_controllers.keys():
		active_ids.append(int(id_value))

	for stable_id: int in active_ids:
		_deactivate(stable_id)

	_descriptors.clear()
	_initialized = false
