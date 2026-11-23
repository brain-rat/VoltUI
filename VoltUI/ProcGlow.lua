-- VoltUI · Proc glow on the action bars
-- A button lights up while a proc makes its spell instant, free or usable: Maelstrom Weapon
-- at five stacks on Lightning Bolt, Shadow Trance on Shadow Bolt, Overpower after a dodge.
--
-- Two things can light a button:
--   The game's own glow. The client has it (ActionButtonSpellAlertManager, fired by
--     SPELL_ACTIVATION_OVERLAY_GLOW_SHOW), and it works on VoltUI's bars because they are the
--     game's buttons. Which procs the server sends it for on Forever is unknown, so VoltUI
--     doesn't count on it.
--   VoltUI's list below (G.PROCS), by class. Each entry names the buff, the spells it changes,
--     and what it does to them. A fight hides your buffs' names and stacks from add-ons, so
--     the buff is only read where it can be. What the spell itself says stays readable
--     (C_Spell.GetSpellInfo's cast time, GetSpellPowerCost, IsSpellUsable: none are secret
--     in the game's API documentation), so in a fight VoltUI asks the spell: a Lightning Bolt
--     with no cast time is a Lightning Bolt with five Maelstrom Weapon stacks.
--
-- The glow is VoltUI's square one, pulsing or still, or the game's own art. On the game's
-- buttons VoltUI writes no field and calls none of the game's functions: it only reads what
-- the game set, and sets the alpha and size of the game's glow frame.

local _, ns = ...
local FUI, S = ns.FUI, ns.Style
local B = ns.ActionBars
local Safe, IsSecret = S.Safe, S.IsSecret
local sin, pi, max = math.sin, math.pi, math.max

local G = { lit = {}, base = {}, paid = {}, auras = {}, memo = {} }
B.Glow = G

G.COLOR = { 1, 0.8, 0.3 }
G.PING_TIME = 0.45 -- the flash when a button lights up
G.TICK = 0.25      -- how often watched spells are asked again, between events
G.TEST_TIME = 3

G.STYLES = {
  { key = "pulse", name = "Square, pulsing" },
  { key = "still", name = "Square, still" },
  { key = "game", name = "The game's" },
}

-- What each class's procs do, from Forever's talent and spell text (foreverdb.net's class
-- pages, read 2026-11-18). Spells and buffs by name, so every rank counts.
--   aura     the buff's name (or a list of names it goes by)
--   stacks   how many stacks it takes (1 if not given)
--   spells   the spells it changes
--   instant  the spells have no cast time while it's up: asked of the spell in a fight
--   free     the spells cost nothing while it's up: asked of the spell in a fight
--   react    no buff: the spell lights up while it can be used and isn't cooling down
-- An entry with neither instant, free nor react only shows when the buff can be read,
-- which a fight can stop.
G.PROCS = {
  SHAMAN = {
    -- Forever's talent: each stack takes 20% off Lightning Bolt's cast time and mana, up to 5.
    { aura = "Maelstrom Weapon", stacks = 5, spells = { "Lightning Bolt" }, instant = true, free = true },
    { aura = "Nature's Swiftness", spells = { "Lightning Bolt", "Chain Lightning", "Healing Wave", "Lesser Healing Wave", "Chain Heal" }, instant = true },
    { aura = "Clearcasting", spells = { "Lightning Bolt", "Chain Lightning" }, free = true }, -- Elemental Focus
  },
  MAGE = {
    { aura = "Presence of Mind", spells = { "Pyroblast", "Fireball", "Frostbolt", "Frostfire Bolt", "Arcane Blast" }, instant = true },
    { aura = "Missile Barrage", spells = { "Arcane Missiles" }, free = true },
    { aura = "Heating Up", stacks = 3, spells = { "Pyroblast" } },
    { aura = "Fingers of Frost", spells = { "Ice Lance" } },
  },
  WARLOCK = {
    { aura = "Shadow Trance", spells = { "Shadow Bolt" }, instant = true }, -- Nightfall
    { aura = "Decimation", spells = { "Soul Fire" } },
  },
  DRUID = {
    { aura = "Nature's Swiftness", spells = { "Healing Touch", "Regrowth", "Wrath", "Rebirth" }, instant = true },
    { aura = "Eclipse", spells = { "Starfire" } },
  },
  PALADIN = {
    { aura = "Infusion of Light", spells = { "Holy Light" } },
    { aura = "Divine Favor", spells = { "Flash of Light", "Holy Light", "Holy Shock" } },
    { react = true, spells = { "Hammer of Wrath" } },
  },
  PRIEST = {
    { aura = "Searing Light", spells = { "Holy Nova" }, free = true },
  },
  ROGUE = {
    { aura = "Cold Blood", spells = { "Sinister Strike", "Backstab", "Ambush", "Eviscerate", "Mutilate" } },
    { aura = { "Remorseless", "Remorseless Attacks" }, spells = { "Sinister Strike", "Backstab", "Ambush", "Mutilate", "Ghostly Strike" } },
    { react = true, spells = { "Riposte" } },
  },
  WARRIOR = {
    { react = true, spells = { "Overpower", "Revenge", "Execute" } },
  },
  HUNTER = {
    { react = true, spells = { "Counterattack", "Mongoose Bite" } },
  },
}

local function Ask(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, a, b, c, d = pcall(fn, ...)
  if ok then return a, b, c, d end
end

local function Now() return GetTime and GetTime() or 0 end

function G:On() return ns.db.barProcs ~= false end
function G:Style()
  local s = ns.db.barProcStyle
  for _, st in ipairs(G.STYLES) do
    if st.key == s then return s end
  end
  return "pulse"
end

------------------------------------------------------------------------
-- The list, for your class
------------------------------------------------------------------------

-- spell name -> the entries that change it. Your class doesn't change, so this is built once.
function G:Rules()
  if self.byName then return self.byName end
  local _, class = Ask(UnitClass, "player")
  class = Safe(class)
  if not class then return {} end -- not readable yet: ask again next time
  local byName, withAura = {}, {}
  for _, rule in ipairs(G.PROCS[class] or {}) do
    if rule.aura then
      rule.auraNames = type(rule.aura) == "table" and rule.aura or { rule.aura }
      withAura[#withAura + 1] = rule
    end
    for _, name in ipairs(rule.spells) do
      local list = byName[name]
      if not list then list = {}; byName[name] = list end
      list[#list + 1] = rule
    end
  end
  self.byName, self.withAura = byName, withAura
  return byName
end

------------------------------------------------------------------------
-- Reading the game
------------------------------------------------------------------------

-- The spell on a button, as the game's own glow finds it: a spell, or a macro showing one.
function G:SpellOf(b)
  local action = b.GetAttribute and b:GetAttribute("action")
  if not action or not (HasAction and Ask(HasAction, action)) then return nil end
  local kind, id = Ask(GetActionInfo, action)
  kind, id = Safe(kind), Safe(id)
  if (kind == "spell" or kind == "macro") and type(id) == "number" and id > 0 then return id end
end

function G:Name(id)
  local CS = C_Spell
  local name = CS and Ask(CS.GetSpellName, id)
  if name == nil and GetSpellInfo then name = Ask(GetSpellInfo, id) end
  name = Safe(name)
  return type(name) == "string" and name or nil
end

-- No cast time now, and one before: something made it instant. The cast time it had is
-- learned as it's seen, so a spell that's always instant never lights.
function G:Instant(id)
  local CS = C_Spell
  local ct
  local info = CS and Ask(CS.GetSpellInfo, id)
  if type(info) == "table" and not IsSecret(info) then
    ct = Safe(info.castTime)
  elseif GetSpellInfo and not (CS and CS.GetSpellInfo) then
    ct = Safe(select(4, Ask(GetSpellInfo, id)))
  end
  if type(ct) ~= "number" then return false end
  if ct > 0 then
    self.base[id] = ct
    return false
  end
  return self.base[id] ~= nil
end

-- Costs nothing now, and cost something before.
function G:Free(id)
  local CS = C_Spell
  local costs = Ask(CS and CS.GetSpellPowerCost or GetSpellPowerCost, id)
  if type(costs) ~= "table" or IsSecret(costs) then return false end
  local ok, total = pcall(function()
    local sum = 0
    for _, c in ipairs(costs) do
      local n = type(c) == "table" and Safe(c.cost)
      if type(n) ~= "number" then return nil end
      sum = sum + n
    end
    return sum
  end)
  if not ok or type(total) ~= "number" then return false end
  if total > 0 then
    self.paid[id] = true
    return false
  end
  return self.paid[id] == true
end

-- Usable and not cooling down (the global cooldown doesn't count). Timers reads cooldowns
-- the secret-safe way already.
function G:Ready(id)
  local T = ns.Timers
  if not (T and T.ReadCooldown) then return false end
  local ok, onCD, _, usable = pcall(T.ReadCooldown, T, { spell = id })
  return ok and usable == true and not onCD
end

-- Whether an aura the game named before is still on you, for when it won't say more.
local function StillThere(aid)
  local UA = C_UnitAuras
  if not (aid and UA and UA.GetAuraDataByAuraInstanceID) then return false end
  local ok, a = pcall(UA.GetAuraDataByAuraInstanceID, "player", aid)
  return ok and S.Present(a)
end

-- Each listed buff: up or not, at enough stacks. In a fight the names can be hidden; then a
-- buff seen before stays as it was while the game still has it, and anything new waits for
-- the spell checks or the end of the fight.
function G:ReadAuras()
  local rules = self.withAura
  if not rules or #rules == 0 then return end
  local T = ns.Timers
  local found, complete = {}, false
  if T and T.Scan then found, complete = T.Scan("player", "HELPFUL") end
  local UA = C_UnitAuras
  for _, rule in ipairs(rules) do
    local st = self.auras[rule]
    if not st then st = {}; self.auras[rule] = st end
    local a
    for _, n in ipairs(rule.auraNames) do
      a = found[n]
      if a then break end
    end
    if not a and not complete and UA and UA.GetAuraDataBySpellName then
      for _, n in ipairs(rule.auraNames) do
        local got = Ask(UA.GetAuraDataBySpellName, "player", n, "HELPFUL")
        if type(got) == "table" then a = got break end
      end
    end
    local on
    if a then
      local need = rule.stacks or 1
      local n = Safe(a.applications)
      if need <= 1 then
        on = true
      elseif type(n) == "number" then
        on = max(n, 1) >= need
      else
        on = st.on -- stacks hidden: as it was
      end
      st.aid = Safe(a.auraInstanceID)
    elseif complete then
      on, st.aid = false, nil
    else
      on = st.on and StillThere(st.aid)
      if not on then st.aid = nil end
    end
    st.on = on and true or false
  end
end

-- The spell checks for one spell, asked once per look.
function G:Check(id, kind)
  local key = kind .. id
  local v = self.memo[key]
  if v == nil then
    if kind == "i" then v = self:Instant(id)
    elseif kind == "f" then v = self:Free(id)
    else v = self:Ready(id) end
    self.memo[key] = v
  end
  return v
end

function G:RuleOn(id, rules)
  for _, rule in ipairs(rules) do
    local st = rule.aura and self.auras[rule]
    if st and st.on then return true end
    if rule.instant and self:Check(id, "i") then return true end
    if rule.free and self:Check(id, "f") then return true end
    if rule.react and self:Check(id, "r") then return true end
  end
  return false
end

-- The game's own glow on this button.
function G:GameAlert(b)
  local m = _G.ActionButtonSpellAlertManager
  if m and m.HasAlert then return Ask(m.HasAlert, m, b) == true end
  local alert = b.SpellActivationAlert
  return type(alert) == "table" and alert.IsShown and alert:IsShown() and true or false
end

------------------------------------------------------------------------
-- Drawing
------------------------------------------------------------------------

local function Size(b)
  return (b.owner and b.owner.cfg and b.owner.cfg.size) or 36
end

-- VoltUI's square glow: a bright line inside the edge, a soft band outside it, and a flash
-- over the icon as it lights. Above the cooldown swipe, under the key and count text.
function G:Frame(b)
  local g = b.kGlow
  if g then return g end
  g = CreateFrame("Frame", nil, b)
  g:SetAllPoints(b)
  g:SetFrameLevel(b:GetFrameLevel() + 3)
  local c = G.COLOR
  g.inner = S.Edges(g, "OVERLAY", 7)
  S.EdgeWidth(g.inner, 2)
  g.outer = S.Edges(g, "OVERLAY", 6, g, 3)
  S.EdgeWidth(g.outer, 3)
  for i = 1, 4 do
    g.inner[i]:SetColorTexture(c[1], c[2], c[3], 1)
    g.outer[i]:SetColorTexture(c[1], c[2], c[3], 0.45)
  end
  g.wash = S.Tex(g, "OVERLAY", 5)
  g.wash:SetAllPoints(g)
  g.wash:SetColorTexture(c[1], c[2], c[3], 1)
  if g.wash.SetBlendMode then g.wash:SetBlendMode("ADD") end
  g.wash:SetAlpha(0)
  g:Hide()
  b.kGlow = g
  return g
end

-- The game's glow art, made by VoltUI for the procs on VoltUI's list, for the "The game's" style.
-- Nil where the client's template can't be made: then the square glow stands in.
function G:GameCopy(b)
  if b.kGameGlow ~= nil then return b.kGameGlow or nil end
  local ok, f = pcall(CreateFrame, "Frame", nil, b, "ActionButtonSpellAlertTemplate")
  if not (ok and f and f.ProcStartAnim and f.ProcLoop) then
    b.kGameGlow = false
    return nil
  end
  f:SetPoint("CENTER", b, "CENTER", 0, 0)
  f:Hide()
  b.kGameGlow = f
  return f
end

-- The game's alert art scaled to the button. The game sizes it once, from the button's size
-- when it's made, for its own 45-pixel buttons.
local function FitAlert(f, size)
  f:SetSize(size * 1.4, size * 1.4)
  if f.ProcStartFlipbook then f.ProcStartFlipbook:SetSize(size * 150 / 45, size * 150 / 45) end
end

-- The game's own glow frame on a button: seen only with the game's style.
function G:GameArt(b)
  local alert = b.SpellActivationAlert
  if type(alert) ~= "table" or not alert.SetAlpha then return end
  if self:On() and self:Style() == "game" then
    alert:SetAlpha(1)
    FitAlert(alert, Size(b))
  else
    alert:SetAlpha(0)
  end
end

function G:Light(b, lit, style, gameShowing)
  local copy = style == "game" and self:GameCopy(b) or nil
  local square = lit and not copy
  local g = (square or b.kGlow) and self:Frame(b)
  if g then
    if square and not g:IsShown() then
      g.ping = Now()
      g:Show()
    elseif not square and g:IsShown() then
      g:Hide()
      g.ping = nil
    end
  end
  if copy then
    local want = lit and not gameShowing
    if want and not copy:IsShown() then
      FitAlert(copy, Size(b))
      copy:Show()
      copy.ProcStartAnim:Play()
    elseif not want and copy:IsShown() then
      copy.ProcStartAnim:Stop()
      copy.ProcLoop:Stop()
      copy:Hide()
    end
  elseif b.kGameGlow and b.kGameGlow:IsShown() then
    b.kGameGlow:Hide()
  end
  self.lit[b] = square or nil
end

function G:Animate(now)
  local pulse = self:Style() == "pulse"
  local wave = 0.5 + 0.5 * sin(now * 2 * pi * 1.2)
  for b in pairs(self.lit) do
    local g = b.kGlow
    if g then
      local p = g.ping and (now - g.ping) / G.PING_TIME
      if p and p < 1 then
        g.wash:SetAlpha(0.6 * (1 - p))
      else
        g.ping = nil
        g.wash:SetAlpha(0)
      end
      if pulse then
        for i = 1, 4 do
          g.inner[i]:SetAlpha(0.65 + 0.35 * wave)
          g.outer[i]:SetAlpha(0.25 + 0.75 * wave)
        end
      else
        for i = 1, 4 do
          g.inner[i]:SetAlpha(1)
          g.outer[i]:SetAlpha(1)
        end
      end
    end
  end
end

------------------------------------------------------------------------
-- Looking
------------------------------------------------------------------------

function G:Update()
  if not B.started then return end
  wipe(self.memo)
  local on, style = self:On(), self:Style()
  local rules = self:Rules()
  local testing = self.testUntil ~= nil
  if on and not testing then self:ReadAuras() end
  local watching = false
  for _, b in ipairs(B.buttons) do
    local lit, gameShowing = false, false
    if on then
      gameShowing = self:GameAlert(b)
      local id = self:SpellOf(b)
      if testing then
        lit = id ~= nil
      else
        if gameShowing and style ~= "game" then lit = true end
        local name = id and self:Name(id)
        local list = name and rules[name]
        if list then
          watching = true
          if not lit then lit = self:RuleOn(id, list) end
        end
      end
    end
    self:Light(b, lit, style, gameShowing)
    self:GameArt(b)
  end
  self.watching = watching
end

function G:OnUpdate(elapsed)
  local now = Now()
  self.since = (self.since or 0) + (elapsed or 0)
  if self.testUntil and now >= self.testUntil then
    self.testUntil = nil
    self.dirty = true
  end
  if self.dirty or (self.watching and self.since >= G.TICK) then
    self.dirty, self.since = false, 0
    self:Update()
  end
  if next(self.lit) then self:Animate(now) end
end

-- Every button with something on it lights for a few seconds, to see the style.
function G:Test()
  if not B.started then return FUI:Print("VoltUI's action bars aren't on.") end
  if not self:On() then return FUI:Print("the proc glow is off: switch on Glow when a spell procs first.") end
  for _, b in ipairs(B.buttons) do self:Light(b, false, self:Style(), false) end -- each lights afresh
  self.testUntil = Now() + G.TEST_TIME
  self:Update()
end

-- After a setting changes.
function G:Refresh()
  if not self.ev then return end
  self.dirty = true
  self:Update()
end

local EVENTS = {
  "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "PLAYER_TARGET_CHANGED",
  "SPELLS_CHANGED", "SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_USABLE", "ACTIONBAR_UPDATE_USABLE",
  "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUSACTIONBAR", "UPDATE_MACROS",
  "UPDATE_SHAPESHIFT_FORM", "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE",
}

function G:Start()
  if self.ev then return end
  local ev = CreateFrame("Frame")
  self.ev = ev
  for _, e in ipairs(EVENTS) do pcall(ev.RegisterEvent, ev, e) end
  if ev.RegisterUnitEvent then
    pcall(ev.RegisterUnitEvent, ev, "UNIT_AURA", "player")
  else
    pcall(ev.RegisterEvent, ev, "UNIT_AURA")
  end
  ev:SetScript("OnEvent", function(_, event, unit)
    if event == "UNIT_AURA" and unit ~= "player" then return end
    G.dirty = true
  end)
  ev:SetScript("OnUpdate", function(_, elapsed) G:OnUpdate(elapsed) end)

  -- The game's glow: VoltUI's square one takes its place, or it's fitted to the button. Only
  -- after the game's own code has run, and only alpha and size on its glow frame.
  local m = _G.ActionButtonSpellAlertManager
  if m and m.ShowAlert then
    hooksecurefunc(m, "ShowAlert", function(_, b)
      if B.mine[b] then
        G:GameArt(b)
        G.dirty = true
      end
    end)
    if m.HideAlert then
      hooksecurefunc(m, "HideAlert", function(_, b)
        if B.mine[b] then G.dirty = true end
      end)
    end
  elseif type(_G.ActionButton_ShowOverlayGlow) == "function" then
    hooksecurefunc("ActionButton_ShowOverlayGlow", function(b)
      if B.mine[b] then
        G:GameArt(b)
        G.dirty = true
      end
    end)
    if type(_G.ActionButton_HideOverlayGlow) == "function" then
      hooksecurefunc("ActionButton_HideOverlayGlow", function(b)
        if B.mine[b] then G.dirty = true end
      end)
    end
  end
  -- Made now, out of combat, rather than at the first proc.
  for _, b in ipairs(B.buttons) do self:Frame(b) end
  self.dirty = true
  self:Update()
end
