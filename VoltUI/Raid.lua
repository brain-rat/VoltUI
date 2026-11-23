-- VoltUI · Party and raid frames
-- VoltUI's own party and raid frames. Since VoltUI 1.25.0 they replace the game's, which are
-- hidden while these are on (switch the part off and /reload for the game's back).
--
-- Each tile shows health (with incoming heals and shields), power, name, role, Dead /
-- Ghost / Offline, missing health or percent, borders on your target, aggro and the mouse,
-- fades out of range, and carries debuffs (RaidAuras.lua). Size, layout and what's shown
-- are VoltUI's settings (VoltUIDB.raidCfg), in four sets: party and raid, each with its own heal
-- mode set (HealMode.lua). The party header uses a party set, the raid groups a raid set.
--
-- How they're built, because they're secure and work in combat:
--  * One SecureGroupHeaderTemplate per raid group, and one for the party. The game makes and
--    fills the member buttons (SecureUnitButtonTemplate), in combat too; its snippet asks
--    VoltUI to dress each new one (InitTile) through CallMethod.
--  * Layout (size, sorting, where groups go) is set out of combat only, and waits for a
--    fight to end. Member buttons are never shown, hidden or moved by VoltUI.
--  * Health, range and incoming heals are secret values on this client, and aura details,
--    power and threat are secret in a fight. They're handed to the bars and texts that take
--    them (SetValue, SetFormattedText, SetAlphaFromBoolean, SetAlpha) and never compared.
--  * The game's party and raid frames are moved under a hidden parent and stop listening,
--    out of combat; their member buttons are protected.

local _, ns = ...
local FUI, S = ns.FUI, ns.Style

local R = {
  key = "groups", name = "Party and raid frames",
  tiles = {}, byUnit = {}, headers = {}, titles = {}, reported = {}, missing = {},
  hiddenGame = {}, pendingClicks = {}, sim = nil,
}
ns.Raid = R

local Safe, IsSecret = S.Safe, S.IsSecret
local floor, max, min = math.floor, math.max, math.min

local FRIENDLY = { 0.3, 0.7, 0.35 }
local GREY = { 0.5, 0.5, 0.5 }
local DARK = { 0.13, 0.14, 0.17 } -- the health bar in the dark style; the missing part shows the class colour
local AGGRO = { 1, 0.25, 0.2 }
local HEAL_COLOR = { 0.35, 0.9, 0.45, 0.45 }
local SHIELD_COLOR = { 1, 1, 1, 0.5 }
local OVERHEAL_COLOR = { 0.55, 1, 0.6 }
local POWER = {
  MANA = { 0.25, 0.5, 0.95 }, RAGE = { 0.85, 0.25, 0.25 }, ENERGY = { 0.95, 0.8, 0.25 },
  FOCUS = { 0.95, 0.55, 0.25 }, RUNIC_POWER = { 0, 0.82, 1 },
}
local ROLE_ATLAS = { TANK = "roleicon-tiny-tank", HEALER = "roleicon-tiny-healer", DAMAGER = "roleicon-tiny-dps" }
local TITLE_H = 14
R.TITLE_H = TITLE_H

-- A friendly heal per class, to fade members out of your heal range (plain answers).
-- Everyone else uses the game's range check, which is secret and faded with SetAlphaFromBoolean.
local RANGE_SPELLS = { PRIEST = { 2050, 2061 }, PALADIN = { 635, 19750 }, DRUID = { 5185, 774 }, SHAMAN = { 331, 8004 } }

-- The four settings sets: party frames and raid frames, each with a heal mode set used
-- while heal mode is on.
R.SETS = {
  { key = "party", name = "Party frames", kind = "party" },
  { key = "raid", name = "Raid frames", kind = "raid" },
  { key = "healParty", name = "Heal mode: party", kind = "party", heal = true },
  { key = "healRaid", name = "Heal mode: raid", kind = "raid", heal = true },
}
local SET_INFO = {}
for _, s in ipairs(R.SETS) do SET_INFO[s.key] = s end
R.SET_INFO = SET_INFO

-- One settings set. Heal mode's sets differ in places (HealMode.lua).
R.SET_DEFAULTS = {
  width = 72, height = 36, gap = 2, groupGap = 8, scale = 1,
  layout = "columns",   -- columns: a group per column · rows: a group per row
  sort = "group",       -- group (the raid's order) · role · class · name
  showPlayer = true, showSolo = false, titles = true,
  hpColor = "class",    -- class · green · custom · dark
  customColor = { 0.3, 0.7, 0.35 },
  missing = 0.1,        -- how much the missing part of the health bar shows
  hpText = "off",       -- off · missing (-1634) · percent
  heals = true, shields = true,
  overheal = true,      -- a glow at the bar's end when heals or shields come to more than what's missing
  power = "healers",    -- off · healers · all
  powerHeight = 4,
  nameScale = 1, nameColor = "white", statusScale = 1,
  target = "accent", aggro = true, hover = true, roleIcons = true,
  rangeAlpha = 0.5,
  debuffs = true, debuffSize = 14, debuffCount = 3,
  removableFirst = true, onlyRemovable = false, bigRemovable = true,
  hots = true, hotSize = 12, hotCount = 3, -- your own HoTs and shields, with their time left
  corners = true,       -- Earth Shield and Fear Ward in the top right corner
  -- Since 1.47.0, on each tile:
  markers = true,       -- its raid marker
  leader = true,        -- a gold mark on the group's leader
  ready = true,         -- its answer to a ready check
  incoming = true,      -- a resurrection on its way, or a summon waiting
}

-- What the old restyle of the game's frames (VoltUI 1.24 and before) kept, moved over once.
local MOVED = { "hpColor", "missing", "rangeAlpha", "nameScale", "nameColor", "statusScale", "target", "aggro",
  "hover", "roleIcons", "titles" }

local function Copy(v)
  if type(v) ~= "table" then return v end
  local t = {}
  for k, x in pairs(v) do t[k] = x end
  return t
end
R.Copy = Copy

local function Fill(t, defaults)
  for k, v in pairs(defaults) do
    if t[k] == nil then t[k] = Copy(v) end
  end
end
R.Fill = Fill

-- A copy of a whole set, its colour tables included, so two sets never share one.
local function CopySet(t)
  local out = {}
  for k, v in pairs(t) do out[k] = Copy(v) end
  return out
end
R.CopySet = CopySet

-- Up to 1.27 there was one set for party and raid ("normal") and one for heal mode ("heal").
-- Each becomes a party and a raid set, starting the same, so nothing looks different.
function R.SplitSet(c, old, party, raid)
  if type(c[old]) ~= "table" then return end
  if type(c[party]) ~= "table" then c[party] = CopySet(c[old]) end
  if type(c[raid]) ~= "table" then c[raid] = CopySet(c[old]) end
  c[old] = nil
end

function R:Cfg()
  local db = ns.db
  local c = db.raidCfg
  if c ~= nil and c == self.cfg then return c end
  if type(c) ~= "table" then
    c = {}
    db.raidCfg = c
  end
  if not c.moved then
    local old, set = db.groupCfg, {}
    if type(old) == "table" then
      for _, k in ipairs(MOVED) do
        if old[k] ~= nil then set[k] = Copy(old[k]) end
      end
      if set.hpColor == "game" then set.hpColor = "class" end -- that mode was the game's own
      if type(c.normal) ~= "table" and type(c.party) ~= "table" then c.normal = set end
    end
    db.groupCfg, db.groupsRaid, db.groupsParty = nil, nil, nil
    db.groupSimLeft, db.groupSimTop, db.groupSimPoint = nil, nil, nil
    c.moved = true
  end
  R.SplitSet(c, "normal", "party", "raid")
  for _, name in ipairs({ "party", "raid" }) do
    if type(c[name]) ~= "table" then c[name] = {} end
    Fill(c[name], self.SET_DEFAULTS)
  end
  if self.FillExtra then self:FillExtra(c) end -- heal mode's sets (HealMode.lua)
  self.cfg = c
  return c
end

-- Party or raid: which frames are up. Set out of combat (in Apply), so the frames never
-- change their settings halfway through a fight.
local function CurrentKind()
  return (IsInRaid and IsInRaid()) and "raid" or "party"
end

function R:Kind()
  return self.activeKind or CurrentKind()
end

-- Which set is in use for party or raid frames (`kind`, else the ones up now): the plain
-- one, or its heal mode set while heal mode is on.
function R:SetName(kind)
  kind = kind or self:Kind()
  local heal = self.HealOn and self:HealOn()
  if kind == "raid" then return heal and "healRaid" or "raid" end
  return heal and "healParty" or "party"
end

function R:Set(name)
  local c = self:Cfg()
  return c[name or self:SetName()] or c.party
end

-- The set a member tile uses: its header's, party or raid (the preview's tiles have none).
function R:TileSet(f)
  local h = f and f.kheader
  if not h then return self:Set() end
  return self:Set(self:SetName(h.kgroup and "raid" or "party"))
end

function R:IsHealSet(name) return SET_INFO[name] ~= nil and SET_INFO[name].heal == true end
function R:SetKind(name) return SET_INFO[name] and SET_INFO[name].kind or "party" end

-- A set's default for one setting (heal mode's differ in places; HealMode.lua).
function R:DefaultFor(name, key)
  local heal = self:IsHealSet(name) and self.HEAL_DEFAULTS
  if heal and heal[key] ~= nil then return heal[key] end
  return self.SET_DEFAULTS[key]
end

function R:ResetSet(name)
  local c = self:Cfg()
  c[name] = {}
  self.cfg = nil
  self:Cfg()
  self:Apply()
end

-- A game update can rename anything; that should cost no more than one part.
local function Guard(what, fn, ...)
  local ok, err = pcall(fn, ...)
  if not ok and not R.reported[what] then
    R.reported[what] = tostring(err)
    FUI:Print("Party and raid frames: something went wrong with the %s. %s", what, tostring(err))
    if ns.Errors then ns.Errors:Add("Party and raid frames: " .. what, tostring(err), nil, "volt") end
  end
  return ok
end
R.Guard = Guard

------------------------------------------------------------------------
-- Colours and texts
------------------------------------------------------------------------

local function ClassTokenRGB(class)
  if type(class) ~= "string" then return end
  local c = C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(class)
  if c then return c.r, c.g, c.b end
  c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  if c then return c.r, c.g, c.b end
end
R.ClassTokenRGB = ClassTokenRGB

local function UnitClassToken(u)
  if not UnitClass then return end
  local _, class = UnitClass(u)
  return Safe(class)
end

-- The health bar's colour and the track behind it (the missing part) for a set.
local function HealthColors(c, class, offline, dead)
  local cr, cg, cb = ClassTokenRGB(class)
  if not cr then cr, cg, cb = FRIENDLY[1], FRIENDLY[2], FRIENDLY[3] end
  local mode = c.hpColor
  local track = { 1, 1, 1, c.missing or 0.1 }
  if offline then
    if mode == "dark" then track = { GREY[1], GREY[2], GREY[3], 0.5 } end
    return GREY, track
  end
  if mode == "dark" then
    return DARK, dead and { GREY[1], GREY[2], GREY[3], 0.5 } or { cr, cg, cb, 0.85 }
  elseif mode == "green" then
    return FRIENDLY, track
  elseif mode == "custom" then
    local cc = type(c.customColor) == "table" and c.customColor or FRIENDLY
    return { cc[1] or FRIENDLY[1], cc[2] or FRIENDLY[2], cc[3] or FRIENDLY[3] }, track
  end
  return { cr, cg, cb }, track
end
R.HealthColors = HealthColors

local function Font(fs, size, flags, role)
  local px = floor(size * 2 + 0.5) / 2
  local ok = pcall(fs.SetFont, fs, S.Font(nil, role).path, px, flags or "OUTLINE")
  if not ok or (fs.GetFont and not fs:GetFont()) then
    pcall(fs.SetFont, fs, "Fonts\\FRIZQT__.TTF", px, flags or "OUTLINE")
  end
  return px
end
R.Font = Font

local function RoleAtlas(role)
  local atlas = ROLE_ATLAS[role]
  if not atlas then return end
  if type(_G.GetIconForRole) == "function" then
    local ok, a = pcall(_G.GetIconForRole, role, false)
    if ok and type(a) == "string" then atlas = a end
  end
  return atlas
end

-- 1 below full health, 0 at full: fades the missing-health text when the numbers are secret.
local fullCurve
local function FullCurve()
  if fullCurve then return fullCurve end
  local CU = C_CurveUtil
  if CU and CU.CreateCurve then
    local ok, curve = pcall(CU.CreateCurve)
    if ok and curve then
      if Enum and Enum.LuaCurveType and curve.SetType then pcall(curve.SetType, curve, Enum.LuaCurveType.Step) end
      pcall(curve.AddPoint, curve, 0, 1)
      pcall(curve.AddPoint, curve, 1, 0)
      fullCurve = curve
    end
  end
  return fullCurve
end

-- Incoming heals and shields, and the glows for more than is missing: shared with the player
-- frame (Style.lua).
local Predict, ShowIf = S.Predict, S.ShowIf

------------------------------------------------------------------------
-- A tile: built the same on a member button and on a preview frame
------------------------------------------------------------------------

local function BuildTile(f)
  f.kfill = S.Tex(f, "BACKGROUND", -8)
  f.kfill:SetAllPoints(f)
  f.khp = CreateFrame("StatusBar", nil, f)
  S.UseBarTexture(f.khp)
  f.khp:SetMinMaxValues(0, 1)
  if f.khp.SetClipsChildren then f.khp:SetClipsChildren(true) end -- heals past full are cut off
  f.ktrack = S.Tex(f, "BACKGROUND", -7)
  f.ktrack:SetAllPoints(f.khp)
  -- Incoming heals and shields start where the health ends.
  f.kheal = CreateFrame("StatusBar", nil, f.khp)
  S.UseBarTexture(f.kheal)
  f.kheal:SetMinMaxValues(0, 1)
  f.kheal:SetValue(0)
  f.kheal:SetPoint("TOPLEFT", f.khp:GetStatusBarTexture(), "TOPRIGHT", 0, 0)
  f.kheal:SetPoint("BOTTOMLEFT", f.khp:GetStatusBarTexture(), "BOTTOMRIGHT", 0, 0)
  f.kheal:SetStatusBarColor(HEAL_COLOR[1], HEAL_COLOR[2], HEAL_COLOR[3], HEAL_COLOR[4])
  f.kshield = CreateFrame("StatusBar", nil, f.khp)
  S.UseBarTexture(f.kshield)
  f.kshield:SetMinMaxValues(0, 1)
  f.kshield:SetValue(0)
  f.kshield:SetPoint("TOPLEFT", f.kheal:GetStatusBarTexture(), "TOPRIGHT", 0, 0)
  f.kshield:SetPoint("BOTTOMLEFT", f.kheal:GetStatusBarTexture(), "BOTTOMRIGHT", 0, 0)
  f.kshield:SetStatusBarColor(SHIELD_COLOR[1], SHIELD_COLOR[2], SHIELD_COLOR[3], SHIELD_COLOR[4])
  -- Overhealing: more heals coming than health missing. A bright edge at the end of the bar,
  -- and a white one for shields past full health.
  f.koverheal = f.khp:CreateTexture(nil, "OVERLAY", nil, 6)
  f.koverheal:SetTexture(S.WHITE)
  f.koverheal:SetPoint("TOPRIGHT", f.khp, "TOPRIGHT", 0, 0)
  f.koverheal:SetPoint("BOTTOMRIGHT", f.khp, "BOTTOMRIGHT", 0, 0)
  f.koverheal:SetWidth(4)
  f.koverheal:SetVertexColor(OVERHEAL_COLOR[1], OVERHEAL_COLOR[2], OVERHEAL_COLOR[3])
  if f.koverheal.SetBlendMode then f.koverheal:SetBlendMode("ADD") end
  f.koverheal:SetAlpha(0)
  f.koverabsorb = f.khp:CreateTexture(nil, "OVERLAY", nil, 7)
  f.koverabsorb:SetTexture(S.WHITE)
  f.koverabsorb:SetPoint("TOPRIGHT", f.khp, "TOPRIGHT", 0, 0)
  f.koverabsorb:SetPoint("BOTTOMRIGHT", f.khp, "BOTTOMRIGHT", 0, 0)
  f.koverabsorb:SetWidth(2)
  f.koverabsorb:SetVertexColor(1, 1, 1)
  f.koverabsorb:SetAlpha(0)
  f.kpw = S.Bar(f)
  -- Above the bars: texts, the role icon, debuffs and borders.
  f.ktop = CreateFrame("Frame", nil, f)
  f.ktop:SetAllPoints(f)
  f.ktop:SetFrameLevel(f:GetFrameLevel() + 3)
  f.krole = S.Tex(f.ktop, "OVERLAY")
  f.krole:SetSize(12, 12)
  f.krole:SetPoint("TOPLEFT", f, "TOPLEFT", 3, -2)
  f.kname = S.Text(f.ktop, nil, "LEFT", "OVERLAY")
  f.kname:SetPoint("TOPLEFT", f.krole, "TOPRIGHT", 0, -1)
  f.kname:SetPoint("TOPRIGHT", f, "TOPRIGHT", -3, -3)
  f.kstatus = S.Text(f.ktop, nil, "CENTER", "OVERLAY")
  -- Raid marker (top middle), leader mark (top right), ready-check answer (right), and a word
  -- across the middle for a resurrection or summon on its way.
  f.kmark = S.Tex(f.ktop, "OVERLAY", 2)
  f.kmark:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
  f.kmark:SetSize(12, 12)
  f.kmark:SetPoint("TOP", f, "TOP", 0, 5)
  f.kmark:Hide()
  f.klead = S.Tex(f.ktop, "OVERLAY", 2)
  f.klead:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
  f.klead:SetSize(10, 10)
  f.klead:SetPoint("TOPRIGHT", f, "TOPRIGHT", 2, 4)
  f.klead:Hide()
  f.kready = S.Tex(f.ktop, "OVERLAY", 3)
  f.kready:SetSize(14, 14)
  f.kready:SetPoint("RIGHT", f, "RIGHT", -3, 0)
  f.kready:Hide()
  f.kflag = S.Text(f.ktop, nil, "CENTER", "OVERLAY")
  f.kflag:SetPoint("CENTER", f, "CENTER", 0, 1)
  f.kflag:Hide()
  f.kglow = S.Glow(f.ktop, f, 14)
  -- Aggro has its own glow, so a secret threat level can be its opacity.
  f.kaggro = CreateFrame("Frame", nil, f.ktop)
  f.kaggro:SetAllPoints(f)
  f.kaggroGlow = S.Glow(f.kaggro, f, 14)
  S.GlowRGB(f.kaggroGlow, AGGRO[1], AGGRO[2], AGGRO[3], 0.45)
  f.kaggro:SetAlpha(0)
  if ns.RaidAuras then ns.RaidAuras:Build(f) end
end
R.BuildTile = BuildTile

-- Sizes and places what's inside a tile, for a set. `power` says whether its power bar shows.
function R:PaintLayout(f, c, power)
  c = c or self:TileSet(f)
  local w, h = tonumber(c.width) or 72, tonumber(c.height) or 36
  local ph = power and (tonumber(c.powerHeight) or 4) or 0
  f.khp:ClearAllPoints()
  f.khp:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
  f.khp:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1 + (ph > 0 and ph + 1 or 0))
  f.kheal:SetWidth(max(1, w - 2))
  f.kshield:SetWidth(max(1, w - 2))
  f.kpw:ClearAllPoints()
  f.kpw:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1, 1)
  f.kpw:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
  f.kpw:SetHeight(max(1, ph))
  f.kpw:SetShown(ph > 0)
  f.kshowPower = ph > 0
  local scale = min(h / 36, w / 72)
  Font(f.kname, 10 * (tonumber(c.nameScale) or 1), nil, "groups.name")
  local px = Font(f.kstatus, 12 * scale * (tonumber(c.statusScale) or 1), nil, "groups.status")
  f.kstatus:SetHeight(px)
  f.kstatus:ClearAllPoints()
  f.kstatus:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 3, (h - ph) / 3 - 2 + ph)
  f.kstatus:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -3, (h - ph) / 3 - 2 + ph)
  f.krole:SetAlpha(c.roleIcons and 1 or 0)
  f.kfill:SetColorTexture(S.BG[1], S.BG[2], S.BG[3], ns.db.alpha)
  if ns.RaidAuras then ns.RaidAuras:Layout(f, c) end
end

-- Target, mouse or plain; aggro is its own glow on top.
function R:PaintEdge(f, c, target, hover)
  local glow = f.kglow
  if c.target ~= "off" and target then
    if c.target == "white" then
      S.GlowRGB(glow, 1, 1, 1, 0)
    else
      S.GlowRGB(glow, S.ACCENT[1], S.ACCENT[2], S.ACCENT[3], 0)
    end
  elseif c.hover and hover then
    S.GlowOff(glow)
    S.ColorEdges(glow.edges, 1, 1, 1, 0.85)
  else
    S.GlowOff(glow)
    S.ColorEdges(glow.edges, S.EDGE[1], S.EDGE[2], S.EDGE[3], 0.6)
  end
end

------------------------------------------------------------------------
-- A tile with a real member
------------------------------------------------------------------------

local function Role(u)
  if not UnitGroupRolesAssigned then return end
  return Safe(UnitGroupRolesAssigned(u))
end

local function ShowsPower(c, u)
  if c.power == "all" then return true end
  if c.power == "healers" then return Role(u) == "HEALER" end
  return false
end

local function Offline(u) return UnitIsConnected ~= nil and Safe(UnitIsConnected(u)) == false end

local function DeadText(u)
  if Offline(u) then return _G.PLAYER_OFFLINE or "Offline" end
  if UnitIsGhost and Safe(UnitIsGhost(u)) then return _G.GHOST or "Ghost" end
  if UnitIsDeadOrGhost and Safe(UnitIsDeadOrGhost(u)) then return _G.DEAD or "Dead" end
end

function R:UpdateHealth(f)
  local u = f.kunit
  if not u then return end
  local c = self:TileSet(f)
  local maxv = UnitHealthMax(u)
  local cur = UnitHealth(u)
  local offline = Offline(u)
  f.khp:SetMinMaxValues(0, maxv)
  f.khp:SetValue(offline and maxv or cur)
  local heals, shields, healOver, shieldOver = Predict(u)
  f.kheal:SetMinMaxValues(0, maxv)
  S.SetAmount(f.kheal, heals, c.heals and not offline)
  f.kshield:SetMinMaxValues(0, maxv)
  S.SetAmount(f.kshield, shields, c.shields and not offline)
  ShowIf(f.koverheal, healOver, c.heals and c.overheal and not offline)
  ShowIf(f.koverabsorb, shieldOver, c.shields and c.overheal and not offline)
  -- Status: Dead, Ghost, Offline, or the health text.
  local st = f.kstatus
  local gone = DeadText(u)
  st:SetAlpha(1)
  if gone then
    st:SetText(gone)
    st:SetTextColor(GREY[1], GREY[2], GREY[3])
  elseif c.hpText == "missing" then
    st:SetTextColor(1, 1, 1)
    local m = UnitHealthMissing and UnitHealthMissing(u)
    local pc, pm = Safe(cur), Safe(maxv)
    if not IsSecret(m) and m == nil and pc and pm then m = pm - pc end -- secret first: it can't be compared
    if Safe(m) then
      st:SetText(m > 0 and ("-" .. S.ShortNum(m)) or "")
    elseif C_StringUtil and C_StringUtil.TruncateWhenZero then
      -- Secret: the game leaves it empty at full health.
      local s = C_StringUtil.TruncateWhenZero(m)
      if C_StringUtil.WrapString then s = C_StringUtil.WrapString(s, "-") end
      st:SetText(s)
    else
      st:SetFormattedText("-%s", S.ShortNum(m))
      local curve = FullCurve()
      if curve and UnitHealthPercent then st:SetAlpha(UnitHealthPercent(u, false, curve)) end
    end
  elseif c.hpText == "percent" then
    st:SetTextColor(1, 1, 1)
    st:SetFormattedText("%s%%", S.HealthPercent(u, cur, maxv))
  else
    st:SetText("")
  end
  self:UpdateColor(f)
end

function R:UpdateColor(f)
  local u = f.kunit
  if not u then return end
  local c = self:TileSet(f)
  local dead = UnitIsDeadOrGhost and Safe(UnitIsDeadOrGhost(u)) or false
  local bar, track = HealthColors(c, UnitClassToken(u), Offline(u), dead)
  S.BarColor(f.khp, bar[1], bar[2], bar[3])
  f.ktrack:SetColorTexture(track[1], track[2], track[3], track[4])
end

function R:UpdatePower(f)
  local u = f.kunit
  if not u then return end
  local c = self:TileSet(f)
  local want = ShowsPower(c, u)
  if want ~= f.kshowPower then self:PaintLayout(f, c, want) end
  if not want then return end
  local _, token = UnitPowerType(u)
  local pc = POWER[Safe(token) or "MANA"] or POWER.MANA
  S.BarColor(f.kpw, pc[1], pc[2], pc[3])
  f.kpw:SetMinMaxValues(0, UnitPowerMax(u))
  f.kpw:SetValue(Offline(u) and 0 or UnitPower(u))
end

function R:UpdateName(f)
  local u = f.kunit
  if not u then return end
  local c = self:TileSet(f)
  local name = UnitName and UnitName(u)
  if Safe(name) then
    name = name:match("^([^%-]+)") or name -- the realm goes
  end
  f.kname:SetText(name or "")
  local r, g, b = 1, 1, 1
  if c.nameColor == "class" and not Offline(u) then
    local cr, cg, cb = ClassTokenRGB(UnitClassToken(u))
    if cr then r, g, b = cr, cg, cb end
  end
  f.kname:SetTextColor(r, g, b)
end

function R:UpdateRole(f)
  local u = f.kunit
  if not u then return end
  local atlas = RoleAtlas(Role(u))
  if atlas and f.krole.SetAtlas then
    pcall(f.krole.SetAtlas, f.krole, atlas)
    f.krole:SetAlpha(self:TileSet(f).roleIcons and 1 or 0)
  else
    f.krole:SetAlpha(0)
  end
end

function R:UpdateAggro(f)
  local u = f.kunit
  if not u then return end
  if not self:TileSet(f).aggro or not UnitThreatSituation then
    f.kaggro:SetAlpha(0)
    return
  end
  local s = UnitThreatSituation(u)
  if IsSecret(s) then
    f.kaggro:SetAlpha(s) -- 0 without threat, full from "higher threat than the tank" up
  else
    f.kaggro:SetAlpha((type(s) == "number" and s >= 2) and 1 or 0)
  end
end

function R:UpdateEdge(f)
  local u = f.kunit
  if not u then return end
  local target = UnitIsUnit and Safe(UnitIsUnit(u, "target")) or false
  self:PaintEdge(f, self:TileSet(f), target, f.kover)
end

-- Out of range: from your heal spell where it's known (a plain answer), else the game's
-- check, which is secret and goes straight into the alpha.
function R:UpdateRange(f)
  local u = f.kunit
  if not u then return end
  local fade = tonumber(self:TileSet(f).rangeAlpha) or 0.5
  if u == "player" or f.kisPlayer then
    f:SetAlpha(1)
    return
  end
  local spell = self.rangeSpell
  if spell and C_Spell and C_Spell.IsSpellInRange then
    local ok, r = pcall(C_Spell.IsSpellInRange, spell, u)
    if ok and not IsSecret(r) and r ~= nil then
      f:SetAlpha(r and 1 or fade)
      return
    end
  end
  if UnitInRange then
    local r = UnitInRange(u)
    if IsSecret(r) then
      if f.SetAlphaFromBoolean then f:SetAlphaFromBoolean(r, 1, fade) end
      return
    end
    f:SetAlpha(r == false and fade or 1)
    return
  end
  f:SetAlpha(1)
end

function R:UpdateAuras(f)
  if ns.RaidAuras then Guard("debuffs", ns.RaidAuras.Update, ns.RaidAuras, f) end
end

-- Raid marker, leader, ready check, and a resurrection or summon on its way (since 1.47.0).
local READY_TEX = {
  ready = "Interface\\RaidFrame\\ReadyCheck-Ready", notready = "Interface\\RaidFrame\\ReadyCheck-NotReady",
  waiting = "Interface\\RaidFrame\\ReadyCheck-Waiting",
}
function R:UpdateFlags(f)
  local u = f.kunit
  if not (u and f.kmark) then return end
  local c = self:TileSet(f)
  -- raid marker
  local index = c.markers and GetRaidTargetIndex and Safe(GetRaidTargetIndex(u)) or nil
  if type(index) == "number" and index >= 1 and SetRaidTargetIconTexture then
    SetRaidTargetIconTexture(f.kmark, index)
    f.kmark:Show()
  else
    f.kmark:Hide()
  end
  -- leader
  f.klead:SetShown(c.leader and UnitIsGroupLeader ~= nil and Safe(UnitIsGroupLeader(u)) == true)
  -- ready check: its answer while one runs, and for a few seconds after. Once a check ends the
  -- game forgets the answers, so the last one seen is kept; someone still "waiting" then didn't answer.
  local live = GetReadyCheckStatus and Safe(GetReadyCheckStatus(u)) or nil
  if live then f.kanswer = live end
  local answer = c.ready and self.readyCheck and (live or f.kanswer) or nil
  if answer == "waiting" and self.readyOver then answer = "notready" end
  local tex = answer and READY_TEX[answer]
  if tex then
    f.kready:SetTexture(tex)
    f.kready:Show()
  else
    f.kready:Hide()
  end
  -- on its way
  local text, r, g, b
  if c.incoming then
    if UnitHasIncomingResurrection and Safe(UnitHasIncomingResurrection(u)) == true then
      text, r, g, b = "Res coming", 1, 0.88, 0.54
    elseif C_IncomingSummon and C_IncomingSummon.HasIncomingSummon and Safe(C_IncomingSummon.HasIncomingSummon(u)) == true then
      text, r, g, b = "Summon", 0.78, 0.65, 1
    end
  end
  if text then
    Font(f.kflag, 10 * (c.statusScale or 1), nil, "groups.status")
    f.kflag:SetText(text)
    f.kflag:SetTextColor(r, g, b)
    f.kflag:Show()
  else
    f.kflag:Hide()
  end
end

function R:UpdateAll(f)
  if not f.kunit then return end
  local c = self:TileSet(f)
  self:PaintLayout(f, c, ShowsPower(c, f.kunit))
  self:UpdateHealth(f)
  self:UpdatePower(f)
  self:UpdateName(f)
  self:UpdateRole(f)
  self:UpdateAggro(f)
  self:UpdateEdge(f)
  self:UpdateRange(f)
  self:UpdateAuras(f)
  self:UpdateFlags(f)
end

function R:SetUnit(f, unit)
  local old = f.kunit
  if old and self.byUnit[old] then self.byUnit[old][f] = nil end
  if type(unit) ~= "string" or unit == "" then unit = nil end
  f.kunit = unit
  f.kisPlayer = nil
  if not unit then return end
  self.byUnit[unit] = self.byUnit[unit] or {}
  self.byUnit[unit][f] = true
  f.kisPlayer = unit == "player" or (UnitIsUnit and Safe(UnitIsUnit(unit, "player"))) or nil
  Guard("frames", self.UpdateAll, self, f)
end

-- Called by the header's snippet for each member button it makes (in combat too).
function R:InitTile(f, header)
  if type(f) ~= "table" or self.tiles[f] then return end
  BuildTile(f)
  f.kheader = header
  self.tiles[f] = true
  f:HookScript("OnAttributeChanged", function(b, name, value)
    if name == "unit" then R:SetUnit(b, value) end
  end)
  f:HookScript("OnEnter", function(b)
    b.kover = true
    R:UpdateEdge(b)
    if b.kunit and GameTooltip_SetDefaultAnchor then
      GameTooltip_SetDefaultAnchor(GameTooltip, b)
      GameTooltip:SetUnit(b.kunit)
      GameTooltip:Show()
    end
  end)
  f:HookScript("OnLeave", function(b)
    b.kover = nil
    R:UpdateEdge(b)
    GameTooltip:Hide()
  end)
  _G.ClickCastFrames = _G.ClickCastFrames or {}
  _G.ClickCastFrames[f] = true
  if InCombatLockdown() then
    self.pendingClicks[f] = true
  else
    f:RegisterForClicks("AnyUp")
  end
  if self.OnTile then self:OnTile(f) end -- click-casting (HealMode.lua)
  self:SetUnit(f, f:GetAttribute("unit"))
end

------------------------------------------------------------------------
-- Headers and layout
------------------------------------------------------------------------

-- Runs in the game's secure environment for each new member button: its size, the default
-- clicks, then VoltUI's look. (Click-casting adds its own attributes through
-- _initialAttribute-*, which the header copies onto new buttons by itself.)
local INIT = [[
  local header = self:GetParent()
  self:SetWidth(header:GetAttribute("volt-width") or 72)
  self:SetHeight(header:GetAttribute("volt-height") or 36)
  self:SetAttribute("*type1", "target")
  self:SetAttribute("*type2", "togglemenu")
  header:CallMethod("kInit", self:GetName())
]]
R.INIT = INIT

local function MakeHeader(name, parent, group)
  local h = CreateFrame("Frame", name, parent, "SecureGroupHeaderTemplate")
  h:SetAttribute("template", "SecureUnitButtonTemplate")
  h:SetAttribute("templateType", "Button")
  h:SetAttribute("initialConfigFunction", INIT)
  h:SetAttribute("unitsPerColumn", 5)
  h:SetAttribute("maxColumns", 1)
  if group then
    h:SetAttribute("showRaid", true)
    h:SetAttribute("groupFilter", tostring(group))
  else
    h:SetAttribute("showParty", true)
  end
  h.kgroup = group
  h.kInit = function(header, childName) R:InitTile(_G[childName], header) end
  local title = S.Text(parent, nil, "LEFT", "OVERLAY")
  title:SetPoint("BOTTOMLEFT", h, "TOPLEFT", 1, 2)
  title:SetTextColor(S.ACCENT[1], S.ACCENT[2], S.ACCENT[3])
  title:SetText(group and ((_G.GROUP or "Group") .. " " .. group) or (_G.PARTY or "Party"))
  R.titles[h] = title
  return h
end

-- Every member button a header can need, made now rather than as people join (1.101.14).
-- Buttons can't be told which mouse buttons to answer in a fight, so one made mid-fight
-- took left clicks only until it ended. Asking the game's header to start its list before
-- the first member makes it create that many buttons at once; back at 1, it shows the group
-- as it is. Out of combat, and only while the header is showing (it does nothing hidden).
function R.PreMake(h, count)
  if not h or (h.kPremade or 0) >= count then return false end
  if InCombatLockdown() or not (h.IsVisible and h:IsVisible()) then return false end
  h:SetAttribute("startingIndex", 1 - count)
  h:SetAttribute("startingIndex", 1)
  h.kPremade = count
  return true
end

local SORTS = {
  group = { sortMethod = "INDEX" },
  name = { sortMethod = "NAME" },
  role = { sortMethod = "INDEX", groupBy = "ASSIGNEDROLE", groupingOrder = "TANK,HEALER,DAMAGER,NONE" },
  class = { sortMethod = "INDEX", groupBy = "CLASS",
    groupingOrder = "WARRIOR,PALADIN,PRIEST,SHAMAN,DRUID,ROGUE,MAGE,WARLOCK,HUNTER,DEATHKNIGHT,MONK,DEMONHUNTER,EVOKER" },
}

-- Where group header i sits in the holder, and the holder's size for `groups` groups.
function R:Geometry(c, groups)
  local w, h = tonumber(c.width) or 72, tonumber(c.height) or 36
  local gap, gg = tonumber(c.gap) or 2, tonumber(c.groupGap) or 8
  local titleH = c.titles and TITLE_H or 0
  local colW, colH = w, 5 * h + 4 * gap
  if c.layout == "rows" then colW, colH = 5 * w + 4 * gap, h end
  local function at(i)
    if c.layout == "rows" then return 0, -((i - 1) * (colH + titleH + gg) + titleH) end
    return (i - 1) * (colW + gg), -titleH
  end
  local W, H
  if c.layout == "rows" then
    W, H = colW, groups * (colH + titleH) + (groups - 1) * gg
  else
    W, H = groups * colW + (groups - 1) * gg, colH + titleH
  end
  return at, max(W, 40), max(H, 20), w, h, gap
end

-- How many raid groups have someone in them (1 out of a raid).
local function GroupsInUse()
  if not (IsInRaid and IsInRaid()) or not GetRaidRosterInfo then return 1 end
  local top = 1
  for i = 1, 40 do
    local _, _, sub = GetRaidRosterInfo(i)
    sub = Safe(sub)
    if type(sub) == "number" and sub > top then top = sub end
  end
  return top
end

-- Shows a group's title only while that group has someone in it: raid group N in a raid,
-- "Party" in a party (or alone with "Show when you're alone" on). The titles are plain text
-- on VoltUI's own holder, so this is fine in combat too.
function R:UpdateTitles()
  local pc, rc = self:Set(self:SetName("party")), self:Set(self:SetName("raid"))
  local raid = IsInRaid and IsInRaid()
  local used = {}
  if raid and GetRaidRosterInfo then
    for i = 1, 40 do
      local name, _, sub = GetRaidRosterInfo(i)
      sub = Safe(sub)
      if name and type(sub) == "number" then used[sub] = true end
    end
  end
  local party = not raid and ((IsInGroup and IsInGroup()) or pc.showSolo)
  for hd, title in pairs(self.titles) do
    local show
    if hd.kgroup then show = rc.titles and used[hd.kgroup] else show = pc.titles and party end
    title:SetShown(show and true or false)
  end
end

-- Size, layout and order onto one header from its set. Secure: out of combat only.
local function LayoutHeader(hd, c, at, holder)
  local w, h, gap = tonumber(c.width) or 72, tonumber(c.height) or 36, tonumber(c.gap) or 2
  local sort = SORTS[c.sort] or SORTS.group
  -- Column to row or back: the game's header only sets its buttons' new anchor, so the old one
  -- has to go first or each tile hangs from both and they come out as a staircase.
  local point = c.layout == "rows" and "LEFT" or "TOP"
  local had = hd:GetAttribute("point")
  if had and had ~= point then
    for i = 1, 40 do
      local child = hd:GetAttribute("child" .. i)
      if not child then break end
      child:ClearAllPoints()
    end
  end
  hd:SetAttribute("_ignore", "volt") -- one re-layout at the end, not one per attribute
  hd:SetAttribute("volt-width", w)
  hd:SetAttribute("volt-height", h)
  if c.layout == "rows" then
    hd:SetAttribute("point", "LEFT")
    hd:SetAttribute("xOffset", gap)
    hd:SetAttribute("yOffset", 0)
  else
    hd:SetAttribute("point", "TOP")
    hd:SetAttribute("xOffset", 0)
    hd:SetAttribute("yOffset", -gap)
  end
  hd:SetAttribute("sortMethod", sort.sortMethod)
  hd:SetAttribute("groupBy", sort.groupBy)
  hd:SetAttribute("groupingOrder", sort.groupingOrder)
  if not hd.kgroup then
    hd:SetAttribute("showPlayer", c.showPlayer and true or nil)
    hd:SetAttribute("showSolo", c.showSolo and true or nil)
  end
  hd:SetAttribute("_ignore", nil)
  -- Taking "_ignore" off doesn't itself lay the header out (the game skips that attribute by
  -- name); any other attribute does. Without this a changed gap, order or direction only
  -- showed at the next change to the group.
  hd:SetAttribute("volt-layout", (tonumber(hd:GetAttribute("volt-layout")) or 0) + 1)
  local x, y = at(hd.kgroup or 1)
  hd:ClearAllPoints()
  hd:SetPoint("TOPLEFT", holder, "TOPLEFT", x, y)
end

-- Puts the settings onto the headers and every member button. Out of combat only; waits
-- for the fight to end otherwise.
function R:Apply()
  if not self.enabled or not self.holder then return end -- no holder: a reload in a fight, Start is still waiting
  if InCombatLockdown() then
    self.applyPending = true
    return
  end
  self.applyPending = nil
  -- The party header takes a party set, the raid groups a raid set. The holder (where the
  -- frames sit, and their scale) follows the frames that are up.
  self.activeKind = CurrentKind()
  local pc, rc = self:Set(self:SetName("party")), self:Set(self:SetName("raid"))
  local pat, PW, PH = self:Geometry(pc, 1)
  local rat, RW, RH = self:Geometry(rc, GroupsInUse())
  local raid = self.activeKind == "raid"
  local holder = self.holder
  holder:SetScale(tonumber((raid and rc or pc).scale) or 1)
  holder:SetSize(raid and RW or PW, raid and RH or PH)
  for _, hd in ipairs(self.headers) do
    if hd.kgroup then LayoutHeader(hd, rc, rat, holder) else LayoutHeader(hd, pc, pat, holder) end
    local title = self.titles[hd]
    if title then Font(title, 11) end
  end
  self:UpdateTitles()
  for f in pairs(self.tiles) do
    local c = self:TileSet(f)
    f:SetSize(tonumber(c.width) or 72, tonumber(c.height) or 36)
    if f.kunit then Guard("frames", self.UpdateAll, self, f) else self:PaintLayout(f, c, false) end
  end
  if self.sim then Guard("preview", self.DrawSim, self) end
  if ns.Dispel and ns.Dispel.enabled then Guard("dispel windows", ns.Dispel.Apply, ns.Dispel) end
  -- The party's five buttons always; a raid group's five once you're in a raid.
  local inRaid = IsInRaid and IsInRaid()
  for _, hd in ipairs(self.headers) do
    if not hd.kgroup or inRaid then Guard("buttons made ahead", R.PreMake, hd, 5) end
  end
end

-- After a setting changes on the settings window: everything that doesn't need combat to end.
function R:Refresh()
  if not self.enabled then return end
  self:Apply()
end

function R:PlaceHolder()
  local holder = self.holder
  if not S.PlaceSpot(holder, ns.db, "raidLeft", "raidTop", "raidPoint") then
    holder:ClearAllPoints()
    holder:SetPoint("TOPLEFT", UIParent, "LEFT", 40, 220) -- about where the game puts raid frames
  end
end

function R:SetUnlocked(on)
  if ns.Dispel and ns.Dispel.enabled then ns.Dispel:SetUnlocked(on) end
  if not self.holder or not self.holder.mover then return end
  self.holder.mover:SetShown(on and true or false)
end

------------------------------------------------------------------------
-- The game's own party and raid frames
------------------------------------------------------------------------

local GAME_FRAMES = { "PartyFrame", "CompactPartyFrame", "CompactRaidFrameContainer", "CompactRaidFrameManager" }

function R:HideGame()
  if InCombatLockdown() then
    self.hidePending = true
    return
  end
  self.hidePending = nil
  local hidden = S.HiddenParent()
  local function away(f)
    if type(f) ~= "table" or self.hiddenGame[f] then return end
    self.hiddenGame[f] = true
    if UnregisterUnitWatch then pcall(UnregisterUnitWatch, f) end
    if f.UnregisterAllEvents then pcall(f.UnregisterAllEvents, f) end
    if f.SetParent then pcall(f.SetParent, f, hidden) end
  end
  for _, name in ipairs(GAME_FRAMES) do
    local f = _G[name]
    if type(f) == "table" and f.UnregisterAllEvents then pcall(f.UnregisterAllEvents, f) end
    if type(f) == "table" and not self.hiddenGame[f] and f.SetParent then
      self.hiddenGame[f] = true
      pcall(f.SetParent, f, hidden)
    end
  end
  local pf = _G.PartyFrame
  for i = 1, 4 do
    away(type(pf) == "table" and pf["MemberFrame" .. i] or nil)
    away(_G["PartyMemberFrame" .. i])
  end
end

------------------------------------------------------------------------
-- Preview: made-up members on VoltUI's own (plain) tiles
------------------------------------------------------------------------

R.SIM_MODES = {
  { key = false, name = "Off" }, { key = "party", name = "5" },
  { key = "raid10", name = "10" }, { key = "raid25", name = "25" }, { key = "raid40", name = "40" },
}
local SIM_COUNT = { party = 5, raid10 = 10, raid25 = 25, raid40 = 40 }
R.SIM_COUNT = SIM_COUNT
-- What a party page and a raid page offer.
R.SIM_PARTY = { { key = false, name = "Off" }, { key = "party", name = "On" } }
R.SIM_RAID = { { key = false, name = "Off" }, { key = "raid10", name = "10" }, { key = "raid25", name = "25" }, { key = "raid40", name = "40" } }
local SIM_NAMES = {
  "Brakka", "Lumen", "Vexa", "Thornwick", "Quill", "Morrow", "Sable", "Haldor", "Rook", "Ember",
  "Oswin", "Kestrel", "Dagny", "Fenn", "Ilsa", "Gorrum", "Tamsin", "Wren", "Bastian", "Odalys",
  "Corvin", "Maelis", "Torvald", "Juniper", "Hask", "Nyra", "Pell", "Ardent", "Sorrel", "Bryn",
  "Calder", "Yselle", "Grisk", "Lorne", "Myrtle", "Varn", "Elsbeth", "Tobin", "Ashka", "Dunmore",
}
local SIM_CLASSES = { "WARRIOR", "PRIEST", "MAGE", "DRUID", "ROGUE", "WARLOCK", "HUNTER", "PALADIN", "SHAMAN", "MAGE" }
local SIM_ROLES = { "TANK", "HEALER", "DAMAGER", "HEALER", "DAMAGER", "DAMAGER", "DAMAGER", "TANK", "HEALER", "DAMAGER" }
local SIM_HP = { 0.82, 0.95, 0.46, 1, 0.27, 0, 0.71, 0.64, 0.88, 1 }
local SIM_STATE = {
  [1] = "aggro", [3] = "target", [5] = "far", [6] = "dead", [10] = "offline",
  [14] = "far", [17] = "dead", [23] = "far", [31] = "offline", [38] = "far",
}
local SIM_POWER = { WARRIOR = "RAGE", ROGUE = "ENERGY" }
-- A few debuffs to show the debuff settings on: removable ones (by type) and one that isn't.
local SIM_DEBUFFS = {
  [3] = { { kind = "Magic", removable = true, icon = 136207 }, { icon = 132090 } },
  [5] = { { kind = "Poison", removable = true, icon = 136016 } },
  [8] = { { kind = "Curse", removable = true, icon = 136139 }, { kind = "Disease", removable = true, icon = 136127 } },
  [12] = { { icon = 132090 } },
}

-- Member i of the made-up group. The first is you.
local function SimMember(i)
  local k = (i - 1) % 10 + 1
  local m = {
    name = SIM_NAMES[i] or ("Member " .. i), class = SIM_CLASSES[k], role = SIM_ROLES[k],
    hp = SIM_HP[((i - 1) + floor((i - 1) / 10) * 3) % 10 + 1],
    max = 2400 + (i * 397) % 1800, debuffs = SIM_DEBUFFS[i] or {},
  }
  local state = SIM_STATE[i]
  if state then m[state] = true end
  if m.dead then m.hp = 0 end
  if not (m.dead or m.offline) and m.hp < 0.9 then m.heal = 0.08 end
  if i == 2 or i == 9 then m.shield = 0.1 end
  if i == 2 then m.heal = 0.1 end -- more than they're missing: overhealing
  -- Your HoTs and shields (Renew, Rejuvenation, Power Word: Shield), and corner buffs.
  if i == 1 or i == 4 or i == 9 then m.hots = { 135953, 136081 } end
  if i == 2 then m.hots = { 135940 } end
  if i == 1 then m.corners = { 136089, 135902 } end
  if i == 8 then m.corners = { false, 135902 } end
  if i == 1 then
    local name = UnitName and Safe(UnitName("player"))
    local class = UnitClassToken("player")
    if type(name) == "string" and name ~= "" then m.name = name end
    if type(class) == "string" then m.class = class end
  end
  return m
end
R.SimMember = SimMember

function R:PaintSim(f, m, c)
  f.kmember = m
  local power = c.power == "all" or (c.power == "healers" and m.role == "HEALER")
  self:PaintLayout(f, c, power)
  local bar, track = HealthColors(c, m.class, m.offline, m.dead)
  f.khp:SetMinMaxValues(0, 1)
  f.khp:SetValue(m.offline and 1 or m.hp)
  S.BarColor(f.khp, bar[1], bar[2], bar[3])
  f.ktrack:SetColorTexture(track[1], track[2], track[3], track[4])
  f.kheal:SetMinMaxValues(0, 1)
  f.kheal:SetValue(c.heals and m.heal or 0)
  f.kshield:SetMinMaxValues(0, 1)
  f.kshield:SetValue(c.shields and m.shield or 0)
  local missing = m.offline and 0 or 1 - m.hp
  ShowIf(f.koverheal, (m.heal or 0) > missing, c.heals and c.overheal and not m.offline)
  ShowIf(f.koverabsorb, (m.shield or 0) > math.max(0, missing - (m.heal or 0)), c.shields and c.overheal and not m.offline)
  local pc = POWER[SIM_POWER[m.class] or "MANA"]
  S.BarColor(f.kpw, pc[1], pc[2], pc[3])
  f.kpw:SetMinMaxValues(0, 1)
  f.kpw:SetValue(m.offline and 0 or 0.4 + (m.max % 60) / 100)
  f.kname:SetText(m.name)
  local r, g, b = 1, 1, 1
  if c.nameColor == "class" and not m.offline then
    local cr, cg, cb = ClassTokenRGB(m.class)
    if cr then r, g, b = cr, cg, cb end
  end
  f.kname:SetTextColor(r, g, b)
  local st = f.kstatus
  st:SetAlpha(1)
  local now = floor(m.max * m.hp + 0.5)
  if m.offline or m.dead then
    st:SetText(m.offline and (_G.PLAYER_OFFLINE or "Offline") or (_G.DEAD or "Dead"))
    st:SetTextColor(GREY[1], GREY[2], GREY[3])
  elseif c.hpText == "missing" then
    st:SetText(now < m.max and ("-" .. S.ShortNum(m.max - now)) or "")
    st:SetTextColor(1, 1, 1)
  elseif c.hpText == "percent" then
    st:SetText(("%d%%"):format(floor(100 * now / m.max + 0.5)))
    st:SetTextColor(1, 1, 1)
  else
    st:SetText("")
  end
  local atlas = RoleAtlas(m.role)
  if atlas and f.krole.SetAtlas then pcall(f.krole.SetAtlas, f.krole, atlas) end
  f.krole:SetAlpha((c.roleIcons and atlas) and 1 or 0)
  f.kaggro:SetAlpha((c.aggro and m.aggro) and 1 or 0)
  self:PaintEdge(f, c, m.target, f.kover)
  f:SetAlpha(m.far and (tonumber(c.rangeAlpha) or 0.5) or 1)
  if ns.RaidAuras then ns.RaidAuras:PaintSim(f, m, c) end
end

function R:SimBox()
  if self.simBox then return self.simBox end
  local box = CreateFrame("Frame", "VoltUIRaidPreview", UIParent)
  box:SetFrameStrata("MEDIUM")
  box:Hide()
  box.label = S.UIText(box, nil, "LEFT", "OVERLAY", 11, "OUTLINE")
  box.label:SetPoint("BOTTOMLEFT", box, "TOPLEFT", 0, 4)
  box.label:SetTextColor(S.ACCENT[1], S.ACCENT[2], S.ACCENT[3])
  box.label:SetText("Preview: made-up members")
  self.simBox, self.simTiles, self.simTitles = box, {}, {}
  return box
end

function R:SimTile(i)
  local f = self.simTiles[i]
  if f then return f end
  f = CreateFrame("Frame", nil, self.simBox)
  BuildTile(f)
  f:EnableMouse(true)
  f:SetScript("OnEnter", function() f.kover = true; R:PaintEdge(f, R:SimSet(), f.kmember and f.kmember.target, true) end)
  f:SetScript("OnLeave", function() f.kover = nil; R:PaintEdge(f, R:SimSet(), f.kmember and f.kmember.target, false) end)
  self.simTiles[i] = f
  return f
end

-- The preview shows the set the settings window is on, else the one in use for its size:
-- 5 shows party frames, more shows raid frames.
function R:SimSet()
  if self.simSet then return self:Set(self.simSet) end
  return self:Set(self:SetName((SIM_COUNT[self.sim] or 5) > 5 and "raid" or "party"))
end

function R:DrawSim()
  local box = self.simBox
  if not box or not self.sim then return end
  local c = self:SimSet()
  local count = SIM_COUNT[self.sim] or 5
  local groups = math.ceil(count / 5)
  local at, W, H, w, h, gap = self:Geometry(c, groups)
  box:SetScale(tonumber(c.scale) or 1)
  box:SetSize(W, H)
  for _, f in ipairs(self.simTiles) do f:Hide() end
  for _, t in ipairs(self.simTitles) do t:Hide() end
  for gi = 1, groups do
    local x, y = at(gi)
    local title = self.simTitles[gi]
    if not title then
      title = S.Text(box, nil, "LEFT", "OVERLAY")
      self.simTitles[gi] = title
    end
    title:ClearAllPoints()
    title:SetPoint("BOTTOMLEFT", box, "TOPLEFT", x + 1, y + 2)
    Font(title, 11)
    title:SetTextColor(S.ACCENT[1], S.ACCENT[2], S.ACCENT[3])
    title:SetText(count > 5 and ((_G.GROUP or "Group") .. " " .. gi) or (_G.PARTY or "Party"))
    title:SetShown(c.titles and true or false)
    for k = 1, min(5, count - (gi - 1) * 5) do
      local i = (gi - 1) * 5 + k
      local f = self:SimTile(i)
      f:SetSize(w, h)
      f:ClearAllPoints()
      if c.layout == "rows" then
        f:SetPoint("TOPLEFT", box, "TOPLEFT", x + (k - 1) * (w + gap), y)
      else
        f:SetPoint("TOPLEFT", box, "TOPLEFT", x, y - (k - 1) * (h + gap))
      end
      self:PaintSim(f, SimMember(i), c)
      f:Show()
    end
  end
end

-- Shows the preview in `mode` (a key of SIM_MODES), or hides it, over where the real frames
-- go. `fromEdit` closes it again with the settings window. The real frames step aside meanwhile.
function R:Simulate(mode, fromEdit)
  if mode and not SIM_COUNT[mode] then mode = "party" end
  if mode and InCombatLockdown() then return end
  self.sim = mode or nil
  self.simFromEdit = (mode and fromEdit) and true or nil
  if not mode then
    if self.simBox then self.simBox:Hide() end
    if self.holder then self.holder:SetAlpha(1) end -- alpha isn't locked in a fight; left at 0 the real frames stayed invisible
    return
  end
  local box = self:SimBox()
  box:ClearAllPoints()
  if self.holder then
    box:SetPoint("TOPLEFT", self.holder, "TOPLEFT", 0, 0)
    self.holder:SetAlpha(0)
  else
    box:SetPoint("TOPLEFT", UIParent, "LEFT", 40, 220)
  end
  Guard("preview", self.DrawSim, self)
  box:Show()
end

------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------

local UNIT_EVENTS = {
  UNIT_HEALTH = "UpdateHealth", UNIT_MAXHEALTH = "UpdateHealth", UNIT_HEAL_PREDICTION = "UpdateHealth",
  UNIT_ABSORB_AMOUNT_CHANGED = "UpdateHealth", UNIT_CONNECTION = "UpdateAll", UNIT_FLAGS = "UpdateHealth",
  UNIT_POWER_UPDATE = "UpdatePower", UNIT_POWER_FREQUENT = "UpdatePower", UNIT_MAXPOWER = "UpdatePower",
  UNIT_DISPLAYPOWER = "UpdatePower", UNIT_NAME_UPDATE = "UpdateName",
  UNIT_THREAT_SITUATION_UPDATE = "UpdateAggro", UNIT_AURA = "UpdateAuras",
}

function R:ForUnit(unit, method)
  local set = self.byUnit[unit]
  if set then
    for f in pairs(set) do Guard("frames", self[method], self, f) end
  end
  if unit == "player" then
    -- Your own tile in a raid has a raidN token; events come for "player".
    for f in pairs(self.tiles) do
      if f.kisPlayer and f.kunit ~= "player" then Guard("frames", self[method], self, f) end
    end
  end
end

function R:ForAll(method)
  for f in pairs(self.tiles) do
    if f.kunit then Guard("frames", self[method], self, f) end
  end
end

function R:FindRangeSpell()
  self.rangeSpell = nil
  local _, class = UnitClass("player")
  local list = RANGE_SPELLS[Safe(class) or ""]
  if not list then return end
  for _, id in ipairs(list) do
    if IsPlayerSpell and IsPlayerSpell(id) then
      self.rangeSpell = id
      return
    end
  end
end

function R:OnEvent(event, arg)
  local method = UNIT_EVENTS[event]
  if method then
    if arg then self:ForUnit(arg, method) end
  elseif event == "PLAYER_TARGET_CHANGED" then
    self:ForAll("UpdateEdge")
  elseif event == "RAID_TARGET_UPDATE" or event == "PARTY_LEADER_CHANGED" or event == "INCOMING_SUMMON_CHANGED" then
    self:ForAll("UpdateFlags")
  elseif event == "INCOMING_RESURRECT_CHANGED" then
    if arg then self:ForUnit(arg, "UpdateFlags") else self:ForAll("UpdateFlags") end
  elseif event == "READY_CHECK" or event == "READY_CHECK_CONFIRM" then
    if event == "READY_CHECK" then
      -- a new check: the last one's answers go, and so does its timer to clear them
      self.readyStamp, self.readyOver = nil, nil
      for f in pairs(self.tiles) do f.kanswer = nil end
    end
    self.readyCheck = true
    self:ForAll("UpdateFlags")
  elseif event == "READY_CHECK_FINISHED" then
    -- The answers stay up a few seconds after the check ends, then go.
    local stamp = {}
    self.readyStamp = stamp
    self.readyOver = true
    self:ForAll("UpdateFlags")
    local function clear()
      if R.readyStamp ~= stamp then return end
      R.readyCheck, R.readyOver = nil, nil
      for f in pairs(R.tiles) do f.kanswer = nil end
      R:ForAll("UpdateFlags")
    end
    if C_Timer and C_Timer.After then C_Timer.After(6, clear) else clear() end
  elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ROLES_ASSIGNED" then
    for f in pairs(self.tiles) do
      if f.kunit then f.kisPlayer = f.kunit == "player" or (UnitIsUnit and Safe(UnitIsUnit(f.kunit, "player"))) or nil end
    end
    self:ForAll("UpdateAll")
    self:UpdateTitles()
    if self.OnRoster then self:OnRoster() end -- heal mode's auto switch (HealMode.lua)
    self:Apply() -- in a fight it waits: party to raid (or back) switches sets after it
  elseif event == "SPELLS_CHANGED" then
    self:FindRangeSpell()
    if ns.RaidAuras then ns.RaidAuras:FindDispels() end
  elseif event == "ADDON_LOADED" then
    if arg == "Blizzard_CompactRaidFrames" then self:HideGame() end
  elseif event == "PLAYER_REGEN_DISABLED" then
    if self.sim then self:Simulate(false) end
  elseif event == "PLAYER_REGEN_ENABLED" then
    for f in pairs(self.pendingClicks) do
      f:RegisterForClicks("AnyUp")
      self.pendingClicks[f] = nil
    end
    if self.hidePending then self:HideGame() end
    if self.applyPending then self:Apply() end
    if self.AfterCombat then self:AfterCombat() end -- click-casting, heal mode (HealMode.lua)
  end
end

local RANGE_EVERY = 0.25

-- Secure headers can't be made, set up or shown in combat. A /reload in a fight waits until
-- it ends, as the player and target frames do; before 1.101.7 the headers were made at once
-- and never shown afterwards.
function R:Enable()
  self.enabled = true
  if not InCombatLockdown() then return self:Start() end
  local wait = CreateFrame("Frame")
  wait:RegisterEvent("PLAYER_REGEN_ENABLED")
  wait:SetScript("OnEvent", function(w)
    w:UnregisterEvent("PLAYER_REGEN_ENABLED")
    Guard("party and raid frames", R.Start, R)
  end)
end

function R:Start()
  if self.started then return end
  self.started = true
  self:Cfg()
  local holder = CreateFrame("Frame", "VoltUIRaidFrames", UIParent)
  holder:SetMovable(true)
  holder:SetClampedToScreen(true)
  holder:SetSize(72, 36)
  self.holder = holder
  self:PlaceHolder()
  holder.mover = S.Mover(holder, "Party and raid", function(f)
    S.KeepSpot(f, ns.db, "raidLeft", "raidTop", "raidPoint")
  end, { spot = function() return ns.db, "raidLeft", "raidTop", "raidPoint" end })
  self.headers[1] = MakeHeader("VoltUIRaidParty", holder, nil)
  for g = 1, 8 do self.headers[#self.headers + 1] = MakeHeader("VoltUIRaidGroup" .. g, holder, g) end
  self:FindRangeSpell()
  if ns.RaidAuras then ns.RaidAuras:FindDispels() end

  local ev = CreateFrame("Frame")
  for e in pairs(UNIT_EVENTS) do pcall(ev.RegisterEvent, ev, e) end
  for _, e in ipairs({ "PLAYER_TARGET_CHANGED", "GROUP_ROSTER_UPDATE", "PLAYER_ROLES_ASSIGNED", "SPELLS_CHANGED",
                       "ADDON_LOADED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
    pcall(ev.RegisterEvent, ev, e)
  end
  for _, e in ipairs({ "RAID_TARGET_UPDATE", "PARTY_LEADER_CHANGED", "READY_CHECK", "READY_CHECK_CONFIRM", "READY_CHECK_FINISHED",
                       "INCOMING_RESURRECT_CHANGED", "INCOMING_SUMMON_CHANGED" }) do
    pcall(ev.RegisterEvent, ev, e)
  end
  ev:SetScript("OnEvent", function(_, event, arg) R:OnEvent(event, arg) end)
  -- Range, a few times a second.
  local since = 0
  ev:SetScript("OnUpdate", function(_, elapsed)
    since = since + (elapsed or 0)
    if since < RANGE_EVERY then return end
    since = 0
    R:ForAll("UpdateRange")
  end)
  self.ev = ev

  if self.EnableHeal then self:EnableHeal() end -- HealMode.lua
  if ns.Dispel then Guard("dispel windows", ns.Dispel.Enable, ns.Dispel) end -- Dispel.lua
  self:HideGame()
  self:Apply()
  for _, hd in ipairs(self.headers) do
    if not InCombatLockdown() then hd:Show() end
  end
end

------------------------------------------------------------------------
-- /volt groups
------------------------------------------------------------------------

local function Count(t)
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  return n
end

function R:Slash(arg)
  local cmd, rest = (arg or ""):match("^(%S*)%s*(.-)$")
  if not self.enabled then
    FUI:Print("VoltUI's party and raid frames are off. /volt groups on, then /reload.")
    return
  end
  if cmd == "options" or cmd == "settings" or cmd == "edit" then
    ns.EditMode:Open(self:Kind())
    return
  end
  if cmd == "test" or cmd == "preview" then
    local modes = { party = "party", ["5"] = "party", ["10"] = "raid10", ["25"] = "raid25", ["40"] = "raid40", raid = "raid25" }
    local mode = modes[rest]
    if rest == "off" or (rest == "" and self.sim) then mode = false end
    if rest == "" and not self.sim then mode = "party" end
    if mode == nil then
      FUI:Print("/volt groups test 5 · 10 · 25 · 40 · off")
      return
    end
    if mode and InCombatLockdown() then
      FUI:Print("The preview waits until you're out of combat.")
      return
    end
    self:Simulate(mode)
    if mode then FUI:Print("Preview shown. /volt groups test again hides it.") end
    return
  end
  if cmd == "reset" then
    self:ResetSet("party")
    self:ResetSet("raid")
    if self.ResetHeal then self:ResetHeal() end
    FUI:Print("Party and raid frame settings are back to their defaults.")
    return
  end
  if cmd == "heal" and self.HealSlash then
    self:HealSlash(rest)
    return
  end
  FUI:Print("Party and raid frames: %d member frames, settings set %s.", Count(self.tiles), self:SetName())
  for what, err in pairs(self.reported) do FUI:Print("|cffff7f7f%s:|r %s", what, err) end
  FUI:Print("/volt groups options (the settings) · test 5|10|25|40|off (a preview) · reset · on|off (needs /reload)")
end

FUI:Register(R)
