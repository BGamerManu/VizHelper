local titleControl = {}

titleControl.shouldShow = ffi.new("bool[1]", false)

titleControl.show = function()
    titleControl.shouldShow[0] = true
end

titleControl.draw = function()
    imgui.Begin("Title Control", titleControl.shouldShow, imgui.love.WindowFlags("NoSavedSettings", "NoResize"))
        imgui.SetWindowSize_Vec2(imgui.ImVec2_Float(620,230))

        imgui.PushFont(TitleFont)
        imgui.Text("Titles (BBC News, Chameleon)")
        imgui.PopFont()
        imgui.Text("The text under the BBC blocks is the channel name from Branding Control")

        --The titles are BBC graphics: they are not used with another logo
        local locked = LogoControl.active()
        if locked then
            imgui.PushStyleColor_Vec4(imgui.ImGuiCol_Text, imgui.ImVec4_Float(1, 0.6, 0.2, 1))
            imgui.Text("Locked: the logo in Branding Control is not the BBC one ("..LogoControl.name()..").")
            imgui.PopStyleColor()
            imgui.BeginDisabled()
        end

        if imgui.Button("Show Title") then
            GFX:send("headline", {Type = "Show-TitleLogo", Style = "chameleon"})
        end
        imgui.SameLine()
        if imgui.Button("Hide Title") then
            GFX:send("headline", {Type = "Hide-TitleLogo"})
        end

        imgui.Separator()

        imgui.PushFont(TitleFont)
        imgui.Text("Legacy titles (Red boxed BBC News Logo)")
        imgui.PopFont()

        if imgui.Button("Show Legacy Title") then
            GFX:send("headline", {Type = "Show-TitleLogo", Style = "legacy"})
        end
        imgui.SameLine()
        if imgui.Button("Hide Legacy Title") then
            GFX:send("headline", {Type = "Hide-TitleLogo"})
        end

        if locked then imgui.EndDisabled() end
    imgui.End()
end

return titleControl
