Prettyscope
Source: https://github.com/soundemote/prettyscope-clap

Prettyscope is an OpenGL oscilloscope and signal visualizer for DAW audio.
This is an early build intended for testing the visual controls, audio input path,
dot image overrides, and screen-burn/phosphor behavior.

This zip contains plugin builds, usually CLAP, VST3, and a standalone executable
depending on the platform package.

To install the plugin, move the CLAP or VST3 bundle to the appropriate plugin folder.

On Windows:
- CLAP: C:\Program Files\Common Files\CLAP
- VST3: C:\Program Files\Common Files\VST3
- User-local CLAP: %LOCALAPPDATA%\Programs\Common\CLAP
- User-local VST3: %LOCALAPPDATA%\Programs\Common\VST3

On Linux:
- CLAP: ~/.clap or /usr/lib/clap
- VST3: ~/.vst3 or /usr/lib/vst3

After installing, rescan plugins in your DAW. Put Prettyscope on an audio track
or bus with signal flowing through it, then open the editor to see the scope.

If you have feedback or ideas, open an issue on the Prettyscope project:
https://github.com/soundemote/prettyscope-clap/issues

The Prettyscope CLAP source code is released under the MIT license, but the final product contains GPL3 dependencies
so this release is released under the GNU General Public License, 3 or later. You can read that license in the
file License.txt included here.
