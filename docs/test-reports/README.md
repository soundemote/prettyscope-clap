# DAW Test Reports

Generated Prettyscope CLAP DAW test reports live here by default.

Create a prefilled report with:

```powershell
powershell -ExecutionPolicy Bypass -File ..\..\scripts\new-daw-test-report.ps1 -Format CLAP -Daw "Your DAW"
```

Keep reports that capture useful host behavior, regressions, or release
decisions. Scratch reports can be written elsewhere with `-OutputPath`.
