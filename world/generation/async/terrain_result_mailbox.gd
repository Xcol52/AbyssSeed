class_name TerrainResultMailbox
extends RefCounted

var _capacity: int
var _results: Array[TerrainGenerationResult] = []
var _mutex := Mutex.new()
var _overflow_count: int = 0


func _init(capacity: int) -> void:
	assert(capacity > 0)
	_capacity = capacity


## Called by worker threads.
func publish(result: TerrainGenerationResult) -> bool:
	if result == null:
		return false

	_mutex.lock()

	if _results.size() >= _capacity:
		_overflow_count += 1
		_mutex.unlock()
		return false

	_results.append(result)
	_mutex.unlock()
	return true


## Called by the main thread.
func take_next() -> TerrainGenerationResult:
	_mutex.lock()

	if _results.is_empty():
		_mutex.unlock()
		return null

	var result: TerrainGenerationResult = (
		_results.pop_front() as TerrainGenerationResult
	)

	_mutex.unlock()
	return result


func get_count() -> int:
	_mutex.lock()
	var count := _results.size()
	_mutex.unlock()
	return count


func contains_request_id(request_id: int) -> bool:
	_mutex.lock()

	for result in _results:
		if result.snapshot.request_id == request_id:
			_mutex.unlock()
			return true

	_mutex.unlock()
	return false


func get_overflow_count() -> int:
	_mutex.lock()
	var count := _overflow_count
	_mutex.unlock()
	return count


func clear() -> void:
	_mutex.lock()
	_results.clear()
	_mutex.unlock()
