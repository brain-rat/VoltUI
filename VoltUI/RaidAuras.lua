-- VoltUI · Debuffs on the party and raid frames
-- A row of debuff icons along the bottom of each tile (Raid.lua). The ones you can remove
-- come first, framed in their type's colour (Magic blue, Curse purple, Disease brown, Poison
-- green) and a size bigger if that's on; the others follow with a dark frame, or not at all
-- with "only removable" on. Each has its time left drawn by the game's cooldown swipe and
-- numbers, which keep working in a fight.
--
-- Can you remove it? Two ways, either is enough:
--  * The game's own filter (HARMFUL|RAID: debuffs the player can dispel). It answers with a
--    plain true or false even in a fight.
--  * VoltUI's own check: the debuff's type against your dispel spells. The game's filter misses
--    some for Forever's spells. The type is secret in a fight, so this only adds to the
--    game's answer when the type can be read.
--
-- In a fight aura details are secret: icons, counts and times are handed straight to the
-- widgets, and a type that can't be read is coloured through the game's colour curve.
--
-- Since 1.27.0 a tile also shows your own HoTs and shields along the bottom right, with
-- their time left (the game's HELPFUL|PLAYER|RAID_IN_COMBAT filter: the ones it flags for
-- raid frames in a fight), and a corner icon for Earth Shield and Fear Ward from anyone.

local _, ns = ...
local FUI, S = ns.FUI, ns.Style

local A = { types = {} }
ns.RaidAuras = A

local Safe, IsSecret = S.Safe, S.IsSecret
local floor, min = math.floor, math.min

A.MAX = 6 -- icons per tile at most
A.MAX_HOTS = 5
local HOT_FILTER = "HELPFUL|PLAYER|RAID_IN_COMBAT"
A.HOT_FILTER = HOT_FILTER

-- Corner icons, top right: buffs worth seeing on anyone, whoever cast them. Ranks included.
A.CORNERS = {
  { key = "earthShield", name = "Earth Shield", ids = { 974, 32593, 32594 } },
  { key = "fearWard", name = "Fear Ward", ids = { 6346 } },
}
A.seen = {} -- aura instance ID -> spell ID, noted while it could be read
local seenCount = 0
local BIG = 1.4 -- how much bigger removable ones are with that setting on

local TYPE_COLORS = {
  Magic = { 0.2, 0.6, 1 }, Curse = { 0.6, 0, 1 }, Disease = { 0.6, 0.4, 0 }, Poison = { 0, 0.6, 0 },
}
A.TYPE_COLORS = TYPE_COLORS
local DARK_EDGE = { 0.05, 0.05, 0.05 }

-- Your dispel spells by class: spell ID = what it removes. Lower ranks are listed too.
A.DISPELS = {
  PRIEST = { [527] = { "Magic" }, [988] = { "Magic" }, [528] = { "Disease" }, [552] = { "Disease" } },
  PALADIN = { [1152] = { "Poison", "Disease" }, [4987] = { "Magic", "Poison", "Disease" } },
  DRUID = { [2782] = { "Curse" }, [8946] = { "Poison" }, [2893] = { "Poison" } },
  SHAMAN = { [526] = { "Poison" }, [2870] = { "Disease" } },
  MAGE = { [475] = { "Curse" } },
}

function A:FindDispels()
  wipe(self.types)
  local _, class = UnitClass("player")
  local list = self.DISPELS[Safe(class) or ""]
  if not list then return end
  for id, kinds in pairs(list) do
    if IsPlayerSpell and IsPlayerSpell(id) then
      for _, k in ipairs(kinds) do self.types[k] = true end
    end
  end
end

-- The dispel type IDs the game's colour curve is keyed by.
local function TypeIDs()
  local e = Enum and Enum.AuraDispelType
  if type(e) == "table" then
    return { Magic = e.Magic, Curse = e.Curse, Disease = e.Disease, Poison = e.Poison }
  end
  return { Magic = 1, Curse = 2, Disease = 3, Poison = 4 }
end

local curve
local function TypeCurve()
  if curve then return curve end
  local CU = C_CurveUtil
  if CU and CU.CreateColorCurve and CreateColor then
    local ok, c = pcall(CU.CreateColorCurve)
    if ok and c then
      if Enum and Enum.LuaCurveType and c.SetType then pcall(c.SetType, c, Enum.LuaCurveType.Step) end
      pcall(c.AddPoint, c, 0, CreateColor(DARK_EDGE[1], DARK_EDGE[2], DARK_EDGE[3], 1))
      for kind, id in pairs(TypeIDs()) do
        local col = TYPE_COLORS[kind]
        if type(id) == "number" then pcall(c.AddPoint, c, id, CreateColor(col[1], col[2], col[3], 1)) end
      end
      curve = c
    end
  end
  return curve
end

------------------------------------------------------------------------
-- Icons
------------------------------------------------------------------------

local function Icon(parent)
  local b = CreateFrame("Frame", nil, parent)
  b.tex = S.Tex(b, "ARTWORK")
  b.tex:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
  b.tex:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
  b.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  b.edges = S.Edges(b, "OVERLAY", 1, b)
  b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
  b.cd:SetAllPoints(b.tex)
  if b.cd.SetDrawEdge then b.cd:SetDrawEdge(false) end
  if b.cd.SetReverse then b.cd:SetReverse(true) end
  b.count = S.Text(b, nil, "RIGHT", "OVERLAY")
  b.count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 1, 0)
  b:Hide()
  return b
end

local function Paint(b, r, g, bl)
  S.ColorEdges(b.edges, r, g, bl, 1)
end

function A:Build(f)
  f.kdebuffs = {}
  for i = 1, self.MAX do f.kdebuffs[i] = Icon(f.ktop) end
  f.khots = {}
  for i = 1, self.MAX_HOTS do
    f.khots[i] = Icon(f.ktop)
    Paint(f.khots[i], DARK_EDGE[1], DARK_EDGE[2], DARK_EDGE[3])
  end
  f.kcorners = {}
  for i = 1, #self.CORNERS do
    f.kcorners[i] = Icon(f.ktop)
    Paint(f.kcorners[i], DARK_EDGE[1], DARK_EDGE[2], DARK_EDGE[3])
  end
end
A.Icon = Icon

-- Sizes and places the icons for a set: a row from the bottom left, above the power bar.
function A:Layout(f, c)
  local size = tonumber(c.debuffSize) or 14
  for _, b in ipairs(f.kdebuffs or {}) do
    b.ksize = size
    b:SetSize(size, size)
    if b.count.SetFont then pcall(b.count.SetFont, b.count, S.Font().path, floor(size * 0.6 + 0.5), "OUTLINE") end
    if b.cd.SetHideCountdownNumbers then b.cd:SetHideCountdownNumbers(size < 14) end
  end
  local hs = tonumber(c.hotSize) or 12
  for _, list in ipairs({ f.khots or {}, f.kcorners or {} }) do
    for _, b in ipairs(list) do
      b:SetSize(hs, hs)
      if b.count.SetFont then pcall(b.count.SetFont, b.count, S.Font().path, floor(hs * 0.6 + 0.5), "OUTLINE") end
      if b.cd.SetHideCountdownNumbers then b.cd:SetHideCountdownNumbers(hs < 12) end
    end
  end
  for i, b in ipairs(f.kcorners or {}) do
    b:ClearAllPoints()
    b:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2 - (i - 1) * (hs + 1), -2)
  end
  self:Place(f, c)
end

-- Puts the shown icons in a row; removable ones can be bigger.
function A:Place(f, c)
  local size = tonumber(c.debuffSize) or 14
  local ph = f.kshowPower and (tonumber(c.powerHeight) or 4) + 1 or 0
  local x = 2
  for _, b in ipairs(f.kdebuffs or {}) do
    if b:IsShown() then
      local s = (b.kremovable and c.bigRemovable) and floor(size * BIG + 0.5) or size
      b:SetSize(s, s)
      b:ClearAllPoints()
      b:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", x, 2 + ph)
      x = x + s + 1
    end
  end
  -- Your HoTs from the bottom right, leftwards.
  local hs = tonumber(c.hotSize) or 12
  local rx = 2
  for _, b in ipairs(f.khots or {}) do
    if b:IsShown() then
      b:ClearAllPoints()
      b:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -rx, 2 + ph)
      rx = rx + hs + 1
    end
  end
end

------------------------------------------------------------------------
-- Reading a unit's debuffs
------------------------------------------------------------------------

local function Ids(u, filter)
  local UA = C_UnitAuras
  if UA and UA.GetUnitAuraInstanceIDs then
    local ok, ids = pcall(UA.GetUnitAuraInstanceIDs, u, filter)
    if ok and type(ids) == "table" then return ids end
  end
  return {}
end

local function Data(u, id)
  local UA = C_UnitAuras
  if not (UA and UA.GetAuraDataByAuraInstanceID) then return end
  local ok, d = pcall(UA.GetAuraDataByAuraInstanceID, u, id)
  if ok and type(d) == "table" then return d end
end

-- A field of an aura's data, or nil if the game won't let VoltUI read it.
local function Index(d, k) return d[k] end
local function Field(d, k)
  if type(d) ~= "table" then return end
  if canaccesstable and not canaccesstable(d) then return end
  local ok, v = pcall(Index, d, k)
  if ok then return v end
end

A.Ids, A.Data, A.Field = Ids, Data, Field

-- Can you remove this debuff? (plain true or false)
function A:Removable(u, id, d)
  local UA = C_UnitAuras
  if UA and UA.IsAuraFilteredOutByInstanceID then
    local ok, out = pcall(UA.IsAuraFilteredOutByInstanceID, u, id, "HARMFUL|RAID")
    if ok and out == false then return true end
  end
  local kind = Safe(Field(d, "dispelName"))
  return type(kind) == "string" and self.types[kind] == true
end

-- The debuffs to show for a set, in order: { id, data, removable }. Without a set: every
-- debuff, the removable ones first.
local ALL = { removableFirst = true }

-- One reading of a unit's debuffs for everything that shows them (1.80.0): the member's tile,
-- their dispel window and the dispel warning each used to ask the game for the whole list on
-- every aura event. `who` is the frame asking. A reading made this instant is handed to each
-- frame once: a frame asking again has had a newer event, so it's read afresh. Without `who`
-- it's always read afresh.
A.scans = {}
function A:Scan(u, who)
  local now = GetTime and GetTime() or 0
  local s = self.scans[u]
  if who and s and s.t == now and not s.seen[who] then
    s.seen[who] = true
    return s
  end
  s = { t = now, seen = {}, all = {} }
  if who then s.seen[who] = true end
  local all = s.all
  for _, id in ipairs(Ids(u, "HARMFUL")) do
    if not IsSecret(id) then
      local d = Data(u, id)
      all[#all + 1] = { id = id, data = d, removable = self:Removable(u, id, d) }
    end
  end
  self.scans[u] = s
  return s
end

-- A reading put in a set's order.
function A:Order(scan, c)
  c = c or ALL
  local first, rest = {}, {}
  for _, e in ipairs(scan.all) do
    if e.removable and c.removableFirst then
      first[#first + 1] = e
    elseif e.removable or not c.onlyRemovable then
      rest[#rest + 1] = e
    end
  end
  for _, e in ipairs(rest) do first[#first + 1] = e end
  return first
end

function A:List(u, c, who)
  return self:Order(self:Scan(u, who), c)
end

-- The icon's frame colour: by type when it can be read, else through the game's colour
-- curve for removable ones; dark for the rest.
local function PaintType(b, u, id, d, removable)
  local kind = Safe(Field(d, "dispelName"))
  if type(kind) == "string" and TYPE_COLORS[kind] then
    local col = removable and TYPE_COLORS[kind] or DARK_EDGE
    Paint(b, col[1], col[2], col[3])
    return
  end
  if removable and C_UnitAuras and C_UnitAuras.GetAuraDispelTypeColor then
    local cv = TypeCurve()
    if cv then
      local ok, col = pcall(C_UnitAuras.GetAuraDispelTypeColor, u, id, cv)
      if ok and col and col.GetRGB then
        local r, g, bl = col:GetRGB()
        for i = 1, 4 do b.edges[i]:Show(); b.edges[i]:SetColorTexture(1, 1, 1, 1); b.edges[i]:SetVertexColor(r, g, bl) end
        return
      end
    end
  end
  Paint(b, DARK_EDGE[1], DARK_EDGE[2], DARK_EDGE[3])
end
A.PaintType = PaintType
A.TypeCurve = TypeCurve -- your own debuffs use the same secret-safe colours (Buffs.lua)

-- The time left and stacks of aura `id` on `u`, onto icon b.
local function Timer(b, u, id)
  local UA = C_UnitAuras
  if UA and UA.GetAuraDuration and b.cd.SetCooldownFromDurationObject then
    local ok, dur = pcall(UA.GetAuraDuration, u, id)
    if ok and dur then
      b.cd:SetCooldownFromDurationObject(dur, true)
    else
      b.cd:Clear()
    end
  end
  local stacks = ""
  if UA and UA.GetAuraApplicationDisplayCount then
    local ok, s = pcall(UA.GetAuraApplicationDisplayCount, u, id, 2)
    if ok and s then stacks = s end
  end
  b.count:SetText(stacks)
end
A.Timer = Timer

local function SpellTexture(id)
  if C_Spell and C_Spell.GetSpellTexture then
    local ok, t = pcall(C_Spell.GetSpellTexture, id)
    if ok and t then return t end
  end
end

-- The aura instance of a corner buff on `u`, if it's there: asked of the game by spell
-- (it only answers for auras it doesn't keep secret), else found among the unit's buffs by
-- the spell IDs noted while they could be read.
function A:FindCorner(u, spec, helpful)
  local UA = C_UnitAuras
  if UA and UA.GetUnitAuraBySpellID then
    for _, sid in ipairs(spec.ids) do
      local ok, d = pcall(UA.GetUnitAuraBySpellID, u, sid)
      if ok and type(d) == "table" then
        local id = Field(d, "auraInstanceID")
        if type(id) == "number" and not IsSecret(id) then return id, sid end
      end
    end
  end
  for _, id in ipairs(helpful) do
    if not IsSecret(id) then
      local sid = self.seen[id]
      if sid == nil then
        local v = Safe(Field(Data(u, id), "spellId"))
        if type(v) == "number" then
          if seenCount > 4000 then
            wipe(self.seen)
            seenCount = 0
          end
          self.seen[id], sid = v, v
          seenCount = seenCount + 1
        end
      end
      for _, want in ipairs(spec.ids) do
        if sid == want then return id, sid end
      end
    end
  end
end

-- Your HoTs and shields, and the corner buffs.
function A:UpdateHelpful(f, u, c)
  local hots, corners = f.khots, f.kcorners
  if not hots then return end
  local cornerIds = {}
  if u and c.corners then
    local helpful = Ids(u, "HELPFUL")
    for i, spec in ipairs(self.CORNERS) do
      local b = corners[i]
      local id, sid = self:FindCorner(u, spec, helpful)
      if id then
        cornerIds[id] = true
        b.kid = id
        b.tex:SetTexture(SpellTexture(sid) or SpellTexture(spec.ids[1]))
        Timer(b, u, id)
        b:Show()
      else
        b.kid = nil
        b:Hide()
      end
    end
  else
    for _, b in ipairs(corners) do
      b.kid = nil
      b:Hide()
    end
  end
  local list = {}
  if u and c.hots then
    for _, id in ipairs(Ids(u, HOT_FILTER)) do
      if not IsSecret(id) and not cornerIds[id] then list[#list + 1] = id end
    end
  end
  local count = min(tonumber(c.hotCount) or 3, self.MAX_HOTS)
  for i, b in ipairs(hots) do
    local id = i <= count and list[i]
    if id then
      b.kid = id
      b.tex:SetTexture(Field(Data(u, id), "icon"))
      Timer(b, u, id)
      b:Show()
    else
      b.kid = nil
      b:Hide()
    end
  end
end

function A:Update(f)
  local R = ns.Raid
  local u = f.kunit
  local icons = f.kdebuffs
  if not icons then return end
  local c = R:TileSet(f)
  -- Every debuff is read once: the removable ones go to the dispel warning whatever the tile
  -- shows; the tile shows what its set asks for.
  local scan = u and self:Scan(u, f)
  local all = scan and self:Order(scan) or {}
  local removable, list = {}, {}
  for _, e in ipairs(all) do
    if e.removable then removable[#removable + 1] = e end
  end
  if c.debuffs then
    if c.onlyRemovable then
      list = removable
    elseif c.removableFirst then
      list = all
    elseif scan then
      list = self:Order(scan, c) -- the same reading in this set's order, not the game asked again
    end
  end
  local count = min(tonumber(c.debuffCount) or 3, self.MAX)
  f.kremovableCount = #removable
  for i, b in ipairs(icons) do
    local e = i <= count and list[i]
    if e then
      b.kremovable = e.removable
      b.kid = e.id
      b.tex:SetTexture(Field(e.data, "icon"))
      PaintType(b, u, e.id, e.data, e.removable)
      Timer(b, u, e.id)
      b:Show()
    else
      b.kremovable, b.kid = nil, nil
      b:Hide()
    end
  end
  self:UpdateHelpful(f, u, c)
  self:Place(f, c)
  if self.OnUpdated then self:OnUpdated(f, removable) end -- the dispel warning (Dispel.lua)
end

-- The preview's made-up debuffs.
function A:PaintSim(f, m, c)
  local icons = f.kdebuffs
  if not icons then return end
  local list = {}
  if c.debuffs then
    local first, rest = {}, {}
    for _, d in ipairs(m.debuffs or {}) do
      if d.removable and c.removableFirst then
        first[#first + 1] = d
      elseif d.removable or not c.onlyRemovable then
        rest[#rest + 1] = d
      end
    end
    for _, d in ipairs(rest) do first[#first + 1] = d end
    list = first
  end
  local count = min(tonumber(c.debuffCount) or 3, self.MAX)
  for i, b in ipairs(icons) do
    local d = i <= count and list[i]
    if d then
      b.kremovable = d.removable
      b.tex:SetTexture(d.icon)
      local col = d.removable and TYPE_COLORS[d.kind] or DARK_EDGE
      Paint(b, col[1], col[2], col[3])
      b.count:SetText("")
      b.cd:Clear()
      b:Show()
    else
      b.kremovable = nil
      b:Hide()
    end
  end
  local hots = c.hots and m.hots or {}
  local hcount = min(tonumber(c.hotCount) or 3, self.MAX_HOTS)
  for i, b in ipairs(f.khots or {}) do
    local icon = i <= hcount and hots[i]
    if icon then
      b.tex:SetTexture(icon)
      b.count:SetText("")
      b.cd:Clear()
      b:Show()
    else
      b:Hide()
    end
  end
  for i, b in ipairs(f.kcorners or {}) do
    local icon = c.corners and m.corners and m.corners[i]
    if icon then
      b.tex:SetTexture(icon)
      b.count:SetText("")
      b.cd:Clear()
      b:Show()
    else
      b:Hide()
    end
  end
  self:Place(f, c)
end
