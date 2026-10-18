local tickerControl = {}

local wires = require "wires"

--What a row of "My text" is: its ticker code, what the row is called in the list, and whether it carries text
local KINDS = {
    [0] = {code = "!hh", label = "HEADLINES label"},
    {code = "!h", label = "Headline", text = true},
    {code = "!bb", label = "BREAKING label"},
    {code = "!b", label = "Breaking story", text = true},
    {code = "!ii", label = "INTERACTIVE label"},
    {code = "!i", label = "Interactive message", text = true},
}
local KIND_LIST = ""
for i = 0, #KINDS do KIND_LIST = KIND_LIST..KINDS[i].label.."\0" end

--The section label that goes with each text kind
local LABEL_OF = {[1] = 0, [3] = 2, [5] = 4}

local MAX_TEXT = 512

local nextId = 0
local rows = {}

local function newRow(kind, text)
    nextId = nextId + 1
    return {id = nextId, kind = ffi.new("int[1]", kind), text = ffi.new("char[?]", MAX_TEXT, (text or ""):sub(1, MAX_TEXT - 1))}
end

--Same format as ticker.txt and the Viz2.0 GetTickerText request: one coded line per row
local function toText()
    local lines = {}
    for _, row in ipairs(rows) do
        local kind = KINDS[row.kind[0]]
        if not kind.text then
            lines[#lines + 1] = kind.code
        else
            local text = ffi.string(row.text)
            if text ~= "" then lines[#lines + 1] = kind.code.." "..text end
        end
    end
    return table.concat(lines, "\n")
end

local function fromText(text)
    rows = {}
    for line in text:gmatch("[^\r\n]+") do
        for kind = 0, #KINDS do
            local code = KINDS[kind].code
            if KINDS[kind].text and line:sub(1, #code + 1) == code.." " then
                rows[#rows + 1] = newRow(kind, line:sub(#code + 2))
                break
            elseif not KINDS[kind].text and line:sub(1, #code) == code then
                rows[#rows + 1] = newRow(kind)
                break
            end
        end
    end
end

--Adds a row at the end, with its section label first when the list is not already in that section
local function addRow(kind)
    local label = LABEL_OF[kind]
    local current
    for i = #rows, 1, -1 do
        if not KINDS[rows[i].kind[0]].text then current = rows[i].kind[0] break end
    end
    if current ~= label then rows[#rows + 1] = newRow(label) end
    rows[#rows + 1] = newRow(kind)
end

--Check if ticker.txt exists
local saved = love.filesystem.read("ticker.txt")
if saved == nil then
    saved = "!hh\n!h Edit the text in VizHelper\n!ii\n!i Edit the text in VizHelper"
    love.filesystem.write("ticker.txt", saved)
end
fromText(saved)

tickerControl.shouldShow = ffi.new("bool[1]", false)
tickerControl.defaultTickerText = ffi.new("char[1024]", "bbc.co.uk/news")

local usingRSS = ffi.new("bool[1]", false)
local rssFeed = ffi.new("int[1]", 0)
local rssLimit = ffi.new("int[1]", 0)

--Changes in the list that are not on air yet
local dirty = false

local function defaultText()
    return ffi.string(tickerControl.defaultTickerText)
end

local function sendWires()
    GFX:send("headline", {Type = "GetTickerTextTable", Limit = rssLimit[0], Text = wires.wireData, DefaultText = defaultText()})
end

local function sendText()
    GFX:send("headline", {Type = "GetTickerText", Text = toText(), DefaultText = defaultText()})
end

--Puts the ticker text (own lines or RSS, whichever is picked) on air, and keeps the own lines for the next start
tickerControl.send = function()
    if usingRSS[0] then
        sendWires()
    else
        sendText()
        love.filesystem.write("ticker.txt", toText())
    end
    dirty = false
end

--The headlines of a feed arrive some time after it was picked
wires.onUpdate = function()
    if usingRSS[0] == true then sendWires() end
end
wires.fetch(1)

tickerControl.show = function()
    tickerControl.shouldShow[0] = true
end

local function colorButton(label, r, g, b, size)
    imgui.PushStyleColor_Vec4(imgui.ImGuiCol_Button, imgui.ImVec4_Float(r, g, b, 1))
    local clicked = imgui.Button(label, size)
    imgui.PopStyleColor()
    return clicked
end

tickerControl.draw = function()
    imgui.Begin("Ticker Control", tickerControl.shouldShow, imgui.love.WindowFlags("NoSavedSettings", "NoResize"))
        imgui.SetWindowSize_Vec2(imgui.ImVec2_Float(760,560))

        imgui.PushFont(TimingsFont)
        imgui.Text("Ticker")
        imgui.PopFont()

        if colorButton("Ticker ON", 0, 0.5, 0, imgui.ImVec2_Float(160, 36)) then
            GFX:send("headline", {Type = "ResumeTicker"})
        end
        imgui.SameLine()
        if colorButton("Ticker OFF", 0.55, 0, 0, imgui.ImVec2_Float(160, 36)) then
            GFX:send("headline", {Type = "KillTicker", Text = defaultText()})
        end
        imgui.SameLine()
        imgui.TextDisabled("OFF leaves only the default text")

        imgui.Separator()

        imgui.Text("Default text") imgui.SameLine()
        imgui.SetNextItemWidth(300)
        if imgui.InputText("###defaultTickerText", tickerControl.defaultTickerText, 1024) then dirty = true end

        imgui.Text("Source") imgui.SameLine()
        if imgui.RadioButton_Bool("My text###srcOwn", not usingRSS[0]) and usingRSS[0] then
            usingRSS[0] = false
            sendText()
        end
        imgui.SameLine()
        if imgui.RadioButton_Bool("RSS feed###srcRss", usingRSS[0]) and not usingRSS[0] then
            usingRSS[0] = true
            sendWires()
        end

        imgui.Separator()

        if usingRSS[0] == false then
            imgui.BeginChild_Str("###tickerRows", imgui.ImVec2_Float(0, 300), true)
                if #rows == 0 then imgui.TextDisabled("Nothing here yet: add a headline below.") end

                local remove, up, down
                for i, row in ipairs(rows) do
                    local kind = KINDS[row.kind[0]]
                    imgui.PushID_Int(row.id)

                    imgui.SetNextItemWidth(190)
                    if imgui.Combo_Str("###kind", row.kind, KIND_LIST) then dirty = true end
                    imgui.SameLine()
                    if kind.text then
                        imgui.SetNextItemWidth(330)
                        if imgui.InputTextWithHint("###text", "Text", row.text, MAX_TEXT) then dirty = true end
                    else
                        imgui.SetNextItemWidth(330)
                        imgui.TextDisabled("(label shown for 3 s)")
                    end
                    imgui.SameLine()
                    if imgui.SmallButton("Up") then up = i end
                    imgui.SameLine()
                    if imgui.SmallButton("Dn") then down = i end
                    imgui.SameLine()
                    if imgui.SmallButton("X") then remove = i end

                    imgui.PopID()
                end

                if remove then table.remove(rows, remove) end
                if up and up > 1 then rows[up], rows[up - 1] = rows[up - 1], rows[up] end
                if down and down < #rows then rows[down], rows[down + 1] = rows[down + 1], rows[down] end
                if remove or up or down then dirty = true end
            imgui.EndChild()

            imgui.Text("Add") imgui.SameLine()
            if imgui.Button("+ Headline") then addRow(1) dirty = true end
            imgui.SameLine()
            if imgui.Button("+ Breaking story") then addRow(3) dirty = true end
            imgui.SameLine()
            if imgui.Button("+ Interactive message") then addRow(5) dirty = true end
        else
            imgui.Text("Feed") imgui.SameLine()
            imgui.SetNextItemWidth(300)
            if imgui.Combo_Str("###rssFeedList", rssFeed, wires.feedNames) then
                wires.fetch(rssFeed[0] + 1)
            end
            imgui.Text(wires.status)

            imgui.Text("Show at most") imgui.SameLine()
            imgui.SetNextItemWidth(120)
            if imgui.InputInt("headlines (0 = all)###tickerLimit", rssLimit, 1, 2) then
                rssLimit[0] = math.max(0, math.min(rssLimit[0], #wires.wireData))
                sendWires()
            end
        end

        imgui.Separator()

        if usingRSS[0] == false then
            if colorButton("Apply to ticker", 0, 0.35, 0.7, imgui.ImVec2_Float(200, 36)) then
                tickerControl.send()
            end
            imgui.SameLine()
            if dirty then
                imgui.TextColored(imgui.ImVec4_Float(1, 0.7, 0.2, 1), "Changes not on air yet")
            else
                imgui.TextDisabled("On air")
            end
        else
            imgui.TextDisabled("RSS headlines go on air by themselves.")
        end
    imgui.End()
end

return tickerControl
