-- VoltUI · ForeverDB Companion: just its leveling window
-- The ForeverDB Companion add-on does a great deal. This keeps only its leveling window,
-- with what that window shows (the quest plan, where to go next, the supply, training and
-- gathering tips), and switches the rest off: its rare alerts, map and
-- minimap pins, routes, arrow, quest guide, tooltip lines, rotation helper, auto-selling,
-- popups, chat lines and minimap button. It also switches off the ForeverDB Helper add-on
-- for every character.
--
-- It runs once, by itself. /volt foreverdb runs it again (after a ForeverDB update, say);
-- /volt foreverdb undo puts back ForeverDB's settings as they were and turns the Helper
-- back on.
--
-- When another add-on says it plans the levelling (FUI:PlansLevelling), the leveling window
-- goes too, once, since that add-on does its job. /volt foreverdb window brings it back, and undo does as well. What ForeverDB records for foreverdb.net (the Uploader's data) is left as you
-- set it: it shows nothing in the game.
--
-- ForeverDB's settings are plain values in its saved table, ForeverDB_DB. The list below
-- was read from ForeverDB 0.57.10's own settings and brought up to 0.72.1's. Features a
-- newer version adds (C.ADDED) are switched off once by themselves if you trimmed it
-- before they came, and nothing else is touched again, so what you turned back on in
-- ForeverDB stays on. Nothing of ForeverDB's is copied or run.

local ADDON, ns = ...
local FUI = ns.FUI

local C = { READ_FROM = "0.72.1", HELPER = "ForeverDB_Helper" }
ns.Companion = C

-- Switched off (false).
C.OFF = {
  "ahAutoScan", "ahButton", "ahTooltip", "announce", "assist", "assistAlways", "assistGlow", "atlasInFrame",
  "autolog", "autologPvp", "bgAnnounce", "bgPace", "bgPanel", "bgTimers", "bisSearch", "booksNearby",
  "booksTooltip", "booksTrack", "botCrowd", "botHideSpam", "botPrompts", "buffcheck", "campMinimap",
  "campPins", "campShare", "cfDeleteCheapest", "cfFastLoot", "cfQuestAccept", "cfQuestCost", "cfQuestEscort",
  "cfQuestGossip", "cfQuestTurnin", "cfRepair", "cfRepairGuild", "cfSellJunk", "chatBuffs", "coach",
  "coachCues", "coachHintCd", "coachHintGap", "coachHintKeep", "coachHintMana", "coachHintProc",
  "coachHintSound", "coachHints", "coachPrepull", "dgPanel", "dgSync", "dmapClassicSpots", "dmapLoot",
  "dmapOn", "dmapPanelButton", "favorTooltip", "flightBar", "flightTimes", "gatherMinimap", "gatherPins",
  "gfEnchants", "gfMapPins", "gfRollHint", "gfSheet", "gfTrackAlerts", "gfTrackHelper", "gfTrackSound",
  "gpEnchantWho", "kitVendorMark", "levelSummary", "leylinePins", "liveMode", "livePins", "mapFade",
  "mapFadeMax", "mapPins", "mapSearch", "merchantHelp", "newPlayerHome", "nextOnLevelUp", "planArrow",
  "planPins", "professionHelp", "pvpAlerts", "pvpPins", "pvpShare", "pvpSummary", "qhArrow", "qhArrowAuto",
  "qhArrowClear", "qhArrowCorpse", "qhArrowDist", "qhArrowEta", "qhArrowFx", "qhArrowHint", "qhArrowName",
  "qhBlizzDistances", "qhCoordsCursor", "qhCoordsPlayer", "qhFollowBlizz", "qhGuide", "qhGuideButton",
  "qhGuideInline", "qhGuidePanel", "qhGuideSwitch", "qhMinimapPins", "qhNoteSpotPins", "qhNotesShare",
  "qhPinsAvailable", "qhPinsObjective", "qhPinsTurnin", "qhSidePane", "qhSidePaneAuto", "qhTooltips",
  "qhTracker", "questBuddies", "questBuddiesMap", "questBuddiesMinimap", "questPick", "raidBossNotes",
  "raidCheckOnReady", "raidReceive", "raidShareReady", "rareAlerts", "rareChat", "rareClassic",
  "rareFlashScreen", "rareMinimap", "rareNameplateHint", "rareParty", "rarePins", "recipeShareGuild",
  "recipeSharePublic", "recipeTooltip", "reserveChat", "reserveTips", "routeMinimapLine", "routeOn",
  "routeWarn", "routeWorldLine", "talentHighlight", "talentPrompt", "tipDrops", "tipFacts", "tipMade",
  "tipNew", "tipNpc", "tipRep", "tipSold", "tipUpgrade", "tipUsed", "tooltip", "trainerMinimap",
  "trainerPins", "trainerProfPins", "tripTaxiGlow", "upgradeAlerts", "welcome", "wmAuction", "wmBank",
  "wmDungeons", "wmFlight", "wmFlightMinimap", "wmFlightPaths", "wmGraveyards", "wmInn", "wmLore", "wmMail",
  "wmRepair", "wmServices", "wmServicesMinimap", "wmStable", "wmTransport", "zoneLevelsMap", "zoneNews",
  "rmapShow", "rmapAuto", "rmapFollow", "rmapMinimap",
  "coverHead", "coverNotes", "coverTips", "rollAdvice", "rollAlert", "rollClasses", "rollInspect", "rollWarn",
  "spFindGather", "spFindQuest", "spGatherSparkle", "spQuestSparkle", "spSkinSparkle",
}
-- New since the last list (0.60.3), all on by default in ForeverDB 0.72.1: its loot roll
-- advice and alerts (which inspect your group), the dungeon loot coverage lines, and the
-- sparkles and "find" buttons for quest items, herbs, ore and corpses to skin.
C.ADDED = {
  "coverHead", "coverNotes", "coverTips", "rollAdvice", "rollAlert", "rollClasses", "rollInspect", "rollWarn",
  "spFindGather", "spFindQuest", "spGatherSparkle", "spQuestSparkle", "spSkinSparkle",
}
-- Set to a value of their own.
C.SET = { gatherMap = "off", mapReveal = "off", qhArrowSound = "off", quiet = true }

local function DB() return type(ForeverDB_DB) == "table" and ForeverDB_DB or nil end
-- Sets one of ForeverDB's settings, keeping its own value the first time, for undo.
local function Put(d, saved, key, v)
  if saved[key] == nil then saved[key] = { v = d[key] } end
  if d[key] ~= v then d[key] = v; return 1 end
  return 0
end
local function AddOnCall(name, ...)
  local fn = (C_AddOns and C_AddOns[name]) or _G[name]
  if not fn then return nil end
  local ok, a, b = pcall(fn, ...)
  if ok then return a, b end
end

-- Puts ForeverDB's settings to "leveling window only". Each setting's own value is kept the
-- first time, for undo. Returns how many changed, or nil without ForeverDB (or while
-- ForeverDB is only collecting data: it holds its settings itself then).
function C:Apply()
  local d = DB()
  if not d or d.collectOnly == true then return nil end
  local db = ns.db
  local saved = type(db.fdbSaved) == "table" and db.fdbSaved or {}
  local n = 0
  for _, key in ipairs(self.OFF) do n = n + Put(d, saved, key, false) end
  for key, v in pairs(self.SET) do n = n + Put(d, saved, key, v) end
  -- The minimap button keeps its setting in d.minimap.hide.
  if type(d.minimap) ~= "table" then d.minimap = {} end
  if saved["minimap.hide"] == nil then saved["minimap.hide"] = { v = d.minimap.hide } end
  if d.minimap.hide ~= true then d.minimap.hide = true; n = n + 1 end
  db.fdbSaved = saved
  -- The Helper: off for every character from the next /reload.
  if AddOnCall("IsAddOnLoaded", self.HELPER) then
    db.fdbHelperWasOn = true
    AddOnCall("DisableAddOn", self.HELPER)
    n = n + 1
  end
  db.fdbTrimmed = self.READ_FROM
  return n
end

-- Trimmed with an older list: switch off only what ForeverDB has added since, once. How
-- many changed, or nil when there's nothing to catch up on.
function C:CatchUp()
  local d, db = DB(), ns.db
  local was = db.fdbTrimmed
  if not d or d.collectOnly == true or not was or was == "undone" or was == self.READ_FROM then return nil end
  local saved = type(db.fdbSaved) == "table" and db.fdbSaved or {}
  local n = 0
  for _, key in ipairs(self.ADDED) do n = n + Put(d, saved, key, false) end
  db.fdbSaved = saved
  db.fdbTrimmed = self.READ_FROM
  return n
end

-- Another add-on plans your levelling: ForeverDB's leveling window can go. Kept for undo like
-- the rest. True if it changed anything.
function C:WindowOff()
  local d, db = DB(), ns.db
  if not d or d.collectOnly == true then return false end
  local saved = type(db.fdbSaved) == "table" and db.fdbSaved or {}
  if saved.levelWin == nil then saved.levelWin = { v = d.levelWin } end
  db.fdbSaved = saved
  db.fdbWindowOff = true
  local changed = d.levelWin ~= false
  d.levelWin = false
  local w = _G.ForeverDBLevelWindow
  if w and w.IsShown and w:IsShown() then w:Hide() end
  return changed
end

function C:WindowOn()
  local d, db = DB(), ns.db
  if not d then return false end
  d.levelWin = true
  db.fdbWindowOff = false -- you chose it: it stays
  return true
end

-- Once: an add-on that plans your levelling is here and you haven't chosen either way, or
-- undone VoltUI's changes.
function C:AtLogin()
  local planner = FUI.levelPlanner
  if DB() and ns.db.fdbWindowOff == nil and ns.db.fdbTrimmed ~= "undone" and planner and self:WindowOff() then
    FUI:Print("ForeverDB's leveling window is off: %s plans your levelling now. /volt foreverdb window brings it back.", planner)
  end
end

function C:Undo()
  local d, db = DB(), ns.db
  local saved = db.fdbSaved
  if not (d and type(saved) == "table") then return false end
  for key, e in pairs(saved) do
    local v -- (a saved false must come back as false, not nil)
    if type(e) == "table" then v = e.v end
    if key == "minimap.hide" then
      if type(d.minimap) ~= "table" then d.minimap = {} end
      d.minimap.hide = v
    else
      d[key] = v
    end
  end
  db.fdbSaved = nil
  db.fdbWindowOff = false
  if db.fdbHelperWasOn then AddOnCall("EnableAddOn", self.HELPER) end
  db.fdbHelperWasOn = nil
  db.fdbTrimmed = "undone" -- so it doesn't run again by itself
  return true
end

local function Say(n)
  if n == nil then return end
  if n == 0 then
    FUI:Print("ForeverDB is already down to its leveling window.")
  else
    FUI:Print("ForeverDB: kept its leveling window and switched the rest off, the ForeverDB Helper too. Type /reload to finish. /volt foreverdb undo puts it all back.")
  end
end

-- Once, as soon as VoltUI's settings are loaded: ForeverDB has loaded by then (it comes
-- first), and most of its parts read their settings later, at login or when used.
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(self, event, name)
  if event == "ADDON_LOADED" and name ~= ADDON then return end
  if not ns.db then return end
  if not ns.db.fdbTrimmed and DB() then
    Say(C:Apply())
  elseif (C:CatchUp() or 0) > 0 then
    FUI:Print("ForeverDB's newer features (loot roll advice, dungeon loot coverage, sparkles on quest items and nodes) are off too, like the rest. Type /reload to finish. /volt foreverdb undo puts it all back.")
  end
  -- An add-on that plans the levelling loads after VoltUI, so this waits for login.
  if event == "PLAYER_LOGIN" then
    self:UnregisterAllEvents()
    C:AtLogin()
  end
end)

function C:Slash(arg)
  if not DB() then
    FUI:Print("The ForeverDB Companion add-on isn't loaded.")
  elseif arg == "undo" then
    if self:Undo() then
      FUI:Print("ForeverDB's settings are back as they were, and the ForeverDB Helper is on again. Type /reload to finish.")
    else
      FUI:Print("Nothing to undo: VoltUI hasn't changed ForeverDB's settings.")
    end
  elseif arg == "window" then
    if ns.db.fdbWindowOff then
      self:WindowOn()
      FUI:Print("ForeverDB's leveling window is back. Type /reload to finish.")
    else
      self:WindowOff()
      FUI:Print("ForeverDB's leveling window is off.")
    end
  elseif arg == "" or arg == "trim" or arg == "on" then
    local n = self:Apply()
    if n == nil then FUI:Print("ForeverDB is collecting data only, so it holds its settings itself. Untick that in its settings first.") end
    Say(n)
  else
    FUI:Print("/volt foreverdb: keep only ForeverDB's leveling window (and switch the Helper off) · /volt foreverdb window: its leveling window on or off · /volt foreverdb undo")
  end
end
