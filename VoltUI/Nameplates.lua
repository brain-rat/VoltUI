-- VoltUI · Nameplates
-- Gives the game's own nameplates VoltUI's flat look, on every unit: enemies, friends, NPCs and
-- players. They stay the game's nameplates: it still decides which units get one, how big they
-- are, what they show (cast bar spell name, icon and target, auras, level, raid marker) and where
-- they stack, all from its own options (Options > Interface > Nameplates). VoltUI changes how they're
-- drawn, with its own settings (/volt nameplates options), one set for enemies, one for friends,
-- and how your target stands out on top of either:
--  * the health bar: flat or a texture, on a dark track, with a border of any thickness; VoltUI's
--    colours for hostile, neutral, friendly and tapped units and for players, each one yours to
--    pick, class colours for enemy and friendly players, and tank or damage threat colours
--  * health text as a percent, a number or both, left, centre or right
--  * name colour (the game's, white or class) and the size of each text
--  * your target gets a blue border (focus orange), aggro an outer ring in the threat colour, and
--    other plates dim a little while you have a target
--  * the cast bar goes flat in colours you pick (cast, channel, can't be interrupted, stopped), with
--    a square spell icon, its own height and the time left
--  * aura icons go square, sized per list (debuffs, buffs, crowd control), with timer numbers, stack
--    counts, swipe and a border in the debuff type's colour
--
-- Each unit's frame comes from a pool and is used again for other units, so it's styled once and
-- its look is put back whenever the game sets it up again (a new unit, a changed option).
--
-- Taint, because nameplates are drawn by the game's own code in combat:
--  * Nothing VoltUI makes is stored on the game's frames; it's kept in tables here.
--  * Only the game's global functions and each frame's own methods are hooked, after they run
--    (hooksecurefunc). No game function is replaced, none is called, and no field the game reads
--    is set.
--  * Art the game sets again is faded with SetAlpha(0) or recoloured, never moved or replaced.
--    The aggro flare is hidden after the game shows it, since its fade animation sets its alpha.
--  * Health numbers go straight to VoltUI's own text, formatted by the game's own functions, since
--    they can be secret. Cast "can't be interrupted" flags can be secret too, so they go to the
--    game's colour-picking function, as VoltUI's castbar does. Anything else that comes back secret
--    (a unit's class, its threat, an aura's type) just leaves that part as it was.
--  * Forbidden nameplates (friendly units in instances) can't be reached by add-ons and keep the
--    game's look.
--
-- Another nameplate add-on (Platynator, Plater and so on) draws its own plates over the game's,
-- so VoltUI stays out while one is loaded.

local _, ns = ...
local FUI, S = ns.FUI, ns.Style

local N = {
  key = "nameplates", name = "Nameplates",
  plates = {}, casts = {}, levels = {}, auras = {}, faces = {}, lists = {}, reported = {}, missing = {},
  auraOwner = {},
}
ns.Nameplates = N

local Safe = S.Safe
local floor, abs, max = math.floor, math.abs, math.max

-- Add-ons that replace the game's nameplates. VoltUI leaves the plates to them.
local OTHERS = { "Platynator", "Plater", "Kui_Nameplates", "TidyPlates_ThreatPlates", "TidyPlates", "NeatPlates" }

local TRACK = { 0.06, 0.07, 0.09, 0.85 }
local BLACK = { 0, 0, 0 }
local WHITE = { 1, 1, 1 }
local FOCUS = { 1, 0.49, 0.04 }
local AGGRO = { 1, 0.25, 0.2 }
local GREY = { 0.5, 0.5, 0.5 }
-- Debuff type colours, when the game has no table of them.
local DEBUFF_TYPES = {
  Magic = { 0.2, 0.6, 1 }, Curse = { 0.6, 0, 1 }, Disease = { 0.6, 0.4, 0 }, Poison = { 0, 0.6, 0 },
}

-- The game's plain health colours, and which of VoltUI's colours each one becomes. Anything else the
-- game picks (its own threat colours, extended colours) is left alone.
local GAME_COLORS = {
  { 1, 0, 0, "colHostile" },
  { 1, 0.5, 0, "colHostile" },      -- unfriendly
  { 1, 1, 0, "colNeutral" },
  { 0, 1, 0, "colFriendly" },
  { 0.9, 0.9, 0.9, "colTapped" },   -- tapped by someone else
  { 0.667, 0.667, 1, "colPlayer" }, -- friendly players
  { 0, 0, 1, "colPlayer" },         -- friendly players, older colour
}

-- Settings every plate shares: VoltUI's colours for each kind of unit, threat, focus, aggro, dimming.
N.DEFAULTS = {
  threat = "off",      -- off · tank: green while you hold it · dps: warns when you're pulling it
  colHostile = { 0.8, 0.26, 0.22 },
  colNeutral = { 0.9, 0.72, 0.25 },
  colFriendly = { 0.3, 0.7, 0.35 },
  colTapped = { 0.55, 0.55, 0.57 },
  colPlayer = { 0.45, 0.62, 0.92 }, -- friendly players without class colours
  colThreatGood = { 0.3, 0.7, 0.35 },
  colThreatWarn = { 0.95, 0.6, 0.2 },
  colThreatBad = { 0.9, 0.2, 0.2 },
  dim = 0.3,           -- how much other plates darken while you have a target (0 = off)
  focus = true,        -- an orange border on your focus
  aggro = true,        -- an outer ring in the threat colour on anything that's after you
  quest = true,        -- a gold "!" beside a creature one of your quests still needs (1.101.22)
}

-- Each kind of plate (enemy, friendly) has its own set of these.
N.TYPE_DEFAULTS = {
  -- Health bar
  hpColor = "volt",     -- volt: VoltUI's colours · game: as the game has them
  texture = "flat",
  barHeight = 0,       -- health bar height; 0 keeps the game's
  class = true,        -- class colours on players
  -- Health text
  hpText = "game",     -- game: the game's own · off · pct · num · both
  hpTextPos = "center", -- left · center · right
  -- Name and text sizes
  nameColor = "game",  -- game · white · class (players; others white)
  nameScale = 0.9, textScale = 0.9, castScale = 1, levelScale = 1,
  -- Border
  border = 1,          -- thickness in screen pixels
  colBorder = { 0, 0, 0 },
  -- Cast bar
  castBar = true,      -- VoltUI's flat cast bar (off keeps the game's art)
  castHeight = 0,      -- 0 keeps the game's
  castTime = false,    -- time left, at the right of the bar
  colCast = { S.ACCENT[1], S.ACCENT[2], S.ACCENT[3] },
  colChannel = { 0.45, 0.85, 0.55 },
  colLocked = { 0.55, 0.58, 0.63 },
  colFailed = { 0.85, 0.25, 0.2 },
  -- Auras
  auras = true,        -- flat, square aura icons
  debuffScale = 1, buffScale = 1, ccScale = 1,
  auraTimer = "short", -- short: the game's (under a minute) · all · off
  timerScale = 1, stackScale = 1,
  auraBorder = "type", -- type: the debuff type's colour · black
  swipe = true,        -- the dark sweep over an icon as it runs out
}

-- How your target stands out, whichever kind it is. The "same" values leave its kind's own.
N.TARGET_DEFAULTS = {
  color = "accent",    -- its border: accent (blue) · white · off
  glow = true,         -- a faint ring round it
  border = 0,          -- border thickness; 0 = the same as its kind
  barHeight = 0,       -- health bar height; 0 = the same
  hpText = "same",     -- same · off · pct · num · both
  nameScale = 1,       -- name size, times its kind's
}
-- Target settings that stand in for the plate's own while it's your target, and their "same".
local OVERRIDE = { border = 0, barHeight = 0, hpText = "same" }

local KINDS = { "enemy", "friendly" }
N.KINDS = KINDS

local function Copy(v)
  if type(v) ~= "table" then return v end
  local t = {}
  for k, x in pairs(v) do t[k] = Copy(x) end
  return t
end

local function Fill(t, defaults)
  for k, v in pairs(defaults) do
    if t[k] == nil then t[k] = Copy(v) end
  end
end

function N:Cfg()
  local c = ns.db.plateCfg
  if c ~= nil and c == self.cfg then return c end
  if type(c) ~= "table" then
    c = {}
    ns.db.plateCfg = c
  end
  -- 1.19 had one set for every plate: it becomes the enemy set and the friendly set.
  if type(c.target) ~= "table" then
    local old = c.target
    c.target = { color = (old == "white" or old == "off") and old or "accent" }
  end
  for _, kind in ipairs(KINDS) do
    if type(c[kind]) ~= "table" then
      local t = {}
      for k in pairs(self.TYPE_DEFAULTS) do
        if c[k] ~= nil then t[k] = Copy(c[k]) end
      end
      local was = c[kind == "enemy" and "classEnemy" or "classFriendly"]
      if was ~= nil then t.class = was end
      c[kind] = t
    end
    Fill(c[kind], self.TYPE_DEFAULTS)
  end
  for k in pairs(self.TYPE_DEFAULTS) do
    if self.DEFAULTS[k] == nil then c[k] = nil end
  end
  c.classEnemy, c.classFriendly = nil, nil
  Fill(c, self.DEFAULTS)
  Fill(c.target, self.TARGET_DEFAULTS)
  self.cfg = c
  return c
end

local function IsColor(v)
  return type(v) == "table" and type(v[1]) == "number" and type(v[2]) == "number" and type(v[3]) == "number"
end

-- One of the shared colour settings, as { r, g, b }: the default if what's saved isn't a colour.
function N:Color(key)
  local v = self:Cfg()[key]
  if IsColor(v) then return v end
  return self.DEFAULTS[key]
end

-- Which set a plate uses: friendly for units friendly to you, enemy for the rest.
function N:Kind(f)
  local p = self.plates[f]
  return p and p.kind or "enemy"
end

-- One of a plate's own settings, from its kind's set, or your target's where that says so.
function N:Opt(f, key)
  local c = self:Cfg()
  local p = self.plates[f]
  if p and p.target then
    local same = OVERRIDE[key]
    if same ~= nil then
      local v = c.target[key]
      if v ~= nil and v ~= same then return v end
    end
  end
  local v = c[p and p.kind or "enemy"][key]
  if v == nil then v = self.TYPE_DEFAULTS[key] end
  return v
end

-- One of a plate's own colours, as { r, g, b }.
function N:TypeColor(f, key)
  local v = self:Opt(f, key)
  if IsColor(v) then return v end
  return self.TYPE_DEFAULTS[key]
end

-- Puts a setting back to its default (the colour swatches' right-click). `set` is "enemy",
-- "friendly" or "target" for those sets' own settings.
function N:Default(key, set)
  local c = self:Cfg()
  if set == "target" then
    c.target[key] = Copy(self.TARGET_DEFAULTS[key])
  elseif set then
    c[set][key] = Copy(self.TYPE_DEFAULTS[key])
  else
    c[key] = Copy(self.DEFAULTS[key])
  end
end

-- Every setting back to its default, or just one set's ("enemy", "friendly", "target").
function N:ResetCfg(set)
  if set then
    local c = self:Cfg()
    c[set] = {}
    Fill(c[set], set == "target" and self.TARGET_DEFAULTS or self.TYPE_DEFAULTS)
    if set == "target" then c.dim, c.focus = self.DEFAULTS.dim, self.DEFAULTS.focus end
  else
    ns.db.plateCfg = nil
  end
  self:Refresh()
end

-- A game update can rename anything here, and that should cost no more than the look of one
-- part. Says so once per part, and keeps the error for /volt nameplates.
local function Guard(what, fn, ...)
  local ok, err = pcall(fn, ...)
  if not ok and not N.reported[what] then
    N.reported[what] = tostring(err)
    FUI:Print("Nameplates: couldn't style the %s. The nameplates still work. %s", what, tostring(err))
    if ns.Errors then ns.Errors:Add("Nameplates: " .. what, tostring(err), nil, "volt") end
  end
end

local function AfterGlobal(name, what, fn)
  if type(_G[name]) ~= "function" then
    N.missing[#N.missing + 1] = name
    return false
  end
  hooksecurefunc(name, function(...) Guard(what, fn, ...) end)
  return true
end

local function AfterMethod(obj, name, what, fn)
  if type(obj) ~= "table" or type(obj[name]) ~= "function" then return end
  hooksecurefunc(obj, name, function(...) Guard(what, fn, ...) end)
end

-- One of the game's nameplate sizes (only read), or `default`.
local function Setup(key, default)
  local o = _G.NamePlateSetupOptions
  local v = type(o) == "table" and Safe(o[key]) or nil
  if type(v) == "number" and v > 0 then return v end
  return default
end

local function Fade(...)
  for i = 1, select("#", ...) do
    local o = select(i, ...)
    if type(o) == "table" and o.SetAlpha then o:SetAlpha(0) end
  end
end

local function SetFace(fs, px, role)
  local ok = pcall(fs.SetFont, fs, S.Font(nil, role).path, px, "OUTLINE")
  if not ok or (fs.GetFont and not fs:GetFont()) then
    pcall(fs.SetFont, fs, "Fonts\\FRIZQT__.TTF", px, "OUTLINE")
  end
end

-- VoltUI's font on one of plate f's texts, at the game's size for it (`baseKey` in its setup
-- options) times the setting `scaleKey`. The game sets the size again whenever it sets a frame up.
local function Face(f, fs, baseKey, baseDefault, scaleKey, role)
  if type(fs) ~= "table" or not fs.SetFont then return end
  local rec = N.faces[fs]
  if not rec then
    rec = { base = baseKey, default = baseDefault, key = scaleKey }
    N.faces[fs] = rec
  end
  if role then rec.role = role end
  local scale = tonumber(N:Opt(f, rec.key)) or 1
  local p = N.plates[f]
  if rec.key == "nameScale" and p and p.target then
    scale = scale * (tonumber(N:Cfg().target.nameScale) or 1)
  end
  local px = floor(Setup(rec.base, rec.default) * scale * 2 + 0.5) / 2
  if px < 6 then px = 6 end
  SetFace(fs, px, rec.role)
  -- The game scales these texts to a height of its own; that height becomes VoltUI's size.
  if fs.SetTextHeight then pcall(fs.SetTextHeight, fs, px) end
end

local function Near(a, b) return abs(a - b) < 0.02 end
local function Same(c, r, g, b) return c and Near(c[1], r) and Near(c[2], g) and Near(c[3], b) end

-- VoltUI's colour for the game's r, g, b, or nil to keep the game's.
function N.Soften(r, g, b)
  for _, s in ipairs(GAME_COLORS) do
    if Near(r, s[1]) and Near(g, s[2]) and Near(b, s[3]) then return N:Color(s[4]) end
  end
end

-- `n` screen pixels, in the units of `region`, which nameplates scale. Plain units if the game
-- won't say.
local function Pixels(region, n)
  local pu = _G.PixelUtil
  local factor = pu and pu.GetPixelToUIUnitFactor and Safe(pu.GetPixelToUIUnitFactor())
  local scale = region and region.GetEffectiveScale and Safe(region:GetEffectiveScale())
  if type(factor) == "number" and type(scale) == "number" and scale > 0 then return n * factor / scale end
  return n
end

-- Four lines round `anchor`, sized later by Place. Left to snap to whole pixels.
local function Lines(parent, layer, sub, anchor)
  local e = { anchor = anchor }
  for i = 1, 4 do e[i] = parent:CreateTexture(nil, layer, nil, sub) end
  return e
end

-- The lines `size` thick, starting `from` outside the anchor's edge. The sides fit between the
-- top and bottom, so the corners aren't drawn twice.
local function Place(e, from, size)
  if e.from == from and e.size == size then return end
  e.from, e.size = from, size
  local a, o = e.anchor, from + size
  for i = 1, 4 do e[i]:ClearAllPoints() end
  e[1]:SetPoint("TOPLEFT", a, "TOPLEFT", -o, o); e[1]:SetPoint("TOPRIGHT", a, "TOPRIGHT", o, o); e[1]:SetHeight(size)
  e[2]:SetPoint("BOTTOMLEFT", a, "BOTTOMLEFT", -o, -o); e[2]:SetPoint("BOTTOMRIGHT", a, "BOTTOMRIGHT", o, -o); e[2]:SetHeight(size)
  e[3]:SetPoint("TOPLEFT", a, "TOPLEFT", -o, from); e[3]:SetPoint("BOTTOMLEFT", a, "BOTTOMLEFT", -o, -from); e[3]:SetWidth(size)
  e[4]:SetPoint("TOPRIGHT", a, "TOPRIGHT", o, from); e[4]:SetPoint("BOTTOMRIGHT", a, "BOTTOMRIGHT", o, -from); e[4]:SetWidth(size)
end

local function Paint(e, rgb, a)
  S.ColorEdges(e, rgb[1], rgb[2], rgb[3], a)
end

local function Off(e)
  for i = 1, 4 do e[i]:Hide() end
end

------------------------------------------------------------------------
-- Bar textures: the same list as the rest of VoltUI (Style.lua): flat, VoltUI's own, two of the
-- game's, and any LibSharedMedia ones other add-ons register
------------------------------------------------------------------------

function N.Textures() return S.BarTextures() end

-- The nameplates keep their own pick; nothing saved is flat, as before 1.69.0.
function N:TexturePath(f)
  return S.BarPath(self:Opt(f, "texture") or "flat")
end

------------------------------------------------------------------------
-- The unit
------------------------------------------------------------------------

local function HealthBar(f)
  local c = f.HealthBarsContainer
  return type(c) == "table" and c.healthBar or nil
end

local function UnitOf(f)
  local u = Safe(f.displayedUnit) or Safe(f.unit)
  return type(u) == "string" and u or nil
end

local function ClassRGB(u)
  if not UnitClass then return end
  local _, class = UnitClass(u)
  class = Safe(class)
  if type(class) ~= "string" then return end
  local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  if not c and C_ClassColor and C_ClassColor.GetClassColor then c = C_ClassColor.GetClassColor(class) end
  if c and type(c.r) == "number" then return c.r, c.g, c.b end
end

local function Yes(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, v = pcall(fn, ...)
  if not ok then return nil end
  return Safe(v)
end

------------------------------------------------------------------------
-- The health bar, its border, its text and the level box
------------------------------------------------------------------------

-- The parts VoltUI adds to one of the game's nameplate frames, made once per frame.
function N:Build(f)
  local hb = HealthBar(f)
  local p = { hb = hb, kind = "enemy" }
  self.plates[f] = p
  p.track = S.Tex(hb, "BACKGROUND", -8)
  p.track:SetAllPoints(hb)
  p.edge = Lines(hb, "BACKGROUND", -7, hb)
  p.ring = Lines(hb, "BACKGROUND", -7, hb)
  -- Above the fill and absorbs, below the health text.
  p.dim = S.Tex(hb, "ARTWORK", 7)
  p.dim:SetAllPoints(hb)
  p.dim:SetColorTexture(0, 0, 0, 1)
  p.dim:SetAlpha(0)
  p.text = hb:CreateFontString(nil, "OVERLAY", nil, 7)
  p.text:SetWordWrap(false)
  p.text:Hide()
  p.quest = hb:CreateFontString(nil, "OVERLAY", nil, 7)
  p.quest:SetWordWrap(false)
  p.quest:SetPoint("LEFT", hb, "RIGHT", 4, 0)
  p.quest:SetTextColor(S.ACCENT[1], S.ACCENT[2], S.ACCENT[3])
  p.quest:Hide()

  local lf = f.PlayerLevelDiffFrame
  if type(lf) == "table" and lf.CreateTexture then
    local l = { frame = lf }
    l.fill = S.Tex(lf, "BACKGROUND", -8)
    l.fill:SetAllPoints(lf)
    l.edge = S.Edges(lf, "BACKGROUND", -7, lf, 0)
    self.levels[f] = l
  end

  local cb = f.CastBarsContainer and f.CastBarsContainer.castBar
  if type(cb) == "table" and cb.CreateTexture then self:BuildCast(f, cb) end

  AfterMethod(f, "UpdateAnchors", "health bar", function(frame) N:Flatten(frame) end)
  AfterMethod(f, "ApplyFrameOptions", "text", function(frame) N:Fonts(frame); N:CastSize(frame) end)
  AfterMethod(f, "OnUnitSet", "nameplates", function(frame) N:Dress(frame) end)
  AfterMethod(f, "UpdateAggroHighlight", "aggro border", function(frame) N:Aggro(frame) end)
  AfterMethod(f, "UpdateIsTarget", "target border", function(frame) N:Targeted(frame) end)
  AfterMethod(f, "UpdateIsFocus", "focus border", function(frame) N:Paint(frame) end)
  local af = f.AurasFrame
  if type(af) == "table" then self.auraOwner[af] = f end
  AfterMethod(af, "RefreshList", "aura icons", function(frame) N:SkinAuras(frame) end)
  AfterMethod(af, "RefreshLossOfControl", "aura icons", function(frame) N:SkinAuras(frame) end)
  return p
end

function N:Skin(f)
  if self.yielded or type(f) ~= "table" or not HealthBar(f) then return end
  if f.IsForbidden and f:IsForbidden() then return end
  if not self.plates[f] then self:Build(f) end
  self:Dress(f)
end

-- Which set this plate uses, and whether it's your target: worked out again with each new unit.
function N:Sort(f)
  local p = self.plates[f]
  local u = UnitOf(f)
  local friend = u and Yes(UnitIsFriend, "player", u)
  p.kind = friend == true and "friendly" or "enemy"
  p.target = Safe(f.isTarget) == true
end

-- Your target changed: a plate that became or stopped being it gets your target's settings or
-- its own back. Only the border changes when your target's settings are all "the same".
function N:Targeted(f)
  local p = self.plates[f]
  if not p then return end
  local now = Safe(f.isTarget) == true
  if now == p.target then return self:Paint(f) end
  p.target = now
  local t = self:Cfg().target
  if t.border ~= 0 or t.barHeight ~= 0 or t.hpText ~= "same" or t.nameScale ~= 1 then
    self:Dress(f)
  else
    self:Paint(f)
  end
end

-- Everything VoltUI sets on one frame: after it's styled, after it gets a new unit, after a setting.
function N:Dress(f)
  if not self.plates[f] then return end
  self:Sort(f)
  self:Flatten(f)
  self:Fonts(f)
  self:CastSize(f)
  self:ColorHealth(f)
  self:ColorName(f)
  self:HealthText(f)
  self:Aggro(f)
  self:Quest(f)
  self:SkinAuras(f.AurasFrame)
  local cb = f.CastBarsContainer and f.CastBarsContainer.castBar
  if self.casts[cb] then self:DressCast(cb) end
end

-- Quest marker (1.101.22). The game's tooltip for a creature lists the objectives of your
-- quests that it counts toward ("Kobold Vermin slain: 3/8"); that list is read as data
-- (C_TooltipInfo.GetUnit), so nothing is shown or hovered. A creature with an objective
-- still unfinished gets a gold "!" after its health bar, with how many are left when the
-- line says. In a group the tooltip lists other players' progress too: only your own lines
-- count. Lines the game hides (secret text) are skipped.
local LINE_OBJECTIVE, LINE_TITLE, LINE_PLAYER = 8, 17, 18

-- wanted (true or nil), and the most still needed on any one objective (or nil).
function N.QuestLeft(unit)
  local ti = _G.C_TooltipInfo
  if type(unit) ~= "string" or not (ti and ti.GetUnit) then return nil end
  local ok, data = pcall(ti.GetUnit, unit)
  if not ok or type(data) ~= "table" or S.IsSecret(data) or type(data.lines) ~= "table" then return nil end
  local kinds = Enum and Enum.TooltipDataLineType
  local objective = kinds and kinds.QuestObjective or LINE_OBJECTIVE
  local title = kinds and kinds.QuestTitle or LINE_TITLE
  local player = kinds and kinds.QuestPlayer or LINE_PLAYER
  local me = UnitName and Safe(UnitName("player"))
  local mine, wanted, most = true, nil, nil
  for _, line in ipairs(data.lines) do
    local kind, text = type(line) == "table" and line.type, type(line) == "table" and line.leftText
    if kind ~= nil and not S.IsSecret(kind) and not S.IsSecret(text) then
      if kind == title then
        mine = true
      elseif kind == player then
        mine = me ~= nil and text == me
      elseif kind == objective and mine and type(text) == "string" then
        local have, need = text:match("(%d+)%s*/%s*(%d+)")
        have, need = tonumber(have), tonumber(need)
        if have and need then
          if have < need then
            wanted = true
            if not most or need - have > most then most = need - have end
          end
        else
          local pct = tonumber(text:match("(%d+)%%"))
          if pct and pct < 100 then wanted = true end
        end
      end
    end
  end
  return wanted, most
end

function N:Quest(f)
  local p = self.plates[f]
  if not p or not p.quest then return end
  local u = UnitOf(f)
  if not u or not self:Cfg().quest or Yes(UnitIsPlayer, u) == true then return p.quest:Hide() end
  local wanted, most = N.QuestLeft(u)
  if not wanted then return p.quest:Hide() end
  SetFace(p.quest, 11, "mono")
  p.quest:SetText(most and ("!" .. most) or "!")
  p.quest:Show()
end

-- Quest progress changed: every plate's marker again, once, a moment later (the events come in bursts).
function N:QuestSoon()
  if self.questQueued then return end
  self.questQueued = true
  local run = function()
    N.questQueued = nil
    for f in pairs(N.plates) do Guard("quest marker", N.Quest, N, f) end
  end
  if C_Timer and C_Timer.After then C_Timer.After(0.3, run) else run() end
end

-- After the game lays a frame out: it sets its bar and level art again each time.
function N:Flatten(f)
  local p = self.plates[f]
  if not p then return end
  local hb = p.hb
  hb:SetStatusBarTexture(self:TexturePath(f))
  if p.shown then hb:SetStatusBarColor(p.shown[1], p.shown[2], p.shown[3]) end
  Fade(hb.bgTexture, hb.selectedBorder, hb.deselectedOverlay)
  p.track:SetColorTexture(TRACK[1], TRACK[2], TRACK[3], TRACK[4])

  local h = tonumber(self:Opt(f, "barHeight")) or 0
  if h > 0 then
    f.HealthBarsContainer:SetHeight(h)
    p.heightSet = true
  elseif p.heightSet then
    -- Back to the game's own height, from its setup options.
    f.HealthBarsContainer:SetHeight(Setup("healthBarHeight", 20))
    p.heightSet = nil
  end

  local l = self.levels[f]
  if l then
    Fade(l.frame.playerLevelDiffIcon, l.frame.selectedBorder)
    l.fill:SetColorTexture(S.BG[1], S.BG[2], S.BG[3], 0.9)
  end
  self:Paint(f)
end

function N:Fonts(f)
  local p = self.plates[f]
  if not p then return end
  local hb = p.hb
  Face(f, f.name, "healthBarFontHeight", 14, "nameScale", "plates.name")
  Face(f, hb.Text, "healthBarFontHeight", 14, "textScale", "plates.health")
  Face(f, hb.LeftText, "healthBarFontHeight", 14, "textScale", "plates.health")
  Face(f, hb.RightText, "healthBarFontHeight", 14, "textScale", "plates.health")
  Face(f, p.text, "healthBarFontHeight", 14, "textScale", "plates.health")
  local lf = f.PlayerLevelDiffFrame
  if type(lf) == "table" then Face(f, lf.playerLevelDiffText, "levelFontHeight", 10, "levelScale", "plates.level") end
  local lv = f.LevelFrame
  if type(lv) == "table" then Face(f, lv.LevelText, "levelFontHeight", 10, "levelScale", "plates.level") end
  local cb = f.CastBarsContainer and f.CastBarsContainer.castBar
  if type(cb) == "table" then
    Face(f, cb.Text, "castBarFontHeight", 10, "castScale", "plates.cast")
    Face(f, cb.CastTargetNameText, "castBarFontHeight", 10, "castScale", "plates.cast")
    local cp = self.casts[cb]
    if cp and cp.time then Face(f, cp.time, "castBarFontHeight", 10, "castScale", "plates.cast") end
  end
end

-- VoltUI's colour for this plate's health bar, or nil to keep the game's.
function N:WantColor(f, p)
  local c = self:Cfg()
  local game = p.game
  local u = UnitOf(f)
  if u and c.threat ~= "off" and UnitThreatSituation then
    local s = Yes(UnitThreatSituation, "player", u)
    if type(s) == "number" then
      if c.threat == "tank" then
        if s >= 3 then return self:Color("colThreatGood") end
        if s == 2 then return self:Color("colThreatWarn") end
        return self:Color("colThreatBad")
      elseif s >= 2 then
        return self:Color("colThreatBad")
      elseif s == 1 then
        return self:Color("colThreatWarn")
      end
    end
  end
  if Same(game, GREY[1], GREY[2], GREY[3]) then return nil end -- dead or offline: the game's grey
  if u and Yes(UnitIsPlayer, u) == true then
    local friend = Yes(UnitIsFriend, "player", u)
    if friend ~= nil then
      if self:Opt(f, "class") then
        local r, g, b = ClassRGB(u)
        if r then return { r, g, b } end
      end
      return self:Color(friend and "colPlayer" or "colHostile")
    end
  end
  return N.Soften(game[1], game[2], game[3])
end

-- After the game colours the health bar: VoltUI's colour for it. The game only sets its colour when
-- the bar shows another, so it's set again every time and VoltUI's goes after it.
function N:ColorHealth(f)
  local p = self.plates[f]
  if not p then return end
  local hb = p.hb
  local r, g, b = hb:GetStatusBarColor()
  r, g, b = Safe(r), Safe(g), Safe(b)
  if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then return end
  local s = p.shown
  if not (s and Near(r, s[1]) and Near(g, s[2]) and Near(b, s[3])) then
    p.game = { r, g, b } -- the game's own colour, for when VoltUI's is turned off
  end
  if not p.game then return end
  local want = self:Opt(f, "hpColor") == "volt" and self:WantColor(f, p) or nil
  if want then
    hb:SetStatusBarColor(want[1], want[2], want[3])
    p.shown = { want[1], want[2], want[3] }
  else
    if s then hb:SetStatusBarColor(p.game[1], p.game[2], p.game[3]) end
    p.shown = nil
  end
end

-- After the game colours the name. It sets its colour every time, so "the game's" needs nothing.
function N:ColorName(f)
  if not self.plates[f] then return end
  local mode = self:Opt(f, "nameColor")
  local fs = f.name
  if mode == "game" or type(fs) ~= "table" or not fs.SetVertexColor then return end
  if fs.GetVertexColor then
    local r, g, b = fs:GetVertexColor()
    r, g, b = Safe(r), Safe(g), Safe(b)
    if type(r) == "number" and Near(r, 0.5) and Near(g or 0, 0.5) and Near(b or 0, 0.5) then return end -- tapped or dead
  end
  local col = WHITE
  if mode == "class" then
    local u = UnitOf(f)
    if u and Yes(UnitIsPlayer, u) == true then
      local r, g, b = ClassRGB(u)
      if r then col = { r, g, b } end
    end
  end
  fs:SetVertexColor(col[1], col[2], col[3])
end

local JUSTIFY = { left = "LEFT", center = "CENTER", right = "RIGHT" }

-- VoltUI's health text, after the game updates the bar. Hidden when it's set to the game's own.
function N:HealthText(f)
  local p = self.plates[f]
  if not p then return end
  local hb, mode = p.hb, self:Opt(f, "hpText")
  local mine = mode ~= "game"
  for _, t in ipairs({ hb.Text, hb.LeftText, hb.RightText }) do
    if type(t) == "table" and t.SetAlpha then t:SetAlpha(mine and 0 or 1) end
  end
  local u = UnitOf(f)
  if not mine or mode == "off" or not u or not UnitHealth then
    p.text:Hide()
    return
  end
  local pos = JUSTIFY[self:Opt(f, "hpTextPos")] or "CENTER"
  if p.pos ~= pos then
    p.pos = pos
    p.text:ClearAllPoints()
    p.text:SetPoint(pos, hb, pos, pos == "LEFT" and 3 or pos == "RIGHT" and -3 or 0, 0)
    p.text:SetJustifyH(pos)
  end
  local cur, maxv = UnitHealth(u), UnitHealthMax and UnitHealthMax(u)
  if mode == "pct" then
    p.text:SetFormattedText("%s%%", S.HealthPercent(u, cur, maxv))
  elseif mode == "num" then
    p.text:SetFormattedText("%s", S.ShortNum(cur))
  else
    p.text:SetFormattedText("%s · %s%%", S.ShortNum(cur), S.HealthPercent(u, cur, maxv))
  end
  p.text:Show()
end

-- After the game shows or hides its aggro flare: that flare goes, and VoltUI's ring shows instead.
function N:Aggro(f)
  if not self.plates[f] then return end
  for _, t in ipairs({ f.aggroHighlightBase, f.aggroHighlightAdditive, f.aggroHighlightMask }) do
    if type(t) == "table" and t.Hide then t:Hide() end
  end
  self:Paint(f)
end

local function Thickness(f, region)
  local n = tonumber(N:Opt(f, "border")) or 1
  if n < 1 then n = 1 end
  return Pixels(region, n)
end

-- The border: your target or focus inside, aggro as a ring outside; and the dimming.
function N:Paint(f)
  local p = self.plates[f]
  if not p then return end
  local c = self:Cfg()
  local target = Safe(f.isTarget) == true
  local focus = Safe(f.isFocus) == true
  local mark
  local tc = c.target.color
  if target and tc ~= "off" then
    mark = tc == "white" and WHITE or S.ACCENT
  elseif focus and c.focus then
    mark = FOCUS
  end
  local t = Thickness(f, p.hb)
  Place(p.edge, 0, t)
  Place(p.ring, t, t)
  if mark then Paint(p.edge, mark, 1) else Paint(p.edge, self:TypeColor(f, "colBorder"), 0.9) end

  local threat
  local ah = f.aggroHighlight
  if c.aggro and type(ah) == "table" and ah.IsShown and ah:IsShown() then
    local r, g, b = ah:GetVertexColor()
    r, g, b = Safe(r), Safe(g), Safe(b)
    threat = (type(r) == "number" and type(g) == "number" and type(b) == "number") and { r, g, b } or AGGRO
  end
  if threat then
    Paint(p.ring, threat, 0.9)
  elseif mark and (mark == FOCUS or c.target.glow) then -- the faint ring round your target or focus
    Paint(p.ring, mark, 0.35)
  else
    Off(p.ring)
  end

  local dim = tonumber(c.dim) or 0
  local others = dim > 0 and not target and not focus and UnitExists ~= nil and Safe(UnitExists("target")) == true
  p.dim:SetAlpha(others and dim or 0)

  local l = self.levels[f]
  if l then
    if mark then Paint(l.edge, mark, 1) else Paint(l.edge, S.EDGE, 0.8) end
  end
end

------------------------------------------------------------------------
-- The cast bar
------------------------------------------------------------------------

function N:BuildCast(f, cb)
  local cp = { frame = f }
  self.casts[cb] = cp
  cp.fill = S.Tex(cb, "BACKGROUND", -8)
  cp.fill:SetAllPoints(cb)
  cp.edge = Lines(cb, "BACKGROUND", -7, cb)
  if type(cb.Icon) == "table" then cp.iconEdge = S.Edges(cb, "OVERLAY", 2, cb.Icon, 1) end
  -- The time left, in a frame of VoltUI's own that shows and hides with the bar.
  cp.clock = CreateFrame("Frame", nil, cb)
  cp.clock:SetAllPoints(cb)
  cp.time = cp.clock:CreateFontString(nil, "OVERLAY")
  cp.time:SetPoint("RIGHT", cb, "RIGHT", -3, 0)
  cp.time:SetJustifyH("RIGHT")
  cp.clock:SetScript("OnUpdate", function(_, elapsed) N:Tick(cb, elapsed) end)
  cp.clock:Hide()
  AfterMethod(cb, "UpdateBarFillTexture", "cast bar", function(bar, isFull) N:PaintCast(bar, isFull) end)
  AfterMethod(cb, "HandleCastStart", "cast bar", function(bar) N:DressCast(bar) end)
  AfterMethod(cb, "HandleInterruptOrSpellFailed", "cast bar", function(bar) N:CastStopped(bar) end)
  AfterMethod(cb, "UpdateIconShown", "cast icon", function(bar) N:CastIcon(bar) end)
end

-- The cast bar's height, VoltUI's or the game's (from its setup options) at 0.
function N:CastSize(f)
  local cbc = f.CastBarsContainer
  local cb = cbc and cbc.castBar
  local cp = self.casts[cb]
  if not cp then return end
  local h = tonumber(self:Opt(f, "castHeight")) or 0
  local o = _G.NamePlateSetupOptions
  local inside = type(o) == "table" and Safe(o.spellNameInsideCastBar) == true
  if h > 0 then
    cbc:SetHeight(inside and h or h + Setup("castIconHeight", 12))
    cb:SetHeight(h)
    cp.heightSet = true
  elseif cp.heightSet then
    local game = Setup("castBarHeight", 16)
    cbc:SetHeight(inside and game or game + Setup("castIconHeight", 12))
    cb:SetHeight(game)
    cp.heightSet = nil
  end
end

function N:DressCast(cb)
  local cp = self.casts[cb]
  if not cp then return end
  local f = cp.frame
  local on = self:Opt(f, "castBar")
  Fade(cb.Border)
  if cb.Background and cb.Background.SetAlpha then cb.Background:SetAlpha(on and 0 or 1) end
  cp.fill:SetColorTexture(TRACK[1], TRACK[2], TRACK[3], on and TRACK[4] or 0)
  if on then
    Place(cp.edge, 0, Thickness(f, cb))
    Paint(cp.edge, self:TypeColor(f, "colBorder"), 0.9)
  else
    Off(cp.edge)
  end
  if type(cb.Icon) == "table" and cb.Icon.SetTexCoord then
    if on then cb.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) else cb.Icon:SetTexCoord(0, 1, 0, 1) end
  end
  if self:Opt(f, "castTime") then
    if cp.time.GetFont and not cp.time:GetFont() then Face(f, cp.time, "castBarFontHeight", 10, "castScale", "plates.cast") end
    cp.clock:Show()
    self:Tick(cb, 1)
  else
    cp.clock:Hide()
  end
  self:CastIcon(cb)
  self:PaintCast(cb)
end

-- The time left on the cast, a few times a second. Blank when the bar's numbers can't be read.
function N:Tick(cb, elapsed)
  local cp = self.casts[cb]
  if not cp then return end
  cp.wait = (cp.wait or 0) - (elapsed or 0)
  if cp.wait > 0 then return end
  cp.wait = 0.05
  local v, m = Safe(cb.value), Safe(cb.maxValue)
  local left
  if type(v) == "number" and type(m) == "number" then
    if cb.casting then
      left = m - v
    elseif cb.channeling or cb.reverseChanneling then
      left = v
    end
  end
  if left and left >= 0 then
    cp.time:SetFormattedText("%.1f", left)
  else
    cp.time:SetText("")
  end
end

function N:CastIcon(cb)
  local cp = self.casts[cb]
  if not cp or not cp.iconEdge then return end
  local shown = self:Opt(cp.frame, "castBar") and cb.Icon.IsShown and cb.Icon:IsShown()
  if shown then Paint(cp.iconEdge, BLACK, 0.9) else Off(cp.iconEdge) end
end

local function FillBar(cb, col)
  local cp = N.casts[cb]
  cb:SetStatusBarTexture(N:TexturePath(cp and cp.frame))
  S.BarColor(cb, col[1], col[2], col[3])
end

-- After the game picks the cast bar's art: VoltUI's colour for the same kind of cast. `isFull` is the
-- bar filling up at the end (done, or stopped): it keeps the colour it had.
function N:PaintCast(cb, isFull)
  local cp = self.casts[cb]
  if not cp or not self:Opt(cp.frame, "castBar") then return end
  local f = cp.frame
  local kind = Safe(cb.barType)
  local failed = self:TypeColor(f, "colFailed")
  if kind == "interrupted" then return FillBar(cb, failed) end
  local channel = cb.channeling or cb.reverseChanneling
  local base = self:TypeColor(f, channel and "colChannel" or "colCast")
  local lockedCol = self:TypeColor(f, "colLocked")
  if isFull or not (cb.casting or channel) then
    FillBar(cb, cp.last and self:TypeColor(f, cp.last) or base)
    return
  end
  -- Whether it can be interrupted, asked of the game, since the bar's own note of it can be secret.
  local locked
  local unit = cb.unit
  if type(unit) == "string" then
    if channel then
      locked = select(7, UnitChannelInfo(unit))
    else
      locked = select(8, UnitCastingInfo(unit))
    end
  elseif kind == "uninterruptable" then
    locked = true
  end
  if S.IsSecret(locked) then
    local pick = C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean
    if pick then
      cb:SetStatusBarTexture(self:TexturePath(f))
      S.BarColor(cb, pick(locked, lockedCol[1], base[1]), pick(locked, lockedCol[2], base[2]), pick(locked, lockedCol[3], base[3]))
      cp.last = nil -- can't be kept, being secret
      return
    end
    locked = false
  end
  local key = locked and "colLocked" or (channel and "colChannel" or "colCast")
  FillBar(cb, self:TypeColor(f, key))
  cp.last = key
end

-- After an interrupt or a failed cast: red, when the game did stop the bar.
function N:CastStopped(cb)
  local cp = self.casts[cb]
  if not cp or not self:Opt(cp.frame, "castBar") then return end
  if not (cb.casting or cb.channeling or cb.reverseChanneling) then
    FillBar(cb, self:TypeColor(cp.frame, "colFailed"))
    cp.last = "colFailed"
  end
end

------------------------------------------------------------------------
-- Aura icons
------------------------------------------------------------------------

-- The colour of an aura's type, or nil.
local function TypeColor(kind)
  if type(kind) ~= "string" or kind == "" then return end
  local c = DebuffTypeColor and DebuffTypeColor[kind]
  if c and type(c.r) == "number" then return { c.r, c.g, c.b } end
  return DEBUFF_TYPES[kind]
end

local function Field(t, k) return t[k] end

-- An aura's dispel type, or nil. On enemy plates the game can hand over the whole aura as a secret
-- table, which can't even be indexed; its border then stays black.
local function DispelName(aura)
  if type(aura) ~= "table" or S.IsSecret(aura) then return end
  if canaccesstable and not canaccesstable(aura) then return end
  local ok, v = pcall(Field, aura, "dispelName")
  if ok then return Safe(v) end
end

-- After the game puts an aura on one of its icons: its type, for the border.
function N:AuraSet(item, aura)
  local a = self.auras[item]
  if not a then return end
  a.kind = DispelName(aura)
  self:SkinAura(item)
end

-- One of the game's aura icons on plate f: square, with a thin border, no round mask or frame.
function N:SkinAura(item, f)
  if type(item) ~= "table" or type(item.Icon) ~= "table" then return end
  local a = self.auras[item]
  if not a then
    a = { mask = {}, art = {}, frame = f }
    self.auras[item] = a
    for _, r in ipairs({ item:GetRegions() }) do
      local kind = r.GetObjectType and r:GetObjectType()
      if kind == "MaskTexture" then
        a.mask[#a.mask + 1] = r
      elseif kind == "Texture" and r ~= item.Icon then
        a.art[#a.art + 1] = r
      end
    end
    a.edge = S.Edges(item, "OVERLAY", 7, item.Icon, 0)
    if item.CountFrame then a.count = item.CountFrame.Count end
    a.cd = item.Cooldown
    if type(a.cd) == "table" and a.cd.GetCountdownFontString then
      local ok, fs = pcall(a.cd.GetCountdownFontString, a.cd)
      if ok and type(fs) == "table" then a.timer = fs end
    end
    AfterMethod(item, "SetAura", "aura icons", function(it, aura) N:AuraSet(it, aura) end)
  end
  if f then a.frame = f end -- pooled icons can move to another plate
  f = a.frame
  local function c(key) return N:Opt(f, key) end
  local on = c("auras")
  for _, m in ipairs(a.mask) do
    if on then
      if item.Icon.RemoveMaskTexture then pcall(item.Icon.RemoveMaskTexture, item.Icon, m) end
    elseif item.Icon.AddMaskTexture then
      pcall(item.Icon.AddMaskTexture, item.Icon, m)
    end
  end
  for _, t in ipairs(a.art) do t:SetAlpha(on and 0 or 1) end
  if item.Icon.SetTexCoord then
    if on then item.Icon:SetTexCoord(0.1, 0.9, 0.1, 0.9) else item.Icon:SetTexCoord(0, 1, 0, 1) end
  end
  if on then
    local col = c("auraBorder") == "type" and TypeColor(a.kind) or nil
    Paint(a.edge, col or BLACK, 1)
  else
    Off(a.edge)
  end
  if a.count then SetFace(a.count, max(6, floor(10 * (tonumber(c("stackScale")) or 1) + 0.5)), "plates.auras") end
  local cd = a.cd
  if type(cd) == "table" then
    -- The game sets whether numbers show with each aura; VoltUI only overrules it when asked to.
    local timer = c("auraTimer")
    if timer ~= "short" and cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(timer == "off") end
    if cd.SetDrawSwipe then cd:SetDrawSwipe(c("swipe") or not on) end
  end
  if a.timer then SetFace(a.timer, max(6, floor(10 * (tonumber(c("timerScale")) or 1) + 0.5)), "plates.auras") end
end

-- Each list's size, VoltUI's on top of the game's own aura scale. Left alone until it's changed.
local LISTS = { DebuffListFrame = "debuffScale", BuffListFrame = "buffScale", CrowdControlListFrame = "ccScale" }

function N:SkinAuras(af)
  if type(af) ~= "table" then return end
  local f = self.auraOwner[af]
  for field, key in pairs(LISTS) do
    local list = af[field]
    if type(list) == "table" and list.SetScale then
      local s = tonumber(self:Opt(f, key)) or 1
      if s <= 0 then s = 1 end
      if self.lists[list] ~= s and (self.lists[list] or s ~= 1) then
        list:SetScale(s)
        self.lists[list] = s
      end
    end
  end
  local pool = af.auraItemFramePool
  if type(pool) == "table" and pool.EnumerateActive then
    for item in pool:EnumerateActive() do self:SkinAura(item, f) end
  end
  local loc = af.LossOfControlFrame
  if type(loc) == "table" then self:SkinAura(loc.AuraItemFrame, f) end
end

------------------------------------------------------------------------
-- Start, settings
------------------------------------------------------------------------

function N:Sweep()
  local np = C_NamePlate
  if type(np) ~= "table" or not np.GetNamePlates then return end
  for _, plate in ipairs(np.GetNamePlates() or {}) do
    Guard("nameplates", self.Skin, self, plate.UnitFrame)
  end
end

-- Every plate's border and dimming, when the target or focus changes.
function N:PaintAll()
  for f in pairs(self.plates) do Guard("target border", self.Paint, self, f) end
end

function N:Refresh()
  if not self.enabled or self.yielded then return end
  for f in pairs(self.plates) do Guard("nameplates", self.Dress, self, f) end
end

------------------------------------------------------------------------
-- A sketch of a plate for the settings pages (1.97.0)
------------------------------------------------------------------------
-- The real plates are the game's and only exist on units in the world, so the settings
-- pages get a drawing of one: VoltUI's own frame, laid out like a plate and dressed from the
-- same settings (one for the enemy set, one for the friendly set, one for your target on an
-- enemy). It's a sketch: the game's sizes are read where it gives them, and its own art
-- (with VoltUI's cast bar or aura icons switched off) is only hinted at. Its parts can be
-- clicked (Style.lua, PickZones) to bring that part's settings together.

local MOCK = {
  enemy = { name = "Defias Pillager", level = "14", game = { 1, 0, 0 }, col = "colHostile", nameCol = { 1, 0.35, 0.3 } },
  friendly = { name = "Town Guard", level = "30", game = { 0, 1, 0 }, col = "colFriendly", nameCol = { 0.45, 1, 0.45 } },
}
local MOCK_W, MOCK_AURA = 132, 18
local MOCK_AURAS = {
  { list = "debuffScale", icon = "Interface\\Icons\\Spell_Shadow_ShadowWordPain", kind = "Magic", left = 12, stacks = 3 },
  { list = "debuffScale", icon = "Interface\\Icons\\Ability_Rogue_Rupture", left = 45 },
  { list = "buffScale", icon = "Interface\\Icons\\Spell_Holy_PowerWordShield", left = 120 },
  { list = "ccScale", icon = "Interface\\Icons\\Spell_Frost_FrostNova", kind = "Magic", left = 6 },
}

-- What a click on the sketch picks, from the back to the front. The target's page only has
-- the parts it can change.
local ALL_PLATES = { plates = true, friendly = true }
N.PARTS = {
  { key = "border", name = "Border", region = function(m) return m.hb, 5 end },
  { key = "health", name = "Health bar", region = function(m) return m.hb, 0 end },
  { key = "cast", name = "Cast bar", only = ALL_PLATES, region = function(m) return m.castBox, 1 end },
  { key = "auras", name = "Aura icons", only = ALL_PLATES, region = function(m) return m.auraBox, 1 end },
  { key = "name", name = "Name", region = function(m) return m.name, 2 end },
  { key = "level", name = "Level", only = ALL_PLATES, region = function(m) return m.levelBox, 1 end },
  { key = "hpText", name = "Health text", region = function(m) if m.text:IsShown() then return m.text, 2 end end },
}

local function MockText(parent)
  local fs = parent:CreateFontString(nil, "OVERLAY", nil, 7)
  if fs.SetWordWrap then fs:SetWordWrap(false) end
  return fs
end

function N:BuildMock(parent)
  local m = CreateFrame("Frame", nil, parent)
  m.mock = true
  m.hb = CreateFrame("StatusBar", nil, m)
  m.hb:SetMinMaxValues(0, 100)
  m.hb:SetValue(62)
  m.track = S.Tex(m.hb, "BACKGROUND", -8)
  m.track:SetAllPoints(m.hb)
  m.track:SetColorTexture(TRACK[1], TRACK[2], TRACK[3], TRACK[4])
  m.edge = Lines(m.hb, "BACKGROUND", -7, m.hb)
  m.ring = Lines(m.hb, "BACKGROUND", -7, m.hb)
  m.text = MockText(m.hb)
  m.name = MockText(m)
  m.levelBox = CreateFrame("Frame", nil, m)
  m.levelFill = S.Tex(m.levelBox, "BACKGROUND", -8)
  m.levelFill:SetAllPoints(m.levelBox)
  m.levelFill:SetColorTexture(TRACK[1], TRACK[2], TRACK[3], TRACK[4])
  m.levelEdge = S.Edges(m.levelBox, "BACKGROUND", -7, m.levelBox, 0)
  m.level = MockText(m.levelBox)
  m.level:SetPoint("CENTER", 0, 0)

  m.castBox = CreateFrame("Frame", nil, m)
  m.castIcon = S.Tex(m.castBox, "ARTWORK")
  m.castIcon:SetTexture("Interface\\Icons\\Spell_Fire_FlameBolt")
  m.castIconEdge = S.Edges(m.castBox, "OVERLAY", 2, m.castIcon, 1)
  m.cast = CreateFrame("StatusBar", nil, m.castBox)
  m.cast:SetMinMaxValues(0, 100)
  m.cast:SetValue(55)
  m.castTrack = S.Tex(m.cast, "BACKGROUND", -8)
  m.castTrack:SetAllPoints(m.cast)
  m.castEdge = Lines(m.cast, "BACKGROUND", -7, m.cast)
  m.castText = MockText(m.cast)
  m.castText:SetPoint("CENTER", 0, 0)
  m.castText:SetText("Fireball")
  m.castTime = MockText(m.cast)
  m.castTime:SetPoint("RIGHT", m.cast, "RIGHT", -3, 0)
  m.castTime:SetText("1.4")

  m.auraBox = CreateFrame("Frame", nil, m)
  m.auras = {}
  for i, def in ipairs(MOCK_AURAS) do
    local a = CreateFrame("Frame", nil, m.auraBox)
    a.def = def
    a.icon = S.Tex(a, "ARTWORK")
    a.icon:SetAllPoints(a)
    a.icon:SetTexture(def.icon)
    a.swipe = S.Tex(a, "ARTWORK", 2)
    a.swipe:SetPoint("TOPLEFT", a, "TOPLEFT", 0, 0)
    a.swipe:SetPoint("BOTTOMRIGHT", a, "BOTTOM", 0, 0)
    a.swipe:SetColorTexture(0, 0, 0, 0.55)
    a.edge = S.Edges(a, "OVERLAY", 7, a, 0)
    a.timer = MockText(a)
    a.timer:SetPoint("CENTER", 0, 0)
    a.count = MockText(a)
    a.count:SetPoint("BOTTOMRIGHT", 1, -1)
    m.auras[i] = a
  end
  return m
end

local function MockPx(base, default, scale)
  local px = floor(Setup(base, default) * (tonumber(scale) or 1) * 2 + 0.5) / 2
  return px < 6 and 6 or px
end

local function TimerText(left, mode)
  if mode == "off" or (mode ~= "all" and left >= 60) then return "" end
  return left >= 60 and ("%dm"):format(floor(left / 60)) or tostring(left)
end

-- Lays the sketch out and dresses it from set `m.set` ("enemy", "friendly" or "target").
function N:DrawMock(m)
  local c = self:Cfg()
  local target = m.set == "target"
  local kind = target and "enemy" or m.set
  local who = MOCK[kind]
  local function opt(key)
    if target then
      local same, v = OVERRIDE[key], c.target[key]
      if same ~= nil and v ~= nil and v ~= same then return v end
    end
    local v = c[kind][key]
    if v == nil then v = self.TYPE_DEFAULTS[key] end
    return v
  end
  local function col(key)
    local v = opt(key)
    return IsColor(v) and v or self.TYPE_DEFAULTS[key]
  end
  local barH = tonumber(opt("barHeight")) or 0
  if barH <= 0 then barH = Setup("healthBarHeight", 20) end
  local castH = tonumber(opt("castHeight")) or 0
  if castH <= 0 then castH = Setup("castBarHeight", 16) end
  local namePx = MockPx("healthBarFontHeight", 14, (tonumber(opt("nameScale")) or 1) * (target and (tonumber(c.target.nameScale) or 1) or 1))

  -- the aura icons, in a row over the name
  local ax, tallest = 0, 0
  local on = opt("auras")
  for _, a in ipairs(m.auras) do
    local def = a.def
    local size = floor(MOCK_AURA * (tonumber(opt(def.list)) or 1) + 0.5)
    a:ClearAllPoints()
    a:SetSize(size, size)
    a:SetPoint("BOTTOMLEFT", m.auraBox, "BOTTOMLEFT", ax, 0)
    ax = ax + size + 3
    if size > tallest then tallest = size end
    if on then a.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9) else a.icon:SetTexCoord(0, 1, 0, 1) end
    if on then
      Paint(a.edge, opt("auraBorder") == "type" and TypeColor(def.kind) or BLACK, 1)
    else
      Off(a.edge)
    end
    a.swipe:SetShown((opt("swipe") or not on) and true or false)
    SetFace(a.timer, max(6, floor(10 * (tonumber(opt("timerScale")) or 1) + 0.5)), "plates.auras")
    a.timer:SetText(TimerText(def.left, opt("auraTimer")))
    SetFace(a.count, max(6, floor(10 * (tonumber(opt("stackScale")) or 1) + 0.5)), "plates.auras")
    a.count:SetText(def.stacks and tostring(def.stacks) or "")
  end
  m.auraBox:ClearAllPoints()
  m.auraBox:SetSize(max(1, ax - 3), tallest)
  m.auraBox:SetPoint("TOPLEFT", m, "TOPLEFT", 6, 0)

  -- the name, then the health bar with the level at its end
  SetFace(m.name, namePx, "plates.name")
  m.name:SetText(who.name)
  local mode = opt("nameColor")
  local nc = mode == "game" and who.nameCol or WHITE
  m.name:SetTextColor(nc[1], nc[2], nc[3])
  m.name:ClearAllPoints()
  m.name:SetPoint("TOP", m.hb, "TOP", 0, namePx + 3)
  local y = tallest + 3 + namePx + 3
  m.hb:ClearAllPoints()
  m.hb:SetSize(MOCK_W, barH)
  m.hb:SetPoint("TOPLEFT", m, "TOPLEFT", 6, -y)
  m.hb:SetStatusBarTexture(S.BarPath(opt("texture") or "flat"))
  local hc = opt("hpColor") == "volt" and self:Color(who.col) or who.game
  m.hb:SetStatusBarColor(hc[1], hc[2], hc[3])
  local t = Pixels(m.hb, max(1, tonumber(opt("border")) or 1))
  local mark
  if target and c.target.color ~= "off" then mark = c.target.color == "white" and WHITE or S.ACCENT end
  m.edge.from, m.ring.from = nil, nil -- placed afresh: the bar's size may have changed under them
  Place(m.edge, 0, t)
  Place(m.ring, t, t)
  for i = 1, 4 do m.edge[i]:Show() end
  if mark then Paint(m.edge, mark, 1) else Paint(m.edge, col("colBorder"), 0.9) end
  if mark and c.target.glow then
    for i = 1, 4 do m.ring[i]:Show() end
    Paint(m.ring, mark, 0.35)
  else
    Off(m.ring)
  end

  local levelPx = MockPx("levelFontHeight", 10, opt("levelScale"))
  SetFace(m.level, levelPx, "plates.level")
  m.level:SetText(who.level)
  m.levelBox:ClearAllPoints()
  m.levelBox:SetSize(floor(levelPx * 1.6) + 6, barH)
  m.levelBox:SetPoint("LEFT", m.hb, "RIGHT", t + 2, 0)
  S.ColorEdges(m.levelEdge, S.EDGE[1], S.EDGE[2], S.EDGE[3], 0.8)

  -- the health text: VoltUI's in the place chosen, the game's own roughly as it draws it
  local hp = opt("hpText")
  local pos = hp == "game" and "CENTER" or JUSTIFY[opt("hpTextPos")] or "CENTER"
  SetFace(m.text, MockPx("healthBarFontHeight", 14, opt("textScale")), "plates.health")
  m.text:ClearAllPoints()
  m.text:SetPoint(pos, m.hb, pos, pos == "LEFT" and 3 or pos == "RIGHT" and -3 or 0, 0)
  m.text:SetJustifyH(pos)
  m.text:SetText(hp == "num" and S.ShortNum(1240) or hp == "both" and (S.ShortNum(1240) .. " · 62%") or "62%")
  m.text:SetShown(hp ~= "off")

  -- the cast bar under it, its icon at the left
  local castOn = opt("castBar")
  m.castBox:ClearAllPoints()
  m.castBox:SetSize(MOCK_W, castH)
  m.castBox:SetPoint("TOPLEFT", m.hb, "BOTTOMLEFT", 0, -(t + 3))
  m.castIcon:ClearAllPoints()
  m.castIcon:SetSize(castH, castH)
  m.castIcon:SetPoint("LEFT", m.castBox, "LEFT", 0, 0)
  if castOn then m.castIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92) else m.castIcon:SetTexCoord(0, 1, 0, 1) end
  S.ColorEdges(m.castIconEdge, 0, 0, 0, castOn and 1 or 0)
  m.cast:ClearAllPoints()
  m.cast:SetPoint("TOPLEFT", m.castIcon, "TOPRIGHT", 3, 0)
  m.cast:SetPoint("BOTTOMRIGHT", m.castBox, "BOTTOMRIGHT", 0, 0)
  m.cast:SetStatusBarTexture(castOn and S.BarPath(opt("texture") or "flat") or "Interface\\TargetingFrame\\UI-StatusBar")
  local cc = castOn and col("colCast") or { 1, 0.7, 0 }
  m.cast:SetStatusBarColor(cc[1], cc[2], cc[3])
  m.castTrack:SetColorTexture(TRACK[1], TRACK[2], TRACK[3], castOn and TRACK[4] or 0.5)
  m.castEdge.from = nil
  Place(m.castEdge, 0, t)
  if castOn then
    for i = 1, 4 do m.castEdge[i]:Show() end
    Paint(m.castEdge, col("colBorder"), 0.9)
  else
    Off(m.castEdge)
  end
  local castPx = MockPx("castBarFontHeight", 10, opt("castScale"))
  SetFace(m.castText, castPx, "plates.cast")
  SetFace(m.castTime, castPx, "plates.cast")
  m.castTime:SetShown(opt("castTime") and true or false)
  m.castBox:SetShown(not target) -- the target's page changes neither casts nor auras
  m.auraBox:SetShown(not target)
  m.levelBox:SetShown(not target)

  m.h = y + barH + t + 3 + castH
  m:SetSize(6 + MOCK_W + 40, m.h)
end

-- The sketch for a settings page: frame, its height, its scale (EditMode's preview strip).
function N:Preview(key, set, parent)
  self.previews = self.previews or {}
  local m = self.previews[key]
  if not m then
    m = self:BuildMock(parent)
    m.key, m.set = key, set
    self.previews[key] = m
  end
  self:DrawMock(m)
  m:Show()
  S.PickZones(m, key, self.PARTS, m)
  return m, m.h, 1
end

-- The game's shared unit frame functions, also used by the party and raid frames; only nameplates
-- VoltUI has styled are touched.
function N:HookHealth()
  if self.healthHooked then return true end
  if type(_G.CompactUnitFrame_UpdateHealthColor) ~= "function" then return false end
  self.healthHooked = true
  AfterGlobal("CompactUnitFrame_UpdateHealthColor", "health colour", function(frame)
    if N.plates[frame] then N:ColorHealth(frame) end
  end)
  if type(_G.CompactUnitFrame_UpdateHealth) == "function" then
    AfterGlobal("CompactUnitFrame_UpdateHealth", "health text", function(frame)
      if N.plates[frame] then N:HealthText(frame) end
    end)
  end
  if type(_G.CompactUnitFrame_UpdateMaxHealth) == "function" then
    AfterGlobal("CompactUnitFrame_UpdateMaxHealth", "health text", function(frame)
      if N.plates[frame] then N:HealthText(frame) end
    end)
  end
  if type(_G.CompactUnitFrame_UpdateName) == "function" then
    AfterGlobal("CompactUnitFrame_UpdateName", "name colour", function(frame)
      if N.plates[frame] then N:ColorName(frame) end
    end)
  end
  return true
end

function N:OnEvent(event, arg)
  if event == "NAME_PLATE_UNIT_ADDED" then
    local np = C_NamePlate
    local plate = np and np.GetNamePlateForUnit and np.GetNamePlateForUnit(arg)
    if plate then Guard("nameplates", self.Skin, self, plate.UnitFrame) end
  elseif event == "PLAYER_TARGET_CHANGED" then
    for f in pairs(self.plates) do Guard("target border", self.Targeted, self, f) end
  elseif event == "PLAYER_FOCUS_CHANGED" then
    self:PaintAll()
  elseif event == "UNIT_FACTION" then
    -- A unit turning hostile or friendly moves to the other set. This event comes for
    -- every unit token, and the game refuses party and raid ones here (it raised an
    -- error on "party1"), so only a nameplate's own token is looked up; a unit with a
    -- plate gets the event under that token too.
    if type(arg) ~= "string" or not arg:find("^nameplate%d") then return end
    local np = C_NamePlate
    local ok, plate = false, nil
    if np and np.GetNamePlateForUnit then ok, plate = pcall(np.GetNamePlateForUnit, arg) end
    if not ok then plate = nil end
    if plate and self.plates[plate.UnitFrame] then Guard("nameplates", self.Dress, self, plate.UnitFrame) end
  elseif event == "QUEST_LOG_UPDATE" or event == "UNIT_QUEST_LOG_CHANGED" or event == "QUEST_ACCEPTED" or event == "QUEST_REMOVED" then
    self:QuestSoon()
  elseif event == "ADDON_LOADED" then
    local was = self.healthHooked
    if self:HookHealth() and not was then self:Sweep() end
  end
end

-- The first other nameplate add-on that's loaded, if any.
local function Other()
  local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or _G.IsAddOnLoaded
  if not loaded then return end
  for _, name in ipairs(OTHERS) do
    local ok, on = pcall(loaded, name)
    if ok and on then return name end
  end
end

function N:Enable()
  self.enabled = true
  self:Cfg()
  local other = Other()
  if other then
    self.yielded = other
    FUI:Print("Nameplates: %s is drawing the nameplates, so VoltUI leaves them alone. Turn %s off to get VoltUI's.", other, other)
    return
  end
  local ev = CreateFrame("Frame")
  ev:RegisterEvent("NAME_PLATE_UNIT_ADDED")
  ev:RegisterEvent("PLAYER_TARGET_CHANGED")
  pcall(ev.RegisterEvent, ev, "PLAYER_FOCUS_CHANGED")
  pcall(ev.RegisterEvent, ev, "UNIT_FACTION")
  for _, e in ipairs({ "QUEST_LOG_UPDATE", "UNIT_QUEST_LOG_CHANGED", "QUEST_ACCEPTED", "QUEST_REMOVED" }) do pcall(ev.RegisterEvent, ev, e) end
  ev:RegisterEvent("ADDON_LOADED")
  ev:SetScript("OnEvent", function(_, event, arg) N:OnEvent(event, arg) end)
  self:HookHealth()
  self:Sweep()
end

local function OnOff(v) return v and "|cff7fff7fon|r" or "|cffff7f7foff|r" end

local function Count(t)
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  return n
end

function N:Slash(arg)
  local cmd = (arg or ""):match("^(%S*)")
  if not self.enabled then
    FUI:Print("Nameplates are off. /volt nameplates on, then /reload.")
    return
  end
  if self.yielded then
    FUI:Print("Nameplates: %s is loaded and draws them, so VoltUI leaves them alone.", self.yielded)
    return
  end
  if cmd == "options" or cmd == "settings" or cmd == "edit" then
    ns.EditMode:Open("plates")
    return
  end
  if cmd == "reset" then
    self:ResetCfg()
    FUI:Print("Nameplate settings are back to their defaults.")
    return
  end
  FUI:Print("Nameplates %s: %d styled so far, health colour hook %s.", OnOff(true), Count(self.plates), OnOff(self.healthHooked))
  if #self.missing > 0 then FUI:Print("Not on this client: %s", table.concat(self.missing, ", ")) end
  for what, err in pairs(self.reported) do FUI:Print("|cffff7f7f%s:|r %s", what, err) end
  FUI:Print("/volt nameplates options (the settings) · reset · on|off (needs /reload)")
end

FUI:Register(N)
