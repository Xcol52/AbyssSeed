class_name ChunkGenerationJob
extends RefCounted

const STATE_QUEUED: int = 0
const STATE_RUNNING: int = 1
const STATE_READY: int = 2
const STATE_PRESENTED: int = 3
const STATE_CANCELLED: int = 4
const STATE_STALE: int = 5
const STATE_FAILED: int = 6

var snapshot: TerrainGenerationSnapshot
var state: int = STATE_QUEUED
var task_id: int = -1
var obsolete: bool = false
var result_received: bool = false

## Retained until WorkerThreadPool reports completion.
var worker: TerrainGenerationWorker


func _init(
	job_snapshot: TerrainGenerationSnapshot
) -> void:
	snapshot = job_snapshot
