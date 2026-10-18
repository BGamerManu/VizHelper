local wires = {}

local fetch = require "lib.fetch"
local xml2lua = require "lib.xml2lua"
local tree = require "lib.xmlhandler.tree"

--Name shown in the Ticker Control dropdown, address of the feed
wires.feeds = {
    {"BBC News UK", "https://feeds.bbci.co.uk/news/uk/rss.xml"},
    {"BBC World", "https://feeds.bbci.co.uk/news/world/rss.xml"},
    {"BBC News Top Stories", "https://feeds.bbci.co.uk/news/rss.xml"},
    {"Sky News", "https://feeds.skynews.com/feeds/rss/home.xml"},
    {"The Guardian World", "https://www.theguardian.com/world/rss"},
    {"Al Jazeera", "https://www.aljazeera.com/xml/rss/all.xml"},
    {"DW (Deutsche Welle)", "https://rss.dw.com/rdf/rss-en-all"},
    {"France 24", "https://www.france24.com/en/rss"},
    {"NPR", "https://feeds.npr.org/1001/rss.xml"},
    {"The New York Times", "https://rss.nytimes.com/services/xml/rss/nyt/HomePage.xml"},
    {"ANSA (Italiano)", "https://www.ansa.it/sito/ansait_rss.xml"},
    {"la Repubblica (Italiano)", "https://www.repubblica.it/rss/homepage/rss2.0.xml"},
}

--The Combo_Str string of wires.feeds
wires.feedNames = ""
for _, feed in ipairs(wires.feeds) do wires.feedNames = wires.feedNames..feed[1].."\0" end

wires.wireData = {}
wires.status = "Loading..."
--Called when new headlines arrived
wires.onUpdate = nil

local function plain(text)
    text = tostring(text):gsub("<[^>]*>", ""):gsub("&#(%d+);", function(n) n = tonumber(n) return n < 128 and string.char(n) or "'" end)
    text = text:gsub("&quot;", '"'):gsub("&apos;", "'"):gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&amp;", "&")
    return (text:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", ""))
end

--RSS 2.0 (rss.channel.item) and RSS 1.0 (rdf:RDF.item)
local function titlesOf(xml)
    local handler = tree:new()
    if not pcall(xml2lua.parser(handler).parse, xml2lua.parser(handler), xml) then return nil end
    local root = handler.root
    local items = root.rss and root.rss.channel and root.rss.channel.item or root["rdf:RDF"] and root["rdf:RDF"].item
    if items == nil then return nil end
    if items.title ~= nil then items = {items} end --a feed with one item is not a list

    local titles = {}
    for _, item in ipairs(items) do
        if type(item.title) == "string" and item.title ~= "" then titles[#titles + 1] = plain(item.title) end
    end
    return titles
end

--Loads feed number i (1 based)
function wires.fetch(i)
    local feed = wires.feeds[i]
    wires.status = "Loading "..feed[1].."..."
    wires.wireData = {}
    local requested = wires.feeds[i]
    wires.requested = requested

    fetch.get(feed[2], nil, function(body, err)
        if wires.requested ~= requested then return end --another feed was picked meanwhile
        local titles = body and titlesOf(body)
        if titles == nil then
            wires.status = "Could not read "..feed[1]..": "..tostring(err or "not an RSS feed")
            return
        end
        wires.wireData = titles
        wires.status = feed[1]..": "..#titles.." headlines"
        if wires.onUpdate then wires.onUpdate() end
    end)
end

return wires
