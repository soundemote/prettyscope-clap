# DAW Test Reports

Generated Prettyscope CLAP DAW test reports live here by default.

Create a prefilled report with:

```powershell
powershell -ExecutionPolicy Bypass -File ..\..\scripts\new-daw-test-report.ps1 -Format CLAP -Daw "Your DAW"
```

Or run the full build/test/install/report handoff from the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\prepare-daw-test.ps1 -Format CLAP -Daw "Your DAW"
```

Add `-SkipBuildInstall` to the prep command when the installed artifacts are
already fresh and you only need another report.

Add `-PassThru` to either command when automation needs the generated report
path as pipeline output.

Keep reports that capture useful host behavior, regressions, or release
decisions. Scratch reports can be written elsewhere with `-OutputPath`; parent
folders are created automatically.
