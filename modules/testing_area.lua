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
        imgui.SetWindowSize_Vec2(imgui.ImVec2_Float(560,330))

        imgui.PushFont(TimingsFont)
        imgui.Text("Testing area")
        imgui.PopFont()
        imgui.Separator()

        imgui.PushFont(TitleFont)
        imgui.Text("Transition")
        imgui.PopFont()
        if imgui.Button("Wipe transition") then send("Wipe") end

        imgui.PushFont(TitleFont)
        imgui.Text("News Bar")
        imgui.PopFont()
        if imgui.Button("Show ticker only") then send("Show-TickerOnly") end
        imgui.SameLine()
        if imgui.Button("Hide ticker only") then send("Hide-TickerOnly") end
        if imgui.Button("Show clock") then send("Show-Clock") end
        imgui.SameLine()
        if imgui.Button("Hide clock") then send("Hide-Clock") end

        imgui.PushFont(TitleFont)
        imgui.Text("Viz2.0 window")
        imgui.PopFont()
        if imgui.Button("Toggle backdrop") then send("Toggle-Backdrop") end
        imgui.SameLine()
        if imgui.Button("Toggle scaled window") then send("Toggle-WindowMode") end
    imgui.End()
end

return testingArea
