# Prettyscope CLAP DAW Test Checklist

Use this checklist when testing the current oscilloscope-plugin release surface in a DAW.
Record host-specific results with `docs\DAW_TEST_REPORT_TEMPLATE.md`.
Compare expected controls against `docs\VISUAL_CONTROL_MANIFEST.md`.
Track host coverage in `docs\DAW_HOST_MATRIX.md`.
You can generate a prefilled report with `scripts\new-daw-test-report.ps1`.
Generated reports go to `docs\test-reports` by default.
For a shorter first pass, use `docs\DAW_TEST_QUICKSTART.md`.

## Build Gate

From `C:\Users\argit\Documents\_PROGRAMMING\prettyscope-clap`:

Next-action helper:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\show-daw-test-next-action.ps1
```

Dashboard:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\show-daw-test-dashboard.ps1
```

The next-action helper and dashboard include generated readiness reports under
`build-tracer` by default. Add `-DocsOnlyReports` to either command when you only
want reports from `docs\test-reports`.
When the next-action helper points at a report, it prints an open command for
the active report and, when available, the paired release summary.
The dashboard also includes a current report gap summary so missing DAW report
fields are visible without running another command.

Visual control manifest check:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\test-visual-control-manifest.ps1
```

Host matrix check:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\test-daw-host-matrix.ps1
```

Submit a completed report into the host matrix:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\submit-latest-daw-test-report.ps1 -Preview
powershell -ExecutionPolicy Bypass -File .\scripts\submit-latest-daw-test-report.ps1
```

Or submit a specific report path:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\submit-daw-test-report.ps1 -ReportPath .\docs\test-reports\your-report.md -Preview
powershell -ExecutionPolicy Bypass -File .\scripts\submit-daw-test-report.ps1 -ReportPath .\docs\test-reports\your-report.md
```

Host matrix summary:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\show-daw-host-matrix.ps1
```

First-pass release gate summary:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\show-daw-release-gates.ps1
```

Objective coverage summary:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\show-release-objective-coverage.ps1
```

Current report gap summary:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\show-daw-test-gaps.ps1
```

One-command DAW test prep:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\prepare-daw-test.ps1 -Format CLAP -Daw "Your DAW"
```

Create/apply a JSON answer sheet for the current report:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\new-daw-test-answer-sheet.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\apply-daw-test-answer-sheet.ps1 -AnswerPath "path\to\prettyscope-daw-test-answer-sheet.json" -RequireComplete
```

Full local readiness smoke:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\test-daw-readiness.ps1
```

Use `-SkipBuildInstall` only when strict freshness already passes and you only
need another report.

The prep command also creates known-good Dot 1 / Dot 2 image test PNGs, an
answer sheet, and a bundle manifest. The readiness command also writes a release
candidate summary next to the generated report and bundle. It records image
paths in the generated report. Use `-SkipDotImageAssets`, `-SkipAnswerSheet`, or
`-SkipBundleManifest` only for reruns that do not need fresh handoff assets.

The release candidate summary includes machine checks, release gates, next
action, latest artifacts, and the DAW report index with pass-readiness labels.

Add `-PassThru` when automation needs the generated report and bundle manifest
paths as pipeline output. The returned object also includes the generated answer
sheet path when answer-sheet creation is enabled.

After filling the report, review it for missing essentials:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\update-daw-test-report-artifacts.ps1 -ReportPath .\docs\test-reports\your-report.md -Dot1GeneratedPng "path\to\dot1-generated.png" -Dot1LoadedPng "path\to\dot1-loaded.png" -Dot2GeneratedPng "path\to\dot2-generated.png" -Dot2LoadedPng "path\to\dot2-loaded.png" -PresetPath "path\to\preset" -SessionPath "path\to\session"
```

Use the artifact update helper after exporting the generated/loaded PNGs and
saving the preset/session. Use the field update helper for result rows, visual
notes, release decisions, and issue rows:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\update-daw-test-report-fields.ps1 -ReportPath .\docs\test-reports\your-report.md -ResultArea "Scope follows input signal" -PassFail pass -ResultNotes "Trace follows the test signal."
powershell -ExecutionPolicy Bypass -File .\scripts\update-daw-test-report-fields.ps1 -ReportPath .\docs\test-reports\your-report.md -VisualNoteField "Trace appearance" -VisualNote "No reset line or dotted endpoints observed."
powershell -ExecutionPolicy Bypass -File .\scripts\update-daw-test-report-fields.ps1 -ReportPath .\docs\test-reports\your-report.md -ReadyForNextVisualPolish yes -NeedsCodeFixBeforeMoreTesting no -HighestPriorityFollowUp "Continue visual polish."
```

Alternatively, fill `prettyscope-daw-test-answer-sheet.json` and apply it once:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\apply-daw-test-answer-sheet.ps1 -AnswerPath .\docs\test-reports\prettyscope-daw-test-answer-sheet.json -RequireComplete
```

Then review the report:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\review-daw-test-report.ps1 -ReportPath .\docs\test-reports\your-report.md
```

Or review the newest incomplete report automatically:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\review-latest-daw-test-report.ps1 -RequireComplete
```

List generated reports and completion state:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\show-daw-test-report-index.ps1
```

Use `-IncompleteOnly -OpenLatest` to jump to the newest report that still needs
test results filled in.
The report index also shows `Result`: `incomplete`, `pass-ready`, or
`fix-needed`.

The reviewer checks session fields, preflight fields, Dot Image Test Assets,
Test Artifacts Produced, visual control groups, required result rows, visual
notes, and release decision fields. Add `-RequireComplete` when the report
should fail automation if any of those are incomplete.
Use `-Quiet -PassThru` when another script needs structured review data.
The reviewer also classifies completed reports as pass-ready only when every
required result row is `pass`, `Ready for next visual polish pass` is `yes`, and
`Needs code fix before more testing` is `no`. The submit helper records completed
non-passing reports as `fix needed`.
If a report has any failed result or says a code fix is needed, it must include
at least one complete `Issues Found` row with repro steps.

Optional handoff manifest:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\new-daw-test-bundle-manifest.ps1
```

Optional local handoff folder/zip:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\new-daw-test-bundle.ps1
```

The packager verifies the folder and zip by default.

Verify a handoff folder or zip before testing:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\test-daw-test-bundle.ps1 -BundlePath .\build-tracer\daw-test-bundle\your-bundle.zip
```

Build/test only:

```powershell
cmd.exe /d /c "call ""C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"" && cmake --build build-tracer && ctest --test-dir build-tracer --output-on-failure"
```

Expected:

- CLAP, VST3, and standalone artifacts build.
- `prettyscope-clap-tests` passes.
- Installed CLAP/VST3 copies match the build artifacts.

Optional status check:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\show-local-plugin-status.ps1 -RequireFresh
```

Expected:

- The status script reports installed CLAP/VST3 copies.
- Install freshness says the installed copies match the build artifacts by
  SHA256 hash.
- The command exits successfully.

Print the latest generated DAW test artifacts:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\show-latest-daw-test-artifacts.ps1
```

Open the latest report, release summary, and matching bundle folder together:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\open-daw-test-handoff.ps1
```

Verify the latest handoff matches the current repo commit:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\test-daw-handoff-current.ps1 -RequireCurrent
```

Optional switches: `-OpenReport`, `-OpenSummary`, `-OpenBundleFolder`, and
`-OpenBundleZipFolder`.

## Plugin Load

1. Install local artifacts with `scripts\install-local-plugin.ps1` or scan the `build-tracer` output directly.
2. Load Prettyscope as an audio effect/analyzer on a stereo track.
3. Feed the track a clear stereo signal.
4. Open the editor.

Expected:

- Audio passes through.
- The OpenGL oscilloscope appears.
- A moving phosphor trace is visible.
- The snapshot inspector reports active input.

## Visual Controls

Exercise these groups in the editor:

- Signal: `Input Gain`, `Time Scale`.
- Beam: intensity, core width, glow strength, glow width.
- Phosphor: persistence, fast decay, afterglow.
- Dot 1: intensity, size, halo, image mix, rotation, aspect.
- Dot 2: intensity, size, halo, image mix, rotation, aspect.
- Dot Overall: intensity, size, halo, image mix.
- Screen Burn: persistence, fast decay, afterglow, floor fade.

Expected:

- Dot Overall controls multiply Dot 1 and Dot 2 behavior.
- Screen Burn controls affect persistence without making the trace stay forever.
- Extreme values remain usable and do not crash the editor.

## Dot Image Workflow

If you did not use `prepare-daw-test.ps1`, create known-good PNGs for this test:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\new-dot-image-test-assets.ps1
```

The default output folder is `build-tracer\daw-test-dot-images`.
When generated by the prep command, the exact paths are also listed in the
report's `Dot Image Test Assets` section.

For Dot 1 and Dot 2:

1. Click `Save`.
2. Save the generated PNG while the slot is in Generated mode.
3. Click `Load`.
4. Load the generated PNG, one of the generated smoke-test PNGs, or another
   small PNG/JPEG/BMP/GIF image.
5. Raise that dot's Image Mix control.
6. Click `Save` again and confirm the loaded/normalized image can be exported
   as PNG.
7. Click `Clear`.

Expected:

- Save writes a PNG; in Generated mode it exports the generated dot texture, and
  with a loaded override it exports the active normalized image.
- The smoke-test soft-core image looks like a round dot, while the asymmetric
  streak makes rotation/aspect behavior easy to see.
- Load updates the dot status label with the active texture dimensions; long
  filenames may be abbreviated.
- Image Mix fades generated dot drawing while adding the loaded texture.
- Clear returns the dot to Generated mode.
- Loaded images are normalized to a maximum 512 px longest side before plugin
  state storage.
- The generated and loaded PNG export paths are recorded in the DAW report under
  `Test Artifacts Produced`.

## Preset Persistence

1. Load a Dot 1 image and a Dot 2 image.
2. Set non-default Dot 1, Dot 2, Overall, and Screen Burn controls.
3. Save a Prettyscope preset.
4. Clear both dot images and change several controls.
5. Reload the saved preset.

Expected:

- Parameters return to saved values.
- Dot status labels return to the saved image names.
- Loaded dot textures reappear without needing the original external file path.
- The preset name/path is recorded in the DAW report under
  `Test Artifacts Produced`.

## DAW Session Persistence

1. Load Dot 1 and Dot 2 images.
2. Set non-default image mix values.
3. Save the DAW project/session.
4. Close and reopen the DAW project/session.
5. Open the Prettyscope editor.

Expected:

- The editor restores the dot image labels.
- The loaded image textures reappear.
- Image Mix values and screen-burn values match the saved session.
- The DAW session/project path is recorded in the DAW report under
  `Test Artifacts Produced`.

## Known Watch Points

- Very large image files are resized for plugin state storage, but unusual image
  formats or extreme files should still be tested carefully.
- Current image rendering is an additive point-sprite override path, not the final visual polish pass.
- Loaded image overrides should follow Dot 1 / Dot 2 rotation and aspect controls.
- If a host saves immediately after an image load while audio is stopped, verify the session restore path carefully.
