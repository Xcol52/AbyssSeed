class_name FaunaTypes
extends RefCounted

enum PresentationMode {
	SCHOOL_AGGREGATE,
	INDIVIDUAL,
}

enum TrophicRole {
	HERBIVORE,
	PREDATOR,
	APEX_PREDATOR,
}

enum ModelMode {
	PROCEDURAL_VARIANTS,
	AUTHORED_MESH,
}

enum OwnershipMode {
	CHUNK_HOME,
	REGIONAL_HOME,
}

enum BehaviorState {
	WANDER,
	GRAZE,
	FLEE,
	PURSUE,
	RETURN_HOME,
}
