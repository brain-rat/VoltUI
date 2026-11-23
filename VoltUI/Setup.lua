-- VoltUI · Starting layouts
-- A small window with a few ready-made layouts to start from (since 1.50.0). It opens by
-- itself once, on a brand-new install only. Anyone who already has VoltUI set up never sees it
-- unless they open it (Home, or /volt setup), and nothing moves unless they press "Use this".
--
-- A layout only says where frames sit: the player, target and focus frames, your cast bar, and
-- the party and raid frames. The three presets (1.100.0) also lay out action bars 2 and 3. No
-- other setting changes. What was there before is kept, so Undo puts it all back exactly.

local _, ns = ...
local FUI, S = ns.FUI, ns.Style

local Su = {}
ns.Setup = Su

local A = S.UI.accent
local WIDTH, CARD_W, THUMB_W, THUMB_H = 848, 196, 180, 112 -- four cards since 1.100.0

-- Spots are a frame's top-left measured from a point of the screen, as everywhere in VoltUI
-- (Style.lua): { point, left, top }. A frame not named here goes back to its default spot.
-- `draw` is the thumbnail: boxes as fractions of the screen { x, y from the top, w, h, kind }.
Su.LAYOUTS = {
  {
    key = "classic", name = "Classic",
    text = "VoltUI's own defaults: frames either side of the middle, above the bars. Groups on the left.",
    spots = {},
    draw = {
      { 0.30, 0.64, 0.15, 0.06, "frame" }, { 0.55, 0.64, 0.15, 0.06, "frame" }, { 0.42, 0.72, 0.16, 0.025, "cast" },
      { 0.03, 0.30, 0.06, 0.26, "group" },
    },
  },
  -- The three presets (1.100.0), from the default-layout mock-ups. They're on the Home page too.
  -- A preset also arranges action bars 2 and 3 (`bars`): whether each is on, how many buttons to
  -- a row, and where it sits. Spots are measured from the bottom middle of the screen (or its top
  -- left), so they hold on any screen size.
  {
    key = "centre", name = "Centre", preset = true,
    text = "Player and target close under your character, cast bar beneath them. Bar 1 in the middle, bars 2 and 3 as blocks either side of it.",
    spots = {
      player = { "BOTTOM", -254, 340 }, target = { "BOTTOM", 24, 340 }, cast = { "BOTTOM", -130, 258 },
    },
    bars = {
      bar2 = { on = true, perRow = 6, point = "BOTTOM", left = -475, top = 95 },
      bar3 = { on = true, perRow = 6, point = "BOTTOM", left = 245, top = 95 },
    },
    draw = {
      { 0.341, 0.62, 0.144, 0.058, "frame" }, { 0.515, 0.62, 0.144, 0.058, "frame" }, { 0.42, 0.715, 0.16, 0.025, "cast" },
      { 0.03, 0.30, 0.06, 0.26, "group" },
      { 0.20, 0.855, 0.145, 0.07, "bars" }, { 0.655, 0.855, 0.145, 0.07, "bars" },
    },
    oneBar = true,
  },
  {
    key = "healer", name = "Healer", preset = true,
    text = "Party and raid frames in the middle, under your character, where your eyes already are. Your own frames and two bars below them.",
    spots = {
      player = { "BOTTOM", -254, 176 }, target = { "BOTTOM", 24, 176 }, cast = { "BOTTOM", -130, 119 },
      raid = { "BOTTOM", -196, 390 },
    },
    bars = {
      bar2 = { on = true, perRow = 12 },
      bar3 = { on = false, perRow = 12 },
    },
    draw = {
      { 0.341, 0.805, 0.144, 0.058, "frame" }, { 0.515, 0.805, 0.144, 0.058, "frame" }, { 0.42, 0.868, 0.16, 0.02, "cast" },
      { 0.378, 0.565, 0.245, 0.21, "group" },
    },
  },
  {
    key = "topleft", name = "Top left", preset = true,
    text = "Player and target in the top left corner, as in the game's own layout, with the party under them. Three bars stacked at the bottom.",
    spots = {
      player = { "TOPLEFT", 24, -24 }, target = { "TOPLEFT", 266, -24 }, cast = { "BOTTOM", -130, 170 },
      raid = { "TOPLEFT", 24, -124 },
    },
    bars = {
      bar2 = { on = true, perRow = 12 },
      bar3 = { on = true, perRow = 12 },
    },
    draw = {
      { 0.015, 0.027, 0.144, 0.058, "frame" }, { 0.166, 0.027, 0.144, 0.058, "frame" }, { 0.42, 0.74, 0.16, 0.025, "cast" },
      { 0.015, 0.138, 0.045, 0.21, "group" },
      { 0.36, 0.79, 0.28, 0.035, "bars" },
    },
  },
}

-- The frames a layout places, and the saved keys each one's spot lives in.
local FRAMES = { "player", "target", "tot", "pet", "focus", "cast", "raid" }
local function Keys(frame) return frame .. "Left", frame .. "Top", frame .. "Point" end

-- The action bars a preset arranges, and what it sets on each. A layout that doesn't name a
-- bar leaves it the way you had it before you tried any layout.
local BARS = { "bar2", "bar3" }
local BAR_KEYS = { "on", "perRow", "point", "left", "top" }

local function Bars()
  local B = ns.ActionBars
  if B and B.started and B.frames then return B end
end

local function BarShot(B)
  local shot = {}
  for _, bar in ipairs(BARS) do
    local c, t = B:Cfg(bar), {}
    for _, k in ipairs(BAR_KEYS) do t[k] = c[k] end
    shot[bar] = t
  end
  return shot
end

local function BarWrite(B, shot)
  for _, bar in ipairs(BARS) do
    local c, t = B:Cfg(bar), shot[bar]
    if t then
      for _, k in ipairs(BAR_KEYS) do c[k] = t[k] end
    end
    local f = B.frames[bar]
    if f then f.cfg = c end -- the bar reads its own copy of the table: keep it the saved one
  end
  B:ApplyAll()
end

-- The presets, in the order the Home page shows them.
function Su:Presets()
  local list = {}
  for _, l in ipairs(self.LAYOUTS) do
    if l.preset then list[#list + 1] = l end
  end
  return list
end

function Su:Layout(key)
  for _, l in ipairs(self.LAYOUTS) do
    if l.key == key then return l end
  end
end

-- Puts every frame where its saved spot (or its default) says. Out of combat only.
function Su:PlaceAll()
  FUI:PlaceAll()
  local R = ns.Raid
  if R and R.enabled and R.holder and not InCombatLockdown() then pcall(R.PlaceHolder, R) end
end

-- Uses a layout. Where every frame was is kept for Undo. False in combat, or for no such layout.
function Su:Apply(key)
  local l = self:Layout(key)
  if not l or InCombatLockdown() then return false end
  local db = ns.db
  local undo = {}
  for _, frame in ipairs(FRAMES) do
    local xk, yk, pk = Keys(frame)
    undo[frame] = { db[xk], db[yk], db[pk] }
    local spot = l.spots[frame]
    if spot then
      db[pk], db[xk], db[yk] = spot[1], spot[2], spot[3]
    else
      db[xk], db[yk], db[pk] = nil, nil, nil
    end
  end
  -- Kept from the first layout you try, not the last: Undo goes back to your own layout
  -- however many you look at.
  if type(db.setupUndo) ~= "table" then db.setupUndo = undo end
  local B = Bars()
  if B then
    -- your own bars, from before the first layout (an Undo kept by an older version has none)
    if type(db.setupUndo.bars) ~= "table" then db.setupUndo.bars = BarShot(B) end
    local want = {}
    for _, bar in ipairs(BARS) do
      want[bar] = l.bars and l.bars[bar] or db.setupUndo.bars[bar]
    end
    BarWrite(B, want)
  end
  db.setupDone = true
  db.setupUsed = l.key
  self:PlaceAll()
  return true
end

-- Every frame back where it was before you tried any layout.
function Su:Undo()
  local db = ns.db
  local undo = db.setupUndo
  if type(undo) ~= "table" or InCombatLockdown() then return false end
  for _, frame in ipairs(FRAMES) do
    local xk, yk, pk = Keys(frame)
    local was = undo[frame] or {}
    db[xk], db[yk], db[pk] = was[1], was[2], was[3]
  end
  local B = Bars()
  if B and type(undo.bars) == "table" then BarWrite(B, undo.bars) end
  db.setupUndo = nil
  db.setupUsed = nil
  self:PlaceAll()
  return true
end

------------------------------------------------------------------------
-- The window
------------------------------------------------------------------------

local KIND = {
  frame = { A[1], A[2], A[3], 0.75 }, cast = { 1, 1, 1, 0.5 }, group = { 0.44, 0.83, 0.6, 0.7 },
  bars = { 1, 1, 1, 0.22 }, map = { 1, 1, 1, 0.22 },
}

local function Thumb(parent, layout, THUMB_W, THUMB_H)
  THUMB_W, THUMB_H = THUMB_W or 180, THUMB_H or 112
  local t = CreateFrame("Frame", nil, parent)
  t:SetSize(THUMB_W, THUMB_H)
  local fill = S.Tex(t, "BACKGROUND")
  fill:SetAllPoints()
  S.Round(fill, S.UI.r.thumb)
  S.Paint(fill, 0.17, 0.2, 0.2, 1)
  S.ColorEdges(S.RoundEdges(t, "BORDER", nil, t, S.UI.r.thumb), S.UI.line[1], S.UI.line[2], S.UI.line[3], 1)
  local boxes = { { 0.36, 0.89, 0.28, 0.035, "bars" }, { 0.86, 0.05, 0.11, 0.2, "map" } }
  if not layout.oneBar then boxes[#boxes + 1] = { 0.36, 0.84, 0.28, 0.035, "bars" } end
  for _, b in ipairs(layout.draw) do boxes[#boxes + 1] = b end
  t.boxes = {}
  for i, b in ipairs(boxes) do
    local tex = S.Tex(t, "ARTWORK")
    local c = KIND[b[5]] or KIND.frame
    tex:SetColorTexture(c[1], c[2], c[3], c[4])
    tex:SetSize(math.max(2, b[3] * THUMB_W), math.max(2, b[4] * THUMB_H))
    tex:SetPoint("TOPLEFT", t, "TOPLEFT", b[1] * THUMB_W, -(b[2] * THUMB_H))
    t.boxes[i] = tex
  end
  return t
end
Su.Thumb = Thumb

function Su:Build()
  if self.frame then return end
  local f = CreateFrame("Frame", "VoltUISetup", UIParent)
  f:SetFrameStrata("DIALOG")
  f:SetToplevel(true)
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function() f:StartMoving() end)
  f:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
  f:SetSize(WIDTH, 360)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
  f:Hide()
  S.ThemePanel(f, 0.97)
  S.TitleBar(f, "Starting layouts", 30)
  local x = S.UIButton(f, "x", 22, function() Su:Close() end, "Close")
  x:SetPoint("TOPRIGHT", -4, -4)
  f.intro = S.UIText(f, nil, "LEFT", nil, 12)
  f.intro:SetPoint("TOPLEFT", 14, -40)
  f.intro:SetPoint("RIGHT", -14, 0)
  f.intro:SetTextColor(S.UI.sub[1], S.UI.sub[2], S.UI.sub[3])
  f.intro:SetWordWrap(true)
  f.intro:SetText("Pick where your frames start, or keep what you have. Only where frames sit changes, and for the three presets how action bars 2 and 3 are laid out. Undo puts everything back where it was.")
  f.cards = {}
  for i, l in ipairs(self.LAYOUTS) do
    local c = CreateFrame("Frame", nil, f)
    c:SetSize(CARD_W, 240)
    c:SetPoint("TOPLEFT", f, "TOPLEFT", 14 + (i - 1) * (CARD_W + 12), -76)
    local fill = S.Tex(c, "BACKGROUND", -5)
    fill:SetAllPoints()
    S.Round(fill, S.UI.r.card)
    S.Paint(fill, S.UI.card[1], S.UI.card[2], S.UI.card[3], 1)
    S.ColorEdges(S.RoundEdges(c, "BACKGROUND", -4, c, S.UI.r.card), S.UI.line[1], S.UI.line[2], S.UI.line[3], 1)
    c.thumb = Thumb(c, l)
    c.thumb:SetPoint("TOP", c, "TOP", 0, -8)
    c.name = S.UIText(c, nil, "LEFT", nil, 14)
    c.name:SetPoint("TOPLEFT", 9, -(THUMB_H + 14))
    c.name:SetText(l.name)
    c.name:SetTextColor(S.UI.text[1], S.UI.text[2], S.UI.text[3])
    c.text = S.UIText(c, nil, "LEFT", nil, 11)
    c.text:SetPoint("TOPLEFT", 9, -(THUMB_H + 32))
    c.text:SetWidth(CARD_W - 18)
    c.text:SetWordWrap(true)
    c.text:SetText(l.text)
    c.text:SetTextColor(S.UI.sub[1], S.UI.sub[2], S.UI.sub[3])
    c.use = S.PillButton(c, "Use this", 84, function() Su:Pick(l.key) end, false)
    c.use:SetPoint("BOTTOMRIGHT", -8, 8)
    c.layout = l
    f.cards[i] = c
  end
  f.note = S.UIText(f, nil, "LEFT", nil, 12)
  f.note:SetPoint("BOTTOMLEFT", 14, 16)
  f.note:SetTextColor(S.UI.text[1], S.UI.text[2], S.UI.text[3])
  f.undo = S.PillButton(f, "Undo", 70, function() Su:PickUndo() end, false, "Every frame back where it was before you tried a layout")
  f.undo:SetPoint("BOTTOMRIGHT", -150, 10)
  f.keep = S.PillButton(f, "Keep what I have", 130, function() Su:Close() end, true)
  f.keep:SetPoint("BOTTOMRIGHT", -12, 10)
  table.insert(UISpecialFrames, "VoltUISetup")
  f:SetScript("OnHide", function() ns.db.setupDone = true end)
  self.frame = f
end

function Su:Paint(text)
  local f = self.frame
  if not f then return end
  f.note:SetText(text or "")
  f.undo:SetShown(type(ns.db.setupUndo) == "table")
  f.keep.text:SetText(type(ns.db.setupUndo) == "table" and "Done" or "Keep what I have")
end

function Su:Pick(key)
  if InCombatLockdown() then return self:Paint("Frames can't move in combat. Try again after the fight.") end
  local l = self:Layout(key)
  if self:Apply(key) then self:Paint(("Using %s. Move anything you like with Move frames."):format(l.name)) end
end

function Su:PickUndo()
  if InCombatLockdown() then return self:Paint("Frames can't move in combat. Try again after the fight.") end
  if self:Undo() then self:Paint("Every frame is back where it was.") end
end

function Su:Open()
  self:Build()
  self:Paint("")
  self.frame:Show()
end

function Su:Close()
  if self.frame then self.frame:Hide() end
  ns.db.setupDone = true
end

-- Once, on a brand-new install: a moment after you first log in.
function Su:FirstRun()
  if not ns.freshInstall or ns.db.setupDone then return end
  local function open()
    if ns.db.setupDone then return end
    if InCombatLockdown() then
      -- Logged in to a fight: it opens when that ends. Next session wouldn't count as new.
      local wait = CreateFrame("Frame")
      wait:RegisterEvent("PLAYER_REGEN_ENABLED")
      wait:SetScript("OnEvent", function(self)
        self:UnregisterAllEvents()
        if not ns.db.setupDone then Su:Open() end
      end)
      return
    end
    Su:Open()
  end
  if C_Timer and C_Timer.After then C_Timer.After(3, open) else open() end
end
