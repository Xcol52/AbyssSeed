class_name FloraChannels
extends RefCounted

## Each species receives a block of deterministic channels.
const SPECIES_CHANNEL_STRIDE: int = 32

const CANDIDATE_JITTER_X_BASE: int = 7101
const CANDIDATE_JITTER_Z_BASE: int = 7102
const SPAWN_ROLL_BASE: int = 7103
const SCALE_ROLL_BASE: int = 7104
const YAW_ROLL_BASE: int = 7105
const IDENTITY_BASE: int = 7106
const PATCH_NOISE_BASE: int = 7107


static func for_species(
	base_channel: int,
	species_id: int
) -> int:
	return (
		base_channel
		+ species_id * SPECIES_CHANNEL_STRIDE
	)
