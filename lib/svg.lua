--A small SVG rasterizer: svg.render(text, maxSide) -> ImageData cropped to the drawing (or nil, error message).
--LÖVE cannot draw SVG, so shapes are scan converted here (4 sub-scanlines per pixel, exact horizontal coverage).
--shortcut: no text, images, filters, masks, clip paths, markers or dashed strokes, gradients become their average colour,
--group opacity is multiplied into each child. Upgrade when a logo needs one of them.
local ffi = require "ffi"

local svg = {}

local floor, ceil, min, max, abs, sqrt = math.floor, math.ceil, math.min, math.max, math.abs, math.sqrt
local sin, cos, atan2, pi = math.sin, math.cos, math.atan2, math.pi

--------------------------------------------------------------------------------------------------- XML

local function unescape(s)
    return (s:gsub("&(#?x?%w+);", function(e)
        if e == "amp" then return "&" elseif e == "lt" then return "<" elseif e == "gt" then return ">"
        elseif e == "quot" then return '"' elseif e == "apos" then return "'" end
        local n = e:match("^#x(%x+)$")
        n = n and tonumber(n, 16) or tonumber(e:match("^#(%d+)$"))
        return n and n < 128 and string.char(n) or "?"
    end))
end

--Elements are {name, attr, children, text}; text only matters for <style>
local function parseXML(s)
    local root = {name = "#root", attr = {}, children = {}}
    local stack = {root}
    local pos = 1
    while true do
        local lt = s:find("<", pos, true)
        if not lt then break end
        local top = stack[#stack]
        if s:sub(lt, lt + 3) == "<!--" then
            local e = s:find("-->", lt + 4, true)
            pos = e and e + 3 or #s + 1
        elseif s:sub(lt, lt + 8) == "<![CDATA[" then
            local e = s:find("]]>", lt + 9, true) or #s
            top.text = (top.text or "")..s:sub(lt + 9, e - 1)
            pos = e + 3
        elseif s:sub(lt, lt + 1) == "<?" then
            pos = (s:find("?>", lt + 2, true) or #s) + 2
        elseif s:sub(lt, lt + 1) == "<!" then
            local e
            if s:match("^<!DOCTYPE[^>]*%[", lt) then e = s:find("]>", lt, true); e = e and e + 1 else e = s:find(">", lt, true) end
            pos = (e or #s) + 1
        elseif s:sub(lt, lt + 1) == "</" then
            if #stack > 1 then stack[#stack] = nil end
            pos = (s:find(">", lt, true) or #s) + 1
        else
            local name, p = s:match("^<([%w_:%.%-]+)()", lt)
            if not name then return nil, "Not an SVG file" end
            local el = {name = name:match("([^:]+)$"), attr = {}, children = {}}
            while true do
                local a, q, v, np = s:match("^%s*([%w_:%.%-]+)%s*=%s*([\"'])(.-)%2()", p)
                if not a then break end
                el.attr[a] = unescape(v)
                p = np
            end
            local slash, np = s:match("^%s*(/?)>()", p)
            if not np then return nil, "Broken SVG tag" end
            top.children[#top.children + 1] = el
            if slash ~= "/" then stack[#stack + 1] = el end
            pos = np
            --Text of <style> (only element whose text is read)
            if el.name == "style" and slash ~= "/" then
                local e = s:find("</", pos, true) or #s + 1
                local body = s:sub(pos, e - 1)
                el.text = body:gsub("<!%[CDATA%[", ""):gsub("%]%]>", "")
            end
        end
    end
    return root
end

--------------------------------------------------------------------------------------------------- styles

local NAMED = {
    black = {0, 0, 0}, white = {1, 1, 1}, red = {1, 0, 0}, green = {0, 128/255, 0}, blue = {0, 0, 1},
    yellow = {1, 1, 0}, orange = {1, 165/255, 0}, gray = {128/255, 128/255, 128/255}, grey = {128/255, 128/255, 128/255},
    silver = {192/255, 192/255, 192/255}, lightgray = {211/255, 211/255, 211/255}, lightgrey = {211/255, 211/255, 211/255},
    darkgray = {169/255, 169/255, 169/255}, darkgrey = {169/255, 169/255, 169/255}, navy = {0, 0, 128/255},
    maroon = {128/255, 0, 0}, purple = {128/255, 0, 128/255}, teal = {0, 128/255, 128/255}, lime = {0, 1, 0},
    aqua = {0, 1, 1}, cyan = {0, 1, 1}, magenta = {1, 0, 1}, fuchsia = {1, 0, 1}, olive = {128/255, 128/255, 0},
    brown = {165/255, 42/255, 42/255}, pink = {1, 192/255, 203/255}, gold = {1, 215/255, 0}, crimson = {220/255, 20/255, 60/255},
    darkblue = {0, 0, 139/255}, darkred = {139/255, 0, 0}, darkgreen = {0, 100/255, 0}, royalblue = {65/255, 105/255, 225/255},
}

local INHERIT = {fill = true, ["fill-opacity"] = true, ["fill-rule"] = true, stroke = true, ["stroke-width"] = true,
    ["stroke-opacity"] = true, ["stroke-linecap"] = true, visibility = true, color = true}
local OWN = {opacity = true, display = true, ["stop-color"] = true, ["stop-opacity"] = true}

local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

--"a:b; c:d" -> iterator-friendly list
local function declarations(s)
    local list = {}
    for k, v in s:gmatch("([%w%-]+)%s*:%s*([^;]+)") do list[#list + 1] = {k, (trim(v):gsub("%s*!important", ""))} end
    return list
end

--Rules like ".st0{fill:#fff}" or "path, .a{...}". Selectors with spaces or > are ignored.
local function parseCSS(text)
    local rules = {}
    text = text:gsub("/%*.-%*/", "")
    for sels, body in text:gmatch("([^{}]+){([^}]*)}") do
        local decl = declarations(body)
        for sel in sels:gmatch("[^,]+") do
            sel = trim(sel)
            if sel ~= "" and not sel:find("[%s>+~:%[]") then
                local tag, id, classes = sel:match("^([%w%*]*)"), sel:match("#([%w_%-]+)"), {}
                for c in sel:gmatch("%.([%w_%-]+)") do classes[#classes + 1] = c end
                rules[#rules + 1] = {tag = tag, id = id, classes = classes, decl = decl}
            end
        end
    end
    return rules
end

local function ruleMatches(rule, el)
    if rule.tag ~= "" and rule.tag ~= "*" and rule.tag ~= el.name then return false end
    if rule.id and el.attr.id ~= rule.id then return false end
    if #rule.classes > 0 then
        local have = {}
        for c in (el.attr.class or ""):gmatch("%S+") do have[c] = true end
        for _, c in ipairs(rule.classes) do if not have[c] then return false end end
    end
    return true
end

local function styleOf(el, parent, rules)
    local st = {}
    for k in pairs(INHERIT) do st[k] = parent[k] end
    for k, v in pairs(el.attr) do
        if INHERIT[k] or OWN[k] then st[k] = trim(v) end
    end
    for _, rule in ipairs(rules) do
        if ruleMatches(rule, el) then
            for _, kv in ipairs(rule.decl) do
                if INHERIT[kv[1]] or OWN[kv[1]] then st[kv[1]] = kv[2] end
            end
        end
    end
    if el.attr.style then
        for _, kv in ipairs(declarations(el.attr.style)) do
            if INHERIT[kv[1]] or OWN[kv[1]] then st[kv[1]] = kv[2] end
        end
    end
    return st
end

--------------------------------------------------------------------------------------------------- colours

local colour

--A gradient is painted with the average of its stops
local function gradientColour(el, ids, rules, depth)
    if depth > 4 then return {0, 0, 0} end
    local r, g, b, n = 0, 0, 0, 0
    for _, child in ipairs(el.children) do
        if child.name == "stop" then
            local st = styleOf(child, {}, rules)
            local c = colour(st["stop-color"] or "black", {}, ids, rules, depth + 1) or {0, 0, 0}
            r, g, b, n = r + c[1], g + c[2], b + c[3], n + 1
        end
    end
    if n == 0 then
        local href = (el.attr["xlink:href"] or el.attr.href or ""):match("^#(.+)$")
        if href and ids[href] then return gradientColour(ids[href], ids, rules, depth + 1) end
        return {0, 0, 0}
    end
    return {r / n, g / n, b / n}
end

--Returns {r, g, b} (0..1) or nil for "no paint"
colour = function(v, st, ids, rules, depth)
    depth = depth or 0
    if not v then return nil end
    v = trim(v):lower()
    if v == "" or v == "none" or v == "transparent" then return nil end
    if v == "currentcolor" then return colour(st.color or "black", {}, ids, rules, depth + 1) end
    local hex = v:match("^#(%x+)$")
    if hex then
        if #hex == 3 or #hex == 4 then
            return {tonumber(hex:sub(1, 1), 16) / 15, tonumber(hex:sub(2, 2), 16) / 15, tonumber(hex:sub(3, 3), 16) / 15}
        elseif #hex >= 6 then
            return {tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255}
        end
        return {0, 0, 0}
    end
    local inner = v:match("^rgba?%(([^)]*)%)")
    if inner then
        local c = {}
        for num, pct in inner:gmatch("([%d%.]+)(%%?)") do
            c[#c + 1] = pct == "%" and tonumber(num) / 100 or tonumber(num) / 255
            if #c == 3 then break end
        end
        return {c[1] or 0, c[2] or 0, c[3] or 0}
    end
    local id = v:match("^url%(#?['\"]?#?([^)'\"]+)")
    if id then
        local el = ids[id]
        if el then return gradientColour(el, ids, rules, depth) end
        return nil
    end
    return NAMED[v] or {0, 0, 0}
end

--------------------------------------------------------------------------------------------------- transforms

--Number at position i of path data, or nil
local function pathNumber(d, i)
    local mant, p = d:match("^[%s,]*([+-]?%d*%.?%d*)()", i)
    if not mant or not mant:find("%d") then return nil end
    local ex, p2 = d:match("^([eE][+-]?%d+)()", p)
    if ex then mant, p = mant..ex, p2 end
    return tonumber(mant), p
end

--All the numbers of a string (transform arguments, viewBox, points)
local function numbers(s)
    local list, i = {}, 1
    while true do
        local v, p = pathNumber(s, i)
        if not v then return list end
        list[#list + 1], i = v, p
    end
end

local function mul(p, q)
    return {
        p[1] * q[1] + p[3] * q[2], p[2] * q[1] + p[4] * q[2],
        p[1] * q[3] + p[3] * q[4], p[2] * q[3] + p[4] * q[4],
        p[1] * q[5] + p[3] * q[6] + p[5], p[2] * q[5] + p[4] * q[6] + p[6],
    }
end

local function parseTransform(s)
    local m = {1, 0, 0, 1, 0, 0}
    for name, args in s:gmatch("(%a+)%s*%(([^)]*)%)") do
        local a = numbers(args)
        local t
        if name == "matrix" and #a >= 6 then t = {a[1], a[2], a[3], a[4], a[5], a[6]}
        elseif name == "translate" then t = {1, 0, 0, 1, a[1] or 0, a[2] or 0}
        elseif name == "scale" then t = {a[1] or 1, 0, 0, a[2] or a[1] or 1, 0, 0}
        elseif name == "rotate" then
            local r = math.rad(a[1] or 0)
            t = {cos(r), sin(r), -sin(r), cos(r), 0, 0}
            if a[2] then t = mul(mul({1, 0, 0, 1, a[2], a[3] or 0}, t), {1, 0, 0, 1, -a[2], -(a[3] or 0)}) end
        elseif name == "skewX" then t = {1, 0, math.tan(math.rad(a[1] or 0)), 1, 0, 0}
        elseif name == "skewY" then t = {1, math.tan(math.rad(a[1] or 0)), 0, 1, 0, 0}
        end
        if t then m = mul(m, t) end
    end
    return m
end

--------------------------------------------------------------------------------------------------- paths -> polygons (device space)

local function dist(x0, y0, x1, y1) return sqrt((x1 - x0) ^ 2 + (y1 - y0) ^ 2) end

--Turns path data into a list of polygons (flat x,y arrays, .closed marks z)
local function buildPath(d, m, subs)
    local i, n = 1, #d
    local cx, cy, sx, sy = 0, 0, 0, 0 --current and start point (user space)
    local cur
    local lastC2x, lastC2y, lastQx, lastQy

    local function tx(x, y) return m[1] * x + m[3] * y + m[5], m[2] * x + m[4] * y + m[6] end

    local function moveTo(x, y)
        cur = {}
        subs[#subs + 1] = cur
        cur[1], cur[2] = tx(x, y)
        cx, cy, sx, sy = x, y, x, y
    end

    local function lineTo(x, y)
        if not cur then moveTo(cx, cy) end
        local X, Y = tx(x, y)
        cur[#cur + 1], cur[#cur + 2] = X, Y
        cx, cy = x, y
    end

    local function cubicTo(x1, y1, x2, y2, x, y)
        if not cur then moveTo(cx, cy) end
        local k = #cur
        local X0, Y0 = cur[k - 1], cur[k]
        local X1, Y1 = tx(x1, y1)
        local X2, Y2 = tx(x2, y2)
        local X3, Y3 = tx(x, y)
        local len = dist(X0, Y0, X1, Y1) + dist(X1, Y1, X2, Y2) + dist(X2, Y2, X3, Y3)
        local steps = max(4, min(64, ceil(len / 4)))
        for s = 1, steps do
            local t = s / steps
            local u = 1 - t
            local a, b, c, e = u * u * u, 3 * u * u * t, 3 * u * t * t, t * t * t
            cur[#cur + 1] = a * X0 + b * X1 + c * X2 + e * X3
            cur[#cur + 1] = a * Y0 + b * Y1 + c * Y2 + e * Y3
        end
        cx, cy = x, y
    end

    local function quadTo(qx, qy, x, y)
        cubicTo(cx + 2 / 3 * (qx - cx), cy + 2 / 3 * (qy - cy), x + 2 / 3 * (qx - x), y + 2 / 3 * (qy - y), x, y)
    end

    local function arcTo(rx, ry, phiDeg, fa, fs, x2, y2)
        local x1, y1 = cx, cy
        if x1 == x2 and y1 == y2 then return end
        rx, ry = abs(rx), abs(ry)
        if rx == 0 or ry == 0 then lineTo(x2, y2) return end
        local phi = math.rad(phiDeg)
        local c, s = cos(phi), sin(phi)
        local dx, dy = (x1 - x2) / 2, (y1 - y2) / 2
        local x1p, y1p = c * dx + s * dy, -s * dx + c * dy
        local lam = x1p ^ 2 / rx ^ 2 + y1p ^ 2 / ry ^ 2
        if lam > 1 then local sl = sqrt(lam); rx, ry = rx * sl, ry * sl end
        local num = rx ^ 2 * ry ^ 2 - rx ^ 2 * y1p ^ 2 - ry ^ 2 * x1p ^ 2
        local den = rx ^ 2 * y1p ^ 2 + ry ^ 2 * x1p ^ 2
        local co = sqrt(max(0, num / den))
        if fa == fs then co = -co end
        local cxp, cyp = co * rx * y1p / ry, -co * ry * x1p / rx
        local ccx, ccy = c * cxp - s * cyp + (x1 + x2) / 2, s * cxp + c * cyp + (y1 + y2) / 2
        local th1 = atan2((y1p - cyp) / ry, (x1p - cxp) / rx)
        local th2 = atan2((-y1p - cyp) / ry, (-x1p - cxp) / rx)
        local dth = th2 - th1
        if fs == 0 and dth > 0 then dth = dth - 2 * pi elseif fs == 1 and dth < 0 then dth = dth + 2 * pi end
        local segs = max(1, ceil(abs(dth) / (pi / 2) - 1e-9))
        local delta = dth / segs
        local t = 8 / 3 * sin(delta / 4) ^ 2 / sin(delta / 2)
        local function map(u, v) return ccx + rx * c * u - ry * s * v, ccy + rx * s * u + ry * c * v end
        for k = 0, segs - 1 do
            local a1 = th1 + k * delta
            local a2 = a1 + delta
            local c1, s1, c2, s2 = cos(a1), sin(a1), cos(a2), sin(a2)
            local p1x, p1y = map(c1 - t * s1, s1 + t * c1)
            local p2x, p2y = map(c2 + t * s2, s2 - t * c2)
            local ex, ey = map(c2, s2)
            if k == segs - 1 then ex, ey = x2, y2 end
            cubicTo(p1x, p1y, p2x, p2y, ex, ey)
        end
    end

    local cmd
    while true do
        local c, np = d:match("^[%s,]*(%a)()", i)
        if c then cmd, i = c, np
        elseif not pathNumber(d, i) then break end
        if not cmd then break end
        local rel = cmd:lower() == cmd
        local C = cmd:lower()
        local ox, oy = rel and cx or 0, rel and cy or 0
        local nums = {}
        local need = ({m = 2, l = 2, h = 1, v = 1, c = 6, s = 4, q = 4, t = 2, a = 7, z = 0})[C]
        if not need then return end
        for k = 1, need do
            if C == "a" and (k == 4 or k == 5) then
                local f, p = d:match("^[%s,]*([01])()", i)
                if not f then return end
                nums[k], i = tonumber(f), p
            else
                local v, p = pathNumber(d, i)
                if not v then return end
                nums[k], i = v, p
            end
        end
        if C == "m" then
            moveTo(nums[1] + ox, nums[2] + oy)
            cmd = rel and "l" or "L" --extra pairs after a moveto are lineto
        elseif C == "l" then lineTo(nums[1] + ox, nums[2] + oy)
        elseif C == "h" then lineTo(nums[1] + ox, cy)
        elseif C == "v" then lineTo(cx, nums[1] + oy)
        elseif C == "c" then
            cubicTo(nums[1] + ox, nums[2] + oy, nums[3] + ox, nums[4] + oy, nums[5] + ox, nums[6] + oy)
            lastC2x, lastC2y = nums[3] + ox, nums[4] + oy
        elseif C == "s" then
            local x1, y1 = cx, cy
            if lastC2x then x1, y1 = 2 * cx - lastC2x, 2 * cy - lastC2y end
            cubicTo(x1, y1, nums[1] + ox, nums[2] + oy, nums[3] + ox, nums[4] + oy)
            lastC2x, lastC2y = nums[1] + ox, nums[2] + oy
        elseif C == "q" then
            quadTo(nums[1] + ox, nums[2] + oy, nums[3] + ox, nums[4] + oy)
            lastQx, lastQy = nums[1] + ox, nums[2] + oy
        elseif C == "t" then
            local qx, qy = cx, cy
            if lastQx then qx, qy = 2 * cx - lastQx, 2 * cy - lastQy end
            quadTo(qx, qy, nums[1] + ox, nums[2] + oy)
            lastQx, lastQy = qx, qy
        elseif C == "a" then
            arcTo(nums[1], nums[2], nums[3], nums[4], nums[5], nums[6] + ox, nums[7] + oy)
        elseif C == "z" then
            if cur then cur.closed = true end
            cx, cy = sx, sy
            cur, cmd = nil, nil --numbers after z without a command are garbage
        end
        if C ~= "c" and C ~= "s" then lastC2x = nil end
        if C ~= "q" and C ~= "t" then lastQx = nil end
    end
end

local pathToPolys = buildPath

--------------------------------------------------------------------------------------------------- strokes -> polygons

local function orient(p)
    local area = 0
    local n = #p / 2
    for k = 1, n do
        local k2 = k % n + 1
        area = area + p[2 * k - 1] * p[2 * k2] - p[2 * k2 - 1] * p[2 * k]
    end
    if area < 0 then
        local r = {}
        for k = n, 1, -1 do r[#r + 1], r[#r + 2] = p[2 * k - 1], p[2 * k] end
        return r
    end
    return p
end

local function disc(x, y, r)
    local p = {}
    for k = 0, 7 do
        local a = k * pi / 4 + pi / 8
        p[#p + 1], p[#p + 2] = x + r * cos(a), y + r * sin(a)
    end
    return p
end

local function strokePolys(subs, width, roundCaps)
    local out = {}
    local hw = width / 2
    for _, sub in ipairs(subs) do
        local n = #sub / 2
        local segs = sub.closed and n or n - 1
        for k = 1, segs do
            local k2 = k % n + 1
            local x0, y0, x1, y1 = sub[2 * k - 1], sub[2 * k], sub[2 * k2 - 1], sub[2 * k2]
            local len = dist(x0, y0, x1, y1)
            if len > 1e-6 then
                local nx, ny = -(y1 - y0) / len * hw, (x1 - x0) / len * hw
                out[#out + 1] = orient({x0 + nx, y0 + ny, x1 + nx, y1 + ny, x1 - nx, y1 - ny, x0 - nx, y0 - ny})
            end
        end
        for k = 1, n do
            local interior = sub.closed or (k > 1 and k < n)
            if interior or roundCaps then out[#out + 1] = orient(disc(sub[2 * k - 1], sub[2 * k], hw)) end
        end
    end
    return out
end

--------------------------------------------------------------------------------------------------- rasterizer

local SS = 4 --sub-scanlines per pixel

local function newCanvas(w, h)
    return {w = w, h = h, px = ffi.new("float[?]", w * h * 4), row = ffi.new("float[?]", w + 2), painted = 0}
end

--Fills polygons (flat x,y arrays) in colour c with the given alpha, nonzero or even-odd
local function fillPolys(cv, polys, evenodd, c, alpha)
    local W, H, px, row = cv.w, cv.h, cv.px, cv.row
    local minx, maxx, miny, maxy = math.huge, -math.huge, math.huge, -math.huge
    for _, p in ipairs(polys) do
        for k = 1, #p, 2 do
            if p[k] < minx then minx = p[k] end
            if p[k] > maxx then maxx = p[k] end
            if p[k + 1] < miny then miny = p[k + 1] end
            if p[k + 1] > maxy then maxy = p[k + 1] end
        end
    end
    if minx > maxx or alpha <= 0 then return end
    local y0, y1 = max(0, floor(miny)), min(H - 1, floor(maxy))
    local x0, x1 = max(0, floor(minx)), min(W - 1, floor(maxx))
    if y1 < y0 or x1 < x0 then return end

    --A white shape over the whole canvas that comes first is a background, not part of the logo
    if cv.painted == 0 and c[1] > 0.96 and c[2] > 0.96 and c[3] > 0.96 and (maxx - minx) >= W * 0.98 and (maxy - miny) >= H * 0.98 then return end
    cv.painted = cv.painted + 1

    local nsub = (y1 - y0 + 1) * SS
    local cxs, cds = {}, {}
    for _, p in ipairs(polys) do
        local n = #p / 2
        for k = 1, n do
            local k2 = k % n + 1
            local xa, ya, xb, yb = p[2 * k - 1], p[2 * k], p[2 * k2 - 1], p[2 * k2]
            if ya ~= yb then
                local dir = 1
                if ya > yb then xa, ya, xb, yb, dir = xb, yb, xa, ya, -1 end
                local first = max(0, ceil((ya - y0) * SS - 0.5))
                local last = min(nsub - 1, ceil((yb - y0) * SS - 0.5) - 1)
                local slope = (xb - xa) / (yb - ya)
                for si = first, last do
                    local x = xa + (y0 + (si + 0.5) / SS - ya) * slope
                    local xs, ds = cxs[si], cds[si]
                    if not xs then xs, ds = {}, {}; cxs[si], cds[si] = xs, ds end
                    local j = #xs
                    while j >= 1 and xs[j] > x do xs[j + 1], ds[j + 1] = xs[j], ds[j]; j = j - 1 end
                    xs[j + 1], ds[j + 1] = x, dir
                end
            end
        end
    end

    local r, g, b = c[1], c[2], c[3]
    local weight = 1 / SS
    for y = y0, y1 do
        for x = x0, x1 + 1 do row[x] = 0 end
        for s = 0, SS - 1 do
            local si = (y - y0) * SS + s
            local xs, ds = cxs[si], cds[si]
            if xs then
                local w = 0
                for j = 1, #xs - 1 do
                    w = w + ds[j]
                    local inside
                    if evenodd then inside = w % 2 ~= 0 else inside = w ~= 0 end
                    if inside then
                        local xa, xb = max(xs[j], 0), min(xs[j + 1], W)
                        if xb > xa then
                            local ia, ib = floor(xa), floor(xb)
                            if ia == ib then
                                row[ia] = row[ia] + (xb - xa) * weight
                            else
                                row[ia] = row[ia] + (ia + 1 - xa) * weight
                                for x = ia + 1, ib - 1 do row[x] = row[x] + weight end
                                row[ib] = row[ib] + (xb - ib) * weight
                            end
                        end
                    end
                end
            end
        end
        for x = x0, x1 do
            local cov = row[x]
            if cov > 0.001 then
                if cov > 1 then cov = 1 end
                local al = cov * alpha
                local k = (y * W + x) * 4
                local ia = 1 - al
                px[k] = r * al + px[k] * ia
                px[k + 1] = g * al + px[k + 1] * ia
                px[k + 2] = b * al + px[k + 2] * ia
                px[k + 3] = al + px[k + 3] * ia
            end
        end
    end
end

--------------------------------------------------------------------------------------------------- walking the document

local function len(v, default)
    return tonumber(v and v:match("^%s*([%-+]?[%d%.]+)")) or default
end

local SHAPES = {path = true, rect = true, circle = true, ellipse = true, line = true, polygon = true, polyline = true}
local GROUPS = {g = true, a = true, switch = true, svg = true, symbol = true}

local function render(root, rules, ids, cv, rootM)
    local function paint(el, st, m, opacity, subs, isLine)
        if st.visibility == "hidden" or st.visibility == "collapse" then return end
        local scale = sqrt(abs(m[1] * m[4] - m[2] * m[3]))
        local fillPaint = not isLine and colour(st.fill or "black", st, ids, rules)
        if fillPaint then
            local polys = {}
            for _, s in ipairs(subs) do if #s >= 6 then polys[#polys + 1] = s end end
            fillPolys(cv, polys, st["fill-rule"] == "evenodd", fillPaint, opacity * (tonumber(st["fill-opacity"]) or 1))
        end
        local strokePaint = colour(st.stroke, st, ids, rules)
        if strokePaint then
            local w = (len(st["stroke-width"], 1)) * scale
            fillPolys(cv, strokePolys(subs, max(w, 0.5), st["stroke-linecap"] == "round" or st["stroke-linecap"] == "square"), false, strokePaint, opacity * (tonumber(st["stroke-opacity"]) or 1))
        end
    end

    local function shapePolys(el, m)
        local a, subs = el.attr, {}
        local name = el.name
        if name == "path" then
            pathToPolys(a.d or "", m, subs)
        elseif name == "rect" then
            local x, y, w, h = len(a.x, 0), len(a.y, 0), len(a.width, 0), len(a.height, 0)
            local rx, ry = len(a.rx), len(a.ry)
            rx, ry = rx or ry or 0, ry or rx or 0
            rx, ry = min(rx, w / 2), min(ry, h / 2)
            if w <= 0 or h <= 0 then return subs end
            if rx > 0 and ry > 0 then
                pathToPolys(string.format("M%f %f H%f A%f %f 0 0 1 %f %f V%f A%f %f 0 0 1 %f %f H%f A%f %f 0 0 1 %f %f V%f A%f %f 0 0 1 %f %f Z",
                    x + rx, y, x + w - rx, rx, ry, x + w, y + ry, y + h - ry, rx, ry, x + w - rx, y + h, x + rx, rx, ry, x, y + h - ry, y + ry, rx, ry, x + rx, y), m, subs)
            else
                pathToPolys(string.format("M%f %f H%f V%f H%f Z", x, y, x + w, y + h, x), m, subs)
            end
        elseif name == "circle" or name == "ellipse" then
            local cx, cy = len(a.cx, 0), len(a.cy, 0)
            local rx = name == "circle" and len(a.r, 0) or len(a.rx, 0)
            local ry = name == "circle" and rx or len(a.ry, 0)
            if rx <= 0 or ry <= 0 then return subs end
            pathToPolys(string.format("M%f %f A%f %f 0 1 1 %f %f A%f %f 0 1 1 %f %f Z", cx - rx, cy, rx, ry, cx + rx, cy, rx, ry, cx - rx, cy), m, subs)
        elseif name == "line" then
            pathToPolys(string.format("M%f %f L%f %f", len(a.x1, 0), len(a.y1, 0), len(a.x2, 0), len(a.y2, 0)), m, subs)
        else --polygon / polyline
            local nums = numbers(a.points or "")
            local d = {}
            for k = 1, #nums - 1, 2 do d[#d + 1] = (k == 1 and "M" or "L")..nums[k].." "..nums[k + 1] end
            if name == "polygon" then d[#d + 1] = "Z" end
            pathToPolys(table.concat(d, " "), m, subs)
        end
        return subs
    end

    local function walk(el, parentSt, m, opacity, depth)
        if depth > 40 then return end
        local st = styleOf(el, parentSt, rules)
        if st.display == "none" then return end
        if el.attr.transform then m = mul(m, parseTransform(el.attr.transform)) end
        opacity = opacity * (tonumber(st.opacity) or 1)
        if SHAPES[el.name] then
            local subs = shapePolys(el, m)
            if #subs > 0 then paint(el, st, m, opacity, subs, el.name == "line") end
        elseif GROUPS[el.name] and (el.name ~= "symbol" or depth < 0) then
            for _, child in ipairs(el.children) do walk(child, st, m, opacity, depth + 1) end
        elseif el.name == "use" then
            local href = (el.attr["xlink:href"] or el.attr.href or ""):match("^#(.+)$")
            local target = href and ids[href]
            if target then
                local um = mul(m, {1, 0, 0, 1, len(el.attr.x, 0), len(el.attr.y, 0)})
                if target.name == "symbol" or target.name == "svg" then
                    for _, child in ipairs(target.children) do walk(child, st, um, opacity, depth + 1) end
                else
                    walk(target, st, um, opacity, depth + 1)
                end
            end
        end
    end

    walk(root, {}, rootM, 1, 0)
end

--Returns ImageData (straight alpha, cropped to what was drawn) or nil, message
function svg.render(text, maxSide)
    maxSide = maxSide or 512
    local doc, err = parseXML(text)
    if not doc then return nil, err end
    local root
    for _, el in ipairs(doc.children) do if el.name == "svg" then root = el break end end
    if not root then return nil, "Not an SVG file" end

    local ids, css, texts = {}, {}, 0
    local function index(el)
        if el.attr.id then ids[el.attr.id] = el end
        if el.name == "style" and el.text then css[#css + 1] = el.text end
        if el.name == "text" then texts = texts + 1 end
        for _, c in ipairs(el.children) do index(c) end
    end
    index(root)
    local rules = parseCSS(table.concat(css, "\n"))

    local vx, vy, vw, vh = 0, 0, nil, nil
    if root.attr.viewBox then
        local n = numbers(root.attr.viewBox)
        if #n == 4 and n[3] > 0 and n[4] > 0 then vx, vy, vw, vh = n[1], n[2], n[3], n[4] end
    end
    vw = vw or len(root.attr.width, 300)
    vh = vh or len(root.attr.height, 150)
    if not (vw > 0 and vh > 0) then return nil, "The SVG has no size" end

    local s = maxSide / max(vw, vh)
    local W, H = max(1, ceil(vw * s)), max(1, ceil(vh * s))
    local cv = newCanvas(W, H)
    render(root, rules, ids, cv, {s, 0, 0, s, -vx * s, -vy * s})

    --Crop to the drawing
    local px = cv.px
    local minx, maxx, miny, maxy = W, -1, H, -1
    for y = 0, H - 1 do
        for x = 0, W - 1 do
            if px[(y * W + x) * 4 + 3] > 0.02 then
                if x < minx then minx = x end
                if x > maxx then maxx = x end
                if y < miny then miny = y end
                if y > maxy then maxy = y end
            end
        end
    end
    if maxx < 0 then
        return nil, texts > 0 and "This SVG is made of text, which cannot be drawn: pick one with outlined shapes" or "Nothing to draw in this SVG"
    end

    local cw, ch = maxx - minx + 1, maxy - miny + 1
    local data = love.image.newImageData(cw, ch)
    local out = ffi.cast("uint8_t*", data:getFFIPointer())
    for y = 0, ch - 1 do
        for x = 0, cw - 1 do
            local k = ((y + miny) * W + x + minx) * 4
            local o = (y * cw + x) * 4
            local a = px[k + 3]
            if a > 0 then
                out[o] = min(255, floor(px[k] / a * 255 + 0.5))
                out[o + 1] = min(255, floor(px[k + 1] / a * 255 + 0.5))
                out[o + 2] = min(255, floor(px[k + 2] / a * 255 + 0.5))
                out[o + 3] = min(255, floor(a * 255 + 0.5))
            end
        end
    end
    return data
end

return svg
