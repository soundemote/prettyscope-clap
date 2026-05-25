# Prettyscope CLAP

Prettyscope CLAP is the plugin-shell repository for Prettyscope, built from
`baconpaul/sidequest-startingpoint`.

The standalone/core visual renderer lives in the separate `prettyscope`
repository. This repository hosts the CLAP-first JUCE plugin integration.
Treat `prettyscope` as the golden standalone visual instrument and
`prettyscope-clap` as the DAW-facing host shell that adapts audio, parameters,
state, and editor lifecycle into that core.

Early integration goals:

- keep Prettyscope rendering code reusable and independent from JUCE/CLAP
- expose host parameters from Prettyscope visual descriptors
- add a stereo audio input path for DAW visualization
- render the golden phosphor scope look inside the plugin editor
- preserve sidequest-startingpoint license attribution

This repo is not yet the finished Prettyscope plugin. The first milestone is a
minimal hosted visualizer path: stereo host audio in, editor-safe signal snapshot,
OpenGL scope render out.

See `docs/PLUGIN_BRIDGE_PLAN.md` for the current bridge sequence and boundaries.
