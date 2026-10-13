local wires = {}

--local showWires = ffi.new("bool[1]", false)

local gathering = true

local BBCWorldSCR = [[
    local xml2lua = require("lib.xml2lua")
    local handler = require("lib.xmlhandler.tree")
    local wireGatherChannel = love.thread.getChannel("wireGatherChannel")
    local socket = require("socket.http")
    local parser = xml2lua.parser(handler)
     local wireGatherData = ""
    local wireGatherURLS = {"http://rss.playsamay4.com:2082/bbcworld"}
    local inspect = require "lib.inspect"

    for i = 1, #wireGatherURLS do
        wireGatherData = socket.request(wireGatherURLS[1])

        if wireGatherData == nil then return end
    
        --The server may answer with something that is not RSS (e.g. a redirect page): ignore it instead of crashing the helper
        if not pcall(parser.parse, parser, wireGatherData) then return end
        --if i == 1 then print(inspect(handler)) end
        if handler.root.rss == nil then return end
        local wireGatherTable = handler.root.rss.channel.item
        local wireData = handler.root.rss.channel
        
        wireGatherChannel:push(wireGatherTable)
        wireGatherChannel:push(wireData)
    end

]]

local BBCUKSCR = [[
    local xml2lua = require("lib.xml2lua")
    local handler = require("lib.xmlhandler.tree")
    local wireGatherChannel = love.thread.getChannel("wireGatherChannel")
    local socket = require("socket.http")
    local parser = xml2lua.parser(handler)
     local wireGatherData = ""
    local wireGatherURLS = {"http://rss.playsamay4.com:2082/bbcuk"}
    local inspect = require "lib.inspect"

    for i = 1, #wireGatherURLS do
        wireGatherData = socket.request(wireGatherURLS[1])

        if wireGatherData == nil then return end
    
        --The server may answer with something that is not RSS (e.g. a redirect page): ignore it instead of crashing the helper
        if not pcall(parser.parse, parser, wireGatherData) then return end
        --if i == 1 then print(inspect(handler)) end
          if handler.root.rss == nil then return end
        local wireGatherTable = handler.root.rss.channel.item
        local wireData = handler.root.rss.channel
        
        wireGatherChannel:push(wireGatherTable)
        wireGatherChannel:push(wireData)
    end

]]

wires.wireData = {}

local BBCWorldThread = love.thread.newThread(BBCWorldSCR)
--BBCWorldThread:start()

local BBCUKThread = love.thread.newThread(BBCUKSCR)
BBCUKThread:start()


lastUpdated = os.date("%c")


function wires.Update(dt)
        local wireGatherChannel = love.thread.getChannel("wireGatherChannel")
        local wireGatherData = wireGatherChannel:pop()
        if wireGatherData then
            
            gathering = false
            local data = wireGatherChannel:pop()

            if data == nil then return end
            if data.item == nil then return end

            for i = 1, #wireGatherData do
                if wireGatherData[i].title ~= nil then table.insert(wires.wireData, wireGatherData[i].title) end
            end



        end
end

function fillWithWorldWires()
    wires.wireData = {}
    BBCWorldThread:start()
end

function fillWithUKWires()
    wires.wireData = {}
    BBCUKThread:start()
end

return wires
