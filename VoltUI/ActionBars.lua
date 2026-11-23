-- VoltUI · Action bars
-- Flat, square action bars in the shared style. Eight bars, plus stance, pet, the
-- Shaman's totem bar, the menu buttons, the bag buttons, and XP and reputation bars.
-- Each has its own size, layout and visibility, all changed live from the edit mode.
--
-- The buttons are the game's own, moved onto VoltUI's bars, so its secure code keeps doing
-- the work: clicks, cooldowns, usability, procs and drag and drop. VoltUI lays them out,
-- dresses them and binds your keys to them. The approach follows Dominos, which supports
-- this client. Everything secure is set up out of combat only.
--
-- They have to be the game's own. Everything on a button an add-on makes counts as that
-- add-on's, including the slot number the game reads before it uses the action. The game
-- then treats its own clicks and events as add-on code, and blocks them. On the game's
-- buttons, VoltUI must not write a field or fire a handler the game's code goes on to read:
-- only new k-prefixed fields, and attributes set with no handler.
--
-- Empty slots and faded bars use alpha rather than Hide, because alpha can change in
-- combat. A spell picked up mid-fight still shows you where it can go.
--
-- The menu, bag and totem buttons are the game's own, moved and dressed. The game keeps
-- doing their work, and redraws some of their art as it goes, so that art is put right
-- again after each redraw. The menu and bag buttons aren't secure and sit on a plain
-- frame, so the game can borrow the menu for its vehicle bar and hand it back in combat.

local _, ns = ...
local FUI, S = ns.FUI, ns.Style

local B = { key = "bars", name = "Action bars", frames = {}, list = {}, extraList = {}, mine = {}, buttons = {} }
ns.ActionBars = B

local floor, ceil, min, max = math.floor, math.ceil, math.min, math.max
local A = S.ACCENT
local FADE_TIME = 0.15

local DEFS = {
  { key = "bar1", label = "Bar 1", kind = "action", base = 0, command = "ACTIONBUTTON", paged = true },
  { key = "bar2", label = "Bar 2", kind = "action", base = 60, command = "MULTIACTIONBAR1BUTTON", blizz = "MultiBarBottomLeft" },
  { key = "bar3", label = "Bar 3", kind = "action", base = 48, command = "MULTIACTIONBAR2BUTTON", blizz = "MultiBarBottomRight" },
  { key = "bar4", label = "Bar 4", kind = "action", base = 24, command = "MULTIACTIONBAR3BUTTON", blizz = "MultiBarRight" },
  { key = "bar5", label = "Bar 5", kind = "action", base = 36, command = "MULTIACTIONBAR4BUTTON", blizz = "MultiBarLeft" },
  { key = "bar6", label = "Bar 6", kind = "action", base = 144, command = "MULTIACTIONBAR5BUTTON", blizz = "MultiBar5" },
  { key = "bar7", label = "Bar 7", kind = "action", base = 156, command = "MULTIACTIONBAR6BUTTON", blizz = "MultiBar6" },
  { key = "bar8", label = "Bar 8", kind = "action", base = 168, command = "MULTIACTIONBAR7BUTTON", blizz = "MultiBar7" },
  { key = "stance", label = "Stance bar", kind = "stance", command = "SHAPESHIFTBUTTON" },
  { key = "pet", label = "Pet bar", kind = "pet", command = "BONUSACTIONBUTTON" },
  { key = "totem", label = "Totem bar", kind = "totem" },
  { key = "menu", label = "Menu bar", kind = "menu", extra = true },
  { key = "bags", label = "Bag bar", kind = "bags", extra = true },
  { key = "xp", label = "XP bar", kind = "status", extra = true },
  { key = "rep", label = "Reputation bar", kind = "status", extra = true },
}

local LOOK = {
  on = false, count = 12, perRow = 12, size = 36, gapX = 3, gapY = 3, scale = 1,
  growX = "right", growY = "up", mode = "always", fade = "off", alpha = 1, fadeTo = 0, empty = true,
  keys = true, keySize = 11, macro = false, macroSize = 10, stack = true, stackSize = 12,
  border = true, cdText = true, cdSize = 14,
  cdMin = 2, cdTenths = 3, -- no number on a cooldown shorter than this (the global one); tenths below this (1.101.16)
  mono = true, keyring = true, reagent = true, slots = true,
  width = 400, height = 12, text = "hover", textSize = 11, rested = true,
  plate = false, plateAlpha = 0.55, platePad = 5,
}
local SIDE = { perRow = 1, growY = "down" }
local PER_BAR = {
  bar1 = { on = true },
  bar4 = SIDE, bar5 = SIDE, bar6 = SIDE, bar7 = SIDE, bar8 = SIDE,
  stance = { on = true, count = 10, perRow = 10, size = 30 },
  pet = { on = true, count = 10, perRow = 10, size = 30 },
  totem = { on = true, perRow = 6, size = 30, gapX = 4, gapY = 4 },
  menu = { on = true, perRow = 14, size = 24, gapX = 2, gapY = 2, plate = true },
  bags = { on = true, perRow = 7, size = 30, stackSize = 11, plate = true },
  xp = { on = true, width = 1192 },
  rep = { on = false }, -- off until you switch it on: above the XP bar it overlaps bar 1
}
-- What "Copy look to all" copies. Not position, or how many buttons a bar has.
local COPIED = {
  "size", "gapX", "gapY", "scale", "mode", "fade", "alpha", "fadeTo", "empty", "keys", "keySize",
  "macro", "macroSize", "stack", "stackSize", "border", "cdText", "cdSize", "cdMin", "cdTenths",
  "plate", "plateAlpha", "platePad",
}

-- point on the bar, point on the screen, x, y
local SPOTS = {
  bar1 = { "BOTTOM", "BOTTOM", 0, 20 }, bar2 = { "BOTTOM", "BOTTOM", 0, 59 }, bar3 = { "BOTTOM", "BOTTOM", 0, 98 },
  bar4 = { "RIGHT", "RIGHT", -6, 0 }, bar5 = { "RIGHT", "RIGHT", -45, 0 }, bar6 = { "RIGHT", "RIGHT", -84, 0 },
  bar7 = { "RIGHT", "RIGHT", -123, 0 }, bar8 = { "RIGHT", "RIGHT", -162, 0 },
  stance = { "BOTTOM", "BOTTOM", -280, 0 }, pet = { "BOTTOM", "BOTTOM", 0, 0 }, totem = { "BOTTOM", "BOTTOM", 280, 0 },
  -- (1.92.0) in from the corner by a plate's padding, the two plates a 2px seam apart
  menu = { "BOTTOMRIGHT", "BOTTOMRIGHT", -9, 9 }, bags = { "BOTTOMRIGHT", "BOTTOMRIGHT", -9, 45 },
  xp = { "BOTTOM", "BOTTOM", 0, 3 }, rep = { "BOTTOM", "BOTTOM", 0, 17 }, -- just above the XP bar
}

-- Names for the rows that turn menu buttons on and off.
local MENU_NAMES = {
  CharacterMicroButton = "Character", ProfessionMicroButton = "Professions", SpellbookMicroButton = "Spellbook",
  TalentMicroButton = "Talents", LegacyMicroButton = "Legacy", QuestLogMicroButton = "Quest log",
  HousingMicroButton = "Housing", GuildMicroButton = "Guild", LFDMicroButton = "Group finder",
  CollectionsMicroButton = "Collections", EJMicroButton = "Adventure guide", HelpMicroButton = "Help",
  StoreMicroButton = "Shop", MainMenuMicroButton = "Game menu",
}

-- The first page condition sends vehicles, possession and temporary forms to the
-- snippet below, which asks the game which page they use. After that, Shift-number
-- pages, then stance and form pages, the same order the game's own bar uses.
local PAGE_DRIVER = "[overridebar][vehicleui][possessbar][bonusbar:5][shapeshift]special;"
  .. "[bar:2]2;[bar:3]3;[bar:4]4;[bar:5]5;[bar:6]6;"
  .. "[bonusbar:1]7;[bonusbar:2]8;[bonusbar:3]9;[bonusbar:4]10;1"

local ON_PAGE = [[
  local page = tonumber(newstate)
  if newstate == "special" then
    if HasVehicleActionBar and HasVehicleActionBar() then
      page = GetVehicleBarIndex()
    elseif HasOverrideActionBar and HasOverrideActionBar() then
      page = GetOverrideBarIndex()
    elseif HasTempShapeshiftActionBar and HasTempShapeshiftActionBar() then
      page = GetTempShapeshiftBarIndex()
    elseif HasBonusActionBar and HasBonusActionBar() then
      page = GetBonusBarIndex()
    end
  end
  local offset = ((page or 1) - 1) * 12
  self:SetAttribute("actionOffset", offset)
  control:ChildUpdate("offset", offset)
  control:CallMethod("Paged")
]]

local ON_OFFSET = [[
  local action = self:GetAttribute("index") + (message or 0)
  if self:GetAttribute("action") ~= action then
    self:SetAttribute("action", action)
  end
]]

-- A key press arrives as the made-up button HOTKEY. Flyouts open on a click instead.
local ON_KEY_CLICK = [[
  if button == "HOTKEY" then
    if GetActionInfo(self:GetEffectiveAttribute("action")) == "flyout" then
      return false
    end
    return "LeftButton"
  end
]]

-- While the game's vehicle bar is up, the keys for 1-6 go back to the game, which
-- sends them to that bar's buttons.
local ON_OVERRIDE = [[
  if name ~= "overrideui" and name ~= "petbattleui" then return end
  self:ClearBindings()
  if self:GetAttribute("overrideui") == 1 or self:GetAttribute("petbattleui") == 1 then
    for i = 1, 6 do
      local command = "ACTIONBUTTON" .. i
      self:RunAttribute("SetKeys", command, GetBindingKey(command))
    end
  end
]]

local SET_KEYS = [[
  local command = ...
  for i = 2, select("#", ...) do
    self:SetBinding(true, select(i, ...), command)
  end
]]

------------------------------------------------------------------------
-- Settings
------------------------------------------------------------------------

local function RuleOn(name)
  local rules, enum = _G.C_GameRules, _G.Enum and _G.Enum.GameRule
  return rules and enum and enum[name] and rules.IsGameRuleActive(enum[name]) or false
end

local function Exists(def)
  if def.kind == "action" then return not def.blizz or _G[def.blizz] ~= nil end
  if def.kind == "menu" then
    local menu = _G.MicroMenu
    return menu ~= nil and type(menu.GenerateButtonInfos) == "function"
  end
  if def.kind == "bags" then return _G.MainMenuBarBackpackButton ~= nil and not RuleOn("BagsUIDisabled") end
  if def.kind == "status" then return true end
  if def.kind == "totem" then
    local _, class = UnitClass("player")
    return class == "SHAMAN" and _G.MultiCastActionBarFrame ~= nil
  end
  return true
end

function B:Def(key)
  for _, def in ipairs(DEFS) do
    if def.key == key then return def end
  end
end

-- A bar's default for one setting (the settings window's changed marks, since 1.61.0).
function B:DefaultFor(key, k)
  local own = PER_BAR[key]
  if own and own[k] ~= nil then return own[k] end
  return LOOK[k]
end

-- When a bar shows and when it fades are two settings since 1.80.0: `mode` (always, only in a
-- fight, only out of one) and `fade` (off, until the mouse is over it, or until that or a
-- fight). Before, "Hover" was one of the modes, so a bar couldn't be both faded out of a fight
-- and solid in one. Settings from before (saved, imported, or another profile's) are carried over.
local function Tidy(c)
  if c.mode == "hover" then
    c.mode = "always"
    if c.fade == nil or c.fade == "off" then c.fade = "hover" end
  end
  return c
end

-- Does this bar fade? And is it awake (solid) for a reason other than the mouse?
local function Fades(c) return c.fade == "hover" or c.fade == "combat" end

function B:Cfg(key)
  local all = ns.db.barCfg or {}
  ns.db.barCfg = all
  local c = all[key]
  -- Since 1.34.0 the reputation bar starts off, just above the XP bar. One that was on only
  -- because that was the default (it was never moved) goes off, once.
  if key == "rep" and not ns.db.barRepOff then
    ns.db.barRepOff = true
    if c and c.left == nil then c.on = false end
  end
  if not c then
    c = {}
    all[key] = c
  end
  local own = PER_BAR[key]
  if own then
    for k, v in pairs(own) do
      if c[k] == nil then c[k] = v end
    end
  end
  Tidy(c) -- before the defaults: an old "Hover" becomes always shown, fading until hovered
  for k, v in pairs(LOOK) do
    if c[k] == nil then c[k] = v end
  end
  return c
end

-- The bars on this client and class, for the edit mode's pickers. The menu and bag
-- bars have a tab of their own.
function B:List(extra)
  local list = extra and self.extraList or self.list
  if #list == 0 then
    for _, def in ipairs(DEFS) do
      if Exists(def) and (def.extra or false) == (extra or false) then
        list[#list + 1] = { key = def.key, name = def.label }
      end
    end
  end
  return list
end

local function Filled(def)
  for i = 1, 12 do
    if HasAction(def.base + i) then return true end
  end
  return false
end

-- The first time VoltUI runs, a bar starts on if the game was showing it or it has
-- anything on it, so nothing you've set up disappears. Later choices are left alone.
function B:Seed()
  if ns.db.barSeeded then return end
  local shown = { GetActionBarToggles and GetActionBarToggles() }
  local n = 0
  for _, def in ipairs(DEFS) do
    if def.kind == "action" then
      if def.key ~= "bar1" and Exists(def) and (shown[n] or Filled(def)) then
        self:Cfg(def.key).on = true
      end
      n = n + 1
    end
  end
end

------------------------------------------------------------------------
-- Dressing a button
------------------------------------------------------------------------

local ART = {
  "NormalTexture", "SlotArt", "SlotBackground", "Border", "IconMask", "HotKey", "FloatingBG",
  "InterruptDisplay", "TargetReticleAnimFrame", "CooldownFlash",
}
local FIT = { "SpellHighlightTexture", "NewActionTexture", "AutoCastOverlay", "AutoCastable" }

-- A part of a button, if this button has it.
local function Part(b, key)
  local part = b[key]
  return type(part) == "table" and part or nil
end

-- Set without running the button's handler, which would run the game's code as VoltUI's.
local function Quiet(b, key, value)
  local set = b.SetAttributeNoHandler or b.SetAttribute
  set(b, key, value)
end

-- What the game's quick keybind mode binds. Its own buttons have this already, and the
-- game reads it during events, so it's only written if it's missing.
local function SetCommand(b, command)
  b.kCommand = command
  if b.commandName ~= command then b.commandName = command end
end

-- The game hides a button with nothing on it whenever it redraws its main bar. VoltUI fades
-- those itself, so this keeps them up. It's well above the reasons the game has of its own.
local ALWAYS_SHOWN = 4096

-- Under a hidden parent, art stays gone whatever the game does to it later.
local function Gone(obj)
  if not (type(obj) == "table" and obj.SetParent) then return end
  if not pcall(obj.SetParent, obj, S.HiddenParent()) and obj.SetAlpha then obj:SetAlpha(0) end
end

local function Flat(tex, icon, r, g, b, a)
  if not tex then return end
  tex:SetColorTexture(r, g, b, a)
  tex:ClearAllPoints()
  tex:SetAllPoints(icon)
end

local function Dress(b)
  local icon = b.icon or b.Icon
  b.kIcon = icon
  if b.IconMask and icon and icon.RemoveMaskTexture then icon:RemoveMaskTexture(b.IconMask) end
  Gone(b.GetNormalTexture and b:GetNormalTexture())
  for _, name in ipairs(ART) do Gone(b[name]) end
  -- This one has to stay on the button: when a cast animation ends, the game goes up
  -- through its parents to reach the button and calls the button's own functions.
  local cast = Part(b, "SpellCastAnimFrame")
  if cast then cast:SetAlpha(0) end
  if icon then icon:SetTexCoord(0.07, 0.93, 0.07, 0.93) end

  b.kBack = S.Tex(b, "BACKGROUND", -8)
  b.kBack:SetAllPoints()
  b.kBack:SetColorTexture(S.BG[1], S.BG[2], S.BG[3], 0.55)
  b.kEdges = S.Edges(b, "OVERLAY", 6)

  Flat(b.GetHighlightTexture and b:GetHighlightTexture(), icon, 1, 1, 1, 0.16)
  Flat(b.GetPushedTexture and b:GetPushedTexture(), icon, A[1], A[2], A[3], 0.4)
  Flat(b.GetCheckedTexture and b:GetCheckedTexture(), icon, A[1], A[2], A[3], 0.35)
  if b.Flash then Flat(b.Flash, icon, 0.85, 0.25, 0.2, 0.35) end
  for _, name in ipairs(FIT) do
    local part = b[name]
    if type(part) == "table" and part.ClearAllPoints then
      part:ClearAllPoints()
      part:SetAllPoints(b)
    end
  end

  local cd = b.cooldown
  if cd then
    cd:ClearAllPoints()
    cd:SetAllPoints(icon)
    if cd.SetDrawEdge then cd:SetDrawEdge(false) end
    if cd.SetDrawBling then cd:SetDrawBling(false) end
    if cd.SetSwipeColor then cd:SetSwipeColor(0, 0, 0, 0.72) end
  end

  -- Text sits above the cooldown swipe.
  local over = CreateFrame("Frame", nil, b)
  over:SetAllPoints()
  over:SetFrameLevel(b:GetFrameLevel() + 4)
  b.kText = over
  b.kKey = S.Text(over, nil, "RIGHT", "OVERLAY", LOOK.keySize, "OUTLINE")
  b.kKey:SetPoint("TOPRIGHT", -2, -3)
  if b.Name then
    b.Name:SetParent(over)
    b.Name:ClearAllPoints()
    b.Name:SetPoint("BOTTOMLEFT", 2, 2)
    b.Name:SetPoint("BOTTOMRIGHT", -2, 2)
    b.Name:SetJustifyH("CENTER")
  end
  if b.Count then
    b.Count:SetParent(over)
    b.Count:ClearAllPoints()
    b.Count:SetPoint("BOTTOMRIGHT", -2, 2)
  end
end

-- A font object for cooldown numbers, one per bar, because the numbers can only be
-- given a named font.
local function CooldownFont(f)
  local c = f.cfg
  local name = "VoltUICooldownFont" .. f.def.key
  local font = _G[name] or (CreateFont and CreateFont(name))
  if font and font.SetFont then
    local flags = "OUTLINE"
    if not pcall(font.SetFont, font, S.Font(nil, "bars.cooldown").path, c.cdSize, flags) then
      pcall(font.SetFont, font, "Fonts\\FRIZQT__.TTF", c.cdSize, flags)
    end
  end
  return font and name
end

-- The parts that follow a bar's settings. Nothing here is secure, so it's safe any time.
function B:Fit(b, c, fontName)
  local inset = c.border and 1 or 0
  local icon = b.kIcon
  if icon then
    icon:ClearAllPoints()
    icon:SetPoint("TOPLEFT", inset, -inset)
    icon:SetPoint("BOTTOMRIGHT", -inset, inset)
  end
  for i = 1, 4 do b.kEdges[i]:SetShown(c.border) end
  if b.kKey then
    S.SetFont(b.kKey, c.keySize, "OUTLINE", "bars.key")
    b.kKey:SetAlpha(c.keys and 1 or 0)
  end
  if Part(b, "Name") then
    S.SetFont(b.Name, c.macroSize, "OUTLINE", "bars.macro")
    b.Name:SetAlpha(c.macro and 1 or 0)
  end
  if Part(b, "Count") then
    S.SetFont(b.Count, c.stackSize, "OUTLINE", "bars.count")
    b.Count:SetAlpha(c.stack and 1 or 0)
  end
  local cd = b.cooldown
  if cd then
    if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(not c.cdText) end
    if fontName and cd.SetCountdownFont then pcall(cd.SetCountdownFont, cd, fontName) end
    -- The game draws the numbers, so these work on cooldowns VoltUI can't read: none at all on
    -- a cooldown whose whole length is under cdMin seconds, tenths once under cdTenths left.
    if cd.SetMinimumCountdownDuration then pcall(cd.SetMinimumCountdownDuration, cd, math.floor((tonumber(c.cdMin) or 0) * 1000 + 0.5)) end
    if cd.SetCountdownMillisecondsThreshold then pcall(cd.SetCountdownMillisecondsThreshold, cd, tonumber(c.cdTenths) or 0) end
  end
  if b.kFit then b:kFit(c) end
end

function B:Has(b)
  local kind = b.owner.def.kind
  if kind == "action" then
    local action = b:GetAttribute("action")
    return action and HasAction(action) and true or false
  elseif kind == "pet" then
    return GetPetActionInfo and GetPetActionInfo(b.kIndex) ~= nil
  end
  return true
end

-- The border of a button with no slot behind it: menu, bags and totems.
local function PaintEdges(b)
  local c = b.kHover and A or b.kColor or S.SOFT
  for i = 1, 4 do
    b.kEdges[i]:SetColorTexture(c[1], c[2], c[3], 1)
    b.kEdges[i]:SetShown(b.owner.cfg.border)
  end
end

-- Empty slots, and the green border on equipped items.
function B:Paint(b)
  local f = b.owner
  if f.def.extra or f.def.kind == "totem" then return PaintEdges(b) end
  local show = f.cfg.empty or self.grid or self.quick or FUI.unlocked or self:Has(b)
  b:SetAlpha(show and 1 or 0)
  local r, g, bl = S.SOFT[1], S.SOFT[2], S.SOFT[3]
  if f.def.kind == "action" and IsEquippedAction then
    local action = b:GetAttribute("action")
    if action and IsEquippedAction(action) then r, g, bl = 0.3, 0.85, 0.4 end
  end
  for i = 1, 4 do
    b.kEdges[i]:SetColorTexture(r, g, bl, 1)
    b.kEdges[i]:SetShown(f.cfg.border)
  end
end

function B:PaintBar(f)
  for _, b in ipairs(f.buttons) do self:Paint(b) end
end

function B:PaintAll()
  for _, f in pairs(self.frames) do self:PaintBar(f) end
end

------------------------------------------------------------------------
-- Out of range
------------------------------------------------------------------------

local OUT = { 0.85, 0.28, 0.24 }

local function TintRange(b)
  if b.kOut and b.kIcon then b.kIcon:SetVertexColor(OUT[1], OUT[2], OUT[3]) end
end

function B:SetRange(b, inRange, checks)
  inRange, checks = S.Safe(inRange), S.Safe(checks)
  local out = ns.db.barRange and checks == true and inRange == false or false
  if out == (b.kOut or false) then return end
  b.kOut = out or nil
  if out then
    TintRange(b)
  elseif b.UpdateUsable then
    b:UpdateUsable()
  elseif b.kIcon then
    b.kIcon:SetVertexColor(1, 1, 1)
  end
end

-- The buttons showing an action slot. A new target sends a range event for every slot, and
-- each used to ask every button for its slot. Made on first use and thrown away whenever a
-- button's slot can have changed (a new button, the main bar's page).
local NO_BUTTONS = {}
function B:BySlot(slot)
  local map = self.slotMap
  if not map then
    map = {}
    for _, b in ipairs(self.buttons) do
      local a = b:GetAttribute("action")
      if a then
        local list = map[a]
        if not list then list = {}; map[a] = list end
        list[#list + 1] = b
      end
    end
    self.slotMap = map
  end
  return map[slot] or NO_BUTTONS
end

function B:RangeChanged(slot, inRange, checks)
  for _, b in ipairs(self:BySlot(slot)) do self:SetRange(b, inRange, checks) end
end

------------------------------------------------------------------------
-- Keys
------------------------------------------------------------------------

local SHORT = {
  { "SHIFT%-", "S" }, { "CTRL%-", "C" }, { "ALT%-", "A" }, { "META%-", "M" },
  { "MOUSEWHEELUP", "WU" }, { "MOUSEWHEELDOWN", "WD" }, { "MIDDLEMOUSE", "M3" }, { "BUTTON(%d+)", "M%1" },
  { "NUMPADPLUS", "N+" }, { "NUMPADMINUS", "N-" }, { "NUMPADMULTIPLY", "N*" }, { "NUMPADDIVIDE", "N/" },
  { "NUMPADDECIMAL", "N." }, { "NUMPAD", "N" },
  { "PAGEUP", "PU" }, { "PAGEDOWN", "PD" }, { "BACKSPACE", "Bs" }, { "SPACE", "Sp" }, { "INSERT", "Ins" },
  { "DELETE", "Del" }, { "HOME", "Hm" }, { "END", "En" }, { "TAB", "Tb" }, { "ENTER", "Ent" }, { "ESCAPE", "Esc" },
  { "CAPSLOCK", "Cap" }, { "UP", "Up" }, { "DOWN", "Dn" }, { "LEFT", "Lt" }, { "RIGHT", "Rt" },
}

function B.ShortKey(key)
  if not key or key == "" then return "" end
  key = key:upper()
  for _, s in ipairs(SHORT) do key = key:gsub(s[1], s[2]) end
  return key
end

local function KeyPress(self, _, down)
  local owner = self:GetParent()
  if down then
    if owner:GetButtonState() == "NORMAL" then owner:SetButtonState("PUSHED") end
  elseif owner:GetButtonState() == "PUSHED" then
    owner:SetButtonState("NORMAL")
  end
end

-- Key text, and the bindings that make your keys press this button. Bindings can only
-- change out of combat, and setting them fires UPDATE_BINDINGS, so they're only
-- rewritten when they differ.
function B:BindButton(b)
  if not b.kKey then return end
  local cmd = b.kCommand
  local keys = cmd and { GetBindingKey(cmd) } or {}
  b.kKey:SetText(B.ShortKey(keys[1]))
  local bind = b.kBind
  if not bind then return end
  local want = b.owner.cfg.on and table.concat(keys, " ") or ""
  if want == b.kBound then return end
  if InCombatLockdown() then
    self.keysPending = true
    return
  end
  b.kBound = want
  ClearOverrideBindings(bind)
  if b.owner.cfg.on then
    for _, key in ipairs(keys) do
      SetOverrideBindingClick(bind, false, key, b.kBindName, "HOTKEY")
    end
  end
end

function B:BindAll()
  self.keysPending = nil
  for _, f in pairs(self.frames) do
    for _, b in ipairs(f.buttons) do self:BindButton(b) end
  end
end

------------------------------------------------------------------------
-- Making buttons
------------------------------------------------------------------------

-- The game's own button for this spot on this bar, taken from the bar it was made for.
-- Making one is only for a client that hasn't got it.
function B:TakeButton(f, i)
  local def = f.def
  local b = _G[(def.blizz or "Action") .. "Button" .. i]
  if not b then
    return CreateFrame("CheckButton", "VoltUI" .. def.label:gsub(" ", "") .. "Button" .. i, f, "ActionBarButtonTemplate")
  end
  b:UnregisterAllEvents()
  b:SetParent(f)
  b.bar = nil -- or the game's bar would redo its layout each time this button's slot changes
  return b
end

function B:ActionButton(f, i)
  local def = f.def
  local name = "VoltUI" .. def.label:gsub(" ", "") .. "Button" .. i
  local b = self:TakeButton(f, i)
  b.owner = f
  SetCommand(b, def.command .. i)
  b:SetID(0) -- the "action" attribute decides the slot, not the game's paging
  Quiet(b, "index", i)
  Quiet(b, "showgrid", ALWAYS_SHOWN)
  Quiet(b, "useparent-checkfocuscast", true)
  Quiet(b, "useparent-checkmouseovercast", true)
  Quiet(b, "useparent-checkselfcast", true)
  b:EnableMouseWheel(true)
  b:RegisterForClicks("AnyUp", "AnyDown")
  if def.paged then Quiet(b, "_childupdate-offset", ON_OFFSET) end
  -- The game already has this slot on its button. Paging changes it securely from here on.
  Quiet(b, "action", def.base + i + (f:GetAttribute("actionOffset") or 0))
  self.slotMap = nil

  -- A second, hidden button takes the key presses, so they can cast on key down.
  local bind = CreateFrame("Button", name .. "Key", b, "SecureActionButtonTemplate")
  bind:SetAttribute("type", "action")
  bind:SetAttribute("typerelease", "actionrelease")
  bind:SetAttribute("useparent-action", true)
  bind:SetAttribute("useparent-checkfocuscast", true)
  bind:SetAttribute("useparent-checkmouseovercast", true)
  bind:SetAttribute("useparent-checkselfcast", true)
  bind:SetAttribute("useparent-flyoutDirection", true)
  bind:SetAttribute("useparent-pressAndHoldAction", true)
  bind:SetAttribute("useparent-unit", true)
  bind:EnableMouseWheel(true)
  bind:RegisterForClicks("AnyUp", "AnyDown")
  bind:SetScript("PreClick", KeyPress)
  self.wrap:WrapScript(bind, "OnClick", ON_KEY_CLICK)
  b.kBind, b.kBindName = bind, name .. "Key"

  Dress(b)
  -- The game's Edit Mode re-applies each bar's art setting to every button still on that
  -- bar's list (bar 1's are), and that puts a new frame border on the button and its own
  -- pressed art back. Faded and flattened again straight after (1.101.11).
  if b.UpdateButtonArt then hooksecurefunc(b, "UpdateButtonArt", B.Undress) end
  if b.Update then hooksecurefunc(b, "Update", function(self) B:Paint(self) end) end
  if b.UpdateUsable then hooksecurefunc(b, "UpdateUsable", TintRange) end
  self.mine[b] = true
  self.buttons[#self.buttons + 1] = b
  return b
end

function B:StanceButton(f, i)
  local b = CreateFrame("CheckButton", "VoltUIStanceButton" .. i, f, "StanceButtonTemplate", i)
  b.owner, b.index = f, i
  SetCommand(b, f.def.command .. i)
  if b.SetID then b:SetID(i) end
  b:SetScript("OnUpdate", nil)
  Dress(b)
  self.mine[b] = true
  return b
end

function B:PetButton(f, i)
  local bar = _G.PetActionBar
  local b = (bar and bar.actionButtons and bar.actionButtons[i]) or _G["PetActionButton" .. i]
  if not b then return nil end
  b:SetParent(f)
  b.owner, b.kIndex = f, i
  SetCommand(b, f.def.command .. i)
  Dress(b)
  self.mine[b] = true
  return b
end

function B:Button(f, i)
  local b = f.buttons[i]
  if b then return b end
  local kind = f.def.kind
  if kind == "action" then
    b = self:ActionButton(f, i)
  elseif kind == "stance" then
    b = self:StanceButton(f, i)
  else
    b = self:PetButton(f, i)
  end
  f.buttons[i] = b
  return b
end

function B:Holder(def)
  local f = self.frames[def.key]
  if f then return f end
  f = CreateFrame("Frame", "VoltUI" .. def.label:gsub(" ", ""), UIParent, "SecureHandlerStateTemplate")
  f.def, f.key, f.buttons = def, def.key, {}
  f.cfg = self:Cfg(def.key)
  f:SetFrameStrata("LOW")
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:SetAttribute("checkselfcast", true)
  f:SetAttribute("checkfocuscast", true)
  f:SetAttribute("checkmouseovercast", true)
  f.mover = S.Mover(f, def.label, function()
    S.KeepSpot(f, f.cfg, "left", "top", "point")
  end, { spot = function() return f.cfg, "left", "top", "point" end })
  f.mover:SetScript("OnMouseUp", function()
    if S.MoverDragged(f.mover) then return end -- that was the end of a drag, not a click
    ns.EditMode:PickBar(def.key)
  end)
  self.frames[def.key] = f
  if def.extra then
    f.tray = CreateFrame("Frame", nil, f) -- plain, so buttons can join it in combat
    f.tray:SetAllPoints()
  end

  if def.kind == "action" then
    for i = 1, 12 do self:Button(f, i) end
  elseif def.kind == "pet" then
    for i = 1, (NUM_PET_ACTION_SLOTS or 10) do self:Button(f, i) end
  elseif def.kind == "totem" then
    self:SetupTotem(f)
  elseif def.kind == "menu" then
    self:SetupMenu(f)
  elseif def.kind == "bags" then
    self:SetupBags(f)
  elseif def.kind == "status" then
    self:SetupStatus(f)
  end

  if def.paged then
    f.Paged = function(self)
      B.slotMap = nil
      for _, b in ipairs(self.buttons) do b.kOut = nil end
      B:PaintBar(self)
    end
    f:SetAttribute("_onstate-page", ON_PAGE)
    RegisterStateDriver(f, "page", PAGE_DRIVER)
  end
  return f
end

------------------------------------------------------------------------
-- The totem bar: the game's own buttons, flattened
------------------------------------------------------------------------

local function TotemColors()
  return {
    [_G.FIRE_TOTEM_SLOT or 1] = { 0.85, 0.35, 0.2 },
    [_G.EARTH_TOTEM_SLOT or 2] = { 0.55, 0.7, 0.3 },
    [_G.WATER_TOTEM_SLOT or 3] = { 0.3, 0.6, 0.9 },
    [_G.AIR_TOTEM_SLOT or 4] = { 0.7, 0.75, 0.95 },
  }
end

function B:TotemPart(f, name, command)
  local b = _G[name]
  if not b then return nil end
  b.owner = f
  SetCommand(b, command)
  Dress(b)
  Gone(b.overlayTex)
  Gone(_G[name .. "Highlight"])
  Gone(_G[name .. "HotKey"])
  self.mine[b] = true
  f.buttons[#f.buttons + 1] = b
  return b
end

function B:DressFlyout()
  local fly = _G.MultiCastFlyoutFrame
  if not fly then return end
  if not fly.kDressed then
    fly.kDressed = true
    for _, part in ipairs({ fly.top, fly.middle }) do
      part:SetColorTexture(S.BG[1], S.BG[2], S.BG[3], 0.92)
    end
  end
  for _, b in ipairs(fly.buttons or {}) do
    if not b.kEdges then
      b.kEdges = S.Edges(b, "OVERLAY", 6)
      S.ColorEdges(b.kEdges, S.SOFT[1], S.SOFT[2], S.SOFT[3], 1)
      Flat(b.GetHighlightTexture and b:GetHighlightTexture(), b, 1, 1, 1, 0.16)
    end
    if b.spellId ~= 0 and b.icon then b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93) end -- 0 is "no totem", which is art
  end
end

-- The game's totem frame sits in VoltUI's bar. The game's own Edit Mode places that frame too,
-- when you log in and whenever its layout is applied, which left the totems where Edit Mode
-- had them and VoltUI's bar (and its overlay) somewhere else. So it's put back whenever it moves.
function B:AnchorTotem(f)
  local t = _G.MultiCastActionBarFrame
  if not t or not f then return end
  if InCombatLockdown() then
    self.applyPending = true -- laid out again, and so anchored, when the fight ends
    return
  end
  self.totemAnchoring = true
  if t:GetParent() ~= f then t:SetParent(f) end
  t:ClearAllPoints()
  t:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
  self.totemAnchoring = nil
end

function B:SetupTotem(f)
  local t = _G.MultiCastActionBarFrame
  t.ignoreFramePositionManager = true
  t:SetScript("OnShow", nil)
  t:SetScript("OnHide", nil)
  t:SetScript("OnUpdate", nil)
  self:AnchorTotem(f)
  local function Back()
    if B.totemAnchoring or B.totemQueued then return end
    if InCombatLockdown() or not (C_Timer and C_Timer.After) then
      B.applyPending = true
      return
    end
    B.totemQueued = true
    C_Timer.After(0, function()
      B.totemQueued = nil
      B:AnchorTotem(f)
    end)
  end
  hooksecurefunc(t, "SetPoint", Back)
  hooksecurefunc(t, "SetParent", Back)

  f.kSummon = self:TotemPart(f, "MultiCastSummonSpellButton", "MULTICASTSUMMONBUTTON1")
  f.kRecall = self:TotemPart(f, "MultiCastRecallSpellButton", "MULTICASTRECALLBUTTON1")
  for i = 1, 12 do self:TotemPart(f, "MultiCastActionButton" .. i, "MULTICASTACTIONBUTTON" .. i) end
  -- The slots sit under the action buttons and only catch the mouse.
  f.kSlots = {}
  for i = 1, 4 do
    local slot = _G["MultiCastSlotButton" .. i]
    if slot then
      Gone(slot.background)
      Gone(slot.overlayTex)
      Gone(slot.GetHighlightTexture and slot:GetHighlightTexture())
      f.kSlots[i] = slot
    end
  end
  self:DressFlyout()

  local colors = TotemColors()
  if type(_G.MultiCastActionButton_Update) == "function" then
    hooksecurefunc("MultiCastActionButton_Update", function(b, _, _, slot)
      if b.kEdges then
        b.kColor = colors[slot]
        PaintEdges(b)
      end
    end)
  end
  if type(_G.MultiCastFlyoutFrame_ToggleFlyout) == "function" then
    hooksecurefunc("MultiCastFlyoutFrame_ToggleFlyout", function() B:DressFlyout() end)
  end
  -- The game moves these buttons itself whenever the totem slots change.
  if type(_G.MultiCastActionBarFrame_Update) == "function" then
    hooksecurefunc("MultiCastActionBarFrame_Update", function()
      if InCombatLockdown() then
        B.applyPending = true
      elseif f.cfg.on then
        B:Layout(f)
      end
    end)
  end
end

------------------------------------------------------------------------
-- The menu buttons
------------------------------------------------------------------------

-- The game swaps these two itself. The shop goes in favour of help only in one region.
local function MenuWanted(b)
  local name = b.GetName and b:GetName()
  if name ~= "StoreMicroButton" and name ~= "HelpMicroButton" then return true end
  local store, region = _G.C_StorePublic, _G.GetCurrentRegionName
  local swapped = store and not store.IsEnabled() and region and region() == "CN"
  if name == "HelpMicroButton" then return swapped or false end
  return not swapped
end

local function MenuInfos()
  local out = {}
  for _, info in ipairs(_G.MicroMenu:GenerateButtonInfos()) do
    local rule = info.gameRule and _G.C_GameRules and _G.C_GameRules.IsGameRuleActive(info.gameRule)
    if info.button and not rule and not (info.callback and info.callback()) then
      out[#out + 1] = info.button
    end
  end
  return out
end

-- The menu buttons on this client, for the edit mode.
function B:MenuList()
  local out = {}
  if not Exists({ kind = "menu" }) then return out end
  for _, b in ipairs(MenuInfos()) do
    if MenuWanted(b) then
      local name = b:GetName()
      out[#out + 1] = { key = name, name = MENU_NAMES[name] or (name:gsub("MicroButton", "")) }
    end
  end
  return out
end

-- The art is about as wide as the button and a little taller, with room around the
-- picture, so it keeps its shape and centres on a square.
local GLYPH_W, GLYPH_H = 1.15, 1.4375

local function FitMenu(b, c)
  local w = b:GetWidth()
  local parts = {
    b.GetNormalTexture and b:GetNormalTexture(), b.GetPushedTexture and b:GetPushedTexture(),
    b.GetDisabledTexture and b:GetDisabledTexture(), b.GetHighlightTexture and b:GetHighlightTexture(),
    b.FlashContent,
  }
  for i = 1, 5 do
    local tex = parts[i]
    if type(tex) == "table" then
      tex:ClearAllPoints()
      tex:SetPoint("CENTER", b, "CENTER", 0, 0)
      tex:SetSize(w * GLYPH_W, w * GLYPH_H)
      tex:SetDesaturated(c.mono)
    end
  end
  local portrait = Part(b, "Portrait")
  if portrait then
    portrait:ClearAllPoints()
    portrait:SetPoint("TOPLEFT", 2, -2)
    portrait:SetPoint("BOTTOMRIGHT", -2, 2)
  end
end

-- (1.92.0) Menu and bag buttons are raised grey squares, as buttons in VoltUI's windows are.
local RAISED_ALPHA = 0.9
local function Raised(b)
  local c = S.UI.raised
  b.kBack:SetColorTexture(c[1], c[2], c[3], RAISED_ALPHA)
end

-- A button stays pushed in while its window is open: the dark gold block with a gold line
-- under it that a window's title has.
local function MenuState(b, open)
  if open then
    local c = S.UI.block
    b.kBack:SetColorTexture(c[1], c[2], c[3], 1)
  else
    Raised(b)
  end
  b.kLine:SetShown(open and true or false)
  FitMenu(b, b.owner.cfg) -- the game has just set the art and anchors again
end

local function Hover(b)
  b:HookScript("OnEnter", function(self)
    self.kHover = true
    PaintEdges(self)
  end)
  b:HookScript("OnLeave", function(self)
    self.kHover = nil
    PaintEdges(self)
  end)
end

local function DressMenu(b, f)
  b.owner = f
  Gone(b.Background)
  Gone(b.PushedBackground)
  Gone(b.Shadow)
  Gone(b.PushedShadow)
  local portrait, mask = Part(b, "Portrait"), Part(b, "PortraitMask")
  if portrait and mask and portrait.RemoveMaskTexture then portrait:RemoveMaskTexture(mask) end
  b.kBack = S.Tex(b, "BACKGROUND", -8)
  b.kBack:SetAllPoints()
  Raised(b)
  b.kLine = S.Tex(b, "OVERLAY", 5)
  b.kLine:SetPoint("BOTTOMLEFT", 1, 1)
  b.kLine:SetPoint("BOTTOMRIGHT", -1, 1)
  b.kLine:SetHeight(2)
  b.kLine:SetColorTexture(S.UI.accent[1], S.UI.accent[2], S.UI.accent[3], 1)
  b.kLine:Hide()
  b.kEdges = S.Edges(b, "OVERLAY", 6)
  b.kFit = FitMenu
  local flash = Part(b, "FlashBorder")
  if flash then flash:SetColorTexture(A[1], A[2], A[3], 0.35) end
  local perf = Part(b, "MainMenuBarPerformanceBar")
  if perf then
    perf:SetTexture("Interface\\Buttons\\WHITE8X8")
    perf:ClearAllPoints()
    perf:SetPoint("BOTTOMLEFT", 2, 2)
    perf:SetPoint("BOTTOMRIGHT", -2, 2)
    perf:SetHeight(2)
  end
  if b.SetNormal then hooksecurefunc(b, "SetNormal", function(self) MenuState(self, false) end) end
  if b.SetPushed then hooksecurefunc(b, "SetPushed", function(self) MenuState(self, true) end) end
  Hover(b)
  PaintEdges(b)
end

-- The vehicle bar and pet battles take the buttons for a while. They're plain buttons,
-- so they can come and go in combat.
function B:MenuToGame()
  local f = self.frames.menu
  if not f or f.borrowed then return end
  f.borrowed = true
  for _, b in ipairs(f.buttons) do
    b:SetParent(_G.MicroMenu)
    b:EnableMouse(true)
    b:SetSize(32, 40)
    FitMenu(b, f.cfg)
  end
end

function B:MenuBack()
  local f = self.frames.menu
  if not f or not f.borrowed then return end
  f.borrowed = nil
  self:PlaceExtra(f)
end

function B:SetupMenu(f)
  local menu = _G.MicroMenu
  for _, b in ipairs(MenuInfos()) do
    DressMenu(b, f)
    f.buttons[#f.buttons + 1] = b
  end
  f.borrowed = menu:GetParent() ~= _G.MicroMenuContainer or nil
  hooksecurefunc(menu, "SetParent", function(_, parent)
    if parent == _G.MicroMenuContainer then
      B:MenuBack()
    else
      B:MenuToGame()
    end
  end)
  -- With no buttons of its own, the game can't place the help ticket button.
  if menu.UpdateHelpTicketButtonAnchor then
    hooksecurefunc(menu, "UpdateHelpTicketButtonAnchor", function()
      local ticket, first = _G.HelpOpenWebTicketButton, _G.CharacterMicroButton
      if ticket and first and not f.borrowed then
        ticket:ClearAllPoints()
        ticket:SetPoint("CENTER", first, "CENTER", 0, 20)
      end
    end)
  end
end

------------------------------------------------------------------------
-- The bag buttons
------------------------------------------------------------------------

local KEY_ICON = "Interface\\Icons\\ui-hud-actionbar-keyring"

local function BagNames()
  local names = { "KeyRingButton", "CharacterReagentBag0Slot" }
  for i = (NUM_BAG_SLOTS or 4) - 1, 0, -1 do names[#names + 1] = "CharacterBag" .. i .. "Slot" end
  names[#names + 1] = "MainMenuBarBackpackButton"
  return names
end

-- The game sets all of this again whenever a bag changes.
local function BagArt(b)
  local icon = b.kIcon
  -- See-through, not moved away like other art. The game asks the button for this
  -- texture whenever a bag changes, and once it's moved the button has none to give.
  local normal = b.GetNormalTexture and b:GetNormalTexture()
  if type(normal) == "table" and normal.SetAlpha then normal:SetAlpha(0) end
  local high = b.GetHighlightTexture and b:GetHighlightTexture()
  Flat(high, icon, 1, 1, 1, 0.16)
  if high and high.SetBlendMode then
    high:SetBlendMode("BLEND")
    high:SetAlpha(1)
  end
  Flat(b.GetPushedTexture and b:GetPushedTexture(), icon, A[1], A[2], A[3], 0.4)
  local open = Part(b, "SlotHighlightTexture")
  if open then open:SetColorTexture(A[1], A[2], A[3], 0.3) end
  if icon then
    if b:GetName() == "KeyRingButton" then icon:SetTexture(KEY_ICON) end
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  end
end

local function FitBag(b, c)
  local free = Part(b, "FreeSlots")
  if free then
    S.SetFont(free, c.stackSize, "OUTLINE")
    if b.SetCountShown then b:SetCountShown(c.stack) end
    free:SetAlpha(c.stack and 1 or 0)
  end
end

local function DressBag(b, f)
  b.owner = f
  local icon = b.icon
  b.kIcon = icon
  local mask = Part(b, "SquareMask")
  if mask and icon and icon.RemoveMaskTexture then icon:RemoveMaskTexture(mask) end
  Gone(b.IconBorder)
  Gone(b.IconOverlay)
  Gone(b.IconOverlay2)
  b.kBack = S.Tex(b, "BACKGROUND", -8)
  b.kBack:SetAllPoints()
  Raised(b)
  b.kEdges = S.Edges(b, "OVERLAY", 6)
  local over = CreateFrame("Frame", nil, b)
  over:SetAllPoints()
  over:SetFrameLevel(b:GetFrameLevel() + 4)
  local free, count = Part(b, "FreeSlots"), Part(b, "Count")
  if free then
    free:SetParent(over)
    free:ClearAllPoints()
    free:SetPoint("BOTTOM", 0, 2)
  end
  if count then
    count:SetParent(over)
    count:ClearAllPoints()
    count:SetPoint("BOTTOMRIGHT", -2, 2)
  end
  b.kFit = FitBag
  BagArt(b)
  if b.UpdateTextures then hooksecurefunc(b, "UpdateTextures", BagArt) end
  Hover(b)
  PaintEdges(b)
end

function B:SetupBags(f)
  for _, name in ipairs(BagNames()) do
    local b = _G[name]
    if b then
      DressBag(b, f)
      f.buttons[#f.buttons + 1] = b
    end
  end
  -- Picking up an item would otherwise have the game lay these out again.
  local bar = _G.BagsBar
  if bar then
    if _G.EventRegistry then _G.EventRegistry:UnregisterCallback("MainMenuBarManager.OnExpandChanged", bar) end
    if bar.Layout then hooksecurefunc(bar, "Layout", function() B:PlaceExtra(f) end) end
  end
end

------------------------------------------------------------------------
-- The XP and reputation bars: VoltUI's own, reading the same numbers as the game's
------------------------------------------------------------------------

local function Commas(v)
  return _G.BreakUpLargeNumbers and _G.BreakUpLargeNumbers(v) or tostring(v)
end

local function Percent(value, low, top)
  return floor((value - low) / max(top - low, 1) * 100)
end

-- low, top, value, rested, colour and text, or nothing if there's no XP to show.
local function XPState()
  local rules = _G.GameRulesUtil
  if rules and rules.CanShowExperienceBar then
    if not rules.CanShowExperienceBar() then return end
  elseif _G.IsXPUserDisabled and _G.IsXPUserDisabled() then
    return
  end
  local value, top = S.Safe(UnitXP("player")), S.Safe(UnitXPMax("player"))
  if not (value and top and top > 0) then return end
  local rested = S.Safe(_G.GetXPExhaustion and _G.GetXPExhaustion()) or 0
  local text = ("%s / %s (%d%%)"):format(Commas(value), Commas(top), Percent(value, 0, top))
  local level = S.Safe(UnitLevel("player"))
  if level then text = ("Level %s   %s"):format(tostring(level), text) end
  if rested > 0 then text = ("%s   Rested %s"):format(text, Commas(rested)) end
  return 0, top, value, rested, A, text
end

local function RepState()
  local rep = _G.C_Reputation
  local data = rep and rep.GetWatchedFactionData and rep.GetWatchedFactionData()
  if not data or data.factionID == 0 or not data.name or data.name == "" then return end
  local low, top, value = data.currentReactionThreshold, data.nextReactionThreshold, data.currentStanding
  if not (low and top and value) then return end
  local colors = _G.FACTION_BAR_COLORS
  local c = colors and colors[data.reaction]
  c = c and { c.r, c.g, c.b } or A
  local standing = _G["FACTION_STANDING_LABEL" .. tostring(data.reaction)]
  local text = standing and ("%s   %s"):format(data.name, standing) or data.name
  if top <= low then return 0, 1, 1, 0, c, text end -- the top of the scale: nothing left to fill
  text = ("%s   %s / %s (%d%%)"):format(text, Commas(value - low), Commas(top - low), Percent(value, low, top))
  return low, top, value, 0, c, text
end

-- Nothing here is secure, so it can follow your XP in combat. With nothing to show the
-- bar steps aside, except while you're placing it.
function B:UpdateStatus(f)
  local low, top, value, rested, color, text
  if f.key == "xp" then
    low, top, value, rested, color, text = XPState()
  else
    low, top, value, rested, color, text = RepState()
  end
  local c = f.cfg
  if not low then
    if not FUI.unlocked then return f.tray:Hide() end
    low, top, value, rested, color, text = 0, 1, 0, 0, A, f.def.label
  end
  f.tray:Show()
  f.kBar:SetMinMaxValues(low, top)
  f.kBar:SetValue(value)
  S.BarColor(f.kBar, color[1], color[2], color[3])
  f.kRest:SetMinMaxValues(low, top)
  f.kRest:SetValue(c.rested and min(value + rested, top) or low)
  f.kText:SetText(text)
  local show = c.text == "always" or FUI.unlocked or (c.text == "hover" and f.kHover)
  f.kText:SetAlpha(show and 1 or 0)
end

function B:UpdateStatusAll()
  if self.frames.xp then self:UpdateStatus(self.frames.xp) end
  if self.frames.rep then self:UpdateStatus(self.frames.rep) end
end

function B:LayoutStatus(f)
  local c = f.cfg
  f:SetSize(c.width, c.height)
  local inset = c.border and 1 or 0
  for _, bar in ipairs({ f.kRest, f.kBar }) do
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", f.tray, "TOPLEFT", inset, -inset)
    bar:SetPoint("BOTTOMRIGHT", f.tray, "BOTTOMRIGHT", -inset, inset)
  end
  for i = 1, 4 do f.kEdges[i]:SetShown(c.border) end
  S.SetFont(f.kText, c.textSize, "OUTLINE", "bars.xp")
  -- Only catches the mouse when hovering does something, so clicks pass through it.
  f.tray:EnableMouse(c.text == "hover" and not FUI.unlocked)
  self:UpdateStatus(f)
end

function B:SetupStatus(f)
  -- The rested part sits behind the bar and shows past its end. It carries the track too.
  f.kRest = S.Bar(f.tray)
  f.kRest:GetStatusBarTexture():SetVertexColor(A[1], A[2], A[3], 0.35)
  f.kBar = S.Bar(f.tray)
  f.kBar.bg:Hide()
  f.kBar:SetFrameLevel(f.kRest:GetFrameLevel() + 1)
  f.kEdges = S.Edges(f.tray, "BACKGROUND", -6)
  S.ColorEdges(f.kEdges, S.SOFT[1], S.SOFT[2], S.SOFT[3], 1)
  f.kText = S.Text(f.kBar, "GameFontHighlightSmall", "CENTER", "OVERLAY", f.cfg.textSize, "OUTLINE", "bars.xp")
  f.kText:SetPoint("CENTER")
  f.tray:SetScript("OnEnter", function()
    f.kHover = true
    B:UpdateStatus(f)
  end)
  f.tray:SetScript("OnLeave", function()
    f.kHover = nil
    B:UpdateStatus(f)
  end)
end

------------------------------------------------------------------------
-- Layout and visibility
------------------------------------------------------------------------

-- The size of a block of n buttons, and where each one goes.
local function Grid(c, n)
  local size, perRow = c.size, max(1, min(c.perRow, max(n, 1)))
  local rows = max(1, ceil(n / perRow))
  local w = perRow * size + (perRow - 1) * c.gapX
  local h = rows * size + (rows - 1) * c.gapY
  return max(w, 1), max(h, 1), function(i)
    local col, row = (i - 1) % perRow, floor((i - 1) / perRow)
    local x = c.growX == "right" and col * (size + c.gapX) or w - size - col * (size + c.gapX)
    local y = c.growY == "up" and row * (size + c.gapY) or h - size - row * (size + c.gapY)
    return x, y
  end
end

local function Wanted(f, b)
  local c, name = f.cfg, b:GetName()
  if f.def.kind == "menu" then
    return MenuWanted(b) and not (c.hide and c.hide[name])
  end
  if name == "KeyRingButton" then
    local bar = _G.C_ActionBar
    return c.keyring and not (bar and bar.ShouldShowKeyring and not bar.ShouldShowKeyring())
  elseif name == "CharacterReagentBag0Slot" then
    return c.reagent
  elseif name == "MainMenuBarBackpackButton" then
    return true
  end
  return c.slots
end

-- Puts the menu or bag buttons in place. None of it is secure, so it's safe in combat,
-- when the game may hand buttons back or lay them out again.
function B:PlaceExtra(f)
  if f.borrowed then return end
  local c, n = f.cfg, 0
  for _, b in ipairs(f.buttons) do
    if Wanted(f, b) then n = n + 1 end
  end
  local _, _, at = Grid(c, n)
  local i = 0
  for _, b in ipairs(f.buttons) do
    if Wanted(f, b) then
      i = i + 1
      local x, y = at(i)
      b:SetParent(f.tray)
      b:SetFrameLevel(f.tray:GetFrameLevel() + 1)
      b:ClearAllPoints()
      b:SetPoint("BOTTOMLEFT", f.tray, "BOTTOMLEFT", x, y)
      b:SetSize(c.size, c.size)
      b:EnableMouse(not FUI.unlocked)
      b:Show()
    else
      b:SetParent(S.HiddenParent()) -- not Hide: the game shows some of these itself
    end
    self:Fit(b, c)
    PaintEdges(b)
  end
end

function B:LayoutExtra(f)
  local n = 0
  for _, b in ipairs(f.buttons) do
    if Wanted(f, b) then n = n + 1 end
  end
  f:SetSize(Grid(f.cfg, n))
  self:PlaceExtra(f)
end

local function Put(b, t, x, y, size)
  b:ClearAllPoints()
  b:SetPoint("BOTTOMLEFT", t, "BOTTOMLEFT", x, y)
  b:SetSize(size, size)
end

-- Only the totems you have get a place. The game points the first slot and the recall
-- button somewhere new when it updates them, and in combat that has to wait, so they use
-- the same anchor point the game does: its move replaces ours rather than stretching
-- the button between two.
function B:LayoutTotem(f)
  local c, t = f.cfg, _G.MultiCastActionBarFrame
  self:AnchorTotem(f)
  local cells = {}
  if f.kSummon and f.kSummon:IsShown() then cells[#cells + 1] = f.kSummon end
  for i = 1, t.numActiveSlots or 0 do cells[#cells + 1] = i end
  if f.kRecall and f.kRecall:IsShown() then cells[#cells + 1] = f.kRecall end
  local w, h, at = Grid(c, #cells > 0 and #cells or 4) -- something for the overlay to grab
  f:SetSize(w, h)
  t:SetSize(w, h)
  for i, cell in ipairs(cells) do
    local x, y = at(i)
    if cell == f.kRecall then
      cell:ClearAllPoints()
      cell:SetPoint("LEFT", t, "BOTTOMLEFT", x, y + c.size / 2)
      cell:SetSize(c.size, c.size)
    elseif cell == f.kSummon then
      Put(cell, t, x, y, c.size)
    else
      if f.kSlots[cell] then Put(f.kSlots[cell], t, x, y, c.size) end
      for page = 0, 2 do
        local action = _G["MultiCastActionButton" .. (page * 4 + cell)]
        if action then Put(action, t, x, y, c.size) end
      end
    end
  end
  local fontName = CooldownFont(f)
  for _, b in ipairs(f.buttons) do
    b:SetSize(c.size, c.size)
    self:Fit(b, c, fontName)
    PaintEdges(b)
  end
end

local function HowMany(f)
  local c, kind = f.cfg, f.def.kind
  if kind == "stance" then
    local n = min(c.count, GetNumShapeshiftForms and GetNumShapeshiftForms() or 0)
    return FUI.unlocked and max(n, 1) or n
  elseif kind == "pet" then
    return min(c.count, #f.buttons)
  end
  return c.count
end

-- Bars that sit in a column open their flyouts sideways, towards the screen's middle.
local function FlyoutDirection(f)
  if f.cfg.perRow > 1 then return f.cfg.growY == "down" and "DOWN" or "UP" end
  -- From the saved spot where there is one: straight after the bar is placed the game still
  -- reports where it was (or nothing, at login). Both sides in the bar's own units, so a
  -- scaled bar isn't judged against the screen's width in another scale.
  local s = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
  local x = S.SpotCorner(f, f.cfg, "left", "top", "point") or f:GetCenter()
  if not x then return "LEFT" end
  return x > (UIParent:GetWidth() or 0) / s / 2 and "LEFT" or "RIGHT"
end

function B:Layout(f)
  local c = f.cfg
  if f.def.kind == "totem" then return self:LayoutTotem(f) end
  if f.def.kind == "status" then return self:LayoutStatus(f) end
  if f.def.extra then return self:LayoutExtra(f) end
  local n = HowMany(f)
  for i = 1, n do
    if not self:Button(f, i) then
      n = i - 1
      break
    end
  end
  local size = c.size
  local w, h, at = Grid(c, n)
  f:SetSize(w, h)
  local fontName = CooldownFont(f)
  local direction = f.def.kind == "action" and FlyoutDirection(f)
  for i, b in ipairs(f.buttons) do
    if i <= n then
      local x, y = at(i)
      b:ClearAllPoints()
      b:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", x, y)
      b:SetSize(size, size)
      Quiet(b, "statehidden", nil)
      b:Show()
      -- The game reads this next time it redraws the button. Calling its UpdateFlyout
      -- from here would write what it finds on the button as VoltUI's.
      if direction then Quiet(b, "flyoutDirection", direction) end
    else
      Quiet(b, "statehidden", true)
      b:Hide()
    end
    self:Fit(b, c, fontName)
    self:Paint(b)
  end
end

-- (1.92.0) A plate: a glass panel behind a bar, a little larger than its buttons, that ties
-- them into one piece. It's VoltUI's own plain frame under the bar, so it shows, hides and fades
-- with the bar, and nothing on the game's buttons is touched. The bar's own size and spot
-- don't change: the plate reaches out past them by its padding.
function B:Plate(f)
  local c, p = f.cfg, f.plate
  local want = c.plate and f.def.kind ~= "status"
  if want and f.def.kind == "stance" and HowMany(f) == 0 then want = false end -- no forms: nothing to frame
  if not want then
    if p then p:Hide() end
    return
  end
  if not p then
    p = CreateFrame("Frame", nil, f)
    p.back = S.Tex(p, "BACKGROUND", -8)
    p.back:SetAllPoints()
    p.edges = S.Edges(p, "BACKGROUND", -7)
    f.plate = p
  end
  local pad = c.platePad
  p:SetFrameLevel(f:GetFrameLevel())
  p:ClearAllPoints()
  p:SetPoint("TOPLEFT", f, "TOPLEFT", -pad, pad)
  p:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", pad, -pad)
  local bg, edge = S.UI.bg, S.UI.edge
  p.back:SetColorTexture(bg[1], bg[2], bg[3], c.plateAlpha)
  for i = 1, 4 do p.edges[i]:SetColorTexture(edge[1], edge[2], edge[3], min(1, c.plateAlpha + 0.25)) end
  p:Show()
end

-- What the game's state driver checks. Bars step aside for the game's vehicle bar.
function B:Driver(f)
  local conds = {}
  if f.def.kind == "pet" then conds[#conds + 1] = "@pet,exists,nopossessbar" end
  local mode = f.cfg.mode
  if mode == "combat" then
    conds[#conds + 1] = "combat"
  elseif mode == "peace" then
    conds[#conds + 1] = "nocombat"
  end
  local stop = "[petbattle]hide;"
  if _G.OverrideActionBar then stop = stop .. "[overridebar][vehicleui]hide;" end
  if #conds == 0 then return stop .. "show" end
  return stop .. "[" .. table.concat(conds, ",") .. "]show;hide"
end

function B:Place(f)
  local c = f.cfg
  f:SetScale(c.scale)
  if S.PlaceSpot(f, c, "left", "top", "point") then return end
  f:ClearAllPoints()
  local spot = SPOTS[f.key]
  local y = spot[4]
  if spot[1] == "BOTTOM" and y == 0 then
    -- stance, pet and totems sit just above whichever of the bottom bars are on
    y = 60
    if self:Cfg("bar2").on then y = 99 end
    if self:Cfg("bar3").on then y = 138 end
  end
  f:SetPoint(spot[1], UIParent, spot[2], spot[3], y)
end

-- Bring one bar in line with its settings. Out of combat only: this moves secure frames.
function B:Apply(f)
  if InCombatLockdown() then
    self.applyPending = true
    return
  end
  local c = Tidy(f.cfg)
  if not c.on then
    UnregisterStateDriver(f, "visibility")
    f:Hide()
    f.mover:Hide()
    for _, b in ipairs(f.buttons) do self:BindButton(b) end
    self:UpdateTicker()
    return
  end
  self:Place(f)
  self:Layout(f)
  self:Plate(f)
  if FUI.unlocked or self.quick then
    -- Every bar stays up while you edit or bind, whenever it would normally show.
    UnregisterStateDriver(f, "visibility")
    f:Show()
    f:SetAlpha(c.alpha)
    f.mover:SetShown(FUI.unlocked)
  else
    f.mover:Hide()
    RegisterStateDriver(f, "visibility", self:Driver(f))
    f:SetAlpha(Fades(c) and c.fadeTo or c.alpha)
  end
  for _, b in ipairs(f.buttons) do self:BindButton(b) end
  self:UpdateTicker()
end

function B:ApplyAll()
  if InCombatLockdown() then
    self.applyPending = true
    return
  end
  self.applyPending = nil
  for _, def in ipairs(DEFS) do
    if def.extra then
      -- These lean on the game's own frames more than the bars do. If one of them
      -- trips, your action bars still work and the game's buttons stay where they were.
      local ok, err = pcall(self.ApplyOne, self, def)
      if not ok then
        self.failed = self.failed or {}
        self.failed[def.key] = true
        FUI:Print("%s left as the game has it: %s", def.label, tostring(err))
      end
    else
      self:ApplyOne(def)
    end
  end
end

function B:ApplyOne(def)
  local f = self.frames[def.key]
  if f then
    self:Apply(f)
  elseif Exists(def) and self:Cfg(def.key).on then
    self:Apply(self:Holder(def))
  end
end

------------------------------------------------------------------------
-- Fading on hover
------------------------------------------------------------------------

function B:Tick(dt)
  for _, f in pairs(self.frames) do
    local c = f.cfg
    if c.on and Fades(c) then
      local fly = f.key == "totem" and _G.MultiCastFlyoutFrame
      local awake = FUI.unlocked or self.grid or self.quick or (MouseIsOver and MouseIsOver(f)) or (fly and fly:IsShown())
        or (c.fade == "combat" and InCombatLockdown()) -- solid for the whole fight, faded outside it
      local want = awake and c.alpha or c.fadeTo
      local now = f:GetAlpha()
      -- The game hands alpha back rounded (0.35 as 0.3499999940), so "not equal" never settles
      -- and the bar would be set again every frame for good.
      if math.abs(now - want) > 0.004 then
        local step = dt / FADE_TIME * max(c.alpha - c.fadeTo, 0.01)
        if now < want then
          f:SetAlpha(min(want, now + step))
        else
          f:SetAlpha(max(want, now - step))
        end
      end
    end
  end
end

-- Only runs while a bar actually fades.
function B:UpdateTicker()
  if not self.ev then return end
  local any = false
  for _, f in pairs(self.frames) do
    if f.cfg.on and Fades(f.cfg) then any = true end
  end
  self.ev:SetScript("OnUpdate", any and function(_, dt) B:Tick(dt) end or nil)
end

------------------------------------------------------------------------
-- Stance buttons: nothing in the game updates ours
------------------------------------------------------------------------

function B:UpdateStance()
  local f = self.frames.stance
  if not (f and GetShapeshiftFormInfo) then return end
  for i, b in ipairs(f.buttons) do
    local tex, active, castable = GetShapeshiftFormInfo(i)
    if b.kIcon then
      b.kIcon:SetTexture(tex)
      if castable then
        b.kIcon:SetVertexColor(1, 1, 1)
      else
        b.kIcon:SetVertexColor(0.4, 0.4, 0.4)
      end
    end
    if b.SetChecked then b:SetChecked(active and true or false) end
    local cd = b.cooldown
    if cd and GetShapeshiftFormCooldown then
      local start, duration = GetShapeshiftFormCooldown(i)
      start, duration = S.Safe(start), S.Safe(duration)
      if start and duration and start > 0 and duration > 0 then
        cd:SetCooldown(start, duration)
      elseif cd.Clear then
        cd:Clear()
      end
    end
  end
end

-- After the game re-arts a button: its new border goes (alpha, so it stays the button's
-- own normal texture and the game finds it next time), and the pressed look is VoltUI's again.
function B.Undress(b)
  local normal = b.GetNormalTexture and b:GetNormalTexture()
  if normal and normal.SetAlpha then normal:SetAlpha(0) end
  local icon = b.kIcon or b.icon or b.Icon
  if icon then Flat(b.GetPushedTexture and b:GetPushedTexture(), icon, A[1], A[2], A[3], 0.4) end
end

------------------------------------------------------------------------
-- Leave vehicle / stop flight (1.101.12)
------------------------------------------------------------------------
-- The game's button for getting out of a vehicle that has no bar of its own, and for landing
-- early from a flight, is a child of the main bar, which VoltUI hides: so it never showed. It
-- gets a holder of its own that can be moved like any other frame. The game still decides
-- when it shows and what a click does; VoltUI only gives it a place and a flat look.

local LEAVE_SIZE = 34

function B:PlaceLeave()
  local h = self.leave
  if not h then return end
  if S.PlaceSpot(h, ns.db, "leaveLeft", "leaveTop", "leavePoint") then return end
  h:ClearAllPoints()
  local bar = self.frames and self.frames.bar1
  if bar then
    h:SetPoint("BOTTOMRIGHT", bar, "BOTTOMLEFT", -6, 0) -- beside bar 1 until it's moved
  else
    h:SetPoint("BOTTOM", UIParent, "BOTTOM", -260, 60)
  end
end

-- The button into the holder. It's one of the game's Edit Mode frames, whose SetPoint is the
-- game's own wrapper: the plain one is used where there is one.
function B:SeatLeave()
  local b, h = _G.MainMenuBarVehicleLeaveButton, self.leave
  if not (b and h) then return end
  if InCombatLockdown() and b.IsProtected and b:IsProtected() then
    self.leavePending = true
    return
  end
  self.leavePending = nil
  self.seatingLeave = true
  pcall(function()
    if b:GetParent() ~= h then b:SetParent(h) end
    ;(b.ClearAllPointsBase or b.ClearAllPoints)(b)
    ;(b.SetPointBase or b.SetPoint)(b, "CENTER", h, "CENTER", 0, 0)
    b:SetSize(LEAVE_SIZE - 2, LEAVE_SIZE - 2)
  end)
  self.seatingLeave = nil
end

function B:LeaveButton()
  local b = _G.MainMenuBarVehicleLeaveButton
  if not b or self.leave then return end
  local h = CreateFrame("Frame", "VoltUILeaveVehicle", UIParent)
  h:SetSize(LEAVE_SIZE, LEAVE_SIZE)
  h:SetFrameStrata("LOW")
  h:SetMovable(true)
  h:SetClampedToScreen(true)
  self.leave = h
  self:PlaceLeave()
  h.mover = S.Mover(h, "Leave vehicle", function()
    S.KeepSpot(h, ns.db, "leaveLeft", "leaveTop", "leavePoint")
  end, { spot = function() return ns.db, "leaveLeft", "leaveTop", "leavePoint" end })
  -- VoltUI's flat frame, on the button itself so it shows and hides with it
  local back = S.Tex(b, "BACKGROUND", -8)
  back:SetPoint("TOPLEFT", -1, 1)
  back:SetPoint("BOTTOMRIGHT", 1, -1)
  back:SetColorTexture(S.BG[1], S.BG[2], S.BG[3], 0.55)
  S.Edges(b, "OVERLAY", 6)
  self:SeatLeave()
  -- Back into the holder whenever the game places or re-parents it (Edit Mode, a layout change).
  local again = function() if not B.seatingLeave then B:SeatLeave() end end
  hooksecurefunc(b, "SetPoint", again)
  hooksecurefunc(b, "SetParent", again)
  if b.Update then pcall(b.Update, b) end -- shown now if you're already in a vehicle or flying
end

------------------------------------------------------------------------
-- The game's own bars
------------------------------------------------------------------------

local function Retire(name, keepEvents, wipeButtons)
  local frame = _G[name]
  if not frame then return end
  if not keepEvents then frame:UnregisterAllEvents() end
  ;(frame.HideBase or frame.Hide)(frame)
  frame:SetParent(S.HiddenParent())
  if type(frame.actionButtons) == "table" then
    for _, button in pairs(frame.actionButtons) do
      if not B.mine[button] then -- a bar that's on has already taken its buttons
        button:UnregisterAllEvents()
        Quiet(button, "statehidden", true)
        button:Hide()
      end
    end
    if wipeButtons then wipe(frame.actionButtons) end
  end
end

function B:HideBlizzard()
  -- The main bar keeps listening: the game's vehicle bar relies on it.
  Retire("MainActionBar", true)
  if _G.MainMenuBar then
    Retire("MainMenuBar", true)
    Retire("MainMenuBarArtFrame")
  end
  for _, def in ipairs(DEFS) do
    if def.blizz then Retire(def.blizz, false, true) end
  end
  Retire("StanceBar") -- its buttons stay listed: the game reaches for them directly
  local pet = _G.PetActionBar or _G.PetActionBarFrame
  if pet then pet:SetParent(S.HiddenParent()) end -- keeps updating the buttons we borrowed
  -- The menu and bag holders go, not their events: the buttons still need those.
  if Exists(self:Def("menu")) and not (self.failed and self.failed.menu) then
    if _G.MicroMenuContainer then _G.MicroMenuContainer:SetParent(S.HiddenParent()) end
  end
  if Exists(self:Def("bags")) and not (self.failed and self.failed.bags) then
    if _G.BagsBar then _G.BagsBar:SetParent(S.HiddenParent()) end
  end
  local track = _G.StatusTrackingBarManager
  if track and not (self.failed and (self.failed.xp or self.failed.rep)) then
    track:UnregisterAllEvents()
    track:SetParent(S.HiddenParent())
  end
end

-- Priority bindings hand keys 1-6 back to the game while its vehicle bar is up.
function B:WatchOverride()
  local first = _G.OverrideActionBarButton1
  if not first then return end
  local w = self.wrap
  w:WrapScript(first, "OnShow", [[ control:SetAttribute("overrideui", 1) ]])
  w:WrapScript(first, "OnHide", [[ control:SetAttribute("overrideui", 0) ]])
  w:SetAttribute("SetKeys", SET_KEYS)
  w:SetAttribute("_onattributechanged", ON_OVERRIDE)
  w:SetAttribute("overrideui", first:IsVisible() and 1 or 0)
  if RegisterAttributeDriver then RegisterAttributeDriver(w, "petbattleui", "[petbattle]1;0") end
end

function B:WatchProcs()
  -- The proc glow, the game's and VoltUI's own: ProcGlow.lua.
  if B.Glow then B.Glow:Start() end
  -- The game sets cooldown numbers from its own option. Ours decides on our bars.
  if type(_G.ActionButton_UpdateCooldownNumberHidden) == "function" then
    hooksecurefunc("ActionButton_UpdateCooldownNumberHidden", function(b)
      if B.mine[b] and b.cooldown and b.cooldown.SetHideCountdownNumbers then
        b.cooldown:SetHideCountdownNumbers(not b.owner.cfg.cdText)
      end
    end)
  end
end

------------------------------------------------------------------------
-- Quick keybinds: the game's own mode, on VoltUI's buttons
------------------------------------------------------------------------

-- The game only lights up its own buttons in this mode, with art made for round-edged
-- ones. It still fades this texture as you hover, so ours only needs painting flat.
function B:QuickGlow(on)
  for _, f in pairs(self.frames) do
    for _, b in ipairs(f.buttons) do
      local glow = Part(b, "QuickKeybindHighlightTexture")
      if glow and b.commandName then
        if on then
          glow:ClearAllPoints()
          glow:SetAllPoints(b)
          glow:SetColorTexture(A[1], A[2], A[3], 0.55)
          if glow.SetBlendMode then glow:SetBlendMode("BLEND") end
          glow:SetAlpha(0.5)
        end
        glow:SetShown(on)
      end
    end
  end
end

-- Runs however the mode was opened, including from the game's own settings.
function B:QuickMode(on)
  self.quick = on or nil
  self:ApplyAll()
  self:QuickGlow(on)
  self:PaintAll()
  if on or not self.quickOpened then return end
  -- The game opens its settings when the mode closes. Opened from VoltUI, it comes back here.
  local back = self.quickOpened
  self.quickOpened = nil
  if InCombatLockdown() then return end
  local panel = _G.SettingsPanel
  if panel and panel:IsShown() then HideUIPanel(panel) end
  if back == "edit" then
    FUI:SetUnlocked(true)
  elseif back == "settings" then
    ns.EditMode:Open()
  end
end

function B:QuickKeys()
  local mode = _G.QuickKeybindFrame
  if not mode then return FUI:Print("Quick keybinds aren't on this client.") end
  if InCombatLockdown() then return FUI:Print("Quick keybinds can't open in combat.") end
  if mode:IsShown() then return end
  self.quickOpened = FUI.unlocked and "edit" or ns.EditMode:IsOpen() and "settings" or "world"
  if FUI.unlocked then FUI:SetUnlocked(false) end
  ns.EditMode:Close()
  mode:Show()
end

function B:WatchQuick()
  local mode = _G.QuickKeybindFrame
  if not (mode and mode.HookScript) then return end
  mode:HookScript("OnShow", function() B:QuickMode(true) end)
  mode:HookScript("OnHide", function() B:QuickMode(false) end)
end

------------------------------------------------------------------------
-- Changes from the edit mode
------------------------------------------------------------------------

function B:Changed(key)
  if InCombatLockdown() then return end
  local def = self:Def(key)
  if not def or not Exists(def) then return end
  local f = self.frames[key]
  if not f then
    if not self:Cfg(key).on then return end
    f = self:Holder(def)
  end
  self:Apply(f)
  if def.kind == "stance" then self:UpdateStance() end
  if key == "bar2" or key == "bar3" then
    for _, k in ipairs({ "stance", "pet", "totem" }) do
      if self.frames[k] and self.frames[k].cfg.on then self:Place(self.frames[k]) end
    end
  end
end

-- Back to its default look and spot, without switching the bar on or off.
function B:ResetBar(key)
  if InCombatLockdown() then return end
  local c = self:Cfg(key)
  local on = c.on
  wipe(c)
  self:Cfg(key).on = on
  self:Changed(key)
end

function B:CopyLook(from)
  if InCombatLockdown() then return end
  local src = self:Cfg(from)
  for _, def in ipairs(DEFS) do
    if def.key ~= from and not def.extra then
      local c = self:Cfg(def.key)
      for _, k in ipairs(COPIED) do c[k] = src[k] end
      self:Changed(def.key)
    end
  end
end

function B:Mark(key)
  for k, f in pairs(self.frames) do
    if f.mover then f.mover.fill:SetColorTexture(A[1], A[2], A[3], k == key and 0.45 or 0.2) end
  end
end

function B:SetUnlocked()
  if not self.started then return end
  if self.leave and self.leave.mover then self.leave.mover:SetShown(FUI.unlocked and true or false) end
  self:ApplyAll()
  self:PaintAll()
  if not FUI.unlocked then self:Mark(nil) end
end

function B:Refresh()
  if not self.started then return end
  for _, f in pairs(self.frames) do
    if #f.buttons > 0 and f.cfg.on then
      local fontName = CooldownFont(f)
      for _, b in ipairs(f.buttons) do self:Fit(b, f.cfg, fontName) end
    end
  end
end

function B:Slash(arg)
  if arg == "reset" then
    if InCombatLockdown() then return end
    ns.db.barCfg = nil
    ns.db.barSeeded = nil
    self:Seed()
    ns.db.barSeeded = true
    for _, f in pairs(self.frames) do f.cfg = self:Cfg(f.key) end
    self:ApplyAll()
    FUI:Print("action bars back to their defaults.")
  elseif arg == "glow" or arg == "procs" then
    if B.Glow then B.Glow:Test() end
  elseif arg == "debug" then
    local failed = ns.db.startErrors and ns.db.startErrors.bars
    FUI:Print("Started: %s.", failed and ("no: " .. failed:match("^[^\n]*"))
      or self.waiting and "waiting for combat to end" or self.started and "yes" or "no")
    for _, def in ipairs(DEFS) do
      local f = self.frames[def.key]
      FUI:Print("%s: %s", def.label, not Exists(def) and "not on this client"
        or not f and "off"
        or ("%s, slot %s, %s"):format(f.cfg.on and "on" or "off",
          tostring(f.buttons[1] and f.buttons[1]:GetAttribute("action")), f:IsShown() and "showing" or "hidden"))
    end
    FUI:Print("Vehicle bar: %s. Keys waiting for combat to end: %s.",
      _G.OverrideActionBar and "found" or "not on this client", self.keysPending and "yes" or "no")
  else
    if not FUI.unlocked then FUI:SetUnlocked(true) end
    if FUI.unlocked then ns.EditMode:Open("bars") end -- asked for by name, so the window shows
  end
end

------------------------------------------------------------------------
-- Start
------------------------------------------------------------------------

local EVENTS = {
  "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD", "UPDATE_BINDINGS",
  "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_SHOWGRID", "ACTIONBAR_HIDEGRID", "PET_BAR_SHOWGRID", "PET_BAR_HIDEGRID",
  "ACTION_RANGE_CHECK_UPDATE", "PLAYER_EQUIPMENT_CHANGED", "PET_BAR_UPDATE", "UNIT_PET",
  "UPDATE_SHAPESHIFT_FORMS", "UPDATE_SHAPESHIFT_FORM", "UPDATE_SHAPESHIFT_USABLE", "UPDATE_SHAPESHIFT_COOLDOWN",
  "PET_BATTLE_CLOSE",
  "PLAYER_XP_UPDATE", "UPDATE_EXHAUSTION", "PLAYER_LEVEL_UP", "ENABLE_XP_GAIN", "DISABLE_XP_GAIN",
  "PLAYER_MAX_LEVEL_UPDATE", "UPDATE_FACTION", "MAJOR_FACTION_RENOWN_LEVEL_CHANGED",
}

local STATUS_EVENTS = {
  PLAYER_XP_UPDATE = true, UPDATE_EXHAUSTION = true, PLAYER_LEVEL_UP = true, ENABLE_XP_GAIN = true,
  DISABLE_XP_GAIN = true, PLAYER_MAX_LEVEL_UPDATE = true, UPDATE_FACTION = true,
  MAJOR_FACTION_RENOWN_LEVEL_CHANGED = true,
}

local function OnEvent(_, event, a1, a2, a3)
  if STATUS_EVENTS[event] then
    B:UpdateStatusAll()
  elseif event == "ACTION_RANGE_CHECK_UPDATE" then
    B:RangeChanged(a1, a2, a3)
  elseif event == "ACTIONBAR_SLOT_CHANGED" then
    if not a1 or a1 == 0 then
      B:PaintAll()
    else
      for _, b in ipairs(B:BySlot(a1)) do B:Paint(b) end
    end
  elseif event == "ACTIONBAR_SHOWGRID" or event == "PET_BAR_SHOWGRID" then
    B.grid = true
    B:PaintAll()
  elseif event == "ACTIONBAR_HIDEGRID" or event == "PET_BAR_HIDEGRID" then
    B.grid = nil
    B:PaintAll()
  elseif event == "UPDATE_BINDINGS" then
    B:BindAll()
  elseif event == "PLAYER_EQUIPMENT_CHANGED" then
    B:PaintAll()
  elseif event == "PET_BAR_UPDATE" or event == "UNIT_PET" then
    if B.frames.pet then B:PaintBar(B.frames.pet) end
  elseif event == "UPDATE_SHAPESHIFT_FORMS" then
    if InCombatLockdown() then
      B.applyPending = true
    elseif B.frames.stance then
      B:Apply(B.frames.stance)
    end
    B:UpdateStance()
  elseif event:find("^UPDATE_SHAPESHIFT") then
    B:UpdateStance()
  elseif event == "PET_BATTLE_CLOSE" then
    B:MenuBack() -- the game doesn't hand the menu back after a pet battle
  elseif event == "PLAYER_REGEN_DISABLED" then
    if FUI.unlocked then
      FUI:SetUnlocked(false)
      FUI:Print("moving frames stopped: you're in combat.")
    end
    if B.quick and _G.QuickKeybindFrame.CancelBinding then
      _G.QuickKeybindFrame:CancelBinding()
      FUI:Print("quick keybinds closed: you're in combat. Keys you hadn't saved went back.")
    end
  elseif event == "PLAYER_REGEN_ENABLED" then
    if B.applyPending then B:ApplyAll() end
    if B.leavePending then B:SeatLeave() end
    if B.keysPending then B:BindAll() end
    B:UpdateStance()
    if not ns.db.barSeeded then
      B:Seed()
      ns.db.barSeeded = true
      B:ApplyAll()
    end
  elseif event == "PLAYER_ENTERING_WORLD" then
    -- Action data can arrive after login, so the first run checks again here.
    if not ns.db.barSeeded and not InCombatLockdown() then
      B:Seed()
      ns.db.barSeeded = true
      B:ApplyAll()
    end
    B:PaintAll()
    B:BindAll()
    B:UpdateStance()
    B:UpdateStatusAll()
  end
end

function B:Start()
  self.started = true
  self.wrap = CreateFrame("Frame", nil, nil, "SecureHandlerAttributeTemplate")
  local ev = CreateFrame("Frame")
  self.ev = ev
  self:Seed()
  -- Ours first: if something goes wrong here, the game's own bars are still there.
  self:ApplyAll()
  self:HideBlizzard()
  self:LeaveButton()
  self:WatchOverride()
  self:WatchProcs()
  self:WatchQuick()
  for _, e in ipairs(EVENTS) do pcall(ev.RegisterEvent, ev, e) end
  ev:SetScript("OnEvent", OnEvent)
  self:UpdateTicker()
  self:UpdateStance()
  self:PaintAll()
end

-- A /reload in combat waits, because secure frames can't be made then.
function B:Enable()
  self.enabled = true
  if not InCombatLockdown() then return self:Start() end
  self.waiting = true
  FUI:Print("you're in combat, so these are the game's action bars for now. VoltUI's come back when the fight ends.")
  local wait = CreateFrame("Frame")
  wait:RegisterEvent("PLAYER_REGEN_ENABLED")
  wait:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    B.waiting = nil
    B:Start()
  end)
end

FUI:Register(B)
