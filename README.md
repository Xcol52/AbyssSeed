1. The Procedural Ocean World is a deterministic, chunk-streamed underwater engine built in Godot 4.7.1.
2. It uses GDScript, Forward+, FastNoiseLite, SurfaceTool, and ArrayMesh without external plugins.
3. The current development milestone is Session 9 complete, with authoritative generation version 9.
4. Runtime, geology, terrain, environmental, biome, and ecosystem-foundation regression tests pass.
5. One Godot world unit equals one meter, positive Y is upward, and depth increases below sea level.
6. World sessions are configured before entering the SceneTree and can be replaced without global state.
7. WorldDefinition owns seeds, compatibility versions, and typed subsystem settings.
8. The architecture separates deterministic generation, worker computation, and main-thread presentation.
9. Generated output depends only on explicit seeds, versions, settings, coordinates, and stable identifiers.
10. Generation is independent of frame timing, worker order, camera direction, and dictionary iteration order.
11. Negative coordinates use mathematical floor behavior and are covered by regression tests.
12. Adjacent chunks sample identical global border coordinates, ensuring seamless terrain.
13. Chunk ownership uses half-open world-space domains to prevent duplicate boundary content.
14. ChunkCoordinator manages bounded residency, scheduling, stale-result rejection, retries, and presentation.
15. Terrain and geometry calculations run in bounded background jobs using immutable request data.
16. SceneTree mutation, ArrayMesh creation, chunk attachment, and rendering presentation remain main-thread work.
17. Worker-prepared geometry reduced main-thread mesh construction to roughly 0.6 milliseconds.
18. Accepted benchmarks show bounded memory, stable queues, and sustained frame times below the 60 FPS budget.
19. The ocean uses one persistent procedural grid that recenters around the observer without rebuilding.
20. Ocean rendering remains independent of terrain chunk streaming and supports one primary observer.
21. Terrain generation retains data for surface, geology, environmental, and ecosystem queries.
22. Active-surface queries use retained chunk data and never secretly dispatch new generation.
23. Macro-geology uses deterministic plate-like regions rather than a complete physical tectonic simulation.
24. Geological relationships classify locations as interior, divergent, convergent, or transform.
25. Divergent boundaries can create broad ridges, central rifts, volcanism, and reduced stability.
26. Convergent boundaries can create broad depressions, asymmetric trenches, uplift, and volcanic potential.
27. Transform boundaries provide shear metadata and minor relief without automatically creating major walls.
28. Plate interiors include deterministic hills, terraces, massifs, ravines, and depressions.
29. Continuous depth provinces span shallow shelves, deep slopes, abyssal transitions, and abyssal plains.
30. The authoritative seabed depth envelope extends from 2 meters to 6,000 meters below sea level.
31. A protected shallow province surrounds the world origin to provide a safe starting region.
32. Most convergent boundaries produce no axial trench, keeping major formations uncommon.
33. Ordinary, major, and extreme trenches target approximately 4 km, 5 km, and 6 km depths.
34. Extreme trenches are rare, broad, elongated landmarks intended to support very large fauna.
35. Geological channels remain queryable and are environmental evidence rather than fixed biome labels.
36. EnvironmentSampler derives depth, slope, roughness, light, temperature, pressure, nutrients, and currents.
37. It also derives stability, substrate weights, biological potential, and geological activity signals.
38. Rendering Environment resources and procedural EnvironmentSettings resources are distinct and not interchangeable.
39. Environmental queries operate only on active chunk data and do not regenerate terrain.
40. Biome evaluation produces overlapping suitability weights instead of rigid horizontal biome bands.
41. Ten provisional profiles include shelves, reefs, slopes, abyssal plains, vents, and trench habitats.
42. Dominant biome selection exists for diagnostics but does not replace overlapping ecological suitability.
43. Session 9 includes deterministic, data-only flora candidates with stable IDs, transforms, and ownership.
44. Flora placement uses environmental suitability, biome affinity, spacing, clustering, and stable spawn rolls.
45. Flora currently has no runtime mesh presentation; dense presentation will later use MultiMeshInstance3D.
46. Debug tools include depth gauges, geology maps, environmental maps, sample inspection, and generation profiling.
47. The dependency direction remains terrain/geology → environment → biomes → flora → fauna.
48. Session 10 will finalize flora taxonomy, placement, procedural models, sway, MultiMesh presentation, and thinning.
49. Session 11 will add stable fauna populations, movement, schooling, predators, and rare trench species.
50. Session 12 will connect and tune the ecosystem while preserving determinism, streaming safety, and stable IDs.
