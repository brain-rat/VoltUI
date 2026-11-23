-- VoltUI · Unit frames
-- Flat player, target, target-of-target and pet frames in the shared style,
-- replacing Blizzard's. Each frame is laid out from its own settings, so the edit
-- mode (/volt edit) can change any of them while you watch: size, fonts, name,
-- level, numbers, class colours, portrait and the elite and rare style.
--
--   Left-click   target        Right-click   the game's unit menu
--
-- Blizzard's totem frame is moved out first and sits above the player frame.
-- Combo points are a row of pips under the player frame (Rogue and Druid).
--
-- Numbers can be secret on this client, so they go straight to the widgets:
-- nothing here adds up or compares a health or power value unless Safe() let it through.

local _, ns = ...
local FUI, S = ns.FUI, ns.Style

local U = { key = "frames", name = "Unit frames", frames = {}, byUnit = {}, auras = {} }
ns.UnitFrames = U

local Safe, Present = S.Safe, S.Present
local floor, max = math.floor, math.max

local ICON_GAP, MAX_AURAS = 3, 16
local FRAME_KEYS = { "player", "target", "tot", "pet", "focus" }

local DEFAULTS = {
  player = {
    width = 230, hpHeight = 20, power = true, pwHeight = 12,
    name = "full", nameSize = 13, level = true, tags = true,
    hpText = true, hpPct = true, barSize = 12, pwText = true, pwSize = 10,
    classColor = true, portrait = "off", portraitSide = "left", elite = "off", scale = 1,
    heals = true,
  },
  target = {
    width = 230, hpHeight = 20, power = true, pwHeight = 12,
    name = "full", nameSize = 13, level = true, tags = true,
    hpText = true, hpPct = true, barSize = 12, pwText = true, pwSize = 10,
    classColor = true, portrait = "off", portraitSide = "right", elite = "glow", scale = 1,
    auras = true, auraSize = 22, heals = false,
    auraGame = true, -- the row is the game's own aura container, which keeps going in a fight (1.101.24)
  },
  tot = {
    width = 120, hpHeight = 10, power = false, pwHeight = 5,
    name = "full", nameSize = 11, level = false, tags = false,
    hpText = false, hpPct = false, barSize = 10, pwText = false, pwSize = 9,
    classColor = true, portrait = "off", portraitSide = "right", elite = "off", scale = 1,
    heals = false,
  },
  pet = {
    width = 120, hpHeight = 10, power = true, pwHeight = 5,
    name = "full", nameSize = 11, level = false, tags = false,
    hpText = false, hpPct = false, barSize = 10, pwText = false, pwSize = 9,
    classColor = true, portrait = "off", portraitSide = "left", elite = "off", scale = 1,
    heals = false,
  },
}
-- Your focus (since 1.47.0): between the pet frame and the big frames in size.
DEFAULTS.focus = {
  width = 160, hpHeight = 14, power = true, pwHeight = 5,
  name = "full", nameSize = 12, level = true, tags = false,
  hpText = false, hpPct = true, barSize = 10, pwText = false, pwSize = 9,
  classColor = true, portrait = "off", portraitSide = "left", elite = "border", scale = 1,
  heals = false,
}
-- Since 1.46.0: what the health and power numbers show, and whether big ones are shortened.
for _, d in pairs(DEFAULTS) do
  d.hpFormat, d.pwFormat, d.short = "both", "both", false
end
-- (1.96.0) The level, the status tags and the health percent have sizes of their own. They
-- used to follow the name's size (one and two smaller) and the health numbers' size, and
-- start from there, in the defaults and in settings saved before.
local function OwnSizes(c, d)
  local name, bar = c.nameSize or d.nameSize, c.barSize or d.barSize
  if c.levelSize == nil then c.levelSize = max(name - 1, 8) end
  if c.tagSize == nil then c.tagSize = max(name - 2, 8) end
  if c.hpPctSize == nil then c.hpPctSize = bar end
end
for _, d in pairs(DEFAULTS) do OwnSizes(d, d) end
-- (1.93.0) Where each text sits and the order of a frame's rows. A text is on the name panel
-- or on one of the bars, at its left, middle or right, and can be nudged from there. The rows
-- (name panel, health, power, combo points) stack top to bottom by their numbers.
local PIECE_HOME = {
  name = { "name", "left" }, level = { "name", "right" }, tag = { "name", "right" },
  hpText = { "hp", "right" }, hpPct = { "hp", "left" }, pwText = { "pw", "right" },
}
for _, d in pairs(DEFAULTS) do
  for piece, home in pairs(PIECE_HOME) do
    d[piece .. "At"], d[piece .. "Align"], d[piece .. "X"], d[piece .. "Y"] = home[1], home[2], 0, 0
  end
  d.rowName, d.rowHp, d.rowPw, d.rowPips = 1, 2, 3, 4
end
-- (1.94.0) The border's look. It also signalled a fight, a debuff and low health until
-- 1.97.1: the status tags already say Combat, and the user wanted the border left alone.
for _, d in pairs(DEFAULTS) do
  d.border = "hairline"
end
U.BORDERS = {
  { key = "hairline", name = "Hairline" }, { key = "double", name = "Double line" }, { key = "plate", name = "Glass plate" },
  { key = "rail", name = "Rail and tab" }, { key = "none", name = "None" },
}
U.DEFAULTS = DEFAULTS
U.PLACES = { { key = "name", name = "Name panel" }, { key = "hp", name = "Health bar" }, { key = "pw", name = "Power bar" } }
U.ALIGNS = { { key = "left", name = "Left" }, { key = "center", name = "Middle" }, { key = "right", name = "Right" } }
local ROWS = { "name", "hp", "pw", "pips" }
local ROW_KEY = { name = "rowName", hp = "rowHp", pw = "rowPw", pips = "rowPips" }
local ROW_INDEX = { name = 1, hp = 2, pw = 3, pips = 4 }
U.ROW_KEY = ROW_KEY
local PIP_H, PAD = 6, 5
-- Texts that share a side line up outward from the edge in this order.
local FROM_LEFT = { "name", "level", "tag", "hpPct", "hpText", "pwText" }
local FROM_RIGHT = { "level", "tag", "hpText", "pwText", "hpPct", "name" }

-- A frame's rows, top to bottom. `pips` says whether to list the combo points (the player's page).
function U:Order(c, pips)
  local out = {}
  for _, k in ipairs(ROWS) do
    if k ~= "pips" or pips then out[#out + 1] = k end
  end
  table.sort(out, function(a, b)
    local pa, pb = c[ROW_KEY[a]] or 9, c[ROW_KEY[b]] or 9
    if pa ~= pb then return pa < pb end
    return ROW_INDEX[a] < ROW_INDEX[b]
  end)
  return out
end

-- Puts one row at a place in the order, by swapping with the row that has it.
function U:SetRow(c, row, at, pips)
  local order = self:Order(c, pips)
  local other = order[at]
  if not other or other == row then return end
  local a, b = ROW_KEY[row], ROW_KEY[other]
  c[a], c[b] = c[b], c[a]
  if c[a] == c[b] then -- a tie from somewhere: number them all afresh
    for i, k in ipairs(order) do c[ROW_KEY[k]] = i end
    c[a], c[b] = c[b], c[a]
  end
end

local function PieceOn(c, piece)
  if piece == "name" then return c.name ~= "off" end
  if piece == "tag" then return c.tags end
  if piece == "pwText" then return c.pwText and c.power end
  return c[piece] and true or false
end

-- With the rail and tab border the level sits in the tab above the frame, wherever it was put.
local function TabOn(c) return c.border == "rail" and c.level and true or false end

-- Is anything on the name panel? Without, the panel isn't drawn.
local function PanelUsed(c)
  for piece in pairs(PIECE_HOME) do
    if PieceOn(c, piece) and c[piece .. "At"] == "name" and not (piece == "level" and TabOn(c)) then return true end
  end
  return false
end

-- The rows a frame has, in order, with heights and where each starts, and the frame's height.
-- Combo points at the top or bottom sit just outside the frame, as they always did, so a
-- Druid with none doesn't carry an empty row; in between they get a row inside.
function U:Rows(f, c)
  local hasPips = f.key == "player" and not f.preview and self.pips ~= nil
  local rows = {}
  for _, k in ipairs(self:Order(c, hasPips)) do
    local h
    if k == "name" then
      h = PanelUsed(c) and max(c.nameSize, 8) + 4 or nil
    elseif k == "hp" then
      h = c.hpHeight
    elseif k == "pw" then
      h = c.power and c.pwHeight or nil
    else
      h = PIP_H
    end
    if h then rows[#rows + 1] = { key = k, h = h } end
  end
  local outside
  if hasPips and #rows > 1 then
    if rows[1].key == "pips" then
      outside = "top"
      table.remove(rows, 1)
    elseif rows[#rows].key == "pips" then
      outside = "bottom"
      table.remove(rows)
    end
  end
  local y = 1
  for i, r in ipairs(rows) do
    if i > 1 then
      -- the name panel sits flush against its neighbour; bars have a line between them
      local flush = r.key == "name" or rows[i - 1].key == "name"
      y = y + (flush and 0 or 1)
    end
    r.y = y
    y = y + r.h
  end
  return rows, y + 1, outside
end
U.HP_FORMATS = { { key = "both", name = "Now / most" }, { key = "cur", name = "Now" }, { key = "missing", name = "Missing" } }
U.PW_FORMATS = { { key = "both", name = "Now / most" }, { key = "cur", name = "Now" }, { key = "pct", name = "Percent" } }

local HOSTILE, NEUTRAL, FRIENDLY = { 0.8, 0.25, 0.2 }, { 0.9, 0.75, 0.25 }, { 0.3, 0.7, 0.35 }
local GREY = { 0.5, 0.5, 0.5 }
-- Incoming heals and shields, as on VoltUI's party and raid frames.
local HEAL_COLOR, SHIELD_COLOR, OVERHEAL_COLOR = { 0.35, 0.9, 0.45, 0.45 }, { 1, 1, 1, 0.5 }, { 0.55, 1, 0.6 }
local POWER = {
  MANA = { 0.25, 0.5, 0.95 }, RAGE = { 0.85, 0.25, 0.25 }, ENERGY = { 0.95, 0.8, 0.25 },
  FOCUS = { 0.95, 0.55, 0.25 }, RUNIC_POWER = { 0, 0.82, 1 },
}
local CLASSIFICATION = {
  worldboss = "|cffff5555Boss|r", rareelite = "|cffc8c8ffRare Elite|r",
  elite = "|cffffd100Elite|r", rare = "|cffc8c8ffRare|r",
}
local ELITE_RGB = {
  worldboss = { 1, 0.33, 0.33 }, rareelite = { 0.78, 0.78, 1 },
  elite = { 1, 0.82, 0 }, rare = { 0.78, 0.78, 1 },
}

-- One frame's settings. Anything missing comes from the defaults, and the older
-- all-frames settings carry over the first time a frame is seen.
function U:Cfg(key)
  local db = ns.db
  db.frameCfg = db.frameCfg or {}
  local c = db.frameCfg[key]
  if not c then
    c = { classColor = db.classColor, scale = db.frameScale }
    db.frameCfg[key] = c
  end
  OwnSizes(c, DEFAULTS[key])
  c.sigCombat, c.sigDebuff, c.sigLow = nil, nil, nil -- the border signals, gone in 1.97.1
  for k, v in pairs(DEFAULTS[key]) do
    if c[k] == nil then c[k] = v end
  end
  return c
end

------------------------------------------------------------------------
-- Values
------------------------------------------------------------------------

local Num, Percent = S.Num, S.HealthPercent

local function ClassColor(u)
  local _, class = UnitClass(u)
  if C_ClassColor and C_ClassColor.GetClassColor then
    local c = C_ClassColor.GetClassColor(class)
    if c then return c.r, c.g, c.b end
  end
  local key = Safe(class)
  local c = key and RAID_CLASS_COLORS and RAID_CLASS_COLORS[key]
  if c then return c.r, c.g, c.b end
end

local function ReactionColor(u)
  local n = Safe(UnitReaction(u, "player"))
  local c = FRIENDLY
  if n then
    if n <= 3 then c = HOSTILE elseif n == 4 then c = NEUTRAL end
  end
  return c[1], c[2], c[3]
end

local function HealthColor(u, useClass)
  if Safe(UnitIsPlayer(u)) then
    if useClass then
      local r, g, b = ClassColor(u)
      if r then return r, g, b end
    end
    return FRIENDLY[1], FRIENDLY[2], FRIENDLY[3]
  end
  if Safe(UnitIsTapDenied(u)) then return GREY[1], GREY[2], GREY[3] end
  return ReactionColor(u)
end

-- This client's player names come in two parts: "Da" and "Rat".
local function SetName(fs, u, mode)
  local first, second = UnitName(u)
  if mode ~= "first" and Present(second) and Safe(second) ~= ""
    and RegionalUniqueNamesEnabled and RegionalUniqueNamesEnabled() then
    local names = Constants and Constants.CharacterNameSeparatorConsts
    fs:SetFormattedText("%s%s%s", first, names and names.CHARACTERNAME_SURNAME_SEPARATOR or " ", second)
  else
    fs:SetText(first)
  end
end

-- While placing the frames, the target frame can pretend to be an elite or rare.
local function Classification(f)
  if f.key == "target" and (U.unlocked or f.preview) and U.previewClass then return U.previewClass end
  return Safe(UnitClassification(f.unit))
end

------------------------------------------------------------------------
-- Painting a frame
------------------------------------------------------------------------

function U:UpdateHealth(f)
  local u, c = f.unit, self:Cfg(f.key)
  local cur, maxv = UnitHealth(u), UnitHealthMax(u)
  f.hp:SetMinMaxValues(0, maxv)
  f.hp:SetValue(cur)
  local status
  if Safe(UnitIsConnected(u)) == false then
    status = "Offline"
  elseif Safe(UnitIsGhost(u)) then
    status = "Ghost"
  elseif Safe(UnitIsDead(u)) then
    status = "Dead"
  end
  if status then
    f.hpText:SetText(status)
    f.hpPct:SetText("")
    f.hpText:SetShown(c.hpText or c.hpPct)
  else
    local num = c.short and S.ShortNum or Num
    if c.hpFormat == "cur" then
      f.hpText:SetText(num(cur))
    elseif c.hpFormat == "missing" then
      -- What's gone, empty at full health. The game works it out where the numbers are secret.
      local gone = UnitHealthMissing and UnitHealthMissing(u)
      -- Secret first: a secret can't be compared, not even with nil.
      local hidden = S.IsSecret(gone)
      if not hidden and gone == nil and Safe(cur) and Safe(maxv) then gone = maxv - cur end
      if not hidden and gone == nil then
        f.hpText:SetFormattedText("%s / %s", num(cur), num(maxv))
      elseif Safe(gone) then
        f.hpText:SetText(gone > 0 and ("-" .. num(gone)) or "")
      elseif C_StringUtil and C_StringUtil.TruncateWhenZero then
        -- Secret: the game leaves it empty at full health, as on the party and raid frames.
        local text = C_StringUtil.TruncateWhenZero(gone)
        if C_StringUtil.WrapString then text = C_StringUtil.WrapString(text, "-") end
        f.hpText:SetText(text)
      else
        f.hpText:SetFormattedText("-%s", num(gone))
      end
    else
      f.hpText:SetFormattedText("%s / %s", num(cur), num(maxv))
    end
    f.hpPct:SetFormattedText("%s%%", Percent(u, cur, maxv))
    f.hpText:SetShown(c.hpText)
  end
  self:UpdateHeals(f, c, maxv, status ~= nil)
end

-- Incoming heals and shields after the health, up to full (the game's heal calculator cuts
-- them to what's missing), and a bright edge when there's more than that: the same as the
-- party and raid frames (Style.lua's S.Predict). Secret values go straight into the bars.
function U:UpdateHeals(f, c, maxv, gone)
  if not f.heal then return end
  local on = c.heals and not gone
  local heals, shields, healOver, shieldOver
  if on then heals, shields, healOver, shieldOver = S.Predict(f.unit) end
  f.heal:SetMinMaxValues(0, maxv)
  S.SetAmount(f.heal, heals, on)
  f.shield:SetMinMaxValues(0, maxv)
  S.SetAmount(f.shield, shields, on)
  S.ShowIf(f.overheal, healOver, on)
  S.ShowIf(f.overshield, shieldOver, on)
end

function U:UpdatePower(f)
  if not self:Cfg(f.key).power then return end
  local u = f.unit
  local kind, token = UnitPowerType(u)
  local c = POWER[Safe(token)] or (PowerBarColor and PowerBarColor[Safe(token)]) or GREY
  S.BarColor(f.pw, c[1] or c.r, c[2] or c.g, c[3] or c.b)
  local cur, maxv = UnitPower(u, kind), UnitPowerMax(u, kind)
  f.pw:SetMinMaxValues(0, maxv)
  f.pw:SetValue(cur)
  local cfg = self:Cfg(f.key)
  local num = cfg.short and S.ShortNum or Num
  if Safe(maxv) == 0 then
    f.pwText:SetText("")
  elseif cfg.pwFormat == "cur" then
    f.pwText:SetText(num(cur))
  elseif cfg.pwFormat == "pct" and Safe(cur) and Safe(maxv) then
    f.pwText:SetFormattedText("%d%%", math.floor(cur / maxv * 100 + 0.5))
  elseif cfg.pwFormat == "pct" and UnitPowerPercent and CurveConstants and CurveConstants.ScaleTo100 then
    -- Secret numbers: the game works the percent out and hands back something text can show.
    local ok, p = pcall(UnitPowerPercent, u, kind, false, CurveConstants.ScaleTo100)
    if ok and p ~= nil then
      if C_StringUtil and C_StringUtil.RoundToNearestString then p = C_StringUtil.RoundToNearestString(p) end
      f.pwText:SetFormattedText("%s%%", p)
    else
      f.pwText:SetFormattedText("%s / %s", num(cur), num(maxv))
    end
  else
    f.pwText:SetFormattedText("%s / %s", num(cur), num(maxv))
  end
end

function U:UpdateLevel(f)
  local lvl = Safe(UnitLevel(f.unit))
  if not lvl then
    f.level:SetText("")
  elseif lvl <= 0 then
    f.level:SetText("??")
    f.level:SetTextColor(1, 0.3, 0.3)
  else
    f.level:SetText(lvl)
    local r, g, b = S.LABEL[1], S.LABEL[2], S.LABEL[3]
    if f.unit ~= "player" and GetCreatureDifficultyColor then
      local ok, c = pcall(GetCreatureDifficultyColor, lvl)
      if ok and type(c) == "table" and c.r then r, g, b = c.r, c.g, c.b end
    end
    f.level:SetTextColor(r, g, b)
  end
end

function U:UpdateTag(f)
  local u = f.unit
  local parts = {}
  if f.key == "player" then
    if Safe(UnitAffectingCombat(u)) then
      parts[#parts + 1] = "|cffff5555Combat|r"
    elseif IsResting and IsResting() then
      parts[#parts + 1] = "|cff7fc8ffRested|r"
    end
    if Safe(UnitIsGroupLeader(u)) then parts[#parts + 1] = "|cffffd100Lead|r" end
  else
    local c = CLASSIFICATION[Classification(f)]
    if c then parts[#parts + 1] = c end
  end
  if Safe(UnitIsPVP(u)) then parts[#parts + 1] = "|cffff8040PvP|r" end
  f.tag:SetText(table.concat(parts, " "))
end

function U:UpdateRaidIcon(f)
  local i = Safe(GetRaidTargetIndex(f.unit))
  if i and SetRaidTargetIconTexture and self:Cfg(f.key).tags then
    SetRaidTargetIconTexture(f.raid, i)
    f.raid:Show()
  else
    f.raid:Hide()
  end
end

function U:UpdateName(f)
  local u, mode = f.unit, self:Cfg(f.key).name
  SetName(f.name, u, mode)
  if f.key == "player" then
    f.name:SetTextColor(S.ACCENT[1], S.ACCENT[2], S.ACCENT[3])
  elseif Safe(UnitIsPlayer(u)) then
    f.name:SetTextColor(1, 1, 1)
  elseif Safe(UnitIsTapDenied(u)) then
    f.name:SetTextColor(GREY[1], GREY[2], GREY[3])
  else
    f.name:SetTextColor(ReactionColor(u))
  end
end

function U:UpdateColor(f)
  S.BarColor(f.hp, HealthColor(f.unit, self:Cfg(f.key).classColor))
end

-- Coloured outline, and a soft glow if chosen, for elites, rares and bosses.
function U:UpdateElite(f)
  local style = self:Cfg(f.key).elite
  local rgb = style ~= "off" and ELITE_RGB[Classification(f)]
  if rgb then
    S.GlowRGB(f.eliteGlow, rgb[1], rgb[2], rgb[3], style == "glow" and 0.35 or 0)
  else
    S.GlowOff(f.eliteGlow)
  end
end

-- force: paint it even if the unit looks the same. Without it, a model isn't reloaded for nothing.
function U:UpdatePortrait(f, force)
  local mode = self:Cfg(f.key).portrait
  if mode == "off" then return end
  local u = f.unit
  local guid = Safe(UnitGUID(u))
  if not force and (guid == nil or guid == f.portraitGUID) then return end
  f.portraitGUID = guid
  if mode == "2d" then
    if SetPortraitTexture then SetPortraitTexture(f.portrait2d, u) end
  elseif f.portrait3d then
    local m = f.portrait3d
    if Safe(UnitIsVisible(u)) == false then
      if m.ClearModel then m:ClearModel() end
    else
      pcall(m.SetUnit, m, u)
      if m.SetPortraitZoom then pcall(m.SetPortraitZoom, m, 1) end
    end
  end
end

function U:Update(f, light)
  if not f then return end
  if Safe(UnitExists(f.unit)) == false then return end
  self:UpdateName(f)
  self:UpdateLevel(f)
  self:UpdateTag(f)
  self:UpdateRaidIcon(f)
  self:UpdateColor(f)
  self:UpdateHealth(f)
  self:UpdatePower(f)
  self:UpdateElite(f)
  self:UpdatePortrait(f, not light)
end

function U:UpdateAll()
  for _, f in pairs(self.frames) do self:Update(f) end
  self:UpdateAuras()
  self:UpdatePips()
end

------------------------------------------------------------------------
-- Target buffs and debuffs
------------------------------------------------------------------------

local function AuraEnter(b)
  if not b.aura then return end
  GameTooltip:SetOwner(b, "ANCHOR_BOTTOMRIGHT")
  local id = b.aura.auraInstanceID
  if id and GameTooltip.SetUnitAuraByAuraInstanceID then
    GameTooltip:SetUnitAuraByAuraInstanceID("target", id)
  elseif GameTooltip.SetUnitAura then
    GameTooltip:SetUnitAura("target", b.index, b.filter)
  end
  GameTooltip:Show()
end

function U:AuraButton(i)
  local b = self.auras[i]
  if b then return b end
  b = CreateFrame("Frame", nil, self.auraRow)
  b:EnableMouse(true)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetAllPoints()
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.edges = S.Edges(b, "OVERLAY", 6)
  b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
  b.cd:SetAllPoints()
  b.cd:SetDrawEdge(false)
  b.cd:SetReverse(true)
  b.count = S.Text(b, "NumberFontNormal", "RIGHT", "OVERLAY", 11, "OUTLINE", "frames.auras")
  b.count:SetDrawLayer("OVERLAY", 7)
  b.count:SetPoint("BOTTOMRIGHT", 1, 0)
  b:SetScript("OnEnter", AuraEnter)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  self.auras[i] = b
  return b
end

-- As many icons in a row as fit the frame's width, then the next row up.
function U:PlaceAura(b, i)
  local c = self:Cfg("target")
  local size = c.auraSize
  local step = size + ICON_GAP
  local perRow = max(1, floor((c.width + ICON_GAP) / step))
  local row, col = floor((i - 1) / perRow), (i - 1) % perRow
  b:SetSize(size, size)
  b:ClearAllPoints()
  b:SetPoint("BOTTOMLEFT", self.auraRow, "BOTTOMLEFT", col * step, row * step)
end

function U:PaintAura(b, a, index, filter)
  b.aura, b.index, b.filter = a, index, filter
  S.AuraIcon(b.icon, a) -- secret icons included

  local n = Safe(a.applications)
  if type(n) == "number" then
    b.count:SetText(n > 1 and n or "")
  elseif C_UnitAuras.GetAuraApplicationDisplayCount then
    local ok, text = pcall(C_UnitAuras.GetAuraApplicationDisplayCount, "target", a.auraInstanceID, 2, 99)
    b.count:SetText(ok and text or "")
  else
    b.count:SetText("")
  end

  local d, e = Safe(a.duration), Safe(a.expirationTime)
  if d and e then
    if d > 0 then
      b.cd:SetCooldown(e - d, d)
      b.cd:Show()
    else
      b.cd:Hide()
    end
  elseif C_UnitAuras.GetAuraDuration and b.cd.SetCooldownFromDurationObject then
    local ok, obj = pcall(C_UnitAuras.GetAuraDuration, "target", a.auraInstanceID)
    if ok and obj then
      b.cd:SetCooldownFromDurationObject(obj)
      b.cd:Show()
    else
      b.cd:Hide()
    end
  else
    b.cd:Hide()
  end

  local r, g, bl, alpha = S.EDGE[1], S.EDGE[2], S.EDGE[3], 0.8
  local kind = Safe(a.dispelName)
  local c = filter == "HARMFUL" and kind and DebuffTypeColor and DebuffTypeColor[kind]
  if c then
    r, g, bl, alpha = c.r, c.g, c.b, 1
  elseif Safe(a.isFromPlayerOrPlayerPet) then
    r, g, bl, alpha = S.ACCENT[1], S.ACCENT[2], S.ACCENT[3], 1
  end
  S.ColorEdges(b.edges, r, g, bl, alpha)
  b:Show()
end

------------------------------------------------------------------------
-- The target's auras, kept up by the game (1.101.24, a first try on this one frame)
------------------------------------------------------------------------
-- In a fight the game refuses every aura read an add-on makes, so VoltUI's own row above stops
-- updating until the fight ends. The game has a frame type made for this, an "aura
-- container" (Blizzard_AuraContainer; its templates may be created by add-ons): VoltUI says
-- which unit, which kinds of aura, how many and how they're laid out, and builds each
-- button's parts once; the game then picks the auras and fills the icon, the sweep and the
-- stack count itself. No aura value passes through VoltUI, so it keeps working in a fight.
-- What it can't do is tell VoltUI which auras are up, and once made, a button can't be touched
-- by VoltUI while auras are hidden from add-ons. VoltUI's own row stays as the fallback: if the
-- container can't be made, or "Kept up by the game" is off, that is what shows.

function U:DressGameAura(b)
  local size = self:Cfg("target").auraSize
  b:SetSize(size, size)
  local icon = b:CreateTexture(nil, "ARTWORK")
  icon:SetAllPoints()
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  pcall(b.SetIcon, b, icon)
  local cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
  cd:SetAllPoints()
  if cd.SetDrawEdge then cd:SetDrawEdge(false) end
  if cd.SetReverse then cd:SetReverse(true) end
  pcall(b.SetDurationCooldown, b, cd)
  local count = S.Text(b, "NumberFontNormal", "RIGHT", "OVERLAY", 11, "OUTLINE", "frames.auras")
  count:SetDrawLayer("OVERLAY", 7)
  count:SetPoint("BOTTOMRIGHT", 1, 0)
  pcall(b.SetApplicationCount, b, count)
  S.ColorEdges(S.Edges(b, "OVERLAY", 6), S.EDGE[1], S.EDGE[2], S.EDGE[3], 0.8)
  self.gameAuraButtons = self.gameAuraButtons or {}
  self.gameAuraButtons[#self.gameAuraButtons + 1] = b
end

local function GameAuraLayout(size, second)
  return { elementSpacing = ICON_GAP, lineSpacing = ICON_GAP, groupSpacing = second and ICON_GAP or 0, elementWidth = size, elementHeight = size }
end

-- The container, made once. False (and why, in gameAurasWhy) if this client won't have it.
function U:GameAuras()
  if self.gameAuras ~= nil then return self.gameAuras end
  self.gameAuras = false
  local ok, c = pcall(CreateFrame, "AuraContainer", "VoltUITargetAuras", self.auraRow, "CustomAuraContainerTemplate")
  if not ok or type(c) ~= "table" or type(c.AddAuraGroup) ~= "function" then
    self.gameAurasWhy = ok and "no aura container on this client" or tostring(c)
    return false
  end
  local cfg = self:Cfg("target")
  local built, err = pcall(function()
    c:SetPoint("BOTTOMLEFT", self.auraRow, "BOTTOMLEFT", 0, 0)
    -- from the bottom-left, to the right, then the next row up: as VoltUI's own row does
    if c.SetFlowLayoutAnchorPoint then c:SetFlowLayoutAnchorPoint("BOTTOMLEFT") end
    local dir = AnchorUtil and AnchorUtil.FlowDirection
    if dir and c.SetFlowLayoutGrowthDirection then c:SetFlowLayoutGrowthDirection(dir.Right, dir.Up) end
    if c.SetFlowLayoutMaximumLineSize then c:SetFlowLayoutMaximumLineSize(cfg.width) end
    local init = function(b) U:DressGameAura(b) end
    c:AddAuraGroup("harm", "HARMFUL", { maxFrameCount = MAX_AURAS, initializeFrame = init, layout = GameAuraLayout(cfg.auraSize) })
    c:AddAuraGroup("help", "HELPFUL", { maxFrameCount = MAX_AURAS, initializeFrame = init, layout = GameAuraLayout(cfg.auraSize, true) })
    c:SetUnit("target")
  end)
  if not built then
    self.gameAurasWhy = tostring(err)
    pcall(c.Hide, c)
    return false
  end
  self.gameAuras = c
  return c
end

-- Icon size and row width follow the settings. Out of a fight only: the game doesn't let an
-- add-on touch these while auras are hidden from it.
function U:SizeGameAuras()
  local c = self.gameAuras
  if not c or InCombatLockdown() then return end
  local cfg = self:Cfg("target")
  pcall(function()
    if c.SetFlowLayoutMaximumLineSize then c:SetFlowLayoutMaximumLineSize(cfg.width) end
    c:SetAuraGroupLayout("harm", GameAuraLayout(cfg.auraSize))
    c:SetAuraGroupLayout("help", GameAuraLayout(cfg.auraSize, true))
  end)
  for _, b in ipairs(self.gameAuraButtons or {}) do pcall(b.SetSize, b, cfg.auraSize, cfg.auraSize) end
end

-- True when the game's container is the one showing the target's auras.
function U:UseGameAuras()
  local cfg = self:Cfg("target")
  local want = cfg.auras and cfg.auraGame ~= false
  local c = want and self:GameAuras() or self.gameAuras
  if not c then
    if want and self.gameAurasWhy and not self.gameAurasTold then
      self.gameAurasTold = true
      FUI:Print("target auras: the game's aura container couldn't be used here (%s), so they're VoltUI's own row, which stops in a fight.", self.gameAurasWhy:match("^[^\n]*"))
    end
    return false
  end
  pcall(c.SetShown, c, want and not self.unlocked)
  return want and true or false
end

function U:UpdateAuras()
  if not self.auraRow then return end
  local shown = 0
  if self:UseGameAuras() then
    for i = 1, #self.auras do
      self.auras[i].aura = nil
      self.auras[i]:Hide()
    end
    return
  end
  local on = self:Cfg("target").auras
  if on and not self.unlocked and Safe(UnitExists("target")) ~= false and C_UnitAuras then
    -- In a fight the game refuses reading auras by position; S.AuraList then reads them by
    -- id (1.92.1). Refused both ways isn't a fault to report: nothing shows, and the next
    -- change or combat's end tries again.
    self.seenAuras = self.seenAuras or {}
    local sets, allPlain = {}, true
    for _, filter in ipairs({ "HARMFUL", "HELPFUL" }) do
      local list, plain = S.AuraList("target", filter, MAX_AURAS, self.seenAuras)
      if not list then break end
      allPlain = allPlain and plain
      sets[#sets + 1] = S.AuraIDSet(list)
      for _, it in ipairs(list) do
        if shown >= MAX_AURAS then break end
        shown = shown + 1
        local b = self:AuraButton(shown)
        self:PlaceAura(b, shown)
        self:PaintAura(b, it[1], it[2], filter)
      end
    end
    -- Both read plainly: forget what's gone (other targets' auras included).
    if allPlain and #sets == 2 then S.ForgetAuras(self.seenAuras, sets[1], sets[2]) end
  end
  for i = shown + 1, #self.auras do
    self.auras[i].aura = nil
    self.auras[i]:Hide()
  end
end

-- The auras sit above the target's cast bar when it's up, otherwise above the frame.
function U:AnchorAuras()
  local bar = self.targetBar
  local c = self:Cfg("target")
  local over = (bar and bar:IsShown()) and bar or self.frames.target
  self.auraRow:ClearAllPoints()
  local up = over == self.frames.target and (self:Reach(c)) or 0
  self.auraRow:SetPoint("BOTTOMLEFT", over, "TOPLEFT", 0, 4 + up)
  self.auraRow:SetSize(c.width, c.auraSize)
  self:SizeGameAuras()
end

------------------------------------------------------------------------
-- Combo points
------------------------------------------------------------------------

function U:BuildPips()
  local _, class = UnitClass("player")
  class = Safe(class)
  if class ~= "ROGUE" and class ~= "DRUID" then return end
  local p = self.frames.player
  local kind = Enum.PowerType and Enum.PowerType.ComboPoints
  local n = (kind and Safe(UnitPowerMax("player", kind))) or 5
  if n <= 0 then n = 5 end
  local row = CreateFrame("Frame", nil, p)
  row:SetPoint("TOPLEFT", p, "BOTTOMLEFT", 0, -2)
  row:SetPoint("TOPRIGHT", p, "BOTTOMRIGHT", 0, -2)
  row:SetHeight(6)
  row.pips = {}
  for i = 1, n do
    local b = S.Bar(row)
    b:SetMinMaxValues(i - 1, i) -- fills when the count reaches i, even if the count is secret
    S.BarColor(b, 1, 0.82, 0)
    row.pips[i] = b
  end
  row.druid = class == "DRUID"
  self.pips = row
  self:LayoutPips()
end

function U:LayoutPips()
  local row = self.pips
  if not row then return end
  local n = #row.pips
  local w = ((row.kWidth or self:Cfg("player").width) - (n - 1) * 2) / n
  for i, b in ipairs(row.pips) do
    b:SetSize(w, PIP_H)
    b:ClearAllPoints()
    b:SetPoint("LEFT", row, "LEFT", (i - 1) * (w + 2), 0)
  end
end

function U:UpdatePips()
  local row = self.pips
  if not row then return end
  local cur = 0
  if GetComboPoints then
    cur = GetComboPoints("player", "target")
  elseif Enum.PowerType then
    cur = UnitPower("player", Enum.PowerType.ComboPoints)
  end
  for _, b in ipairs(row.pips) do b:SetValue(cur) end
  -- A Druid only needs them while they have some. A secret count stays shown.
  local shown = not row.druid or Safe(cur) ~= 0
  row:SetShown(shown)
  if row.kShown ~= shown then
    row.kShown = shown
    self:FitPlate(self.frames.player)
  end
end

------------------------------------------------------------------------
-- Border (1.94.0)
------------------------------------------------------------------------
-- A frame's border is one of five looks: the hairline it always had, a double line, the
-- action bars' glass plate, a gold rail with the level in a tab above the frame, or none.
-- All of it is VoltUI's own textures and plain frames. (It signalled fights, debuffs and low
-- health until 1.97.1.)

local PLATE_PAD = 6

-- How far the border reaches past the frame, above and below: what sits there moves out.
function U:Reach(c)
  local b = c.border
  if b == "double" then return 3, 3 end
  if b == "plate" then return PLATE_PAD, PLATE_PAD end
  if TabOn(c) then return max(c.levelSize, 8) + 4, 0 end
  return 0, 0
end

-- The plate covers combo points that sit outside the frame, while they show.
function U:FitPlate(f)
  local bd = f.bd
  if not bd or not bd.plateOn then return end
  local top, bottom = PLATE_PAD, PLATE_PAD
  if f.key == "player" and not f.preview then bottom = bottom + (self.below or 0) end
  local row = f.key == "player" and not f.preview and self.pips
  if row and row.kShown ~= false then
    if f.kPipsOut == "top" then
      top = top + PIP_H + 2
    elseif f.kPipsOut == "bottom" then
      bottom = bottom + PIP_H + 2
    end
  end
  bd.plate:ClearAllPoints()
  bd.plate:SetPoint("TOPLEFT", f, "TOPLEFT", -PLATE_PAD, top)
  bd.plate:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", PLATE_PAD, -bottom)
end

function U:Border(f, c)
  c = c or self:Cfg(f.key)
  local style, T = c.border, S.UI
  local p = S.Panel(f)
  local bd = f.bd
  if not bd then
    bd = {}
    bd.gap = S.Edges(f, "BACKGROUND", -7, f, 2)
    S.EdgeWidth(bd.gap, 2)
    bd.outer = S.Edges(f, "BACKGROUND", -7, f, 3)
    bd.plate = S.Tex(f, "BACKGROUND", -8)
    bd.plateEdges = S.Edges(f, "BACKGROUND", -7, bd.plate)
    bd.rail = S.Tex(f, "BACKGROUND", -7)
    bd.rail:SetPoint("TOPLEFT", f, "TOPLEFT", -5, 0)
    bd.rail:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", -5, 0)
    bd.rail:SetWidth(4)
    bd.tab = CreateFrame("Frame", nil, f)
    bd.tabFill = S.Tex(bd.tab, "BACKGROUND", -8)
    bd.tabFill:SetAllPoints()
    bd.tabEdges = S.Edges(bd.tab, "BACKGROUND", -7)
    f.bd = bd
  end
  S.HideEdges(bd.gap)
  S.HideEdges(bd.outer)
  S.HideEdges(bd.plateEdges)
  bd.plate:Hide()
  bd.rail:Hide()
  bd.tab:Hide()
  bd.plateOn, bd.style = nil, style
  p.fill:Show()
  if style == "none" then
    S.HideEdges(p.edges)
  elseif style == "double" then
    S.ColorEdges(bd.gap, T.panel[1], T.panel[2], T.panel[3], 1)
    S.ColorEdges(bd.outer, 0, 0, 0, 1)
  elseif style == "plate" then
    S.HideEdges(p.edges)
    p.fill:Hide()
    S.Paint(bd.plate, T.bg[1], T.bg[2], T.bg[3], 0.55)
    bd.plate:Show()
    S.ColorEdges(bd.plateEdges, T.edge[1], T.edge[2], T.edge[3], 0.8)
    bd.plateOn = true
    self:FitPlate(f)
  elseif style == "rail" then
    S.ColorEdges(p.edges, T.line[1], T.line[2], T.line[3], 1)
    S.Paint(bd.rail, T.accent[1], T.accent[2], T.accent[3], 1)
    bd.rail:Show()
    if TabOn(c) then
      local size = max(c.levelSize, 8)
      bd.tab:ClearAllPoints()
      bd.tab:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", -8, 0)
      bd.tab:SetSize(floor(size * 1.6) + 12, size + 4)
      S.Paint(bd.tabFill, T.panel[1], T.panel[2], T.panel[3], 1)
      S.ColorEdges(bd.tabEdges, T.line[1], T.line[2], T.line[3], 1)
      bd.tabEdges[2]:Hide() -- open at the bottom, onto the frame
      bd.tab:Show()
    end
  end
end

------------------------------------------------------------------------
-- Building
------------------------------------------------------------------------

-- Everything a frame is drawn with: panel, header, bars, texts, portrait and elite glow.
function U:Dress(f)
  S.Panel(f)
  f.strip = S.Header(f)

  f.name = S.Text(f, "GameFontNormalSmall", nil, "OVERLAY", 13)
  f.level = S.Text(f, "GameFontHighlightSmall", "RIGHT", "OVERLAY", 12)
  f.tag = S.Text(f, "GameFontHighlightSmall", "RIGHT", "OVERLAY", 11)
  f.raid = S.Tex(f, "OVERLAY", 1)
  f.raid:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
  f.raid:SetSize(14, 14)
  f.raid:Hide()

  f.hp = S.Bar(f)
  if f.hp.SetClipsChildren then f.hp:SetClipsChildren(true) end -- heals past full are cut off
  -- Incoming heals, then shields, straight after the health.
  f.heal = CreateFrame("StatusBar", nil, f.hp)
  S.UseBarTexture(f.heal)
  f.heal:SetMinMaxValues(0, 1)
  f.heal:SetValue(0)
  f.heal:SetPoint("TOPLEFT", f.hp:GetStatusBarTexture(), "TOPRIGHT", 0, 0)
  f.heal:SetPoint("BOTTOMLEFT", f.hp:GetStatusBarTexture(), "BOTTOMRIGHT", 0, 0)
  f.heal:SetStatusBarColor(HEAL_COLOR[1], HEAL_COLOR[2], HEAL_COLOR[3], HEAL_COLOR[4])
  f.shield = CreateFrame("StatusBar", nil, f.hp)
  S.UseBarTexture(f.shield)
  f.shield:SetMinMaxValues(0, 1)
  f.shield:SetValue(0)
  f.shield:SetPoint("TOPLEFT", f.heal:GetStatusBarTexture(), "TOPRIGHT", 0, 0)
  f.shield:SetPoint("BOTTOMLEFT", f.heal:GetStatusBarTexture(), "BOTTOMRIGHT", 0, 0)
  f.shield:SetStatusBarColor(SHIELD_COLOR[1], SHIELD_COLOR[2], SHIELD_COLOR[3], SHIELD_COLOR[4])
  -- The health text and the overheal edges sit above the heals.
  f.hpTop = CreateFrame("Frame", nil, f) -- not under the bar, which clips: a nudged text can leave it
  f.hpTop:SetAllPoints(f.hp)
  f.hpTop:SetFrameLevel(f.hp:GetFrameLevel() + 3)
  f.overheal = f.hpTop:CreateTexture(nil, "OVERLAY", nil, 6)
  f.overheal:SetTexture(S.WHITE)
  f.overheal:SetPoint("TOPRIGHT", f.hp, "TOPRIGHT", 0, 0)
  f.overheal:SetPoint("BOTTOMRIGHT", f.hp, "BOTTOMRIGHT", 0, 0)
  f.overheal:SetWidth(4)
  f.overheal:SetVertexColor(OVERHEAL_COLOR[1], OVERHEAL_COLOR[2], OVERHEAL_COLOR[3])
  if f.overheal.SetBlendMode then f.overheal:SetBlendMode("ADD") end
  f.overheal:SetAlpha(0)
  f.overshield = f.hpTop:CreateTexture(nil, "OVERLAY", nil, 7)
  f.overshield:SetTexture(S.WHITE)
  f.overshield:SetPoint("TOPRIGHT", f.hp, "TOPRIGHT", 0, 0)
  f.overshield:SetPoint("BOTTOMRIGHT", f.hp, "BOTTOMRIGHT", 0, 0)
  f.overshield:SetWidth(2)
  f.overshield:SetVertexColor(1, 1, 1)
  f.overshield:SetAlpha(0)
  f.hpText = S.Text(f.hpTop, "GameFontHighlightSmall", "RIGHT", "OVERLAY", 12, "OUTLINE")
  f.hpText:SetPoint("RIGHT", -5, 0)
  f.hpPct = S.Text(f.hpTop, "GameFontHighlightSmall", nil, "OVERLAY", 12, "OUTLINE")
  f.hpPct:SetPoint("LEFT", 5, 0)
  f.pw = S.Bar(f)
  f.pwText = S.Text(f.pw, "GameFontHighlightSmall", "RIGHT", "OVERLAY", 10, "OUTLINE")
  f.pwText:SetPoint("RIGHT", -5, 0)

  f.portrait2d = S.Tex(f, "ARTWORK")
  f.portrait2d:SetTexCoord(0.15, 0.85, 0.15, 0.85)
  f.portrait2d:Hide()

  -- Above the bars, or the elite outline and glow would be hidden behind them.
  f.over = CreateFrame("Frame", nil, f)
  f.over:SetAllPoints(f)
  f.over:SetFrameLevel(f:GetFrameLevel() + 5)
  f.eliteGlow = S.Glow(f.over, f.over, 20)
  S.GlowOff(f.eliteGlow)
end

-- A second copy of a frame for the settings window, since the window often covers the real
-- one. It isn't a unit button: nothing to click, and it always shows you, as the real frames do
-- while they're being moved. Laid out from the same settings by the same code.
function U:Preview(key, parent)
  self.previews = self.previews or {}
  local f = self.previews[key]
  if not f then
    f = CreateFrame("Frame", nil, parent)
    f.key, f.unit, f.realUnit, f.preview = key, "player", "player", true
    self:Dress(f)
    self.previews[key] = f
  end
  self:Layout(f)
  self:Update(f)
  self:Zones(f)
  f:Show()
  local c = self:Cfg(key)
  local _, height = self:Rows(f, c)
  return f, height * c.scale, c.scale
end

------------------------------------------------------------------------
-- Picking a part in the preview (1.96.0)
------------------------------------------------------------------------
-- Each part of the preview can be clicked. The settings page then shows a card for that
-- part alone, above its other cards (Pages.lua, Pinned). Only the preview has these:
-- the real frames are for targeting.

local function TextPart(piece)
  return function(f)
    local fs = f[piece]
    if fs and fs:IsShown() then return fs, 2 end
  end
end

-- The parts, from the back to the front: where two overlap, the later one takes the click.
-- region(f, c) gives what the part covers and how far past its edges a click still counts,
-- or nothing while the part isn't showing.
U.PARTS = {
  { key = "frame", name = "Frame and border", region = function(f) return f, 6 end },
  { key = "panel", name = "Name panel", region = function(f) if f.strip:IsShown() then return f.strip, 0 end end },
  { key = "hp", name = "Health bar", region = function(f) return f.hp, 0 end },
  { key = "pw", name = "Power bar", region = function(f, c) if c.power then return f.pw, 0 end end },
  { key = "portrait", name = "Portrait", region = function(f, c)
      if c.portrait == "3d" and f.portrait3d then return f.portrait3d, 0 end
      if c.portrait == "2d" then return f.portrait2d, 0 end
    end },
  { key = "name", name = "Name", region = TextPart("name") },
  { key = "level", name = "Level", region = TextPart("level") },
  { key = "tag", name = "Status tags", region = TextPart("tag") },
  { key = "hpText", name = "Health numbers", region = TextPart("hpText") },
  { key = "hpPct", name = "Health percent", region = TextPart("hpPct") },
  { key = "pwText", name = "Power numbers", region = TextPart("pwText") },
}

function U:PartName(key) return S.PartName(self.PARTS, key) end

-- The part picked on a frame's page, if any. The picking itself is shared (Style.lua).
function U:Picked(key) return S.Picked(key) end
function U:Pick(key, part) S.Pick(key, part) end

-- Click zones on a preview; the real frames are for targeting and get none.
function U:Zones(f)
  if not f or not f.preview then return end
  S.PickZones(f, f.key, self.PARTS, self:Cfg(f.key))
end

function U:Make(key, unit, name)
  local f = self.frames[key]
  if f then return f end
  f = CreateFrame("Button", name, UIParent, "SecureUnitButtonTemplate")
  f.key, f.unit, f.realUnit = key, unit, unit
  f:SetFrameStrata("LOW")
  f:SetClampedToScreen(true)
  f:SetAttribute("unit", unit)
  f:SetAttribute("type1", "target")
  f:SetAttribute("type2", "togglemenu")
  f:RegisterForClicks("AnyUp")
  f:HookScript("OnEnter", function(self)
    if GameTooltip_SetDefaultAnchor then GameTooltip_SetDefaultAnchor(GameTooltip, self) end
    GameTooltip:SetUnit(self.unit)
    GameTooltip:Show()
  end)
  f:HookScript("OnLeave", function() GameTooltip:Hide() end)
  f:HookScript("OnShow", function(self) U:Update(self) end)
  self:Dress(f)

  f.mover = S.Mover(f, name:gsub("^VoltUI", ""):gsub("Frame$", ""), function()
    S.KeepSpot(f, ns.db, key .. "Left", key .. "Top", key .. "Point")
  end, { spot = function() return ns.db, key .. "Left", key .. "Top", key .. "Point" end })

  _G.ClickCastFrames = _G.ClickCastFrames or {}
  _G.ClickCastFrames[f] = true
  self.frames[key] = f
  self.byUnit[unit] = f
  return f
end

-- (1.93.0) Each text goes on the name panel or a bar, at the left, middle or right, moved by
-- its nudge. Texts that share a side line up outward from the edge. The name is cut short
-- where it would run into what's on the other side. The raid marker stays beside the tags.
function U:PlaceTexts(f, c)
  local boxes = {
    name = { region = f.strip, parent = f.over, shown = PanelUsed(c) }, -- above the bars, for a text nudged over one
    hp = { region = f.hp, parent = f.hpTop, shown = true },
    pw = { region = f.pw, parent = f.pw, shown = c.power },
  }
  local size = {
    name = max(c.nameSize, 8), level = max(c.levelSize, 8), tag = max(c.tagSize, 8),
    hpText = c.barSize, hpPct = c.hpPctSize, pwText = c.pwSize,
  }
  local role = {
    name = "frames.name", level = "frames.level", tag = "frames.level",
    hpText = "frames.health", hpPct = "frames.health", pwText = "frames.power",
  }
  local where = {}
  for piece in pairs(PIECE_HOME) do
    local fs = f[piece]
    local box = boxes[c[piece .. "At"]] or boxes[PIECE_HOME[piece][1]]
    local on = PieceOn(c, piece) and box.shown and true or false
    -- the health numbers also say Dead, Ghost or Offline, with only the percent on
    local placed = on or (piece == "hpText" and c.hpPct and box.shown) or false
    local align = c[piece .. "Align"]
    if align ~= "left" and align ~= "center" and align ~= "right" then align = PIECE_HOME[piece][2] end
    fs:SetParent(box.parent)
    -- on a bar, an outline keeps the text readable over the fill
    S.SetFont(fs, size[piece], box ~= boxes.name and "OUTLINE" or nil, role[piece])
    fs:ClearAllPoints()
    fs:SetJustifyH(align == "center" and "CENTER" or align == "left" and "LEFT" or "RIGHT")
    fs:SetShown(on)
    where[piece] = placed and { box = box, align = align } or nil
    if piece == "level" and TabOn(c) and f.bd then
      fs:SetParent(f.bd.tab)
      S.SetFont(fs, size[piece], nil, role[piece])
      fs:SetJustifyH("CENTER")
      fs:SetPoint("CENTER", f.bd.tab, "CENTER", 0, 0)
      fs:SetShown(true)
      where[piece] = nil
    end
  end
  f.raid:SetParent((where.tag and where.tag.box or boxes.name).parent)
  f.raid:ClearAllPoints()

  for _, box in pairs(boxes) do
    local region = box.region
    local lastLeft, lastRight
    local prev
    for _, piece in ipairs(FROM_LEFT) do
      local w = where[piece]
      if w and w.box == box and w.align == "left" then
        local fs, x, y = f[piece], c[piece .. "X"] or 0, c[piece .. "Y"] or 0
        if prev then
          fs:SetPoint("LEFT", prev, "RIGHT", PAD + x, y)
        else
          fs:SetPoint("LEFT", region, "LEFT", PAD + x, y)
        end
        prev = fs
        if piece == "tag" then
          f.raid:SetPoint("LEFT", fs, "RIGHT", 4, 0)
          prev = f.raid
        end
      end
    end
    lastLeft, prev = prev, nil
    for _, piece in ipairs(FROM_RIGHT) do
      local w = where[piece]
      if w and w.box == box and w.align == "right" and piece ~= "name" then
        local fs, x, y = f[piece], c[piece .. "X"] or 0, c[piece .. "Y"] or 0
        if prev then
          fs:SetPoint("RIGHT", prev, "LEFT", -PAD + x, y)
        else
          fs:SetPoint("RIGHT", region, "RIGHT", -PAD + x, y)
        end
        prev = fs
        if piece == "tag" then
          f.raid:SetPoint("RIGHT", fs, "LEFT", -4, 0)
          prev = f.raid
        end
      end
    end
    lastRight, prev = prev, nil
    for _, piece in ipairs(FROM_LEFT) do
      local w = where[piece]
      if w and w.box == box and w.align == "center" and piece ~= "name" then
        local fs, x, y = f[piece], c[piece .. "X"] or 0, c[piece .. "Y"] or 0
        if prev then
          fs:SetPoint("LEFT", prev, "RIGHT", PAD + x, y)
        else
          fs:SetPoint("CENTER", region, "CENTER", x, y)
        end
        prev = fs
        if piece == "tag" then
          f.raid:SetPoint("LEFT", fs, "RIGHT", 4, 0)
          prev = f.raid
        end
      end
    end
    -- The name takes the room that's left, so a long one is cut short, not drawn over its neighbours.
    local w = where.name
    if w and w.box == box then
      local fs, x, y = f.name, c.nameX or 0, c.nameY or 0
      if w.align == "left" then
        -- its left point was set above, first in the line
        if lastRight then
          fs:SetPoint("RIGHT", lastRight, "LEFT", -4 + x, y)
        else
          fs:SetPoint("RIGHT", region, "RIGHT", -4 + x, y)
        end
      elseif w.align == "right" then
        if lastRight then
          fs:SetPoint("RIGHT", lastRight, "LEFT", -PAD + x, y)
        else
          fs:SetPoint("RIGHT", region, "RIGHT", -PAD + x, y)
        end
        if lastLeft then
          fs:SetPoint("LEFT", lastLeft, "RIGHT", 4 + x, y)
        else
          fs:SetPoint("LEFT", region, "LEFT", 4 + x, y)
        end
      else
        fs:SetPoint("LEFT", region, "LEFT", PAD + x, y)
        fs:SetPoint("RIGHT", region, "RIGHT", -PAD + x, y)
      end
    end
  end
  if not where.tag then f.raid:SetPoint("RIGHT", f.strip, "RIGHT", -PAD, 0) end
end

-- Combo points outside the frame: clear of the border, or on the plate, and under whatever
-- else hangs below the frame (self.below: a shapeshifted Druid's mana bar, FrameExtras.lua).
-- Only anchors on a plain child frame, so it can run in a fight.
function U:PipsOutside(f, c)
  local row = self.pips
  if not row or not f.kPipsOut then return end
  local up, down = self:Reach(c)
  local onPlate = c.border == "plate"
  row:ClearAllPoints()
  if f.kPipsOut == "top" then
    local y = 2 + (onPlate and 0 or up)
    row:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, y)
    row:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", 0, y)
  else
    local y = -2 - (onPlate and 0 or down) - (self.below or 0)
    row:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 0, y)
    row:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", 0, y)
  end
  row.kWidth = c.width
end

-- Sizes and anchors everything from the frame's settings. Out of combat only.
function U:Layout(f)
  local c = self:Cfg(f.key)
  local rows, height, pipsOut = self:Rows(f, c)
  f:SetSize(c.width, height)
  f:SetScale(c.scale)
  local up, down = self:Reach(c)
  f.kPipsOut = pipsOut
  self:Border(f, c)

  -- Portrait: a square on one side, the full height of the frame.
  local left, right = 1, 1
  local showPortrait = c.portrait ~= "off"
  local size = height - 2
  if showPortrait then
    if c.portraitSide == "left" then left = size + 2 else right = size + 2 end
  end
  local tex = f.portrait2d
  tex:ClearAllPoints()
  tex:SetSize(size, size)
  local point = c.portraitSide == "left" and "TOPLEFT" or "TOPRIGHT"
  local px = c.portraitSide == "left" and 1 or -1
  tex:SetPoint(point, f, point, px, -1)
  tex:SetShown(c.portrait == "2d")
  if c.portrait == "3d" and not f.portrait3d then
    f.portrait3d = CreateFrame("PlayerModel", nil, f)
  end
  if f.portrait3d then
    f.portrait3d:ClearAllPoints()
    f.portrait3d:SetSize(size, size)
    f.portrait3d:SetPoint(point, f, point, px, -1)
    f.portrait3d:SetShown(c.portrait == "3d")
  end
  f.portraitGUID = nil

  -- The rows, top to bottom in the order chosen.
  local at = {}
  for _, r in ipairs(rows) do at[r.key] = r end
  local function Row(region, r)
    region:ClearAllPoints()
    if not r then return end
    region:SetPoint("TOPLEFT", f, "TOPLEFT", left, -r.y)
    region:SetPoint("TOPRIGHT", f, "TOPRIGHT", -right, -r.y)
    region:SetHeight(r.h)
  end
  f.strip:SetShown(at.name ~= nil)
  Row(f.strip, at.name)
  Row(f.hp, at.hp)
  -- A heal bar is as wide as the health bar, so its numbers fill the same way.
  f.heal:SetWidth(max(1, c.width - left - right))
  f.shield:SetWidth(max(1, c.width - left - right))
  f.pw:SetShown(c.power)
  Row(f.pw, at.pw)
  if not at.pw then
    f.pw:SetPoint("TOPLEFT", f.hp, "BOTTOMLEFT", 0, -1)
    f.pw:SetPoint("TOPRIGHT", f.hp, "BOTTOMRIGHT", 0, -1)
    f.pw:SetHeight(c.pwHeight)
  end
  self:PlaceTexts(f, c)

  if f.preview then return end -- the pips and the target's auras belong to the real frames
  if f.key == "player" and self.pips then
    local row = self.pips
    row:ClearAllPoints()
    row:SetHeight(PIP_H)
    if at.pips then
      row:SetPoint("TOPLEFT", f, "TOPLEFT", left, -at.pips.y)
      row:SetPoint("TOPRIGHT", f, "TOPRIGHT", -right, -at.pips.y)
      row.kWidth = max(1, c.width - left - right)
    else
      self:PipsOutside(f, c)
    end
  end
  -- What sits above the frame keeps clear of the border.
  local bar = f.key == "target" and self.targetBar or f.key == "focus" and self.focusBar
  if bar then
    bar:ClearAllPoints()
    bar:SetPoint("BOTTOMLEFT", f, "TOPLEFT", 0, 3 + up)
    bar:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", 0, 3 + up)
  end
  if f.key == "player" then self:AnchorTotems() end
  if f.preview then return end -- the pips and the target's auras belong to the real frames
  if f.key == "player" then self:LayoutPips() end
  if f.key == "target" and self.auraRow then
    self:AnchorAuras()
    self:UpdateAuras()
  end
end

function U:LayoutAll()
  for _, f in pairs(self.frames) do self:Layout(f) end
  self:Place()
end

function U:Build()
  if self.frames.player then return end
  local p = self:Make("player", "player", "VoltUIPlayerFrame")
  local t = self:Make("target", "target", "VoltUITargetFrame")
  local tot = self:Make("tot", "targettarget", "VoltUIToTFrame")
  local pet = self:Make("pet", "pet", "VoltUIPetFrame")
  local focus = self:Make("focus", "focus", "VoltUIFocusFrame")
  for _, f in ipairs({ t, tot, pet, focus }) do RegisterUnitWatch(f) end
  -- Its own cast bar, above it, the same height as the target frame's.
  local fbar = ns.Castbar:Make("VoltUIFocusCastbar", "focus", focus)
  fbar:SetPoint("BOTTOMLEFT", focus, "TOPLEFT", 0, 3)
  fbar:SetPoint("BOTTOMRIGHT", focus, "TOPRIGHT", 0, 3)
  fbar.off = not ns.db.focusCast or nil
  self.focusBar = fbar
  ns.Castbar.focus = fbar

  -- There's no event when your target's target changes, so that frame checks.
  local elapsed = 0
  tot:SetScript("OnUpdate", function(self, dt)
    elapsed = elapsed + dt
    if elapsed < 0.25 then return end
    elapsed = 0
    U:Update(self, true)
  end)

  self.auraRow = CreateFrame("Frame", nil, t)
  local bar = ns.Castbar:Make("VoltUITargetCastbar", "target", t)
  bar:SetPoint("BOTTOMLEFT", t, "TOPLEFT", 0, 3)
  bar:SetPoint("BOTTOMRIGHT", t, "TOPRIGHT", 0, 3)
  bar.off = not ns.db.targetCast or nil
  bar:HookScript("OnShow", function() U:AnchorAuras() end)
  bar:HookScript("OnHide", function() U:AnchorAuras() end)
  self.targetBar = bar
  ns.Castbar.target = bar
  ns.Castbar:LayoutAll()
  self:BuildPips()
  self:LayoutAll()
end

-- Default spots sit either side of the middle, just above the action bars.
function U:Place()
  local w, h = UIParent:GetWidth(), UIParent:GetHeight()
  local db, fr = ns.db, self.frames
  local x, y = floor(w * 0.115), floor(h * 0.29)
  local spots = {
    player = { "CENTER", UIParent, "BOTTOM", -x, y },
    target = { "CENTER", UIParent, "BOTTOM", x, y },
    tot = { "TOPLEFT", fr.target, "TOPRIGHT", 6, 0 },
    pet = { "TOPRIGHT", fr.player, "TOPLEFT", -6, 0 },
    focus = { "BOTTOMRIGHT", fr.player, "TOPLEFT", -6, 34 }, -- up and to the left of the player frame
  }
  for _, key in ipairs(FRAME_KEYS) do
    local f = fr[key]
    if not S.PlaceSpot(f, db, key .. "Left", key .. "Top", key .. "Point") then
      local s = spots[key]
      f:ClearAllPoints()
      f:SetPoint(s[1], s[2], s[3], s[4], s[5])
    end
  end
end

-- One frame back to its defaults, spot included.
function U:ResetFrame(key)
  local db = ns.db
  db.frameCfg = db.frameCfg or {}
  db.frameCfg[key] = { classColor = DEFAULTS[key].classColor, scale = DEFAULTS[key].scale }
  S.ClearSpot(db, key .. "Left", key .. "Top", key .. "Point")
  local f = self.frames[key]
  self:Layout(f)
  self:Place()
  self:Update(f)
  if key == "target" then
    db.targetCast, db.targetCastH = FUI.defaults.targetCast, FUI.defaults.targetCastH
    ns.Castbar:SetTargetBar(db.targetCast)
    ns.Castbar:LayoutAll()
  end
end

------------------------------------------------------------------------
-- Blizzard's frames
------------------------------------------------------------------------

local function Gone(fr)
  if type(fr) ~= "table" then return end
  if UnregisterUnitWatch then pcall(UnregisterUnitWatch, fr) end
  pcall(fr.UnregisterAllEvents, fr)
  pcall(fr.Hide, fr)
  pcall(fr.SetParent, fr, S.HiddenParent())
  for _, k in ipairs({ "healthbar", "healthBar", "HealthBar", "manabar", "ManaBar", "spellbar" }) do
    local part = fr[k]
    if type(part) == "table" then pcall(part.UnregisterAllEvents, part) end
  end
end

-- Totems live inside Blizzard's player frame, so they move out before it goes.
function U:AnchorTotems()
  local tf = self.totems
  if not tf or self.anchoring then return end
  if InCombatLockdown() and tf.IsProtected and tf:IsProtected() then
    self.totemsPending = true
    return
  end
  self.anchoring = true
  tf:ClearAllPoints()
  tf:SetPoint("BOTTOMLEFT", self.frames.player, "TOPLEFT", 0, 4 + (self:Reach(self:Cfg("player"))))
  self.anchoring = false
  self.totemsPending = nil
end

function U:HideBlizzard()
  local tf = _G.TotemFrame
  if type(tf) == "table" then
    self.totems = tf
    -- Each time the totem frame shows, the game's own OnShow hands it to a container inside its
    -- player frame (ManagedFrameMixin: ClearAllPoints, SetParent). That frame is hidden here, so
    -- the totem buttons went with it and took no clicks: no right-click to destroy a totem
    -- (1.101.3). The script goes; the game lays the buttons out from its Update anyway.
    pcall(tf.SetScript, tf, "OnShow", nil)
    pcall(tf.SetParent, tf, UIParent)
    self:AnchorTotems()
    hooksecurefunc(tf, "SetPoint", function() U:AnchorTotems() end)
  end
  for _, name in ipairs({ "PlayerFrame", "PetFrame", "TargetFrame", "TargetFrameToT", "TargetFrameSpellBar", "ComboFrame",
                          "FocusFrame", "FocusFrameToT", "FocusFrameSpellBar" }) do
    Gone(_G[name])
  end
end

------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------

local function TargetChanged()
  U:Update(U.frames.target)
  U:Update(U.frames.tot)
  U:UpdateAuras()
  U:UpdatePips()
  if not (PlaySound and SOUNDKIT) then return end
  if Safe(UnitExists("target")) == false then
    if SOUNDKIT.INTERFACE_SOUND_LOST_TARGET_UNIT then PlaySound(SOUNDKIT.INTERFACE_SOUND_LOST_TARGET_UNIT) end
  elseif Safe(UnitIsEnemy("target", "player")) then
    if SOUNDKIT.IG_CREATURE_AGGRO_SELECT then PlaySound(SOUNDKIT.IG_CREATURE_AGGRO_SELECT) end
  elseif Safe(UnitIsFriend("target", "player")) then
    if SOUNDKIT.IG_CHARACTER_NPC_SELECT then PlaySound(SOUNDKIT.IG_CHARACTER_NPC_SELECT) end
  elseif SOUNDKIT.IG_CREATURE_NEUTRAL_SELECT then
    PlaySound(SOUNDKIT.IG_CREATURE_NEUTRAL_SELECT)
  end
end

local HANDLERS = {
  UNIT_HEALTH = "UpdateHealth", UNIT_MAXHEALTH = "UpdateHealth",
  UNIT_HEAL_PREDICTION = "UpdateHealth", UNIT_ABSORB_AMOUNT_CHANGED = "UpdateHealth",
  UNIT_POWER_UPDATE = "UpdatePower", UNIT_POWER_FREQUENT = "UpdatePower", UNIT_MAXPOWER = "UpdatePower",
  UNIT_DISPLAYPOWER = "UpdatePower", UNIT_NAME_UPDATE = "UpdateName", UNIT_LEVEL = "UpdateLevel",
  UNIT_FACTION = "UpdateColor", UNIT_CLASSIFICATION_CHANGED = "UpdateTag", UNIT_FLAGS = "UpdateTag",
}

local function OnEvent(_, event, unit)
  local method = HANDLERS[event]
  if method then
    local f = U.byUnit[unit]
    if f then
      U[method](U, f)
      if event == "UNIT_FACTION" then
        U:UpdateName(f)
        U:UpdateTag(f)
      elseif event == "UNIT_CLASSIFICATION_CHANGED" then
        U:UpdateElite(f)
      end
    end
    if unit == "player" and (event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER") then U:UpdatePips() end
  elseif event == "UNIT_PORTRAIT_UPDATE" or event == "UNIT_MODEL_CHANGED" then
    local f = U.byUnit[unit]
    if f then U:UpdatePortrait(f, true) end
  elseif event == "PLAYER_TARGET_CHANGED" then
    TargetChanged()
  elseif event == "UNIT_TARGET" then
    if unit == "target" then U:Update(U.frames.tot) end
  elseif event == "UNIT_AURA" then
    if unit == "target" then U:UpdateAuras() end
  elseif event == "UNIT_PET" then
    if unit == "player" then U:Update(U.frames.pet) end
  elseif event == "PLAYER_FOCUS_CHANGED" then
    U:Update(U.frames.focus)
  elseif event == "RAID_TARGET_UPDATE" then
    U:UpdateRaidIcon(U.frames.player)
    U:UpdateRaidIcon(U.frames.target)
    U:UpdateRaidIcon(U.frames.focus)
  elseif event == "PLAYER_REGEN_DISABLED" then
    if U.unlocked then
      FUI:SetUnlocked(false)
      FUI:Print("moving frames stopped: you're in combat.")
    end
    U:UpdateTag(U.frames.player)
  elseif event == "PLAYER_REGEN_ENABLED" then
    if U.totemsPending then U:AnchorTotems() end
    U:UpdateTag(U.frames.player)
    U:UpdateAuras()
  elseif event == "PLAYER_UPDATE_RESTING" or event == "PLAYER_FLAGS_CHANGED"
    or event == "PARTY_LEADER_CHANGED" or event == "GROUP_ROSTER_UPDATE" then
    U:UpdateTag(U.frames.player)
    U:UpdateTag(U.frames.target)
    U:UpdateTag(U.frames.focus)
  elseif event == "PLAYER_ENTERING_WORLD" then
    U:UpdateAll()
  end
end

function U:Events()
  local ev = CreateFrame("Frame")
  for e in pairs(HANDLERS) do pcall(ev.RegisterEvent, ev, e) end -- a client without heal prediction events still works
  for _, e in ipairs({
    "PLAYER_TARGET_CHANGED", "UNIT_TARGET", "UNIT_AURA", "UNIT_PET", "RAID_TARGET_UPDATE",
    "UNIT_PORTRAIT_UPDATE", "UNIT_MODEL_CHANGED",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_UPDATE_RESTING", "PLAYER_FLAGS_CHANGED",
    "PARTY_LEADER_CHANGED", "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD",
  }) do
    ev:RegisterEvent(e)
  end
  pcall(ev.RegisterEvent, ev, "PLAYER_FOCUS_CHANGED") -- a client without focus still works
  ev:SetScript("OnEvent", OnEvent)
end

------------------------------------------------------------------------
-- Edit mode and settings
------------------------------------------------------------------------

-- In edit mode the target, target-of-target and pet frames stay up, showing you, so they can be placed.
function U:SetUnlocked(on)
  on = on or nil
  if not self.started or self.unlocked == on then return end
  self.unlocked = on
  if not on then self.previewClass = nil end
  local previews = { self.frames.target, self.frames.tot, self.frames.pet, self.frames.focus }
  for _, f in ipairs(previews) do
    if on then
      UnregisterUnitWatch(f)
      f.unit = "player"
      f:Show()
      self:Update(f)
    else
      f.unit = f.realUnit
      RegisterUnitWatch(f)
      self:Update(f)
    end
  end
  for _, f in pairs(self.frames) do f.mover:SetShown(on) end
  self:UpdateAuras()
end

function U:Refresh()
  if not self.started then return end
  for _, f in pairs(self.frames) do self:Border(f) end -- the panel, then the border's look over it
  if self.targetBar then S.Panel(self.targetBar) end
  self:UpdateAll()
end

function U:Slash(arg)
  local cmd, rest = (arg or ""):match("^(%S*)%s*(.-)$")
  local n = tonumber(rest)
  local db = ns.db
  if not self.started then
    FUI:Print("The unit frames are off. /volt frames on, then /reload.")
  elseif cmd == "unlock" or cmd == "lock" then
    FUI:SetUnlocked(cmd == "unlock")
  elseif InCombatLockdown() and (cmd == "scale" or cmd == "reset") then
    FUI:Print("That can't change in combat.")
  elseif cmd == "scale" and n then
    db.frameScale = math.max(0.5, math.min(2, n))
    for _, key in ipairs(FRAME_KEYS) do self:Cfg(key).scale = db.frameScale end
    self:LayoutAll()
    FUI:Print("unit frame scale %.2f", db.frameScale)
  elseif cmd == "class" then
    db.classColor = not db.classColor
    for _, key in ipairs(FRAME_KEYS) do self:Cfg(key).classColor = db.classColor end
    self:UpdateAll()
    FUI:Print("class colours on player health: %s", db.classColor and "on" or "off")
  elseif cmd == "reset" then
    db.classColor, db.frameScale = FUI.defaults.classColor, FUI.defaults.frameScale
    for _, key in ipairs(FRAME_KEYS) do self:ResetFrame(key) end
    FUI:Print("unit frames back to their default spots and settings.")
  else
    FUI:Print("/volt edit opens the edit mode. Also /volt frames scale 0.5-2 · class · reset · on|off")
  end
end

function U:Start()
  if self.started then return end
  self.started = true
  self:Build()
  self:HideBlizzard()
  self:Events()
  self:UpdateAll()
end

-- Secure frames can't be made or moved in combat. A /reload in combat waits until it ends.
function U:Enable()
  self.enabled = true
  if not InCombatLockdown() then return self:Start() end
  local wait = CreateFrame("Frame")
  wait:RegisterEvent("PLAYER_REGEN_ENABLED")
  wait:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    U:Start()
  end)
end

FUI:Register(U)
