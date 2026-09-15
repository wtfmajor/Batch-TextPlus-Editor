# Batch-TextPlus-Editor
A Lua Script to change the text properties of multiple Text+ instances at once.

Installation

1. Save the script as a plain text file named Batch TextPlus Editor.lua.

2. Place the file into the appropriate directory based on your operating system:

Windows:
%APPDATA%\Blackmagic Design\DaVinci Resolve\Support\Fusion\Scripts\Utility\

macOS:
~/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts/Utility/

Linux:
~/.local/share/DaVinci Resolve/Fusion/Scripts/Utility/

Note: Create the Utility folder manually if it does not already exist.

---

How to Use

1. Open your project and timeline on the Edit page in DaVinci Resolve.

2. Mark your timeline region by moving the playhead before the first target Text+ clip and pressing I to set an In point, then moving after the last target clip and pressing O to set an Out point.

3. Open the script from the top menu by going to Workspace, then Scripts, then Batch TextPlus Editor.

5. Click Load First In Range to populate the tool with the settings from the first detected Text+ clip.

6. Adjust the settings you want to change. Changing a value automatically selects its Apply box. Uncheck any properties you do not want to overwrite.

7. Click Apply to Text+ in Range to update all target clips simultaneously.
