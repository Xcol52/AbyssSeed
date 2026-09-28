# Procedural Ocean Engine
# Procedural Ocean Engine

## Status

Session 1 — Foundation and Architecture: complete.

The project currently bootstraps an empty, configured world session. It does
not yet render geometry or generate procedural content.

Engine target: current stable Godot 4.x.
Language: GDScript.
External plugins: none.

## Architectural Goals

- Deterministic procedural generation
- Infinite logical exploration
- Explicit dependencies
- Thread-ready data generation
- Chunk-owned streamed content
- Replaceable world sessions
- Feature-oriented project organization

## Current Project Structure

res://
├── app/
│   ├── main.gd
│   └── main.tscn
├── world/
│   └── core/
│       ├── default_world_definition.tres
│       ├── ocean_world.gd
│       ├── ocean_world.tscn
│       └── world_definition.gd
├── .gitignore
├── project.godot
└── README.md

Future feature folders will be created only as their systems are implemented.

## Runtime Scene Tree

Main
└── OceanWorld
	├── SystemsRoot
	└── WorldContent
		├── StreamedChunksRoot
		├── OceanRoot
		└── DynamicEntitiesRoot

WorldContent is the future floating-origin rebase target.

Streamed chunks will own their terrain and static procedural placements.
Dynamic, stateful entities will live separately under DynamicEntitiesRoot.
The single camera-relative ocean surface will live under OceanRoot.

## Current Components

### Main

Application composition root. It instantiates and configures an OceanWorld
before adding it to the SceneTree.

### WorldDefinition

Read-only world identity and compatibility configuration. It currently stores
a seed and generation version.

### OceanWorld

Lifecycle and orchestration boundary for one world session. It will eventually
wire focused world systems together without implementing their algorithms.

## Bootstrap Sequence

1. Main loads the configured PackedScene and WorldDefinition.
2. Main instantiates the OceanWorld.
3. Main configures it before it enters the SceneTree.
4. Main adds the configured world as a child.
5. OceanWorld validates that configuration is present.

An active OceanWorld is not reconfigured. Loading a different world replaces
the world instance.

## Dependency Rules

- Main may create and configure OceanWorld.
- OceanWorld may wire world systems together.
- Systems receive narrow, explicit dependencies.
- Systems do not locate dependencies through autoloads or SceneTree searches.
- Configuration resources contain no runtime Node references.
- Generators do not create Nodes or access the SceneTree.
- Presenters may consume generated data and create Godot rendering objects.
- Shared code must not depend on world features.
- Circular dependencies between sibling systems are prohibited.

## Coordinate Contract

- One Godot unit represents one meter.
- Positive Y is up.
- X and Z form the horizontal world plane.
- Procedural generation will use logical chunk/global coordinates.
- Render-space transforms may be rebased around the observer.
- Adjacent chunks will sample shared borders from identical global inputs.

## Determinism Contract

A generated result must depend only on explicit inputs such as:

- Base seed
- Generation version
- Subsystem identifier
- Logical chunk coordinate
- Local sample coordinate
- Typed generation settings

Generation order, thread completion order, and the global random-number
generator must not affect results.

A stable seed-derivation/hash function will be implemented before procedural
generation. Engine-dependent hashing will not be assumed stable without
verification.

## Threading Contract

Future worker jobs may calculate data but must not mutate the SceneTree or
shared mutable Resources.

The initial safe pipeline will be:

1. Create an immutable generation request.
2. Calculate single-owner arrays and descriptors on a worker.
3. Return the result to the main thread.
4. Reject stale or cancelled results.
5. Build or update runtime presentation on the main thread.

Thread use of specific Godot APIs will be verified against the exact engine
version before implementation.

## Setup

1. Open the project with the current stable Godot 4 editor.
2. Set res://app/main.tscn as the main scene.
3. Run the project.
4. Open the Remote Scene Tree in the editor.

Expected Remote Scene Tree:

Main
└── OceanWorld
	├── SystemsRoot
	└── WorldContent
		├── StreamedChunksRoot
		├── OceanRoot
		└── DynamicEntitiesRoot

The viewport is intentionally empty because no camera or rendered geometry
exists yet.

## Known Limitations

- No camera or debug observer
- No ocean mesh
- No chunk system
- No terrain
- No FastNoiseLite configuration
- No biome system
- No procedural placement
- No shaders, lighting, or fog
- No floating-origin implementation
- No automated tests
- No generation-version migration logic

## Deferred Features

- Ocean surface geometry and GPU animation
- Chunk streaming and lifecycle state machine
- Deterministic seed derivation
- Terrain field sampling
- Terrain mesh construction
- Biome resolution
- Procedural placement descriptors
- Background generation scheduling
- Chunk and presentation pooling
- Dynamic entities
- Persistence and save data
- Lighting, fog, and visual polish

## Development Journal

### 2026-07-30 — Session 1

Implemented:

- Feature-oriented project organization
- Application composition root
- Replaceable world-session boundary
- Seeded and versioned WorldDefinition
- Configuration-before-SceneTree lifecycle
- Spatial ownership roots
- Initial architecture documentation

Reasoning:

The foundation separates world configuration, orchestration, future data
generation, and runtime presentation. This avoids hidden global dependencies
and establishes a safe route toward deterministic multithreaded generation.

## Next Milestone

Session 2 should implement one static, camera-relative procedural ocean grid.

It should:

- Use one MeshInstance3D
- Construct one ArrayMesh using SurfaceTool
- Use typed OceanSettings
- Recenter or snap around an explicit debug observer
- Avoid rebuilding geometry every frame
- Remain independent of chunk streaming
- Use a simple non-shader material for validation

Gerstner waves, ocean shaders, terrain, and chunks remain deferred.
## Status

Session 2 — Infinite Ocean Surface Foundation: implemented.

The project now renders one procedural, observer-relative ocean grid. There is
no terrain, chunk generation, noise, streaming, shader animation, lighting, or
fog.

## Technical Baseline

- Engine: Godot 4.7.1
- Renderer: Forward+
- Initial platform target: desktop
- Language: GDScript
- External plugins: none

Forward+ was selected for future atmospheric lighting, volumetric fog, and
water shader requirements. Mobile or web support may require a different
renderer strategy.

## Current Project Structure

```text
res://
├── app/
│   ├── main.gd
│   └── main.tscn
├── debug/
│   └── observer/
│       ├── debug_observer.gd
│       └── debug_observer.tscn
├── world/
│   ├── core/
│   │   ├── default_world_definition.tres
│   │   ├── ocean_world.gd
│   │   ├── ocean_world.tscn
│   │   └── world_definition.gd
│   └── ocean/
│       ├── default_ocean_settings.tres
│       ├── ocean_settings.gd
│       ├── ocean_surface.gd
│       └── ocean_surface.tscn
├── .gitignore
├── project.godot
└── README.md
```

## Runtime Scene Tree

```text
Main
├── DebugObserver
│   └── PitchPivot
│       └── Camera3D
└── OceanWorld
	├── SystemsRoot
	└── WorldContent
		├── StreamedChunksRoot
		├── OceanRoot
		│   └── OceanSurface
		│       └── OceanMesh
		└── DynamicEntitiesRoot
```

`StreamedChunksRoot` and `DynamicEntitiesRoot` are empty architectural anchors.
No chunk or entity systems are implemented.

## Current Components

### Main

Application composition root. It supplies a generic observer and a
WorldDefinition to OceanWorld before adding the world to the SceneTree.

### DebugObserver

Development-only flying camera. It is isolated from world generation and is
not a player or gameplay system.

### WorldDefinition

Read-only world identity and subsystem configuration. It currently stores the
world seed, generation version, and OceanSettings.

### OceanSettings

Focused ocean geometry configuration:

- Grid size
- Mesh resolution
- Ocean height
- Recenter distance

Wave, material, color, fog, and biome values intentionally remain absent.

### OceanWorld

World-session orchestration boundary. It passes the narrow dependencies needed
by OceanSurface without implementing rendering itself.

### OceanSurface

Rendering component responsible for:

- Constructing one indexed grid through SurfaceTool
- Storing the resulting ArrayMesh
- Assigning it to one MeshInstance3D
- Reading observer position
- Moving to snapped observer-relative coordinates

It does not generate terrain, create chunks, or manage gameplay.

## Ocean Invariants

- Exactly one ocean MeshInstance3D exists.
- The grid is generated once during initialization.
- Observer movement never rebuilds the mesh.
- No ocean tiles are spawned.
- The surface moves only when its snapped center changes.
- OceanSettings is treated as read-only after bootstrap.
- OceanSurface receives a generic Node3D observer.
- No custom shader exists.

Default mesh statistics:

- 128 cells per axis
- 129 vertices per axis
- 16,641 total vertices
- 32,768 triangles

## Observer-Relative Rendering

The surface center is calculated by snapping the observer's X and Z position
to `recenter_distance`.

Moving the existing surface is preferable to tiling because it avoids node
churn, seams, tile coordination, and mesh duplication. This approach assumes
one primary observer and limited viewing distance.

A future wave shader must use logical-world coordinates or an accumulated
world-origin offset. Sampling only local mesh coordinates would make wave
phases jump when the surface recenters.

## Coordinate Contract

- One Godot unit represents one meter.
- Positive Y is up.
- X and Z form the horizontal world plane.
- Ocean height is expressed in OceanRoot-local coordinates.
- Procedural generation will eventually use logical coordinates distinct from
  render-space transforms.
- WorldContent remains the future floating-origin rebase target.

## Controls

- W/A/S/D: horizontal movement
- E: move up
- Q: move down
- Shift: speed boost
- Mouse: look
- Escape: release mouse
- Left click: capture mouse

Debug controls use direct physical keyboard queries. They do not define
gameplay input actions.

## Setup and Testing

1. Open the project in Godot 4.7.1.
2. Confirm the renderer is Forward+.
3. Confirm `res://app/main.tscn` is the main scene.
4. Run the project.
5. Move using the debug observer controls.
6. Inspect the Remote Scene Tree.

Expected results:

- One OceanSurface exists.
- One OceanMesh MeshInstance3D exists.
- The viewport displays a dark blue geometric plane.
- OceanSurface position changes in 32-meter increments.
- The ArrayMesh resource instance remains unchanged while moving.
- No new nodes appear while exploring.
- The debugger reports no errors.

The mesh resource identity can be inspected through the Remote Inspector before
and after movement to verify that it is reused.

## Dependency Rules

- Main composes the observer and OceanWorld.
- OceanWorld injects narrow dependencies into world components.
- OceanSurface depends on OceanSettings and a generic Node3D observer.
- OceanSurface does not know about the debug observer implementation.
- Configuration resources contain no runtime Node references.
- Generators must not access the SceneTree.
- Presenters may consume generated data and create rendering objects.
- Circular dependencies between sibling systems are prohibited.

## Determinism Contract

Future generated results must depend only on explicit inputs such as:

- Base seed
- Generation version
- Subsystem identifier
- Logical chunk coordinate
- Global sample coordinate
- Typed generation settings

Generation order, thread completion order, and the global random-number
generator must not affect results.

## Threading Contract

Future worker jobs may calculate data but must not mutate the SceneTree or
shared mutable Resources.

The current ocean mesh is generated once on the main thread. Moving this
one-time operation to a worker would provide no meaningful benefit.

## Known Limitations

- The ocean is a finite grid creating an infinite-looking illusion.
- Only one primary observer is supported.
- Extremely high observer altitudes can expose the finite rendering model.
- There are no waves or GPU displacement.
- The validation material is unshaded and visually uniform.
- There is no lighting, fog, or WorldEnvironment.
- There is no floating-origin implementation.
- Runtime OceanSettings changes do not rebuild the mesh.
- The debug observer has no collision.
- There is no terrain, noise, chunk lifecycle, or streaming.
- There are no automated tests yet.

## Deferred Features

- Logical world coordinates
- Stable deterministic seed derivation
- Chunk coordinate data type
- Terrain field sampling
- Terrain mesh generation
- Chunk lifecycle and streaming
- FastNoiseLite configuration
- Floating-origin rebasing
- Ocean shaders and Gerstner waves
- Lighting and underwater fog
- Biomes
- Procedural placement
- Dynamic entities
- Background generation
- Pooling

## Development Journal

### 2026-07-30 — Session 1

Implemented:

- Feature-oriented project organization
- Application composition root
- Replaceable world-session boundary
- Seeded and versioned WorldDefinition
- Configuration-before-SceneTree lifecycle
- Spatial ownership roots
- Initial architecture documentation

Reasoning:

The foundation separates configuration, orchestration, future data generation,
and runtime presentation. This avoids hidden global dependencies and preserves
a safe path toward deterministic background generation.

### 2026-07-30 — Session 2

Implemented:

- Godot 4.7.1 and Forward+ desktop baseline
- Focused OceanSettings resource
- One procedural indexed ocean grid
- SurfaceTool and ArrayMesh mesh construction
- One persistent MeshInstance3D
- Observer-relative snapped recentering
- Isolated debug observer and camera
- Unshaded validation material
- Updated composition and documentation

Reasoning:

A single recentered surface provides the infinite-ocean illusion without tile
management, seams, mesh recreation, or chunk-system coupling. The observer is
injected as a generic Node3D so ocean rendering remains independent of debug
and future gameplay implementations.

## Next Milestone

Session 3 should establish procedural-world data contracts before implementing
streaming:

1. Define logical world and chunk coordinates.
2. Define chunk size and coordinate conversion rules.
3. Implement stable subsystem/chunk seed derivation.
4. Add deterministic tests.
5. Verify shared-border sample coordinates.
6. Create one fixed terrain-generation test only after those contracts pass.

Chunk loading, unloading, and multithreaded streaming should remain deferred
until deterministic single-chunk generation is validated.
## Status

Session 3 — Deterministic World Coordinates and Seabed Prototype:
implemented, pending local validation.

The project now generates one deterministic seabed chunk below the
observer-relative ocean surface. No chunk streaming exists.

## Session 3 Architecture

WorldDefinition
├── WorldGridSettings
├── TerrainSettings
├── world_seed
└── generation_version
          │
          v
StableSeed
          │
          v
TerrainGenerationRequest
          │
          v
TerrainSampler
          │
          v
TerrainChunkData
          │
          v
TerrainMeshBuilder
          │
          v
SeabedPrototype / MeshInstance3D

TerrainSampler and TerrainChunkData have no SceneTree dependency.
TerrainMeshBuilder is the rendering boundary.

## Coordinate Contract

- One Godot unit represents one meter.
- Positive Y is up.
- X and Z form the horizontal world plane.
- Vector2i.x represents world X.
- Vector2i.y represents world Z.
- Chunk ownership is half-open.
- A chunk with N cells has N + 1 mesh samples per axis.
- Shared mesh borders query identical global sample coordinates.
- Negative chunk conversion uses mathematical floor behavior.

Default grid:

- Chunk size: 256 meters
- Cells per axis: 32
- Cell size: 8 meters
- Vertices per axis: 33

## Determinism Contract

Subsystem seeds depend only on:

- World seed
- Generation version
- Explicit numeric subsystem ID

Coordinate seeds additionally include a Vector2i logical coordinate.

Continuous terrain uses one terrain subsystem seed and global sample
coordinates. It never uses an independently derived seed per chunk.

The stable seed utility does not use String.hash(), dictionary ordering,
global random state, or generation order.

FastNoiseLite output is tied to Godot 4.7.1. Engine upgrades must be
treated as potential generation changes and tested before adoption.

## Static Seabed Prototype

Exactly one chunk at coordinate (0, 0) is generated.

The prototype:

- Samples one continuous FastNoiseLite field
- Stores heights in TerrainChunkData
- Builds one flat-shaded ArrayMesh
- Uses duplicated vertices for independent face normals
- Is generated once during initialization
- Has no collision
- Is not loaded or unloaded dynamically

## Session 3 Tests

Run:

res://tests/session_3/session_3_tests.tscn

The test scene validates:

- Positive and negative coordinate conversion
- Exact chunk boundaries
- Coordinate reconstruction
- Stable subsystem seeds
- Stable negative-coordinate seeds
- Shared global border addresses
- Exact neighboring terrain-edge heights

## Known Limitations

- Only one seabed chunk exists.
- Terrain uses one simple test-noise field.
- The seabed has no collision.
- There is no chunk lifecycle or streaming.
- There is no LOD or background generation.
- Fog applies globally rather than detecting whether the observer is underwater.
- The terrain material and environment are temporary validation assets.
- Flat triangle duplication uses more vertices than smooth indexed geometry.
- Runtime settings changes do not rebuild the prototype.

## Deferred Features

- Chunk loading and unloading
- Infinite terrain
- Generation scheduling and worker threads
- Object pooling
- LOD
- Collision
- Multi-layer geological terrain
- Continental shelves, cliffs, and final trenches
- Biomes
- Procedural object placement
- Caves
- Floating-origin rebasing
- Final lighting, fog, and ocean shaders

## Development Journal

### Session 3 — Deterministic Coordinates and Seabed Prototype

Implemented:

- Focused WorldGridSettings and TerrainSettings
- Floor-correct negative coordinate conversion
- Stable numeric subsystem IDs
- Stable seed derivation
- Data-only TerrainGenerationRequest
- Data-only TerrainChunkData
- Scene-independent TerrainSampler
- SurfaceTool/ArrayMesh terrain presentation
- One static low-poly seabed chunk
- Minimal underwater fog
- Project-owned deterministic tests

Reasoning:

Global sample addressing ensures neighboring chunks independently query
the same coordinates along shared edges. Continuous terrain uses one
subsystem seed so the terrain field remains seamless. Data generation is
separate from mesh presentation to preserve a safe future threading
boundary.

## Next Milestone

Session 4 should introduce a synchronous chunk lifecycle before adding
threads:

1. Define explicit chunk states.
2. Calculate a desired coordinate set around the observer.
3. Generate a small bounded neighborhood synchronously.
4. Load and unload chunk presenters.
5. Prove lifecycle correctness and stale-result handling.
6. Add pooling only if profiling demonstrates meaningful churn.

Threading, LOD, and advanced geology should remain deferred until the
synchronous lifecycle is correct.
Session 3 — Deterministic World Coordinates and Seabed Prototype: complete.

Validation:
- Session 3 tests passed: 86 assertions.
- One static seabed prototype renders successfully.
- Ocean surface and validation fog render successfully.
- No debugger errors observed.

# Procedural Ocean Engine

A deterministic, chunk-based procedural underwater world built with Godot 4.7.1 and GDScript.

## Status

Session 4 — Synchronous Chunk Lifecycle and Observer-Driven Streaming: complete.

The project maintains a bounded, observer-centered set of deterministic terrain chunks. Generation is synchronous, limited per frame, and prioritized by observer distance and camera heading.

No threading, pooling, LOD, collision, advanced geology, or gameplay systems have been introduced.

## Technical Baseline

- Engine: Godot 4.7.1
- Renderer: Forward+
- Initial platform target: desktop
- Language: GDScript
- Noise source: FastNoiseLite
- Mesh construction: SurfaceTool and ArrayMesh
- External plugins: none

Forward+ was selected for future atmospheric lighting, volumetric fog, and water rendering requirements.

## Current Features

- Procedurally generated static ocean surface
- Camera-relative debug observer movement
- Observer-relative ocean recentering
- Deterministic terrain generation
- Correct negative world-coordinate handling
- Seamless shared terrain borders
- Observer-driven terrain chunk residency
- Bounded synchronous chunk generation
- Per-frame generation budget
- Load/unload hysteresis
- Camera-aware generation priority
- Automatic renderer frustum culling
- Minimal underwater fog
- Project-owned coordinate, determinism, and streaming tests

## Runtime Architecture

```text
Main
├── DebugObserver
│   └── PitchPivot
│       └── Camera3D
└── OceanWorld
    ├── SystemsRoot
    │   ├── UnderwaterEnvironment
    │   └── ChunkCoordinator
    └── WorldContent
        ├── StreamedChunksRoot
        │   ├── WorldChunk
        │   ├── WorldChunk
        │   └── ...
        ├── OceanRoot
        │   └── OceanSurface
        │       └── OceanMesh
        └── DynamicEntitiesRoot
```

`WorldContent` remains the future floating-origin rebase target.

`StreamedChunksRoot` owns all active terrain chunk presentation. The old single `SeabedPrototype` validation harness has been removed.

## Chunk Streaming Architecture

```text
Observer
   │
   ├── position → current chunk coordinate
   └── heading  → generation priority
                         │
                         v
                 ChunkStreamPolicy
                         │
                         v
                  ChunkStreamPlan
               ┌─────────┼─────────┐
               v         v         v
            retain    generate    unload
                         │
                         v
              TerrainGenerationRequest
                         │
                         v
                  TerrainSampler
                         │
                         v
                 TerrainChunkData
                         │
                         v
                TerrainMeshBuilder
                         │
                         v
                     WorldChunk
                         │
                         v
               StreamedChunksRoot
```

### Responsibilities

#### ChunkStreamPolicy

A data-only policy that:

- Computes desired coordinates
- Identifies missing coordinates
- Identifies chunks beyond the unload radius
- Orders missing coordinates by distance and camera heading
- Has no SceneTree access
- Does not generate terrain

#### ChunkStreamPlan

A data-only result containing:

- Desired coordinates
- Ordered generation coordinates
- Unload coordinates

#### ChunkCoordinator

The runtime lifecycle owner. It:

- Tracks active chunks by `Vector2i`
- Observes logical chunk changes
- Rebuilds residency when the observer crosses a chunk boundary
- Reprioritizes pending work after significant camera rotation
- Discards stale pending coordinates before generation
- Limits synchronous generation per frame
- Creates and removes `WorldChunk` instances

It does not contain terrain-sampling algorithms.

#### WorldChunk

Owns the presentation for one logical chunk:

- Logical chunk coordinate
- Generated `TerrainChunkData`
- Generated `ArrayMesh`
- One `MeshInstance3D`

It does not decide whether it should be loaded or unloaded.

#### Godot renderer

Godot performs normal frustum culling for loaded `MeshInstance3D` objects.

The chunk system controls residency and memory. It does not manually unload terrain merely because it is outside the camera view.

## Loaded Versus Rendered

These are separate concepts.

Loaded means:

- Terrain data exists
- An ArrayMesh exists
- A WorldChunk node exists in memory

Rendered means:

- Godot determines the chunk is visible to the camera
- The renderer submits its visible geometry

Nearby chunks remain loaded in every direction so turning the camera does not produce holes or force regeneration.

Camera direction affects pending generation order, not chunk ownership.

## Residency Contract

The default policy uses square Chebyshev distance.

```text
Load radius:                  2 chunks
Unload radius:                3 chunks
Generation budget:            1 chunk per frame
Camera reprioritization:      15 degrees
Forward priority bias:        0.25
```

A load radius of two produces a 5×5 desired neighborhood:

```text
5 × 5 = 25 desired chunks
```

An unload radius of three provides a 7×7 maximum residency boundary:

```text
7 × 7 = 49 possible resident coordinates
```

Chunks between the load and unload radii may remain loaded but are not newly requested. This hysteresis prevents repeated destruction and regeneration near residency boundaries.

At the initial position, the system settles at 25 active chunks after the pending queue finishes.

## Generation Priority

Missing chunks are ordered using:

1. Distance from the observer
2. Horizontal camera alignment
3. Stable coordinate ordering for exact ties

Distance remains dominant. A nearby side or rear chunk cannot be delayed indefinitely in favor of a distant forward-facing chunk.

Camera rotation beyond the configured threshold reorders pending work. It does not:

- Rebuild terrain
- Remove active chunks
- Change residency
- Create new desired coordinates

## Queue Contract

The pending generation queue is rebuilt when the observer enters another logical chunk.

Rebuilding the queue:

- Removes coordinates that are no longer desired
- Excludes already active chunks
- Prevents duplicate requests
- Does not cancel in-progress work because generation is synchronous

Before generating a pending coordinate, the coordinator verifies that it is still desired and not already active.

At a stable observer position, the system reaches a steady state:

```text
Pending queue = 0
Active set stops changing
No meshes are regenerated
No nodes are repeatedly created or destroyed
```

## Terrain Generation Pipeline

```text
WorldDefinition
├── world_seed
├── generation_version
├── WorldGridSettings
├── TerrainSettings
└── ChunkStreamingSettings
          │
          v
Stable terrain subsystem seed
          │
          v
TerrainGenerationRequest
          │
          v
TerrainSampler
          │
          v
TerrainChunkData
          │
          v
TerrainMeshBuilder
          │
          v
WorldChunk
```

### TerrainSampler

- Uses global logical sample coordinates
- Uses one terrain subsystem seed
- Creates deterministic height data
- Has no SceneTree dependency
- Creates no Nodes or meshes

### TerrainChunkData

Contains only generated terrain data:

- Chunk coordinate
- Cells per axis
- Cell size
- Packed height values

### TerrainMeshBuilder

The rendering boundary. It:

- Consumes `TerrainChunkData`
- Builds a flat-shaded mesh through `SurfaceTool`
- Returns an `ArrayMesh`
- Uses stable face coloring independent of per-chunk height ranges

The terrain mesh uses duplicated triangle vertices for independent flat normals. This costs more memory than indexed smooth geometry but supports the intended low-poly presentation.

## Coordinate Contract

- One Godot unit represents one meter.
- Positive Y is up.
- X and Z form the horizontal world plane.
- `Vector2i.x` represents world X.
- `Vector2i.y` represents world Z.
- Chunk coordinates use mathematical floor behavior.
- Chunk ownership is half-open.
- A chunk with N cells has N + 1 mesh samples per axis.
- Neighboring chunks query identical global sample addresses along shared borders.
- Render-space transforms remain separate from logical procedural addresses.

Default grid:

```text
Chunk size:          256 meters
Cells per axis:      32
Cell size:           8 meters
Vertices per axis:   33
```

## Determinism Contract

Subsystem seeds depend only on:

- World seed
- Generation version
- Explicit numeric subsystem ID

Coordinate-specific seeds may additionally use a logical `Vector2i`.

Continuous terrain does not use an independent seed per chunk. Every chunk samples one continuous terrain field using:

```text
Terrain subsystem seed
+
Global sample coordinate
```

Generated results must not depend on:

- `String.hash()`
- Dictionary iteration order
- Global random state
- Generation order
- Chunk load order
- Camera direction
- Frame timing

Returning to an unloaded coordinate regenerates the same terrain.

FastNoiseLite output is currently tied to Godot 4.7.1. Engine upgrades must be treated as potential procedural-generation changes and validated before adoption.

## Ocean Surface

The ocean remains one procedural grid rather than tiled ocean chunks.

It:

- Owns one persistent `MeshInstance3D`
- Builds its geometry once
- Recenters around the observer at snapped intervals
- Does not regenerate during movement
- Is independent of terrain chunk streaming

A future ocean shader must use logical world coordinates or an accumulated origin offset so recentering does not cause visible wave-phase changes.

## Controls

```text
W / S       Move forward or backward relative to camera direction
A / D       Move left or right relative to camera direction
Shift       Speed boost
Mouse       Look
Escape      Release mouse
Left click  Recapture mouse
```

Movement includes camera pitch. Looking downward and pressing W moves the observer downward.

The observer is development tooling, not a gameplay player system.

## Testing

### Session 3 tests

Run:

```text
res://tests/session_3/session_3_tests.tscn
```

Validated result:

```text
Session 3 tests passed: 86 assertions.
```

These tests cover:

- Positive and negative coordinate conversion
- Exact chunk boundaries
- Coordinate reconstruction
- Deterministic subsystem seeds
- Shared global sample addresses
- Exact neighboring terrain borders

### Session 4 tests

Run:

```text
res://tests/session_4/session_4_tests.tscn
```

Expected validated result:

```text
Session 4 tests passed: 137 assertions.
```

These tests cover:

- Desired coordinate calculation
- Negative-coordinate neighborhoods
- Duplicate prevention
- Load-radius behavior
- Unload-radius hysteresis
- Pending queue reconstruction
- Stable generation priority
- Camera-facing priority
- Distance-dominant priority
- Deterministic terrain regeneration
- Negative-coordinate terrain borders

The test window closes automatically after reporting its result.

## Runtime Validation

Session 4 runtime validation confirmed:

- Multiple chunks load around the observer.
- Initial residency settles correctly.
- New chunks load after crossing chunk boundaries.
- Distant chunks unload.
- Negative-coordinate movement works.
- Terrain borders remain seamless.
- Camera rotation does not unload active chunks.
- Camera rotation does not regenerate existing terrain.
- Pending chunks can be reprioritized while loading.
- Movement and rotation tests complete without debugger errors.
- The active set becomes stable while the observer remains stationary.

## Known Limitations

- Terrain sampling runs synchronously on the main thread.
- Mesh construction runs synchronously on the main thread.
- The generation budget counts chunks rather than milliseconds.
- One expensive chunk can still cause a frame spike.
- Pending arrays are small and currently use simple array operations.
- Unloaded chunks are freed rather than pooled.
- Returning to a coordinate reconstructs its data and mesh.
- Active chunks retain both terrain data and mesh data.
- Flat-shaded terrain duplicates triangle vertices.
- Only one primary observer is supported.
- Camera heading assumes the current debug observer hierarchy.
- Terrain still uses one simple prototype noise field.
- No terrain collision exists.
- No LOD or crack-management strategy exists.
- No floating-origin rebasing exists.
- Fog applies globally rather than detecting whether the observer is underwater.
- The ocean has no wave shader.
- There are no gameplay systems.

## Deferred Features

- Worker-thread terrain generation
- Bounded asynchronous job scheduling
- Stale completed-result rejection
- Safe shutdown of background jobs
- Object pooling where profiling justifies it
- Terrain LOD and crack management
- Collision
- Floating-origin rebasing
- Multi-layer geological terrain
- Continental shelves
- Abyssal plains
- Cliffs and final trench fields
- Biomes
- Procedural object placement
- Kelp, coral, ruins, and shipwrecks
- Dynamic entities
- Final ocean shader
- Final underwater lighting and fog

## Development Journal

### Session 1 — Foundation and Architecture

Implemented:

- Feature-oriented project organization
- Application composition root
- Replaceable world-session boundary
- Versioned `WorldDefinition`
- Configuration-before-SceneTree lifecycle
- World-content ownership roots
- Generator/presentation separation

### Session 2 — Infinite Ocean Surface Foundation

Implemented:

- One procedural ocean grid
- Persistent ocean `ArrayMesh`
- Observer-relative snapped recentering
- Isolated debug observer
- Camera-relative movement
- Basic validation material

### Session 3 — Deterministic Coordinates and Seabed Prototype

Implemented:

- `WorldGridSettings`
- Floor-correct negative coordinates
- Global terrain sample addressing
- Stable numeric subsystem identifiers
- Stable seed derivation
- Data-only terrain generation request and result
- Scene-independent terrain sampling
- Separate terrain mesh construction
- One static seabed prototype
- Minimal underwater fog
- Project-owned deterministic tests

Validation:

```text
86 assertions passed
0 debugger errors
0 debugger warnings
```

### 2026-07-31 — Session 4

Implemented:

- Observer-driven chunk residency
- Configurable load and unload radii
- Residency hysteresis
- Bounded active chunk count
- Data-only stream planning
- Deterministic pending-generation ordering
- Camera-aware generation priority
- Significant-rotation reprioritization threshold
- Synchronous per-frame generation budget
- Independent `WorldChunk` presentation
- Runtime loading and unloading
- Negative-coordinate streaming
- Stale pending-coordinate rejection
- Stable cross-chunk terrain coloring
- Session 4 policy and determinism tests

Reasoning:

Residency is based on observer position so nearby terrain remains stable when the camera turns. Camera direction affects only pending generation order. This avoids visible holes and lifecycle thrashing while improving perceived loading.

The synchronous lifecycle was intentionally implemented before worker threads, cancellation, pooling, LOD, or advanced geology.

## Next Milestone

Session 5 should begin with profiling rather than immediately adding complexity.

Recommended scope:

1. Measure terrain sampling time.
2. Measure mesh-construction time.
3. Measure scene-instantiation time.
4. Record worst-frame generation cost.
5. Determine whether background generation is justified.
6. If justified, create immutable worker requests.
7. Generate data-only terrain results in bounded background jobs.
8. Reject completed results that are no longer desired.
9. Keep SceneTree mutation and mesh presentation on the main thread.
10. Handle world shutdown safely.

Thread safety of FastNoiseLite and other Godot APIs must be verified for Godot 4.7.1 before using them from worker threads. Job-local noise instances should be preferred over shared mutable resources.

Advanced geology, pooling, and LOD should remain separate milestones.
# Procedural Ocean Engine

## Status

Session 6 — Deterministic Planetary Geology Foundation: complete.

The project now generates broad terrain from deterministic pseudo-tectonic relationships rather than using a generic noise field as the primary source of macro elevation.

“Planetary” describes the scale and coherence of the geological system. The current world remains an effectively unbounded planar X/Z domain; spherical topology is not implemented.

## Validation

All regression suites pass:

- Session 3: 86 assertions
- Session 4: 137 assertions
- Session 5: 64 assertions
- Session 6: 36 assertions
- Debugger errors: 0
- Debugger warnings: 0

Runtime validation confirmed:

- Deterministic terrain and geology
- Matching synchronous and asynchronous results
- Stable negative-coordinate generation
- Identical shared chunk borders
- Bounded asynchronous scheduling
- Safe stale-result rejection
- Safe shutdown
- Queryable geological channels
- Functional geological debug visualization
- Visible geological influence in runtime terrain

## Geological Architecture

The generation pipeline is now:

World seed  
→ geology subsystem seed  
→ deterministic weighted plate sites  
→ neighboring plate relationships  
→ compression, extension, and shear fields  
→ ridge, trench, volcanic, and sediment potentials  
→ macro elevation  
→ regional terrain detail  
→ final terrain data  
→ main-thread mesh construction and presentation

The geological model is locally queryable. It does not require a precomputed global plate graph or depend on chunk generation order.

## Plate Topology

Plate-like regions are created from deterministic jittered sites in large geological cells.

Each site contains stable properties derived from its logical address:

- Plate identity
- Position
- Motion direction
- Motion magnitude
- Continental affinity
- Plate-size influence weight

Weighted power-distance selection introduces meaningful variation in plate area. Some plates occupy broad regions while others are compressed into smaller regions.

Domain warping makes boundaries less geometric without changing their deterministic relationships.

Plate topology depends only on world coordinates, geological settings, generation version, and the geology subsystem seed. It does not depend on:

- Observer position
- Camera direction
- Chunk load order
- Worker completion order
- Streaming state
- Chunk residency
- Presentation state

## Boundary Relationships

Nearby plate motion produces continuous geological influence fields.

Compression represents plate-like regions moving toward one another and can contribute to:

- Trench potential
- Continental collision uplift
- Subduction-like volcanic potential

Extension represents regions moving apart and can contribute to:

- Ridge potential
- Volcanic potential
- Elevated spreading-like boundaries

Shear represents regions moving alongside one another and provides a broad fault-like terrain influence.

Plate identities may change discretely across boundaries, but terrain and environmental influence fields transition continuously.

## Geological Channels

Each generated terrain chunk may retain:

- Primary plate identity
- Neighboring plate identity
- Continental affinity
- Boundary proximity
- Compression strength
- Extension strength
- Shear strength
- Ridge potential
- Trench potential
- Volcanic potential
- Sediment potential
- Macro elevation

These channels provide future systems with geological causes rather than biome labels.

For example, a future ecosystem can query depth, stability, volcanism, sediment suitability, and boundary activity instead of querying whether a location belongs to a predefined “trench biome.”

## Geological Semantics

The model enforces broad causal relationships:

- Ridge potential requires extension.
- Trench potential requires compression.
- Volcanic potential derives from spreading or subduction-like activity.
- Continental collision favors uplift rather than deep trenches.
- Stable continental regions tend to receive greater sediment potential.
- Oceanic and continental affinities produce different broad depth ranges.

These relationships are Earth-inspired abstractions rather than a scientific tectonic simulation.

`sediment_potential` represents deposition suitability. It is not simulated sediment transport or accumulated sediment depth.

## Terrain Composition

Final terrain height is composed from:

1. Broad continental or oceanic depth
2. Basin-scale variation
3. Ridge uplift
4. Trench depression
5. Continental collision uplift
6. Shear-related relief
7. Existing deterministic terrain detail

The current configuration keeps all generated terrain below ocean level. Continental regions therefore appear as submerged continental plateaus rather than exposed land.

## Determinism and Continuity

Geological sampling is based on world-space coordinates.

Changing the following does not move geological boundaries at a given world position:

- Chunk generation order
- Streaming state
- Camera position
- Worker scheduling
- Compatible sampling resolution

Adjacent chunks independently generate identical geological values and final heights at shared world-space samples.

Terrain remains seamless across positive and negative chunk coordinates.

## Asynchronous Ownership

Session 5’s ownership rules remain intact.

Worker tasks may:

- Read immutable request snapshots
- Create job-local noise generators
- Generate geological channels
- Generate terrain height data
- Publish data-only results

Worker tasks may not:

- Access the SceneTree
- Read observer transforms
- Create or remove nodes
- Modify active chunk state
- Create presentation objects
- Mutate shared runtime resources

The main thread remains responsible for:

- Residency decisions
- Request prioritization
- Result validation
- Mesh-resource creation
- WorldChunk creation
- SceneTree presentation
- Chunk removal

## Scheduling Bounds

The current default generation configuration is:

- Background workers: enabled
- Maximum pending requests: 64
- Maximum concurrent jobs: 2
- Maximum completed results: 4
- Dispatch budget: 1 per frame
- Presentation budget: 1 per frame
- Maximum retries: 1 per coordinate

Scheduler completion capacity uses explicit reservations. A fast task cannot be counted twice as both running and completed.

## Debug Visualization

The geological debug map supports visualization of:

- Plate identity
- Continental affinity
- Boundary proximity
- Compression
- Extension
- Shear
- Ridge potential
- Trench potential
- Volcanic potential
- Sediment potential
- Macro elevation

Run:

`res://debug/geology/geology_debug_map.tscn`

Controls:

- Left arrow: previous channel
- Right arrow: next channel
- R: regenerate the current map

Visual inspection confirmed:

- Broad plate regions
- Meaningful plate-size variation
- Coherent irregular boundaries
- No visible chunk-grid pattern
- Ridges aligned with extension
- Trenches aligned with compression
- Volcanism connected to geological activity
- Broad elevation differences between geological regions

Some cellular regularity remains, but it is acceptable for the current foundational model.

## Session 6 Performance Baseline

Configuration:

- Bounded asynchronous generation
- Two concurrent workers
- One dispatch per frame
- One presentation per frame

Measured results:

| Metric | Average | Maximum |
|---|---:|---:|
| Terrain and geology sampling | 79.438 ms | 97.551 ms |
| Mesh construction | 9.170 ms | 12.619 ms |
| WorldChunk presentation | 0.090 ms | 2.836 ms |
| Accepted compute total | 88.676 ms | 108.332 ms |
| Accepted request latency | 1004.315 ms | 3196.390 ms |
| Generation-frame work | 8.365 ms | 14.669 ms |

High-water counts:

- Pending requests: 64
- Running jobs: 2
- Completed results: 1
- Active chunks: 99

Outcomes:

- Sampled results: 178
- Presented chunks: 177
- Stale results rejected: 1
- Failed jobs: 0

The outcome counts reconcile correctly:

178 sampled  
= 177 presented  
+ 1 stale

The scheduler remained within all configured bounds.

## Performance Findings

Geological sampling is the largest total generation cost:

- Approximately 79 ms per chunk on average
- Executed on background workers
- Contributes heavily to request latency and queue saturation

Mesh construction is the largest direct main-thread generation cost:

- Approximately 9–13 ms per presented chunk
- Occurs in frames that must also handle rendering and normal runtime work
- Is the most likely cause of visible frame drops

WorldChunk presentation itself is inexpensive and is not currently the primary bottleneck.

The pending queue reached its maximum of 64. The generation pipeline can therefore become saturated during initial loading or sustained travel.

Average request latency is approximately one second, with a measured maximum above three seconds. This explains visible terrain appearance during rapid movement.

## Known Limitations

- The geological system is pseudo-tectonic rather than scientific.
- The world uses planar topology rather than a spherical planet.
- Triple-junction behavior is approximate.
- Some cellular regularity remains visible in the plate map.
- Continental regions remain submerged.
- Individual volcanoes and faults are not generated.
- Sediment transport and crust history are not simulated.
- All geological channels are retained for active chunks.
- Geological sampling is relatively expensive.
- Mesh construction remains on the main thread.
- Chunk-generation frames can produce visible frame-time spikes.
- Rapid travel can outpace generation and expose terrain appearing in the distance.
- The pending generation queue may reach its configured limit.
- No LOD, collision improvements, pooling, or floating origin exist.

## Deferred Systems

The following remain intentionally deferred:

- Individual volcanoes
- Hydrothermal vents
- Seamount and hotspot chains
- Detailed faults
- Simulated crust age
- Sediment transport
- Erosion
- Resource deposits
- Caves
- Biomes
- Ecosystems
- Flora and fauna
- Civilization
- Gameplay systems
- LOD
- Floating origin
- Advanced ocean rendering

## Session 6 Conclusion

Session 6 established a deterministic, queryable geological foundation that explains broad terrain shape through plate-like relationships.

The world now contains:

- Broad geological identity
- Variable plate regions
- Continental and oceanic environments
- Continuous boundary influences
- Causally connected ridges and trenches
- Volcanic and sediment potentials
- Queryable data for future environmental systems
- Seamless chunk-independent generation
- Bounded asynchronous execution
- Development visualization for geological validation

Session 6 is complete.

# Recommended Session 7 Direction

Session 7 should address measured generation performance before adding more world complexity.

A suitable title is:

## Session 7 — Profiled Geometry Preparation and Streaming Smoothness

The objective should be:

Reduce generation-related frame spikes and visible terrain arrival while preserving deterministic output, worker safety, scheduling bounds, and geological relationships.

There are two distinct problems to address.

### Problem 1: Main-thread frame spikes

Mesh construction currently costs:

- 9.170 ms average
- 12.619 ms maximum

That cost occurs on the main thread. At 60 FPS, the entire frame budget is 16.67 ms.

Session 7 should divide mesh construction into separately measured stages:

- Vertex-position generation
- Index generation
- Normal calculation
- Color, UV, or auxiliary-channel generation
- Surface array assembly
- ArrayMesh creation
- Rendering-resource upload
- WorldChunk assignment

The likely architectural transition is:

Current worker result:

Terrain and geology data  
→ main-thread geometry preparation  
→ main-thread ArrayMesh creation  
→ presentation

Proposed result:

Worker:
Terrain and geology data  
→ data-only vertex, normal, and index arrays

Main thread:
Packed geometry arrays  
→ ArrayMesh creation  
→ presentation

Only data-only calculations should move to workers. `ArrayMesh`, nodes, SceneTree changes, and presentation should remain on the main thread unless their thread safety is explicitly verified.

### Problem 2: Generation throughput and pop-in

Sampling currently costs:

- 79.438 ms average
- 97.551 ms maximum

The pending queue reached 64, and average request latency exceeded one second.

Session 7 should profile geological sampling internally:

- Coordinate warping
- Candidate-site lookup
- Power-distance evaluation
- Boundary relationship calculation
- Geological noise sampling
- Channel composition
- Terrain-detail sampling
- Geological array writes

Optimization should preserve output where practical. Good candidates include:

- Reusing candidate-site sets across samples in the same chunk
- Reducing repeated hash calculations
- Avoiding temporary allocations in inner loops
- Replacing unnecessary per-site objects with compact data
- Caching deterministic site properties within each job
- Computing values shared by nearby samples once
- Evaluating whether every retained channel needs full terrain-vertex resolution

Any approximation that changes terrain or geology should be explicit and should trigger generation-version consideration.

## Session 7 Should Not Begin With

Avoid immediately:

- Increasing the presentation budget
- Increasing the load radius
- Increasing camera distance
- Adding more workers without profiling
- Creating Godot rendering resources on workers
- Adding object pooling without evidence
- Adding LOD before the current pipeline is understood
- Reducing geological quality blindly
- Adding ecosystems or gameplay systems

Increasing the presentation budget could allow multiple 9–13 ms mesh builds in one frame and worsen spikes.

Increasing the load radius would increase startup work while the pending queue is already saturated.

## Recommended Session 7 Stages

### Stage 1 — Reproducible Benchmarking

Create a repeatable route or benchmark scene that records:

- Total frame time
- Generation-frame time
- Frame-time percentiles
- Frames exceeding 16.67 ms
- Sampling substage timings
- Mesh substage timings
- Queue high-water marks
- Request latency
- Initial settlement time

Use the same world seed, route, settings, and duration for every comparison.

### Stage 2 — Profile Mesh Construction

Measure exactly which portion of the current 9–13 ms mesh build is data calculation and which portion is Godot resource creation.

Do not redesign the pipeline until this distinction is known.

### Stage 3 — Introduce Data-Only Geometry Results

If geometry calculation dominates, add a worker-safe structure such as:

`TerrainMeshData`

It could contain:

- Vertices
- Normals
- Indices
- Colors
- UVs
- Additional packed channels needed by the material

The structure should become immutable after publication.

### Stage 4 — Preserve Main-Thread Resource Ownership

The main thread should validate freshness before creating an `ArrayMesh`.

Stale results must be discarded before:

- ArrayMesh creation
- Rendering-resource upload
- Node creation
- SceneTree presentation

Geometry results must remain subject to the same request ID, world-session ID, and generation-version checks.

### Stage 5 — Optimize Geological Sampling

After mesh preparation is separated, profile and optimize the 79 ms geological sampling path.

Prioritize reduced computation and allocations without weakening determinism or continuity.

### Stage 6 — Reassess Streaming Behavior

Only after throughput and frame spikes improve should the project consider:

- A bounded camera-facing prefetch ring
- Predictive loading based on observer velocity
- Different startup and movement budgets
- Adaptive worker concurrency
- Time-based rather than count-only presentation budgets

These should remain bounded and should not replace the existing residency model.

## Proposed Session 7 Acceptance Criteria

Session 7 should be complete when:

- Sessions 3–6 continue passing with 86, 137, 64, and 36 assertions.
- Terrain and geological outputs remain deterministic.
- Shared borders remain exact.
- Worker ownership boundaries remain enforced.
- Pending, running, and completed work remain bounded.
- Stale geometry results cannot create meshes.
- Mesh construction is divided into measured substages.
- Safe data-only geometry work is moved off the main thread where beneficial.
- Main-thread generation-frame spikes are measurably reduced.
- Geological sampling cost is understood and improved where practical.
- Request latency and queue behavior are remeasured.
- Shutdown remains safe.
- Before-and-after benchmark results are documented.
- No geological or visual regression is introduced.

The main priority should be frame consistency, followed by generation throughput. More geological detail, ecosystems, and gameplay should wait until the measured streaming lag is under control.

1. `res://docs/session_7_readme.md`

```markdown
# Session 7 — Worker Geometry and Performance Stabilization

## Status

Session 7 is complete.

All Session 7 regression tests pass, and the accepted benchmark demonstrated a major reduction in main-thread terrain-presentation cost.

Session 7 established the performance baseline that later world-generation sessions must preserve.

---

## Purpose

Session 7 moved expensive terrain geometry preparation away from the main thread while preserving:

- Deterministic terrain output
- Exact shared chunk borders
- Stable chunk streaming
- Bounded queues
- Bounded memory
- Safe worker shutdown
- Existing terrain and geology behavior

The primary objective was to prevent chunk presentation from causing visible frame-time spikes.

---

## Final Architecture

Terrain generation follows this pipeline:

```text
ChunkCoordinator
    |
    v
ChunkGenerationScheduler
    |
    v
Background generation job
    |
    +--> TerrainSampler
    |       |
    |       +--> GeologySampler
    |       +--> TerrainChunkData
    |
    +--> Worker-side geometry preparation
            |
            +--> Vertex arrays
            +--> Normal arrays
            +--> UV arrays
            +--> Index arrays
            +--> Validated generation result
    |
    v
Bounded completion mailbox
    |
    v
Main-thread presentation
    |
    +--> Construct rendering resources
    +--> Attach completed WorldChunk
```

The worker performs the expensive numeric geometry preparation.

The main thread remains responsible for Godot rendering objects and scene-tree ownership.

---

## Core Responsibilities

### `TerrainSampler`

`TerrainSampler` produces deterministic terrain height samples.

When a geology snapshot is available, terrain height is based on:

```text
geological macro elevation
+ terrain detail noise
```

The detail-noise strength is adjusted by geological stability and boundary activity.

`TerrainSampler` does not own chunk scheduling or scene-tree presentation.

### `TerrainChunkData`

`TerrainChunkData` is the data-only output of terrain generation.

It contains:

- Chunk coordinate
- Cell count
- Cell size
- Height samples
- Optional retained `GeologyChunkData`

The retained geology channels support debugging and later gameplay queries without regenerating terrain.

### Worker geometry preparation

The worker converts terrain samples into render-ready numeric arrays.

This includes:

- Vertex positions
- Triangle indices
- Surface normals
- UV coordinates
- Geometry validation

The worker does not create or modify scene-tree nodes.

### `ChunkGenerationScheduler`

The scheduler manages:

- Pending requests
- Running jobs
- Completed results
- Dispatch budgets
- Worker concurrency
- Cancellation
- Result acknowledgement
- Shutdown

All queues remain bounded by configuration.

### Completion mailbox

Completed jobs enter a bounded mailbox before main-thread consumption.

The mailbox prevents unbounded result accumulation when workers temporarily complete jobs faster than the main thread presents them.

### `ChunkCoordinator`

The coordinator owns the runtime chunk lifecycle:

- Determines desired chunks
- Creates generation requests
- Submits work
- Polls completed jobs
- Presents completed chunks
- Removes obsolete chunks
- Tracks active chunks
- Performs orderly shutdown

The coordinator does not regenerate active terrain for debug queries.

### `WorldChunk`

`WorldChunk` owns the runtime representation of one active chunk.

It retains the accepted `TerrainChunkData`, allowing later read-only surface and geology inspection.

---

## Threading Contract

Background workers may operate on:

- Immutable generation snapshots
- Plain GDScript data objects
- Packed arrays
- Numeric terrain and geometry calculations
- Deterministic noise instances local to the job

Background workers must not:

- Add or remove scene-tree nodes
- Modify active `WorldChunk` nodes
- Read mutable scene state
- Create presentation-side ownership relationships
- Perform unbounded retries
- Mutate shared generation configuration

The main thread remains the only owner of scene-tree presentation.

---

## Determinism Contract

For identical inputs, generation must produce identical outputs.

The authoritative inputs include:

- World seed
- Generation version
- Subsystem seed derivation
- Chunk coordinate
- Grid settings
- Terrain settings
- Geology settings
- Sampling resolution

Generation must not depend on:

- Request order
- Worker assignment
- Worker completion order
- Frame timing
- Camera timing
- Dictionary iteration order
- Previous noise queries
- Positive versus negative chunk coordinates

---

## Shared-Border Contract

Adjacent chunks sample shared vertices from identical global sample coordinates.

Conceptually:

```text
chunk-local sample
    -> global integer sample
    -> world-space XZ
    -> deterministic terrain query
```

This prevents neighboring chunks from deriving border coordinates through separate floating-point accumulation.

The final height samples and worker-prepared geometry must agree at shared borders.

---

## Presentation Contract

Worker results are validated before presentation.

A result must not be attached if it is:

- Invalid
- Failed
- Cancelled
- Stale
- Associated with the wrong request
- Associated with an obsolete chunk
- Structurally incomplete

Successful results are acknowledged after presentation.

Cancelled or discarded results are acknowledged with the appropriate terminal state.

---

## Performance Baseline

The accepted Session 7 benchmark established approximately:

```text
Main-thread mesh construction: 0.55–0.63 ms
Sustained p99 frame time:      about 7.8 ms
Worker terrain sampling:       about 80 ms
```

These are representative measurements from the accepted benchmark environment, not universal hardware-independent limits.

The important architectural results are:

- Main-thread mesh construction is no longer a major frame spike.
- Frame-time behavior remains stable during streaming.
- Worker concurrency remains bounded.
- Queues settle after movement stops.
- Memory remains bounded.
- No generation failures occur.
- Shutdown completes safely.

Later sessions must compare against the same benchmark configuration rather than treating measurements from different machines or settings as equivalent.

---

## Benchmark Scene

The Session 7 benchmark scene is:

```text
res://benchmarks/session_7/session_7_benchmark.tscn
```

The benchmark runtime disables optional debug HUD work:

```text
enable_depth_gauge = false
```

Debug visualization must not contaminate generation benchmark comparisons.

---

## Benchmark Review Checklist

Review at least:

- Worker sampling duration
- Worker geometry-preparation duration
- End-to-end request latency
- Main-thread presentation duration
- Main-thread mesh-construction duration
- Pending queue high-water mark
- Running-job high-water mark
- Completion mailbox high-water mark
- Mailbox overflow count
- Failed generation count
- Cancelled generation count
- Recovery time after movement
- Whole-run frame percentiles
- Sustained frame percentiles
- Starting memory
- Peak memory
- Ending memory
- Final queue state
- Shutdown errors

A benchmark is not accepted merely because its average frame time is low.

Queue recovery, memory behavior, failures, and sustained percentiles are equally important.

---

## Regression Expectations

Session 7 requires continued success from the established suites, including:

```text
Session 3: 86 assertions
Session 4: 137 assertions
Session 5: 64 assertions
Session 6: 36 assertions
```

The project-specific Session 7 worker-geometry and benchmark checks must also pass.

Later intentional generation changes may update geological expected values, but they must not invalidate:

- Scheduling behavior
- Queue bounds
- Worker determinism
- Shared borders
- Negative-coordinate behavior
- Result acknowledgement
- Safe shutdown

---

## Non-Goals

Session 7 did not implement:

- New geological formations
- Ecosystems
- Resources
- Ocean rendering changes
- Terrain LOD
- GPU terrain generation
- Scheduler redesign for geological features
- Gameplay systems

Its purpose was performance architecture and stability.

---

## Rules for Later Sessions

Later generation work must not hide regressions by casually changing:

- Worker count
- Queue limits
- Dispatch budget
- Presentation budget
- Benchmark route
- Benchmark duration
- Chunk radius
- Chunk resolution

If generation becomes slower, measure and optimize the generation model before increasing concurrency.

Session 7 is the accepted performance foundation for Session 8 and beyond.
```

2. `res://docs/session_8_readme.md`

```markdown
# Session 8 — World Scale and Believable Macro-Geology

## Status

Session 8 is in progress.

Current status:

| Stage | Status |
|---|---|
| Stage 1 — World-scale contract and depth gauge | Complete |
| Stage 2A — Experimental hash-classified boundaries | Superseded |
| Stage 2B — Motion-derived divergent ridges and rifts | Implemented and passing tests |
| Stage 2C — Divergent inspection and benchmark validation | Active |
| Stage 3 — Convergent trenches and uplift | Not started |

The current authoritative generation version is:

```text
generation_version = 3
```

---

## Purpose

Session 8 establishes a believable large-scale ocean structure without attempting a complete tectonic simulation.

The project needs:

- Coherent seafloor regions
- Recognizable large terrain formations
- Deterministic generation
- Queryable geological channels
- Useful debugging tools
- Gameplay-appropriate scales
- Stable performance

The project does not need scientifically exhaustive plate mechanics.

Session 8 therefore treats geology as deterministic geological art direction supported by a lightweight plate model.

---

## Design Principle

The target is:

```text
Believable and coherent
not
exhaustive and physically complete
```

Players primarily experience:

- Depth
- Silhouette
- Visibility
- Traversable slopes
- Ridges
- Rift valleys
- Trenches
- Plains
- Drop-offs
- Large navigational landmarks

The implementation should support those experiences without adding systems that have no visible or gameplay value.

---

# Stage 1 — World Scale and Runtime Depth Inspection

## Status

Complete.

All Stage 1 tests pass:

```text
Session 8 Stage 1: 20 passed, 0 failed
```

## World-Scale Contract

The project uses the following scale:

```text
1 Godot world unit = 1 meter
```

World Y is elevation and increases upward.

Depth is positive downward from sea level:

```text
depth = sea level - elevation
```

Bottom clearance is:

```text
clearance = observer elevation - seafloor elevation
```

A positive clearance means the observer is above the seafloor.

A negative clearance means the observer is beneath the rendered terrain surface.

## Canonical sea level

Sea level is read from the initialized ocean surface.

The depth HUD does not maintain an independent duplicate sea-level constant.

## Active terrain surface query

The runtime can query the visible surface of an already-active chunk.

The query:

- Reads retained `TerrainChunkData`
- Does not invoke `TerrainSampler`
- Does not enqueue generation
- Does not create a worker job
- Does not alter streaming state
- Uses the same triangle split as the rendered mesh

The result is therefore the actual piecewise-planar rendered surface, not a separate bilinear approximation.

## Depth gauge

The debug depth gauge displays:

- Sea level
- Observer elevation
- Observer depth
- Seafloor elevation
- Seafloor depth
- Bottom clearance
- Active chunk coordinate
- Sea, observer, and seafloor markers

Marker meanings:

```text
S = sea surface
O = observer
F = seafloor
```

The gauge updates at a low fixed frequency and can be disabled for benchmarks.

## Important Stage 1 files

```text
res://world/scale/world_scale_contract.gd
res://world/terrain/terrain_surface_query.gd
res://world/terrain/terrain_surface_query_result.gd
res://debug/depth/debug_depth_gauge.gd
res://tests/session_8/session_8_stage_1_tests.gd
res://tests/session_8/session_8_stage_1_tests.tscn
res://docs/world_scale_contract.md
```

---

# Stage 2 — Divergent Ridges and Central Rifts

## Goal

Stage 2 creates the first recognizable macro-geological formation family:

```text
Divergent boundary
    -> broad positive ridge
    -> narrower negative central rift
```

This is a gameplay-compressed formation rather than a full-scale simulation of a real global mid-ocean ridge system.

---

# Stage 2A — Superseded Experimental Contract

Stage 2A introduced a temporary boundary classifier based on:

- World seed
- Canonically ordered plate IDs
- Deterministic hashing

That classifier was useful for proving:

- Stable plate-pair ordering
- Determinism
- Side-independent classification
- Query-order independence

However, inspection of the existing geology implementation showed that the project already had a better runtime basis:

- Deterministic plate sites
- Plate motion vectors
- Boundary normals
- Tangential directions
- Relative normal motion
- Relative shear motion

The hash-assigned classifier is therefore not authoritative.

The current runtime must not use two competing boundary-class definitions.

If no remaining runtime code references them, the following experimental files may be removed:

```text
res://world/geology/macro/macro_geology_query.gd
res://world/geology/macro/macro_geology_query_result.gd
res://tests/session_8/session_8_stage_2a_tests.gd
res://tests/session_8/session_8_stage_2a_tests.tscn
```

Do not remove files while another scene or script still references them.

---

# Stage 2B — Motion-Derived Divergent Terrain

## Status

Implemented.

The Stage 2B profile suite passes:

```text
Session 8 Stage 2B profiles: 14 passed, 0 failed
```

All previous regression suites also pass after updating the obsolete Session 6 ridge-support invariant.

## Authoritative runtime model

The authoritative divergent model is:

```text
GeologySampler
    + DivergentRidgeProfile
    + GeologyChunkData
```

`TerrainSampler` does not independently calculate ridges or perform another plate search.

It consumes:

```text
geology_data.macro_elevation
```

This keeps generated terrain and geological debug channels synchronized.

## Plate topology

Plate ownership uses a deterministic weighted power diagram.

For every world-space geology sample:

1. The nearest weighted plate site is selected.
2. The nearest competing plate site is selected.
3. Distance to their shared weighted boundary is estimated.
4. Relative plate motion is projected onto:
   - Boundary normal
   - Boundary tangent
5. The relationship is classified.
6. Geological channels are calculated.
7. Macro elevation is assembled.

Stable plate identity resolves exact candidate ties.

## Boundary classification

Boundary classification is based on relative plate motion.

Conceptually:

```text
Positive normal rate  -> compression
Negative normal rate  -> extension
Tangential rate       -> shear
```

The current lightweight classes are:

```text
INTERIOR
DIVERGENT
CONVERGENT
TRANSFORM
```

A boundary is divergent when extension is meaningful and sufficiently strong relative to shear.

A boundary is convergent when compression is meaningful and sufficiently strong relative to shear.

Otherwise, the relationship is transform-dominant.

This classification is deterministic geological art direction, not a complete stress simulation.

## Divergent ridge

The ridge is:

- Positive vertical relief
- Broad
- Smooth
- Centered on a divergent boundary
- Modulated by extension activity
- Modulated by oceanic plate affinity
- Modulated by limited regional variation
- Zero at non-divergent boundaries

The ridge profile uses an independent influence width rather than the older narrow general-boundary band.

## Central rift

The rift is:

- Negative vertical relief
- Centered on the divergent boundary
- Considerably narrower than the ridge
- Modulated by the same divergent activity
- Zero at non-divergent boundaries
- Stored independently from ridge uplift

The rift is not a trench.

It is a central depression inside a broader elevated divergent formation.

## Current tuning

The current gameplay-compressed defaults are:

```text
Plate cell size:       4096 m
Boundary influence:     700 m
Ridge influence:       1400 m from center
Rift influence:         180 m from center
Maximum ridge uplift:   180 m
Maximum rift depth:      70 m
```

These values are intentionally chosen for the current traversal and streaming scale.

They should only be changed after inspection of a known divergent location.

## Divergent channels

`GeologyChunkData` now stores:

### Identity

```text
primary_plate_ids
neighboring_plate_ids
boundary_classes
```

### General plate fields

```text
continental_affinity
boundary_proximity
compression_strength
extension_strength
shear_strength
```

### Divergent geometry

```text
ridge_influence
rift_influence
```

These are geometric proximity profiles.

### Divergent activity

```text
ridge_potential
rift_potential
```

These combine geometric influence with divergent activity.

### Divergent elevation

```text
ridge_elevation_contribution
rift_elevation_contribution
```

Ridge contribution is positive.

Rift contribution is negative.

### Other geology

```text
trench_potential
volcanic_potential
sediment_potential
macro_elevation
```

## Macro elevation

The current macro elevation is conceptually:

```text
-base depth
+ basin variation
+ ridge elevation contribution
+ rift elevation contribution
- trench contribution
+ continental collision uplift
+ transform/shear relief
```

The result is clamped so Session 8 does not generate exposed land:

```text
macro elevation <= -minimum seabed depth
```

## Terrain integration

`TerrainSampler` uses:

```text
final terrain elevation =
    geology macro elevation
    + detail noise * geological detail scale
```

Stable sediment regions reduce small-scale detail.

Active geological regions preserve somewhat stronger detail.

There is no duplicate ridge calculation in `TerrainSampler`.

---

# Updated Session 6 Invariant

The original Session 6 test assumed:

```text
ridge potential > 0
requires
extension strength > 0
```

That assumption became obsolete in Stage 2B.

`extension_strength` still uses the original narrow 700-meter boundary band, while ridge potential may remain active across the broader 1400-meter ridge profile.

The correct invariant is now:

```text
ridge or rift potential > 0
requires
boundary class == DIVERGENT
```

This preserves broad ridge shoulders without disconnecting them from their geological cause.

Session 6 continues to pass:

```text
Session 6: 36 assertions
```

Its determinism and border comparisons now include all Stage 2B channels.

---

# Stage 2C — Divergent Inspection and Validation

## Status

Active.

Stage 2C does not add another terrain feature.

Its purpose is to verify that Stage 2B is:

- Visible
- Coherent
- Correctly scaled
- Debuggable
- Performance-safe

## Debug map behavior

The geology debug map derives its geology seed from:

- World seed
- Generation version
- Geology subsystem identifier

With unchanged inputs, the map must be identical on every run.

This is intentional.

The map is regenerated through:

```text
GeologySampler.generate_region()
```

It therefore uses the current authoritative geology implementation.

## Debug-map generation version

The Stage 2C map must use:

```text
generation_version = 3
```

A version-2 map will derive a different geology subsystem seed and will not represent the current version-3 world.

## Debug-map modes

The current inspection map supports:

```text
Plate ownership
Continental affinity
Boundary class
Boundary proximity
Compression strength
Extension strength
Shear strength
Ridge influence
Rift influence
Ridge potential
Rift potential
Ridge elevation contribution
Rift elevation contribution
Trench potential
Volcanic potential
Sediment potential
Final macro elevation
```

The debug map reads stored `GeologyChunkData` channels.

It must not reproduce the geological formulas independently.

## Boundary-class colors

The Stage 2C map uses approximately:

```text
Divergent: orange/red
Convergent: violet/blue
Transform: yellow
No meaningful influence: dark neutral
```

## Debug-map controls

```text
Left Arrow  = previous mode
Right Arrow = next mode
R           = regenerate current map
M           = toggle feature marker
C           = center map on strongest ridge sample
```

Regenerating with `R` should produce the same map unless an input changed.

## Debug statistics

The inspection panel reports:

- World seed
- Generation version
- Map center
- Map resolution
- Minimum macro elevation
- Maximum macro elevation
- Divergent sample count
- Convergent sample count
- Transform sample count
- Strongest ridge coordinate
- Strongest ridge potential
- Strongest ridge uplift
- Strongest rift coordinate
- Strongest rift potential
- Strongest rift contribution

These coordinates provide known locations for later in-world inspection.

## Important Stage 2 files

```text
res://world/geology/macro/divergent_ridge_profile.gd
res://world/geology/geology_settings.gd
res://world/geology/geology_generation_snapshot.gd
res://world/geology/geology_chunk_data.gd
res://world/geology/geology_sampler.gd
res://debug/geology/geology_debug_map.gd
res://debug/geology/geology_debug_map.tscn
res://tests/session_8/session_8_stage_2b_profile_tests.gd
res://tests/session_8/session_8_stage_2b_profile_tests.tscn
```

Actual folder placement may vary if the geology files already existed under a different established path.

---

# Stage 2C Visual Acceptance Checklist

Inspect the following modes:

## Boundary class

Verify:

- Divergent, convergent, and transform relationships exist.
- Boundary corridors are coherent.
- The classifications are not random per pixel.
- Classifications follow plate relationships.

## Ridge influence

Verify:

- Ridges form broad corridors.
- Width is substantially larger than the rift width.
- Influence fades smoothly.
- Non-divergent boundaries receive no ridge influence.

## Rift influence

Verify:

- Rifts form narrow centerlines.
- Rift influence stays inside the ridge corridor.
- The line does not become an independent trench network.

## Ridge potential

Verify:

- Potential appears only at divergent relationships.
- Activity varies without fragmenting the corridor.
- Broad shoulders remain visible.

## Rift potential

Verify:

- Potential is centered on divergent boundaries.
- It remains narrower than ridge potential.
- It is absent from convergent and transform relationships.

## Elevation contributions

Verify:

```text
ridge elevation contribution >= 0
rift elevation contribution <= 0
```

## Final macro elevation

Verify:

- Ridges affect final terrain.
- Central rifts remain readable.
- Basin variation does not erase the formation.
- The terrain stays submerged.
- Formation transitions are smooth.

## In-world inspection

At the reported strongest ridge coordinate, verify:

- The ridge is recognizable at player scale.
- The formation is not a thin wall.
- The central rift reads as a depression inside the ridge.
- Slopes remain traversable.
- The depth gauge agrees with rendered terrain.
- No chunk seams appear.
- Streaming remains stable while crossing the formation.

---

# Stage 2C Performance Validation

The accepted Session 7 benchmark must be rerun with:

```text
generation_version = 3
enable_depth_gauge = false
```

Compare with the accepted Session 7 baseline.

Review:

- Worker geology sampling time
- Worker geometry-preparation time
- End-to-end request latency
- Main-thread mesh construction
- Main-thread presentation
- Queue high-water marks
- Queue recovery
- Mailbox overflow count
- Failed generation count
- Frame-time percentiles
- Memory start, peak, and end
- Final queue state
- Shutdown behavior

Expected results:

- Main-thread mesh construction remains near the Session 7 baseline.
- The additional ridge and rift calculations affect worker sampling only.
- Queues settle after movement stops.
- Memory remains bounded.
- No generation failures occur.
- No worker or shutdown errors occur.
- No recurring frame-time regression appears.

Do not conceal a sampling regression by increasing worker count or queue limits.

---

# Session 8 Test Matrix

Current expected suites include:

```text
Session 3: 86 assertions
Session 4: 137 assertions
Session 5: 64 assertions
Session 6: 36 assertions
Session 8 Stage 1: 20 passed
Session 8 Stage 2B profiles: 14 passed
```

The project-specific Session 7 regression and benchmark checks must also pass.

If the superseded Stage 2A implementation is removed, its old test scene is no longer part of the active matrix.

---

# Stage 2 Completion Criteria

Stage 2 is complete when:

- Version-3 divergent terrain is active.
- Ridge and rift channels are deterministic.
- Ridges are broad and coherent.
- Rifts are narrow and centered.
- Non-divergent boundaries receive no divergent relief.
- All channels remain continuous across chunk borders.
- Negative coordinates behave correctly.
- Synchronous and worker generation agree.
- Debug maps use the authoritative sampler.
- A divergent feature is confirmed in-world.
- The depth gauge agrees with rendered terrain.
- All active regression suites pass.
- Session 7 benchmark behavior remains acceptable.
- The obsolete hash classifier is retired.
- No duplicate geological implementation remains.

---

# Non-Goals

Session 8 Stage 2 does not implement:

- Full tectonic simulation
- Real-world spreading rates
- Stress tensors
- Crustal-age simulation
- Magma simulation
- Individual volcanoes
- Hydrothermal vents
- Resources or ecosystems
- Ocean shader changes
- Terrain LOD
- Scheduler redesign
- Increased worker limits
- Gameplay teleportation

---

# Next Stage

After Stage 2C is accepted, Stage 3 may address convergent boundaries.

The likely Stage 3 vertical slice is:

```text
Convergent boundary
    -> asymmetric trench depression
    -> overriding-side uplift
```

Stage 3 should remain similarly lean:

- Reuse the existing plate search.
- Add only channels required by visible terrain.
- Keep contributions independently queryable.
- Use deterministic side selection.
- Validate visually before expanding scope.
- Benchmark against the Session 7 baseline.
```

The key current status is: Session 7 is complete; Session 8 divergent generation is implemented and passing tests; Stage 2C still requires debug-map confirmation, in-world inspection, and the version-3 benchmark before Stage 2 is formally accepted.
# Procedural Ocean World with Macro-Geology

## Overview

This project is a deterministic, chunk-streamed underwater world built with Godot 4.7.1.

The terrain system creates a large-scale ocean floor containing:

- Divergent ridges and central rifts
- Hills and hill groups
- Terraces and geological steps
- Broad massifs and underwater mountains
- Interior depressions and ravines
- Convergent depressions
- Asymmetric trenches
- Overriding-side uplift
- Rare extreme-depth trench capability

The goal is not to simulate geology perfectly. The goal is to produce a believable, visually varied underwater world where a roughly 2-meter-tall player consistently encounters terrain worth exploring.

The terrain should not feel like an endless sloped plane or a world covered in procedural sand dunes.

---

## Current Status

Current authoritative generation version:

```text
Generation version: 5
```

Current project status:

| System | Status |
|---|---|
| Deterministic terrain generation | Complete |
| Bounded asynchronous chunk generation | Complete |
| Worker-side geometry preparation | Complete |
| Runtime depth gauge | Complete |
| Geological debug map | Working |
| Divergent ridges and rifts | Complete |
| Plate-interior structural relief | Complete |
| Convergent trenches and uplift | Implemented |
| Stage 3B regression tests | Passing |
| Visual inspection | Passing with one major tuning issue |
| Version-5 performance benchmark | Pending |
| Plate-boundary transition refinement | Next |

All active tests currently pass.

---

## Artistic Direction

The world is designed around a player approximately two meters tall.

Terrain should be judged from that perspective rather than only from a distant top-down view.

The desired experience is:

- The player should quickly see or recognize a direction worth exploring.
- Quiet terrain should still contain readable structure.
- Hills, cliffs, steps, ravines, mountains, and depressions should break up travel.
- Large formations should create recognizable regions and landmarks.
- Extreme formations should be uncommon enough to remain memorable.
- Terrain should provide contrast without becoming uniformly noisy.
- Sand dunes may eventually exist, but only as a restricted geological or sedimentary feature.

The project intentionally avoids using additional blanket noise as the main solution to visual flatness.

---

## World-Scale Contract

The project uses the following scale:

```text
1 Godot world unit = 1 meter
```

World Y is elevation and increases upward.

Depth is positive downward from sea level:

```text
depth = sea level - elevation
```

Bottom clearance is:

```text
clearance = observer elevation - seafloor elevation
```

The current seabed depth envelope is:

```text
Minimum seabed depth: 2 m
Maximum seabed depth: 1500 m
```

The seabed may approach to within two meters of the surface.

Positive relief is smoothly compressed near the surface so mountains are not simply cut into large flat tops.

Negative detail is similarly limited near the maximum depth boundary.

---

## Terrain Resolution

The current terrain configuration uses:

```text
Chunk size:       256 m
Cells per axis:   32
Vertex spacing:   8 m
Load radius:      4 chunks
Unload radius:    5 chunks
```

This creates the following practical feature hierarchy:

```text
1–8 m:        future rocks, ledges, debris, and human-scale detail
8–50 m:       small terrain structures
50–500 m:     hills, steps, scarps, and depressions
500 m–2 km:   massifs, mountains, and large basins
1 km or more: ridges, trenches, and plate-scale formations
```

Authoritative terrain formations should generally span several mesh cells. Features much narrower than approximately 32–64 meters may not be represented cleanly by the current mesh resolution.

---

## Terrain Architecture

The final terrain height is assembled from separate deterministic geological contributions.

Conceptually:

```text
final terrain elevation =
    plate and basin datum
    + divergent ridge contribution
    + central rift contribution
    + plate-interior hills
    + terraces and steps
    + massif contribution
    + interior depressions
    + broad convergent depression
    + axial trench contribution
    + overriding-side uplift
    + transform relief
    + limited terrain detail
```

Each major formation family remains independently queryable.

This makes it possible to:

- Debug individual terrain causes
- Test geological relationships
- Tune one formation without rewriting others
- Preserve deterministic generation
- Add future gameplay queries
- Associate ecosystems and resources with geological features

---

# Session 7 — Performance Foundation

## Status

Session 7 is complete.

Session 7 moved expensive geometry preparation away from the main thread while keeping rendering-resource creation and scene-tree ownership on the main thread.

The architecture remains the required performance foundation for later generation work.

## Generation Pipeline

```text
ChunkCoordinator
    |
    v
ChunkGenerationScheduler
    |
    v
Bounded worker job
    |
    +--> TerrainSampler
    |       |
    |       +--> GeologySampler
    |       +--> TerrainChunkData
    |
    +--> Worker geometry preparation
            |
            +--> Vertices
            +--> Normals
            +--> UVs
            +--> Triangle data
    |
    v
Bounded completion mailbox
    |
    v
Main-thread presentation
    |
    +--> ArrayMesh creation
    +--> WorldChunk attachment
```

Workers may perform deterministic numeric calculations and prepare packed arrays.

Workers must not:

- Add or remove scene-tree nodes
- Modify active chunks
- Read mutable scene state
- Create unbounded work queues
- Modify shared generation configuration

## Accepted Version-3 Benchmark

Three version-3 benchmark runs produced stable sustained-movement results.

Approximate three-run averages:

```text
Sustained frame p95:             6.846 ms
Sustained frame p99:             7.912 ms
Worker geology/terrain sampling: 82.094 ms
Worker geometry preparation:      6.783 ms
Accepted worker compute:         88.848 ms
Main-thread mesh construction:    0.570 ms
Accepted request latency:       262.888 ms
Peak process memory:            115.472 MiB
```

During sustained movement:

- No frames exceeded 16.67 ms.
- Queue growth remained bounded.
- The completed-result mailbox remained well below capacity.
- No generation failures occurred.
- Memory remained bounded.
- All queues returned to zero during recovery.

The large maximum frames occurred during initial editor settlement and did not recur during movement or recovery.

## Benchmark Rule

Later generation work must not hide regressions by increasing:

- Worker count
- Queue capacity
- Dispatch budget
- Presentation budget
- Chunk radius
- Benchmark duration
- Chunk resolution

Generation changes must be measured against the accepted configuration.

A new version-5 benchmark is still required after Stage 3 visual tuning is complete.

---

# Session 8 — Geological World Structure

## Stage 1 — Scale and Depth Inspection

Status: complete.

Stage 1 established:

- One world unit equals one meter.
- Sea level is read from the active ocean surface.
- Observer depth is measured from sea level.
- Seafloor elevation is read from retained active chunk data.
- Bottom clearance is measured against the rendered terrain surface.
- Debug surface queries do not regenerate terrain.
- Benchmark scenes can disable the depth gauge.

The depth gauge displays:

- Sea level
- Observer elevation
- Observer depth
- Seafloor elevation
- Seafloor depth
- Bottom clearance
- Active chunk coordinate

---

## Stage 2 — Divergent Ridges and Rifts

Status: complete.

Divergent formations use the existing deterministic plate model rather than a separate random boundary classifier.

Plate relationships are derived from:

- Deterministic plate sites
- Weighted plate ownership
- Plate motion vectors
- Boundary normals
- Relative normal movement
- Relative tangential movement

The resulting boundary classes are:

```text
INTERIOR
DIVERGENT
CONVERGENT
TRANSFORM
```

A divergent boundary produces:

```text
Broad positive ridge
    +
Narrow negative central rift
```

Current divergent defaults:

```text
Plate cell size:       4096 m
Boundary influence:     700 m
Ridge influence:       1400 m
Rift influence:         180 m
Maximum ridge uplift:   180 m
Maximum rift depth:      70 m
```

The ridge and rift channels are deterministic, continuous across chunks, and stored separately from final macro elevation.

---

## Stage 3A — Plate-Interior Structural Relief

Status: complete.

Stage 3A addressed the problem of plate interiors reading like tilted planes.

It added finite, deterministic, plate-attached formations:

- Hill groups
- Raised and lowered terraces
- Broad massifs
- Interior depressions

These features are not a blanket layer of high-amplitude noise.

Each plate receives deterministic feature descriptors controlling:

- Feature anchors
- Orientation
- Width
- Height or depth
- Ellipticity
- Hill count
- Terrace arrangement
- Massif eligibility
- Depression eligibility

The descriptors are derived from stable plate identity and generation seeds.

## Default Stage 3A Ranges

### Hills

```text
Count per plate: 5
Radius:          220–720 m
Height:           14–68 m
```

### Terraces

```text
Count per plate: 2
Length:          600–1700 m
Width:           160–420 m
Relief:            8–38 m
```

Terraces may be raised or lowered.

### Massifs

```text
Probability: 45%
Radius:      600–1300 m
Height:       90–280 m
```

Massifs use multiple overlapping profiles to avoid reading as simple symmetric hills.

### Interior Depressions

```text
Probability: 55%
Radius:      500–1200 m
Depth:        35–140 m
```

Interior features fade near plate boundaries so independently generated plate descriptors do not create direct discontinuities.

## Stage 3A Channels

```text
plate_interior_influence
hill_elevation_contribution
terrace_elevation_contribution
massif_elevation_contribution
interior_depression_elevation_contribution
combined_interior_elevation_contribution
surface_headroom_scale
```

Visual inspection confirmed that the current world contains interesting:

- Ravines
- Mountains
- Hills
- Terrain steps
- General elevation variation

The plate interiors no longer read exclusively as sloped planes.

---

## Stage 3B — Convergent Trenches and Uplift

Status: implemented and passing tests.

Stage 3B added convergent-boundary terrain with a larger vertical range.

A convergent formation consists of:

```text
Broad regional depression
    +
Narrower axial trench
    +
Deterministic asymmetric sides
    +
Overriding-side uplift
```

## Trench Depth Tiers

Trench tiers are selected deterministically per canonical plate pair.

```text
Ordinary trench target:  600 m total depth
Major trench target:    1000 m total depth
Extreme trench target:  1480 m total depth
Maximum terrain depth:  1500 m
```

Current probabilities:

```text
Major trench:   16%
Extreme trench:  4%
```

These values make very deep trenches uncommon landmarks rather than the default appearance of every boundary.

Target depths describe total depth below sea level. They are not blindly subtracted from the existing seabed.

For example:

```text
Existing seabed:       -300 m
Target trench floor:  -1000 m
Required contribution: -700 m
```

## Convergent Profile Defaults

```text
Broad influence width:       3000 m
Broad depression depth:       180 m
Descending-side trench width: 900 m
Overriding-side trench width: 450 m
Uplift width:                 1500 m
Uplift peak offset:            550 m
Maximum uplift:                600 m
```

The descending side is deliberately broader than the overriding side.

Overriding-side selection is deterministic:

- Continental affinity is used when the two plates differ meaningfully.
- Stable pair hashing resolves ambiguous cases.
- Reversing plate query order does not reverse the result.

## Stage 3B Channels

```text
convergent_influence
convergent_potential
convergent_depression_elevation_contribution

trench_influence
trench_potential
trench_tiers
trench_target_depth
trench_elevation_contribution

overriding_plate_ids
sample_is_on_overriding_plate
overriding_uplift_influence
overriding_uplift_potential
overriding_uplift_elevation_contribution
```

## Stage 3B Test Coverage

The active tests verify:

- Deterministic trench tiers
- Stable overriding-side selection
- Plate-order independence
- Correct asymmetric trench widths
- Uplift only on the overriding side
- Broad convergent depressions
- Axial trench contributions
- Total-depth targeting
- Valid channel signs and ranges
- Geological cause relationships
- Exact shared chunk borders
- Negative-coordinate behavior
- Deterministic repeated generation
- Final terrain inside the 2–1500 m depth envelope

All active tests pass.

---

# Current Visual Results

The current F5 world produces significantly more varied terrain than earlier generations.

Successful visual results include:

- Cool ravines
- Underwater mountains
- Large elevation changes
- Readable plate-interior formations
- More immediate exploration opportunities
- Greater vertical variety
- Terrain that no longer looks like only a gently sloped plane

The added formations are visible at the intended player scale.

---

# Known Visual Issue — Plate Boundaries

The primary current issue is that plate boundaries are too visually obvious and too abundant.

Observed behavior:

- Boundaries can appear sharp.
- Elevation changes can be too drastic.
- Boundary corridors occupy too much of the world.
- Multiple nearby boundaries can make the world feel divided into obvious cells.
- The geological construction is easier to see than the intended natural formation.

This is now the highest-priority terrain issue.

## Likely Causes

The current configuration uses:

```text
Plate cell size:             4096 m
Convergent influence width:  3000 m
Ridge influence width:       1400 m
Uplift width:                1500 m
Boundary warp amplitude:      600 m
```

A 3000-meter convergent influence width is large relative to a 4096-meter plate cell.

As a result, a large portion of the world can be influenced by boundaries rather than reading as a distinct plate interior.

Additional contributors may include:

- Every sufficiently convergent relationship receiving a readable formation
- Strong broad-depression depth
- Strong overriding uplift
- Rapid transitions between plate-interior and boundary terrain
- Competing boundary influences near plate corners
- Asymmetric profiles changing too quickly across the axis
- Strong elevation contributions overlapping in narrow regions

The problem should not be fixed by removing geological features entirely.

The correct goal is:

```text
Fewer visually dominant boundaries
+
Broader and smoother transitions
+
A hierarchy of weak and strong boundaries
```

---

# Next Stage — Boundary Hierarchy and Transition Refinement

The next pass should refine Stage 3 rather than add another unrelated feature family.

Proposed name:

```text
Stage 3C — Boundary Hierarchy, Blending, and Visual Validation
```

## Goals

### 1. Reduce dominant-boundary frequency

Not every plate boundary should create a major visible formation.

Relationships should be divided into tiers such as:

```text
Quiet boundary
Minor boundary
Active boundary
Major landmark boundary
```

Weak relationships may affect geological metadata without producing a large terrain wall or depression.

### 2. Preserve major landmarks

Strong divergent ridges and rare deep trenches should remain.

The goal is not to make all boundaries subtle. The goal is to prevent all boundaries from competing for attention.

### 3. Smooth elevation transitions

Boundary contributions should enter and leave the surrounding terrain gradually.

This includes:

- Broader outer fades
- Gentler contribution curves
- Reduced abrupt side changes
- Better blending with plate-interior relief
- Smoother treatment around boundary junctions

### 4. Reduce visible plate-cell structure

Players should recognize formations such as ridges and trenches, not the underlying plate partition.

Boundary warping should remain coherent, but plate ownership should not be visually obvious as a repeated network of cells.

### 5. Protect exploration density

Reducing boundary prominence must not return the world to featureless plates.

Plate interiors should continue to provide:

- Hills
- Terraces
- Ravines
- Massifs
- Depressions
- Readable routes and silhouettes

### 6. Retain uncommon extreme trenches

Extreme trench capability remains part of the design.

Rare trenches may approach:

```text
1500 m total depth
```

They should be identifiable regional landmarks rather than a common boundary treatment.

---

# Stage 3C Acceptance Criteria

Stage 3C will be accepted when:

- Plate ownership is not immediately obvious from ordinary F5 terrain.
- Most boundaries transition smoothly into nearby terrain.
- Weak boundaries do not all create drastic elevation changes.
- Major ridges and trenches remain visually recognizable.
- Rare extreme trenches remain possible.
- Plate interiors retain hills, terraces, mountains, and ravines.
- Terrain does not return to a universal dune-like appearance.
- Boundary junctions do not create artificial spikes or pits.
- Shared chunk borders remain exact.
- All active tests pass.
- Dedicated debug channels remain deterministic.
- The version-5 benchmark remains within the Session 7 performance envelope.

A generation-version increase should occur only if Stage 3C changes authoritative terrain output.

---

# Determinism Contract

For identical authoritative inputs, terrain must produce identical output.

Inputs include:

- World seed
- Generation version
- Subsystem seed
- Chunk coordinate
- Grid settings
- Geology settings
- Terrain settings
- Plate identity
- Feature-channel identifiers

Generation must not depend on:

- Request order
- Worker assignment
- Worker completion order
- Frame timing
- Camera timing
- Dictionary iteration order
- Previous noise calls
- Positive or negative world coordinates

---

# Shared-Border Contract

Adjacent chunks derive shared vertices from the same global integer sample coordinates.

```text
chunk-local sample
    -> global integer sample
    -> world-space XZ
    -> deterministic terrain query
```

All geological channels and final terrain heights must match exactly at shared chunk borders.

No formation may use chunk-local placement randomness.

---

# Debugging

The geological debug map reads authoritative `GeologyChunkData`.

It must not independently reproduce geological formulas.

Useful existing channels include:

```text
Plate ownership
Continental affinity
Boundary class
Boundary proximity
Compression
Extension
Shear
Ridge influence
Rift influence
Ridge potential
Rift potential
Macro elevation
Plate-interior influence
Hill contribution
Terrace contribution
Massif contribution
Interior-depression contribution
Convergent influence
Convergent potential
Trench influence
Trench potential
Trench tier
Trench target depth
Trench contribution
Overriding side
Overriding uplift
Surface headroom scale
```

The debug map must use the same generation version as the runtime world.

Current required value:

```text
generation_version = 5
```

---

# Important Files

## Core geology

```text
res://world/geology/geology_settings.gd
res://world/geology/geology_generation_snapshot.gd
res://world/geology/geology_chunk_data.gd
res://world/geology/geology_sampler.gd
res://world/geology/geology_plate_site.gd
res://world/geology/default_geology_settings.tres
```

## Divergent formations

```text
res://world/geology/macro/divergent_ridge_profile.gd
```

## Plate-interior formations

```text
res://world/geology/interior/plate_interior_relief_snapshot.gd
res://world/geology/interior/plate_interior_relief_descriptor.gd
res://world/geology/interior/plate_interior_relief_profile.gd
```

## Convergent formations

```text
res://world/geology/macro/convergent_relief_snapshot.gd
res://world/geology/macro/convergent_boundary_descriptor.gd
res://world/geology/macro/convergent_profile.gd
```

## Terrain integration

```text
res://world/terrain/terrain_sampler.gd
res://world/terrain/terrain_chunk_data.gd
res://world/terrain/terrain_surface_query.gd
res://world/terrain/terrain_surface_query_result.gd
```

## Debug tools

```text
res://debug/depth/debug_depth_gauge.gd
res://debug/geology/geology_debug_map.gd
res://debug/geology/geology_debug_map.tscn
```

## Stage 3 tests

```text
res://tests/session_8/session_8_stage_3a_tests.gd
res://tests/session_8/session_8_stage_3a_tests.tscn
res://tests/session_8/session_8_stage_3b_tests.gd
res://tests/session_8/session_8_stage_3b_tests.tscn
```

---

# Non-Goals

The current project does not attempt to implement:

- A scientifically complete tectonic simulation
- Real-world plate velocities
- Stress tensors
- Crustal-age simulation
- Fluid erosion
- Sediment transport simulation
- Magma simulation
- Individual volcano placement
- Hydrothermal vents
- Ecosystems
- Resources
- Terrain LOD
- GPU terrain generation
- Universal sand-dune coverage

These systems may be considered later only when they provide a clear visible or gameplay benefit.

---

# Immediate Roadmap

## Stage 3C

- Reduce excessive boundary prominence
- Add boundary-strength hierarchy
- Smooth drastic elevation transitions
- Improve blending at plate corners and junctions
- Preserve major trenches and ridges
- Extend debug inspection where needed
- Run the version-5 performance benchmark

## Later Regional Detail

- Add sparse scarps and fault blocks
- Add localized rough mountain summits
- Add trench-wall terraces
- Add coherent depth variation along trench corridors
- Add restricted sediment dune fields
- Measure feature and landmark coverage
- Prevent excessively large bland regions

## Later Gameplay Integration

Geological channels may eventually guide:

- Creature habitats
- Resource placement
- Navigation
- Sonar landmarks
- Lighting and fog regions
- Wreck placement
- Hazard regions
- Hydrothermal activity
- Story locations

---

# Current Conclusion

Session 7 established a stable asynchronous generation and presentation architecture.

Session 8 has now added:

- A formal meter-based world scale
- Runtime depth inspection
- Divergent ridges and rifts
- Plate-interior hills, terraces, massifs, and depressions
- Convergent depressions
- Asymmetric trenches
- Overriding-side uplift
- A final terrain depth range of 2–1500 meters

The current world is visually interesting and contains successful ravines, mountains, and varied terrain.

The next priority is not adding more formation types. It is making the existing plate boundaries less abundant, less sharp, and less visibly procedural while preserving rare major geological landmarks.
Agreed. Session 8 is ready to close once the final regression run confirms the trench changes. We should not call it complete until that gate passes.

SESSION 8 FINAL ACCEPTANCE GATE

Use generation version 9 for both:

default_world_definition.tres
geology_debug_map.tscn

Run and confirm:

1. All existing automated geology and terrain tests pass.
2. Adjacent chunks have identical shared-edge samples.
3. The origin remains inside the protected shallow province.
4. Macro elevation remains between -6000 m and -2 m.
5. Trenches do not appear in shallow provinces.
6. Most convergent boundaries do not produce trenches.
7. The three trench classes reach approximately:
   - Ordinary: 3,800–4,000 m
   - Major: 4,750–5,000 m
   - Extreme: 5,700–6,000 m
8. Extreme trenches remain rare.
9. Extreme trenches appear as elongated corridors rather than circular pits.
10. Extreme trenches retain a broad floor suitable for large fauna.
11. Macro and micro debug-map modes render correctly.
12. Debug-map panning and zooming work across negative and positive coordinates.
13. F5 generation remains stable while moving between chunks.
14. No new parser, resource-property, or null-snapshot errors appear.
15. Generation is deterministic for the same seed and version.

Do not change the world seed during final validation.

README UPDATE

Add or replace the Session 8 section in README.md with the following:

# Session 8 — Deterministic Macro-Geology

Status: Complete
Authoritative generation version: 9

Session 8 establishes the deterministic macro-geological foundation used by terrain generation, future biome selection, flora placement, fauna habitat selection, and environmental simulation.

The system does not attempt to run a full physical plate-tectonics simulation. Instead, it produces deterministic, art-directable geological relationships that remain continuous across chunk borders and are suitable for procedural gameplay systems.

## Goals

Session 8 provides:

- Deterministic plate ownership
- Continuous plate-boundary relationships
- Continental and oceanic affinity
- Divergent, convergent, and transform classifications
- Broad ridges and central rifts
- Plate-interior hills, terraces, massifs, and depressions
- Convergent uplift and broad depressions
- World-scale depth provinces
- Sparse 4 km, 5 km, and 6 km trench classes
- Exact shared-border continuity
- Macro- and micro-elevation debug visualization
- Stable generation from world seed and generation version

All geological distances, depths, and elevations are expressed in meters.

## Depth Contract

The authoritative seabed envelope is:

- Minimum seabed depth: 2 m
- Maximum seabed depth: 6,000 m

Depth values are literal world-space benchmarks and are not compressed into the previous 1,500 m range.

The broad province benchmarks are:

- Shallow shelf: approximately 2–300 m
- Deep slopes: approximately 800–1,800 m
- Abyssal transitions: approximately 1,500–3,000 m
- Abyssal plains: approximately 2,200–3,200 m

These ranges may overlap. They describe geological suitability and transition ranges rather than mutually exclusive biome bands.

Depth provinces are continuous influence fields. They are independent of plate ownership, allowing a single depth province to span multiple plates without exposing the plate-cell network.

A protected shallow region surrounds the initial world origin. This is a starting-area constraint, not a permanent biome assignment.

## Depth-Province Channels

GeologyChunkData exposes the following depth-province channels:

- shallow_province_influence
- deep_province_influence
- abyssal_province_influence
- province_transition_influence
- province_target_depth
- province_elevation_contribution

The shallow, deep, and abyssal influences form a normalized continuous membership set.

Province target depth establishes the broad seabed datum before local geological relief is applied.

## Plate-Boundary Formations

Plate boundaries are classified as:

- Interior
- Divergent
- Convergent
- Transform

Boundary classification is geological metadata. It does not automatically define a biome or ecosystem boundary.

### Divergent Boundaries

Divergent boundaries may produce:

- Broad ridge uplift
- Central rift depressions
- Increased volcanic potential
- Reduced local geological stability

### Convergent Boundaries

Convergent boundaries may produce:

- Broad depressions
- Asymmetric trench profiles
- Overriding-side uplift
- Increased volcanic potential
- Sparse trench corridors

Most convergent boundaries do not produce an axial trench.

### Transform Boundaries

Transform relationships currently provide:

- Shear metadata
- Minor signed relief
- Reduced stability

They do not automatically generate large walls or canyons.

## Trench Contract

Trenches only become visible in sufficiently deep provinces.

The three trench classes are:

### Ordinary trench

- Nominal target depth: 4,000 m
- Approximate target range: 3,800–4,000 m
- Pair-level probability: 18%
- Eligible in sufficiently deep lower provinces
- Narrowest of the three classes

### Major trench

- Nominal target depth: 5,000 m
- Approximate target range: 4,750–5,000 m
- Pair-level probability: 7%
- Strongly favors abyssal terrain
- Wider profile and floor than ordinary trenches

### Extreme trench

- Nominal target depth: 6,000 m
- Approximate target range: 5,700–6,000 m
- Pair-level probability: 3%
- Restricted to abyssal cores
- Rarest trench class
- Broadest floor and overall profile
- Intended to support major landmarks and very large fauna

The remaining 72% of eligible plate-pair rolls produce no axial trench.

Actual world frequency is lower than these pair probabilities because a visible trench additionally requires:

- A convergent relationship
- Sufficient convergence activity
- Subduction eligibility
- A compatible lower-depth province
- Distance from conflicting plate junctions

Extreme trenches are broad but remain elongated. Junction attenuation prevents large profiles from expanding into circular pits near three-plate intersections.

Trench target depth is a total seabed depth, not an amount blindly subtracted from the existing seabed.

## Plate Scale

The default plate-cell scale is:

16,384 m

The larger plate scale:

- Reduces excessive visible boundary density
- Produces longer geological relationships
- Gives major trenches room to form
- Prevents extreme trench width from consuming entire plate cells
- Improves the visual distinction between plate interiors and boundaries

## Terrain Composition

The final macro elevation combines:

- Continental or oceanic base depth
- Depth-province contribution
- Basin variation
- Ridge uplift
- Rift depression
- Broad convergent depression
- Trench contribution
- Overriding-side uplift
- Transform/shear contribution
- Plate-interior hills
- Terraces
- Massifs
- Interior depressions

Positive relief is softly limited near the water surface.

Final macro elevation is clamped only as a numerical safety guard to:

-2 m to -6,000 m

TerrainSampler then applies bounded micro elevation without exceeding the same seabed envelope.

## Macro and Micro Elevation

Macro elevation is the geological seabed generated by GeologySampler.

Micro elevation is defined as:

final terrain elevation - macro geology elevation

Micro elevation therefore represents the authoritative terrain-detail contribution applied by TerrainSampler.

The debug map reads generated TerrainChunkData rather than recreating the terrain-detail formula independently.

## Geology Debug Map

The geology debug map supports:

- Plate ownership
- Continental affinity
- Boundary class
- Boundary proximity
- Compression
- Extension
- Shear
- Ridge influence
- Rift influence
- Ridge potential
- Rift potential
- Ridge elevation contribution
- Rift elevation contribution
- Trench potential
- Volcanic potential
- Sediment potential
- Macro elevation
- Micro elevation

### Controls

- WASD: pan
- Shift + WASD: fast pan
- Q/E: zoom
- Mouse wheel: zoom
- Home: return to the world origin
- Left/Right: cycle visualization modes
- Tab: cycle visualization modes
- Shift + Tab: cycle backward
- G: macro-elevation mode
- T: micro-elevation mode
- R: regenerate
- M: toggle the feature marker
- C: center on the strongest visible ridge

Large map spans of 131,072 m or 262,144 m are recommended when searching for rare major or extreme trenches.

## Determinism and Continuity

Generation depends on:

- World seed
- Generation version
- Stable subsystem seeds
- Stable channel identifiers
- Stable spatial and plate-pair hashes
- World-space sampling coordinates

The same seed, generation version, settings, and world coordinate must produce the same result.

Adjacent chunks sample the same world coordinates at their shared border and must produce identical geological and terrain values.

## Authoritative Data Contract

Future systems should query geological data instead of reimplementing geology.

Relevant ecosystem inputs include:

- Final depth
- Macro elevation
- Micro elevation
- Depth-province influences
- Province transition influence
- Continental affinity
- Boundary class
- Compression
- Extension
- Shear
- Volcanic potential
- Sediment potential
- Ridge potential
- Trench potential
- Trench tier
- Plate-interior influence
- Stability derived from tectonic activity

Geological channels are environmental evidence. They are not fixed biome labels.

## Deliberate Limitations

Session 8 does not implement:

- Full physical tectonic simulation
- Erosion simulation
- Sediment transport
- Ocean currents
- Temperature simulation
- Nutrient transport
- Light attenuation
- Pressure gameplay
- Biome classification
- Flora placement
- Fauna populations
- Food webs
- Migration
- Ecological succession

Those systems should consume the deterministic geology contract rather than being embedded in it.

## Session 8 Completion Criteria

Session 8 is complete when:

- All geology tests pass
- Existing terrain regressions pass
- Shared chunk borders match exactly
- The origin remains safely shallow
- Depth provinces span the literal 2–6,000 m scale
- Trenches only appear in lower-depth provinces
- Ordinary, major, and extreme trench classes remain distinguishable
- Extreme trenches are rare, broad, and elongated
- Debug-map navigation works
- Macro and micro modes agree with generated terrain
- F5 generation remains deterministic and stable

SESSION 9 RECOMMENDATION

Session 9 should not treat “biome” as a single enum selected only from depth.

That would create rigid horizontal bands such as:

- shallow biome
- deep biome
- abyssal biome
- trench biome

Those bands would ignore geology, light, substrate, nutrients, slope, and local habitat structure.

Instead, Session 9 should introduce a deterministic ecosystem suitability layer.

Recommended scope:

Session 9A — Environmental query contract
Session 9B — Biome and habitat suitability
Session 9C — Flora distribution
Session 9D — Fauna populations and spawning
Session 9E — Ecosystem debug tools and validation

SESSION 9A — ENVIRONMENTAL QUERY CONTRACT

Create a single immutable environmental sample that future systems can query.

Conceptually:

EcosystemEnvironmentSample

Recommended fields:

- world_position
- seabed_elevation
- depth_below_surface
- macro_elevation
- micro_elevation
- local_slope
- local_roughness
- shallow_province_influence
- deep_province_influence
- abyssal_province_influence
- province_transition_influence
- continental_affinity
- volcanic_potential
- sediment_potential
- trench_potential
- trench_tier
- ridge_potential
- compression
- extension
- shear
- stability
- substrate weights
- light availability
- temperature
- nutrient availability
- current exposure
- pressure

Not all of these must receive complex simulation immediately.

For the Session 9 MVP:

- Light can be an analytic function of depth and water clarity.
- Pressure can be an analytic function of depth.
- Temperature can use broad deterministic regional fields plus depth.
- Nutrients can combine sediment, volcanic activity, currents, and regional noise.
- Current exposure can begin as a deterministic broad field.
- Substrate can be inferred from sediment, slope, volcanic activity, and roughness.

This produces a stable contract that can later accept better ocean simulation without rewriting biome, flora, or fauna systems.

SESSION 9B — BIOME AND HABITAT SUITABILITY

Biomes should use overlapping suitability weights.

For example:

- Sunlit shelf
- Kelp or macroalgae forest
- Temperate reef
- Volcanic reef
- Open sandy shelf
- Continental slope
- Deep rocky slope
- Abyssal sediment plain
- Hydrothermal vent field
- Cold seep
- Trench wall
- Trench floor
- Extreme-trench refuge

Each biome should define preferred ranges rather than exact boundaries.

Example:

Hydrothermal vent field suitability may depend on:

- High volcanic potential
- Ridge or convergent activity
- Appropriate depth
- Exposed rock substrate
- Local roughness
- Reduced sediment burial

Abyssal sediment plain suitability may depend on:

- High abyssal influence
- High sediment potential
- Low slope
- Low tectonic activity
- Low roughness

The output should be a collection of biome weights, not immediately a single winner.

A dominant biome can still be exposed for rendering or UI, but secondary weights should remain available for transition zones.

SESSION 9C — FLORA

Flora should be implemented before fauna because flora establishes:

- Shelter
- Food
- Occlusion
- Navigation structure
- Nursery habitat
- Resource distribution
- Visual biome identity

Recommended deterministic placement pipeline:

1. Query environmental suitability.
2. Select eligible flora species.
3. Generate stable world-space placement candidates.
4. Reject candidates based on slope, substrate, depth, and spacing.
5. Apply density from biome and species suitability.
6. Instantiate only candidates inside loaded chunks.
7. Preserve identity across unload and reload.

Flora categories could include:

- Kelp and macroalgae
- Seagrass
- Corals
- Sponges
- Tube worms
- Vent organisms
- Deep fungal or fictional analogues
- Trench-floor colonies

Each species definition should contain:

- Stable species ID
- Depth range
- Light preference
- Temperature preference
- Substrate preferences
- Slope limit
- Biome affinities
- Cluster radius
- Minimum spacing
- Density
- Scale range
- Orientation rules
- Optional resource value

Placement should use stable world-space seeds. It should not depend on chunk generation order.

SESSION 9D — FAUNA

Fauna should not be permanently generated as random decorative objects tied directly to terrain samples.

Use two layers:

1. Persistent population descriptors
2. Runtime creature instances

Population descriptors can define:

- Species
- Home region
- Population capacity
- Preferred biome weights
- Depth range
- Feeding requirements
- Territory radius
- School or solitary behavior
- Migration tendency
- Activity period
- Respawn or recovery rules

Runtime instances are then created from the population descriptor when the relevant region is loaded.

Suggested fauna scales:

Small fauna:
- Local deterministic schools
- Reef and flora association
- Limited persistence requirements

Medium fauna:
- Habitat territories
- Predator/prey relationships
- Broader movement between chunks

Large fauna:
- Sparse regional identities
- Persistent state
- Large navigation corridors
- Special spawning constraints

Extreme-trench fauna:
- Associated with a specific extreme-trench region
- Rare and persistent
- Able to use the broad trench floor
- Not spawned independently in every chunk
- Discoverable through environmental signs before direct encounter

The 6 km trenches should therefore become regional habitat anchors, not simple per-chunk spawn modifiers.

SESSION 9E — DEBUGGING

Add an ecosystem debug map with modes for:

- Depth
- Light
- Temperature
- Pressure
- Nutrients
- Current exposure
- Substrate
- Slope
- Roughness
- Individual biome suitability
- Dominant biome
- Flora density
- Flora candidate locations
- Fauna habitat suitability
- Population-region ownership
- Large-fauna territories

The debug map should reuse the Session 8 pan and zoom behavior.

It should support inspecting a world point and displaying all environmental values and selected biome weights.

RECOMMENDED SESSION 9 IMPLEMENTATION ORDER

1. Finalize the environment sample contract.
2. Add slope and roughness queries.
3. Add analytic light and pressure.
4. Add broad temperature, nutrient, and current fields.
5. Infer substrate weights.
6. Implement continuous biome suitability.
7. Add the ecosystem debug map.
8. Implement deterministic flora candidates.
9. Add two or three representative flora species.
10. Add persistent fauna population descriptors.
11. Add small-fauna schools.
12. Add one medium predator.
13. Add one rare extreme-trench fauna population.
14. Validate unloading, reloading, and deterministic identity.

SCOPE PUSHBACK

Biomes, flora, and fauna together are larger than Session 8.

To keep Session 9 testable, its completion target should be a vertical slice rather than a complete ecosystem catalog.

A good Session 9 completion target is:

- One environmental query contract
- Six to eight biome suitability profiles
- Four to six flora definitions
- Three small-fauna species
- One medium predator
- One rare extreme-trench species
- Deterministic placement and population identity
- An ecosystem debug map
- No full food-web or evolutionary simulation yet

That provides a believable ecosystem framework without locking the project into premature simulation complexity.

The immediate first coding task for Session 9 should be the environmental query contract and substrate/slope/light channels. Flora and fauna should consume that contract rather than query geology directly.
# Procedural Ocean World

## Overview

This project builds a deterministic, chunk-streamed underwater world in Godot 4.7.1. It focuses on believable macro-geology, queryable environmental conditions, overlapping biome suitability, and stable ecosystem-placement foundations.

The architecture deliberately separates:

- Deterministic data generation
- Worker-thread terrain sampling
- Main-thread scene presentation
- Environmental and biome queries
- Future flora and fauna presentation
- Generated identities from persistent save-state

## Current Status

- Godot version: 4.7.1
- World generation version: 9
- Development milestone: Session 9 complete
- Runtime status: F5 passes
- Regression status: Session 9, geology, and terrain tests pass

Session numbers and world-generation versions are separate concepts. Session 10 does not automatically require changing `generation_version`.

## Implemented Systems

### Deterministic World Generation

The world generation pipeline currently provides:

- Stable subsystem seeds
- Deterministic terrain and geology
- Chunk-independent world-space sampling
- Negative-coordinate support
- Seamless shared chunk boundaries
- Bounded asynchronous generation queues
- Stale-result rejection
- Deterministic chunk generation order
- Main-thread mesh creation from worker-produced data

### Macro-Geology

The geology system generates broad, readable formations rather than attempting a complete tectonic simulation.

Current geological features include:

- Plate-like regional structure
- Ridges
- Trenches
- Compression zones
- Extension zones
- Shear zones
- Volcanic potential
- Sediment potential
- Convergent potential
- Shallow, deep, and abyssal provinces
- Province transitions
- Ordinary, major, and extreme trench tiers

Geology is deterministic and remains consistent across chunk boundaries.

### Terrain

Terrain generation consumes geological signals and produces:

- Seabed elevation
- Macro and micro elevation structure
- Chunk mesh data
- Retained terrain data for runtime queries
- Continuous borders between adjacent chunks
- World-space surface lookup support

Expensive terrain and geology sampling occurs outside the main-thread presentation path.

### Environmental Sampling

`EnvironmentSampler` converts terrain and geology into queryable environmental conditions.

Current environmental channels include:

- Seabed elevation
- Depth below the ocean surface
- Macro elevation
- Micro elevation
- Local slope
- Local roughness
- Light availability
- Temperature
- Pressure
- Nutrient potential
- Current exposure
- Geological stability
- Volcanic potential
- Sediment potential
- Ridge potential
- Trench potential
- Trench tier
- Compression, extension, and shear signals
- Shallow, deep, and abyssal province influence
- Province transition influence
- Rock substrate
- Sand substrate
- Soft-sediment substrate
- Biological potential

Environmental sampling is deterministic and does not regenerate terrain.

### World-Position Environment Queries

The runtime supports environmental queries at arbitrary positions inside active chunks.

The query system provides:

- Bilinear terrain and geology interpolation
- Exact requested world positions
- Deterministic slope and roughness
- Canonical chunk ownership
- Negative-coordinate support
- Active-chunk-only queries
- No hidden generation or queue dispatch

Chunk domains use half-open ownership:

```text
[world_origin, world_origin + chunk_size)
```

A chunk owns its minimum X/Z edges. Its positive maximum edges belong to the adjacent positive-axis chunks. This prevents two chunks from claiming the same environmental or ecosystem candidate.

### Biome Suitability

Biome evaluation remains separate from `EnvironmentSample`.

The biome system produces overlapping raw suitability weights rather than forcing every point into one exclusive biome. Multiple biomes may therefore be suitable at the same location.

Current provisional biome profiles are:

1. Sunlit shelf
2. Rocky reef
3. Sandy shelf
4. Continental slope
5. Deep rocky slope
6. Abyssal sediment plain
7. Hydrothermal field
8. Trench wall
9. Trench floor
10. Extreme-trench refuge

Biome criteria can consume:

- Depth
- Light
- Temperature
- Nutrients
- Current exposure
- Geological stability
- Slope
- Roughness
- Substrate
- Biological potential
- Geological activity
- Province influence
- Trench potential and tier

Raw biome weights are not normalized to sum to one.

A deterministic dominant-biome result is also available for visualization and summary purposes. It does not replace the overlapping suitability data.

### Preliminary Flora Placement Foundation

Session 9 includes a deterministic flora-placement prototype.

It currently demonstrates:

- Stable world-space candidate grids
- Species-specific spacing
- Deterministic candidate jitter
- Stable candidate IDs
- Habitat suitability evaluation
- Biome affinities
- Patch and colony clustering
- Deterministic spawn rolls
- Deterministic scale and yaw
- Half-open chunk ownership
- No duplicate candidates between adjacent chunks
- Generation-order independence
- Active-chunk flora-data queries

The generated output is data only. It does not create flora Nodes or meshes.

The current flora catalog is provisional. Some prototype entries, such as vent tube worms, are not botanically flora and will be replaced during Session 10.

Session 10 will revise the catalog before visual flora integration.

## Runtime Architecture

The main runtime dependency flow is:

```text
Main
└── WorldDefinition
    ├── OceanSettings
    ├── WorldGridSettings
    ├── TerrainSettings
    ├── GeologySettings
    ├── EnvironmentSettings
    ├── ChunkStreamingSettings
    └── ChunkGenerationSettings

OceanWorld
├── SystemsRoot
│   ├── UnderwaterEnvironment
│   └── ChunkCoordinator
│
└── WorldContent
    ├── StreamedChunksRoot
    ├── OceanRoot
    │   └── OceanSurface
    └── DynamicEntitiesRoot
```

`WorldDefinition` is the authoritative runtime settings container.

`OceanWorld` passes the same `OceanSettings` resource to:

- `OceanSurface`
- `ChunkCoordinator`
- `EnvironmentGenerationSnapshot`

This ensures rendered sea level and environmental depth calculations use the same ocean height.

### Important Environment Resource Distinction

The project contains two different environment resource types.

Rendering environment:

```text
res://world/environment/underwater_environment.tres
```

Type:

```text
Environment
```

Used by `WorldEnvironment` for rendering, fog, lighting, and related visual settings.

Procedural environmental settings:

```text
res://world/environment/default_environment_settings.tres
```

Type:

```text
EnvironmentSettings
```

Used by environmental, biome, and ecosystem sampling.

These resources are not interchangeable.

## Generation Pipeline

The high-level generation flow is:

```text
World seed and generation version
            ↓
Stable subsystem seeds
            ↓
Geology generation
            ↓
Terrain generation
            ↓
Terrain mesh preparation
            ↓
Main-thread chunk presentation
            ↓
Environment sampling
            ↓
Overlapping biome suitability
            ↓
Deterministic ecosystem placement data
```

The dependency direction must remain one-way:

```text
Terrain and geology
        ↓
Environment
        ↓
Biome suitability
        ↓
Flora
        ↓
Fauna
```

Later systems may consume earlier systems, but earlier generation stages must not depend on flora or fauna.

## Threading Model

### Worker-Compatible Work

The following work is data-oriented and suitable for worker execution with isolated sampler instances:

- Geology sampling
- Terrain sampling
- Terrain mesh-data preparation
- Environmental sampling
- Biome suitability evaluation
- Flora candidate generation

### Main-Thread Work

The following remains on the main thread:

- SceneTree changes
- Node creation and deletion
- `ArrayMesh` creation
- Chunk presentation
- Future `MultiMeshInstance3D` creation
- Future flora and fauna presentation

Samplers containing mutable `FastNoiseLite` instances should not be shared concurrently between workers. Use one sampler set per worker or serialize access.

## Chunk Streaming

`ChunkCoordinator` currently manages:

- Desired chunk residency
- Priority ordering
- Bounded pending and running work
- Worker dispatch
- Completed-result consumption
- Stale-result rejection
- Retry limits
- Main-thread presentation budgets
- Active terrain chunks
- Runtime terrain queries
- Runtime environmental queries
- Preliminary flora-data queries
- Profiling

Flora and fauna presentation will use dedicated coordinators rather than continuing to expand `ChunkCoordinator`.

## Debugging Tools

### Environmental Debug Map

Scene:

```text
res://debug/environment/environment_debug_map.tscn
```

Run it directly with F6.

Current modes include:

- Depth
- Light
- Temperature
- Pressure
- Nutrients
- Current exposure
- Geological stability
- Slope
- Roughness
- Rock substrate
- Sand substrate
- Soft-sediment substrate
- Biological potential
- Dominant biome
- Ten individual biome-suitability modes

Controls:

```text
WASD             Pan
Shift + WASD     Fast pan
Q / E            Zoom
Mouse wheel      Zoom
Home             Return to origin
Left / Right     Cycle modes
Tab              Cycle forward
Shift + Tab      Cycle backward
B                 Dominant-biome mode
R                 Regenerate
Left click        Inspect a sample
```

Click inspection reports environmental values, geological signals, substrate composition, dominant biome, and the strongest overlapping biome weights.

### Generation Profiling

While the main runtime is active, press F9 to print the current generation profile.

The profiler tracks values such as:

- Sampling time
- Geometry-preparation time
- Main-thread mesh-build time
- Presentation time
- Total generation latency
- Pending work
- Running work
- Completed work
- Active chunks
- Stale results
- Failed results

Current validated performance has included approximately:

- Main-thread mesh creation around 0.6 ms
- Worker sampling around 80 ms
- Bounded queues that settle reliably
- No observed queue overflows during validated runs

These values are development measurements rather than fixed performance guarantees.

## Project Structure

The main world-generation directories are:

```text
res://world/
├── core/
│   ├── ocean_world.gd
│   ├── ocean_world.tscn
│   ├── world_definition.gd
│   └── default_world_definition.tres
│
├── coordinates/
│   ├── world_coordinates.gd
│   ├── world_grid_settings.gd
│   └── default_world_grid_settings.tres
│
├── chunks/
│   ├── chunk_coordinator.gd
│   ├── chunk_coordinator.tscn
│   ├── world_chunk.gd
│   ├── world_chunk.tscn
│   └── default_chunk_streaming_settings.tres
│
├── generation/
│   └── async/
│
├── geology/
│   ├── geology_settings.gd
│   ├── geology_generation_snapshot.gd
│   ├── geology_chunk_data.gd
│   └── default_geology_settings.tres
│
├── terrain/
│   ├── terrain_settings.gd
│   ├── terrain_generation_snapshot.gd
│   ├── terrain_chunk_data.gd
│   ├── terrain_sampler.gd
│   └── default_terrain_settings.tres
│
├── environment/
│   ├── environment_settings.gd
│   ├── environment_generation_snapshot.gd
│   ├── environment_sample.gd
│   ├── environment_sampler.gd
│   ├── default_environment_settings.tres
│   └── underwater_environment.tres
│
├── biomes/
│   ├── biome_ids.gd
│   ├── biome_evidence_channels.gd
│   ├── biome_criterion_snapshot.gd
│   ├── biome_profile_snapshot.gd
│   ├── biome_catalog_snapshot.gd
│   ├── biome_suitability_result.gd
│   └── biome_suitability_sampler.gd
│
├── flora/
│   ├── flora_ids.gd
│   ├── flora_channels.gd
│   ├── flora_criterion_snapshot.gd
│   ├── flora_species_snapshot.gd
│   ├── flora_catalog_snapshot.gd
│   ├── flora_placement_candidate.gd
│   ├── flora_chunk_data.gd
│   └── flora_placement_sampler.gd
│
└── ocean/
    ├── ocean_settings.gd
    ├── default_ocean_settings.tres
    ├── ocean_surface.gd
    └── ocean_surface.tscn
```

Debugging and tests are organized separately:

```text
res://debug/
└── environment/

res://tests/
└── session_9/
```

## Testing

Session 9 includes coverage for:

- Environmental ranges
- Deterministic environmental sampling
- Arbitrary world-position queries
- Half-open chunk ownership
- Negative coordinates
- Substrate normalization
- Pressure and light behavior
- Biome-catalog validation
- Overlapping biome suitability
- Trench-tier restrictions
- Hydrothermal suitability without light
- Flora-catalog validation
- Flora habitat suitability
- Stable flora IDs and transforms
- Adjacent-chunk flora ownership
- Generation-order independence

Recommended regression order:

1. Session 9 flora tests
2. Session 9 biome tests
3. Session 9 world-query tests
4. Session 9 environment tests
5. Session 8 geology tests
6. Terrain regression tests
7. Environmental debug map
8. F5 runtime validation

All tests pass at the Session 9 checkpoint.

## Versioning Policy

The project distinguishes between:

- Development session
- Global world-generation version
- Future subsystem-content versions
- Save-data schema version

Current values:

```text
Development milestone: Session 9 complete
Next development milestone: Session 10
Global generation version: 9
```

Do not change `generation_version` merely because development moves to Session 10.

The global generation version participates in subsystem seed derivation:

```gdscript
StableSeed.derive_subsystem_seed(
    world_seed,
    generation_version,
    subsystem_id
)
```

Changing it can alter terrain, geology, environment, and ecosystem placement simultaneously.

Future flora and fauna revisions should use independent catalog or subsystem-content versions where possible.

## Session 9 Completion

Session 9 established the environmental and ecosystem-query foundation.

Completed outcomes include:

- Stable terrain and macro-geology
- Environmental sampling
- Arbitrary active-chunk environmental queries
- Environmental debugging
- Overlapping biome suitability
- Dominant-biome visualization
- Stable ecosystem candidate identities
- Preliminary flora placement
- Runtime query integration
- Passing regression coverage

The recommended source-control checkpoint is:

```text
session-9-environment-biome-foundation
```

## Roadmap

### Session 10 — Flora in Full

Session 10 will replace the provisional flora prototype with the complete flora pipeline.

#### 10A — Flora Taxonomy and Catalog

Replace the provisional catalog with flora-only entries.

Recommended initial catalog:

```text
0 — Giant kelp
1 — Seagrass
2 — Reef macroalgae
3 — Red fan algae
4 — Coralline algae
```

This pass will:

- Remove vent tube worms from flora
- Remove ambiguous colony definitions
- Finalize environmental criteria
- Finalize biome affinities
- Define depth and light restrictions
- Ensure aphotic regions contain no photosynthetic flora
- Add flora-specific catalog and suitability tests

#### 10B — Placement Refinement

Complete the placement contract with:

- Surface normals
- Species spacing
- Patch structure
- Density controls
- Stable candidate ordering
- Negative-coordinate validation
- Shared-border validation
- Generation-order independence
- Vertical and slope restrictions

#### 10C — Flora Model Gallery

Create a standalone F6 scene containing procedural models for every flora species.

The gallery will validate:

- Scale
- Pivot placement
- Materials
- Geometry cost
- Surface attachment
- Two-sided rendering
- Sway weighting
- Species readability

#### 10D — Flora Materials and Sway

Create shared GPU-driven materials supporting:

- Height-weighted bending
- World-position phase variation
- Current direction
- Current strength
- Species-specific sway
- Stable bases and moving tips
- Nearly static coralline algae

#### 10E — MultiMesh Presentation

Dense flora will use `MultiMeshInstance3D`, not one Node per plant.

Generated data and presentation remain separate:

```text
FloraChunkData
    authoritative deterministic candidates

FloraChunkPresenter
    visual MultiMesh realization
```

#### 10F — FloraCoordinator

Create a dedicated runtime coordinator that responds to terrain chunk activation and deactivation.

It will:

- Generate flora data once per active chunk
- Cache authoritative flora data
- Build species MultiMeshes
- Remove flora presentation on chunk unload
- Restore identical transforms on reload
- Respect per-frame presentation budgets

#### 10G — Distance Thinning

Implement deterministic presentation thinning:

```text
Near chunks:   all accepted candidates
Middle chunks: stable-ID-based subset
Far chunks:    no individual flora or simplified coverage
```

Presentation thinning must never alter authoritative ecological data.

#### 10H — Flora Debugging and Acceptance

Add flora diagnostics for:

- Per-species suitability
- Placement probability
- Patch strength
- Accepted density
- Rendered density
- Stable IDs
- Surface normals
- Per-chunk counts
- Generation and presentation timing

### Session 11 — Fauna in Full

Session 11 will introduce fauna as a separate system.

Planned scope:

- Fauna taxonomy
- Species profiles
- Stable population descriptors
- Population home anchors
- Water-column placement
- Fauna model gallery
- Runtime creature presentation
- Basic movement
- Schooling
- Home-region constraints
- Grazing, fleeing, pursuing, and wandering states
- Fauna debugging
- Population persistence hooks
- Performance budgets

Fauna generation will create stable populations rather than permanent fixed positions for every individual animal.

### Session 12 — Biome Connection and Finalization

Session 12 will connect the completed flora and fauna systems and finalize biome definitions.

Planned scope:

- Audit actual generated biome distributions
- Revise provisional biome profiles
- Tune overlaps and dominance biases
- Connect biome suitability to flora support
- Connect flora and prey support to fauna
- Tune ecological density
- Identify empty or oversaturated habitats
- Build unified ecosystem diagnostics
- Verify streaming and deterministic identities
- Freeze biome, flora, and fauna IDs
- Decide whether a global generation-version bump is required

The final dependency direction will remain:

```text
Terrain and geology
        ↓
Environment
        ↓
Biome suitability
        ↓
Flora
        ↓
Fauna
```

## Design Principles

The project follows these rules:

1. World generation must be deterministic.
2. Chunk boundaries must not affect generated content.
3. Negative coordinates must behave correctly.
4. Expensive sampling should remain off the main thread where practical.
5. SceneTree changes remain on the main thread.
6. Generated data and visual presentation remain separate.
7. Ecosystem candidates use stable IDs rather than Node instance IDs.
8. Save-state will be stored separately from immutable generation data.
9. Biomes remain overlapping suitability fields.
10. Dominant biome is a visualization and summary result, not the sole ecological truth.
11. Flora and fauna receive dedicated coordinators.
12. Session numbers do not automatically change world-generation compatibility.
13. Later systems may consume earlier systems, but generation dependencies must not become circular.
