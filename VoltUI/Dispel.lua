-- VoltUI · Dispel windows and the dispel warning
-- Two extras for healers, on top of the party and raid frames (Raid.lua):
--
-- Dispel windows: a small square for each member, which only shows (by its opacity) while
-- that member has a debuff you can remove. It shows the debuff's icon in its type's colour
-- and the member's name. Left-click casts your first dispel on them, right-click the second
-- (a priest: Dispel Magic, then Abolish Disease). The squares are secure unit buttons made
-- by the game's group header, so they keep their place in a fight and work in one; they're
-- only shown, hidden, sized and given their spells out of combat.
--
-- The warning: a large line when someone gets a debuff you can remove: the debuff's icon,
-- who has it, its name and which click removes it, with a sound (raid warning, ready check,
-- an alarm, or none). Once per new debuff, with the sound at most every two seconds.
--
-- Both work in heal mode (the default), always, or not at all.
--
-- Whether a debuff can be removed is the frames' own answer (RaidAuras.lua): the game's
-- HARMFUL|RAID filter, plain even in a fight, or the debuff's type against your dispels when
-- it can be read. Icons and names may be secret in a fight; they go straight to the widgets.

local _, ns = ...
local FUI, S = ns.FUI, ns.Style
local R, A = ns.Raid, ns.RaidAuras

local D = { tiles = {}, byUnit = {}, seen = {}, pendingClicks = {}, spells = {}, attrs = {} }
ns.Dispel = D

local Safe = S.Safe

D.WHEN = { { key = "off", name = "Off" }, { key = "heal", name = "In heal mode" }, { key = "always", name = "Always" } }
D.SOUNDS = {
  { key = "raidwarning", name = "Raid warning", kit = "RAID_WARNING", id = 8959 },
  { key = "readycheck", name = "Ready check", kit = "READY_CHECK", id = 8960 },
  { key = "alarm", name = "Alarm", kit = "ALARM_CLOCK_WARNING_3", id = 12889 },
  { key = "off", name = "None" },
}
D.DEFAULTS = { windows = "heal", size = 32, warn = "heal", sound = "raidwarning", warnScale = 1 }

-- A window's two clicks by class: left, then right. The first spell you know from each list.
D.CLICKS = {
  PRIEST = { { 988, 527 }, { 552, 528 } },
  PALADIN = { { 4987, 1152 } },
  DRUID = { { 2782 }, { 2893, 8946 } },
  SHAMAN = { { 526 }, { 2870 } },
  MAGE = { { 475 } },
}

local WARN_FOR, WARN_FADE, SOUND_EVERY = 4, 0.6, 2

------------------------------------------------------------------------
-- Settings: VoltUIDB.raidCfg.dispel
------------------------------------------------------------------------

local baseFill = R.FillExtra
function R:FillExtra(c)
  if baseFill then baseFill(self, c) end
  if type(c.dispel) ~= "table" then c.dispel = {} end
  for k, v in pairs(D.DEFAULTS) do
    if c.dispel[k] == nil then c.dispel[k] = v end
  end
end

function D:Cfg() return R:Cfg().dispel end

function D:Reset()
  R:Cfg().dispel = {}
  R.cfg = nil
  R:Cfg()
  self:Apply()
end

local function On(mode)
  return mode == "always" or (mode == "heal" and R:HealOn())
end

function D:WindowsOn() return On(self:Cfg().windows) and self.spells[1] ~= nil end
function D:WarnOn() return On(self:Cfg().warn) end

-- Your two dispels, by name: { { id, name, types } } (left first).
function D:Spells()
  local class = R.PlayerClass()
  local out = {}
  for _, ids in ipairs(self.CLICKS[class] or {}) do
    for _, id in ipairs(ids) do
      if IsPlayerSpell and IsPlayerSpell(id) == true then
        local name = R.SpellName(id)
        if name then out[#out + 1] = { id = id, name = name, types = (A.DISPELS[class] or {})[id] or {} } end
        break
      end
    end
  end
  return out
end

------------------------------------------------------------------------
-- The windows
------------------------------------------------------------------------

-- Runs in the game's secure environment for each new window: its size, then VoltUI's look.
-- (Its two spells come from the header's _initialAttribute-*.)
local INIT = [[
  local header = self:GetParent()
  local size = header:GetAttribute("volt-size") or 32
  self:SetWidth(size)
  self:SetHeight(size)
  header:CallMethod("kInit", self:GetName())
]]
D.INIT = INIT

local function Font(fs, size)
  if fs.SetFont then pcall(fs.SetFont, fs, S.Font().path, math.max(6, math.floor(size + 0.5)), "OUTLINE") end
end

function D:SetUnit(f, unit)
  local old = f.kunit
  if old and self.byUnit[old] then self.byUnit[old][f] = nil end
  if type(unit) ~= "string" or unit == "" then unit = nil end
  f.kunit = unit
  if unit then
    self.byUnit[unit] = self.byUnit[unit] or {}
    self.byUnit[unit][f] = true
  end
  R.Guard("dispel windows", self.Update, self, f)
end

function D:InitTile(f)
  if type(f) ~= "table" or self.tiles[f] then return end
  self.tiles[f] = true
  f.kfill = S.Tex(f, "BACKGROUND", -8)
  f.kfill:SetAllPoints(f)
  f.kfill:SetColorTexture(S.BG[1], S.BG[2], S.BG[3], 0.9)
  f.tex = S.Tex(f, "ARTWORK")
  f.tex:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -2)
  f.tex:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 2)
  f.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  f.edges = S.Edges(f, "OVERLAY", 1, f)
  f.kname = S.Text(f, nil, "CENTER", "OVERLAY")
  f.kname:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1, 2)
  f.kname:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 2)
  Font(f.kname, (tonumber(self:Cfg().size) or 32) / 4)
  S.Highlight(f, 0.15)
  f:SetAlpha(0)
  f:HookScript("OnAttributeChanged", function(b, name, value)
    if name == "unit" then D:SetUnit(b, value) end
  end)
  if InCombatLockdown() then
    self.pendingClicks[f] = true
  else
    f:RegisterForClicks("AnyUp")
    for k, v in pairs(self.attrs) do f:SetAttribute(k, v) end
  end
  self:SetUnit(f, f:GetAttribute("unit"))
end

-- Shows a window (by opacity: plain, so fine in a fight) while its member has something you
-- can remove, with the first such debuff's icon.
function D:Update(f)
  local u = f.kunit
  local first
  if u then
    -- the member's tile has usually just read these for the same event: that reading is shared
    for _, e in ipairs(A:Scan(u, f).all) do
      if e.removable then
        first = e
        break
      end
    end
  end
  if first then
    f.tex:SetTexture(A.Field(first.data, "icon"))
    A.PaintType(f, u, first.id, first.data, true)
    local name = UnitName and UnitName(u)
    f.kname:SetText(name or "")
    f:SetAlpha(1)
    f.kshowing = true
  else
    f:SetAlpha(0)
    f.kshowing = nil
  end
end

function D:ForUnit(unit)
  local set = self.byUnit[unit]
  if not set then return end
  for f in pairs(set) do R.Guard("dispel windows", self.Update, self, f) end
end

-- How many rows of five the windows fill: one for a party, up to eight for a raid.
function D:Rows()
  if not (IsInRaid and IsInRaid()) then return 1 end
  local n = GetNumGroupMembers and S.Safe(GetNumGroupMembers())
  if type(n) ~= "number" then return 8 end
  return math.max(1, math.min(8, math.ceil(n / 5)))
end

-- The holder (and so the overlay you drag) covers every row the group fills. Out of combat only.
function D:SizeHolder()
  if not self.holder then return end
  if InCombatLockdown() then
    self.applyPending = true
    return
  end
  local size = tonumber(self:Cfg().size) or 32
  local rows = self:Rows()
  self.holder:SetSize(5 * size + 8, rows * size + (rows - 1) * 2)
end

-- Sizes, spells and whether the windows show. Out of combat only; waits for the fight to end.
function D:Apply()
  if not self.enabled then return end
  if InCombatLockdown() then
    self.applyPending = true
    return
  end
  self.applyPending = nil
  self.spells = self:Spells()
  local c = self:Cfg()
  local size = tonumber(c.size) or 32
  local attrs = {}
  for i, sp in ipairs(self.spells) do
    if i <= 2 then
      attrs["type" .. i] = "spell"
      attrs["spell" .. i] = sp.name
    end
  end
  local old = self.attrs or {}
  local names = {}
  for k in pairs(attrs) do names[#names + 1] = k end
  table.sort(names)
  local h = self.header
  h:SetAttribute("_ignore", "volt")
  h:SetAttribute("volt-size", size)
  for k in pairs(old) do
    if attrs[k] == nil then h:SetAttribute("_initialAttribute-" .. k, nil) end
  end
  for k, v in pairs(attrs) do h:SetAttribute("_initialAttribute-" .. k, v) end
  h:SetAttribute("_initialAttributeNames", #names > 0 and table.concat(names, ",") or nil)
  h:SetAttribute("_ignore", nil)
  for f in pairs(self.tiles) do
    f:SetSize(size, size)
    Font(f.kname, size / 4)
    for k in pairs(old) do
      if attrs[k] == nil then f:SetAttribute(k, nil) end
    end
    for k, v in pairs(attrs) do f:SetAttribute(k, v) end
  end
  self.attrs = attrs
  self:SizeHolder()
  if self:WindowsOn() then h:Show() else h:Hide() end
  -- every window made ahead of a fight, as the party and raid frames' buttons are (Raid.lua)
  if ns.Raid and ns.Raid.PreMake then pcall(ns.Raid.PreMake, h, (IsInRaid and IsInRaid()) and 40 or 5) end
  local w = self.warn
  if w then
    w:SetScale(tonumber(c.warnScale) or 1)
  end
end

------------------------------------------------------------------------
-- The warning
------------------------------------------------------------------------

function D:WarnFrame()
  if self.warn then return self.warn end
  local holder = CreateFrame("Frame", "VoltUIDispelWarning", UIParent)
  holder:SetSize(440, 40)
  holder:SetFrameStrata("HIGH")
  holder:SetMovable(true)
  holder:SetClampedToScreen(true)
  if not S.PlaceSpot(holder, ns.db, "dispelWarnLeft", "dispelWarnTop", "dispelWarnPoint") then
    holder:ClearAllPoints()
    holder:SetPoint("TOP", UIParent, "TOP", 0, -180)
  end
  holder.mover = S.Mover(holder, "Dispel warning", function(f)
    S.KeepSpot(f, ns.db, "dispelWarnLeft", "dispelWarnTop", "dispelWarnPoint")
  end, { spot = function() return ns.db, "dispelWarnLeft", "dispelWarnTop", "dispelWarnPoint" end })
  local w = CreateFrame("Frame", nil, holder)
  w:SetAllPoints(holder)
  w:SetAlpha(0)
  w.box = CreateFrame("Frame", nil, w)
  w.box:SetSize(32, 32)
  w.box:SetPoint("LEFT", w, "LEFT", 4, 0)
  w.box.tex = S.Tex(w.box, "ARTWORK")
  w.box.tex:SetPoint("TOPLEFT", w.box, "TOPLEFT", 2, -2)
  w.box.tex:SetPoint("BOTTOMRIGHT", w.box, "BOTTOMRIGHT", -2, 2)
  w.box.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  w.box.edges = S.Edges(w.box, "OVERLAY", 1, w.box)
  local function line(anchor, r, g, b)
    local fs = S.Text(w, nil, "LEFT", "OVERLAY")
    Font(fs, 16)
    fs:SetPoint("LEFT", anchor, "RIGHT", 10, 0)
    fs:SetTextColor(r, g, b)
    return fs
  end
  w.who = line(w.box, 1, 1, 1)
  w.what = line(w.who, 1, 0.82, 0.3)
  w.how = line(w.what, S.ACCENT[1], S.ACCENT[2], S.ACCENT[3])
  w:SetScript("OnUpdate", function(self)
    if not self.untilAt or D.sample then return end
    local left = self.untilAt - GetTime()
    if left <= 0 then
      self:SetAlpha(0)
      self.untilAt = nil
    elseif left < WARN_FADE then
      self:SetAlpha(left / WARN_FADE)
    end
  end)
  holder.warnBox = w
  self.warn = holder
  holder:SetScale(tonumber(self:Cfg().warnScale) or 1)
  return holder
end

-- Which click removes debuff e: a click on the frames that casts a dispel for its type, else
-- the dispel window's. With the type secret (in a fight) any dispel click will do.
function D:HowTo(e)
  local kind = Safe(A.Field(e and e.data, "dispelName"))
  if type(kind) ~= "string" then kind = nil end
  local function covers(types)
    if not kind then return true end
    for _, t in ipairs(types) do
      if t == kind then return true end
    end
    return false
  end
  local class = R.PlayerClass()
  local found = {}
  local cfg = R:Cfg()
  if cfg.clicksWhen == "always" or R:HealOn() then
    local binds = R:Bindings()
    for _, m in ipairs(R.MODS) do
      for _, bt in ipairs(R.BUTTONS) do
        local combo = m.key .. bt.key
        local b = binds[combo]
        local name = b and b.kind == "spell" and R:SpellOf(b)
        if type(name) == "string" and #found < 2 then
          name = name:gsub("%(.*%)$", "")
          for id, types in pairs(A.DISPELS[class] or {}) do
            if R.SpellName(id) == name and covers(types) then
              found[#found + 1] = R:ComboName(combo) .. "-click"
              break
            end
          end
        end
      end
    end
  end
  if #found > 0 then return table.concat(found, " or ") end
  if self:WindowsOn() then
    for i, sp in ipairs(self.spells) do
      if i <= 2 and covers(sp.types) then
        return (i == 1 and "Left" or "Right") .. "-click its dispel window"
      end
    end
  end
  return ""
end

function D:PlaySound(key)
  for _, s in ipairs(self.SOUNDS) do
    if s.key == key and s.kit then
      local id = (type(SOUNDKIT) == "table" and SOUNDKIT[s.kit]) or s.id
      if PlaySound then pcall(PlaySound, id, "Master") end
      return true
    end
  end
  return false
end

function D:Warn(u, e)
  local holder = self:WarnFrame()
  local w = holder.warnBox
  w.box.tex:SetTexture(A.Field(e.data, "icon"))
  A.PaintType(w.box, u, e.id, e.data, true)
  local name = UnitName and UnitName(u)
  w.who:SetText(name or "")
  w.what:SetText(A.Field(e.data, "name") or "")
  w.how:SetText(self:HowTo(e))
  w:SetAlpha(1)
  w.untilAt = GetTime() + WARN_FOR
  local now = GetTime()
  if now - (self.soundAt or -SOUND_EVERY) >= SOUND_EVERY then
    if self:PlaySound(self:Cfg().sound) then self.soundAt = now end
  end
end

-- From each tile's debuff update (RaidAuras.lua): warns about a removable debuff the tile
-- didn't have before. The first look at a tile only notes what's there.
function A:OnUpdated(f, removable)
  D:Check(f, removable)
end

function D:Check(f, removable)
  local now = {}
  for _, e in ipairs(removable or {}) do now[e.id] = true end
  local old = self.seen[f]
  self.seen[f] = now
  if not old or not f.kunit or not self:WarnOn() then return end
  for _, e in ipairs(removable) do
    if not old[e.id] then
      R.Guard("dispel warning", self.Warn, self, f.kunit, e)
      return
    end
  end
end

-- A member changing tiles starts afresh, so their old debuffs aren't news.
local baseSetUnit = R.SetUnit
function R:SetUnit(f, unit)
  if f.kunit ~= unit then D.seen[f] = nil end
  return baseSetUnit(self, f, unit)
end

-- Made-up text while moving frames, and the Test button on the Dispel page.
function D:Sample(on)
  local holder = self:WarnFrame()
  local w = holder.warnBox
  if on then
    self.sample = true
    w.box.tex:SetTexture(136016)
    local col = A.TYPE_COLORS.Poison
    S.ColorEdges(w.box.edges, col[1], col[2], col[3], 1)
    w.who:SetText("Brakka")
    w.what:SetText("Deadly Poison")
    local spells = self:Spells()
    w.how:SetText(spells[1] and ("Left-click its dispel window (" .. spells[1].name .. ")") or "Middle-click")
    w:SetAlpha(1)
  else
    self.sample = nil
    w:SetAlpha(0)
    w.untilAt = nil
  end
end

function D:Test()
  self:Sample(true)
  self.sample = nil
  self.warn.warnBox.untilAt = GetTime() + WARN_FOR
  self:PlaySound(self:Cfg().sound)
end

function D:SetUnlocked(on)
  if self.holder and self.holder.mover then self.holder.mover:SetShown(on and true or false) end
  local holder = self:WarnFrame()
  if holder.mover then holder.mover:SetShown(on and true or false) end
  self:Sample(on)
end

------------------------------------------------------------------------
-- Starting up
------------------------------------------------------------------------

function D:OnEvent(event, arg)
  if event == "UNIT_AURA" then
    if arg then self:ForUnit(arg) end
  elseif event == "SPELLS_CHANGED" then
    self:Apply()
  elseif event == "GROUP_ROSTER_UPDATE" then
    self:SizeHolder()
  elseif event == "PLAYER_REGEN_ENABLED" then
    for f in pairs(self.pendingClicks) do
      f:RegisterForClicks("AnyUp")
      self.pendingClicks[f] = nil
    end
    if self.applyPending then self:Apply() end
  end
end

function D:Enable()
  if self.enabled then return end
  self.enabled = true
  R:Cfg()
  local holder = CreateFrame("Frame", "VoltUIDispelFrames", UIParent)
  holder:SetMovable(true)
  holder:SetClampedToScreen(true)
  holder:SetSize(5 * 32 + 8, 32)
  if not S.PlaceSpot(holder, ns.db, "dispelLeft", "dispelTop", "dispelPoint") then
    holder:ClearAllPoints()
    holder:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
  end
  holder.mover = S.Mover(holder, "Dispel windows", function(f)
    S.KeepSpot(f, ns.db, "dispelLeft", "dispelTop", "dispelPoint")
  end, { spot = function() return ns.db, "dispelLeft", "dispelTop", "dispelPoint" end })
  self.holder = holder

  local h = CreateFrame("Frame", "VoltUIDispelHeader", holder, "SecureGroupHeaderTemplate")
  h:SetAttribute("template", "SecureUnitButtonTemplate")
  h:SetAttribute("templateType", "Button")
  h:SetAttribute("initialConfigFunction", INIT)
  h:SetAttribute("showParty", true)
  h:SetAttribute("showRaid", true)
  h:SetAttribute("showPlayer", true)
  h:SetAttribute("groupBy", "GROUP")
  h:SetAttribute("groupingOrder", "1,2,3,4,5,6,7,8")
  h:SetAttribute("maxColumns", 8)
  h:SetAttribute("unitsPerColumn", 5)
  h:SetAttribute("point", "LEFT")
  h:SetAttribute("xOffset", 2)
  h:SetAttribute("yOffset", 0)
  h:SetAttribute("columnAnchorPoint", "TOP")
  h:SetAttribute("columnSpacing", 2)
  h:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
  h.kInit = function(_, childName) D:InitTile(_G[childName]) end
  self.header = h

  local ev = CreateFrame("Frame")
  for _, e in ipairs({ "UNIT_AURA", "SPELLS_CHANGED", "GROUP_ROSTER_UPDATE", "PLAYER_REGEN_ENABLED" }) do pcall(ev.RegisterEvent, ev, e) end
  ev:SetScript("OnEvent", function(_, event, arg) D:OnEvent(event, arg) end)
  self.ev = ev
  self:WarnFrame()
  self:Apply()
end
