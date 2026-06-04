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
- Dot 1 and Dot 2 image controls exist for load, active PNG save, and clear.
- Save exports the generated texture in Generated mode and the loaded/normalized
  image when an override is active.
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
- Generated DAW test reports list the visual control groups under test.
- Generated DAW test reports are kept in `docs\test-reports` by default.
- A report review script checks filled DAW reports for blank essentials before
  handoff.
- DAW reports require concrete generated/loaded dot PNG export paths, preset
  name/path, and DAW session/project path before they are complete.
- A report index script lists generated DAW reports with completion state and
  issue counts.
- A report submit script requires complete DAW reports before updating the host
  matrix, then validates the matrix and prints release gates.
- Completed reports are only matrix `pass` candidates when all required result
  rows pass and the release decision is pass-ready; completed non-passing
  reports are submitted as `fix needed`.
- Release gates re-read linked reports and require pass-ready evidence, so a
  manually edited matrix `pass` row cannot satisfy gates with a non-passing
  report.
- A report classification smoke test verifies pass-ready reports, completed
  non-passing reports, matrix status updates, and forced-pass rejection.
- A next-action routing smoke test verifies incomplete-report, unsubmitted-
  report, submitted-but-not-ready, and ready-gate guidance.
- A next-action script recommends whether to prepare a test package, fill an
  incomplete report, or review completed reports.
- The next-action script and dashboard include generated readiness reports under
  `build-tracer` by default, with `-DocsOnlyReports` available for docs-only
  report scans.
- A DAW test dashboard script combines local plugin status, latest artifacts,
  next action, release gates, and report index output.
- A release candidate summary script writes a Markdown snapshot of local status,
  machine checks, release gates, next action, and latest DAW test artifacts.
- A bundle manifest script records built artifacts, installed artifacts, and
  DAW-test handoff files with SHA256 hashes.
- A bundle script assembles a local DAW-test folder/zip with artifacts, docs,
  helper scripts, smoke-test dot images, package copy, and manifest.
- A bundle verifier script checks local handoff folders/zips for required
  artifacts, docs, scripts, dot image assets, and manifest content.
- The bundle packager runs the verifier by default after creating the folder and
  zip.
- A DAW readiness script runs local freshness, report prep, self-verifying
  bundle creation, bundle verification, and report review smoke.
- The DAW readiness script writes a release candidate summary beside the
  generated report and bundle.
- The latest-artifact helper reports the release candidate summary and can open
  it with `-OpenSummary`.
- The readiness script avoids repeating the freshness check after its initial
  strict preflight.
- A DAW test quickstart gives the short first hands-on test path.
- DAW prep/report scripts support `-PassThru` when automation needs the
  generated report path.
- A smoke-test asset script generates known-good PNGs for Dot 1 / Dot 2 image
  override testing.
- The one-command DAW prep script creates those dot image smoke-test assets by
  default and records their paths in the generated report.
- The one-command DAW prep script creates a bundle manifest by default.
- Host-facing plugin identity is recorded in `docs\PLUGIN_IDENTITY_AUDIT.md`.
- The first DAW-test visual control surface is recorded in
  `docs\VISUAL_CONTROL_MANIFEST.md`.
- A visual control manifest verifier checks the manifest against
  `src\scope\visual-parameters.h`.

## Objective Coverage

| Requirement | Current Evidence | Remaining Gate |
| --- | --- | --- |
| Dot 1 controls | Descriptor/editor/renderer coverage for intensity, size, halo, image mix, rotation, and aspect. | Hands-on DAW usability. |
| Dot 2 controls | Descriptor/editor/renderer coverage for intensity, size, halo, image mix, rotation, and aspect. | Hands-on DAW usability. |
| Dot image override load/save workflow | Editor `Load`, active `Save`, and `Clear`; state stores PNG payloads and labels. | Host preset/session restore with real DAW reports. |
| Generated dot texture export | `Save` exports the generated texture in Generated mode. | Tester confirms exported PNG is usable in DAW workflow. |
| Loaded image export | `Save` exports the loaded/normalized image when an override is active. | Tester confirms loaded override export in DAW workflow. |
| Overall dot multipliers | Descriptor/editor/renderer coverage for shared intensity, size, halo, and image mix. | Hands-on visual feel with real audio. |
| Screen burn controls | Descriptor/editor/renderer coverage for persistence, fast decay, afterglow, and floor fade. | Hands-on decay feel with real audio and host frame pacing. |
| Release-path handoff | Quickstart, checklist, host matrix, report generator/reviewer, readiness script, bundle script, and bundle verifier. | At least one CLAP and one VST3 host report. |

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

For a full local DAW-readiness smoke:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\test-daw-readiness.ps1 -Format CLAP -Daw "Your DAW" -Tester "Your Name"
```

This checks strict installed-artifact freshness, visual manifest drift, release
audit drift, host matrix validity, report generation, bundle creation, bundle
verification, and blank-report review. Blank report warnings are expected until
hands-on DAW test results are filled in.

For the current DAW-test dashboard:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\show-daw-test-dashboard.ps1
```

For the immediate next DAW-test action:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\show-daw-test-next-action.ps1
```

For first-pass DAW release gates:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\show-daw-release-gates.ps1
```

For a saved release-candidate summary:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\new-release-candidate-summary.ps1
```

For submitting a completed hands-on DAW report:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\submit-daw-test-report.ps1 -ReportPath .\docs\test-reports\your-report.md -Preview
powershell -ExecutionPolicy Bypass -File .\scripts\submit-daw-test-report.ps1 -ReportPath .\docs\test-reports\your-report.md
```

For visual control manifest drift checks:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\test-visual-control-manifest.ps1
```

For release-readiness audit drift checks:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\test-release-readiness-audit.ps1
```

## DAW Testing Still Required

Use `docs\DAW_TEST_CHECKLIST.md` to verify:

- Host-specific results are captured with `docs\DAW_TEST_REPORT_TEMPLATE.md`.
- The short first-pass workflow is in `docs\DAW_TEST_QUICKSTART.md`.
- Host coverage is tracked in `docs\DAW_HOST_MATRIX.md`.

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
  final polished texture-brush renderer, but it now honors Dot 1 / Dot 2
  rotation and aspect controls.
- Inherited Sidequest synth internals are still present by design; they should be
  quarantined only after DAW parameter/state behavior is proven.
- The editor control layout is functional, not final product UI design.
- Cross-platform package signing, installer polish, and host matrix completion
  are not done yet.
