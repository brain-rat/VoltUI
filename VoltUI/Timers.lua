-- VoltUI · Timers (since 1.69.0)
-- Your class's cooldowns, buffs, procs, debuffs on your target, totems and weapon imbues as
-- icons or bars, with big countdown numbers, in the spirit of WeakAuras. Each class has a list
-- below, and whatever your spellbook holds with a cooldown of 10 seconds to 10 minutes that
-- the list doesn't name (racials, Forever's own spells) is found too. Only spells you know.
--
-- Since 1.102.0 nothing shows until you add it: the Timers page lists your timers, Add a
-- timer offers what was found for your class (or any spell by name or ID), and each timer
-- has its own settings: when it shows (in a fight, out of one, in which kind of place), how
-- it looks and what it does when missing or ready. A setting you haven't changed on a timer
-- follows the block it sits in (T:Opt).
--
--   Cooldowns     always there; dark with the time left while cooling down, a pulse when
--                 ready. Reactive ones (Overpower, Revenge, Execute, Riposte...) light up when
--                 usable. Blue when you're short of mana, rage or energy.
--   Buffs/procs   buffs to keep up (Lightning Shield, Battle Shout, seals, aspects...) are
--                 always there and flash red once they drop; procs (Clearcasting, Flurry,
--                 Enrage...) only show while up, with a pulse when they come.
--   On target     your debuffs to keep on the target (Flame Shock, Rend, Corruption...), when
--                 you have something to attack; they flash in a fight when they fall off.
--   Totems        a bar for each totem down, with its name and time; a flash when one goes.
--
-- Four groups, each moved while moving frames (/volt edit) and set up on the Timers page.
--
-- Numbers can be secret on this client in a fight. Times go to the game's own widgets as
-- duration objects (the cooldown's countdown numbers and StatusBar:SetTimerDuration), which
-- draw them whether VoltUI can read them or not. Whether a cooldown is running comes from the
-- isActive and isOnGCD fields, which the game never makes secret. Auras are found by name;
-- when a fight hides them, one already seen stays until the game says it went.
-- Only VoltUI's own frames, never the game's: fine in combat.

local _, ns = ...
local FUI, S = ns.FUI, ns.Style

local T = { key = "timers", name = "Timers", items = {}, holders = {}, widgets = {}, anims = {} }
ns.Timers = T

local Safe, IsSecret = S.Safe, S.IsSecret
local floor, max, min, sin, pi = math.floor, math.max, math.min, math.sin, math.pi

local function Ask(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a, b, c, d, e, f, g = pcall(fn, ...)
  if ok then return a, b, c, d, e, f, g end
end

local function Now() return GetTime and GetTime() or 0 end

------------------------------------------------------------------------
-- Groups and settings
------------------------------------------------------------------------

T.GROUPS = {
  { key = "buffs", name = "Buffs and procs" },
  { key = "cds", name = "Cooldowns" },
  { key = "debuffs", name = "On your target" },
  { key = "totems", name = "Totems" },
}
T.KIND_GROUP = { cd = "cds", keep = "buffs", proc = "buffs", imbue = "buffs", dot = "debuffs", totem = "totems" }
T.KIND_NAME = { cd = "Cooldown", keep = "Keep up", proc = "Proc", imbue = "Weapon", dot = "On target", totem = "Totem" }

-- One group's look. style: "icons" or "bars"; grow: "center", "right", "left" (rows) or
-- "down", "up" (columns). Bars are width x height with the icon at the left.
T.DEFAULTS = {
  buffs = { on = true, style = "icons", size = 40, numbers = 18, perRow = 8, gap = 4, grow = "center", width = 180, height = 22 },
  cds = { on = true, style = "icons", size = 36, numbers = 16, perRow = 10, gap = 4, grow = "center", width = 180, height = 20 },
  debuffs = { on = true, style = "icons", size = 34, numbers = 15, perRow = 8, gap = 4, grow = "center", width = 180, height = 20 },
  totems = { on = true, style = "bars", size = 34, numbers = 13, perRow = 4, gap = 3, grow = "down", width = 170, height = 20 },
  pulse = true,        -- a pulse when a cooldown is ready, or a buff, proc or totem comes up
  warnFight = true,    -- flash missing buffs (and your debuffs on the target) in a fight
  warnIdle = false,    -- flash missing long buffs (Lightning Shield, armors, imbues) out of a fight too (1.89.0)
  missIdle = false,    -- show missing buffs, faded, out of a fight (1.101.2: off, they only show in a fight)
  readyHide = false,   -- hide cooldowns while they're ready
  buffHide = false,    -- hide buffs you keep up and weapon imbues while they're on (1.74.0)...
  buffSoon = 60,       -- ...until this many seconds are left
  usable = true,       -- blue when short of power, dim while a reactive spell can't be used
  hideManager = true,  -- the game's Cooldown Manager out of sight while VoltUI reads it (1.99.0)
  idleAlpha = 1,       -- opacity out of combat with no target
  scale = 1,
}
-- Where each group starts, from the middle of the screen.
T.SPOTS = {
  buffs = { "CENTER", 0, -110 }, cds = { "CENTER", 0, -160 },
  debuffs = { "CENTER", 0, -66 }, totems = { "CENTER", -250, -150 },
}

local function Fill(t, d)
  for k, v in pairs(d) do
    if type(v) == "table" then
      if type(t[k]) ~= "table" then t[k] = {} end
      Fill(t[k], v)
    elseif t[k] == nil then
      t[k] = v
    end
  end
end

-- Asked several times for every timer on every cooldown and power event, so the defaults are
-- only filled in again for a new table (an import, a profile, a reset) or after T:Refresh.
function T:Cfg()
  local db = ns.db
  local c = db.timerCfg
  if c ~= nil and c == self.cfgFilled then return c end
  if type(c) ~= "table" then c = {}; db.timerCfg = c end
  -- Before 1.89.0 one choice, warn: smart (long buffs out of a fight too), combat, always, off.
  -- Out of a fight is a switch of its own now, off unless you'd picked Always.
  if type(c.warn) == "string" then
    if c.warnFight == nil then c.warnFight = c.warn ~= "off" end
    if c.warnIdle == nil then c.warnIdle = c.warn == "always" end
    c.warn = nil
  end
  Fill(c, T.DEFAULTS)
  if type(c.custom) ~= "table" then c.custom = {} end -- spells you've added: { class, kind, id }
  if type(c.order) ~= "table" then c.order = {} end   -- your order, once you've moved one: item keys
  -- (1.102.0) Your timers: auras[item key] = that timer's own settings (see T:Opt). A set-up
  -- from before has none: its list starts empty (asked for), and what was set for the groups
  -- and for every timer at once stays where it was, as what a timer you add starts from.
  if type(c.auras) ~= "table" then c.auras = {} end
  self.cfgFilled = c
  return c
end

function T:G(g) return self:Cfg()[g] end

------------------------------------------------------------------------
-- Your timers, and each one's own settings (1.102.0)
------------------------------------------------------------------------

-- false: only what you've added shows. true: everything found for your class is a timer
-- until you remove it, as before 1.102.0 (the tests use it; the user chose the empty list).
T.AUTO_LIST = false

-- Where you are, for a timer's places: the game's instance type to one of four.
T.PLACES = {
  { key = "world", name = "Open world" }, { key = "dungeon", name = "Dungeons" },
  { key = "raid", name = "Raids" }, { key = "pvp", name = "Battlegrounds" },
}
T.ZONES = { none = "world", party = "dungeon", scenario = "dungeon", raid = "raid", pvp = "pvp", arena = "pvp" }
T.WHEN = { { key = "always", name = "All the time" }, { key = "combat", name = "In a fight" }, { key = "idle", name = "Out of a fight" } }
T.LOOK_KEYS = { "style", "size", "numbers", "width", "height" }
local LOOK = {}
for _, k in ipairs(T.LOOK_KEYS) do LOOK[k] = true end
local GROUP_OK = {}
for _, g in ipairs(T.GROUPS) do GROUP_OK[g.key] = true end
T.KIND_LONG = { cd = "Cooldown", keep = "Buff to keep up", proc = "Proc", imbue = "Weapon imbue", dot = "On your target", totem = "Totem" }

-- One timer's own settings, if it's in your list.
function T:Aura(key)
  local a = self:Cfg().auras[key]
  return type(a) == "table" and a or nil
end

function T:Listed(key)
  local a = self:Cfg().auras[key]
  if T.AUTO_LIST then return a ~= false end
  return type(a) == "table"
end

-- The block a timer sits in: its own pick, else its kind's.
function T:GroupOf(it)
  local a = self:Aura(it.key)
  local g = a and a.group
  return GROUP_OK[g] and g or T.KIND_GROUP[it.kind]
end

-- What a setting is for a timer that hasn't changed it. Its look follows the block it sits
-- in; the rest follow what used to be set for every timer at once (before 1.102.0), so an
-- older set-up behaves as it did:
--   when     "always", "combat" or "idle"
--   world, dungeon, raid, pvp   shows in that kind of place
--   ready    a cooldown while it's ready: "show" or "hide"
--   up       a buff while it's on: "show" or "hide" (until `soon` seconds are left)
--   miss     a buff or debuff that's missing in a fight: "flash", "faded" or "hide"
--   missOut  the same out of a fight
--   pulse, usable   as before, for this timer
function T:OptDefault(it, k)
  local cfg = self:Cfg()
  if LOOK[k] then return cfg[self:GroupOf(it)][k] end
  if k == "group" then return T.KIND_GROUP[it.kind] end
  if k == "when" then return "always" end
  if k == "world" or k == "dungeon" or k == "raid" or k == "pvp" then return true end
  if k == "pulse" then return cfg.pulse ~= false end
  if k == "usable" then return cfg.usable ~= false end
  if k == "ready" then return cfg.readyHide and "hide" or "show" end
  if k == "up" then return cfg.buffHide and "hide" or "show" end
  if k == "soon" then return tonumber(cfg.buffSoon) or 60 end
  if k == "miss" then return cfg.warnFight and "flash" or "faded" end
  if k == "missOut" then
    if cfg.warnIdle and it.always then return "flash" end
    return cfg.missIdle and "faded" or "hide"
  end
  return nil
end

function T:Opt(it, k)
  local a = self:Cfg().auras[it.key]
  if type(a) == "table" then
    local v = a[k]
    if v ~= nil and (k ~= "group" or GROUP_OK[v]) then return v end
  end
  return self:OptDefault(it, k)
end

-- Changes one setting of a timer in your list. One put back to what it would be anyway is
-- forgotten, so it follows its block again.
function T:SetOpt(key, k, v)
  local it = self:Find(key)
  local a = self:Aura(key)
  if not it or not a then return false end
  a[k] = nil
  if v ~= nil and v ~= self:OptDefault(it, k) then a[k] = v end
  self:Refresh()
  return true
end

function T:Find(key)
  for i, it in ipairs(self.items) do
    if it.key == key then return it, i end
  end
end

-- An item's place in your list, the block it sits in and whether it's switched off.
function T:Mark(it)
  local a = self:Aura(it.key)
  it.listed = self:Listed(it.key)
  it.group = self:GroupOf(it)
  it.hidden = not it.listed or (a ~= nil and a.on == false)
  return it
end

-- Where you are: "world", "dungeon", "raid" or "pvp". Asked once, then kept until a loading
-- screen or a new zone (T:OnEvent) or a changed setting (T:Refresh).
function T:Zone()
  if self.zone then return self.zone end
  local inside, kind = Ask(IsInInstance)
  inside, kind = Safe(inside), Safe(kind)
  local z = "world"
  if inside == true and type(kind) == "string" then z = T.ZONES[kind] or "world" end
  self.zone = z
  return z
end

-- Do the timer's own conditions let it show now: in or out of a fight, and this kind of place.
function T:Allowed(it)
  local when = self:Opt(it, "when")
  if when == "combat" or when == "idle" then
    local fight = self:InCombat() and true or false
    if (when == "combat") ~= fight then return false end
  end
  return self:Opt(it, self:Zone()) ~= false
end

-- Your timers, in order; and what was found for your class that isn't one of them.
function T:Mine()
  local out = {}
  for _, it in ipairs(self.items) do if it.listed then out[#out + 1] = it end end
  return out
end

function T:Available()
  local out = {}
  for _, it in ipairs(self.items) do if not it.listed then out[#out + 1] = it end end
  return out
end

-- After the list or a switch changed: everything read again for what now shows.
function T:Relist()
  if not self.enabled then
    for _, it in ipairs(self.items) do self:Mark(it) end
    return
  end
  self:Refresh()
  self:UpdateAll()
end

-- Puts one of the spells found for your class in your list. True if it's there now.
function T:Add(key)
  local it = self:Find(key)
  if not it then return false end
  local auras = self:Cfg().auras
  if type(auras[key]) ~= "table" then auras[key] = {} end
  auras[key].on = nil
  self:Relist()
  return true
end

function T:AddAll()
  local auras = self:Cfg().auras
  local n = 0
  for _, it in ipairs(self.items) do
    if not it.listed then
      if type(auras[it.key]) ~= "table" then auras[it.key] = {} end
      n = n + 1
    end
  end
  self:Relist()
  return n
end

-- Takes one out of your list, its own settings with it. A spell you added by name or ID is
-- forgotten altogether; one of the class's goes back to Add a timer.
function T:Remove(key)
  local it = self:Find(key)
  local cfg = self:Cfg()
  cfg.auras[key] = T.AUTO_LIST and false or nil
  if it and it.custom then return self:RemoveCustom(key) end
  self:Relist()
end

-- Switches a timer off or on without losing its settings.
function T:SetOn(key, on)
  local auras = self:Cfg().auras
  if type(auras[key]) ~= "table" then
    if not self:Find(key) then return false end
    auras[key] = {}
  end
  if on then auras[key].on = nil else auras[key].on = false end
  self:Relist()
  return true
end

-- One timer's look (shape and sizes) for every timer in its block: the block takes it, and
-- the others stop having their own. How many others changed.
function T:CopyLook(key)
  local it = self:Find(key)
  if not it then return 0 end
  local cfg = self:Cfg()
  local g = cfg[it.group]
  local look = {}
  for _, k in ipairs(T.LOOK_KEYS) do look[k] = self:Opt(it, k) end
  local n = 0
  for _, other in ipairs(self.items) do
    if other.group == it.group and other.listed then
      local a = self:Aura(other.key)
      local had = false
      for _, k in ipairs(T.LOOK_KEYS) do
        if self:Opt(other, k) ~= look[k] then had = true end
        if a then a[k] = nil end
      end
      if had and other ~= it then n = n + 1 end
    end
  end
  for _, k in ipairs(T.LOOK_KEYS) do g[k] = look[k] end
  self:Refresh()
  return n
end

-- A line for the list: when and where a timer shows, in a few words.
function T:Summary(it)
  local bits = {}
  local when = self:Opt(it, "when")
  if when == "combat" then bits[#bits + 1] = "In a fight" elseif when == "idle" then bits[#bits + 1] = "Out of a fight" end
  local places, all = {}, true
  for _, p in ipairs(T.PLACES) do
    if self:Opt(it, p.key) ~= false then places[#places + 1] = p.name else all = false end
  end
  if not all then bits[#bits + 1] = #places > 0 and table.concat(places, ", ") or "Nowhere" end
  local k = it.kind
  if k == "cd" then
    if self:Opt(it, "ready") == "hide" then bits[#bits + 1] = "hidden while ready" end
  elseif k == "keep" or k == "imbue" then
    if self:Opt(it, "up") == "hide" then bits[#bits + 1] = "only when it needs recasting" end
    if self:Opt(it, "miss") == "flash" then bits[#bits + 1] = "flashes when missing" end
  elseif k == "dot" then
    if self:Opt(it, "miss") == "flash" then bits[#bits + 1] = "flashes when missing" end
  end
  if self:Opt(it, "style") == "bars" then bits[#bits + 1] = "bar" end
  if #bits == 0 then return "All the time, everywhere" end
  local text = table.concat(bits, " · ")
  return (text:gsub("^%l", string.upper))
end

-- Where a group was dragged: VoltUI-wide keys ending Left, Top and Point, like every frame's
-- spot, so Share and the starting layouts carry them (timerCdsLeft, ...).
function T.SpotKeys(gkey)
  local base = "timer" .. gkey:gsub("^%l", string.upper)
  return ns.db, base .. "Left", base .. "Top", base .. "Point"
end

------------------------------------------------------------------------
-- Each class's list (Classic spell ids; the lowest rank, which every later rank keeps
-- known). A list in `any` means "whichever of these": one seal, one aspect, one curse.
--   always: a long buff, worth a flash out of a fight too (warnIdle)
--   react:  a cooldown that's only usable after something happens (lights up when it is)
------------------------------------------------------------------------

local function E(kind, id, opts)
  local o = {} -- a copy: ALWAYS and REACT are shared by many
  for k, v in pairs(opts or {}) do o[k] = v end
  o.kind = kind
  if type(id) == "table" then o.any, o.id = id, id[1] else o.id = id end
  return o
end
local function cd(id, o) return E("cd", id, o) end
local function keep(id, o) return E("keep", id, o) end
local function proc(id, o) return E("proc", id, o) end
local function dot(id, o) return E("dot", id, o) end
local ALWAYS, REACT = { always = true }, { react = true }
local function A(o) local t = { always = true } for k, v in pairs(o or {}) do t[k] = v end return t end

T.CLASS = {
  WARRIOR = {
    keep(6673), -- Battle Shout
    proc(12880), proc(12966), -- Enrage, Flurry
    cd(7384, REACT), cd(6572, REACT), cd(5308, REACT), -- Overpower, Revenge, Execute
    cd(12294), cd(23881), cd(23922), cd(1680), -- Mortal Strike, Bloodthirst, Shield Slam, Whirlwind
    cd(2687), cd(100), cd(20252), cd(6552), cd(72), cd(2565), -- Bloodrage, Charge, Intercept, Pummel, Shield Bash, Shield Block
    cd(18499), cd(12292), cd(12328), cd(1719), cd(20230), cd(871), cd(12975), -- Berserker Rage .. Last Stand
    cd(12809), cd(5246), cd(1161), cd(355), cd(694), cd(676), -- Concussion Blow .. Disarm
    dot(772), dot(7386), dot(1160), dot(6343), -- Rend, Sunder Armor, Demoralizing Shout, Thunder Clap
  },
  PALADIN = {
    keep({ 21084, 20375, 21082, 20165, 20166, 20164 }, { label = "Seal" }),
    keep({ 465, 7294, 19746, 19876, 19888, 19891, 20218 }, A({ label = "Aura" })),
    keep({ 19740, 19742, 20217, 1038, 19977, 20911, 25782, 25894, 25898, 25895, 25890, 25899 }, A({ label = "Blessing" })),
    proc(25780), proc(20050), -- Righteous Fury, Vengeance
    cd(24275, REACT), -- Hammer of Wrath
    cd(20271), cd(853), cd(26573), cd(879), cd(20473), cd(2812), cd(20925), -- Judgement .. Holy Shield
    cd(642), cd(498), cd(1022), cd(1044), cd(633), cd(20216), cd(20066), cd(2878), -- Divine Shield .. Turn Undead
    dot({ 21183, 20185, 20186, 20184 }, { label = "Judgement" }),
  },
  HUNTER = {
    keep({ 13165, 13163, 5118, 13159, 20043, 13161 }, A({ label = "Aspect" })),
    keep(19506, ALWAYS), -- Trueshot Aura
    proc(6150), proc(3045), -- Quick Shots, Rapid Fire
    cd(19306, REACT), cd(1495, REACT), -- Counterattack, Mongoose Bite
    cd(3044), cd(2643), cd(19434), cd(5116), cd(19503), cd(19386), cd(2973), -- Arcane Shot .. Raptor Strike
    cd({ 1499, 13795, 13809, 13813 }, { label = "Traps" }),
    cd(3045), cd(19574), cd(19577), cd(19263), cd(781), cd(5384), cd(20736), cd(19801), cd(1513),
    dot({ 1978, 3034, 3043 }, { label = "Sting" }), dot(1130), -- a sting, Hunter's Mark
  },
  ROGUE = {
    keep(5171), -- Slice and Dice
    proc(13750), proc(13877), proc(5277), -- Adrenaline Rush, Blade Flurry, Evasion
    cd(14251, REACT), -- Riposte
    cd(1766), cd(1776), cd(408), cd(2094), cd(1966), cd(2983), cd(5277), cd(1856), -- Kick .. Vanish
    cd(13750), cd(13877), cd(14177), cd(14185), cd(14183), cd(14278), cd(1725), cd(1784), -- Adrenaline Rush .. Stealth
    dot(1943), dot(703), dot(8647), dot(16511), -- Rupture, Garrote, Expose Armor, Hemorrhage
  },
  PRIEST = {
    keep({ 1243, 21562 }, A({ label = "Fortitude" })), keep(588, ALWAYS), -- Inner Fire
    keep({ 14752, 27681 }, A({ label = "Divine Spirit" })), keep(15473, ALWAYS), -- Shadowform
    proc(15271), proc(14751), proc(10060), -- Spirit Tap, Inner Focus, Power Infusion
    cd(8092), cd(8122), cd(586), cd(14751), cd(10060), cd(14914), cd(15487), cd(13908), -- Mind Blast .. Desperate Prayer
    cd(6346), cd(2651), cd(13896), cd(2944), cd(10797), -- Fear Ward .. Starshards
    dot(589), dot(15286), dot(2944), dot(14914), -- Shadow Word: Pain, Vampiric Embrace, Devouring Plague, Holy Fire
  },
  SHAMAN = {
    keep(324, ALWAYS), -- Lightning Shield
    proc(16246), proc(16257), proc(16166), proc(16188), -- Clearcasting, Flurry, Elemental Mastery, Nature's Swiftness
    cd({ 8042, 8050, 8056 }, { label = "Shocks" }),
    cd(421), cd(17364), cd(16166), cd(16188), cd(8177), cd(2484), cd(1535), cd(5730), cd(16190), -- Chain Lightning .. Mana Tide
    cd(20608), cd(556), -- Reincarnation, Astral Recall
    dot(8050), dot(17364), -- Flame Shock, Stormstrike
  },
  MAGE = {
    keep({ 1459, 23028 }, A({ label = "Arcane Intellect" })),
    keep({ 168, 7302, 6117 }, A({ label = "Armor" })),
    proc(12536), proc(12043), proc(11129), proc(12042), proc(11426), proc(1463), -- Clearcasting .. Mana Shield
    cd(2136), cd(122), cd(120), cd(1953), cd(2139), cd(12051), cd(11958), cd(12472), -- Fire Blast .. Cold Snap
    cd(11426), cd(11129), cd(12043), cd(12042), cd(11113), cd(543), cd(6143), -- Ice Barrier .. Frost Ward
    dot(12579), dot(22959), -- Winter's Chill, Fire Vulnerability
  },
  WARLOCK = {
    keep({ 687, 706 }, A({ label = "Demon Armor" })), keep(19028, ALWAYS), -- Soul Link
    proc(17941), proc(18288), -- Shadow Trance, Amplify Curse
    cd(6789), cd(5484), cd(17877), cd(17962), cd(18288), cd(18708), cd(603), cd(6229), -- Death Coil .. Shadow Ward
    dot(172), dot(348), dot(18265), -- Corruption, Immolate, Siphon Life
    dot({ 980, 1490, 17862, 704, 702, 1714, 18223, 603 }, { label = "Curse" }),
  },
  DRUID = {
    keep({ 1126, 21849 }, A({ label = "Mark of the Wild" })), keep(467, ALWAYS), keep(16864, ALWAYS), -- Thorns, Omen of Clarity
    proc(16870), -- Clearcasting
    cd(5211), cd(16979), cd(16857), cd(22812), cd(29166), cd(17116), cd(18562), cd(740), cd(16914), -- Bash .. Hurricane
    cd(20484), cd(5229), cd(22842), cd(1850), cd(5217), cd(6795), cd(5209), cd(8998), cd(16689), -- Rebirth .. Nature's Grasp
    dot(8921), dot(5570), dot(1822), dot(1079), dot({ 770, 16857 }, { label = "Faerie Fire" }), dot(99), -- Moonfire .. Demoralizing Roar
  },
}

-- The weapon imbues: who gets them, and from when.
T.IMBUE = {
  SHAMAN = { hands = { 16 }, known = { 8017, 8024, 8033, 8232 } }, -- Rockbiter, Flametongue, Frostbrand, Windfury
  ROGUE = { hands = { 16, 17 }, level = 20 }, -- poisons
}
-- Totem slots (the game's order) and their colours.
T.TOTEMS = {
  { slot = 1, name = "Fire", color = { 1, 0.45, 0.2 } },
  { slot = 2, name = "Earth", color = { 0.72, 0.55, 0.3 } },
  { slot = 3, name = "Water", color = { 0.3, 0.6, 1 } },
  { slot = 4, name = "Air", color = { 0.78, 0.88, 1 } },
}
T.COLORS = {
  cd = { 0.45, 0.62, 1 }, keep = { 0.35, 0.8, 0.45 }, proc = { 1, 0.75, 0.25 },
  dot = { 0.85, 0.4, 0.95 }, imbue = { 0.62, 0.45, 0.95 },
}
T.WARN = { 1, 0.15, 0.15 }

-- Spellbook spells added by themselves: a cooldown this long (in seconds).
T.AUTO_MIN, T.AUTO_MAX = 10, 600

------------------------------------------------------------------------
-- Spells
------------------------------------------------------------------------

local function Known(id)
  if IsPlayerSpell and Safe(Ask(IsPlayerSpell, id)) == true then return true end
  if IsSpellKnown and Safe(Ask(IsSpellKnown, id)) == true then return true end
  return false
end
T.Known = Known

local function SpellName(id)
  local n = C_Spell and Ask(C_Spell.GetSpellName, id)
  if n == nil and GetSpellInfo then n = Ask(GetSpellInfo, id) end
  n = Safe(n)
  return type(n) == "string" and n ~= "" and n or nil
end
local function SpellIcon(id)
  local t = C_Spell and Ask(C_Spell.GetSpellTexture, id)
  if t == nil and GetSpellTexture then t = Ask(GetSpellTexture, id) end
  return t
end
T.SpellName, T.SpellIcon = SpellName, SpellIcon

function T:Class()
  local _, class = Ask(UnitClass, "player")
  return Safe(class)
end

-- Spells in the spellbook that aren't passive: { { id, name, icon }, ... }.
function T.Book()
  local out = {}
  local SB = C_SpellBook
  if not (SB and SB.GetNumSpellBookSkillLines and SB.GetSpellBookSkillLineInfo and SB.GetSpellBookItemInfo) then return out end
  local En = Enum or {}
  local bank = En.SpellBookSpellBank and En.SpellBookSpellBank.Player or 0
  local spellType = En.SpellBookItemType and En.SpellBookItemType.Spell or 1
  local lines = Ask(SB.GetNumSpellBookSkillLines)
  for line = 1, type(lines) == "number" and lines or 0 do
    local li = Ask(SB.GetSpellBookSkillLineInfo, line)
    if type(li) == "table" and not li.isGuild and not li.shouldHide and not li.offSpecID
      and type(li.itemIndexOffset) == "number" and type(li.numSpellBookItems) == "number" then
      for slot = li.itemIndexOffset + 1, li.itemIndexOffset + li.numSpellBookItems do
        local it = Ask(SB.GetSpellBookItemInfo, slot, bank)
        if type(it) == "table" and it.itemType == spellType and not it.isPassive and not it.isOffSpec then
          local id = it.spellID or it.actionID
          if type(id) == "number" and type(it.name) == "string" then
            out[#out + 1] = { id = id, name = it.name, icon = it.iconID }
          end
        end
      end
    end
  end
  return out
end

-- A spell's cooldown before talents and gear, in seconds, or nil.
local function BaseCooldown(id)
  local ms = GetSpellBaseCooldown and Safe(Ask(GetSpellBaseCooldown, id))
  if type(ms) == "number" then return ms / 1000 end
end

------------------------------------------------------------------------
-- What to show: T.items, in list order, each { key, kind, group, name, icon, ... }
------------------------------------------------------------------------

-- The kinds you can add a spell as, in the order the settings page offers them.
T.CUSTOM_KINDS = { cd = true, keep = true, proc = true, dot = true }
T.CUSTOM_LIST = {
  { key = "cd", name = "Cooldown" }, { key = "keep", name = "Buff to keep up" },
  { key = "proc", name = "Proc" }, { key = "dot", name = "On target" },
}
function T.CustomKey(e) return "custom:" .. e.kind .. ":" .. e.id end

-- A spell's id from what was typed: its id, or the name of a spell in your spellbook (or one
-- the game will look up by name, which it only does for spells you know).
function T.FindSpell(text)
  text = tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if text == "" then return nil end
  local id = tonumber(text) or tonumber(text:match("spell[:=](%d+)"))
  if id then return SpellName(id) and id or nil end
  local want = text:lower()
  for _, b in ipairs(T.Book()) do
    if b.name:lower() == want then return b.id end
  end
  local info = C_Spell and Ask(C_Spell.GetSpellInfo, text)
  local found = type(info) == "table" and Safe(info.spellID)
  if type(found) == "number" then return found end
  return nil
end

-- Adds a spell of your own to your timers. Returns true, its name and its timer's key, or
-- false and why not.
function T:AddCustom(kind, text)
  if not T.CUSTOM_KINDS[kind] then return false, "Pick what it is: a cooldown, a buff to keep up, a proc or a debuff on your target." end
  local class = self:Class()
  if not class then return false, "Your class isn't known yet. Try again in a moment." end
  local id = T.FindSpell(text)
  if not id then
    return false, ("No spell found for \"%s\". A name only works for a spell in your spellbook: for a proc or someone else's buff, give its spell ID (Alt-click the spell or buff for its web page, the number is in the address)."):format(tostring(text or ""))
  end
  local name = SpellName(id)
  local cfg = self:Cfg()
  for _, e in ipairs(cfg.custom) do
    if e.class == class and e.kind == kind and e.id == id then return false, name .. " is already one of yours." end
  end
  for _, it in ipairs(self.items) do
    if it.kind == kind then
      for _, n in ipairs(it.names or {}) do
        if n == name then
          -- one VoltUI found for your class: that one joins your list
          if it.listed then return false, name .. " is already in the list of your timers.", it.key end
          self:Add(it.key)
          return true, name, it.key
        end
      end
    end
  end
  local e = { class = class, kind = kind, id = id }
  cfg.custom[#cfg.custom + 1] = e
  local key = T.CustomKey(e)
  if type(cfg.auras[key]) ~= "table" then cfg.auras[key] = {} end -- and it's one of your timers
  if self.enabled then
    self:Collect()
    self:UpdateAll()
    self:Refresh()
  end
  return true, name, key
end

function T:RemoveCustom(key)
  local cfg = self:Cfg()
  for i = #cfg.custom, 1, -1 do
    local e = cfg.custom[i]
    if type(e) == "table" and T.CUSTOM_KINDS[e.kind] and T.CustomKey(e) == key and e.class == self:Class() then
      table.remove(cfg.custom, i)
    end
  end
  cfg.auras[key] = nil
  if self.enabled then
    self:Collect()
    self:UpdateAll()
    self:Refresh()
  end
end

-- Moves one earlier (-1) or later (1) among the timers of its own group, and keeps the order.
-- True if it moved.
function T:Move(key, dir)
  local items = self.items
  local at
  for i, it in ipairs(items) do if it.key == key then at = i break end end
  if not at then return false end
  local other = at + dir
  while items[other] and (items[other].group ~= items[at].group or not items[other].listed) do other = other + dir end
  if not items[other] then return false end
  items[at], items[other] = items[other], items[at]
  local order = {}
  for i, it in ipairs(items) do order[i] = it.key end
  self:Cfg().order = order
  self:LayoutAll()
  return true
end

-- Back to the lists' own order.
function T:ResetOrder()
  self:Cfg().order = {}
  if self.enabled then
    self:Collect()
    self:UpdateAll()
    self:Refresh()
  end
end

function T:Collect()
  local class = self:Class()
  local cfg = self:Cfg()
  local old = {}
  for _, it in ipairs(self.items) do old[it.key] = it end
  local items, byName, have = {}, {}, {}
  local function add(it)
    if old[it.key] then it.st, it.w = old[it.key].st, old[it.key].w end
    it.st = it.st or {}
    self:Mark(it)
    for _, n in ipairs(it.names or {}) do have[it.kind .. ":" .. n] = true end
    items[#items + 1] = it
  end
  for _, e in ipairs(class and T.CLASS[class] or {}) do
    local ids = e.any or { e.id }
    local known = {}
    for _, id in ipairs(ids) do if e.kind == "proc" or Known(id) then known[#known + 1] = id end end
    if #known > 0 then
      local first = known[1]
      local names = {}
      -- Auras by any rank's or any choice's name: every one in the list, known or not, since a
      -- buff can come from someone else (a blessing) or a rank you no longer use.
      for _, id in ipairs(e.kind == "cd" and known or ids) do
        local n = SpellName(id)
        if n then names[#names + 1] = n end
      end
      local spellName = SpellName(first)
      if spellName or e.kind == "proc" then
        local it = {
          key = e.kind .. ":" .. e.id, kind = e.kind, id = first, entry = e,
          name = e.label or spellName or ("Spell " .. first), icon = SpellIcon(first),
          spell = spellName or first, names = names, unit = e.kind == "dot" and "target" or "player",
          always = e.always, react = e.react,
        }
        if e.kind == "cd" then
          for _, n in ipairs(names) do byName[n] = true end
        end
        add(it)
      end
    end
  end
  -- Weapon imbues
  local im = class and T.IMBUE[class]
  if im then
    local ok = true
    if im.level then ok = (Safe(Ask(UnitLevel, "player")) or 0) >= im.level end
    if ok and im.known then
      ok = false
      for _, id in ipairs(im.known) do if Known(id) then ok = true break end end
    end
    if ok then
      for _, hand in ipairs(im.hands) do
        add({ key = "imbue:" .. hand, kind = "imbue", hand = hand, always = true,
              name = hand == 16 and "Main hand" or "Off hand", unit = "player", names = {} })
      end
    end
  end
  -- Totems
  if class == "SHAMAN" and GetTotemInfo then
    for _, t in ipairs(T.TOTEMS) do
      add({ key = "totem:" .. t.slot, kind = "totem", slot = t.slot, name = t.name .. " totem", color = t.color, names = {} })
    end
  end
  -- Spells you've added yourself (since 1.80.0), for this class: a cooldown, a buff to keep
  -- up, a proc or a debuff on your target, by spell id. One the lists above already have, by
  -- name and kind, isn't shown twice.
  for _, e in ipairs(cfg.custom) do
    if type(e) == "table" and e.class == class and T.CUSTOM_KINDS[e.kind] and type(e.id) == "number" then
      local n = SpellName(e.id)
      if n and not have[e.kind .. ":" .. n] then
        if e.kind == "cd" then byName[n] = true end
        add({ key = T.CustomKey(e), kind = e.kind, id = e.id, name = n, icon = SpellIcon(e.id), spell = n, names = { n },
              unit = e.kind == "dot" and "target" or "player", custom = true })
      end
    end
  end
  -- Anything else in the spellbook with a real cooldown: racials, Forever's own spells.
  for _, b in ipairs(T.Book()) do
    local base = BaseCooldown(b.id)
    if base and base >= T.AUTO_MIN and base <= T.AUTO_MAX and not byName[b.name] then
      byName[b.name] = true
      add({ key = "cd:" .. b.id, kind = "cd", id = b.id, name = b.name, icon = b.icon or SpellIcon(b.id),
            spell = b.name, names = { b.name }, unit = "player", auto = true })
    end
  end
  -- Your order, if you've moved any: those in it first, as you left them; ones found since
  -- (a spell learned later) after them, in the lists' own order.
  if #cfg.order > 0 then
    local rank = {}
    for i, key in ipairs(cfg.order) do rank[key] = i end
    for i, it in ipairs(items) do it.rank = rank[it.key] or (100000 + i) end
    table.sort(items, function(a, b) return a.rank < b.rank end)
  end
  -- Widgets of items no longer there go.
  for key, it in pairs(old) do
    local still
    for _, n in ipairs(items) do if n.key == key then still = true break end end
    if not still and it.w then it.w:Hide() end
  end
  self.items = items
  return items
end

------------------------------------------------------------------------
-- Reading the game
------------------------------------------------------------------------

-- A cooldown: running (not just the global cooldown), its time, and whether it can be used.
function T:ReadCooldown(it)
  local spell = it.spell
  local onCD, timer
  local CS = C_Spell
  local info = CS and Ask(CS.GetSpellCooldown, spell)
  if type(info) == "table" then
    local active = info.isActive
    if active == nil then
      local s, d = Safe(info.startTime), Safe(info.duration)
      active = s ~= nil and d ~= nil and s > 0 and d > 0
    end
    onCD = active == true and info.isOnGCD ~= true
    if onCD and info.isOnGCD == nil then
      local d = Safe(info.duration)
      if d and d <= 1.5 then onCD = false end -- an older client: the global cooldown by its length
    end
    if onCD then
      local dur = Ask(CS.GetSpellCooldownDuration, spell)
      if dur then
        timer = { dur = dur }
      else
        local s, d = Safe(info.startTime), Safe(info.duration)
        if s and d then timer = { start = s, length = d } end
      end
    end
  elseif GetSpellCooldown then
    local s, d = Ask(GetSpellCooldown, spell)
    s, d = Safe(s), Safe(d)
    onCD = s ~= nil and d ~= nil and s > 0 and d > 1.5
    if onCD then timer = { start = s, length = d } end
  end
  local usable, noPower = nil, nil
  local fn = (CS and CS.IsSpellUsable) or IsUsableSpell
  if fn then usable, noPower = Ask(fn, spell) end
  return onCD and true or false, timer, Safe(usable), Safe(noPower)
end

-- Every aura on a unit by name: found[name] = aura. complete is false when the game wouldn't
-- show them (secret in a fight): then only the ones it still shows are there.
function T.Scan(unit, filter)
  local found, complete = {}, true
  local UA = C_UnitAuras
  if not (UA and UA.GetAuraDataByIndex) then return found, false end
  for i = 1, 40 do
    local ok, a = pcall(UA.GetAuraDataByIndex, unit, i, filter)
    if not ok then complete = false break end
    if type(a) ~= "table" then break end
    local name = Safe(a.name)
    if name then
      if found[name] == nil then found[name] = a end
    else
      complete = false
    end
  end
  return found, complete
end

-- A list in UNIT_AURA's updateInfo, when it can be read: a table, not a secret one.
local function Readable(info, key)
  if type(info) ~= "table" or IsSecret(info) then return nil end
  local ok, t = pcall(function() return info[key] end)
  if ok and type(t) == "table" and not IsSecret(t) then return t end
end

-- The game's duration object for a time it keeps secret, or nothing when it gave none.
local function DurTimer(dur)
  if dur ~= nil then return { dur = dur } end
end

-- An aura's time: readable, or the game's duration object.
local function AuraTimer(unit, a)
  local d, e = Safe(a.duration), Safe(a.expirationTime)
  if d and e then
    if d > 0 then return { start = e - d, length = d } end
    return nil -- lasts until cancelled
  end
  local id = a.auraInstanceID
  local UA = C_UnitAuras
  if S.Present(id) and UA and UA.GetAuraDuration then
    local dur = Ask(UA.GetAuraDuration, unit, id)
    if dur then return { dur = dur } end
  end
end

local function AuraCount(unit, a)
  local n = Safe(a.applications)
  if n then return n > 1 and tostring(n) or "" end
  local UA = C_UnitAuras
  if UA and UA.GetAuraApplicationDisplayCount and S.Present(a.auraInstanceID) then
    return Ask(UA.GetAuraApplicationDisplayCount, unit, a.auraInstanceID, 2, 99) or ""
  end
  return ""
end

-- Every aura instance on a unit, as a set of ids (1.89.0). Unlike the auras themselves the
-- game's API documentation marks none of this secret, so in a fight it still says which
-- auras are there: a buff seen before keeps its id, and once the id goes, so did the buff.
-- Nil when the game won't say.
function T.AuraIDs(unit, filter)
  local UA = C_UnitAuras
  if not (UA and UA.GetUnitAuraInstanceIDs) then return nil end
  local ok, list = pcall(UA.GetUnitAuraInstanceIDs, unit, filter)
  if not ok or type(list) ~= "table" or IsSecret(list) then return nil end
  local set = {}
  local fine = pcall(function()
    for _, id in ipairs(list) do
      if IsSecret(id) or type(id) ~= "number" then error("unreadable") end
      set[id] = true
    end
  end)
  if fine then return set end
end

-- Your buffs as the game's own buff frame has them (1.98.0). In a fight every aura read from
-- an add-on is refused on this client (VoltUIDB.auraProbe, 2026-11-19: the list, by index, by
-- id, slots and time all "cannot be accessed when secret while tainted"). The game's buff
-- frame is filled in by the game's own code, which may read them, and keeps what it read
-- in BuffFrame.auraInfo. That's only looked at here, never written. Whether its values can
-- be read by an add-on in a fight isn't known: each is taken only if it isn't secret, and
-- `ids` is nil unless every buff's id could be read. Nil without the game's buff frame.
function T.GameBuffs()
  local bf = _G.BuffFrame
  local list = type(bf) == "table" and bf.auraInfo
  if type(list) ~= "table" or IsSecret(list) then return nil end
  local out = { byId = {}, list = {}, ids = {} }
  local every = true
  local ok = pcall(function()
    for _, info in ipairs(list) do
      if type(info) == "table" and not IsSecret(info) and Safe(info.auraType) == "Buff" then
        local r = { aid = Safe(info.auraInstanceID), icon = Safe(info.texture), n = Safe(info.count),
          d = Safe(info.duration), e = Safe(info.expirationTime) }
        out.list[#out.list + 1] = r
        if type(r.aid) == "number" then
          out.byId[r.aid], out.ids[r.aid] = r, true
        else
          every = false
        end
      end
    end
  end)
  if not ok then return nil end
  if not every then out.ids = nil end
  return out
end

-- A buff's time and stacks from the game's own note of it, where those can be read.
local function FromGame(st, r)
  if not r then return end
  if type(r.d) == "number" and type(r.e) == "number" then
    st.timer = r.d > 0 and { start = r.e - r.d, length = r.d } or nil
  end
  if type(r.n) == "number" then st.count = r.n > 1 and tostring(r.n) or "" end
end

-- Finds a timer's buff in the game's list: by the id it had, or by its icon (a buff put on,
-- or a proc, during the fight). True when it's there.
local function InGame(it, st, game, taken, now)
  local r = st.aid and game.byId[st.aid]
  if not r then
    local icon = it.icon
    if icon == nil then return false end
    for _, x in ipairs(game.list) do
      if x.icon ~= nil and x.icon == icon and type(x.aid) == "number" and not taken[x.aid] then
        r = x
        break
      end
    end
    if not r then return false end
    st.aid, st.aidAt, taken[r.aid] = r.aid, now, true
  end
  FromGame(st, r)
  return true
end

-- The one id that came on lately and no timer has taken, if there's just one.
local function OneFresh(fresh, taken)
  local pick
  for id in pairs(fresh) do
    if not taken[id] then
      if pick then return nil end
      pick = id
    end
  end
  return pick
end

-- An aura's time and stacks by its id, for when its name can't be read.
local function ByID(unit, st)
  local UA = C_UnitAuras
  if not (UA and st.aid) then return end
  local dur = Ask(UA.GetAuraDuration, unit, st.aid)
  if dur then st.timer = { dur = dur } end
  local n = Ask(UA.GetAuraApplicationDisplayCount, unit, st.aid, 2, 99)
  if n ~= nil then st.count = n end
end

T.FRESH_TIME = 3 -- how long after your cast a new aura id counts as that buff

-- Is a buff of yours still on, when neither names nor the id list can be read? (1.92.3)
-- Lightning Shield losing its charges in a fight only showed as missing once the fight ended:
-- the id list (1.89.0) evidently isn't readable then either. Two narrower questions:
--   by spell id (GetPlayerAuraBySpellID): a table = on, and it gives the new aura's id;
--   by the id known from before (GetAuraDataByAuraInstanceID): nil = that aura is gone.
-- True, false, or nil when the game wouldn't answer either.
function T.StillOn(st)
  local UA = C_UnitAuras
  if not UA then return nil end
  local function call(fn, ...)
    if type(fn) ~= "function" then return false end
    local ok, v = pcall(fn, ...)
    if not ok then return false end
    return true, v
  end
  for _, id in ipairs({ st.castID, st.spellId }) do
    local ok, a = call(UA.GetPlayerAuraBySpellID, id)
    if ok and type(a) == "table" and not IsSecret(a) then
      local aid = Safe(a.auraInstanceID)
      if type(aid) == "number" and aid ~= st.aid then st.aid, st.aidAt = aid, Now() end
      return true
    end
  end
  if st.aid then
    local ok, a = call(UA.GetAuraDataByAuraInstanceID, "player", st.aid)
    if ok then
      if a ~= nil then return true end
      -- that aura went; cast again since it was seen, the new one is on (its id not known yet)
      if st.castAt and st.castAt > (st.aidAt or 0) then
        st.aid = nil
        return true, true
      end
      return false
    end
  end
  return nil
end

-- What the game answers about your buffs in a fight, kept in VoltUIDB.auraProbe (1.92.3): the
-- last few fights' first aura changes, so the next fix rests on what this client does, not a
-- guess. Each answer is "error: ...", "nil", "secret", "table" or a plain value.
T.PROBE_KEEP, T.PROBE_PER_FIGHT = 12, 3
local function Describe(ok, v, ...)
  if not ok then return "error: " .. tostring(v):sub(1, 90) end
  if v == nil then return "nil" end
  if IsSecret(v) then return "secret" end
  if type(v) == "table" then
    if canaccesstable and not canaccesstable(v) then return "locked table" end
    local n, sec = 0, 0
    pcall(function() for _, x in pairs(v) do n = n + 1; if IsSecret(x) then sec = sec + 1 end end end)
    return ("table (%d fields, %d secret)"):format(n, sec)
  end
  return type(v) .. ": " .. tostring(v)
end
function T:Probe(st)
  local db = ns.db
  if not db or (self.probes or 0) >= T.PROBE_PER_FIGHT then return end
  self.probes = (self.probes or 0) + 1
  local UA = C_UnitAuras or {}
  local function ask(fn, ...)
    if type(fn) ~= "function" then return "missing" end
    return Describe(pcall(fn, ...))
  end
  local r = {
    at = date and date("%Y-%m-%d %H:%M:%S") or tostring(Now()),
    shownOn = tostring(st.on), aid = tostring(st.aid), spellId = tostring(st.spellId), castID = tostring(st.castID),
    byIndex = ask(UA.GetAuraDataByIndex, "player", 1, "HELPFUL"),
    idList = ask(UA.GetUnitAuraInstanceIDs, "player", "HELPFUL"),
    slots = ask(UA.GetAuraSlots, "player", "HELPFUL"),
    bySpellID = ask(UA.GetPlayerAuraBySpellID, st.castID or st.spellId or 324),
    byName = ask(UA.GetAuraDataBySpellName, "player", SpellName(324) or "Lightning Shield", "HELPFUL"),
  }
  -- what the game's own buff frame holds, and whether an add-on may read it (1.98.0)
  r.gameBuffs = Describe(pcall(function()
    local list = _G.BuffFrame and _G.BuffFrame.auraInfo
    if type(list) ~= "table" then return "no list" end
    local function what(v) return v == nil and "nil" or IsSecret(v) and "secret" or type(v) end
    local first
    for _, info in ipairs(list) do
      if type(info) == "table" and not IsSecret(info) and Safe(info.auraType) == "Buff" then first = info break end
    end
    if not first then return ("%d entries, no buff"):format(#list) end
    return ("%d entries; id %s, icon %s, count %s, duration %s, expires %s"):format(#list, what(first.auraInstanceID),
      what(first.texture), what(first.count), what(first.duration), what(first.expirationTime))
  end))
  if st.aid then
    r.byAid = ask(UA.GetAuraDataByAuraInstanceID, "player", st.aid)
    r.duration = ask(UA.GetAuraDuration, "player", st.aid)
  end
  local ok, ids = pcall(UA.GetUnitAuraInstanceIDs, "player", "HELPFUL")
  if ok and type(ids) == "table" and not IsSecret(ids) then
    r.firstId = Describe(pcall(function() return ids[1] end))
  end
  db.auraProbe = type(db.auraProbe) == "table" and db.auraProbe or {}
  table.insert(db.auraProbe, r)
  while #db.auraProbe > T.PROBE_KEEP do table.remove(db.auraProbe, 1) end
end

-- What else in the game might say a buff went in a fight (1.98.1). Buffs can't be read
-- there by any road tried so far, the game's own buff list included (its values are secret
-- too). Two things are left, and this notes what each gives so the next step rests on what
-- this client does. Kept in VoltUIDB.viewerProbe; nothing here changes anything.
--   The game's Cooldown Manager: its tracked buff icons are the game's own frames. If the
--     game lists your buffs there, and an add-on may see whether an icon is showing or
--     "active", that says up or down.
--   The combat log: an aura-removed line for you would say it outright.
T.VIEWERS = { "BuffIconCooldownViewer", "BuffBarCooldownViewer", "EssentialCooldownViewer", "UtilityCooldownViewer" }
local function What(v)
  if v == nil then return "nil" end
  if IsSecret(v) then return "secret" end
  local t = type(v)
  if t == "table" or t == "function" or t == "userdata" then return t end
  return t .. " " .. tostring(v):sub(1, 40)
end

-- The game's Cooldown Manager as the source for your buffs in a fight (1.99.0). Seen in
-- game (VoltUIDB.viewerProbe, 2026-11-20): it is available on this client and its tracked
-- buffs include Lightning Shield, Water Shield, Flurry, Maelstrom Weapon and the rest; the
-- combat log gives add-ons nothing at all. The manager's icons are the game's own frames,
-- filled in by the game's own code, so they follow a fight. VoltUI only looks at them: which
-- spell an icon is for (not secret: it's the game's own list), and whether it is active or
-- showing. Whether those two can be read in a fight is the one thing still unseen; where
-- they can't, this says nothing and Timers do as before.
T.BUFF_VIEWERS = { "BuffIconCooldownViewer", "BuffBarCooldownViewer" }

-- Is the game's Cooldown Manager switched on (its own setting)?
function T.ManagerOn()
  if not C_CooldownViewer or not GetCVar then return false end
  local ok, v = pcall(GetCVar, "cooldownViewerEnabled")
  return ok and (v == "1" or v == 1)
end

-- Your tracked buffs by spell name: true while up, false while not. Nil when the manager
-- is off or hidden, or nothing of it can be read. The second answer (1.101.5) is true when
-- the manager is on and its icons could be walked, even with none on it: then a buff that
-- isn't among them is one you've set to Not tracked.
function T.ViewerBuffs()
  if not T.ManagerOn() then return nil, false end
  local out, any, read = {}, false, false
  local CV = C_CooldownViewer
  for _, vname in ipairs(T.BUFF_VIEWERS) do
    local v = _G[vname]
    if type(v) == "table" and v.GetItemFrames and v.IsShown and Safe(v:IsShown()) == true then
      local hides = Safe(v.hideWhenInactive)
      pcall(function()
        local frames = v:GetItemFrames()
        if type(frames) ~= "table" then return end
        read = true
        for _, item in ipairs(frames) do
          local cid = type(item) == "table" and Safe(item.cooldownID) or nil
          if cid ~= nil then
            local spell = item.GetSpellID and Safe(item:GetSpellID()) or nil
            if type(spell) ~= "number" and CV.GetCooldownViewerCooldownInfo then
              local info = CV.GetCooldownViewerCooldownInfo(cid)
              spell = type(info) == "table" and Safe(info.spellID) or nil
            end
            local name = type(spell) == "number" and SpellName(spell) or nil
            local state
            local active = Safe(item.isActive)
            if type(active) == "boolean" then
              state = active
            elseif hides == true and item.IsShown then
              -- an icon that hides while its buff is down: showing means up
              local shown = Safe(item:IsShown())
              if type(shown) == "boolean" then state = shown end
            end
            if name and state ~= nil then
              out[name] = out[name] or state
              any = true
            end
          end
        end
      end)
    end
  end
  return any and out or nil, read
end

-- What the manager says about one timer's buff: true, false, or nil when it doesn't track it.
local function ViewerSays(it, viewer)
  local said
  for _, n in ipairs(it.names) do
    local v = viewer[n]
    if v == true then return true end
    if v == false then said = false end
  end
  return said
end

-- The game's Tracked Buffs, picked from VoltUI's settings (1.101.0). Seen in game 2026-11-20:
-- the manager only makes an icon for a buff in its displayed set, and only those can be
-- followed in a fight.
--   Reading: the game's own list of what can be tracked (C_CooldownViewer, no game table
--     touched) and, for which are tracked now, the cooldown ids on the manager's icons.
--   Changing: the game's own settings object does it (SetCooldownToCategory, then
--     SaveCurrentLayout), as its settings window does. That writes into the game's tables
--     from an add-on, which may leave the manager unable to read buffs until the interface
--     is reloaded: so a change always asks for a reload, after which the game has loaded
--     the saved layout by itself. Unseen in game; what the game answered is noted in
--     VoltUIDB.viewerProbe.trackSet.
local function TrackCats()
  local c = Enum and Enum.CooldownViewerCategory
  return type(c) == "table" and c or nil
end

-- Cooldown ids that have an icon in the manager now.
local function TrackedNow()
  local out = {}
  for _, vname in ipairs(T.BUFF_VIEWERS) do
    local v = _G[vname]
    pcall(function()
      local frames = type(v) == "table" and v.GetItemFrames and v:GetItemFrames()
      for _, item in ipairs(type(frames) == "table" and frames or {}) do
        local cid = type(item) == "table" and Safe(item.cooldownID) or nil
        if cid ~= nil then out[cid] = true end
      end
    end)
  end
  return out
end

-- Every buff of yours the game can track: { id, name, icon, on }, by name. Nil when the
-- manager is off or this client has none.
function T.TrackList()
  local CV, cats = C_CooldownViewer, TrackCats()
  if not CV or not cats or not T.ManagerOn() then return nil end
  local now, pending = TrackedNow(), T.trackPending or {}
  local out, seen = {}, {}
  for _, cat in ipairs({ cats.TrackedBuff, cats.TrackedBar }) do
    pcall(function()
      for _, id in ipairs(CV.GetCooldownViewerCategorySet(cat, false) or {}) do
        local info = not seen[id] and CV.GetCooldownViewerCooldownInfo(id)
        local spell = type(info) == "table" and (Safe(info.overrideSpellID) or Safe(info.spellID)) or nil
        local name = type(spell) == "number" and SpellName(spell) or nil
        if name then
          seen[id] = true
          local on = now[id] or false
          if pending[id] ~= nil then on = pending[id] end
          out[#out + 1] = { id = id, name = name, icon = SpellIcon(spell), on = on, pending = pending[id] ~= nil }
        end
      end
    end)
  end
  table.sort(out, function(a, b) if a.name ~= b.name then return a.name < b.name end return a.id < b.id end)
  return out
end

-- Puts a buff among the game's Tracked Buffs, or takes it out. True, or false and why.
function T:SetTracked(id, on)
  local cats = TrackCats()
  local settings = _G.CooldownViewerSettings
  if self:InCombat() then return false, "Not in a fight: change it once the fight ends." end
  if not cats or type(settings) ~= "table" or not settings.GetDataProvider or not settings.SaveCurrentLayout then
    return false, "The game's Cooldown Manager settings aren't there."
  end
  local to = on and cats.TrackedBuff or cats.HiddenPassive
  if to == nil then return false, "This client has no place for a buff that isn't tracked." end
  local note = { at = date and date("%Y-%m-%d %H:%M:%S") or "?", id = id, on = on and true or false }
  local ok, status = pcall(function()
    local dp = settings:GetDataProvider()
    return dp:SetCooldownToCategory(id, to)
  end)
  note.set = tostring(ok) .. " " .. tostring(status)
  local fine = Enum and Enum.CooldownLayoutStatus and Enum.CooldownLayoutStatus.Success
  local took = ok and (fine == nil or status == nil or status == fine)
  if took then
    local saved, err = pcall(settings.SaveCurrentLayout, settings)
    note.saved = tostring(saved) .. " " .. tostring(err or "")
    took = saved
  end
  local db = ns.db
  if db then
    db.viewerProbe = type(db.viewerProbe) == "table" and db.viewerProbe or {}
    db.viewerProbe.trackSet = type(db.viewerProbe.trackSet) == "table" and db.viewerProbe.trackSet or {}
    table.insert(db.viewerProbe.trackSet, note)
    while #db.viewerProbe.trackSet > 12 do table.remove(db.viewerProbe.trackSet, 1) end
  end
  if not took then return false, "The game didn't take the change. Type /cdm and drag it there instead." end
  self.trackPending = self.trackPending or {}
  self.trackPending[id] = on and true or false
  self.trackReload = true
  return true
end

-- How the game's Cooldown Manager stands with one timer's buff (1.102.0), for that timer's
-- settings. Nil for anything but a buff or proc of your own (nothing to follow), else:
--   "none"   this client has no Cooldown Manager
--   "off"    the manager is switched off
--   "cant"   the game doesn't offer this buff to track
--   a table  { entries = the game's entries for it (T.TrackList's), on = all of them tracked,
--              pending = a change waiting for a reload }
-- `list` is T.TrackList() when the caller already has it.
function T:Follow(it, list)
  if not it or (it.kind ~= "keep" and it.kind ~= "proc") or it.unit ~= "player" then return nil end
  if not C_CooldownViewer then return "none" end
  if not T.ManagerOn() then return "off" end
  local want = {}
  for _, n in ipairs(it.names or {}) do want[n] = true end
  local out = { entries = {}, on = true, pending = false }
  for _, e in ipairs(list or T.TrackList() or {}) do
    if want[e.name] then
      out.entries[#out.entries + 1] = e
      if not e.on then out.on = false end
      if e.pending then out.pending = true end
    end
  end
  if #out.entries == 0 then return "cant" end
  return out
end

-- Has the game follow a timer's buff in a fight, or stop. True, or false and why.
function T:SetFollow(it, on)
  local f = self:Follow(it)
  if type(f) ~= "table" then return false, "The game's Cooldown Manager can't follow this one." end
  for _, e in ipairs(f.entries) do
    if (e.on and true or false) ~= (on and true or false) then
      local ok, why = self:SetTracked(e.id, on)
      if not ok then return false, why end
    end
  end
  return true
end

-- Your buffs and procs against the manager: how many it follows, and the names of the rest.
function T:FollowCount()
  local list = T.ManagerOn() and T.TrackList() or nil
  local total, followed, missing = 0, 0, {}
  for _, it in ipairs(self.items) do
    if it.listed and not it.hidden then
      local f = self:Follow(it, list)
      if f ~= nil then
        total = total + 1
        if type(f) == "table" and f.on then followed = followed + 1 else missing[#missing + 1] = it.name end
      end
    end
  end
  return followed, total, missing
end

-- The manager only needs to be on, not seen: VoltUI's Timers show the same things. With the
-- setting on its frames are made see-through and deaf to the mouse; they still update.
function T:HideManager()
  local on = T.ManagerOn()
  local hide = on and self:Cfg().hideManager and not (EditModeManagerFrame and EditModeManagerFrame.IsShown and EditModeManagerFrame:IsShown())
    and not (CooldownViewerSettings and CooldownViewerSettings.IsShown and CooldownViewerSettings:IsShown())
  if not hide and not self.managerHidden then return end
  self.managerHidden = hide or nil
  for _, vname in ipairs(T.VIEWERS) do
    local v = _G[vname]
    if type(v) == "table" and v.SetAlpha then
      v:SetAlpha(hide and 0 or 1)
      pcall(function()
        local frames = v.GetItemFrames and v:GetItemFrames()
        for _, item in ipairs(type(frames) == "table" and frames or {}) do
          if item.SetMouseMotionEnabled then item:SetMouseMotionEnabled(not hide) end
        end
      end)
    end
  end
end

-- Switches the game's Cooldown Manager on (the Timers page's button: your click).
function T:TurnManagerOn()
  local ok, err
  if SetCVar then ok, err = pcall(SetCVar, "cooldownViewerEnabled", "1") end
  -- noted, so a later look can tell a click that didn't take from no click at all
  local db = ns.db
  if db then
    db.viewerProbe = type(db.viewerProbe) == "table" and db.viewerProbe or {}
    db.viewerProbe.switchedOn = ("%s: set %s %s, now %s"):format(date and date("%Y-%m-%d %H:%M:%S") or "?", tostring(ok), tostring(err or ""),
      Describe(pcall(function() return GetCVar and GetCVar("cooldownViewerEnabled") end)))
  end
  self:HideManager()
  self:Soon("player")
end

-- Once, out of a fight: is the Cooldown Manager there and on, and which spells it tracks.
function T:ProbeViewerStatic()
  local db = ns.db
  if not db then return end
  local r = { at = date and date("%Y-%m-%d %H:%M:%S") or tostring(Now()) }
  local CV = C_CooldownViewer
  r.api = CV and "there" or "missing"
  if CV then
    r.available = Describe(pcall(function() return CV.IsCooldownViewerAvailable() end))
    r.cvar = Describe(pcall(function() return GetCVar and GetCVar("cooldownViewerEnabled") end))
    local cats = Enum and Enum.CooldownViewerCategory
    r.categories = {}
    for name, cat in pairs(type(cats) == "table" and cats or {}) do
      local line = {}
      local ok, err = pcall(function()
        local ids = CV.GetCooldownViewerCategorySet(cat, true)
        for i, id in ipairs(ids or {}) do
          if i > 40 then break end
          local info = CV.GetCooldownViewerCooldownInfo(id)
          local spell = type(info) == "table" and Safe(info.spellID) or nil
          line[#line + 1] = ("%s %s"):format(tostring(spell), tostring(spell and SpellName(spell) or "?"))
        end
      end)
      r.categories[tostring(name)] = ok and table.concat(line, "; ") or ("error: " .. tostring(err):sub(1, 90))
    end
  end
  r.frames = {}
  for _, name in ipairs(T.VIEWERS) do
    local f = _G[name]
    r.frames[name] = type(f) == "table" and ("there, shown " .. What(f.IsShown and f:IsShown())) or "missing"
  end
  db.viewerProbe = type(db.viewerProbe) == "table" and db.viewerProbe or {}
  db.viewerProbe.static = r
end

-- In a fight: what an add-on may see of each tracked buff icon.
function T:ProbeViewerFight(tag)
  local db = ns.db
  if not db then return end
  local r = { at = date and date("%Y-%m-%d %H:%M:%S") or tostring(Now()), when = tag, items = {} }
  for _, name in ipairs({ "BuffIconCooldownViewer", "BuffBarCooldownViewer" }) do
    local f = _G[name]
    local ok, err = pcall(function()
      if type(f) ~= "table" or not f.GetItemFrames then return end
      for i, item in ipairs({ f:GetItemFrames() }) do
        if i == 1 and type(item) == "table" and item[1] then -- one table of frames, not a list of returns
          for j, it in ipairs(item) do
            if j > 12 then break end
            local spell = it.GetSpellID and it:GetSpellID()
            r.items[#r.items + 1] = ("%s #%d: id %s, spell %s (%s), active %s, shown %s"):format(name, j, What(it.cooldownID), What(spell),
              tostring(Safe(spell) and SpellName(Safe(spell)) or "?"), What(it.isActive), What(it.IsShown and it:IsShown()))
          end
          return
        end
        if i > 12 then break end
        local spell = item.GetSpellID and item:GetSpellID()
        r.items[#r.items + 1] = ("%s #%d: id %s, spell %s (%s), active %s, shown %s"):format(name, i, What(item.cooldownID), What(spell),
          tostring(Safe(spell) and SpellName(Safe(spell)) or "?"), What(item.isActive), What(item.IsShown and item:IsShown()))
      end
    end)
    if not ok then r.items[#r.items + 1] = name .. " error: " .. tostring(err):sub(1, 90) end
  end
  r.log = self.logSeen and table.concat(self.logSeen, " | ") or "no combat log event"
  r.logCount = self.logCount or 0
  r.cvar = Describe(pcall(function() return GetCVar and GetCVar("cooldownViewerEnabled") end))
  db.viewerProbe = type(db.viewerProbe) == "table" and db.viewerProbe or {}
  db.viewerProbe.fights = type(db.viewerProbe.fights) == "table" and db.viewerProbe.fights or {}
  table.insert(db.viewerProbe.fights, r)
  while #db.viewerProbe.fights > 8 do table.remove(db.viewerProbe.fights, 1) end
end

-- The combat log, a few lines a fight: which of its values an add-on may read.
function T:ProbeLog()
  self.logCount = (self.logCount or 0) + 1
  self.logSeen = self.logSeen or {}
  if #self.logSeen >= 6 then return end
  local line
  local ok, err = pcall(function()
    local v = { CombatLogGetCurrentEventInfo() }
    local bits = { "n=" .. select("#", CombatLogGetCurrentEventInfo()) }
    for _, i in ipairs({ 2, 5, 9, 12, 13 }) do bits[#bits + 1] = i .. ":" .. What(v[i]) end
    line = table.concat(bits, ", ")
  end)
  self.logSeen[#self.logSeen + 1] = ok and line or ("error: " .. tostring(err):sub(1, 90))
end

function T:StartViewerProbe()
  if self.viewerProbe then return end
  local f = CreateFrame("Frame")
  self.viewerProbe = f
  -- Not the combat log: asking for COMBAT_LOG_EVENT_UNFILTERED is itself a forbidden action
  -- on this client (seen in game, 1.98.1: "VoltUI has been blocked", from this line). pcall
  -- doesn't catch that, and the event never came. Add-ons get no combat log here.
  pcall(f.RegisterEvent, f, "PLAYER_REGEN_DISABLED")
  pcall(f.RegisterEvent, f, "PLAYER_REGEN_ENABLED")
  f:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
      T.logSeen, T.logCount, T.fightAt = {}, 0, Now()
      T:ProbeViewerFight("fight start")
    else
      T:ProbeViewerFight("fight end, after " .. floor(Now() - (T.fightAt or Now())) .. "s")
    end
  end)
  if C_Timer and C_Timer.After then C_Timer.After(5, function() T:ProbeViewerStatic() end) else self:ProbeViewerStatic() end
end

function T:CanAttack()
  if not Safe(Ask(UnitExists, "target")) then return false end
  if Safe(Ask(UnitIsDeadOrGhost, "target")) == true then return false end
  return Safe(Ask(UnitCanAttack, "player", "target")) == true
end

function T:InCombat()
  return (InCombatLockdown and InCombatLockdown()) or Safe(Ask(UnitAffectingCombat, "player")) == true
end

------------------------------------------------------------------------
-- Updating
------------------------------------------------------------------------

function T:UpdateCooldowns()
  for _, it in ipairs(self.items) do
    if it.kind == "cd" and not it.hidden then
      local onCD, timer, usable, noPower = self:ReadCooldown(it)
      local st = it.st
      local was = st.onCD
      st.onCD, st.timer, st.usable, st.noPower = onCD, onCD and timer or nil, usable, noPower
      st.lit = it.react and not onCD and usable == true or nil
      if st.seen and was and not onCD then self:Pulse(it) end
      if st.seen and it.react and st.lit and not st.wasLit then self:Pulse(it) end
      st.wasLit = st.lit
      st.seen = true
      self:Paint(it)
    end
  end
  self:LayoutAll()
end

-- removed: the aura instance ids the game said went (UNIT_AURA's updateInfo), for when the
-- auras can't be read.
function T:UpdateAuras(unit, info)
  -- Nothing to look for on this unit: don't ask the game at all.
  local wanted = false
  for _, it in ipairs(self.items) do
    if it.unit == unit and (it.kind == "keep" or it.kind == "proc" or it.kind == "dot") and not it.hidden then
      wanted = true
      break
    end
  end
  if not wanted then return end
  local filter = unit == "player" and "HELPFUL" or "HARMFUL|PLAYER"
  local found, complete = T.Scan(unit, filter)
  local removed = {}
  -- In a fight the game can hand over these lists as secrets, which can't be walked (seen in
  -- game, 1.78.0: "table expected, got secret"); then they're left unread.
  local gone, added = Readable(info, "removedAuraInstanceIDs"), Readable(info, "addedAuras")
  if gone then
    pcall(function()
      for _, id in ipairs(gone) do
        id = Safe(id)
        if id then removed[id] = true end
      end
    end)
  end
  if not complete and added then
    pcall(function()
      for _, a in ipairs(added) do
        local n = type(a) == "table" and not IsSecret(a) and Safe(a.name)
        if n and found[n] == nil then found[n] = a end
      end
    end)
  end
  local attack = unit ~= "target" or self:CanAttack()
  -- The ids of the auras there now, and the ones that came on since the last look.
  local now = Now()
  self.lastIDs, self.fresh = self.lastIDs or {}, self.fresh or {}
  if info == "target" then self.lastIDs[unit], self.fresh[unit] = nil, nil end -- a new target
  local ids = T.AuraIDs(unit, filter)
  -- your buffs can't be read at all: the game's own buff frame may still say (1.98.0)
  local game
  if not complete and unit == "player" then
    game = T.GameBuffs()
    if game and not ids then ids = game.ids end
  end
  local function ById(st)
    ByID(unit, st)
    if game then FromGame(st, game.byId[st.aid]) end
  end
  -- and the game's Cooldown Manager says which of your tracked buffs are up (1.99.0)
  local viewer, viewerRead
  if not complete and unit == "player" then viewer, viewerRead = T.ViewerBuffs() end
  local fresh = self.fresh[unit] or {}
  self.fresh[unit] = fresh
  if ids then
    local last = self.lastIDs[unit]
    if last then
      for id in pairs(ids) do
        if not last[id] then fresh[id] = now end
      end
    end
    for id, at in pairs(fresh) do
      if not ids[id] or now - at > T.FRESH_TIME then fresh[id] = nil end
    end
    self.lastIDs[unit] = ids
  end
  local taken = {}
  for _, it in ipairs(self.items) do
    if it.unit == unit and it.st.aid then taken[it.st.aid] = true end
  end
  for _, it in ipairs(self.items) do
    if it.unit == unit and (it.kind == "keep" or it.kind == "proc" or it.kind == "dot") and not it.hidden then
      local st = it.st
      local a
      for _, n in ipairs(it.names) do
        a = found[n]
        if a then break end
      end
      if not a and not complete then
        local UA = C_UnitAuras
        for _, n in ipairs(it.names) do
          local got = UA and Ask(UA.GetAuraDataBySpellName, unit, n, filter)
          if type(got) == "table" then a = got break end
        end
      end
      local on
      st.unsure, st.untracked = nil, nil
      if unit == "player" and it.kind == "keep" and not complete and self:InCombat() then self:Probe(st) end
      if a then
        on = true
        -- Seen now, whatever its id: a cast before this moment is this aura's own (1.92.4). The
        -- cast event can come a frame after the aura's, and taking it for a later recast kept a
        -- shield put on out of combat "on" after it went in the fight.
        st.aid, st.aidAt = Safe(a.auraInstanceID), Now()
        local sid = Safe(a.spellId)
        if type(sid) == "number" then st.spellId = sid end
        st.timer = AuraTimer(unit, a)
        st.count = AuraCount(unit, a)
        if it.kind == "proc" and S.Present(a.icon) then st.icon = a.icon end
      elseif complete or (unit == "target" and info == "target") then
        on = false
      elseif viewer and ViewerSays(it, viewer) ~= nil then
        on = ViewerSays(it, viewer) -- the game's own tracker: up or down, whatever else is hidden
        if on and not st.on then st.timer, st.count = nil, "" end
      elseif viewerRead and unit == "player" and (it.kind == "keep" or it.kind == "proc") then
        -- (1.101.5) The manager is on and this buff isn't on it: you've set it to Not tracked,
        -- so nothing can say how it's doing in this fight. It stays as it was, unseen and
        -- without a warning. The guesses below (asking the game about one aura) are refused
        -- in a fight, and a refusal read as "gone": Lightning Shield set to Not tracked kept
        -- flashing as missing while it was up (seen by the user, 2026-11-21).
        on = st.on and true or false
        st.unsure, st.untracked = true, true
      elseif st.aid and removed[st.aid] then
        on = false
      elseif game and InGame(it, st, game, taken, now) then
        on = true -- the game's buff frame has it
      elseif ids and st.aid then
        -- names hidden, but the ids aren't: still there, or gone (1.89.0)
        if ids[st.aid] then
          on = true
          ById(st)
        else
          -- gone, unless you've just put it back on: then it's the new aura that came with the cast
          local new = st.castAt and now - st.castAt <= T.FRESH_TIME and OneFresh(fresh, taken)
          if new then
            st.aid, st.aidAt, taken[new] = new, now, true
            ById(st)
          end
          on = new and true or false
        end
      elseif not ids and unit == "player" and it.kind == "keep" then
        -- the id list hidden too: ask about this one buff (1.92.3)
        local still, unknown = T.StillOn(st)
        if still == nil then
          on = st.on and true or false -- can't see: as it was, and look again when it can be read
          st.unsure = true
        else
          on = still
          if still and st.aid and not unknown then ById(st) end
          if unknown then st.unsure, st.timer = true, nil end
        end
      elseif ids and st.on then
        -- on since your cast in this fight, its aura not known yet: the one that came with the cast
        local new = st.castAt and now - st.castAt <= T.FRESH_TIME and OneFresh(fresh, taken)
        if new then
          st.aid, st.aidAt, taken[new] = new, now, true
          ById(st)
        else
          st.unsure = true
        end
        on = true
      else
        on = st.on and true or false -- can't see: as it was, and look again when it can be read
        st.unsure = true
      end
      if not on then st.aid, st.timer, st.count = nil, nil, "" end
      if unit == "target" and not attack then on = false end
      if st.seen and on and not st.on then
        self:Pulse(it)
      elseif st.seen and not on and st.on and (it.kind == "keep" or it.kind == "dot") then
        st.dropped = Now()
      end
      st.on = on
      st.seen = true
      self:Paint(it)
    end
  end
  self:LayoutAll()
end

function T:UpdateImbues()
  local has = {}
  local ok, mh, mhMs, _, _, oh, ohMs = pcall(GetWeaponEnchantInfo or error)
  if ok then
    has[16] = { Safe(mh) == true, Safe(mhMs) }
    has[17] = { Safe(oh) == true, Safe(ohMs) }
  end
  local now = Now()
  for _, it in ipairs(self.items) do
    if it.kind == "imbue" and not it.hidden then
      local st = it.st
      local h = has[it.hand] or {}
      local on = h[1] == true
      st.icon = GetInventoryItemTexture and Ask(GetInventoryItemTexture, "player", it.hand) or nil
      if on and type(h[2]) == "number" then
        local left = h[2] / 1000
        if not st.full or left > st.full + 1 then st.full = left end -- put on again: a new full time
        st.timer = { start = now - (st.full - left), length = st.full }
      else
        st.full, st.timer = nil, nil
      end
      if st.seen and on and not st.on then self:Pulse(it) end
      if st.seen and not on and st.on then st.dropped = now end
      st.on = on
      st.seen = true
      self:Paint(it)
    end
  end
  self:LayoutAll()
end

function T:UpdateTotems()
  local now = Now()
  for _, it in ipairs(self.items) do
    if it.kind == "totem" and not it.hidden then
      local st = it.st
      local r = { pcall(GetTotemInfo, it.slot) }
      local have, name, start, length, icon = r[2], r[3], r[4], r[5], r[6]
      local on
      if not r[1] then
        on = false
      elseif IsSecret(have) then
        -- A fight hides whether there's a totem in the slot at all. The game's own timer for
        -- the slot says: it hands one over for a totem that's down and nothing for an empty
        -- slot. (Seen in game, 1.79.0: every slot counted as a totem, so the three empty ones
        -- stood as full bars with no name, and a totem that ran out stayed as an empty bar.)
        -- With no way to ask for that timer, the slot stays as it was last known.
        st.secret = true
        if GetTotemDuration then
          st.timer = DurTimer(Ask(GetTotemDuration, it.slot))
          on = st.timer ~= nil
        else
          on = st.on == true
          if not on then st.timer = nil end
        end
      else
        st.secret = nil
        local s, d = Safe(start), Safe(length)
        on = have == true and (d == nil or d > 0)
        st.timer = on and s and d and d > 0 and { start = s, length = d } or nil
        if on and not st.timer and GetTotemDuration then st.timer = DurTimer(Ask(GetTotemDuration, it.slot)) end
      end
      if on then st.icon, st.label = icon, name end
      if st.seen and on and not st.on then
        self:Pulse(it)
        st.gone = nil
      elseif st.seen and not on and st.on then
        st.gone = now + 2.5 -- a flash for a moment where it was, then it goes
      end
      st.on = on
      st.seen = true
      self:Paint(it)
    end
  end
  self:LayoutAll()
end

function T:UpdateAll()
  self:UpdateCooldowns()
  self:UpdateAuras("player")
  self:UpdateAuras("target", "target")
  self:UpdateImbues()
  if GetTotemInfo then self:UpdateTotems() end
end

------------------------------------------------------------------------
-- Widgets
------------------------------------------------------------------------

local function SetTimer(w, timer, kind)
  -- Skip what's already showing, so a running sweep isn't restarted.
  local last = w.timer
  if timer and last and timer.dur == nil and last.dur == nil and timer.start and last.start
    and math.abs(timer.start - last.start) < 0.25 and math.abs(timer.length - last.length) < 0.25 then
    return
  end
  if timer == nil and last == nil then return end
  w.timer = timer
  local cdf, bar = w.cd, w.bar
  if not timer then
    if cdf.Clear then cdf:Clear() else cdf:SetCooldown(0, 0) end
    if bar then bar:SetValue(kind == "cd" and 1 or 0) end
    return
  end
  if timer.dur ~= nil then
    if cdf.SetCooldownFromDurationObject then pcall(cdf.SetCooldownFromDurationObject, cdf, timer.dur) end
    if bar and bar.SetTimerDuration then
      local En = Enum or {}
      local dir = En.StatusBarTimerDirection or {}
      -- Cooldowns fill as they come back; auras drain as they run out.
      local d = kind == "cd" and (dir.ElapsedTime or 0) or (dir.RemainingTime or 1)
      pcall(bar.SetTimerDuration, bar, timer.dur, 0, d)
    end
  elseif type(timer.start) == "number" and type(timer.length) == "number" then
    cdf:SetCooldown(timer.start, timer.length)
  else
    -- no time to show (seen in game, 1.78.0: a totem the game gave no time for)
    if cdf.Clear then cdf:Clear() else cdf:SetCooldown(0, 0) end
    if bar then bar:SetValue(kind == "cd" and 1 or 0) end
  end
end

local function Edges(w, layer, sub, outset)
  return S.Edges(w.body, layer, sub, w.icon, outset)
end

function T:Widget(it)
  local style = self:Opt(it, "style")
  local w = it.w
  local holder = self.holders[it.group]
  if w and w.style == style then
    if w.group ~= it.group then -- moved to another block
      w.group = it.group
      if w.SetParent then w:SetParent(holder) end
    end
    return w
  end
  if w then w:Hide() end
  w = CreateFrame("Frame", nil, holder)
  w.style, w.item, w.group = style, it, it.group
  w.body = CreateFrame("Frame", nil, w)
  w.body:SetPoint("CENTER")
  w.back = S.Tex(w.body, "BACKGROUND", -8)
  w.back:SetColorTexture(0, 0, 0, 0.6)
  w.icon = S.Tex(w.body, "ARTWORK")
  w.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  w.edge = Edges(w, "OVERLAY", 4, 1)
  S.ColorEdges(w.edge, 0, 0, 0, 1)
  -- the pulse: a white glow over the icon; the warning: a red wash and border
  w.glow = S.Tex(w.body, "OVERLAY", 5)
  w.glow:SetAllPoints(w.icon)
  w.glow:SetColorTexture(1, 1, 1, 1)
  if w.glow.SetBlendMode then w.glow:SetBlendMode("ADD") end
  w.glow:SetAlpha(0)
  w.wash = S.Tex(w.body, "OVERLAY", 6)
  w.wash:SetAllPoints(w.icon)
  w.wash:SetColorTexture(T.WARN[1], T.WARN[2], T.WARN[3], 1)
  w.wash:SetAlpha(0)
  w.warn = Edges(w, "OVERLAY", 7, 2)
  S.ColorEdges(w.warn, T.WARN[1], T.WARN[2], T.WARN[3], 1)
  S.HideEdges(w.warn)
  w.cd = CreateFrame("Cooldown", nil, w.body, "CooldownFrameTemplate")
  if w.cd.SetDrawEdge then w.cd:SetDrawEdge(false) end
  if w.cd.SetHideCountdownNumbers then w.cd:SetHideCountdownNumbers(false) end
  if w.cd.SetSwipeColor then w.cd:SetSwipeColor(0, 0, 0, 0.7) end
  if w.cd.SetCountdownAbbrevThreshold then pcall(w.cd.SetCountdownAbbrevThreshold, w.cd, 90) end
  -- a cooldown's end, even one VoltUI couldn't read: look again
  w.cd:SetScript("OnCooldownDone", function() T:Soon(it.kind) end)
  w.count = S.Text(w.body, nil, "RIGHT", "OVERLAY")
  if style == "bars" then
    w.bar = S.Bar(w.body)
    w.bar:SetMinMaxValues(0, 1)
    w.bar.bg:SetColorTexture(0, 0, 0, 0.55)
    w.label = S.Text(w.bar, nil, "LEFT", "OVERLAY")
    w.label:SetPoint("LEFT", 4, 0)
    if w.cd.SetDrawSwipe then w.cd:SetDrawSwipe(false) end
  end
  it.w = w
  self:Shape(it)
  return w
end

-- A timer's width and height on screen: its own, or its block's.
function T:Dim(it)
  if self:Opt(it, "style") == "bars" then return self:Opt(it, "width"), self:Opt(it, "height") end
  local size = self:Opt(it, "size")
  return size, size
end

-- Size and fonts from the timer's settings.
function T:Shape(it)
  local w = it.w
  if not w then return end
  local cw, size = self:Dim(it)
  w:SetSize(cw, size)
  w.body:SetSize(cw, size)
  w.icon:ClearAllPoints()
  w.icon:SetPoint("TOPLEFT", w.body, "TOPLEFT", 0, 0)
  w.icon:SetSize(size, size)
  w.back:ClearAllPoints()
  w.back:SetAllPoints(w.body)
  w.cd:ClearAllPoints()
  if w.style == "bars" then
    w.bar:ClearAllPoints()
    w.bar:SetPoint("TOPLEFT", w.icon, "TOPRIGHT", 1, 0)
    w.bar:SetPoint("BOTTOMRIGHT", w.body, "BOTTOMRIGHT", 0, 0)
    -- the time sits at the bar's right end
    w.cd:SetPoint("TOPRIGHT", w.bar, "TOPRIGHT", -2, 0)
    w.cd:SetPoint("BOTTOMRIGHT", w.bar, "BOTTOMRIGHT", -2, 0)
    w.cd:SetWidth(size * 2)
    S.SetFont(w.label, max(9, floor(size * 0.5 + 0.5)), "OUTLINE", "timers.label")
  else
    w.cd:SetAllPoints(w.icon)
  end
  local fs = w.cd.GetCountdownFontString and Ask(w.cd.GetCountdownFontString, w.cd)
  if type(fs) == "table" and fs.SetFont then
    S.SetFont(fs, self:Opt(it, "numbers"), "OUTLINE", "timers.numbers")
    if w.style == "bars" and fs.ClearAllPoints then
      fs:ClearAllPoints()
      fs:SetPoint("RIGHT", w.cd, "RIGHT", 0, 0)
      if fs.SetJustifyH then fs:SetJustifyH("RIGHT") end
    end
  end
  w.count:ClearAllPoints()
  w.count:SetPoint("BOTTOMRIGHT", w.icon, "BOTTOMRIGHT", -1, 2)
  S.SetFont(w.count, max(9, floor(size * 0.34 + 0.5)), "OUTLINE", "timers.count")
end

-- Should it be on screen?
function T:Visible(it)
  if it.hidden or not self:G(it.group).on then return false end
  if self.preview then return true end
  if not self:Allowed(it) then return false end -- (1.102.0) its own conditions: fight, place
  local st = it.st
  local k = it.kind
  if k == "cd" then return not (self:Opt(it, "ready") == "hide" and not st.onCD) end
  if k == "keep" or k == "imbue" then
    if st.untracked and not st.on and self:InCombat() then return false end -- (1.101.5) Not tracked: silent in a fight
    if st.on then
      if self:Opt(it, "up") == "hide" then return self:RunningOut(it) end
      return true
    end
    -- missing: flashing, faded or not there at all, as picked for in and out of a fight
    return self:Missing(it) ~= "hide"
  end
  if k == "proc" then return st.on == true end
  if k == "dot" then
    if not self:CanAttack() then return false end
    return st.on == true or not self:InCombat() or self:Opt(it, "miss") ~= "hide"
  end
  if k == "totem" then return st.on == true or (st.gone ~= nil and Now() < st.gone) end
  return false
end

-- A buff that's on, with no more than buffSoon seconds left. A time the game keeps secret can't
-- be read, so such a buff counts as on until it's gone.
function T:RunningOut(it)
  local t = it.st.timer
  if not (t and type(t.start) == "number" and type(t.length) == "number") then return false end
  return t.start + t.length - Now() <= (tonumber(self:Opt(it, "soon")) or 60)
end

-- What a missing buff does right now: "flash", "faded" or "hide".
function T:Missing(it)
  return self:Opt(it, self:InCombat() and "miss" or "missOut")
end

-- Should a missing one flash?
function T:Warns(it)
  local st = it.st
  if self.preview then return false end
  if not self:Allowed(it) then return false end
  if it.kind == "totem" then return st.gone ~= nil and Now() < st.gone end
  if st.on then return false end
  local fight = self:InCombat()
  if it.kind == "dot" then return fight and self:CanAttack() and self:Opt(it, "miss") == "flash" end
  if it.kind == "keep" or it.kind == "imbue" then
    if fight and st.untracked then return false end -- (1.101.5) set to Not tracked: no warning in a fight
    return self:Missing(it) == "flash"
  end
  return false
end

function T:Paint(it)
  if it.hidden then
    if it.w then
      it.w.flashing = nil -- or it's still animated every frame, unseen
      it.w:Hide()
    end
    return
  end
  local w = self:Widget(it)
  local st = it.st
  local cfg = self:Cfg()
  local k = it.kind
  local icon = st.icon or it.icon
  if self.preview and not S.Present(icon) then icon = 134400 end -- the question mark
  w.icon:SetTexture(icon)
  local r, g, b = 1, 1, 1
  local desat, alpha = false, 1
  local timer = st.timer
  if self.preview then
    timer = (k == "cd" or k == "totem" or k == "proc" or k == "dot") and { start = Now(), length = 30 } or nil
  elseif k == "cd" then
    desat = st.onCD == true
    if self:Opt(it, "usable") and not st.onCD then
      if st.noPower then r, g, b = 0.45, 0.55, 1 end
      if it.react and not st.lit then alpha = 0.4 end
    end
  elseif k == "keep" or k == "imbue" or k == "dot" then
    if not st.on then
      desat = true
      alpha = self:Warns(it) and 1 or 0.45
    end
  end
  w.icon:SetDesaturated(desat)
  w.icon:SetVertexColor(r, g, b)
  w.body:SetAlpha(alpha)
  w.count:SetText(self.preview and "" or (st.count or ""))
  -- a reactive spell ready to use: a gold border while it is
  if st.lit and not self.preview then
    S.ColorEdges(w.edge, 1, 0.82, 0.2, 1)
  else
    S.ColorEdges(w.edge, 0, 0, 0, 1)
  end
  if w.bar then
    local c = it.color or T.COLORS[k] or T.COLORS.cd
    S.BarColor(w.bar, c[1], c[2], c[3])
    local text = it.name
    if k == "totem" and S.Present(st.label) then text = st.label end -- a secret name still shows
    if not self.preview and (k == "keep" or k == "imbue" or k == "dot") and not st.on then
      w.label:SetText(it.name .. " missing")
      w.label:SetTextColor(1, 0.45, 0.45)
    else
      w.label:SetText(text)
      w.label:SetTextColor(1, 1, 1)
    end
  end
  SetTimer(w, timer, k)
  if w.bar and not timer then w.bar:SetValue((k == "cd" or st.on) and 1 or 0) end
  local warn = self:Warns(it)
  w.flashing = warn or nil
  if warn then
    self.anims[w] = true
  else
    w.wash:SetAlpha(0)
    S.HideEdges(w.warn)
  end
  if w.timer and w.timer.start and w.bar then self.anims[w] = true end
end

------------------------------------------------------------------------
-- Pulse and flash: one OnUpdate for all of them
------------------------------------------------------------------------

T.PULSE_TIME, T.PULSE_GROW = 0.45, 0.32

function T:Pulse(it)
  if not it.w or not self:Opt(it, "pulse") then return end
  it.w.pulse = Now()
  self.anims[it.w] = true
end

function T:Animate(now)
  for w in pairs(self.anims) do
    local busy = false
    if w.pulse then
      local p = (now - w.pulse) / T.PULSE_TIME
      if p < 0 then
        busy = true -- a pulse that starts in a moment (/volt timers test, one after another)
      elseif p >= 1 then
        w.pulse = nil
        w.body:SetScale(1)
        w.glow:SetAlpha(0)
      else
        w.body:SetScale(1 + T.PULSE_GROW * sin(p * pi))
        w.glow:SetAlpha(0.75 * (1 - p))
        busy = true
      end
    end
    if w.flashing then
      local a = 0.5 + 0.5 * sin(now * 2 * pi * 1.4)
      w.wash:SetAlpha(0.12 + 0.4 * a)
      S.ColorEdges(w.warn, T.WARN[1], T.WARN[2], T.WARN[3], 0.35 + 0.65 * a)
      busy = true
    end
    -- bars with a time VoltUI can read: VoltUI moves them
    local t = w.timer
    if w.bar and t and t.start and t.length and t.length > 0 then
      local done = (now - t.start) / t.length
      done = min(1, max(0, done))
      w.bar:SetValue(w.item.kind == "cd" and done or 1 - done)
      busy = done < 1 or busy
    end
    if not busy then self.anims[w] = nil end
  end
end

------------------------------------------------------------------------
-- Layout
------------------------------------------------------------------------

function T:Layout(gkey)
  local holder = self.holders[gkey]
  if not holder then return end
  local g = self:G(gkey)
  local all, shown = {}, {}
  for _, it in ipairs(self.items) do
    if it.group == gkey and not it.hidden then
      all[#all + 1] = it
      if it.w and self:Visible(it) then shown[#shown + 1] = it end
    end
  end
  local per = max(1, g.perRow)
  local gap = g.gap
  local vertical = g.grow == "down" or g.grow == "up"
  -- (1.102.0) Each timer has its own size, so a line is as long as what's in it and as thick
  -- as its biggest. Lines run across (rows), or down or up (columns).
  local function measure(list)
    local lines, length, thick = {}, 0, 0
    for i = 1, #list, per do
      local line = { len = 0, thick = 0 }
      for j = i, min(i + per - 1, #list) do
        local w, h = self:Dim(list[j])
        local along, across = vertical and h or w, vertical and w or h
        line.len = line.len + along + (#line > 0 and gap or 0)
        line.thick = max(line.thick, across)
        line[#line + 1] = { it = list[j], along = along }
      end
      lines[#lines + 1] = line
      length = max(length, line.len)
      thick = thick + line.thick + (#lines > 1 and gap or 0)
    end
    return lines, length, thick
  end
  -- The block is as big as all its timers showing at once, so it doesn't jump about.
  local _, capLen, capThick = measure(all)
  if #all == 0 then -- nothing in it: one of its own cells, for moving frames
    local bars = g.style == "bars"
    local cw, ch = bars and g.width or g.size, bars and g.height or g.size
    capLen, capThick = vertical and ch or cw, vertical and cw or ch
  end
  local lines, len, thick = measure(shown)
  len, thick = max(len, capLen), max(thick, capThick)
  local W, H = vertical and thick or len, vertical and len or thick
  W, H = max(W, 40), max(H, 16)
  holder:SetSize(W, H)
  holder:SetScale(self:Cfg().scale or 1)
  local off = 0
  for _, line in ipairs(lines) do
    local at = 0
    for _, c in ipairs(line) do
      local w = c.it.w
      w:ClearAllPoints()
      if vertical then
        if g.grow == "up" then
          w:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", off, at)
        else
          w:SetPoint("TOPLEFT", holder, "TOPLEFT", off, -at)
        end
      elseif g.grow == "left" then
        w:SetPoint("TOPRIGHT", holder, "TOPRIGHT", -at, -off)
      elseif g.grow == "right" then
        w:SetPoint("TOPLEFT", holder, "TOPLEFT", at, -off)
      else
        w:SetPoint("TOPLEFT", holder, "TOPLEFT", (W - line.len) / 2 + at, -off)
      end
      w:Show()
      at = at + c.along + gap
    end
    off = off + line.thick + gap
  end
  local showing = {}
  for _, it in ipairs(shown) do showing[it] = true end
  for _, it in ipairs(self.items) do
    if it.w and (it.hidden or (it.group == gkey and not showing[it])) then it.w:Hide() end
  end
  holder:SetShown(g.on and (#all > 0 or self.preview) and true or false)
  if holder.empty then holder.empty:SetShown(self.preview and #all == 0 or false) end
end

function T:LayoutAll()
  if not self.enabled then return end
  for _, g in ipairs(T.GROUPS) do self:Layout(g.key) end
  self:Fade()
  self:GameTotems()
end

-- The game's own totem buttons (TotemFrame), since 1.77.0. While the Totems group is on they're
-- see-through and each lies over its totem's timer here, so the game's buttons stay what you
-- click: right-click destroys the totem, a hover shows its tooltip. DestroyTotem only works
-- from the game's own code, which is why its buttons are kept rather than VoltUI's made to click.
-- Only their place, layer, opacity and mouse are changed, never a field the game reads.
function T:GameTotems()
  local tf = _G.TotemFrame
  if type(tf) ~= "table" or not tf.GetChildren or self.placingTotems then return end
  self.placingTotems = true
  if not self.totemHooks then
    self.totemHooks = true
    for _, m in ipairs({ "Update", "Layout" }) do
      if type(tf[m]) == "function" then hooksecurefunc(tf, m, function() T:GameTotems() end) end
    end
  end
  local byslot = {}
  for _, it in ipairs(self.items or {}) do
    -- (1.102.0) only totems that are timers of yours, in a block that's showing
    if it.kind == "totem" and not it.hidden and self:G(it.group).on then byslot[it.slot] = it end
  end
  -- Only while VoltUI has totem timers to show: the game's own frame would be hidden and
  -- unclickable for a class VoltUI shows nothing for, or with no totem in your list.
  local on = self.enabled and next(byslot) ~= nil and true or false
  tf:SetAlpha(on and 0 or 1)
  local back = self.totemsTaken and not on
  self.totemsTaken = on or nil
  for _, b in ipairs({ tf:GetChildren() }) do
    local slot = type(b.slot) == "number" and b.slot or nil
    if slot and on then
      local it = byslot[slot]
      local w = it and not it.hidden and it.w
      b:ClearAllPoints()
      if w and w:IsShown() then
        b:SetAllPoints(w)
        b:SetFrameStrata(w:GetFrameStrata())
        b:SetFrameLevel(w:GetFrameLevel() + 10)
        b:EnableMouse(true)
      else
        b:SetPoint("CENTER", tf, "CENTER") -- no timer to lie over: out of the way, and no clicks
        b:EnableMouse(false)
      end
    elseif slot and back then
      b:SetFrameStrata(tf:GetFrameStrata())
      b:EnableMouse(true)
    end
  end
  if back and type(tf.Layout) == "function" then tf:Layout() end -- the game's row again
  self.placingTotems = nil
end

-- Out of a fight with no target: the opacity you picked.
function T:Fade()
  local a = 1
  if not self.preview and not self:InCombat() and not Safe(Ask(UnitExists, "target")) then
    a = self:Cfg().idleAlpha or 1
  end
  for _, h in pairs(self.holders) do h:SetAlpha(a) end
end

------------------------------------------------------------------------
-- Holders, spots and moving
------------------------------------------------------------------------

function T:Place(gkey)
  local h = self.holders[gkey]
  if not h then return end
  if not S.PlaceSpot(h, T.SpotKeys(gkey)) then
    local sp = T.SPOTS[gkey]
    h:ClearAllPoints()
    h:SetPoint(sp[1], UIParent, sp[1], sp[2], sp[3])
  end
end

function T:MakeHolder(g)
  local h = CreateFrame("Frame", "VoltUITimers" .. g.key:gsub("^%l", string.upper), UIParent)
  h:SetFrameStrata("MEDIUM")
  h:SetClampedToScreen(true)
  h:SetMovable(true)
  h:SetSize(120, 30)
  h.key = g.key
  h.mover = S.Mover(h, "Timers: " .. g.name, function(fr)
    S.KeepSpot(fr, T.SpotKeys(g.key))
  end, { spot = function() return T.SpotKeys(g.key) end,
         default = function() S.ClearSpot(T.SpotKeys(g.key)); T:Place(g.key) end })
  h.mover:SetScript("OnMouseUp", function()
    if S.MoverDragged(h.mover) then return end -- that was the end of a drag, not a click
    if ns.EditMode then
      ns.EditMode.timerGroup, ns.EditMode.timerView = g.key, "layout"
      ns.EditMode:Open("timers")
    end
  end)
  h.empty = S.Text(h, nil, "CENTER", "OVERLAY", 11)
  h.empty:SetPoint("CENTER")
  h.empty:SetText(g.name)
  h.empty:Hide()
  self.holders[g.key] = h
  self:Place(g.key)
  return h
end

function T:SetUnlocked(on)
  self.preview = on and true or nil
  for _, h in pairs(self.holders) do h.mover:SetShown(on and true or false) end
  self:Refresh()
end

------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------

-- Look again next frame, once (a burst of events is one look).
function T:Soon(what)
  self.due = self.due or {}
  self.due[what or "all"] = true
  if self.waiting then return end
  self.waiting = true
  local function run()
    T.waiting = nil
    local due = T.due
    T.due = {}
    if due.rescan then
      T:Collect()
      T:UpdateAll()
      return
    end
    if due.all then T:UpdateAll() return end
    if due.cd then T:UpdateCooldowns() end
    if due.keep or due.proc or due.player then T:UpdateAuras("player") end
    if due.dot or due.target then T:UpdateAuras("target", "target") end
    if due.imbue then T:UpdateImbues() end
    if due.totem and GetTotemInfo then T:UpdateTotems() end
  end
  if C_Timer and C_Timer.After then C_Timer.After(0, run) else run() end
end

local EVENTS = {
  "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB", "PLAYER_LEVEL_UP", "CHARACTER_POINTS_CHANGED",
  "PLAYER_TALENT_UPDATE", "UNIT_AURA", "PLAYER_TARGET_CHANGED", "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_USABLE",
  "PLAYER_TOTEM_UPDATE", "UNIT_INVENTORY_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
  "UNIT_SPELLCAST_SUCCEEDED", "ZONE_CHANGED_NEW_AREA",
}

-- You cast one of your buffs to keep up. In a fight the game can hide aura names, so a
-- buff put back on then couldn't be seen and stayed "missing" (seen in game, 1.77.0): the
-- cast says it's on until the auras can be read again (1.78.0).
function T:Cast(spellID)
  local n = SpellName(Safe(spellID))
  if not n then return end
  local changed = false
  for _, it in ipairs(self.items) do
    if it.kind == "keep" and it.unit == "player" and not it.hidden then
      for _, name in ipairs(it.names) do
        if name == n then
          local st = it.st
          st.castAt = Now() -- the new aura that comes with it is this buff (1.89.0)
          local cid = Safe(spellID)
          if type(cid) == "number" then st.castID = cid end -- the rank cast: its aura has this id
          if not st.on then
            st.on, st.unsure, st.timer, st.count = true, true, nil, ""
            st.seen = true
            self:Pulse(it)
            self:Paint(it)
            changed = true
          end
          break
        end
      end
    end
  end
  if changed then self:LayoutAll() end
  self:Soon("player") -- and read it properly, if it can be
end

function T:OnEvent(event, unit, info, spellID)
  if event == "UNIT_AURA" then
    if unit == "player" or unit == "target" then self:UpdateAuras(unit, info) end
  elseif event == "PLAYER_TARGET_CHANGED" then
    self:UpdateAuras("target", "target")
  elseif event == "SPELL_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_USABLE" then
    -- straight away: isOnGCD is only right while this event is being handled
    self:UpdateCooldowns()
  elseif event == "PLAYER_TOTEM_UPDATE" then
    self:Soon("totem")
  elseif event == "UNIT_INVENTORY_CHANGED" then
    if unit == "player" then self:Soon("imbue") end
  elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
    if unit == "player" then self:Cast(spellID) end
  elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
    if event == "PLAYER_REGEN_DISABLED" then self.probes = 0 end -- a new fight: probe its first changes
    for _, it in ipairs(self.items) do if it.w then self:Paint(it) end end
    self:LayoutAll()
    -- out of the fight, auras can be read again: what was put on or went during it (1.78.0)
    if event == "PLAYER_REGEN_ENABLED" then
      self:Soon("player")
      self:Soon("target")
      self:Soon("totem") -- and the totems: which slots really hold one (1.80.1)
    end
  else
    self.zone = nil -- a loading screen or a new zone: where you are is asked again
    self:Soon("rescan")
  end
end

-- Twice a second: weapon imbues (no event as they run down), totems gone a moment ago, and
-- readable times that ran out.
function T:Tick()
  local now = Now()
  local imbue, relayout, unsure
  for _, it in ipairs(self.items) do
    local st = it.st
    if it.kind == "imbue" then imbue = true end
    if st.unsure and it.unit == "player" and not it.hidden then unsure = true end
    if st.gone and now >= st.gone then
      st.gone = nil
      relayout = true
      if it.w then self:Paint(it) end
    end
    -- a buff hidden while it's up shows again as it runs out
    if it.kind == "keep" and st.on and not it.hidden then
      local out = self:RunningOut(it)
      if out ~= (st.out or false) then
        st.out = out
        relayout = true
      end
    end
    local t = st.timer
    if t and t.start and t.length and now > t.start + t.length + 0.1 and it.kind ~= "imbue" then
      self:Soon(it.kind)
    end
    -- a totem last read while the game was hiding it: read again once it will say
    if it.kind == "totem" and st.secret and st.on and not it.hidden and not self:InCombat() then
      self:Soon("totem")
    end
  end
  if imbue then self:UpdateImbues() end
  if relayout then self:LayoutAll() end
  if unsure and not self:InCombat() then self:UpdateAuras("player") end -- couldn't be read: try again
  self:HideManager()
  -- in a fight the game's tracker is the only word on your buffs: ask it again (1.99.0)
  if self:InCombat() and T.ManagerOn() then self:UpdateAuras("player") end
end

function T:Enable()
  self.enabled = true
  self:Cfg()
  for _, g in ipairs(T.GROUPS) do self:MakeHolder(g) end
  local ev = CreateFrame("Frame")
  self.ev = ev
  -- The unit events for you (and your target's auras) only: in a raid they fire for everyone.
  local UNITS = { UNIT_AURA = { "player", "target" }, UNIT_INVENTORY_CHANGED = { "player" }, UNIT_SPELLCAST_SUCCEEDED = { "player" } }
  for _, e in ipairs(EVENTS) do
    local units = UNITS[e]
    if not (units and ev.RegisterUnitEvent and pcall(ev.RegisterUnitEvent, ev, e, unpack(units))) then
      pcall(ev.RegisterEvent, ev, e)
    end
  end
  ev:SetScript("OnEvent", function(_, event, ...) T:OnEvent(event, ...) end)
  local wait = 0
  ev:SetScript("OnUpdate", function(_, dt)
    local now = Now()
    T:Animate(now)
    wait = wait + (dt or 0)
    if wait >= 0.5 then
      wait = 0
      T:Tick()
    end
  end)
  self:StartViewerProbe()
  -- After the game's buff frame reads your buffs: look at what it has (1.98.0). The game's
  -- own handler can run after VoltUI's for the same change.
  local bf = _G.BuffFrame
  if type(bf) == "table" and bf.UpdateAuras and hooksecurefunc then
    hooksecurefunc(bf, "UpdateAuras", function() T:Soon("player") end)
  end
  self:Collect()
  self:UpdateAll()
end

-- A setting changed: new looks, sizes and layout.
function T:Refresh()
  self.cfgFilled = nil -- a setting put back to its default is nil until filled in again
  self.zone = nil
  if not self.enabled then return end
  for _, it in ipairs(self.items) do
    self:Mark(it)
    if it.w then
      self:Widget(it) -- a new shape or block, if its settings say so
      self:Shape(it)
    end
  end
  for _, it in ipairs(self.items) do
    if not it.hidden then self:Paint(it) end
  end
  self:LayoutAll()
end

-- Everything found for your class, in order: your timers and the rest.
function T:List()
  return self.items
end

-- Every timer's settings back to what its block gives it, the blocks' looks and spots back
-- to the defaults. Your list stays: which timers you have, and the spells you added.
function T:Reset()
  local db = ns.db
  local old = type(db.timerCfg) == "table" and db.timerCfg or {}
  db.timerCfg = nil
  local c = self:Cfg()
  c.custom = type(old.custom) == "table" and old.custom or {}
  for key, a in pairs(type(old.auras) == "table" and old.auras or {}) do
    if type(a) == "table" then c.auras[key] = {} else c.auras[key] = a end
  end
  if self.enabled then self:Collect() end -- back in the lists' own order
  for _, g in ipairs(T.GROUPS) do
    S.ClearSpot(T.SpotKeys(g.key))
    self:Place(g.key)
  end
  self:Refresh()
end

-- A look at what they do: every one pulses, and missing buffs flash for a few seconds.
function T:Test()
  if not self.enabled then
    FUI:Print("Timers are off. /volt timers on, then /reload.")
    return
  end
  local n = 0
  for _, it in ipairs(self.items) do
    if it.w and it.w:IsShown() then
      n = n + 1
      it.w.pulse = Now() + (n - 1) * 0.08
      self.anims[it.w] = true
    end
  end
  if #self:Mine() == 0 then
    FUI:Print("Timers: none yet. Add one on the Timers page (/volt timers).")
    return
  end
  FUI:Print("Timers: %d of your %d showing. Moving frames (/volt edit) shows them all.", n, #self:Mine())
end

function T:Slash(arg)
  arg = arg or ""
  if arg == "test" then
    self:Test()
  elseif arg == "reset" then
    self:Reset()
    FUI:Print("Timers: settings and spots back to the defaults. Your list of timers stays.")
  elseif arg == "all" then
    FUI:Print("Timers: %d added, everything found for your class.", self:AddAll())
  elseif arg:find("^add%s") then
    -- /volt timers add cooldown|buff|proc|target <spell name or id>
    local WORDS = { cooldown = "cd", cd = "cd", buff = "keep", keep = "keep", proc = "proc", target = "dot", debuff = "dot", dot = "dot" }
    local word, rest = arg:match("^add%s+(%S+)%s*(.*)$")
    local kind = WORDS[word or ""]
    if not kind then
      FUI:Print("/volt timers add cooldown|buff|proc|target <spell name or ID>")
    else
      local ok, said = self:AddCustom(kind, rest)
      FUI:Print(ok and ("Timers: %s added. Remove it on the Timers page."):format(said) or ("Timers: " .. said))
    end
  else
    FUI:OpenSettings("timers")
  end
end

FUI:Register(T)
