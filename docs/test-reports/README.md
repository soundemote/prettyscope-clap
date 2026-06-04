# DAW Test Reports

Generated Prettyscope CLAP DAW test reports live here by default.

Create a prefilled report with:

```powershell
powershell -ExecutionPolicy Bypass -File ..\..\scripts\new-daw-test-report.ps1 -Format CLAP -Daw "Your DAW"
```

Ask for the next test/report action from the repository root with:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\show-daw-test-next-action.ps1
```

The next-action helper includes generated readiness reports under `build-tracer`
by default. Add `-DocsOnlyReports` when you only want reports from this folder.

Show the combined DAW test dashboard with:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\show-daw-test-dashboard.ps1
```

The dashboard uses the same default report scan.

Or run the full build/test/install/asset/report handoff from the repository
root:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\prepare-daw-test.ps1 -Format CLAP -Daw "Your DAW"
```

Add `-SkipBuildInstall` to the prep command when the installed artifacts are
already fresh and you only need another report.

The prep command creates Dot 1 / Dot 2 smoke-test PNGs and a bundle manifest by
default. It records image paths in the report. Add `-SkipDotImageAssets` or
`-SkipBundleManifest` only for reruns that do not need fresh handoff assets.

Add `-PassThru` to either command when automation needs generated paths as
pipeline output.

Print the latest generated report, release summary, manifest, bundle folder, and
bundle zip paths with:

```powershell
powershell -ExecutionPolicy Bypass -File ..\..\scripts\show-latest-daw-test-artifacts.ps1
```

From the repository root, open the latest report, release summary, and matching
bundle folder together with:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\open-daw-test-handoff.ps1
```

Verify the latest handoff matches the current repo commit with:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\test-daw-handoff-current.ps1 -RequireCurrent
```

Add `-OpenReport` to open the latest generated report or `-OpenSummary` to open
the latest release candidate summary.

Review a filled report before handoff with:

```powershell
powershell -ExecutionPolicy Bypass -File ..\..\scripts\review-daw-test-report.ps1 -ReportPath .\your-report.md
```

From the repository root, review the newest incomplete report automatically
with:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\review-latest-daw-test-report.ps1 -RequireComplete
```

After exporting the Dot 1 / Dot 2 generated and loaded PNGs, and after saving
the tested preset/session, fill those report fields with:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\update-daw-test-report-artifacts.ps1 -ReportPath .\docs\test-reports\your-report.md -Dot1GeneratedPng "path\to\dot1-generated.png" -Dot1LoadedPng "path\to\dot1-loaded.png" -Dot2GeneratedPng "path\to\dot2-generated.png" -Dot2LoadedPng "path\to\dot2-loaded.png" -PresetPath "path\to\preset" -SessionPath "path\to\session"
```

Fill result rows, visual notes, release decisions, or issue rows with:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\update-daw-test-report-fields.ps1 -ReportPath .\docs\test-reports\your-report.md -ResultArea "Scope follows input signal" -PassFail pass -ResultNotes "Trace follows the test signal."
powershell -ExecutionPolicy Bypass -File .\scripts\update-daw-test-report-fields.ps1 -ReportPath .\docs\test-reports\your-report.md -VisualNoteField "Trace appearance" -VisualNote "No reset line or dotted endpoints observed."
powershell -ExecutionPolicy Bypass -File .\scripts\update-daw-test-report-fields.ps1 -ReportPath .\docs\test-reports\your-report.md -ReadyForNextVisualPolish yes -NeedsCodeFixBeforeMoreTesting no -HighestPriorityFollowUp "Continue visual polish."
```

After strict review passes, preview and submit the matching host matrix update
from the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\submit-latest-daw-test-report.ps1 -Preview
powershell -ExecutionPolicy Bypass -File .\scripts\submit-latest-daw-test-report.ps1
```

Or submit a specific report path:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\submit-daw-test-report.ps1 -ReportPath .\docs\test-reports\your-report.md -Preview
powershell -ExecutionPolicy Bypass -File .\scripts\submit-daw-test-report.ps1 -ReportPath .\docs\test-reports\your-report.md
```

The submit command requires a complete report, updates and validates the host
matrix, then prints first-pass release gates.
Complete reports with any `fail` result row, a `no` value for
`Ready for next visual polish pass`, or a `yes` value for
`Needs code fix before more testing` are submitted as `fix needed` rather than
`pass`.
Reports with failed results or a code-fix decision must include at least one
complete `Issues Found` row with repro steps.

List generated reports and their completion state with:

```powershell
powershell -ExecutionPolicy Bypass -File ..\..\scripts\show-daw-test-report-index.ps1
```

Add `-IncludeBuildScratch` to also scan scratch reports under `build-tracer`.
Add `-IncompleteOnly` or `-CompleteOnly` to filter by review status. Add
`-OpenLatest` to open the newest report after filtering.
Use `-Quiet -PassThru` when another script needs structured report-index data.
The index reports each row as `incomplete`, `pass-ready`, or `fix-needed`.

Generated reports include a `Test Procedure` section that maps the DAW actions
to the result rows. The reviewer expects real Dot Image Test Assets, Test
Artifacts Produced fields, all visual control groups, all required result rows,
visual notes, and release decision fields before a report is complete.

Use `-Quiet -PassThru` with `review-daw-test-report.ps1` when another script
needs structured completion and issue-count data.

Keep reports that capture useful host behavior, regressions, or release
decisions. Scratch reports can be written elsewhere with `-OutputPath`; parent
folders are created automatically.
