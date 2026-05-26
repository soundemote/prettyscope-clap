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

This repo is not yet the finished Prettyscope plugin, but the first hosted
visualizer bridge is now in place:

- stereo host audio is passed through and tapped for visualization
- audio blocks are published through an editor-safe `ScopeAudioSnapshotQueue`
- visual parameter descriptors adapt into the Sidequest `Patch`/CLAP parameter path
- the editor exposes descriptor-driven visual controls for input scale, beam
  intensity, glow strength, trace width, glow width, time scale, phosphor decay,
  fast decay, and afterglow
- the editor hosts a JUCE/OpenGL `ScopeOpenGLView`
- `ScopeOpenGLView` accepts an injected `IScopeRenderer`
- `PhosphorScopeRenderer` is the default renderer and ports the standalone
  golden beam/persistence core into the plugin editor

The next renderer milestone is DAW/standalone verification with real audio input,
then adapter-level scale tuning if the hosted signal feels different from the
standalone golden reference.

Useful local build artifacts after a Windows build:

```text
build-ninja\prettyscope-clap_assets\CLAP\Prettyscope.clap
build-ninja\prettyscope-clap_assets\VST3\Prettyscope.vst3
build-ninja\prettyscope-clap_assets\Standalone-prettyscope-clap_standalone\Prettyscope.exe
```

To copy the built plugin artifacts into user-local Windows plugin folders for
DAW scanning:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install-local-plugin.ps1
```

To build, run tests, and install the local artifacts in one step:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-test-install-local-plugin.ps1
```

For first visual testing, load Prettyscope as an audio effect/analyzer and feed
it a stereo signal. The plugin passes audio through while the editor scope reads
the same block stream.

Useful local verification command on Windows:

```powershell
cmd.exe /d /c "call ""C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"" && cmake --build build-ninja && build-ninja\tests\prettyscope-clap-tests.exe"
```

See `docs/PLUGIN_BRIDGE_PLAN.md` for the current bridge sequence and boundaries.
