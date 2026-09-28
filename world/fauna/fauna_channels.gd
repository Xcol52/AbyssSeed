class_name FaunaChannels
extends RefCounted

const SPECIES_CHANNEL_STRIDE: int = 64

const CANDIDATE_JITTER_X_BASE: int = 8101
const CANDIDATE_JITTER_Z_BASE: int = 8102
const SPAWN_ROLL_BASE: int = 8103
const ALTITUDE_ROLL_BASE: int = 8104
const POPULATION_ROLL_BASE: int = 8105
const HEADING_ROLL_BASE: int = 8106
const IDENTITY_BASE: int = 8107
const BEHAVIOR_BASE: int = 8108
const PATCH_NOISE_BASE: int = 8109


static func for_species(
	base_channel: int,
	species_id: int
) -> int:
	return (
		base_channel
		+ species_id * SPECIES_CHANNEL_STRIDE
	)
