# Prettyscope CLAP Release Readiness Audit

This audit tracks the current first-testable oscilloscope plugin surface. It is
not a marketing release checklist yet; it separates locally verified work from
the DAW behavior that still needs hands-on testing.

## Locally Verified

- Plugin formats build: CLAP, VST3, and standalone wrapper.
- Tests run through CTest in `build-tracer`.
- Stereo audio is passed through and tapped for editor visualization.
- The editor hosts the OpenGL phosphor scope renderer.
- Visual parameter descriptors remain the source of truth for host parameters.
- Descriptor-adapted controls are visible in the editor.
- Dot 1 controls exist for intensity, size, halo, image mix, rotation, and
  aspect.
- Dot 2 controls exist for intensity, size, halo, image mix, rotation, and
  aspect.
- Overall dot controls multiply shared dot intensity, size, halo, and image mix.
- Screen Burn controls exist for persistence, fast decay, afterglow, and floor
  fade.
- Dot 1 and Dot 2 image controls exist for load, generated PNG save, and clear.
- Loaded dot images are uploaded to OpenGL textures and rendered through the dot
  image path.
- Dot image labels and PNG payloads are stored in patch XML state.
- Editor image state syncs into engine patch state for host/plugin state save.
- The local install script verifies copied CLAP/VST3 artifact paths, sizes, and
  timestamps after install.

## Local Verification Command

From `C:\Users\argit\Documents\_PROGRAMMING\prettyscope-clap`:

```powershell
cmd.exe /d /c "call ""C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"" && cmake --build build-tracer && ctest --test-dir build-tracer --output-on-failure"
```

For a local install handoff:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-test-install-local-plugin.ps1 -Format All -BuildDir build-tracer
```

## DAW Testing Still Required

Use `docs\DAW_TEST_CHECKLIST.md` to verify:

- The plugin scans and opens in the target DAW.
- Audio passes through in the host while the editor scope follows the signal.
- Dot 1, Dot 2, Overall, and Screen Burn controls feel usable with real audio.
- Loaded dot images render correctly at practical DAW frame rates.
- Preset save/reload restores dot images without needing original external
  files.
- DAW session save/reopen restores dot images and visual parameter values.
- Large image files do not create unacceptable host state size or save latency.

## Known Non-Release Gaps

- The loaded-image dot renderer is a first additive point-sprite path, not the
  final polished texture-brush renderer.
- Inherited Sidequest synth internals are still present by design; they should be
  quarantined only after DAW parameter/state behavior is proven.
- The editor control layout is functional, not final product UI design.
- Cross-platform package signing, installer polish, and host matrix testing are
  not done yet.
