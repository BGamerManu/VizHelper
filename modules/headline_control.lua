local headlineControl = {}

headlineControl.shouldShow = ffi.new("bool[1]", false)

headlineControl.show = function()
    headlineControl.shouldShow[0] = true
end

headlineControl.headlineStrap1 = ffi.new("char[1024]", "")
headlineControl.headlineStrapComingUp = ffi.new("bool[1]", false)


headlineControl.draw = function()
    imgui.Begin("Headline Control", headlineControl.shouldShow, imgui.love.WindowFlags("NoSavedSettings", "NoResize"))
        imgui.SetWindowSize_Vec2(imgui.ImVec2_Float(800,250))

        imgui.PushFont(TimingsFont)
        imgui.Text("Headline Strap")
        imgui.PopFont()
        imgui.InputTextWithHint("###headlineStrap1","Headline text (one line, a long headline shrinks to fit)", headlineControl.headlineStrap1, 1024)

        imgui.Text("Coming Up badge") imgui.SameLine()
        imgui.Checkbox("###headlineStrapComing", headlineControl.headlineStrapComingUp)



        imgui.SetCursorPosY(200)
        if imgui.Button("Show Strap", imgui.ImVec2_Float(400,40)) then
            local style = ""
            if headlineControl.headlineStrapComingUp[0] == true then
                style = style.."ComingUp"
            end

            GFX:send("headline", {Type = "Show-Headline", Text = ffi.string(headlineControl.headlineStrap1), Style = style})
        end

        imgui.SameLine()

        if imgui.Button("Hide Strap",imgui.ImVec2_Float(400,40) ) then
            GFX:send("headline", {Type = "Hide-Headline"})
        end

    imgui.End()
end

return headlineControl
