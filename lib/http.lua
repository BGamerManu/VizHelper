--HTTP / HTTPS GET through the Windows WinHTTP library (luasocket has no HTTPS). Windows only, like the rest of VizHelper.
--Loaded inside love.thread code too, so it must not use any love.* function.
local ffi = require "ffi"

ffi.cdef[[
typedef void* HINTERNET;
HINTERNET WinHttpOpen(const wchar_t*, uint32_t, const wchar_t*, const wchar_t*, uint32_t);
HINTERNET WinHttpConnect(HINTERNET, const wchar_t*, uint16_t, uint32_t);
HINTERNET WinHttpOpenRequest(HINTERNET, const wchar_t*, const wchar_t*, const wchar_t*, const wchar_t*, const wchar_t**, uint32_t);
int WinHttpSendRequest(HINTERNET, const wchar_t*, uint32_t, void*, uint32_t, uint32_t, uintptr_t);
int WinHttpReceiveResponse(HINTERNET, void*);
int WinHttpReadData(HINTERNET, void*, uint32_t, uint32_t*);
int WinHttpQueryHeaders(HINTERNET, uint32_t, const wchar_t*, void*, uint32_t*, uint32_t*);
int WinHttpSetOption(HINTERNET, uint32_t, void*, uint32_t);
int WinHttpSetTimeouts(HINTERNET, int, int, int, int);
int WinHttpCloseHandle(HINTERNET);
]]

local winhttp = ffi.load("winhttp")
local http = {}

--Only ASCII goes in: the callers percent-encode the query (see http.encode)
local function wide(s)
    local buf = ffi.new("wchar_t[?]", #s + 1)
    for i = 1, #s do buf[i - 1] = s:byte(i) end
    return buf
end

function http.encode(s)
    return (s:gsub("[^%w%-_%.~]", function(c) return string.format("%%%02X", c:byte()) end))
end

--Returns body, status. On failure: nil, status (or nil), error message. maxBytes caps the answer (default 4 MB).
function http.get(url, maxBytes)
    maxBytes = maxBytes or 4 * 1024 * 1024
    local scheme, host, port, path = url:match("^(https?)://([^/:]+):?(%d*)(/?.*)$")
    if not scheme then return nil, nil, "Bad URL: "..tostring(url) end
    if path == "" then path = "/" end
    local secure = scheme == "https"
    port = tonumber(port) or (secure and 443 or 80)

    local session = winhttp.WinHttpOpen(wide("VizHelper/1.4 (https://github.com/BGamerManu/VizHelper)"), 0, nil, nil, 0)
    if session == nil then return nil, "WinHttpOpen failed" end

    local connection, request
    local function finish(body, status, err)
        if request ~= nil then winhttp.WinHttpCloseHandle(request) end
        if connection ~= nil then winhttp.WinHttpCloseHandle(connection) end
        winhttp.WinHttpCloseHandle(session)
        return body, status, err
    end

    winhttp.WinHttpSetTimeouts(session, 10000, 10000, 15000, 20000)
    connection = winhttp.WinHttpConnect(session, wide(host), port, 0)
    if connection == nil then return finish(nil, nil, "Cannot connect to "..host) end
    request = winhttp.WinHttpOpenRequest(connection, wide("GET"), wide(path), nil, nil, nil, secure and 0x00800000 or 0)
    if request == nil then return finish(nil, nil, "WinHttpOpenRequest failed") end

    --Follow redirects also from http to https (the old BBC feeds do that)
    local policy = ffi.new("uint32_t[1]", 2)
    winhttp.WinHttpSetOption(request, 88, policy, 4)

    if winhttp.WinHttpSendRequest(request, nil, 0, nil, 0, 0, 0) == 0 or winhttp.WinHttpReceiveResponse(request, nil) == 0 then
        return finish(nil, nil, "No answer from "..host)
    end

    local status = ffi.new("uint32_t[1]")
    local size = ffi.new("uint32_t[1]", 4)
    winhttp.WinHttpQueryHeaders(request, 19 + 0x20000000, nil, status, size, nil) --STATUS_CODE | FLAG_NUMBER
    if status[0] ~= 200 then return finish(nil, status[0], "HTTP "..status[0]) end

    local parts, total = {}, 0
    local chunk = ffi.new("char[16384]")
    local read = ffi.new("uint32_t[1]")
    while winhttp.WinHttpReadData(request, chunk, 16384, read) ~= 0 and read[0] > 0 do
        total = total + read[0]
        if total > maxBytes then return finish(nil, 200, "Answer is bigger than "..math.floor(maxBytes / 1024).." KB") end
        parts[#parts + 1] = ffi.string(chunk, read[0])
    end
    return finish(table.concat(parts), 200)
end

return http
