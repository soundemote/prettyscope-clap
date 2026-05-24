# Prettyscope CLAP

Prettyscope CLAP is the plugin-shell repository for Prettyscope, built from
`baconpaul/sidequest-startingpoint`.

The standalone/core visual renderer lives in the separate `prettyscope`
repository. This repository hosts the CLAP-first JUCE plugin integration.

Early integration goals:

- keep Prettyscope rendering code reusable and independent from JUCE/CLAP
- expose host parameters from Prettyscope visual descriptors
- add a stereo audio input path for DAW visualization
- render the golden phosphor scope look inside the plugin editor
- preserve sidequest-startingpoint license attribution

This repo is not yet the finished Prettyscope plugin. The first milestone is a
minimal hosted visualizer path: stereo host audio in, editor-safe signal snapshot,
OpenGL scope render out.
