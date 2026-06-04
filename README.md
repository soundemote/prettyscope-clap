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
  fast decay, afterglow, Dot 1, Dot 2, overall dot multipliers, and screen burn
- the editor hosts a JUCE/OpenGL `ScopeOpenGLView`
- `ScopeOpenGLView` accepts an injected `IScopeRenderer`
- `PhosphorScopeRenderer` is the default renderer and ports the standalone
  golden beam/persistence core into the plugin editor
- Dot 1 and Dot 2 support generated PNG save, loaded image override, clear, and
  patch/session state persistence

The next renderer milestone is DAW/standalone verification with real audio input,
then adapter-level scale and image-dot polish if the hosted signal feels
different from the standalone golden reference.

Useful local build artifacts after a Windows build:

```text
build-tracer\prettyscope-clap_assets\CLAP\Prettyscope.clap
build-tracer\prettyscope-clap_assets\VST3\Prettyscope.vst3
build-tracer\prettyscope-clap_assets\Standalone-prettyscope-clap_standalone\Prettyscope.exe
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

This also verifies that the installed CLAP/VST3 copies match the build
artifacts.

To prepare a DAW test in one command, including build/test/install/freshness
verification plus a prefilled report:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\prepare-daw-test.ps1 -Format CLAP -Daw "Your DAW"
```

If the current installed artifacts are already fresh, add `-SkipBuildInstall` to
generate another report without rebuilding.

Add `-PassThru` when automation needs the generated report path as pipeline
output.

To check which build artifacts and user-local plugin copies are currently
present:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\show-local-plugin-status.ps1
```

Add `-RequireFresh` to make the status command fail when installed CLAP/VST3
copies are missing or stale:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\show-local-plugin-status.ps1 -RequireFresh
```

To create a prefilled DAW test report:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\new-daw-test-report.ps1 -Format CLAP -Daw "Your DAW"
```

Reports are written to `docs\test-reports` by default.
Add `-PassThru` to return the generated report path.

To create known-good PNGs for Dot 1 / Dot 2 image override testing:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\new-dot-image-test-assets.ps1
```

The default output folder is `build-tracer\daw-test-dot-images`.

For first visual testing, load Prettyscope as an audio effect/analyzer and feed
it a stereo signal. The plugin passes audio through while the editor scope reads
the same block stream.

Useful local verification command on Windows:

```powershell
cmd.exe /d /c "call ""C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"" && cmake -S . -B build-tracer -G Ninja && cmake --build build-tracer && ctest --test-dir build-tracer --output-on-failure"
```

See `docs/PLUGIN_BRIDGE_PLAN.md` for the current bridge sequence and boundaries.
See `docs/DAW_TEST_CHECKLIST.md` for the current hands-on test checklist.
See `docs/DAW_TEST_REPORT_TEMPLATE.md` for recording host-specific DAW results.
See `docs/RELEASE_READINESS_AUDIT.md` for locally verified release-prep status
and remaining DAW testing gates.
