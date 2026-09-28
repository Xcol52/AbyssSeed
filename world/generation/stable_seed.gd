class_name StableSeed
extends RefCounted

# 32-bit FNV-1a constants.
const _FNV_OFFSET_BASIS: int = 2_166_136_261
const _FNV_PRIME: int = 16_777_619

const _U32_MASK: int = 0xFFFFFFFF
const _SIGN_BIT_32: int = 0x80000000
const _U32_RANGE: int = 0x100000000


static func derive_subsystem_seed(
	world_seed: int,
	generation_version: int,
	subsystem_id: int
) -> int:
	assert(generation_version >= 1)
	assert(subsystem_id > 0)

	var state := _FNV_OFFSET_BASIS
	state = _mix_int64(state, world_seed)
	state = _mix_int64(state, generation_version)
	state = _mix_int64(state, subsystem_id)

	return _unsigned_to_signed_32(state)


## Reserved for discrete coordinate-owned decisions such as placement.
## Continuous terrain does not use a different seed for each chunk.
static func derive_coordinate_seed(
	world_seed: int,
	generation_version: int,
	subsystem_id: int,
	logical_coordinate: Vector2i
) -> int:
	assert(generation_version >= 1)
	assert(subsystem_id > 0)

	var state := _FNV_OFFSET_BASIS
	state = _mix_int64(state, world_seed)
	state = _mix_int64(state, generation_version)
	state = _mix_int64(state, subsystem_id)
	state = _mix_int64(state, logical_coordinate.x)
	state = _mix_int64(state, logical_coordinate.y)

	return _unsigned_to_signed_32(state)

## Derives a stable child seed for one explicitly numbered channel.
static func derive_channel_seed(
	base_seed: int,
	channel_id: int
) -> int:
	assert(channel_id > 0)

	var state := _FNV_OFFSET_BASIS
	state = _mix_int64(state, base_seed)
	state = _mix_int64(state, channel_id)

	return _unsigned_to_signed_32(state)


## Derives a stable seed from a base seed, channel, and logical address.
static func derive_spatial_seed(
	base_seed: int,
	channel_id: int,
	logical_coordinate: Vector2i
) -> int:
	assert(channel_id > 0)

	var state := _FNV_OFFSET_BASIS
	state = _mix_int64(state, base_seed)
	state = _mix_int64(state, channel_id)
	state = _mix_int64(state, logical_coordinate.x)
	state = _mix_int64(state, logical_coordinate.y)

	return _unsigned_to_signed_32(state)


static func seed_to_unit_float(seed_value: int) -> float:
	var unsigned_value: int = seed_value & _U32_MASK
	return float(unsigned_value) / float(_U32_MASK)



## Mixes all eight bytes of a signed 64-bit integer in little-endian order.
static func _mix_int64(
	initial_state: int,
	input_value: int
) -> int:
	var state := initial_state

	for byte_index in range(8):
		var shift_amount := byte_index * 8
		var byte_value: int = (
			(input_value >> shift_amount) & 0xFF
		)

		state = (
			((state ^ byte_value) * _FNV_PRIME)
			& _U32_MASK
		)

	return state


static func _unsigned_to_signed_32(
	unsigned_value: int
) -> int:
	var normalized := unsigned_value & _U32_MASK

	if normalized >= _SIGN_BIT_32:
		return normalized - _U32_RANGE

	return normalized
