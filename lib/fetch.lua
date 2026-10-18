--Downloads a URL in a thread (lib/http.lua, so HTTPS works) without freezing the panel.
--fetch.get(url, maxBytes, function(body, errorMessage) end); fetch.update() must be called every frame.
local fetch = {}

local httpSource = love.filesystem.read("lib/http.lua")
local jobs = {}

local threadCode = [[
    require "love.thread"
    local source, url, maxBytes, channel = ...
    local ok, http = pcall(function() return loadstring(source)() end)
    if not ok then channel:push({err = tostring(http)}) return end
    local body, status, err = http.get(url, maxBytes)
    channel:push({body = body, err = err})
]]

function fetch.get(url, maxBytes, callback)
    local channel = love.thread.newChannel()
    local thread = love.thread.newThread(threadCode)
    thread:start(httpSource, url, maxBytes, channel)
    jobs[#jobs + 1] = {channel = channel, thread = thread, callback = callback}
end

function fetch.update()
    for i = #jobs, 1, -1 do
        local result = jobs[i].channel:pop()
        if result then
            local callback = jobs[i].callback
            table.remove(jobs, i)
            callback(result.body, result.err)
        end
    end
end

return fetch
