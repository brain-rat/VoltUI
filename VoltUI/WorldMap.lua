-- VoltUI · World map
-- Level labels over every zone on the continent maps, your and the cursor's coordinates, and
-- the flat VoltUI look for the map window. Another add-on can add layers of pins of its own
-- (W:AddLayer) and zone levels (ns.Extra.zoneLevels).
--
-- The window stays the game's own. Nothing here writes a field the game reads, replaces
-- a script or calls one of its Lua methods that stores anything. Its art is only faded
-- with SetAlpha, because the game keeps looking those textures up. See the rules in
-- Style.lua's Kill and the notes on taint in the read-me.

local _, ns = ...
local FUI, S = ns.FUI, ns.Style

local W = { key = "worldmap", name = "World map", labels = {}, spots = {}, used = 0 }
ns.WorldMap = W

local max, min, abs, floor = math.max, math.min, math.abs, math.floor

-- Pins of other add-ons': { key, name, slash, Setup(canvas), Draw() -> true when it
-- drew something from data that wants its credit shown, Rescale(), Toggle(), Status(),
-- credit() }. Each is set up with the map's own, drawn with it and rescaled with it.
W.layers = {}

-- Where the level labels sit among the map's layers: over explored areas and the zone
-- highlight. An add-on with pins of its own can swap this for one that keeps them under.
function W.LiftLabels(f, canvas, children)
  local lvl = canvas:GetFrameLevel() + 40
  if f:GetFrameLevel() == lvl then return end
  f:SetFrameLevel(lvl)
  for _, c in ipairs(children or {}) do c:SetFrameLevel(lvl + 1) end
end

function W:AddLayer(layer)
  for _, l in ipairs(self.layers) do
    if l.key == layer.key then return end
  end
  self.layers[#self.layers + 1] = layer
  if self.canvas and layer.Setup then layer:Setup(self.canvas) end
end

-- In the title bar, where the full credit would crowd TomTom's coordinates and the levels:
-- what the data's add-on gives as a short form. The full one, with the address, is in the
-- settings window and under /volt worldmap.
local function ShortCredit() return ns.Extra.shortCredit end

local function ExtraLevels()
  local z = ns.Extra.zoneLevels
  return type(z) == "table" and type(z.levels) == "table" and z or nil
end

-- Classic's published level ranges, for when the game doesn't give a zone's levels.
local ZONE_LEVELS = {
  -- Eastern Kingdoms
  [1416] = { 30, 40 }, -- Alterac Mountains
  [1417] = { 30, 40 }, -- Arathi Highlands
  [1418] = { 35, 45 }, -- Badlands
  [1419] = { 45, 55 }, -- Blasted Lands
  [1420] = { 1, 10 },  -- Tirisfal Glades
  [1421] = { 10, 20 }, -- Silverpine Forest
  [1422] = { 51, 58 }, -- Western Plaguelands
  [1423] = { 53, 60 }, -- Eastern Plaguelands
  [1424] = { 20, 30 }, -- Hillsbrad Foothills
  [1425] = { 40, 50 }, -- The Hinterlands
  [1426] = { 1, 10 },  -- Dun Morogh
  [1427] = { 43, 50 }, -- Searing Gorge
  [1428] = { 50, 58 }, -- Burning Steppes
  [1429] = { 1, 10 },  -- Elwynn Forest
  [1430] = { 55, 60 }, -- Deadwind Pass
  [1431] = { 18, 30 }, -- Duskwood
  [1432] = { 10, 20 }, -- Loch Modan
  [1433] = { 15, 25 }, -- Redridge Mountains
  [1434] = { 30, 45 }, -- Stranglethorn Vale
  [1435] = { 35, 45 }, -- Swamp of Sorrows
  [1436] = { 10, 20 }, -- Westfall
  [1437] = { 20, 30 }, -- Wetlands
  -- Kalimdor
  [1411] = { 1, 10 },  -- Durotar
  [1412] = { 1, 10 },  -- Mulgore
  [1413] = { 10, 25 }, -- The Barrens
  [1438] = { 1, 10 },  -- Teldrassil
  [1439] = { 10, 20 }, -- Darkshore
  [1440] = { 18, 30 }, -- Ashenvale
  [1441] = { 25, 35 }, -- Thousand Needles
  [1442] = { 15, 27 }, -- Stonetalon Mountains
  [1443] = { 30, 40 }, -- Desolace
  [1444] = { 40, 50 }, -- Feralas
  [1445] = { 35, 45 }, -- Dustwallow Marsh
  [1446] = { 40, 50 }, -- Tanaris
  [1447] = { 45, 55 }, -- Azshara
  [1448] = { 48, 55 }, -- Felwood
  [1449] = { 48, 55 }, -- Un'Goro Crater
  [1450] = { 55, 60 }, -- Moonglade
  [1451] = { 55, 60 }, -- Silithus
  [1452] = { 53, 60 }, -- Winterspring
}
W.ZONE_LEVELS = ZONE_LEVELS

-- Zones new in Forever, which Classic never had and ForeverDB has no range for yet. Read off
-- the levels of the ordinary hostile creatures QuestieDB 1.1.0 has in each (2026-11-14): the
-- same reading lands within about 3 levels of ForeverDB's range for the zones it does have.
local FOREVER_LEVELS = {
  [2482] = { 55, 60 }, -- Mount Hyjal
  [2548] = { 35, 45 }, -- Riverglades
  [2652] = { 37, 45 }, -- Shen'dralas
  [2521] = { 1, 12 },  -- Zephras Isle (Blizzard's own range; ForeverDB's file has it too)
}
W.FOREVER_LEVELS = FOREVER_LEVELS

-- No real zone spans this many levels, so a range wider than this is scaling data.
local WIDEST_RANGE = 25

local function MapTypes()
  local t = Enum and Enum.UIMapType or {}
  return t.Continent or 2, t.Zone or 3
end

-- A zone's levels: the game's first, as its own hover label shows, then another add-on's
-- (ns.Extra.zoneLevels, "extra"), then Classic's, then VoltUI's own for the zones new in Forever.
function W.Levels(id)
  if C_Map.GetMapLevels then
    local ok, lo, hi = pcall(C_Map.GetMapLevels, id)
    lo, hi = ok and S.Safe(lo), ok and S.Safe(hi)
    if type(lo) == "number" and type(hi) == "number" and lo > 0 and hi >= lo and hi - lo <= WIDEST_RANGE then
      return lo, hi, "game"
    end
  end
  local z = ExtraLevels()
  local db = z and z.levels[id]
  if db then return db[1], db[2], "extra" end
  local f = ZONE_LEVELS[id]
  if f then return f[1], f[2], "Classic" end
  f = FOREVER_LEVELS[id]
  if f then return f[1], f[2], "Forever creatures" end
end

-- The same colours as the game's hover label: yellow in range, red above you, green
-- and then grey below you.
function W.LevelColor(lo, hi)
  local level = S.Safe(UnitLevel("player")) or 1
  local c
  if level >= lo and level <= hi then
    c = QuestDifficultyColors and QuestDifficultyColors.difficult
  elseif GetQuestDifficultyColor then
    c = GetQuestDifficultyColor(level < lo and lo or hi - 2)
  end
  if c then return c.r, c.g, c.b end
  return 1, 0.82, 0
end

local function RangeText(lo, hi)
  return lo == hi and tostring(lo) or (lo .. "-" .. hi)
end

------------------------------------------------------------------------
-- Where a label goes: the roomiest spot inside the zone
------------------------------------------------------------------------

local GRID_X, GRID_Y = 84, 56
local STEP_X, STEP_Y = 1, 2 -- labels are wider than they're tall, so height counts for more

-- The game can answer with a map inside the zone, which counts as the zone.
local function ChildOf(id, parent, memo)
  if memo[id] ~= nil then return memo[id] end
  local cur = id
  for _ = 1, 6 do
    local info = C_Map.GetMapInfo(cur)
    if not info then break end
    if info.parentMapID == parent then
      memo[id] = cur
      return cur
    end
    cur = info.parentMapID
    if not cur or cur == 0 then break end
  end
  memo[id] = false
  return false
end

-- A zone's box on the continent often sticks out over its neighbours and the sea, so
-- its middle can land in the wrong place. The game's own hover test says which zone is
-- under any point, so read that across the map once and take the point in each zone
-- that's furthest from its edges. Only the first look at a continent pays for this.
function W:FindSpots(mapID)
  local found = self.spots[mapID]
  if found then return found end
  found = {}
  self.spots[mapID] = found

  local X, Y = GRID_X, GRID_Y
  local grid, memo, sums = {}, {}, {}
  for j = 1, Y do
    for i = 1, X do
      local info = C_Map.GetMapInfoAtPosition(mapID, (i - 0.5) / X, (j - 0.5) / Y)
      local id = info and info.mapID ~= mapID and ChildOf(info.mapID, mapID, memo) or false
      grid[(j - 1) * X + i] = id
      if id then
        local s = sums[id]
        if not s then
          s = { x = 0, y = 0, n = 0 }
          sums[id] = s
        end
        s.x, s.y, s.n = s.x + i, s.y + j, s.n + 1
      end
    end
  end

  -- How far each cell is from the edge of its zone, swept both ways.
  local far = {}
  for j = 1, Y do
    for i = 1, X do
      local c = (j - 1) * X + i
      local id = grid[c]
      if not id then
        far[c] = 0
      else
        local a = (i > 1 and grid[c - 1] == id) and far[c - 1] + STEP_X or STEP_X
        local b = (j > 1 and grid[c - X] == id) and far[c - X] + STEP_Y or STEP_Y
        far[c] = min(a, b)
      end
    end
  end
  local best = {}
  for j = Y, 1, -1 do
    for i = X, 1, -1 do
      local c = (j - 1) * X + i
      local id = grid[c]
      if id then
        local a = (i < X and grid[c + 1] == id) and far[c + 1] + STEP_X or STEP_X
        local b = (j < Y and grid[c + X] == id) and far[c + X] + STEP_Y or STEP_Y
        local d = min(far[c], a, b)
        far[c] = d
        -- Plenty of cells tie, so the one nearest the zone's middle wins.
        local s = sums[id]
        local off = abs(i - s.x / s.n) + abs(j - s.y / s.n)
        local b2 = best[id]
        if not b2 or d > b2.d or (d == b2.d and off < b2.off) then
          best[id] = { d = d, off = off, i = i, j = j }
        end
      end
    end
  end
  for id, b in pairs(best) do
    found[id] = { x = (b.i - 0.5) / X, y = (b.j - 0.5) / Y }
  end
  return found
end

function W:Spot(mapID, zoneID)
  local s = self:FindSpots(mapID)[zoneID]
  if s then return s.x, s.y end
  local left, right, top, bottom = C_Map.GetMapRectOnMap(zoneID, mapID)
  if left and right > left and bottom > top then
    return (left + right) / 2, (top + bottom) / 2
  end
end

------------------------------------------------------------------------
-- The labels
------------------------------------------------------------------------

function W:Label(i)
  local l = self.labels[i]
  if l then return l end
  -- A plain frame with no mouse, so clicks and the hover highlight carry on to the map.
  l = CreateFrame("Frame", nil, self.overlay)
  l.plate = S.Tex(l, "BACKGROUND", -8)
  l.plate:SetAllPoints()
  -- (1.86.0) a square plate with a border, the levels in Space Mono
  l.plate:SetColorTexture(S.UI.bg[1], S.UI.bg[2], S.UI.bg[3], 0.82)
  l.edges = S.Edges(l, "BACKGROUND", -7)
  S.ColorEdges(l.edges, S.UI.edge[1], S.UI.edge[2], S.UI.edge[3], 1)
  l.level = S.UIText(l, nil, "CENTER", "OVERLAY", 15, "OUTLINE")
  self.labels[i] = l
  return l
end

-- Just the levels: the game's map already names the zone you hover (since 1.65.0).
function W:FillLabel(l, lo, hi)
  local db = ns.db
  local size = db.mapLabelSize
  S.FixFont(l.level, size, "OUTLINE", "semibold")
  l.level:SetText(RangeText(lo, hi))
  l.level:SetTextColor(W.LevelColor(lo, hi))
  l.plate:SetShown(db.mapPlates)
  -- the zone you're in is outlined in gold
  local e = l.here and S.UI.accent or S.UI.edge
  S.ColorEdges(l.edges, e[1], e[2], e[3], 1)
  for _, t in ipairs(l.edges) do t:SetShown(db.mapPlates and true or false) end
  l.level:ClearAllPoints()
  l.level:SetPoint("CENTER", l, "CENTER", 0, 0)
  l.kW, l.kH = (l.level:GetStringWidth() or 0) + 10, size + 6
  l:SetSize(l.kW, l.kH)
end

function W:Draw()
  if not self.overlay then return end
  W.LiftLabels(self.overlay, self.canvas, self.labels)
  local used, fromDB = 0, false
  local mapID = WorldMapFrame:IsShown() and WorldMapFrame:GetMapID() or nil
  local info = mapID and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
  local continent = MapTypes()
  if info and ns.db.mapLevels and info.mapType == continent then
    local _, zoneType = MapTypes()
    local here = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if issecretvalue and issecretvalue(here) then here = nil end
    for _, child in ipairs(C_Map.GetMapChildrenInfo(mapID, zoneType) or {}) do
      local lo, hi, from = W.Levels(child.mapID)
      if lo then
        local x, y = self:Spot(mapID, child.mapID)
        if x then
          used = used + 1
          local l = self:Label(used)
          l.kX, l.kY, l.kZone = x, y, child.mapID
          l.here = here ~= nil and here == child.mapID
          self:FillLabel(l, lo, hi)
          l:Show()
          fromDB = fromDB or from == "extra"
        end
      end
    end
  end
  for i = used + 1, #self.labels do self.labels[i]:Hide() end
  self.used = used
  self:Place()
  fromDB = self:DrawTag(info) or fromDB
  local full = fromDB and ExtraLevels() and ExtraLevels().credit or nil
  -- other add-ons' layers
  for _, l in ipairs(self.layers) do
    local ok, drew = pcall(l.Draw, l)
    if ok and drew then
      fromDB = true
      full = full or (l.credit and l:credit())
    end
  end
  full = full or ShortCredit()
  if self.credit then self.credit:SetText(fromDB and (self.skinned and ShortCredit() or full) or "") end
  self:FitTomTom()
end

-- TomTom writes the player's and the cursor's coordinates at fixed spots on the map's top
-- edge, made for the game's title in the middle. With VoltUI's title on the left they'd land
-- on it and on the levels, so they go in a row straight after the title instead, the
-- cursor's in a column of its own so it doesn't shuffle as the player's numbers change.
-- TomTom puts them back whenever its settings change, so they're fitted again after it.
function W:FitTomTom()
  local text = self.titleText
  if not text then return end
  local tom = _G.TomTom
  if type(tom) == "table" and type(tom.ShowHideWorldCoords) == "function" and not self.tomHooked then
    self.tomHooked = true
    hooksecurefunc(tom, "ShowHideWorldCoords", function() W:FitTomTom() end)
  end
  local frame = _G.TomTomWorldFrame
  local player, cursor = frame and frame.Player, frame and frame.Cursor
  if not (player and cursor) then return end
  local ok, err = pcall(function()
    player:ClearAllPoints()
    player:SetPoint("LEFT", text, "RIGHT", 18, 0)
    cursor:ClearAllPoints()
    if player:IsShown() then
      cursor:SetPoint("LEFT", player, "LEFT", 150, 0)
    else
      cursor:SetPoint("LEFT", text, "RIGHT", 18, 0)
    end
  end)
  if not ok and ns.Errors then ns.Errors:Add("World map: " .. tostring(err), nil, nil, "volt") end
end

-- Labels stay the same size on screen while the map zooms under them, and are pushed
-- apart when they'd overlap. Zooming in spreads the zones out, so they settle back.
function W:Place()
  local used = self.used
  if used == 0 or not self.overlay then return end
  local f = self.overlay
  local wd, ht = f:GetWidth(), f:GetHeight()
  local cs = WorldMapFrame.GetCanvasScale and WorldMapFrame:GetCanvasScale() or 1
  if not cs or cs <= 0 then cs = 1 end
  local box = WorldMapFrame.ScrollContainer
  local view = box and box:GetWidth() or 0
  if view <= 0 then view = wd * cs end
  local fit = max(0.8, min(1.2, view / 1000)) -- smaller on the small map, where the zones are
  local labels = self.labels
  for i = 1, used do
    local l = labels[i]
    l.kSX, l.kSY = l.kX * wd * cs, l.kY * ht * cs
  end
  for _ = 1, 3 do
    for i = 1, used - 1 do
      local a = labels[i]
      for j = i + 1, used do
        local b = labels[j]
        if abs(a.kSX - b.kSX) < (a.kW + b.kW) * fit / 2 then
          local gap = (a.kH + b.kH) * fit / 2 - abs(a.kSY - b.kSY)
          if gap > 0 then
            local push = gap / 2 + 1
            if a.kSY <= b.kSY then push = -push end
            a.kSY, b.kSY = a.kSY + push, b.kSY - push
          end
        end
      end
    end
  end
  local scale = fit / cs
  for i = 1, used do
    local l = labels[i]
    l:SetScale(scale)
    l:ClearAllPoints()
    l:SetPoint("CENTER", f, "TOPLEFT", l.kSX / fit, -l.kSY / fit)
  end
end

-- On a zone's own map, its levels sit in the title bar. Says if they're another add-on's.
function W:DrawTag(info)
  local tag = self.tag
  if not tag then return false end
  local lo, hi, from
  if info and ns.db.mapLevels then lo, hi, from = W.Levels(info.mapID) end
  if lo then
    tag:SetText("Levels " .. RangeText(lo, hi))
    tag:SetTextColor(W.LevelColor(lo, hi))
  else
    tag:SetText("")
  end
  return from == "extra"
end

function W:SetupLabels()
  local canvas = WorldMapFrame:GetCanvas()
  local f = CreateFrame("Frame", nil, canvas)
  f:SetAllPoints(canvas)
  -- over explored areas and the zone highlight, under other add-ons' pins
  W.LiftLabels(f, canvas)
  self.overlay, self.canvas = f, canvas
  for _, l in ipairs(self.layers) do
    if l.Setup then pcall(l.Setup, l, canvas) end
  end
  self:SetupCoords()

  local border = WorldMapFrame.BorderFrame
  if border then
    local title = border.TitleContainer or border
    self.tag = S.Text(title, nil, "RIGHT", "OVERLAY", 13, "OUTLINE")
    self.tag:SetPoint("RIGHT", title, "RIGHT", -28, 0)
    -- The data's credit, above the map and never over it. The game's own title sits in
    -- the middle of the bar when the skin's off, so then it goes on the row below.
    self.credit = S.Text(title, nil, "RIGHT", "OVERLAY", 10)
    if ns.db.mapSkin then
      self.credit:SetPoint("RIGHT", self.tag, "LEFT", -10, 0)
    else
      self.credit:SetPoint("TOPRIGHT", border, "TOPRIGHT", -8, -30)
    end
    self.credit:SetTextColor(S.UI.off[1], S.UI.off[2], S.UI.off[3])
  end

  local function draw() W:Draw() end
  hooksecurefunc(WorldMapFrame, "OnMapChanged", draw)
  WorldMapFrame:HookScript("OnShow", draw)
  canvas:HookScript("OnSizeChanged", draw)
  hooksecurefunc(WorldMapFrame, "OnCanvasScaleChanged", function()
    W:Place()
    for _, l in ipairs(W.layers) do
      if l.Rescale then pcall(l.Rescale, l) end
    end
  end)

  local ev = CreateFrame("Frame")
  ev:RegisterEvent("PLAYER_LEVEL_UP")
  -- UnitLevel can still give the old level during the event itself.
  ev:SetScript("OnEvent", function() C_Timer.After(0.2, draw) end)
end

------------------------------------------------------------------------
-- Where you are and where the cursor is, at the map's bottom-left (VoltUIDB.mapCoords). Since
-- 1.104.0 the map's own; it used to sit with the pins' buttons, which have left VoltUI. An add-on
-- with buttons of its own there can move it up (W:SetupCoords makes it, as VoltUIMapCoords).
------------------------------------------------------------------------

local function Secret(v) return issecretvalue and issecretvalue(v) end
-- "52.1, 68.4" for a spot 0-1 across the map.
local function Coord(x, y) return ("%.1f, %.1f"):format(x * 100, y * 100) end

function W:UpdateCoords()
  local c = self.coords
  if not c or ns.db.mapCoords == false then return end
  local mapID = WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
  local you
  if mapID and C_Map and C_Map.GetPlayerMapPosition then
    local ok, pos = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
    local x, y
    if ok and pos then
      if pos.GetXY then x, y = pos:GetXY() else x, y = pos.x, pos.y end
    end
    if x and y and not Secret(x) and not Secret(y) and (x > 0 or y > 0) then you = Coord(x, y) end
  end
  local sc = WorldMapFrame.ScrollContainer
  local cursor
  if sc and sc.GetNormalizedCursorPosition and (not sc.IsMouseOver or sc:IsMouseOver()) then
    local ok, x, y = pcall(sc.GetNormalizedCursorPosition, sc)
    if ok and type(x) == "number" and type(y) == "number" and x >= 0 and x <= 1 and y >= 0 and y <= 1 then cursor = Coord(x, y) end
  end
  local text
  if you and cursor then
    text = you .. "   |cff8c8c8ccursor|r " .. cursor
  elseif cursor then
    text = "|cff8c8c8ccursor|r " .. cursor
  else
    text = you or ""
  end
  c.text:SetText(text)
  c.plate:SetShown(text ~= "")
  if text ~= "" then c.plate:SetWidth(c.text:GetStringWidth() + 12) end
end

function W:PaintCoords()
  local c = self.coords
  if not c then return end
  local on = ns.db.mapCoords ~= false
  c:SetShown(on)
  if on then self:UpdateCoords() end
end

function W:SetupCoords()
  if self.coords or not (WorldMapFrame and WorldMapFrame.ScrollContainer) then return end
  local sc = WorldMapFrame.ScrollContainer
  local c = CreateFrame("Frame", "VoltUIMapCoords", sc)
  c:SetSize(10, 18)
  c:SetPoint("BOTTOMLEFT", sc, "BOTTOMLEFT", 8, 8)
  c:SetFrameLevel((sc:GetFrameLevel() or 1) + 3000) -- over the game's own pins, which start at 2000
  c.plate = S.Tex(c, "BACKGROUND")
  c.plate:SetColorTexture(S.UI.panel[1], S.UI.panel[2], S.UI.panel[3], 0.92)
  c.plate:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 0, 0)
  c.plate:SetHeight(18)
  c.text = S.UIText(c, nil, "LEFT", "OVERLAY", 11, nil, "mono")
  c.text:SetPoint("LEFT", c.plate, "LEFT", 6, 0)
  c.text:SetTextColor(S.UI.text[1], S.UI.text[2], S.UI.text[3])
  c:SetScript("OnUpdate", function(self, elapsed)
    self.wait = (self.wait or 0) + (elapsed or 0)
    if self.wait < 0.1 then return end
    self.wait = 0
    W:UpdateCoords()
  end)
  self.coords = c
  self:PaintCoords()
end

------------------------------------------------------------------------
-- The window's look
------------------------------------------------------------------------

local Fade, FadeTextures, FlatHighlight, Glyph, FlatButton = S.Fade, S.FadeTextures, S.FlatHighlight, S.Glyph, S.FlatButton

local navDone = {}
local function SkinNavButton(b, first)
  if navDone[b] then return end
  navDone[b] = true
  FadeTextures(b)
  S.GoldHighlight(b)
  if b.text then
    S.FixFont(b.text, 11, nil, nil, "mono")
    b.text:SetTextColor(0.85, 0.85, 0.85)
  end
  if not first then
    local arrow = S.Text(b, nil, "LEFT", "OVERLAY", 12)
    arrow:SetPoint("LEFT", b, "LEFT", 7, 0)
    arrow:SetText(">")
    arrow:SetTextColor(S.UI.edge[1], S.UI.edge[2], S.UI.edge[3])
  end
  local menu = b.MenuArrowButton
  if menu then
    -- The game shows these two itself when the mouse is over the arrow.
    if menu.NormalTexture then menu.NormalTexture:SetColorTexture(1, 1, 1, 0.08) end
    if menu.PushedTexture then menu.PushedTexture:SetColorTexture(1, 1, 1, 0.08) end
    Fade(menu.GetHighlightTexture and menu:GetHighlightTexture())
  end
end

function W:SkinNav()
  local bar = WorldMapFrame.NavBar
  if not bar then return end
  FadeTextures(bar)
  Fade(bar.overlay)
  local home = bar.homeButton or bar.home
  if home then SkinNavButton(home, true) end
  local over = bar.overflowButton or bar.overflow
  if over then
    Fade(over:GetNormalTexture(), over:GetPushedTexture())
    S.GoldHighlight(over)
    Glyph(over, "<<")
  end
  local function skinAll()
    for i, b in ipairs(bar.navList or {}) do SkinNavButton(b, i == 1) end
  end
  skinAll()
  if NavBar_AddButton then
    -- The game makes the buttons as they're first needed.
    hooksecurefunc("NavBar_AddButton", function(which) if which == bar then skinAll() end end)
  end
  -- The game leaves room for a portrait on the small map, which is gone now.
  local spacer = WorldMapFrame.TitleCanvasSpacerFrame
  local function placeNav()
    if spacer then bar:SetPoint("TOPLEFT", spacer, "TOPLEFT", 8, -25) end
  end
  placeNav()
  hooksecurefunc(WorldMapFrame, "Minimize", placeNav)
  hooksecurefunc(WorldMapFrame, "Maximize", placeNav)
end

-- The quest list loses its background and frame. The details page keeps its parchment:
-- the game writes that page's text in dark ink, which needs a pale page behind it.
function W:SkinQuestPanel()
  local q = QuestMapFrame
  if not q then return end
  Fade(q.VerticalSeparator)
  local quests = q.QuestsFrame
  local list = quests and quests.ScrollFrame
  if list then Fade(list.Background, list.Edge, list.BorderFrame) end
  local details = quests and quests.DetailsFrame or q.DetailsFrame
  if details then Fade(details.BorderFrame) end
end

function W:PaintPanel()
  S.ThemePanel(WorldMapFrame, max(ns.db.alpha, 0.92)) -- the map's frame stays nearly solid
end

function W:SetupSkin()
  local map, border = WorldMapFrame, WorldMapFrame.BorderFrame
  if not border then return end
  -- (1.86.0) in VoltUI's own windows' look: square greys, the map's name on a gold block, gold
  -- ticks in the map's top corners
  local UI, A = S.UI, S.UI.accent
  self:PaintPanel()
  Fade(border.NineSlice, border.Bg, border.TopTileStreaks, border.InsetBorderTop, border.PortraitContainer, map.OverscrollBG)
  if border.Tutorial then
    Fade(border.Tutorial)
    border.Tutorial:EnableMouse(false)
  end

  -- A line around the window and around the map, over the map's own edges.
  S.ColorEdges(S.Edges(border, "OVERLAY", 7), UI.edge[1], UI.edge[2], UI.edge[3], 1)
  if map.ScrollContainer then
    S.ColorEdges(S.Edges(border, "OVERLAY", 7, map.ScrollContainer), UI.edge[1], UI.edge[2], UI.edge[3], 1)
    self.ticks = {}
    for _, side in ipairs({ "LEFT", "RIGHT" }) do
      for _, size in ipairs({ { 14, 3 }, { 3, 14 } }) do
        local t = S.Tex(border, "OVERLAY", 7)
        t:SetPoint("TOP" .. side, map.ScrollContainer, "TOP" .. side, 0, 0)
        t:SetSize(size[1], size[2])
        t:SetColorTexture(A[1], A[2], A[3], 1)
        self.ticks[#self.ticks + 1] = t
      end
    end
  end

  local title = border.TitleContainer
  local text = title and title.TitleText
  if title and text then
    title:ClearAllPoints()
    title:SetPoint("TOPLEFT", border, "TOPLEFT", 8, -1)
    title:SetPoint("TOPRIGHT", border, "TOPRIGHT", -24, -1)
    title:SetHeight(S.HEADER_H - 2)
    text:ClearAllPoints()
    text:SetPoint("LEFT", title, "LEFT", 4, 0) -- only as wide as its words, so things can sit after it
    text:SetJustifyH("LEFT")
    S.FixFont(text, 13, nil, "semibold")
    text:SetTextColor(UI.primaryText[1], UI.primaryText[2], UI.primaryText[3])
    if text.SetDrawLayer then text:SetDrawLayer("OVERLAY", 2) end
    -- the gold block behind it follows the name's width
    local block = S.Tex(title, "ARTWORK")
    block:SetPoint("TOPLEFT", border, "TOPLEFT", 1, -1)
    block:SetPoint("BOTTOMRIGHT", text, "RIGHT", 11, -(S.HEADER_H / 2 - 1))
    S.BlockLook(title, block)
    self.block = block
    self.titleText = text
  end
  self.skinned = true

  local close, resize = border.CloseButton, border.MaximizeMinimizeFrame
  if close then
    close:SetSize(20, 20)
    close:ClearAllPoints()
    close:SetPoint("TOPRIGHT", border, "TOPRIGHT", -2, -2)
    FlatButton(close, "x")
    S.GoldHighlight(close)
  end
  if resize then
    resize:SetSize(20, 20)
    resize:ClearAllPoints()
    resize:SetPoint("RIGHT", close or border, close and "LEFT" or "TOPRIGHT", -2, 0)
    FlatButton(resize.MaximizeButton, "+")
    FlatButton(resize.MinimizeButton, "-")
    if resize.MaximizeButton then S.GoldHighlight(resize.MaximizeButton) end
    if resize.MinimizeButton then S.GoldHighlight(resize.MinimizeButton) end
  end

  self:SkinNav()
  self:SkinQuestPanel()
end

------------------------------------------------------------------------
-- Moving the window
------------------------------------------------------------------------

-- The small and full-size maps each remember their own spot.
local function SpotKeys()
  if WorldMapFrame.IsMaximized and WorldMapFrame:IsMaximized() then return "mapBigLeft", "mapBigTop", "mapBigPoint" end
  return "mapLeft", "mapTop", "mapPoint"
end

local function Locked()
  return InCombatLockdown() and WorldMapFrame:IsProtected()
end

function W:PlaceWindow()
  if self.moving or self.placing or not ns.db.mapDrag then return end
  local keyL, keyT, keyP = SpotKeys()
  if not ns.db[keyL] or not ns.db[keyT] then return end
  if Locked() then
    self.placeLater = true
    return
  end
  self.placing = true
  pcall(S.PlaceSpot, WorldMapFrame, ns.db, keyL, keyT, keyP)
  self.placing = false
end

function W:FinishMoving()
  if not self.moving then return end
  self.moving = false
  local map = WorldMapFrame
  map:StopMovingOrSizing()
  map:SetUserPlaced(false) -- VoltUI keeps the spot, not the game's layout file
  local keyL, keyT, keyP = SpotKeys()
  if S.SaveSpot(map, ns.db, keyL, keyT, keyP) then self:PlaceWindow() end
end

-- Drag by the title bar, because dragging the map itself pans it. The game counts this
-- window as one of its side panels and re-anchors it whenever any panel opens or closes,
-- so every time it does, the saved spot goes straight back on. Hooking SetPoint catches
-- all of its routes, including the anchor it sets last when going full size.
function W:SetupDrag()
  local map, border = WorldMapFrame, WorldMapFrame.BorderFrame
  if not border then return end
  map:SetMovable(true)
  map:SetClampedToScreen(true) -- keeps the title bar reachable

  local grip = CreateFrame("Frame", nil, border)
  -- Clear of the close and resize buttons, and of the portrait and help button if unskinned.
  grip:SetPoint("TOPLEFT", border, "TOPLEFT", ns.db.mapSkin and 0 or 60, 0)
  grip:SetPoint("TOPRIGHT", border, "TOPRIGHT", -52, 0)
  grip:SetHeight(S.HEADER_H)
  grip:EnableMouse(true)
  grip:RegisterForDrag("LeftButton")
  grip:SetScript("OnDragStart", function()
    if Locked() then return end
    W.moving = true
    map:StartMoving()
  end)
  grip:SetScript("OnDragStop", function() W:FinishMoving() end)
  grip:SetScript("OnHide", function() W:FinishMoving() end) -- shut mid-drag
  grip:SetShown(ns.db.mapDrag)
  self.grip = grip

  -- its size first: a saved spot is counted in the window's own units
  local function place()
    W:ApplyScale()
    W:PlaceWindow()
  end
  hooksecurefunc(map, "SetPoint", place)
  map:HookScript("OnShow", place)

  local ev = CreateFrame("Frame")
  ev:RegisterEvent("PLAYER_REGEN_ENABLED")
  ev:SetScript("OnEvent", function()
    if W.placeLater then
      W.placeLater = nil
      place()
    end
  end)
  place()
end

------------------------------------------------------------------------
-- Resizing the window (1.90.0)
------------------------------------------------------------------------

-- The small map grows and shrinks as a whole, by its scale: the game lays the window out at
-- fixed sizes (702 by 534, the quest list beside it) and puts them back on every minimise,
-- so its width and height aren't VoltUI's to change. The game's own map code reads the cursor
-- at the window's scale (MapCanvasScrollControllerMixin:GetCursorPosition), so hovering and
-- clicking zones still land. The full-size map always fills the screen, at the game's size.
local SCALE_MIN, SCALE_MAX = 0.6, 2
W.SCALE_MIN, W.SCALE_MAX = SCALE_MIN, SCALE_MAX

local function Big()
  return WorldMapFrame.IsMaximized and WorldMapFrame:IsMaximized() and true or false
end

local function CleanScale(s)
  s = tonumber(s) or 1
  return floor(max(SCALE_MIN, min(SCALE_MAX, s)) * 100 + 0.5) / 100
end

function W:ApplyScale()
  if not self.ready then return end
  local map = WorldMapFrame
  local big = Big()
  if self.sizer then self.sizer:SetShown(not big) end
  local want = big and 1 or CleanScale(ns.db.mapScale)
  -- never touched until you've resized it, so another add-on's map size is left alone
  if want == 1 and not self.scaled then return end
  local have = map.GetScale and map:GetScale() or 1
  if abs(have - want) < 0.001 then return end
  if Locked() then
    self.placeLater = true
    return
  end
  self.scaled = true
  map:SetScale(want)
end

-- The small map's saved spot as a place on screen, for a window at scale s.
local function SpotOnScreen(db, s)
  local x, y, p = db.mapLeft, db.mapTop, db.mapPoint
  if type(x) ~= "number" or type(y) ~= "number" or type(p) ~= "string" then return nil end
  local wd, ht = UIParent:GetWidth(), UIParent:GetHeight()
  local ax = p:find("LEFT") and 0 or p:find("RIGHT") and wd or wd / 2
  local ay = p:find("BOTTOM") and 0 or p:find("TOP") and ht or ht / 2
  return ax + x * s, ay + y * s
end

-- A new size for the small map, its top-left corner staying where it is: at left, top on
-- screen if given (the corner drag knows them), else wherever its saved spot has it.
function W:SetMapScale(s, left, top)
  local db = ns.db
  s = CleanScale(s)
  local old = self.scaleNow or 1
  if not left then left, top = SpotOnScreen(db, old) end
  db.mapScale, self.scaleNow = s, s
  if left and db.mapDrag then
    local p, x, y = S.SpotFrom(WorldMapFrame, left / s, top / s, true, s)
    if p then db.mapPoint, db.mapLeft, db.mapTop = p, x, y end
  end
  if not self.ready then return end
  self:ApplyScale()
  if left and not db.mapDrag and not Big() and not Locked() then
    -- with dragging off there's no spot of VoltUI's: hold the corner until the game next places it
    self.placing = true
    pcall(function()
      WorldMapFrame:ClearAllPoints()
      WorldMapFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left / s, top / s)
    end)
    self.placing = false
  end
  self:PlaceWindow()
  self:Place()
end

local function CursorOnScreen()
  local ui = UIParent:GetEffectiveScale() or 1
  local x, y = GetCursorPosition()
  return x / ui, y / ui
end

function W:StartSizing()
  local map = WorldMapFrame
  if self.sizing or Locked() or Big() then return end
  local s0 = map.GetScale and map:GetScale() or 1
  -- the window has been sitting still, so its corner can be read
  local l, t = map:GetLeft(), map:GetTop()
  if not (l and t) then return end
  local left, top = l * s0, t * s0
  local cx, cy = CursorOnScreen()
  local dx, dy = cx - left, top - cy
  if dx < 20 or dy < 20 then return end
  self.sizing = { s0 = s0, left = left, top = top, dx = dx, dy = dy, w = map:GetWidth() or 0, h = map:GetHeight() or 0 }
end

-- The corner follows the mouse along the window's diagonal, and never past the screen.
function W:Sizing()
  local z = self.sizing
  if not z then return end
  if Locked() or Big() then return self:StopSizing() end
  local cx, cy = CursorOnScreen()
  local s = z.s0 * ((cx - z.left) * z.dx + (z.top - cy) * z.dy) / (z.dx * z.dx + z.dy * z.dy)
  if z.w > 0 and z.h > 0 then s = min(s, UIParent:GetWidth() / z.w, UIParent:GetHeight() / z.h) end
  s = CleanScale(s)
  if s ~= z.s then
    z.s = s
    self:SetMapScale(s, z.left, z.top)
  end
end

function W:StopSizing()
  if not self.sizing then return end
  self.sizing = nil
  if self.sizer and not (self.sizer.IsMouseOver and self.sizer:IsMouseOver()) then self.sizer:SetAlpha(0.55) end
end

function W:SetupResize()
  local map, border = WorldMapFrame, WorldMapFrame.BorderFrame
  if not border then return end
  self.scaleNow = CleanScale(ns.db.mapScale)
  local A = S.UI.accent
  local g = CreateFrame("Frame", nil, border)
  g:SetSize(18, 18)
  g:SetPoint("BOTTOMRIGHT", map, "BOTTOMRIGHT", -2, 2)
  g:SetFrameLevel((border:GetFrameLevel() or 1) + 20)
  g:EnableMouse(true)
  for _, size in ipairs({ { 14, 3 }, { 3, 14 } }) do
    local t = S.Tex(g, "OVERLAY", 7)
    t:SetPoint("BOTTOMRIGHT", g, "BOTTOMRIGHT", 0, 0)
    t:SetSize(size[1], size[2])
    t:SetColorTexture(A[1], A[2], A[3], 1)
  end
  g:SetAlpha(0.55)
  g:SetScript("OnEnter", function(self)
    self:SetAlpha(1)
    GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
    GameTooltip:SetText("Drag to resize the map", 1, 1, 1)
    GameTooltip:AddLine("Right-click: normal size", 0.8, 0.8, 0.8)
    GameTooltip:Show()
  end)
  g:SetScript("OnLeave", function(self)
    if not W.sizing then self:SetAlpha(0.55) end
    GameTooltip:Hide()
  end)
  g:SetScript("OnMouseDown", function(_, button)
    if button == "RightButton" then
      if Locked() or Big() then return end
      local s0 = map.GetScale and map:GetScale() or 1
      local l, t = map:GetLeft(), map:GetTop()
      W:SetMapScale(1, l and l * s0, t and t * s0)
    else
      W:StartSizing()
    end
  end)
  g:SetScript("OnMouseUp", function() W:StopSizing() end)
  g:SetScript("OnHide", function() W:StopSizing() end)
  g:SetScript("OnUpdate", function() if W.sizing then W:Sizing() end end)
  self.sizer = g
  self:ApplyScale()
end

------------------------------------------------------------------------
-- Start-up, settings
------------------------------------------------------------------------

function W:Setup()
  if self.ready or not (WorldMapFrame and WorldMapFrame.GetCanvas) then return end
  self.ready = true
  if ns.db.mapSkin then self:SetupSkin() end
  self:SetupLabels()
  self:SetupDrag()
  self:SetupResize()
end

function W:Enable()
  self.enabled = true
  if WorldMapFrame then return self:Setup() end
  -- The game can load its map after VoltUI starts.
  local ev = CreateFrame("Frame")
  ev:RegisterEvent("ADDON_LOADED")
  ev:SetScript("OnEvent", function(frame)
    if WorldMapFrame then
      frame:UnregisterEvent("ADDON_LOADED")
      W:Setup()
    end
  end)
end

function W:Refresh()
  if not self.ready then return end
  if ns.db.mapSkin and WorldMapFrame.fuiPanel then self:PaintPanel() end
  self:Draw()
end

local function OnOff(v) return v and "|cff7fff7fon|r" or "|cffff7f7foff|r" end

-- What each zone on this map is getting, for reporting a wrong number or spot.
function W:Debug()
  local mapID = WorldMapFrame and WorldMapFrame:GetMapID()
  if not mapID then return FUI:Print("Open the world map first.") end
  local _, zoneType = MapTypes()
  local children = C_Map.GetMapChildrenInfo(mapID, zoneType) or {}
  FUI:Print("Map %d: %d zones, %d labels.", mapID, #children, self.used)
  local credit
  for _, child in ipairs(children) do
    local lo, hi, from = W.Levels(child.mapID)
    local x, y = self:Spot(mapID, child.mapID)
    FUI:Print("%d %s: %s, at %s", child.mapID, child.name or "?",
      lo and (RangeText(lo, hi) .. " (" .. from .. ")") or "no levels",
      x and ("%.2f, %.2f"):format(x, y) or "nowhere")
    credit = credit or from == "extra"
  end
  if credit and ExtraLevels().credit then FUI:Print("%s", ExtraLevels().credit) end
end

-- The layer a /volt worldmap word belongs to.
function W:Layer(word)
  if word == "" then return nil end
  for _, l in ipairs(self.layers) do
    if l.slash == word then return l end
  end
end

function W:Slash(arg)
  local db = ns.db
  local cmd, value = (arg or ""):match("^(%S*)%s*(.-)$")
  local n = tonumber(value)
  local toggles = { levels = "mapLevels", plates = "mapPlates" }
  if toggles[cmd] then
    db[toggles[cmd]] = not db[toggles[cmd]]
    self:Draw()
    FUI:Print("World map %s: %s", cmd, OnOff(db[toggles[cmd]]))
  elseif cmd == "size" and n then
    db.mapLabelSize = max(10, min(24, floor(n + 0.5)))
    self:Draw()
    FUI:Print("World map level size: %d", db.mapLabelSize)
  elseif cmd == "skin" then
    db.mapSkin = not db.mapSkin
    FUI:Print("World map look: %s. Type /reload to apply.", OnOff(db.mapSkin))
  elseif cmd == "drag" then
    db.mapDrag = not db.mapDrag
    if self.grip then self.grip:SetShown(db.mapDrag) end
    self:PlaceWindow()
    FUI:Print("World map dragging: %s%s", OnOff(db.mapDrag), db.mapDrag and "" or ". It goes back to the game's spot next time you open it.")
  elseif cmd == "scale" and n then
    -- 60 to 200 as a percentage, or 0.6 to 2
    self:SetMapScale(n > 5 and n / 100 or n)
    FUI:Print("Small world map size: %d%%", floor(db.mapScale * 100 + 0.5))
  elseif cmd == "reset" then
    S.ClearSpot(db, "mapLeft", "mapTop", "mapPoint")
    S.ClearSpot(db, "mapBigLeft", "mapBigTop", "mapBigPoint")
    db.mapScale, self.scaleNow = 1, 1
    self:ApplyScale()
    FUI:Print("World map spot and size forgotten. It goes back to the game's spot next time you open it.")
  elseif self:Layer(cmd) then
    self:Layer(cmd):Toggle(value)
  elseif cmd == "debug" then
    self:Debug()
  else
    local extra = {}
    for _, l in ipairs(self.layers) do
      if l.slash then extra[#extra + 1] = l.slash .. " " .. (l.Status and l:Status() or "") end
    end
    FUI:Print("/volt worldmap levels %s · plates %s · size %d (10-24) · %sskin %s · drag %s · scale %d (60-200) · reset · debug · on|off",
      OnOff(db.mapLevels), OnOff(db.mapPlates), db.mapLabelSize, #extra > 0 and (table.concat(extra, " · ") .. " · ") or "",
      OnOff(db.mapSkin), OnOff(db.mapDrag), floor((tonumber(db.mapScale) or 1) * 100 + 0.5))
    local z = ExtraLevels()
    if z and z.credit then FUI:Print("Map levels: %s", z.credit) end
    for _, l in ipairs(self.layers) do
      local c = l.credit and l:credit()
      if c then FUI:Print("%s: %s", l.name or l.key, c) end
    end
  end
end

FUI:Register(W)
