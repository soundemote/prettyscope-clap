# Prettyscope DAW Host Matrix

This matrix tracks host coverage for the first Prettyscope CLAP oscilloscope
plugin test pass. Use host-specific DAW reports from `docs\test-reports` as the
evidence source for each row.
Run `scripts\test-daw-host-matrix.ps1` after matrix updates.
Run `scripts\show-daw-host-matrix.ps1` for a quick summary.
Run `scripts\show-daw-release-gates.ps1` to see which first-pass gates remain.
Release gates re-read linked reports and only count matrix `pass` rows when the
report itself is pass-ready.

Status values:

- `untested`: no hands-on report yet.
- `testing`: test started, report incomplete.
- `pass`: report complete, all required result rows pass, and release decision
  is pass-ready.
- `blocked`: host-specific issue prevents useful testing.
- `fix needed`: completed report has failures, the release decision says code
  fix needed, or a reproducible plugin issue needs code work before retest.

## Current Matrix

| Host | Format | OS | Status | Latest Report | Notes |
| --- | --- | --- | --- | --- | --- |
| Bitwig Studio | CLAP | Windows | untested |  | Priority CLAP host. |
| REAPER | CLAP | Windows | untested |  | Good CLAP/VST3 comparison host. |
| REAPER | VST3 | Windows | untested |  | Confirms fallback format behavior. |
| Ableton Live | VST3 | Windows | untested |  | Important non-CLAP production host. |
| FL Studio | VST3 | Windows | untested |  | Important Windows host; watch editor/OpenGL behavior. |
| Cubase/Nuendo | VST3 | Windows | untested |  | Optional early pass if available. |
| Standalone wrapper | Standalone | Windows | local smoke |  | Built as a quick editor/render sanity target, not a DAW substitute. |

## First-Pass Minimum

Before calling this first DAW-test surface ready for broader attention:

- At least one CLAP host should pass scan/open/audio/editor behavior.
- At least one VST3 host should pass scan/open/audio/editor behavior.
- At least one host should pass preset save/reload with Dot 1 and Dot 2 image
  overrides.
- At least one host should pass session save/reopen with Dot 1 and Dot 2 image
  overrides.
- Any black OpenGL editor, crash, failed scan, or lost dot image state should be
  marked `fix needed`.

## Update Procedure

1. Generate or locate a report with `scripts\show-daw-test-dashboard.ps1`.
2. Fill the report while testing the host.
3. Run `scripts\review-daw-test-report.ps1 -RequireComplete`.
4. Preview and submit this matrix row with:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\scripts\submit-daw-test-report.ps1 -ReportPath .\docs\test-reports\your-report.md -Preview
   powershell -ExecutionPolicy Bypass -File .\scripts\submit-daw-test-report.ps1 -ReportPath .\docs\test-reports\your-report.md
   ```

5. Keep detailed reproduction steps in the report, not in this matrix.

The submit command requires a complete report before writing, then runs matrix
validation and release gate review.
