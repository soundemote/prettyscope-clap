# Prettyscope CLAP DAW Test Checklist

Use this checklist when testing the current oscilloscope-plugin release surface in a DAW.

## Build Gate

From `C:\Users\argit\Documents\_PROGRAMMING\prettyscope-clap`:

```powershell
cmd.exe /d /c "call ""C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"" && cmake --build build-tracer && ctest --test-dir build-tracer --output-on-failure"
```

Expected:

- CLAP, VST3, and standalone artifacts build.
- `prettyscope-clap-tests` passes.

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

For Dot 1 and Dot 2:

1. Click `Save`.
2. Save the generated PNG.
3. Click `Load`.
4. Load the generated PNG or another small PNG/JPEG/BMP/GIF image.
5. Raise that dot's Image Mix control.
6. Click `Clear`.

Expected:

- Save writes a PNG.
- Load updates the dot status label.
- Image Mix fades generated dot drawing while adding the loaded texture.
- Clear returns the dot to Generated mode.
- Loaded images are normalized to a maximum 512 px longest side before plugin
  state storage.

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

## Known Watch Points

- Very large image files are resized for plugin state storage, but unusual image
  formats or extreme files should still be tested carefully.
- Current image rendering is an additive point-sprite override path, not the final visual polish pass.
- If a host saves immediately after an image load while audio is stopped, verify the session restore path carefully.
