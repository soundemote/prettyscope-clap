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

Show the combined DAW test dashboard with:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\show-daw-test-dashboard.ps1
```

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

Print the latest generated report, manifest, bundle folder, and bundle zip
paths with:

```powershell
powershell -ExecutionPolicy Bypass -File ..\..\scripts\show-latest-daw-test-artifacts.ps1
```

Add `-OpenReport` to open the latest generated report.

Review a filled report before handoff with:

```powershell
powershell -ExecutionPolicy Bypass -File ..\..\scripts\review-daw-test-report.ps1 -ReportPath .\your-report.md
```

After strict review passes, preview and apply the matching host matrix update
from the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\update-daw-host-matrix-from-report.ps1 -ReportPath .\docs\test-reports\your-report.md -Preview
powershell -ExecutionPolicy Bypass -File .\scripts\update-daw-host-matrix-from-report.ps1 -ReportPath .\docs\test-reports\your-report.md
```

List generated reports and their completion state with:

```powershell
powershell -ExecutionPolicy Bypass -File ..\..\scripts\show-daw-test-report-index.ps1
```

Add `-IncludeBuildScratch` to also scan scratch reports under `build-tracer`.
Add `-IncompleteOnly` or `-CompleteOnly` to filter by review status. Add
`-OpenLatest` to open the newest report after filtering.
Use `-Quiet -PassThru` when another script needs structured report-index data.

The reviewer expects real Dot Image Test Assets, all visual control groups, all
required result rows, visual notes, and release decision fields before a report
is complete.

Use `-Quiet -PassThru` with `review-daw-test-report.ps1` when another script
needs structured completion and issue-count data.

Keep reports that capture useful host behavior, regressions, or release
decisions. Scratch reports can be written elsewhere with `-OutputPath`; parent
folders are created automatically.
