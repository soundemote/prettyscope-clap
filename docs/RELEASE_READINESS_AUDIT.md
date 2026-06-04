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
- Loaded dot images are normalized to a maximum 512 px longest side before
  rendering/persisting.
- Dot image status labels show the active texture dimensions after load/restore
  and abbreviate long filenames for the compact editor row.
- Loaded dot images are uploaded to OpenGL textures and rendered through the dot
  image path.
- Dot image labels and PNG payloads are stored in patch XML state.
- Editor image state syncs into engine patch state for host/plugin state save.
- The local install script verifies copied CLAP/VST3 artifact paths, sizes, and
  timestamps after install.
- A local status script reports current build artifacts and installed plugin
  copies with paths, sizes, timestamps, SHA256 hashes, git revision, and install
  freshness.
- The status script supports `-RequireFresh` for machine-checkable local DAW
  test preflight.
- A report script generates prefilled DAW test reports from the current commit,
  installed artifact path, installed artifact SHA256, and dot image asset
  dimensions.
- Generated DAW test reports are kept in `docs\test-reports` by default.
- DAW prep/report scripts support `-PassThru` when automation needs the
  generated report path.
- A smoke-test asset script generates known-good PNGs for Dot 1 / Dot 2 image
  override testing.
- The one-command DAW prep script creates those dot image smoke-test assets by
  default and records their paths in the generated report.

## Local Verification Command

From `C:\Users\argit\Documents\_PROGRAMMING\prettyscope-clap`:

```powershell
cmd.exe /d /c "call ""C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"" && cmake --build build-tracer && ctest --test-dir build-tracer --output-on-failure"
```

For a local install handoff:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-test-install-local-plugin.ps1 -Format All -BuildDir build-tracer
```

The handoff script runs the strict freshness check after install.

For a complete DAW-test prep handoff:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\prepare-daw-test.ps1 -Format CLAP -Daw "Your DAW"
```

`prepare-daw-test.ps1 -SkipBuildInstall` is available for report-only prep after
strict freshness has already been verified.

## DAW Testing Still Required

Use `docs\DAW_TEST_CHECKLIST.md` to verify:

- Host-specific results are captured with `docs\DAW_TEST_REPORT_TEMPLATE.md`.

- The plugin scans and opens in the target DAW.
- Audio passes through in the host while the editor scope follows the signal.
- Dot 1, Dot 2, Overall, and Screen Burn controls feel usable with real audio.
- Loaded dot images render correctly at practical DAW frame rates.
- Preset save/reload restores dot images without needing original external
  files.
- DAW session save/reopen restores dot images and visual parameter values.
- Large image files are resized as expected and do not create unacceptable host
  state size or save latency.

## Known Non-Release Gaps

- The loaded-image dot renderer is a first additive point-sprite path, not the
  final polished texture-brush renderer.
- Inherited Sidequest synth internals are still present by design; they should be
  quarantined only after DAW parameter/state behavior is proven.
- The editor control layout is functional, not final product UI design.
- Cross-platform package signing, installer polish, and host matrix testing are
  not done yet.
