-- VoltUI · Core
-- Settings, module start-up and /volt.

local ADDON, ns = ...
local FUI = { modules = {} }
ns.FUI = FUI
FUI.Style = ns.Style -- other add-ons can use the same look and font
_G.VoltUI = FUI
_G.ForeverUI = FUI -- the old name, for add-ons that still look for it
-- VoltUI's own parts, for an add-on that adds parts of its own to VoltUI. What it can hook into:
-- FUI:Register, FUI:AddDefaults, FUI:PlansLevelling, FUI:SetDropRecord, FUI.slash and
-- FUI.tipToggles here; ns.Extra (data other parts read); WorldMap:AddLayer and
-- WorldMap.LiftLabels; Tooltips:AddUnitLines; Pages.Extend, Pages.AddPage, Pages.AddTab and
-- Pages.AddLauncher; Move.AddAnchor; MinimapIcon:AddAction; Share.AddKeys; Profiles.AddData.
FUI.ns = ns
-- Data another add-on gives VoltUI's own parts, each with a `credit` to show beside it:
--   zoneLevels = { levels = { [mapID] = { lo, hi } }, credit, made }   (WorldMap.lua)
--   shortCredit: a few words for the world map's title bar
ns.Extra = {}

local defaults = {
  alpha = 0.85,   -- panel background opacity
  glow = 0.6,     -- rarity glow strength (0 = outline only)
  common = false, -- white outline + glow on common items
  loot = true,    -- VoltUI loot window
  lootLeft = nil, lootTop = nil, -- saved loot window spot (when not under the mouse)
  lootScale = 1, lootWidth = 230, -- its size
  lootRows = 8,     -- rows before it scrolls
  lootIlvl = true,  -- item level beside weapons and armour
  map = true,     -- square, simplified minimap
  minimapScale = 1, -- its size, 0.5 to 2
  -- The line under the minimap's zone strip (since 1.45.0): which readouts it shows
  stripClock = true, stripMs = true, stripFps = true, stripDura = true, stripGold = true, stripMail = true,
  minimapLeft = nil, minimapTop = nil, -- its saved spot, while it's somewhere other than the game's
  -- World map
  worldmap = true,
  mapSkin = true,   -- flat look for the map window
  mapLevels = true, -- level labels over the zones
  mapPlates = true, -- dark plate behind each label
  mapLabelSize = 15,
  mapDrag = true,   -- drag the window by its title bar
  mapScale = 1,     -- the small map's size, 0.6 to 2 (drag its bottom-right corner)
  mapLeft = nil, mapTop = nil, mapBigLeft = nil, mapBigTop = nil, -- saved spots, small and full size
  font = "barlow", -- VoltUI font (see Style.lua)
  -- fontRoles: a font for one text in place of `font`, made when first set (S.SetRoleFont)
  barTexture = "flat", -- VoltUI bars' texture (Style.lua S.BAR_TEXTURES); the nameplates keep their own
  -- Questie skin
  questie = true,
  questieFonts = true, -- VoltUI's font on Questie's tracker
  -- Party and raid frames (VoltUI's own, in place of the game's; see Raid.lua)
  groups = true,
  raidCfg = nil, -- see Raid.lua
  -- Nameplates (the game's own, restyled)
  nameplates = true,
  plateCfg = nil, -- see Nameplates.lua
  -- Bags
  bags = true,
  bank = true,
  bagCols = 10, bagSize = 36, gapX = 4, gapY = 4, sectionGap = 10,
  categories = true, ilvl = false, questLeft = true,
  bagEdge = 1, -- how thick an item's rarity outline is in the bags, 1 to 4 pixels
  bagHeads = "line", -- category headings: "line" (a marker, the name, a short hatch) or "band" (a raised band)
  countSize = 12, headerSize = 12, outline = "OUTLINE",
  bagScale = 1,
  bagLeft = nil, bagTop = nil, bankLeft = nil, bankTop = nil,
  -- Tooltips and vendor
  tooltips = true,
  tipIlvl = true, tipVendor = true, tipDrops = true,
  tipAnchor = "game", -- where tooltips show: the game's spot, at the cursor, or a spot of your own
  tipSize = 13,       -- their text size
  tipClass = true,    -- players' names in their class colour
  tipTarget = true,   -- who a unit is targeting
  tipCombat = false,  -- hide tooltips for units in the world while you're in combat
  tipHealth = "percent", -- text on a unit tooltip's health bar: off, percent or number (1.101.17)
  tipCount = true,    -- how many of an item you carry and bank (1.101.18)
  tipIds = true,      -- item, spell and NPC ids while Shift is held (1.101.18)
  junk = true,
  autoRepair = false, -- repair at a vendor that can, with the junk sale (1.101.15); off unless asked for
  pixelEdges = true,  -- border lines a whole number of screen pixels thick (1.101.19)
  -- Unit frames and castbar
  frames = true,
  drawer = false, drawerOpen = false, -- other add-ons' minimap buttons in a drawer (Extras.lua); off until switched on
  rolls = true, -- the game's need / greed frames on a VoltUI panel (Extras.lua)
  guildbank = true, -- the game's guild bank window in VoltUI's look (GuildBank.lua, since 1.67.0)
  groupfinder = true, -- the group finder's listings laid out by VoltUI (GroupFinder.lua, since 1.91.0)
  chat = true, chatAlpha = 0.55, -- the chat windows on VoltUI panels (Chat.lua), and how solid those are
  chatUrls = true,  -- web addresses in chat become links that open a box to copy from (1.101.23)
  chatCopy = true,  -- a small button on each chat window that opens its text to copy (1.101.23)
  links = true, linkSite = "wowhead", -- Alt-click an item or quest for its web page to copy (Links.lua)
  uiText = 12, -- the settings window's text size (since 1.61.0)
  editShape = nil, editH = nil, -- the settings window's width (1, 2r, 2 or 3; EditMode.lua) and height
  -- VoltUI's own buffs and debuffs (Buffs.lua). Off until you switch it on: it puts the game's away.
  buffs = false, buffSize = 30, debuffSize = 30, buffPerRow = 10, buffScale = 1, buffTimers = true, buffTimeSize = 10, buffCountSize = 11,
  classColor = true, -- starting value for each frame; frameCfg holds the per-frame settings
  frameScale = 1,
  frameCfg = nil, -- see UnitFrames.lua
  playerLeft = nil, playerTop = nil, targetLeft = nil, targetTop = nil,
  totLeft = nil, totTop = nil, petLeft = nil, petTop = nil,
  castbar = true,
  castWidth = 260, castHeight = 22, castSize = 12,
  castIcon = true, castTime = true, castSpark = true,
  focusCast = true,  -- a cast bar on the focus frame
  castLag = true,    -- your latency marked at the end of your casts
  castLock = true,   -- a gold line along the top of a cast that can't be interrupted
  castMirror = true, -- breath, fatigue and feign death timers in VoltUI's look
  castSwing = true,  -- the game's weapon swing timers in VoltUI's look (since 1.67.0)
  targetCast = true, -- cast bar on the target frame
  targetCastH = 18,
  castScale = 1,
  castLeft = nil, castTop = nil,
  -- Action bars
  bars = true,
  barCfg = nil, -- see ActionBars.lua
  barSeeded = nil, -- the first run's choice of which bars start on is done
  barRepOff = nil, -- 1.34.0's one-time switching off of a reputation bar left at its old default
  barRange = true, -- tint icons red when out of range
  barProcs = true, -- a glow on a button while a proc makes its spell instant, free or usable
  barProcStyle = "pulse", -- its look: "pulse", "still" (VoltUI's square glow) or "game" (the game's art)
  editLeft = nil, editTop = nil, -- where the settings window sits
  editPage = nil, -- the page it was last on, and opens on
  -- Moving frames
  grid = true,     -- a grid over the screen while moving frames
  snap = true,     -- dropped frames line up with it
  snapFrames = true, -- and with the other frames' edges and middles
  -- On the world map
  mapCoords = true, -- your and the cursor's coordinates on the map (WorldMap.lua)
  gridSize = 16,   -- grid lines this many screen pixels apart
  errorsAll = false, -- the Errors page lists other add-ons' errors too
  icon = true,     -- minimap icon
  iconAngle = 315, -- where on the map's edge, in degrees
}
FUI.defaults = defaults

-- Settings another add-on adds to VoltUI's. They're kept in VoltUIDB with VoltUI's own, so they go
-- in profiles and backups with the rest. Settings already saved stay as they are.
function FUI:AddDefaults(t)
  for k, v in pairs(t) do
    if defaults[k] == nil then defaults[k] = v end
    if ns.db and ns.db[k] == nil then ns.db[k] = v end
  end
end

-- Another add-on that plans the player's levelling says so as it loads, before login: the
-- ForeverDB Companion's leveling window then goes, once (Companion.lua). `name` is shown.
function FUI:PlansLevelling(name)
  FUI.levelPlanner = tostring(name or "another add-on")
end

-- Another add-on's record of what you've looted, for "Drops from" on item tooltips
-- (Tooltips.lua). fn() gives { [source] = { name, loots, it = { ["itemID..."] = { seen } } } },
-- a source key starting "o" and the object's id for a chest or node, or nil when it has none.
function FUI:SetDropRecord(fn)
  FUI.dropRecord = type(fn) == "function" and fn or nil
end

-- More /volt words, from another add-on: FUI.slash.word = function(arg) ... end, and FUI.slashHelp
-- for the words to add to /volt's list.
FUI.slash, FUI.slashHelp = {}, {}
-- /volt tooltips <word>: which setting each word turns on and off. Another add-on can add its own.
FUI.tipToggles = { ilvl = "tipIlvl", vendor = "tipVendor", drops = "tipDrops" }

function FUI:Print(fmt, ...)
  local msg = select("#", ...) > 0 and fmt:format(...) or fmt
  DEFAULT_CHAT_FRAME:AddMessage("|cffffc61aVoltUI|r " .. msg)
end

-- module = { name, Enable(), Refresh() }
function FUI:Register(m) table.insert(self.modules, m) end

-- Switches that only take effect after a reload, and how each was when the game started.
-- Which those are comes from the settings pages' own rows (Pages.lua: `reload` for either way,
-- `reloadOff` for ones that go on at once but need a reload to take back off), so a row's tip
-- and the reload banner can't disagree. Every on/off setting's value at login is kept, since
-- the pages are only read when first asked.
local startedWith = {}

-- Every part has registered by the time anything asks (PLAYER_LOGIN at the earliest), so the
-- lists are made once: the settings window asks on every repaint.
local switchKeys, offKeys
local function SwitchKeys()
  if switchKeys then return switchKeys, offKeys end
  local keys = {}
  for _, m in ipairs(FUI.modules) do
    if m.key ~= "icon" then keys[#keys + 1] = m.key end
  end
  local rows = ns.Pages and ns.Pages.ReloadKeys and ns.Pages.ReloadKeys() or { both = {}, off = {} }
  for _, k in ipairs(rows.both) do keys[#keys + 1] = k end
  switchKeys, offKeys = keys, rows.off
  return keys, offKeys
end

-- Something changed that only a reload puts in place (an import, ForeverDB's settings).
function FUI:NeedReload()
  self.reloadNeeded = true
end

-- Every "Reload now" button goes through here. A reload in the middle of a fight brings the
-- secure parts (bars, party frames) back only once the fight ends, so it's put off instead:
-- the first reload after the fight is the one that's wanted (1.101.8).
function FUI:Reload()
  if InCombatLockdown and InCombatLockdown() then
    self:Print("not in a fight: a reload now would leave the bars and party frames waiting. Type /reload when it's over.")
    return false
  end
  ReloadUI()
  return true
end

-- Is a reload needed for what's been changed since the game started?
function FUI:ReloadPending()
  if self.reloadNeeded then return true end
  local db = ns.db
  if not db then return false end
  local keys, off = SwitchKeys()
  for _, k in ipairs(keys) do
    if startedWith[k] ~= nil and (db[k] ~= false) ~= startedWith[k] then return true end
  end
  for _, k in ipairs(off) do
    if startedWith[k] and db[k] == false then return true end
  end
  return false
end

-- Is the game already locking its frames when VoltUI starts after a /reload in a fight? Nobody
-- knew, and it decides what a reload in combat can and can't set up. Each start notes what
-- the game answers at the three points an add-on can act on, and how long after login a fight
-- first began or ended: VoltUIDB.loginProbe, the last eight starts (1.101.13). Notes only.
do
  local probe = CreateFrame("Frame")
  local row, t0
  local function Note(key)
    if not row then return end
    local locked = InCombatLockdown and InCombatLockdown() and true or false
    local fighting = false
    if UnitAffectingCombat then
      local ok, v = pcall(UnitAffectingCombat, "player")
      if ok and not (issecretvalue and issecretvalue(v)) then fighting = v and true or false end
    end
    row[key] = (locked and "locked" or "free") .. (fighting and ", in combat" or "")
    if locked or fighting then row.inFight = true end
  end
  for _, e in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
    pcall(probe.RegisterEvent, probe, e)
  end
  probe:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" then
      if name ~= ADDON or type(VoltUIDB) ~= "table" then return end
      self:UnregisterEvent("ADDON_LOADED")
      local log = type(VoltUIDB.loginProbe) == "table" and VoltUIDB.loginProbe or {}
      VoltUIDB.loginProbe = log
      row = { at = date and date("%Y-%m-%d %H:%M:%S") or "?" }
      table.insert(log, 1, row)
      while #log > 8 do table.remove(log) end
      t0 = GetTime and GetTime() or 0
      Note("addonLoaded")
    elseif event == "PLAYER_LOGIN" then
      Note("login")
    elseif event == "PLAYER_ENTERING_WORLD" then
      self:UnregisterEvent("PLAYER_ENTERING_WORLD")
      Note("enteringWorld")
    elseif row then
      -- the first of each, as seconds after VoltUI loaded
      local key = event == "PLAYER_REGEN_DISABLED" and "fightBegan" or "fightEnded"
      if row[key] == nil then row[key] = math.floor(((GetTime and GetTime() or 0) - (t0 or 0)) * 10 + 0.5) / 10 end
      if row.fightBegan ~= nil and row.fightEnded ~= nil then
        self:UnregisterEvent("PLAYER_REGEN_DISABLED")
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
      end
    end
  end)
  FUI.loginProbeFrame = probe
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
pcall(ev.RegisterEvent, ev, "ADDON_ACTION_BLOCKED")
pcall(ev.RegisterEvent, ev, "ADDON_ACTION_FORBIDDEN")
pcall(ev.RegisterEvent, ev, "DISPLAY_SIZE_CHANGED")
pcall(ev.RegisterEvent, ev, "UI_SCALE_CHANGED")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:SetScript("OnEvent", function(_, event, name, call)
  if event == "PLAYER_REGEN_DISABLED" then
    -- Moving frames ends as a fight starts, whichever parts are on: this comes just before the
    -- game locks its frames, so a frame being dragged can still be dropped where it is.
    if FUI.unlocked then
      FUI:SetUnlocked(false)
      FUI:Print("moving frames stopped: you're in combat.")
    end
  elseif event == "DISPLAY_SIZE_CHANGED" or event == "UI_SCALE_CHANGED" then
    -- Next frame, once the screen has its new size.
    if C_Timer then C_Timer.After(0, function() FUI:PlaceAll() end) else FUI:PlaceAll() end
  elseif event == "PLAYER_REGEN_ENABLED" then
    ev:UnregisterEvent("PLAYER_REGEN_ENABLED")
    FUI:PlaceAll()
  elseif event == "ADDON_LOADED" and name == ADDON then
    -- A brand-new install has nothing saved yet. Only then does the starting-layouts window
    -- open by itself (Setup.lua); anyone with settings already is left exactly as they are.
    ns.freshInstall = type(VoltUIDB) ~= "table" or next(VoltUIDB) == nil
    VoltUIDB = type(VoltUIDB) == "table" and VoltUIDB or {}
    for k, v in pairs(defaults) do
      if VoltUIDB[k] == nil then VoltUIDB[k] = v end
    end
    ns.db = VoltUIDB
    if not ns.freshInstall then VoltUIDB.setupDone = true end
    -- This character's profile, if it isn't the one whose settings are in use (Profiles.lua).
    if ns.Profiles then
      local ok, err = pcall(ns.Profiles.Load, ns.Profiles, VoltUIDB)
      if not ok then FUI.profileError = tostring(err) end
    end
    VoltUIDB.uiFont = nil -- 1.71.0's settings window font choice: the fonts are fixed since 1.72.0
  elseif event == "PLAYER_LOGIN" then
    ns.Style.LoadSharedFonts()
    -- A failure is kept with where it happened, since chat is gone after a /reload.
    ns.db.startErrors = nil
    for k, v in pairs(defaults) do
      if type(v) == "boolean" then startedWith[k] = ns.db[k] ~= false end
    end
    for _, m in ipairs(FUI.modules) do startedWith[m.key] = ns.db[m.key] ~= false end
    local function WithStack(err)
      return tostring(err) .. "\n" .. (debugstack and debugstack(2) or "")
    end
    for _, m in ipairs(FUI.modules) do
      if ns.db[m.key] ~= false then
        local ok, err = xpcall(function() return m:Enable() end, WithStack)
        if not ok then
          ns.db.startErrors = ns.db.startErrors or {}
          ns.db.startErrors[m.key] = err
          FUI:Print("%s couldn't start: %s", m.name, err:match("^[^\n]*"))
          if ns.Errors then
            local msg, stack = err:match("^([^\n]*)\n?(.*)$")
            ns.Errors:Add(m.name .. " couldn't start: " .. (msg or err), stack, nil, "volt")
          end
        end
      end
    end
    if ns.Setup then pcall(ns.Setup.FirstRun, ns.Setup) end
    if FUI.profileError then
      FUI:Print("couldn't bring in this character's profile, so the settings in use are another profile's: %s", FUI.profileError)
      if ns.Errors and ns.Errors.Add then pcall(ns.Errors.Add, ns.Errors, "Profiles: " .. FUI.profileError, nil, nil, "volt") end
    end
  elseif event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
    -- The game's own message doesn't say what was blocked, so VoltUI names it, once
    -- per call each session, and keeps a count in its saved settings.
    if name ~= ADDON or not ns.db then return end
    local what = tostring(call or "?")
    local log = ns.db.blockedLog or {}
    ns.db.blockedLog = log
    log[what] = (log[what] or 0) + 1
    FUI.blockedSeen = FUI.blockedSeen or {}
    if not FUI.blockedSeen[what] then
      FUI.blockedSeen[what] = true
      FUI:Print("|cffff7f7fThe game blocked VoltUI from:|r %s%s. Please report this.", what, InCombatLockdown() and " (in combat)" or "")
    end
    if ns.Errors then
      ns.Errors:Add("The game blocked VoltUI from: " .. what .. (InCombatLockdown() and " (in combat)" or ""),
        debugstack and debugstack(2) or "", nil, "blocked")
    end
  end
end)

-- After the window or UI scale changes (windowed and back, a new resolution). Saved
-- spots hang off the screen's edges and follow on their own; this puts them back in
-- case the game nudged a frame while the screen was smaller, and works the default
-- spots, which are measured from the screen size, out again. The unit frames and bars
-- can't move in combat, so that waits for it to end.
function FUI:PlaceAll()
  ns.Style.RefreshEdges() -- border lines follow the new scale; not a protected change, so before the combat check
  if InCombatLockdown() then
    ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    return
  end
  local U, C, B = ns.UnitFrames, ns.Castbar, ns.ActionBars
  if U and U.enabled and U.frames.player then pcall(U.Place, U) end
  if C and C.enabled and C.player then pcall(C.Place, C) end
  if B and B.enabled then
    for _, f in pairs(B.frames) do
      if f.cfg.on then pcall(B.Place, B, f) end
    end
    if B.leave then pcall(B.PlaceLeave, B) end
  end
end

function FUI:Refresh()
  for _, m in ipairs(self.modules) do
    if m.enabled and m.Refresh then pcall(m.Refresh, m) end
  end
  ns.Style.RefreshEdges() -- a frame's own scale may have changed: its border lines stay whole pixels
  -- The settings window shows these settings too, so it follows a change made elsewhere
  -- (a slash command, say).
  local E = ns.EditMode
  if E and E.panel and E:IsOpen() then E:RefreshPage() end
end

-- Moving frames: drag overlays on everything that can be moved, the move toolbar, and the
-- settings window. Stopping leaves the settings window as it is.
function FUI:SetUnlocked(on)
  if on and InCombatLockdown() then
    self:Print("Frames can't be moved in combat.")
    return
  end
  local was = self.unlocked
  self.unlocked = on or nil
  for _, m in ipairs(self.modules) do
    if m.enabled and m.SetUnlocked then m:SetUnlocked(on) end
  end
  ns.EditMode:MoveMode(on)
  if on and not was then
    self:Print("Moving frames: drag one to move it, click it to change it. The arrow keys nudge the one you picked.")
  end
end

-- The settings window, on a page (see Pages.lua for their keys).
function FUI:OpenSettings(page)
  ns.EditMode:Open(page)
end

local function OnOff(v) return v and "|cff7fff7fon|r" or "|cffff7f7foff|r" end

SLASH_VOLTUI1 = "/volt"
SLASH_VOLTUI2 = "/voltui"
SlashCmdList.VOLTUI = function(msg)
  local db = ns.db
  if not db then return end
  local cmd, arg = (msg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
  local n = tonumber(arg)
  local mod
  for _, m in ipairs(FUI.modules) do if m.key == cmd then mod = m end end
  if cmd == "" or cmd == "settings" or cmd == "options" or cmd == "config" then
    FUI:OpenSettings(arg ~= "" and arg or nil)
  elseif cmd == "setup" or cmd == "layouts" then
    ns.Setup:Open()
  elseif FUI.slash[cmd] and not (mod and (arg == "on" or arg == "off")) then
    -- another add-on's word; its part's own on and off are still switched below
    FUI.slash[cmd](arg)
  elseif cmd == "errors" or cmd == "error" or cmd == "bugs" then
    FUI:OpenSettings("errors")
  elseif cmd == "share" or cmd == "export" or cmd == "import" or cmd == "backup" then
    FUI:OpenSettings("share")
  elseif cmd == "bank" and (arg == "on" or arg == "off") then
    db.bank = arg == "on"
    FUI:Print("VoltUI bank window %s. Type /reload to apply.", OnOff(db.bank))
  elseif mod and (arg == "on" or arg == "off") then
    db[mod.key] = arg == "on"
    if mod.key == "icon" and ns.MinimapIcon and ns.MinimapIcon.button then
      -- The one part that goes on and off without a reload, once it has started.
      ns.MinimapIcon:SetShown(db.icon)
      FUI:Print("%s %s.", mod.name, OnOff(db.icon))
    else
      FUI:Print("%s %s. Type /reload to apply.", mod.name, OnOff(db[mod.key]))
    end
    FUI:Refresh() -- an open settings window follows
  elseif cmd == "alpha" and n then
    db.alpha = math.max(0, math.min(1, n))
    FUI:Refresh()
    FUI:Print("panel opacity %.2f", db.alpha)
  elseif cmd == "glow" and n then
    db.glow = math.max(0, math.min(1, n))
    FUI:Refresh()
    FUI:Print("glow strength %.2f", db.glow)
  elseif cmd == "common" then
    db.common = not db.common
    FUI:Refresh()
    FUI:Print("white glow on common items: %s", OnOff(db.common))
  elseif cmd == "edit" or cmd == "move" then
    if FUI.unlocked then
      FUI:SetUnlocked(false) -- the settings window comes back if it was open before
    else
      FUI:SetUnlocked(true)
    end
  elseif cmd == "unlock" then
    FUI:SetUnlocked(true)
  elseif cmd == "lock" then
    FUI:SetUnlocked(false)
    ns.EditMode:Close()
  elseif cmd == "frames" then
    ns.UnitFrames:Slash(arg)
  elseif cmd == "timers" or cmd == "timer" then
    ns.Timers:Slash(arg)
  elseif cmd == "castbar" then
    ns.Castbar:Slash(arg)
  elseif cmd == "minimap" then
    ns.Minimap:Slash(arg)
  elseif cmd == "bars" then
    if ns.ActionBars.enabled then ns.ActionBars:Slash(arg) else FUI:Print("The action bars are off. /volt bars on, then /reload.") end
  elseif cmd == "keys" then
    if ns.ActionBars.enabled then ns.ActionBars:QuickKeys() else FUI:Print("The action bars are off. /volt bars on, then /reload.") end
  elseif cmd == "bags" then
    ns.Bags:Slash(arg)
  elseif cmd == "foreverdb" or cmd == "fdb" then
    ns.Companion:Slash(arg)
  elseif cmd == "worldmap" then
    if ns.WorldMap.enabled then ns.WorldMap:Slash(arg) else FUI:Print("The world map part is off. /volt worldmap on, then /reload.") end
  elseif cmd == "groups" or cmd == "raid" or cmd == "party" then
    ns.Raid:Slash(arg)
  elseif cmd == "heal" then
    ns.Raid:Slash("heal " .. arg)
  elseif cmd == "nameplates" or cmd == "plates" then
    ns.Nameplates:Slash(arg)
  elseif cmd == "chat" then
    if not (ns.Chat and ns.Chat.enabled) then
      FUI:Print("The chat part is off. /volt chat on, then /reload.")
    elseif arg == "copy" then
      ns.Chat:Copy()
    else
      FUI:Print("/volt chat copy (the showing chat window's text, to select and copy) · on|off")
    end
  elseif cmd == "questie" then
    ns.QuestieSkin:Slash(arg)
  elseif cmd == "font" then
    local found
    -- No name lists them: an empty string is found at the start of every name.
    for _, f in ipairs(arg ~= "" and ns.Style.FONTS or {}) do
      if f.key == arg or f.name:lower():find(arg, 1, true) == 1 then found = found or f end
    end
    if found then
      db.font = found.key
      ns.Style.ApplyFonts()
      FUI:Refresh()
      FUI:Print("font: %s", found.name)
    else
      local names = {}
      for _, f in ipairs(ns.Style.FONTS) do names[#names + 1] = f.name end
      FUI:Print("fonts: %s", table.concat(names, ", "))
    end
  elseif cmd == "tip" or (cmd == "tooltips" and arg ~= "") then
    local map = FUI.tipToggles
    if map[arg] then
      db[map[arg]] = not db[map[arg]]
      FUI:Print("tooltip %s line: %s", arg, OnOff(db[map[arg]]))
    else
      local words = {}
      for w in pairs(map) do words[#words + 1] = w end
      table.sort(words)
      FUI:Print("/volt tooltips %s (turn those lines on or off) · on|off", table.concat(words, " · "))
    end
  elseif cmd == "loottest" or cmd == "test" then
    if ns.Loot then ns.Loot:Test() end
  elseif cmd == "reset" then
    ns.Style.ClearSpot(db, "lootLeft", "lootTop", "lootPoint")
    FUI:Print("loot window back in its default spot.")
  else
    local parts = {}
    for _, m in ipairs(FUI.modules) do parts[#parts + 1] = m.name .. " " .. OnOff(db[m.key] ~= false) end
    FUI:Print("%s. Opacity %.2f, glow %.2f.", table.concat(parts, ", "), db.alpha, db.glow)
    FUI:Print("/volt (settings) · edit (move frames) · errors · share · frames · timers (test · all · reset) · castbar · minimap · bars (reset · debug) · keys · icon on|off · bags · tooltips · worldmap · questie · groups · nameplates · foreverdb · %s<part> on|off · font <name> · alpha 0-1 · glow 0-1 · common · test (sample loot window) · reset",
      #FUI.slashHelp > 0 and (table.concat(FUI.slashHelp, " · ") .. " · ") or "")
  end
end
