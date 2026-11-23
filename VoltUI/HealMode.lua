-- VoltUI · Heal mode and click-casting for the party and raid frames
-- Heal mode swaps the frames (Raid.lua) to their heal mode sets, one for party frames and
-- one for raid frames (raidCfg.healParty and healRaid), made for healing:
-- bigger tiles, missing health, everyone's power, bigger debuffs you can remove. It's
-- switched by hand (the settings, the minimap menu, /volt heal), or comes on by itself while
-- your group role is healer ("Auto", the default).
--
-- Click-casting: any of 35 clicks (five mouse buttons, alone or with Shift, Ctrl, Alt or two
-- of them) on a member casts a spell (by name, so a new rank is used as soon as it's
-- learned; or typed with a rank, "Heal(Rank 2)"), targets them, opens their menu, sets
-- focus, or runs a macro. Priests, paladins, druids and shamans start with ready-made
-- clicks. They work in heal mode, or always.
--
-- Clicks are attributes on the secure member buttons, so they're only changed out of combat
-- (a change waits for the fight to end). The headers also hold them as _initialAttribute-*,
-- which the game copies onto anyone who joins mid-fight.

local _, ns = ...
local FUI, S = ns.FUI, ns.Style
local R = ns.Raid

local Safe = S.Safe
local Copy = R.Copy

-- Where heal mode's settings differ from the normal set's.
R.HEAL_DEFAULTS = {
  width = 84, height = 42, hpText = "missing", power = "all", rangeAlpha = 0.4,
  debuffSize = 16, debuffCount = 4, removableFirst = true, bigRemovable = true,
  hotSize = 14, hotCount = 4,
}

R.HEAL_MODES = { { key = "off", name = "Off" }, { key = "auto", name = "Auto" }, { key = "on", name = "On" } }
R.CLICKS_WHEN = { { key = "heal", name = "In heal mode" }, { key = "always", name = "Always" } }

R.BUTTONS = {
  { key = "1", name = "Left" }, { key = "2", name = "Right" }, { key = "3", name = "Middle" },
  { key = "4", name = "Button 4" }, { key = "5", name = "Button 5" },
}
-- Modifiers in the order the game reads them (alt-, ctrl-, shift-).
R.MODS = {
  { key = "", name = "None" }, { key = "shift-", name = "Shift" }, { key = "ctrl-", name = "Ctrl" },
  { key = "alt-", name = "Alt" }, { key = "ctrl-shift-", name = "Ctrl+Shift" }, { key = "alt-shift-", name = "Alt+Shift" },
  { key = "alt-ctrl-", name = "Ctrl+Alt" },
}
R.ACTIONS = {
  { key = "none", name = "Nothing" }, { key = "spell", name = "Spell" }, { key = "target", name = "Target" },
  { key = "menu", name = "Menu" }, { key = "focus", name = "Focus" }, { key = "macro", name = "Macro" },
}

-- Ready-made clicks: spell IDs, the first one you know (or the first) is used, by name.
local EVERYONE = { ["shift-1"] = { kind = "target" }, ["shift-2"] = { kind = "menu" } }
R.CLASS_CLICKS = {
  PRIEST = {
    ["1"] = { 2061 }, ["2"] = { 139 }, ["ctrl-1"] = { 17 }, ["ctrl-2"] = { 2060 },
    ["3"] = { 527 }, ["shift-3"] = { 552, 528 }, ["alt-1"] = { 2006 },
  },
  PALADIN = {
    ["1"] = { 19750 }, ["2"] = { 635 }, ["ctrl-1"] = { 1022 }, ["ctrl-2"] = { 633 },
    ["3"] = { 4987, 1152 }, ["shift-3"] = { 1152 }, ["alt-1"] = { 7328 },
  },
  DRUID = {
    ["1"] = { 774 }, ["2"] = { 5185 }, ["ctrl-1"] = { 8936 }, ["ctrl-2"] = { 18562 },
    ["3"] = { 2782 }, ["shift-3"] = { 2893, 8946 }, ["alt-1"] = { 20484 },
  },
  SHAMAN = {
    ["1"] = { 8004 }, ["2"] = { 331 }, ["ctrl-1"] = { 1064 },
    ["3"] = { 526 }, ["shift-3"] = { 2870 }, ["alt-1"] = { 2008 },
  },
}

-- Spells offered in the picker (ones you know are shown), besides anything typed.
R.CLASS_SPELLS = {
  PRIEST = { 2050, 2054, 2060, 2061, 139, 17, 596, 527, 528, 552, 2006, 1243, 6346, 10060 },
  PALADIN = { 635, 19750, 20473, 4987, 1152, 1022, 633, 1044, 6940, 7328, 19740, 19742 },
  DRUID = { 5185, 774, 8936, 18562, 2782, 2893, 8946, 20484, 1126, 29166 },
  SHAMAN = { 331, 8004, 1064, 526, 2870, 2008, 974, 131, 546 },
  MAGE = { 475, 1459 },
}

local function PlayerClass()
  local _, class = UnitClass("player")
  return Safe(class) or ""
end
R.PlayerClass = PlayerClass

local function SpellName(id)
  if type(id) ~= "number" then return end
  if C_Spell and C_Spell.GetSpellName then
    local ok, name = pcall(C_Spell.GetSpellName, id)
    if ok and type(name) == "string" and name ~= "" then return name end
  end
  if GetSpellInfo then
    local ok, name = pcall(GetSpellInfo, id)
    if ok and type(name) == "string" and name ~= "" then return name end
  end
end
R.SpellName = SpellName

local function Known(id) return IsPlayerSpell ~= nil and IsPlayerSpell(id) == true end

------------------------------------------------------------------------
-- Settings
------------------------------------------------------------------------

function R:FillExtra(c)
  R.SplitSet(c, "heal", "healParty", "healRaid") -- one heal mode set up to 1.27
  for _, name in ipairs({ "healParty", "healRaid" }) do
    if type(c[name]) ~= "table" then c[name] = {} end
    R.Fill(c[name], self.HEAL_DEFAULTS)
    R.Fill(c[name], self.SET_DEFAULTS)
  end
  if c.healEdit ~= "raid" then c.healEdit = "party" end -- which one the Heal mode page shows
  if c.healMode ~= "on" and c.healMode ~= "off" then c.healMode = "auto" end
  if c.clicksWhen ~= "always" then c.clicksWhen = "heal" end
  if type(c.clicks) ~= "table" then c.clicks = {} end
end

function R:ResetHeal()
  local c = self:Cfg()
  c.healParty, c.healRaid = {}, {}
  c.healMode, c.clicksWhen = nil, nil
  self.cfg = nil
  self:Cfg()
  self:CheckHeal(true)
  self:ApplyClicks()
  self:Apply()
end

------------------------------------------------------------------------
-- Heal mode
------------------------------------------------------------------------

-- Should heal mode be on, by its setting and your role?
function R:WantHeal()
  local c = self:Cfg()
  if c.healMode == "on" then return true end
  if c.healMode == "off" then return false end
  return UnitGroupRolesAssigned ~= nil and Safe(UnitGroupRolesAssigned("player")) == "HEALER"
end

function R:HealOn() return self.activeHeal == true end

-- Switches to the set heal mode asks for. In combat the switch waits for the fight to end,
-- so the frames never change size halfway through one.
function R:CheckHeal(quiet)
  if not self.enabled then return end
  local want = self:WantHeal()
  if want == (self.activeHeal == true) then
    self.healPending = nil
    return
  end
  if InCombatLockdown() then
    self.healPending = true
    return
  end
  self.healPending = nil
  self.activeHeal = want
  self:ApplyClicks()
  self:Apply()
  if not quiet then
    FUI:Print("Heal mode %s.", want and "|cff7fff7fon|r" or "|cffff7f7foff|r")
  end
end

-- The settings, the minimap menu and /volt heal: on if it's off, off if it's on.
function R:ToggleHeal()
  local c = self:Cfg()
  c.healMode = self.activeHeal and "off" or "on"
  self:CheckHeal()
  if self.healPending then FUI:Print("Heal mode changes when you're out of combat.") end
  if ns.EditMode and ns.EditMode.RefreshPage then pcall(ns.EditMode.RefreshPage, ns.EditMode) end
end

------------------------------------------------------------------------
-- Click-casting
------------------------------------------------------------------------

-- Your class's ready-made clicks.
function R:DefaultClicks(class)
  local out = {}
  for combo, b in pairs(EVERYONE) do out[combo] = Copy(b) end
  for combo, ids in pairs(self.CLASS_CLICKS[class or PlayerClass()] or {}) do
    local pick = ids[1]
    for _, id in ipairs(ids) do
      if Known(id) then
        pick = id
        break
      end
    end
    out[combo] = { kind = "spell", spell = pick }
  end
  return out
end

-- Your clicks: what you've set, or the ready-made ones until you change one.
function R:Bindings()
  local saved = self:Cfg().clicks[PlayerClass()]
  if type(saved) == "table" then return saved end
  return self:DefaultClicks()
end

function R:GetBinding(combo)
  return self:Bindings()[combo]
end

function R:SetBinding(combo, b)
  local c = self:Cfg()
  local class = PlayerClass()
  if type(c.clicks[class]) ~= "table" then c.clicks[class] = self:DefaultClicks() end
  c.clicks[class][combo] = b
  self:ApplyClicks()
end

function R:UseDefaultClicks()
  self:Cfg().clicks[PlayerClass()] = nil
  self:ApplyClicks()
end

-- The spell a binding casts, by name.
function R:SpellOf(b)
  if type(b) ~= "table" then return end
  if type(b.value) == "string" and b.value ~= "" then return b.value end
  return SpellName(b.spell)
end

-- What a binding does, in words.
function R:Describe(b)
  if type(b) ~= "table" or b.kind == "none" then return "Nothing" end
  if b.kind == "spell" then return self:SpellOf(b) or "A spell (none picked)" end
  if b.kind == "macro" then
    local first = type(b.value) == "string" and b.value:match("^[^\n]*") or ""
    return "Macro: " .. (first ~= "" and first or "(empty)")
  end
  for _, a in ipairs(self.ACTIONS) do
    if a.key == b.kind then return a.name end
  end
  return "Nothing"
end

-- "Ctrl+Left" for "ctrl-1".
function R:ComboName(combo)
  local mod, btn = tostring(combo):match("^(.-)(%d+)$")
  local mname, bname = "", btn or "?"
  for _, m in ipairs(self.MODS) do if m.key == mod and m.key ~= "" then mname = m.name .. "+" end end
  for _, b in ipairs(self.BUTTONS) do if b.key == btn then bname = b.name end end
  return mname .. bname
end

-- The attributes your clicks put on a member button.
function R:ClickAttrs()
  local out = {}
  local c = self:Cfg()
  if c.clicksWhen ~= "always" and not self.activeHeal then return out end
  for combo, b in pairs(self:Bindings()) do
    local mod, btn = tostring(combo):match("^(.-)(%d+)$")
    if btn and type(b) == "table" then
      local typeKey = mod .. "type" .. btn
      if b.kind == "spell" then
        local name = self:SpellOf(b)
        if name then
          out[typeKey] = "spell"
          out[mod .. "spell" .. btn] = name
        end
      elseif b.kind == "target" then
        -- The game only lets a unit button target on a click its own click bindings give an
        -- interaction to (plain left-click by default), so a modified click targets by macro.
        if mod == "" then
          out[typeKey] = "target"
        else
          out[typeKey] = "macro"
          out[mod .. "macrotext" .. btn] = "/target [@mouseover]"
        end
      elseif b.kind == "menu" then
        out[typeKey] = "togglemenu"
      elseif b.kind == "focus" then
        out[typeKey] = "focus"
      elseif b.kind == "macro" and type(b.value) == "string" and b.value ~= "" then
        out[typeKey] = "macro"
        out[mod .. "macrotext" .. btn] = b.value
      elseif b.kind == "none" then
        out[typeKey] = "" -- nothing, not even the default target or menu
      end
    end
  end
  return out
end

-- Puts your clicks on every member button and on the headers (for anyone who joins later).
function R:ApplyClicks()
  if not self.enabled or not self.headers[1] then return end
  if InCombatLockdown() then
    self.clicksPending = true
    return
  end
  self.clicksPending = nil
  local attrs = self:ClickAttrs()
  local old = self.clickAttrs or {}
  local names = {}
  for k in pairs(attrs) do names[#names + 1] = k end
  table.sort(names)
  for _, hd in ipairs(self.headers) do
    hd:SetAttribute("_ignore", "volt")
    for k in pairs(old) do
      if attrs[k] == nil then hd:SetAttribute("_initialAttribute-" .. k, nil) end
    end
    for k, v in pairs(attrs) do hd:SetAttribute("_initialAttribute-" .. k, v) end
    hd:SetAttribute("_initialAttributeNames", #names > 0 and table.concat(names, ",") or nil)
    hd:SetAttribute("_ignore", nil)
  end
  for f in pairs(self.tiles) do
    for k in pairs(old) do
      if attrs[k] == nil then f:SetAttribute(k, nil) end
    end
    for k, v in pairs(attrs) do f:SetAttribute(k, v) end
  end
  self.clickAttrs = attrs
end

-- A member button made out of combat gets the clicks straight away (the header copies
-- them too; this covers buttons made before a change).
function R:OnTile(f)
  if InCombatLockdown() or not self.clickAttrs then return end
  for k, v in pairs(self.clickAttrs) do f:SetAttribute(k, v) end
end

-- The game's own click casting wins over VoltUI's on the same click. How many it has, if any.
function R:GameClickBindings()
  local CB = C_ClickBindings
  if not (CB and CB.GetProfileInfo) then return 0 end
  local ok, list = pcall(CB.GetProfileInfo)
  if ok and type(list) == "table" then return #list end
  return 0
end

-- The game's own binding on the same click as `combo` ("shift-1", "4", ...), if it has one:
-- what it does, in words. It wins over VoltUI's, so the Clicks page marks that slot (since 1.46.0).
local GAME_BUTTONS = { LeftButton = "1", RightButton = "2", MiddleButton = "3", Button4 = "4", Button5 = "5" }
local function ModSet(text)
  text = tostring(text or ""):upper()
  return (text:find("ALT") and "a" or "") .. (text:find("CTRL") and "c" or "") .. (text:find("SHIFT") and "s" or "")
end
function R:GameClickFor(combo)
  local CB = C_ClickBindings
  if not (CB and CB.GetProfileInfo) then return nil end
  local ok, list = pcall(CB.GetProfileInfo)
  if not ok or type(list) ~= "table" then return nil end
  combo = tostring(combo or "")
  local button = combo:match("(%d)$")
  local mods = ModSet(combo)
  -- The game's own function for a binding's modifier keys is a plain global.
  local toText = _G.GetStringFromModifiers or CB.GetStringFromModifiers
  local kinds = Enum and Enum.ClickBindingType or {}
  for _, e in ipairs(list) do
    -- The game's defaults (left: target, right: menu) are in the list too, as "interactions".
    -- Those are what a click does anyway, so they aren't a clash.
    if type(e) == "table" and GAME_BUTTONS[e.button or ""] == button and e.type ~= kinds.Interaction and e.type ~= kinds.None then
      local theirs
      if toText then
        local okM, text = pcall(toText, e.modifiers or 0)
        theirs = okM and ModSet(text) or nil
      elseif (tonumber(e.modifiers) or 0) == 0 then
        theirs = ""
      end
      if theirs == mods then
        local name
        if e.actionID then
          local okN, n = pcall(function()
            if e.type == kinds.Macro then return GetMacroInfo and (GetMacroInfo(e.actionID)) end
            if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(e.actionID) end
            return GetSpellInfo and (GetSpellInfo(e.actionID))
          end)
          if okN and type(n) == "string" then name = n end
        end
        return name or "a click binding"
      end
    end
  end
  return nil
end

-- A ready mouseover macro with your first click's spell.
function R:MacroExample()
  local b = self:GetBinding("1")
  local name = (b and b.kind == "spell" and self:SpellOf(b)) or SpellName((self.CLASS_SPELLS[PlayerClass()] or {})[1]) or "Flash Heal"
  return ("/cast [@mouseover,help,nodead][] %s"):format(name)
end

------------------------------------------------------------------------
-- Your healing spells, for the pickers
------------------------------------------------------------------------

-- The clicks the Heal mode page shows, in order.
R.QUICK_CLICKS = { "1", "2", "shift-1", "shift-2", "ctrl-1", "ctrl-2", "alt-1", "alt-2", "3", "shift-3" }

local function SpellIcon(id)
  if type(id) ~= "number" then return end
  if C_Spell and C_Spell.GetSpellTexture then
    local ok, tex = pcall(C_Spell.GetSpellTexture, id)
    if ok and tex then return tex end
  end
  if GetSpellTexture then
    local ok, tex = pcall(GetSpellTexture, id)
    if ok and tex then return tex end
  end
end
R.SpellIcon = SpellIcon

local function Ask(fn, ...)
  if type(fn) ~= "function" then return end
  local ok, v = pcall(fn, ...)
  if ok then return v end
end

-- A spell you'd cast on someone else to help them: heals, shields, cleanses, buffs,
-- resurrection. Not damage, and not a buff only you can have. VoltUI's own class lists count too,
-- so a client that can't answer still gets them.
local function HealerSpell(id, class)
  if type(id) ~= "number" then return false end
  for _, known in ipairs(R.CLASS_SPELLS[class] or {}) do
    if known == id then return true end
  end
  local CS = C_Spell
  if not (CS and CS.IsSpellHelpful) then return false end
  if Ask(CS.IsSpellHelpful, id) ~= true then return false end
  if CS.IsSelfBuff and Ask(CS.IsSelfBuff, id) == true then return false end
  if CS.SpellHasRange and Ask(CS.SpellHasRange, id) == false then return false end
  return true
end

-- The healing spells in your spellbook, in its order: { key = spellID, name, icon }. A spell
-- with ranks shows once (it's cast by name, so you get the highest). Without the spellbook
-- functions, the spells you know from VoltUI's list for your class.
function R:HealerSpells()
  local class = PlayerClass()
  local out, seen = {}, {}
  local function add(id, name, icon)
    if type(name) ~= "string" or name == "" or seen[name] then return end
    seen[name] = true
    out[#out + 1] = { key = id, name = name, icon = icon or SpellIcon(id) }
  end
  local SB = C_SpellBook
  if SB and SB.GetNumSpellBookSkillLines and SB.GetSpellBookSkillLineInfo and SB.GetSpellBookItemInfo then
    local E = Enum or {}
    local bank = E.SpellBookSpellBank and E.SpellBookSpellBank.Player or 0
    local spellType = E.SpellBookItemType and E.SpellBookItemType.Spell or 1
    local lines = Ask(SB.GetNumSpellBookSkillLines)
    for line = 1, type(lines) == "number" and lines or 0 do
      local li = Ask(SB.GetSpellBookSkillLineInfo, line)
      if type(li) == "table" and not li.isGuild and not li.shouldHide and not li.offSpecID
        and type(li.itemIndexOffset) == "number" and type(li.numSpellBookItems) == "number" then
        for slot = li.itemIndexOffset + 1, li.itemIndexOffset + li.numSpellBookItems do
          local it = Ask(SB.GetSpellBookItemInfo, slot, bank)
          if type(it) == "table" and it.itemType == spellType and not it.isPassive and not it.isOffSpec then
            local id = it.spellID or it.actionID
            if HealerSpell(id, class) then add(id, it.name, it.iconID) end
          end
        end
      end
    end
  end
  for _, id in ipairs(self.CLASS_SPELLS[class] or {}) do
    if Known(id) then add(id, SpellName(id), SpellIcon(id)) end
  end
  return out
end

-- What the click pickers offer: your healing spells, then target, menu, and clear (the
-- click goes back to what it does without VoltUI: left targets, right opens the menu).
function R:PickChoices()
  local out = {}
  for _, s in ipairs(self:HealerSpells()) do
    out[#out + 1] = { name = s.name, icon = s.icon, bind = { kind = "spell", spell = s.key } }
  end
  out[#out + 1] = { name = "Target", other = true, bind = { kind = "target" } }
  out[#out + 1] = { name = "Menu", other = true, bind = { kind = "menu" } }
  out[#out + 1] = { name = "Clear", other = true, clear = true }
  return out
end

-- The icon for a binding: its spell's, or nothing for the rest.
function R:BindingIcon(b)
  if type(b) ~= "table" or b.kind ~= "spell" then return end
  if b.spell then return SpellIcon(b.spell) end
  if type(b.value) == "string" and C_Spell and C_Spell.GetSpellTexture then
    return Ask(C_Spell.GetSpellTexture, (b.value:gsub("%(.*%)$", "")))
  end
end

-- Is this the binding a picker choice would make?
function R:SameBinding(b, choice)
  if choice.clear then return b == nil end
  if type(b) ~= "table" then return false end
  local c = choice.bind
  if b.kind ~= c.kind then return false end
  if c.kind ~= "spell" then return true end
  if type(b.value) == "string" and b.value ~= "" then return false end
  return b.spell == c.spell or (SpellName(b.spell) ~= nil and SpellName(b.spell) == SpellName(c.spell))
end

-- Spells for the stepper on the Clicks page: your healing spells, and whatever is bound.
function R:SpellChoices(current)
  local out, seen = {}, {}
  for _, s in ipairs(self:HealerSpells()) do
    if not seen[s.name] then
      seen[s.name] = true
      out[#out + 1] = { key = s.key, name = s.name }
    end
  end
  for _, id in ipairs(self.CLASS_SPELLS[PlayerClass()] or {}) do
    local name = SpellName(id)
    if name and not seen[name] and id == current then
      seen[name] = true
      out[#out + 1] = { key = id, name = name }
    end
  end
  if type(current) == "number" and not seen[SpellName(current) or ""] then
    out[#out + 1] = { key = current, name = SpellName(current) or ("Spell " .. current) }
  end
  if #out == 0 then out[1] = { key = false, name = "Type one below" } end
  return out
end

------------------------------------------------------------------------
-- Hooks from Raid.lua
------------------------------------------------------------------------

function R:EnableHeal()
  self.activeHeal = self:WantHeal()
  self:ApplyClicks()
end

function R:OnRoster()
  self:CheckHeal()
end

function R:AfterCombat()
  if self.healPending then self:CheckHeal() end
  if self.clicksPending then self:ApplyClicks() end
end

function R:HealSlash(arg)
  local c = self:Cfg()
  if arg == "on" or arg == "off" or arg == "auto" then
    c.healMode = arg
    self:CheckHeal(true)
    FUI:Print("Heal mode: %s%s%s", arg, arg == "auto" and " (on while your role is healer)" or "",
      self.healPending and ". It changes when you're out of combat." or ".")
  elseif arg == "options" or arg == "settings" then
    ns.EditMode:Open("heal")
  elseif arg == "clicks" then
    ns.EditMode:Open("clicks")
  elseif arg == "dispel" or arg == "dispels" then
    ns.EditMode:Open("dispel")
  elseif arg == "" then
    self:ToggleHeal()
  else
    FUI:Print("Heal mode is %s (set to %s). /volt heal toggles it · on · off · auto · options · clicks · dispel",
      self.activeHeal and "on" or "off", c.healMode)
  end
end
