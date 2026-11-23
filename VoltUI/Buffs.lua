-- VoltUI · Buffs and debuffs
-- The game's own buff and debuff frames, in VoltUI's look and where VoltUI puts them: square
-- icons with a thin border (violet for weapon enchants, the debuff's type colour or red for
-- debuffs), VoltUI's font on the time and the stack count, your debuffs under your buffs. The
-- whole block moves with Move frames. (A part since 1.48.0, off until you switch it on.)
--
-- Until 1.98.0 VoltUI drew buttons of its own here and read your auras to fill them. On this
-- client that can't work in a fight: every aura read from an add-on is refused there
-- ("Auras cannot be accessed when secret while tainted", for the list, an aura by index, by
-- id, its slots and its time alike: VoltUIDB.auraProbe, 2026-11-19), so the panel froze until
-- the fight ended. The game's own frames are filled in by the game's own code, which may
-- read auras at any time, so they keep up. VoltUI only changes how they're drawn:
--  * Nothing is stored on the game's frames; what VoltUI makes is kept in tables here.
--  * Only each frame's own methods are hooked, after they run (hooksecurefunc). None is
--    replaced or called, and no field the game reads is set.
--  * The game's border art is faded with SetAlpha(0), never moved or replaced.
--  * The frames are placed and scaled from outside (SetPoint, SetScale), and put back
--    whenever the game places them again. They aren't protected, so that works in a fight.
-- What the game decides stays the game's: which buffs show, how many in a row and which way
-- they grow (its Edit Mode), the time's wording, right-click to cancel, the flash under
-- half a minute.

local _, ns = ...
local FUI, S = ns.FUI, ns.Style

local B = { key = "buffs", name = "Buffs and debuffs", skins = {} }
local ENCHANT_EDGE = { 0.62, 0.45, 0.95 } -- weapon enchants: a violet edge, apart from buffs
local DEBUFF_EDGE = { 0.8, 0.2, 0.2 }
ns.Buffs = B

local floor, max, min, ceil = math.floor, math.max, math.min, math.ceil
local Safe = S.Safe

-- The game's own sizes for an aura button (BuffFrame.lua): 30 wide, 40 tall with its time.
local GAME_W, GAME_H, GAME_PAD, GAME_STRIDE = 30, 40, 5, 8
local GAP = 6 -- between the buffs and the debuffs
-- The buff frame keeps a small arrow right of its icons; the game sets the debuffs in by
-- this much so both rows end at the same place (BuffFrame.xml).
local ARROW = 13

local function TimeSize() return max(6, tonumber(ns.db.buffTimeSize) or 10) end
local function CountSize() return max(6, tonumber(ns.db.buffCountSize) or 11) end

-- "2h", "14m", "42"
function B.Left(seconds)
  -- Rounded so that it never reads "60m" or "60": 59.5 minutes is an hour, 59.5 seconds a minute.
  if seconds >= 3570 then return floor(seconds / 3600 + 0.5) .. "h" end
  if seconds >= 59.5 then return floor(seconds / 60 + 0.5) .. "m" end
  return tostring(max(0, floor(seconds + 0.5)))
end

function B:Frames() return _G.BuffFrame, _G.DebuffFrame end

------------------------------------------------------------------------
-- The look of one button
------------------------------------------------------------------------

-- VoltUI's fonts on a button's time and stack count. The game can set the time's font again
-- as it runs down, so this is also run after that.
function B:Fonts(btn)
  if self.fonting then return end
  self.fonting = true
  local d, c = btn.Duration, btn.Count
  if type(d) == "table" and d.SetFont then
    S.SetFont(d, TimeSize(), "OUTLINE", "buffs.time")
    if d.SetAlpha then d:SetAlpha(ns.db.buffTimers ~= false and 1 or 0) end
  end
  if type(c) == "table" and c.SetFont then S.SetFont(c, CountSize(), "OUTLINE", "buffs.count") end
  self.fonting = nil
end

-- What VoltUI keeps for a button of the game's, made the first time it's seen. Nothing for
-- the debuff frame's private aura anchors, which have no icon texture of their own.
function B:Skin(btn)
  local s = self.skins[btn]
  if s ~= nil then return s end
  if type(btn) ~= "table" or type(btn.Icon) ~= "table" or not btn.Icon.SetTexCoord then
    if type(btn) == "table" then self.skins[btn] = false end
    return false
  end
  s = { edges = S.Edges(btn, "OVERLAY", 6, btn.Icon, 0) }
  self.skins[btn] = s
  if btn.Update then hooksecurefunc(btn, "Update", function(b) B:Dress(b) end) end
  local d = btn.Duration
  if type(d) == "table" and d.SetFontObject then hooksecurefunc(d, "SetFontObject", function() B:Fonts(btn) end) end
  return s
end

-- After the game fills a button in: VoltUI's look on it.
function B:Dress(btn)
  local s = self:Skin(btn)
  if not s then return end
  btn.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  for _, key in ipairs({ "DebuffBorder", "TempEnchantBorder" }) do
    local t = btn[key]
    if type(t) == "table" and t.SetAlpha then t:SetAlpha(0) end
  end
  local kind = Safe(btn.auraType)
  local r, g, b, a = S.EDGE[1], S.EDGE[2], S.EDGE[3], 0.8
  if kind == "TempEnchant" then
    r, g, b, a = ENCHANT_EDGE[1], ENCHANT_EDGE[2], ENCHANT_EDGE[3], 1
  elseif kind == "Debuff" or kind == "DeadlyDebuff" then
    r, g, b, a = DEBUFF_EDGE[1], DEBUFF_EDGE[2], DEBUFF_EDGE[3], 1
    -- its type's colour, when the game's note of it can be read
    local info = btn.buttonInfo
    local dtype = type(info) == "table" and not S.IsSecret(info) and Safe(info.debuffType) or nil
    local c = type(dtype) == "string" and DebuffTypeColor and DebuffTypeColor[dtype]
    if c then r, g, b = c.r, c.g, c.b end
  end
  S.ColorEdges(s.edges, r, g, b, a)
  self:Fonts(btn)
end

function B:DressAll()
  for _, frame in ipairs({ self:Frames() }) do
    for _, btn in ipairs(type(frame) == "table" and frame.auraFrames or {}) do self:Dress(btn) end
  end
end

------------------------------------------------------------------------
-- Where the game's frames sit
------------------------------------------------------------------------

local function Num(v, default)
  v = Safe(v)
  return type(v) == "number" and v > 0 and v or default
end

-- How many rows of buffs are showing, from the game's own buttons (only looked at).
function B:Rows(bf)
  local n = 0
  for _, btn in ipairs(bf.auraFrames or {}) do
    if btn.IsShown and btn:IsShown() then n = n + 1 end
  end
  local box = bf.AuraContainer
  local stride = type(box) == "table" and Num(box.iconStride, GAME_STRIDE) or GAME_STRIDE
  return max(1, ceil(n / stride)), n, stride
end

-- The game's two frames onto VoltUI's holder: buffs at its top right at VoltUI's size, debuffs
-- under the rows of buffs showing. Run again whenever the game places them or the buffs
-- change. The holder is sized to match, for its overlay while frames are being moved.
function B:Arrange()
  local h = self.holder
  local bf, df = self:Frames()
  if not h or type(bf) ~= "table" or self.placing then return end
  self.placing = true
  local db = ns.db
  local scale = max(0.5, min(2, tonumber(db.buffScale) or 1))
  local box = bf.AuraContainer
  local pad = type(box) == "table" and Num(box.iconPadding, GAME_PAD) or GAME_PAD
  local icon = type(box) == "table" and Num(box.iconScale, 1) or 1
  -- (1.101.1) each frame has an icon size of its own in the game's Edit Mode, and the
  -- debuffs' can differ from the buffs': taken out, so VoltUI's sizes are the sizes drawn
  local dbox = type(df) == "table" and df.AuraContainer
  local dicon = type(dbox) == "table" and Num(dbox.iconScale, 1) or 1
  local bs = (tonumber(db.buffSize) or 30) / GAME_W * scale / icon
  local ds = (tonumber(db.debuffSize) or 30) / GAME_W * scale / dicon
  local rows, _, stride = self:Rows(bf)
  local function put(frame, s, y, x)
    if type(frame) ~= "table" or not frame.SetPoint then return end
    -- the game's frames aren't protected; if one ever is, it can't be moved in a fight
    if frame.IsProtected and frame:IsProtected() and InCombatLockdown and InCombatLockdown() then return end
    if not self.hooked[frame] then
      self.hooked[frame] = true
      hooksecurefunc(frame, "SetPoint", function() B:Arrange() end)
    end
    frame:SetScale(s)
    frame:ClearAllPoints()
    frame:SetPoint("TOPRIGHT", h, "TOPRIGHT", (x or 0) / s, y / s) -- offsets are in the frame's own scale
  end
  self.hooked = self.hooked or {}
  local rowH = (GAME_H + pad) * icon * bs -- a row of buffs, in the screen's units
  put(bf, bs, 0)
  put(df, ds, -(rows * rowH + GAP * scale), -ARROW * bs) -- in line with the buffs' icons, clear of the arrow
  -- the holder covers a full row of buffs and the debuffs' row
  h:SetSize(stride * (GAME_W + pad) * icon * bs / scale, (rows * rowH + GAP * scale + GAME_H * dicon * ds) / scale)
  self.placing = nil
end

function B:Update()
  if not self.holder then return end
  self:DressAll()
  self:Arrange()
  local bf = self:Frames()
  local _, n = 1, 0
  if type(bf) == "table" then _, n = self:Rows(bf) end
  self.empty:SetShown(FUI.unlocked and n == 0 and true or false)
end

function B:Place()
  local f = self.holder
  f:SetScale(max(0.5, min(2, tonumber(ns.db.buffScale) or 1)))
  if not S.PlaceSpot(f, ns.db, "buffLeft", "buffTop", "buffPoint") then
    f:ClearAllPoints()
    B.DefaultSpot(f)
  end
  self:Arrange()
end

-- Where the block sits until you move it: left of the minimap, wherever that is and whatever
-- its size; or where the game's map would be, with VoltUI's minimap off.
function B.DefaultSpot(f)
  local hold = ns.Minimap and ns.Minimap.enabled and ns.Minimap.holder
  if hold then
    f:SetPoint("TOPRIGHT", hold, "TOPLEFT", -10, 0)
  else
    f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -236, -43)
  end
end

function B:Reset()
  S.ClearSpot(ns.db, "buffLeft", "buffTop", "buffPoint")
  ns.db.buffSize, ns.db.debuffSize, ns.db.buffScale, ns.db.buffTimers = 30, 30, 1, true
  ns.db.buffTimeSize, ns.db.buffCountSize = 10, 11
  self:Place()
  self:Update()
end

function B:SetUnlocked(on)
  if not self.holder then return end
  self.holder.mover:SetShown(on and true or false)
  self:Update()
end

function B:Refresh()
  if self.holder then self:Update() end
end

function B:Enable()
  self.enabled = true
  local f = CreateFrame("Frame", "VoltUIBuffs", UIParent)
  f:SetFrameStrata("LOW")
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:SetSize(327, 90)
  self.holder = f
  f.mover = S.Mover(f, "Buffs", function(fr)
    S.KeepSpot(fr, ns.db, "buffLeft", "buffTop", "buffPoint")
  end, { spot = function() return ns.db, "buffLeft", "buffTop", "buffPoint" end,
         default = function(fr) B.DefaultSpot(fr) end })
  f.mover:SetScript("OnMouseUp", function()
    if S.MoverDragged(f.mover) then return end -- that was the end of a drag, not a click
    ns.EditMode:Open("buffs")
  end)
  self.empty = S.Text(f, nil, "RIGHT", "OVERLAY", 11)
  self.empty:SetPoint("TOPRIGHT", -4, -4)
  self.empty:SetText("Your buffs show here")
  self.empty:SetTextColor(S.SUB[1], S.SUB[2], S.SUB[3])
  self.empty:Hide()

  local bf, df = self:Frames()
  if type(bf) ~= "table" then
    FUI:Print("Buffs: the game's buff frame isn't there, so there's nothing for VoltUI to restyle.")
    self:Place()
    return
  end
  -- After the game fills its buttons in (a buff came or went): the rows may have changed.
  for _, frame in ipairs({ bf, df }) do
    if type(frame) == "table" and frame.UpdateAuraButtons then
      hooksecurefunc(frame, "UpdateAuraButtons", function() B:Update() end)
    end
    if type(frame) == "table" and frame.UpdateGridLayout then
      hooksecurefunc(frame, "UpdateGridLayout", function() B:Update() end) -- it sizes and anchors each icon again
    end
  end
  self:Place()
  self:Update()
  -- once more when the world is in: the game's Edit Mode places its frames then
  local ev = CreateFrame("Frame")
  ev:RegisterEvent("PLAYER_ENTERING_WORLD")
  ev:SetScript("OnEvent", function() B:Place(); B:Update() end)
end

FUI:Register(B)
