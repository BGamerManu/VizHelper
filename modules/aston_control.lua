local astonControl = {}

astonControl.shouldShow = ffi.new("bool[1]", false)


astonControl.lowerThirdText = ffi.new("char[1024]", "")
astonControl.lowerThirdText2 = ffi.new("char[1024]", "")
astonControl.lowerThirdText3 = ffi.new("char[1024]", "")
astonControl.lowerThirdText4 = ffi.new("char[1024]", "")

astonControl.breakingTitle = ffi.new("char[1024]", "")
astonControl.breakingText = ffi.new("char[1024]", "")
astonControl.breakingText1 = ffi.new("char[1024]", "")
astonControl.breakingText2 = ffi.new("char[1024]", "")

astonControl.badgeText = ffi.new("char[1024]", "")
astonControl.badgeBGColor = ffi.new("float[3]",{0.68,0,0})
astonControl.badgeTextColor = ffi.new("float[3]",{1,1,1})

astonControl.socialBadgeText = ffi.new("char[1024]", "")
astonControl.creditBadgeText = ffi.new("char[1024]", "")

astonControl.nameStrapText1 = ffi.new("char[1024]", "")
astonControl.nameStrapText2 = ffi.new("char[1024]", "")



astonControl.presetBadges = {}

if love.filesystem.getInfo("badges.dat") ~= nil then
    ---@diagnostic disable-next-line: cast-local-type
    astonControl.presetBadges = bitser.loadLoveFile("badges.dat")
else
    astonControl.presetBadges = {
        {"NEWS AT NINE", bcolor = {.7,0,0,1}, tcolor = {1,1,1,1}},
        {"NEWS AT FIVE", bcolor = {.7,0,0,1}, tcolor = {1,1,1,1}},
        {"ACROSS THE UK", bcolor = {.7,0,0,1}, tcolor = {1,1,1,1}},
        {"BUSINESS BREIFING", bcolor = {.7,0,0,1}, tcolor = {1,1,1,1}},
        {"REVIEW 2022", bcolor = {.7,0,0,1}, tcolor = {1,1,1,1}},
        {"OUTSIDE SOURCE", bcolor = {.9,0,0,1}, tcolor = {1,1,1,1}},
        {"THE BRIEFING", bcolor = {.9,0,0,1}, tcolor = {1,1,1,1}},
        {"WORLD NEWS TODAY", bcolor = {.9,0,0,1}, tcolor = {1,1,1,1}},
        {"OUTSIDE SOURCE", bcolor = {.9,0,0,1}, tcolor = {1,1,1,1}},
        {"THE CONTEXT", bcolor = {.9,0,0,1}, tcolor = {1,1,1,1}},
        {"OUTSIDE SOURCE", bcolor = {0,0.5,.8,1}, tcolor = {1,1,1,1}},
        {"NEWSROOM LIVE", bcolor = {1,1,1,1}, tcolor = {.7,0,0,0}},
        {"AFTERNOON LIVE", bcolor = {1,0.3,0,1}, tcolor = {1,1,1,1}},
        {"NEWSDAY", bcolor = {1,0.4,0,1}, tcolor = {1,1,1,1}},
        {"IMPACT", bcolor = {0.9,0.2,0,1}, tcolor = {1,1,1,1}},
        {"WORKLIFE", bcolor = {0.9,0.5,0.2,1}, tcolor = {1,1,1,1}},
        {"BEYOND 100 DAYS", bcolor = {0,0.4,0.5,1}, tcolor = {1,1,1,1}},
        {"THE CONTEXT", bcolor = {0,0.4,0.5,1}, tcolor = {1,1,1,1}},
        {"THE PAPERS", bcolor = {0,0.4,0.5,1}, tcolor = {1,1,1,1}},
        {"BUSINESS LIVE", bcolor = {0,0.3,0.6,1}, tcolor = {1,1,1,1}},
        {"GLOBAL", bcolor = {0.1,0.6,0.6,1}, tcolor = {1,1,1,1}},
        {"NICKY CAMPBELL", bcolor = {0,0.7,0.7,1}, tcolor = {0,0,0,1}},
        {"FOCUS ON AFRICA", bcolor = {0.3,0.5,0,1}, tcolor = {1,1,1,1}},
        {"G M T", bcolor = {0.6,0,0.5,1}, tcolor = {1,1,1,1}},
        {"SPORTSDAY", bcolor = {0.9,0.7,0,1}, tcolor = {0,0,0,1}},
        {"YOUR QUESTIONS ANSWERED", bcolor = {0.4,0.4,0.4,1}, tcolor = {1,1,1,1}},        
    }
    bitser.dumpLoveFile("badges.dat", astonControl.presetBadges)
end

astonControl.presetBadgeSelected = 0

astonControl.show = function()
    astonControl.shouldShow[0] = true
end

astonControl.draw = function()
    imgui.Begin("Aston Control", astonControl.shouldShow, imgui.love.WindowFlags("NoSavedSettings","NoResize"))
        imgui.SetWindowSize_Vec2(imgui.ImVec2_Float(800,450))
        imgui.PushFont(TitleFont)
        imgui.PopFont()


        imgui.Separator()

        if imgui.BeginTabBar("Tabs") then
            if imgui.BeginTabItem("Text Strap") then
                imgui.PushFont(TimingsFont)
                imgui.Text("Text Strap")
                imgui.PopFont()
                imgui.InputTextWithHint("###lowerThirdTopLineText", "Top line text", astonControl.lowerThirdText, 1024)
                imgui.InputTextWithHint("###lowerThirdBottomLineText1", "Bottom line text (1/2) Leave blank for a single line strap" ,astonControl.lowerThirdText2, 1024)
                imgui.InputTextWithHint("###lowerThirdBottomLineText2", "Bottom line (2/2) Leave blank if you don't want it to scroll", astonControl.lowerThirdText3, 1024)
                imgui.InputTextWithHint("###lowerThirdTextBadgeText", "Text to appear next to logo (Ex. IN BRIEF) leave blank for none" , astonControl.lowerThirdText4, 1024)

                if imgui.Button("Show/Update Strap") then
                    if ffi.string(astonControl.lowerThirdText) == "" then
                        showError = true
                        errorTitle = "You missed a field!"
                        errorMessage = "You need to input text for the top line"
                        return
                    end
                    
                    GFX:send("headline", {Type = "Show-LowerThirdText", Text = ffi.string(astonControl.lowerThirdText).."\n"..ffi.string(astonControl.lowerThirdText2).."\n"..ffi.string(astonControl.lowerThirdText3), BoxText = ffi.string(astonControl.lowerThirdText4)})
                end

                imgui.SameLine()

                if imgui.Button("Hide Strap") then
                    GFX:send("headline", {Type = "Hide-LowerThirdText"})
                end
                imgui.EndTabItem()
            end

            if imgui.BeginTabItem("Breaking Strap") then
                imgui.PushFont(TimingsFont)
                imgui.Text("Breaking Strap")
                imgui.PopFont()


                imgui.InputTextWithHint("###breakingTitle", "Title of breaking news story (Appears after BREAKING, optional)", astonControl.breakingTitle, 1024)
                imgui.InputTextWithHint("###breakingTopLine", "Text to appear on the top line", astonControl.breakingText, 1024)
                imgui.InputTextWithHint("###breakingBottomLine1", "Text to appear on the bottom line (1/2) Leave blank for a single line strap", astonControl.breakingText1, 1024)
                imgui.InputTextWithHint("###breakingBottomLine2", "Bottom line (2/2) Leave blank if you don't want it to scroll", astonControl.breakingText2, 1024)

                imgui.Text("Show/Update again with new text to change it without taking the strap down")

                if imgui.Button("Show/Update BREAKING") then
                    GFX:send("headline", {Type = "Show-BreakingTitle", Text = ffi.string(astonControl.breakingTitle)})
                end

                imgui.SameLine()

                if imgui.Button("Scroll BREAKING") then
                    GFX:send("headline", {Type = "Advance-BreakingTitle"})
                end

                imgui.SameLine()

                if imgui.Button("Show/Update Strap###breaking") then
                    if ffi.string(astonControl.breakingText) == "" then
                        showError = true
                        errorTitle = "You missed a field!"
                        errorMessage = "You need to input the breaking strap's top line"
                        return
                    end

                    GFX:send("headline", {Type = "Show-BreakingLowerThird", Text = ffi.string(astonControl.breakingText).."\n"..ffi.string(astonControl.breakingText1).."\n"..ffi.string(astonControl.breakingText2)})
                end

                imgui.SameLine()

                if imgui.Button("Hide Strap###breakingHideStrap") then
                    GFX:send("headline", {Type = "Hide-BreakingLowerThird"})
                end
                imgui.EndTabItem()
            end

            if imgui.BeginTabItem("Name Strap") then
                imgui.PushFont(TimingsFont)
                imgui.Text("Name Strap")
                imgui.PopFont()
                
                imgui.InputTextWithHint("##nameStrap1", "Text to appear on the top line", astonControl.nameStrapText1, 1024)
                imgui.InputTextWithHint("##nameStrap2", "Text to appear on the bottom line, leave empty for top only",  astonControl.nameStrapText2, 1024)

                if imgui.Button("Show Name Strap") then
                    if ffi.string(astonControl.nameStrapText1) == "" then
                        showError = true
                        errorTitle = "You missed a field!"
                        errorMessage = "You need at least input text for the top line"
                        return
                    end

                    if ffi.string(astonControl.nameStrapText2) == "" then
                        GFX:send("headline", {Type = "Show-PresenterName", Text = ffi.string(astonControl.nameStrapText1)})
                    else
                        GFX:send("headline", {Type = "Show-PresenterName", Text = ffi.string(astonControl.nameStrapText1).."\n"..ffi.string(astonControl.nameStrapText2)})
                    end
                end

                imgui.SameLine()

                if imgui.Button("Hide Name Strap") then
                    GFX:send("headline", {Type = "Hide-PresenterName"})
                end
                imgui.EndTabItem()
            end

            if imgui.BeginTabItem("Programme Badge") then
                imgui.PushFont(TimingsFont)
                imgui.Text("Programme Badge")
                imgui.PopFont()

                imgui.Text("Badge Text") imgui.SameLine()
                imgui.InputText("###lowerThirdBadgeText",astonControl.badgeText, 1024)

                imgui.Text("Background Colour") imgui.SameLine()
                imgui.ColorEdit3("###lowerThirdBadgeBGColor",astonControl.badgeBGColor, imgui.love.ColorEditFlags("None"))

                imgui.Text("Text Colour") imgui.SameLine()
                imgui.ColorEdit3("###lowerThirdBadgeTextColor",astonControl.badgeTextColor, imgui.love.ColorEditFlags("None"))
                
                if imgui.Button("Set Badge") then
                    GFX:send("headline", {Type = "Set-ProgramBadge", Text = ffi.string(astonControl.badgeText), TextColor = convertTableToCondensedString({astonControl.badgeTextColor[0], astonControl.badgeTextColor[1], astonControl.badgeTextColor[2]}), BackgroundColor = convertTableToCondensedString({astonControl.badgeBGColor[0], astonControl.badgeBGColor[1], astonControl.badgeBGColor[2]})})    
                end

                imgui.SameLine()

                if imgui.Button("Remove Badge") then
                    GFX:send("headline", {Type = "Remove-ProgramBadge"})
                end

                imgui.SameLine()

                if imgui.Button("Show Badge") then
                    print(convertTableToCondensedString({astonControl.badgeTextColor[0], astonControl.badgeTextColor[1], astonControl.badgeTextColor[2]}))
                    GFX:send("headline", {Type = "Show-ProgramBadge", Text = ffi.string(astonControl.badgeText), TextColor = convertTableToCondensedString({astonControl.badgeTextColor[0], astonControl.badgeTextColor[1], astonControl.badgeTextColor[2]}), BackgroundColor = convertTableToCondensedString({astonControl.badgeBGColor[0], astonControl.badgeBGColor[1], astonControl.badgeBGColor[2]})})
                end

                imgui.SameLine()

                if imgui.Button("Hide Badge") then
                    GFX:send("headline", {Type = "Hide-ProgramBadge"})
                end

                imgui.SameLine()
                imgui.SetCursorPosX(400)

                imgui.BeginListBox("###programBadgeList",imgui.ImVec2_Float(300, 80))
                    ---@diagnostic disable-next-line: param-type-mismatch
                    for i, v in ipairs(astonControl.presetBadges) do
                        local selected = false
                        if presetBadgeSelected == i then
                            selected = true
                        end

                        -- imgui.PushStyleColor_Vec4(imgui.ImGuiCol_Text, imgui.ImVec4_Float(v.tcolor[1], v.tcolor[2], v.tcolor[3], 1))
                        -- imgui.PushStyleColor_Vec4(imgui.ImGuiCol_FrameBg, imgui.ImVec4_Float(1,0,0, 1))
                        if imgui.Selectable_Bool(v[1].."###"..i, selected) then
                            astonControl.presetBadgeSelected = i
                            astonControl.badgeText = ffi.new("char[1024]", v[1])
                            astonControl.badgeTextColor[0] = v.tcolor[1]
                            astonControl.badgeTextColor[1] = v.tcolor[2]
                            astonControl.badgeTextColor[2] = v.tcolor[3]
                            astonControl.badgeBGColor[0] = v.bcolor[1]
                            astonControl.badgeBGColor[1] = v.bcolor[2]
                            astonControl.badgeBGColor[2] = v.bcolor[3]
                        end
                        imgui.SameLine()
                        imgui.PushStyleColor_Vec4(imgui.ImGuiCol_ChildBg, imgui.ImVec4_Float(v.bcolor[1], v.bcolor[2], v.bcolor[3], 1))
                            imgui.BeginChild_Str("###programBadgeColExample"..i, imgui.ImVec2_Float(30,18))
                            imgui.EndChild()
                        imgui.PopStyleColor()
                    end
                imgui.EndListBox()

                imgui.SetCursorPosX(420)

                if imgui.Button("Save badge") then
                    table.insert(astonControl.presetBadges, {ffi.string(astonControl.badgeText), tcolor = {astonControl.badgeTextColor[0], astonControl.badgeTextColor[1], astonControl.badgeTextColor[2]}, bcolor = {astonControl.badgeBGColor[0], astonControl.badgeBGColor[1], astonControl.badgeBGColor[2]}})

                end 

                imgui.SameLine()

                if imgui.Button("Remove selected badge") then
                    table.remove(astonControl.presetBadges, presetBadgeSelected)
                    presetBadgeSelected = 0
                end
                imgui.EndTabItem()
            end

            if imgui.BeginTabItem("Other badges") then
                imgui.PushFont(TimingsFont)
                imgui.Text("Misc. badges")
                imgui.PopFont()

                imgui.Text("Socials badge text:")
                imgui.SameLine()
                imgui.InputText("###socialBadgeTextInput", astonControl.socialBadgeText, 1024)
                imgui.SameLine()
                if imgui.Button("Show###socialBadgeButtonShow") then
                    GFX:send("headline", {Type = "Show-SocialsBadge", Text = ffi.string(astonControl.socialBadgeText)})
                end
                imgui.SameLine()
                if imgui.Button("Hide###socialBadgeButtonHide") then
                    GFX:send("headline", {Type = "Hide-SocialsBadge"})
                end

                imgui.Text("Credit badge text:")
                imgui.SameLine()
                imgui.InputText("###creditBadgeTextInput", astonControl.creditBadgeText, 1024)
                imgui.SameLine()
                if imgui.Button("Show###creditBadgeButtonShow") then
                    GFX:send("headline", {Type = "Show-CreditBadge", Text = ffi.string(astonControl.creditBadgeText)})
                end
                imgui.SameLine()
                if imgui.Button("Hide###creditBadgeButtonHide") then
                    GFX:send("headline", {Type = "Hide-CreditBadge"})
                end      
                imgui.EndTabItem()  
            end

            if imgui.BeginTabItem("Misc.") then
                imgui.PushFont(TimingsFont)
                imgui.Text("Miscellaneous")
                imgui.PopFont()

                if imgui.Button("Hide clock") then
                    GFX:send("headline", {Type = "Hide-Clock"})
                end                   
                imgui.EndTabItem()
            end

            imgui.EndTabBar()
        end

        imgui.Separator()
        
        imgui.SetCursorPosY(400)
        if imgui.Button("Show News Bar", imgui.ImVec2_Float(400,40)) then
            GFX:send("headline", {Type = "ShowLowerThird"})
        end
        imgui.SameLine()
        if imgui.Button("Hide News Bar", imgui.ImVec2_Float(380,40)) then
            GFX:send("headline", {Type = "HideLowerThird"})
        end

    imgui.End()
end

return astonControl