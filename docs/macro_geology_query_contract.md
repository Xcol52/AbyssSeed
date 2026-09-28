# Macro-Geology Query Contract

## Purpose

The macro-geology query provides stable relationships used to create
believable ocean terrain.

It is deliberately not a tectonic simulation.

## Inputs

The existing plate lookup remains responsible for determining:

- The primary plate ID
- The neighboring plate ID
- Distance to their shared boundary

The macro-geology query does not repeat plate-site searches.

## Canonical plate pairs

A boundary pair is always ordered by plate ID:

- canonical plate A = lower plate ID
- canonical plate B = higher plate ID

This ordering remains the same when the same boundary is queried from
either side.

## Boundary side

Signed boundary distance is:

- Negative on canonical plate A
- Positive on canonical plate B

The absolute distance remains identical across both sides.

This supports later asymmetric formations without requiring a full plate
motion model.

## Boundary classes

Each canonical plate pair receives one deterministic class:

- Divergent
- Convergent
- Transform

The class is derived from:

- World seed
- Canonical plate A ID
- Canonical plate B ID
- Boundary-model version

Query order, chunk coordinate, worker timing, and the current side do not
affect the result.

## Boundary strength

Boundary strength is a deterministic art-direction scalar.

It is not a physical spreading rate, force, or stress tensor.

It exists only to vary the visual strength of otherwise coherent
geological formations.

## Boundary influence

Boundary influence is a smooth proximity field:

- 1 at the boundary
- 0.5 at half of the configured width
- 0 at and beyond the configured width

Feature-specific ridge, rift, trench, and fault profiles may use narrower
or wider fields later.

## Generation versions

Creating and testing this contract does not alter terrain output.

Generation remains version 2 during Stage 2A.

The first authoritative divergent-ridge terrain output in Stage 2B will
increment generation from version 2 to version 3.
