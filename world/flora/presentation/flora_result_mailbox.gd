class_name FloraResultMailbox
extends RefCounted

var _capacity: int
var _results: Array[FloraGenerationResult] = []
var _mutex := Mutex.new()


func _init(capacity: int) -> void:
	assert(capacity > 0)
	_capacity = capacity


## Called by worker threads.
func publish(result: FloraGenerationResult) -> bool:
	if result == null:
		return false

	_mutex.lock()

	if _results.size() >= _capacity:
		_mutex.unlock()
		return false

	_results.append(result)
	_mutex.unlock()
	return true


## Called by the main thread.
func take_matching(
	chunk_coordinate: Vector2i,
	activation_token: int,
	request_revision: int
) -> FloraGenerationResult:
	_mutex.lock()

	for index in _results.size():
		var result := _results[index]

		if (
			result.chunk_coordinate == chunk_coordinate
			and result.activation_token == activation_token
			and result.request_revision == request_revision
		):
			_results.remove_at(index)
			_mutex.unlock()
			return result

	_mutex.unlock()
	return null
