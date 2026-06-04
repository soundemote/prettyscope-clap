# Prettyscope CLAP Plugin Identity Audit

This note records the current host-facing identity for the first DAW-testable
Prettyscope plugin builds.

## Host-Facing Identity

- Product name: `Prettyscope`
- CLAP plugin ID: `com.soundemote.prettyscope`
- Bundle identifier: `com.soundemote.prettyscope`
- Vendor: `Soundemote`
- Vendor URL: `https://soundemote.com`
- Description: `OpenGL oscilloscope and signal visualizer.`
- CLAP features: audio effect, analyzer, stereo, free and open source
- Primary release/test formats: CLAP, VST3, standalone wrapper

## Source Locations

- Product name and bundle identifier: `CMakeLists.txt`
- CLAP descriptor: `src/clap/plugin-clap-entry-impl.cpp`
- Preset/user document vendor folder: `src/presets/preset-manager.cpp`
- Package README: `resources/ReadmeZip.txt`
- Nightly/package blurb: `resources/NightlyBlurb.md`

## Intentional Inherited Internals

This repository is still based on `baconpaul/sidequest-startingpoint`.
The internal namespace, some source comments, and parts of the inherited
engine/voice plumbing still use Sidequest names.

That is intentional for the current DAW-test checkpoint. The host-facing plugin
identity is Prettyscope/Soundemote, while Sidequest remains adapter plumbing
until parameter/state behavior has been tested in real DAWs.

Do not rename broad internal namespaces or remove inherited voice/MIDI plumbing
until DAW parameter, preset, session, and audio/editor behavior is proven.

## First-Test Copy Requirements

Tester-facing copy should describe Prettyscope as:

- an OpenGL oscilloscope and signal visualizer
- an audio effect/analyzer that passes audio through
- an early build for testing visual controls, dot image overrides, and
  screen-burn/phosphor behavior

Tester-facing copy should not describe Prettyscope as:

- a synth
- a MIDI instrument
- a Sidequest demo
- a finished release

## Next Identity Gates

- Verify the CLAP and VST3 names as displayed by the target DAWs.
- Verify DAW category placement as an audio effect/analyzer.
- Verify package README and nightly blurb are included in any zipped handoff.
- Revisit inherited synth/voice internals only after the first DAW test reports
  prove host state, automation, preset, and session behavior.
