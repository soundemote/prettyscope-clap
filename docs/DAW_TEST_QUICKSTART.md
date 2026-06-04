# Prettyscope CLAP DAW Test Quickstart

Use this when you are ready to do the first hands-on DAW test. The full checklist
is `docs\DAW_TEST_CHECKLIST.md`; this is the shorter path.
The expected visual controls are listed in `docs\VISUAL_CONTROL_MANIFEST.md`.
Host coverage is tracked in `docs\DAW_HOST_MATRIX.md`.

## 1. Prep The Test Package

From `C:\Users\argit\Documents\_PROGRAMMING\prettyscope-clap`:

To ask the tooling what to do next:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\show-daw-test-next-action.ps1
```

This includes generated readiness reports under `build-tracer` by default. Add
`-DocsOnlyReports` when you only want reports from `docs\test-reports`.
When a report is ready to fill or submit, the helper prints an open command for
the active report and, when available, the paired release summary.

To see status, latest artifacts, next action, and report index together:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\show-daw-test-dashboard.ps1
```

The dashboard also includes readiness reports under `build-tracer` by default.

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\test-daw-readiness.ps1 -Format CLAP -Daw "Your DAW" -Tester "Your Name"
```

The script prints paths for:

- a prefilled DAW test report
- a bundle manifest
- a verified bundle folder
- a verified bundle zip
- a release candidate summary

The blank report warnings are expected before DAW testing. Leave the generated
report open or keep its path handy.

To print the most recent report, summary, manifest, bundle folder, and bundle
zip paths again later:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\show-latest-daw-test-artifacts.ps1
```

Add `-OpenReport`, `-OpenSummary`, `-OpenBundleFolder`, or
`-OpenBundleZipFolder` when you want Windows to open the latest report, summary,
or bundle location directly.

## 2. Load Prettyscope In The DAW

1. Rescan plugins if the host does not already see Prettyscope.
2. Add Prettyscope as an audio effect/analyzer on a stereo track or bus.
3. Feed it a clear signal, such as a sine, synth, loop, or full mix.
4. Open the Prettyscope editor.

Expected:

- Audio passes through.
- The phosphor scope moves with the input.
- The snapshot inspector shows active input.

## 3. Exercise The Visual Controls

Touch each group enough to confirm it responds:

- Signal: Input Gain, Time Scale
- Beam: intensity, trace width, glow strength, glow width
- Phosphor: decay, fast decay, afterglow
- Dot 1: intensity, size, halo, image mix, rotation, aspect
- Dot 2: intensity, size, halo, image mix, rotation, aspect
- Dot Overall: intensity, size, halo, image mix
- Screen Burn: persistence, fast decay, afterglow, floor fade

Record anything that feels too sensitive, confusing, visually broken, or host
unstable.

## 4. Test Dot Image Overrides

Use the smoke-test PNG paths listed in the generated report under
`Dot Image Test Assets`.

For Dot 1 and Dot 2:

1. Click `Load`.
2. Load one of the smoke-test PNGs.
3. Raise Image Mix.
4. Move rotation/aspect.
5. Click `Save` and export the active loaded image PNG somewhere temporary.
6. Click `Clear`.

Expected:

- Loaded image dimensions appear in the status row.
- The soft-core PNG behaves like a round dot.
- The asymmetric streak makes rotation/aspect easy to see.
- Save exports the generated dot in Generated mode and the loaded/normalized
  image when an override is active.
- Clear returns the slot to generated mode.

Record the Dot 1 and Dot 2 generated/loaded PNG export paths in the generated
report under `Test Artifacts Produced`.

## 5. Test Preset And Session Restore

1. Load Dot 1 and Dot 2 smoke images.
2. Set non-default Dot Overall and Screen Burn values.
3. Save a Prettyscope preset.
4. Clear images and change a few controls.
5. Reload the preset.
6. Save the DAW project/session.
7. Close and reopen the DAW project/session.
8. Reopen the Prettyscope editor.

Expected:

- Dot labels return.
- Dot textures return without needing the original image paths.
- Image Mix, Dot Overall, and Screen Burn values match the saved state.

Record the preset name/path and DAW session/project path in the generated report
under `Test Artifacts Produced`.

## 6. Fill, Review, And Record The Report

Fill the generated report as you test. Then run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\review-daw-test-report.ps1 -ReportPath "PATH_FROM_READINESS_OUTPUT" -RequireComplete
```

Or review the newest incomplete report automatically:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\review-latest-daw-test-report.ps1 -RequireComplete
```

If the review finds missing fields, fill them in and rerun it.
The review includes Dot Image Test Assets, Test Artifacts Produced, visual
control groups, required result rows, visual notes, and release decision fields.
Complete reports are not automatically passing reports. If any required result
row is `fail`, if `Ready for next visual polish pass` is `no`, or if
`Needs code fix before more testing` is `yes`, submission records the matrix row
as `fix needed` instead of `pass`.
Any non-passing report must include at least one complete `Issues Found` row
with repro steps.

After the report passes review, preview the host matrix row:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\submit-latest-daw-test-report.ps1 -Preview
```

If the preview looks right, submit it:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\submit-latest-daw-test-report.ps1
```

Or submit a specific report path:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\submit-daw-test-report.ps1 -ReportPath "PATH_FROM_READINESS_OUTPUT" -Preview
```

And then:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\submit-daw-test-report.ps1 -ReportPath "PATH_FROM_READINESS_OUTPUT"
```

The submit command requires a complete report, updates the host matrix, validates
the matrix, prints release gates, and shows the dashboard for the default matrix.

## Highest-Value Notes

Capture these especially:

- DAW name/version and plugin format used
- whether the plugin scanned and opened cleanly
- whether audio passes through
- whether the scope follows real audio
- whether dot images save/load/restore
- whether DAW session reopen restores dot image state
- whether screen burn feels good, too permanent, or too weak
- any crash, hang, black OpenGL view, or UI weirdness
