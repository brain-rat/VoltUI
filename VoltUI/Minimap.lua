-- VoltUI · Minimap
-- Square, flat minimap: Blizzard's round border, compass, zoom buttons, world-map
-- button, zone banner and clock are gone. Three rows underneath (1.83.0, in VoltUI's own
-- windows' look): the place name on a row of its own after a square in the territory's
-- colour; your coordinates and the clock; then the other readouts.
--
--   Mouse wheel   zoom          Right-click   tracking menu
--   Click a row   world map     Middle-click  calendar (if the game has one)
--   Click the clock or the readouts: calendar
--
-- Mail, queue and battleground icons and the tracking icon stay, moved to the corners.
--
-- The map sits in VoltUI's own holder frame (VoltUIMinimapHolder), so it can be dragged while
-- moving frames, snapped and nudged like the others, and scaled. The game's cluster stays
-- where the game puts it, empty, and lets clicks through.

local _, ns = ...
local FUI, S = ns.FUI, ns.Style

local M = { key = "map", name = "Square minimap" }
ns.Minimap = M

local STRIP_H = 20 -- the place name's row
local MID_H = 18 -- coordinates and the clock
local INFO_H = 18 -- the line of readouts under those
-- The readouts on the last row. The clock (stripClock) sits on the row above since 1.83.0.
local INFO_KEYS = { "stripMs", "stripFps", "stripDura", "stripGold", "stripMail" }
local T, A = S.UI, S.UI.accent
local DIM = "8c8c8c"
local SCALE_MIN, SCALE_MAX = 0.5, 2
-- Before it's moved, the holder's top-right hangs here from the screen's top-right: where
-- the game's own layout puts the map, so nothing shifts until it's moved.
local DEFAULT_X, DEFAULT_Y = -18, -43

local function Spot() return ns.db, "minimapLeft", "minimapTop", "minimapPoint" end

-- Blizzard parts to hide (Classic and modern names; missing ones are skipped).
local HIDE = {
  "MinimapBorder", "MinimapBorderTop", "MinimapCompassTexture", "MinimapNorthTag",
  "MinimapZoomIn", "MinimapZoomOut", "MiniMapWorldMapButton", "MinimapToggleButton",
  "MinimapZoneTextButton", "GameTimeFrame", "TimeManagerClockButton",
  "MiniMapMeetingStoneFrame", "MinimapBackdropBorder",
  "MinimapCompassTextureUnderlay", -- the round plate the game shows under a rotating minimap
}
local function Modern(path)
  local t = _G
  for k in path:gmatch("[^%.]+") do
    t = type(t) == "table" and rawget(t, k) or (type(t) == "table" and t == _G and _G[k]) or nil
  end
  return type(t) == "table" and t or nil
end
local HIDE_MODERN = {
  "MinimapCluster.BorderTop", "MinimapCluster.ZoneTextButton", "MinimapCluster.Tracking.Background",
  "Minimap.ZoomIn", "Minimap.ZoomOut", "Minimap.ZoomHitArea", "ExpansionLandingPageMinimapButton",
  "MinimapCluster.MinimapContainer.PlayerCoords", -- the game's own coordinates, under the map where the strip is
  "MinimapCluster.DielFrame", -- this client's day/night ring: it stays where the game's map was
}
-- Kept, moved to a corner: { name, corner, x, y }
local KEEP = {
  { "MiniMapMailFrame", "TOPRIGHT", -2, -2 },
  { "MiniMapTracking", "TOPLEFT", 2, -2 },
  { "MiniMapTrackingFrame", "TOPLEFT", 2, -2 },
  { "MinimapCluster.Tracking", "TOPLEFT", 2, -2 },
  { "MiniMapBattlefieldFrame", "BOTTOMLEFT", 2, 2 },
  { "MiniMapLFGFrame", "BOTTOMLEFT", 2, 2 },
}

-- Other add-ons place their minimap buttons around a square: set once the map is made square
-- (M:Enable), so the round map keeps its round answer while this part is off.
local function SquareShape() return "SQUARE" end

local function PvPColor()
  local pvp = GetZonePVPInfo and GetZonePVPInfo()
  if pvp == "sanctuary" then return 0.41, 0.8, 0.94 end
  if pvp == "friendly" then return 0.1, 1, 0.1 end
  if pvp == "hostile" then return 1, 0.1, 0.1 end
  if pvp == "contested" then return 1, 0.7, 0 end
  if pvp == "arena" or pvp == "combat" then return 1, 0.1, 0.1 end
  return 1, 0.82, 0
end

function M:Square()
  Minimap:SetMaskTexture(S.WHITE)
  if Minimap.SetArchBlobRingScalar then Minimap:SetArchBlobRingScalar(0) end
  if Minimap.SetArchBlobRingAlpha then Minimap:SetArchBlobRingAlpha(0) end
  if Minimap.SetQuestBlobRingScalar then Minimap:SetQuestBlobRingScalar(0) end
  if Minimap.SetQuestBlobRingAlpha then Minimap:SetQuestBlobRingAlpha(0) end
  if Minimap.SetTaskBlobRingScalar then Minimap:SetTaskBlobRingScalar(0) end
end

function M:Strip()
  ns.killing = true
  for _, name in ipairs(HIDE) do S.Kill(_G[name]) end
  for _, path in ipairs(HIDE_MODERN) do S.Kill(Modern(path)) end
  -- MinimapBackdrop holds the round art in Classic, but also some buttons: hide only its textures.
  local bd = _G.MinimapBackdrop
  if bd and bd.GetRegions then
    for _, r in ipairs({ bd:GetRegions() }) do
      if r.IsObjectType and r:IsObjectType("Texture") then r:SetAlpha(0) end
    end
  end
  for _, k in ipairs(KEEP) do
    local f = _G[k[1]] or Modern(k[1])
    if f and f.ClearAllPoints and not (f.IsProtected and f:IsProtected()) then
      pcall(function()
        f:ClearAllPoints()
        f:SetPoint(k[2], Minimap, k[2], k[3], k[4])
      end)
    end
  end
  self:PlaceMail()
end

-- New mail. On this client the icon has no name of its own: it sits in the cluster's
-- IndicatorFrame, which the game hangs off the zone text or the tracking button, so it was
-- left wherever those were. The whole indicator goes to the map's top-right corner, and back
-- there each time the game places it again (1.101.10).
function M:PlaceMail()
  local f = Modern("MinimapCluster.IndicatorFrame")
  if not f or not f.ClearAllPoints or (f.IsProtected and f:IsProtected()) then return end
  self.placingMail = true
  pcall(function()
    f:ClearAllPoints()
    f:SetPoint("TOPRIGHT", Minimap, "TOPRIGHT", -2, -2)
    if f.SetFrameLevel and Minimap.GetFrameLevel then f:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 5) end
  end)
  self.placingMail = nil
  if self.mailHooked then return end
  self.mailHooked = true
  local again = function() if not M.placingMail then M:PlaceMail() end end
  if type(MiniMapIndicatorFrame_UpdatePosition) == "function" then hooksecurefunc("MiniMapIndicatorFrame_UpdatePosition", again) end
  local c = _G.MinimapCluster
  if c and type(c.SetHeaderUnderneath) == "function" then hooksecurefunc(c, "SetHeaderUnderneath", again) end
end

-- Right-click (tracking) and middle-click (calendar) used to reach the game's own click
-- handler too, which pings the map on any button. A plain frame over the map now takes
-- those two; the left button passes through it, so a left click still pings, and the mouse
-- moving over it passes through as well, so the map's own tooltips still show. Setting which
-- buttons pass through isn't allowed in a fight, so a reload in one waits (1.101.9).
function M:Catcher()
  if self.catch then return end
  if InCombatLockdown() then
    self.catchPending = true
    return
  end
  self.catchPending = nil
  local f = CreateFrame("Frame", "VoltUIMinimapClicks", Minimap)
  if not f.SetPassThroughButtons or not f.SetMouseMotionEnabled then return end -- an older client: as before
  f:SetAllPoints(Minimap)
  f:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 1) -- under the pins (+4) and VoltUI's button (+8)
  local ok = pcall(function()
    f:EnableMouse(true)
    f:SetMouseMotionEnabled(false)
    f:SetPassThroughButtons("LeftButton")
  end)
  if not ok then
    f:Hide()
    return
  end
  f:SetScript("OnMouseUp", function(_, button) M:Click(button) end)
  self.catch = f
end

function M:Click(button)
  if button == "RightButton" then
    M:TrackingMenu()
  elseif button == "MiddleButton" then
    if ToggleCalendar then pcall(ToggleCalendar) end
  end
end

-- The game's clock, as text. Above M:Build, which uses it for the readout line's tooltip.
local function Clock()
  if GameTime_GetTime then
    local ok, text = pcall(GameTime_GetTime, false)
    if ok and type(text) == "string" and text ~= "" then return text end
  end
  return date and date("%H:%M") or ""
end

function M:Build()
  if self.border then return end
  -- 1px border just outside the map, and the info strip below it.
  local b = CreateFrame("Frame", nil, Minimap)
  b:SetAllPoints(Minimap)
  b:SetFrameLevel(Minimap:GetFrameLevel() + 2)
  self.edges = S.Edges(b, "OVERLAY", 7, Minimap, 1)
  self.border = b
  -- two gold ticks in the map's bottom corners
  self.ticks = {}
  for _, side in ipairs({ "LEFT", "RIGHT" }) do
    for _, size in ipairs({ { 12, 2 }, { 2, 12 } }) do
      local t = S.Tex(b, "OVERLAY", 6)
      t:SetPoint("BOTTOM" .. side, Minimap, "BOTTOM" .. side, 0, 0)
      t:SetSize(size[1], size[2])
      t:SetColorTexture(A[1], A[2], A[3], 1)
      self.ticks[#self.ticks + 1] = t
    end
  end

  local function WorldMap()
    if ToggleWorldMap then ToggleWorldMap() elseif ToggleFrame and WorldMapFrame then ToggleFrame(WorldMapFrame) end
  end
  local function Calendar() if ToggleCalendar then pcall(ToggleCalendar) end end
  local function ZoneTip(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:SetText(GetZoneText and GetZoneText() or "", PvPColor())
    local sub = GetSubZoneText and GetSubZoneText()
    if sub and sub ~= "" then GameTooltip:AddLine(sub, 1, 1, 1) end
    GameTooltip:AddLine("Click: world map", 0.6, 0.75, 1)
    GameTooltip:AddLine("On the map: wheel to zoom, right-click for tracking", 0.6, 0.75, 1)
    GameTooltip:Show()
  end
  local function TipOff() GameTooltip:Hide() end

  -- Row 1: the place name with the row to itself, so a long one fits. The square before it
  -- carries the territory's colour, which the name itself had before 1.83.0.
  local strip = CreateFrame("Button", "VoltUIMinimapStrip", Minimap)
  strip:SetPoint("TOPLEFT", Minimap, "BOTTOMLEFT", -1, 0)
  strip:SetPoint("TOPRIGHT", Minimap, "BOTTOMRIGHT", 1, 0)
  strip:SetHeight(STRIP_H)
  S.ThemePanel(strip, ns.db.alpha)
  S.Hover(strip, { bar = false })
  strip.mark = S.Tex(strip, "ARTWORK")
  strip.mark:SetSize(6, 6)
  strip.mark:SetPoint("LEFT", 7, 0)
  strip.zone = S.UIText(strip, nil, "LEFT", nil, 12)
  S.FixFont(strip.zone, 12, nil, "semibold")
  strip.zone:SetPoint("LEFT", strip.mark, "RIGHT", 6, 0)
  strip.zone:SetPoint("RIGHT", -6, 0)
  if strip.zone.SetWordWrap then strip.zone:SetWordWrap(false) end
  strip.zone:SetTextColor(T.text[1], T.text[2], T.text[3])
  strip:RegisterForClicks("LeftButtonUp")
  strip:SetScript("OnClick", WorldMap)
  strip:SetScript("OnEnter", ZoneTip)
  strip:SetScript("OnLeave", TipOff)
  self.strip = strip

  -- Row 2: coordinates, a hatched strip, the clock.
  local mid = CreateFrame("Button", "VoltUIMinimapMid", Minimap)
  mid:SetPoint("TOPLEFT", strip, "BOTTOMLEFT", 0, 1)
  mid:SetPoint("TOPRIGHT", strip, "BOTTOMRIGHT", 0, 1)
  mid:SetHeight(MID_H)
  S.ThemePanel(mid, ns.db.alpha)
  S.Hover(mid, { bar = false })
  strip.coords = S.UIText(mid, nil, "LEFT", nil, 11, nil, "mono")
  strip.coords:SetPoint("LEFT", 7, 0)
  strip.coords:SetTextColor(T.text[1], T.text[2], T.text[3])
  mid.coords = strip.coords
  mid.clock = S.UIText(mid, nil, "RIGHT", nil, 11, nil, "mono")
  mid.clock:SetPoint("RIGHT", -7, 0)
  mid.clock:SetTextColor(T.text[1], T.text[2], T.text[3])
  mid.hatch = S.Hatch(S.Tex(mid, "ARTWORK"))
  mid.hatch:SetHeight(5)
  S.Paint(mid.hatch, 0.23, 0.23, 0.23, 1)
  mid:RegisterForClicks("LeftButtonUp")
  mid:SetScript("OnClick", WorldMap)
  mid:SetScript("OnEnter", ZoneTip)
  mid:SetScript("OnLeave", TipOff)
  mid.clockBtn = CreateFrame("Button", nil, mid)
  mid.clockBtn:SetPoint("TOPRIGHT", -1, -1)
  mid.clockBtn:SetPoint("BOTTOMRIGHT", -1, 1)
  mid.clockBtn:SetWidth(46)
  mid.clockBtn:RegisterForClicks("LeftButtonUp")
  mid.clockBtn:SetScript("OnClick", Calendar)
  mid.clockBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:SetText(Clock(), A[1], A[2], A[3])
    if ToggleCalendar then GameTooltip:AddLine("Click: calendar", 0.6, 0.75, 1) end
    GameTooltip:Show()
  end)
  mid.clockBtn:SetScript("OnLeave", TipOff)
  self.mid = mid

  -- Row 3: the other readouts.
  local info = CreateFrame("Button", "VoltUIMinimapInfo", Minimap)
  info:SetPoint("TOPLEFT", mid, "BOTTOMLEFT", 0, 1)
  info:SetPoint("TOPRIGHT", mid, "BOTTOMRIGHT", 0, 1)
  info:SetHeight(INFO_H)
  S.ThemePanel(info, ns.db.alpha)
  info.back = S.Tex(info, "BACKGROUND", 1) -- the darkest grey, as the bags' pane
  info.back:SetPoint("TOPLEFT", 1, -1)
  info.back:SetPoint("BOTTOMRIGHT", -1, 1)
  info.back:SetColorTexture(T.bg[1], T.bg[2], T.bg[3], 1)
  S.Hover(info, { bar = false })
  info.text = S.UIText(info, nil, "CENTER", nil, 10, nil, "mono")
  info.text:SetPoint("LEFT", 4, 0)
  info.text:SetPoint("RIGHT", -4, 0)
  if info.text.SetWordWrap then info.text:SetWordWrap(false) end
  info:RegisterForClicks("LeftButtonUp")
  info:SetScript("OnClick", Calendar)
  info:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:SetText(Clock(), A[1], A[2], A[3])
    if GetNetStats then
      local _, _, home, world = GetNetStats()
      if type(home) == "number" then GameTooltip:AddDoubleLine("Latency, home", home .. " ms", 0.75, 0.77, 0.8, 1, 1, 1) end
      if type(world) == "number" then GameTooltip:AddDoubleLine("Latency, world", world .. " ms", 0.75, 0.77, 0.8, 1, 1, 1) end
    end
    local p = M.Durability()
    if p then GameTooltip:AddDoubleLine("Most worn gear", p .. "%", 0.75, 0.77, 0.8, 1, 1, 1) end
    if GetMoney and GetCoinTextureString then GameTooltip:AddDoubleLine("Money", GetCoinTextureString(GetMoney()), 0.75, 0.77, 0.8, 1, 1, 1) end
    if HasNewMail and HasNewMail() then GameTooltip:AddLine("You have mail", A[1], A[2], A[3]) end
    if ToggleCalendar then GameTooltip:AddLine("Click: calendar", 0.6, 0.75, 1) end
    GameTooltip:Show()
  end)
  info:SetScript("OnLeave", function() GameTooltip:Hide() end)
  -- once a second, from the middle row: it is always shown, the readouts' row may not be
  local wait = 1
  mid:SetScript("OnUpdate", function(_, dt)
    wait = wait + (dt or 0)
    if wait < 1 then return end
    wait = 0
    M:UpdateInfo()
  end)
  info:SetShown(self:InfoOn())
  self.info = info

  local elapsed = 0
  strip:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    if elapsed < 0.2 then return end
    elapsed = 0
    M:UpdateText()
  end)

  -- Mouse: wheel zooms, right-click tracking, middle-click calendar.
  Minimap:EnableMouseWheel(true)
  Minimap:SetScript("OnMouseWheel", function(self, delta)
    local z = self:GetZoom() + (delta > 0 and 1 or -1)
    local maxZ = (self.GetZoomLevels and self:GetZoomLevels() or 6) - 1
    if z >= 0 and z <= maxZ then self:SetZoom(z) end
  end)
  self:Catcher()
  -- Without the catcher (an older client, or until a fight ends) the map's own handler is hooked.
  Minimap:HookScript("OnMouseUp", function(_, button)
    if not M.catch then M:Click(button) end
  end)
end

function M:TrackingMenu()
  local t = Modern("MinimapCluster.Tracking.Button")
  if t and t.OpenMenu then return pcall(t.OpenMenu, t) end
  if t and t.Click then return pcall(t.Click, t) end
  if MiniMapTrackingDropDown and ToggleDropDownMenu then
    return pcall(ToggleDropDownMenu, 1, nil, MiniMapTrackingDropDown, "cursor")
  end
  local b = _G.MiniMapTrackingButton or _G.MiniMapTracking
  if b and b.Click then pcall(b.Click, b) end
end

function M:UpdateText()
  local strip = self.strip
  local zone = (GetMinimapZoneText and GetMinimapZoneText()) or (GetZoneText and GetZoneText()) or ""
  strip.zone:SetText(zone)
  strip.mark:SetColorTexture(PvPColor())
  local m = C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
  local text = ""
  if m and not (issecretvalue and issecretvalue(m)) then
    local pos = C_Map.GetPlayerMapPosition(m, "player")
    if pos and not (issecretvalue and issecretvalue(pos)) then
      local x, y = pos.x, pos.y
      if pos.GetXY then x, y = pos:GetXY() end
      if x and not (issecretvalue and issecretvalue(x)) and (x > 0 or y > 0) then
        text = ("%.1f|cff%s,|r %.1f"):format(x * 100, DIM, y * 100)
      end
    end
  end
  strip.coords:SetText(text)
end

------------------------------------------------------------------------
-- Holder: where the map sits and how big it is
------------------------------------------------------------------------

function M:Scale()
  local s = tonumber(ns.db.minimapScale) or 1
  return math.max(SCALE_MIN, math.min(SCALE_MAX, s))
end

-- The holder's size in its own units: the map, its 1px border and the rows under it, which
-- share their border lines. Read from the map once, since VoltUI never sizes the map itself.
function M:Size()
  local w, h = self.mapW, self.mapH
  if not w then
    w, h = Minimap:GetWidth(), Minimap:GetHeight()
    if type(w) ~= "number" or w <= 0 then w = 198 end
    if type(h) ~= "number" or h <= 0 then h = w end
    self.mapW, self.mapH = w, h -- read once: later the game can hand back a stale size
  end
  return w + 2, h + STRIP_H + MID_H + (self:InfoOn() and INFO_H - 1 or 0)
end

------------------------------------------------------------------------
-- The readouts: the clock beside the coordinates; latency, frame rate, durability, gold and
-- mail on the row under them
------------------------------------------------------------------------

-- Whether the last row has anything to show.
function M:InfoOn()
  for _, k in ipairs(INFO_KEYS) do
    if ns.db[k] then return true end
  end
  return false
end

-- Your most worn piece of gear, as a whole percent. Nil with nothing that wears.
function M.Durability()
  if not GetInventoryItemDurability then return nil end
  local worst
  for slot = 1, 18 do
    local cur, most = GetInventoryItemDurability(slot)
    if type(cur) == "number" and type(most) == "number" and most > 0 then
      local p = cur / most
      if not worst or p < worst then worst = p end
    end
  end
  return worst and math.floor(worst * 100 + 0.5) or nil
end

-- The readouts that are on, in order, each { key, text, colour code } and, for a number with
-- a unit, num and unit (the unit is drawn dim, or in uhex).
function M:InfoParts()
  local db, out = ns.db, {}
  local function add(key, text, hex, num, unit, uhex)
    out[#out + 1] = { key = key, text = text, hex = hex, num = num, unit = unit, uhex = uhex }
  end
  local OK, WARN, BAD, PLAIN = "4ade80", "facc15", "f87171", "ffffff"
  if db.stripClock then add("clock", Clock(), PLAIN) end
  if db.stripMs and GetNetStats then
    local _, _, home, world = GetNetStats()
    local ms = (type(world) == "number" and world > 0) and world or home
    if type(ms) == "number" then add("ms", ms .. " ms", ms >= 400 and BAD or ms >= 200 and WARN or OK, ms, "ms") end
  end
  if db.stripFps and GetFramerate then
    local fps = GetFramerate()
    if type(fps) == "number" then add("fps", math.floor(fps + 0.5) .. " fps", PLAIN, math.floor(fps + 0.5), "fps") end
  end
  if db.stripDura then
    local p = M.Durability()
    if p then add("dura", p .. "%", p < 20 and BAD or p < 50 and WARN or PLAIN, p, "%") end
  end
  if db.stripGold and GetMoney then
    local m = GetMoney()
    if type(m) == "number" then add("gold", math.floor(m / 10000) .. "g", PLAIN, math.floor(m / 10000), "g", "ffc61a") end
  end
  if db.stripMail and HasNewMail and HasNewMail() then add("mail", "Mail", "ffc61a") end
  return out
end

function M:UpdateInfo()
  local mid, line = self.mid, self.info
  if not mid then return end
  local clock, bits = "", {}
  for _, p in ipairs(self:InfoParts()) do
    if p.key == "clock" then
      clock = p.text
    elseif p.unit then
      bits[#bits + 1] = ("|cff%s%s|r|cff%s%s|r"):format(p.hex, p.num, p.uhex or DIM, p.unit)
    else
      bits[#bits + 1] = ("|cff%s%s|r"):format(p.hex, p.text)
    end
  end
  mid.clock:SetText(clock)
  -- the hatch runs from the coordinates to the clock, or to the row's end without one
  local on = clock ~= ""
  if mid.clockOn ~= on then
    mid.clockOn = on
    mid.clockBtn:SetShown(on)
    mid.hatch:ClearAllPoints()
    mid.hatch:SetPoint("LEFT", mid.coords, "RIGHT", 7, 0)
    if on then mid.hatch:SetPoint("RIGHT", mid.clock, "LEFT", -7, 0) else mid.hatch:SetPoint("RIGHT", mid, "RIGHT", -7, 0) end
  end
  if line and line:IsShown() then line.text:SetText(table.concat(bits, "  ")) end
end

-- Shows or hides the line and gives the holder its new height. Out of combat only: the map
-- sits in the holder.
function M:ApplyInfo()
  local line = self.info
  if not line then return end
  if InCombatLockdown() then
    self.infoPending = true
    return
  end
  self.infoPending = nil
  local on = self:InfoOn()
  line:SetShown(on)
  if self.holder then
    self.w, self.h = self:Size()
    self.holder:SetSize(self.w, self.h)
  end
  self:UpdateInfo()
end

function M:Holder()
  if self.holder then return self.holder end
  local hold = CreateFrame("Frame", "VoltUIMinimapHolder", UIParent)
  hold:SetFrameStrata("LOW")
  hold:SetClampedToScreen(true)
  self.w, self.h = self:Size()
  hold:SetSize(self.w, self.h)
  self.holder = hold
  hold.mover = S.Mover(hold, "Minimap", function()
    S.KeepSpot(hold, Spot())
  end, { spot = Spot })
  -- Above the map's own buttons and other add-ons' icons on it.
  hold.mover:SetFrameStrata("MEDIUM")
  return hold
end

-- Moves the map into the holder. Not in combat, since another add-on's secure button on the
-- map would make that a blocked action; it waits for the fight to end.
function M:Anchor()
  local hold = self.holder
  if not hold then return end
  if InCombatLockdown() then
    self.anchorPending = true
    return
  end
  self.anchorPending = nil
  self.anchoring = true
  local ok, err = pcall(function()
    if Minimap:GetParent() ~= hold then Minimap:SetParent(hold) end
    Minimap:ClearAllPoints()
    Minimap:SetPoint("TOPLEFT", hold, "TOPLEFT", 1, -1)
  end)
  self.anchoring = nil
  if not ok and ns.Errors then ns.Errors:Add("Minimap: " .. tostring(err), nil, nil, "volt") end
  -- The game's cluster stays where the game puts it, now empty. Clicks go through it.
  local c = _G.MinimapCluster
  if c and c.EnableMouse then pcall(c.EnableMouse, c, false) end
end

-- Puts the holder at its saved spot (or the default one) at its scale.
function M:Place()
  local hold = self.holder
  if not hold then return end
  if InCombatLockdown() then
    self.placePending = true
    return
  end
  self.placePending = nil
  local s = self:Scale()
  hold:SetScale(s)
  self.applied = s
  if not S.PlaceSpot(hold, Spot()) then
    hold:ClearAllPoints()
    hold:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", DEFAULT_X, DEFAULT_Y)
  end
end

-- The holder's top-left in screen units (UIParent's) at scale s, from the saved spot or the
-- default one. Worked out, never read back from the frame (see Saved spots in Style.lua).
function M:TopLeft(s)
  local W, H = UIParent:GetWidth(), UIParent:GetHeight()
  local t, xk, yk, pk = Spot()
  local x, y, p = t[xk], t[yk], t[pk]
  if type(x) == "number" and type(y) == "number" then
    if type(p) ~= "string" then p = "BOTTOMLEFT" end
    local ax = p:find("LEFT") and 0 or p:find("RIGHT") and W or W / 2
    local ay = p:find("BOTTOM") and 0 or p:find("TOP") and H or H / 2
    return ax + x * s, ay + y * s
  end
  return W + (DEFAULT_X - self.w) * s, H + DEFAULT_Y * s
end

-- A new scale. The side of the map nearest the screen's edge stays where it is, so a map in
-- the top-right corner grows down and to the left, one at the bottom grows up, and one in
-- the middle grows around its middle.
function M:Rescale()
  local hold = self.holder
  if not hold then return end
  if InCombatLockdown() then
    self.rescalePending = true
    return
  end
  self.rescalePending = nil
  local old, new = self.applied or 1, self:Scale()
  if old == new then return end
  local W, H = UIParent:GetWidth(), UIParent:GetHeight()
  local L, T = self:TopLeft(old)
  local w, h = self.w * old, self.h * old
  local nw, nh = self.w * new, self.h * new
  local cx, cy = L + w / 2, T - h / 2
  local nl, nt
  if cx < W / 3 then nl = L elseif cx > W * 2 / 3 then nl = L + w - nw else nl = cx - nw / 2 end
  if cy > H * 2 / 3 then nt = T elseif cy < H / 3 then nt = T - h + nh else nt = cy + nh / 2 end
  hold:SetScale(new)
  self.applied = new
  local t, xk, yk, pk = Spot()
  local p, x, y = S.SpotFrom(hold, nl / new, nt / new, true, new)
  if p then t[xk], t[yk], t[pk] = x, y, p end
  if not S.PlaceSpot(hold, t, xk, yk, pk) then self:Place() end
  if ns.Move and ns.Move.Readout then pcall(ns.Move.Readout, ns.Move) end
end

function M:SetUnlocked(on)
  if self.holder and self.holder.mover then self.holder.mover:SetShown(on) end
end

-- Back to the game's spot and its normal size.
function M:Reset()
  ns.db.minimapScale = FUI.defaults.minimapScale or 1
  S.ClearSpot(Spot())
  self:Place()
end

function M:Slash(arg)
  local cmd, rest = (arg or ""):match("^(%S*)%s*(.-)$")
  local n = tonumber(rest)
  if not self.enabled then
    FUI:Print("The square minimap is off. /volt map on, then /reload.")
  elseif cmd == "scale" and n then
    ns.db.minimapScale = math.max(SCALE_MIN, math.min(SCALE_MAX, n))
    self:Rescale()
    FUI:Print("minimap scale %.2f", self:Scale())
  elseif cmd == "reset" then
    self:Reset()
    FUI:Print("minimap back in its default spot and size.")
  else
    FUI:Print("/volt minimap scale 0.5-2 · reset. /volt edit to drag it, or /volt to open its page.")
  end
end

function M:Refresh()
  if not self.strip then return end
  S.ThemePanel(self.strip, ns.db.alpha)
  if self.mid then S.ThemePanel(self.mid, ns.db.alpha) end
  if self.info then S.ThemePanel(self.info, ns.db.alpha) end
  S.ColorEdges(self.edges, T.edge[1], T.edge[2], T.edge[3], 1)
  self:UpdateInfo()
end

function M:Enable()
  if not Minimap then return end
  self.enabled = true
  _G.GetMinimapShape = SquareShape
  self:Square()
  self:Strip()
  self:Build()
  self:Holder()
  self:Anchor()
  self:Place()
  self:Refresh()
  self:UpdateText()
  -- If anything puts the map back in the game's cluster, it comes back to the holder.
  local function Back()
    if M.anchoring or M.backQueued then return end
    M.backQueued = true
    C_Timer.After(0, function()
      M.backQueued = nil
      M:Anchor()
    end)
  end
  hooksecurefunc(Minimap, "SetPoint", Back)
  hooksecurefunc(Minimap, "SetParent", Back)
  -- Turning on the rotating minimap puts the game's round mask back.
  local c = _G.MinimapCluster
  if c and type(c.UpdateMinimapConfig) == "function" then
    hooksecurefunc(c, "UpdateMinimapConfig", function()
      M:Square()
      local under = _G.MinimapCompassTextureUnderlay -- shown again by the game for a rotating map
      if under and under.SetAlpha then under:SetAlpha(0) end
    end)
  end
  -- The game re-applies some of its own layout on loading screens.
  local ev = CreateFrame("Frame")
  ev:RegisterEvent("PLAYER_ENTERING_WORLD")
  ev:RegisterEvent("ZONE_CHANGED_NEW_AREA")
  ev:RegisterEvent("PLAYER_REGEN_ENABLED")
  ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
      if M.anchorPending then M:Anchor() end
      if M.catchPending then M:Catcher() end
      -- Before Place, which takes the new scale as applied and would leave Rescale nothing to do.
      if M.rescalePending then M:Rescale() end
      if M.placePending then M:Place() end
      if M.infoPending then M:ApplyInfo() end
      return
    end
    C_Timer.After(0.5, function()
      M:Square()
      M:Strip()
      M:Anchor()
      M:UpdateText()
    end)
  end)
end

FUI:Register(M)
