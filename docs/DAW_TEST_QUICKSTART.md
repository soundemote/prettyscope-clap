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

To see status, latest artifacts, next action, and report index together:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\show-daw-test-dashboard.ps1
```

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\test-daw-readiness.ps1 -Format CLAP -Daw "Your DAW" -Tester "Your Name"
```

The script prints paths for:

- a prefilled DAW test report
- a bundle manifest
- a verified bundle folder
- a verified bundle zip

The blank report warnings are expected before DAW testing. Leave the generated
report open or keep its path handy.

To print the most recent report, manifest, bundle folder, and bundle zip paths
again later:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\show-latest-daw-test-artifacts.ps1
```

Add `-OpenReport`, `-OpenBundleFolder`, or `-OpenBundleZipFolder` when you want
Windows to open the latest report or bundle location directly.

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
5. Click `Save` and save the generated PNG somewhere temporary.
6. Click `Clear`.

Expected:

- Loaded image dimensions appear in the status row.
- The soft-core PNG behaves like a round dot.
- The asymmetric streak makes rotation/aspect easy to see.
- Clear returns the slot to generated mode.

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

## 6. Fill And Review The Report

Fill the generated report as you test. Then run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\review-daw-test-report.ps1 -ReportPath "PATH_FROM_READINESS_OUTPUT" -RequireComplete
```

If the review finds missing fields, fill them in and rerun it.
The review includes the Dot Image Test Assets section, visual control groups,
required result rows, visual notes, and release decision fields.

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
