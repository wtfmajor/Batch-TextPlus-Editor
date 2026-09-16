# Batch Text+ Editor Instructions

## Overview

Batch Text+ Editor lets you modify multiple selected Text+ clips directly from a floating DaVinci Resolve window.

Available controls include:

* Text content
* Font family
* Font style
* Font size
* Character spacing
* Line spacing
* Text color
* Opacity
* Center position
* Shading settings
* Batch undo and redo

## Installation

Place `Batch_TextPlus_Editor.lua` in the appropriate Resolve Utility Scripts folder.

### Windows

```text
C:\Users\YOURNAME\AppData\Roaming\Blackmagic Design\DaVinci Resolve\Support\Fusion\Scripts\Utility\
```

### macOS

```text
~/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts/Utility/
```

### Linux

```text
~/.local/share/DaVinciResolve/Fusion/Scripts/Utility/
```

Restart DaVinci Resolve after installing or replacing the script.

Open the editor from:

```text
Workspace > Scripts > Batch_TextPlus_Editor
```

## Selecting Text+ Clips

1. Open the Edit page.
2. Select one or multiple Text+ clips on the timeline.
3. Hold `Ctrl` on Windows or `Command` on macOS to select clips individually.
4. Hold `Shift` to select a continuous group of clips.
5. Click **Refresh** in the Batch Text+ Editor.
6. Confirm that the status area shows the correct number of selected clips and Text+ targets.

Only selected Text+ clips are processed. Regular video, audio, subtitle, and standard Text clips are ignored.

## Loading Existing Formatting

1. Select one or multiple Text+ clips.
2. Click **Load First Selected**.
3. The editor loads the formatting from the first selected Text+ clip.
4. All Apply checkboxes are cleared after loading.
5. Enable only the attributes you want to copy or change.

When multiple clips are selected, the first clip is determined by its position on the timeline.

## Applying Formatting

Each editable attribute has its own Apply checkbox.

1. Select the Text+ clips you want to modify.
2. Change the desired settings in the editor.
3. Confirm that the correct Apply checkboxes are enabled.
4. Click **Apply to Selected Text+**.

Editing most formatting fields automatically enables the matching Apply checkbox.

Text replacement does not enable itself automatically. You must manually check the Text Apply box before the script will replace text content.

Use **Clear Apply Checks** to disable every Apply checkbox.

## Changing the Font

1. Select the Text+ clips.
2. Choose a font from the **Font family** dropdown.
3. Choose an available style from the **Font style** dropdown.
4. Click **Apply to Selected Text+**.

The style list updates when the font family changes.

## Changing the Text Color

1. Click **RGB Picker**.
2. Select a basic color or choose a color from the hue and saturation grid.
3. Adjust Hue, Saturation, Value, Red, Green, or Blue if needed.
4. You can also enter an HTML hex value such as `#FFFFFF`.
5. Click **OK**.
6. Click **Apply to Selected Text+**.

The color picker automatically enables the Text Color Apply checkbox.

## Copying Shading Settings

Shading copy requires exactly one selected Text+ source.

1. Select one Text+ clip containing the shading you want to copy.
2. Click **Copy From Selected**.
3. Confirm that the status area reports the copied shading settings.
4. Select one or multiple destination Text+ clips.
5. Click **Paste to Selected Text+**.

The shading clipboard remains available while the editor window is open.

The script copies only enabled shading elements. Disabled shading elements from the source will not erase shading on the destination clips.

Copied shading settings can include:

* Element enabled state
* Appearance
* Color and opacity
* Blending
* Thickness
* Border and line settings
* Softness
* Position and offset
* Rotation
* Shear
* Size
* Layer priority

Text content and regular typography settings are protected during shading paste.

## Undo and Redo

The editor keeps a history of the last 20 batch operations.

Click **Undo** to reverse the most recent formatting or shading operation.

Click **Redo** to restore the most recently undone operation.

Undo and Redo only track changes made through the current Batch Text+ Editor session. Closing the window clears the script history.

If there is nothing available to undo or redo, the status area will display a message.

## Keeping the Window Open

The Batch Text+ Editor can remain open while you work.

After each timeline selection:

1. Select the desired Text+ clips.
2. Click **Refresh** if you want to confirm the target count.
3. Change or apply the desired settings.

The script reads the current timeline selection again whenever you load, apply, copy, or paste settings.

## Troubleshooting

### No Text+ targets are found

Confirm that:

* The clips are selected on the Edit timeline.
* The selected clips are Text+ titles.
* You are not selecting standard Text titles or subtitle clips.
* Your Resolve version supports selected timeline clips through its scripting API.

### Paste Shading is unavailable

Select exactly one source Text+ clip and click **Copy From Selected** first.

### Text is being replaced

Make sure the Text Apply checkbox is disabled unless you intentionally want every selected title to use the same text.

### Fonts are missing

Install the font through your operating system, restart Resolve, and reopen the script.

### The updated script does not appear

Close Resolve completely, replace the old Lua file, and restart Resolve.
