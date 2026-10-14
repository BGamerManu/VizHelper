local brandingControl = {}

brandingControl.shouldShow = ffi.new("bool[1]", false)

brandingControl.show = function()
    brandingControl.shouldShow[0] = true
end

brandingControl.List = {
    {
        name = "News Channel Original",
        channelName = "NEWS",
        themeColor = {184/255,0,0},

        headlineStrap = {
            logo = "default",
            text = "channelName",
            newsBarColor = "themeColor",
            leftBarColor = "themeColor",
            
            gillFont = false,
        },

        ticker = {
            opaque = false,
            tickerColor = "default",

            defaultText = "bbc.co.uk/news",

            headlinesText = "HEADLINES",
            
            redSquare = "themeColor",
        },

        newsBar = {
            logo = "default",
            text = "channelName",
            newsBarColor = "themeColor",
            clearBarColor = "themeColor",

            clockColor = "themeColor",
            clockMode = "On",

            fasterOutAnimation = false,

            gillFont = false,
        },

        straps = {
            breakingColor = "themeColor",
            breakingText = "BREAKING",

            breakingLogoText = "BREAKING",
            breakingLogoColor = "themeColor",
            breakingLogoShowWithScroll = true,
        },

        badges = {
            socialsBadgeColor = "themeColor",
            creditBadgeColor = "themeColor",
        },

        tile = {
            logo = "default",
        },

        liveBugs = {
            text = "LIVE",
            liveBoxColor = "themeColor",
            barColor = "themeColor",
            clearPartColor = "themeColor",

        }
        
    }
}

brandingControl.brandingNameBox = ffi.new("char[1024]", "News Red Straps")
brandingControl.brandingThemeNameBox = ffi.new("char[1024]", "NEWS")
brandingControl.brandingThemeColor = ffi.new("float[3]", {0.68,0,0})
brandingControl.brandingTickerOpaque = ffi.new("bool[1]", true)
brandingControl.brandingColoredStrap = ffi.new("bool[1]", true)
brandingControl.clockModeBox = ffi.new("int[1]", 0)

brandingControl.brandingPresets = {}
--The program always starts with the first saved branding (News Red Straps)
brandingControl.brandingPresetSelected = 1
if love.filesystem.getInfo("branding.dat") ~= nil then
    ---@diagnostic disable-next-line: cast-local-type
    brandingControl.brandingPresets = bitser.loadLoveFile("branding.dat")
else
    brandingControl.brandingPresets = {
        {name = "News Red Straps",channelName = "NEWS", opaque = true, coloredStrap = true, themeColor = {0.68,0,0}, mode = "Channel", clockMode = "default"},
        {name = "News Channel Original",channelName = "NEWS", opaque = false, coloredStrap = false, themeColor = {0.68,0,0}, mode = "Channel", clockMode = "default"},
        {name = "World News", channelName = "WORLD NEWS", opaque = false, coloredStrap = false, themeColor = {0.68,0,0}, mode = "World", clockMode = "off"},
        {name = "Breakfast", channelName = "BREAKFAST", opaque = false, coloredStrap = false, themeColor = {0.95,0.3,0}, mode = "Breakfast", clockMode = "breakfast"},
        {name = "Region Example (NWT)", channelName = "NORTH WEST TONIGHT", opaque = false, coloredStrap = false, themeColor = {0.68, 0, 0}, mode = "Region", clockMode = "default"},
    }
    bitser.dumpLoveFile("branding.dat", brandingControl.brandingPresets)
end

--Send what the boxes say (News Red Straps when the program starts) to Viz2.0
brandingControl.send = function()
    local xclockMode = "default"
    if brandingControl.clockModeBox[0] == 1 then
        xclockMode = "off"
    elseif brandingControl.clockModeBox[0] == 2 then
        xclockMode = "breakfast"
    end
    GFX:send("headline", {Type = "Set-Branding", channelName = ffi.string(brandingControl.brandingThemeNameBox), opaque = brandingControl.brandingTickerOpaque[0], coloredStrap = brandingControl.brandingColoredStrap[0], ThemeColor = {brandingControl.brandingThemeColor[0],brandingControl.brandingThemeColor[1],brandingControl.brandingThemeColor[2]}, clockMode = xclockMode})
end

brandingControl.draw = function()
    imgui.Begin("Branding Control", brandingControl.shouldShow, imgui.love.WindowFlags("NoSavedSettings", "NoResize"))
    imgui.SetWindowSize_Vec2(imgui.ImVec2_Float(800,400))

        imgui.PushFont(TimingsFont)
        imgui.Text("Branding")
        imgui.PopFont()                                 
        imgui.Text("Controls branding of all onscreen graphics")
        imgui.Separator()
        imgui.Separator()

        imgui.Text("Branding Theme name")
        imgui.SameLine()
        imgui.InputText("###brandingThemeName", brandingControl.brandingNameBox, 1024)

        imgui.Text("Channel name")
        imgui.SameLine()
        imgui.InputText("###brandingNameInput", brandingControl.brandingThemeNameBox, 1024)

        imgui.Text("Theme colour")
        imgui.SameLine()
        imgui.ColorEdit3("###brandingColorInput",brandingControl.brandingThemeColor,imgui.love.ColorEditFlags("None"))

        imgui.Text("Clock mode")
        imgui.SameLine()
        if imgui.Combo_Str("###clockModeCombo", brandingControl.clockModeBox, "On\0Off\0Breakfast Clock\0") then
            if brandingControl.clockModeBox[0] == 0 then
                brandingControl.brandingPresets[brandingControl.brandingPresetSelected].clockMode = "default"
            elseif brandingControl.clockModeBox[0] == 1 then
                brandingControl.brandingPresets[brandingControl.brandingPresetSelected].clockMode = "off"
            elseif brandingControl.clockModeBox[0] == 2 then
                brandingControl.brandingPresets[brandingControl.brandingPresetSelected].clockMode = "breakfast"
            end
        end

        imgui.Checkbox("Opaque ticker", brandingControl.brandingTickerOpaque)
        imgui.SameLine()
        imgui.Checkbox("Coloured Straps", brandingControl.brandingColoredStrap)
        
        
        if brandingControl.brandingPresets[1].name ~= "News Red Straps" then
            table.insert(brandingControl.brandingPresets, 1, {name = "News Red Straps", channelName = "NEWS", opaque = true, coloredStrap = true, themeColor = {0.68,0,0}, clockMode = "default"})
        end
        

        imgui.Text("Saved brandings")
        imgui.SameLine()
        imgui.BeginListBox("###brandingPresetList",imgui.ImVec2_Float(300, 80))
        ---@diagnostic disable-next-line: param-type-mismatch
        for i, v in ipairs(brandingControl.brandingPresets) do
                local selected = false
                if brandingControl.brandingPresetSelected == i then
                    selected = true


                end

                -- imgui.PushStyleColor_Vec4(imgui.ImGuiCol_Text, imgui.ImVec4_Float(v.tcolor[1], v.tcolor[2], v.tcolor[3], 1))
                -- imgui.PushStyleColor_Vec4(imgui.ImGuiCol_FrameBg, imgui.ImVec4_Float(1,0,0, 1))
                if imgui.Selectable_Bool(v.name.."###"..i, selected) then
                    brandingControl.brandingPresetSelected = i
                    brandingControl.brandingNameBox = ffi.new("char[1024]", v.name)
                    brandingControl.brandingThemeNameBox = ffi.new("char[1024]", v.channelName)
                    brandingControl.brandingThemeColor[0] = v.themeColor[1]
                    brandingControl.brandingThemeColor[1] = v.themeColor[2]
                    brandingControl.brandingThemeColor[2] = v.themeColor[3]
                    if v.opaque == nil then brandingControl.brandingTickerOpaque[0] = false else brandingControl.brandingTickerOpaque[0] = v.opaque end
                    if v.coloredStrap == nil then brandingControl.brandingColoredStrap[0] = false else brandingControl.brandingColoredStrap[0] = v.coloredStrap end

                    
                    if v.clockMode == "default" then
                        brandingControl.clockModeBox[0] = 0
                    elseif v.clockMode == "off" then
                        brandingControl.clockModeBox[0] = 1
                    elseif v.clockMode == "breakfast" then
                        brandingControl.clockModeBox[0] = 2
                    end
                    
                    GFX:send("headline", {Type = "Set-Branding", channelName = ffi.string(brandingControl.brandingThemeNameBox), opaque = v.opaque, coloredStrap = v.coloredStrap, ThemeColor = {brandingControl.brandingThemeColor[0],brandingControl.brandingThemeColor[1],brandingControl.brandingThemeColor[2]}, clockMode = v.clockMode})


                end
                imgui.SameLine()
                imgui.PushStyleColor_Vec4(imgui.ImGuiCol_ChildBg, imgui.ImVec4_Float(v.themeColor[1], v.themeColor[2], v.themeColor[3], 1))
                    imgui.BeginChild_Str("###brandingPresetColExample"..i, imgui.ImVec2_Float(30,18))
                    imgui.EndChild()
                imgui.PopStyleColor()
            end
        imgui.EndListBox()

        imgui.SetCursorPosX(110)

        if imgui.Button("Save branding") then
            table.insert(brandingControl.brandingPresets, {name = ffi.string(brandingControl.brandingNameBox), channelName = ffi.string(brandingControl.brandingThemeNameBox), themeColor = {brandingControl.brandingThemeColor[0], brandingControl.brandingThemeColor[1], brandingControl.brandingThemeColor[2]}, opaque = brandingControl.brandingTickerOpaque[0], coloredStrap = brandingControl.brandingColoredStrap[0]})
        end 

        imgui.SameLine()

        if imgui.Button("Remove selected branding") then
            table.remove(brandingControl.brandingPresets, brandingControl.brandingPresetSelected)
            brandingControl.brandingPresetSelected = 0
        end

        imgui.SameLine()
        
        if imgui.Button("Send Branding") then
            brandingControl.send()
        end

        imgui.Text("Custom logos coming soon....")

    imgui.End()
end


return brandingControl