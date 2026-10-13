local testingArea = {}

testingArea.shouldShow = ffi.new("bool[1]", false)

testingArea.show = function()
    testingArea.shouldShow[0] = true
end

local function send(requestType)
    GFX:send("headline", {Type = requestType})
end

testingArea.draw = function()
    imgui.Begin("Testing area", testingArea.shouldShow, imgui.love.WindowFlags("NoSavedSettings", "NoResize"))
        imgui.SetWindowSize_Vec2(imgui.ImVec2_Float(560,430))

        imgui.PushFont(TimingsFont)
        imgui.Text("Testing area")
        imgui.PopFont()
        imgui.Text("Things Viz2.0 only does from a keyboard shortcut (the key is in brackets)")
        imgui.Separator()

        imgui.PushFont(TitleFont)
        imgui.Text("Transition")
        imgui.PopFont()
        if imgui.Button("Wipe transition (Space)") then send("Wipe") end

        imgui.PushFont(TitleFont)
        imgui.Text("News Bar")
        imgui.PopFont()
        if imgui.Button("Show ticker only (Numpad 1)") then send("Show-TickerOnly") end
        imgui.SameLine()
        if imgui.Button("Hide ticker only (Numpad 2)") then send("Hide-TickerOnly") end
        if imgui.Button("Show clock (9)") then send("Show-Clock") end
        imgui.SameLine()
        if imgui.Button("Hide clock (0)") then send("Hide-Clock") end

        imgui.PushFont(TitleFont)
        imgui.Text("Breakfast intro clock")
        imgui.PopFont()
        if imgui.Button("Show breakfast clock (;)") then send("Show-BreakfastIntroClock") end
        imgui.SameLine()
        if imgui.Button("Hide breakfast clock (\\)") then send("Hide-BreakfastIntroClock") end

        imgui.PushFont(TitleFont)
        imgui.Text("Viz2.0 window")
        imgui.PopFont()
        if imgui.Button("Toggle backdrop (Numpad *)") then send("Toggle-Backdrop") end
        imgui.SameLine()
        if imgui.Button("Toggle Gill Sans mode (G)") then send("Toggle-GillMode") end
        if imgui.Button("Hide splash screen (N)") then send("Hide-Splash") end
        imgui.SameLine()
        if imgui.Button("Toggle scaled window (F11)") then send("Toggle-WindowMode") end
    imgui.End()
end

return testingArea
