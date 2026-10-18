--Custom logos: an SVG (from a file or searched on Wikimedia Commons) replaces the BBC logo in the boxes of Viz2.0.
--LÖVE cannot draw SVG, so lib/svg.lua draws it and Viz2.0 receives the picture as a PNG (and it recolours it).
local logoControl = {}

local svg = require "lib.svg"
local http = require "lib.http"
local fetch = require "lib.fetch"
local json = require "lib.json"

local MAX_SVG = 1024 * 1024

logoControl.shouldShow = ffi.new("bool[1]", false)
logoControl.show = function() logoControl.shouldShow[0] = true end

--The logo in use: nil is the BBC logo
local current --{name, svg, png, color = Image, mask = Image}
local modeBox = ffi.new("int[1]", 0) --0 original colours, 1 one colour, 2 automatic
local colorBox = ffi.new("float[3]", {1, 1, 1})
local MODES = {[0] = "original", "colour", "auto"}

local pathBox = ffi.new("char[1024]", "")
local queryBox = ffi.new("char[256]", "")
local broadcasterBox = ffi.new("int[1]", 0)
local results, resultSelected = {}, 0
local status = "Drop an .svg file on VizHelper, type its path, or search online."
local busy = false

local BROADCASTERS = {
    "BBC News", "BBC World News", "CNN", "Sky News", "Al Jazeera", "Euronews", "France 24", "Deutsche Welle", "Rai News 24",
    "Sky TG24", "Fox News", "NBC News", "ABC News", "CBS News", "NHK World", "ITV News", "Channel 4 News", "TRT World",
    "Bloomberg Television", "RTVE", "TVE 24 horas", "La7", "Mediaset", "TF1", "ZDF", "ARD Tagesschau",
}
local broadcasterList = table.concat(BROADCASTERS, "\0").."\0"

local previewCanvas = love.graphics.newCanvas(460, 70)

------------------------------------------------------------------------------------------------ the logo in use

logoControl.active = function() return current ~= nil end
logoControl.name = function() return current and current.name or "BBC (default)" end

logoControl.clear = function()
    current = nil
end

--Draws the SVG; returns true, or false and a message
logoControl.set = function(text, name)
    local data, err = svg.render(text, 512)
    if not data then return false, err end

    local mask = data:clone()
    mask:mapPixel(function(x, y, r, g, b, a) return 1, 1, 1, a end)
    current = {
        name = name, svg = text,
        png = data:encode("png"):getString(),
        color = love.graphics.newImage(data), mask = love.graphics.newImage(mask),
    }
    for _, image in ipairs({current.color, current.mask}) do image:setFilter("linear", "linear") end
    return true
end

--What Set-Branding carries (nothing for the BBC logo)
logoControl.fields = function(t)
    if current == nil then return end
    t.LogoPNG = current.png
    t.LogoMode = MODES[modeBox[0]]
    t.LogoColor = {colorBox[0], colorBox[1], colorBox[2]}
end

--Saved with the branding preset
logoControl.snapshot = function()
    if current == nil then return nil end
    return {name = current.name, svg = current.svg, mode = modeBox[0], color = {colorBox[0], colorBox[1], colorBox[2]}}
end

logoControl.restore = function(saved)
    current = nil
    if saved == nil then return end
    modeBox[0] = saved.mode
    colorBox[0], colorBox[1], colorBox[2] = saved.color[1], saved.color[2], saved.color[3]
    local ok, err = logoControl.set(saved.svg, saved.name)
    if not ok then status = "Saved logo not loaded: "..err end
end

local function loadSvg(text, name)
    local ok, err = logoControl.set(text, name)
    status = ok and ("Logo set: "..name..". Press Send Branding in Branding Control to put it on air.") or ("Not loaded: "..err)
    return ok
end

------------------------------------------------------------------------------------------------ from a file

local function loadFile(path, getText)
    local name = path:match("([^/\\]+)$") or path
    if not name:lower():find("%.svg$") then
        status = "Only .svg files are accepted: "..name
        return
    end
    local text = getText()
    if text == nil or #text > MAX_SVG then
        status = "Cannot read "..name.." (or it is bigger than 1 MB)"
        return
    end
    loadSvg(text, name)
end

--love.filedropped
logoControl.dropped = function(file)
    loadFile(file:getFilename(), function()
        file:open("r")
        local text = file:read()
        file:close()
        return text
    end)
    logoControl.shouldShow[0] = true
end

------------------------------------------------------------------------------------------------ search on Wikimedia Commons

local function search()
    local query = ffi.string(queryBox):gsub("^%s+", ""):gsub("%s+$", "")
    if query == "" or busy then return end
    if not query:lower():find("logo") then query = query.." logo" end

    busy, status, results, resultSelected = true, "Searching Wikimedia Commons...", {}, 0
    --filetype:drawing is how Commons calls SVG
    local url = "https://commons.wikimedia.org/w/api.php?action=query&format=json&generator=search&gsrnamespace=6&gsrlimit=30&gsrsearch="
        ..http.encode(query.." filetype:drawing").."&prop=imageinfo&iiprop=url|mime|size"
    fetch.get(url, nil, function(body, err)
        busy = false
        local ok, answer = pcall(function() return json:decode(body) end)
        if not body or not ok or type(answer) ~= "table" then
            status = "Search failed: "..tostring(err or "bad answer")
            return
        end
        local pages = {}
        for _, page in pairs(answer.query and answer.query.pages or {}) do
            local info = page.imageinfo and page.imageinfo[1]
            if info and info.mime == "image/svg+xml" and info.size <= MAX_SVG then
                pages[#pages + 1] = {index = page.index, title = page.title:gsub("^File:", ""), url = info.url, size = info.size}
            end
        end
        table.sort(pages, function(a, b) return a.index < b.index end)
        results = pages
        status = #pages.." SVG logos found. Click one to use it."
    end)
end

local function download(result)
    busy, status = true, "Downloading "..result.title.."..."
    fetch.get(result.url, MAX_SVG, function(body, err)
        busy = false
        if not body then
            status = "Download failed: "..tostring(err)
            return
        end
        loadSvg(body, result.title)
    end)
end

------------------------------------------------------------------------------------------------ window

local function drawPreview()
    local box = BrandingControl.brandingThemeColor
    love.graphics.setCanvas(previewCanvas)
    love.graphics.clear(box[0], box[1], box[2], 1)
    if current then
        local image, tint = current.mask, {colorBox[0], colorBox[1], colorBox[2]}
        if modeBox[0] == 0 then
            image, tint = current.color, {1, 1, 1}
        elseif modeBox[0] == 2 then
            local luma = 0.2126 * box[0] + 0.7152 * box[1] + 0.0722 * box[2]
            tint = luma > 0.6 and {0.1, 0.1, 0.1} or {1, 1, 1}
        end
        --The slot of the logo in the News Bar, twice as big
        local w, h = 230.4, 66
        local iw, ih = image:getDimensions()
        local scale = math.min(w / iw, h / ih)
        love.graphics.setColor(tint[1], tint[2], tint[3], 1)
        love.graphics.draw(image, 13 * 2 + (w - iw * scale) / 2, 2 + (h - ih * scale) / 2, 0, scale, scale)
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setCanvas()
end

logoControl.draw = function()
    imgui.Begin("Custom Logos", logoControl.shouldShow, imgui.love.WindowFlags("NoSavedSettings", "NoResize"))
    imgui.SetWindowSize_Vec2(imgui.ImVec2_Float(820, 660))

        imgui.PushFont(TimingsFont)
        imgui.Text("Custom logos")
        imgui.PopFont()
        imgui.Text("Replaces the BBC logo in the News Bar and headline box. SVG only, so the colour can change.")
        imgui.Text("While a custom logo is set the Title Control is locked (the titles are BBC graphics).")
        imgui.Separator()

        imgui.Text("Logo in use: "..logoControl.name())
        if current then
            imgui.SameLine()
            if imgui.Button("Back to the BBC logo") then
                logoControl.clear()
                status = "BBC logo. Press Send Branding in Branding Control to put it on air."
            end
        end

        drawPreview()
        imgui.Image(previewCanvas, imgui.ImVec2_Float(460, 70))

        imgui.Text("Colour")
        imgui.SameLine()
        imgui.Combo_Str("###logoMode", modeBox, "Original colours of the SVG\0One colour\0Automatic (black or white, whichever reads on the graphic)\0")
        if modeBox[0] == 1 then
            imgui.Text("Logo colour")
            imgui.SameLine()
            imgui.ColorEdit3("###logoColor", colorBox, imgui.love.ColorEditFlags("None"))
        end

        imgui.Separator()
        imgui.PushFont(TitleFont)
        imgui.Text("From a file")
        imgui.PopFont()
        imgui.InputText("###logoPath", pathBox, 1024)
        imgui.SameLine()
        if imgui.Button("Load SVG") then
            local path = ffi.string(pathBox):gsub('^%s*"?', ""):gsub('"?%s*$', "")
            loadFile(path, function()
                local f = io.open(path, "rb")
                if not f then return nil end
                local text = f:read("*all")
                f:close()
                return text
            end)
        end
        imgui.Text("(or drop an .svg file on this program)")

        imgui.Separator()
        imgui.PushFont(TitleFont)
        imgui.Text("Search online (Wikimedia Commons)")
        imgui.PopFont()
        imgui.Text("Broadcaster")
        imgui.SameLine()
        if imgui.Combo_Str("###logoBroadcaster", broadcasterBox, broadcasterList) then
            queryBox = ffi.new("char[256]", BROADCASTERS[broadcasterBox[0] + 1])
            search()
        end
        imgui.Text("Search")
        imgui.SameLine()
        if imgui.InputText("###logoQuery", queryBox, 256, imgui.love.InputTextFlags("EnterReturnsTrue")) then search() end
        imgui.SameLine()
        if imgui.Button("Search") then search() end

        if imgui.BeginListBox("###logoResults", imgui.ImVec2_Float(-1, 100)) then
            for i, result in ipairs(results) do
                if imgui.Selectable_Bool(result.title.." ("..math.ceil(result.size / 1024).." KB)###logoResult"..i, resultSelected == i) and not busy then
                    resultSelected = i
                    download(result)
                end
            end
            imgui.EndListBox()
        end

        imgui.PushTextWrapPos(0)
        imgui.Text(status)
        imgui.Text("Logos are trademarks of their owners: check that you may use them. Pictures that are made of text or use filters and masks may not draw correctly.")
        imgui.PopTextWrapPos()
    imgui.End()
end

return logoControl
