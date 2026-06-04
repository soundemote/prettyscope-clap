# Prettyscope Visual Control Manifest

This manifest records the first DAW-test visual control surface. It should match
the descriptor-owned parameter layer in `src\scope\visual-parameters.h`.
Run `scripts\test-visual-control-manifest.ps1` after descriptor changes.

## Source Of Truth

- Descriptor registry: `src\scope\visual-parameters.h`
- Visual state: `src\scope\scope-visual-state.h`
- Patch/host adapter state: `src\engine\patch.h`
- Editor controls: `src\ui\main-panel.cpp`
- Renderer use: `src\ui\phosphor-scope-renderer.cpp`

Visual descriptor IDs and stable numeric IDs are the parameter identity source.
Sidequest/JUCE/CLAP host plumbing adapts to those descriptors.

## Automatable Visual Parameters

| Category | ID | Stable ID | Display | Default | Min | Mid | Max |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Signal | `input_gain` | 1002 | Input Gain | 1.0 | 0.1 | 1.0 | 8.0 |
| Signal | `time_scale` | 1003 | Time Scale | 1.0 | 0.25 | 1.0 | 4.0 |
| Beam | `beam_intensity` | 1001 | Beam Intensity | 1.6 | 0.0 | 1.0 | 4.0 |
| Beam | `beam_trace_width` | 1007 | Trace Width | 2.0 | 0.5 | 2.0 | 8.0 |
| Beam | `beam_glow_strength` | 1006 | Glow Strength | 0.35 | 0.0 | 0.35 | 2.0 |
| Beam | `beam_glow_width` | 1008 | Glow Width | 7.0 | 1.0 | 7.0 | 24.0 |
| Phosphor | `phosphor_decay` | 1000 | Phosphor Decay | 0.98 | 0.80 | 0.95 | 0.999 |
| Phosphor | `phosphor_fast_decay` | 1004 | Fast Decay | 0.25 | 0.0 | 0.25 | 1.0 |
| Phosphor | `phosphor_afterglow` | 1005 | Afterglow | 0.95 | 0.0 | 0.80 | 1.0 |
| Dot 1 | `dot1_intensity` | 1009 | Dot 1 Intensity | 1.0 | 0.0 | 1.0 | 4.0 |
| Dot 1 | `dot1_size` | 1010 | Dot 1 Size | 2.0 | 0.25 | 2.0 | 32.0 |
| Dot 1 | `dot1_halo` | 1011 | Dot 1 Halo | 0.35 | 0.0 | 0.35 | 4.0 |
| Dot 1 | `dot1_image_mix` | 1012 | Dot 1 Image Mix | 0.0 | 0.0 | 0.5 | 1.0 |
| Dot 1 | `dot1_rotation` | 1013 | Dot 1 Rotation | 0.0 | -180.0 | 0.0 | 180.0 |
| Dot 1 | `dot1_aspect` | 1014 | Dot 1 Aspect | 1.0 | 0.1 | 1.0 | 10.0 |
| Dot 2 | `dot2_intensity` | 1015 | Dot 2 Intensity | 0.45 | 0.0 | 1.0 | 4.0 |
| Dot 2 | `dot2_size` | 1016 | Dot 2 Size | 6.0 | 0.25 | 4.0 | 64.0 |
| Dot 2 | `dot2_halo` | 1017 | Dot 2 Halo | 0.65 | 0.0 | 0.5 | 4.0 |
| Dot 2 | `dot2_image_mix` | 1018 | Dot 2 Image Mix | 0.0 | 0.0 | 0.5 | 1.0 |
| Dot 2 | `dot2_rotation` | 1019 | Dot 2 Rotation | 0.0 | -180.0 | 0.0 | 180.0 |
| Dot 2 | `dot2_aspect` | 1020 | Dot 2 Aspect | 1.0 | 0.1 | 1.0 | 10.0 |
| Dot Overall | `dot_overall_intensity` | 1021 | Overall Dot Intensity | 1.0 | 0.0 | 1.0 | 4.0 |
| Dot Overall | `dot_overall_size` | 1022 | Overall Dot Size | 1.0 | 0.1 | 1.0 | 8.0 |
| Dot Overall | `dot_overall_halo` | 1023 | Overall Dot Halo | 1.0 | 0.0 | 1.0 | 4.0 |
| Dot Overall | `dot_overall_image_mix` | 1024 | Overall Dot Image Mix | 1.0 | 0.0 | 1.0 | 1.0 |
| Screen Burn | `screen_burn_persistence` | 1025 | Screen Burn Persistence | 0.98 | 0.80 | 0.95 | 0.9995 |
| Screen Burn | `screen_burn_fast_decay` | 1026 | Screen Burn Fast Decay | 0.25 | 0.0 | 0.25 | 1.0 |
| Screen Burn | `screen_burn_afterglow` | 1027 | Screen Burn Afterglow | 0.95 | 0.0 | 0.8 | 1.0 |
| Screen Burn | `screen_burn_floor_fade` | 1028 | Screen Burn Floor Fade | 0.00035 | 0.0 | 0.0005 | 0.01 |

## Non-Automatable Dot Image Workflow

Dot image controls are editor/state actions, not host automation parameters.

For Dot 1 and Dot 2:

- `Load` accepts a PNG/JPEG/BMP/GIF image on the UI thread.
- Loaded images are normalized to a maximum 512 px longest side before
  rendering and persistence.
- Loaded image labels and PNG payloads are stored in patch/plugin state, so
  presets and DAW sessions should restore without the original file path.
- `Save` writes the current generated dot PNG.
- `Clear` returns the slot to generated mode.
- Image Mix fades generated dot drawing while adding the loaded texture.

## DAW Test Expectations

- Dot Overall controls should multiply Dot 1 and Dot 2 behavior together.
- Screen Burn controls should change persistence without making the trace stay
  forever.
- The asymmetric smoke-test PNG should make rotation/aspect behavior obvious.
- The soft-core smoke-test PNG should behave like a round dot.
- Preset reload and DAW session reopen should restore loaded images and visual
  parameter values.
