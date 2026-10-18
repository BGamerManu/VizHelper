--Own taskbar identity, so Windows does not group VizHelper with Viz2.0 (both run on love.exe)
if jit.os == "Windows" then
    local ffi = require "ffi"
    ffi.cdef[[int SetCurrentProcessExplicitAppUserModelID(const wchar_t *AppID);]]
    local id = "beebViz.VizHelper"
    local w = ffi.new("wchar_t[?]", #id + 1)
    for i = 1, #id do w[i - 1] = id:byte(i) end
    pcall(function() ffi.load("shell32").SetCurrentProcessExplicitAppUserModelID(w) end)
end

function love.conf(t)
    t.window.title = "VizHelper BETA"
    t.window.width = 1280
    t.window.height = 720
    t.window.resizable = true
end
