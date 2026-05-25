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
- the editor exposes the first descriptor-driven visual controls
- the editor hosts a JUCE/OpenGL `ScopeOpenGLView`
- `SimpleXyScopeRenderer` renders the current proof trace from snapshots
- `ScopeOpenGLView` accepts an injected `IScopeRenderer` for the future phosphor renderer

The next renderer milestone is to port the standalone golden phosphor scope into
that renderer slot without importing standalone app ownership or making JUCE/CLAP
the source of visual truth.

Useful local verification command on Windows:

```powershell
cmd.exe /d /c "call ""C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"" && cmake --build build-ninja && build-ninja\tests\prettyscope-clap-tests.exe"
```

See `docs/PLUGIN_BRIDGE_PLAN.md` for the current bridge sequence and boundaries.
