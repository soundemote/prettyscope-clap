# Prettyscope Plugin Bridge Plan

This repository is the CLAP/JUCE plugin shell for Prettyscope. The standalone
`prettyscope` repository remains the visual core and golden renderer reference.

## Current Checkpoint

- The project is renamed from `sidequest-startingpoint` to Prettyscope.
- The plugin builds CLAP, VST3, and standalone wrapper artifacts.
- The CLAP shell exposes one stereo input and one stereo output.
- Incoming host audio is passed through to the output.
- `Engine::scopeInput` stores the latest stereo block for visualization.
- `ScopeAudioSnapshot` defines the small stereo block shape the editor bridge
  will use next.
- `ScopeAudioSnapshotQueue` lets the audio side publish subscribed snapshots
  and lets the editor side drain to the newest available block.
- The editor subscribes to the snapshot queue while it exists and stores the
  latest block during its idle tick.
- Prettyscope visual float descriptors now adapt into the Sidequest `Patch` and
  `Param` system. Descriptor string IDs remain the visual source of truth, while
  descriptor stable numeric IDs become the host-facing CLAP/patch IDs.
- The editor's small `Visual Parameters` panel is descriptor-driven and exposes
  the first four adapted visual parameters through the existing Sidequest knob
  binding path.
- A tiny JUCE `ScopeSnapshotInspector` reads the latest subscribed audio
  snapshot and displays simple left/right input levels. This is only a bridge
  proof, not the OpenGL scope renderer.
- A first JUCE/OpenGL scope view exists in the editor and renders the latest
  snapshot as a simple XY line strip. This proves OpenGL lifecycle and
  audio-snapshot feeding before the golden phosphor renderer is ported.

## Near-Term Bridge

1. Port the standalone phosphor renderer into a reusable module boundary.

## Boundaries

- Do not move rendering ownership into CLAP or JUCE.
- Do not make CLAP/JUCE parameter types the source of truth.
- Do not redesign the current standalone Prettyscope look during bridge work.
- Keep the audio thread free of GUI or OpenGL dependencies.
- Defer inherited synth UI cleanup until descriptor-driven parameter UI and host
  state plumbing are proven stable.

## Future Shape

The plugin shell should adapt host state into Prettyscope core concepts:

- host automation to visual parameter descriptors
- host audio buffers to `ScopeAudioSnapshot`
- editor UI events to visual parameter changes
- OpenGL/JUCE lifecycle to reusable renderer create/destroy calls

The desired dependency direction is:

`CLAP/JUCE shell -> Prettyscope visual core`

The renderer should remain reusable outside this plugin shell.
