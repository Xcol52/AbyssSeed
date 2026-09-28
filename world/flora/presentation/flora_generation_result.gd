class_name FloraGenerationResult
extends RefCounted

var chunk_coordinate: Vector2i
var activation_token: int
var request_revision: int

var flora_data: FloraChunkData
var error_message: String

var generation_usec: int
var examined_candidate_count: int
var accepted_candidate_count: int


func _init(
	new_chunk_coordinate: Vector2i,
	new_activation_token: int,
	new_request_revision: int,
	new_flora_data: FloraChunkData,
	new_error_message: String,
	new_generation_usec: int,
	new_examined_candidate_count: int,
	new_accepted_candidate_count: int
) -> void:
	chunk_coordinate = new_chunk_coordinate
	activation_token = new_activation_token
	request_revision = new_request_revision

	flora_data = new_flora_data
	error_message = new_error_message

	generation_usec = new_generation_usec
	examined_candidate_count = new_examined_candidate_count
	accepted_candidate_count = new_accepted_candidate_count


func succeeded() -> bool:
	return (
		flora_data != null
		and error_message.is_empty()
	)
