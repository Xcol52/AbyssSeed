# World Scale Contract

## Units

One Godot world unit represents one meter.

Horizontal coordinates, vertical elevations, geological widths, and
geological amplitudes are therefore all measured in meters.

## Vertical axis

World Y is elevation and increases upward.

Sea level is not assumed to be zero. The canonical sea level is the
world-space Y position of the initialized configured ocean surface.

Examples:

- Sea level: 0 m
- Observer elevation: -600 m
- Observer depth: 600 m
- Seafloor elevation: -3,400 m
- Seafloor depth: 3.4 km
- Bottom clearance: 2.8 km

## Depth

Depth is positive downward from sea level:

depth = sea level - elevation

An object above sea level therefore has a negative depth.

## Bottom clearance

Bottom clearance is positive when the observer is above the seafloor:

clearance = observer elevation - seafloor elevation

A negative clearance means the observer is beneath the rendered
seafloor.

## Geological dimensions

All geological feature widths are horizontal distances in meters.

All geological terrain channels are signed vertical contributions in
meters.

Examples:

- Ridge contribution: +900 m
- Rift contribution: -250 m
- Trench contribution: -3,100 m
- Arc uplift: +700 m

Final seafloor elevation is the sum of the canonical geological
contributions defined by the generation model.

## Runtime seafloor queries

Debug bathymetry queries read TerrainChunkData retained by active
WorldChunk instances.

They do not invoke TerrainSampler, submit generation requests, or
regenerate geology.

The query uses the same triangle split and winding as the rendered
terrain mesh. It therefore reports the elevation of the visible
piecewise-planar terrain surface rather than a separate bilinear
approximation.
