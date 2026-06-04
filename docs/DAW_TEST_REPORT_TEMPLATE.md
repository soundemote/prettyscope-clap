# Prettyscope CLAP DAW Test Report

Use this template with `docs\DAW_TEST_CHECKLIST.md` when testing a specific
DAW/build combination.

## Session

- Date:
- Tester:
- DAW:
- DAW version:
- OS:
- Plugin format tested: CLAP / VST3
- Prettyscope commit:
- Installed artifact path:
- Installed artifact SHA256:
- Audio source used:

## Preflight

- `scripts\show-local-plugin-status.ps1 -RequireFresh` passed: yes / no
- Build artifacts matched installed artifacts: yes / no
- Notes:

## Dot Image Test Assets

- Asset paths/dimensions used:

## Results

| Area | Pass/Fail | Notes |
| --- | --- | --- |
| Plugin scans and loads |  |  |
| Audio passes through |  |  |
| Scope follows input signal |  |  |
| Snapshot inspector shows active input |  |  |
| Visual controls respond |  |  |
| Dot Overall multiplies Dot 1 / Dot 2 |  |  |
| Screen Burn controls decay/persistence |  |  |
| Dot 1 image load/save/clear |  |  |
| Dot 2 image load/save/clear |  |  |
| Large image resize behavior |  |  |
| Preset save/reload restores images |  |  |
| DAW session save/reopen restores images |  |  |
| Editor remains stable during close/reopen |  |  |

## Visual Notes

- Trace appearance:
- Screen burn feel:
- Dot image appearance:
- Control layout pain points:
- Performance/frame-rate notes:

## Issues Found

| Severity | Area | Description | Repro Steps |
| --- | --- | --- | --- |
|  |  |  |  |

## Release Decision

- Ready for next visual polish pass: yes / no
- Needs code fix before more testing: yes / no
- Highest-priority follow-up:
