local inspect = require "lib.inspect"

Version = "1.3"

--Set Identity
love.filesystem.setIdentity("VizHelper")



love.filesystem.createDirectory("libraries")
-- Set the file paths
local srcFilePath = love.filesystem.getSourceBaseDirectory() .. "/VizHelper/imgui.dll"
local destFilePath = love.filesystem.getSaveDirectory() .. "/libraries/cimgui.dll"

-- Copy the file from source to destination
local srcFile = assert(io.open(srcFilePath, "rb"))
local destFile = assert(io.open(destFilePath, "wb"))
destFile:write(srcFile:read("*all"))
srcFile:close()
destFile:close()


ffi = require "ffi"
local extension = jit.os == "Windows" and "dll" or jit.os == "Linux" and "so" or jit.os == "OSX" and "dylib"
local timer = require "lib.timer"
local dllExists = love.filesystem.read("libraries/cimgui.dll")
sock = require "lib.sock"
Inspect = require "lib.inspect"

local showDebug = false

if jit.os == "Windows" then
    if dllExists == nil then
        love.window.showMessageBox("Error", "Couldn't find cImGUI dll file. Contact playsamay4#3646.", "error", true)
        love.event.quit()
    end
end

-- Make sure the shared library can be found through package.cpath before loading the module.
-- For example, if you put it in the LÖVE save directory, you could do something like this:
local lib_path = love.filesystem.getSaveDirectory() .. "/libraries"
package.cpath = string.format("%s;%s/?.%s", package.cpath, lib_path, extension)

imgui = require "cimgui" -- cimgui is the folder containing the Lua module (the "src" folder in the github repository)


AstonControl = require "modules.aston_control"
TickerControl = require "modules.ticker_control"
BrandingControl = require "modules.branding_control"
HeadlineControl = require "modules.headline_control"
PlayoutControl = require "modules.playout_control"

local showTileCon = ffi.new("bool[1]", false)
local showLiveCon = ffi.new("bool[1]", false)
local showAutomationCon = ffi.new("bool[1]", false)


local liveBugText = ffi.new("char[1024]", "")
local liveBugLive = ffi.new("bool[1]", true)
local liveBugShowTime = ffi.new("bool[1]", false)
local liveBugTimeOffset = ffi.new("int[1]", 0)
local liveBugSide = ffi.new("int[1]", 0)

local automationList = {
    {name = "Countdown", actions = {
        {id = "SetAndRun Source (Time Sync)", data = {"CountdownVid", "D:\\Example\\A1Day.mov"}, delay = 0},
        {id = "Fade Scene", data = {"Countdown"}, delay = 500},
        {id = "Viz KILL ALL", data = {}, delay = 0}, 
    }},
    {name = "Titles", actions = {
        {id = "Set Source", data = {"TitlesVid", "D:\\Example\\Titles.mov"}, delay = 0},
        {id = "Run Source", data = {"TitlesVid"}, delay = 0},
        {id = "Fade Scene", data = {"Titles"}, delay = 1000},
        {id = "Viz Show Ticker", data = {}, delay = 10000},
    }}
}

local connectedToViz = false

showError = false
errorTitle = ""
errorMessage = ""


local gearIcon = love.graphics.newImage("assets/gear.png")

Settings = require "modules.settings"

GFX = sock.newClient(Settings.data.Connections.IP or "localhost", 10655)
local connectSuccess, connectError = pcall(function() GFX:connect() end)

if connectSuccess == false then
    --temporarily set GFX to a dummy object so it doesn't error
    GFX = {error = true, on = function() end, send = function() end, update = function() end, disconnect = function() end, connect = function() end}
    showError = true
    errorTitle = "Connection Error"
    errorMessage = "Couldn't connect to Viz2.0: \n"..connectError
end


function registerCallbacks()
    GFX:on("connect", function(data)
        GFX:send("headline", {Type = "GetTickerText", Text = ffi.string(TickerControl.tickerText), DefaultText = ffi.string(TickerControl.defaultTickerText)})
        connectedToViz = true

        --This breaks figure out why \/\/\/

        -- local sendData = {Type = "Set-Branding"}
        -- sendData.channelName = brandingPresets[brandingPresetSelected].channelName
        -- sendData.opaque = brandingPresets[brandingPresetSelected].opaque
        -- sendData.coloredStrap = brandingPresets[brandingPresetSelected].coloredStrap
        -- sendData.ThemeColor = brandingPresets[brandingPresetSelected].themeColor
        -- sendData.mode = brandingPresets[brandingPresetSelected].mode
        -- sendData.clockMode = brandingPresets[brandingPresetSelected].clockMode
        -- GFX:send("headline", sendData)  

    end)

    GFX:on("disconnect", function(data)
        connectedToViz = false
    end)
end
registerCallbacks()

function love.load()
    imgui.love.Init() -- or imgui.love.Init("RGBA32") or imgui.love.Init("Alpha8")

    --Set imgui font
    
    local imio = imgui.GetIO()
    
    imio.ConfigWindowsMoveFromTitleBarOnly = true
    imio.ConfigDockingWithShift = true

    local config = imgui.ImFontConfig()
    config.FontDataOwnedByAtlas = false -- it's important to set this, or imgui.love.Shutdown() will crash trying to free already freed memory

    local font_size = 18
    local content, size = love.filesystem.read("fonts/segoeui/segoeui.ttf")
    local contentBold, sizeBold = love.filesystem.read("fonts/segoeui/segoeuib.ttf")
    local newfont = imio.Fonts:AddFontFromMemoryTTF(ffi.cast("void*", content), size, font_size, config)
    ScriptEditorFont = imio.Fonts:AddFontFromMemoryTTF(ffi.cast("void*", content), size, 22, config)
    NCSEditorFont = imio.Fonts:AddFontFromMemoryTTF(ffi.cast("void*", content), size, 25, config)
    TitleFont = imio.Fonts:AddFontFromMemoryTTF(ffi.cast("void*", contentBold), sizeBold, 18, config)
    TimingsFont = imio.Fonts:AddFontFromMemoryTTF(ffi.cast("void*", contentBold), sizeBold, 45, config)
    imio.FontDefault = newfont

    imgui.love.BuildFontAtlas() -- or imgui.love.BuildFontAtlas("RGBA32") or imgui.love.BuildFontAtlas("Alpha8")

    local style = imgui.GetStyle()
    local hspacing = 8
    local vspacing = 6
    imio.ConfigFlags = imgui.ImGuiConfigFlags_DockingEnable

    style.DisplaySafeAreaPadding = {0, 0}
    style.WindowPadding = {hspacing/2, vspacing}
    style.FramePadding = {hspacing, vspacing}
    style.ItemSpacing = {hspacing, vspacing}
    style.ItemInnerSpacing = {hspacing, vspacing}
    style.IndentSpacing = 20.0

    style.WindowRounding = 0
    style.FrameRounding = 0

    style.WindowBorderSize = 1
    style.FrameBorderSize = 1
    style.PopupBorderSize = 1

    style.ScrollbarSize = 20
    style.ScrollbarRounding = 0
    style.GrabMinSize = 5
    style.GrabRounding = 0

    --Light mode :barf:
    -- local white = {1, 1, 1, 1}
    -- local transparent = {0, 0, 0, 0}
    -- local dark = {0, 0, 0, 0.2}
    -- local darker = {0, 0, 0, 0.5}

    -- local background = {0.95, 0.95, 0.95, 1}
    -- local text = {0.1, 0.1, 0.1, 1}
    -- local border = {0.6, 0.6, 0.6, 1}
    -- local grab = {0.69, 0.69, 0.69, 1}
    -- local header = {0.86, 0.86, 0.86, 1}
    -- local active = {0, 0.47, 0.84, 1}
    -- local hover = {0, 0.47, 0.84, 0.2}
    -- local tab = {161/255, 196/255, 216/255,1}

    local white = {0, 0, 0, 1}
    local transparent = {1, 1, 1, 0}
    local dark = {1, 1, 1, 0.8}
    local darker = {1, 1, 1, 0.5}

    local background = {0.05, 0.05, 0.05, 1}
    local text = {0.9, 0.9, 0.9, 1}
    local border = {0.4, 0.4, 0.4, 1}
    local grab = {0.31, 0.31, 0.31, 1}
    local header = {0.14, 0.14, 0.14, 1}
    local active = {0, 0.47, 0.84, 1}
    local hover = {0, 0.47, 0.84, 0.2}
    local tab = {12/255, 20/255, 84/255,1}


    style.Colors[imgui.ImGuiCol_Text] = text
    style.Colors[imgui.ImGuiCol_WindowBg] = background
    style.Colors[imgui.ImGuiCol_ChildBg] = background
    style.Colors[imgui.ImGuiCol_PopupBg] = white
    style.Colors[imgui.ImGuiCol_TitleBg] = header
    style.Colors[imgui.ImGuiCol_TitleBgActive] = white
    style.Colors[imgui.ImGuiCol_TitleBgCollapsed] = header
    style.Colors[imgui.ImGuiCol_TableHeaderBg] = header
    style.Colors[imgui.ImGuiCol_Tab] = white
    style.Colors[imgui.ImGuiCol_TabHovered] = hover
    style.Colors[imgui.ImGuiCol_TabActive] = tab

    style.Colors[imgui.ImGuiCol_Border] = border
    style.Colors[imgui.ImGuiCol_BorderShadow] = transparent

    style.Colors[imgui.ImGuiCol_Button] = header
    style.Colors[imgui.ImGuiCol_ButtonHovered] = hover
    style.Colors[imgui.ImGuiCol_ButtonActive] = active


    style.Colors[imgui.ImGuiCol_FrameBg] = white
    style.Colors[imgui.ImGuiCol_FrameBgHovered] = hover
    style.Colors[imgui.ImGuiCol_FrameBgActive] = active

    style.Colors[imgui.ImGuiCol_MenuBarBg] = header
    style.Colors[imgui.ImGuiCol_Header] = header
    style.Colors[imgui.ImGuiCol_HeaderHovered] = hover
    style.Colors[imgui.ImGuiCol_HeaderActive] = active

    style.Colors[imgui.ImGuiCol_CheckMark] = text
    style.Colors[imgui.ImGuiCol_SliderGrab] = grab
    style.Colors[imgui.ImGuiCol_SliderGrabActive] = darker



    style.Colors[imgui.ImGuiCol_ScrollbarBg] = header
    style.Colors[imgui.ImGuiCol_ScrollbarGrab] = grab
    style.Colors[imgui.ImGuiCol_ScrollbarGrabHovered] = hover
    style.Colors[imgui.ImGuiCol_ScrollbarGrabActive] = active

    love.window.setTitle("VizHelper")
end

function love.update(dt)
    imgui.love.Update(dt)
    imgui.NewFrame()
    timer.update(dt)
    GFX:update()
    TickerControl.update(dt)

end

function love.draw()
    love.graphics.setBackgroundColor(0, 0, 0, 1)
    if showDebug == true then imgui.ShowDemoWindow() end
    imgui.Begin("VizHelper Hub", nil, imgui.love.WindowFlags("MenuBar","NoMove", "NoTitleBar", "NoSavedSettings", "NoResize", "NoBringToFrontOnFocus","NoDocking","NoNavFocus"))
        imgui.SetWindowSize_Vec2(imgui.ImVec2_Float(love.graphics.getWidth(), 1))
        imgui.SetWindowPos_Vec2(imgui.ImVec2_Float(0, 0))
        if imgui.BeginMenuBar() then
            if imgui.BeginMenu("VizHelper") then
                if imgui.MenuItem_Bool("Toggle ImGUI debug menu") then
                    showDebug = not showDebug
                end

                if imgui.MenuItem_Bool("Exit") then
                    love.event.quit()
                end
            
                imgui.EndMenu()
            end

        
            imgui.EndMenuBar()
        end
        imgui.SetNextWindowSize(imgui.ImVec2_Float(500,love.graphics.getHeight()-80))
        imgui.Begin("VizHelper Main", nil, imgui.love.WindowFlags("NoSavedSettings","NoResize", "NoTitleBar", "NoBorders", "NoMove", "NoBackground","NoBringToFrontOnFocus"))
            
            imgui.SetWindowPos_Vec2(imgui.ImVec2_Float(30, 50))

            imgui.Text("Welcome to VizHelper")
            imgui.Separator()
            if imgui.Button("Aston\nControl", imgui.ImVec2_Float(100, 100)) then
                AstonControl.show()
            end
            imgui.SameLine() 
            if imgui.Button("Ticker Control", imgui.ImVec2_Float(100, 100)) then
                TickerControl.show()
            end
            imgui.SameLine()

  
            if imgui.Button("Playout\nControl", imgui.ImVec2_Float(100, 100)) then
                PlayoutControl.show()
            end
            if imgui.IsItemHovered() then
                imgui.SetTooltip("in development - coming soon")
            end

            imgui.SameLine()
            if imgui.Button("Branding\nControl", imgui.ImVec2_Float(100,100)) then
                BrandingControl.show()
            end


            if imgui.Button("Headline\nControl", imgui.ImVec2_Float(100, 100)) then
                HeadlineControl.show()
            end
            imgui.SameLine()
            if imgui.Button("Tile Control", imgui.ImVec2_Float(100, 100)) then
                imgui.SetNextWindowPos(imgui.ImVec2_Float(500,120))
                showTileCon[0] = true
            end
            imgui.SameLine()
            if imgui.Button("Live Bug\nControl", imgui.ImVec2_Float(100, 100)) then
                imgui.SetNextWindowPos(imgui.ImVec2_Float(500,120))
                showLiveCon[0] = true            
            end
            imgui.SameLine()
            if imgui.Button("Automation\n    (Alpha)", imgui.ImVec2_Float(100, 100)) then
                imgui.SetNextWindowPos(imgui.ImVec2_Float(100,120))
                -- showAutomationCon[0] = true            
            end
            if imgui.IsItemHovered() then
                imgui.SetTooltip("in development - coming soon")
            end

            
            local text = "Connect to Viz2.0"
            if connectedToViz == true then
                text = "Connected to Viz2.0"
            end
            if connectedToViz then 
                imgui.PushStyleColor_Vec4(imgui.ImGuiCol_Button, imgui.ImVec4_Float(0, 0.5, 0, 1))
            else
                imgui.PushStyleColor_Vec4(imgui.ImGuiCol_Button, imgui.ImVec4_Float(0.5, 0, 0, 1))
            end
            if imgui.Button(text) then
                if connectedToViz == false then

                    GFX = sock.newClient(Settings.data.Connections.IP, 10655)
            
                    local connectSuccess, connectError = pcall(function() GFX:connect() end)

                    if connectSuccess == false then
                        --temporarily set GFX to a dummy object so it doesn't error
                        GFX = {error = true, on = function() end, send = function() end, update = function() end, disconnect = function() end, connect = function() end}
                        showError = true
                        errorTitle = "Connection Error"
                        errorMessage = "Couldn't connect to Viz2.0: \n"..connectError
                    end

                    registerCallbacks()

                else
                    GFX:disconnect()
                end
            end
            imgui.PopStyleColor()

            imgui.SameLine()
           
            imgui.Separator()

            
            imgui.Text("BETA - A MUCH EASIER AND CLEANER VERSION IS IN DEVELOPMENT")

            imgui.SetCursorPosY(love.graphics.getHeight()-140)
            if imgui.ImageButton("gearicon", gearIcon, imgui.ImVec2_Float(29, 25)) then
                imgui.SetNextWindowPos(imgui.ImVec2_Float(200,220))
                Settings.show()
            end
        imgui.End()

        if showTileCon[0] == true then
            
            imgui.Begin("Tile Control", showTileCon, imgui.love.WindowFlags("NoSavedSettings","NoResize"))
                imgui.SetWindowSize_Vec2(imgui.ImVec2_Float(200,120))
                imgui.Text("Control the BBC News tile")
                imgui.Separator()
                
                if imgui.Button("Show Tile") then
                    GFX:send("headline", {Type = "Show-TitleLogo"})
                end
                imgui.SameLine()
                if imgui.Button("Hide Tile") then
                    GFX:send("headline", {Type = "Hide-TitleLogo"})
                end
            imgui.End()
        end

        if showAutomationCon[0] == true then
            
            imgui.Begin("Automation (ALPHA 0.00000000000001)", showAutomationCon, imgui.love.WindowFlags("NoSavedSettings","NoResize"))
                imgui.SetWindowSize_Vec2(imgui.ImVec2_Float(800,400))
                imgui.PushFont(TimingsFont)
                imgui.Text("Automation (alpha)")
                imgui.PopFont()
                
                imgui.PushStyleColor_Vec4(imgui.ImGuiCol_ChildBg, imgui.ImVec4_Float(0.1,0.1,0.1,1))
                imgui.PushStyleVar_Vec2(imgui.ImGuiStyleVar_ChildRounding, imgui.ImVec2_Float(5,5))

                imgui.Text("Rundown items:")
                imgui.BeginListBox("###automationList",imgui.ImVec2_Float(8000, 12 * imgui.GetTextLineHeightWithSpacing()))
                    for i,v in ipairs(automationList) do
                        if imgui.CollapsingHeader_TreeNodeFlags(v.name, nil) then
                            imgui.BeginChild_Str("###childBox"..v.name,imgui.ImVec2_Float(imgui.GetWindowWidth()-8, 100))
                                if v.actions == nil then
                                    imgui.Text("There are no actions under this item") 
                                else
                                    for i2,v2 in ipairs(v.actions) do
                                        local assembled = ""
                                        if v2.data ~= {} then
                                            for i3,v3 in ipairs(v2.data) do
                                                assembled = assembled .. " " .. v3
                                            end
                                        end
                                        imgui.Selectable_Bool(v2.id.." / "..assembled.." / Delay: "..v2.delay.."ms###selectable"..v.name)
                                    end
                                end
                            
                            imgui.EndChild()
                        end
                    end
                imgui.EndListBox()

                    
                
             imgui.End()
        end

        if AstonControl.shouldShow[0] == true then
            AstonControl.draw()
        end

        if HeadlineControl.shouldShow[0] then
            HeadlineControl.draw()
        end

        if showLiveCon[0] == true then
            imgui.Begin("Live Control", showLiveCon, imgui.love.WindowFlags("NoSavedSettings", "NoResize"))
                imgui.SetWindowSize_Vec2(imgui.ImVec2_Float(800,400))
                
                imgui.Text("Control live straps")

                --Drop down
                imgui.Separator()
                imgui.Separator()

                imgui.PushFont(TimingsFont)
                imgui.Text("Live Bug")
                imgui.PopFont()
                imgui.Text("Location") imgui.SameLine()
                imgui.InputText("###liveBug1", liveBugText, 1024)

                imgui.Checkbox("Live###LiveCheckbox", liveBugLive)
                imgui.SameLine()
                imgui.Checkbox("Show Time###TimeLiveCheckbox", liveBugShowTime)

                imgui.Text("Side") imgui.SameLine()
                imgui.Combo_Str("###liveBugSide", liveBugSide, "Left\0Right\0")

                if liveBugShowTime[0] == true then 
                    imgui.InputInt("Offset in hours###liveOffsetInput", liveBugTimeOffset, 1, 2)

                    if liveBugTimeOffset[0] < -12 then liveBugTimeOffset[0] = -12 end
                    if liveBugTimeOffset[0] > 12 then liveBugTimeOffset[0] = 12 end
                end

                if imgui.Button("Show Bug") then
                    local text = ""
                    if liveBugLive[0] == true then
                        text = "LIVE   "
                    end
                    text = text..ffi.string(liveBugText)
                    local side = liveBugSide[0] == 1 and "right" or "left"
                    if liveBugShowTime[0] == false then
                        GFX:send("headline", {Type = "Show-PlaceName", Text = text, Side = side})
                    elseif liveBugShowTime[0] == true then
                        GFX:send("headline", {Type = "Show-PlaceNameWithTime", Text = text, Offset = liveBugTimeOffset[0], Side = side})
                    end
                end

                imgui.SameLine()

                if imgui.Button("Hide Bug") then
                    GFX:send("headline", {Type = "Hide-PlaceName"})
                end
             imgui.End()
        end

        if PlayoutControl.shouldShow[0] == true then
            -- PlayoutControl.draw()
        end

        if TickerControl.shouldShow[0] == true then
            TickerControl.draw()
        end

        if BrandingControl.shouldShow[0] == true then
            BrandingControl.draw()
        end

        if showError == true then 
            imgui.OpenPopup_Str(errorTitle)
            local center = imgui.ImVec2_Float(love.graphics.getWidth() / 2, love.graphics.getHeight() / 2)
            imgui.SetNextWindowPos(center, imgui.ImGuiCond_Appearing, imgui.ImVec2_Float(0.5, 0.5))

            if imgui.BeginPopupModal(errorTitle, nil, imgui.love.WindowFlags("AlwaysAutoResize", "NoSavedSettings", "NoMove"))then
                imgui.Text(errorMessage)
                
                imgui.Separator()
                if imgui.Button("OK", imgui.ImVec2_Float(120, 0)) then
                    imgui.CloseCurrentPopup()
                    showError = false
                end
            imgui.EndPopup()
            end
        end

        if Settings.shouldShow[0] == true then
            Settings.draw()
        end



    imgui.End()


-- code to render imgui
imgui.Render()
imgui.love.RenderDrawLists()

end




function love.mousemoved(x, y, ...)
    imgui.love.MouseMoved(x, y)
    if not imgui.love.GetWantCaptureMouse() then
        -- your code here
    end
end

function love.mousepressed(x, y, button, ...)
    imgui.love.MousePressed(button)
    if not imgui.love.GetWantCaptureMouse() then
        -- your code here 
    end
end

function love.mousereleased(x, y, button, ...)
    imgui.love.MouseReleased(button)
    if not imgui.love.GetWantCaptureMouse() then
        -- your code here 
    end
end

function love.wheelmoved(x, y)
    imgui.love.WheelMoved(x, y)
    if not imgui.love.GetWantCaptureMouse() then
        -- your code here 
    end
end

function love.keypressed(key, ...)
    --if ShowSaveDialog == true or ShowOpenDialog == true then else 
        imgui.love.KeyPressed(key)
        imgui.love.RunShortcuts(key)
        if not imgui.love.GetWantCaptureKeyboard() then
            -- your code here
        end 
    --end
end

function love.keyreleased(key, ...)
    --if ShowSaveDialog == true or ShowOpenDialog == true then else imgui.love.KeyReleased(key) end
    imgui.love.KeyReleased(key)
    if not imgui.love.GetWantCaptureKeyboard() then
        -- your code here 
    end
end

function love.textinput(t)
    --if ShowSaveDialog == true or ShowOpenDialog == true then else  end
    imgui.love.TextInput(t)
    if imgui.love.GetWantCaptureKeyboard() then
        -- your code here 
    end
end

function love.quit()
    bitser.dumpLoveFile("badges.dat", AstonControl.presetBadges)
    bitser.dumpLoveFile("branding.dat", BrandingControl.brandingPresets)
    return imgui.love.Shutdown()
end

-- for gamepad support also add the following:

function love.joystickadded(joystick)
    imgui.love.JoystickAdded(joystick)
    -- your code here 
end

function love.joystickremoved(joystick)
    imgui.love.JoystickRemoved()
    -- your code here 
end

function love.gamepadpressed(joystick, button)
    imgui.love.GamepadPressed(button)
    -- your code here 
end

function love.gamepadreleased(joystick, button)
    imgui.love.GamepadReleased(button)
    -- your code here 
end

-- choose threshold for considering analog controllers active, defaults to 0 if unspecified
local threshold = 0.2 

function love.gamepadaxis(joystick, axis, value)
    imgui.love.GamepadAxis(axis, value, threshold)
    -- your code here 
end








function convertTableToCondensedString(tbl)
    local str = ""
    for i, num in ipairs(tbl) do
        str = str .. string.format("%.1f", num)
        if i < #tbl then
            str = str .. "/"
        end
    end
    return str
end
