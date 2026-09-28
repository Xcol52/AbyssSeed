# Atmospheric Dive Suit Audio

This directory contains diegetic audio for the player's atmospheric dive suit.

Expected assets:

- `breathing_idle.ogg`
  - Quiet breathing and suit ambience while the player is stationary or drifting.
  - Intended to loop continuously.

- `swimming_active.ogg`
  - Propulsive swimming, suit movement, and displaced-water audio while the player is actively moving.
  - Intended to loop continuously.

The runtime loads these files from their exact paths when they exist:

```text
res://audio/dive_suit/breathing_idle.ogg
res://audio/dive_suit/swimming_active.ogg
