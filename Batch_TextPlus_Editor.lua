local resolveApp = resolve
if not resolveApp then
    print("Batch Text+ Editor: Resolve scripting context is not available.")
    return
end

local fusion = resolveApp:Fusion()
if not fusion then
    print("Batch Text+ Editor: Fusion scripting is not available.")
    return
end

local ui = fusion.UIManager
local disp = bmd.UIDispatcher(ui)
local projectManager = resolveApp:GetProjectManager()
local project = projectManager:GetCurrentProject()

if not project then
    print("Batch Text+ Editor: No project is open.")
    return
end

local timeline = project:GetCurrentTimeline()
if not timeline then
    print("Batch Text+ Editor: No timeline is open.")
    return
end

local function refreshTimeline()
    project = projectManager:GetCurrentProject()
    if not project then
        return false, "No project is open."
    end

    timeline = project:GetCurrentTimeline()
    if not timeline then
        return false, "No timeline is open."
    end

    return true
end

local function trim(value)
    if value == nil then
        return ""
    end
    return tostring(value):match("^%s*(.-)%s*$")
end

local function clamp(value, minimum, maximum)
    if value < minimum then
        return minimum
    end
    if value > maximum then
        return maximum
    end
    return value
end

local function byteToHex(value)
    value = math.floor(clamp(value, 0, 255) + 0.5)
    return string.format("%02X", value)
end

local function rgbToHex(red, green, blue)
    red = tonumber(red) or 1
    green = tonumber(green) or 1
    blue = tonumber(blue) or 1
    return "#" .. byteToHex(red * 255) .. byteToHex(green * 255) .. byteToHex(blue * 255)
end

local function hexToRgb(value)
    value = trim(value):gsub("#", "")

    if #value == 3 then
        value = value:sub(1, 1) .. value:sub(1, 1)
            .. value:sub(2, 2) .. value:sub(2, 2)
            .. value:sub(3, 3) .. value:sub(3, 3)
    end

    if #value ~= 6 or not value:match("^[%x]+$") then
        return nil
    end

    return tonumber(value:sub(1, 2), 16) / 255,
        tonumber(value:sub(3, 4), 16) / 255,
        tonumber(value:sub(5, 6), 16) / 255
end

local function hsvToRgb(hue, saturation, value)
    hue = (tonumber(hue) or 0) % 360
    saturation = clamp((tonumber(saturation) or 0) / 255, 0, 1)
    value = clamp((tonumber(value) or 0) / 255, 0, 1)

    local chroma = value * saturation
    local sector = hue / 60
    local secondary = chroma * (1 - math.abs((sector % 2) - 1))
    local red = 0
    local green = 0
    local blue = 0

    if sector < 1 then
        red, green, blue = chroma, secondary, 0
    elseif sector < 2 then
        red, green, blue = secondary, chroma, 0
    elseif sector < 3 then
        red, green, blue = 0, chroma, secondary
    elseif sector < 4 then
        red, green, blue = 0, secondary, chroma
    elseif sector < 5 then
        red, green, blue = secondary, 0, chroma
    else
        red, green, blue = chroma, 0, secondary
    end

    local match = value - chroma
    return red + match, green + match, blue + match
end

local function rgbToHsv(red, green, blue)
    red = clamp(tonumber(red) or 0, 0, 1)
    green = clamp(tonumber(green) or 0, 0, 1)
    blue = clamp(tonumber(blue) or 0, 0, 1)

    local maximum = math.max(red, green, blue)
    local minimum = math.min(red, green, blue)
    local delta = maximum - minimum
    local hue = 0

    if delta > 0 then
        if maximum == red then
            hue = 60 * (((green - blue) / delta) % 6)
        elseif maximum == green then
            hue = 60 * (((blue - red) / delta) + 2)
        else
            hue = 60 * (((red - green) / delta) + 4)
        end
    end

    local saturation = maximum == 0 and 0 or delta / maximum
    return hue, saturation * 255, maximum * 255
end

local function getVideoRange()
    local marks = timeline:GetMarkInOut()
    local video = marks and marks.video

    if not video or video["in"] == nil or video["out"] == nil then
        return nil, nil
    end

    local markIn = tonumber(video["in"])
    local markOut = tonumber(video["out"])
    local timelineStart = tonumber(timeline:GetStartFrame()) or 0

    if markIn == nil or markOut == nil then
        return nil, nil
    end

    return markIn + timelineStart, markOut + timelineStart
end

local function getItemsInRange()
    local ok, err = refreshTimeline()
    if not ok then
        return nil, err
    end

    local markIn, markOut = getVideoRange()
    if markIn == nil or markOut == nil then
        return nil, "Set video In and Out points around the Text+ clips you want to edit."
    end

    local items = {}
    local trackCount = timeline:GetTrackCount("video")

    for trackIndex = 1, trackCount do
        local trackItems = timeline:GetItemListInTrack("video", trackIndex) or {}
        for _, item in ipairs(trackItems) do
            local itemStart = tonumber(item:GetStart())
            local itemEnd = tonumber(item:GetEnd())

            if itemStart and itemEnd and itemStart <= markOut and itemEnd > markIn then
                items[#items + 1] = item
            end
        end
    end

    table.sort(items, function(a, b)
        return tonumber(a:GetStart()) < tonumber(b:GetStart())
    end)

    return items, nil, markIn, markOut
end

local function findFirstTextPlus(item)
    local compCount = item:GetFusionCompCount() or 0

    for compIndex = 1, compCount do
        local comp = item:GetFusionCompByIndex(compIndex)
        if comp then
            local tools = comp:GetToolList(false, "TextPlus") or {}
            for _, tool in pairs(tools) do
                return comp, tool
            end
        end
    end

    return nil, nil
end

local function getTextPlusTargets()
    local items, err, markIn, markOut = getItemsInRange()
    if not items then
        return nil, err
    end

    local targets = {}

    for _, item in ipairs(items) do
        local comp, tool = findFirstTextPlus(item)
        if comp and tool then
            targets[#targets + 1] = {
                item = item,
                comp = comp,
                tool = tool
            }
        end
    end

    return targets, nil, #items, markIn, markOut
end

local fontManager = fusion.FontManager
local fontList = fontManager:GetFontList() or {}

if not next(fontList) then
    fontManager:ScanDir()
    fontList = fontManager:GetFontList() or {}
end

local fontFamilies = {}

for family, styles in pairs(fontList) do
    if type(family) == "string" and type(styles) == "table" then
        fontFamilies[#fontFamilies + 1] = family
    end
end

table.sort(fontFamilies, function(a, b)
    return a:lower() < b:lower()
end)

local win = disp:AddWindow({
    ID = "BatchTextPlusEditor",
    WindowTitle = "Batch Text+ Editor",
    WindowFlags = {
        Window = true,
        WindowStaysOnTopHint = true
    },
    MinimumSize = {620, 535},
    Spacing = 8,
    Margin = 12,

    ui:VGroup{
        ID = "root",
        Spacing = 8,

        ui:Label{
            ID = "Status",
            Text = "Set timeline In and Out points around the Text+ clips you want to edit.",
            WordWrap = true
        },

        ui:HGroup{
            Weight = 0,
            ui:Button{ID = "Refresh", Text = "Refresh Range"},
            ui:Button{ID = "LoadFirst", Text = "Load First In Range"},
            ui:Button{ID = "ClearChecks", Text = "Clear Apply Checks"}
        },

        ui:Label{
            Text = "Check a row to apply that attribute. Editing a field automatically checks its row.",
            WordWrap = true
        },

        ui:HGroup{
            Weight = 0,
            ui:CheckBox{ID = "ApplyText", Text = "Apply", Checked = false, MinimumSize = {70, 24}},
            ui:Label{Text = "Text", MinimumSize = {105, 24}},
            ui:LineEdit{ID = "TextValue", PlaceholderText = "Same text for every title in range"}
        },

        ui:HGroup{
            Weight = 0,
            ui:CheckBox{ID = "ApplyFont", Text = "Apply", Checked = false, MinimumSize = {70, 24}},
            ui:Label{Text = "Font family", MinimumSize = {105, 24}},
            ui:ComboBox{ID = "FontValue"}
        },

        ui:HGroup{
            Weight = 0,
            ui:CheckBox{ID = "ApplyStyle", Text = "Apply", Checked = false, MinimumSize = {70, 24}},
            ui:Label{Text = "Font style", MinimumSize = {105, 24}},
            ui:ComboBox{ID = "StyleValue"}
        },

        ui:HGroup{
            Weight = 0,
            ui:CheckBox{ID = "ApplySize", Text = "Apply", Checked = false, MinimumSize = {70, 24}},
            ui:Label{Text = "Size", MinimumSize = {105, 24}},
            ui:LineEdit{ID = "SizeValue", Text = "0.08", PlaceholderText = "0.08"},
            ui:Label{Text = "Fusion normalized value"}
        },

        ui:HGroup{
            Weight = 0,
            ui:CheckBox{ID = "ApplyTracking", Text = "Apply", Checked = false, MinimumSize = {70, 24}},
            ui:Label{Text = "Character spacing", MinimumSize = {105, 24}},
            ui:LineEdit{ID = "TrackingValue", Text = "1.0", PlaceholderText = "1.0"}
        },

        ui:HGroup{
            Weight = 0,
            ui:CheckBox{ID = "ApplyLineSpacing", Text = "Apply", Checked = false, MinimumSize = {70, 24}},
            ui:Label{Text = "Line spacing", MinimumSize = {105, 24}},
            ui:LineEdit{ID = "LineSpacingValue", Text = "1.0", PlaceholderText = "1.0"}
        },

        ui:HGroup{
            Weight = 0,
            ui:CheckBox{ID = "ApplyColor", Text = "Apply", Checked = false, MinimumSize = {70, 24}},
            ui:Label{Text = "Text color", MinimumSize = {105, 24}},
            ui:LineEdit{ID = "ColorValue", Text = "#FFFFFF", PlaceholderText = "#FFFFFF"},
            ui:Button{ID = "OpenColorPicker", Text = "RGB Picker...", MinimumSize = {105, 24}}
        },

        ui:HGroup{
            Weight = 0,
            ui:CheckBox{ID = "ApplyOpacity", Text = "Apply", Checked = false, MinimumSize = {70, 24}},
            ui:Label{Text = "Opacity", MinimumSize = {105, 24}},
            ui:SpinBox{ID = "OpacityValue", Value = 100, Minimum = 0, Maximum = 100, SingleStep = 1, Suffix = "%"}
        },

        ui:HGroup{
            Weight = 0,
            ui:CheckBox{ID = "ApplyPosition", Text = "Apply", Checked = false, MinimumSize = {70, 24}},
            ui:Label{Text = "Center X / Y", MinimumSize = {105, 24}},
            ui:LineEdit{ID = "PositionX", Text = "0.5", PlaceholderText = "0.5"},
            ui:LineEdit{ID = "PositionY", Text = "0.5", PlaceholderText = "0.5"}
        },

        ui:VGap(4),

        ui:HGroup{
            Weight = 0,
            ui:Button{ID = "ApplyButton", Text = "Apply to Text+ in Range", MinimumSize = {250, 34}},
            ui:Button{ID = "CloseButton", Text = "Close", MinimumSize = {90, 34}}
        }
    }
})

local itm = win:GetItems()
local loadingValues = false

if #fontFamilies > 0 then
    itm.FontValue:AddItems(fontFamilies)
    itm.FontValue.CurrentIndex = 0
else
    itm.FontValue:AddItem("No fonts found")
    itm.FontValue.CurrentIndex = 0
end

local function comboIndex(items, value)
    for index, item in ipairs(items) do
        if item == value then
            return index - 1
        end
    end
    return nil
end

local function selectComboText(combo, items, value)
    local index = comboIndex(items, value)

    if index == nil then
        items[#items + 1] = value
        combo:AddItem(value)
        index = #items - 1
    end

    combo.CurrentIndex = index
end


local currentStyles = {}

local function populateStyleMenu(family, selectedStyle)
    currentStyles = {}

    local styles = fontList[family]
    if type(styles) == "table" then
        for style in pairs(styles) do
            if type(style) == "string" then
                currentStyles[#currentStyles + 1] = style
            end
        end
    end

    table.sort(currentStyles, function(a, b)
        return a:lower() < b:lower()
    end)

    itm.StyleValue:Clear()

    if #currentStyles == 0 then
        currentStyles[1] = "Regular"
    end

    itm.StyleValue:AddItems(currentStyles)

    if selectedStyle and selectedStyle ~= "" then
        selectComboText(itm.StyleValue, currentStyles, selectedStyle)
    else
        itm.StyleValue.CurrentIndex = 0
    end
end

populateStyleMenu(itm.FontValue.CurrentText)

local basicColors = {
    "#000000", "#800000", "#008000", "#805000", "#00A000", "#808000", "#00FF00", "#80FF00",
    "#000080", "#800080", "#008080", "#B06088", "#00B090", "#B0B090", "#00FFB0", "#90FF90",
    "#0000FF", "#A000A0", "#0088FF", "#FF60B0", "#00FFFF", "#B0B0FF", "#60FFFF", "#C0FFFF",
    "#600000", "#FF0000", "#606000", "#FF7000", "#50B000", "#FFB000", "#00FF40", "#FFFF00"
}

local paletteColumnCount = 18
local paletteRowCount = 9
local paletteCells = {}
local valueButtons = {}
local basicButtons = {}
local paletteRows = {Spacing = 1}
local valueRows = {Spacing = 1}

for row = 1, paletteRowCount do
    local rowLayout = {Spacing = 1, Weight = 0}
    local saturation = 255 - ((row - 1) * 255 / (paletteRowCount - 1))

    for column = 1, paletteColumnCount do
        local hue = (column - 1) * 360 / paletteColumnCount
        local id = string.format("Palette%02d%02d", row, column)

        paletteCells[id] = {
            hue = hue,
            saturation = saturation,
            row = row,
            column = column
        }

        rowLayout[#rowLayout + 1] = ui:Button{
            ID = id,
            Text = "",
            Flat = true,
            MinimumSize = {17, 18},
            MaximumSize = {24, 22}
        }
    end

    paletteRows[#paletteRows + 1] = ui:HGroup(rowLayout)
end

for row = 1, paletteRowCount do
    local value = 255 - ((row - 1) * 255 / (paletteRowCount - 1))
    local id = string.format("Value%02d", row)

    valueButtons[id] = value
    valueRows[#valueRows + 1] = ui:Button{
        ID = id,
        Text = "",
        Flat = true,
        MinimumSize = {18, 18},
        MaximumSize = {22, 22}
    }
end

local basicRows = {Spacing = 3}

for row = 1, 4 do
    local rowLayout = {Spacing = 3, Weight = 0}

    for column = 1, 8 do
        local index = (row - 1) * 8 + column
        local id = string.format("Basic%02d", index)

        basicButtons[id] = basicColors[index]
        rowLayout[#rowLayout + 1] = ui:Button{
            ID = id,
            Text = "",
            Flat = true,
            MinimumSize = {23, 20},
            MaximumSize = {30, 23}
        }
    end

    basicRows[#basicRows + 1] = ui:HGroup(rowLayout)
end

local colorWin = disp:AddWindow({
    ID = "BatchTextPlusColorPicker",
    WindowTitle = "Color",
    WindowFlags = {
        Window = true,
        WindowStaysOnTopHint = true
    },
    MinimumSize = {610, 470},
    Spacing = 9,
    Margin = 11,

    ui:VGroup{
        Spacing = 9,

        ui:HGroup{
            Spacing = 14,

            ui:VGroup{
                Weight = 0,
                Spacing = 6,
                ui:Label{Text = "Basic colors"},
                ui:VGroup(basicRows),
                ui:VGap(1),
                ui:Button{ID = "ResetWhite", Text = "White"},
                ui:Button{ID = "ResetBlack", Text = "Black"}
            },

            ui:VGroup{
                Spacing = 6,
                ui:Label{Text = "Hue and saturation"},
                ui:HGroup{
                    Spacing = 5,
                    ui:VGroup(paletteRows),
                    ui:VGroup(valueRows)
                }
            }
        },

        ui:HGroup{
            Spacing = 16,

            ui:Label{
                ID = "ColorPreview",
                Text = "#FFFFFF",
                Alignment = {AlignHCenter = true, AlignVCenter = true},
                MinimumSize = {125, 118},
                MaximumSize = {155, 140}
            },

            ui:VGroup{
                Spacing = 5,

                ui:HGroup{
                    ui:Label{Text = "Hue", MinimumSize = {48, 24}},
                    ui:SpinBox{ID = "HueValue", Minimum = 0, Maximum = 359, Value = 0},
                    ui:Label{Text = "Red", MinimumSize = {48, 24}},
                    ui:SpinBox{ID = "ColorRed", Minimum = 0, Maximum = 255, Value = 255}
                },

                ui:HGroup{
                    ui:Label{Text = "Sat", MinimumSize = {48, 24}},
                    ui:SpinBox{ID = "SatValue", Minimum = 0, Maximum = 255, Value = 0},
                    ui:Label{Text = "Green", MinimumSize = {48, 24}},
                    ui:SpinBox{ID = "ColorGreen", Minimum = 0, Maximum = 255, Value = 255}
                },

                ui:HGroup{
                    ui:Label{Text = "Val", MinimumSize = {48, 24}},
                    ui:SpinBox{ID = "ValValue", Minimum = 0, Maximum = 255, Value = 255},
                    ui:Label{Text = "Blue", MinimumSize = {48, 24}},
                    ui:SpinBox{ID = "ColorBlue", Minimum = 0, Maximum = 255, Value = 255}
                },

                ui:HGroup{
                    ui:Label{Text = "HTML", MinimumSize = {48, 24}},
                    ui:LineEdit{ID = "HtmlValue", Text = "#FFFFFF", PlaceholderText = "#FFFFFF"}
                }
            }
        },

        ui:Label{ID = "PickerStatus", Text = "", WordWrap = true},

        ui:HGroup{
            Weight = 0,
            ui:HGap(220),
            ui:Button{ID = "CancelColor", Text = "Cancel", MinimumSize = {100, 30}},
            ui:Button{ID = "UseColor", Text = "OK", MinimumSize = {100, 30}}
        }
    }
})

local colorItm = colorWin:GetItems()
local pickerUpdating = false
local colorState = {
    hue = 0,
    saturation = 0,
    value = 255,
    red = 255,
    green = 255,
    blue = 255,
    html = "#FFFFFF"
}

local function colorButtonStyle(red, green, blue, selected)
    local border = selected and "2px solid #FFFFFF" or "1px solid #171717"
    return string.format(
        "background-color: rgb(%d, %d, %d); border: %s; border-radius: 0px;",
        red,
        green,
        blue,
        border
    )
end

local function refreshColorPalette()
    local selectedColumn = math.floor((colorState.hue / 360) * paletteColumnCount + 0.5) % paletteColumnCount + 1
    local selectedRow = math.floor((1 - colorState.saturation / 255) * (paletteRowCount - 1) + 0.5) + 1

    for id, cell in pairs(paletteCells) do
        local red, green, blue = hsvToRgb(cell.hue, cell.saturation, colorState.value)
        local selected = cell.row == selectedRow and cell.column == selectedColumn

        colorItm[id].StyleSheet = colorButtonStyle(
            math.floor(red * 255 + 0.5),
            math.floor(green * 255 + 0.5),
            math.floor(blue * 255 + 0.5),
            selected
        )
    end


    local selectedValueRow = math.floor((1 - colorState.value / 255) * (paletteRowCount - 1) + 0.5) + 1

    for id, value in pairs(valueButtons) do
        local gray = math.floor(value + 0.5)
        local row = math.floor((1 - value / 255) * (paletteRowCount - 1) + 0.5) + 1
        colorItm[id].StyleSheet = colorButtonStyle(gray, gray, gray, row == selectedValueRow)
    end
end

local function refreshBasicColors()
    for id, html in pairs(basicButtons) do
        local red, green, blue = hexToRgb(html)
        colorItm[id].StyleSheet = colorButtonStyle(
            math.floor(red * 255 + 0.5),
            math.floor(green * 255 + 0.5),
            math.floor(blue * 255 + 0.5),
            false
        )
    end
end

local function refreshColorControls()
    pickerUpdating = true

    colorItm.HueValue.Value = math.floor(colorState.hue + 0.5) % 360
    colorItm.SatValue.Value = math.floor(colorState.saturation + 0.5)
    colorItm.ValValue.Value = math.floor(colorState.value + 0.5)
    colorItm.ColorRed.Value = colorState.red
    colorItm.ColorGreen.Value = colorState.green
    colorItm.ColorBlue.Value = colorState.blue
    colorItm.HtmlValue.Text = colorState.html
    colorItm.ColorPreview.Text = colorState.html

    local textColor = colorState.red + colorState.green + colorState.blue > 382 and 0 or 255
    colorItm.ColorPreview.StyleSheet = string.format(
        "background-color: rgb(%d, %d, %d); color: rgb(%d, %d, %d); border: 1px solid #777777;",
        colorState.red,
        colorState.green,
        colorState.blue,
        textColor,
        textColor,
        textColor
    )

    refreshColorPalette()
    pickerUpdating = false
end

local function setPickerFromHsv(hue, saturation, value)
    colorState.hue = clamp(tonumber(hue) or 0, 0, 359)
    colorState.saturation = clamp(tonumber(saturation) or 0, 0, 255)
    colorState.value = clamp(tonumber(value) or 0, 0, 255)

    local red, green, blue = hsvToRgb(colorState.hue, colorState.saturation, colorState.value)
    colorState.red = math.floor(red * 255 + 0.5)
    colorState.green = math.floor(green * 255 + 0.5)
    colorState.blue = math.floor(blue * 255 + 0.5)
    colorState.html = "#" .. byteToHex(colorState.red) .. byteToHex(colorState.green) .. byteToHex(colorState.blue)
    colorItm.PickerStatus.Text = ""
    refreshColorControls()
end

local function setPickerFromRgb(red, green, blue)
    colorState.red = math.floor(clamp(tonumber(red) or 0, 0, 255) + 0.5)
    colorState.green = math.floor(clamp(tonumber(green) or 0, 0, 255) + 0.5)
    colorState.blue = math.floor(clamp(tonumber(blue) or 0, 0, 255) + 0.5)

    colorState.hue, colorState.saturation, colorState.value = rgbToHsv(
        colorState.red / 255,
        colorState.green / 255,
        colorState.blue / 255
    )
    colorState.html = "#" .. byteToHex(colorState.red) .. byteToHex(colorState.green) .. byteToHex(colorState.blue)
    colorItm.PickerStatus.Text = ""
    refreshColorControls()
end

refreshBasicColors()
refreshColorControls()

local function setStatus(message)
    itm.Status.Text = tostring(message or "")
end

local applyChecks = {
    "ApplyText",
    "ApplyFont",
    "ApplyStyle",
    "ApplySize",
    "ApplyTracking",
    "ApplyLineSpacing",
    "ApplyColor",
    "ApplyOpacity",
    "ApplyPosition"
}

local function clearApplyChecks()
    for _, id in ipairs(applyChecks) do
        itm[id].Checked = false
    end
end

local function refreshRangeStatus()
    local targets, err, itemCount, markIn, markOut = getTextPlusTargets()
    if not targets then
        setStatus(err)
        return
    end

    setStatus(string.format(
        "Range %s to %s contains %d video clip(s) and %d Text+ target(s).",
        tostring(markIn),
        tostring(markOut),
        itemCount,
        #targets
    ))
end

local function loadFirstInRange()
    local items, err = getItemsInRange()
    if not items then
        setStatus(err)
        return
    end

    local comp = nil
    local tool = nil

    for _, item in ipairs(items) do
        comp, tool = findFirstTextPlus(item)
        if comp and tool then
            break
        end
    end

    if not tool then
        setStatus("No Text+ title was found inside the In/Out range.")
        return
    end

    local time = tonumber(comp.CurrentTime) or 0
    local center = tool:GetInput("Center", time)

    loadingValues = true

    local text = tool:GetInput("StyledText", time)
    local font = tool:GetInput("Font", time)
    local style = tool:GetInput("Style", time)
    local size = tool:GetInput("Size", time)
    local tracking = tool:GetInput("CharacterSpacing", time)
    local lineSpacing = tool:GetInput("LineSpacing", time)
    local red = tool:GetInput("Red1", time)
    local green = tool:GetInput("Green1", time)
    local blue = tool:GetInput("Blue1", time)
    local alpha = tool:GetInput("Alpha1", time)

    if text ~= nil then itm.TextValue.Text = tostring(text) end
    if font ~= nil then
        selectComboText(itm.FontValue, fontFamilies, tostring(font))
        populateStyleMenu(tostring(font), style ~= nil and tostring(style) or nil)
    elseif style ~= nil then
        populateStyleMenu(itm.FontValue.CurrentText, tostring(style))
    end
    if size ~= nil then itm.SizeValue.Text = tostring(size) end
    if tracking ~= nil then itm.TrackingValue.Text = tostring(tracking) end
    if lineSpacing ~= nil then itm.LineSpacingValue.Text = tostring(lineSpacing) end
    itm.ColorValue.Text = rgbToHex(red, green, blue)

    if alpha ~= nil then
        itm.OpacityValue.Value = math.floor(clamp(tonumber(alpha) or 1, 0, 1) * 100 + 0.5)
    end

    if type(center) == "table" then
        if center[1] ~= nil then itm.PositionX.Text = tostring(center[1]) end
        if center[2] ~= nil then itm.PositionY.Text = tostring(center[2]) end
    end

    clearApplyChecks()
    loadingValues = false
    setStatus("Loaded values from the first Text+ title inside the In/Out range.")
end

local function validateInputs()
    local values = {}
    local any = false

    if itm.ApplyText.Checked then
        values.text = itm.TextValue.Text or ""
        any = true
    end

    if itm.ApplyFont.Checked then
        values.font = trim(itm.FontValue.CurrentText)
        if values.font == "" or values.font == "No fonts found" then
            return nil, "Font family cannot be blank when Apply is checked."
        end
        any = true
    end

    if itm.ApplyStyle.Checked then
        values.style = trim(itm.StyleValue.CurrentText)
        if values.style == "" then
            return nil, "Font style cannot be blank when Apply is checked."
        end
        any = true
    end

    if itm.ApplySize.Checked then
        values.size = tonumber(trim(itm.SizeValue.Text))
        if values.size == nil then
            return nil, "Size must be a number, for example 0.08."
        end
        any = true
    end

    if itm.ApplyTracking.Checked then
        values.tracking = tonumber(trim(itm.TrackingValue.Text))
        if values.tracking == nil then
            return nil, "Character spacing must be a number, for example 1.0."
        end
        any = true
    end

    if itm.ApplyLineSpacing.Checked then
        values.lineSpacing = tonumber(trim(itm.LineSpacingValue.Text))
        if values.lineSpacing == nil then
            return nil, "Line spacing must be a number, for example 1.0."
        end
        any = true
    end

    if itm.ApplyColor.Checked then
        values.red, values.green, values.blue = hexToRgb(itm.ColorValue.Text)
        if values.red == nil then
            return nil, "Text color must be a hex color such as #FFFFFF or #F80."
        end
        any = true
    end

    if itm.ApplyOpacity.Checked then
        values.alpha = clamp((tonumber(itm.OpacityValue.Value) or 100) / 100, 0, 1)
        any = true
    end

    if itm.ApplyPosition.Checked then
        values.x = tonumber(trim(itm.PositionX.Text))
        values.y = tonumber(trim(itm.PositionY.Text))
        if values.x == nil or values.y == nil then
            return nil, "Center X and Y must both be numbers, for example 0.5 and 0.5."
        end
        any = true
    end

    if not any then
        return nil, "Nothing is enabled. Edit a field or check at least one Apply box."
    end

    return values
end

local function applyToRange()
    local values, validationError = validateInputs()
    if not values then
        setStatus(validationError)
        return
    end

    local targets, err = getTextPlusTargets()
    if not targets then
        setStatus(err)
        return
    end

    if #targets == 0 then
        setStatus("No Text+ title was found inside the In/Out range.")
        return
    end

    local changedTargets = 0
    local failedWrites = 0

    for _, target in ipairs(targets) do
        local comp = target.comp
        local tool = target.tool
        local time = tonumber(comp.CurrentTime) or 0
        local changed = false

        comp:StartUndo("Batch Text+ Edit")

        local function write(inputName, value)
            if tool:SetInput(inputName, value, time) then
                changed = true
            else
                failedWrites = failedWrites + 1
            end
        end

        if itm.ApplyText.Checked then write("StyledText", values.text) end
        if itm.ApplyFont.Checked then write("Font", values.font) end
        if itm.ApplyStyle.Checked then write("Style", values.style) end
        if itm.ApplySize.Checked then write("Size", values.size) end
        if itm.ApplyTracking.Checked then write("CharacterSpacing", values.tracking) end
        if itm.ApplyLineSpacing.Checked then write("LineSpacing", values.lineSpacing) end

        if itm.ApplyColor.Checked then
            write("Red1", values.red)
            write("Green1", values.green)
            write("Blue1", values.blue)
        end

        if itm.ApplyOpacity.Checked then
            write("Alpha1", values.alpha)
        end

        if itm.ApplyPosition.Checked then
            write("Center", {values.x, values.y})
        end

        comp:EndUndo(changed)

        if changed then
            changedTargets = changedTargets + 1
        end
    end

    if failedWrites > 0 then
        setStatus(string.format(
            "Changed %d Text+ target(s). %d input write(s) were rejected by the title.",
            changedTargets,
            failedWrites
        ))
    else
        setStatus(string.format("Changed %d Text+ target(s).", changedTargets))
    end
end

function win.On.BatchTextPlusEditor.Close(ev)
    colorWin:Hide()
    disp:ExitLoop()
end

function win.On.CloseButton.Clicked(ev)
    colorWin:Hide()
    disp:ExitLoop()
end

function win.On.Refresh.Clicked(ev)
    refreshRangeStatus()
end

function win.On.LoadFirst.Clicked(ev)
    loadFirstInRange()
end

function win.On.ClearChecks.Clicked(ev)
    clearApplyChecks()
    setStatus("Apply checkboxes cleared.")
end

function win.On.ApplyButton.Clicked(ev)
    applyToRange()
end

function win.On.OpenColorPicker.Clicked(ev)
    local red, green, blue = hexToRgb(itm.ColorValue.Text)

    if red == nil then
        red, green, blue = 1, 1, 1
    end

    setPickerFromRgb(red * 255, green * 255, blue * 255)
    colorWin:Show()
end

function colorWin.On.BatchTextPlusColorPicker.Close(ev)
    colorWin:Hide()
end

function colorWin.On.CancelColor.Clicked(ev)
    colorWin:Hide()
end

function colorWin.On.UseColor.Clicked(ev)
    itm.ColorValue.Text = colorState.html
    itm.ApplyColor.Checked = true
    colorWin:Hide()
end

function colorWin.On.ResetWhite.Clicked(ev)
    setPickerFromRgb(255, 255, 255)
end

function colorWin.On.ResetBlack.Clicked(ev)
    setPickerFromRgb(0, 0, 0)
end

local function updateFromHsvControls(ev)
    if pickerUpdating then
        return
    end

    setPickerFromHsv(
        colorItm.HueValue.Value,
        colorItm.SatValue.Value,
        colorItm.ValValue.Value
    )
end

local function updateFromRgbControls(ev)
    if pickerUpdating then
        return
    end

    setPickerFromRgb(
        colorItm.ColorRed.Value,
        colorItm.ColorGreen.Value,
        colorItm.ColorBlue.Value
    )
end

local hsvControls = {
    "HueValue",
    "SatValue",
    "ValValue"
}

for _, id in ipairs(hsvControls) do
    colorWin.On[id].ValueChanged = updateFromHsvControls
end

local rgbControls = {
    "ColorRed",
    "ColorGreen",
    "ColorBlue"
}

for _, id in ipairs(rgbControls) do
    colorWin.On[id].ValueChanged = updateFromRgbControls
end

local function updateFromHtml(ev)
    if pickerUpdating then
        return
    end

    local red, green, blue = hexToRgb(colorItm.HtmlValue.Text)

    if red == nil then
        colorItm.PickerStatus.Text = "HTML must be a color such as #FFFFFF or #F80."
        return
    end

    setPickerFromRgb(red * 255, green * 255, blue * 255)
end


colorWin.On.HtmlValue.EditingFinished = updateFromHtml
colorWin.On.HtmlValue.ReturnPressed = updateFromHtml

local function makePaletteHandler(cell)
    return function(ev)
        setPickerFromHsv(cell.hue, cell.saturation, colorState.value)
    end
end

for id, cell in pairs(paletteCells) do
    colorWin.On[id].Clicked = makePaletteHandler(cell)
end

local function makeValueHandler(value)
    return function(ev)
        setPickerFromHsv(colorState.hue, colorState.saturation, value)
    end
end

for id, value in pairs(valueButtons) do
    colorWin.On[id].Clicked = makeValueHandler(value)
end

local function makeBasicColorHandler(html)
    return function(ev)
        local red, green, blue = hexToRgb(html)
        setPickerFromRgb(red * 255, green * 255, blue * 255)
    end
end

for id, html in pairs(basicButtons) do
    colorWin.On[id].Clicked = makeBasicColorHandler(html)
end

function win.On.FontValue.CurrentIndexChanged(ev)
    local wasLoading = loadingValues

    populateStyleMenu(itm.FontValue.CurrentText)

    if not wasLoading then
        itm.ApplyFont.Checked = true
        itm.ApplyStyle.Checked = true
    end
end

function win.On.StyleValue.CurrentIndexChanged(ev)
    if not loadingValues then
        itm.ApplyStyle.Checked = true
    end
end

local textEditBindings = {
    TextValue = "ApplyText",
    SizeValue = "ApplySize",
    TrackingValue = "ApplyTracking",
    LineSpacingValue = "ApplyLineSpacing",
    ColorValue = "ApplyColor",
    PositionX = "ApplyPosition",
    PositionY = "ApplyPosition"
}

local function makeTextEditHandler(checkBoxId)
    return function(ev)
        if not loadingValues then
            itm[checkBoxId].Checked = true
        end
    end
end

for fieldId, checkBoxId in pairs(textEditBindings) do
    win.On[fieldId].TextEdited = makeTextEditHandler(checkBoxId)
end

function win.On.OpacityValue.ValueChanged(ev)
    if not loadingValues then
        itm.ApplyOpacity.Checked = true
    end
end

win:Show()
disp:RunLoop()
win:Hide()
