-- VoltUI · Unit frame extras (1.95.0, 1.95.1)
-- Four additions to the unit frames (UnitFrames.lua), for things a class needs that the
-- frames didn't show:
--
--   Mana while shapeshifted   a thin mana bar under your frame while your power bar shows
--                             something else (a Druid in bear or cat form).
--   Pet experience            a thin line under the pet frame, for a hunter's pet that's
--                             below your level.
--   Regen tick                a spark crossing your power bar in time with the 2 second
--                             energy or mana tick, and a pale fill for the 5 seconds after
--                             spending mana. An experiment, off to begin with.
--   Extra texts               two texts of your choice above or below your frame: a soul
--                             shard, ammo or reagent count, combo points, or plain things
--                             like health, mana, name and level. The pet frame has one of
--                             its own (1.95.1), showing a hunter pet's mood to begin with.
--
-- Your frame and the pet frame are secure, so nothing here changes their size: the bars and
-- texts hang outside them, on plain child frames, and can come and go in a fight.
--
-- Numbers can be secret on this client. They go straight to the widgets; anything worked
-- out here (a tick seen, a percent) only happens when Safe() let the number through.

local _, ns = ...
local FUI, S = ns.FUI, ns.Style
local U = ns.UnitFrames

local X = { t = {} }
ns.FrameExtras = X

local Safe = S.Safe
local floor, max = math.floor, math.max

local ALT_H, XP_H, PIP_H = 5, 3, 6
local MANA = 0 -- Enum.PowerType.Mana
local TICK, RULE = 2, 5
local EXTRAS = { player = 2, pet = 1 } -- how many texts each frame has
X.EXTRAS = EXTRAS

------------------------------------------------------------------------
-- Settings
------------------------------------------------------------------------

do
  local D = U.DEFAULTS
  D.player.altMana = true
  D.player.tick = false
  D.pet.petXP = true
  for key, count in pairs(EXTRAS) do
    for i = 1, count do
      local k = "extra" .. i
      D[key][k] = "off"
      D[key][k .. "At"] = i == 1 and "bl" or "br"
      D[key][k .. "Size"] = 11
      D[key][k .. "Label"] = key == "player"
      D[key][k .. "X"], D[key][k .. "Y"] = 0, 0
    end
  end
  D.pet.extra1 = "happiness" -- blank for any pet that isn't a hunter's
end

X.SPOTS = {
  { key = "bl", name = "Below, left" }, { key = "br", name = "Below, right" },
  { key = "tl", name = "Above, left" }, { key = "tr", name = "Above, right" },
}
local SPOT = {
  bl = { key = "bl" }, br = { key = "br", right = true },
  tl = { key = "tl", above = true }, tr = { key = "tr", above = true, right = true },
}

------------------------------------------------------------------------
-- Mana while shapeshifted
------------------------------------------------------------------------

-- Wanted while the power bar shows something other than mana and you have mana at all.
function X:AltWanted()
  if not U:Cfg("player").altMana then return false end
  local _, token = UnitPowerType("player")
  token = Safe(token)
  if token == nil or token == "MANA" then return false end
  local most = Safe(UnitPowerMax("player", MANA))
  if type(most) == "number" then return most > 0 end
  local _, class = UnitClass("player")
  return Safe(class) == "DRUID"
end

-- How far below the frame things start: under the border, or on the plate.
local function Drop(c)
  local _, down = U:Reach(c)
  return c.border == "plate" and 0 or down
end

function X:PlaceAlt()
  local bar, f = self.alt, U.frames.player
  if not bar or not f then return end
  local y = -1 - Drop(U:Cfg("player"))
  bar:ClearAllPoints()
  bar:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 0, y)
  bar:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", 0, y)
  bar:SetHeight(ALT_H)
end

-- What hangs under the frame moves when the mana bar comes or goes.
function X:Reflow()
  local f = U.frames.player
  if not f then return end
  local c = U:Cfg("player")
  self:PlaceAlt()
  U:PipsOutside(f, c)
  U:FitPlate(f)
  self:PlaceExtras(f)
end

function X:UpdateAlt()
  local f = U.frames.player
  if not f then return end
  local want = self:AltWanted()
  local bar = self.alt
  if want and not bar then
    bar = S.Bar(f)
    bar.bg:SetColorTexture(S.BG[1], S.BG[2], S.BG[3], 0.9)
    S.BarColor(bar, 0.25, 0.5, 0.95)
    bar:Hide()
    self.alt = bar
    self:PlaceAlt()
  end
  if not bar then return end
  if want then
    bar:SetMinMaxValues(0, UnitPowerMax("player", MANA))
    bar:SetValue(UnitPower("player", MANA))
  end
  if (bar.kOn or false) ~= want then
    bar.kOn = want
    bar:SetShown(want)
    U.below = want and (ALT_H + 1) or 0
    self:Reflow()
  end
end

------------------------------------------------------------------------
-- Pet experience
------------------------------------------------------------------------

function X:PlaceXP()
  local bar, f = self.xp, U.frames.pet
  if not bar or not f then return end
  local y = -1 - Drop(U:Cfg("pet"))
  bar:ClearAllPoints()
  bar:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 0, y)
  bar:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", 0, y)
  bar:SetHeight(XP_H)
end

-- Shown for a hunter's pet that still has levels to gain on you.
function X:UpdateXP()
  local f = U.frames.pet
  if not f then return end
  local cur, most
  if U:Cfg("pet").petXP and not U.unlocked and GetPetExperience then
    local ok, a, b = pcall(GetPetExperience)
    if ok then cur, most = Safe(a), Safe(b) end
  end
  local want = type(cur) == "number" and type(most) == "number" and most > 0
  if want and HasPetUI then
    local _, hunterPet = HasPetUI()
    want = hunterPet and true or false
  end
  if want then
    local pet, me = Safe(UnitLevel("pet")), Safe(UnitLevel("player"))
    if type(pet) == "number" and type(me) == "number" and pet >= me then want = false end
  end
  local bar = self.xp
  if want and not bar then
    bar = S.Bar(f)
    bar.bg:SetColorTexture(S.BG[1], S.BG[2], S.BG[3], 0.9)
    S.BarColor(bar, 0.6, 0.37, 0.84)
    self.xp = bar
    self:PlaceXP()
  end
  if not bar then return end
  if want then
    bar:SetMinMaxValues(0, most)
    bar:SetValue(cur)
    self.xpNow, self.xpMost = cur, most
  end
  bar:SetShown(want)
  if (bar.kOn or false) ~= want then
    bar.kOn = want
    self:PlaceExtras(f)
  end
end

------------------------------------------------------------------------
-- Regen tick (an experiment)
------------------------------------------------------------------------
-- Energy and mana come back in a tick every 2 seconds. A gain seen on the power bar marks
-- a tick, and the spark runs from there, reaching the right edge as the next one lands.
-- For 5 seconds after spending mana, regeneration is cut: a pale fill runs across instead.
-- In a fight the game may keep the numbers secret. Then no tick is seen, and the spark
-- keeps running from the last one it saw; a mana spend is taken from your spell casts.

-- Called whenever your power changes.
function X:OnPower()
  local t = self.t
  local kind, token = UnitPowerType("player")
  token = Safe(token)
  if token ~= t.token then t.token, t.prev = token, nil end
  local cur = Safe(UnitPower("player", kind))
  local now = GetTime()
  if type(cur) ~= "number" then
    t.prev, t.full = nil, nil
    return
  end
  if t.prev then
    if cur > t.prev then
      t.last = now
    elseif cur < t.prev and token == "MANA" then
      t.spend = now
    end
  end
  t.prev = cur
  local most = Safe(UnitPowerMax("player", kind))
  if type(most) == "number" then t.full = cur >= most else t.full = nil end
end

-- A cast that went off while mana can't be read counts as a spend.
function X:OnCast()
  local t = self.t
  if t.token == "MANA" and t.prev == nil then t.spend = GetTime() end
end

function X:PaintTick()
  local f, spark, rule = U.frames.player, self.spark, self.rule
  if not f or not spark then return end
  local t, now = self.t, GetTime()
  t.start = t.start or now
  local frac, ruled
  if t.token == "ENERGY" then
    frac = ((now - (t.last or t.start)) % TICK) / TICK
  elseif t.token == "MANA" then
    if t.spend and now - t.spend < RULE then
      frac, ruled = (now - t.spend) / RULE, true
    elseif t.full == false or (t.full == nil and t.last) then
      frac = ((now - (t.last or t.start)) % TICK) / TICK
    end
  end
  if not frac then
    spark:Hide()
    rule:Hide()
    return
  end
  local w = self.pwW or 1
  spark:ClearAllPoints()
  spark:SetPoint("LEFT", f.pw, "LEFT", frac * max(0, w - 2), 0)
  spark:Show()
  if ruled then
    rule:SetWidth(max(1, frac * w))
    rule:Show()
  else
    rule:Hide()
  end
  self.frac, self.ruled = frac, ruled or false
end

function X:ApplyTick()
  local f = U.frames.player
  if not f then return end
  local c = U:Cfg("player")
  local on = c.tick and c.power and true or false
  if on and not self.spark then
    self.rule = S.Tex(f.pw, "OVERLAY", 4)
    self.rule:SetColorTexture(1, 1, 1, 0.22)
    self.rule:SetPoint("TOPLEFT", f.pw, "TOPLEFT", 0, 0)
    self.rule:SetPoint("BOTTOMLEFT", f.pw, "BOTTOMLEFT", 0, 0)
    self.rule:Hide()
    self.spark = S.Tex(f.pw, "OVERLAY", 5)
    self.spark:SetColorTexture(1, 1, 1, 0.9)
    self.spark:Hide()
  end
  if self.spark then
    self.spark:SetSize(2, c.pwHeight)
    if not on then
      self.spark:Hide()
      self.rule:Hide()
    end
  end
  if on then self:OnPower() end
  self.driver = self.driver or CreateFrame("Frame")
  self.driver:SetScript("OnUpdate", on and function() X:PaintTick() end or nil)
  self.ticking = on
end

------------------------------------------------------------------------
-- Extra texts: what they can show
------------------------------------------------------------------------

local LABEL = "|cffa8adb8%s|r "
local RED, AMBER, WHITE = "|cffe5645f", "|cfff0b24a", "|cffffffff"

local function Put(fs, label, fmt, ...)
  if label then fmt = LABEL:format(label) .. fmt end
  fs:SetFormattedText(fmt, ...)
end

local function NumFn(c) return c.short and S.ShortNum or S.Num end

local function ItemCount(id)
  local fn = (C_Item and C_Item.GetItemCount) or GetItemCount
  if not fn then return 0 end
  local ok, n = pcall(fn, id)
  n = ok and Safe(n)
  return type(n) == "number" and n or 0
end

local function PowerPercent(u, kind)
  local cur, most = Safe(UnitPower(u, kind)), Safe(UnitPowerMax(u, kind))
  if cur and most then return most > 0 and floor(cur / most * 100 + 0.5) or 0 end
  if UnitPowerPercent and CurveConstants and CurveConstants.ScaleTo100 then
    local ok, p = pcall(UnitPowerPercent, u, kind, false, CurveConstants.ScaleTo100)
    if ok and p ~= nil then
      if C_StringUtil and C_StringUtil.RoundToNearestString then p = C_StringUtil.RoundToNearestString(p) end
      return p
    end
  end
  return "?"
end

-- Your pet's mood: 1 unhappy, 2 content, 3 happy, with its damage percent and whether it's
-- gaining or losing loyalty. Nothing without a hunter's pet.
function X.Happiness()
  if HasPetUI then
    local has, hunterPet = HasPetUI()
    if not has or not hunterPet then return end
  end
  local fn = (C_PetInfo and C_PetInfo.GetPetHappiness) or GetPetHappiness
  if not fn then return end
  local ok, mood, damage, loyalty = pcall(fn)
  if ok then return Safe(mood), Safe(damage), Safe(loyalty) end
end
X.MOODS = {
  { name = "Unhappy", code = RED, rgb = { 0.9, 0.39, 0.37 } },
  { name = "Content", code = AMBER, rgb = { 0.94, 0.7, 0.29 } },
  { name = "Happy", code = "|cff6fcf7a", rgb = { 0.44, 0.81, 0.48 } },
}

-- Arrows or bullets in the ammo slot; nil where there's no such slot or nothing in it.
local function Ammo()
  local slot = INVSLOT_AMMO or 0
  if not (GetInventoryItemID and GetInventoryItemCount) then return end
  local ok, id = pcall(GetInventoryItemID, "player", slot)
  if not ok or not Safe(id) then return end
  local ok2, n = pcall(GetInventoryItemCount, "player", slot)
  n = ok2 and Safe(n)
  return type(n) == "number" and n or nil
end

local function Count(label, id, classes)
  return {
    key = "item:" .. id, name = label .. " (in bags)", label = label, classes = classes,
    paint = function(fs, lab)
      local n = ItemCount(id)
      Put(fs, lab, "%s%d|r", n == 0 and RED or WHITE, n)
    end,
  }
end

local function Only(...)
  local set = {}
  for _, class in ipairs({ ... }) do set[class] = true end
  return set
end

-- Everything a text can show, in the list's order. `classes`: only offered to those.
-- `on`: which frame's list it's in, "pet" or "both"; without it, yours only.
-- paint(text, label, settings, unit, preview).
-- The item ids are Classic's; whether Forever keeps each item is unverified.
X.SOURCES = {
  { key = "off", name = "Off" },
  -- your class
  { key = "combo", name = "Combo points", label = "Combo", classes = Only("ROGUE", "DRUID"),
    paint = function(fs, lab)
      local n = 0
      if GetComboPoints then n = GetComboPoints("player", "target") end
      Put(fs, lab, "%s", n)
    end },
  Count("Soul Shards", 6265, Only("WARLOCK")),
  { key = "ammo", name = "Ammo", label = "Ammo", classes = Only("HUNTER", "WARRIOR", "ROGUE"),
    paint = function(fs, lab)
      local n = Ammo()
      if not n then return Put(fs, lab, "%snone|r", RED) end
      Put(fs, lab, "%s%d|r", n < 50 and RED or n < 200 and AMBER or WHITE, n)
    end },
  { key = "happiness", name = "Pet happiness", label = "Mood", classes = Only("HUNTER"), on = "pet",
    paint = function(fs, lab, _, _, preview)
      local mood = X.MOODS[X.Happiness() or (preview and 3) or 0]
      if not mood then return fs:SetText("") end
      Put(fs, lab, "%s%s|r", mood.code, mood.name)
    end },
  { key = "petxp", name = "Pet experience", label = "XP", classes = Only("HUNTER"), on = "pet",
    paint = function(fs, lab)
      local cur, most
      if GetPetExperience then cur, most = GetPetExperience() end
      cur, most = Safe(cur), Safe(most)
      if type(cur) ~= "number" or type(most) ~= "number" or most <= 0 then return fs:SetText("") end
      Put(fs, lab, "%d%%", floor(cur / most * 100 + 0.5))
    end },
  Count("Ankh", 17030, Only("SHAMAN")),
  Count("Arcane Powder", 17020, Only("MAGE")),
  Count("Rune of Teleportation", 17031, Only("MAGE")),
  Count("Rune of Portals", 17032, Only("MAGE")),
  Count("Holy Candle", 17028, Only("PRIEST")),
  Count("Sacred Candle", 17029, Only("PRIEST")),
  Count("Symbol of Kings", 21177, Only("PALADIN")),
  Count("Symbol of Divinity", 17033, Only("PALADIN")),
  Count("Flash Powder", 5140, Only("ROGUE")),
  Count("Blinding Powder", 5530, Only("ROGUE")),
  Count("Wild Thornroot", 17026, Only("DRUID")),
  Count("Ironwood Seed", 17038, Only("DRUID")),
  -- everyone
  { key = "mana", name = "Mana", label = "Mana",
    classes = Only("PALADIN", "HUNTER", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID"),
    paint = function(fs, lab, c)
      local num = NumFn(c)
      Put(fs, lab, "%s / %s", num(UnitPower("player", MANA)), num(UnitPowerMax("player", MANA)))
    end },
  { key = "manaPct", name = "Mana percent", label = "Mana",
    classes = Only("PALADIN", "HUNTER", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID"),
    paint = function(fs, lab) Put(fs, lab, "%s%%", PowerPercent("player", MANA)) end },
  { key = "health", name = "Health", label = "Health", on = "both",
    paint = function(fs, lab, c, u)
      local num = NumFn(c)
      Put(fs, lab, "%s / %s", num(UnitHealth(u)), num(UnitHealthMax(u)))
    end },
  { key = "healthPct", name = "Health percent", label = "Health", on = "both",
    paint = function(fs, lab, _, u)
      Put(fs, lab, "%s%%", S.HealthPercent(u, UnitHealth(u), UnitHealthMax(u)))
    end },
  { key = "power", name = "Power (what the bar shows)", label = "Power", on = "both",
    paint = function(fs, lab, c, u)
      local num, kind = NumFn(c), UnitPowerType(u)
      Put(fs, lab, "%s / %s", num(UnitPower(u, kind)), num(UnitPowerMax(u, kind)))
    end },
  { key = "powerPct", name = "Power percent", label = "Power", on = "both",
    paint = function(fs, lab, _, u) Put(fs, lab, "%s%%", PowerPercent(u, (UnitPowerType(u)))) end },
  { key = "name", name = "Name", on = "both", paint = function(fs, _, _, u) fs:SetText((UnitName(u)) or "") end },
  { key = "level", name = "Level", label = "Level", on = "both",
    paint = function(fs, lab, _, u) Put(fs, lab, "%s", UnitLevel(u)) end },
  { key = "xp", name = "Experience percent", label = "XP",
    paint = function(fs, lab)
      local cur, most = UnitXP and Safe(UnitXP("player")), UnitXPMax and Safe(UnitXPMax("player"))
      if type(cur) ~= "number" or type(most) ~= "number" or most <= 0 then return fs:SetText("") end
      Put(fs, lab, "%d%%", floor(cur / most * 100 + 0.5))
    end },
}
X.byKey = {}
for _, src in ipairs(X.SOURCES) do X.byKey[src.key] = src end

-- The choices for your class on one frame ("player" unless told "pet"): Off, your class's
-- own, then the ones everyone has.
function X.SourceList(key)
  key = key == "pet" and "pet" or "player"
  local _, class = UnitClass("player")
  class = Safe(class) or false
  if not X.lists or X.listFor ~= class then X.lists, X.listFor = {}, class end
  if X.lists[key] then return X.lists[key] end
  local out = {}
  for _, src in ipairs(X.SOURCES) do
    local here = src.key == "off" or src.on == "both" or (src.on or "player") == key
    if here and (not src.classes or (class and src.classes[class])) then out[#out + 1] = src end
  end
  X.lists[key] = out
  return out
end

------------------------------------------------------------------------
-- Extra texts: on the frame
------------------------------------------------------------------------

-- Each text hangs off a corner of the frame, clear of the border and of what's already
-- there (the mana bar, combo points outside the frame, the pet's experience line). Two on
-- one corner stack outward.
function X:PlaceExtras(f)
  local count = f and EXTRAS[f.key]
  if not count then return end
  local c = U:Cfg(f.key)
  local up, down = U:Reach(c)
  local above, below = 3 + up, 3 + down
  if f.preview then
    -- nothing else hangs off a preview
  elseif f.key == "pet" then
    if self.xp and self.xp.kOn then below = below + XP_H + 1 end
  else
    below = below + (U.below or 0)
    local row = U.pips
    if row and row.kShown ~= false and f.kPipsOut then
      if f.kPipsOut == "top" then above = above + PIP_H + 2 else below = below + PIP_H + 2 end
    end
  end
  f.extras = f.extras or {}
  local used = {}
  for i = 1, count do
    local k = "extra" .. i
    local on = c[k] ~= nil and c[k] ~= "off"
    local fs = f.extras[i]
    if on and not fs then
      fs = S.Text(f.over, "GameFontHighlightSmall", "LEFT", "OVERLAY", 11, "OUTLINE", "frames.power")
      f.extras[i] = fs
    end
    if fs then
      fs:SetShown(on)
      if on then
        local at = SPOT[c[k .. "At"]] or SPOT.bl
        local size = max(c[k .. "Size"] or 11, 6)
        S.SetFont(fs, size, "OUTLINE", "frames.power")
        local stack = used[at.key] or 0
        used[at.key] = stack + size + 2
        local x, y = c[k .. "X"] or 0, c[k .. "Y"] or 0
        local inset = at.right and -2 or 2
        fs:ClearAllPoints()
        fs:SetJustifyH(at.right and "RIGHT" or "LEFT")
        if at.above then
          fs:SetPoint(at.right and "BOTTOMRIGHT" or "BOTTOMLEFT", f, at.right and "TOPRIGHT" or "TOPLEFT", inset + x, above + stack + y)
        else
          fs:SetPoint(at.right and "TOPRIGHT" or "TOPLEFT", f, at.right and "BOTTOMRIGHT" or "BOTTOMLEFT", inset + x, -below - stack + y)
        end
      end
    end
  end
end

-- (1.96.0) Each text is a part that can be picked in the settings preview.
for i = 1, 2 do
  local k = "extra" .. i
  U.PARTS[#U.PARTS + 1] = {
    key = k, name = "Extra text " .. i, only = i == 1 and { player = true, pet = true } or { player = true },
    region = function(f, c)
      local fs = f.extras and f.extras[i]
      if fs and c[k] ~= nil and c[k] ~= "off" then return fs, 2 end
    end,
  }
end

function X:PaintExtras(f)
  if not f or not f.extras then return end
  local c = U:Cfg(f.key)
  for i = 1, EXTRAS[f.key] or 0 do
    local fs, key = f.extras[i], c["extra" .. i]
    if fs and key and key ~= "off" then
      local src = X.byKey[key]
      local ok = src and src.paint
        and pcall(src.paint, fs, c["extra" .. i .. "Label"] and src.label or nil, c, f.key, f.preview and true or false)
      if not ok then fs:SetText("") end
    end
  end
end

function X:PaintAllExtras()
  for key in pairs(EXTRAS) do
    self:PaintExtras(U.frames[key])
    if U.previews then self:PaintExtras(U.previews[key]) end
  end
end

------------------------------------------------------------------------
-- Joining the unit frames
------------------------------------------------------------------------

function X:AfterLayout(f)
  if f.key == "player" then
    if not f.preview then
      local c = U:Cfg("player")
      local _, height = U:Rows(f, c)
      -- the power bar's width, from the settings: a size read back from the game can be stale
      self.pwW = max(1, c.width - (c.portrait ~= "off" and (height + 1) or 2))
      self:PlaceAlt()
      self:UpdateAlt()
      self:ApplyTick()
    end
    self:PlaceExtras(f)
    self:PaintExtras(f)
  elseif f.key == "pet" then
    if not f.preview then
      self:PlaceXP()
      self:UpdateXP()
    end
    self:PlaceExtras(f)
    self:PaintExtras(f)
  end
end

local Layout = U.Layout
function U:Layout(f)
  Layout(self, f)
  X:AfterLayout(f)
end

local Update = U.Update
function U:Update(f, light)
  Update(self, f, light)
  if f and EXTRAS[f.key] then X:PaintExtras(f) end
end

-- Combo points coming or going (a Druid) move a text that sits beyond them.
local UpdatePips = U.UpdatePips
function U:UpdatePips()
  UpdatePips(self)
  local row = self.pips
  local shown = row and row.kShown ~= false and true or false
  if X.pipsShown ~= shown then
    X.pipsShown = shown
    X:PlaceExtras(self.frames.player)
  end
end

local SetUnlocked = U.SetUnlocked
function U:SetUnlocked(on)
  SetUnlocked(self, on)
  X:UpdateXP()
end

local POWER_EVENTS = { UNIT_POWER_UPDATE = true, UNIT_POWER_FREQUENT = true, UNIT_MAXPOWER = true, UNIT_DISPLAYPOWER = true }
local QUIET = { UNIT_POWER_FREQUENT = true } -- too often to repaint the texts on

local function OnEvent(_, event, unit)
  if event:find("^UNIT_") and unit ~= "player" and unit ~= "pet" then return end
  if POWER_EVENTS[event] then
    if unit ~= "player" then return end
    X:UpdateAlt()
    if X.ticking then X:OnPower() end
  elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
    if unit == "player" and X.ticking then X:OnCast() end
    return
  elseif event == "UNIT_PET" or event == "UNIT_PET_EXPERIENCE" or event == "UNIT_LEVEL"
    or event == "PLAYER_LEVEL_UP" or event == "PLAYER_ENTERING_WORLD" then
    X:UpdateXP()
    if event == "PLAYER_ENTERING_WORLD" then X:UpdateAlt() end
  end
  if not QUIET[event] then X:PaintAllExtras() end
end

function X:Start()
  if self.started then return end
  self.started = true
  local ev = CreateFrame("Frame")
  for _, e in ipairs({
    "UNIT_POWER_UPDATE", "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER",
    "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_LEVEL", "UNIT_NAME_UPDATE", "UNIT_PET", "UNIT_PET_EXPERIENCE",
    "UNIT_HAPPINESS", "UNIT_INVENTORY_CHANGED", "UNIT_SPELLCAST_SUCCEEDED",
    "PLAYER_LEVEL_UP", "PLAYER_XP_UPDATE", "PLAYER_TARGET_CHANGED", "BAG_UPDATE_DELAYED", "PLAYER_ENTERING_WORLD",
  }) do
    pcall(ev.RegisterEvent, ev, e) -- a client without one of these still gets the rest
  end
  ev:SetScript("OnEvent", OnEvent)
  self.ev = ev
  local pet = U.frames.pet
  if pet then
    pet:HookScript("OnEnter", function()
      local bar = X.xp
      if bar and bar:IsShown() and X.xpMost then
        GameTooltip:AddLine(("Experience %s / %s (%d%%)"):format(S.Num(X.xpNow), S.Num(X.xpMost),
          floor(X.xpNow / X.xpMost * 100 + 0.5)), 0.72, 0.52, 0.95)
        GameTooltip:Show()
      end
    end)
  end
  local p = U.frames.player
  self:AfterLayout(p)
  if pet then self:AfterLayout(pet) end
end

local Start = U.Start
function U:Start()
  local was = self.started
  Start(self)
  if not was and self.started then X:Start() end
end
