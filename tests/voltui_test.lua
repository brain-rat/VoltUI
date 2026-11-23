-- Stubbed WoW environment for VoltUI. Run: texlua tests/voltui_test.lua VoltUI
local DIR = arg[1]
-- The game runs Lua 5.1, so test on that where you can. Newer versions work too.
table.unpack = table.unpack or unpack
if setfenv then
  local loadFunction = load
  function load(chunk, name, _, env)
    if type(chunk) ~= "string" then return loadFunction(chunk, name) end
    local f, err = loadstring(chunk, name)
    if f and env then setfenv(f, env) end
    return f, err
  end
end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
local unpack = table.unpack
local passed, failed, errors = 0, 0, {}
local function check(c, label) if c then passed = passed + 1 else failed = failed + 1; print("  FAIL: " .. label) end end
-- Another add-on's tests, run inside these on the same pretend game: VOLTUI_EXTRA names
-- a Lua file that returns { load = fn(T), <point> = fn(T), ... }. load runs as the game would
-- load that add-on, after VoltUI's; each other one where these tests call Extra("<point>"). T holds
-- what they need of these tests' own: check, ns, fire, Mock, new, runTimers, and more by point.
-- One local for all of it: the main chunk is near Lua's 200.
local Extra = setmetatable({ T = { check = check } }, { __call = function(self, point, more)
  if self.tests == nil then
    local path = os.getenv and os.getenv("VOLTUI_EXTRA")
    self.tests = (path and path ~= "") and dofile(path) or false
  end
  for k, v in pairs(more or {}) do self.T[k] = v end
  if not (self.tests and self.tests[point]) then return end
  -- Where each local here at this point lives (its function and slot), innermost first, for
  -- tests moved out of this file that still read and write them (since 1.104.0).
  local refs, level = {}, 2
  while true do
    local info = debug.getinfo(level, "fS")
    if not info then break end
    local i = 1
    while true do
      local name = debug.getlocal(level, i)
      if not name then break end
      local r = refs[name]
      if name:sub(1, 1) ~= "(" and (not r or r.func == info.func) then refs[name] = { func = info.func, i = i } end
      i = i + 1
    end
    if info.what == "main" then break end
    level = level + 1
  end
  self.T.refs = refs
  self.tests[point](self.T)
end })
local timers = {}
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
local function runTimers() local t = timers; timers = {}; for _, fn in ipairs(t) do fn() end end

local Mock = {}
local Meta = { __index = function(t, k)
  if Mock[k] ~= nil then return Mock[k] end
  if type(k) == "string" and k:match("^%u") then return function() end end
end }
local eventFrames = {}
local function new(kind, name, parent)
  local m = setmetatable({ kind = kind, scripts = {}, shown = true, alpha = 1, regions = {}, points = {}, parent = parent, flevel = 1, events = {} }, Meta)
  if name then _G[name] = m end
  return m
end
function Mock:SetScript(k, fn) self.scripts[k] = fn end
function Mock:HookScript(k, fn) local o = self.scripts[k]; self.scripts[k] = function(...) if o then o(...) end; fn(...) end end
function Mock:Show() if not self.shown then self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end end
function Mock:Hide() if self.shown then self.shown = false; if self.scripts.OnHide then self.scripts.OnHide(self) end end end
function Mock:IsShown() return self.shown end
function Mock:SetShown(v) if v then self:Show() else self:Hide() end end
function Mock:SetAlpha(a) self.alpha = a end
function Mock:SetText(t) self.text = t end
function Mock:GetText() return self.text end
function Mock:SetTextColor(r, g, b) self.color = { r, g, b } end
function Mock:SetColorTexture(r, g, b, a) self.ctex = { r, g, b, a } end
-- A texture's colour: rounded ones (S.Round, S.Disc, since 1.66.0) keep what S.Paint gave them.
function tint(t) return t.paint or t.ctex end
function Mock:SetTexture(t) self.tex = t end
function Mock:SetDesaturated(v) self.desat = v end
function Mock:SetGradient(o, a, b) self.grad = { o, a, b } end
function Mock:SetHeight(h) self.h = h end
function Mock:SetWidth(w) self.w = w end
function Mock:GetWidth() return self.w or 0 end
function Mock:GetHeight() return self.h or 0 end
function Mock:SetSize(w, h) self.w, self.h = w, h end
function Mock:SetPoint(...) table.insert(self.points, { ... }) end
function Mock:ClearAllPoints() self.points = {} end
-- Where a frame's top-left lands on screen, worked out from its last anchor when that's
-- on UIParent. Anything else (or nothing) counts as 300, 600.
local function HX(pt, size) return pt:find("LEFT") and 0 or pt:find("RIGHT") and size or size / 2 end
local function VY(pt, size) return pt:find("BOTTOM") and 0 or pt:find("TOP") and size or size / 2 end
function screenTopLeft(f)
  local q = f.points and f.points[#f.points]
  if not q or q[2] ~= UIParent then return 300, 600 end
  local p, rp = q[1], q[3] or q[1]
  local x, y = q[4] or 0, q[5] or 0
  if type(q[3]) == "number" then rp, x, y = q[1], q[3], q[4] or 0 end -- SetPoint(point, rel, x, y)
  local w, h = f:GetWidth(), f:GetHeight()
  return HX(rp, UIParent:GetWidth()) + x - HX(p, w), VY(rp, UIParent:GetHeight()) + y + h - VY(p, h)
end
-- True when f is anchored to UIParent with its top-left at left, top (to the pixel).
function sitsAt(f, left, top)
  local q = f.points and f.points[#f.points]
  if not q or q[2] ~= UIParent then return false end
  local l, t = screenTopLeft(f)
  return math.abs(l - left) <= 1 and math.abs(t - top) <= 1
end
function Mock:GetLeft() return (screenTopLeft(self)) end
function Mock:GetTop() return select(2, screenTopLeft(self)) end
-- On screen: shown, and so is everything it sits in.
function Mock:IsVisible()
  local f = self
  while f do
    if f.shown == false then return false end
    f = f.parent
  end
  return true
end
function Mock:GetRight() return (screenTopLeft(self)) + self:GetWidth() end
function Mock:GetBottom() return select(2, screenTopLeft(self)) - self:GetHeight() end
-- In the game a rect read straight after SetPoint or SetSize can still be the old one,
-- which put bars in the wrong place in 1.12.1. So here it's always stale.
function Mock:GetRect() return 0, 0, 1, 1 end
function Mock:GetEffectiveScale() return 1 end
function Mock:GetFrameLevel() return self.flevel end
function Mock:SetFrameLevel(l) self.flevel = l end
function Mock:IsObjectType(k) return self.kind == k end
function Mock:GetRegions() return unpack(self.regions) end
function Mock:CreateTexture(_, layer) local t = new("Texture", nil, self); t.layer = layer; table.insert(self.regions, t); return t end
allFontStrings = {}
function Mock:CreateFontString() local t = new("FontString", nil, self); t.text = ""; allFontStrings[#allFontStrings + 1] = t; return t end
function Mock:RegisterEvent(e) self.events[e] = true; eventFrames[e] = eventFrames[e] or {}; table.insert(eventFrames[e], self) end
-- Unit events are sent to the frame like any other here; the add-on's own unit check still runs.
function Mock:RegisterUnitEvent(e) self:RegisterEvent(e) end
function Mock:UnregisterEvent(e) self.events[e] = nil; for i, f in ipairs(eventFrames[e] or {}) do if f == self then table.remove(eventFrames[e], i) break end end end
function Mock:SetMaskTexture(t) self.mask = t end
function Mock:GetZoom() return self.zoom or 0 end
function Mock:SetZoom(z) self.zoom = z end
function Mock:GetZoomLevels() return 6 end
function Mock:StartMoving() end
-- Like the game: a dropped frame is left anchored by its top-left to the screen's
-- bottom-left, here at dropLeft, dropTop (300, 600 unless a test says).
function Mock:StopMovingOrSizing()
  self.points = { { "TOPLEFT", UIParent, "BOTTOMLEFT", self.dropLeft or 300, self.dropTop or 600 } }
end
function CreateFrame(kind, name, parent) return new(kind, name, parent) end
local function fire(e, ...) for _, f in ipairs(eventFrames[e] or {}) do if f.events[e] then f.scripts.OnEvent(f, e, ...) end end end
function hooksecurefunc(t, k, fn) local o = t[k]; t[k] = function(...) local r = { o(...) }; fn(...); return unpack(r) end end
function CreateColor(r, g, b, a) return { r = r, g = g, b = b, a = a } end
UIParent = new("Frame", "UIParent")
UIParent:SetSize(1920, 1080)
GameTooltip = new("GameTooltip")
function GameTooltip:SetLootItem(slot) self.lootSlot = slot end
UISpecialFrames = {}
local chat = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) chat[#chat + 1] = m end }
SlashCmdList = {}
ITEM_QUALITY_COLORS = { [0] = { r = 0.62, g = 0.62, b = 0.62 }, [1] = { r = 1, g = 1, b = 1 }, [2] = { r = 0.12, g = 1, b = 0 }, [3] = { r = 0, g = 0.44, b = 0.87 }, [4] = { r = 0.64, g = 0.21, b = 0.93 } }
Enum = { LootSlotType = { None = 0, Item = 1, Money = 2, Currency = 3 } }

-- Loot
local loot = {}
local looted, closed = {}, 0
function GetNumLootItems() return #loot end
function LootSlotHasItem(i) return loot[i] ~= nil and not loot[i].gone end
function GetLootSlotInfo(i) local l = loot[i]; if not l or l.gone then return nil end; return l.icon, l.name, l.count, nil, l.q, l.locked, l.quest, l.qid, l.active end
function GetLootSlotType(i) return loot[i] and loot[i].money and 2 or 1 end
function GetLootSlotLink(i) return "|Hitem:" .. i .. "|h" end
function LootSlot(i) looted[#looted + 1] = i end
function CloseLoot() closed = closed + 1 end
local modified, handledLink = false, nil
function IsModifiedClick() return modified end
function HandleModifiedItemClick(l) handledLink = l; return true end
local cvar = false
function GetCVarBool() return cvar end
function GetCursorPosition() return 500, 400 end
function UnitExists() return true end
function UnitIsDead() return true end
function UnitName() return "Mottled Boar" end
function GetItemInfo(id) return "Item" .. id, nil, id == 774 and 2 or 1, nil, nil, nil, nil, nil, nil, "icon" .. id end
LootFrame = new("Frame", "LootFrame")
for _, e in ipairs({ "LOOT_OPENED", "LOOT_SLOT_CLEARED", "LOOT_SLOT_CHANGED", "LOOT_CLOSED", "OPEN_MASTER_LOOT_LIST" }) do LootFrame:RegisterEvent(e) end
LootFrame.scripts.OnEvent = function() LootFrame.blizzShown = true end

-- Minimap world
Minimap = new("Minimap", "Minimap")
MinimapCluster = new("Frame", "MinimapCluster")
function MinimapCluster:UpdateMinimapConfig() Minimap:SetMaskTexture("ui-hud-minimap-frame-generic-mask") end
MinimapCluster.MinimapContainer = new("Frame")
MinimapCluster.MinimapContainer.PlayerCoords = new("Frame")
local hideNames = { "MinimapBorder", "MinimapBorderTop", "MinimapZoomIn", "MinimapZoomOut", "MiniMapWorldMapButton", "MinimapZoneTextButton", "GameTimeFrame", "MinimapToggleButton" }
for _, n in ipairs(hideNames) do new("Frame", n) end
MinimapBackdrop = new("Frame", "MinimapBackdrop")
local backdropArt = MinimapBackdrop:CreateTexture()
MiniMapMailFrame = new("Frame", "MiniMapMailFrame")
MiniMapTrackingFrame = new("Frame", "MiniMapTrackingFrame")
function GetZonePVPInfo() return "friendly" end
function GetMinimapZoneText() return "Razor Hill" end
C_Map = { GetBestMapForUnit = function() return 1411 end, GetPlayerMapPosition = function() return { x = 0.523, y = 0.414 } end }
local worldMap = 0
function ToggleWorldMap() worldMap = worldMap + 1 end
local trackingMenu
MiniMapTrackingDropDown = {}
function ToggleDropDownMenu(_, _, menu, anchor) trackingMenu = anchor end


-- Bags world
function Mock:SetID(i) self.id = i end
function Mock:GetID() return self.id end
function Mock:SetFont(path, size, flags) self.font = { path, size, flags } end
function Mock:GetFont() return self.font and self.font[1] end
function Mock:SetDrawLayer(l, s) self.layer = l; self.sub = s end
function Mock:GetAlpha() return self.alpha end
function Mock:GetHighlightTexture() self.hlTex = self.hlTex or new("Texture"); return self.hlTex end
function Mock:GetPushedTexture() self.pushTex = self.pushTex or new("Texture"); return self.pushTex end
function Mock:ClearNormalTexture() self.normalCleared = true end
function Mock:IsProtected() return false end
function Mock:GetObjectType() return self.kind end
function Mock:SetAttribute(k, v) self.attrs = self.attrs or {}; self.attrs[k] = v end
function Mock:SetUnit(u) self.modelUnit = u end
function Mock:SetCreature(id) self.modelCreature = id end
function Mock:SetScale(s) self.scale = s end
local baseCreate = CreateFrame
function CreateFrame(kind, name, parent, template)
  local f = baseCreate(kind, name, parent)
  f.tmpl = template
  if template == "ContainerFrameItemButtonTemplate" then
    f.icon = f:CreateTexture()
    f.Count = f:CreateFontString()
    f.IconBorder = f:CreateTexture()
    f.Cooldown = new("Cooldown")
    f.template = true
  end
  return f
end
-- As the game does it: the whole texture (crop reset), and its slot picture when empty.
function SetItemButtonTexture(b, t) b.icon.tex = t or "bags-item-slot64"; b.icon.texCoord = { 0, 1, 0, 1 }; b.icon.shown = true end
function SetItemButtonCount(b, c) b.Count.text = (c and c > 1) and tostring(c) or "" end
function SetItemButtonDesaturated(b, d) b.desat = d end
function CooldownFrame_Set(cd, s, d, e) cd.cd = { s, d, e } end
local inCombat = false
function InCombatLockdown() return inCombat end
C_AddOns = { IsAddOnLoaded = function(n) return false end }
NUM_BAG_SLOTS, NUM_BANKBAGSLOTS, BANK_CONTAINER = 4, 6, -1
NUM_TOTAL_EQUIPPED_BAG_SLOTS = 5
Enum.BagIndex = { ReagentBag = 5 }
local BAGS = { [0] = {}, [1] = {}, [-1] = {} }
local SIZES = { [0] = 16, [1] = 10, [2] = 0, [3] = 0, [4] = 0, [-1] = 24 }
BAG_FAMILIES, BAG_NAMES = { [0] = 0 }, {} -- globals: the main chunk is near Lua's limit of 200 locals
local ITEMS = {
  [6948] = { "Hearthstone", 15, 0, 1 }, [2589] = { "Linen Cloth", 7, 5, 1 }, [774] = { "Malachite", 7, 7, 2 },
  [818] = { "Tigerseye", 7, 7, 2 }, [25] = { "Worn Shortsword", 2, 7, 1 }, [2138] = { "Sharpened Letter Opener", 2, 15, 2 },
  [117] = { "Tough Jerky", 0, 0, 1 }, [4865] = { "Ruined Pelt", 15, 0, 0 }, [5571] = { "Small Black Pouch", 1, 0, 1 },
  [4881] = { "Aged Envelope", 12, 0, 1 }, [6145] = { "Clarice's Pendant", 4, 2, 4 },
}
local function put(bag, slot, id, count, extra)
  local d = ITEMS[id]
  BAGS[bag][slot] = { iconFileID = "icon" .. id, stackCount = count or 1, quality = d[4], itemID = id, hyperlink = "item:" .. id, isLocked = false }
  if extra then for k, v in pairs(extra) do BAGS[bag][slot][k] = v end end
end
put(0, 1, 6948); put(0, 2, 2589, 12); put(0, 3, 774); put(0, 4, 25); put(0, 5, 117, 5); put(0, 6, 4865, 2)
put(0, 8, 2138); put(0, 9, 818); put(1, 1, 5571); put(1, 3, 4881, 1, { quest = { isQuestItem = true, questID = 123, isActive = false } }); put(1, 4, 6145)
C_Container = {
  GetContainerNumSlots = function(b) return SIZES[b] or 0 end,
  GetContainerNumFreeSlots = function(b) return 0, BAG_FAMILIES[b] end,
  GetBagName = function(b) return BAG_NAMES[b] end,
  GetContainerItemInfo = function(b, s) return BAGS[b] and BAGS[b][s] end,
  GetContainerItemQuestInfo = function(b, s) local i = BAGS[b] and BAGS[b][s]; return i and i.quest or { isQuestItem = false } end,
  GetContainerItemCooldown = function() return 0, 0, 1 end,
  SortBags = function() sorted = true end,
}
C_Item = {
  GetItemInfoInstant = function(id) local d = ITEMS[id]; if not d then return nil end; return id, d[2] == 7 and "Trade Goods" or "Thing", d[2] == 7 and "Metal & Stone" or "Sub", "", "icon", d[2], d[3] end,
  GetItemInfo = function(id) local d = ITEMS[id]; return d and d[1] end,
  GetDetailedItemLevelInfo = function() return 11 end,
}
function GetMoney() return 123456 end
function GetCoinTextureString(m) return "12g 34s 56c" end
local bankClosed = 0
function CloseBankFrame() bankClosed = bankClosed + 1 end
BankFrame = new("Frame", "BankFrame")
BankFrame:RegisterEvent("BANKFRAME_OPENED")
BankFrame.scripts.OnEvent = function() BankFrame.blizzOpened = true end
ContainerFrame1 = new("Frame", "ContainerFrame1")
ContainerFrameCombinedBags = new("Frame", "ContainerFrameCombinedBags")
PlaySound = function() end
-- The game's bag functions, which call each other just as the real ones do.
gameBags = { open = false, ran = {} }
function gameBagRan(name) gameBags.ran[name] = (gameBags.ran[name] or 0) + 1 end
function OpenBackpack() gameBagRan("OpenBackpack"); gameBags.open = true end
function CloseBackpack() gameBagRan("CloseBackpack"); gameBags.open = false end
function OpenBag() gameBagRan("OpenBag"); gameBags.open = true end
function CloseBag() gameBagRan("CloseBag") end
function OpenAllBags()
  gameBagRan("OpenAllBags")
  if gameBags.open then return end
  OpenBackpack()
  for i = 1, 4 do OpenBag(i) end
end
function CloseAllBags()
  gameBagRan("CloseAllBags")
  CloseBackpack()
  for i = 1, 4 do CloseBag(i) end
end
function ToggleAllBags()
  gameBagRan("ToggleAllBags")
  if gameBags.open then
    CloseBackpack()
    for i = 1, 4 do CloseBag(i) end
  else
    OpenBackpack()
    for i = 1, 4 do OpenBag(i) end
  end
end
function ToggleBackpack()
  gameBagRan("ToggleBackpack")
  if gameBags.open then CloseAllBags() else OpenBackpack() end
end
function ToggleBag(id)
  gameBagRan("ToggleBag")
  if gameBags.open then CloseAllBags() else OpenBag(id) end
end

-- Tooltips world
GameTooltip.NineSlice = new("Frame")
function GameTooltip:GetName() return "GameTooltip" end
GameTooltip.nlines = 0
function GameTooltip:NumLines() return self.nlines end
function GameTooltip:AddDoubleLine(a, b) self.dlines = self.dlines or {}; table.insert(self.dlines, { a, b }) end
local tipItem
function GameTooltip:GetItem() return tipItem and tipItem[1], tipItem and tipItem[2] end
ItemRefTooltip = new("GameTooltip", "ItemRefTooltip")
ItemRefTooltip.SetBackdropColor = function(self, r, g, b, a) self.bd = { r, g, b, a } end
ItemRefTooltip.SetBackdropBorderColor = function(self, r, g, b, a) self.bdb = { r, g, b, a } end
GameTooltipStatusBar = new("StatusBar", "GameTooltipStatusBar")
GameTooltipStatusBar.SetStatusBarTexture = function(self, t) self.sbt = t end
GameTooltipHeaderText = new("Font", "GameTooltipHeaderText")
GameTooltipText = new("Font", "GameTooltipText")
GameTooltipTextSmall = new("Font", "GameTooltipTextSmall")
Enum.TooltipDataType = { Item = 0, Unit = 2 }
local postCalls, unitPostCalls = {}, {}
TooltipDataProcessor = { AddTooltipPostCall = function(kind, fn) table.insert(kind == 2 and unitPostCalls or postCalls, fn) end }
local dropRecord = { -- another add-on's loot record (FUI:SetDropRecord, called once VoltUI has loaded)
  n3129 = { name = "Kul Tiras Marine", loots = 10, it = { ["5469"] = { seen = 1 }, ["2589"] = { seen = 4 } } },
  n3128 = { name = "Kul Tiras Sailor", loots = 23, it = { ["2589"] = { seen = 6 } } },
  o106318 = { name = "Node: Refreshing Spring Water", loots = 4, it = { ["2589"] = { seen = 2 } } },
}
-- Unit frames world
function Mock:SetStatusBarTexture(t) self.sbt = t end
function Mock:GetStatusBarTexture() self.fill = self.fill or new("Texture", nil, self); return self.fill end
function Mock:SetMinMaxValues(a, b) self.minv, self.maxv = a, b end
function Mock:SetValue(v) self.value = v end
function Mock:SetVertexColor(r, g, b, a) self.vc = { r, g, b, a } end
function Mock:GetThumbTexture() self.thumb = self.thumb or new("Texture", nil, self); return self.thumb end
function Mock:GetBottom() return 200 end
function Mock:SetParent(p) self.parent = p end
function Mock:GetParent() return self.parent end
function Mock:UnregisterAllEvents() for e in pairs(self.events) do self:UnregisterEvent(e) end; self.allOff = true end
function Mock:SetCooldown(s, d) self.cooldown = { s, d } end
function Mock:SetCooldownFromDurationObject(o) self.cooldownObj = o end
function Mock:SetTimerDuration(d, _, dir) self.timerDur, self.timerDir = d, dir end
function Mock:SetFormattedText(fmt, ...)
  for i = 1, select("#", ...) do
    if issecretvalue and issecretvalue((select(i, ...))) then self.text = "<secret>"; return end
  end
  self.text = fmt:format(...)
end
local unitWatch = {}
function RegisterUnitWatch(f) unitWatch[f] = true end
function UnregisterUnitWatch(f) unitWatch[f] = nil end
RAID_CLASS_COLORS = { SHAMAN = { r = 0, g = 0.44, b = 0.87 }, ROGUE = { r = 1, g = 0.96, b = 0.41 } }
DebuffTypeColor = { Magic = { r = 0.2, g = 0.6, b = 1 } }
Enum.PowerType = { ComboPoints = 14 }
function GetCreatureDifficultyColor() return { r = 1, g = 1, b = 0 } end
local UNITS
local function unitInfo(u) return UNITS and UNITS[u] or {} end
local castInfo, chanInfo = {}, {}
local playerClass, combo = "SHAMAN", 0
local unitApi = {
  UnitHealth = function(u) return unitInfo(u).hp or 100 end,
  UnitHealthMax = function(u) return unitInfo(u).hpMax or 100 end,
  UnitPower = function(u, k) if k == 14 then return combo end; return unitInfo(u).pw or 50 end,
  UnitPowerMax = function(u, k) if k == 14 then return 5 end; return unitInfo(u).pwMax or 100 end,
  UnitPowerType = function(u) local i = unitInfo(u); return i.pkind or 0, i.ptoken or "MANA" end,
  UnitLevel = function(u) return unitInfo(u).level or 7 end,
  UnitClass = function(u) local i = unitInfo(u); return "Class", i.class or playerClass end,
  UnitIsPlayer = function(u) return unitInfo(u).isPlayer end,
  UnitReaction = function(u) return unitInfo(u).reaction end,
  UnitIsTapDenied = function(u) return unitInfo(u).tapped end,
  UnitIsConnected = function(u) local c = unitInfo(u).connected; if c == nil then return true end; return c end,
  UnitIsGhost = function(u) return unitInfo(u).ghost end,
  UnitClassification = function(u) return unitInfo(u).classif or "normal" end,
  UnitAffectingCombat = function(u) return unitInfo(u).combat end,
  UnitIsGroupLeader = function(u) return unitInfo(u).lead end,
  UnitIsPVP = function(u) return unitInfo(u).pvp end,
  UnitIsEnemy = function(u) return unitInfo(u).enemy end,
  UnitIsFriend = function(u) return unitInfo(u).friend end,
  GetRaidTargetIndex = function(u) return unitInfo(u).raid end,
  SetRaidTargetIconTexture = function(t, i) t.raidIndex = i end,
  GetComboPoints = function() return combo end,
  IsResting = function() return UNITS and UNITS.resting end,
  UnitCastingInfo = function(u) local c = castInfo[u]; if c then local d = c.display; if d == nil then d = c.name end; return c.name, d, c.icon, c.st, c.en, false, c.guid, c.locked, c.spellID, c.barID end end,
  UnitChannelInfo = function(u) local c = chanInfo[u]; if c then local d = c.display; if d == nil then d = c.name end; return c.name, d, c.icon, c.st, c.en, false, c.locked, c.spellID, false, 0, c.barID end end,
  BreakUpLargeNumbers = function(v) if issecretvalue and issecretvalue(v) then return v end; return tostring(v) end,
}
unitApi.UnitGUID = function(u) return u end
unitApi.UnitIsVisible = function() return true end
for k, fn in pairs(unitApi) do if _G[k] == nil then _G[k] = fn end end
PlayerFrame = new("Frame", "PlayerFrame")
PlayerFrame:RegisterEvent("UNIT_HEALTH")
PlayerFrame.healthbar = new("StatusBar"); PlayerFrame.healthbar:RegisterEvent("UNIT_HEALTH")
TargetFrame = new("Frame", "TargetFrame")
TargetFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
PetFrame = new("Frame", "PetFrame")
TargetFrameToT = new("Frame", "TargetFrameToT")
TargetFrameSpellBar = new("StatusBar", "TargetFrameSpellBar")
ComboFrame = new("Frame", "ComboFrame")
TotemFrame = new("Frame", "TotemFrame")
-- the game's own: each time it shows, back inside the player frame it goes
TotemFrame:SetScript("OnShow", function(self) self:SetParent(PlayerFrame) end)
PlayerCastingBarFrame = new("StatusBar", "PlayerCastingBarFrame")
PlayerCastingBarFrame:RegisterEvent("UNIT_SPELLCAST_START")
function PlayerCastingBarFrame:SetUnit(u) self.barUnit = u or "none" end
for _, b in ipairs({ PlayerFrame, TargetFrame, PetFrame, TargetFrameToT }) do unitWatch[b] = true end

-- Action bars world
local stateDrivers, attrDrivers = {}, {}
local function barStateDriver(f, kind, v) stateDrivers[f] = stateDrivers[f] or {}; stateDrivers[f][kind] = v end
RegisterStateDriver = barStateDriver
local function barStateDriverOff(f, kind) if stateDrivers[f] then stateDrivers[f][kind] = nil end end
UnregisterStateDriver = barStateDriverOff
function RegisterAttributeDriver(f, kind, v) attrDrivers[f] = attrDrivers[f] or {}; attrDrivers[f][kind] = v end
function Mock:GetAttribute(k) return self.attrs and self.attrs[k] end
function Mock:SetAttributeNoHandler(k, v) self.attrs = self.attrs or {}; self.attrs[k] = v end
function Mock:WrapScript(f, script, pre) f.wrapped = f.wrapped or {}; f.wrapped[script] = pre end
function Mock:SetJustifyH(j) self.justify = j end
function Mock:SetTexCoord(...) self.texCoord = { ... } end
function Mock:RemoveMaskTexture(t) self.maskRemoved = t end
function Mock:GetCheckedTexture() self.checkTex = self.checkTex or new("Texture"); return self.checkTex end
function Mock:SetChecked(v) self.checked = v end
function Mock:SetHideCountdownNumbers(v) self.hideNumbers = v end
function Mock:SetCountdownFont(n) self.countdownFont = n end
function Mock:SetSwipeColor(...) self.swipe = { ... } end
function Mock:Clear() self.cleared = true end
function Mock:SetFrameStrata(s) self.strata = s end
function Mock:EnableMouse(v) self.mouseOn = v end
function Mock:SetBagID(id) self.bagID = id end -- as the game's own: VoltUI must never call this
function Mock:GetStringWidth() return #(self.text or "") * 6 end
local baseHook = hooksecurefunc
hookedGlobals = {}
function hooksecurefunc(t, k, fn)
  if type(t) == "string" then
    hookedGlobals[t] = true
    return baseHook(_G, t, k)
  end
  return baseHook(t, k, fn)
end
local barKeys, barActions, equipped = {}, {}, {}
local boundKeys, bindCalls = {}, 0
function GetBindingKey(cmd) return unpack(barKeys[cmd] or {}) end
function SetOverrideBindingClick(owner, _, key, name, button) bindCalls = bindCalls + 1; boundKeys[key] = { owner = owner, name = name, button = button } end
function ClearOverrideBindings(owner) for k, v in pairs(boundKeys) do if v.owner == owner then boundKeys[k] = nil end end end
function HasAction(slot) return barActions[slot] == true end
function IsEquippedAction(slot) return equipped[slot] == true end
local barToggles = { true, false, false, false }
function GetActionBarToggles() return unpack(barToggles) end
function CreateFont(name) local f = new("Font", name); return f end
local forms = {}
function GetNumShapeshiftForms() return #forms end
function GetShapeshiftFormInfo(i) local x = forms[i]; if x then return x.icon, x.active, x.castable end end
function GetShapeshiftFormCooldown(i) local x = forms[i]; if x then return x.cdStart or 0, x.cdDur or 0, 1 end end
local petActions = {}
function GetPetActionInfo(i) return petActions[i] end
NUM_PET_ACTION_SLOTS = 10
local function actionButtonParts(f)
  f.icon = f:CreateTexture()
  f.IconMask = f:CreateTexture()
  f.NormalTexture = f:CreateTexture()
  f.SlotArt, f.SlotBackground, f.Border, f.Flash = f:CreateTexture(), f:CreateTexture(), f:CreateTexture(), f:CreateTexture()
  f.SpellHighlightTexture, f.NewActionTexture = f:CreateTexture(), f:CreateTexture()
  f.SpellCastAnimFrame, f.InterruptDisplay = new("Frame", nil, f), new("Frame", nil, f)
  f.HotKey, f.Count, f.Name = f:CreateFontString(), f:CreateFontString(), f:CreateFontString()
  f.cooldown = new("Cooldown", nil, f)
  f.buttonNormal = f:CreateTexture() -- not always the same texture as the NormalTexture key
  f.GetNormalTexture = function(self) return self.buttonNormal end
end
local baseCreate2 = CreateFrame
function CreateFrame(kind, name, parent, template, id)
  local f = baseCreate2(kind, name, parent, template)
  if template == "ActionBarButtonTemplate" or template == "StanceButtonTemplate" then
    actionButtonParts(f)
    if id then f.id = id end
    f.GetName = function() return name end
    if template == "ActionBarButtonTemplate" then
      f.updates, f.usables = 0, 0
      f.Update = function(self) self.updates = self.updates + 1 end
      f.UpdateUsable = function(self) self.usables = self.usables + 1; self.icon:SetVertexColor(1, 1, 1) end
      -- Called from add-on code, this would write what it finds on the button as VoltUI's.
      f.UpdateFlyout = function(self) self.flyoutUpdates = (self.flyoutUpdates or 0) + 1 end
    end
  end
  return f
end
-- The game's aura container (1.101.24). This pretend client hasn't got one unless a test
-- says so, so the target's own aura row is still what the older tests see.
auraContainerWorld = nil
do
  local create = CreateFrame
  function CreateFrame(kind, name, parent, template, id)
    if kind == "AuraContainer" then
      if not auraContainerWorld then error("Unknown frame type: AuraContainer") end
      local c = create("Frame", name, parent, template)
      c.groups, c.calls = {}, {}
      c.AddAuraGroup = function(self, key, filter, options)
        self.groups[#self.groups + 1] = { key = key, filter = filter, options = options }
        -- the game makes a batch of buttons up front and hands each to the add-on
        for _ = 1, 2 do
          local b = create("Frame", nil, self)
          b.SetIcon = function(btn, tex) btn.iconSet = tex end
          b.SetDurationCooldown = function(btn, cd) btn.cdSet = cd end
          b.SetApplicationCount = function(btn, fs) btn.countSet = fs end
          options.initializeFrame(b)
          self.buttons = self.buttons or {}
          self.buttons[#self.buttons + 1] = b
        end
      end
      c.SetAuraGroupLayout = function(self, key, layout) self.calls[#self.calls + 1] = key .. ":" .. tostring(layout.elementWidth) end
      c.SetUnit = function(self, unit) self.unit = unit end
      c.SetFlowLayoutAnchorPoint = function(self, p) self.flowAnchor = p end
      c.SetFlowLayoutGrowthDirection = function(self, h, v) self.flowDir = { h, v } end
      c.SetFlowLayoutMaximumLineSize = function(self, w) self.lineSize = w end
      return c
    end
    return create(kind, name, parent, template, id)
  end
end
MainActionBar = new("Frame", "MainActionBar")
MainActionBar:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
MainActionBar.actionButtons = {}
-- The game makes each bar's buttons itself, with what its own code reads already on them.
-- The VoltUI names below are what the tests call them, for which bar they're on.
local function gameButtons(bar, prefix, voltBar, command, base)
  for i = 1, 12 do
    local b = CreateFrame("CheckButton", prefix .. i, bar, "ActionBarButtonTemplate", i)
    b.bar, b.index, b.commandName, b.action = bar, i, command .. i, base + i
    b:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
    -- The handled way runs the game's code as whoever called it.
    b.handled = 0
    b.SetAttribute = function(self, k, v) self.handled = self.handled + 1; Mock.SetAttribute(self, k, v) end
    bar.actionButtons[i] = b
    _G["VoltUIBar" .. voltBar .. "Button" .. i] = b
  end
end
gameButtons(MainActionBar, "ActionButton", 1, "ACTIONBUTTON", 0)
for _, g in ipairs({
  { "MultiBarBottomLeft", 2, "MULTIACTIONBAR1BUTTON", 60 }, { "MultiBarBottomRight", 3, "MULTIACTIONBAR2BUTTON", 48 },
  { "MultiBarRight", 4, "MULTIACTIONBAR3BUTTON", 24 }, { "MultiBarLeft", 5, "MULTIACTIONBAR4BUTTON", 36 },
  { "MultiBar5", 6, "MULTIACTIONBAR5BUTTON", 144 }, { "MultiBar6", 7, "MULTIACTIONBAR6BUTTON", 156 },
}) do
  local bar = new("Frame", g[1])
  bar:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
  bar.actionButtons = {}
  gameButtons(bar, g[1] .. "Button", g[2], g[3], g[4])
end
StanceBar = new("Frame", "StanceBar")
StanceBar:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
StanceBar.actionButtons = { new("CheckButton", "StanceButton1") }
PetActionBar = new("Frame", "PetActionBar")
PetActionBar:RegisterEvent("PET_BAR_UPDATE")
PetActionBar.scripts.OnEvent = function() end
MainActionBar.scripts.OnEvent = function() end
PetActionBar.actionButtons = {}
for i = 1, 10 do
  local b = new("CheckButton", "PetActionButton" .. i, PetActionBar)
  actionButtonParts(b)
  b.id = i
  PetActionBar.actionButtons[i] = b
end
OverrideActionBar = new("Frame", "OverrideActionBar")
OverrideActionBarButton1 = new("CheckButton", "OverrideActionBarButton1")
OverrideActionBarButton1.IsVisible = function() return false end
MultiCastActionBarFrame = new("Frame", "MultiCastActionBarFrame")
MultiCastActionBarFrame.w, MultiCastActionBarFrame.h = 230, 40
MultiCastActionBarFrame.numActiveSlots = 0
local function namedButton(name, parent)
  local b = new("CheckButton", name, parent)
  b.GetName = function() return name end
  return b
end
local function totemButton(name, parent)
  local b = namedButton(name, parent)
  actionButtonParts(b)
  b.overlayTex = b:CreateTexture()
  return b
end
MultiCastSummonSpellButton = totemButton("MultiCastSummonSpellButton", MultiCastActionBarFrame)
MultiCastRecallSpellButton = totemButton("MultiCastRecallSpellButton", MultiCastActionBarFrame)
new("Texture", "MultiCastRecallSpellButtonHighlight")
for i = 1, 4 do
  local slot = namedButton("MultiCastSlotButton" .. i, MultiCastActionBarFrame)
  slot.background, slot.overlayTex = slot:CreateTexture(), slot:CreateTexture()
end
for i = 1, 12 do totemButton("MultiCastActionButton" .. i, MultiCastActionBarFrame) end
MultiCastFlyoutFrame = new("Frame", "MultiCastFlyoutFrame", MultiCastActionBarFrame)
MultiCastFlyoutFrame.top, MultiCastFlyoutFrame.middle = MultiCastFlyoutFrame:CreateTexture(), MultiCastFlyoutFrame:CreateTexture()
MultiCastFlyoutFrame.buttons = {}
function MultiCastActionButton_Update() end
function MultiCastFlyoutFrame_ToggleFlyout() end
-- What the game does when the totem slots change: it points two of the buttons somewhere new.
function MultiCastActionBarFrame_Update(self)
  MultiCastSlotButton1:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 41, 3)
  MultiCastRecallSpellButton:SetPoint("LEFT", MultiCastSlotButton4, "RIGHT", 8, 0)
end
-- The XP and reputation numbers.
local xpNow = { value = 300, top = 1000, rested = 200, show = true }
local watched = nil
function UnitXP() return xpNow.value end
function UnitXPMax() return xpNow.top end
function GetXPExhaustion() return xpNow.rested end
GameRulesUtil = { CanShowExperienceBar = function() return xpNow.show end }
C_Reputation = { GetWatchedFactionData = function() return watched end }
FACTION_BAR_COLORS = { [5] = { r = 0, g = 0.6, b = 0.1 } }
FACTION_STANDING_LABEL5 = "Friendly"
StatusTrackingBarManager = new("Frame", "StatusTrackingBarManager", UIParent)
StatusTrackingBarManager:RegisterEvent("PLAYER_XP_UPDATE")
-- The game's quick keybind mode. Closing it opens the game's settings.
QuickKeybindFrame = new("Button", "QuickKeybindFrame", UIParent)
QuickKeybindFrame.shown = false
SettingsPanel = new("Frame", "SettingsPanel", UIParent)
SettingsPanel.shown = false
QuickKeybindFrame.scripts.OnHide = function() SettingsPanel:Show() end
function QuickKeybindFrame:CancelBinding() self.cancelled = true; self:Hide() end
function HideUIPanel(f) f:Hide() end
MicroMenuContainer = new("Frame", "MicroMenuContainer", UIParent)
MicroMenu = new("Frame", "MicroMenu", MicroMenuContainer)
function MicroMenu:GetParent() return self.parent end
function MicroMenu:SetParent(p) self.parent = p end
local microRules = {}
local function microButton(name)
  local b = namedButton(name, MicroMenu)
  b.w, b.h = 32, 40
  b.Background, b.PushedBackground, b.FlashBorder = b:CreateTexture(), b:CreateTexture(), b:CreateTexture()
  b.normalArt, b.disabledArt = b:CreateTexture(), b:CreateTexture()
  b.GetNormalTexture = function(self) return self.normalArt end
  b.GetDisabledTexture = function(self) return self.disabledArt end
  b.FlashContent = b:CreateTexture()
  -- The game anchors the art again whenever a button changes state.
  b.SetNormal = function(self) self.normalArt:ClearAllPoints(); self.normalArt:SetPoint("TOPLEFT"); self.state = "normal" end
  b.SetPushed = function(self) self.normalArt:ClearAllPoints(); self.normalArt:SetPoint("TOPLEFT"); self.state = "pushed" end
  return b
end
for _, n in ipairs({ "CharacterMicroButton", "QuestLogMicroButton", "EJMicroButton", "HelpMicroButton", "StoreMicroButton", "MainMenuMicroButton" }) do
  microButton(n)
end
CharacterMicroButton.Shadow, CharacterMicroButton.PushedShadow = CharacterMicroButton:CreateTexture(), CharacterMicroButton:CreateTexture()
CharacterMicroButton.Portrait, CharacterMicroButton.PortraitMask = CharacterMicroButton:CreateTexture(), CharacterMicroButton:CreateTexture()
MainMenuMicroButton.MainMenuBarPerformanceBar = MainMenuMicroButton:CreateTexture()
HelpOpenWebTicketButton = new("Frame", "HelpOpenWebTicketButton")
MicroMenu.GenerateButtonInfos = function()
  return {
    { button = CharacterMicroButton }, { button = QuestLogMicroButton },
    { button = EJMicroButton, callback = function() return microRules.ej end },
    { button = HelpMicroButton }, { button = StoreMicroButton }, { button = MainMenuMicroButton },
  }
end
MicroMenu.UpdateHelpTicketButtonAnchor = function() end
BagsBar = new("Frame", "BagsBar", UIParent)
local function bagButton(name)
  local b = namedButton(name, BagsBar)
  b.w, b.h = 45, 45
  b.icon = b:CreateTexture()
  b.SquareMask, b.IconBorder, b.IconOverlay = b:CreateTexture(), b:CreateTexture(), b:CreateTexture()
  b.SlotHighlightTexture = b:CreateTexture()
  b.Count = b:CreateFontString()
  b.art = b:CreateTexture()
  -- As in the game: once this texture is moved off the button, the button has none.
  b.GetNormalTexture = function(self)
    if self.art.parent == nil or self.art.parent == self then return self.art end
  end
  -- What the game does on any bag change: back to its own art.
  b.UpdateTextures = function(self)
    self:GetNormalTexture().atlas = "game"
    self:GetHighlightTexture().atlas = "game"
    self:GetHighlightTexture().ctex = nil
    self:GetPushedTexture().ctex = nil
  end
  return b
end
for _, n in ipairs({ "KeyRingButton", "CharacterReagentBag0Slot", "CharacterBag3Slot", "CharacterBag2Slot", "CharacterBag1Slot", "CharacterBag0Slot", "MainMenuBarBackpackButton" }) do
  bagButton(n)
end
MainMenuBarBackpackButton.FreeSlots = MainMenuBarBackpackButton:CreateFontString()
MainMenuBarBackpackButton.SetCountShown = function(self, v) self.countShown = v end
NUM_BAG_SLOTS = 4
C_ActionBar = { ShouldShowKeyring = function() return true end }
-- What the game does when you pick up an item: it lays the bag buttons out again.
BagsBar.Layout = function(self)
  MainMenuBarBackpackButton:ClearAllPoints()
  MainMenuBarBackpackButton:SetPoint("RIGHT", self, "RIGHT")
end
local unregistered = {}
EventRegistry = { UnregisterCallback = function(_, ev, owner) unregistered[ev] = owner end }
ActionButtonSpellAlertManager = { alerts = {}, ShowAlert = function(self, b) self.alerts[b] = true end, HideAlert = function(self, b) self.alerts[b] = nil end }
ActionButton_UpdateCooldownNumberHidden = function(b) b.cooldown:SetHideCountdownNumbers(true) end
barKeys.ACTIONBUTTON1 = { "1", "F1" }
barKeys.ACTIONBUTTON2 = { "SHIFT-MOUSEWHEELUP" }
barKeys.MULTIACTIONBAR1BUTTON2 = { "SHIFT-Q" }
barActions[1] = true
barActions[49] = true -- something on bar 3, which the game has hidden

function SetItemRef() end -- the game's handler for a clicked chat link
-- load
local ns = {}
for line in io.lines(DIR .. "/VoltUI.toc") do
  if line:match("%.lua$") then
    local fn, err = loadfile(DIR .. "/" .. line)
    if fn then fn("VoltUI", ns) else error(err) end
  end
end
fire("ADDON_LOADED", "VoltUI")
ns.FUI:SetDropRecord(function() return dropRecord end)
Extra("load", { ns = ns, fire = fire, Mock = Mock, new = new, runTimers = runTimers, DIR = DIR }) -- another add-on that needs VoltUI loads after it, as in the game
fire("PLAYER_LOGIN")
check(VoltUIDB and VoltUIDB.alpha == 0.85 and VoltUIDB.loot and VoltUIDB.map, "defaults")

print("== Loot")
local f = VoltUILoot
check(f and not f.shown, "loot window made, hidden")
check(not LootFrame.events.LOOT_OPENED and LootFrame.events.OPEN_MASTER_LOOT_LIST, "Blizzard's loot window stops listening (master loot untouched)")
check(UISpecialFrames[1] == "VoltUILoot", "Esc closes it")
check(f.fuiPanel.fill.ctex[1] == 0.04 and f.fuiPanel.edges[1].ctex[1] == 0.35, "VoltUI's panel colours")
loot = {
  { icon = "i1", name = "Ruined Leather Scraps", count = 1, q = 1 },
  { icon = "i2", name = "Malachite", count = 1, q = 2 },
  { icon = "c", name = "12 Copper\n", money = true },
  { icon = "i4", name = "Scorpid Tail", count = 3, q = 1, quest = true },
  { icon = "i5", name = "Grimy Note", count = 1, q = 1, quest = true, qid = 900, active = false },
  { icon = "i6", name = "Sword", count = 1, q = 4, locked = true },
}
fire("LOOT_OPENED")
check(f.shown and not LootFrame.blizzShown, "opens on loot, Blizzard's stays closed")
check(f.title.text == "Mottled Boar", "title is the corpse's name")
local L = ns.Loot
local r = L.rows
check(r[1].name.text == "Ruined Leather Scraps" and r[1].name.color[1] == 1, "common item, white name")
check(r[2].name.color[2] == 1 and r[2].glow.edges[1].ctex[2] == 1 and r[2].glow.glow[1].shown ~= false, "uncommon: green name, outline and glow")
check(r[1].glow.edges[1].ctex[1] == 0.35 and r[1].glow.glow[1].shown == false, "common: no glow by default")
check(r[3].name.text == "12 Copper ", "coins on one line")
check(r[4].tag.text:find("Quest") and r[4].count.text == 3, "quest item tagged, stack count")
check(r[5].tag.text:find("Starts a quest"), "quest starters tagged")
check(r[6].icon.desat and r[6].name.color[1] == 0.6, "locked items dimmed")
check(r[6].glow.edges[1].ctex[1] == 0.64, "epic purple outline")
check(f.h == 24 + 2 + 6 * 30 + 8, "height fits the rows: " .. tostring(f.h))
r[2].scripts.OnClick(r[2])
check(looted[#looted] == 2, "click loots the slot")
modified = true
r[2].scripts.OnClick(r[2])
modified = false
check(handledLink and handledLink:find("item:2"), "shift-click links")
r[1].scripts.OnEnter(r[1])
check(GameTooltip.lootSlot == 1, "tooltip")
loot[2].gone = true
fire("LOOT_SLOT_CLEARED", 2)
check(#L:Read() == 5 and r[6].shown == false and r[2].name.text == "Coins" or r[2].name.text == "12 Copper ", "cleared slot drops out, rest move up")
looted = {}
f.all.scripts.OnClick(f.all)
check(#looted == 4, "All loots everything not locked (" .. #looted .. ")")
f.close.scripts.OnClick(f.close)
check(closed == 1, "x closes loot")
fire("LOOT_CLOSED")
check(not f.shown and closed == 1, "closes with the game, no double close")
fire("LOOT_OPENED")
f:Hide() -- Esc
check(closed == 2, "Esc closes loot")
fire("LOOT_CLOSED")
cvar = true
fire("LOOT_OPENED")
local p = f.points[1]
check(p and p[4] == 470, "under the mouse when that option is on")
fire("LOOT_CLOSED")
loot = {}
SlashCmdList.VOLTUI("test")
check(f.shown and f.title.text == "Sample loot" and #L.items == 10, "/fui test shows a sample")
local c0 = closed
r[1].scripts.OnClick(r[1])
check(#looted == 4, "sample rows don't loot")
-- 1.41.0: more items than rows scroll, and the window has a size
;(function()
  local function lit() local n = 0; for _, row in ipairs(L.rows) do if row.shown then n = n + 1 end end return n end
  check(lit() == 8 and f.more.shown and f.more.text:find("1-8 of 10", 1, true), "ten items: eight rows, and a line saying so: " .. tostring(f.more.text))
  check(f.h == 24 + 2 + 8 * 30 + 18 + 8, "no taller than eight rows and that line: " .. tostring(f.h))
  local first = L.rows[1].name.text
  f.scripts.OnMouseWheel(f, -1)
  check(L.offset == 1 and L.rows[1].name.text ~= first and f.more.text:find("2-9 of 10", 1, true), "the wheel moves down through them")
  f.scripts.OnMouseWheel(f, -1)
  f.scripts.OnMouseWheel(f, -1)
  check(L.offset == 2 and f.more.text:find("3-10 of 10", 1, true) and L.rows[8].slot == 10, "and stops at the end; a row still knows its own loot slot")
  f.scripts.OnMouseWheel(f, 1)
  f.scripts.OnMouseWheel(f, 1)
  f.scripts.OnMouseWheel(f, 1)
  check(L.offset == 0 and L.rows[1].name.text == first, "and back up to the top")
  local epic
  for _, row in ipairs(L.rows) do if row.shown and row.name.text == "Epic sample" then epic = row end end
  f.scripts.OnMouseWheel(f, -1); f.scripts.OnMouseWheel(f, -1)
  for _, row in ipairs(L.rows) do if row.shown and row.name.text == "Epic sample" then epic = row end end
  check(epic and epic.tag.text:find("31", 1, true), "gear shows its item level")
  VoltUIDB.lootIlvl = false
  L:Reshow()
  check(epic.tag.text == "", "unless that's switched off")
  VoltUIDB.lootIlvl = true
  VoltUIDB.lootRows, VoltUIDB.lootWidth, VoltUIDB.lootScale = 12, 300, 1.2
  L:Reshow()
  check(lit() == 10 and not f.more.shown and f.w == 300 and f.scale == 1.2, "rows, width and scale follow their settings")
  VoltUIDB.lootRows, VoltUIDB.lootWidth, VoltUIDB.lootScale = 8, 230, 1
  L:Reshow()
  check(lit() == 8 and f.w == 230, "and back")
end)()
f:Hide()
check(closed == c0 and L.offset == 0, "closing the sample doesn't touch real loot, and the next one starts at the top")

-- auto loot: nothing shows until what's left is known
loot = { { icon = "i1", name = "Linen Cloth", count = 1, q = 1 } }
fire("LOOT_OPENED", true)
check(not f.shown, "auto loot: no flash of the window")
loot[1].gone = true
runTimers()
check(not f.shown, "auto loot took it all: window never shows")
fire("LOOT_CLOSED")
loot = { { icon = "i1", name = "Linen Cloth", count = 1, q = 1, locked = true } }
fire("LOOT_OPENED", true)
runTimers()
check(f.shown, "auto loot left something: window shows it")
fire("LOOT_CLOSED")
print("== Minimap"); for _, m in ipairs(chat) do print("  chat: " .. m) end
check(Minimap.mask == "Interface\\Buttons\\WHITE8X8", "square mask")
check(GetMinimapShape() == "SQUARE", "other add-ons see a square map")
check(MinimapBorder.shown == false and MinimapZoomIn.shown == false and MinimapZoneTextButton.shown == false and GameTimeFrame.shown == false, "round border, zoom, zone banner, clock hidden")
MinimapZoomIn:Show()
check(MinimapZoomIn.shown == false, "and stay hidden")
check(backdropArt.alpha == 0 and MinimapBackdrop.shown, "round art faded, its buttons kept")
check(MiniMapMailFrame.shown and MiniMapMailFrame.points[1][1] == "TOPRIGHT", "mail icon kept, in the corner")
local strip = VoltUIMinimapStrip
ns.Minimap:UpdateText()
check(strip.zone.text == "Razor Hill" and strip.zone.font[1]:find("SpaceMono"), "the place name on its own row, in Space Mono")
check(tint(strip.mark)[2] == 1 and tint(strip.mark)[1] < 0.5, "a square before it in the territory's colour")
check(strip.coords.text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") == "52.3, 41.4", "coordinates: " .. tostring(strip.coords.text))
check(VoltUIMinimapMid and strip.coords.parent == VoltUIMinimapMid and VoltUIMinimapMid.hatch, "on the row under it (1.83.0), with a hatched strip")
strip.scripts.OnClick(strip)
check(worldMap == 1, "click the strip for the world map")
Minimap.scripts.OnMouseWheel(Minimap, 1)
check(Minimap.zoom == 1, "wheel zooms in")
Minimap.scripts.OnMouseWheel(Minimap, -1); Minimap.scripts.OnMouseWheel(Minimap, -1)
check(Minimap.zoom == 0, "and out, not past the limit")
-- 1.101.9: right and middle clicks are taken by a frame over the map, so the game's own
-- handler (which pings on any button) never sees them; the left button passes through
check(VoltUIMinimapClicks and VoltUIMinimapClicks.parent == Minimap and ns.Minimap.catch == VoltUIMinimapClicks, "a click catcher over the map")
Minimap.scripts.OnMouseUp(Minimap, "RightButton")
check(trackingMenu == nil, "the map's own handler no longer opens tracking (it would ping too)")
VoltUIMinimapClicks.scripts.OnMouseUp(VoltUIMinimapClicks, "RightButton")
check(trackingMenu == "cursor", "right-click opens tracking")
check(#ns.Minimap.edges == 4 and math.abs(ns.Minimap.edges[1].ctex[1] - 0.35) < 0.01, "1px border")
check(MinimapCluster.MinimapContainer.PlayerCoords.shown == false, "the game's own coordinates hidden, the strip has them")
MinimapCluster:UpdateMinimapConfig()
check(Minimap.mask == "Interface\\Buttons\\WHITE8X8", "turning on the rotating map keeps it square")

do
print("== Minimap holder")
local MM = ns.Minimap
local Hold = VoltUIMinimapHolder
local function lastPoint(f) return f.points[#f.points] end
check(Hold and MM.holder == Hold and Hold.parent == UIParent and Hold.strata == "LOW", "a holder for the map")
check(Minimap.parent == Hold, "the map moved into it")
local mp = lastPoint(Minimap)
check(mp[1] == "TOPLEFT" and mp[2] == Hold and mp[4] == 1 and mp[5] == -1, "inside its 1px border")
check(Hold.w == 200 and Hold.h == 253, "the map, its border, the two rows and the line of readouts: " .. tostring(Hold.w) .. "x" .. tostring(Hold.h))
check(MinimapCluster.mouseOn == false, "the game's empty cluster lets clicks through")
local hp = lastPoint(Hold)
check(hp[1] == "TOPRIGHT" and hp[2] == UIParent and hp[3] == "TOPRIGHT" and hp[4] == -18 and hp[5] == -43 and Hold.scale == 1, "where the game had it, at its normal size")
check(not VoltUIDB.minimapLeft and VoltUIDB.minimapScale == 1, "nothing saved until it's moved")
check(Hold.mover and not Hold.mover.shown and Hold.mover.strata == "MEDIUM", "an overlay, above the map's buttons")
-- something puts the map back where the game had it
Minimap:SetPoint("CENTER", MinimapCluster, "CENTER")
runTimers()
mp = lastPoint(Minimap)
check(mp[2] == Hold and mp[1] == "TOPLEFT", "it comes back to the holder")
Minimap:SetParent(MinimapCluster)
runTimers()
check(Minimap.parent == Hold, "even if it's handed back to the cluster")
-- in combat it waits
local realLockdown = InCombatLockdown
InCombatLockdown = function() return true end
Minimap:SetParent(MinimapCluster)
runTimers()
check(Minimap.parent == MinimapCluster and MM.anchorPending, "not in combat")
InCombatLockdown = realLockdown
fire("PLAYER_REGEN_ENABLED")
check(Minimap.parent == Hold and not MM.anchorPending, "the fight ends: back in the holder")
end

print("== Bags")
local Bg = ns.Bags
check(Bg.enabled, "bags enabled")
local bagsWin = Bg.windows.bags
local bf = VoltUIBags
check(bf and not bf.shown, "bag window made, hidden")
local made = 0
for bag, list in pairs(bagsWin.buttons) do for _ in pairs(list) do made = made + 1 end end
check(made == 26, "a button for every slot, made at login: " .. made)
local b02 = bagsWin.buttons[0][2]
check(b02.template and b02.id == 2 and b02.parent.id == 0, "the game's own container buttons: slot id, bag id on the holder")
check(b02.bagID == nil, "VoltUI writes nothing the game reads when you use an item")
check(b02.normalCleared and b02.IconBorder.alpha == 0, "slot art and Blizzard border gone")
ToggleAllBags()
check(not bf.shown, "the bags wait until the game's functions have finished calling each other")
runTimers()
check(bf.shown, "B opens the bag window")
local function posOf(b) local p = b.points[#b.points]; return p[4], -p[5] end
local labels = {}
for i, h in ipairs(bagsWin.headers) do if h.shown then labels[#labels + 1] = (h.text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end end
print("  sections: " .. table.concat(labels, " | "))
check(labels[1]:find("^New") == nil and labels[1]:find("Quest"), "quest items first")
check(labels[#labels]:find("^Empty") and labels[#labels]:find("15"), "every empty slot at the bottom: " .. labels[#labels])
local order = {}
for _, l in ipairs(labels) do order[#order + 1] = l:match("^(%S+)") end
local want = { "Quest", "Equipment", "Consumables", "Trade", "Bags", "Miscellaneous", "Junk", "Empty" }
check(table.concat(order, ",") == table.concat(want, ","), "category order: " .. table.concat(order, ","))
-- empties after everything
local emptyTop = math.huge
local itemBottom = 0
for _, b in ipairs(bagsWin.shown) do
  local _, y = posOf(b)
  if b.fuiItem then itemBottom = math.max(itemBottom, y) else emptyTop = math.min(emptyTop, y) end
end
check(emptyTop > itemBottom, "empty slots below all items")
do -- every heading is wide enough to read, a one-item category's too (1.76.0), and none overlap
  local full = VoltUIDB.bagCols * VoltUIDB.bagSize + (VoltUIDB.bagCols - 1) * VoltUIDB.gapX
  local wide, apart, rows = true, true, {}
  for _, h in ipairs(bagsWin.headers) do
    if h.shown then
      local need = math.min(#h.text * 6, full)
      if (h.w or 0) < need then wide = false print("    narrow: " .. h.text) end
      local p = h.points[#h.points]
      local row = rows[p[5]] or {}
      rows[p[5]] = row
      row[#row + 1] = { x = p[4], w = h.w }
    end
  end
  for _, row in pairs(rows) do
    table.sort(row, function(a, b) return a.x < b.x end)
    for i = 2, #row do if row[i - 1].x + row[i - 1].w > row[i].x then apart = false end end
  end
  check(wide, "every bag heading has room for its name and count")
  check(apart, "and headings side by side don't overlap")
end
do -- a heading sits as far from the slots above it as from its own (1.75.0)
local function headingGaps()
  local emptyHead
  for _, h in ipairs(bagsWin.headers) do if h.shown and h.text:find("^Empty") then emptyHead = h end end
  local hy = -emptyHead.points[#emptyHead.points][5]
  local above, firstEmpty, lastItem = 0, math.huge, 0
  for _, b in ipairs(bagsWin.shown) do
    local _, y = posOf(b)
    if b.fuiItem then lastItem = math.max(lastItem, y) else firstEmpty = math.min(firstEmpty, y) end
  end
  return hy - (lastItem + VoltUIDB.bagSize), firstEmpty - (hy + VoltUIDB.headerSize)
end
local up, down = headingGaps()
check(up == down and up > 0, "a heading is centred between the categories: " .. up .. " above, " .. down .. " below")
local gapWas = VoltUIDB.sectionGap
VoltUIDB.sectionGap = 2
ns.Bags:Layout(bagsWin)
up, down = headingGaps()
check(up == down and up == 4, "and with a small category gap: " .. up .. " above, " .. down .. " below")
VoltUIDB.sectionGap = gapWas
ns.Bags:Layout(bagsWin)
end
local cropped, bare = true, true
for _, b in ipairs(bagsWin.shown) do
  local tc = b.fuiIcon.texCoord or {}
  if b.fuiItem then
    if not (b.fuiIcon.shown and tc[1] == 0.08 and tc[2] == 0.92) then cropped = false end
  elseif b.fuiIcon.shown or b.fuiIcon.tex ~= nil then
    bare = false
  end
end
check(cropped, "item icons keep their crop, so the border drawn into each icon stays hidden")
check(bare, "empty slots show no slot picture, just VoltUI's square")
-- gaps
local db = VoltUIDB
local trade = {}
for _, b in ipairs(bagsWin.shown) do if b.fuiItem and b.fuiItem.classID == 7 then trade[#trade + 1] = b end end
local x1, y1 = posOf(trade[1]); local x2, y2 = posOf(trade[2])
check(x2 - x1 == db.bagSize + db.gapX and y1 == y2, "horizontal gap between slots")
local empties = {}
for _, b in ipairs(bagsWin.shown) do if not b.fuiItem then empties[#empties + 1] = b end end
local ex1, ey1 = posOf(empties[1]); local ex11, ey11 = posOf(empties[11])
check(ey11 - ey1 == db.bagSize + db.gapY and ex11 == ex1, "vertical gap between rows")
-- flow: small categories share a row
local rowsY = {}
for i, h in ipairs(bagsWin.headers) do if h.shown then local p = h.points[#h.points]; rowsY[-p[5]] = (rowsY[-p[5]] or 0) + 1 end end
local shared = false
for _, n in pairs(rowsY) do if n > 1 then shared = true end end
check(shared, "small categories sit side by side")
-- glow
local epic, quest
for _, b in ipairs(bagsWin.shown) do
  if b.fuiItem and b.fuiItem.quality == 4 then epic = b end
  if b.fuiItem and b.fuiItem.starts then quest = b end
end
check(epic and epic.fuiGlow.edges[1].ctex[1] == 0.64 and epic.fuiGlow.glow[1].shown ~= false, "epic: purple outline and glow")
check(quest and quest.fuiMark.text:find("!") and not quest.fuiLeft.shown, "quest starters marked")
do -- 1.63.0: quest items you no longer need
  local QL = C_QuestLog
  local log = { [77] = { title = "Lost Letter", objectives = { { text = "Aged Envelope: 0/1" } } } }
  C_QuestLog = setmetatable({
    GetNumQuestLogEntries = function() return log[77] and 1 or 0 end,
    GetInfo = function(i) return log[77] and { questID = 77, title = "Lost Letter" } or nil end,
    GetQuestObjectives = function(id) return log[id] and log[id].objectives end,
    IsQuestFlaggedCompleted = function(q) return q == 123 and log.done or false end,
  }, { __index = QL })
  local slot = BAGS[1][3]
  slot.quest = { isQuestItem = true } -- the envelope as an objective, not a starter
  ns.Bags:Layout(bagsWin)
  local env
  for _, b in ipairs(bagsWin.shown) do if b.fuiItem and b.fuiItem.id == 4881 then env = b end end
  check(env and not env.fuiLeft.shown and not env.fuiItem.leftover, "a quest item a quest in your log asks for: no mark")
  log[77] = nil
  ns.Bags:Layout(bagsWin)
  for _, b in ipairs(bagsWin.shown) do if b.fuiItem and b.fuiItem.id == 4881 then env = b end end
  check(env and env.fuiLeft.shown and env.fuiItem.leftover == "No quest in your log needs it.", "dropped the quest: a red bin on it")
  check(env.fuiLeft.icon.kind == "discard" and env.fuiLeft.icon.parts[1].ctex[1] == ns.Style.UI.bad[1], "the bin, in red")
  -- a delivery: no objectives, so the letter's name is in none of them
  log[78] = { objectives = {} }
  local count, info = C_QuestLog.GetNumQuestLogEntries, C_QuestLog.GetInfo
  C_QuestLog.GetNumQuestLogEntries = function() return 1 end
  C_QuestLog.GetInfo = function() return { questID = 78, title = "Calling in the Reserves" } end
  ns.Bags:Layout(bagsWin)
  for _, b in ipairs(bagsWin.shown) do if b.fuiItem and b.fuiItem.id == 4881 then env = b end end
  check(not env.fuiLeft.shown, "a delivery quest nobody can read the items of: nothing is marked while you have it")
  -- QuestieDB knows it: the letter is what its giver hands you, so it's kept
  local oldLib = LibQuestieDB
  local function lib(src)
    return { Item = { Get = function() return nil end },
      Quest = { Exists = function(q) return q == 78 end, Get = function(q, k) if q == 78 and k == "sourceItemId" then return src end end } }
  end
  LibQuestieDB = lib(4881)
  ns.Bags:Layout(bagsWin)
  for _, b in ipairs(bagsWin.shown) do if b.fuiItem and b.fuiItem.id == 4881 then env = b end end
  check(not env.fuiLeft.shown, "the item a quest's giver hands you is needed while you have the quest")
  LibQuestieDB = lib(9999)
  ns.Bags:Layout(bagsWin)
  for _, b in ipairs(bagsWin.shown) do if b.fuiItem and b.fuiItem.id == 4881 then env = b end end
  check(env.fuiLeft.shown, "and a quest item it doesn't hand you is still marked")
  LibQuestieDB = oldLib
  C_QuestLog.GetNumQuestLogEntries, C_QuestLog.GetInfo = count, info
  log[78] = nil
  VoltUIDB.questLeft = false
  ns.Bags:Layout(bagsWin)
  for _, b in ipairs(bagsWin.shown) do if b.fuiItem and b.fuiItem.id == 4881 then env = b end end
  check(not env.fuiLeft.shown, "the bag setting turns the marks off")
  VoltUIDB.questLeft = true
  -- a starter: left over once its quest is done, and its "!" goes
  slot.quest = { isQuestItem = true, questID = 123, isActive = false }
  log.done = true
  ns.Bags:Layout(bagsWin)
  for _, b in ipairs(bagsWin.shown) do if b.fuiItem and b.fuiItem.id == 4881 then env = b end end
  check(env.fuiLeft.shown and env.fuiMark.text == "" and env.fuiItem.leftover == "You've done the quest it starts.", "an item that starts a quest you've done: the bin, not the !")
  -- cloth a quest wants is never marked
  local cloth
  for _, b in ipairs(bagsWin.shown) do if b.fuiItem and b.fuiItem.id == 2589 then cloth = b end end
  check(cloth and not cloth.fuiLeft.shown, "only the game's quest items are judged")
  C_QuestLog = QL
  ns.Bags:Layout(bagsWin)
end
check(b02.Count.text == "12" and b02.Count.font and b02.Count.font[1]:find("Barlow") and b02.Count.font[3] == "OUTLINE", "stack count in the bag font, outlined")
check(bf.money.text == "|cffffd10012|r|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:2:0|t  |cffc7c7cf34|r|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:2:0|t  |cffeda55f56|r|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:2:0|t" and bf.free.text == "11/26", "money with the game's coins, and slots used: " .. bf.money.text)
check(bf.sort.text.points[1][1] == "LEFT" and bf.sort.text.points[2][1] == "RIGHT" and #bf.sort.text.points == 2 and bf.sort.text.text == "Sort", "a button's label spans it, with its height left to the text")
check(bf.w == db.bagCols * db.bagSize + (db.bagCols - 1) * db.gapX + 16, "window width from columns, size and gaps")
-- search
bf.search:SetText("mala")
bf.search.scripts.OnTextChanged(bf.search)
local bright, dim = 0, 0
for _, b in ipairs(bagsWin.shown) do if b.alpha == 1 then bright = bright + 1 else dim = dim + 1 end end
check(bright == 1 and dim == #bagsWin.shown - 1, "search dims everything else")
bf.search:SetText("metal")
bf.search.scripts.OnTextChanged(bf.search)
bright = 0
for _, b in ipairs(bagsWin.shown) do if b.alpha == 1 then bright = bright + 1 end end
check(bright == 3, "search matches item types too")
bf.search:SetText(""); bf.search.scripts.OnTextChanged(bf.search)
-- filters (1.35.0): one at a time, with the search, and words the search box knows
;(function()
  local function lit()
    local n, names = 0, {}
    for _, b in ipairs(bagsWin.shown) do
      if b.alpha == 1 then n = n + 1; names[#names + 1] = b.fuiItem and b.fuiItem.name or "?" end
    end
    return n, table.concat(names, ",")
  end
  local function type_(t) bf.search:SetText(t); bf.search.scripts.OnTextChanged(bf.search) end
  check(bf.filters == nil and bagsWin.content.points[1][3] == -(24 + 8 - 2), "no row of filter buttons: the items start under the title")
  type_("gear")
  local n, names = lit()
  check(n == 3, "typing gear lights weapons and armour: " .. names)
  type_("epic")
  n, names = lit()
  check(n == 1 and names == "Clarice's Pendant", "the search knows rarities: " .. names)
  type_("junk")
  n, names = lit()
  check(n == 1 and names == "Ruined Pelt", "and junk: " .. names)
  type_("boe")
  check(lit() == 0, "BoE: nothing while the game hasn't said an item is unbound")
  BAGS[0][8].isBound = false -- the green letter opener
  BAGS[0][4].isBound = false -- a white sword: not what anyone means by BoE
  Bg:Layout(bagsWin)
  n, names = lit()
  check(n == 1 and names == "Sharpened Letter Opener", "BoE: unbound gear, green or better: " .. names)
  type_(" Quest ")
  n, names = lit()
  check(n == 1 and names == "Aged Envelope", "spaces and capitals aside: " .. names)
  type_("gear")
  bf:Hide(); bf:Show()
  check(lit() == #bagsWin.shown, "closing the window clears the search")
  -- the corner to drag
  local g, db = bf.grip, VoltUIDB
  local cols0, oldCursor = db.bagCols, GetCursorPosition
  local keepL, keepT, keepP = db.bagLeft, db.bagTop, db.bagPoint
  local left = bf:GetLeft()
  check(g and g.parent == bf and g.points[1][1] == "BOTTOMRIGHT", "a corner to drag at the bottom-right")
  local function widthFor(c) return c * db.bagSize + (c - 1) * db.gapX + 16 end
  g.scripts.OnMouseDown(g)
  check(db.bagPoint ~= nil and bf.points[1][1] == "TOPLEFT" and g.scripts.OnUpdate, "pressing it pins the window's top-left corner")
  GetCursorPosition = function() return left + widthFor(6), 300 end
  g.scripts.OnUpdate(g, 0.01)
  check(db.bagCols == 6 and bf.w == widthFor(6), "dragging in: six columns, and the window is that wide: " .. db.bagCols)
  local h6 = bf.h
  GetCursorPosition = function() return left + widthFor(14) + 9, 300 end
  g.scripts.OnUpdate(g, 0.01)
  check(db.bagCols == 14 and bf.w == widthFor(14) and bf.h < h6, "dragging out: fourteen, and fewer rows")
  GetCursorPosition = function() return left + 20, 300 end
  g.scripts.OnUpdate(g, 0.01)
  check(db.bagCols == 4, "never fewer than four")
  GetCursorPosition = function() return left + 9000, 300 end
  g.scripts.OnUpdate(g, 0.01)
  check(db.bagCols == 30, "or more than thirty")
  g.scripts.OnMouseUp(g)
  check(g.scripts.OnUpdate == nil, "letting go stops it")
  GetCursorPosition = oldCursor
  db.bagCols = cols0
  db.bagLeft, db.bagTop, db.bagPoint = keepL, keepT, keepP
  Bg:Place(bagsWin)
  BAGS[0][8].isBound, BAGS[0][4].isBound = nil, nil
  Bg:Layout(bagsWin)
end)()
-- settings
SlashCmdList.VOLTUI("bags gapx 8")
local nx1 = posOf(trade[1]); local nx2 = posOf(trade[2])
check(nx2 - nx1 == db.bagSize + 8, "/fui bags gapx changes the horizontal gap live")
SlashCmdList.VOLTUI("bags gapy 10")
local _, a1 = posOf(empties[1]); local _, a11 = posOf(empties[11])
check(a11 - a1 == db.bagSize + 10, "/fui bags gapy changes the vertical gap live")
SlashCmdList.VOLTUI("bags cols 8")
check(bf.w == 8 * db.bagSize + 7 * 8 + 16, "columns")
-- Settings (the button, /volt bags, the minimap menu) open the settings window on its Bags page
-- A page's rows by key, built without showing the page. A global: the main chunk is near 200 locals.
function hubRows(page)
  ns.EditMode:Build()
  local out = {}
  for _, r in ipairs(ns.EditMode:Page(page).rows) do
    if r.def.key then out[r.def.key] = r end
    r:Refresh()
  end
  return out
end
check(VoltUIBagSettings == nil, "the bags have no settings panel of their own any more")
SlashCmdList.VOLTUI("bags")
check(VoltUISettings.shown and ns.EditMode.tab == "bags", "/volt bags opens the settings window on the Bags page")
bf.cog.scripts.OnClick(bf.cog)
check(not VoltUISettings.shown, "the bag window's Settings button closes it again")
bf.cog.scripts.OnClick(bf.cog)
check(VoltUISettings.shown and ns.EditMode.tab == "bags", "and opens it")
ns.EditMode:Select("general")
bf.cog.scripts.OnClick(bf.cog)
check(VoltUISettings.shown and ns.EditMode.tab == "bags", "from another page it goes to Bags rather than closing")
check(hubRows("bags").bagCols and hubRows("bags").ilvl and hubRows("general").font, "its rows are there, the font on General")
ns.EditMode:Select("general") -- as the later tests expect to find it
ns.EditMode:Close()
db.font = "rajdhani"; ns.Style.ApplyFonts(); ns.FUI:Refresh()
check(b02.Count.font[1]:find("Rajdhani"), "changing the font restyles everything")
check(bf.title.font[1]:find("SpaceMono") and bf.free.font[1]:find("JetBrainsMono"), "but not the bag window's title bar, which is in VoltUI's own fonts (1.82.0)")
SlashCmdList.VOLTUI("font chakra")
check(db.font == "chakra" and b02.Count.font[1]:find("ChakraPetch"), "/fui font")
SlashCmdList.VOLTUI("bags categories")
labels = {}
for i, h in ipairs(bagsWin.headers) do if h.shown then labels[#labels + 1] = h.text:match("^(%S+)") end end
check(table.concat(labels, ",") == "Items,Empty", "categories off: one grid, empties last")
SlashCmdList.VOLTUI("bags categories")
SlashCmdList.VOLTUI("bags reset")
check(db.gapX == 4 and db.bagCols == 10, "bags reset")
-- item moves
BAGS[0][7] = BAGS[0][2]; BAGS[0][2] = nil
fire("BAG_UPDATE", 0); fire("BAG_UPDATE_DELAYED"); runTimers()
check(bagsWin.buttons[0][7].fuiItem and not bagsWin.buttons[0][2].fuiItem, "moves show up")
do -- the reagent bag: only some items can go in it, so it's kept apart
  local function shownLabels()
    local out = {}
    for _, h in ipairs(bagsWin.headers) do
      if h.shown then out[#out + 1] = (h.text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
    end
    return out
  end
  local function update()
    fire("BAG_CONTAINER_UPDATE"); runTimers()
  end
  local labelsBefore = table.concat(shownLabels(), " | ")
  local usedBefore, freeBefore, heightBefore = bf.free.text, bf.info.text, bf.h
  check(not labelsBefore:find("Reagent Bag", 1, true), "no reagent bag: no section")

  BAGS[5], SIZES[5] = {}, 4
  put(5, 1, 2589, 20); put(5, 3, 774, 3)
  put(5, 4, 4881, 1, { quest = { isQuestItem = true, questID = 0, isActive = false } })
  update()
  local now = shownLabels()
  check(now[#now] == "Reagent Bag  3/4", "its own section, last, saying how full it is: " .. tostring(now[#now]))
  check(table.concat(now, " | ", 1, #now - 1) == labelsBefore, "nothing else changes, empty count included")
  check(bf.free.text == usedBefore and bf.info.text == freeBefore, "its slots aren't counted as bag space: " .. bf.free.text .. ", " .. bf.info.text)
  check(bf.h == heightBefore + db.sectionGap + db.headerSize + 6 + db.bagSize, "the window grows to fit it")

  local slots = bagsWin.buttons[5]
  local lowest = 0
  for _, b in ipairs(bagsWin.shown) do
    if b.fuiBag ~= 5 then lowest = math.max(lowest, select(2, posOf(b))) end
  end
  local _, reagentY = posOf(slots[3])
  check(reagentY > lowest, "below everything else")
  local x3, x1, x4, x2 = posOf(slots[3]), posOf(slots[1]), posOf(slots[4]), posOf(slots[2])
  check(x3 < x1 and x1 < x4 and x4 < x2, "items sorted, then its empty slots")
  check(slots[3].fuiItem and slots[3].fuiItem.name == "Malachite" and slots[4].fuiItem.isQuest, "a quest item stays in the bag it's in")
  check(slots[2].shown and not slots[2].fuiItem, "its empty slots are real slots")
  check(slots[1].parent.id == 5 and slots[1].id == 1 and slots[1].bagID == nil, "using the game's own bag and slot ids")

  bf.search:SetText("mala"); bf.search.scripts.OnTextChanged(bf.search)
  check(slots[3].alpha == 1 and slots[1].alpha < 1, "search reaches it")
  bf.search:SetText(""); bf.search.scripts.OnTextChanged(bf.search)

  SlashCmdList.VOLTUI("bags categories")
  local plain = {}
  for _, l in ipairs(shownLabels()) do plain[#plain + 1] = l:match("^(%S+)") end
  check(table.concat(plain, ",") == "Items,Empty,Reagent", "stays apart with categories off: " .. table.concat(plain, ","))
  SlashCmdList.VOLTUI("bags categories")

  BAGS[5] = {}
  update()
  now = shownLabels()
  check(now[#now] == "Reagent Bag  0/4" and slots[1].shown and not slots[1].fuiItem, "shown empty too")

  local sizes = { SIZES[0], SIZES[1] }
  SIZES[0], SIZES[1] = 0, 0
  update()
  now = shownLabels()
  local head = bagsWin.headers[1]
  check(#now == 1 and head.points[#head.points][5] == 0, "nothing above it: no gap at the top")
  SIZES[0], SIZES[1] = sizes[1], sizes[2]

  SIZES[5] = 0
  update()
  check(table.concat(shownLabels(), " | ") == labelsBefore and not slots[1].shown, "taking the bag off removes the section and its slots")
  check(bf.h == heightBefore, "and the window shrinks back")
  SIZES[5], BAGS[5] = nil, nil
end
do -- quivers, ammo pouches, soul bags and profession bags: the same, named after the bag
  local function shownLabels()
    local out = {}
    for _, h in ipairs(bagsWin.headers) do
      if h.shown then out[#out + 1] = (h.text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
    end
    return out
  end
  local function update()
    fire("BAG_CONTAINER_UPDATE"); runTimers()
  end
  local labelsBefore = table.concat(shownLabels(), " | ")
  local usedBefore, freeBefore, heightBefore = bf.free.text, bf.info.text, bf.h

  -- A general bag worn in the same slot takes the items, counts as space, and gets no section.
  BAGS[2], SIZES[2] = {}, 4
  put(2, 1, 2589, 20)
  BAG_FAMILIES[2] = 0
  update()
  check(not table.concat(shownLabels(), " | "):find("Quiver", 1, true), "a bag with no limit gets no section")
  check(bf.free.text ~= usedBefore, "and counts as bag space: " .. bf.free.text)

  -- The same slot now holds a quiver.
  BAG_FAMILIES[2], BAG_NAMES[2] = 1, "Light Quiver"
  update()
  local now = shownLabels()
  check(now[#now] == "Light Quiver  1/4", "its own section, named after the bag: " .. tostring(now[#now]))
  check(table.concat(now, " | ", 1, #now - 1) == labelsBefore, "nothing else changes, empty count included")
  check(bf.free.text == usedBefore and bf.info.text == freeBefore, "its slots aren't counted as bag space: " .. bf.free.text .. ", " .. bf.info.text)
  check(bf.h == heightBefore + db.sectionGap + db.headerSize + 6 + db.bagSize, "the window grows to fit it")
  local q = bagsWin.buttons[2]
  check(q[1].shown and q[1].fuiItem and q[1].fuiItem.name == "Linen Cloth", "its item is shown there")
  check(q[4].shown and not q[4].fuiItem, "its empty slots are real slots")
  local lowest = 0
  for _, b in ipairs(bagsWin.shown) do
    if b.fuiBag ~= 2 then lowest = math.max(lowest, select(2, posOf(b))) end
  end
  check(select(2, posOf(q[1])) > lowest, "below everything else")

  bf.search:SetText("linen"); bf.search.scripts.OnTextChanged(bf.search)
  check(q[1].alpha == 1 and q[4].alpha < 1, "search reaches it")
  bf.search:SetText(""); bf.search.scripts.OnTextChanged(bf.search)

  -- Several at once: one section each, in the order they're worn, the reagent bag included.
  BAGS[3], SIZES[3], BAG_FAMILIES[3], BAG_NAMES[3] = {}, 2, 4, "Small Soul Pouch"
  BAGS[5], SIZES[5] = {}, 2
  BAG_NAMES[5] = "A Name That Isn't Used"
  update()
  now = shownLabels()
  check(table.concat(now, " | ", #now - 2) == "Light Quiver  1/4 | Small Soul Pouch  0/2 | Reagent Bag  0/2",
    "one section each, in order: " .. table.concat(now, " | ", #now - 2))
  check(select(2, posOf(bagsWin.buttons[3][1])) > select(2, posOf(q[4])), "each below the last")
  BAGS[3], SIZES[3], BAG_FAMILIES[3], BAG_NAMES[3] = nil, 0, nil, nil
  BAGS[5], SIZES[5], BAG_NAMES[5] = nil, nil, nil

  -- A name that hasn't arrived yet.
  BAG_NAMES[2] = ""
  update()
  now = shownLabels()
  check(now[#now] == "Special Bag  1/4", "a plain label until its name arrives: " .. tostring(now[#now]))
  BAG_NAMES[2] = "Light Quiver"
  fire("GET_ITEM_INFO_RECEIVED"); runTimers()
  now = shownLabels()
  check(now[#now] == "Light Quiver  1/4", "and the name when it does: " .. tostring(now[#now]))
  BAG_NAMES[2] = nil
  update()
  now = shownLabels()
  check(now[#now] == "Special Bag  1/4", "no name at all gets the same label: " .. tostring(now[#now]))
  BAG_NAMES[2] = "Light Quiver"

  -- Taking it off.
  SIZES[2] = 0
  update()
  check(table.concat(shownLabels(), " | ") == labelsBefore and not q[1].shown, "taking the bag off removes the section and its slots")
  check(bf.h == heightBefore, "and the window shrinks back")
  SIZES[2], BAGS[2], BAG_FAMILIES[2], BAG_NAMES[2] = 0, nil, nil, nil

  -- A game with no way to ask: every bag counts as general.
  local freeWere = C_Container.GetContainerNumFreeSlots
  BAG_FAMILIES[1] = 1
  C_Container.GetContainerNumFreeSlots = nil
  update()
  check(table.concat(shownLabels(), " | ") == labelsBefore, "no such function: nothing is set apart")
  C_Container.GetContainerNumFreeSlots = freeWere
  BAG_FAMILIES[1] = nil
  update()
end
-- close
ToggleAllBags()
runTimers()
check(not bf.shown, "B closes it")
OpenAllBags()
runTimers()
check(bf.shown, "merchant/mail open the bags")
CloseAllBags()
runTimers()
check(not bf.shown, "and close them")
do -- its own block: the main chunk is near Lua's limit of 200 locals
-- The game's functions stay the game's. Replacing one would make everything the game does
-- after calling it count as add-on code, and it blocks some of that: its bank opens the bags, then claims a free bag slot.
gameBags.ran, gameBags.open = {}, false
for _, name in ipairs({ "OpenAllBags", "CloseAllBags", "ToggleAllBags", "ToggleBackpack", "OpenBackpack", "CloseBackpack", "ToggleBag", "OpenBag" }) do
  check(hookedGlobals[name], name .. " is followed")
end
OpenAllBags(); runTimers()
check(gameBags.ran.OpenAllBags == 1 and gameBags.ran.OpenBackpack == 1 and gameBags.ran.OpenBag == 4, "the game's own code still runs")
CloseAllBags(); runTimers()
local replaced = {}
for _, file in ipairs({ "Bags", "Core", "Loot", "Tooltips", "Minimap", "Treasures", "UnitFrames", "Castbar", "ActionBars", "EditMode", "MinimapIcon", "Style", "Controls" }) do
  local src = io.open(DIR .. "/" .. file .. ".lua")
  if src then
    local text = src:read("*a")
    src:close()
    for _, name in ipairs({ "OpenAllBags", "CloseAllBags", "ToggleAllBags", "ToggleBackpack", "OpenBackpack", "CloseBackpack", "ToggleBag", "OpenBag", "CloseBag", "IsBagOpen" }) do
      if text:find("\n%s*" .. name .. "%s*=%s*[^=\"%s]") or text:find("function%s+" .. name .. "%s*%(") then replaced[#replaced + 1] = file .. ":" .. name end
    end
  end
end
check(#replaced == 0, "nothing in VoltUI replaces them: " .. table.concat(replaced, ", "))
-- Each way of pressing B, starting closed and open
for _, press in ipairs({ ToggleAllBags, ToggleBackpack, function() ToggleBag(2) end }) do
  gameBags.open = false
  press(); runTimers()
  check(bf.shown, "a bag key opens the window")
  press(); runTimers()
  check(not bf.shown, "and the same key closes it, whatever the game called along the way")
end
-- Closed with x or Esc: the game still thinks the bags are open, and B still opens them.
gameBags.open = false
ToggleAllBags(); runTimers()
bf:Hide()
check(gameBags.open, "the game hasn't noticed the window closing")
ToggleAllBags(); runTimers()
check(bf.shown, "and one press of B opens it again")
bf:Hide()
check(not bf.shown, "closed again")
gameBags.open = false
OpenBackpack(); runTimers()
check(bf.shown, "OpenBackpack on its own opens it")
CloseBackpack(); runTimers()
check(not bf.shown, "CloseBackpack closes it")
OpenBag(1); runTimers()
check(bf.shown, "and OpenBag opens it")
CloseBag(1); runTimers()
check(bf.shown, "but closing one bag doesn't close them all")
CloseAllBags(); runTimers()
-- Two reports in a row: the last wins
gameBags.open = false
OpenBackpack()
CloseAllBags()
runTimers()
check(not bf.shown, "the last call decides")
-- Bank bags don't toggle ours while the bank is open
ns.Bags.bankOpen = true
ToggleBag(9)
runTimers()
check(not bf.shown, "a bank bag leaves the bag window alone")
ns.Bags.bankOpen = false
-- The game's windows
local gone = ns.Style.HiddenParent()
check(ContainerFrame1.parent == gone and ContainerFrameCombinedBags.parent == gone, "the game's bag windows are out of sight")
check(ContainerFrame1.scripts.OnShow == nil, "with no add-on code run when they open")
inCombat = true
ContainerFrame1.parent = UIParent
ns.Bags:PutAwayGameBags()
check(ContainerFrame1.parent == UIParent and ns.Bags.putAwayPending, "a /reload in combat waits")
inCombat = false
fire("PLAYER_REGEN_ENABLED")
check(ContainerFrame1.parent == gone and not ns.Bags.putAwayPending, "and finishes when combat ends")
end
-- bank
fire("BANKFRAME_OPENED")
local bk = VoltUIBank
check(bk and bk.shown and bf.shown, "bank opens ours (and the bags)")
check(BankFrame.parent == ns.Style.HiddenParent(), "the game's bank window is out of sight")
check(bk.free.text == "0/24", "bank slots: " .. bk.free.text)
check(bk.grip and bk.info.text == "24 free" and bk.money.text == bf.money.text,
  "the bank has the corner to drag, and a footer with free slots and your money: " .. tostring(bk.info.text))
bk:Hide()
check(bankClosed == 1, "closing our bank closes the banker")
fire("BANKFRAME_CLOSED")
check(bankClosed == 1, "no double close")
do -- a bank made of tabs you buy, as WoW Forever has
  local B = ns.Bags
  local tabs = { 6, 7 }
  local next = { tabCost = 10000, canAfford = true }
  local maxTabs = 4
  local bankClosedNew = 0
  canViewWarband = false
  Enum = Enum or {}
  Enum.BankType = { Character = 0, Account = 2 }
  Enum.PlayerInteractionType = { Banker = 8, AccountBanker = 9, Merchant = 5 }
  C_Bank = {
    CanViewBank = function(kind) return kind == 0 or canViewWarband end,
    FetchPurchasedBankTabData = function(kind)
      local out = {}
      if kind == 0 then for _, id in ipairs(tabs) do out[#out + 1] = { ID = id } end end
      if kind == 2 then out[1] = { ID = 12 } end
      return out
    end,
    FetchNumPurchasedBankTabs = function() return #tabs end,
    FetchMaxNumBankTabs = function() return maxTabs end,
    FetchNextPurchasableBankTabData = function() return next end,
    CloseBankFrame = function() bankClosedNew = bankClosedNew + 1 end,
  }
  local slotsWere = C_Container.GetContainerNumSlots
  local infoWere = C_Container.GetContainerItemInfo
  local sorted
  C_Container.GetContainerNumSlots = function(bag)
    if bag == 6 then return 2 elseif bag == 7 then return 1 elseif bag == 12 then return 3 elseif bag > 5 then return 0 end
    return slotsWere(bag)
  end
  C_Container.GetContainerItemInfo = function(bag, slot)
    if bag == 6 and slot == 1 then
      return { iconFileID = "tabitem", stackCount = 1, quality = 2, hyperlink = "item:900", itemID = 900 }
    end
    if bag >= 6 then return nil end
    return infoWere(bag, slot)
  end
  C_Container.SortBank = function(kind) sorted = kind end
  local realCreate = CreateFrame
  CreateFrame = function(kind, name, parent, template, ...)
    local made = realCreate(kind, name, parent, template, ...)
    if made then made.madeFrom = template end
    return made
  end
  -- A fresh window, since the one above was made for the older bank.
  B.windows.bank = nil
  VoltUIBank = nil
  B.bankOpen = false
  ns.Bags.bankOpenedBags = nil
  B:Close()
  fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", Enum.PlayerInteractionType.Merchant)
  check(not (B.windows.bank and B.windows.bank.frame.shown), "another NPC doesn't open the bank")
  fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", Enum.PlayerInteractionType.Banker)
  local w = B.windows.bank
  check(w and w.frame.shown and bf.shown and B.bankOpen, "a banker opens it, and the bags")
  fire("BANKFRAME_OPENED")
  check(B.bankOpen and bf.shown, "and the game's other signal doesn't open it twice")
  B:Layout(w)
  check(w.frame.free.text == "1/3", "your purchased tabs fill it: " .. tostring(w.frame.free.text))
  SIZES[5] = 4
  B:Layout(w)
  check(w.frame.free.text == "1/3" and not w.buttons[5], "the reagent bag stays out of the bank window")
  SIZES[5] = nil
  BAG_FAMILIES[6], BAG_FAMILIES[2], SIZES[2], BAG_NAMES[6] = 1, 1, 4, "Bank Tab"
  B:Layout(w)
  check(w.frame.free.text == "1/3" and not w.buttons[2], "a limited bag you're wearing stays out of the bank window too")
  for _, h in ipairs(w.headers) do
    check(not (h.shown and h.text:find("Bank Tab", 1, true)), "and bank tabs are never set apart")
  end
  BAG_FAMILIES[6], BAG_FAMILIES[2], SIZES[2], BAG_NAMES[6] = nil, nil, 0, nil
  check(w.buttons[6] and w.buttons[6][1] and w.buttons[6][2] and w.buttons[7] and w.buttons[7][1], "with a slot for each")
  check(w.buttons[6][1].parent.id == 6 and w.buttons[6][1].id == 1, "each tab's holder carries its ID")
  check(w.buttons[6][1].bagID == nil, "and nothing the game reads is written")
  check(w.buttons[6][1].fuiItem and w.buttons[6][1].fuiItem.icon == "tabitem", "items show")
  check(not w.buttons[-1], "no old bank bags")
  check(not w.buttons[12], "no warband tabs you can't see")
  canViewWarband = true
  B:Layout(w)
  check(w.buttons[12] and w.buttons[12][3] and w.frame.free.text == "1/6", "and they join in when you can")
  canViewWarband = false
  B:Layout(w)
  local buy = w.frame.buy
  check(buy and buy.madeFrom == "BankPanelPurchaseButtonScriptTemplate", "the buy button uses the game's own script")
  check(buy.attrs.overrideBankType == 0, "for your own bank")
  check(buy.scripts.OnClick == nil, "and VoltUI doesn't replace it")
  check(buy.shown and buy.text.text:find("Buy bank tab", 1, true) and buy.text.text:find("12g 34s 56c", 1, true), "it shows the cost")
  check(w.frame.info.text:find(" free", 1, true) and w.frame.info.points[1][2] == buy and w.frame.info.points[1][1] == "LEFT",
    "the free count sits after it: " .. tostring(w.frame.info.text))
  check(w.frame.money.text == bf.money.text and w.frame.money.text ~= "", "and the bank shows your money too")
  next.canAfford = false
  fire("PLAYER_MONEY")
  check(buy.text.color[2] == 0.35, "red when you can't afford it")
  next.canAfford = true
  next.tabCost = 0
  fire("PLAYER_MONEY")
  check(buy.text.text == "Claim your free bank tab" and buy.text.color[2] == 1, "your first tab is free")
  next.tabCost = 10000
  -- Buying one
  tabs = { 6, 7, 8 }
  C_Container.GetContainerNumSlots = function(bag)
    if bag == 6 then return 2 elseif bag == 7 then return 1 elseif bag == 8 then return 4 elseif bag == 12 then return 3 elseif bag > 5 then return 0 end
    return slotsWere(bag)
  end
  fire("BANK_TABS_CHANGED", 0); runTimers()
  check(w.frame.free.text == "1/7" and w.buttons[8] and w.buttons[8][4], "a new tab appears")
  maxTabs = 3
  B:Layout(w)
  check(not buy.shown and w.frame.info.text:find("6 free", 1, true), "at the most you can have, the button goes")
  maxTabs = 4
  w.frame.sort.scripts.OnClick(w.frame.sort)
  check(sorted == 0, "sort tidies your own tabs")
  -- Leaving
  fire("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", Enum.PlayerInteractionType.Merchant)
  check(w.frame.shown, "another NPC closing doesn't touch it")
  fire("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", Enum.PlayerInteractionType.Banker)
  check(not w.frame.shown and not B.bankOpen and not bf.shown, "walking away closes both")
  check(bankClosedNew == 0, "without closing what's already closed")
  fire("BANKFRAME_CLOSED")
  check(not B.bankOpen, "and the other signal is harmless")
  -- Bags you had open stay open
  B:Open()
  fire("BANKFRAME_OPENED")
  fire("BANKFRAME_CLOSED")
  check(bf.shown and not w.frame.shown, "bags you opened yourself stay open")
  B:Close()
  fire("BANKFRAME_OPENED")
  w.frame:Hide()
  check(bankClosedNew == 1, "closing our window ends the visit")
  fire("BANKFRAME_CLOSED")
  check(bankClosedNew == 1, "once")
  -- With no tabs yet, the free one can still be claimed
  tabs, next.tabCost = {}, 0
  fire("BANKFRAME_OPENED")
  B:Layout(w)
  check(w.frame.shown and buy.shown and buy.text.text == "Claim your free bank tab", "an empty bank offers the free tab")
  fire("BANKFRAME_CLOSED")
  -- Off
  local bankSetting = VoltUIDB.bank
  VoltUIDB.bank = false
  check(not B:UsesOwnBank(), "/volt bank off gives the bank back to the game")
  VoltUIDB.bank = bankSetting
  check(B:UsesOwnBank(), "and on takes it again")
  B.ownBank = false
  fire("BANKFRAME_OPENED")
  check(not w.frame.shown, "/volt bank off leaves it to the game")
  BankFrame.parent = UIParent
  B:PutAwayGameBags()
  check(BankFrame.parent == UIParent, "and its window stays up")
  B.ownBank = true
  B:PutAwayGameBags()
  B.bankOpen = false
  fire("BANKFRAME_CLOSED")
  C_Container.GetContainerNumSlots, C_Container.GetContainerItemInfo, C_Container.SortBank = slotsWere, infoWere, nil
  C_Bank, Enum.BankType, Enum.PlayerInteractionType = nil, nil, nil
  CreateFrame = realCreate
  B:Close()
end

-- The pretend world the map tests share: a fake Durotar, the world map, units, the clock
-- (the rare and treasure tests that set it up left VoltUI in 1.104.0).
-- fake Durotar for placing spawn points
local Z = { xs = -1500, xn = 1300, yw = -3600, ye = -6000 }
function CreateVector2D(x, y) return { x = x, y = y } end
C_Map.GetMapInfo = function(m) return ({ [1411] = { name = "Durotar", mapType = 3, parentMapID = 1414 }, [1414] = { name = "Kalimdor", mapType = 2 } })[m] end
C_Map.GetWorldPosFromMapPos = function(m, v)
  if m == 1414 then return 1, { x = 12000 - v.y * 24000, y = 12000 - v.x * 24000 } end
  if m == 1411 then return 1, { x = Z.xn - v.y * (Z.xn - Z.xs), y = Z.yw - v.x * (Z.yw - Z.ye) } end
end
C_Map.GetMapPosFromWorldPos = function(inst, v, m)
  if inst ~= 1 then return nil end
  if m == 1414 then return m, { x = (12000 - v.y) / 24000, y = (12000 - v.x) / 24000 } end
  if m == 1411 then return m, { x = (Z.yw - v.y) / (Z.yw - Z.ye), y = (Z.xn - v.x) / (Z.xn - Z.xs) } end
end
C_Map.GetMapInfoAtPosition = function(m, cx, cy)
  local wx, wy = 12000 - cy * 24000, 12000 - cx * 24000
  if wx >= Z.xs and wx <= Z.xn and wy <= Z.yw and wy >= Z.ye then return { mapID = 1411, mapType = 3 } end
end
C_Map.GetPlayerMapPosition = function() return { x = 0.5, y = 0.5 } end
-- world map
local canvas = new("Frame")
canvas.w, canvas.h = 1000, 667
WorldMapFrame = new("Frame", "WorldMapFrame")
WorldMapFrame.ScrollContainer = new("Frame")
function WorldMapFrame:GetCanvas() return canvas end
function WorldMapFrame:GetMapID() return 1411 end
function WorldMapFrame.OnMapChanged() end
WorldMapFrame.BorderFrame = false -- just enough map for the rare dots; the window's look is tested at the end
GameTooltip.lines = {}; function GameTooltip:AddLine(t) table.insert(self.lines, t) end
local units = {}
function UnitExists(u) return units[u] ~= nil end
function UnitIsPlayer() return false end
function UnitClassification(u) return units[u] and units[u].class end
function UnitGUID(u) return units[u] and ("Creature-0-1-1-1-" .. units[u].id .. "-0") end
function UnitName(u) return units[u] and units[u].name end
function UnitLevel(u) return units[u] and units[u].level end
function UnitIsDead(u) return units[u] and units[u].dead or false end
function strsplit(sep, s) local t = {}; for p in (s .. sep):gmatch("(.-)%" .. sep) do t[#t + 1] = p end; return table.unpack(t) end
function time() return 1000000 end
local now = 500
function GetTime() return now end
local sounds = 0
PlaySound = function() sounds = sounds + 1 end
SOUNDKIT = { RAID_WARNING = 8959 }
function FlashClientIcon() end
function GetRaidTargetIndex() return nil end
function SetRaidTarget() end
function IsInGroup() return false end
local combatNow = false
InCombatLockdown = function() return combatNow end
local wp
TomTom = { AddWaypoint = function(_, m, x, y, o) wp = { m, x, y, o.title }; return 1 end, RemoveWaypoint = function() end }
local nowT = 1000000
time = function() return nowT end
GameTooltipTextLeft1 = new("FontString", "GameTooltipTextLeft1")
local lootGUID = "GameObject-0-1-1-1-777777-0"
function GetLootSourceInfo() return lootGUID end
Extra("finds") -- another add-on's tests, since VoltUI 1.104.0

print("== Tooltips")
local Tt = ns.Tooltips
check(Tt.enabled and GameTooltip.fuiPanel and GameTooltip.NineSlice.alpha == 0, "tooltip: flat panel, Blizzard frame hidden")
GameTooltip.NineSlice:SetAlpha(1)
check(GameTooltip.NineSlice.alpha == 0, "and it stays hidden")
check(ItemRefTooltip.fuiPanel and ItemRefTooltip.bd and ItemRefTooltip.bd[4] == 0, "old-style backdrops cleared too")
check(GameTooltipStatusBar.sbt == "Interface\\Buttons\\WHITE8X8" and GameTooltipStatusBar.h == 12, "flat health bar, tall enough for its text (1.101.17)")
check(GameTooltipText.font and GameTooltipText.font[1]:find("Fonts"), "tooltip text in the Forever UI font")
check(#postCalls >= 1, "item lines hooked")
-- an uncommon cloth item
local items2 = { [2589] = { "Linen Cloth", 1, 5, 7, 0, 13 }, [5469] = { "Strider Meat", 1, 10, 0, 0, 4 }, [774] = { "Malachite", 2, 7, 7, 0, 25 }, [2138] = { "Sharpened Letter Opener", 2, 15, 2, 15, 200 } }
GetItemInfo = function(x)
  local id = tonumber(tostring(x):match("(%d+)"))
  local d = items2[id]; if not d then return nil end
  return d[1], "item:" .. id, d[2], d[3], 1, "", "", 1, "", "icon", d[6]
end
C_Item.GetItemInfo = GetItemInfo
local oldInst = C_Item.GetItemInfoInstant
C_Item.GetItemInfoInstant = function(x)
  local id = tonumber(tostring(x):match("(%d+)"))
  local d = items2[id]; if d then return id, "", "", "", "icon", d[4], d[5] end
  return oldInst(x)
end
GameTooltip.lines, GameTooltip.dlines = {}, {}
tipItem = { "Linen Cloth", "item:2589" }
for _, fn in ipairs(postCalls) do fn(GameTooltip) end
local dl = {}
for _, l in ipairs(GameTooltip.dlines) do dl[#dl + 1] = l[1] .. " = " .. l[2] end
print("  lines: " .. table.concat(GameTooltip.lines, " | ") .. " || " .. table.concat(dl, " | "))
local hasHeader = false
for _, l in ipairs(GameTooltip.lines) do if l:find("Drops from") then hasHeader = true end end
check(hasHeader and GameTooltip.dlines[2][1]:find(ns.TreasureData and "Battered Chest" or "Refreshing Spring Water") and GameTooltip.dlines[3][1]:find("Kul Tiras Marine") and GameTooltip.dlines[3][2]:find("40%%"), "drops from your loot record, best chance first, chests by name with another add-on's data")
check(GameTooltip.dlines[1][1] == "Vendor" and GameTooltip.dlines[1][2] == "12g 34s 56c", "vendor price when the game doesn't show one")
GameTooltip.lines, GameTooltip.dlines = {}, {}
GameTooltip.shownMoneyFrames = 1
for _, fn in ipairs(postCalls) do fn(GameTooltip) end
check(GameTooltip.dlines[1][1] ~= "Vendor", "no vendor line when the game shows its own")
GameTooltip.shownMoneyFrames = nil
do -- 1.101.7: on this client the game's price is a text line, not a money frame
  local oldSell, oldLeft, oldN = SELL_PRICE, GameTooltipTextLeft1.text, GameTooltip.nlines
  SELL_PRICE = "Sell Price"
  GameTooltip.lines, GameTooltip.dlines = {}, {}
  GameTooltipTextLeft1.text, GameTooltip.nlines = "Sell Price: 12g 34s 56c", 1
  for _, fn in ipairs(postCalls) do fn(GameTooltip) end
  check(GameTooltip.dlines[1][1] ~= "Vendor", "no vendor line when the game wrote its own Sell Price line")
  GameTooltipTextLeft1.text = "Linen Cloth"
  GameTooltip.lines, GameTooltip.dlines = {}, {}
  for _, fn in ipairs(postCalls) do fn(GameTooltip) end
  check(GameTooltip.dlines[1][1] == "Vendor", "and one when it didn't")
  SELL_PRICE, GameTooltipTextLeft1.text, GameTooltip.nlines = oldSell, oldLeft, oldN
end
-- gear: rarity border and item level
GameTooltip.lines, GameTooltip.dlines = {}, {}
tipItem = { "Sharpened Letter Opener", "item:2138" }
for _, fn in ipairs(postCalls) do fn(GameTooltip) end
check(GameTooltip.fuiPanel.edges[1].ctex[2] == 1 and GameTooltip.fuiPanel.edges[1].ctex[1] == 0.12, "green border for an uncommon item")
check(GameTooltip.lines[1] == "Item level 15", "item level on gear")
GameTooltip.scripts.OnHide(GameTooltip)
GameTooltip.scripts.OnShow(GameTooltip)
check(math.abs(GameTooltip.fuiPanel.edges[1].ctex[1] - 0.35) < 0.01, "border back to normal for the next tooltip")
SlashCmdList.VOLTUI("tooltips drops")
check(VoltUIDB.tipDrops == false, "tooltip lines can be turned off")
SlashCmdList.VOLTUI("tooltips drops")

check(#unitPostCalls == 1, "creature lines hooked")
Extra("loot", { unitPostCalls = unitPostCalls, Tt = Tt })

print("== Junk")
local sold = {}
C_Container.UseContainerItem = function(b, s) sold[#sold + 1] = b .. ":" .. s; BAGS[b][s] = nil end
BAGS[0][10] = { iconFileID = "g", stackCount = 3, quality = 0, itemID = 4865, hyperlink = "item:4865" }
BAGS[0][11] = { iconFileID = "g", stackCount = 1, quality = 0, itemID = 2138, hyperlink = "item:2138", hasNoValue = true }
BAGS[0][12] = { iconFileID = "g", stackCount = 1, quality = 0, itemID = 5469, hyperlink = "item:5469", isLocked = true }
items2[4865] = { "Ruined Pelt", 0, 1, 15, 0, 5 }
local chatBefore = #chat
fire("MERCHANT_SHOW")
for _ = 1, 20 do runTimers() end
check(#sold >= 1 and sold[1] == "0:6" or sold[1] == "0:10", "greys sold at the vendor: " .. table.concat(sold, ","))
local soldSet = {}
for _, x in ipairs(sold) do soldSet[x] = true end
check(not soldSet["0:11"] and not soldSet["0:12"], "items with no value, or locked, are left alone")
check(not soldSet["0:2"] and not soldSet["0:3"], "nothing but greys")
check(chat[#chat]:find("Sold %d junk item"), "summary: " .. chat[#chat])
fire("MERCHANT_CLOSED")
-- shift skips
BAGS[0][10] = { iconFileID = "g", stackCount = 3, quality = 0, itemID = 4865, hyperlink = "item:4865" }
IsShiftKeyDown = function() return true end
sold = {}
fire("MERCHANT_SHOW")
for _ = 1, 5 do runTimers() end
check(#sold == 0, "hold Shift to skip")
IsShiftKeyDown = function() return false end
fire("MERCHANT_CLOSED")
-- the slot changes before it's sold: not sold
fire("MERCHANT_SHOW")
BAGS[0][10] = { iconFileID = "x", stackCount = 1, quality = 2, itemID = 774, hyperlink = "item:774" }
for _ = 1, 5 do runTimers() end
check(#sold == 0, "re-checked before selling: a slot that changed isn't sold")
fire("MERCHANT_CLOSED")
BAGS[0][10] = nil

-- (1.80.0) greys you've said to keep aren't sold; new items stop being new as you look at them
;(function()
  local J, Bg = ns.Junk, ns.Bags
  local keepWas = VoltUIDB.junkKeep
  VoltUIDB.junkKeep = nil
  BAGS[0][10] = { iconFileID = "g", stackCount = 3, quality = 0, itemID = 4865, hyperlink = "item:4865" }
  J:ToggleKeep(4865, "Ruined Pelt")
  check(J:Keeps(4865) and J:KeepCount() == 1 and chat[#chat]:find("Ruined Pelt is kept", 1, true), "a grey item can be kept: " .. chat[#chat])
  sold = {}
  fire("MERCHANT_SHOW")
  for _ = 1, 10 do runTimers() end
  local soldIt = false
  for _, x in ipairs(sold) do if x == "0:10" then soldIt = true end end
  check(not soldIt and BAGS[0][10] ~= nil, "a kept grey isn't sold at the vendor")
  fire("MERCHANT_CLOSED")
  check(ns.Share:Collect("bags").junkKeep ~= nil, "the keep list travels with the bags' settings")

  -- in the bags: Alt-right-click toggles it, and the tooltip says which way it is
  local win = Bg.windows.bags
  Bg:Open()
  Bg:Layout(win)
  local pelt
  for _, b in ipairs(win.shown or {}) do if b.fuiItem and b.fuiItem.id == 4865 then pelt = b end end
  check(pelt ~= nil, "the grey item has a slot in the bags")
  if pelt then
    local altWas = IsAltKeyDown
    pelt.scripts.OnClick(pelt, "RightButton")
    check(J:Keeps(4865), "a plain right-click leaves the keep list alone")
    IsAltKeyDown = function() return true end
    pelt.scripts.OnClick(pelt, "LeftButton")
    check(J:Keeps(4865), "so does Alt and the left button (that's the web link)")
    pelt.scripts.OnClick(pelt, "RightButton")
    check(not J:Keeps(4865) and VoltUIDB.junkKeep == nil and chat[#chat]:find("sold with your junk again", 1, true), "Alt-right-click stops keeping it")
    pelt.scripts.OnClick(pelt, "RightButton")
    check(J:Keeps(4865), "and again keeps it")
    IsAltKeyDown = altWas
  end
  J:ForgetKept()
  check(J:KeepCount() == 0, "the settings page's button forgets them all")

  -- new items: closing the bags makes them all not new, hovered or not (1.92.2)
  local newWas = C_NewItems
  local new = { ["0:10"] = true, ["0:13"] = true }
  C_NewItems = {
    IsNewItem = function(bag, slot) return new[bag .. ":" .. slot] or false end,
    RemoveNewItem = function(bag, slot) new[bag .. ":" .. slot] = nil end,
    ClearAll = function() for k in pairs(new) do new[k] = nil end end,
  }
  BAGS[0][13] = { iconFileID = "n", stackCount = 1, quality = 1, itemID = 117, hyperlink = "item:117" }
  Bg:Layout(win)
  local a, b2
  for _, b in ipairs(win.shown or {}) do
    if b.fuiBag == 0 and b.fuiSlot == 10 then a = b end
    if b.fuiBag == 0 and b.fuiSlot == 13 then b2 = b end
  end
  check(a and b2 and a.fuiItem.new and b2.fuiItem.new and a.fuiNew.shown and win.newBtn and win.newBtn.shown, "new items are marked, under a New heading you can click")
  if a and b2 then
    a.scripts.OnEnter(a)
    check(a.fuiItem.new and a.fuiNew.shown, "hovering one leaves it in New while the bags are open")
    win.frame:Hide()
    check(next(new) == nil, "closing the bags: none is new any more, the one never hovered too")
    Bg:Open()
    Bg:Layout(win)
    check(not a.fuiItem.new and not b2.fuiItem.new and not win.newBtn.shown, "opened again: both sorted into their own categories, no New heading")
    -- with only RemoveNewItem, each new item is removed one by one
    local clearAll = C_NewItems.ClearAll
    C_NewItems.ClearAll = nil
    new["0:10"], new["0:13"] = true, true
    Bg:Layout(win)
    win.frame:Hide()
    check(next(new) == nil, "a client without ClearAll: each new one removed")
    C_NewItems.ClearAll = clearAll
    new["0:10"], new["0:13"] = true, true
    Bg:Open()
    Bg:Layout(win)
    win.newBtn.scripts.OnClick(win.newBtn)
    check(next(new) == nil and not win.newBtn.shown, "clicking the New heading: all seen, and the heading goes")
  end
  C_NewItems = newWas
  BAGS[0][10], BAGS[0][13] = nil, nil
  VoltUIDB.junkKeep = keepWas
  Bg:Layout(win)
end)()

print("== Fonts redraw")
local lbl = VoltUILoot.title
local lblText = lbl.text
lbl.redraws = 0
local oldSet = lbl.SetText
lbl.SetText = function(self, t) self.redraws = self.redraws + 1; oldSet(self, t) end
SlashCmdList.VOLTUI("font rajdhani")
check(lbl.font[1]:find("Rajdhani") and lbl.redraws >= 1 and lbl.text == lblText, "text redrawn in the new font")
SlashCmdList.VOLTUI("font barlow")
check(lbl.font[1]:find("Barlow") and lbl.text == lblText, "and back again")

print("== Settings")
SlashCmdList.VOLTUI("alpha 0.5")
check(math.abs(f.fuiPanel.fill.ctex[4] - 0.5) < 1e-9 and math.abs(strip.fuiPanel.fill.ctex[4] - 0.5) < 1e-9, "opacity applies everywhere")
SlashCmdList.VOLTUI("common")
check(VoltUIDB.common, "common toggle")
SlashCmdList.VOLTUI("map off")
check(VoltUIDB.map == false and chat[#chat]:find("reload"), "modules switch off (after reload)")
SlashCmdList.VOLTUI("help")
check(chat[#chat]:find("edit") and chat[#chat]:find("bags") and chat[#chat]:find("errors"), "help")

print("== Unit frames")
for k, fn in pairs(unitApi) do _G[k] = fn end
UNITS = {
  player = { hp = 269, hpMax = 269, pw = 171, pwMax = 171, level = 7, isPlayer = true, class = "SHAMAN", reaction = 5 },
  target = { hp = 40, hpMax = 80, pw = 10, pwMax = 20, ptoken = "RAGE", level = 9, reaction = 2, classif = "elite", enemy = true },
  targettarget = { hp = 269, hpMax = 269 },
  pet = { hp = 30, hpMax = 60, pw = 5, pwMax = 10 },
}
function UnitExists(u) return UNITS[u] ~= nil end
function UnitIsDead(u) return unitInfo(u).dead end
function UnitName(u) return unitInfo(u).name or u end
UNITS.player.name, UNITS.target.name = "Test Hero", "Razormane Scout"
local now = 100
GetTime = function() return now end
local U, CB, St = ns.UnitFrames, ns.Castbar, ns.Style
local P, T, ToT, Pet = VoltUIPlayerFrame, VoltUITargetFrame, VoltUIToTFrame, VoltUIPetFrame
local started = true
for _, m in ipairs(chat) do if m:find("couldn't start") then started = false end end
check(started, "every module starts")
check(VoltUIDB.frames and VoltUIDB.castbar and VoltUIDB.targetCast and VoltUIDB.frameScale == 1, "defaults on")

-- Blizzard's frames
local hidden = St.HiddenParent()
for _, b in ipairs({ PlayerFrame, TargetFrame, PetFrame, TargetFrameToT, TargetFrameSpellBar, ComboFrame }) do
  check(b.parent == hidden and b.shown == false and b.allOff, "Blizzard frame hidden and silent")
end
check(PlayerFrame.healthbar.allOff, "its bars stop listening too")
for _, b in ipairs({ PlayerFrame, TargetFrame, PetFrame, TargetFrameToT }) do check(not unitWatch[b], "Blizzard frame off unit watch") end
check(TotemFrame.parent == UIParent and TotemFrame.shown ~= false, "totem frame moved out, still showing")
check(TotemFrame.scripts.OnShow == nil, "and the game no longer takes it back into its hidden player frame when it shows (1.101.3)")
check(TotemFrame.points[1][2] == P, "totems sit on the VoltUI player frame")
TotemFrame:SetPoint("TOPLEFT", PlayerFrame, "BOTTOMLEFT", 0, 0)
check(#TotemFrame.points == 1 and TotemFrame.points[1][2] == P, "and stay there when Blizzard re-anchors them")
check(PlayerCastingBarFrame.parent == hidden and PlayerCastingBarFrame.barUnit == "none" and PlayerCastingBarFrame.allOff, "Blizzard's cast bar gone")

-- Secure setup
for _, fr in ipairs({ P, T, ToT, Pet }) do
  check(fr.tmpl == "SecureUnitButtonTemplate" and fr.attrs.type1 == "target" and fr.attrs.type2 == "togglemenu", "click targets, right-click menu")
  check(ClickCastFrames[fr], "click-cast add-ons can see it")
end
check(P.attrs.unit == "player" and T.attrs.unit == "target" and ToT.attrs.unit == "targettarget" and Pet.attrs.unit == "pet", "right units")
check(unitWatch[T] and unitWatch[ToT] and unitWatch[Pet] and not unitWatch[P], "only the player frame stays up without a unit")
check(P.fuiPanel.fill.ctex[1] == 0.04 and P.fuiPanel.edges[1].ctex[1] == 0.35, "shared panel colours")
check(P.h == 18 + 20 + 1 + 12 + 1 and ToT.h == 16 + 10 + 1 and Pet.h == 16 + 10 + 1 + 5 + 1, "heights fit the bars")

-- Player
fire("PLAYER_ENTERING_WORLD")
check(P.name.text == "Test Hero" and P.name.color[1] == 0.5, "player name in the accent colour")
check(P.hp.minv == 0 and P.hp.maxv == 269 and P.hp.value == 269, "health bar")
check(P.hpText.text == "269 / 269" and P.hpPct.text == "100%", "health text: " .. tostring(P.hpText.text))
check(P.pwText.text == "171 / 171" and P.pw.value == 171, "power text")
check(P.level.text == 7, "level")
local vc = P.hp:GetStatusBarTexture().vc
check(vc[1] == 0 and vc[2] == 0.44, "class colour on your health")
SlashCmdList.VOLTUI("frames class")
vc = P.hp:GetStatusBarTexture().vc
check(not VoltUIDB.classColor and vc[1] == 0.3 and vc[2] == 0.7, "class colours can be turned off")
SlashCmdList.VOLTUI("frames class")
UNITS.player.hp = 100
fire("UNIT_HEALTH", "nameplate1")
check(P.hp.value == 269, "other units' events don't touch it")
fire("UNIT_HEALTH", "player")
check(P.hp.value == 100 and P.hpText.text == "100 / 269" and P.hpPct.text == "37%", "health updates: " .. tostring(P.hpPct.text))
UNITS.player.pw = 20
fire("UNIT_POWER_FREQUENT", "player")
check(P.pwText.text == "20 / 171", "power updates")
-- Incoming heals and shields on your health bar (1.29.0).
UnitGetIncomingHeals = function(u) return unitInfo(u).heals or 0 end
UnitGetTotalAbsorbs = function(u) return unitInfo(u).shields or 0 end
UNITS.player.heals, UNITS.player.shields = 120, 30
fire("UNIT_HEAL_PREDICTION", "player")
check(P.heal.value == 120 and P.heal.maxv == 269 and P.shield.value == 30 and P.shield.maxv == 269, "incoming heals and shields on your health bar")
check(P.heal.points[1][2] == P.hp:GetStatusBarTexture() and P.shield.points[1][2] == P.heal:GetStatusBarTexture(),
  "straight after your health, then the shields")
check(P.heal.w == 228 and P.shield.w == 228, "as wide as the health bar, so they fill the same way")
check(P.overheal.alpha == 0 and P.overshield.alpha == 0, "169 missing: no overhealing")
UNITS.player.heals = 200
fire("UNIT_ABSORB_AMOUNT_CHANGED", "player")
check(P.heal.value == 200 and P.overheal.alpha == 1 and P.overshield.alpha == 1, "more coming than missing: the bright edges")
check(P.hpText:GetParent() == P.hpTop and P.hpTop.flevel == P.hp:GetFrameLevel() + 3, "the health numbers stay above the heals")
UNITS.target.heals = 10
fire("UNIT_HEAL_PREDICTION", "target")
check(T.heal.value == 0, "off on the target frame unless you turn it on")
U:Cfg("target").heals = true
fire("UNIT_HEAL_PREDICTION", "target")
check(T.heal.value == 10, "and on")
U:Cfg("target").heals = false
U:Cfg("player").heals = false
fire("UNIT_HEALTH", "player")
check(P.heal.value == 0 and P.shield.value == 0 and P.overheal.alpha == 0 and P.overshield.alpha == 0, "switched off on the player frame")
U:Cfg("player").heals = true
UNITS.player.dead = true
fire("UNIT_HEALTH", "player")
check(P.heal.value == 0 and P.overheal.alpha == 0, "nothing while you're dead")
UNITS.player.dead, UNITS.player.heals, UNITS.player.shields, UNITS.target.heals = nil, nil, nil, nil
fire("UNIT_HEALTH", "player")
UNITS.player.combat = true
fire("PLAYER_REGEN_ENABLED")
check(P.tag.text:find("Combat"), "combat tag")
UNITS.player.combat, UNITS.resting = nil, true
fire("PLAYER_UPDATE_RESTING")
check(P.tag.text:find("Rested") and not P.tag.text:find("Combat"), "rested tag")
UNITS.resting, UNITS.player.lead, UNITS.player.pvp = nil, true, true
fire("PARTY_LEADER_CHANGED")
check(P.tag.text:find("Lead") and P.tag.text:find("PvP"), "leader and PvP tags")
UNITS.player.lead, UNITS.player.pvp = nil, nil
UNITS.player.dead = true
fire("UNIT_HEALTH", "player")
check(P.hpText.text == "Dead" and P.hpPct.text == "", "dead")
UNITS.player.dead, UNITS.player.ghost = nil, true
fire("UNIT_HEALTH", "player")
check(P.hpText.text == "Ghost", "ghost")
UNITS.player.ghost = nil

-- Target
local fsounds = {}
PlaySound = function(id) fsounds[#fsounds + 1] = id end
SOUNDKIT = { INTERFACE_SOUND_LOST_TARGET_UNIT = "lost", IG_CREATURE_AGGRO_SELECT = "aggro", IG_CHARACTER_NPC_SELECT = "npc", IG_CREATURE_NEUTRAL_SELECT = "neutral" }
fsounds = {}
fire("PLAYER_TARGET_CHANGED")
check(T.name.text == "Razormane Scout", "target name")
check(T.tag.text:find("Elite"), "elite tag")
check(T.level.text == 9 and T.level.color[2] == 1, "level in its difficulty colour")
vc = T.hp:GetStatusBarTexture().vc
check(vc[1] == 0.8 and T.name.color[1] == 0.8, "hostile: red")
check(T.hpText.text == "40 / 80" and T.hpPct.text == "50%", "target health")
check(T.pw:GetStatusBarTexture().vc[1] == 0.85, "rage colour")
check(fsounds[1] == "aggro", "hostile target sound")
UNITS.target.reaction = 4
fire("UNIT_FACTION", "target")
check(T.hp:GetStatusBarTexture().vc[1] == 0.9 and T.name.color[1] == 0.9, "neutral: yellow")
UNITS.target.reaction, UNITS.target.tapped = 2, true
fire("UNIT_FACTION", "target")
check(T.hp:GetStatusBarTexture().vc[1] == 0.5, "tapped by someone else: grey")
UNITS.target.tapped, UNITS.target.level = nil, -1
fire("PLAYER_TARGET_CHANGED")
check(T.level.text == "??", "skull level")
UNITS.target.level, UNITS.target.pwMax = 9, 0
fire("UNIT_MAXPOWER", "target")
check(T.pwText.text == "", "no power, no numbers")
UNITS.target.pwMax, UNITS.target.isPlayer, UNITS.target.connected = 20, true, false
UNITS.target.class = "ROGUE"
fire("PLAYER_TARGET_CHANGED")
check(T.hpText.text == "Offline" and T.hp:GetStatusBarTexture().vc[1] == 1, "offline player, class coloured")
UNITS.target.isPlayer, UNITS.target.connected, UNITS.target.class = nil, nil, nil
UNITS.target.raid = 8
fire("RAID_TARGET_UPDATE")
check(T.raid.shown and T.raid.raidIndex == 8, "raid icon")
UNITS.target.raid = nil
fire("RAID_TARGET_UPDATE")
check(not T.raid.shown, "raid icon cleared")
local keep = UNITS.target
UNITS.target = nil
fsounds = {}
fire("PLAYER_TARGET_CHANGED")
check(fsounds[1] == "lost", "lost-target sound")
UNITS.target = keep

-- Small frames
ToT.name.text = ""
ToT.scripts.OnUpdate(ToT, 0.1)
check(ToT.name.text == "", "target of target checks now and then, not every frame")
ToT.scripts.OnUpdate(ToT, 0.2)
check(ToT.name.text == "targettarget" and ToT.hp.value == 269, "target of target updates")
check(ToT.hpText.shown == false and ToT.pw.shown == false and ToT.level.shown == false, "target of target: name and health only")
fire("UNIT_PET", "player")
check(Pet.name.text == "pet" and Pet.hp.value == 30 and Pet.pw.value == 5 and Pet.hpText.shown == false, "pet frame")

-- Auras
local AURAS = { HARMFUL = {}, HELPFUL = {} }
local tipAura
function GameTooltip:SetUnitAuraByAuraInstanceID(u, id) tipAura = id end
C_UnitAuras = { GetAuraDataByIndex = function(_, i, filter) return AURAS[filter][i] end }
AURAS.HARMFUL[1] = { icon = "d1", applications = 3, duration = 10, expirationTime = 150, dispelName = "Magic", auraInstanceID = 11 }
AURAS.HARMFUL[2] = { icon = "d2", applications = 0, duration = 0, expirationTime = 0, isFromPlayerOrPlayerPet = true, auraInstanceID = 12 }
AURAS.HELPFUL[1] = { icon = "b1", applications = 1, duration = 5, expirationTime = 120, auraInstanceID = 13 }
fire("UNIT_AURA", "player")
check(#U.auras == 0, "other units' auras ignored")
fire("UNIT_AURA", "target")
local a = U.auras
check(#a == 3 and a[1].icon.tex == "d1" and a[3].icon.tex == "b1", "debuffs first, then buffs")
check(a[1].count.text == 3 and a[2].count.text == "", "stacks only above one")
check(a[1].cd.cooldown[1] == 140 and a[1].cd.cooldown[2] == 10 and a[2].cd.shown == false, "cooldown spiral only with a duration")
check(a[1].edges[1].ctex[1] == 0.2, "dispel type colours the border")
check(a[2].edges[1].ctex[1] == 0.5, "yours in the accent colour")
a[1].scripts.OnEnter(a[1])
check(tipAura == 11, "aura tooltip")
check(a[1].points[1][4] == 0 and a[2].points[1][4] == 25, "icons in a row")
for i = 3, 20 do AURAS.HARMFUL[i] = { icon = "x", applications = 0, duration = 0, expirationTime = 0, auraInstanceID = 100 + i } end
fire("UNIT_AURA", "target")
check(#a == 16 and a[10].points[1][5] == 25 and a[10].points[1][4] == 0, "stops at 16, next row goes up")
for i = 3, 20 do AURAS.HARMFUL[i] = nil end
AURAS.HARMFUL[2] = nil
fire("UNIT_AURA", "target")
check(a[1].shown and a[2].icon.tex == "b1" and a[3].shown == false and a[16].shown == false, "gone auras hide")
AURAS.HARMFUL[1] = nil

-- Castbar
local Bar, TBar = VoltUICastbar, VoltUITargetCastbar
check(Bar.shown == false and TBar.shown == false, "cast bars hidden until something casts")
check(TBar.parent == T, "target bar belongs to the target frame")
check(U.auraRow.points[1][2] == T, "auras above the target frame")
castInfo.player = { name = "Lightning Bolt", icon = "bolt", st = 100000, en = 102000, guid = "g1" }
fire("UNIT_SPELLCAST_START", "player", "g1")
check(Bar.shown and Bar.label.text == "Lightning Bolt" and Bar.icon.tex == "bolt", "cast shows")
check(Bar.bar.maxv == 2 and Bar.bar:GetStatusBarTexture().vc[1] == 0.5, "accent colour, runs for the cast time")
now = 101
Bar.scripts.OnUpdate(Bar, 1)
check(Bar.bar.value == 1 and Bar.time.text == "1.0", "fills as it goes")
fire("UNIT_SPELLCAST_FAILED", "player", "g2")
check(Bar.mode == "cast", "another spell failing doesn't end this cast")
fire("UNIT_SPELLCAST_STOP", "player", "g2")
check(Bar.mode == "cast", "another cast's stop doesn't end this one")
castInfo.player.en = 103000
fire("UNIT_SPELLCAST_DELAYED", "player", "g1")
check(Bar.bar.maxv == 3, "pushback extends it")
castInfo.player = nil
fire("UNIT_SPELLCAST_STOP", "player", "g1")
check(Bar.mode == "fade" and Bar.bar.value == 1 and Bar.time.text == "", "finished cast fills up and fades")
Bar.scripts.OnUpdate(Bar, 0.1)
check(Bar.alpha < 1 and Bar.shown, "fading")
Bar.scripts.OnUpdate(Bar, 1)
check(Bar.shown == false and Bar.mode == nil and Bar.alpha == 1, "then gone")
castInfo.player = { name = "Heal", icon = "h", st = 101000, en = 103000, guid = "g3" }
fire("UNIT_SPELLCAST_START", "player", "g3")
castInfo.player = nil
fire("UNIT_SPELLCAST_INTERRUPTED", "player", "g3")
check(Bar.label.text == "Interrupted" and Bar.bar:GetStatusBarTexture().vc[1] == 0.85, "interrupted: red")
fire("UNIT_SPELLCAST_STOP", "player", "g3")
check(Bar.label.text == "Interrupted", "the stop after an interrupt doesn't hide the message")
Bar.scripts.OnUpdate(Bar, 0.3)
check(Bar.alpha == 1, "message holds")
Bar.scripts.OnUpdate(Bar, 1)
check(Bar.shown == false, "then fades")
castInfo.player = { name = "Heal", icon = "h", st = 101000, en = 103000, guid = "g4" }
fire("UNIT_SPELLCAST_START", "player", "g4")
castInfo.player = nil
fire("UNIT_SPELLCAST_FAILED", "player", "g4")
check(Bar.label.text == "Failed", "failed")
Bar.scripts.OnUpdate(Bar, 2)
chanInfo.player = { name = "Drain", icon = "c", st = 101000, en = 105000 }
fire("UNIT_SPELLCAST_CHANNEL_START", "player")
check(Bar.mode == "channel" and Bar.bar:GetStatusBarTexture().vc[1] == 0.45 and Bar.bar.value == 4, "channel: green, starts full")
now = 102
Bar.scripts.OnUpdate(Bar, 1)
check(Bar.bar.value == 3, "channel empties")
fire("UNIT_SPELLCAST_FAILED", "player", "zz")
check(Bar.mode == "channel", "a failed spell doesn't end a channel")
chanInfo.player = nil
fire("UNIT_SPELLCAST_CHANNEL_STOP", "player")
check(Bar.mode == "fade", "channel ends")
Bar.scripts.OnUpdate(Bar, 2)
-- target cast
castInfo.target = { name = "Shadow Bolt", icon = "s", st = 102000, en = 104000, guid = "t1", locked = true }
fire("UNIT_SPELLCAST_START", "target", "t1")
check(TBar.shown and Bar.shown == false, "target's cast only on the target's bar")
check(TBar.bar:GetStatusBarTexture().vc[1] == 0.55, "can't be interrupted: grey")
check(U.auraRow.points[1][2] == TBar, "auras move up above the cast bar")
castInfo.target = nil
fire("PLAYER_TARGET_CHANGED")
check(TBar.shown == false and U.auraRow.points[1][2] == T, "new target: bar gone, auras back down")
castInfo.target = { name = "Shadow Bolt", icon = "s", st = 102000, en = 104000, guid = "t2" }
fire("PLAYER_TARGET_CHANGED")
check(TBar.shown and TBar.label.text == "Shadow Bolt", "targeting something mid-cast shows it")
castInfo.target = nil
fire("PLAYER_TARGET_CHANGED")
-- 1.101.7: someone else's cast has no readable GUID; events are matched by the cast bar's id
castInfo.target = { name = "Shadow Bolt", icon = "s", st = 102000, en = 104000, barID = 5 }
fire("UNIT_SPELLCAST_START", "target", nil, 686, 5)
check(TBar.barID == 5 and TBar.guid == nil, "the cast bar's id is kept, the GUID isn't there to keep")
fire("UNIT_SPELLCAST_FAILED", "target", nil, 695, 6)
check(TBar.mode == "cast" and TBar.label.text == "Shadow Bolt", "a failure for another cast bar id doesn't end this cast")
fire("UNIT_SPELLCAST_INTERRUPTED", "target", nil, 695, 6)
check(TBar.mode == "cast", "nor does an interrupt for another id")
castInfo.target.locked = true
fire("UNIT_SPELLCAST_NOT_INTERRUPTIBLE", "target")
check(TBar.bar:GetStatusBarTexture().vc[1] == 0.55, "a cast that turns uninterruptible part-way goes grey")
castInfo.target.locked = nil
fire("UNIT_SPELLCAST_INTERRUPTIBLE", "target")
check(TBar.bar:GetStatusBarTexture().vc[1] ~= 0.55, "and back when it can be interrupted again")
castInfo.target = nil
fire("UNIT_SPELLCAST_INTERRUPTED", "target", nil, 686, 5)
check(TBar.label.text == "Interrupted", "the same id ends it")
TBar.scripts.OnUpdate(TBar, 5)
castInfo.target = { name = "Shadow Bolt", icon = "s", st = 102000, en = 104000 }
fire("UNIT_SPELLCAST_START", "target")
castInfo.target = nil
fire("UNIT_SPELLCAST_FAILED", "target")
check(TBar.label.text == "Failed", "with no id from the game it's as before")
TBar.scripts.OnUpdate(TBar, 5)
fire("PLAYER_TARGET_CHANGED")
-- a lost stop event can't leave the bar stuck
castInfo.player = { name = "Heal", icon = "h", st = 101000, en = 102500, guid = "g9" }
fire("UNIT_SPELLCAST_START", "player", "g9")
castInfo.player = nil
now = 104
Bar.scripts.OnUpdate(Bar, 0.1)
check(Bar.mode == "fade", "a lost stop event can't leave the bar stuck")
Bar.scripts.OnUpdate(Bar, 2)
-- sample
SlashCmdList.VOLTUI("castbar test")
check(Bar.shown and TBar.shown and Bar.label.text == "Sample cast", "/volt castbar test")
now = now + 3.5
Bar.scripts.OnUpdate(Bar, 0.1)
check(Bar.mode == "fade", "sample ends by itself")
Bar.scripts.OnUpdate(Bar, 2)
TBar.scripts.OnUpdate(TBar, 0.1)
TBar.scripts.OnUpdate(TBar, 2)
check(Bar.shown == false and TBar.shown == false, "sample gone")

-- Combo points
check(rawget(U, "pips") == nil, "no combo pips on a Shaman")
playerClass = "ROGUE"
UNITS.player.class = "ROGUE"
combo = 3
U:BuildPips()
U:UpdatePips()
check(#U.pips.pips == 5 and U.pips.pips[3].value == 3 and U.pips.pips[3].minv == 2 and U.pips.pips[3].maxv == 3, "five pips, filled by the count")
check(U.pips.shown, "Rogue: always there")
combo = 4
fire("UNIT_POWER_UPDATE", "player")
check(U.pips.pips[1].value == 4, "pips update")
U.pips.druid, combo = true, 0
U:UpdatePips()
check(U.pips.shown == false, "Druid: only with points")
combo = 1
U:UpdatePips()
check(U.pips.shown, "Druid: shows with points")
combo = 0
playerClass, UNITS.player.class = "SHAMAN", "SHAMAN"
U.pips = nil

-- Secret values: bars and text take them untouched, and Lua never does sums on them.
local SecretMeta = {}
local function boom() error("a secret value was used in Lua", 2) end
for _, m in ipairs({ "__add", "__sub", "__mul", "__div", "__mod", "__idiv", "__unm", "__concat", "__len", "__lt", "__le", "__tostring", "__call", "__index", "__newindex" }) do SecretMeta[m] = boom end
local function Secret() return setmetatable({}, SecretMeta) end
issecretvalue = function(v) return getmetatable(v) == SecretMeta end
local sHp, sMax, sPw = Secret(), Secret(), Secret()
UnitHealth, UnitHealthMax = function() return sHp end, function() return sMax end
UnitPower, UnitPowerMax = function() return sPw end, function() return sPw end
UnitPowerType = function() return Secret(), Secret() end
UnitName, UnitLevel = function() return Secret() end, function() return Secret() end
UnitClass = function() return Secret(), Secret() end
for _, k in ipairs({ "UnitIsPlayer", "UnitReaction", "UnitIsTapDenied", "UnitIsConnected", "UnitIsDead", "UnitIsGhost", "UnitClassification", "UnitAffectingCombat", "UnitIsGroupLeader", "UnitIsPVP", "GetRaidTargetIndex", "UnitIsEnemy", "UnitIsFriend", "GetComboPoints" }) do
  _G[k] = function() return Secret() end
end
UnitExists = function() return Secret() end
CurveConstants = { ScaleTo100 = "to100" }
local pctAsked
UnitHealthPercent = function(_, _, curve) pctAsked = curve; return Secret() end
C_StringUtil = { RoundToNearestString = function(v) return v end }
local ok, err = pcall(function()
  fire("PLAYER_ENTERING_WORLD")
  fire("UNIT_HEALTH", "target")
  fire("UNIT_POWER_UPDATE", "target")
  fire("PLAYER_TARGET_CHANGED")
  fire("UNIT_FACTION", "target")
  fire("PLAYER_FLAGS_CHANGED")
  fire("RAID_TARGET_UPDATE")
  ToT.scripts.OnUpdate(ToT, 1)
end)
check(ok, "secret unit values: no errors: " .. tostring(err))
check(T.hp.value == sHp and T.hp.maxv == sMax, "secret health goes straight into the bar")
check(T.hpText.text == "<secret>" and T.hpPct.text == "<secret>" and pctAsked == "to100", "secret health text comes from the game")
check(T.pw.value == sPw and T.pwText.text == "<secret>", "secret power")
check(T.level.text == "", "secret level just isn't shown")
check(issecretvalue(T.name.text), "secret name still shows")
-- In a fight the game's heal calculator answers in secrets, its overheal answers too (1.29.1:
-- testing one with `and`/`or` stopped the player frame). They go to the bars untouched.
do
  local sh, ss, sOver, sShieldOver = Secret(), Secret(), Secret(), Secret()
  St.healCalc = nil
  CreateUnitHealPredictionCalculator = function()
    return { GetIncomingHeals = function() return sh, Secret(), Secret(), sOver end,
             GetDamageAbsorbs = function() return ss, sShieldOver end }
  end
  UnitGetDetailedHealPrediction = function() return true end
  for _, t in ipairs({ P.overheal, P.overshield }) do
    t.SetAlphaFromBoolean = function(self, v, a, b) self.alphaFrom = { v, a, b } end
  end
  ok, err = pcall(fire, "UNIT_HEAL_PREDICTION", "player")
  check(ok, "secret heal answers: no errors: " .. tostring(err))
  check(P.heal.value == sh and P.shield.value == ss, "secret heals and shields go straight into the bars")
  check(P.overheal.alphaFrom and P.overheal.alphaFrom[1] == sOver and P.overshield.alphaFrom[1] == sShieldOver,
    "and the secret overheal answers light the edges through the game")
  CreateUnitHealPredictionCalculator, UnitGetDetailedHealPrediction = nil, nil
  St.healCalc = nil
end
-- A secret true/false can't be tested in the game (no `x and`, `x or`, `if x`, `x ==`), and
-- plain Lua can't copy that error, so the heal code is read for it.
do
  local NAMES = { "heals", "shields", "healOver", "shieldOver", "flag", "v" }
  local function body(file, from, to)
    local src = assert(io.open(DIR .. "/" .. file)):read("*a")
    local a = assert(src:find(from, 1, true), from)
    local b = assert(src:find(to, a, true), to)
    return src:sub(a, b)
  end
  local bad = {}
  for _, part in ipairs({
    { "Style.lua", "function S.Predict(u)", "-- Without the calculator" },
    { "Style.lua", "function S.SetAmount(", "\nend" },
    { "Style.lua", "function S.ShowIf(", "  else\n" },
    { "UnitFrames.lua", "function U:UpdateHeals(", "\nend" },
    { "Raid.lua", "local heals, shields, healOver, shieldOver = Predict(u)", "-- Status:" },
  }) do
    local code = body(part[1], part[2], part[3]):gsub("%-%-[^\n]*", "")
    for _, n in ipairs(NAMES) do
      for _, pat in ipairs({ "and%s+" .. n .. "%f[^%w_]", "%f[%w_]" .. n .. "%s+or%f[^%w_]", "if%s+" .. n .. "%s+then",
                             "%f[%w_]" .. n .. "%s*[=~]=", "not%s+" .. n .. "%f[^%w_]" }) do
        if code:find(pat) then bad[#bad + 1] = part[1] .. ": " .. n end
      end
    end
  end
  check(#bad == 0, "the heal code never tests a value that can be secret: " .. table.concat(bad, ", "))
end
ok, err = pcall(function() SlashCmdList.VOLTUI("font rajdhani"); SlashCmdList.VOLTUI("font barlow") end)
check(ok, "changing font with a secret name on screen: " .. tostring(err))
-- secret auras
local durObj = {}
C_UnitAuras = {
  GetAuraDataByIndex = function(_, i, f) if i == 1 and f == "HARMFUL" then return { icon = Secret(), applications = Secret(), duration = Secret(), expirationTime = Secret(), dispelName = Secret(), isFromPlayerOrPlayerPet = Secret(), auraInstanceID = 77 } end end,
  GetAuraApplicationDisplayCount = function(_, id, lo, hi) return "x" .. id end,
  GetAuraDuration = function() return durObj end,
}
ok, err = pcall(function() fire("UNIT_AURA", "target") end)
check(ok, "secret auras: no errors: " .. tostring(err))
check(a[1].count.text == "x77" and a[1].cd.cooldownObj == durObj and a[1].cd.shown, "secret aura: count and spiral from the game")
-- secret cast
local cObj = { GetRemainingDuration = function() return Secret() end }
local sLocked = Secret()
UnitCastingDuration = function() return cObj end
Enum.StatusBarTimerDirection = { ElapsedTime = 0, RemainingTime = 1 }
C_CurveUtil = { EvaluateColorValueFromBoolean = function(flag, a1, b1) if flag == sLocked then return a1 end; return b1 end }
castInfo.target = { name = Secret(), icon = Secret(), st = Secret(), en = Secret(), guid = Secret(), locked = sLocked }
ok, err = pcall(function()
  fire("UNIT_SPELLCAST_START", "target", Secret())
  TBar.scripts.OnUpdate(TBar, 0.1)
end)
check(ok, "secret cast: no errors: " .. tostring(err))
check(TBar.shown and TBar.bar.timerDur == cObj and TBar.bar.timerDir == 0 and TBar.time.text == "<secret>", "secret cast: the game's duration drives the bar")
check(TBar.bar:GetStatusBarTexture().vc[1] == 0.55, "secret can't-interrupt still colours it")
ok, err = pcall(function() fire("UNIT_SPELLCAST_STOP", "target", Secret()) end)
check(ok and TBar.mode == "fade", "secret cast ends: " .. tostring(err))
TBar.scripts.OnUpdate(TBar, 2)
castInfo.target = nil
issecretvalue = nil
for k, fn in pairs(unitApi) do _G[k] = fn end
function UnitExists(u) return UNITS[u] ~= nil end
function UnitIsDead(u) return unitInfo(u).dead end
function UnitName(u) return unitInfo(u).name or u end
C_UnitAuras = { GetAuraDataByIndex = function(_, i, filter) return AURAS[filter][i] end }
AURAS.HARMFUL[1] = { icon = "d1", applications = 3, duration = 10, expirationTime = 150, auraInstanceID = 11 }
fire("PLAYER_TARGET_CHANGED")
fire("UNIT_AURA", "target")
check(a[1].shown, "back to plain values")

-- The game refusing auras during a fight
do
  local allowed = C_UnitAuras.GetAuraDataByIndex
  local function refuse() error("GetAuraDataByIndex(): Auras cannot be accessed when secret while tainted by 'VoltUI'") end
  C_UnitAuras.GetAuraDataByIndex = refuse
  fire("UNIT_AURA", "target")
  check(not a[1].shown, "refused auras aren't an error, and nothing old stays up")
  C_UnitAuras.GetAuraDataByIndex = allowed
  fire("PLAYER_REGEN_ENABLED")
  check(a[1].shown, "they come back when combat ends")
  local asks = 0
  C_UnitAuras.GetAuraDataByIndex = function(u, i, filter)
    asks = asks + 1
    if i == 1 then return allowed(u, i, filter) end
    refuse()
  end
  AURAS.HELPFUL[1] = { icon = "b1", applications = 1, duration = 5, expirationTime = 120, auraInstanceID = 13 }
  AURAS.HARMFUL[2] = { icon = "d2", applications = 0, duration = 8, expirationTime = 130, auraInstanceID = 12 }
  fire("UNIT_AURA", "target")
  check(not a[1].shown, "refused partway with no other way to ask: nothing half-read shows")
  check(asks == 2, "and it stops asking once refused")
  -- 1.92.1: in a fight they're read by instance id instead
  local byId = {}
  for _, f in ipairs({ "HARMFUL", "HELPFUL" }) do for _, x in ipairs(AURAS[f]) do byId[x.auraInstanceID] = x end end
  C_UnitAuras.GetUnitAuraInstanceIDs = function(u, filter)
    local out = {}
    for _, x in ipairs(AURAS[filter]) do out[#out + 1] = x.auraInstanceID end
    return out
  end
  C_UnitAuras.GetAuraDataByAuraInstanceID = function(u, id) return byId[id] end
  fire("UNIT_AURA", "target")
  check(a[1].shown and a[1].icon.tex == "d1" and a[2].shown and a[2].icon.tex == "d2" and a[3].shown and a[3].icon.tex == "b1",
    "in a fight the target's debuffs and buffs are read by id, all of them")
  -- a debuff whose data is hidden keeps the icon it had; a new one is a question mark
  byId[12] = nil
  AURAS.HARMFUL[3] = { auraInstanceID = 14 }
  fire("UNIT_AURA", "target")
  check(a[2].shown and a[2].icon.tex == "d2", "one whose data is hidden keeps its icon")
  check(a[3].shown and a[3].icon.tex:find("QuestionMark") and a[4].icon.tex == "b1", "one never seen is a question mark, the buffs after it")
  C_UnitAuras.GetUnitAuraInstanceIDs, C_UnitAuras.GetAuraDataByAuraInstanceID = nil, nil
  AURAS.HELPFUL[1], AURAS.HARMFUL[2], AURAS.HARMFUL[3] = nil, nil, nil
  C_UnitAuras.GetAuraDataByIndex = allowed
  fire("UNIT_AURA", "target")
end

-- Moving (the grid's snapping has tests of its own, under Moving frames)
VoltUIDB.snap = false
InCombatLockdown = function() return inCombat end
inCombat = true
SlashCmdList.VOLTUI("unlock")
check(not U.unlocked and chat[#chat]:find("combat"), "can't unlock in combat")
inCombat = false
SlashCmdList.VOLTUI("unlock")
check(U.unlocked and P.mover.shown and T.mover.shown and Bar.mover.shown and Bar.shown, "/volt unlock shows the drag overlays")
check(not unitWatch[T] and not unitWatch[ToT] and not unitWatch[Pet] and T.shown and T.unit == "player" and T.name.text == "Test Hero", "target frame stays up to place it, showing you")
check(a[1].shown == false, "no auras while placing")
P.mover.scripts.OnDragStart(P.mover)
P.mover.scripts.OnDragStop(P.mover)
check(VoltUIDB.playerPoint and VoltUIDB.playerLeft and VoltUIDB.playerTop, "dragging saves the spot")
check(sitsAt(P, 300, 600) and P.points[1][1] == "TOPLEFT" and P.points[1][3] == VoltUIDB.playerPoint, "against the nearest edge, and the frame stays where it was dropped")
Bar.mover.scripts.OnDragStop(Bar.mover)
check(VoltUIDB.castPoint and sitsAt(Bar, 300, 600), "castbar spot saved")
SlashCmdList.VOLTUI("lock")
check(not U.unlocked and P.mover.shown == false and Bar.mover.shown == false and Bar.shown == false, "/volt lock")
check(unitWatch[T] and unitWatch[ToT] and unitWatch[Pet] and T.unit == "target", "frames follow their units again")
local watchCalls = 0
local rw = RegisterUnitWatch
RegisterUnitWatch = function(f) watchCalls = watchCalls + 1; rw(f) end
inCombat = true
SlashCmdList.VOLTUI("lock")
check(watchCalls == 0, "/volt lock in combat when already locked touches nothing protected")
inCombat = false
SlashCmdList.VOLTUI("frames unlock")
check(U.unlocked, "/volt frames unlock too")
fire("PLAYER_REGEN_DISABLED")
check(not U.unlocked and P.mover.shown == false and Bar.mover.shown == false and watchCalls == 4, "entering combat locks them (target, its target, pet and focus go back to watching their units)")
RegisterUnitWatch = rw
U:Place(); CB:Place()
check(#P.points == 1 and sitsAt(P, 300, 600), "saved spot used")
check(#Bar.points == 1 and sitsAt(Bar, 300, 600), "saved castbar spot used")
VoltUIDB.snap = true
-- Spots saved before 1.12.1 were the top-left from the bottom-left corner, with no point.
VoltUIDB.playerLeft, VoltUIDB.playerTop, VoltUIDB.playerPoint = 1500, 1000, nil
U:Place()
check(VoltUIDB.playerPoint == "TOPRIGHT" and sitsAt(P, 1500, 1000), "an old spot is rewritten against the nearest edge, the frame where it was")
-- Straight after SetSize the game can still report a frame's old size and rect (bars
-- came out as if 2 pixels across in 1.12.1 and 1.12.2), so none of that is read.
do
  local gw, gh = P.GetWidth, P.GetHeight
  P.GetWidth, P.GetHeight = function() return 2 end, function() return 2 end
  VoltUIDB.playerLeft, VoltUIDB.playerTop, VoltUIDB.playerPoint = 900, 300, nil
  U:Place()
  P.GetWidth, P.GetHeight = gw, gh
  check(sitsAt(P, 900, 300) and VoltUIDB.playerPoint == "BOTTOM", "an old spot converts right even while the game reports a stale size")
  -- Spots written by 1.12.1 and 1.12.2 came from those stale numbers: dropped once.
  VoltUIDB.spotFormat = nil
  VoltUIDB.castLeft, VoltUIDB.castTop, VoltUIDB.castPoint = -234, 368, "BOTTOM"
  VoltUIDB.barCfg = VoltUIDB.barCfg or {}
  VoltUIDB.barCfg.zzz = { left = 5, top = 6, point = "BOTTOM" }
  VoltUIDB.playerLeft, VoltUIDB.playerTop, VoltUIDB.playerPoint = 1500, 1000, nil
  U:Place(); CB:Place()
  check(not (VoltUIDB.castLeft or VoltUIDB.castTop or VoltUIDB.castPoint) and Bar.points[1][1] == "CENTER", "a spot from 1.12.1 or 1.12.2 is dropped, the frame back in its default spot")
  check(not (VoltUIDB.barCfg.zzz.left or VoltUIDB.barCfg.zzz.point), "bars too")
  check(VoltUIDB.playerPoint == "TOPRIGHT" and sitsAt(P, 1500, 1000), "an old-style spot is kept and converted")
  check(VoltUIDB.spotFormat == 3, "only once")
  VoltUIDB.barCfg.zzz = nil
  VoltUIDB.castLeft, VoltUIDB.castTop, VoltUIDB.castPoint = 300, 600, nil
  CB:Place()
  VoltUIDB.playerLeft, VoltUIDB.playerTop, VoltUIDB.playerPoint = 1500, 1000, nil
  U:Place()
end
-- Windowed and back: the screen changes shape, the frame keeps to its corner.
UIParent:SetSize(1280, 720)
fire("DISPLAY_SIZE_CHANGED"); runTimers()
check(sitsAt(P, 1500 - 640, 1000 - 360), "in a smaller window it keeps its distance from the top-right corner")
inCombat = true
local placedBefore = P.points
UIParent:SetSize(1920, 1080)
fire("DISPLAY_SIZE_CHANGED"); runTimers()
check(P.points == placedBefore, "in combat the frames aren't touched")
inCombat = false
fire("PLAYER_REGEN_ENABLED")
check(sitsAt(P, 1500, 1000) and #P.points == 1, "and back to full screen it's where it was, placed again once out of combat")
check(sitsAt(Bar, 300, 600), "the castbar too")
VoltUIDB.playerLeft, VoltUIDB.playerTop, VoltUIDB.playerPoint = nil, nil, nil
U:Place()
SlashCmdList.VOLTUI("frames scale 1.2")
check(VoltUIDB.frameScale == 1.2 and T.scale == 1.2 and ToT.scale == 1.2, "scale")
inCombat = true
SlashCmdList.VOLTUI("frames scale 0.9")
check(VoltUIDB.frameScale == 1.2 and chat[#chat]:find("combat"), "no scaling in combat")
inCombat = false
SlashCmdList.VOLTUI("frames reset")
check(not VoltUIDB.playerLeft and VoltUIDB.frameScale == 1 and P.points[1][1] == "CENTER", "frames reset")
SlashCmdList.VOLTUI("castbar scale 1.5")
check(VoltUIDB.castScale == 1.5 and Bar.scale == 1.5, "castbar scale")
SlashCmdList.VOLTUI("castbar reset")
check(not VoltUIDB.castLeft and VoltUIDB.castScale == 1 and Bar.points[1][1] == "CENTER", "castbar reset")
SlashCmdList.VOLTUI("castbar target")
check(VoltUIDB.targetCast == false and TBar.off, "target cast bar switch")
SlashCmdList.VOLTUI("castbar target")
SlashCmdList.VOLTUI("alpha 0.6")
check(math.abs(P.fuiPanel.fill.ctex[4] - 0.6) < 1e-9 and math.abs(Bar.fuiPanel.fill.ctex[4] - 0.6) < 1e-9 and math.abs(TBar.fuiPanel.fill.ctex[4] - 0.6) < 1e-9, "opacity reaches the frames and bars")
SlashCmdList.VOLTUI("frames off")
check(VoltUIDB.frames == false and chat[#chat]:find("reload"), "/volt frames off")
SlashCmdList.VOLTUI("frames on")
SlashCmdList.VOLTUI("castbar off")
check(VoltUIDB.castbar == false, "/volt castbar off")
SlashCmdList.VOLTUI("castbar on")
SlashCmdList.VOLTUI("frames")
check(chat[#chat]:find("/volt edit"), "frames help")
SlashCmdList.VOLTUI("castbar")
check(chat[#chat]:find("/volt castbar test"), "castbar help")

print("== Edit mode")
UnitGUID = function(u) return unitInfo(u).guid or u end
UnitIsVisible = function() return true end
local portraitCalls = {}
SetPortraitTexture = function(t, u) portraitCalls[#portraitCalls + 1] = { t, u } end
inCombat = false

-- Names come in two parts on this client
local realName = UnitName
RegionalUniqueNamesEnabled = function() return true end
Constants = { CharacterNameSeparatorConsts = { CHARACTERNAME_SURNAME_SEPARATOR = " " } }
UnitName = function(u) if u == "player" then return "Test", "Hero" end; return realName(u) end
U:Update(P)
check(P.name.text == "Test Hero", "both parts of a player's name: " .. tostring(P.name.text))
UnitName = function(u) if u == "player" then return "Test", "" end; return realName(u) end
U:Update(P)
check(P.name.text == "Test", "no empty second part")
UnitName = function(u) if u == "player" then return "Test", "Hero" end; return realName(u) end
RegionalUniqueNamesEnabled = nil
U:Update(P)
check(P.name.text == "Test", "a second value only counts where the client uses two-part names")
RegionalUniqueNamesEnabled = function() return true end

-- Opening
VoltUIDB.snap = false -- these tests drop frames where they want them
SlashCmdList.VOLTUI("edit")
local Panel = VoltUISettings
local E = ns.EditMode
check(Panel and not Panel.shown and VoltUIMoveBar.shown and U.unlocked and P.mover.shown and ToT.mover.shown and Pet.mover.shown and Bar.mover.shown, "/volt edit shows the overlays and the toolbar, and leaves the settings window out of the way")
P.mover.scripts.OnMouseDown(P.mover) -- a click is a press and a release; earlier tests dragged this frame
P.mover.scripts.OnMouseUp(P.mover)
check(Panel.shown and E.tab == "player" and U.unlocked, "clicking a frame brings the window up on its page")
E:Open("general")
check(#E.tabs == 19 + (ns.Rares and 1 or 0) and #ns.Pages.list == 29 + (ns.Rares and 2 or 0) and E.tab == "general", "a sidebar entry for every page or set of tabs, opening where it was left: " .. #E.tabs)
check(VoltUISettings.w == E.WIDTH and E.WIDTH == 204 + 390 * 2 + 12 * 3 + 10, "room for the sidebar, two columns of cards and the scroll bar (wider since 1.87.0, for mono letters)")
check(VoltUIMoveBar and VoltUIMoveBar.shown, "and the move toolbar")
local escHas = {}
for _, n in ipairs(UISpecialFrames) do escHas[n] = true end
check(escHas.VoltUISettings and escHas.VoltUIMoveBar, "Esc closes them")
local function row(key)
  for _, r in ipairs(E.rows) do if r.shown ~= false and r.def and r.def.key == key then return r end end
  error("no row " .. key)
end
local function plus(key, n) for _ = 1, n or 1 do row(key):Step(1) end end
local function minus(key, n) for _ = 1, n or 1 do row(key):Step(-1) end end

-- Clicking a frame picks its tab
T.mover.scripts.OnMouseUp(T.mover)
check(E.tab == "target" and row("auras") and row("elite"), "clicking a frame opens its settings")
check(math.abs(T.mover.fill.ctex[4] - 0.45) < 1e-9 and math.abs(P.mover.fill.ctex[4] - 0.2) < 1e-9, "the chosen frame stands out")
Bar.mover.scripts.OnMouseUp(Bar.mover)
check(E.tab == "cast" and row("castWidth"), "castbar overlay opens its tab")
E:Select("player")
local hasAuras = false
for _, r in ipairs(E.rows) do if r.shown ~= false and r.def.key == "auras" then hasAuras = true end end
check(not hasAuras, "only the target has aura settings")

-- Sizes
local w0 = P.w
plus("width", 2)
check(P.w == w0 + 10 and U:Cfg("player").width == w0 + 10 and T.w == 230, "width changes this frame only")
check(row("width").value.text == tostring(w0 + 10), "the panel shows the new value")
minus("width", 2)
plus("hpHeight", 5)
check(P.hp.h == 25 and P.h == 18 + 25 + 1 + 12 + 1, "health bar height")
minus("hpHeight", 5)
for _ = 1, 60 do minus("hpHeight") end
check(P.hp.h == 4, "stops at the minimum")
U:Cfg("player").hpHeight = 20
U:Layout(P)
plus("pwHeight", 2)
check(P.pw.h == 14, "power bar height")
minus("pwHeight", 2)
minus("power")
check(P.pw.shown == false and P.h == 18 + 20 + 1, "power bar off, frame shrinks")
plus("power")
check(P.pw.shown and P.h == 18 + 20 + 1 + 12 + 1, "and back")

-- Fonts
plus("nameSize", 3)
check(P.name.font[2] == 16 and P.level.font[2] == 12 and P.h == 21 + 20 + 1 + 12 + 1, "name font size, header grows to fit (the level has its own size since 1.96.0)")
minus("nameSize", 3)
plus("barSize", 2)
check(P.hpText.font[2] == 14 and P.hpPct.font[2] == 12, "health numbers font size (the percent has its own since 1.96.0)")
minus("barSize", 2)
plus("pwSize")
check(P.pwText.font[2] == 11, "power font size")
minus("pwSize")

-- What shows
plus("name")
check(U:Cfg("player").name == "first" and P.name.text == "Test" and P.name.shown, "first name only")
plus("name")
check(U:Cfg("player").name == "off" and P.name.shown == false, "no name")
minus("level")
check(P.level.shown == false, "no level")
check(P.tag.points[1][2] == P.strip, "tags move over when the level goes")
minus("tags")
check(P.tag.shown == false and P.strip.shown == false and P.h == 1 + 20 + 1 + 12 + 1 and P.hp.points[1][5] == -1, "nothing in the header: the strip goes too")
plus("tags"); plus("level"); plus("name")
-- 1.93.0: the order of a frame's rows, and where each text sits
;(function()
  local c = U:Cfg("player")
  local keep = {}
  for k, v in pairs(c) do keep[k] = v end
  local function relay() U:Layout(P); U:Update(P) end
  local function top(region) return region.points[1][5] end
  check(c.nameAt == "name" and c.nameAlign == "left" and c.hpTextAt == "hp" and c.hpPctAlign == "left" and c.pwTextAt == "pw", "every text starts where it always was")
  check(table.concat(U:Order(c, true), " ") == "name hp pw pips", "and the rows in the old order")
  relay()
  local h0 = P.h
  check(P.name.points[1][1] == "LEFT" and P.name.points[1][2] == P.strip and P.name.points[1][4] == 5, "the name at the panel's left")
  check(P.level.points[1][1] == "RIGHT" and P.level.points[1][2] == P.strip and P.level.points[1][4] == -5, "the level at its right")
  check(P.hpText.points[1][2] == P.hp and P.hpText.points[1][4] == -5 and P.hpPct.points[1][4] == 5, "health numbers right and percent left on the bar")
  check(top(P.strip) == -1 and top(P.hp) < top(P.strip) and top(P.pw) < top(P.hp), "panel, health, power from the top")
  -- order
  U:SetRow(c, "pw", 2, true)
  relay()
  check(table.concat(U:Order(c, true), " ") == "name pw hp pips", "a row takes another's place by swapping with it")
  check(top(P.pw) > top(P.hp) and P.h == h0, "power above health, the frame no taller")
  U:SetRow(c, "name", 3, true)
  relay()
  check(table.concat(U:Order(c, true), " ") == "hp pw name pips" and top(P.hp) == -1 and top(P.strip) < top(P.pw) and P.h == h0, "the name panel can go under the bars")
  U:SetRow(c, "name", 1, true); U:SetRow(c, "hp", 2, true)
  relay()
  check(table.concat(U:Order(c, true), " ") == "name hp pw pips", "and back")
  c.rowName, c.rowHp, c.rowPw, c.rowPips = 2, 2, 2, 2
  check(table.concat(U:Order(c, true), " ") == "name hp pw pips", "numbers that tie fall back to the usual order")
  U:SetRow(c, "pips", 1, true)
  check(U:Order(c, true)[1] == "pips" and c.rowPips ~= c.rowName, "and a move sorts the tie out")
  c.rowName, c.rowHp, c.rowPw, c.rowPips = 1, 2, 3, 4
  -- side
  c.nameAlign = "right"; c.levelAlign = "left"
  relay()
  check(P.level.points[1][1] == "LEFT" and P.level.points[1][2] == P.strip, "the level on the left")
  local right
  for _, pt in ipairs(P.name.points) do if pt[1] == "RIGHT" then right = pt end end
  check(right and right[2] ~= P.strip and P.name.justifyH == nil or right, "the name on the right, inside the tags")
  c.nameAlign = "center"
  relay()
  check(P.name.points[1][2] == P.strip and P.name.points[2][2] == P.strip, "or across the middle")
  c.nameAlign, c.levelAlign = "left", "right"
  -- onto a bar, and nudged
  c.levelAt, c.levelAlign, c.levelX, c.levelY = "hp", "center", 7, -3
  relay()
  check(P.level.parent == P.hpTop and P.level.points[1][1] == "CENTER" and P.level.points[1][2] == P.hp, "the level in the middle of the health bar")
  check(P.level.points[1][4] == 7 and P.level.points[1][5] == -3, "nudged from there")
  check(P.level.font[3] == "OUTLINE", "outlined, as text on a bar is")
  c.hpTextX, c.hpTextY = -10, 4
  relay()
  check(P.hpText.points[1][4] == -15 and P.hpText.points[1][5] == 4, "the health numbers nudge too")
  c.hpTextAt, c.hpTextAlign = "pw", "left"
  relay()
  check(P.hpText.parent == P.pw and P.hpText.points[1][2] == P.pw and P.hpText.points[1][1] == "LEFT", "health numbers can sit on the power bar")
  c.hpPctAt, c.hpPctAlign = "name", "right"
  relay()
  check(P.hpPct.parent == P.over and P.hpPct.points[1][1] == "RIGHT" and P.hpPct.points[1][2] == P.raid and P.hpPct.font[3] ~= "OUTLINE", "and the percent on the name panel, plain, inside the tags")
  -- nothing on the panel
  c.nameAt, c.tagAt, c.hpPctAt = "hp", "hp", "hp"
  relay()
  check(P.strip.shown == false and P.h < h0 and top(P.hp) == -1, "a name panel with nothing on it isn't drawn")
  check(P.name.parent == P.hpTop and P.tag.parent == P.hpTop and P.raid.parent == P.hpTop, "the name, tags and raid marker on the bar")
  local pv, ph = U:Preview("player", UIParent)
  check(ph == P.h * c.scale and pv.strip.shown == false, "the settings window's copy follows")
  for k in pairs(c) do c[k] = nil end
  for k, v in pairs(keep) do c[k] = v end
  relay()
  check(P.h == h0 and P.name.parent == P.over and P.strip.shown, "and everything goes back")
  -- the settings rows
  E:Select("player")
  local function urow(key)
    for _, r in ipairs(E.pages.player.rows) do
      if r.def.key == key then return r end
    end
  end
  check(urow("rowName") and urow("rowHp") and urow("rowPw") and urow("rowPips"), "a row for each part's place, combo points too on the player's page")
  check(urow("nameAt") and urow("nameAlign") and urow("hpTextX") and urow("pwTextY") and urow("tagAt"), "and four for each text")
  urow("rowPw"):Set(1)
  check(table.concat(U:Order(c, true), " ") == "pw hp name pips" and top(P.pw) == -1, "picking a place swaps the rows")
  urow("rowPw"):Set(3)
  check(table.concat(U:Order(c, true), " ") == "name hp pw pips", "and swaps them back")
  urow("nameAlign"):Set("right")
  check(c.nameAlign == "right", "the side row works")
  urow("nameAlign"):Set("left")
  E:Select("target")
  local hasPips
  for _, r in ipairs(E.pages.target.rows) do if r.def.key == "rowPips" then hasPips = true end end
  check(not hasPips, "no combo points row for the target")
  E:Select("player")
end)()
-- 1.94.0: the border's look, and the border as a signal
;(function()
  local c, tc = U:Cfg("player"), U:Cfg("target")
  local keep = { hp = UNITS.player.hp, combat = UNITS.player.combat }
  local function relay(f) U:Layout(f); U:Update(f) end
  local function rgb(t, r, g, b)
    local p = tint(t)
    return p and math.abs(p[1] - r) < 0.01 and math.abs(p[2] - g) < 0.01 and math.abs(p[3] - b) < 0.01
  end
  local bd, panel = P.bd, P.fuiPanel
  check(c.border == "hairline" and tc.border == "hairline", "every frame starts with the hairline")
  check(c.sigCombat == nil and c.sigDebuff == nil and c.sigLow == nil and U.UpdateSignal == nil, "the border signals nothing (1.97.1)")
  check(bd and panel.edges[1].shown ~= false and bd.gap[1].shown == false and bd.plate.shown == false and bd.rail.shown == false and bd.tab.shown == false,
    "the hairline is the panel's own line, nothing more")
  local barY = U.targetBar.points[1][5]
  check(barY == 3, "the target's cast bar 3 above its frame")
  -- double line
  c.border = "double"; relay(P)
  check(bd.gap[1].shown and bd.outer[1].shown and rgb(bd.outer[1], 0, 0, 0) and panel.edges[1].shown ~= false, "double: a gap and a black line outside the grey one")
  -- none
  c.border = "none"; relay(P)
  check(panel.edges[1].shown == false and bd.gap[1].shown == false and panel.fill.shown ~= false, "none: no line, the fill stays")
  -- glass plate
  c.border = "plate"; relay(P)
  check(bd.plate.shown and panel.fill.shown == false and panel.edges[1].shown == false and bd.plateEdges[1].shown, "plate: a see-through plate, no fill or line of the frame's own")
  check(bd.plate.points[1][4] == -6 and bd.plate.points[2][4] == 6, "6 past the frame on each side")
  check(tint(bd.plate)[4] == 0.55, "glass")
  -- rail and tab
  c.border = "rail"; relay(P)
  check(bd.rail.shown and rgb(bd.rail, 1, 198 / 255, 26 / 255) and bd.plate.shown == false and panel.fill.shown ~= false, "rail: a gold rail, the fill back")
  check(bd.tab.shown and P.level.parent == bd.tab and P.level.shown and P.level.points[1][2] == bd.tab, "the level in the tab")
  check(bd.tabEdges[2].shown == false and bd.tabEdges[1].shown, "the tab open at the bottom")
  local h1 = P.h
  c.nameAt, c.tagAt = "hp", "hp"; relay(P)
  check(P.strip.shown == false and P.h < h1, "the level in the tab does not hold the name panel open")
  c.nameAt, c.tagAt = "name", "name"
  c.level = false; relay(P)
  check(bd.tab.shown == false and bd.rail.shown, "no level, no tab")
  c.level = true
  -- what sits above keeps clear
  tc.border = "plate"; U:Layout(T)
  check(U.targetBar.points[1][5] == 3 + 6, "the target's cast bar moves up off the plate")
  tc.border = "rail"; U:Layout(T)
  check(U.targetBar.points[1][5] == 3 + math.max(tc.nameSize - 1, 8) + 4, "and above the tab")
  tc.border = "hairline"; U:Layout(T)
  check(U.targetBar.points[1][5] == 3, "and back")
  -- (1.97.1) the border no longer signals: a fight, a debuff or low health leave it as it is
  c.border = "rail"; relay(P)
  VoltUIDB.frameCfg.player.sigCombat = true -- left over from a version that had them
  UNITS.player.combat = true
  UNITS.player.hp = 15
  AURAS["HARMFUL|RAID"] = { { icon = "d9", dispelName = "Magic", auraInstanceID = 91 } }
  fire("UNIT_FLAGS", "player")
  fire("UNIT_AURA", "player")
  fire("UNIT_HEALTH", "player")
  relay(P)
  check(P.sig == nil and rgb(bd.rail, 1, 198 / 255, 26 / 255), "in a fight, low and debuffed: no ring, the rail still gold")
  check(U:Cfg("player").sigCombat == nil, "and the old setting is dropped")
  AURAS["HARMFUL|RAID"] = nil
  UNITS.player.hp, UNITS.player.combat = keep.hp, keep.combat
  fire("UNIT_FLAGS", "player")
  fire("UNIT_HEALTH", "player")
  c.border = "hairline"; relay(P)
  check(bd.rail.shown == false and P.level.parent ~= bd.tab, "and everything goes back")
  -- the settings rows
  E:Select("player")
  local function urow(key)
    for _, r in ipairs(E.pages.player.rows) do
      if r.def.key == key then return r end
    end
  end
  check(urow("border") and not urow("sigCombat") and not urow("sigDebuff") and not urow("sigLow"), "a Border card on the frame's page, with the look only")
  urow("border"):Set("double")
  check(c.border == "double" and bd.gap[1].shown, "picking a look draws it")
  urow("border"):Set("hairline")
  check(bd.gap[1].shown == false, "and back")
end)()
check(U:Cfg("player").name == "full" and P.name.text == "Test Hero" and P.strip.shown and P.h == 18 + 20 + 1 + 12 + 1, "and back")
minus("hpText")
check(P.hpText.shown == false, "no health numbers")
UNITS.player.dead = true
fire("UNIT_HEALTH", "player")
check(P.hpText.shown and P.hpText.text == "Dead", "Dead still shows with numbers off")
UNITS.player.dead = nil
fire("UNIT_HEALTH", "player")
check(P.hpText.shown == false, "and goes again")
plus("hpText")
minus("hpPct")
check(P.hpPct.shown == false, "no health percent")
plus("hpPct")
minus("pwText")
check(P.pwText.shown == false, "no power numbers")
plus("pwText")

-- Class colours per frame
minus("classColor")
check(P.hp:GetStatusBarTexture().vc[2] == 0.7 and U:Cfg("target").classColor, "class colours off for this frame only")
plus("classColor")
check(P.hp:GetStatusBarTexture().vc[2] == 0.44, "and on")

-- Portraits
portraitCalls = {}
plus("portrait")
check(U:Cfg("player").portrait == "2d" and P.portrait2d.shown, "flat portrait")
check(portraitCalls[1] and portraitCalls[1][1] == P.portrait2d and portraitCalls[1][2] == "player", "painted from the unit")
local size = P.h - 2
check(P.portrait2d.w == size and P.portrait2d.h == size, "square, the frame's height")
check(P.hp.points[1][4] == size + 2 and P.hp.points[2][4] == -1, "bars move over")
plus("portraitSide")
check(P.hp.points[1][4] == 1 and P.hp.points[2][4] == -(size + 2) and P.portrait2d.points[1][1] == "TOPRIGHT", "other side")
minus("portraitSide")
plus("portrait")
check(U:Cfg("player").portrait == "3d" and P.portrait3d and P.portrait3d.shown and P.portrait2d.shown == false, "3D portrait")
check(P.portrait3d.modelUnit == "player" and P.portrait3d.points[1][1] == "TOPLEFT", "model of the unit")
P.portrait3d.modelUnit = nil
U:Update(P, true)
check(P.portrait3d.modelUnit == nil, "the model isn't reloaded when nothing changed")
U:Update(P)
check(P.portrait3d.modelUnit == "player", "a real update does reload it")
P.portrait3d.modelUnit = nil
fire("UNIT_MODEL_CHANGED", "player")
check(P.portrait3d.modelUnit == "player", "new model when the game says so")
plus("portrait")
check(U:Cfg("player").portrait == "off" and P.portrait3d.shown == false and P.hp.points[1][4] == 1, "portrait off, bars back")

-- Target of target: its own settings, including a light update every so often
E:Select("tot")
plus("portrait")
check(ToT.portrait2d.shown and U:Cfg("player").portrait == "off", "each frame has its own portrait setting")
portraitCalls = {}
ToT.scripts.OnUpdate(ToT, 1)
check(#portraitCalls == 0, "target of target doesn't repaint an unchanged portrait")
minus("portrait")
plus("level")
check(ToT.level.shown and ToT.level.text ~= nil, "small frames can show their level too")
minus("level")
plus("hpPct")
check(ToT.hpPct.shown and ToT.hpPct.text:find("%%"), "and numbers")
minus("hpPct")

-- Elite and rare
E:Select("target")
local edge, glow = T.eliteGlow.edges[1], T.eliteGlow.glow[1]
check(edge.shown == false and glow.shown == false, "nothing while previewing as normal")
plus("previewClass")
check(row("previewClass").current == "Elite" and edge.shown and edge.ctex[1] == 1 and edge.ctex[2] == 0.82 and glow.shown and T.tag.text:find("Elite"), "preview: gold border, glow and tag")
plus("previewClass")
check(row("previewClass").current == "Rare" and edge.ctex[3] == 1 and T.tag.text:find("Rare"), "preview: rare")
plus("previewClass", 2)
check(row("previewClass").current == "Boss" and edge.ctex[1] == 1 and edge.ctex[2] == 0.33, "preview: boss")
minus("elite")
check(U:Cfg("target").elite == "border" and edge.shown and glow.shown == false, "border only")
minus("elite")
check(U:Cfg("target").elite == "off" and edge.shown == false and T.tag.text:find("Boss"), "style off, the tag has its own switch")
plus("elite", 2)
check(U:Cfg("target").elite == "glow", "back to border and glow")
check(T.over.flevel > T.flevel, "drawn above the bars")

-- Auras and the target's cast bar
plus("auraSize", 3)
check(U:Cfg("target").auraSize == 25, "aura size")
check(TBar.shown and TBar.preview, "the target's cast bar shows to set it up")
plus("targetCastH", 2)
check(TBar.h == 20 and VoltUIDB.targetCastH == 20, "target cast bar height")
minus("targetCastH", 2)
minus("targetCast")
check(VoltUIDB.targetCast == false and TBar.shown == false and TBar.off, "target cast bar off, straight away")
castInfo.target = { name = "Shadow Bolt", icon = "s", st = 102000, en = 104000, guid = "t5" }
fire("UNIT_SPELLCAST_START", "target", "t5")
check(TBar.shown == false, "and it stays off")
castInfo.target = nil
plus("targetCast")
check(VoltUIDB.targetCast and TBar.shown, "and on again")

-- Castbar tab
E:Select("cast")
plus("castWidth", 2)
check(Bar.w == 270 and VoltUIDB.castWidth == 270, "castbar width")
minus("castWidth", 2)
plus("castHeight", 4)
check(Bar.h == 26 and Bar.icon.w == 24, "castbar height, icon keeps up")
minus("castHeight", 4)
plus("castSize", 2)
check(Bar.label.font[2] == 14 and Bar.time.font[2] == 14, "castbar font size")
minus("castSize", 2)
minus("castIcon")
check(Bar.icon.shown == false and Bar.bar.points[1][2] == Bar, "no icon: the bar takes its place")
check(TBar.icon.shown == false, "both bars follow")
plus("castIcon")
check(Bar.icon.shown and Bar.bar.points[1][2] == Bar.icon, "icon back")
minus("castTime")
check(Bar.time.shown == false and Bar.label.points[2][2] == Bar.bar, "no time: the name gets the room")
plus("castTime")
minus("castSpark")
check(Bar.spark.shown == false, "no spark")
plus("castSpark")
plus("castScale", 2)
check(math.abs(Bar.scale - 1.1) < 1e-9, "castbar scale")
Bar.mover.scripts.OnDragStop(Bar.mover)
E.reset.scripts.OnClick()
check(math.abs(VoltUIDB.castScale - 1.1) < 1e-9 and E.reset.text.text == "Click to confirm", "reset asks first")
E.reset.scripts.OnClick()
check(VoltUIDB.castWidth == 260 and VoltUIDB.castScale == 1 and not VoltUIDB.castLeft and Bar.points[1][1] == "CENTER", "reset the castbar")
check(E.reset.text.text == "Reset" and E.banner.shown and E.banner.text.text:find("defaults"), "and says so")

-- Everything-wide settings, on the General page
E:Select("general")
plus("font")
check(VoltUIDB.font ~= "barlow" and P.name.font[1]:find("Barlow"), "font from the panel")
minus("font")
check(VoltUIDB.font == "barlow", "and back")
minus("alpha")
check(math.abs(VoltUIDB.alpha - 0.55) < 1e-9 and math.abs(P.fuiPanel.fill.ctex[4] - 0.55) < 1e-9, "opacity from the panel")
plus("alpha")

-- Reset a frame
E:Select("target")
plus("width", 3)
minus("level")
T.mover.scripts.OnDragStop(T.mover)
check(VoltUIDB.targetLeft == 300, "target spot saved")
minus("targetCast")
E.reset.scripts.OnClick()
E.reset.scripts.OnClick()
check(U:Cfg("target").width == 230 and U:Cfg("target").level and T.w == 230 and T.level.shown, "reset this frame")
check(not VoltUIDB.targetLeft and T.points[1][1] == "CENTER", "spot too")
check(VoltUIDB.targetCast and not TBar.off, "and its cast bar")

-- Target-of-target and pet can move too
ToT.mover.scripts.OnDragStop(ToT.mover)
check(VoltUIDB.totLeft == 300, "target of target spot saved")
U:Place()
check(ToT.points[1][3] == VoltUIDB.totPoint and sitsAt(ToT, 300, 600), "and used")
E:Select("tot")
E.reset.scripts.OnClick()
E.reset.scripts.OnClick()
check(ToT.points[1][2] == T and Pet.points[1][2] == P, "by default they sit beside their frames")

-- The panel doesn't change anything in combat
E:Select("player")
local widthNow = U:Cfg("player").width
inCombat = true
plus("width")
E.reset.scripts.OnClick()
E.reset.scripts.OnClick()
check(U:Cfg("player").width == widthNow, "nothing changes in combat")
check(row("width").alpha == 0.45, "and its rows dim")
check(E.banner.shown and E.banner.text.text:find("combat"), "a reset says it can't")
E.toast = nil
E:RefreshPage()
check(E.banner.shown and E.banner.kind == "combat", "with a line saying why")
inCombat = false
E:RefreshPage()
check(row("width").alpha == 1 and E.banner.kind ~= "combat", "back after the fight")

-- Closing
T.mover.scripts.OnMouseUp(T.mover)
plus("previewClass")
E.done.scripts.OnClick()
check(not Panel.shown and not U.unlocked and P.mover.shown == false and Bar.mover.shown == false, "Done closes it")
check(T.unit == "target" and unitWatch[T] and U.previewClass == nil, "frames back to real units, preview gone")
check(TBar.shown == false and not TBar.preview, "target cast bar back to casts only")
U:Update(T)
check(T.eliteGlow.edges[1].ctex and T.tag.text:find("Elite"), "the real target's elite tag again")
check(T.eliteGlow.edges[1].shown and T.eliteGlow.edges[1].ctex[2] == 0.82, "a real elite gets the gold border")
UNITS.target.classif = "normal"
fire("UNIT_CLASSIFICATION_CHANGED", "target")
check(T.eliteGlow.edges[1].shown == false, "a normal mob doesn't")
UNITS.target.classif = "elite"
SlashCmdList.VOLTUI("edit")
check(U.unlocked and not Panel.shown, "/volt edit starts again")
SlashCmdList.VOLTUI("edit")
check(not Panel.shown and not U.unlocked, "and closes")
SlashCmdList.VOLTUI("unlock")
check(U.unlocked and not Panel.shown, "/volt unlock is the same thing")
VoltUIMoveBar:Hide() -- Esc
check(not U.unlocked and P.mover.shown == false, "Esc leaves the edit mode")
SlashCmdList.VOLTUI("edit")
fire("PLAYER_REGEN_DISABLED")
check(not U.unlocked and not VoltUIMoveBar.shown and P.mover.shown == false, "combat stops moving frames")
E:Open("general")
SlashCmdList.VOLTUI("edit")
check(not Panel.shown and U.unlocked, "a window that was open steps aside while frames are moved")
SlashCmdList.VOLTUI("edit")
check(Panel.shown and not U.unlocked, "and comes back when that ends")
E:Close()
inCombat = true
SlashCmdList.VOLTUI("edit")
check(not Panel.shown and not U.unlocked and chat[#chat]:find("combat"), "frames can't start moving in combat")
SlashCmdList.VOLTUI("")
check(Panel.shown, "but the settings open")
E:Close()
inCombat = false

-- Panel position
SlashCmdList.VOLTUI("edit")
SlashCmdList.VOLTUI("edit")
VoltUIDB.editLeft, VoltUIDB.editTop = 111, 222
SlashCmdList.VOLTUI("edit")
E:Close()
E:Open()
check(sitsAt(Panel, 111, 222) and VoltUIDB.editPoint, "the panel remembers its spot")
SlashCmdList.VOLTUI("edit")

-- Settings from before the edit mode carry over
VoltUIDB.frameCfg = nil
VoltUIDB.classColor, VoltUIDB.frameScale = false, 1.3
check(U:Cfg("player").classColor == false and U:Cfg("target").scale == 1.3, "older settings carry over")
VoltUIDB.classColor, VoltUIDB.frameScale = true, 1
VoltUIDB.frameCfg = nil
U:Update(P)
check(U:Cfg("player").width == 230 and U:Cfg("player").portrait == "off", "new settings get defaults")
-- A frame whose saved settings are missing a newer option still works
VoltUIDB.frameCfg = { player = { width = 300 } }
check(U:Cfg("player").width == 300 and U:Cfg("player").nameSize == 13, "missing options filled in, saved ones kept")
VoltUIDB.frameCfg = nil
U:LayoutAll()
UnitName = realName

;(function() -- a function of its own: Lua allows 200 locals per function
print("== Settings controls")
SlashCmdList.VOLTUI("edit")
local E2 = ns.EditMode
E2:Select("player")
local function rowOf(key)
  for _, r in ipairs(E2.rows) do if r.def.key == key then return r end end
  error("no row " .. key)
end
-- slider
local wr = rowOf("width")
check(wr.slider.minv == 80 and wr.slider.maxv == 500 and wr.slider.value == 230, "slider shows the setting and its range")
wr.slider.scripts.OnValueChanged(wr.slider, 262)
check(U:Cfg("player").width == 260 and P.w == 260 and wr.value.text == "260", "dragging a slider snaps to its step and applies")
wr.slider.scripts.OnMouseWheel(wr.slider, 1)
check(U:Cfg("player").width == 265, "wheel up steps it")
wr.slider.scripts.OnMouseWheel(wr.slider, -1)
wr.slider.scripts.OnValueChanged(wr.slider, 9999)
check(U:Cfg("player").width == 500, "limited to its range")
wr.slider.scripts.OnValueChanged(wr.slider, 230)
wr.filling = true
wr.slider.scripts.OnValueChanged(wr.slider, 300)
wr.filling = false
check(U:Cfg("player").width == 230, "the panel filling itself in doesn't count as a change")
local sr = rowOf("scale")
sr.slider.scripts.OnValueChanged(sr.slider, 1.2)
check(math.abs(P.scale - 1.2) < 1e-9 and sr.value.text == "1.20", "scale shows two decimals")
sr.slider.scripts.OnValueChanged(sr.slider, 1)
-- switch
local lr = rowOf("level")
check(tint(lr.switch.track)[1] == ns.Style.UI.accent[1] and lr.switch.knob.points[1][1] == "RIGHT", "a switch that's on: violet, knob right")
lr.switch.scripts.OnClick(lr.switch)
check(U:Cfg("player").level == false and P.level.shown == false, "clicking the switch")
check(tint(lr.switch.track)[1] == ns.Style.UI.control[1] and lr.switch.knob.points[1][1] == "LEFT", "off: grey, knob left")
lr.switch.scripts.OnClick(lr.switch)
-- segments
local nr = rowOf("name")
check(#nr.segments == 3 and nr.segments[1].text.text == "Full", "choices side by side")
check(tint(nr.segments[1].bg)[1] == ns.Style.UI.control[1] and tint(nr.segments[1].bg)[4] == 1 and tint(nr.segments[2].bg)[4] == 0, "the chosen one is lit")
nr.segments[2].scripts.OnClick(nr.segments[2])
check(U:Cfg("player").name == "first" and nr.current == "First" and tint(nr.segments[2].bg)[4] == 1, "clicking a choice")
nr.segments[1].scripts.OnClick(nr.segments[1])
-- stepper for long lists
E2:Select("general")
local fr = rowOf("font")
check(rawget(fr, "segments") == nil and fr.value.text == "Barlow", "long lists step instead")
fr.plus.scripts.OnClick(fr.plus)
check(VoltUIDB.font ~= "barlow" and fr.value.text ~= "Barlow", "next font")
fr.minus.scripts.OnClick(fr.minus)
check(VoltUIDB.font == "barlow", "previous font")
E2:Select("player")
-- rows that have no effect dim
local pr, phr = rowOf("power"), rowOf("pwHeight")
check(phr.alpha == 1, "a live row is bright")
pr.switch.scripts.OnClick(pr.switch)
check(phr.alpha == 0.45, "power bar off: its settings dim")
pr.switch.scripts.OnClick(pr.switch)
check(phr.alpha == 1, "and wake up")
check(rowOf("portraitSide").alpha == 0.45, "portrait side dims while the portrait is off")
-- layout
local pg = E2.pages.player
local cols = {}
for _, r in ipairs(pg.rows) do cols[r.parent] = true end
local nCards, xs = 0, {}
for card in pairs(cols) do nCards = nCards + 1; xs[card.points[1][4]] = true end
local nCols = 0
for _ in pairs(xs) do nCols = nCols + 1 end
check(nCards >= 5 and nCols == 2, "rows grouped into cards, in two columns")
for card in pairs(cols) do check(card.title.color[1] == ns.Style.UI.text[1] and card.band, "card titles on a band of their own") end
check(Panel.h == E2:WindowHeight() and Panel.h <= 660 and E2.scroll.contentH == pg.height, "the window keeps its size; the page scrolls in it")
E2:Select("tot") -- the player's page is the tallest since 1.95.0 (class extras, two extra texts)
local shortToT = E2.scroll.contentH
E2:Select("player")
check(shortToT < E2.scroll.contentH, "a taller page scrolls further")
local function side(key) -- a page's tab across the top of the page
  for _, b in ipairs(E2.tabButtons) do if b.key == key and b.shown then return b end end
end
check(side("player").bar.shown and not side("target").bar.shown, "the current page is marked among the tabs")
side("target").scripts.OnClick(side("target"))
check(E2.tab == "target" and side("target").bar.shown and not side("player").bar.shown, "clicking a tab")
check(tint(E2.done.bg)[1] == ns.Style.UI.primary[1] and tint(E2.done.bg)[4] == 1 and E2.done.primaryEdges and tint(E2.done.primaryEdges[1])[1] == ns.Style.UI.primaryLine[1], "Done is the main button: a dark gold tint with a gold border (1.87.0)")
check(E2.done.text.color and E2.done.text.color[1] == ns.Style.UI.primaryText[1], "with light text, easy to read")
E2.done.scripts.OnEnter(E2.done)
check(tint(E2.done.primaryEdges[1])[1] == ns.Style.UI.primaryEdge[1] and tint(E2.done.bg)[1] == ns.Style.UI.primaryHover[1], "its border and tint lighten under the mouse")
E2.done.scripts.OnLeave(E2.done)
check(tint(E2.done.primaryEdges[1])[1] == ns.Style.UI.primaryLine[1] and tint(E2.done.bg)[1] == ns.Style.UI.primary[1], "and back after")
-- blocked in combat
E2:Select("player")
inCombat = true
wr.slider.scripts.OnValueChanged(wr.slider, 400)
check(U:Cfg("player").width == 230 and wr.slider.value == 230, "a slider snaps back in combat")
inCombat = false
SlashCmdList.VOLTUI("edit")

-- Bag settings use the same controls
local bagRow = hubRows("bags")
check(bagRow.bagCols.slider and bagRow.categories.switch and #bagRow.outline.segments == 3 and hubRows("general").font.value, "bag settings: same controls")
bagRow.bagCols.slider.scripts.OnValueChanged(bagRow.bagCols.slider, 12)
check(VoltUIDB.bagCols == 12 and bagRow.bagCols.value.text == "12", "bag slider applies")
local bagWin = ns.Bags.windows.bags.frame
ns.Bags:Open()
bagRow.bagCols.slider.scripts.OnValueChanged(bagRow.bagCols.slider, 11)
check(bagWin.w == 11 * VoltUIDB.bagSize + 10 * VoltUIDB.gapX + 16, "and the bag window redraws: " .. tostring(bagWin.w))
bagRow.bagCols.slider.scripts.OnValueChanged(bagRow.bagCols.slider, 10)
local catBefore = VoltUIDB.categories
bagRow.categories.switch.scripts.OnClick(bagRow.categories.switch)
check(VoltUIDB.categories ~= catBefore, "bag switch applies")
bagRow.categories.switch.scripts.OnClick(bagRow.categories.switch)
;(function()
  local E = ns.EditMode
  local was, open = E.tab, E:IsOpen()
  E:Open("general")
  SlashCmdList.VOLTUI("alpha 0.85")
  local alphaRow
  for _, r in ipairs(E.rows) do if r.def.key == "alpha" then alphaRow = r end end
  check(alphaRow and alphaRow.value.text == "0.85", "the settings window follows a change made elsewhere")
  if was then E:Select(was) end
  if not open then E:Close() end
end)()

print("== Minimap icon")
local Ic = ns.MinimapIcon
local Btn = VoltUIMinimapButton
check(Btn and Btn.parent == Minimap and tostring(Btn.glyph.tex):find("Bolt$") and Btn.glyph.vc and Btn.glyph.vc[1] == ns.Style.UI.primaryText[1]
  and tint(Btn.fuiPanel.fill)[1] == ns.Style.UI.accent[1] and tint(Btn.fuiPanel.fill)[3] == ns.Style.UI.accent[3] and Btn.fuiPanel.fill.shape == nil,
  "the icon, on the map: a solid gold square with the dark bolt (1.81.0, bolt 1.105.0)")
check(VoltUIDB.icon and VoltUIDB.iconAngle == 315, "defaults")
-- position: inside the corners of the square map
VoltUIDB.map = true
Minimap:SetSize(140, 140)
Ic:Place()
local pt = Btn.points[1]
check(pt[2] == Minimap and pt[1] == "CENTER" and math.abs(pt[4] - 55) < 1e-9 and math.abs(pt[5] + 55) < 1e-9, "bottom right corner, inside the map")
VoltUIDB.iconAngle = 0
Ic:Place()
check(math.abs(Btn.points[1][4] - 55) < 1e-9 and math.abs(Btn.points[1][5]) < 1e-9, "follows the edge")
VoltUIDB.map = false
VoltUIDB.iconAngle = 180
Ic:Place()
check(math.abs(Btn.points[1][4] + 70) < 1e-9, "on the edge of a round map")
VoltUIDB.map = true
-- dragging
function Minimap:GetCenter() return 500, 300 end
function GetCursorPosition() return 500, 500 end
Btn.scripts.OnDragStart(Btn)
Btn.scripts.OnUpdate(Btn, 0.01)
check(math.abs(VoltUIDB.iconAngle - 90) < 1e-6, "dragging moves it around")
Btn.scripts.OnDragStop(Btn)
check(Btn.scripts.OnUpdate == nil, "and stops")
VoltUIDB.iconAngle = 315
Ic:Place()
-- tooltip
Btn.scripts.OnEnter(Btn)
Btn.scripts.OnLeave(Btn)

-- the menu
check(VoltUIMenu == nil or not VoltUIMenu.shown, "menu shut to start")
Btn.scripts.OnClick(Btn, "LeftButton")
local Menu = VoltUIMenu
check(Menu and Menu.shown, "clicking the icon opens the menu")
check(UISpecialFrames[#UISpecialFrames] == "VoltUIMenu", "Esc closes it")
local function menuRow(text)
  for _, r in ipairs(Ic.rows) do
    if r.shown ~= false and r.item and r.item.text == text then return r end
  end
end
local names = {}
for _, r in ipairs(Ic.rows) do if r.shown ~= false and r.item then names[#names + 1] = r.item.text end end
check(names[1] == "Customise" and names[2] == "Settings" and names[3] == "Move frames", "Settings and Move frames come first: " .. table.concat(names, ", "))
for _, want in ipairs({ "Settings", "Move frames", "Quick keybinds" }) do
  check(menuRow(want), "menu has " .. want)
end
Extra("menu", { menuRow = menuRow })
for _, gone in ipairs({ "Bag settings", "Sample cast", "Sample loot window", "Unit frames", "Bags", "Parts of VoltUI", "Try it out", "Hide this icon" }) do
  check(not menuRow(gone), "the menu no longer has " .. gone)
end
check(#names <= 10, "the menu is short: " .. #names .. " rows")
check(not menuRow("Minimap icon"), "its own switch isn't in the list")
check(not menuRow("Reload to apply"), "no reload offered when nothing changed")
check(menuRow("Customise").item.kind == "section" and menuRow("Customise").text.color[1] == ns.Style.UI.hint[1], "section titles in the quiet hint grey")
Btn.scripts.OnClick(Btn, "LeftButton")
check(not Menu.shown, "clicking again closes it")
ns.EditMode:Close()
Btn.scripts.OnClick(Btn, "LeftButton")
Btn.scripts.OnClick(Btn, "RightButton")
check(not Menu.shown and VoltUISettings.shown, "right-click shuts the menu and opens the settings")
Btn.scripts.OnClick(Btn, "RightButton")
check(not VoltUISettings.shown, "and again closes them")

-- moving frames and the settings from the menu
Btn.scripts.OnClick(Btn)
local em = menuRow("Move frames")
em.scripts.OnClick(em)
check(U.unlocked and not VoltUISettings.shown and not Menu.shown, "the menu starts moving frames, and it and the settings get out of the way")
Btn.scripts.OnClick(Btn)
check(menuRow("Move frames").note.text == "on", "shows it's on")
em = menuRow("Move frames")
em.scripts.OnClick(em)
check(not U.unlocked, "and stops it")
ns.EditMode:Close()
Btn.scripts.OnClick(Btn)
local setRow = menuRow("Settings")
setRow.scripts.OnClick(setRow)
check(VoltUISettings.shown and not U.unlocked, "Settings opens just the settings window")
ns.EditMode:Close()
inCombat = true
Btn.scripts.OnClick(Btn)
em = menuRow("Move frames")
check(em.note.text == "not in combat", "in combat it says why not")
em.scripts.OnClick(em)
check(not U.unlocked and Menu.shown, "and does nothing")
inCombat = false
Btn.scripts.OnClick(Btn)

Extra("menu lists") -- another add-on's tests, since VoltUI 1.104.0

-- a part switched in the settings and not applied yet: the menu offers the reload
local reloads = 0
ReloadUI = function() reloads = reloads + 1 end
VoltUIDB.bags = false
Btn.scripts.OnClick(Btn)
local re = menuRow("Reload to apply")
check(re and tint(re.bg)[1] == ns.Style.UI.primary[1] and re.primaryEdges.on, "a part waiting on a reload: the menu offers it")
re.scripts.OnClick(re)
check(reloads == 1, "reloads")
VoltUIDB.bags = true
Btn.scripts.OnClick(Btn)
check(not menuRow("Reload to apply"), "and not when nothing is waiting")
Btn.scripts.OnClick(Btn)

-- what left the menu is on the settings window's Home page
ns.EditMode:Open("home")
local function homeButton(text)
  for _, r in ipairs(ns.EditMode.rows) do
    for _, b in ipairs(r.buttons or {}) do
      if b.text.text == text then return b end
    end
  end
end
for _, want in ipairs({ "Layouts", "Back up", "Font and look" }) do
  check(homeButton(want), "Home's launcher has " .. want)
end
Extra("launcher", { homeButton = homeButton })
-- the samples moved to the pages they belong to
local function pageButton(page, text)
  ns.EditMode:Select(page)
  for _, r in ipairs(ns.EditMode.rows) do
    if r.button and r.button.text.text == text then return r.button end
  end
end
c = pageButton("cast", "Sample cast")
c.scripts.OnClick(c)
check(Bar.label.text == "Sample cast" and Bar.shown, "sample cast, from the Castbar page")
Bar.scripts.OnUpdate(Bar, 0)
now = now + 5
Bar.scripts.OnUpdate(Bar, 0.1)
Bar.scripts.OnUpdate(Bar, 2)
TBar.scripts.OnUpdate(TBar, 0.1)
TBar.scripts.OnUpdate(TBar, 2)
c = pageButton("loot", "Sample loot")
c.scripts.OnClick(c)
check(VoltUILoot.shown and VoltUILoot.title.text == "Sample loot", "sample loot window, from its page")
VoltUILoot:Hide()
Extra("treasure sample") -- another add-on's tests, since VoltUI 1.104.0
Extra("rare sample") -- another add-on's tests, since VoltUI 1.104.0
ns.EditMode:Select("home")
local keepB = ns.ActionBars.enabled
ns.ActionBars.enabled = nil
ns.EditMode:RefreshPage()
local tl = homeButton("Quick keybinds")
local listed = 0
local realKeys = ns.ActionBars.QuickKeys
ns.ActionBars.QuickKeys = function() listed = listed + 1 end
tl.scripts.OnClick(tl)
check(listed == 0 and tl.alpha == 0.4, "a launcher button for a part that's off is dimmed and does nothing")
ns.ActionBars.QuickKeys = realKeys
ns.ActionBars.enabled = keepB
ns.EditMode:Close()

-- closing by clicking elsewhere
Btn.scripts.OnClick(Btn)
check(Menu.events.GLOBAL_MOUSE_DOWN, "listens for clicks only while open")
local overMenu, overIcon = true, false
MouseIsOver = function(f) if f == Menu then return overMenu end; return overIcon end
Menu.scripts.OnEvent(Menu, "GLOBAL_MOUSE_DOWN")
check(Menu.shown, "a click on the menu keeps it open")
overMenu, overIcon = false, true
Menu.scripts.OnEvent(Menu, "GLOBAL_MOUSE_DOWN")
check(Menu.shown, "a click on the icon is left to the icon")
overIcon = false
Menu.scripts.OnEvent(Menu, "GLOBAL_MOUSE_DOWN")
check(not Menu.shown and not Menu.events.GLOBAL_MOUSE_DOWN, "a click anywhere else closes it")

-- hiding it is the General page's switch
local before_font_check = VoltUIDB.font
SlashCmdList.VOLTUI("icon on")
check(VoltUIDB.icon and not chat[#chat]:find("reload") and VoltUIMinimapButton:IsShown(), "/volt icon on: shown at once, no reload asked for")
SlashCmdList.VOLTUI("icon off")
check(VoltUIDB.icon == false and not VoltUIMinimapButton:IsShown() and not chat[#chat]:find("reload"), "/volt icon off hides it at once")
SlashCmdList.VOLTUI("icon on")
SlashCmdList.VOLTUI("font")
check(chat[#chat]:find("fonts: ") and VoltUIDB.font == before_font_check, "/volt font with no name lists the fonts and changes nothing")
Btn:Show()

end)()

;(function()
Extra("treasure alert in combat") -- another add-on's tests, since VoltUI 1.104.0

print("== Blocked actions")
VoltUIDB.blockedLog = nil
local before = #chat
fire("ADDON_ACTION_BLOCKED", "SomeOtherAddon", "Frame:Hide()")
check(#chat == before and not VoltUIDB.blockedLog, "other add-ons are their own business")
fire("ADDON_ACTION_BLOCKED", "VoltUI", "Frame:Hide()")
check(#chat == before + 1 and chat[#chat]:find("Frame:Hide()", 1, true), "VoltUI says what was blocked")
fire("ADDON_ACTION_BLOCKED", "VoltUI", "Frame:Hide()")
check(#chat == before + 1 and VoltUIDB.blockedLog["Frame:Hide()"] == 2, "once in chat, but counted")
inCombat = true
fire("ADDON_ACTION_FORBIDDEN", "VoltUI", "SetRaidTarget()")
check(chat[#chat]:find("SetRaidTarget", 1, true) and chat[#chat]:find("in combat"), "forbidden too, and whether it was in combat")
inCombat = false
VoltUIDB.blockedLog = nil
end)()

Extra("rare alert in combat") -- another add-on's tests, since VoltUI 1.104.0

;(function()
print("== ForeverDB: just its leveling window")
local C = ns.Companion
check(VoltUIDB.fdbTrimmed == nil, "nothing to do without ForeverDB loaded")
local enabled = { ForeverDB_Helper = true }
C_AddOns = {
  IsAddOnLoaded = function(n) return enabled[n] == true end,
  DisableAddOn = function(n, who) enabled[n] = who == nil and "off for all" or "off for one" end,
  EnableAddOn = function(n) enabled[n] = true end,
}
ForeverDB_DB = { rareAlerts = true, qhArrow = true, mapPins = true, tipUpgrade = nil, levelWin = true, planOn = true,
                 nextOn = true, questCapture = true, rareRecord = true, quiet = false, gatherMap = "mine",
                 minimap = { minimapPos = 200 }, cardIntroduced = true, botDetect = true }
-- ForeverDB loads before VoltUI; VoltUI's settings arrive on its own ADDON_LOADED.
fire("ADDON_LOADED", "VoltUI")
check(VoltUIDB.fdbTrimmed == "0.72.1", "runs once, by itself, when ForeverDB is there")
check(chat[#chat]:find("leveling window", 1, true) and chat[#chat]:find("/reload", 1, true), "and says to /reload")
local d = ForeverDB_DB
check(d.rareAlerts == false and d.qhArrow == false and d.mapPins == false and d.tipUpgrade == false, "its rare alerts, arrow, pins and tooltip lines go off")
check(d.minimap.hide == true and d.minimap.minimapPos == 200, "its minimap button hides, keeping its place")
check(d.quiet == true and d.gatherMap == "off", "quiet, and no gathering map")
check(d.levelWin == true and d.planOn == true and d.nextOn == true, "the leveling window and what it shows stay")
check(d.questCapture == true and d.rareRecord == true and d.botDetect == true, "what it records for foreverdb.net stays as set")
check(d.cardIntroduced == true, "its own bookkeeping isn't touched")
check(enabled.ForeverDB_Helper == "off for all", "the Helper is switched off for every character")
for _, key in ipairs(C.OFF) do
  check(key ~= "levelWin" and key ~= "planOn" and key ~= "nextOn" and key ~= "quiet", "never on the off list: " .. key)
end
check(d.rmapShow == false and d.rmapAuto == false and d.rmapMinimap == false, "0.60.3's raid plan mini map goes off too")
local n = #chat
fire("ADDON_LOADED", "VoltUI")
check(#chat == n, "only once")
-- Trimmed by an older VoltUI: only what ForeverDB added since goes off, once.
check(d.rollAdvice == false and d.coverTips == false and d.spQuestSparkle == false, "0.72.1's roll advice, loot coverage and sparkles go off too")
VoltUIDB.fdbTrimmed, d.mapPins, d.rmapShow, d.rmapAuto, d.rollAdvice, d.rollInspect, d.coverTips, d.spSkinSparkle = "0.60.3", true, nil, true, nil, true, nil, nil
VoltUIDB.fdbSaved.rmapShow, VoltUIDB.fdbSaved.rmapAuto, VoltUIDB.fdbSaved.rollAdvice, VoltUIDB.fdbSaved.rollInspect, VoltUIDB.fdbSaved.coverTips, VoltUIDB.fdbSaved.spSkinSparkle = nil, nil, nil, nil, nil, nil
fire("ADDON_LOADED", "VoltUI")
check(d.rollAdvice == false and d.rollInspect == false and d.coverTips == false and d.spSkinSparkle == false, "a newer ForeverDB's new features go off")
check(d.rmapAuto == true, "what an earlier catch-up covered isn't switched off again")
check(d.mapPins == true, "what you turned back on in ForeverDB stays on")
check(VoltUIDB.fdbTrimmed == "0.72.1" and chat[#chat]:find("loot roll advice", 1, true), "and it says so, once")
n = #chat
fire("ADDON_LOADED", "VoltUI")
check(#chat == n, "only once")
d.mapPins = false
-- You turn something back on in ForeverDB: VoltUI leaves it.
d.mapPins = true
SlashCmdList.VOLTUI("foreverdb undo")
check(d.rareAlerts == true and d.qhArrow == true and d.tipUpgrade == nil and d.quiet == false and d.gatherMap == "mine", "undo puts each setting back exactly, false and missing ones too")
check(d.rollAdvice == nil and d.rollInspect == true, "the caught-up ones too")
check(d.minimap.hide == nil and enabled.ForeverDB_Helper == true and VoltUIDB.fdbSaved == nil, "and the button and the Helper")
check(VoltUIDB.fdbTrimmed == "undone", "and doesn't run again by itself")
SlashCmdList.VOLTUI("foreverdb")
check(d.rareAlerts == false and chat[#chat]:find("/reload", 1, true), "/volt foreverdb does it again")
SlashCmdList.VOLTUI("foreverdb")
check(chat[#chat]:find("already", 1, true), "and says when there's nothing left to do")
-- Another add-on plans the levelling (FUI:PlansLevelling): the leveling window goes too, once, at login (C:AtLogin).
check(VoltUIDB.fdbWindowOff == false, "undo cleared the window's state")
VoltUIDB.fdbWindowOff = nil
d.levelWin = true
C:AtLogin()
check(d.levelWin == true, "without a planner the leveling window stays")
ns.FUI:PlansLevelling("Planner")
local shown = true
ForeverDBLevelWindow = { IsShown = function() return shown end, Hide = function() shown = false end }
C:AtLogin()
check(d.levelWin == false and not shown and VoltUIDB.fdbWindowOff == true, "with one it goes, and hides if it was up")
check(chat[#chat]:find("Planner plans your levelling", 1, true), "and says so, by its name")
n = #chat
d.levelWin = true -- turned back on in ForeverDB's own settings
C:AtLogin()
check(#chat == n, "only once")
SlashCmdList.VOLTUI("foreverdb window")
check(d.levelWin == true and VoltUIDB.fdbWindowOff == false and chat[#chat]:find("back", 1, true), "/volt foreverdb window brings it back, for good")
C:AtLogin()
check(d.levelWin == true, "it isn't turned off again at the next login")
SlashCmdList.VOLTUI("foreverdb window")
check(VoltUIDB.fdbWindowOff == true and d.levelWin == false, "and the same command turns it off again")
SlashCmdList.VOLTUI("foreverdb window")
SlashCmdList.VOLTUI("foreverdb undo")
check(d.levelWin == true, "undo brings the window back as it was")
SlashCmdList.VOLTUI("foreverdb")
ns.FUI.levelPlanner, ForeverDBLevelWindow = nil, nil
d.collectOnly = true
SlashCmdList.VOLTUI("foreverdb")
check(chat[#chat]:find("collecting data", 1, true), "leaves ForeverDB alone while it only collects data")
SlashCmdList.VOLTUI("foreverdb undo")
ForeverDB_DB, C_AddOns = nil, nil
SlashCmdList.VOLTUI("foreverdb")
check(chat[#chat]:find("isn't loaded", 1, true), "says so without ForeverDB")
VoltUIDB.fdbTrimmed, VoltUIDB.fdbSaved, VoltUIDB.fdbHelperWasOn = nil, nil, nil
end)()

;(function()
print("== Settings windows keep their font")
local E, St = ns.EditMode, ns.Style
local function inside(fs, root)
  local p = fs.parent
  while p do
    if p == root then return true end
    p = p.parent
  end
end
local function strays(root)
  local bad = {}
  for _, fs in ipairs(allFontStrings) do
    -- A frame's preview in the settings window is the frame itself, so it does follow the font.
    local preview = false
    for _, f in pairs(ns.EditMode.previews or {}) do if inside(fs, f) then preview = true end end
    -- A font picker shows each font's name in that font.
    if inside(fs, root) and not preview and not fs.fontPreview
      and not (fs.font and (fs.font[1]:find("SpaceMono%-") or fs.font[1]:find("JetBrainsMono%-"))) then
      bad[#bad + 1] = tostring(fs.text)
    end
  end
  return #bad, table.concat(bad, ", ")
end
-- Open everything once so it all exists.
SlashCmdList.VOLTUI("edit")
for _, def in ipairs(ns.Pages.list) do E:Select(def.key) end
VoltUIMinimapButton.scripts.OnClick(VoltUIMinimapButton)
ns.Bags:Slash("")
-- Change the font the way the panel does it.
E:Select("general")
local fontRow
for _, r in ipairs(E.rows) do if r.def.key == "font" then fontRow = r end end
fontRow.io.set(fontRow.def, "rajdhani")
fontRow.io.changed(fontRow.def)
check(VoltUIDB.font == "rajdhani", "font changed")
check(VoltUIPlayerFrame.name.font[1]:find("Rajdhani"), "the frames follow it")
check(VoltUIPlayerFrame.hpText.font[1]:find("Rajdhani"), "and their numbers")
check(VoltUILoot.title.font[1]:find("Rajdhani"), "and other VoltUI windows")
local n, what = strays(VoltUISettings)
check(n == 0, "the settings window doesn't: " .. what)
n, what = strays(VoltUIMoveBar)
check(n == 0, "the move toolbar doesn't: " .. what)
n, what = strays(VoltUIMenu)
check(n == 0, "the minimap menu doesn't: " .. what)
check(VoltUIPlayerFrame.mover.label.font[1]:find("JetBrainsMono%-"), "the drag overlays don't")
check(VoltUIMinimapButton.glyph.font == nil and tostring(VoltUIMinimapButton.glyph.tex):find("Bolt$"), "the icon's bolt is a texture, not a letter")
check(fontRow.value.text == "Rajdhani", "the setting still shows what's chosen")
-- Built while another font is chosen, and repainted after.
E.pages.cast = nil
E:Select("cast")
n, what = strays(VoltUISettings)
check(n == 0, "a page built after the change is the same: " .. what)
VoltUIMinimapButton.scripts.OnClick(VoltUIMinimapButton)
VoltUIMinimapButton.scripts.OnClick(VoltUIMinimapButton)
n, what = strays(VoltUIMenu)
check(n == 0, "and the menu after repainting: " .. what)
-- Size can still change on a fixed one.
St.SetFont(fontRow.label, 14)
check(fontRow.label.font[2] == 14 and fontRow.label.font[1]:find("Mono%-"), "size changes, it stays one of the settings' two fonts")
St.SetFont(fontRow.label, 12)
VoltUIMinimapButton.scripts.OnClick(VoltUIMinimapButton)
ns.Bags:Slash("")
SlashCmdList.VOLTUI("font barlow")
SlashCmdList.VOLTUI("edit")
end)()

;(function()
print("== Cast bar text")
local Bar = VoltUICastbar
local function cast(c)
  c.icon, c.st, c.en, c.guid = "i", GetTime() * 1000, (GetTime() + 2) * 1000, "x" .. tostring(c.spellID)
  castInfo.player = c
  fire("UNIT_SPELLCAST_START", "player", c.guid)
  local text = Bar.label.text
  castInfo.player = nil
  fire("UNIT_SPELLCAST_STOP", "player", c.guid)
  Bar.scripts.OnUpdate(Bar, 2)
  return text
end
check(cast({ name = "Opening", display = "Opening" }) == "Opening", "the usual case")
check(cast({ name = "Opening - No Text", display = "Opening - No Text" }) == "Opening", "a water barrel: the designers' note comes off")
check(cast({ name = "Opening - No Text", display = "" }) == "Opening", "from the plain name too")
check(cast({ name = "Fishing - No Text Here", display = "" }) == "Fishing - No Text Here", "only as the end of a name")
check(cast({ name = "Hearthstone", display = "Hearthstone" }) == "Hearthstone", "other spells are left alone")
check(cast({ name = "", display = "Opening" }) == "Opening", "opening a chest: empty name, display name used")
check(cast({ name = "Internal", display = "Shown" }) == "Shown", "the display name wins, as on the game's own bar")
check(cast({ name = "Lightning Bolt", display = "" }) == "Lightning Bolt", "empty display name falls back to the name")
check(cast({ name = nil, display = "Opening" }) == "Opening", "no name at all still shows the bar")
C_Spell = { GetSpellName = function(id) return id == 3365 and "Opening" or nil end }
check(cast({ name = "", display = "", spellID = 3365 }) == "Opening", "both empty: the spell's own name")
check(cast({ name = "", display = "", spellID = 1 }) == "Casting", "nothing known: never a blank bar")
check(cast({ name = "", display = "" }) == "Casting", "no spell ID either")
C_Spell = nil
-- channels
chanInfo.player = { name = "", display = "Drain", icon = "i", st = GetTime() * 1000, en = (GetTime() + 2) * 1000 }
fire("UNIT_SPELLCAST_CHANNEL_START", "player")
check(Bar.mode == "channel" and Bar.label.text == "Drain", "channels use the display name too")
chanInfo.player = { name = "", display = "", icon = "i", st = GetTime() * 1000, en = (GetTime() + 2) * 1000 }
fire("UNIT_SPELLCAST_CHANNEL_UPDATE", "player")
check(Bar.label.text == "Channelling", "and never go blank")
chanInfo.player = nil
fire("UNIT_SPELLCAST_CHANNEL_STOP", "player")
Bar.scripts.OnUpdate(Bar, 2)
-- secret text goes straight to the widget
local SM = {}
for _, m in ipairs({ "__len", "__concat", "__lt", "__le", "__tostring", "__index" }) do SM[m] = function() error("a secret value was used in Lua", 2) end end
local secret = setmetatable({}, SM)
issecretvalue = function(v) return getmetatable(v) == SM end
castInfo.player = { name = secret, display = secret, icon = "i", st = GetTime() * 1000, en = (GetTime() + 2) * 1000, guid = "s1" }
local ok, err = pcall(function() fire("UNIT_SPELLCAST_START", "player", "s1") end)
check(ok and rawequal(Bar.label.text, secret), "a secret name is passed straight through: " .. tostring(ok and "" or err))
issecretvalue = nil
castInfo.player = nil
fire("UNIT_SPELLCAST_STOP", "player", "s1")
Bar.scripts.OnUpdate(Bar, 2)
end)()

;(function()
print("== Action bars")
local AB = ns.ActionBars
local E = ns.EditMode
inCombat = false
RegisterStateDriver, UnregisterStateDriver = barStateDriver, barStateDriverOff -- the rare alert's tests swapped in their own
check(AB.enabled and AB.started, "started at login")
local Bar1, Bar2, Bar3, Bar4 = VoltUIBar1, VoltUIBar2, VoltUIBar3, VoltUIBar4
local hidden = ns.Style.HiddenParent()

-- Which bars start on
check(VoltUIDB.barCfg.bar1.on, "bar 1 is on")
check(VoltUIDB.barCfg.bar2.on, "a bar the game was showing stays on")
check(VoltUIDB.barCfg.bar3.on, "a bar with something on it stays on")
check(not VoltUIDB.barCfg.bar4 or not VoltUIDB.barCfg.bar4.on, "an empty, hidden bar starts off")
check(Bar1 and Bar2 and Bar3 and not VoltUIBar4, "frames only for the bars that are on")
local names = {}
for _, it in ipairs(AB:List()) do names[#names + 1] = it.key end
check(table.concat(names, " ") == "bar1 bar2 bar3 bar4 bar5 bar6 bar7 stance pet totem", "only bars this client has: " .. table.concat(names, " "))
fire("PLAYER_ENTERING_WORLD")
check(VoltUIDB.barSeeded, "the first run's choice is remembered")
barActions[25] = true
AB:Seed()
check(not VoltUIDB.barCfg.bar4 or not VoltUIDB.barCfg.bar4.on, "and doesn't override your choices later")
barActions[25] = nil

-- The game's bars
check(MultiBarLeft.parent == hidden and MultiBarLeft.allOff, "the game's side bar is retired")
check(#MultiBarLeft.actionButtons == 0, "and forgets its buttons")
check(MainActionBar.parent == hidden and not MainActionBar.allOff and MainActionBar.events.ACTIONBAR_PAGE_CHANGED, "the main bar is hidden but keeps listening, for vehicles")
check(MultiBar6Button1.allOff and MultiBar6Button1.attrs.statehidden and not MultiBar6Button1.shown, "a bar that's off: its buttons are out of the way")
do -- The game's own buttons, or the game treats its own clicks and events as VoltUI's code.
  local AB1 = ActionButton1
  check(AB1.parent == Bar1 and AB1.shown and AB1.attrs.statehidden == nil, "bar 1 uses the game's button, and retiring its old bar leaves it up")
  check(AB1.allOff, "and the button no longer listens for itself")
  AB1.allOff = nil
  AB:HideBlizzard() -- nothing lays the bars out again after this at login, so it mustn't undo them
  check(AB1.shown and AB1.attrs.statehidden == nil and not AB1.allOff, "retiring the game's bars leaves buttons in use alone")
  AB1.allOff = true
  check(MultiBarBottomLeftButton1.parent == Bar2 and MultiBarBottomLeftButton12.parent == Bar2, "so does bar 2")
  check(AB1.bar == nil, "it doesn't send slot changes to its old bar")
  check(AB1.attrs.showgrid >= 4096 and AB1.attrs.showgrid > 4, "the game's main bar won't hide it for being empty")
  check(AB1.index == 1 and AB1.commandName == "ACTIONBUTTON1" and AB1.action == 1, "what the game reads on it is the game's")
  check(not rawget(_G, "VoltUIBar1Button1Key") or VoltUIBar1Button1Key.parent == AB1, "the key's button sits on it")
  local spare = AB:TakeButton({ def = { label = "Spare Bar", blizz = "NoSuchBar" } }, 1)
  check(spare.tmpl == "ActionBarButtonTemplate" and spare:GetName() == "VoltUISpareBarButton1", "a client without one gets a button made")
end
check(StanceBar.parent == hidden and #StanceBar.actionButtons == 1, "the stance bar is hidden, its buttons still listed")
check(PetActionBar.parent == hidden and PetActionBar.events.PET_BAR_UPDATE, "the pet bar is hidden but keeps updating")

-- Slots and templates
local b = VoltUIBar1Button1
check(b and b.tmpl == "ActionBarButtonTemplate" and b.parent == Bar1 and b.kind == "CheckButton", "buttons use the game's template")
check(b.id == 0 and b.attrs.action == 1, "the slot comes from the action attribute, not the game's paging")
check(VoltUIBar2Button1.attrs.action == 61 and VoltUIBar2Button12.attrs.action == 72, "bar 2: the game's bottom left slots")
check(VoltUIBar3Button1.attrs.action == 49, "bar 3: bottom right")
check(#Bar1.buttons == 12, "twelve buttons")

-- Keys
check(b.kKey.text == "1", "key text")
check(boundKeys["1"] and boundKeys["1"].owner == b.kBind and boundKeys["1"].name == "VoltUIBar1Button1Key" and boundKeys["1"].button == "HOTKEY", "your key presses this button")
check(boundKeys.F1 and boundKeys.F1.owner == b.kBind, "every key bound to it, not just the first")
check(VoltUIBar1Button2.kKey.text == "SWU", "long key names shortened: " .. tostring(VoltUIBar1Button2.kKey.text))
check(VoltUIBar2Button2.kKey.text == "SQ" and boundKeys["SHIFT-Q"].owner == VoltUIBar2Button2.kBind, "a multibar key")
local S0 = AB.ShortKey
check(S0("BUTTON4") == "M4" and S0("CTRL-NUMPAD3") == "CN3" and S0("BACKSPACE") == "Bs" and S0("ALT-SPACE") == "ASp" and S0(nil) == "", "short key names")
check(b.kBind.tmpl == "SecureActionButtonTemplate" and b.kBind.attrs["useparent-action"] and b.kBind.attrs.type == "action", "the key button borrows its parent's action")
check(b.kBind.wrapped and b.kBind.wrapped.OnClick, "key presses are turned into clicks")
local calls = bindCalls
fire("UPDATE_BINDINGS")
check(bindCalls == calls, "unchanged keys aren't rebound (setting them fires this event)")
barKeys.ACTIONBUTTON3 = { "E" }
inCombat = true
fire("UPDATE_BINDINGS")
check(VoltUIBar1Button3.kKey.text == "E", "the text updates in combat")
check(not boundKeys.E and AB.keysPending, "binding waits for combat to end")
inCombat = false
fire("PLAYER_REGEN_ENABLED")
check(boundKeys.E and boundKeys.E.owner == VoltUIBar1Button3.kBind and not AB.keysPending, "and happens after")

-- The look
check(b.NormalTexture.parent == hidden and b.buttonNormal.parent == hidden and b.SlotArt.parent == hidden and b.Border.parent == hidden and b.HotKey.parent == hidden, "the game's art is gone for good")
check(b.InterruptDisplay.parent == hidden, "and its interrupt animation")
check(b.SpellCastAnimFrame.parent == b and b.SpellCastAnimFrame.alpha == 0, "the cast animation stays on the button, where the game's code expects it, but out of sight")
check(b.icon.maskRemoved == b.IconMask and b.icon.texCoord[1] == 0.07, "square icons, edges cropped")
check(b.kBack.ctex and b.kEdges[1].shown, "a flat dark slot and a thin border")
check(b.Name.parent == b.kText and b.Count.parent == b.kText, "text sits above the cooldown swipe")
check(b.kText.flevel > b.flevel, "the text layer is higher")
check(b.cooldown.hideNumbers == false and b.cooldown.countdownFont == "VoltUICooldownFontbar1", "cooldown numbers, in VoltUI's font")
check(VoltUICooldownFontbar1.font[2] == 14, "at the chosen size")
ActionButton_UpdateCooldownNumberHidden(b)
check(b.cooldown.hideNumbers == false, "VoltUI's setting wins over the game's on our bars")

-- Layout
check(Bar1.w == 12 * 36 + 11 * 3 and Bar1.h == 36, "the bar fits its buttons: " .. tostring(Bar1.w))
check(b.w == 36 and b.h == 36, "button size")
local function at(btn) local p = btn.points[#btn.points]; return p[4], p[5] end
local x, y = at(VoltUIBar1Button4)
check(x == 3 * 39 and y == 0, "buttons run left to right: " .. tostring(x))
local c = AB:Cfg("bar1")
c.perRow, c.count, c.size, c.gapX, c.gapY = 4, 10, 20, 2, 5
AB:Changed("bar1")
check(Bar1.w == 4 * 20 + 3 * 2 and Bar1.h == 3 * 20 + 2 * 5, "rows: " .. tostring(Bar1.w) .. "x" .. tostring(Bar1.h))
x, y = at(VoltUIBar1Button5)
check(x == 0 and y == 25, "a new row goes above")
x, y = at(VoltUIBar1Button4)
check(x == 66 and y == 0, "the row's end")
check(VoltUIBar1Button10.shown and not VoltUIBar1Button11.shown and VoltUIBar1Button11.attrs.statehidden, "spare buttons are hidden")
c.growX = "left"
AB:Changed("bar1")
x, y = at(VoltUIBar1Button1)
check(x == 66 and y == 0, "rows can fill to the left")
c.growY = "down"
AB:Changed("bar1")
x, y = at(VoltUIBar1Button1)
check(y == 50, "and be added downwards: " .. tostring(y))
c.scale = 1.5
AB:Changed("bar1")
check(Bar1.scale == 1.5, "scale")
c.left, c.top = 100, 200
AB:Changed("bar1")
local p = Bar1.points[#Bar1.points]
check(sitsAt(Bar1, 100, 200) and c.point == p[3], "a saved spot")
AB:ResetBar("bar1")
check(c.perRow == 12 and c.left == nil and c.on and Bar1.w == 465, "reset: default look and spot, still on")

-- Paging on bar 1
check(stateDrivers[Bar1].page:find("[bar:2]2", 1, true) and stateDrivers[Bar1].page:find("[bonusbar:1]7", 1, true), "bar 1 pages")
check(not stateDrivers[Bar2].page, "other bars don't")
local special = { tonumber = tonumber }
local handle
function handle(f)
  return setmetatable({}, { __index = function(_, k)
    if k == "GetAttribute" then return function(_, n) return f.attrs and f.attrs[n] end end
    if k == "SetAttribute" then return function(_, n, v) f.attrs = f.attrs or {}; f.attrs[n] = v end end
    if k == "ChildUpdate" then
      return function(_, id, msg)
        for _, kid in ipairs(f.buttons) do
          local code = kid.attrs["_childupdate-" .. id]
          if code then
            local fn = assert(load("local self, scriptid, message = ...; " .. code, "childupdate", "t", {}))
            fn(handle(kid), id, msg)
          end
        end
      end
    end
    if k == "CallMethod" then return function(_, m, ...) return f[m](f, ...) end end
  end })
end
local function page(state)
  local env = setmetatable({ control = handle(Bar1) }, { __index = special })
  local fn = assert(load("local self, stateid, newstate = ...; " .. Bar1.attrs["_onstate-page"], "onstate", "t", env))
  fn(handle(Bar1), "page", state)
end
page("2")
check(VoltUIBar1Button1.attrs.action == 13 and VoltUIBar1Button12.attrs.action == 24, "Shift-2: page two")
barActions[13] = nil
page("7")
check(VoltUIBar1Button1.attrs.action == 73, "a stance or form page")
page("1")
check(VoltUIBar1Button1.attrs.action == 1, "and back")
special.HasVehicleActionBar = function() return true end
special.GetVehicleBarIndex = function() return 16 end
page("special")
check(VoltUIBar1Button1.attrs.action == 181, "a vehicle's page comes from the game")
special.HasVehicleActionBar, special.GetVehicleBarIndex = nil, nil
special.HasOverrideActionBar = function() return true end
special.GetOverrideBarIndex = function() return 14 end
page("special")
check(VoltUIBar1Button1.attrs.action == 157, "an override page")
special.HasOverrideActionBar, special.GetOverrideBarIndex = nil, nil
special.HasTempShapeshiftActionBar = function() return true end
special.GetTempShapeshiftBarIndex = function() return 13 end
page("special")
check(VoltUIBar1Button1.attrs.action == 145, "a temporary form's page")
special.HasTempShapeshiftActionBar, special.GetTempShapeshiftBarIndex = nil, nil
special.HasBonusActionBar = function() return true end
special.GetBonusBarIndex = function() return 11 end
page("special")
check(VoltUIBar1Button1.attrs.action == 121, "possession")
special.HasBonusActionBar, special.GetBonusBarIndex = nil, nil
page("special")
check(VoltUIBar1Button1.attrs.action == 1, "nothing special after all: page one")
VoltUIBar1Button1.kOut = true
page("1")
check(not VoltUIBar1Button1.kOut, "turning a page forgets the old slot's range")

-- The other secure snippets at least run
local keyCode = VoltUIBar1Button1.kBind.wrapped.OnClick
local function keyClick(button, info)
  local env = { GetActionInfo = function() return info end }
  local me = { GetEffectiveAttribute = function() return 1 end }
  return assert(load("local self, button, down = ...; " .. keyCode, "key", "t", env))(me, button, true)
end
check(keyClick("HOTKEY", "spell") == "LeftButton", "a key press clicks")
check(keyClick("HOTKEY", "flyout") == false, "a flyout key press doesn't cast")
check(keyClick("LeftButton", "spell") == nil, "real clicks pass straight through")
local w = AB.wrap
check(OverrideActionBarButton1.wrapped.OnShow and OverrideActionBarButton1.wrapped.OnHide, "VoltUI watches the vehicle bar")
check(attrDrivers[w].petbattleui == "[petbattle]1;0", "and pet battles")
local keysSet = {}
local function override(name, over, pb)
  keysSet = {}
  w.attrs.overrideui, w.attrs.petbattleui = over, pb
  local me = {
    GetAttribute = function(_, n) return w.attrs[n] end,
    ClearBindings = function() keysSet.cleared = true end,
    RunAttribute = function(_, n, ...)
      local function setb(_, _, key, cmd) keysSet[key] = cmd end
      return assert(load("local self = ...; local function run(...) " .. w.attrs[n] .. " end; return run(select(2, ...))", n, "t", { select = select }))(setmetatable({ SetBinding = setb }, {}), ...)
    end,
  }
  local env = { GetBindingKey = function(cmd) return unpack(barKeys[cmd] or {}) end }
  assert(load("local self, name, value = ...; " .. w.attrs._onattributechanged, "ov", "t", env))(me, name, over)
end
override("overrideui", 1, 0)
check(keysSet.cleared and keysSet["1"] == "ACTIONBUTTON1" and keysSet.F1 == "ACTIONBUTTON1", "the vehicle bar takes keys 1-6 back")
override("overrideui", 0, 0)
check(keysSet.cleared and not keysSet["1"], "and lets go after")

-- Visibility
local cfg2 = AB:Cfg("bar2")
check(stateDrivers[Bar2].visibility == "[petbattle]hide;[overridebar][vehicleui]hide;show", "bars step aside for the vehicle bar: " .. tostring(stateDrivers[Bar2].visibility))
cfg2.mode = "combat"
AB:Changed("bar2")
check(stateDrivers[Bar2].visibility:find("%[combat%]show;hide$"), "only in combat")
cfg2.mode = "peace"
AB:Changed("bar2")
check(stateDrivers[Bar2].visibility:find("%[nocombat%]show;hide$"), "only out of combat")
cfg2.mode = "always"
AB:Changed("bar2")
local realOverride = OverrideActionBar
OverrideActionBar = nil
check(AB:Driver(Bar2) == "[petbattle]hide;show", "no vehicle bar on this client: nothing to step aside for")
OverrideActionBar = realOverride

-- Empty slots
local empty = VoltUIBar1Button2
check(empty.alpha == 1, "empty slots show by default")
local c1 = AB:Cfg("bar1")
c1.empty = false
AB:Changed("bar1")
check(empty.alpha == 0 and VoltUIBar1Button1.alpha == 1, "or only filled ones")
fire("ACTIONBAR_SHOWGRID")
check(empty.alpha == 1, "picking up a spell shows where it can go")
fire("ACTIONBAR_HIDEGRID")
check(empty.alpha == 0, "putting it down hides them")
inCombat = true
fire("ACTIONBAR_SHOWGRID")
check(empty.alpha == 1, "in combat too")
fire("ACTIONBAR_HIDEGRID")
inCombat = false
barActions[2] = true
fire("ACTIONBAR_SLOT_CHANGED", 2)
check(empty.alpha == 1, "filling a slot shows it")
barActions[2] = nil
empty:Update()
check(empty.alpha == 0, "emptying it hides it, when the game updates the button")
barActions[73], barActions[74] = true, true
page("7")
check(VoltUIBar1Button1.alpha == 1 and VoltUIBar1Button2.alpha == 1, "a new page repaints")
page("1")
check(VoltUIBar1Button2.alpha == 0, "and again on the way back")
c1.empty = true
AB:Changed("bar1")
equipped[2] = true
fire("PLAYER_EQUIPMENT_CHANGED")
check(empty.kEdges[1].ctex[2] == 0.85, "equipped items get a green border")
equipped[2] = nil
fire("PLAYER_EQUIPMENT_CHANGED")
check(empty.kEdges[1].ctex[2] == ns.Style.SOFT[2], "and lose it")

-- Text and border options
c1.keys, c1.macro, c1.stack, c1.border = false, true, false, false
c1.keySize, c1.macroSize, c1.stackSize, c1.cdText, c1.cdSize = 9, 13, 15, false, 22
AB:Changed("bar1")
check(b.kKey.alpha == 0 and b.Name.alpha == 1 and b.Count.alpha == 0, "each text can be off")
check(b.Name.font[2] == 13 and b.kKey.font[2] == 9 and b.Count.font[2] == 15, "and has its own size")
check(not b.kEdges[1].shown, "the border can be off")
check(b.icon.points[1][2] == 0, "and the icon fills the slot")
check(b.cooldown.hideNumbers == true and VoltUICooldownFontbar1.font[2] == 22, "cooldown number options")
AB:ResetBar("bar1")
check(b.kEdges[1].shown and b.icon.points[1][2] == 1, "border back")

-- Out of range
fire("ACTION_RANGE_CHECK_UPDATE", 1, false, true)
check(b.kOut and b.icon.vc[1] == 0.85, "out of range: red icon")
b:UpdateUsable()
check(b.icon.vc[1] == 0.85, "stays red when the game repaints it")
local usables = b.usables
fire("ACTION_RANGE_CHECK_UPDATE", 1, true, true)
check(not b.kOut and b.usables == usables + 1 and b.icon.vc[1] == 1, "back in range: the game's colour again")
fire("ACTION_RANGE_CHECK_UPDATE", 1, false, false)
check(not b.kOut, "spells without a range never go red")
VoltUIDB.barRange = false
fire("ACTION_RANGE_CHECK_UPDATE", 1, false, true)
check(not b.kOut, "the tint can be turned off")
VoltUIDB.barRange = true
local SM = {}
SM.__lt = function() error("a secret value was used in Lua", 2) end
SM.__eq = SM.__lt
local secret = setmetatable({}, SM)
issecretvalue = function(v) return getmetatable(v) == SM end
local ok, err = pcall(function() fire("ACTION_RANGE_CHECK_UPDATE", 1, secret, secret) end)
check(ok and not b.kOut, "a secret range is ignored: " .. tostring(err))
fire("ACTION_RANGE_CHECK_UPDATE", 1, false, secret)
check(not b.kOut, "whichever value is the secret one")
issecretvalue = nil

-- Procs (1.89.0): the game's glow and VoltUI's own list
do
  local G = AB.Glow
  local mgr = ActionButtonSpellAlertManager
  mgr.HasAlert = function(self, x) return self.alerts[x] == true end
  local oldTime, oldInfo, oldSpell, oldClass, oldUA, oldCF = GetTime, GetActionInfo, C_Spell, UnitClass, C_UnitAuras, CreateFrame
  local clock = 100
  GetTime = function() return clock end
  local function look() G.dirty = true; G:OnUpdate(0.01) end
  -- What the game makes the first time it shows its glow on a button.
  b.SpellActivationAlert = CreateFrame("Frame", nil, b)
  b.SpellActivationAlert.ProcStartFlipbook = b.SpellActivationAlert:CreateTexture()
  check(G.ev and b.kGlow and not b.kGlow.shown, "every button gets a proc glow, unlit")
  check(b.kGlow.flevel == b.flevel + 3 and b.kText.flevel == b.flevel + 4, "above the cooldown swipe, under the key text")
  check(not hookedGlobals.ActionButton_ShowOverlayGlow, "the game's alert manager is hooked, not the old global")

  -- The game's own glow
  mgr:ShowAlert(b)
  G:OnUpdate(0.01)
  check(mgr.alerts[b] and b.kGlow.shown, "the game's own proc glow lights VoltUI's square one")
  check(b.SpellActivationAlert.alpha == 0, "and its round art is out of sight")
  check(b.kGlow.wash.alpha > 0.5 and b.kGlow.inner[1].ctex[1] == 1, "a gold flash as it lights")
  clock = clock + 1
  G:OnUpdate(0.01)
  check(b.kGlow.wash.alpha == 0, "the flash fades")
  local a1 = b.kGlow.outer[1].alpha
  clock = clock + 0.4
  G:OnUpdate(0.01)
  check(b.kGlow.outer[1].alpha ~= a1, "the glow pulses")
  VoltUIDB.barProcStyle = "still"
  G:Refresh()
  G:Animate(clock + 0.3)
  check(b.kGlow.shown and b.kGlow.outer[1].alpha == 1 and b.kGlow.inner[1].alpha == 1, "or stays still")
  VoltUIDB.barProcStyle = "game"
  G:Refresh()
  check(not b.kGlow.shown and b.SpellActivationAlert.alpha == 1, "the game's look: its own art, not VoltUI's")
  local size = b.owner.cfg.size
  check(b.SpellActivationAlert.w == size * 1.4 and b.SpellActivationAlert.ProcStartFlipbook.w == size * 150 / 45, "fitted to VoltUI's button")
  VoltUIDB.barProcStyle = "nonsense"
  check(G:Style() == "pulse", "an unknown look is the pulsing one")
  VoltUIDB.barProcStyle = "pulse"
  VoltUIDB.barProcs = false
  G:Refresh()
  check(not b.kGlow.shown and b.SpellActivationAlert.alpha == 0, "off: no glow, and the game's hidden too")
  check(mgr.alerts[b], "without touching the game's own record of it")
  mgr:ShowAlert(b)
  check(b.SpellActivationAlert.alpha == 0, "a new game glow stays hidden while off")
  VoltUIDB.barProcs = true
  mgr:HideAlert(b)
  G:OnUpdate(0.01)
  check(not b.kGlow.shown, "the game's glow ending ends VoltUI's")
  local notOurs = { SpellActivationAlert = CreateFrame("Frame") }
  VoltUIDB.barProcs = false
  mgr:ShowAlert(notOurs)
  check(notOurs.SpellActivationAlert.alpha == 1 and not notOurs.kGlow, "leaves other buttons alone")
  mgr.alerts[notOurs] = nil
  VoltUIDB.barProcs = true

  -- VoltUI's list: Maelstrom Weapon on Lightning Bolt
  local actions = { [1] = { "spell", 403 } }
  GetActionInfo = function(slot) local x = actions[slot]; if x then return x[1], x[2], x[3] end end
  local NAMES = { [403] = "Lightning Bolt", [421] = "Chain Lightning", [8042] = "Earth Shock", [7384] = "Overpower" }
  local cast, cost, usable, cdActive = { [403] = 2000 }, { [403] = 30 }, {}, {}
  C_Spell = {
    GetSpellName = function(id) return NAMES[id] end,
    GetSpellInfo = function(id) return { name = NAMES[id], castTime = cast[id] or 0, spellID = id } end,
    GetSpellPowerCost = function(id) return { { cost = cost[id] or 0, type = 0 } } end,
    IsSpellUsable = function(id) return usable[id] == true, false end,
    GetSpellCooldown = function(id) return { isActive = cdActive[id] == true, isOnGCD = false, startTime = 0, duration = 0 } end,
  }
  local buffs, byId = {}, {}
  C_UnitAuras = {
    GetAuraDataByIndex = function(u, i, f) if u == "player" and f == "HELPFUL" then return buffs[i] end end,
    GetAuraDataByAuraInstanceID = function(u, id) return byId[id] end,
  }
  UnitClass = function() return "Shaman", "SHAMAN" end
  G.byName, G.base, G.paid, G.auras = nil, {}, {}, {}
  look()
  check(not b.kGlow.shown and G.watching, "Lightning Bolt on a button is watched, and unlit")
  check(G.base[403] == 2000 and G.paid[403], "its cast time and cost are learned")
  buffs[1] = { name = "Maelstrom Weapon", applications = 4, auraInstanceID = 77 }
  look()
  check(not b.kGlow.shown, "Maelstrom Weapon at 4 stacks: no glow")
  buffs[1].applications = 5
  look()
  check(b.kGlow.shown and b.kGlow.wash.alpha > 0.5, "at 5 stacks Lightning Bolt flashes and glows")
  buffs[1] = nil
  look()
  check(not b.kGlow.shown, "and stops when the stacks are spent")
  actions[1] = { "macro", 403, "spell" }
  buffs[1] = { name = "Maelstrom Weapon", applications = 5, auraInstanceID = 77 }
  look()
  check(b.kGlow.shown, "a macro showing Lightning Bolt glows too")
  actions[1] = { "spell", 403 }
  buffs[1] = nil
  look()

  -- In a fight the buff can't be read: the spell says it
  issecretvalue = function(v) return getmetatable(v) == SM end
  local function hidden() return setmetatable({}, SM) end
  buffs[1] = { name = hidden(), applications = hidden(), auraInstanceID = hidden() }
  look()
  check(not b.kGlow.shown, "a hidden buff alone lights nothing")
  cast[403], cost[403] = 0, 0
  local ok, err = pcall(look)
  check(ok and b.kGlow.shown, "a Lightning Bolt with no cast time glows: " .. tostring(err))
  cast[403], cost[403] = 2000, 30
  buffs[1] = nil
  clock = clock + 1
  G:OnUpdate(0.3) -- no event: the tick asks again
  check(not b.kGlow.shown, "and stops once it has a cast time again")
  cast[403] = 0
  look()
  check(b.kGlow.shown, "no cast time is enough on its own")
  cast[403], cost[403] = 2000, 0
  look()
  check(b.kGlow.shown, "and so is no cost")
  cost[403] = 30
  look()
  check(not b.kGlow.shown, "but a cheaper one isn't")
  cast[403] = setmetatable({}, SM)
  ok, err = pcall(look)
  check(ok and not b.kGlow.shown, "a hidden cast time is no proof: " .. tostring(err))
  cast[403] = 2000
  -- seen at 5 before the names went hidden: stays while the game still has it
  issecretvalue = nil
  buffs[1] = { name = "Maelstrom Weapon", applications = 5, auraInstanceID = 77 }
  byId[77] = buffs[1]
  look()
  issecretvalue = function(v) return getmetatable(v) == SM end
  buffs[1] = { name = hidden(), applications = hidden(), auraInstanceID = hidden() }
  look()
  check(b.kGlow.shown, "a buff seen at 5 before the fight hid it stays lit")
  byId[77], buffs[1] = nil, nil
  look()
  check(not b.kGlow.shown, "until the game no longer has it")
  issecretvalue = nil
  -- always instant: never lights for having no cast time
  actions[1] = { "spell", 421 }
  cast[421], cost[421] = 0, 0
  look()
  check(not b.kGlow.shown, "a spell never seen with a cast time or cost doesn't light for having none")
  actions[1] = { "spell", 8042 }
  look()
  check(not G.watching, "a spell no proc changes isn't watched")
  G.ev.scripts.OnEvent(G.ev, "UNIT_AURA", "target")
  check(not G.dirty, "the target's auras don't make it look again")
  G.ev.scripts.OnEvent(G.ev, "UNIT_AURA", "player")
  check(G.dirty, "yours do")
  look()

  -- Spells that can only be used after something: Overpower
  UnitClass = function() return "Warrior", "WARRIOR" end
  G.byName = nil
  actions[1] = { "spell", 7384 }
  look()
  check(not b.kGlow.shown and G.watching, "Overpower you can't use: no glow")
  usable[7384] = true
  look()
  check(b.kGlow.shown, "usable after a dodge: it glows")
  cdActive[7384] = true
  look()
  check(not b.kGlow.shown, "not while it cools down")
  cdActive[7384] = nil

  -- The game's look for VoltUI's own procs: a copy of the game's art
  CreateFrame = function(kind, name, parent, tmpl, ...)
    local f = oldCF(kind, name, parent, tmpl, ...)
    if tmpl == "ActionButtonSpellAlertTemplate" then
      local function anim() return { Play = function(s) s.playing = true end, Stop = function(s) s.playing = false end } end
      f.ProcStartAnim, f.ProcLoop = anim(), anim()
      f.ProcStartFlipbook = f:CreateTexture()
    end
    return f
  end
  VoltUIDB.barProcStyle = "game"
  b.kGameGlow = nil -- the stand-in client above couldn't make one
  G:Refresh()
  local copy = b.kGameGlow
  check(copy and copy.parent == b and copy.shown and copy.ProcStartAnim.playing, "the game's look: VoltUI's procs get the game's art")
  check(not b.kGlow.shown and copy.w == size * 1.4, "fitted, with no square glow")
  mgr:ShowAlert(b)
  G:OnUpdate(0.01)
  check(not copy.shown and b.SpellActivationAlert.alpha == 1, "the game's own glow on it too: shown once, not twice")
  mgr:HideAlert(b)
  usable[7384] = nil
  look()
  check(not copy.shown and not copy.ProcLoop.playing, "and gone with the proc")
  b.kGameGlow = false -- a client that can't make the art
  usable[7384] = true
  look()
  check(b.kGlow.shown, "where the game's art can't be made, the square glow stands in")
  b.kGameGlow = nil
  VoltUIDB.barProcStyle = "pulse"
  usable[7384] = nil

  -- Seeing the glow without a proc
  AB:Slash("glow")
  check(b.kGlow.shown, "/volt bars glow lights every button with something on it")
  clock = clock + 2
  G:OnUpdate(0.01)
  check(b.kGlow.shown, "for a few seconds")
  clock = clock + 2
  G:OnUpdate(0.01)
  check(not b.kGlow.shown, "then goes")
  VoltUIDB.barProcs = false
  local said = #chat
  G:Test()
  check(not b.kGlow.shown and #chat == said + 1, "with the glow off, it says so instead")
  VoltUIDB.barProcs = true

  -- Every class's list names real kinds of entries
  local okList = true
  for class, list in pairs(G.PROCS) do
    for _, rule in ipairs(list) do
      if type(rule.spells) ~= "table" or #rule.spells == 0 then okList = false end
      if not (rule.aura or rule.react) then okList = false end
      if rule.react and rule.aura then okList = false end
    end
  end
  check(okList, "every proc entry has spells and a buff or a use check")
  local mw = G.PROCS.SHAMAN[1]
  check(mw.aura == "Maelstrom Weapon" and mw.stacks == 5 and mw.spells[1] == "Lightning Bolt" and mw.instant and mw.free, "Maelstrom Weapon: 5 stacks, Lightning Bolt, instant and free")

  GetTime, GetActionInfo, C_Spell, UnitClass, C_UnitAuras, CreateFrame = oldTime, oldInfo, oldSpell, oldClass, oldUA, oldCF
  G.byName, G.base, G.paid, G.auras = nil, {}, {}, {}
  mgr.alerts[b] = nil
  b.SpellActivationAlert = nil
  G:Refresh()
end

-- Stance
check(not (VoltUIStanceButton1 and VoltUIStanceButton1.shown), "no forms, no stance buttons showing")
forms = { { icon = "bear", active = true, castable = true }, { icon = "cat", active = false, castable = false, cdStart = 5, cdDur = 10 } }
fire("UPDATE_SHAPESHIFT_FORMS")
local s1, s2 = VoltUIStanceButton1, VoltUIStanceButton2
check(s1 and s2 and s1.tmpl == "StanceButtonTemplate" and s2.id == 2, "a button per form")
check(s1.icon.tex == "bear" and s1.checked == true and s2.checked == false, "the active form is checked")
check(s1.icon.vc[1] == 1 and s2.icon.vc[1] == 0.4, "forms you can't use are dimmed")
check(s2.cooldown.cooldown and s2.cooldown.cooldown[2] == 10 and s1.cooldown.cleared, "form cooldowns")
check(VoltUIStancebar.w == 2 * 30 + 3, "the bar fits: " .. tostring(VoltUIStancebar.w))
barKeys.SHAPESHIFTBUTTON1 = { "F5" }
fire("UPDATE_BINDINGS")
check(s1.kKey.text == "F5", "stance keys show")
forms[3] = { icon = "tree", castable = true }
inCombat = true
fire("UPDATE_SHAPESHIFT_FORMS")
check(not VoltUIStanceButton3 and AB.applyPending, "a new form waits for combat to end")
inCombat = false
fire("PLAYER_REGEN_ENABLED")
check(VoltUIStanceButton3 and VoltUIStancebar.w == 3 * 30 + 6, "then gets a button")
forms[1].active, forms[2].active = false, true
fire("UPDATE_SHAPESHIFT_FORM")
check(s1.checked == false and s2.checked == true, "changing form moves the check")
local secretCd = setmetatable({}, SM)
issecretvalue = function(v) return getmetatable(v) == SM end
forms[2].cdStart, forms[2].cdDur = secretCd, secretCd
ok, err = pcall(function() fire("UPDATE_SHAPESHIFT_COOLDOWN") end)
check(ok, "a secret cooldown doesn't break the bar: " .. tostring(err))
issecretvalue = nil
forms[2].cdStart, forms[2].cdDur = 0, 0

-- Pet
local PB = VoltUIPetbar
local pb1 = PetActionButton1
check(PB and pb1.parent == PB and PB.buttons[10] == PetActionButton10, "the game's pet buttons move to our bar")
check(pb1.NormalTexture.parent == hidden and pb1.kKey, "dressed like the rest")
check(stateDrivers[PB].visibility:find("%[@pet,exists,nopossessbar%]show;hide$"), "shows with a pet")
AB:Cfg("pet").mode = "combat"
AB:Changed("pet")
check(stateDrivers[PB].visibility:find("%[@pet,exists,nopossessbar,combat%]show;hide$"), "and can also wait for combat")
AB:Cfg("pet").mode = "always"
AB:Cfg("pet").empty = false
AB:Changed("pet")
check(pb1.alpha == 0, "empty pet slots can hide")
petActions[1] = "Attack"
fire("PET_BAR_UPDATE")
check(pb1.alpha == 1, "a filled one shows")
AB:Cfg("pet").empty = true
AB:Changed("pet")
barKeys.BONUSACTIONBUTTON1 = { "CTRL-1" }
fire("UPDATE_BINDINGS")
check(pb1.kKey.text == "C1", "pet keys show")

-- Totems, for Shamans
local TB, T = VoltUITotembar, MultiCastActionBarFrame
check(TB and T.parent == TB and T.ignoreFramePositionManager, "the totem bar moves into a VoltUI frame")
check(T.scripts.OnUpdate == nil and T.points[#T.points][2] == TB, "and the game stops moving it")
-- The game's art goes, and the buttons get ours.
local tb1, summon, recall = MultiCastActionButton1, MultiCastSummonSpellButton, MultiCastRecallSpellButton
check(tb1.overlayTex.parent == hidden and tb1.NormalTexture.parent == hidden, "the totem art is gone")
check(MultiCastSlotButton1.background.parent == hidden and MultiCastSlotButton1.overlayTex.parent == hidden, "from the slots too")
check(MultiCastRecallSpellButtonHighlight.parent == hidden, "and the spell button's frame")
check(tb1.kEdges and summon.kEdges and recall.kEdges and tb1.kBack, "every button gets a slot and a border")
check(tb1.icon.texCoord and tb1.icon.texCoord[1] == 0.07, "and a cropped icon")
check(AB.mine[tb1] and AB.mine[summon], "and follows the proc and cooldown settings")
-- Each totem's own colour.
MultiCastActionButton_Update(tb1, 2, 1, 2)
local earth = tb1.kEdges[1].ctex
MultiCastActionButton_Update(tb1, 1, 1, 1)
check(earth[1] ~= tb1.kEdges[1].ctex[1], "each element has its own border colour")
-- Only the totems you have get a place.
T.numActiveSlots = 4
summon:Show()
recall:Show()
AB:Changed("totem")
check(TB.w == 6 * 30 + 5 * 4 and TB.h == 30 and T.w == TB.w, "summon, four totems and recall in a row")
check(summon.points[1][4] == 0 and tb1.points[1][4] == 34 and MultiCastSlotButton1.points[1][4] == 34, "each in its place, slot under its button")
check(MultiCastActionButton5.points[1][4] == 34 and MultiCastActionButton9.points[1][4] == 34, "and every page lines up")
check(MultiCastActionButton4.points[1][4] == 34 * 4, "up to the fourth")
check(recall.points[1][1] == "LEFT" and recall.points[1][4] == 34 * 5 and recall.w == 30, "recall last")
check(tb1.w == 30 and MultiCastSlotButton1.w == 30 and summon.w == 30, "all one size")
T.numActiveSlots = 2
recall:Hide()
summon:Hide()
AB:Changed("totem")
check(TB.w == 2 * 30 + 4, "fewer totems, a shorter bar")
check(MultiCastActionButton1.points[1][4] == 0, "and no gap for a spell you don't know")
T.numActiveSlots = 0
AB:Changed("totem")
check(TB.w > 1 and TB.h > 1, "something to grab with no totems yet")
-- The game's own moves don't stick, and wait for combat to end when they have to.
T.numActiveSlots = 4
summon:Show()
recall:Show()
AB:Changed("totem")
MultiCastActionBarFrame_Update(T)
check(#recall.points == 1 and recall.points[1][2] == T and MultiCastSlotButton1.points[1][4] == 34, "the game moving its buttons is put right")
inCombat = true
AB.applyPending = nil
MultiCastSlotButton1:SetPoint("BOTTOMLEFT", T, "BOTTOMLEFT", 41, 3)
local inFight = #MultiCastSlotButton1.points
MultiCastActionBarFrame_Update(T)
check(AB.applyPending and #MultiCastSlotButton1.points == inFight + 1, "in combat that waits")
inCombat = false
fire("PLAYER_REGEN_ENABLED")
check(not AB.applyPending and #MultiCastSlotButton1.points == 1 and MultiCastSlotButton1.points[1][4] == 34, "and happens when combat ends")
-- The flyout that picks totems.
local flyButton = new("Button", nil, MultiCastFlyoutFrame)
flyButton.icon, flyButton.spellId = flyButton:CreateTexture(), 100
local clearButton = new("Button", nil, MultiCastFlyoutFrame)
clearButton.icon, clearButton.spellId = clearButton:CreateTexture(), 0
MultiCastFlyoutFrame.buttons = { clearButton, flyButton }
MultiCastFlyoutFrame_ToggleFlyout()
check(MultiCastFlyoutFrame.top.ctex and MultiCastFlyoutFrame.middle.ctex, "the flyout goes flat")
check(flyButton.kEdges and flyButton.icon.texCoord[1] == 0.07, "and its buttons get ours as the game makes them")
check(clearButton.kEdges and clearButton.icon.texCoord == nil, "leaving the empty-slot art whole")
-- Settings
AB:Cfg("totem").scale = 1.2
AB:Cfg("totem").size = 40
AB:Cfg("totem").keys = false
AB:Cfg("totem").border = false
AB:Cfg("totem").perRow = 3
AB:Changed("totem")
check(TB.scale == 1.2 and tb1.w == 40 and tb1.kKey.alpha == 0, "scale, size and text work")
check(not tb1.kEdges[1].shown, "border too")
check(TB.w == 3 * 40 + 2 * 4 and TB.h == 2 * 40 + 4, "and rows")
AB:Cfg("totem").mode = "hover"
AB:Cfg("totem").fadeTo = 0
AB:Changed("totem")
MultiCastFlyoutFrame:Hide()
AB.ev.scripts.OnUpdate(AB.ev, 10)
check(TB.alpha == 0, "it fades")
MultiCastFlyoutFrame:Show()
AB.ev.scripts.OnUpdate(AB.ev, 10)
check(TB.alpha == 1, "but stays while you pick a totem")
barKeys.MULTICASTACTIONBUTTON1 = { "CTRL-5" }
AB:BindAll()
check(tb1.kKey.text == "C5", "the game's own keys show")
check(tb1.kBind == nil, "and stay the game's")
AB:ResetBar("totem")
local realClass = UnitClass
UnitClass = function() return "Rogue", "ROGUE" end
AB.list = {}
local noTotem = true
for _, it in ipairs(AB:List()) do if it.key == "totem" then noTotem = false end end
check(noTotem, "no totem bar for other classes")
UnitClass = realClass
AB.list = {}

-- Default spots above the bottom bars
local function petY() return PB.points[#PB.points][5] end
AB:Place(PB)
check(petY() == 138, "pet bar above bar 3")
AB:Cfg("bar3").on = false
AB:Changed("bar3")
AB:Place(PB)
check(petY() == 99 and not Bar3.shown, "or above bar 2 when bar 3 is off")
check(not stateDrivers[Bar3].visibility, "a bar that's off has no state driver")
AB:Cfg("bar2").on = false
AB:Changed("bar2")
check(petY() == 60, "and it moves when you turn one off")
AB:Cfg("bar2").on, AB:Cfg("bar3").on = true, true
AB:Changed("bar2")
AB:Changed("bar3")

-- A bar that's off gives its keys back
AB:Cfg("bar2").on = false
AB:Changed("bar2")
check(not boundKeys["SHIFT-Q"], "a bar that's off releases its keys")
AB:Cfg("bar2").on = true
AB:Changed("bar2")
check(boundKeys["SHIFT-Q"], "and takes them again")

-- Hover
local ch = AB:Cfg("bar2")
ch.mode, ch.alpha, ch.fadeTo = "hover", 0.9, 0.1
AB:Changed("bar2")
check(Bar2.alpha == 0.1 and AB.ev.scripts.OnUpdate, "hover: starts faded, and a timer runs")
local hovering = Bar2
local realOver = MouseIsOver
MouseIsOver = function(f) return f == hovering end
for _ = 1, 20 do AB.ev.scripts.OnUpdate(AB.ev, 0.05) end
check(math.abs(Bar2.alpha - 0.9) < 1e-6, "fades in under the mouse: " .. tostring(Bar2.alpha))
hovering = nil
AB.ev.scripts.OnUpdate(AB.ev, 0.05)
check(Bar2.alpha < 0.9 and Bar2.alpha > 0.1, "out again gradually")
for _ = 1, 20 do AB.ev.scripts.OnUpdate(AB.ev, 0.05) end
check(math.abs(Bar2.alpha - 0.1) < 1e-6, "back to faded")
inCombat = true
hovering = Bar2
for _ = 1, 20 do AB.ev.scripts.OnUpdate(AB.ev, 0.05) end
check(math.abs(Bar2.alpha - 0.9) < 1e-6, "fading works in combat")
inCombat = false
hovering = nil
fire("ACTIONBAR_SHOWGRID")
for _ = 1, 20 do AB.ev.scripts.OnUpdate(AB.ev, 0.05) end
check(math.abs(Bar2.alpha - 0.9) < 1e-6, "a held spell wakes faded bars")
fire("ACTIONBAR_HIDEGRID")
MouseIsOver = realOver
check(ch.mode == "always" and ch.fade == "hover", "the old Hover choice is carried over: always shown, fading until hovered")
-- (1.80.0) fading is its own setting: faded out of a fight, solid in one
ch.fade = "combat"
AB:Changed("bar2")
for _ = 1, 20 do AB.ev.scripts.OnUpdate(AB.ev, 0.05) end
check(math.abs(Bar2.alpha - 0.1) < 1e-6, "fade out of combat: faded while there's no fight")
inCombat = true
for _ = 1, 20 do AB.ev.scripts.OnUpdate(AB.ev, 0.05) end
check(math.abs(Bar2.alpha - 0.9) < 1e-6, "and solid for the whole fight, without the mouse")
inCombat = false
for _ = 1, 20 do AB.ev.scripts.OnUpdate(AB.ev, 0.05) end
check(math.abs(Bar2.alpha - 0.1) < 1e-6, "and faded again after it")
ch.mode = "combat"
AB:Changed("bar2")
check(AB:Driver(Bar2):find("%[combat%]show") and AB.ev.scripts.OnUpdate ~= nil, "fading goes with any of the Show choices")
ch.mode, ch.fade, ch.alpha, ch.fadeTo = "always", "off", 1, 0
AB:Changed("bar2")
check(Bar2.alpha == 1 and not AB.ev.scripts.OnUpdate, "no faders left: the timer stops")

-- Combat
inCombat = true
local pts = #Bar1.points
AB:Cfg("bar1").size = 50
AB:Changed("bar1")
AB:Apply(Bar1)
AB:ApplyAll()
check(Bar1.w == 465 and #Bar1.points == pts, "nothing secure moves in combat")
check(AB.applyPending, "the change waits")
AB:ResetBar("bar1")
AB:CopyLook("bar1")
AB:Slash("reset")
check(AB:Cfg("bar1").size == 50, "reset and copy wait too")
AB:Cfg("bar1").size = 36
AB:Cfg("bar4").on = true
AB:ApplyAll()
check(not VoltUIBar4, "no new secure frames in combat")
inCombat = false
fire("PLAYER_REGEN_ENABLED")
check(VoltUIBar4 and not AB.applyPending, "all done when combat ends")
Bar4 = VoltUIBar4
check(Bar4.w == 36 and Bar4.h == 12 * 36 + 11 * 3, "side bars run in a column")
check(VoltUIBar4Button1.attrs.action == 25, "bar 4: the game's right bar slots")
check(VoltUIBar4Button1.attrs.flyoutDirection == "LEFT", "column bars open flyouts sideways")
AB:Cfg("bar4").on = false
AB:Changed("bar4")

-- Edit mode
SlashCmdList.VOLTUI("bars")
check(VoltUISettings.shown and E.tab == "bars" and E.barKey == "bar1", "/volt bars opens its tab")
check(Bar1.mover.shown and Bar2.mover.shown and PB.mover.shown, "every bar gets an overlay")
check(not stateDrivers[Bar1].visibility and Bar1.shown and PB.shown, "bars stay shown while you edit them, even the pet bar")
check(E.copy.shown and E.keys.shown and E.hint.text:find("Drag"), "the bar buttons sit at the top of the page")
local function row(key)
  for _, r in ipairs(E.rows) do if r.def.key == key then return r end end
end
row("size"):Set(44)
check(VoltUIDB.barCfg.bar1.size == 44 and b.w == 44 and Bar1.h == 44, "changing a slider changes the bar")
check(row("size").value.text == "44", "and the row")
row("perRow"):Set(6)
check(Bar1.h == 2 * 44 + 3, "rows")
row("keys"):Set(false)
check(b.kKey.alpha == 0, "toggles")
row("growY"):Set("down")
check(VoltUIDB.barCfg.bar1.growY == "down", "choices")
check(row("fadeTo"):Refresh() == nil and row("fadeTo").alpha == 0.45, "opacity when faded is dimmed unless hovering")
row("mode"):Set("hover")
check(row("fadeTo").alpha == 1, "and wakes")
check(Bar1.alpha == 1, "bars stay solid while editing")
row("mode"):Set("always")
-- picking another bar
row("bar"):Step(1)
check(E.barKey == "bar2", "the picker moves to the next bar")
check(row("size").value.text == "36" and row("bar").value.text == "Bar 2", "rows show that bar's settings")
check(VoltUIDB.barCfg.bar2.size == 36 and VoltUIDB.barCfg.bar1.size == 44, "without changing either")
row("size"):Set(30)
check(VoltUIBar2Button1.w == 30 and b.w == 44, "changes go to the picked bar")
check(Bar2.mover.fill.ctex[4] == 0.45 and Bar1.mover.fill.ctex[4] == 0.2, "its overlay stands out")
Bar1.mover.scripts.OnMouseUp(Bar1.mover)
check(E.barKey == "bar1" and row("bar").value.text == "Bar 1", "clicking a bar picks it")
E:Select("player")
Bar2.mover.scripts.OnMouseUp(Bar2.mover)
check(E.tab == "bars" and E.barKey == "bar2", "from any tab")
check(E.copy.shown, "with its buttons")
E:Select("player")
check(E.hint.shown and not E.copy.shown, "other tabs keep their hint")
E:Select("bars")
-- turning a new bar on from the panel
E.barKey = "bar5"
E:RefreshPage()
check(not VoltUIBar5, "bar 5 isn't made until it's wanted")
row("size"):Set(40)
check(not VoltUIBar5, "changing an off bar's settings doesn't make it either")
row("on"):Set(true)
check(VoltUIBar5 and VoltUIBar5.shown and VoltUIBar5.mover.shown and VoltUIBar5Button1.w == 40, "turning it on makes it, with its overlay")
row("on"):Set(false)
check(not VoltUIBar5.shown and not VoltUIBar5.mover.shown, "and off hides it")
-- moving a bar
E.barKey = "bar2"
E:RefreshPage()
Bar2.mover.scripts.OnDragStart(Bar2.mover)
Bar2.mover.scripts.OnDragStop(Bar2.mover)
check(VoltUIDB.barCfg.bar2.point and sitsAt(Bar2, 300, 600), "dragging saves the spot")
-- copy
E.copy.scripts.OnClick(E.copy)
check(VoltUIDB.barCfg.bar3.size == 30 and VoltUIDB.barCfg.pet.size == 30, "copy look: other bars match")
check(VoltUIDB.barCfg.bar3.left == nil and VoltUIDB.barCfg.bar3.count == 12 and VoltUIDB.barCfg.bar3.on, "but stay where they are")
check(VoltUIDB.barCfg.pet.count == 10, "and keep their own number of buttons")
-- reset
E.reset.scripts.OnClick(E.reset)
E.reset.scripts.OnClick(E.reset)
check(VoltUIDB.barCfg.bar2.size == 36 and VoltUIDB.barCfg.bar2.left == nil and VoltUIDB.barCfg.bar2.on, "reset this bar")
-- all bars
b.kOut = true
row("barRange"):Set(false)
check(not b.kOut, "turning range off clears red icons now")
row("barRange"):Set(true)
-- totems have fixed buttons, and no slots to leave empty
E.barKey = "totem"
E:RefreshPage()
check(row("size").alpha == 1 and row("gapX").alpha == 1 and row("scale").alpha == 1 and row("on").alpha == 1 and row("mode").alpha == 1, "the totem bar has the layout rows")
check(row("keys").alpha == 1 and row("cdText").alpha == 1 and row("border").alpha == 1, "and text and border")
check(row("count").alpha == 0.45 and row("empty").alpha == 0.45 and row("macro").alpha == 0.45 and row("stack").alpha == 0.45, "but not what it doesn't have")
E.barKey = "bar1"
E:RefreshPage()
check(row("count").alpha == 1 and row("empty").alpha == 1, "and the others keep them")
-- Menu and bags have a tab of their own
E:Select("extras")
check(E.tab == "extras" and E.extraKey == "menu", "the tab opens on the menu")
check(not E.copy.shown and E.keys.shown, "with quick keybinds but no copy-to-all button")
local function erow(key)
  for _, r in ipairs(E.pages.extras.rows) do
    if r.def.key == key then return r end
  end
end
check(erow("bar").value.text == "Menu bar", "it says which")
check(erow("CharacterMicroButton") and erow("QuestLogMicroButton") and erow("StoreMicroButton"), "a row for each menu button")
check(erow("HelpMicroButton") == nil, "not for help, which the game hides")
check(erow("slots").alpha == 0.45 and erow("mono").alpha == 1 and erow("CharacterMicroButton").alpha == 1, "bag rows wait for the bag bar")
local Menu = VoltUIMenubar
erow("size"):Set(30)
check(CharacterMicroButton.w == 30 and CharacterMicroButton.h == 30, "size works")
check(CharacterMicroButton.normalArt.w == 30 * 1.15, "and the art follows")
erow("perRow"):Set(2)
check(Menu.h == 3 * 30 + 2 * 2, "rows work")
erow("border"):Set(false)
check(not CharacterMicroButton.kEdges[1].shown, "border works")
erow("border"):Set(true)
erow("mono"):Set(false)
check(CharacterMicroButton.normalArt.desat == false, "colour icons")
erow("mono"):Set(true)
check(CharacterMicroButton.normalArt.desat == true, "and grey ones")
-- Typing a value
local sz = erow("size")
local function typed(r, text)
  r.value.scripts.OnEditFocusGained(r.value)
  r.value:SetText(text)
  r.value.scripts.OnEnterPressed(r.value)
end
typed(sz, "33")
check(VoltUIDB.barCfg.menu.size == 33 and sz.value.text == "33" and CharacterMicroButton.w == 33, "a typed value applies")
typed(sz, "999")
check(VoltUIDB.barCfg.menu.size == 64 and sz.value.text == "64", "held to the row's limit")
typed(sz, "-5")
check(VoltUIDB.barCfg.menu.size == 16, "both ways")
typed(sz, "27.6")
check(VoltUIDB.barCfg.menu.size == 28 and sz.value.text == "28", "whole-number rows stay whole")
typed(sz, "rat")
check(VoltUIDB.barCfg.menu.size == 28 and sz.value.text == "28", "nonsense is ignored and the box goes back")
typed(sz, "")
check(VoltUIDB.barCfg.menu.size == 28 and sz.value.text == "28", "and so is nothing")
local sc = erow("scale")
typed(sc, "1.23")
check(VoltUIDB.barCfg.menu.scale == 1.23 and sc.value.text == "1.23", "a typed value needn't land on a slider step")
check(Menu.scale == 1.23, "and it's used")
typed(sc, "1,5")
check(VoltUIDB.barCfg.menu.scale == 1.5 and sc.value.text == "1.50", "a comma works as a decimal point")
sc:Step(1)
check(math.abs(VoltUIDB.barCfg.menu.scale - 1.55) < 0.001, "the wheel carries on from there")
typed(sc, "1")
-- While you type
sz.value.scripts.OnEditFocusGained(sz.value)
sz.value:SetText("3")
sz:Refresh()
check(sz.value.text == "3" and VoltUIDB.barCfg.menu.size == 28, "a refresh doesn't type over you")
sz.value.scripts.OnEscapePressed(sz.value)
check(sz.value.text == "28" and VoltUIDB.barCfg.menu.size == 28, "Esc puts it back")
sz.value.scripts.OnEditFocusGained(sz.value)
sz.value:SetText("31")
sz.value.scripts.OnEditFocusLost(sz.value)
check(VoltUIDB.barCfg.menu.size == 31, "clicking away keeps it")
sz.value.scripts.OnEditFocusGained(sz.value)
sz.value:SetText("40")
sz.value.scripts.OnTabPressed(sz.value)
check(VoltUIDB.barCfg.menu.size == 40, "so does Tab")
inCombat = true
typed(sz, "20")
check(VoltUIDB.barCfg.menu.size == 40 and sz.value.text == "40", "not in combat")
inCombat = false
erow("size"):Set(30)
-- Taking a button off the bar
local widthWith = Menu.w
erow("perRow"):Set(14)
widthWith = Menu.w
erow("QuestLogMicroButton"):Set(false)
check(VoltUIDB.barCfg.menu.hide.QuestLogMicroButton == true and erow("QuestLogMicroButton"):Refresh() == nil, "a menu button can come off")
check(QuestLogMicroButton.parent == hidden and Menu.w == widthWith - 32, "and the bar closes up")
erow("QuestLogMicroButton"):Set(true)
check(QuestLogMicroButton.parent == Menu.tray and VoltUIDB.barCfg.menu.hide.QuestLogMicroButton == nil and Menu.w == widthWith, "and go back")
-- Overlay and mouse
check(Menu.mover.shown and not CharacterMicroButton.mouseOn, "the buttons don't take clicks while editing")
Menu.mover.scripts.OnMouseUp(Menu.mover)
check(E.tab == "extras" and E.extraKey == "menu", "clicking the overlay opens this tab")
local Bags = VoltUIBagbar
E:Select("player")
Bags.mover.scripts.OnMouseUp(Bags.mover)
check(E.tab == "extras" and E.extraKey == "bags", "from anywhere, on the right bar")
check(erow("bar").value.text == "Bag bar" and erow("slots").alpha == 1 and erow("mono").alpha == 0.45 and erow("CharacterMicroButton").alpha == 0.45, "which swaps the rows over")
erow("slots"):Set(false)
check(CharacterBag0Slot.parent == hidden and MainMenuBarBackpackButton.parent == Bags.tray, "backpack only")
erow("slots"):Set(true)
erow("keyring"):Set(false)
check(KeyRingButton.parent == hidden, "no key ring")
erow("keyring"):Set(true)
erow("reagent"):Set(false)
check(CharacterReagentBag0Slot.parent == hidden, "no reagent bag")
erow("reagent"):Set(true)
erow("stack"):Set(false)
check(MainMenuBarBackpackButton.countShown == false and MainMenuBarBackpackButton.FreeSlots.alpha == 0, "no free slot count")
erow("stack"):Set(true)
check(MainMenuBarBackpackButton.countShown == true, "and back")
erow("stackSize"):Set(15)
check(MainMenuBarBackpackButton.FreeSlots.font[2] == 15, "its size")
erow("on"):Set(false)
check(not Bags.shown and not Bags.mover.shown, "the bag bar can go")
erow("on"):Set(true)
check(Bags.shown and Bags.mover.shown, "and come back")
E.reset.scripts.OnClick(E.reset)
E.reset.scripts.OnClick(E.reset)
check(VoltUIDB.barCfg.bags.stackSize == 11 and VoltUIDB.barCfg.bags.on, "reset this bar")
E:Select("extras")
E.extraKey = "menu"
E.reset.scripts.OnClick(E.reset)
E.reset.scripts.OnClick(E.reset)
check(VoltUIDB.barCfg.menu.size == 24 and next(VoltUIDB.barCfg.menu.hide or {}) == nil, "reset the menu")
E:Select("bars")
-- blocked in combat, closes in combat
inCombat = true
local was = VoltUIDB.barCfg.bar1.size
row("size"):Set(20)
check(VoltUIDB.barCfg.bar1.size == was, "no changes in combat")
inCombat = false
U.unlocked = nil -- as if the unit frames were switched off, so only this module can close it
fire("PLAYER_REGEN_DISABLED")
check(not ns.FUI.unlocked and not Bar1.mover.shown, "combat stops moving frames")
check(stateDrivers[Bar1].visibility, "and bars go back to their state drivers")
AB:Slash("reset")
check(not AB.applyPending and VoltUIDB.barCfg.bar1.size == 36 and VoltUIDB.barSeeded, "/volt bars reset")
check(Bar1.w == 465, "and applies it")

-- /volt bars debug, and turning the whole thing off
local before = #chat
AB:Slash("debug")
check(#chat > before and table.concat(chat, "\n", before + 1):find("Bar 1: on, slot 1, showing", 1, true), "debug lists the bars")
check(table.concat(chat, "\n", before + 1):find("Bar 8: not on this client", 1, true), "and says what's missing")
SlashCmdList.VOLTUI("bars off")
check(VoltUIDB.bars == false, "/volt bars off")
AB.enabled = false
SlashCmdList.VOLTUI("bars")
check(chat[#chat]:find("/volt bars on", 1, true), "a hint while it's off")
AB.enabled = true
SlashCmdList.VOLTUI("bars on")
check(VoltUIDB.bars == true, "/volt bars on")

-- The font follows VoltUI's setting; the settings window doesn't.
local fontWas = VoltUIDB.font
VoltUIDB.font = "chakra"
ns.Style.ApplyFonts()
ns.FUI:Refresh()
check(b.kKey.font[1]:find("ChakraPetch") and b.Count.font[1]:find("ChakraPetch"), "button text follows the font")
check(VoltUICooldownFontbar1.font[1]:find("ChakraPetch"), "cooldown numbers too")
local typedBox
for _, r in ipairs(E.pages.bars.rows) do
  if r.def.key == "size" then typedBox = r.value end
end
check(typedBox.font[1]:find("JetBrainsMono%-") and not typedBox.font[1]:find("ChakraPetch"), "the boxes you type in stay in the settings font")
VoltUIDB.font = fontWas
ns.Style.ApplyFonts()
ns.FUI:Refresh()

-- The menu buttons
local Menu, BagBar = VoltUIMenubar, VoltUIBagbar
check(Menu and BagBar, "menu and bag bars are made")
check(MicroMenuContainer.parent == hidden and BagsBar.parent == hidden, "the game's holders are put away")
local cm = CharacterMicroButton
check(cm.parent == Menu.tray and StoreMicroButton.parent == Menu.tray, "the buttons move onto ours")
check(HelpMicroButton.parent == hidden, "help stays hidden while the shop is there")
check(cm.Background.parent == hidden and cm.PushedBackground.parent == hidden, "the game's button art goes")
check(cm.Shadow.parent == hidden and cm.PushedShadow.parent == hidden and cm.Portrait.maskRemoved == cm.PortraitMask, "and the portrait goes square")
check(cm.Portrait.points[1][1] == "TOPLEFT" and cm.Portrait.points[1][2] == 2, "filling the button")
check(cm.FlashBorder.ctex and cm.FlashBorder.ctex[4] == 0.35, "alerts go flat too")
check(MainMenuMicroButton.MainMenuBarPerformanceBar.h == 2, "the latency bar becomes a thin line")
check(Menu.w == 5 * 24 + 4 * 2 and Menu.h == 24, "a flat row of the buttons wanted")
check(Menu.points[1][1] == "BOTTOMRIGHT", "bottom right by default")
-- The game shows the shop every time it updates. A removed one has to stay away.
AB:Cfg("menu").hide = { StoreMicroButton = true }
AB:Changed("menu")
StoreMicroButton:Show()
check(StoreMicroButton.parent == hidden, "a removed button stays gone when the game shows it")
AB:Cfg("menu").hide = nil
AB:Changed("menu")
-- Game rules can take buttons away
microRules.ej = true
local listed = {}
for _, it in ipairs(AB:MenuList()) do listed[it.key] = it.name end
check(listed.EJMicroButton == nil and listed.CharacterMicroButton == "Character", "the rows follow the game's rules")
microRules.ej = nil
-- The art comes back whenever a button changes state
QuestLogMicroButton:SetPushed()
check(QuestLogMicroButton.state == "pushed" and QuestLogMicroButton.kBack.ctex[1] == ns.Style.UI.block[1] and QuestLogMicroButton.kLine.shown, "an open window shows on its button: a gold block and line")
check(#QuestLogMicroButton.normalArt.points == 1 and QuestLogMicroButton.normalArt.points[1][1] == "CENTER", "the art stays centred")
QuestLogMicroButton:SetNormal()
check(QuestLogMicroButton.kBack.ctex[4] == 0.9 and not QuestLogMicroButton.kLine.shown and QuestLogMicroButton.normalArt.points[1][1] == "CENTER", "and closes")
cm.scripts.OnEnter(cm)
check(cm.kEdges[1].ctex[1] == ns.Style.ACCENT[1], "hover lights the border")
-- 1.92.0: plates behind bars, and the raised menu and bag buttons
do
  local UI = ns.Style.UI
  local menuBar, bagBar, bar1 = AB.frames.menu, AB.frames.bags, AB.frames.bar1
  check(AB:DefaultFor("menu", "plate") == true and AB:DefaultFor("bags", "plate") == true, "the menu and bag bars start with a plate")
  check(AB:DefaultFor("bar1", "plate") == false and AB:DefaultFor("bar1", "platePad") == 5, "action bars start without one")
  AB:Cfg("menu").plate, AB:Cfg("menu").plateAlpha, AB:Cfg("menu").platePad = true, 0.55, 5
  AB:Changed("menu")
  local p = menuBar.plate
  check(p and p.shown and p.parent == menuBar, "a plate is VoltUI's own frame under the bar")
  check(p.back.ctex[1] == UI.bg[1] and p.back.ctex[4] == 0.55, "glass: the page grey at about half strength")
  check(p.points[1][1] == "TOPLEFT" and p.points[1][4] == -5 and p.points[1][5] == 5, "it reaches past the buttons by its padding")
  check(p.edges[1].ctex[1] == UI.edge[1], "with a thin edge")
  AB:Cfg("menu").platePad, AB:Cfg("menu").plateAlpha = 8, 1
  AB:Changed("menu")
  check(p.points[2][4] == 8 and p.points[2][5] == -8 and p.back.ctex[4] == 1, "padding and strength follow the settings")
  AB:Cfg("menu").plate = false
  AB:Changed("menu")
  check(not p.shown, "and it goes when switched off")
  AB:Cfg("menu").plate, AB:Cfg("menu").platePad, AB:Cfg("menu").plateAlpha = true, 5, 0.55
  AB:Changed("menu")
  check(p.shown, "and comes back")
  if bar1 then
    local had = AB:Cfg("bar1").plate
    AB:Cfg("bar1").plate = true
    AB:Changed("bar1")
    check(bar1.plate and bar1.plate.shown, "any action bar can have one")
    check(bar1.plate.level == nil or bar1.plate.level <= (bar1.buttons[1].level or bar1.plate.level), "under its buttons")
    AB:Cfg("bar1").plate = had
    AB:Changed("bar1")
    check(not bar1.plate.shown, "one bar at a time")
  end
  local xp = AB.frames.xp
  if xp then
    AB:Cfg("xp").plate = true
    AB:Changed("xp")
    check(xp.plate == nil, "the XP bar has its own background, so no plate")
    AB:Cfg("xp").plate = false
  end
  check(CharacterMicroButton.kBack.ctex[1] == UI.raised[1] and CharacterMicroButton.kBack.ctex[4] == 0.9, "menu buttons are raised grey squares")
  check(CharacterMicroButton.kLine and not CharacterMicroButton.kLine.shown, "with no gold line while closed")
  if bagBar then
    local bb = MainMenuBarBackpackButton
    check(bb.kBack.ctex[1] == UI.raised[1], "and so are the bag buttons")
  end
end
cm.scripts.OnLeave(cm)
check(cm.kEdges[1].ctex[1] == ns.Style.SOFT[1], "and lets go")
-- The vehicle bar borrows the buttons, even in combat
inCombat = true
MicroMenu:SetParent(OverrideActionBar)
check(Menu.borrowed and cm.parent == MicroMenu and cm.w == 32 and cm.h == 40, "the vehicle bar can take them")
AB:Changed("menu")
check(cm.parent == MicroMenu, "nothing takes them back early")
MicroMenu:SetParent(MicroMenuContainer)
check(not Menu.borrowed and cm.parent == Menu.tray and cm.w == 24, "and they come back, in combat too")
inCombat = false
MicroMenu:SetParent(new("Frame"))
check(Menu.borrowed, "a pet battle borrows them")
AB:Changed("menu")
check(cm.parent == MicroMenu, "and a change to the bar's settings leaves them there")
fire("PET_BATTLE_CLOSE")
check(not Menu.borrowed and cm.parent == Menu.tray, "and the end of one hands them back")
MicroMenu.parent = MicroMenuContainer
HelpOpenWebTicketButton.points = {}
MicroMenu:UpdateHelpTicketButtonAnchor()
check(HelpOpenWebTicketButton.points[1][2] == cm, "the help ticket button still has somewhere to sit")

-- The bag buttons
local bp, ring = MainMenuBarBackpackButton, KeyRingButton
check(bp.parent == BagBar.tray and CharacterBag3Slot.parent == BagBar.tray and ring.parent == BagBar.tray, "the bag buttons move onto ours")
check(BagBar.w == 7 * 30 + 6 * 3 and BagBar.h == 30, "seven in a row")
check(ring.points[1][4] == 0 and CharacterReagentBag0Slot.points[1][4] == 33 and bp.points[1][4] == 33 * 6, "key ring first, backpack last")
check(bp.art.alpha == 0 and bp.IconBorder.parent == hidden and bp.icon.maskRemoved == bp.SquareMask, "the game's art goes, with its mask")
check(bp.art.parent ~= hidden and bp:GetNormalTexture() == bp.art, "but stays on the button, where the game looks for it")
check(bp.icon.points[1][2] == 1, "the icon sits inside the border")
check(ring.icon.tex and ring.icon.tex:find("keyring"), "the key ring gets a square icon")
check(bp.FreeSlots.parent == bp.kText or bp.FreeSlots.points[1][1] == "BOTTOM", "free slots along the bottom")
-- The game redraws these whenever a bag changes
local hi = bp:GetHighlightTexture()
bp:UpdateTextures()
check(hi.ctex and hi.ctex[4] == 0.16 and bp:GetPushedTexture().ctex[4] == 0.4, "bag art stays flat after the game redraws it")
check(bp.art.atlas == "game" and bp.art.alpha == 0, "and the game's own redraw of it stays out of sight")
bp.art.alpha = 1
bp:UpdateTextures()
check(bp.art.alpha == 0, "even if something shows it again")
for _, n in ipairs({ "KeyRingButton", "CharacterReagentBag0Slot", "CharacterBag3Slot", "CharacterBag2Slot", "CharacterBag1Slot", "CharacterBag0Slot" }) do
  _G[n]:UpdateTextures() -- must not error on any of them
  check(_G[n].art.alpha == 0, n .. " survives a bag change")
end
check(bp.SlotHighlightTexture.ctex[4] == 0.3, "an open bag shows")
-- ...and lays them out when you pick up an item
check(unregistered["MainMenuBarManager.OnExpandChanged"] == BagsBar, "picking up an item doesn't lay them out")
bp:SetPoint("RIGHT", BagsBar, "RIGHT")
inCombat = true
BagsBar:Layout()
check(bp.points[1][2] == BagBar.tray and #bp.points == 1, "and when something else does, they go straight back, in combat too")
inCombat = false
-- Keys that aren't on this account
C_ActionBar.ShouldShowKeyring = function() return false end
AB:Changed("bags")
check(ring.parent == hidden and BagBar.w == 6 * 30 + 5 * 3, "no key ring on an account without one")
C_ActionBar.ShouldShowKeyring = function() return true end
AB:Changed("bags")
-- Nothing here is secure, so these can happen in combat: buttons don't need Apply.
check(BagBar.tray.parent == BagBar and Menu.tray.parent == Menu, "plain frames carry the buttons")
check(not stateDrivers[Menu.tray], "with no driver of their own")
-- Same visibility as any bar
AB:Cfg("menu").mode = "combat"
AB:Changed("menu")
check(stateDrivers[Menu].visibility:find("[combat]show;hide", 1, true), "the menu can show only in combat")
AB:ResetBar("menu")
-- Copying a bar's look leaves these alone
AB:Cfg("bar1").size = 50
AB:CopyLook("bar1")
check(AB:Cfg("menu").size == 24 and AB:Cfg("totem").size == 50, "copy look reaches the totem bar, not menu and bags")
AB:ResetBar("bar1")
AB:ResetBar("totem")
for _, def in ipairs({ "bar2", "bar3", "stance", "pet" }) do AB:ResetBar(def) end
-- A client without them
local realMenu = MicroMenu
MicroMenu = nil
check(#AB:MenuList() == 0, "no menu rows without the menu")
MicroMenu = realMenu
-- A problem with them doesn't take the bars down
local realDressed = AB.ApplyOne
local realFrames = AB.frames.menu
AB.frames.menu = nil
AB.SetupMenu, AB.oldSetup = function() error("boom") end, AB.SetupMenu
local chatBefore = #chat
ok = pcall(AB.ApplyAll, AB)
check(ok and AB.failed and AB.failed.menu, "a failed menu bar doesn't stop the others")
check(table.concat(chat, "\n", chatBefore + 1):find("Menu bar left as the game has it", 1, true), "and says so")
local holder = MicroMenuContainer.parent
MicroMenuContainer.parent = UIParent
AB:HideBlizzard()
check(MicroMenuContainer.parent == UIParent, "and the game's menu stays out")
MicroMenuContainer.parent = holder
AB.SetupMenu, AB.oldSetup = AB.oldSetup, nil
AB.failed = nil
AB.frames.menu = realFrames

-- The XP and reputation bars
check(VoltUIReputationbar == nil and AB:Cfg("rep").on == false and VoltUIDB.barRepOff, "the reputation bar starts off")
AB:Cfg("rep").on = true
AB:ApplyAll()
local XB, RB = VoltUIXPbar, VoltUIReputationbar
local track = StatusTrackingBarManager
check(XB and RB, "the XP and reputation bars are made")
check(track.parent == hidden and not next(track.events), "the game's are put away and go quiet")
check(XB.w == 1192 and XB.h == 12 and XB.points[1][1] == "BOTTOM", "along the bottom by default")
check(XB.kBar.minv == 0 and XB.kBar.maxv == 1000 and XB.kBar.value == 300, "it shows your XP")
check(XB.kRest.maxv == 1000 and XB.kRest.value == 500, "with rested XP past its end")
check(XB.kText.text:find("300 / 1000 (30%)", 1, true) and XB.kText.text:find("Rested 200", 1, true), "and the numbers")
check(XB.kText.alpha == 0, "which wait for the mouse")
check(XB.tray.mouseOn == true, "so it can feel it")
XB.tray.scripts.OnEnter(XB.tray)
check(XB.kText.alpha == 1, "hovering shows them")
XB.tray.scripts.OnLeave(XB.tray)
check(XB.kText.alpha == 0, "and leaving hides them")
xpNow.value, xpNow.rested = 950, 200
inCombat = true
fire("PLAYER_XP_UPDATE")
check(XB.kBar.value == 950, "it follows your XP, even in combat")
inCombat = false
check(XB.kRest.value == 1000, "and rested XP stops at the end of the level")
xpNow.rested = nil
fire("UPDATE_EXHAUSTION")
check(XB.kRest.value == 950 and not XB.kText.text:find("Rested", 1, true), "no rested XP, no rested part")
xpNow.value, xpNow.top, xpNow.rested = 0, 2000, 10
fire("PLAYER_LEVEL_UP")
check(XB.kBar.value == 0 and XB.kBar.maxv == 2000, "a new level starts over")
AB:Cfg("xp").rested = false
AB:Changed("xp")
check(XB.kRest.value == 0, "rested XP can be off")
AB:Cfg("xp").rested = true
xpNow.top = 0
fire("PLAYER_XP_UPDATE")
check(not XB.tray.shown, "numbers it can't use hide it rather than break it")
xpNow.top = 1000
xpNow.show = false
fire("DISABLE_XP_GAIN")
check(not XB.tray.shown, "at top level, or with XP off, it steps aside")
xpNow.show = true
fire("ENABLE_XP_GAIN")
check(XB.tray.shown, "and comes back")
xpNow.value = 77
fire("PLAYER_ENTERING_WORLD")
check(XB.kBar.value == 77, "the numbers are read again on login")
-- Reputation
check(not RB.tray.shown and RB.points[1][1] == "BOTTOM" and RB.points[1][5] == 17, "with no faction watched there's no reputation bar; its spot is just above the XP bar")
watched = { name = "Orgrimmar", factionID = 76, reaction = 5, currentReactionThreshold = 3000, nextReactionThreshold = 9000, currentStanding = 4500 }
inCombat = true
fire("UPDATE_FACTION")
inCombat = false
check(RB.tray.shown and RB.kBar.minv == 3000 and RB.kBar.maxv == 9000 and RB.kBar.value == 4500, "watching a faction shows it, even in combat")
check(RB.kText.text:find("Orgrimmar   Friendly   1500 / 6000 (25%)", 1, true), "with its name, standing and progress")
check(RB.kRest.value == RB.kBar.value, "and no rested part past its end")
RB.kBar:GetStatusBarTexture().SetVertexColor = function(self, r, g, b) self.vc = { r, g, b } end
fire("UPDATE_FACTION")
check(RB.kBar:GetStatusBarTexture().vc[2] == 0.6, "in the colour of your standing")
watched.nextReactionThreshold = 3000
fire("UPDATE_FACTION")
check(RB.kBar.value == 1 and RB.kBar.maxv == 1, "the top of the scale is a full bar")
check(not RB.kText.text:find("/", 1, true), "with nothing to count")
watched.factionID = 0
fire("UPDATE_FACTION")
check(not RB.tray.shown, "unwatching hides it")
watched = nil
fire("UPDATE_FACTION")
check(not RB.tray.shown, "and so does nothing at all")
-- Placing them
ns.FUI:SetUnlocked(true)
check(RB.tray.shown and RB.kText.text == "Reputation bar" and RB.mover.shown, "an empty bar still shows while you place it")
check(XB.kText.alpha == 1 and XB.tray.mouseOn == false, "numbers on, and the mouse left for the overlay")
XB.mover.scripts.OnMouseUp(XB.mover)
check(E.tab == "extras" and E.extraKey == "xp", "clicking it opens its settings")
local function srow(key)
  for _, r in ipairs(E.pages.extras.rows) do
    if r.def.key == key then return r end
  end
end
check(srow("bar").value.text == "XP bar", "named at the top")
check(srow("width").alpha == 1 and srow("rested").alpha == 1 and srow("size").alpha == 0.45 and srow("perRow").alpha == 0.45, "the rows that matter are awake")
srow("width"):Set(800)
srow("height"):Set(20)
check(XB.w == 800 and XB.h == 20, "width and height work")
srow("textSize"):Set(14)
check(XB.kText.font[2] == 14, "number size too")
srow("text"):Set("always")
ns.FUI:SetUnlocked(false)
check(XB.kText.alpha == 1 and XB.tray.mouseOn == false, "numbers always on, clicks pass through")
ns.FUI:SetUnlocked(true)
E:Select("extras")
srow("text"):Set("off")
ns.FUI:SetUnlocked(false)
check(XB.kText.alpha == 0 and XB.tray.mouseOn == false, "or off")
XB.kHover = true
AB:UpdateStatus(XB)
check(XB.kText.alpha == 0, "even over it")
XB.kHover = nil
ns.FUI:SetUnlocked(true)
E:Select("extras")
srow("border"):Set(false)
check(not XB.kEdges[1].shown and XB.kBar.points[1][4] == 0, "no border, and the bar fills the space")
srow("border"):Set(true)
check(XB.kEdges[1].shown and XB.kBar.points[1][4] == 1, "with a border, it sits inside")
E.extraKey = "rep"
E:RefreshPage()
check(srow("rested").alpha == 0.45 and srow("width").alpha == 1, "reputation has no rested XP")
E.extraKey = "xp"
E:RefreshPage()
srow("on"):Set(false)
check(not XB.shown, "it can be turned off")
srow("on"):Set(true)
check(XB.shown, "and on")
E.reset.scripts.OnClick(E.reset)
E.reset.scripts.OnClick(E.reset)
check(AB:Cfg("xp").width == 1192 and AB:Cfg("xp").text == "hover" and XB.w == 1192, "reset works")
ns.FUI:SetUnlocked(false)
-- Same visibility as any bar
AB:Cfg("xp").mode = "peace"
AB:Changed("xp")
check(stateDrivers[XB].visibility:find("[nocombat]show;hide", 1, true), "it can hide in combat")
AB:ResetBar("xp")
AB:Cfg("bar1").size = 50
AB:CopyLook("bar1")
check(AB:Cfg("xp").size == 36 and AB:Cfg("rep").width == 400, "copy look leaves them alone")
AB:ResetBar("bar1")
for _, k in ipairs({ "bar2", "bar3", "stance", "pet", "totem" }) do AB:ResetBar(k) end
-- If they fail, the game's stays
local realSetup = AB.SetupStatus
local xpFrame, repFrame = AB.frames.xp, AB.frames.rep
AB.frames.xp, AB.frames.rep = nil, nil
AB.SetupStatus = function() error("boom") end
AB:ApplyAll()
check(AB.failed.xp and AB.failed.rep, "a failed XP bar is noted")
track.parent = UIParent
AB:HideBlizzard()
check(track.parent == UIParent, "and the game's stays up")
AB.SetupStatus = realSetup
AB.failed = nil
AB.frames.xp, AB.frames.rep = xpFrame, repFrame
track.parent = hidden

-- Quick keybinds
check(VoltUIBar1Button1.commandName == "ACTIONBUTTON1" and VoltUIBar2Button3.commandName == "MULTIACTIONBAR1BUTTON3", "the game's mode can see our action buttons")
check(VoltUIBar3Button1.commandName == "MULTIACTIONBAR2BUTTON1", "on the right bars")
check(PetActionButton1.commandName == "BONUSACTIONBUTTON1" and MultiCastActionButton2.commandName == "MULTICASTACTIONBUTTON2", "pet and totem buttons too")
local qk, kb = QuickKeybindFrame, VoltUIBar1Button1
for _, btn in ipairs({ kb, cm, bp }) do btn.QuickKeybindHighlightTexture = btn:CreateTexture() end
bp.commandName, cm.commandName = "TOGGLEBACKPACK", "TOGGLECHARACTER0"
local glow = kb.QuickKeybindHighlightTexture
glow.shown = false
AB:Cfg("bar1").empty = false
AB:Cfg("bar2").mode = "combat"
AB:Changed("bar1")
AB:Changed("bar2")
check(VoltUIBar1Button5.alpha == 0 and stateDrivers[VoltUIBar2].visibility, "an empty slot and a combat-only bar, before")
SettingsPanel.shown = false
ns.FUI:SetUnlocked(true)
chat[#chat + 1] = ""
inCombat = true
AB:QuickKeys()
check(not qk.shown and chat[#chat]:find("in combat", 1, true), "it won't open in combat")
inCombat = false
AB:QuickKeys()
check(qk.shown and not ns.FUI.unlocked and not VoltUISettings.shown, "it opens the game's mode, closing the edit mode")
check(AB.quick and AB.quickOpened == "edit", "and remembers where it came from")
check(glow.shown and glow.ctex[1] == ns.Style.ACCENT[1], "our buttons light up, flat")
check(cm.QuickKeybindHighlightTexture.shown and bp.QuickKeybindHighlightTexture.shown, "menu and bag buttons too")
check(VoltUIBar1Button5.alpha == 1, "empty slots show, to be bound")
check(not stateDrivers[VoltUIBar2].visibility and VoltUIBar2.shown, "and every bar stays up")
check(not VoltUIBar2.mover.shown, "with no overlays in the way")
AB:Cfg("bar3").mode = "hover"
AB:Cfg("bar3").fadeTo = 0
AB:Changed("bar3")
AB.ev.scripts.OnUpdate(AB.ev, 10)
check(VoltUIBar3.alpha == 1, "and a faded bar wakes")
AB:ResetBar("bar3")
-- A new key shows at once
barKeys.ACTIONBUTTON1 = { "ALT-3" }
fire("UPDATE_BINDINGS")
check(kb.kKey.text == "A3" and boundKeys["ALT-3"] and boundKeys["ALT-3"].name == "VoltUIBar1Button1Key", "a new key shows and works straight away")
qk:Hide()
check(not AB.quick and not glow.shown, "closing it puts the lights out")
check(not SettingsPanel.shown, "the game's settings don't pop up")
check(ns.FUI.unlocked, "and it's back in the edit mode")
ns.FUI:SetUnlocked(false)
check(VoltUIBar1Button5.alpha == 0 and stateDrivers[VoltUIBar2].visibility, "and the bars go back to how you set them")
AB:QuickKeys()
qk:Hide()
check(not ns.FUI.unlocked, "opened from the world, it goes back to the world")
SlashCmdList.VOLTUI("keys")
check(qk.shown, "/volt keys")
-- Combat closes it
fire("PLAYER_REGEN_DISABLED")
check(qk.cancelled and not qk.shown and not AB.quick and chat[#chat]:find("in combat", 1, true), "entering combat closes it")
qk.cancelled = nil
-- Opened from the game's own settings, the game's way of closing stands
SettingsPanel.shown = false
qk:Show()
check(AB.quick and glow.shown and not AB.quickOpened, "opened from the game's settings, ours still light up")
qk:Hide()
check(SettingsPanel.shown, "and its settings come back")
SettingsPanel.shown = false
local realQk = QuickKeybindFrame
QuickKeybindFrame = nil
AB:QuickKeys()
check(chat[#chat]:find("aren't on this client", 1, true), "a client without it says so")
QuickKeybindFrame = realQk
AB:Cfg("bar1").empty = true
AB:Cfg("bar2").mode = "always"
AB:Changed("bar1")
AB:Changed("bar2")

-- If VoltUI's bars can't be built, the game's stay.
local mb = MultiBar6
local oldParent = new("Frame")
mb.parent = oldParent
local realApply, realEv = AB.ApplyAll, AB.ev
AB.ApplyAll = function() error("boom") end
ok = pcall(AB.Start, AB)
check(not ok and mb.parent == oldParent, "a failure leaves the game's bars in place")
AB.ApplyAll, AB.ev = realApply, realEv
end)()

-- A /reload in combat waits, because secure frames can't be made then.
U.started = nil
inCombat = true
U:Enable()
check(not U.started, "in combat: waits")
inCombat = false
fire("PLAYER_REGEN_ENABLED")
check(U.started, "starts when combat ends")

;(function() -- A /reload in combat, and a failed start: neither may leave you guessing.
  local function said(text)
    for _, m in ipairs(chat) do if m:find(text, 1, true) then return true end end
    return false
  end
  local AB = ns.ActionBars
  local realStart, starts = AB.Start, 0
  AB.Start = function() starts = starts + 1 end
  inCombat = true
  AB:Enable()
  check(starts == 0 and AB.waiting, "in combat: the bars wait")
  check(said("come back when the fight ends"), "and say so")
  wipe(chat)
  SlashCmdList.VOLTUI("bars debug")
  check(said("Started: waiting for combat to end"), "debug shows it")
  inCombat = false
  fire("PLAYER_REGEN_ENABLED")
  check(starts == 1 and not AB.waiting, "the fight ends: they start")
  AB.Start = realStart
  wipe(chat)
  SlashCmdList.VOLTUI("bars debug")
  check(said("Started: yes"), "debug shows that too")

  -- Saved with where it happened, since chat is gone after a /reload.
  local boom = { key = "boomtest", name = "Boom", Enable = function() error("it broke") end }
  local realModules = ns.FUI.modules
  ns.FUI.modules = { boom }
  VoltUIDB.startErrors = { old = "from last time" }
  wipe(chat)
  fire("PLAYER_LOGIN")
  ns.FUI.modules = realModules
  check(said("Boom couldn't start") and said("it broke"), "a failed start says why in chat")
  check(VoltUIDB.startErrors.old == nil and VoltUIDB.startErrors.boomtest:find("it broke", 1, true), "and it's saved, replacing last session's")
  VoltUIDB.startErrors = { bars = "bad thing\nstack here" }
  wipe(chat)
  SlashCmdList.VOLTUI("bars debug")
  check(said("Started: no: bad thing") and not said("stack here"), "debug shows the error's first line")
  VoltUIDB.startErrors = nil
end)()
;(function() -- After everything above: did VoltUI ever touch what the game's own button code reads?
  local touched, count = {}, 0
  for _, prefix in ipairs({ "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarRightButton", "MultiBarLeftButton", "MultiBar5Button", "MultiBar6Button" }) do
    for i = 1, 12 do
      local b = _G[prefix .. i]
      count = count + 1
      if b.handled ~= 0 then touched[#touched + 1] = b:GetName() .. " handler ran x" .. b.handled end
      if b.index ~= i then touched[#touched + 1] = b:GetName() .. " index" end
      if b.commandName:match("%d+$") ~= tostring(i) then touched[#touched + 1] = b:GetName() .. " command" end
    end
  end
  check(count == 84 and #touched == 0, "none of the game's buttons had a handler run or a field changed by VoltUI: " .. table.concat(touched, ", "))
  check(PetActionButton1.index == nil and PetActionButton1.kIndex == 1, "nor the index on the pet buttons")
  local b = VoltUIBar4Button1
  check(b.flyoutUpdates == nil and b.attrs.flyoutDirection, "flyouts: the direction is left for the game to read")
end)()

;(function() -- World map: zone levels and the window's look
  local W = ns.WorldMap
  check(W and W.enabled, "world map part starts")
  -- A continent with three zones and a city, as the game's hover test would see them.
  -- Westfall is an L, so the middle of its box lands on Duskwood.
  local function under(x, y)
    if x > 0.45 and x < 0.55 and y > 0.05 and y < 0.15 then return 1453 end -- Stormwind, on Elwynn
    if y < 0.5 then return x < 0.6 and 1429 or nil end
    if x < 0.2 or y > 0.85 then return 1436 end
    if x < 0.7 then return 1431 end
    return 2548 -- a Forever zone nobody has levels for
  end
  local infos = {
    [1415] = { mapID = 1415, mapType = 2, parentMapID = 947, name = "Eastern Kingdoms" },
    [1429] = { mapID = 1429, mapType = 3, parentMapID = 1415, name = "Elwynn Forest" },
    [1431] = { mapID = 1431, mapType = 3, parentMapID = 1415, name = "Duskwood" },
    [1436] = { mapID = 1436, mapType = 3, parentMapID = 1415, name = "Westfall" },
    [2548] = { mapID = 2548, mapType = 3, parentMapID = 1415, name = "Riverglades" },
    [1453] = { mapID = 1453, mapType = 3, parentMapID = 1415, name = "Stormwind City" },
    [9001] = { mapID = 9001, mapType = 5, parentMapID = 1431, name = "A cave in Duskwood" },
  }
  local samples, gameLevels = 0, { [1431] = { 22, 31 }, [1436] = { 1, 60 } }
  C_Map.GetMapInfo = function(id) return infos[id] end
  C_Map.GetMapLevels = function(id) local l = gameLevels[id]; if l then return l[1], l[2], 0, 0 end; return 0, 0, 0, 0 end
  C_Map.GetMapChildrenInfo = function()
    return { infos[1429], infos[1431], infos[1436], infos[2548], infos[1453] }
  end
  C_Map.GetMapRectOnMap = function(id)
    if id == 1436 then return 0, 0.7, 0.5, 1 end
    return 0, 0, 0, 0
  end
  C_Map.GetMapInfoAtPosition = function(_, x, y)
    samples = samples + 1
    local id = under(x, y)
    if id == 1431 and x > 0.3 and x < 0.32 then id = 9001 end -- something inside the zone
    return id and infos[id] or infos[1415]
  end
  function GetQuestDifficultyColor(l) return { r = l, g = 0, b = 0 } end
  QuestDifficultyColors = { difficult = { r = 1, g = 1, b = 0 } }
  local playerLevel = 25
  UnitLevel = function() return playerLevel end
  function Mock:GetStringWidth() return #(self.text or "") * 6 end
  function Mock:SetScale(s) self.scale = s end
  function Mock:GetObjectType() return self.kind end

  -- Where the labels come from
  local lo, hi, from = W.Levels(1429)
  check(lo == 1 and hi == 10 and from == "Classic", "a zone the game gives no levels for uses Classic's")
  lo, hi, from = W.Levels(1431)
  check(lo == 22 and hi == 31 and from == "game", "the game's own levels come first")
  lo, hi, from = W.Levels(1436)
  check(lo == 10 and hi == 20 and from == "Classic", "a scaled 1-60 range isn't believed: " .. lo .. "-" .. hi)
  lo, hi, from = W.Levels(2482)
  check(lo == 55 and hi == 60 and from == "Forever creatures", "Mount Hyjal, new in Forever, has VoltUI's own range")
  check(W.FOREVER_LEVELS[2548] and W.FOREVER_LEVELS[2652] and W.FOREVER_LEVELS[2521], "so do Riverglades, Shen'dralas and Zephras Isle")
  -- From here on Riverglades stands in for a zone nobody has levels for.
  local keepRiver = W.FOREVER_LEVELS[2548]
  W.FOREVER_LEVELS[2548] = nil
  check(W.Levels(2548) == nil, "a zone nobody has levels for has none")
  check(next(W.ZONE_LEVELS) and W.ZONE_LEVELS[1453] == nil, "cities aren't given levels")

  -- The game's window, as far as the skin touches it
  local function art(b)
    local n, p, d, h = b:CreateTexture(), b:CreateTexture(), b:CreateTexture(), b:CreateTexture()
    b.GetNormalTexture = function() return n end
    b.GetPushedTexture = function() return p end
    b.GetDisabledTexture = function() return d end
    b.GetHighlightTexture = function() return h end
    return n, p, d, h
  end
  local canvas2 = new("Frame")
  canvas2.w, canvas2.h = 1000, 667
  local map = new("Frame")
  map.w, map.h = 1000, 700
  map.ScrollContainer = new("Frame")
  map.ScrollContainer.w = 1000
  map.TitleCanvasSpacerFrame = new("Frame")
  map.OverscrollBG = new("Frame")
  local cscale = 1
  function map:GetCanvas() return canvas2 end
  local shownMap = 1415
  function map:GetMapID() return shownMap end
  function map:GetCanvasScale() return cscale end
  function map:OnMapChanged() end
  function map:OnCanvasScaleChanged() end
  function map:Minimize() self.NavBar:SetPoint("TOPLEFT", self.TitleCanvasSpacerFrame, "TOPLEFT", 64, -25) end
  function map:Maximize() self.NavBar:SetPoint("TOPLEFT", self.TitleCanvasSpacerFrame, "TOPLEFT", 8, -25) end
  function map:IsMaximized() return self.big == true end
  function map:SetMovable(v) self.movable = v end
  function map:SetClampedToScreen(v) self.clamped = v end
  function map:SetUserPlaced(v) self.userPlaced = v end
  function map:StartMoving() self.dragging = true; self.userPlaced = true end
  function map:StopMovingOrSizing() self.dragging = false end
  function map:GetLeft() return self.atLeft end
  function map:GetTop() return self.atTop end
  local border = new("Frame")
  map.BorderFrame = border
  for _, k in ipairs({ "NineSlice", "PortraitContainer", "Bg", "TopTileStreaks", "InsetBorderTop", "Tutorial", "TitleContainer" }) do border[k] = new("Frame") end
  border.TitleContainer.TitleText = border.TitleContainer:CreateFontString()
  border.CloseButton = new("Button")
  local closeNormal = art(border.CloseButton)
  border.MaximizeMinimizeFrame = new("Frame")
  border.MaximizeMinimizeFrame.MaximizeButton = new("Button")
  border.MaximizeMinimizeFrame.MinimizeButton = new("Button")
  art(border.MaximizeMinimizeFrame.MaximizeButton)
  art(border.MaximizeMinimizeFrame.MinimizeButton)
  local nav = new("Frame")
  map.NavBar = nav
  nav.overlay = new("Frame")
  local navArt = nav:CreateTexture()
  local function navButton()
    local b = new("Button")
    local n = art(b)
    b.text = b:CreateFontString()
    b.arrowUp, b.arrowDown, b.selected = b:CreateTexture(), b:CreateTexture(), b:CreateTexture()
    b.xoffset = -15
    b.MenuArrowButton = new("Button")
    b.MenuArrowButton.NormalTexture, b.MenuArrowButton.PushedTexture = new("Texture"), new("Texture")
    return b, n
  end
  local home, homeNormal = navButton()
  nav.homeButton, nav.overflowButton, nav.navList = home, navButton(), { home }
  local late, lateNormal = navButton()
  function NavBar_AddButton(bar, b) bar.navList[#bar.navList + 1] = b end
  QuestMapFrame = new("Frame")
  QuestMapFrame.VerticalSeparator = new("Texture")
  QuestMapFrame.QuestsFrame = new("Frame")
  local list = new("Frame")
  QuestMapFrame.QuestsFrame.ScrollFrame = list
  list.Background, list.BorderFrame, list.Edge = new("Texture"), new("Frame"), new("Texture")
  local details = new("Frame")
  QuestMapFrame.QuestsFrame.DetailsFrame = details
  details.Bg, details.BorderFrame = new("Texture"), new("Frame")

  local oldMap = WorldMapFrame
  WorldMapFrame = map
  W.ready, W.labels, W.spots, W.used, W.overlay, W.tag = nil, {}, {}, 0, nil, nil
  W:Setup()

  -- The look
  local B = border
  check(B.NineSlice.alpha == 0 and B.PortraitContainer.alpha == 0 and B.Bg.alpha == 0 and map.OverscrollBG.alpha == 0, "the game's border, portrait and backgrounds are faded")
  check(B.NineSlice.shown and B.PortraitContainer.shown, "and left in place, not hidden")
  check(map.fuiPanel and map.fuiPanel.fill.ctex[4] >= 0.92, "the window gets the flat panel, nearly solid")
  check(closeNormal.alpha == 0 and border.CloseButton:GetNormalTexture() == closeNormal, "close button art faded, and the game can still find it")
  check(navArt.alpha == 0 and nav.overlay.alpha == 0, "nav bar art faded")
  check(homeNormal.alpha == 0 and home.selected.alpha == 0, "home button flat")
  check(home.xoffset == -15 and home.selected ~= nil and nav.homeButton == home, "the fields the game reads on its nav buttons are untouched")
  NavBar_AddButton(nav, late)
  check(lateNormal.alpha == 0 and late.arrowUp.alpha == 0, "a nav button the game makes later gets the look too")
  check(list.Background.alpha == 0 and list.BorderFrame.alpha == 0, "quest list background and frame faded")
  check(details.BorderFrame.alpha == 0 and details.Bg.alpha ~= 0, "the details page keeps its parchment for its dark text")
  map:Minimize()
  local p = nav.points[#nav.points]
  check(p[4] == 8, "the nav bar stays clear of where the portrait was on the small map: " .. tostring(p[4]))

  -- TomTom's coordinates, which it puts at fixed spots on the top edge
  local TT = border.TitleContainer.TitleText
  check(#TT.points == 1 and TT.points[1][1] == "LEFT", "the title is only as wide as its words")
  local keepTom = TomTom
  local tomFrame = new("Frame", "TomTomWorldFrame")
  tomFrame.Player, tomFrame.Cursor = tomFrame:CreateFontString(), tomFrame:CreateFontString()
  local tomCalls = 0
  TomTom = { ShowHideWorldCoords = function()
    tomCalls = tomCalls + 1
    tomFrame.Player:ClearAllPoints(); tomFrame.Cursor:ClearAllPoints()
    tomFrame.Player:SetPoint("TOPLEFT", map, "TOPLEFT", 100, -6)
    tomFrame.Cursor:SetPoint("TOPLEFT", map, "TOPRIGHT", -170, -6)
  end }
  TomTom.ShowHideWorldCoords()
  W:FitTomTom() -- the map does this each time it draws
  local pp, cp = tomFrame.Player.points, tomFrame.Cursor.points
  check(#pp == 1 and pp[1][1] == "LEFT" and pp[1][2] == TT and pp[1][3] == "RIGHT", "TomTom's player coordinates go after the title, not on it")
  check(#cp == 1 and cp[1][2] == tomFrame.Player and cp[1][4] == 150, "and its cursor's in a column after them, clear of the levels")
  TomTom.ShowHideWorldCoords()
  check(tomCalls == 2 and tomFrame.Player.points[1][2] == TT and tomFrame.Cursor.points[1][2] == tomFrame.Player, "TomTom puts them back when its settings change: fitted again")
  tomFrame.Player:Hide()
  W:FitTomTom()
  check(tomFrame.Cursor.points[1][2] == TT, "with its player coordinates off, the cursor's go after the title")
  tomFrame.Player:Show()
  TomTom, TomTomWorldFrame = keepTom, nil

  -- The labels
  samples = 0
  map.scripts.OnShow(map)
  local ZONE = { ["Elwynn Forest"] = 1429, ["Duskwood"] = 1431, ["Westfall"] = 1436 }
  local function find(name)
    for i = 1, W.used do if W.labels[i].kZone == ZONE[name] then return W.labels[i] end end
  end
  check(samples == 84 * 56, "a continent's zones are read once: " .. samples)
  check(W.used == 3, "a label per zone with levels, no city or unknown zone: " .. W.used)
  local e, d, wf = find("Elwynn Forest"), find("Duskwood"), find("Westfall")
  check(e and d and wf, "a label for each zone")
  check(e.name == nil and e.level.points[1][1] == "CENTER", "just the level, no zone name, in the middle")
  check(e.level.text == "1-10" and d.level.text == "22-31" and wf.level.text == "10-20", "labels show the level ranges")
  check(under(wf.kX, wf.kY) == 1436, ("Westfall's label is on Westfall, not its box's middle (%.2f, %.2f)"):format(wf.kX, wf.kY))
  check(under(e.kX, e.kY) == 1429, "Elwynn's label misses Stormwind and stays in Elwynn")
  check(under(d.kX, d.kY) == 1431, "a map inside a zone counts as that zone")
  samples = 0
  map:OnMapChanged()
  check(samples == 0, "the second look doesn't read the zones again")

  -- Colours follow the player's level, like the game's hover label
  playerLevel = 25
  W:Draw()
  check(find("Duskwood").level.color[1] == 1 and find("Duskwood").level.color[2] == 1, "in range: yellow")
  check(find("Elwynn Forest").level.color[1] == 8, "below you: the colour of its top level less 2")
  playerLevel = 5
  W:Draw()
  check(find("Duskwood").level.color[1] == 22, "above you: the colour of its first level")
  playerLevel = 25

  -- Size and place on screen
  local a = find("Elwynn Forest")
  W:Draw()
  a = find("Elwynn Forest")
  check(math.abs(a.scale - 1) < 0.001, "full size at scale 1: " .. a.scale)
  local before = a.points[1][4]
  cscale = 2
  map:OnCanvasScaleChanged()
  a = find("Elwynn Forest")
  check(math.abs(a.scale - 0.5) < 0.001, "zooming in shrinks the label against the canvas, so it stays the same on screen")
  check(math.abs(a.points[1][4] - before * 2) < 1, "and it keeps its spot on the zone")
  cscale = 1

  -- Labels that would sit on top of each other are moved apart
  local spots = W.spots[1415]
  local keep = {}
  for id, s in pairs(spots) do keep[id] = s end
  spots[1429], spots[1431] = { x = 0.5, y = 0.5 }, { x = 0.5, y = 0.5 }
  W:Draw()
  local c1, c2 = find("Elwynn Forest"), find("Duskwood")
  check(math.abs(c1.kSY - c2.kSY) >= (c1.kH + c2.kH) / 2 - 0.01, "overlapping labels are pushed apart")
  spots[1429], spots[1431] = keep[1429], keep[1431]

  -- Settings
  local function lastSaid() return chat[#chat] end
  SlashCmdList.VOLTUI("worldmap plates")
  check(not VoltUIDB.mapPlates and W.labels[1].plate.shown == false, "plates can go")
  SlashCmdList.VOLTUI("worldmap plates")
  SlashCmdList.VOLTUI("worldmap size 18")
  check(VoltUIDB.mapLabelSize == 18, "label size")
  SlashCmdList.VOLTUI("worldmap size 99")
  check(VoltUIDB.mapLabelSize == 24, "label size has a limit")
  VoltUIDB.mapLabelSize = 15
  SlashCmdList.VOLTUI("worldmap levels")
  check(not VoltUIDB.mapLevels and W.used == 0 and not W.labels[1].shown, "levels can go, straight away")
  SlashCmdList.VOLTUI("worldmap levels")
  check(W.used == 3 and W.labels[1].shown, "and come back")
  SlashCmdList.VOLTUI("worldmap skin")
  check(VoltUIDB.mapSkin == false and lastSaid():find("reload"), "the look needs a reload")
  VoltUIDB.mapSkin = true
  wipe(chat)
  SlashCmdList.VOLTUI("worldmap debug")
  check(#chat == 6 and chat[2]:find("1429 Elwynn Forest: 1%-10 %(Classic%)"), "debug lists each zone: " .. tostring(chat[2]))
  wipe(chat)

  -- Zone maps and the world map
  gameLevels[1411] = nil
  infos[1411] = { mapID = 1411, mapType = 3, parentMapID = 1414, name = "Durotar" }
  shownMap = 1411
  map:OnMapChanged()
  check(W.used == 0, "no zone labels on a zone's own map")
  check(W.tag.text == "Levels 1-10", "its levels go in the title bar: " .. tostring(W.tag.text))
  infos[947] = { mapID = 947, mapType = 1, parentMapID = 0, name = "Azeroth" }
  shownMap = 947
  map:OnMapChanged()
  check(W.used == 0 and W.tag.text == "", "the world map has neither")
  map:Hide()
  check(W.used == 0, "nothing drawn while shut")
  map:Show()

  -- A level up redraws
  shownMap = 1415
  map:OnMapChanged()
  playerLevel = 40
  fire("PLAYER_LEVEL_UP", 40)
  runTimers()
  check(find("Duskwood").level.color[1] == 29, "levelling up changes the colours")
  playerLevel = 25

  -- ForeverDB's ranges, from a file made on the player's PC
  local CREDIT = "Data from ForeverDB.net (https://foreverdb.net)"
  check(W.creditBar == nil and W.credit.parent == border.TitleContainer, "the credit is in the title bar, not over the map")
  check(W.credit.text == "" or W.credit.text == nil, "no credit without their data")
  local E3 = ns.EditMode
  E3:DrawCredit()
  check(E3.credit.text == "", "no credit in settings without their data")
  ns.Extra.zoneLevels = { credit = CREDIT, levels = { [1429] = { 3, 9 }, [1431] = { 40, 41 }, [1436] = { 7, 8 }, [2548] = { 44, 48 }, [2521] = { 2, 11 } } }
  local keepShort = ns.Extra.shortCredit
  ns.Extra.shortCredit = "Data: ForeverDB.net" -- the short form the data's add-on gives
  lo, hi, from = W.Levels(1429)
  check(lo == 3 and hi == 9 and from == "extra", "another add-on's range beats Classic's")
  lo, hi, from = W.Levels(1431)
  check(lo == 22 and hi == 31 and from == "game", "the game's own still comes first")
  lo, hi, from = W.Levels(1436)
  check(lo == 7 and hi == 8 and from == "extra", "a scaled range from the game falls to the other add-on's")
  lo, hi, from = W.Levels(1411)
  check(lo == 1 and hi == 10 and from == "Classic", "a zone ForeverDB doesn't list keeps Classic's")
  map:OnMapChanged()
  ZONE["Riverglades"] = 2548
  check(W.used == 4 and find("Riverglades") and find("Riverglades").level.text == "44-48", "a new zone gets its label once ForeverDB has its levels")
  W.FOREVER_LEVELS[2548] = keepRiver
  local SHORT = "Data: ForeverDB.net"
  check(W.credit.text == SHORT, "the title bar credits them while their data shows")
  SlashCmdList.VOLTUI("worldmap levels")
  check(W.credit.text == "", "no credit once the labels are off")
  SlashCmdList.VOLTUI("worldmap levels")
  check(W.credit.text == SHORT, "and back with them")
  E3:DrawCredit()
  check(E3.credit.text == "Map levels: " .. CREDIT, "the settings window credits them, with the address")
  local keepZones = ns.Extra.zoneLevels
  ns.Extra.zoneLevels = nil
  E3:DrawCredit()
  check(E3.credit.text == "", "no credit without their data")
  ns.Extra.zoneLevels = keepZones
  E3:DrawCredit()
  wipe(chat)
  SlashCmdList.VOLTUI("worldmap")
  check(chat[#chat] == "|cffffc61aVoltUI|r Map levels: " .. CREDIT, "so does the map's settings list")
  wipe(chat)
  SlashCmdList.VOLTUI("worldmap debug")
  check(chat[#chat] == "|cffffc61aVoltUI|r " .. CREDIT, "debug carries the credit too")
  wipe(chat)
  -- Only the game's and Classic's on show: no credit needed.
  ns.Extra.zoneLevels.levels = { [9999] = { 1, 2 } }
  map:OnMapChanged()
  check(W.credit.text == "", "no credit when none of their data is on this map")
  -- A zone's own map, with its range in the title bar
  ns.Extra.zoneLevels.levels = { [2521] = { 2, 11 } }
  infos[2521] = { mapID = 2521, mapType = 3, parentMapID = 947, name = "Zephras Isle" }
  shownMap = 2521
  map:OnMapChanged()
  check(W.tag.text == "Levels 2-11" and W.credit.text == SHORT, "a zone's own map shows its range and credits it")
  check(W.credit.points[1][2] == W.tag, "beside the range, so they don't overlap")
  shownMap = 947
  map:OnMapChanged()
  check(W.credit.text == "", "and the credit goes when the data does")
  ns.Extra.zoneLevels = nil
  ns.Extra.shortCredit = keepShort
  E3:DrawCredit()
  SlashCmdList.VOLTUI("worldmap")
  check(not chat[#chat]:find("ForeverDB", 1, true), "no credit in the settings list without their data")
  wipe(chat)

  -- Moving the window
  local grip = W.grip
  local function gameAnchors(...)
    map:ClearAllPoints()
    map:SetPoint(...)
  end
  local function dragTo(left, top)
    grip.scripts.OnDragStart(grip)
    map.atLeft, map.atTop = left, top
    grip.scripts.OnDragStop(grip)
  end
  local function at()
    local q = map.points[#map.points]
    return #map.points, q[1], q[3], q[4], q[5]
  end
  -- Whether VoltUI placed it (on the UIParent frame; the game's test anchors name it as a
  -- string), and its left and top if so.
  local function ours()
    local q = map.points[#map.points]
    if q[2] ~= UIParent then return false end
    local l, t = screenTopLeft(map)
    return true, math.floor(l + 0.5), math.floor(t + 0.5)
  end
  check(map.movable and map.clamped, "the window can move and can't leave the screen")
  check(grip.parent == border and grip.h == ns.Style.HEADER_H, "it drags by a strip the height of the title bar")
  check(grip.points[2][4] <= -46, "the strip stays clear of the close and resize buttons")
  check(not map.scripts.OnDragStart, "the map itself still pans, it isn't the drag handle")
  gameAnchors("TOPLEFT", "UIParent", "TOPLEFT", 16, -116)
  local n, point, rel, x = at()
  check(n == 1 and point == "TOPLEFT" and rel == "TOPLEFT" and x == 16, "with nothing saved, the game's spot stands")

  map.atLeft, map.atTop = 412.4, 655.6
  grip.scripts.OnDragStart(grip)
  check(map.dragging, "dragging the strip moves the window")
  gameAnchors("TOPLEFT", "UIParent", "TOPLEFT", 16, -116)
  n, point, rel, x = at()
  check(rel == "TOPLEFT", "a window opening mid-drag doesn't fight the mouse")
  grip.scripts.OnDragStop(grip)
  check(not map.dragging and VoltUIDB.mapPoint and VoltUIDB.mapLeft, "letting go saves the spot: " .. tostring(VoltUIDB.mapPoint) .. " " .. tostring(VoltUIDB.mapLeft) .. ", " .. tostring(VoltUIDB.mapTop))
  check(map.userPlaced == false, "VoltUI keeps the spot, not the game's layout file")
  local mine, l, t = ours()
  check(#map.points == 1 and mine and l == 412 and t == 656, "and the window sits there")
  gameAnchors("TOPLEFT", "UIParent", "TOPLEFT", 16, -116)
  mine, l, t = ours()
  check(#map.points == 1 and mine and l == 412 and t == 656, "the game re-anchoring it, as it does when any panel opens, doesn't move it")

  map.big = true
  gameAnchors("TOP")
  n, point = at()
  check(n == 1 and point == "TOP", "going full size for the first time uses the game's spot, not the small map's")
  dragTo(120, 768)
  check(VoltUIDB.mapBigPoint and VoltUIDB.mapBigLeft and VoltUIDB.mapPoint, "the full-size map remembers its own spot")
  gameAnchors("TOP")
  mine, l, t = ours()
  check(#map.points == 1 and mine and l == 120 and t == 768, "and goes back to it after the game's last anchor")
  map.big = false
  gameAnchors("TOPLEFT", "UIParent", "TOPLEFT", 16, -116)
  mine, l = ours()
  check(mine and l == 412, "the small map goes back to its own")

  grip.scripts.OnDragStart(grip)
  map.atLeft, map.atTop = 500, 600
  grip.scripts.OnHide(grip)
  mine, l = ours()
  local saved = VoltUIDB.mapLeft
  check(not map.dragging and mine and l == 500, "shutting the map mid-drag ends the drag and keeps the spot")
  grip.scripts.OnDragStop(grip)
  check(VoltUIDB.mapLeft == saved, "the late mouse release changes nothing")

  -- In a fight the game blocks moving a protected frame, so it waits.
  local oldCombat = InCombatLockdown
  InCombatLockdown = function() return true end
  gameAnchors("TOPLEFT", "UIParent", "TOPLEFT", 16, -116)
  mine, l = ours()
  check(mine and l == 500, "in a fight, a map that isn't protected still moves")
  map.IsProtected = function() return true end
  grip.scripts.OnDragStart(grip)
  check(not map.dragging and not W.moving, "a protected map can't be dragged in a fight")
  gameAnchors("TOPLEFT", "UIParent", "TOPLEFT", 16, -116)
  n, point, rel, x = at()
  check(rel == "TOPLEFT" and x == 16, "or re-anchored in one")
  InCombatLockdown = oldCombat
  fire("PLAYER_REGEN_ENABLED")
  mine, l = ours()
  check(mine and l == 500, "it goes back when the fight ends")
  map.IsProtected = nil

  -- Settings
  SlashCmdList.VOLTUI("worldmap drag")
  check(VoltUIDB.mapDrag == false and grip.shown == false, "dragging can be turned off")
  gameAnchors("TOPLEFT", "UIParent", "TOPLEFT", 16, -116)
  n, point, rel, x = at()
  check(rel == "TOPLEFT" and x == 16 and VoltUIDB.mapLeft == saved, "then the game's spot stands, and yours is kept")
  SlashCmdList.VOLTUI("worldmap drag")
  mine, l = ours()
  check(VoltUIDB.mapDrag and grip.shown and mine and l == 500, "turning it back on returns to your spot")
  SlashCmdList.VOLTUI("worldmap reset")
  check(not (VoltUIDB.mapLeft or VoltUIDB.mapTop or VoltUIDB.mapPoint or VoltUIDB.mapBigLeft or VoltUIDB.mapBigTop or VoltUIDB.mapBigPoint), "reset forgets both spots")
  gameAnchors("TOPLEFT", "UIParent", "TOPLEFT", 16, -116)
  n, point, rel, x = at()
  check(rel == "TOPLEFT" and x == 16, "and the game's spot stands again")
  wipe(chat)

  -- Resizing the small map by its corner (1.90.0)
  do
    local sizer = W.sizer
    function map:GetScale() return self.scale or 1 end
    check(sizer and sizer.parent == border and sizer.shown ~= false, "a corner to resize the map by")
    check(map.scale == nil and VoltUIDB.mapScale == 1, "its size is left alone until you change it")
    local oldCursor = GetCursorPosition
    map.atLeft, map.atTop = 100, 900 -- a 1000 by 700 window: its bottom-right is at 1100, 200
    GetCursorPosition = function() return 1100, 200 end
    sizer.scripts.OnMouseDown(sizer, "LeftButton")
    check(W.sizing ~= nil, "pressing the corner starts a resize")
    sizer.scripts.OnUpdate(sizer)
    check(map.scale == nil, "nothing changes until the mouse moves")
    GetCursorPosition = function() return 1600, -150 end
    sizer.scripts.OnUpdate(sizer)
    check(map.scale == 1.5 and VoltUIDB.mapScale == 1.5, "dragging the corner out half as far again makes it half as big again: " .. tostring(map.scale))
    check(VoltUIDB.mapPoint == "TOPLEFT" and math.abs(VoltUIDB.mapLeft * 1.5 - 100) < 0.02 and math.abs(VoltUIDB.mapTop * 1.5 + 180) < 0.02,
      "and its top-left corner stays where it was on screen: " .. tostring(VoltUIDB.mapLeft) .. ", " .. tostring(VoltUIDB.mapTop))
    local q = map.points[#map.points]
    check(q[2] == UIParent and q[3] == "TOPLEFT" and q[4] == VoltUIDB.mapLeft, "the window is put back on that corner")
    GetCursorPosition = function() return 6000, -4000 end
    sizer.scripts.OnUpdate(sizer)
    check(map.scale == 1.54, "it never grows past the screen: " .. tostring(map.scale))
    GetCursorPosition = function() return 130, 880 end
    sizer.scripts.OnUpdate(sizer)
    check(map.scale == 0.6, "or shrinks under six tenths: " .. tostring(map.scale))
    sizer.scripts.OnMouseUp(sizer)
    check(W.sizing == nil and VoltUIDB.mapScale == 0.6, "letting go keeps the size")
    GetCursorPosition = function() return 1600, -150 end
    sizer.scripts.OnUpdate(sizer)
    check(map.scale == 0.6, "and the mouse no longer resizes it")
    map.atLeft, map.atTop = 100 / 0.6, 900 / 0.6
    sizer.scripts.OnMouseDown(sizer, "RightButton")
    check(map.scale == 1 and VoltUIDB.mapScale == 1 and VoltUIDB.mapLeft == 100 and VoltUIDB.mapTop == -180, "right-click: the normal size, the corner still in place")

    SlashCmdList.VOLTUI("worldmap scale 150")
    check(map.scale == 1.5 and VoltUIDB.mapScale == 1.5 and lastSaid():find("150%%"), "a size can be typed, as a percentage")
    check(math.abs(VoltUIDB.mapLeft * 1.5 - 100) < 0.02, "the saved spot follows the new size")
    SlashCmdList.VOLTUI("worldmap scale 0.8")
    check(map.scale == 0.8, "or as a number")
    SlashCmdList.VOLTUI("worldmap scale 900")
    check(map.scale == 2, "within limits")
    map.big = true
    gameAnchors("TOP")
    check(map.scale == 1 and sizer.shown == false, "the full-size map is the game's size, with no corner to drag")
    sizer.scripts.OnMouseDown(sizer, "LeftButton")
    check(W.sizing == nil, "and can't be resized")
    map.big = false
    gameAnchors("TOPLEFT", "UIParent", "TOPLEFT", 16, -116)
    check(map.scale == 2 and sizer.shown, "the small map gets its size back")

    local oldCombat = InCombatLockdown
    InCombatLockdown = function() return true end
    map.IsProtected = function() return true end
    SlashCmdList.VOLTUI("worldmap scale 100")
    check(map.scale == 2 and VoltUIDB.mapScale == 1, "a protected map isn't resized in a fight")
    sizer.scripts.OnMouseDown(sizer, "LeftButton")
    check(W.sizing == nil, "by the corner either")
    InCombatLockdown = oldCombat
    fire("PLAYER_REGEN_ENABLED")
    check(map.scale == 1, "it's resized when the fight ends")
    map.IsProtected = nil

    -- with dragging off VoltUI keeps no spot, but the corner still holds while you resize
    VoltUIDB.mapDrag = false
    local keepLeft = VoltUIDB.mapLeft
    map.atLeft, map.atTop = 100, 900
    GetCursorPosition = function() return 1100, 200 end
    sizer.scripts.OnMouseDown(sizer, "LeftButton")
    GetCursorPosition = function() return 1300, 60 end
    sizer.scripts.OnUpdate(sizer)
    sizer.scripts.OnMouseUp(sizer)
    q = map.points[#map.points]
    check(map.scale == 1.2 and VoltUIDB.mapLeft == keepLeft and q[3] == "BOTTOMLEFT" and math.abs(q[4] * 1.2 - 100) < 0.02,
      "with dragging off: resized, the corner held, no spot written")
    VoltUIDB.mapDrag = true
    SlashCmdList.VOLTUI("worldmap reset")
    check(VoltUIDB.mapScale == 1 and map.scale == 1 and not VoltUIDB.mapLeft, "reset forgets the size too")
    GetCursorPosition = oldCursor
    wipe(chat)
  end

  WorldMapFrame = oldMap
end)()

Extra("entrances", { canvas = canvas })

Extra("flights", { canvas = canvas })

Extra("pools") -- another add-on's tests, since VoltUI 1.104.0

print("== Questie skin")
;(function()
  local Q = ns.QuestieSkin
  local S = ns.Style
  local FUI = ns.FUI

  -- Without Questie there's nothing to do, and nothing goes wrong.
  check(Q.enabled and not Q.ready, "does nothing when Questie isn't installed")
  wipe(chat)
  SlashCmdList.VOLTUI("questie")
  check(chat[1] and chat[1]:find("isn't installed", 1, true), "and says so")
  wipe(chat)

  check(S.Fade and S.FlatButton, "the map's flattening helpers are shared")
  S.Fade(nil, function() end, 3)
  check(true, "fading skips anything that isn't a frame")

  -- Questie's real files, when you say where they are. It isn't in this repository, so:
  --   QUESTIE_DIR=path/to/Questie python runlua51.py tests/voltui_test.lua VoltUI
  local DIR_Q = os.getenv("QUESTIE_DIR")
  if not DIR_Q then
    print("  (Questie's real files skipped: QUESTIE_DIR isn't set)")
    return
  end

  -- A yield can't pass through the game's hook wrapper. pcall on Lua 5.1 refuses in the
  -- same way, so a hook on something that yields fails here as it would in the game.
  -- Put back once this section ends: later parts hook the game's globals on purpose, and use
  -- the plain stand-in frames, not the ones Questie's files need below.
  PLAIN_HOOKSECUREFUNC = hooksecurefunc
  -- The game's globals this section stands in for, put back once it ends too. Left in place,
  -- GetTime stayed at 0 for every later part, so two settings changes looked like one drag.
  PLAIN_GLOBALS = {}
  for _, k in ipairs({ "CreateFrame", "Questie", "BackdropTemplateMixin", "UISpecialFrames", "IsControlKeyDown",
    "GetTimePreciseSec", "GetTime", "PlaySound", "tinsert", "GetScreenHeight", "GetScreenWidth", "SOUNDKIT", "Menu",
    "NineSliceUtil", "SettingsPanel", "Settings", "CreateScrollBoxLinearView", "ScrollUtil", "FontStringOutlineMixin",
    "IsMouseButtonDown", "IsShiftKeyDown", "IsAltKeyDown", "ChatEdit_GetActiveWindow", "SetCursor", "InCombatLockdown",
    "QuestieJourneyFrame", "C_QuestLog" }) do
    PLAIN_GLOBALS[k] = { v = _G[k] }
  end
  PLAIN_QUESTLOG_MAX = C_QuestLog and C_QuestLog.GetMaxNumQuestsCanAccept
  PLAIN_TABLE_WIPE = table.wipe
  -- Text drawn from here on is Questie's own or its skin's, not one of VoltUI's windows.
  PLAIN_FONTSTRINGS = #allFontStrings
  PLAIN_MOCK = {}
  for k, v in pairs(Mock) do PLAIN_MOCK[k] = v end
  function hooksecurefunc(t, k, fn)
    if type(t) == "string" then error("VoltUI's skin shouldn't hook a global: " .. t) end
    local o = t[k]
    t[k] = function(...)
      local r = { pcall(o, ...) }
      if not r[1] then error(r[2], 0) end
      fn(...)
      return unpack(r, 2)
    end
  end

  local Parts = {
    PortraitFrameTemplate = function(f)
      f.NineSlice = new("Frame", nil, f)
      f.Bg = f:CreateTexture()
      f.TopTileStreaks = f:CreateTexture()
      f.PortraitContainer = new("Frame", nil, f)
      f.PortraitContainer.portrait = f.PortraitContainer:CreateTexture()
      f.TitleContainer = new("Frame", nil, f)
      f.TitleContainer.TitleText = f.TitleContainer:CreateFontString()
      f.CloseButton = CreateFrame("Button", nil, f)
      for _, k in ipairs({ "PortraitFrame", "TopRightCorner", "TopLeftCorner", "TopBorder", "BotLeftCorner", "BotRightCorner", "BottomBorder", "LeftBorder", "RightBorder" }) do
        f[k] = f.NineSlice:CreateTexture()
      end
    end,
    SettingsCheckboxTemplate = function(f)
      f.nt, f.pt, f.ct, f.dct = f:CreateTexture(), f:CreateTexture(), f:CreateTexture(), f:CreateTexture()
    end,
    OptionsSliderTemplate = function(f)
      f.Text, f.Low, f.High = f:CreateFontString(), f:CreateFontString(), f:CreateFontString()
      f.NineSlice, f.Thumb = false, f:CreateTexture()
    end,
    WowStyle1DropdownTemplate = function(f)
      f.Background, f.Arrow, f.Text = f:CreateTexture(), f:CreateTexture(), f:CreateFontString()
      f.NineSlice = false
    end,
    InputBoxTemplate = function(f)
      f.Left, f.Middle, f.Right = f:CreateTexture(), f:CreateTexture(), f:CreateTexture()
    end,
    UIPanelButtonTemplate = function(f)
      f.Left, f.Middle, f.Right = f:CreateTexture(), f:CreateTexture(), f:CreateTexture()
      f.Text = f:CreateFontString()
      f.fontString = f.Text
    end,
    NineSlicePanelTemplate = function(f) f.NineSlice = false; f:CreateTexture(); f:CreateTexture() end,
    BackdropTemplate = function(f) f.isBackdrop = true end,
  }
  local baseCreate = CreateFrame
  function CreateFrame(kind, name, parent, template)
    local f = baseCreate(kind, name, parent)
    f.fname = name
    if parent then
      parent.kids = parent.kids or {}
      table.insert(parent.kids, f)
    end
    if template and Parts[template] then Parts[template](f) end
    return f
  end
  function Mock:GetName() return self.fname end
  function Mock:GetChildren() return unpack(self.kids or {}) end
  function Mock:GetObjectType() return self.kind end
  function Mock:GetNormalTexture() return self.nt end
  function Mock:SetNormalTexture(t) self.nt = t end
  function Mock:GetCheckedTexture() return self.ct end
  function Mock:SetCheckedTexture(t) self.ct = t end
  function Mock:GetDisabledCheckedTexture() return self.dct end
  function Mock:SetDisabledCheckedTexture(t) self.dct = t end
  function Mock:GetDisabledTexture() return self.dt end
  function Mock:SetDisabledTexture(t) self.dt = t end
  function Mock:SetPushedTexture(t) self.pushTex = t end
  function Mock:GetThumbTexture() return self.Thumb end
  function Mock:GetFontString() return self.fontString end
  function Mock:SetFontString(fs) self.fontString = fs end
  function Mock:GetStringWidth() return 50 end
  function Mock:GetUnboundedStringWidth() return 50 end
  function Mock:GetStringHeight() return 12 end
  function Mock:GetTextWidth() return 50 end
  function Mock:GetWidth() return self.w or 300 end
  function Mock:GetHeight() return self.h or 20 end
  function Mock:SetBackdrop(b) self.backdrop = b end
  function Mock:SetBackdropColor(r, g, b, a) self.bgc = { r, g, b, a } end
  function Mock:SetBackdropBorderColor(r, g, b, a) self.bdc = { r, g, b, a } end
  function Mock:SetVertexColor(r, g, b, a) self.vc = { r, g, b, a } end
  function Mock:SetMovable(v) self.movable = v end
  function Mock:IsMovable() return self.movable end
  function Mock:StartMoving() self.moving = true end
  function Mock:StopMovingOrSizing() self.moving = false end
  function Mock:CreateMaskTexture() return new("Texture", nil, self) end
  local plainFontString = Mock.CreateFontString
  function Mock:CreateFontString(...)
    local fs = plainFontString(self, ...)
    table.insert(self.regions, fs)
    return fs
  end

  local function realFile(path, ...)
    local f, err = loadfile(DIR_Q .. "/" .. path)
    if not f then error(err) end
    return f("Questie", {}, ...)
  end

  local fonts = { ["Friz Quadrata TT"] = "friz" }
  -- The real LibStub and AceGUI, as Journey's window is made from them. LibStub keeps its
  -- table global, and VoltUI asks it for the font library.
  realFile("Libs/LibStub/LibStub.lua")
  local LSM = LibStub:NewLibrary("LibSharedMedia-3.0", 1)
  function LSM:IsValid(_, name) return fonts[name] ~= nil end
  function LSM:Register(_, name, path) fonts[name] = path end
  function LSM:Fetch(_, name) return fonts[name] or "default" end

  realFile("Modules/Libs/QuestieLoader.lua")
  local function M(name) return QuestieLoader:ImportModule(name) end

  local profile = {
    trackerBackdropColor = { r = 0, g = 0, b = 0, a = 1 }, trackerBackdropEnabled = false, currentBackdropEnabled = false,
    trackerBorderEnabled = false, currentBorderEnabled = false, trackerBackdropFader = false, trackerLocked = true,
    trackerHeaderEnabled = true, trackerFontOutline = "", moveHeaderToBottom = false, sizerHidden = false,
    trackerFontSizeHeader = 12, trackerFontSizeZone = 12, trackerFontSizeQuest = 10, trackerFontSizeObjective = 14,
    trackerFontHeader = "Friz Quadrata TT", trackerFontZone = "Friz Quadrata TT",
    trackerFontQuest = "Friz Quadrata TT", trackerFontObjective = "Friz Quadrata TT",
    TrackerLocation = { "TOPLEFT", "UIParent", "TOPLEFT", 100, -100 },
  }
  Questie = {
    db = { profile = profile, char = { isTrackerExpanded = true }, global = {} },
    icons = { complete = "icon" }, IsForever = true,
    Debug = function() end, Print = function() end, Colorize = function(_, t) return t end,
    DEBUG_DEVELOP = 1, DEBUG_CRITICAL = 2,
  }
  setmetatable(M("l10n"), { __call = function(_, s) return s end })
  M("QuestieCompat").SetResizeBounds = function() end
  M("QuestieCompat").GetWatchFramePoint = function() return "TOPLEFT", UIParent, "TOPLEFT", 0, 0 end
  M("QuestieCompat").IsAddOnLoaded = function() return false end
  M("QuestieCombatQueue").Queue = function(_, fn) fn() end
  M("QuestLogCache").GetQuestCount = function() return 3 end
  M("TrackerUtils").HasQuest = function() return true end
  M("QuestieTracker").UpdateDurabilityFrame = function() end
  M("QuestieTracker").UpdateVoiceOverFrame = function() end
  local trackerUpdates = 0
  M("QuestieTracker").Update = function() trackerUpdates = trackerUpdates + 1 end
  -- ThreadLib runs its work a frame later, in a coroutine that yields between steps.
  local threads = {}
  M("ThreadLib").Thread = function(fn) threads[#threads + 1] = coroutine.create(fn) end
  local function runThreads()
    while #threads > 0 do
      local co = threads[1]
      local ok, err = coroutine.resume(co)
      if not ok then error(err) end
      if coroutine.status(co) == "dead" then table.remove(threads, 1) end
    end
  end

  C_QuestLog = C_QuestLog or {}
  C_QuestLog.GetMaxNumQuestsCanAccept = function() return 20 end
  BackdropTemplateMixin = true
  UISpecialFrames = {}
  function IsControlKeyDown() return false end
  function GetTimePreciseSec() return 0 end
  function GetTime() return 0 end
  function PlaySound() end
  function tinsert(t, v) table.insert(t, v) end
  function GetScreenHeight() return 1000 end
  SOUNDKIT = { IG_CHARACTER_INFO_TAB = 1 }
  Menu = { GetManager = function() return { GetOpenMenu = function() end } end }
  NineSliceUtil = { ApplyLayoutByName = function() end }
  SettingsPanel = { Container = { SettingsCanvas = new("Frame") } }
  Settings = {
    RegisterCanvasLayoutCategory = function() return {} end,
    RegisterCanvasLayoutSubcategory = function() return {} end,
    RegisterAddOnCategory = function() end,
  }
  CreateScrollBoxLinearView = function() return new("Frame") end
  ScrollUtil = { InitScrollBoxWithScrollBar = function() end, AddManagedScrollBarVisibilityBehavior = function() end }
  FontStringOutlineMixin = nil

  realFile("Modules/Tracker/TrackerBaseFrame.lua")
  realFile("Modules/Tracker/TrackerHeaderFrame.lua")
  realFile("Modules/Options/QuestieOptionsUtils.lua")
  realFile("Modules/Options/QuestieOptionsWindow.lua")
  realFile("Modules/Options/QuestieOptionsLayout.lua")
  realFile("Modules/Options/QuestieOptionsControls.lua")
  realFile("Modules/Options/QuestieOptionsEngine.lua")

  local Journey = M("QuestieJourney")
  Journey.IsShown = function() return false end
  function Journey:ToggleJourneyWindow() self.toggles = (self.toggles or 0) + 1 end

  wipe(chat)
  Q:Enable()
  check(Q.ready, "starts once Questie's there")
  check(#Q.missing == 0, "everything it hooks exists in this Questie: " .. table.concat(Q.missing, ", "))
  check(profile.voltSkinned and profile.trackerBackdropEnabled and profile.trackerBorderEnabled, "the tracker's panel is on")
  check(profile.currentBackdropEnabled and profile.currentBorderEnabled, "and stays on after Questie's resize mode")
  check(profile.trackerBackdropColor.r == S.BG[1] and profile.trackerBackdropColor.a == VoltUIDB.alpha, "in VoltUI's colour")
  check(profile.trackerFontSizeQuest == 12 and profile.trackerFontSizeHeader == 13, "Questie's small default sizes go up")
  check(profile.trackerFontSizeObjective == 14, "a size you changed stays")
  check(profile.trackerFontQuest == S.Font().name and fonts[S.Font().name] == S.Font().path, "the tracker gets VoltUI's font")

  -- The tracker, run through Questie's own code
  local TB, TH = M("TrackerBaseFrame"), M("TrackerHeaderFrame")
  local base = TB.Initialize()
  check(base.backdrop and base.backdrop.edgeSize == 1 and base.backdrop.bgFile == S.WHITE, "flat panel")
  local header = TH.Initialize(base, function() end)
  TH:Update()
  TB:Update()
  check(base.bgc[1] == S.BG[1] and base.bgc[4] == VoltUIDB.alpha, "Questie's own update paints it in VoltUI's colour")
  check(base.bdc[1] == S.EDGE[1] and base.bdc[2] == S.EDGE[2], "its white border comes out in VoltUI's colour")
  check(base.bdc[4] == VoltUIDB.alpha, "at Questie's alpha")
  check(header.trackedQuests.label.color and header.trackedQuests.label.color[1] == S.ACCENT[1], "the title's in VoltUI's blue")
  check(Q.strip.shown and Q.strip.h == 13 + 16, "title strip behind the header")
  check(Q.strip.alpha == VoltUIDB.alpha, "which fades with the panel")
  profile.trackerBackdropEnabled = false
  TB:Update()
  check(base.bgc[4] == 0 and base.bdc[4] == 0 and Q.strip.alpha == 0, "Questie's background option still turns it off")
  profile.trackerBackdropEnabled = true
  TB:Update()
  profile.trackerHeaderEnabled = false
  TH:Update()
  check(not Q.strip.shown, "no strip without a header")
  profile.trackerHeaderEnabled = true
  profile.moveHeaderToBottom = true
  TH:Update()
  check(Q.strip.points[1][1] == "BOTTOMLEFT", "the strip follows the header to the bottom")
  profile.moveHeaderToBottom = false
  TH:Update()

  -- Moving it from the edit mode, through Questie's own drag code
  function IsMouseButtonDown() return true end
  function IsShiftKeyDown() return false end
  function IsAltKeyDown() return false end
  function ChatEdit_GetActiveWindow() end
  function SetCursor() end
  function GetScreenWidth() return 2000 end
  function Mock:GetRight() return 700 end
  function Mock:GetBottom() return 400 end
  check(profile.trackerLocked == true, "the tracker starts locked")
  check(not Q.mover, "no drag overlay until the edit mode opens")
  FUI:SetUnlocked(true)
  check(Q.mover and Q.mover.shown and Q.mover.parent == base, "the edit mode puts an overlay on the tracker")
  check(Q.mover.flevel == 200, "above the tracker's lines")
  check(Q.mover.label.text == "Questie tracker", "and names it")
  Q.mover.scripts.OnDragStart(Q.mover)
  check(base.moving and TB.isMoving, "dragging it moves the tracker even while locked")
  check(profile.trackerLocked == false, "unlocked for the drag")
  profile.trackerSetpoint = "TOPLEFT"
  Q.mover.scripts.OnDragStop(Q.mover)
  check(not base.moving and not TB.isMoving, "letting go stops it")
  check(profile.trackerLocked == true, "and it's locked again")
  local loc = profile.TrackerLocation
  check(loc[1] == "TOPLEFT" and loc[4] == 300 and loc[5] == -400, "Questie saves the new spot itself")
  profile.trackerLocked = false
  Q.mover.scripts.OnDragStart(Q.mover)
  Q.mover.scripts.OnHide(Q.mover)
  check(not base.moving and profile.trackerLocked == false, "closing mid-drag stops it, and an unlocked tracker stays unlocked")
  Q.mover.scripts.OnDragStop(Q.mover)
  check(Q.lockedBeforeDrag == nil, "a second stop does nothing")
  profile.trackerLocked = true
  local inCombat = InCombatLockdown
  InCombatLockdown = function() return true end
  Q.mover.scripts.OnDragStart(Q.mover)
  check(not base.moving and profile.trackerLocked == true, "no moving it in combat")
  InCombatLockdown = inCombat
  FUI:SetUnlocked(false)
  check(not Q.mover.shown, "the overlay goes when the edit mode closes")
  wipe(chat)

  -- Following VoltUI's settings
  local was = trackerUpdates
  SlashCmdList.VOLTUI("alpha 0.5")
  check(profile.trackerBackdropColor.a == 0.5 and trackerUpdates == was + 1, "/volt alpha reaches the tracker")
  SlashCmdList.VOLTUI("alpha 0.85")
  was = trackerUpdates
  SlashCmdList.VOLTUI("glow 0.5")
  check(trackerUpdates == was, "other settings leave the tracker alone")
  profile.trackerBackdropColor.r = 0.3
  SlashCmdList.VOLTUI("alpha 0.4")
  check(profile.trackerBackdropColor.a ~= 0.4, "a colour you picked in Questie is yours")
  profile.trackerBackdropColor.r = S.BG[1]
  SlashCmdList.VOLTUI("alpha 0.85")
  SlashCmdList.VOLTUI("font rajdhani")
  check(profile.trackerFontZone == "Rajdhani", "/volt font reaches the tracker")
  SlashCmdList.VOLTUI("questie fonts")
  SlashCmdList.VOLTUI("font barlow")
  check(profile.trackerFontZone == "Rajdhani", "unless that's turned off")
  SlashCmdList.VOLTUI("questie fonts")

  -- The settings window, built by Questie's real engine in its real coroutines
  local Engine = M("QuestieOptionsEngine")
  local items = {
    aCheck = { type = "checkbox", order = 1, name = "c", title = "A box", description = "Words", get = function() return true end, set = function() end },
    bRadio = { type = "radioButton", order = 2, title = "A radio", value = 1, get = function() return false end, set = function() end },
    cSlider = { type = "slider", order = 3, title = "A slider", min = 1, max = 5, step = 1, showValue = true, get = function() return 2 end, set = function() end },
    dDrop = { type = "dropdown", order = 4, title = "A list", options = { a = "A" }, get = function() return "a" end, set = function() end },
    eDivider = { type = "divider", order = 5, title = "Part" },
    fButton = { type = "button", order = 6, title = "t", btnLabel = "Press", align = "LEFT", func = function() end },
    gText = { type = "textbox", order = 7, title = "Type", get = function() return "x" end, set = function() end },
    hOff = { type = "checkbox", order = 8, title = "Off", enabled = function() return false end, get = function() return false end, set = function() end },
    iBox = { type = "container", order = 9, title = "Group", items = {
      inner = { type = "checkbox", order = 1, title = "Inner", get = function() return false end, set = function() end },
    } },
  }
  Engine.tabs.one = { Initialize = function() return { title = "One", order = 1, icon = 1, items = items } end }
  local co = coroutine.create(function() Engine:Initialize() end)
  repeat
    local ok, err = coroutine.resume(co)
    if not ok then error(err) end
  until coroutine.status(co) == "dead"

  Engine:ShowFrame()
  local win = Engine.popup
  check(win and win.fuiPanel, "the settings window gets VoltUI's panel")
  check(win.NineSlice.alpha == 0 and win.Bg.alpha == 0 and win.PortraitContainer.alpha == 0, "its frame art is faded")
  check(win.TitleContainer.TitleText.color[1] == S.ACCENT[1], "with a blue title")
  local tab
  for _, k in ipairs(win.kids) do if k.Selected then tab = k end end
  check(tab and tab.w == 38 and tab.Icon.w == 26, "square side tabs")
  check(tab and tab.Background.ctex and tab.Highlight.ctex and tab.Selected.ctex, "flat side tabs")
  runThreads()

  local canvas = _G.QuestieOptionsTab_Popup_one
  check(canvas and #canvas.controls >= 9, "Questie builds its page in its coroutine, through the hooks")
  local function find(kind, title)
    for _, c in ipairs(canvas.controls) do
      if c.itemData and c.itemData.type == kind and (not title or c.itemData.title == title) then return c end
    end
  end
  local c = find("checkbox", "A box")
  check(c.widget.nt.w == 16 and c.widget.ct.ctex[1] == S.ACCENT[1], "flat checkbox")
  check(c.widget.HoverTex.ctex, "with a flat hover")
  check(c.titleFrame.color[1] == 0.92 and c.descriptionFrame.color[1] == S.LABEL[1], "label colours")
  local off = find("checkbox", "Off")
  check(off.titleFrame.color[1] == 0.65, "a disabled option stays grey")
  local radio = find("radioButton")
  check(radio.widget.ct.ctex[1] == S.ACCENT[1], "flat radio")
  local slider = find("slider")
  check(slider.widget.TrackMiddle.ctex and slider.widget.TrackLeft.alpha == 0 and slider.thumb.ctex, "flat slider")
  local drop = find("dropdown")
  check(drop.widget.Background.alpha == 0 and drop.widget.fuiPanel, "flat dropdown")
  local div = find("divider")
  check(div.titleFrame.color[1] == S.ACCENT[1], "blue section titles")
  local btn = find("button", "t")
  local art
  for _, r in ipairs(btn.widget.regions) do if r.kind == "Texture" and not r.ctex then art = art or r end end
  check(btn.widget.fuiPanel and art and art.alpha == 0, "flat button")
  local text = find("textbox")
  check(text.widget.Left.alpha == 0 and text.widget.fuiPanel and text.okBtn.Left.alpha == 0, "flat text box")
  local group = find("container")
  check(group.containerFrame.alpha == 1 and group.containerFrame.fuiPanel, "flat group")
  -- Questie's refresh puts its colours back, and the hook follows it.
  Engine:RefreshStates()
  check(c.titleFrame.color[1] == 0.92, "colours survive Questie's refresh")

  local title
  for _, r in ipairs(canvas.regions) do if r.text == "Questie" then title = r end end
  check(title and title.points[1][4] == 8 and title.color[1] == S.ACCENT[1], "the heading moves into the portrait's old spot")

  -- The same controls on Questie's page in the game's settings stay as they are.
  local blizz = _G.QuestieOptionsTab_Blizz_one
  blizz:Show()
  runThreads()
  local stock
  for _, b in ipairs(blizz.controls or {}) do
    if b.itemData and b.itemData.type == "checkbox" then stock = b end
  end
  check(stock and stock.widget.nt.w ~= 16 and not stock.widget.ct.ctex, "the game's settings panel isn't restyled")

  -- My Journey, made from the real AceGUI, the way Questie makes it
  table.wipe = wipe
  realFile("Libs/AceGUI-3.0/AceGUI-3.0.lua")
  realFile("Libs/AceGUI-3.0/widgets/AceGUIContainer-Frame.lua")
  realFile("Libs/AceGUI-3.0/widgets/AceGUIContainer-TabGroup.lua")
  realFile("Libs/AceGUI-3.0/widgets/AceGUIContainer-InlineGroup.lua")
  realFile("Libs/AceGUI-3.0/widgets/AceGUIContainer-SimpleGroup.lua")
  realFile("Libs/AceGUI-3.0/widgets/AceGUIWidget-Button.lua")
  local AceGUI = LibStub("AceGUI-3.0")
  local jf = AceGUI:Create("Frame")
  jf:SetLayout("Fill")
  local tabs = AceGUI:Create("TabGroup")
  tabs:SetLayout("Flow")
  tabs:SetTabs({ { text = "One", value = "one" }, { text = "Two", value = "two" } })
  tabs:BuildTabs()
  tabs:SelectTab("one")
  jf:AddChild(tabs)
  local top = AceGUI:Create("Button")
  jf:AddChild(top)
  QuestieJourneyFrame = jf
  jf.content.SetBackdrop = false   -- as in game: a plain frame has none

  Journey:ToggleJourneyWindow()
  check(Journey.toggles == 1, "the window's own toggle still runs")
  check(jf.frame.fuiPanel and jf.frame.backdrop == nil, "Journey's window gets VoltUI's panel")
  check(jf.titlebg.alpha == 0 and jf.titletext.color[1] == S.ACCENT[1], "and a blue title with no art")
  check(top.frame.Left.alpha == 0 and top.frame.fuiPanel, "flat top button")
  -- AceGUI marks its content frame with .obj as well, and taking it for the status bar stopped
  -- the whole window being styled. The mock answers any field with a function, so look for
  -- a real texture rather than any .Left.
  local statusbg
  for _, k in ipairs(jf.frame.kids) do
    if k.obj == jf and type(k.Left) ~= "table" and k ~= jf.content then statusbg = k end
  end
  check(statusbg and statusbg.fuiPanel and statusbg.backdrop == nil, "flat status bar")
  check(not jf.content.fuiPanel, "and the content frame isn't mistaken for it")
  check(tabs.border.fuiPanel and tabs.border.backdrop == nil, "flat tab area")
  local t1, t2 = tabs.tabs[1], tabs.tabs[2]
  check(t1.Left.alpha == 0 and t1.LeftDisabled.alpha == 0 and t1.HighlightTexture.ctex, "flat tabs")
  check(t1.voltLine.shown and not t2.voltLine.shown, "a blue line under the open tab")
  tabs:SelectTab("two")
  check(t2.voltLine.shown and not t1.voltLine.shown, "which moves when you switch")

  -- Widgets inside come from a pool shared with other add-ons.
  local pane = AceGUI:Create("InlineGroup")
  tabs:AddChild(pane)
  local watcher = jf.frame.kids[#jf.frame.kids]
  watcher.scripts.OnUpdate(watcher, 0.3)
  local paneBorder = pane.content:GetParent()
  check(paneBorder.bgc[1] == S.BG[1] and paneBorder.bdc[1] == S.EDGE[1], "panes inside are tinted as they appear")
  check(paneBorder.backdrop ~= nil, "and keep their shape")
  check(not pane.frame.fuiPanel and not paneBorder.fuiPanel, "with nothing added that could outlive the window")
  tabs:ReleaseChildren()
  watcher.scripts.OnUpdate(watcher, 0.3)
  check(paneBorder.bgc[1] == 0.1 and paneBorder.bdc[1] == 0.4, "and get their own colours back when released")
  local reused = AceGUI:Create("InlineGroup")
  check(reused == pane and paneBorder.bgc[1] == 0.1, "so the next add-on to use one gets it as it should be")
  AceGUI:Release(reused)

  Journey:ToggleJourneyWindow()
  check(Journey.toggles == 2, "opening it again is fine")

  -- Nothing went wrong along the way
  local problems = {}
  for what, err in pairs(Q.reported) do problems[#problems + 1] = what .. ": " .. err end
  check(#problems == 0, "no part failed: " .. table.concat(problems, " | "))
  wipe(chat)
  SlashCmdList.VOLTUI("questie")
  check(chat[1] and chat[1]:find("Questie skin", 1, true), "/volt questie reports")
  wipe(chat)
end)()
if PLAIN_HOOKSECUREFUNC then hooksecurefunc, PLAIN_HOOKSECUREFUNC = PLAIN_HOOKSECUREFUNC, nil end
if PLAIN_GLOBALS then
  for k, saved in pairs(PLAIN_GLOBALS) do _G[k] = saved.v end
  if C_QuestLog then C_QuestLog.GetMaxNumQuestsCanAccept = PLAIN_QUESTLOG_MAX end
  table.wipe = PLAIN_TABLE_WIPE
  for i = PLAIN_FONTSTRINGS + 1, #allFontStrings do allFontStrings[i].questie = true end
  PLAIN_GLOBALS, PLAIN_QUESTLOG_MAX, PLAIN_TABLE_WIPE, PLAIN_FONTSTRINGS = nil, nil, nil, nil
end
if PLAIN_MOCK then
  for k in pairs(Mock) do Mock[k] = nil end
  for k, v in pairs(PLAIN_MOCK) do Mock[k] = v end
  PLAIN_MOCK = nil
end

print("== Party and raid frames")
;(function()
  local R, S = ns.Raid, ns.Style

  -- Stand-ins shared with later sections (bars, colours, fonts).
  function Mock:SetStatusBarTexture(t) self.barTex = t; self.fillTex = self.fillTex or new("Texture"); self.fillTex.tex = t end
  function Mock:GetStatusBarTexture() self.fillTex = self.fillTex or new("Texture"); return self.fillTex end
  function Mock:SetStatusBarColor(r, g, b) self.barColor = { r, g, b } end
  function Mock:SetVertexColor(r, g, b) self.vc = { r, g, b } end
  function Mock:GetVertexColor() local c = self.vc or { 1, 1, 1 }; return c[1], c[2], c[3] end
  function Mock:RemoveMaskTexture(m) self.unmasked = self.unmasked or {}; self.unmasked[m] = true end
  function Mock:SetNormalFontObject(o) self.normalFont = o end
  function Mock:SetDisabledFontObject(o) self.disabledFont = o end
  function Mock:SetAlphaFromBoolean(v, a, b) self.alphaFrom = { v, a, b } end
  function Mock:RegisterForClicks(...) self.clicks = { ... } end
  local oldGetFont = Mock.GetFont
  function Mock:GetFont() if self.font then return self.font[1], self.font[2], self.font[3] end end
  function CreateFont(name)
    local f = new("Font", name)
    f.SetTextColor = function(self, r, g, b) self.color = { r, g, b } end
    return f
  end
  local function near(a, b) return type(a) == "number" and math.abs(a - b) < 1e-6 end

  local saved = {}
  local KEYS = { "UnitGroupRolesAssigned", "UnitIsDeadOrGhost", "UnitThreatSituation", "UnitIsUnit", "UnitInRange",
    "UnitHealthMissing", "UnitHealthPercent", "IsPlayerSpell", "C_Spell", "C_UnitAuras", "C_StringUtil", "C_CurveUtil",
    "UnitGetIncomingHeals", "UnitGetTotalAbsorbs", "IsInRaid", "GetRaidRosterInfo", "UnitExists", "UnitName", "UnitClass",
    "UnitHealth", "UnitHealthMax", "UnitPower", "UnitPowerMax", "UnitPowerType", "UnitIsConnected", "UnitIsGhost",
    "CreateUnitHealPredictionCalculator", "UnitGetDetailedHealPrediction", "issecretvalue", "CurveConstants", "C_ClickBindings" }
  for _, k in ipairs(KEYS) do saved[k] = _G[k] end
  local oldUnits = UNITS

  local G = {
    player = { name = "Test Hero", class = "SHAMAN", hp = 300, hpMax = 400, role = "HEALER" },
    party1 = { name = "Brakka-Stormrage", class = "ROGUE", hp = 900, hpMax = 1000, role = "TANK", threat = 3, ptoken = "ENERGY", heals = 50, shields = 20 },
    party2 = { name = "Vexa", class = "MAGE", hp = 0, hpMax = 500, dead = true, role = "DAMAGER" },
    party3 = { name = "Rook", class = "ROGUE", hp = 100, hpMax = 500, connected = false },
    party4 = { name = "Lumen", class = "PRIEST", hp = 250, hpMax = 500, role = "HEALER", far = true },
  }
  UNITS = G
  local function info(u) return G[u] or {} end
  local targetUnit
  UnitExists = function(u) return G[u] ~= nil end
  UnitName = function(u) return info(u).name end
  UnitClass = function(u) return "x", info(u).class end
  UnitHealth = function(u) return info(u).hp or 100 end
  UnitHealthMax = function(u) return info(u).hpMax or 100 end
  UnitPower = function() return 40 end
  UnitPowerMax = function() return 100 end
  UnitPowerType = function(u) return 0, info(u).ptoken or "MANA" end
  UnitIsConnected = function(u) local c = info(u).connected; if c == nil then return true end; return c end
  UnitIsGhost = function() return false end
  UnitIsDeadOrGhost = function(u) return info(u).dead or false end
  UnitGroupRolesAssigned = function(u) return info(u).role or "NONE" end
  UnitThreatSituation = function(u) return info(u).threat or 0 end
  UnitIsUnit = function(a, b)
    if b == "target" then return a == targetUnit end
    if b == "player" then return a == "player" or info(a).me == true end
    return a == b
  end
  UnitInRange = function(u) return not info(u).far, true end
  UnitHealthMissing = function(u) return (info(u).hpMax or 100) - (info(u).hp or 100) end
  UnitGetIncomingHeals = function(u) return info(u).heals or 0 end
  UnitGetTotalAbsorbs = function(u) return info(u).shields or 0 end
  CreateUnitHealPredictionCalculator, UnitGetDetailedHealPrediction = nil, nil
  IsInRaid = function() return false end
  local rangeAsked = 0
  C_Spell = { IsSpellInRange = function(_, u) rangeAsked = rangeAsked + 1; return not info(u).far end }
  -- A shaman: Healing Wave, Cure Poison, Cure Disease.
  IsPlayerSpell = function(id) return id == 331 or id == 526 or id == 2870 end
  local AURAS = {}
  local function aura(u, id) for _, a in ipairs(AURAS[u] or {}) do if a.id == id then return a end end end
  C_UnitAuras = {
    GetUnitAuraInstanceIDs = function(u) local out = {}; for _, a in ipairs(AURAS[u] or {}) do out[#out + 1] = a.id end; return out end,
    GetAuraDataByAuraInstanceID = function(u, id) local a = aura(u, id); if a then return { icon = a.icon, dispelName = a.kind, auraInstanceID = id } end end,
    IsAuraFilteredOutByInstanceID = function(u, id) local a = aura(u, id); return not (a and a.game) end,
    GetAuraDuration = function(_, id) return { dur = id } end,
    GetAuraApplicationDisplayCount = function(_, id) return id == 12 and "3" or "" end,
    GetAuraDispelTypeColor = function() return { GetRGB = function() return 0.2, 0.6, 1 end } end,
  }
  C_StringUtil = { RoundToNearestString = function(v) return v end }
  R:FindRangeSpell()
  ns.RaidAuras:FindDispels()
  check(R.rangeSpell == 331, "out of heal range: the shaman's Healing Wave")
  check(ns.RaidAuras.types.Poison and ns.RaidAuras.types.Disease and not ns.RaidAuras.types.Magic, "your dispels: poison and disease, not magic")

  -- Headers
  local party, g3 = VoltUIRaidParty, VoltUIRaidGroup3
  check(R.enabled and VoltUIRaidFrames and party and VoltUIRaidGroup1 and VoltUIRaidGroup8, "VoltUI's own headers: the party and eight raid groups")
  check(party.tmpl == "SecureGroupHeaderTemplate" and party.attrs.template == "SecureUnitButtonTemplate", "secure group headers making secure unit buttons")
  check(party.attrs.showParty and not party.attrs.showRaid and g3.attrs.showRaid and g3.attrs.groupFilter == "3", "the party header, and one per raid group")
  check(party.attrs.initialConfigFunction:find('CallMethod("kInit"', 1, true) and party.attrs.initialConfigFunction:find('"*type2", "togglemenu"', 1, true),
    "new member buttons are sized, get target and menu clicks, and are dressed by VoltUI")
  check(party.attrs["volt-width"] == 72 and party.attrs["volt-height"] == 36 and party.attrs.point == "TOP" and party.attrs.yOffset == -2,
    "default size and a column of members")
  check(party.attrs.showPlayer == true and party.attrs.showSolo == nil, "yourself in the party, not alone")

  -- Group titles only over groups with someone in them (1.27.1: all nine showed when alone).
  do
    local oldInGroup = IsInGroup
    local function shown(h) return R.titles[h]:IsShown() and true or false end
    IsInGroup = function() return false end
    R:UpdateTitles()
    local any = false
    for _, t in pairs(R.titles) do any = any or t:IsShown() end
    check(not any, "no group titles when you're alone")
    R:Set().showSolo = true
    R:UpdateTitles()
    check(shown(party) and not shown(VoltUIRaidGroup1), "alone with Show when you're alone: just the party title")
    R:Set().showSolo = false
    IsInGroup = function() return true end
    R:UpdateTitles()
    check(shown(party) and not shown(VoltUIRaidGroup1) and not shown(g3), "in a party: the party title only")
    IsInRaid = function() return true end
    GetRaidRosterInfo = function(i)
      if i == 1 then return "A", 0, 1 elseif i == 2 then return "B", 0, 3 end
    end
    R:UpdateTitles()
    check(not shown(party) and shown(VoltUIRaidGroup1) and not shown(VoltUIRaidGroup2) and shown(g3) and not shown(VoltUIRaidGroup8),
      "in a raid: titles for groups 1 and 3, where people are")
    R:Set(R:SetName("raid")).titles = false
    R:UpdateTitles()
    check(not shown(VoltUIRaidGroup1) and not shown(g3), "group titles off: none")
    R:Set(R:SetName("raid")).titles = true
    IsInRaid = function() return false end
    GetRaidRosterInfo = saved.GetRaidRosterInfo
    IsInGroup = oldInGroup
    R:UpdateTitles()
  end

  -- Member buttons, as the game makes them.
  local made = 0
  local function spawn(header, unit)
    made = made + 1
    local name = "VoltUITestTile" .. made
    local b = CreateFrame("Button", name, header, "SecureUnitButtonTemplate")
    b.attrs = { ["*type1"] = "target", ["*type2"] = "togglemenu" }
    for k, v in pairs(header.attrs or {}) do
      local a = type(k) == "string" and k:match("^_initialAttribute%-(.+)$")
      if a then b.attrs[a] = v end
    end
    b:SetSize(header.attrs["volt-width"], header.attrs["volt-height"])
    header.kInit(header, name)
    b.attrs.unit = unit
    b.scripts.OnAttributeChanged(b, "unit", unit)
    return b
  end
  AURAS.party1 = {
    { id = 11, icon = "i11", kind = "Magic" },               -- not yours to remove
    { id = 12, icon = "i12", kind = "Poison" },              -- yours: the game's filter missed it
    { id = 13, icon = "i13", game = true },                  -- the game says you can
  }
  local me, tank, dead, off, far = spawn(party, "player"), spawn(party, "party1"), spawn(party, "party2"), spawn(party, "party3"), spawn(party, "party4")
  check(R.tiles[tank] and tank.clicks and tank.clicks[1] == "AnyUp" and ClickCastFrames[tank], "dressed: clicks, and click-cast add-ons can see it")
  check(tank.khp.value == 900 and tank.khp.maxv == 1000, "health")
  check(tank.kheal.value == 50 and tank.kshield.value == 20 and tank.kheal.maxv == 1000, "incoming heals and shields after the health")
  check(tank.khp.fillTex.vc[1] == 1 and tank.khp.fillTex.vc[2] == 0.96, "class colour")
  check(tank.kname.text == "Brakka", "the realm goes from the name")
  check(dead.kstatus.text == "Dead" and off.kstatus.text == "Offline", "Dead and Offline")
  check(off.khp.fillTex.vc[1] == 0.5, "offline is grey")
  check(me.kshowPower and not tank.kshowPower, "power bar for healers only, by default")
  check(tank.kaggro.alpha == 1 and me.kaggro.alpha == 0, "aggro glow on the tank")
  check(far.alpha == 0.5 and tank.alpha == 1 and me.alpha == 1 and rangeAsked > 0, "out of your heal range fades")
  check(tank.krole.alpha == 1, "role icon")

  -- Debuffs: removable first (the game's filter or your own dispels), bigger, by type.
  local icons = tank.kdebuffs
  check(icons[1].shown and icons[1].tex.tex == "i12" and icons[2].tex.tex == "i13" and icons[3].tex.tex == "i11",
    "removable first: your own poison cure counts as well as the game's filter")
  check(icons[1].edges[1].ctex[2] == 0.6 and icons[1].edges[1].ctex[1] == 0, "framed in the poison colour")
  check(icons[3].edges[1].ctex[1] == 0.05, "a debuff you can't remove has a dark frame")
  check(icons[1].w == 20 and icons[3].w == 14, "bigger when you can remove it")
  check(icons[1].count.text == "3" and icons[1].cd.cooldownObj.dur == 12, "stacks and time left from the game")
  check(tank.kremovableCount == 2, "two you can remove")
  local c = R:Set("party")
  c.onlyRemovable = true
  fire("UNIT_AURA", "party1")
  check(icons[1].shown and icons[2].shown and not icons[3].shown, "only removable ones")
  c.onlyRemovable, c.debuffCount = false, 1
  fire("UNIT_AURA", "party1")
  check(icons[1].shown and not icons[2].shown, "how many")
  c.debuffCount, c.debuffs = 3, false
  fire("UNIT_AURA", "party1")
  check(not icons[1].shown, "debuffs off")
  c.debuffs = true
  fire("UNIT_AURA", "party1")

  -- Events
  G.party1.hp = 400
  fire("UNIT_HEALTH", "party1")
  check(tank.khp.value == 400, "health follows")
  targetUnit = "party1"
  fire("PLAYER_TARGET_CHANGED")
  check(tank.kglow.edges[1].ctex[1] == S.ACCENT[1] and tank.kglow.edges[1].ctex[4] == 1, "blue border on your target")
  targetUnit = nil
  fire("PLAYER_TARGET_CHANGED")
  check(tank.kglow.edges[1].ctex[4] == 0.6, "and off again")
  tank.scripts.OnEnter(tank)
  check(tank.kglow.edges[1].ctex[1] == 1 and tank.kglow.edges[1].ctex[4] == 0.85, "white under the mouse")
  tank.scripts.OnLeave(tank)

  -- Settings
  c.hpText = "missing"
  R:Apply()
  check(me.kstatus.text == "-100", "missing health")
  G.player.hp = 400
  fire("UNIT_HEALTH", "player")
  check(me.kstatus.text == "", "nothing at full health")
  G.player.hp = 300
  c.hpText = "percent"
  R:Apply()
  check(me.kstatus.text == "75%", "percent")
  c.hpText = "off"
  c.hpColor = "custom"
  c.customColor = { 0.9, 0.1, 0.2 }
  R:Apply()
  check(tank.khp.fillTex.vc[1] == 0.9 and tank.khp.fillTex.vc[3] == 0.2, "your own colour")
  c.hpColor = "dark"
  R:Apply()
  check(tank.khp.fillTex.vc[1] == 0.13 and tank.ktrack.ctex[1] == 1 and tank.ktrack.ctex[4] == 0.85, "dark: the missing part in class colour")
  c.hpColor = "class"
  c.power = "all"
  R:Apply()
  check(tank.kshowPower and tank.kpw.shown and tank.kpw.h == 4, "power bar for everyone")
  c.power = "healers"
  c.width, c.height = 90, 44
  R:Apply()
  check(party.attrs["volt-width"] == 90 and tank.w == 90 and tank.h == 44, "width and height, on new and existing members")
  c.layout, c.sort = "rows", "role"
  R:Apply()
  check(party.attrs.point == "LEFT" and party.attrs.xOffset == 2 and party.attrs.groupBy == "ASSIGNEDROLE", "groups as rows, sorted by role")
  c.layout, c.sort, c.width, c.height = "columns", "group", 72, 36
  c.heals = false
  R:Apply()
  check(tank.kheal.value == 0, "incoming heals off")
  c.heals = true
  c.rangeAlpha = 0.3
  R:Apply()
  check(far.alpha == 0.3, "out of range opacity")
  R.rangeSpell = nil
  rangeAsked = 0
  R:UpdateRange(far)
  check(far.alpha == 0.3 and rangeAsked == 0, "no heal spell: the game's own range check")
  R:FindRangeSpell()
  c.rangeAlpha = 0.5

  -- Combat: nothing secure is touched; layout waits for the fight to end.
  inCombat = true
  local touched = {}
  local orig = party.SetAttribute
  party.SetAttribute = function(self, k, v) touched[#touched + 1] = k; orig(self, k, v) end
  c.width = 80
  R:Apply()
  check(#touched == 0 and R.applyPending, "layout waits for combat to end")
  local late = spawn(party, "party4")
  check(R.pendingClicks[late] and not late.clicks, "someone joining mid-fight: clicks wait too")
  check(late.khp.value == 250, "but their frame works straight away")
  fire("PLAYER_REGEN_DISABLED")
  inCombat = false
  fire("PLAYER_REGEN_ENABLED")
  check(not R.applyPending and party.attrs["volt-width"] == 80 and late.clicks and late.clicks[1] == "AnyUp", "then it's put in place")
  party.SetAttribute = orig
  c.width = 72
  R:Apply()

  -- Secret values: straight into the widgets, never compared.
  local SecretMeta = {}
  local function boom() error("a secret value was used in Lua", 2) end
  for _, m in ipairs({ "__add", "__sub", "__mul", "__div", "__mod", "__unm", "__concat", "__len", "__lt", "__le", "__call", "__index", "__newindex" }) do SecretMeta[m] = boom end
  local function Secret() return setmetatable({}, SecretMeta) end
  issecretvalue = function(v) return getmetatable(v) == SecretMeta end
  local sHp, sMax, sMiss, sRange, sThreat = Secret(), Secret(), Secret(), Secret(), Secret()
  UnitHealth, UnitHealthMax, UnitHealthMissing = function() return sHp end, function() return sMax end, function() return sMiss end
  UnitInRange = function() return sRange, Secret() end
  UnitThreatSituation = function() return sThreat end
  UnitGetIncomingHeals, UnitGetTotalAbsorbs = function() return Secret() end, function() return Secret() end
  local truncated
  C_StringUtil = {
    RoundToNearestString = function(v) return v end,
    TruncateWhenZero = function(v) truncated = v; return "t" end,
    WrapString = function(s, pre) return pre .. s end,
  }
  C_UnitAuras.GetAuraDataByAuraInstanceID = function() return { icon = Secret(), dispelName = Secret() } end
  local curvePoints = {}
  C_CurveUtil = { CreateColorCurve = function() return { SetType = function() end, AddPoint = function(_, x, col) curvePoints[x] = col end } end }
  R.rangeSpell = nil
  c.hpText = "missing"
  local ok, err = pcall(function()
    R:Apply()
    fire("UNIT_HEALTH", "party1")
    fire("UNIT_AURA", "party1")
    fire("UNIT_THREAT_SITUATION_UPDATE", "party1")
    R:ForAll("UpdateRange")
  end)
  check(ok, "secret health, range, threat and auras: no errors: " .. tostring(err))
  check(tank.khp.value == sHp and tank.khp.maxv == sMax, "secret health goes straight into the bar")
  check(truncated == sMiss and tank.kstatus.text == "-t", "secret missing health: the game leaves it empty at full")
  check(tank.alphaFrom and tank.alphaFrom[1] == sRange and tank.alphaFrom[3] == 0.5, "secret range fades through the game")
  check(tank.kaggro.alpha == sThreat, "secret threat is the aggro glow's opacity")
  check(icons[1].tex.tex ~= nil and issecretvalue(icons[1].tex.tex) and icons[1].tex.tex ~= "i12", "secret icons still show")
  check(tank.kdebuffs[1].shown and tank.kremovableCount == 1, "a secret debuff type: only the game's answer counts")
  check(icons[1].edges[1].vc and icons[1].edges[1].vc[3] == 1, "and its frame is coloured through the game's colour curve")
  check(curvePoints[4] and curvePoints[4].g == 0.6 and curvePoints[1].b == 1, "the curve: poison green, magic blue")
  issecretvalue = nil
  for _, k in ipairs({ "UnitHealth", "UnitHealthMax", "UnitHealthMissing", "UnitInRange", "UnitThreatSituation",
    "UnitGetIncomingHeals", "UnitGetTotalAbsorbs" }) do _G[k] = nil end
  UnitHealth = function(u) return info(u).hp or 100 end
  UnitHealthMax = function(u) return info(u).hpMax or 100 end
  UnitHealthMissing = function(u) return (info(u).hpMax or 100) - (info(u).hp or 100) end
  UnitInRange = function(u) return not info(u).far, true end
  UnitThreatSituation = function(u) return info(u).threat or 0 end
  UnitGetIncomingHeals = function(u) return info(u).heals or 0 end
  UnitGetTotalAbsorbs = function(u) return info(u).shields or 0 end
  C_UnitAuras.GetAuraDataByAuraInstanceID = function(u, id) local a = aura(u, id); if a then return { icon = a.icon, dispelName = a.kind } end end
  c.hpText = "off"
  R:FindRangeSpell()

  -- The game's own frames go, out of combat only.
  PartyFrame = new("Frame", "PartyFrame")
  PartyFrame.MemberFrame1 = new("Button")
  PartyFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
  CompactRaidFrameManager = new("Frame", "CompactRaidFrameManager")
  CompactRaidFrameManager:RegisterEvent("GROUP_ROSTER_UPDATE")
  unitWatch[PartyFrame.MemberFrame1] = true
  wipe(R.hiddenGame)
  inCombat = true
  R:HideGame()
  check(R.hidePending and PartyFrame.parent == nil, "the game's frames wait for combat to end")
  inCombat = false
  fire("PLAYER_REGEN_ENABLED")
  check(PartyFrame.parent == S.HiddenParent() and PartyFrame.allOff and CompactRaidFrameManager.parent == S.HiddenParent(),
    "then the game's party frames and raid manager go under a hidden parent and stop listening")
  check(PartyFrame.MemberFrame1.parent == S.HiddenParent() and not unitWatch[PartyFrame.MemberFrame1], "its member frames too")
  PartyFrame, CompactRaidFrameManager = nil, nil

  -- Settings from the old restyle move over once.
  R.cfg = nil
  local keep = VoltUIDB.raidCfg
  VoltUIDB.raidCfg = nil
  VoltUIDB.groupCfg = { hpColor = "game", nameScale = 1.4, manager = "hover", aggro = false }
  VoltUIDB.groupsRaid = true
  local moved = R:Cfg().party
  check(moved.hpColor == "class" and moved.nameScale == 1.4 and moved.aggro == false and moved.width == 72, "the old settings move to VoltUI's own frames")
  check(R:Cfg().raid.nameScale == 1.4 and R:Cfg().raid.aggro == false, "raid frames get them too")
  check(VoltUIDB.groupCfg == nil and VoltUIDB.groupsRaid == nil and R:Cfg().moved, "and the old ones go")
  -- 1.27's two sets (one for party and raid, one for heal mode) each become a party and a raid set.
  R.cfg = nil
  VoltUIDB.raidCfg = { moved = true, healMode = "on", normal = { width = 80, hpColor = "custom", customColor = { 0.1, 0.2, 0.3 } },
    heal = { width = 99, hpText = "percent" } }
  local split = R:Cfg()
  check(split.normal == nil and split.heal == nil and split.party.width == 80 and split.raid.width == 80
    and split.healParty.width == 99 and split.healRaid.width == 99 and split.healRaid.hpText == "percent",
    "1.27's sets become party and raid sets, starting the same")
  check(split.party.customColor[3] == 0.3 and split.party.customColor ~= split.raid.customColor and split.healMode == "on",
    "each with its own colour, and heal mode's own settings stay")
  check(split.party.gap == 2 and split.healParty.power == "all", "and anything missing filled in")
  VoltUIDB.raidCfg = keep
  R.cfg = nil
  c = R:Set("party")

  -- Party frames and raid frames each have their own set.
  local rc = R:Set("raid")
  check(rc ~= c and R:SetName() == "party" and R:SetName("raid") == "raid" and R:Kind() == "party", "out of a raid: the party set")
  rc.width, rc.layout = 60, "rows"
  R:Apply()
  check(party.attrs["volt-width"] == c.width and party.attrs.point == "TOP" and g3.attrs["volt-width"] == 60 and g3.attrs.point == "LEFT",
    "the party header takes the party set, the raid groups the raid set")
  check(tank.w == c.width, "and so do their members")
  rc.width, rc.layout = 72, "columns"
  IsInRaid = function() return true end
  R:Apply()
  check(R:Kind() == "raid" and R:SetName() == "raid", "in a raid: the raid set")
  inCombat = true
  IsInRaid = function() return false end
  R:Apply() -- what GROUP_ROSTER_UPDATE does (the event would also switch heal mode on here)
  check(R:Kind() == "raid" and R.applyPending, "leaving a raid in a fight: the switch waits")
  inCombat = false
  fire("PLAYER_REGEN_ENABLED")
  check(R:Kind() == "party" and not R.applyPending, "and happens when it ends")

  -- Preview
  check(VoltUIRaidPreview == nil, "no preview until asked for")
  R:Simulate("raid10", true)
  local box = VoltUIRaidPreview
  local shown = 0
  for _, f in ipairs(R.simTiles) do if f.shown then shown = shown + 1 end end
  check(box and box.shown and shown == 10 and R.holder.alpha == 0, "ten made-up members where the frames go, the real ones aside")
  check(R.simTiles[6].kstatus.text == "Dead" and R.simTiles[3].kdebuffs[1].shown, "with the dead and debuffs")
  check(R.simTiles[2].koverheal.alpha == 1 and R.simTiles[2].koverabsorb.alpha == 1 and R.simTiles[3].koverheal.alpha == 0, "and overhealing")
  check(R.simTitles[2].text == "Group 2", "group titles")
  rc.width = 100
  R:Apply()
  check(R.simTiles[1].w == 100, "a raid preview follows the raid frames' settings")
  rc.width = 72
  fire("PLAYER_REGEN_DISABLED")
  check(not box.shown and R.holder.alpha == 1 and R.sim == nil, "a fight closes it")
  R:Apply()

  -- The settings window
  inCombat = false
  wipe(chat)
  SlashCmdList.VOLTUI("groups options")
  local E = ns.EditMode
  check(VoltUISettings.shown and E.tab == "party", "/volt groups options opens the party frames page out of a raid")
  check(ns.Pages.byKey.party.needs == "Raid" and ns.Pages.byKey.raid.needs == "Raid", "a page for party frames and one for raid frames")
  local function grow(key)
    for _, r in ipairs(E.rows) do if r.def and r.def.key == key then return r end end
    error("no row " .. key)
  end
  grow("width"):Step(1)
  check(c.width == 73 and party.attrs["volt-width"] == 73, "the width row changes the frames as you click")
  grow("power"):Step(1)
  check(c.power == "all" and tank.kshowPower, "the power row")
  grow("sim"):Set("party")
  check(R.sim == "party" and VoltUIRaidPreview.shown, "the preview row")
  E:Reset(); E:Reset()
  local d = R:Set("party")
  check(d.width == 72 and d.power == "healers", "Reset these: back to the defaults")
  local function pageRow(key)
    for _, r in ipairs(E.rows) do if r.def and r.def.key == key and r.shown ~= false then return true end end
    return false
  end
  check(pageRow("showSolo") and pageRow("showPlayer") and not pageRow("groupGap"), "the party page: yourself and alone, no gap between groups")
  E:Select("raid")
  check(E.tab == "raid" and pageRow("groupGap") and not pageRow("showSolo") and not pageRow("showPlayer"), "the raid page: groups, not party rows")
  grow("width"):Step(1)
  check(rc.width == 73 and g3.attrs["volt-width"] == 73 and R:Set("party").width == 72 and party.attrs["volt-width"] == 72,
    "the raid page changes raid frames only")
  local froms = ns.Pages.byKey.raid.copy()
  check(#froms == 3 and froms[1].key == "party" and froms[1].get({ key = "width" }) == 72, "the raid page copies from the other three sets")
  grow("sim"):Set("raid25")
  check(R.sim == "raid25" and R.simSet == "raid", "its preview is a raid")
  E:Reset(); E:Reset()
  check(R:Set("raid").width == 72 and R:Set("party") == d, "Reset the raid page, not the party one")
  E:Select("party")
  E:Close()
  check(not VoltUIRaidPreview.shown, "the preview closes with the window")
  wipe(chat)
  SlashCmdList.VOLTUI("party")
  check(chat[1] and chat[1]:find("member frames", 1, true), "/volt party reports")
  SlashCmdList.VOLTUI("groups test 25")
  check(R.sim == "raid25", "/volt groups test 25")
  SlashCmdList.VOLTUI("groups test off")
  check(R.sim == nil, "/volt groups test off")
  wipe(chat)
  -- Overhealing
  G.party1.hp, G.party1.hpMax, G.party1.heals, G.party1.shields = 900, 1000, 150, 0
  fire("UNIT_HEALTH", "party1")
  check(tank.koverheal.alpha == 1 and tank.koverabsorb.alpha == 0, "overhealing: more heals coming than health missing")
  G.party1.heals, G.party1.shields = 50, 80
  fire("UNIT_HEALTH", "party1")
  check(tank.koverheal.alpha == 0 and tank.koverabsorb.alpha == 1, "shields past full health")
  R:Set("party").overheal = false
  fire("UNIT_HEALTH", "party1")
  check(tank.koverabsorb.alpha == 0, "overhealing off")
  R:Set("party").overheal = true
  -- With the game's heal calculator: heals cut to what's missing, and its own overheal answer.
  local modes = {}
  local SM = {}
  local secretOver = setmetatable({}, SM)
  local over
  CreateUnitHealPredictionCalculator = function()
    return {
      SetIncomingHealClampMode = function(_, m) modes.heal = m end,
      SetIncomingHealOverflowPercent = function(_, p) modes.overflow = p end,
      SetDamageAbsorbClampMode = function(_, m) modes.shield = m end,
      GetIncomingHeals = function() return 100, 100, 0, over end,
      GetDamageAbsorbs = function() return 0, false end,
    }
  end
  UnitGetDetailedHealPrediction = function() end
  over = true
  fire("UNIT_HEALTH", "party1")
  check(modes.heal == 0 and modes.shield == 0 and modes.overflow == 1, "the calculator cuts heals and shields to the health missing")
  check(tank.kheal.value == 100 and tank.koverheal.alpha == 1, "and says when there's overhealing")
  issecretvalue = function(v) return getmetatable(v) == SM end
  over = secretOver
  fire("UNIT_HEALTH", "party1")
  check(tank.koverheal.alphaFrom and tank.koverheal.alphaFrom[1] == secretOver, "a secret overheal answer shows through the game")
  issecretvalue = nil
  CreateUnitHealPredictionCalculator, UnitGetDetailedHealPrediction = nil, nil
  G.party1.heals, G.party1.shields = 50, 20

  -- Heal mode
  C_Spell.GetSpellName = function(id)
    return ({ [8004] = "Lesser Healing Wave", [331] = "Healing Wave", [1064] = "Chain Heal", [526] = "Cure Poison",
      [2870] = "Cure Disease", [2008] = "Ancestral Spirit", [974] = "Earth Shield" })[id]
  end
  local cfg = R:Cfg()
  check(cfg.healMode == "auto" and cfg.healParty.width == 84 and cfg.healParty.hpText == "missing" and cfg.healParty.power == "all"
    and cfg.healRaid.width == 84, "heal mode has its own sets, party and raid, made for healing")
  check(not R:HealOn() and R:SetName() == "party" and tank.attrs.type1 == nil, "off until your role is healer; plain clicks")
  fire("PLAYER_ROLES_ASSIGNED")
  check(R:HealOn() and party.attrs["volt-width"] == 84 and tank.w == 84 and me.kstatus.text == "-100" and tank.kshowPower,
    "auto: your role is healer, so heal mode, with its own size, missing health and power bars")
  check(chat[#chat]:find("Heal mode", 1, true), "it says so")
  -- A shaman's ready-made clicks, by spell name.
  local a = tank.attrs
  check(a.type1 == "spell" and a.spell1 == "Lesser Healing Wave" and a.type2 == "spell" and a.spell2 == "Healing Wave", "left and right heal")
  check(a["ctrl-spell1"] == "Chain Heal" and a.spell3 == "Cure Poison" and a["shift-spell3"] == "Cure Disease" and a["alt-spell1"] == "Ancestral Spirit",
    "Ctrl, middle, Shift+middle, Alt")
  check(a["shift-type1"] == "macro" and a["shift-macrotext1"] == "/target [@mouseover]" and a["shift-type2"] == "togglemenu",
    "Shift+Left targets (by macro: the game gates targeting to its own click bindings), Shift+Right opens the menu")
  check(party.attrs["_initialAttribute-spell1"] == "Lesser Healing Wave" and party.attrs._initialAttributeNames:find("shift-type1", 1, true),
    "the headers hold them for anyone who joins")
  check(party.attrs._ignore == nil, "and lay themselves out once afterwards")
  inCombat = true
  local joined = spawn(party, "party4")
  check(joined.attrs.spell1 == "Lesser Healing Wave" and joined.attrs["alt-spell1"] == "Ancestral Spirit", "someone joining mid-fight gets them from the header")
  inCombat = false
  fire("PLAYER_REGEN_ENABLED")
  -- Changing clicks
  R:SetBinding("1", { kind = "spell", value = "Healing Wave(Rank 2)" })
  check(a.spell1 == "Healing Wave(Rank 2)" and type(cfg.clicks.SHAMAN) == "table" and cfg.clicks.SHAMAN["2"].spell == 331,
    "a typed spell with its rank; the ready-made ones are kept beside it")
  R:SetBinding("2", { kind = "none" })
  check(a.type2 == "" and a.spell2 == nil, "a click set to nothing does nothing")
  R:SetBinding("4", { kind = "macro", value = "/cast [@mouseover] Healing Wave" })
  check(a.type4 == "macro" and a.macrotext4 == "/cast [@mouseover] Healing Wave", "button 4 runs a macro")
  R:SetBinding("4", { kind = "focus" })
  check(a.type4 == "focus" and a.macrotext4 == nil, "and its old text goes")
  inCombat = true
  R:SetBinding("ctrl-shift-5", { kind = "target" })
  check(R.clicksPending and a["ctrl-shift-type5"] == nil, "a change in combat waits")
  inCombat = false
  fire("PLAYER_REGEN_ENABLED")
  check(a["ctrl-shift-type5"] == "macro", "then it's put on")
  R:SetBinding("5", { kind = "target" })
  check(a.type5 == "target" and a.macrotext5 == nil, "a plain click targets the game's way")
  check(R:ComboName("alt-ctrl-3") == "Ctrl+Alt+Middle" and R:Describe(R:GetBinding("4")) == "Focus", "names for the list")
  check(R:MacroExample():find("[@mouseover,help,nodead]", 1, true) and R:MacroExample():find("Healing Wave(Rank 2)", 1, true), "a mouseover macro with your spell")
  R:UseDefaultClicks()
  check(a.spell1 == "Lesser Healing Wave" and a.type4 == nil and cfg.clicks.SHAMAN == nil, "back to the ready-made clicks")
  C_ClickBindings = { GetProfileInfo = function() return { {}, {} } end }
  check(R:GameClickBindings() == 2, "the game's own click casting is noticed")
  C_ClickBindings = nil

  -- Switching by hand, and never mid-fight.
  wipe(chat)
  SlashCmdList.VOLTUI("heal")
  check(not R:HealOn() and cfg.healMode == "off" and party.attrs["volt-width"] == 72 and a.type1 == nil, "/volt heal: off, normal size, plain clicks")
  cfg.clicksWhen = "always"
  R:ApplyClicks()
  check(a.spell1 == "Lesser Healing Wave", "clicks can work outside heal mode too")
  cfg.clicksWhen = "heal"
  R:ApplyClicks()
  inCombat = true
  SlashCmdList.VOLTUI("heal")
  check(not R:HealOn() and R.healPending and party.attrs["volt-width"] == 72, "in combat it waits")
  inCombat = false
  fire("PLAYER_REGEN_ENABLED")
  check(R:HealOn() and party.attrs["volt-width"] == 84, "and switches when the fight ends")
  SlashCmdList.VOLTUI("heal auto")
  G.player.role = "DAMAGER"
  fire("PLAYER_ROLES_ASSIGNED")
  check(not R:HealOn(), "auto follows your role")
  G.player.role = "HEALER"
  fire("PLAYER_ROLES_ASSIGNED")
  check(R:HealOn(), "both ways")

  -- The pages
  SlashCmdList.VOLTUI("heal options")
  check(VoltUISettings.shown and E.tab == "heal", "/volt heal options opens heal mode's page")
  grow("width"):Step(1)
  check(cfg.healParty.width == 85 and R:Set("party").width == 72 and party.attrs["volt-width"] == 85 and cfg.healRaid.width == 84,
    "heal mode's rows change heal mode's party set (out of a raid)")
  local function hasRow(key)
    for _, r in ipairs(E.rows) do if r.def and r.def.key == key and r.shown ~= false then return true end end
    return false
  end
  check(hasRow("hpText") and hasRow("overheal") and hasRow("onlyRemovable") and hasRow("power") and not hasRow("layout") and not hasRow("gap")
    and not hasRow("nameScale"), "heal mode's page is short: just what matters for healing")
  grow("heals"):Step(1)
  check(cfg.healParty.heals == false and cfg.healParty.shields == false, "one switch for incoming heals and shields")
  grow("heals"):Step(1)
  check(cfg.healParty.heals and cfg.healParty.shields, "and back")
  grow("healAll"):Step(1)
  check(cfg.healAll and E.tab == "heal" and hasRow("layout") and hasRow("gap") and hasRow("nameScale") and hasRow("healAll"),
    "Show every setting: the full list, for heal mode's set")
  grow("healAll"):Step(1)
  check(not cfg.healAll and not hasRow("layout") and hasRow("width"), "and back to the short one")
  local froms = ns.Pages.byKey.heal.copy()
  check(#froms == 3 and froms[1].key == "party" and froms[2].key == "raid" and froms[3].key == "healRaid"
    and froms[1].get({ key = "width" }) == 72, "heal mode's party set copies from the other three")
  -- Its raid set, on the same page.
  check(hasRow("healEdit"), "a Party | Raid switch")
  grow("healEdit"):Set("raid")
  check(E.tab == "heal" and cfg.healEdit == "raid" and hasRow("width"), "switched to heal mode's raid set")
  grow("width"):Step(1)
  check(cfg.healRaid.width == 85 and cfg.healParty.width == 85 and VoltUIRaidGroup3.attrs["volt-width"] == 85, "its rows change the raid set")
  grow("width"):Step(-1)
  check(cfg.healRaid.width == 84 and ns.Pages.byKey.heal.copy()[3].key == "healParty", "and it copies from heal mode's party set")
  grow("sim"):Set("raid10")
  check(R.sim == "raid10" and R.simSet == "healRaid", "its preview is a raid in heal mode's raid set")
  grow("healEdit"):Set("party")
  check(cfg.healEdit == "party", "and back to party")
  grow("healMode"):Set("off")
  check(not R:HealOn() and party.attrs["volt-width"] == 72, "heal mode switched off on its page")
  grow("healMode"):Set("auto")
  check(R:HealOn(), "and back to auto")
  E:Reset(); E:Reset()
  check(cfg.healParty.width == 84, "Reset puts heal mode's party set back")
  SlashCmdList.VOLTUI("heal clicks")
  check(E.tab == "clicks", "/volt heal clicks opens the clicks page")
  grow("pickButton"):Set("2")
  grow("pickMod"):Set("ctrl-")
  grow("action"):Set("spell")
  check(R:GetBinding("ctrl-2").kind == "spell" and a.type2 == "spell" and a["ctrl-type2"] == "spell", "pick a click and give it a spell")
  grow("spell"):Set(331)
  check(a["ctrl-spell2"] == "Healing Wave", "from the spells you know")
  local typed
  for _, r in ipairs(E.rows) do if r.typed then typed = r end end
  check(typed ~= nil, "a box to type a spell or macro")
  typed.box.edit:SetText("Healing Wave(Rank 3)")
  typed.box.edit.scripts.OnTextChanged(typed.box.edit, true)
  check(a["ctrl-spell2"] == "Healing Wave(Rank 3)", "a typed spell with its rank")
  grow("action"):Set("macro")
  typed.box.edit:SetText("/cast Chain Heal")
  typed.box.edit.scripts.OnTextChanged(typed.box.edit, true)
  check(a["ctrl-type2"] == "macro" and a["ctrl-macrotext2"] == "/cast Chain Heal", "or a macro")
  inCombat = true
  grow("pickButton"):Set("3")
  check(R.pickButton == "3", "picking a click still works in combat")
  grow("action"):Set("target")
  check(R:GetBinding("3").kind == "spell", "changing one doesn't")
  inCombat = false
  E:Reset(); E:Reset()
  check(cfg.clicks.SHAMAN == nil and a.spell1 == "Lesser Healing Wave", "Reset gives the ready-made clicks back")

  -- Picking clicks from your healing spells
  C_Spell.GetSpellTexture = function(id) return "icon" .. tostring(id) end
  local spells = R:HealerSpells()
  local names = {}
  for _, sp in ipairs(spells) do names[#names + 1] = sp.name end
  check(table.concat(names, ",") == "Healing Wave,Cure Poison,Cure Disease" and spells[1].icon == "icon331",
    "without the spellbook functions: the healing spells you know from VoltUI's list")
  local SBOOK = {
    { name = "General", itemIndexOffset = 0, numSpellBookItems = 1, isGuild = false, shouldHide = false },
    { name = "Shaman", itemIndexOffset = 1, numSpellBookItems = 7, isGuild = false, shouldHide = false },
    { name = "Guild", itemIndexOffset = 8, numSpellBookItems = 1, isGuild = true, shouldHide = false },
    { name = "Other spec", itemIndexOffset = 9, numSpellBookItems = 1, isGuild = false, shouldHide = false, offSpecID = 3 },
  }
  local ITEMS = {
    { itemType = 1, spellID = 6603, name = "Attack", iconID = 1 },
    { itemType = 1, spellID = 403, name = "Lightning Bolt", iconID = 2 },
    { itemType = 1, spellID = 331, name = "Healing Wave", iconID = 3 },
    { itemType = 1, spellID = 324, name = "Lightning Shield", iconID = 4 },
    { itemType = 1, spellID = 99001, name = "Tidal Mend", iconID = 5 },
    { itemType = 1, spellID = 99002, name = "Ancestral Grace", iconID = 6, isPassive = true },
    { itemType = 4, actionID = 7, name = "Totems", iconID = 7 },
    { itemType = 1, spellID = 1064, name = "Chain Heal", iconID = 8, isOffSpec = true },
    { itemType = 1, spellID = 99003, name = "Guild Mend", iconID = 9 },
    { itemType = 1, spellID = 99004, name = "Off Mend", iconID = 10 },
  }
  local HELPFUL = { [331] = true, [324] = true, [99001] = true, [99002] = true, [99003] = true, [99004] = true, [6603] = false }
  C_SpellBook = {
    GetNumSpellBookSkillLines = function() return #SBOOK end,
    GetSpellBookSkillLineInfo = function(i) return SBOOK[i] end,
    GetSpellBookItemInfo = function(slot) return ITEMS[slot] end,
  }
  C_Spell.IsSpellHelpful = function(id) return HELPFUL[id] == true end
  local bookName = C_Spell.GetSpellName
  C_Spell.GetSpellName = function(id) return id == 99001 and "Tidal Mend" or bookName(id) end
  C_Spell.IsSelfBuff = function(id) return id == 324 end
  C_Spell.SpellHasRange = function(id) return id ~= 6603 end
  spells = R:HealerSpells()
  names = {}
  for _, sp in ipairs(spells) do names[#names + 1] = sp.name end
  check(table.concat(names, ",") == "Healing Wave,Tidal Mend,Cure Poison,Cure Disease" and spells[2].icon == 5 and spells[2].key == 99001,
    "from the spellbook: helpful spells you cast on others (a server's own too); not damage, self buffs, passives, guild or the other spec")
  check(R:SpellChoices()[2].name == "Tidal Mend", "the Clicks page's spell stepper offers the same spells")

  SlashCmdList.VOLTUI("heal options")
  local slots = {}
  for _, r in ipairs(E.rows) do if r.slot then slots[#slots + 1] = r end end
  check(#slots == 10 and slots[1].def.label == "Left click" and slots[4].def.label == "Shift+Right click" and slots[10].def.label == "Shift+Middle click",
    "the Heal mode page shows ten clicks, each with its slot")
  local left, shiftLeft, shiftRight, ctrlRight = slots[1].slot, slots[3].slot, slots[4].slot, slots[6].slot
  check(left.text.text == "Lesser Healing Wave" and left.icon.tex == "icon8004", "a slot shows its spell's name and icon")
  check(shiftLeft.text.text == "Target" and shiftRight.text.text == "Menu", "and what a click does when it isn't a spell")
  left.scripts.OnClick(left, "LeftButton")
  local pk = ns.Pages.picker
  check(pk and pk.shown and pk.slot == left and pk.title.text == "Left click", "clicking a slot opens the list of your healing spells")
  local items = {}
  for _, it in ipairs(pk.items) do if it.shown then items[#items + 1] = it end end
  check(#items == 7 and items[1].text.text == "Healing Wave" and items[1].icon.tex == 3 and items[5].text.text == "Target"
    and items[7].text.text == "Clear", "spells with their icons, then Target, Menu and Clear")
  left.scripts.OnClick(left, "LeftButton")
  check(not pk.shown, "a second click closes it")
  ctrlRight.scripts.OnClick(ctrlRight, "LeftButton")
  items = {}
  for _, it in ipairs(pk.items) do if it.shown then items[#items + 1] = it end end
  items[2].scripts.OnClick(items[2])
  check(not pk.shown and R:GetBinding("ctrl-2").spell == 99001 and a["ctrl-spell2"] == "Tidal Mend" and ctrlRight.text.text == "Tidal Mend"
    and ctrlRight.icon.tex == "icon99001", "picking one sets the click on the frames, and the slot shows it")
  check(cfg.clicks.SHAMAN["1"].spell == 8004, "the other ready-made clicks stay")
  ctrlRight.scripts.OnClick(ctrlRight, "LeftButton")
  check(pk.items[2].text.color[1] == ns.Style.UI.accent[1], "the list marks the click's spell")
  pk.items[7].scripts.OnClick(pk.items[7])
  check(R:GetBinding("ctrl-2") == nil and a["ctrl-type2"] == nil and ctrlRight.text.text == "Menu", "Clear gives the click back to the game")
  left.scripts.OnClick(left, "RightButton")
  check(R:GetBinding("1") == nil and a.spell1 == nil and left.text.text == "Target", "right-clicking a slot clears it")
  shiftLeft.scripts.OnClick(shiftLeft, "LeftButton")
  pk.slot.IsVisible = function() return false end
  pk.scripts.OnUpdate(pk)
  check(not pk.shown, "the list closes when its slot goes away")
  inCombat = true
  wipe(chat)
  shiftLeft.scripts.OnClick(shiftLeft, "LeftButton")
  check(not pk.shown and chat[1] and chat[1]:find("out of combat", 1, true), "no picking in a fight")
  shiftLeft.scripts.OnClick(shiftLeft, "RightButton")
  check(R:GetBinding("shift-1").kind == "target", "or clearing")
  inCombat = false
  SlashCmdList.VOLTUI("heal clicks")
  local grid
  for _, r in ipairs(E.rows) do if r.clickGrid then grid = r end end
  check(grid and #grid.slots == 35, "the Clicks page shows all 35 clicks")
  local cell = grid.slots[2 * 5 + 5] -- Ctrl, button 5
  check(cell.combo == "ctrl-5" and cell.text.text == "Not set", "a click with nothing on it")
  cell.scripts.OnClick(cell, "LeftButton")
  check(pk.shown and R.pickMod == "ctrl-" and R.pickButton == "5" and grow("pickButton").io.get(grow("pickButton").def) == "5",
    "opening a cell makes it the click the Edit a click card works on")
  pk.items[1].scripts.OnClick(pk.items[1])
  check(a["ctrl-spell5"] == "Healing Wave" and cell.text.text == "Healing Wave", "and picks its spell the same way")
  C_SpellBook, C_Spell.IsSpellHelpful, C_Spell.IsSelfBuff, C_Spell.SpellHasRange, C_Spell.GetSpellTexture = nil, nil, nil, nil, nil
  C_Spell.GetSpellName = bookName
  E:Reset(); E:Reset()
  check(cfg.clicks.SHAMAN == nil and a.spell1 == "Lesser Healing Wave", "Reset gives the ready-made clicks back")
  E:Close()
  SlashCmdList.VOLTUI("heal off")
  check(not R:HealOn() and cfg.healMode == "off", "/volt heal off")
  SlashCmdList.VOLTUI("heal auto")
  R.pickButton, R.pickMod = nil, nil

  -- HoTs and shields, corner buffs, dispel windows and the warning (1.27.0)
  local D, A = ns.Dispel, ns.RaidAuras
  local UA = C_UnitAuras
  local oldIds, oldData = UA.GetUnitAuraInstanceIDs, UA.GetAuraDataByAuraInstanceID
  local oldTime, oldSound = GetTime, PlaySound
  local clock, played = 100, {}
  GetTime = function() return clock end
  PlaySound = function(id) played[#played + 1] = id end
  UA.GetUnitAuraInstanceIDs = function(u, filter)
    local out = {}
    for _, au in ipairs(AURAS[u] or {}) do
      local help = au.help == true
      local kindOk = (filter:find("HELPFUL", 1, true) and help) or (filter:find("HARMFUL", 1, true) and not help)
      if kindOk and (not filter:find("PLAYER", 1, true) or au.mine) and (not filter:find("RAID_IN_COMBAT", 1, true) or au.hot) then
        out[#out + 1] = au.id
      end
    end
    return out
  end
  local locked = false
  UA.GetAuraDataByAuraInstanceID = function(u, id)
    local au = aura(u, id)
    if au then return { icon = au.icon, dispelName = au.kind, auraInstanceID = id, spellId = au.spell, name = au.name, secret = locked or nil } end
  end
  canaccesstable = function(t) return not t.secret end
  C_Spell.GetSpellTexture = function(id) return "spell" .. tostring(id) end
  check(R:HealOn(), "(heal mode is on)")
  local hs = R:Set()
  table.insert(AURAS.party1, { id = 21, icon = "renew", help = true, mine = true, hot = true })
  table.insert(AURAS.party1, { id = 22, icon = "fort", help = true, mine = true })
  table.insert(AURAS.party1, { id = 23, icon = "es", help = true, spell = 974 })
  fire("UNIT_AURA", "party1")
  check(tank.khots[1].shown and tank.khots[1].tex.tex == "renew" and not tank.khots[2].shown,
    "your HoTs on the tile; a long buff of yours isn't one")
  check(tank.khots[1].cd.cooldownObj.dur == 21 and tank.khots[1].w == 14 and tank.khots[1].points[1][1] == "BOTTOMRIGHT",
    "with its time left, at heal mode's size, from the bottom right")
  check(tank.kcorners[1].shown and tank.kcorners[1].tex.tex == "spell974" and not tank.kcorners[2].shown
    and tank.kcorners[1].points[1][1] == "TOPRIGHT", "Earth Shield from someone else in the corner")
  locked = true
  fire("UNIT_AURA", "party1")
  check(tank.kcorners[1].shown and tank.khots[1].shown, "still there when the game keeps the buffs secret (noted while it could be read)")
  table.insert(AURAS.party1, { id = 24, icon = "fw", help = true, spell = 6346 })
  fire("UNIT_AURA", "party1")
  check(not tank.kcorners[2].shown, "a corner buff first seen while secret can't be told apart")
  UA.GetUnitAuraBySpellID = function(u, sid)
    if sid == 6346 and aura(u, 24) then return { auraInstanceID = 24 } end
  end
  fire("UNIT_AURA", "party1")
  check(tank.kcorners[2].shown and tank.kcorners[2].tex.tex == "spell6346", "unless the game answers for it by spell")
  UA.GetUnitAuraBySpellID = nil
  locked = false
  hs.hots, hs.corners = false, false
  fire("UNIT_AURA", "party1")
  check(not tank.khots[1].shown and not tank.kcorners[1].shown, "both can be switched off")
  hs.hots, hs.corners = true, true
  for i = #AURAS.party1, 1, -1 do
    if AURAS.party1[i].help then table.remove(AURAS.party1, i) end
  end
  fire("UNIT_AURA", "party1")
  check(not tank.khots[1].shown and not tank.kcorners[1].shown, "and go when the buffs do")
  R:Simulate("party")
  check(R:SimTile(1).khots[1].shown and R:SimTile(1).kcorners[1].shown and R:SimTile(2).khots[1].tex.tex == 135940,
    "the preview has HoTs and corner icons")
  R:Simulate(false)

  -- Dispel windows
  local dh = VoltUIDispelHeader
  check(D.enabled and dh and dh.tmpl == "SecureGroupHeaderTemplate" and dh.attrs.showRaid and dh.attrs.showParty
    and dh.attrs.initialConfigFunction:find('CallMethod("kInit"', 1, true), "dispel windows: their own secure group header")
  check(dh.attrs["_initialAttribute-type1"] == "spell" and dh.attrs["_initialAttribute-spell1"] == "Cure Poison"
    and dh.attrs["_initialAttribute-spell2"] == "Cure Disease" and dh.shown, "left-click Cure Poison, right-click Cure Disease; shown in heal mode")
  dh.attrs["volt-width"], dh.attrs["volt-height"] = 32, 32
  local win1 = spawn(dh, "party1")
  local win2 = spawn(dh, "party2")
  check(D.tiles[win1] and win1.attrs.spell1 == "Cure Poison" and win1.clicks and win1.clicks[1] == "AnyUp", "a window per member, with both clicks")
  check(win1.alpha == 1 and win1.tex.tex == "i12" and win1.kname.text == "Brakka-Stormrage" and win1.edges[1].ctex[2] == 0.6,
    "it shows while they have something you can remove: the debuff, its colour, their name")
  check(win2.alpha == 0, "and stays clear otherwise")
  local p1 = AURAS.party1
  AURAS.party1 = {}
  fire("UNIT_AURA", "party1")
  check(win1.alpha == 0, "it goes when the debuff does")
  AURAS.party1 = p1
  fire("UNIT_AURA", "party1")
  inCombat = true
  SlashCmdList.VOLTUI("heal off")
  check(dh.shown and D.applyPending == nil and R.healPending, "nothing changes in a fight")
  inCombat = false
  fire("PLAYER_REGEN_ENABLED")
  check(not R:HealOn() and not dh.shown, "heal mode off after the fight: the windows hide")
  D:Cfg().windows = "always"
  D:Apply()
  check(dh.shown, "or always")

  -- The warning
  local warn = VoltUIDispelWarning.warnBox
  check(warn.alpha == 1 and #played == 1, "(the debuffs coming back above was news, in heal mode)")
  warn:SetAlpha(0)
  wipe(played)
  clock = clock + 5
  fire("UNIT_AURA", "party1")
  check(warn.alpha == 0 and #played == 0, "no warning for debuffs that were already there")
  D:Cfg().warn = "always"
  table.insert(AURAS.party1, { id = 14, icon = "i14", kind = "Poison", name = "Deadly Poison" })
  fire("UNIT_AURA", "party1")
  check(warn.alpha == 1 and warn.who.text == "Brakka-Stormrage" and warn.what.text == "Deadly Poison" and warn.box.tex.tex == "i14"
    and warn.how.text == "Left-click its dispel window", "a new one: who, what, and which click (the window, with clicks off)")
  check(#played == 1 and played[1] == 8959, "with the raid warning sound")
  warn:SetAlpha(0)
  fire("UNIT_AURA", "party1")
  check(warn.alpha == 0 and #played == 1, "once per debuff")
  SlashCmdList.VOLTUI("heal on")
  clock = clock + 1
  table.insert(AURAS.party1, { id = 15, icon = "i15", kind = "Disease", name = "Plague" })
  fire("UNIT_AURA", "party1")
  check(warn.what.text == "Plague" and warn.how.text == "Shift+Middle-click" and #played == 1,
    "your click that cures it; the sound waits two seconds")
  clock = clock + 3
  locked = true
  table.insert(AURAS.party1, { id = 16, icon = "i16", game = true })
  fire("UNIT_AURA", "party1")
  check(warn.how.text == "Middle-click or Shift+Middle-click" and #played == 2, "a secret type: any of your dispel clicks")
  locked = false
  warn.untilAt = clock - 1
  warn.scripts.OnUpdate(warn)
  check(warn.alpha == 0, "it fades")
  D:Cfg().warn = "off"
  table.insert(AURAS.party1, { id = 17, icon = "i17", kind = "Poison" })
  fire("UNIT_AURA", "party1")
  check(warn.alpha == 0, "the warning can be off")
  D:Cfg().warn = "heal"
  D:Cfg().sound = "alarm"
  D:Test()
  check(warn.alpha == 1 and warn.who.text == "Brakka" and played[#played] == 12889, "Test shows one, with the alarm")
  warn.untilAt = clock - 1
  warn.scripts.OnUpdate(warn)
  ns.FUI:SetUnlocked(true)
  check(VoltUIDispelFrames.mover.shown and VoltUIDispelWarning.mover.shown and warn.alpha == 1, "moving frames: both can be dragged, the warning shows made-up text")
  ns.FUI:SetUnlocked(false)
  check(not VoltUIDispelFrames.mover.shown and warn.alpha == 0, "and back")

  -- The page
  SlashCmdList.VOLTUI("heal dispel")
  check(VoltUISettings.shown and E.tab == "dispel", "/volt heal dispel opens the Dispels page")
  grow("size"):Step(1)
  check(D:Cfg().size == 33 and dh.attrs["volt-size"] == 33 and win1.w == 33, "window size")
  grow("windows"):Set("off")
  check(not dh.shown, "windows off")
  grow("sound"):Set("readycheck")
  check(D:Cfg().sound == "readycheck", "the sound")
  E:Reset(); E:Reset()
  check(D:Cfg().windows == "heal" and D:Cfg().size == 32 and D:Cfg().sound == "raidwarning", "Reset")
  E:Close()
  SlashCmdList.VOLTUI("heal auto")

  for i = #AURAS.party1, 1, -1 do
    if AURAS.party1[i].id >= 14 then table.remove(AURAS.party1, i) end
  end
  UA.GetUnitAuraInstanceIDs, UA.GetAuraDataByAuraInstanceID = oldIds, oldData
  GetTime, PlaySound = oldTime, oldSound
  canaccesstable, C_Spell.GetSpellTexture = nil, nil

  local problems = {}
  for what, e in pairs(R.reported) do problems[#problems + 1] = what .. ": " .. e end
  check(#problems == 0, "no part failed: " .. table.concat(problems, " | "))
  for _, k in ipairs(KEYS) do _G[k] = saved[k] end
  UNITS = oldUnits
  Mock.GetFont = oldGetFont
end)()

print("== Nameplates")
;(function()
  local N, S = ns.Nameplates, ns.Style
  check(N.enabled and not N.yielded, "starts when no other nameplate add-on is loaded")
  -- Most of these tests set a setting for every plate at once: the enemy and friendly sets alike,
  -- or the shared ones. The per-set tests come after, under "Enemy, friendly and your target".
  local PC = setmetatable({}, {
    __index = function(_, k)
      local c = N:Cfg()
      if N.DEFAULTS[k] ~= nil then return c[k] end
      if k == "target" then return c.target.color end
      return c.enemy[k]
    end,
    __newindex = function(_, k, v)
      local c = N:Cfg()
      local function copy(x)
        if type(x) ~= "table" then return x end
        local t = {}
        for i, y in pairs(x) do t[i] = y end
        return t
      end
      if N.DEFAULTS[k] ~= nil then
        c[k] = v
      elseif k == "target" then
        c.target.color = v
      elseif k == "classEnemy" then
        c.enemy.class = v
      elseif k == "classFriendly" then
        c.friendly.class = v
      else
        c.enemy[k], c.friendly[k] = copy(v), copy(v)
      end
    end,
  })
  local function Def(k)
    if N.DEFAULTS[k] ~= nil then return N:Default(k) end
    N:Default(k, "enemy")
    N:Default(k, "friendly")
  end
  local oldExists, oldCast, oldChan, oldSecret = UnitExists, UnitCastingInfo, UnitChannelInfo, issecretvalue
  function Mock:GetStatusBarColor() local c = self.barColor or { 1, 1, 1 }; return c[1], c[2], c[3] end
  function Mock:SetStatusBarColor(r, g, b) self.barColor = { r, g, b } end
  local SMp = {}
  local function Secret() return setmetatable({}, SMp) end
  local secretOn = function(v) return getmetatable(v) == SMp end

  local function auraItem()
    local item = new("Frame")
    item.Icon = item:CreateTexture()
    local mask = new("MaskTexture", nil, item)
    table.insert(item.regions, mask)
    local art = item:CreateTexture()
    item.CountFrame = new("Frame", nil, item)
    item.CountFrame.Count = item.CountFrame:CreateFontString()
    return item, mask, art
  end

  -- A stand-in for the game's nameplate unit frame, with its own copies of the mixin's methods.
  local function plateFrame()
    local f = new("Button")
    f.HealthBarsContainer = new("Frame", nil, f)
    local hb = new("StatusBar", nil, f.HealthBarsContainer)
    f.HealthBarsContainer.healthBar = hb
    f.healthBar = hb
    hb.bgTexture = hb:CreateTexture(nil, "BACKGROUND")
    hb.selectedBorder = hb:CreateTexture(nil, "OVERLAY")
    hb.deselectedOverlay = hb:CreateTexture(nil, "OVERLAY")
    hb.Text, hb.LeftText, hb.RightText = hb:CreateFontString(), hb:CreateFontString(), hb:CreateFontString()
    f.name = f:CreateFontString()
    f.aggroHighlight = f:CreateTexture(); f.aggroHighlight.shown = false
    f.aggroHighlightBase, f.aggroHighlightAdditive, f.aggroHighlightMask = f:CreateTexture(), f:CreateTexture(), f:CreateTexture()
    local lf = new("Frame", nil, f)
    f.PlayerLevelDiffFrame = lf
    lf.playerLevelDiffIcon, lf.selectedBorder, lf.playerLevelDiffText = lf:CreateTexture(), lf:CreateTexture(), lf:CreateFontString()
    f.LevelFrame = new("Frame", nil, f)
    f.LevelFrame.LevelText = f.LevelFrame:CreateFontString()
    f.CastBarsContainer = new("Frame", nil, f)
    local cb = new("StatusBar", nil, f.CastBarsContainer)
    f.CastBarsContainer.castBar = cb
    cb.Background, cb.Border, cb.Icon = cb:CreateTexture(), cb:CreateTexture(), cb:CreateTexture()
    cb.Text, cb.CastTargetNameText = cb:CreateFontString(), cb:CreateFontString()
    local af = new("Frame", nil, f)
    f.AurasFrame = af
    af.active = {}
    af.auraItemFramePool = { EnumerateActive = function() return pairs(af.active) end }
    af.LossOfControlFrame = new("Frame", nil, af)
    af.LossOfControlFrame.AuraItemFrame = (auraItem())
    function af:RefreshList() end
    function af:RefreshLossOfControl() end
    -- What the game's methods do, as far as the look cares.
    function f:UpdateAnchors()
      hb:SetStatusBarTexture("UI-HUD-CoolDownManager-Bar")
      hb.bgTexture:SetAlpha(1)
      self.HealthBarsContainer:SetHeight(20)
    end
    function f:ApplyFrameOptions() self.name:SetFont("Fonts\\FRIZQT__.TTF", 14, ""); self:UpdateAnchors() end
    function f:OnUnitSet() end
    function f:UpdateAggroHighlight()
      local on = self.aggroHighlight:IsShown()
      self.aggroHighlightBase:SetShown(on); self.aggroHighlightAdditive:SetShown(on); self.aggroHighlightMask:SetShown(on)
    end
    function f:UpdateIsTarget() end
    function f:UpdateIsFocus() end
    function cb:UpdateBarFillTexture(isFull) self:SetStatusBarTexture(isFull and "full" or "filling"); self:SetStatusBarColor(1, 1, 1) end
    function cb:HandleCastStart(channel)
      self.casting, self.channeling = (not channel) or nil, channel or nil
      self:UpdateBarFillTexture(false)
    end
    function cb:HandleInterruptOrSpellFailed()
      self.barType = "interrupted"
      self:UpdateBarFillTexture(true)
      self.casting, self.channeling = nil, nil
    end
    function cb:UpdateIconShown() end
    return f, hb, cb, lf, af
  end

  NamePlateSetupOptions = { healthBarFontHeight = 14, castBarFontHeight = 10, levelFontHeight = 10, healthBarHeight = 20 }
  local f1, hb1, cb1, lf1, af1 = plateFrame()
  local before = {}
  for k in pairs(f1) do before[k] = true end
  local barBefore = {}
  for k in pairs(hb1) do barBefore[k] = true end
  local plates, byUnit = { { UnitFrame = f1 } }, { nameplate1 = { UnitFrame = f1 } }
  C_NamePlate = { GetNamePlates = function() return plates end, GetNamePlateForUnit = function(u) return byUnit[u] end }
  -- The game's health colour: only set when the bar shows another.
  CompactUnitFrame_UpdateHealthColor = function(frame)
    local c = frame.gameColor or { 0, 1, 0 }
    local r, g, b = frame.healthBar:GetStatusBarColor()
    if r ~= c[1] or g ~= c[2] or b ~= c[3] then frame.healthBar:SetStatusBarColor(c[1], c[2], c[3]) end
  end
  N.healthHooked = nil
  fire("ADDON_LOADED", "Blizzard_NamePlates")
  check(N.healthHooked and N.plates[f1], "plates already up when VoltUI hooks in get styled")
  check(hb1.barTex == S.WHITE, "a flat health bar")
  check(hb1.bgTexture.alpha == 0 and hb1.selectedBorder.alpha == 0 and hb1.deselectedOverlay.alpha == 0, "the game's bar art fades")
  local p = N.plates[f1]
  check(p.track.ctex and p.track.ctex[4] == 0.85, "a dark track behind the bar")
  check(p.edge[1].ctex[1] == 0 and p.edge[1].ctex[4] == 0.9 and p.ring[1].shown == false, "a thin black border, no ring")
  check(lf1.playerLevelDiffIcon.alpha == 0 and N.levels[f1].fill.ctex[1] == S.BG[1], "a flat level box")

  -- Colours.
  f1.gameColor = { 1, 0, 0 }
  CompactUnitFrame_UpdateHealthColor(f1)
  check(hb1.barColor[1] == 0.8 and hb1.barColor[2] == 0.26, "hostile red softens into VoltUI's")
  CompactUnitFrame_UpdateHealthColor(f1)
  check(hb1.barColor[1] == 0.8, "and stays VoltUI's when the game sets its colour again")
  f1.gameColor = { 1, 1, 0 }
  CompactUnitFrame_UpdateHealthColor(f1)
  check(hb1.barColor[1] == 0.9 and hb1.barColor[2] == 0.72, "neutral gold")
  f1.gameColor = { 0.9, 0.9, 0.9 }
  CompactUnitFrame_UpdateHealthColor(f1)
  check(hb1.barColor[1] == 0.55, "tapped grey")
  f1.gameColor = { 0.96, 0.55, 0.73 }
  CompactUnitFrame_UpdateHealthColor(f1)
  check(hb1.barColor[1] == 0.96 and hb1.barColor[3] == 0.73, "a class colour stays the game's")
  f1.gameColor = { 1, 0, 0 }
  CompactUnitFrame_UpdateHealthColor(f1)
  PC.hpColor = "game"
  N:Refresh()
  check(hb1.barColor[1] == 1 and hb1.barColor[2] == 0, "the game's colour comes back when VoltUI's is off")
  PC.hpColor = "volt"
  N:Refresh()
  check(hb1.barColor[1] == 0.8, "and VoltUI's again when it's on")
  f1:UpdateAnchors()
  check(hb1.barTex == S.WHITE and hb1.bgTexture.alpha == 0 and hb1.barColor[1] == 0.8, "laid out again by the game, it goes flat again")

  -- Text.
  f1:ApplyFrameOptions()
  check(f1.name.font[1] == S.Font().path and f1.name.font[2] == 12.5 and f1.name.font[3] == "OUTLINE", "the name in VoltUI's font, a little under the game's size")
  check(hb1.Text.font[2] == 12.5 and cb1.Text.font[2] == 10 and lf1.playerLevelDiffText.font[2] == 10, "health, spell and level text too")
  PC.nameScale = 1.2
  N:Refresh()
  check(f1.name.font[2] == 17, "name size follows its setting")
  N:Refresh()
  check(f1.name.font[2] == 17, "without growing on each refresh")
  PC.nameScale = 0.9

  -- Target, focus, aggro, dimming.
  local f2, hb2 = plateFrame()
  byUnit.nameplate2 = { UnitFrame = f2 }
  fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
  check(N.plates[f2] and hb2.barTex == S.WHITE, "a plate added later gets styled")
  UnitExists = function() return true end
  f1.isTarget = true
  f1:UpdateIsTarget()
  fire("PLAYER_TARGET_CHANGED")
  check(p.edge[1].ctex[1] == S.ACCENT[1] and p.ring[1].ctex[4] == 0.35, "your target: a blue border and a faint ring")
  check(p.dim.alpha == 0 and N.plates[f2].dim.alpha == 0.3, "the other plates dim while you have a target")
  check(N.levels[f1].edge[1].ctex[1] == S.ACCENT[1], "the level box takes the target border too")
  PC.target = "white"
  N:Refresh()
  check(p.edge[1].ctex[1] == 1 and p.edge[1].ctex[3] == 1, "or a white one")
  PC.target = "accent"
  f2.isFocus = true
  fire("PLAYER_FOCUS_CHANGED")
  check(N.plates[f2].edge[1].ctex[1] == 1 and N.plates[f2].edge[1].ctex[2] == 0.49 and N.plates[f2].dim.alpha == 0, "your focus: orange, not dimmed")
  f2.isFocus = nil
  f2.aggroHighlight.shown = true
  f2.aggroHighlight.vc = { 1, 0.6, 0 }
  f2:UpdateAggroHighlight()
  local p2 = N.plates[f2]
  check(f2.aggroHighlightBase.shown == false and f2.aggroHighlightAdditive.shown == false, "the game's aggro flare is hidden")
  check(p2.ring[1].ctex[1] == 1 and p2.ring[1].ctex[2] == 0.6 and p2.ring[1].ctex[4] == 0.9, "aggro: a ring in the threat colour")
  issecretvalue = secretOn
  f2.aggroHighlight.vc = { Secret(), Secret(), Secret() }
  local ok, err = pcall(f2.UpdateAggroHighlight, f2)
  check(ok and p2.ring[1].ctex[1] == 1 and p2.ring[1].ctex[2] == 0.25, "a secret threat colour falls back to red: " .. tostring(err))
  UnitExists = function() return Secret() end
  ok, err = pcall(fire, "PLAYER_TARGET_CHANGED")
  check(ok and p2.dim.alpha == 0, "a secret answer to having a target doesn't dim: " .. tostring(err))
  issecretvalue = oldSecret
  UnitExists = function() return true end
  PC.aggro = false
  N:Refresh()
  check(p2.ring[1].shown == false and f2.aggroHighlightBase.shown == false, "aggro ring off: no ring and still no flare")
  PC.aggro = true
  PC.dim = 0
  N:Refresh()
  check(p2.dim.alpha == 0, "dimming off")
  PC.dim = 0.3

  -- Height.
  PC.barHeight = 8
  N:Refresh()
  check(f1.HealthBarsContainer.h == 8, "a health bar height of VoltUI's")
  f1:UpdateAnchors()
  check(f1.HealthBarsContainer.h == 8, "kept when the game lays it out again")
  PC.barHeight = 0
  N:Refresh()
  check(f1.HealthBarsContainer.h == 20, "back to the game's own height at 0")

  -- The cast bar.
  local casting, channeling = {}, {}
  UnitCastingInfo = function(u) local c = casting[u]; if c then return "Fireball", "Fireball", 1, 0, 1, false, 7, c.locked end end
  UnitChannelInfo = function(u) local c = channeling[u]; if c then return "Drain", "Drain", 1, 0, 1, false, c.locked end end
  cb1.unit = "nameplate1"
  casting.nameplate1 = { locked = false }
  cb1:HandleCastStart()
  local fill = cb1:GetStatusBarTexture()
  check(cb1.barTex == S.WHITE and fill.vc[1] == S.ACCENT[1] and fill.vc[3] == S.ACCENT[3], "a cast: flat, VoltUI blue")
  check(cb1.Background.alpha == 0 and cb1.Border.alpha == 0 and cb1.Icon.texCoord and cb1.Icon.texCoord[1] == 0.08, "flat behind, a square icon")
  check(N.casts[cb1].edge[1].ctex[4] == 0.9, "a thin border round the cast bar")
  casting.nameplate1 = { locked = true }
  cb1:HandleCastStart()
  check(fill.vc[1] == 0.55, "can't be interrupted: grey")
  cb1:UpdateBarFillTexture(true)
  check(fill.vc[1] == 0.55 and cb1.barTex == S.WHITE, "finishing keeps its colour")
  casting.nameplate1 = nil
  channeling.nameplate1 = { locked = false }
  cb1:HandleCastStart(true)
  check(fill.vc[1] == 0.45 and fill.vc[2] == 0.85, "a channel: green")
  channeling.nameplate1 = nil
  issecretvalue = secretOn
  local sLock = Secret()
  C_CurveUtil = { EvaluateColorValueFromBoolean = function(flag, a, b) if flag == sLock then return a end; return b end }
  casting.nameplate1 = { locked = sLock }
  cb1.barType = Secret()
  ok, err = pcall(cb1.HandleCastStart, cb1)
  check(ok and fill.vc[1] == 0.55, "a secret can't-interrupt still colours it: " .. tostring(err))
  ok, err = pcall(cb1.UpdateBarFillTexture, cb1, true)
  check(ok and fill.vc[1] == S.ACCENT[1], "finishing a secret cast: the cast colour: " .. tostring(err))
  issecretvalue = oldSecret
  casting.nameplate1 = { locked = false }
  cb1.barType = nil
  cb1:HandleCastStart()
  cb1:HandleInterruptOrSpellFailed()
  check(fill.vc[1] == 0.85 and fill.vc[2] == 0.25, "interrupted: red")
  PC.castBar = false
  N:Refresh()
  cb1:HandleCastStart()
  check(cb1.barTex == "filling" and cb1.Background.alpha == 1 and cb1.Icon.texCoord[2] == 1, "VoltUI's cast bar off: the game's art")
  check(N.casts[cb1].edge[1].shown == false, "and no border")
  PC.castBar = true
  N:Refresh()

  -- Aura icons.
  local item, mask, art = auraItem()
  af1.active[item] = true
  af1:RefreshList()
  local a = N.auras[item]
  check(a and item.Icon.unmasked and item.Icon.unmasked[mask], "aura icons lose the round mask")
  check(art.alpha == 0 and item.Icon.texCoord[1] == 0.1 and a.edge[1].ctex[4] == 1, "square, with a thin border")
  check(item.CountFrame.Count.font[1] == S.Font().path, "stack counts in VoltUI's font")
  check(N.auras[af1.LossOfControlFrame.AuraItemFrame], "the loss of control icon too")
  PC.auras = false
  N:Refresh()
  check(art.alpha == 1 and item.Icon.texCoord[2] == 1 and a.edge[1].shown == false, "aura icons off: the game's look")
  PC.auras = true

  -- A frame used again for another unit.
  f1.isTarget = nil
  f1.gameColor = { 0, 1, 0 }
  CompactUnitFrame_UpdateHealthColor(f1)
  f1:OnUnitSet()
  check(hb1.barColor[1] == 0.3 and hb1.barColor[2] == 0.7, "used again for a friendly unit: VoltUI's green")

  -- Nothing written onto the game's frames.
  local added = {}
  for k in pairs(f1) do if not before[k] and k ~= "gameColor" and k ~= "isTarget" then added[#added + 1] = tostring(k) end end
  local MOCK = { barTex = true, fillTex = true, barColor = true, fill = true }
  for k in pairs(hb1) do if not barBefore[k] and not MOCK[k] then added[#added + 1] = "bar." .. tostring(k) end end
  check(#added == 0, "nothing VoltUI makes is written onto the game's frames: " .. table.concat(added, ","))

  -- More settings (1.19.0): the border, colours you pick, class and threat colours, health text,
  -- name colour, textures, the cast bar's height, time and colours, and the aura options.
  local savedG = {}
  local GLOBALS = { "UnitIsPlayer", "UnitIsFriend", "UnitClass", "UnitThreatSituation", "UnitHealth", "UnitHealthMax",
    "AbbreviateNumbers", "BreakUpLargeNumbers", "UnitHealthPercent", "CurveConstants", "C_StringUtil", "LibStub",
    "PixelUtil", "ColorPickerFrame", "CompactUnitFrame_UpdateHealth", "CompactUnitFrame_UpdateName",
    "CompactUnitFrame_UpdateMaxHealth" }
  for _, k in ipairs(GLOBALS) do savedG[k] = _G[k] end
  local who = {}
  UnitIsPlayer = function(u) return who[u] and who[u].player or false end
  UnitIsFriend = function(_, u) return who[u] and who[u].friend or false end
  UnitClass = function(u) return "Rogue", who[u] and who[u].class end
  UnitThreatSituation = function(_, u) return who[u] and who[u].threat end
  UnitHealth = function(u) return who[u] and who[u].hp or 0 end
  UnitHealthMax = function(u) return who[u] and who[u].max or 0 end
  AbbreviateNumbers = function(v)
    if issecretvalue and issecretvalue(v) then return v end
    return v >= 1000 and string.format("%.1fK", v / 1000) or tostring(v)
  end
  BreakUpLargeNumbers, UnitHealthPercent, CurveConstants, C_StringUtil, LibStub, PixelUtil = nil, nil, nil, nil, nil, nil
  local function C() return PC end

  -- The border.
  C().border = 3
  N:Refresh()
  check(p.edge.size == 3 and p.ring.from == 3 and p.ring.size == 3, "border 3 pixels thick, the ring just outside it")
  check(p.edge[1].h == 3 and p.edge[3].w == 3, "each line that thick")
  check(N.casts[cb1].edge.size == 3, "the cast bar's border too")
  PixelUtil = { GetPixelToUIUnitFactor = function() return 0.5 end }
  N:Refresh()
  check(p.edge.size == 1.5, "counted in screen pixels, through the plate's scale")
  PixelUtil = nil
  C().border = 1
  C().colBorder = { 0.2, 0.3, 0.4 }
  N:Refresh()
  check(p.edge.size == 1 and p.edge[1].ctex[1] == 0.2 and p.edge[1].ctex[3] == 0.4, "and in a colour you pick")
  Def("colBorder")
  N:Refresh()
  check(p.edge[1].ctex[1] == 0, "black again by default")

  -- Colours you pick.
  f1.unit = nil
  f1.gameColor = { 1, 0, 0 }
  C().colHostile = { 0.5, 0, 0.5 }
  CompactUnitFrame_UpdateHealthColor(f1)
  check(hb1.barColor[1] == 0.5 and hb1.barColor[3] == 0.5, "hostile in a colour you pick")
  Def("colHostile")
  N:Refresh()
  check(hb1.barColor[1] == 0.8 and hb1.barColor[2] == 0.26, "VoltUI's own again at its default")
  check(N.DEFAULTS.colHostile[1] == 0.8, "the defaults themselves untouched")

  -- Class colours.
  f1.unit = "nameplate1"
  who.nameplate1 = { player = true, friend = false, class = "ROGUE", hp = 12345, max = 20000 }
  f1.gameColor = { 1, 0.96, 0.41 }
  CompactUnitFrame_UpdateHealthColor(f1)
  check(hb1.barColor[1] == 1 and hb1.barColor[2] == 0.96, "an enemy player in class colour")
  C().classEnemy = false
  N:Refresh()
  check(hb1.barColor[1] == 0.8 and hb1.barColor[2] == 0.26, "class colours off for enemies: the hostile colour")
  who.nameplate1.friend = true
  C().classFriendly = false
  N:Refresh()
  check(hb1.barColor[1] == 0.45 and hb1.barColor[3] == 0.92, "a friendly player without class colours: VoltUI's blue")
  C().classFriendly = true
  N:Refresh()
  check(hb1.barColor[2] == 0.96, "and with them, its class colour")
  C().classEnemy = true

  -- Threat colours.
  who.nameplate1 = { threat = 3, hp = 500, max = 1000 }
  f1.gameColor = { 1, 0, 0 }
  C().threat = "tank"
  CompactUnitFrame_UpdateHealthColor(f1)
  check(hb1.barColor[1] == 0.3 and hb1.barColor[2] == 0.7, "tank: green while you hold it")
  who.nameplate1.threat = 2
  CompactUnitFrame_UpdateHealthColor(f1)
  check(hb1.barColor[1] == 0.95 and hb1.barColor[2] == 0.6, "orange as it slips")
  who.nameplate1.threat = 0
  CompactUnitFrame_UpdateHealthColor(f1)
  check(hb1.barColor[1] == 0.9 and hb1.barColor[2] == 0.2, "red when someone else has it")
  C().threat = "dps"
  CompactUnitFrame_UpdateHealthColor(f1)
  check(hb1.barColor[1] == 0.8 and hb1.barColor[2] == 0.26, "damage: its usual colour while the tank holds it")
  who.nameplate1.threat = 1
  CompactUnitFrame_UpdateHealthColor(f1)
  check(hb1.barColor[1] == 0.95, "orange when you're about to pull it")
  who.nameplate1.threat = 3
  CompactUnitFrame_UpdateHealthColor(f1)
  check(hb1.barColor[1] == 0.9 and hb1.barColor[2] == 0.2, "red once you have it")
  issecretvalue = secretOn
  who.nameplate1.threat = Secret()
  ok, err = pcall(CompactUnitFrame_UpdateHealthColor, f1)
  check(ok and hb1.barColor[1] == 0.8, "a secret threat: its usual colour: " .. tostring(err))
  issecretvalue = oldSecret
  who.nameplate1.threat = nil
  C().threat = "off"

  -- Health text, updated with the health through the game's own function.
  CompactUnitFrame_UpdateHealth = function() end
  CompactUnitFrame_UpdateMaxHealth = function() end
  CompactUnitFrame_UpdateName = function(frame) frame.name:SetVertexColor(1, 0, 0) end
  N.healthHooked = nil
  N:HookHealth()
  who.nameplate1 = { hp = 12345, max = 20000 }
  C().hpText = "pct"
  N:Refresh()
  check(p.text.shown and p.text.text == "62%", "health as a percent")
  check(hb1.Text.alpha == 0 and hb1.LeftText.alpha == 0 and hb1.RightText.alpha == 0, "the game's own health text faded")
  check(p.text.font and p.text.font[1] == S.Font().path and p.text.font[2] == 12.5, "in VoltUI's font, at the health text size")
  C().hpText = "num"
  who.nameplate1.hp = 9000
  CompactUnitFrame_UpdateHealth(f1)
  check(p.text.text == "9.0K", "a number, updated with the health")
  C().hpText, C().hpTextPos = "both", "right"
  CompactUnitFrame_UpdateHealth(f1)
  check(p.text.text == "9.0K · 45%" and p.text.justify == "RIGHT" and p.text.points[1][1] == "RIGHT", "both, on the right")
  issecretvalue = secretOn
  who.nameplate1.hp, who.nameplate1.max = Secret(), Secret()
  UnitHealthPercent, CurveConstants = function() return Secret() end, { ScaleTo100 = 1 }
  ok, err = pcall(CompactUnitFrame_UpdateHealth, f1)
  check(ok and p.text.text == "<secret>", "secret health still shows, formatted by the game: " .. tostring(err))
  issecretvalue = oldSecret
  UnitHealthPercent, CurveConstants = nil, nil
  who.nameplate1.hp, who.nameplate1.max = 9000, 20000
  C().hpText = "off"
  N:Refresh()
  check(not p.text.shown and hb1.Text.alpha == 0, "off: no health text at all")
  C().hpText, C().hpTextPos = "game", "center"
  N:Refresh()
  check(not p.text.shown and hb1.Text.alpha == 1, "the game's: its own text back")

  -- Name colour.
  who.nameplate1 = { player = true, friend = true, class = "ROGUE", hp = 1, max = 1 }
  CompactUnitFrame_UpdateName(f1)
  check(f1.name.vc[1] == 1 and f1.name.vc[2] == 0, "names keep the game's colour by default")
  C().nameColor = "class"
  CompactUnitFrame_UpdateName(f1)
  check(f1.name.vc[1] == 1 and f1.name.vc[2] == 0.96, "a player's name in class colour")
  C().nameColor = "white"
  CompactUnitFrame_UpdateName(f1)
  check(f1.name.vc[1] == 1 and f1.name.vc[2] == 1 and f1.name.vc[3] == 1, "or white")
  f1.name:SetVertexColor(0.5, 0.5, 0.5)
  N:ColorName(f1)
  check(f1.name.vc[1] == 0.5, "the grey of a tapped or dead unit stays")
  C().nameColor = "game"

  -- Bar textures.
  local list = N.Textures()
  check(list[1].key == "flat" and #list == #ns.Style.BAR_TEXTURES and #list == 10, "flat, VoltUI's seven and two of the game's bar textures to pick from")
  local LSM = { List = function() return { "Shiny" } end, Fetch = function(_, _, name) return "Interface\\Shiny\\" .. name end }
  LibStub = function() return LSM end
  list = N.Textures()
  check(#list == 11 and list[11].key == "lsm:Shiny", "and any shared ones other add-ons register")
  C().texture = "lsm:Shiny"
  N:Refresh()
  check(hb1.barTex == "Interface\\Shiny\\Shiny", "the health bar takes the texture")
  C().texture = "smooth"
  N:Refresh()
  casting.nameplate1 = { locked = false }
  cb1.barType = nil
  cb1:HandleCastStart()
  check(hb1.barTex == "Interface\\TargetingFrame\\UI-StatusBar" and cb1.barTex == hb1.barTex, "the cast bar too")
  C().texture = "flat"
  LibStub = nil
  N:Refresh()
  cb1:HandleCastStart()
  check(hb1.barTex == S.WHITE and cb1.barTex == S.WHITE, "flat again")

  -- The cast bar's height, colours and time left.
  NamePlateSetupOptions.castBarHeight, NamePlateSetupOptions.castIconHeight = 16, 12
  C().castHeight = 8
  N:Refresh()
  check(f1.CastBarsContainer.h == 20 and cb1.h == 8, "a cast bar height of VoltUI's, with room kept for the icon")
  C().castHeight = 0
  N:Refresh()
  check(f1.CastBarsContainer.h == 28 and cb1.h == 16, "the game's height back at 0")
  C().colCast = { 0.1, 0.2, 0.3 }
  cb1:HandleCastStart()
  check(fill.vc[1] == 0.1 and fill.vc[3] == 0.3, "casts in a colour you pick")
  cb1:UpdateBarFillTexture(true)
  check(fill.vc[1] == 0.1, "kept as it finishes")
  Def("colCast")
  C().colFailed = { 0.7, 0, 0.7 }
  cb1:HandleCastStart()
  cb1:HandleInterruptOrSpellFailed()
  check(fill.vc[1] == 0.7 and fill.vc[3] == 0.7, "interrupted in a colour you pick")
  Def("colFailed")
  cb1.barType = nil
  C().castTime = true
  cb1.value, cb1.maxValue = 0.4, 2
  cb1:HandleCastStart()
  local cp1 = N.casts[cb1]
  check(cp1.clock.shown and cp1.time.text == "1.6", "time left on a cast")
  check(cp1.time.font and cp1.time.font[1] == S.Font().path, "in VoltUI's font")
  cb1.casting, cb1.channeling, cb1.value = nil, true, 1.3
  cp1.clock.scripts.OnUpdate(cp1.clock, 1)
  check(cp1.time.text == "1.3", "and on a channel, counting down")
  issecretvalue = secretOn
  cb1.value = Secret()
  ok, err = pcall(cp1.clock.scripts.OnUpdate, cp1.clock, 1)
  check(ok and cp1.time.text == "", "a secret time left: blank: " .. tostring(err))
  issecretvalue = oldSecret
  C().castTime = false
  N:Refresh()
  check(not cp1.clock.shown, "time left off")
  cb1.channeling, cb1.value, cb1.maxValue = nil, nil, nil

  -- Aura options.
  local item2 = auraItem()
  item2.Cooldown = new("Cooldown", nil, item2)
  local cdText = item2.Cooldown:CreateFontString()
  function item2.Cooldown:GetCountdownFontString() return cdText end
  function item2.Cooldown:SetDrawSwipe(v) self.swipeOn = v end
  function item2:SetAura(aura) self.spellID = aura.spellId end
  af1.active = { [item2] = true }
  af1.DebuffListFrame, af1.BuffListFrame, af1.CrowdControlListFrame = new("Frame", nil, af1), new("Frame", nil, af1), new("Frame", nil, af1)
  af1:RefreshList()
  local a2 = N.auras[item2]
  check(a2 and a2.timer == cdText and cdText.font[1] == S.Font().path and cdText.font[2] == 10, "timer numbers in VoltUI's font")
  check(item2.Cooldown.swipeOn == true and item2.Cooldown.hideNumbers == nil, "the swipe kept, and the game's own rule for numbers")
  check(af1.DebuffListFrame.scale == nil and af1.BuffListFrame.scale == nil, "list sizes left alone at 1")
  item2:SetAura({ spellId = 5, dispelName = "Magic" })
  check(a2.edge[1].ctex[1] == 0.2 and a2.edge[1].ctex[3] == 1, "a Magic aura gets a blue border")
  C().auraBorder = "black"
  N:Refresh()
  check(a2.edge[1].ctex[1] == 0 and a2.edge[1].ctex[3] == 0, "or black")
  C().auraBorder = "type"
  issecretvalue = secretOn
  ok, err = pcall(item2.SetAura, item2, { spellId = 6, dispelName = Secret() })
  check(ok and a2.edge[1].ctex[1] == 0, "a secret type: black: " .. tostring(err))
  item2:SetAura({ spellId = 5, dispelName = "Magic" })
  ok, err = pcall(N.AuraSet, N, item2, Secret())
  check(ok and a2.kind == nil and a2.edge[1].ctex[1] == 0, "a whole aura secret: no error, black: " .. tostring(err))
  issecretvalue = oldSecret
  canaccesstable = function() return false end
  item2:SetAura({ spellId = 7, dispelName = "Magic" })
  check(a2.kind == nil and a2.edge[1].ctex[1] == 0, "an aura the game locks: not read, black")
  canaccesstable = nil
  C().debuffScale, C().buffScale, C().ccScale = 1.5, 0.8, 1.2
  C().auraTimer, C().timerScale, C().stackScale, C().swipe = "off", 1.4, 1.2, false
  N:Refresh()
  check(af1.DebuffListFrame.scale == 1.5 and af1.BuffListFrame.scale == 0.8 and af1.CrowdControlListFrame.scale == 1.2, "debuffs, buffs and crowd control each sized")
  check(item2.Cooldown.hideNumbers == true and item2.Cooldown.swipeOn == false, "timer numbers off, no swipe")
  check(cdText.font[2] == 14 and item2.CountFrame.Count.font[2] == 12, "timer and stack sizes")
  C().auraTimer = "all"
  N:Refresh()
  check(item2.Cooldown.hideNumbers == false, "or numbers on every aura")
  C().debuffScale, C().buffScale, C().ccScale, C().auraTimer, C().timerScale, C().stackScale, C().swipe = 1, 1, 1, "short", 1, 1, true
  N:Refresh()
  check(af1.DebuffListFrame.scale == 1 and af1.BuffListFrame.scale == 1, "back to 1")
  local problems2 = {}
  for what, e in pairs(N.reported) do problems2[#problems2 + 1] = what .. ": " .. e end
  check(#problems2 == 0, "no part failed with the new settings: " .. table.concat(problems2, " | "))

  -- Enemy, friendly and your target (1.22.0): each kind of plate has its own settings, and your
  -- target's go on top of its kind's.
  PixelUtil = nil
  local cfg = N:Cfg()
  local p2 = N.plates[f2]
  f1.unit, f2.unit = "nameplate1", "nameplate2"
  f1.isTarget, f2.isTarget, f2.isFocus = nil, nil, nil
  who.nameplate1 = { friend = false, hp = 5000, max = 10000 }
  who.nameplate2 = { friend = true, hp = 800, max = 1000 }
  cfg.enemy.hpText, cfg.friendly.hpText = "pct", "num"
  N:Refresh()
  check(N:Kind(f1) == "enemy" and N:Kind(f2) == "friendly", "a plate on a friendly unit uses the friendly set")
  check(p.text.text == "50%" and p2.text.text == "800", "each with its own health text")
  cfg.friendly.border = 2
  N:Refresh()
  check(p.edge.size == 1 and p2.edge.size == 2, "and its own border")
  who.nameplate2.friend = false
  fire("UNIT_FACTION", "nameplate2")
  check(N:Kind(f2) == "enemy" and p2.text.text == "80%" and p2.edge.size == 1, "a unit turning hostile moves to the enemy set")
  who.nameplate2.friend = true
  fire("UNIT_FACTION", "nameplate2")
  check(N:Kind(f2) == "friendly" and p2.edge.size == 2, "and back")
  -- The event comes for party and raid members too, and the game raises an error if
  -- those tokens reach the plate lookup.
  local lookup, asked = C_NamePlate.GetNamePlateForUnit, {}
  C_NamePlate.GetNamePlateForUnit = function(u)
    asked[#asked + 1] = u
    if u:find("^party") or u:find("^raid") then error("Raid<n>/Party<n> unit tokens are not allowed for this call.") end
    return lookup(u)
  end
  local okParty = pcall(fire, "UNIT_FACTION", "party1")
  local okRaid = pcall(fire, "UNIT_FACTION", "raid12")
  pcall(fire, "UNIT_FACTION", "player")
  check(okParty and okRaid and #asked == 0, "a faction change on a party or raid member never reaches the plate lookup")
  fire("UNIT_FACTION", "nameplate2")
  check(asked[1] == "nameplate2", "a plate's own token still does")
  C_NamePlate.GetNamePlateForUnit = lookup
  cfg.friendly.border = 1
  N:Refresh()

  cfg.target.hpText, cfg.target.barHeight, cfg.target.border, cfg.target.nameScale = "both", 12, 3, 1.5
  f1.isTarget = true
  f1:UpdateIsTarget()
  check(p.text.text == "5.0K · 50%" and f1.HealthBarsContainer.h == 12 and p.edge.size == 3, "your target: its own health text, bar height and border")
  check(f1.name.font[2] == 19, "and a bigger name: " .. tostring(f1.name.font[2]))
  check(p2.text.text == "800" and p2.edge.size == 1, "the other plates keep theirs")
  f1.isTarget = false
  f1:UpdateIsTarget()
  check(p.text.text == "50%" and p.edge.size == 1 and f1.name.font[2] == 12.5 and f1.HealthBarsContainer.h == 20, "its kind's own again once it isn't")
  cfg.target.hpText, cfg.target.barHeight, cfg.target.border, cfg.target.nameScale = "same", 0, 0, 1
  cfg.target.glow = false
  f1.isTarget = true
  f1:UpdateIsTarget()
  check(p.edge[1].ctex[1] == S.ACCENT[1] and p.ring[1].shown == false, "the faint ring round your target can go")
  cfg.target.color = "white"
  N:Refresh()
  check(p.edge[1].ctex[1] == 1 and p.edge[1].ctex[3] == 1, "a white border")
  cfg.target.color, cfg.target.glow = "accent", true
  f1.isTarget = nil
  f1:UpdateIsTarget()
  cfg.enemy.hpText, cfg.friendly.hpText = "game", "game"
  N:Refresh()

  -- Settings saved by 1.19, one set for every plate, become the enemy and friendly sets.
  local keep = VoltUIDB.plateCfg
  VoltUIDB.plateCfg = { hpText = "pct", border = 2, classEnemy = false, classFriendly = true, target = "white",
    colHostile = { 0.1, 0.2, 0.3 }, dim = 0.5 }
  local m = N:Cfg()
  check(m.enemy.hpText == "pct" and m.friendly.hpText == "pct" and m.enemy.border == 2 and m.friendly.border == 2, "1.19's settings carry over to both kinds")
  check(m.enemy.class == false and m.friendly.class == true and m.target.color == "white", "class colours by side, and the target's border")
  check(m.colHostile[1] == 0.1 and m.dim == 0.5 and m.hpText == nil and m.classEnemy == nil, "shared ones stay shared, the old ones go")
  check(m.enemy.castBar == true and m.target.glow == true and m.target.hpText == "same", "anything new gets its default")
  VoltUIDB.plateCfg = keep
  N:Cfg()
  N:Refresh()

  -- The settings: colour swatches and each kind's page.
  SlashCmdList.VOLTUI("nameplates options")
  local E = ns.EditMode
  local function rowOf(key)
    for _, r in ipairs(E.rows) do
      if r.def.key == key or (r.def.keys and r.def.keys[1].key == key) then return r end
    end
  end
  local sw = rowOf("colHostile")
  check(sw and sw.swatches and #sw.swatches == 3, "colour swatches for hostile, neutral and tapped")
  check(sw and sw.swatches[1].fill.ctex[1] == 0.8 and sw.swatches[2].fill.ctex[1] == 0.9, "showing the current colours")
  ColorPickerFrame = { SetupColorPickerAndShow = function(self, info) self.info = info end, GetColorRGB = function() return 0.1, 0.9, 0.2 end }
  sw.swatches[1].scripts.OnClick(sw.swatches[1], "LeftButton")
  check(ColorPickerFrame.info and ColorPickerFrame.info.r == 0.8 and ColorPickerFrame.info.g == 0.26, "a click opens the game's colour picker on it")
  ColorPickerFrame.info.swatchFunc()
  check(C().colHostile[2] == 0.9 and sw.swatches[1].fill.ctex[2] == 0.9, "a picked colour is saved and shown straight away")
  ColorPickerFrame.info.cancelFunc({ r = 0.8, g = 0.26, b = 0.22 })
  check(C().colHostile[1] == 0.8 and C().colHostile[2] == 0.26, "Cancel puts it back")
  ColorPickerFrame.info.swatchFunc()
  sw.swatches[1].scripts.OnClick(sw.swatches[1], "RightButton")
  check(C().colHostile[2] == 0.26 and sw.swatches[1].fill.ctex[2] == 0.26, "right-click: the default")
  sw:Step(1)
  check(C().colHostile[2] == 0.26, "the mouse wheel leaves a colour alone")
  ColorPickerFrame = nil
  check(rowOf("border") and rowOf("hpText") and rowOf("debuffScale") and rowOf("colCast") and rowOf("threat") and not rowOf("colPlayer"),
    "the enemy page: bars, text, casts, auras and threat")
  E:Select("friendly")
  check(rowOf("colFriendly") and rowOf("debuffScale") and rowOf("class") and not rowOf("threat"), "the friendly page has its own")
  E:Select("plateTarget")
  check(rowOf("color") and rowOf("glow") and rowOf("dim") and rowOf("focus") and not rowOf("debuffScale"), "and your target's page, how it stands out")
  E:Select("plates")

  f1.unit = nil
  for _, k in ipairs(GLOBALS) do _G[k] = savedG[k] end

  -- Settings tab, reset, command.
  PC.nameScale = 1.5
  SlashCmdList.VOLTUI("nameplates options")
  check(ns.EditMode.tab == "plates", "/volt nameplates options opens its tab")
  check(#ns.EditMode.rows > 8, "the tab has its settings")
  ns.EditMode:Reset(); ns.EditMode:Reset()
  check(N:Cfg().enemy.nameScale == 0.9 and N:Cfg().friendly.nameScale == 1.5, "Reset on the enemy page resets just the enemy plates")
  ns.EditMode:Select("friendly")
  ns.EditMode:Reset(); ns.EditMode:Reset()
  check(PC.nameScale == 0.9 and f1.name.font[2] == 12.5, "Reset puts these plates' settings back")
  ns.EditMode:Close()
  wipe(chat)
  SlashCmdList.VOLTUI("nameplates")
  check(chat[1] and chat[1]:find("styled", 1, true), "/volt nameplates reports")
  local problems = {}
  for what, e in pairs(N.reported) do problems[#problems + 1] = what .. ": " .. e end
  check(#problems == 0, "no part failed: " .. table.concat(problems, " | "))
  wipe(chat)

  -- Another nameplate add-on loaded: VoltUI stays out.
  local was = C_AddOns
  C_AddOns = { IsAddOnLoaded = function(n) return n == "Platynator" end }
  local M2 = setmetatable({ plates = {}, casts = {}, levels = {}, auras = {}, faces = {}, reported = {}, missing = {} }, { __index = N })
  M2:Enable()
  check(M2.yielded == "Platynator" and chat[1] and chat[1]:find("Platynator", 1, true), "another nameplate add-on: VoltUI says so and stays out")
  M2:Skin(f2)
  check(next(M2.plates) == nil, "and styles nothing")
  C_AddOns = was
  wipe(chat)

  UnitExists, UnitCastingInfo, UnitChannelInfo, issecretvalue = oldExists, oldCast, oldChan, oldSecret
  C_NamePlate, NamePlateSetupOptions, C_CurveUtil = nil, nil, nil
end)()

;(function()
print("== Settings window: search, copy, reset, parts")
local E, FUI, U, G, N, AB = ns.EditMode, ns.FUI, ns.UnitFrames, ns.Raid, ns.Nameplates, ns.ActionBars
inCombat = false
SlashCmdList.VOLTUI("")
check(VoltUISettings.shown and E.tab and not FUI.unlocked, "/volt opens the settings, without moving frames")
local function rowIn(rows, key, page)
  for _, r in ipairs(rows) do
    if r.shown ~= false and r.def.key == key and (not page or r.page == page) then return r end
  end
end
local function row(key) return rowIn(E.rows, key) end
local function sideOf(key) -- a page's sidebar entry, which it may share with its fellow tabs
  local tg = ns.Pages.tabOf[key]
  if tg then key = tg.pages[1] end
  for _, b in ipairs(E.tabs) do if b.tab == key then return b end end
end
local function search(text)
  E.searchBox:SetText(text)
  E.searchBox.scripts.OnTextChanged(E.searchBox, true)
end

-- Search
E:Select("general")
search("border")
check(E.query == "border" and E.title.text == "Search" and #E.rows >= 6, "search shows every setting that matches: " .. #E.rows)
check(E.counts.plates and E.counts.plates >= 2 and sideOf("plates").note.text ~= "", "the sidebar counts them per page")
check(sideOf("bags").alpha == 0.4 and sideOf("plates").alpha == 1, "and dims the pages with none")
local br = rowIn(E.rows, "border", "plates")
local b0 = N:Cfg().enemy.border
br:Step(1)
check(N:Cfg().enemy.border == b0 + 1, "a result works just like the setting on its page")
br:Step(-1)
search("colour")
local nColour = #E.rows
search("color")
check(#E.rows == nColour and nColour > 0, "either spelling finds the colours")
search("gird zzz")
check(#E.rows == 0 and E.noResults.shown and E.noResults.text:find("zzz", 1, true), "nothing found says so")
search("share")
local link
for _, r in ipairs(E.results["#pages"].rows) do
  if r.shown ~= false and r.def.kind == "link" and r.def.label == "Share and back up" then link = r end
end
check(link and E.results["#pages"].shown, "pages that match are listed to open")
link.link.scripts.OnClick(link.link)
check(E.tab == "share" and not E.query and E.searchBox.text == "" and E.title.text == "Share and back up", "and open from there, clearing the search")
search("font size")
check(#E.rows >= 3 and E.results["player#3"] and E.results["player#3"].shown, "two words: both have to match")
E.results["player#2"].action.scripts.OnClick(E.results["player#2"].action)
check(E.tab == "player" and not E.query, "a result card opens its page")
E:Select("player")
search("width")
search("")
check(not E.query and E.tab == "player", "clearing the search goes back to the page")

-- Copy from another page: text only, with an undo
local pc, uc = U:Cfg("pet"), U:Cfg("player")
uc.nameSize, uc.barSize, uc.width = 15, 13, 260
E:Select("pet")
check(E.copyFrom.shown and E.reset.shown, "a page that can copy has the button")
E.copyFrom.scripts.OnClick()
local pop = VoltUICopy
check(pop and pop.shown, "Copy from opens its window")
local function prow(key, kind)
  for _, r in ipairs(pop.rows) do
    if (key and r.def.key == key) or (kind and r.def.kind == kind) then return r end
  end
end
check(prow("src").value.text == "Player", "from the first page like it")
prow("what"):Set("text")
check(prow(nil, "note").label.text:find("will change"), "says how many settings will change")
prow(nil, "button").button.scripts.OnClick()
check(pc.nameSize == 15 and pc.barSize == 13 and pc.width == 120, "text only: the font sizes come over, the width doesn't")
check(not pop.shown and E.banner.shown and E.banner.text.text:find("Copied") and E.banner.button.text.text == "Undo", "with an undo")
E.banner.button.scripts.OnClick()
check(pc.nameSize == 11 and pc.barSize == 10, "undo puts them back")
E.copyFrom.scripts.OnClick()
prow("what"):Set("pick")
local sizeToggle
for _, r in ipairs(pop.rows) do if r.def.label == "Size" then sizeToggle = r end end
check(sizeToggle and sizeToggle.alpha == 1, "Choose wakes the card switches")
for _, r in ipairs(pop.rows) do
  if r.def.kind == "toggle" and r.def.label ~= "Size" then r:Set(false) end
end
prow(nil, "button").button.scripts.OnClick()
check(pc.width == 260 and pc.nameSize == 11, "only the cards you pick")
pc.width = 120
uc.nameSize, uc.barSize, uc.width = 13, 12, 230

-- One kind of nameplate onto the other
local pcfg = N:Cfg()
pcfg.enemy.castTime, pcfg.enemy.border = true, 3
E:Select("friendly")
E.copyFrom.scripts.OnClick()
prow(nil, "button").button.scripts.OnClick()
check(pcfg.friendly.castTime == true and pcfg.friendly.border == 3, "the enemy plates' settings onto the friendly ones")
N:ResetCfg()

-- One bar onto another, without moving it
AB:Cfg("bar1").size = 44
E:Select("bars")
E.barKey = "bar2"
E:RefreshPage()
local spot = AB:Cfg("bar2").point
E.copyFrom.scripts.OnClick()
check(prow("src").value.text == "Bar 1", "bars copy from another bar")
prow("what"):Set("all")
prow(nil, "button").button.scripts.OnClick()
check(AB:Cfg("bar2").size == 44 and AB:Cfg("bar2").point == spot, "its look, not its spot")
AB:Cfg("bar1").size, AB:Cfg("bar2").size = 36, 36
E.barKey = "bar1"

-- Reset asks once more, and stops asking after a moment
E:Select("pet")
pc.width = 150
E.reset.scripts.OnClick()
check(E.reset.text.text == "Click to confirm" and pc.width == 150, "a first click only asks")
runTimers()
check(E.reset.text.text:find("^Reset") and not E.reset.text.text:find("confirm"), "and the question goes: " .. E.reset.text.text)
E.reset.scripts.OnClick()
E.reset.scripts.OnClick()
check(U:Cfg("pet").width == 120, "two clicks reset")

-- Parts of VoltUI, and the reload they need
E:Select("home")
E.toast = nil
local jr = rowIn(E.rows, "junk")
check(jr and jr.def.store == "part" and jr.switch, "a switch for each part")
jr:Step(1)
check(VoltUIDB.junk == false and FUI:ReloadPending() and E.banner.shown and E.banner.kind == "reload"
  and E.banner.button.text.text == "Reload now", "switching one says a reload is needed, with a button")
jr:Step(1)
check(VoltUIDB.junk ~= false and not FUI:ReloadPending() and not E.banner.shown, "switching it back takes that away")
check(sideOf("home").bar.shown and sideOf("player").note.text == "", "the sidebar marks the page you're on")

-- A page for a part that's off
local was = U.enabled
U.enabled = false
E.pages.tot = nil
E:Select("tot")
check(#E.rows == 2 and E.rows[1].def.store == "part" and E.rows[2].def.kind == "note", "a part that's off shows its switch instead")
check(not E.copyFrom.shown and not E.reset.shown, "and nothing to copy or reset")
check(sideOf("tot").note.text == "off", "the sidebar says it's off")
U.enabled = was
E.pages.tot = nil
E:Select("tot")
check(#E.rows > 5, "and its settings once it's on")

-- The wheel scrolls a long page, and keeps scrolling over sliders while you do
local wheelAt = 100
local oldGetTime = GetTime
GetTime = function() return wheelAt end
E:Select("plates")
local sf = E.scroll
local view = sf.viewH
sf.viewH = 200 -- as on a small screen
sf:ScrollTo(0)
check(sf:MaxScroll() > 0, "a long page scrolls")
sf.scripts.OnMouseWheel(sf, -1)
local off = sf.offset
check(off > 0, "the wheel scrolls it")
local sl = rowIn(E.rows, "textScale")
local ts = N:Cfg().enemy.textScale
sl.slider.scripts.OnMouseWheel(sl.slider, -1)
check(sf.offset > off and N:Cfg().enemy.textScale == ts, "a slider passing under the mouse doesn't take the wheel")
wheelAt = wheelAt + 2
local off2 = sf.offset
sl.slider.scripts.OnMouseWheel(sl.slider, 1)
check(N:Cfg().enemy.textScale == ts and sf.offset < off2, "nor a moment later: on a page that scrolls the wheel always scrolls the page")
local oldShift = IsShiftKeyDown
IsShiftKeyDown = function() return true end
sl.slider.scripts.OnMouseWheel(sl.slider, 1)
check(N:Cfg().enemy.textScale > ts, "with Shift held the wheel steps the slider")
IsShiftKeyDown = oldShift
sf.viewH = 100000
sl.slider.scripts.OnMouseWheel(sl.slider, 1)
check(N:Cfg().enemy.textScale > ts + 0.05, "and on a page that doesn't scroll it steps the slider as before")
GetTime = oldGetTime
sf.viewH = view
N:ResetCfg()
E:Close()
end)()

;(function()
print("== Moving frames: grid, snap, nudge")
VoltUIDB.snapFrames = false -- these drop frames where they want them; snapping to frames has its own tests
local E, FUI, M = ns.EditMode, ns.FUI, ns.Move
local P = VoltUIPlayerFrame
inCombat = false
VoltUIDB.snap, VoltUIDB.grid, VoltUIDB.gridSize = true, true, 16
SlashCmdList.VOLTUI("edit")
local Bar = VoltUIMoveBar
check(FUI.unlocked and Bar.shown and not VoltUISettings.shown, "moving frames: the toolbar, with the settings window out of the way")
E:Open() -- the rest of these look at both
check(VoltUIGrid and VoltUIGrid.shown, "the grid shows")
local shown, accent = 0, 0
for _, t in ipairs(M.lines) do
  if t.shown ~= false then
    shown = shown + 1
    if t.ctex[1] == ns.Style.ACCENT[1] then accent = accent + 1 end
  end
end
check(shown > 150 and accent == 2, "lines every 16 pixels, the middle two in the accent colour: " .. shown)
-- snap
local function onGrid(v, total) local k = (v - total / 2) / 16; return math.abs(k - math.floor(k + 0.5)) < 1e-6 or math.abs(v) < 1e-6 or math.abs(v - total) < 1e-6 end
P.dropLeft, P.dropTop = 303, 597
P.mover.scripts.OnDragStart(P.mover)
P.mover.scripts.OnDragStop(P.mover)
local l, t = screenTopLeft(P)
local w, h = P:GetWidth(), P:GetHeight()
check(onGrid(l, 1920) or onGrid(l + w / 2, 1920) or onGrid(l + w, 1920), "dropped, its nearest edge or middle lands on a grid line across: " .. l)
check(onGrid(t - h, 1080) or onGrid(t - h / 2, 1080) or onGrid(t, 1080), "and up and down: " .. t)
check(math.abs(l - 303) <= 8 and math.abs(t - 597) <= 8 and VoltUIDB.playerPoint, "moving it no more than half a square, and saving it")
VoltUIDB.snap = false
P.mover.scripts.OnDragStart(P.mover)
P.mover.scripts.OnDragStop(P.mover)
check(sitsAt(P, 303, 597), "with snapping off it stays where it's dropped")
-- letting go of a drag is a mouse-up too: it isn't a click on the frame
E:Select("general")
M:Pick(nil)
P.mover.scripts.OnMouseUp(P.mover)
check(E.tab == "general" and M.picked ~= P.mover, "dropping a dragged frame doesn't open its page")
-- the picked frame, and nudging it
P.mover.scripts.OnMouseDown(P.mover)
P.mover.scripts.OnMouseUp(P.mover)
check(E.tab == "player" and M.picked == P.mover and M.name.text == "Player", "clicking a frame picks it")
check(M.xBox.text == 303 and M.yBox.text == 1080 - 597, "its spot, in pixels from the top-left")
check(P.mover.pos.shown and P.mover.pos.text == "303, 483", "on its overlay too")
Bar.SetPropagateKeyboardInput = function(self, v) self.propagate = v end
Bar.scripts.OnKeyDown(Bar, "RIGHT")
check(sitsAt(P, 304, 597) and Bar.propagate == false, "the right arrow moves it a pixel, and the game doesn't get the key")
IsShiftKeyDown = function() return true end
Bar.scripts.OnKeyDown(Bar, "UP")
IsShiftKeyDown = function() return false end
check(sitsAt(P, 304, 607) and M.yBox.text == 1080 - 607, "Shift and an arrow: ten")
Bar.scripts.OnKeyDown(Bar, "W")
check(Bar.propagate == true and sitsAt(P, 304, 607), "other keys go on to the game")
-- (1.80.0) a held arrow keeps nudging after a moment, until it's let go
Bar.scripts.OnKeyDown(Bar, "RIGHT")
check(sitsAt(P, 305, 607), "a press is one pixel")
Bar.scripts.OnUpdate(Bar, 0.2)
check(sitsAt(P, 305, 607), "held a moment: nothing more yet")
Bar.scripts.OnUpdate(Bar, 0.2)
Bar.scripts.OnUpdate(Bar, 0.06)
Bar.scripts.OnUpdate(Bar, 0.06)
check(sitsAt(P, 308, 607), "held on: it keeps going")
Bar.scripts.OnKeyUp(Bar, "RIGHT")
Bar.scripts.OnUpdate(Bar, 0.5)
check(sitsAt(P, 308, 607) and M.held == nil, "let go: it stops")
-- several moves can be taken back, newest first; a run of nudges of one frame is one move
local before = M:Undos()
M:MoveTo(P.mover, 304, 607, true)
M.undo = nil
M:Remember(P.mover, "drag")
M:MoveTo(P.mover, 400, 607, true)
M:Remember(P.mover, "drag")
M:MoveTo(P.mover, 450, 607, true)
check(before >= 1 and M:Undos() == 2, "each move is kept")
M:Undo()
check(sitsAt(P, 400, 607) and M:Undos() == 1, "Undo takes back the last one")
M:Undo()
check(sitsAt(P, 304, 607) and M.undo == nil and M.undoBtn.alpha == 0.4, "and then the one before it")
for i = 1, 14 do M:Remember(P.mover, "drag") end
check(M:Undos() == 10, "the last ten are kept")
M.undo = nil
-- Esc puts the settings window away first, and ends Move frames only when it's away
E:Open("player")
Bar.scripts.OnKeyDown(Bar, "ESCAPE")
check(not Panel.shown and ns.FUI.unlocked and Bar.propagate == false, "Esc with the settings window up puts the window away and goes on moving frames")
Bar.scripts.OnKeyDown(Bar, "ESCAPE")
check(not ns.FUI.unlocked, "Esc again ends Move frames")
SlashCmdList.VOLTUI("edit")
E:Open("player")
M:Pick(P.mover)
M.xBox:SetText("500")
M.xBox.scripts.OnEnterPressed(M.xBox)
check(sitsAt(P, 500, 607), "typing a spot")
M.yBox:SetText("100")
M.yBox.scripts.OnEnterPressed(M.yBox)
check(sitsAt(P, 500, 980), "from the top")
ns.UnitFrames:Place()
check(sitsAt(P, 500, 980), "and it's kept")
inCombat = true
Bar.scripts.OnKeyDown(Bar, "LEFT")
check(sitsAt(P, 500, 980), "nothing moves in combat")
inCombat = false
-- the toolbar's switches
M.gridBtn.scripts.OnClick()
check(VoltUIDB.grid == false and not VoltUIGrid.shown, "the grid can go")
M.gridBtn.scripts.OnClick()
M:GridSize(4)
check(VoltUIDB.gridSize == 20 and M.sizeText.text == "20 px", "and change size")
M:GridSize(-4)
M.snapBtn.scripts.OnClick()
check(VoltUIDB.snap == true, "snapping from the toolbar")
-- done
Bar.SetPropagateKeyboardInput = nil
VoltUIDB.playerLeft, VoltUIDB.playerTop, VoltUIDB.playerPoint = nil, nil, nil
ns.UnitFrames:Place()
Bar:Hide() -- Esc
check(not FUI.unlocked and not VoltUIGrid.shown and P.mover.shown == false and VoltUISettings.shown, "Esc stops moving frames; the settings stay")
E:Close()
end)()

;(function()
print("== Share and back up")
local Sh, FUI, U, E = ns.Share, ns.FUI, ns.UnitFrames, ns.EditMode
local v = { a = 1, b = "x:y{}s5:", c = { true, false, 2.5, { deep = "z" } }, [5] = "five", neg = -0.125 }
local back = Sh.Deserialize(Sh.Serialize(v))
check(back and back.a == 1 and back.b == "x:y{}s5:" and back.c[1] == true and back.c[2] == false and back.c[3] == 2.5
  and back.c[4].deep == "z" and back[5] == "five" and back.neg == -0.125, "values come back from the string as they went in")
local ok = true
for n = 0, 7 do
  local s = ("abcdefg"):sub(1, n)
  if Sh.Decode(Sh.Encode(s)) ~= s then ok = false end
end
check(ok, "letters and back, every length")
check(Sh.Deserialize("{s1:an1;") == nil and Sh.Deserialize("x") == nil, "a broken list isn't read")
VoltUIDB.font = "rajdhani"
U:Cfg("player").width = 333
VoltUIDB.playerLeft, VoltUIDB.playerTop, VoltUIDB.playerPoint = 40, -50, "TOPLEFT"
local str = Sh:Make({ look = true, frames = true, layout = true })
check(str:match("^VoltUI1:[%w%+/=]+:%x+$"), "a string of letters and numbers")
local data = Sh:Read(str)
check(data and data.parts.look.font == "rajdhani" and data.parts.frames.frameCfg.player.width == 333
  and data.parts.layout.db.playerPoint == "TOPLEFT" and data.parts.bars == nil, "with the parts picked, and only those")
check(Sh:Read("  " .. str:sub(1, 30) .. "\n" .. str:sub(31) .. " ") ~= nil, "spaces and line breaks from pasting don't matter")
local _, why = Sh:Read("hello")
check(why:find("isn't a VoltUI string", 1, true), "something else says so")
_, why = Sh:Read((str:gsub("^VoltUI1:....", "VoltUI1:ZZZZ")))
check(why:find("cut short", 1, true), "a changed or cut string is caught")
_, why = Sh:Read("VoltUI2:abcd:0000")
check(why:find("newer", 1, true), "and one from a newer VoltUI")
-- bringing it in
VoltUIDB.font = "barlow"
U:Cfg("player").width = 230
VoltUIDB.playerLeft, VoltUIDB.playerTop, VoltUIDB.playerPoint = nil, nil, nil
FUI.reloadNeeded = nil
Sh.pasted = data
Sh.import = { frames = false }
Sh:Import()
check(VoltUIDB.font == "rajdhani" and VoltUIDB.playerPoint == "TOPLEFT" and U:Cfg("player").width == 230, "brings in the parts left ticked")
check(FUI:ReloadPending() and Sh.done:find("Reload", 1, true), "and asks for a reload")
check(VoltUIDB.importUndo and VoltUIDB.importUndo.parts.look.font == "barlow", "keeping what it replaced")
Sh:Undo()
check(VoltUIDB.font == "barlow" and VoltUIDB.playerPoint == nil and VoltUIDB.importUndo == nil, "undo puts it all back")
-- bars: their look, and where they sit, are separate parts
local b1 = ns.ActionBars:Cfg("bar1")
b1.size, b1.left, b1.top, b1.point = 44, 10, -20, "TOPLEFT"
local barStr = Sh:Make({ bars = true })
local bd = Sh:Read(barStr)
check(bd.parts.bars.barCfg.bar1.size == 44 and bd.parts.bars.barCfg.bar1.left == nil, "a bar's look goes without its spot")
b1.size, b1.left = 36, 99
Sh:Apply(bd, { bars = true }, false)
b1 = ns.ActionBars:Cfg("bar1")
check(b1.size == 44 and b1.left == 99, "brought in, the bar keeps its own spot")
b1.size, b1.left, b1.top, b1.point = 36, nil, nil, nil
-- only VoltUI's own settings, never anything else in a string
Sh:Apply({ v = 1, parts = { look = { font = "chakra", evil = 1 }, layout = { db = { castLeft = 5, castTop = 6, castPoint = "LEFT", frameCfg = 1 } } } },
  { look = true, layout = true }, false)
check(VoltUIDB.font == "chakra" and VoltUIDB.evil == nil and VoltUIDB.castLeft == 5 and VoltUIDB.frameCfg ~= 1, "a string only sets VoltUI's own settings")
check(VoltUIDB.alpha == 0.85 and VoltUIDB.glow == 0.6, "and what it leaves out goes back to its default")
VoltUIDB.font = "barlow"
VoltUIDB.castLeft, VoltUIDB.castTop, VoltUIDB.castPoint = nil, nil, nil
-- the page
E:Open("share")
local mk
for _, r in ipairs(E.rows) do if r.def.kind == "button" and r.def.text == "Make the string" then mk = r end end
mk.button.scripts.OnClick()
check(Sh.out.fixed:find("^VoltUI1:"), "Make the string fills the box")
local imp
for _, r in ipairs(E.rows) do if r.def.text == "Bring it in" then imp = r end end
check(imp.alpha == 0.45, "nothing to bring in yet")
Sh.into.edit.text = Sh.out.fixed
Sh.into.edit.scripts.OnTextChanged(Sh.into.edit, true)
check(Sh.pasted and imp.alpha == 1, "a pasted string can be brought in")
Sh.pasted, Sh.into.edit.text = nil, ""
FUI.reloadNeeded = nil
E:Close()
end)()

;(function()
print("== Errors")
local Er, E = ns.Errors, ns.EditMode
check(Er.session >= 1 and VoltUIDB.errorLog == Er:List(), "kept in VoltUI's saved settings, by session")
ScriptErrorsFrame = { DisplayMessageInternal = function(self, msg) self.got = msg end }
Er.hooked = nil
check(Er:Hook(), "listens after the game's error window")
Er:Clear()
wipe(chat)
local stack = "[Interface/AddOns/VoltUI/Bags.lua]:10: in function <Interface/AddOns/VoltUI/Bags.lua:5>"
ScriptErrorsFrame:DisplayMessageInternal("Interface/AddOns/VoltUI/Bags.lua:10: attempt to index a nil value", 0, stack, "x = nil")
local e = Er:List()[1]
check(ScriptErrorsFrame.got and e and e.mine and e.count == 1 and e.stack == stack, "the game's window still gets it; VoltUI keeps it as its own")
check(#chat == 1 and chat[1]:find("/volt errors", 1, true), "and says so in chat")
check(VoltUIMinimapButton.badge.shown, "with a dot on the minimap icon")
ScriptErrorsFrame:DisplayMessageInternal("Interface/AddOns/VoltUI/Bags.lua:10: attempt to index a nil value", 0, stack, "x = nil")
check(#Er:List() == 1 and e.count == 2 and #chat == 1, "the same error again is counted, once in chat")
ScriptErrorsFrame:DisplayMessageInternal("Interface/AddOns/Other/x.lua:1: oops", 0, "[Interface/AddOns/Other/x.lua]:1", "")
ScriptErrorsFrame:DisplayMessageInternal("just a warning", 1)
check(#Er:List() == 2 and #Er:Shown() == 1, "another add-on's is kept but not listed; warnings aren't kept")
VoltUIDB.errorsAll = true
check(#Er:Shown() == 2, "unless you ask")
VoltUIDB.errorsAll = false
local oldSecret = issecretvalue
local SECRET = {}
issecretvalue = function(v) return v == SECRET end
ScriptErrorsFrame:DisplayMessageInternal(SECRET, 0, "[Interface/AddOns/VoltUI/x.lua]:1", "")
issecretvalue = oldSecret
check(Er:List()[1].msg == "(hidden by the game)", "a message the game hides stays hidden, without breaking")
for i = 1, 45 do Er:Add("VoltUI test " .. i, "", nil, "volt") end
check(#Er:List() == 40, "the last 40 are kept")
Er:Clear()
fire("ADDON_ACTION_BLOCKED", "VoltUI", "Frame:Show()")
check(Er:List()[1] and Er:List()[1].kind == "blocked" and Er:List()[1].msg:find("Frame:Show()", 1, true), "blocked actions go on the list")
ScriptErrorsFrame:DisplayMessageInternal("Interface/AddOns/VoltUI/Bags.lua:10: attempt to index a nil value", 0, stack, "x = nil")
-- the page
SlashCmdList.VOLTUI("errors")
check(VoltUISettings.shown and E.tab == "errors", "/volt errors opens the page")
local list
for _, r in ipairs(E.rows) do if r.items then list = r end end
check(list and list.items[1].shown ~= false and list.items[1].text.text:find("attempt to index", 1, true), "the newest first")
check(not VoltUIMinimapButton.badge.shown, "seen: the dot goes")
list.items[2].scripts.OnClick(list.items[2])
check(Er.picked == Er:List()[2] and Er.box.fixed:find("Frame:Show()", 1, true), "clicking one shows all of it")
local rep
for _, r in ipairs(E.rows) do if r.def.text == "Make a report" then rep = r end end
rep.button.scripts.OnClick()
check(Er.box.fixed:find("^VoltUI ") and Er.box.fixed:find("Parts on:", 1, true) and Er.box.fixed:find("Bags.lua:10", 1, true), "a report has VoltUI's version, the parts on and every error")
local clr
for _, r in ipairs(E.rows) do if r.def.text == "Clear" then clr = r end end
clr.button.scripts.OnClick()
check(#Er:List() == 0 and list.empty.shown, "Clear starts again")
ScriptErrorsFrame = nil
E:Close()
end)()

-- Minimap: moving and scaling
;(function()
print("== Minimap: moving and scaling")
-- These measure the holder as the map and its strip, so the line of readouts is put away for them.
for _, k in ipairs({ "stripClock", "stripMs", "stripFps", "stripDura", "stripGold", "stripMail" }) do VoltUIDB[k] = false end
ns.Minimap:ApplyInfo()
VoltUIDB.snapFrames = false -- these drop frames where they want them; snapping to frames has its own tests
local MM, Hold, E = ns.Minimap, VoltUIMinimapHolder, ns.EditMode
local realLockdown = InCombatLockdown
InCombatLockdown = function() return false end
local function lastPoint(f) return f.points[#f.points] end
local function near(a, b) return math.abs(a - b) < 0.02 end
VoltUIDB.snap = false
MM:Reset()
SlashCmdList.VOLTUI("edit")
check(Hold.mover.shown, "moving frames shows its overlay")
-- dragged to the middle
Hold.dropLeft, Hold.dropTop = 860, 560
Hold.mover.scripts.OnDragStart(Hold.mover)
Hold.mover.scripts.OnDragStop(Hold.mover)
check(VoltUIDB.minimapPoint == "CENTER" and VoltUIDB.minimapLeft == -100 and VoltUIDB.minimapTop == 20, "the spot is saved")
check(sitsAt(Hold, 860, 560), "and it stays there")
-- bigger, around its middle
VoltUIDB.minimapScale = 2
MM:Rescale()
local l, t = MM:TopLeft(2)
check(Hold.scale == 2 and near(l, 760) and near(t, 678), "twice the size, around its middle: " .. l .. ", " .. t)
VoltUIDB.minimapScale = 1
MM:Rescale()
l, t = MM:TopLeft(1)
check(Hold.scale == 1 and near(l, 860) and near(t, 560), "and back")
-- in the bottom-left corner it grows up and to the right
Hold.dropLeft, Hold.dropTop = 20, 240
Hold.mover.scripts.OnDragStart(Hold.mover)
Hold.mover.scripts.OnDragStop(Hold.mover)
check(VoltUIDB.minimapPoint == "BOTTOMLEFT", "near the bottom-left corner")
VoltUIDB.minimapScale = 0.5
MM:Rescale()
l, t = MM:TopLeft(0.5)
check(near(l, 20) and near(t - 236 * 0.5, 4), "half the size, its bottom-left corner where it was")
-- in the top-right corner, from where the game had it
MM:Reset()
check(Hold.scale == 1 and not VoltUIDB.minimapLeft and lastPoint(Hold)[1] == "TOPRIGHT", "reset: back where the game had it")
VoltUIDB.minimapScale = 1.5
MM:Rescale()
l, t = MM:TopLeft(1.5)
check(near(l + 200 * 1.5, 1920 - 18) and near(t, 1080 - 43), "bigger in the top-right corner: its top-right corner stays")
-- not in combat
InCombatLockdown = function() return true end
VoltUIDB.minimapScale = 1
MM:Rescale()
check(Hold.scale == 1.5 and MM.rescalePending, "a new size waits for the fight to end")
InCombatLockdown = function() return false end
fire("PLAYER_REGEN_ENABLED")
l, t = MM:TopLeft(1)
check(Hold.scale == 1 and not MM.rescalePending and near(l + 200, 1902) and near(t, 1037), "then it's put on")
-- the settings page
E:Open("maps")
check(E.tab == "maps" and ns.Move.picked == Hold.mover, "its page picks it for the arrow keys")
local function rowOf(key, text)
  for _, r in ipairs(E.rows) do
    if r.shown ~= false and r.def and ((key and r.def.key == key) or (text and r.def.text == text)) then return r end
  end
end
local sc = rowOf("minimapScale")
check(sc ~= nil, "a scale row")
if sc then
  sc:Step(1)
  check(near(VoltUIDB.minimapScale, 1.05) and near(Hold.scale, 1.05), "the scale row sizes it")
end
local before = VoltUIDB.minimapLeft
ns.Move:Nudge(1, 0)
check(before and VoltUIDB.minimapLeft and VoltUIDB.minimapLeft > before, "the arrow keys nudge it")
local back = rowOf(nil, "Reset spot")
check(back ~= nil, "a button to put it back")
if back then
  back.button.scripts.OnClick()
  check(VoltUIDB.minimapScale == 1 and not VoltUIDB.minimapLeft and Hold.scale == 1, "Put it back: the game's spot and size")
end
E:Select("general")
Hold.mover.scripts.OnMouseDown(Hold.mover)
Hold.mover.scripts.OnMouseUp(Hold.mover)
check(E.tab == "maps", "clicking its overlay opens its page")
-- search finds it
E:Search("minimap scale")
local found = false
for _, r in ipairs(E.rows) do if r.def and r.def.key == "minimapScale" then found = true end end
check(found, "search finds the minimap's scale")
E:ClearSearch()
-- /volt minimap
SlashCmdList.VOLTUI("minimap scale 1.2")
check(near(VoltUIDB.minimapScale, 1.2) and near(Hold.scale, 1.2), "/volt minimap scale")
SlashCmdList.VOLTUI("minimap scale 9")
check(VoltUIDB.minimapScale == 2, "kept between 0.5 and 2")
SlashCmdList.VOLTUI("minimap reset")
check(VoltUIDB.minimapScale == 1 and not VoltUIDB.minimapLeft, "/volt minimap reset")
-- sharing
Hold.dropLeft, Hold.dropTop = 860, 560
Hold.mover.scripts.OnDragStart(Hold.mover)
Hold.mover.scripts.OnDragStop(Hold.mover)
VoltUIDB.minimapScale = 1.3
check(ns.Share:Collect("world").minimapScale == 1.3, "its size goes with the maps in an export")
check(ns.Share:Collect("layout").db.minimapLeft == -100, "and its spot with the layout")
MM:Reset()
SlashCmdList.VOLTUI("edit")
E:Close()
InCombatLockdown = realLockdown
end)()

-- 1.33.0: small fixes from the interface review
print("== Interface review: small fixes")
;(function()
  local E, D = ns.EditMode, ns.Dispel
  -- the settings window remembers its page
  E:Open("bags")
  check(VoltUIDB.editPage == "bags", "the settings window notes the page it's on")
  E:Close()
  E.tab = nil -- as after a reload
  E:Open()
  check(E.tab == "bags", "and opens there next time")
  VoltUIDB.editPage = "no-such-page"
  E:Close()
  E.tab = nil
  E:Open()
  check(E.tab == "home", "a page that's gone falls back to Home")
  -- Enter in the search box opens the first thing found
  E:Search("minimap scale")
  check(E.firstHit == "maps", "search notes its first hit")
  E.searchBox.scripts.OnEnterPressed(E.searchBox)
  check(E.tab == "maps" and not E.query and not E.firstHit, "Enter opens that page and clears the search")
  E:Search("zzzz-nothing")
  check(E.firstHit == nil, "nothing found, nothing to open")
  E.searchBox.scripts.OnEnterPressed(E.searchBox)
  check(E.tab == "maps", "and Enter leaves the page alone")
  E:ClearSearch()
  E:Close()
  -- the dispel windows' overlay covers every row a raid fills
  local oldRaid, oldCount, oldLock = IsInRaid, GetNumGroupMembers, InCombatLockdown
  local size = tonumber(D:Cfg().size) or 32
  IsInRaid = function() return false end
  fire("GROUP_ROSTER_UPDATE")
  check(D:Rows() == 1 and VoltUIDispelFrames.h == size, "dispel windows: one row for a party")
  IsInRaid = function() return true end
  GetNumGroupMembers = function() return 23 end
  fire("GROUP_ROSTER_UPDATE")
  check(D:Rows() == 5 and VoltUIDispelFrames.h == 5 * size + 8 and VoltUIDispelFrames.w == 5 * size + 8, "five rows for a raid of 23")
  GetNumGroupMembers = function() return 40 end
  InCombatLockdown = function() return true end
  fire("GROUP_ROSTER_UPDATE")
  check(VoltUIDispelFrames.h == 5 * size + 8 and D.applyPending, "in combat the size waits")
  InCombatLockdown = oldLock
  fire("PLAYER_REGEN_ENABLED")
  check(VoltUIDispelFrames.h == 8 * size + 14, "and catches up after the fight: eight rows for 40")
  IsInRaid, GetNumGroupMembers = oldRaid, oldCount
  fire("GROUP_ROSTER_UPDATE")
  -- 1.34.0: a reputation bar left at the old default goes off once; one you placed stays
  local AB = ns.ActionBars
  local keep = VoltUIDB.barCfg.rep
  VoltUIDB.barRepOff = nil
  VoltUIDB.barCfg.rep = { on = true }
  check(AB:Cfg("rep").on == false and VoltUIDB.barRepOff, "an unmoved reputation bar is switched off by the update")
  AB:Cfg("rep").on = true
  check(AB:Cfg("rep").on == true, "only once: switching it back on sticks")
  VoltUIDB.barRepOff = nil
  VoltUIDB.barCfg.rep = { on = true, left = 10, top = 20, point = "TOPLEFT" }
  check(AB:Cfg("rep").on == true, "one you placed yourself stays on")
  VoltUIDB.barCfg.rep = keep
  -- 1.53.0: the rest of the review
  ;(function()
    local FUI, M, P, U = ns.FUI, ns.Move, ns.Pages, ns.UnitFrames
    local oldLock = InCombatLockdown
    InCombatLockdown = function() return false end
    -- search: two letters or more, a page's name alone isn't a match, Open page goes to the card
    E:Open("home")
    E:Search("w")
    check(E.query == "w" and #E.rows == 0 and E.noResults.shown and E.noResults.text:find("two letters", 1, true), "one letter asks for more rather than drawing every setting")
    E:Search("player")
    local all = #E:Page("player").rows
    check(#E.rows < all, "a page's name by itself doesn't return every setting on that page: " .. #E.rows .. " of " .. all)
    E:Search("target width")
    local hit, card
    for id, c in pairs(E.results) do
      if c.shown and id:find("^target#") then card = c end
    end
    for _, r in ipairs(E.rows) do if r.page == "target" and r.def.key == "width" then hit = r end end
    check(hit and card and card.cardIndex == 1, "but it still narrows a search: target width finds the target frame's width")
    card.action.scripts.OnClick(card.action)
    check(E.tab == "target" and not E.query, "Open page goes to that page")
    E:ClearSearch()
    -- reset can be undone
    E:Select("pet")
    local c = U:Cfg("pet")
    local w0 = c.width
    c.width, c.hpPct = 177, true
    VoltUIDB.petLeft, VoltUIDB.petTop, VoltUIDB.petPoint = 40, 50, "BOTTOMLEFT"
    U:Place()
    E.reset.scripts.OnClick()
    E.reset.scripts.OnClick()
    check(U:Cfg("pet").width == w0 and VoltUIDB.petPoint == nil and E.banner.shown and E.banner.button.text.text == "Undo", "Reset puts the page back to its defaults, and offers Undo")
    E.banner.fn()
    check(U:Cfg("pet").width == 177 and U:Cfg("pet").hpPct == true and VoltUIDB.petPoint == "BOTTOMLEFT" and VoltUIDB.petLeft == 40, "Undo brings back every setting and the frame's spot")
    U:ResetFrame("pet")
    E.toast = nil
    -- a wide page keeps ordinary cards in two columns
    E:Select("clicks")
    local pg = E.pages.clicks
    local fullCards, narrow = 0, 0
    for _, cd in ipairs(pg.cards) do
      if cd.full then fullCards = fullCards + 1 else narrow = narrow + 1 end
    end
    check(fullCards >= 1 and narrow >= 2, "the Clicks page: the grid is full width, the other cards are not: " .. fullCards .. " and " .. narrow)
    local grid, plain
    for _, cd in ipairs(pg.cards) do
      if cd.full and not grid then grid = cd end
      if not cd.full and not plain then plain = cd end
    end
    check(grid.w > 600 and plain.w == E.COL_W, "full is the page's width, the rest a column's")
    E:Select("home")
    check(E.pages.home.cards[1].full and E.pages.home.cards[1].w > 600, "Home's cards are all full width")
    -- heal mode's pages are kept, not rebuilt on every flip
    local R = ns.Raid
    local was = R:Cfg().healEdit
    R:Cfg().healEdit = "party"
    E:Select("heal")
    local partyPage = E.pages.heal
    R:Cfg().healEdit = "raid"
    E:Select("heal")
    local raidPage = E.pages.heal
    R:Cfg().healEdit = "party"
    E:Select("heal")
    check(raidPage ~= partyPage and E.pages.heal == partyPage and partyPage.frame.shown and not raidPage.frame.shown, "flipping heal mode between party and raid reuses the pages already built")
    R:Cfg().healEdit = was
    E:Select("heal")
    -- names
    E:Select("loot")
    local names = {}
    for _, r in ipairs(E.rows) do if r.button then names[r.button.text.text or ""] = true end end
    check(names["Reset spot"] and not names["Default spot"], "putting a window back is called Reset spot everywhere")
    FUI:SetUnlocked(true)
    check(M.snapBtn.text.text == "Snap: grid" and M.alignBtn.text.text == "Snap: frames", "the toolbar names its two snaps alike")
    FUI:SetUnlocked(false)
    -- deleting a profile confirms the way Reset does
    local Pr = ns.Profiles
    local name = Pr:New("Spare")
    Pr:Use("Default")
    Pr.picked, Pr.armed = name, nil
    E:Select("profiles")
    local del
    for _, r in ipairs(E.rows) do if r.def.label == "Remove it" then del = r end end
    check(del and del.button.text.text == "Delete", "Delete on the Profiles page")
    del.button.scripts.OnClick(del.button)
    check(VoltUIDB.profiles[name] ~= nil and del.button.text.text == "Click to confirm", "the first click asks, on the button itself")
    del.button.scripts.OnClick(del.button)
    check(VoltUIDB.profiles[name] == nil, "the second deletes it")
    Pr.picked, Pr.armed = nil, nil
    -- Copy to all bars can be undone
    local AB = ns.ActionBars
    E:Select("bars")
    local s1, s2 = AB:Cfg("bar1").size, AB:Cfg("bar2").size
    AB:Cfg("bar1").size = 44
    E.actionButtons.copy.scripts.OnClick(E.actionButtons.copy)
    check(AB:Cfg("bar2").size == 44 and E.banner.shown and E.banner.button.text.text == "Undo", "Copy to all bars says what it did and offers Undo")
    E.banner.fn()
    check(AB:Cfg("bar2").size == s2 and AB:Cfg("bar1").size == 44, "Undo gives the other bars their own look back")
    AB:Cfg("bar1").size = s1
    AB:ApplyAll()
    E.toast = nil
    E:Close()
    InCombatLockdown = oldLock
  end)()
  -- 1.52.0: fixes from a review of everything built since 1.33
  ;(function()
    local M, FUI, St = ns.Move, ns.FUI, ns.Style
    -- searching before the Action bars page has ever been opened
    local bar, extra = E.barKey, E.extraKey
    E:Open("home")
    E.barKey, E.extraKey = nil, nil
    local ok, err = pcall(E.Search, E, "size")
    check(ok, "a search with no bar picked yet doesn't throw: " .. tostring(err))
    E:ClearSearch()
    E.barKey, E.extraKey = bar or "bar1", extra
    check(E.barKey ~= nil, "a bar is picked from the start")
    -- the copy window belongs to its page
    E:Select("player")
    E:OpenCopy()
    check(VoltUICopy and VoltUICopy.shown, "Copy from opens")
    check(VoltUICopy.strata == "FULLSCREEN_DIALOG" and VoltUISettings.strata == "DIALOG", "in front of the settings window")
    E:Select("bags")
    check(not VoltUICopy.shown, "and closes when you leave the page, so it can't copy onto the wrong one")
    -- a row's hover covers its label, not its control
    E:Select("player")
    local by = {}
    for _, r in ipairs(E.rows) do if r.def.key then by[r.def.key] = r end end
    check(by.width.tipZone and by.width.tipZone.w <= 164 and by.width.slider.w == 126, "a slider row's hover stops short of the slider: " .. tostring(by.width.tipZone.w))
    check(by.width.label.points[#by.width.label.points][2] == by.width.slider, "and its label is cut off at the slider rather than drawn over it")
    -- colour swatches copy too
    E:Select("party")
    local R = ns.Raid
    local keep = R.Copy(R:Set("party").customColor)
    R:Set("raid").customColor = { 0.11, 0.22, 0.33 }
    local plan = E:CopyPlan({ name = "Raid frames", get = function(def) return R:Set("raid")[def.key] end }, "all", {})
    local found
    for _, step in ipairs(plan) do if step.def.key == "customColor" then found = step.value end end
    check(found and found[1] == 0.11, "Copy from takes colours as well")
    R:Set("raid").customColor = R.Copy(keep)
    -- a stand-in stays picked when its page opens
    FUI:SetUnlocked(true)
    local loot = VoltUIAnchor_loot
    loot.mover.scripts.OnMouseUp(loot.mover)
    check(M.picked == loot.mover and E.tab == "loot", "clicking a window's box opens its page and keeps that box picked")
    -- the settings window can be put away without ending Move frames
    check(M.winBtn and M.winBtn.text.text == "Hide settings", "the toolbar offers to hide the settings window")
    M.winBtn.scripts.OnClick(M.winBtn)
    check(not VoltUISettings.shown and FUI.unlocked and M.winBtn.text.text == "Show settings", "hiding it leaves frames movable")
    M.winBtn.scripts.OnClick(M.winBtn)
    check(VoltUISettings.shown and FUI.unlocked, "and it comes back")
    -- a typed spot stays on the screen
    M:Pick(loot.mover)
    M:Typed("x", "99999")
    local W = UIParent:GetWidth()
    check(select(1, M:Corner(loot.mover)) <= W, "a typed 99999 is held at the screen's edge")
    M:ResetSpot()
    -- a drag cut short by combat ends properly
    loot.dropLeft, loot.dropTop = 333, 444
    loot.mover.scripts.OnDragStart(loot.mover)
    check(loot.mover.dragging, "dragging")
    loot.mover:Hide()
    check(not loot.mover.dragging and VoltUIDB.lootPoint ~= nil, "an overlay hidden mid-drag still drops its frame and saves the spot")
    VoltUIDB.lootLeft, VoltUIDB.lootTop, VoltUIDB.lootPoint = nil, nil, nil
    check(M.bar.w == 1100 and (M.bar.scale or 1) <= 1, "the toolbar has room for its buttons, and shrinks on a narrow screen")
    FUI:SetUnlocked(false)
    -- lists side by side
    Extra("lists side by side") -- another add-on's tests, since VoltUI 1.104.0
    E:Close()
  end)()
  -- 1.51.0: one set of greys for text that isn't the main thing
  ;(function()
    local St = ns.Style
    check(St.SUB[1] == 0.75 and St.HINT[1] == 0.6 and St.OFF[1] == 0.5, "three shared greys: secondary text, hints, and things that are off")
    Extra("alerts grey") -- another add-on's tests, since VoltUI 1.104.0
    local greys = {}
    for _, fs in ipairs(allFontStrings) do
      local c = not fs.questie and fs.color
      if c and c[1] and c[2] and c[3] and math.max(c[1], c[2], c[3]) - math.min(c[1], c[2], c[3]) <= 0.09 then
        local mid = (c[1] + c[2] + c[3]) / 3
        if mid >= 0.44 and mid < 0.815 then greys[("%.2f,%.2f,%.2f"):format(c[1], c[2], c[3])] = true end
      end
    end
    local n, list = 0, {}
    for k in pairs(greys) do n = n + 1; list[#list + 1] = k end
    table.sort(list)
    -- 1.66.0: VoltUI's own windows add their three neutral greys (S.UI sub, hint, off) to the six
    check(n <= 8, "text across VoltUI's windows is down to a handful of greys: " .. table.concat(list, " | "))
  end)()
  -- 1.50.0: starting layouts, which never touch a layout that's already there
  ;(function()
    local Su, FUI = ns.Setup, ns.FUI
    local SPOTS = { "player", "target", "tot", "pet", "focus", "cast", "raid" }
    local function snapshot()
      local t = {}
      for _, k in ipairs(SPOTS) do t[k] = { VoltUIDB[k .. "Left"], VoltUIDB[k .. "Top"], VoltUIDB[k .. "Point"] } end
      return t
    end
    local function same(a, b)
      for _, k in ipairs(SPOTS) do
        for i = 1, 3 do if a[k][i] ~= b[k][i] then return false end end
      end
      return true
    end
    local oldLock = InCombatLockdown
    InCombatLockdown = function() return false end
    -- someone who already has VoltUI set up
    check(ns.freshInstall == false and VoltUIDB.setupDone == true, "an install with settings already is marked as set up")
    local opened = 0
    local realOpen = Su.Open
    Su.Open = function(self) opened = opened + 1 end
    Su:FirstRun()
    runTimers()
    check(opened == 0, "so the starting-layouts window never opens by itself for them")
    -- a brand-new install
    ns.freshInstall, VoltUIDB.setupDone = true, nil
    Su:FirstRun()
    runTimers()
    check(opened == 1, "on a brand-new install it opens once, a moment after login")
    Su.Open = realOpen
    ns.freshInstall, VoltUIDB.setupDone = false, true
    -- a layout of your own: opening the window changes nothing
    VoltUIDB.playerLeft, VoltUIDB.playerTop, VoltUIDB.playerPoint = -400, 500, "BOTTOM"
    VoltUIDB.raidLeft, VoltUIDB.raidTop, VoltUIDB.raidPoint = 30, 100, "LEFT"
    VoltUIDB.petLeft, VoltUIDB.petTop, VoltUIDB.petPoint = 12, 34, "TOPLEFT"
    FUI:PlaceAll()
    local mine = snapshot()
    SlashCmdList.VOLTUI("setup")
    local w = VoltUISetup
    check(w and w.shown and #w.cards == 4 and w.cards[1].name.text == "Classic" and w.cards[2].name.text == "Centre"
      and w.cards[3].name.text == "Healer" and w.cards[4].name.text == "Top left", "/volt setup opens it: four layouts to pick from")
    check(same(mine, snapshot()) and not w.undo.shown and w.keep.text.text == "Keep what I have", "opening it moves nothing")
    check(#w.cards[2].thumb.boxes >= 6, "each layout is drawn as a little screen")
    w.keep.scripts.OnClick(w.keep)
    check(not w.shown and same(mine, snapshot()) and VoltUIDB.setupUndo == nil, "Keep what I have closes it, and still nothing has moved")
    -- picking one
    Su:Open()
    w.cards[3].use.scripts.OnClick(w.cards[3].use)
    check(VoltUIDB.playerPoint == "BOTTOM" and VoltUIDB.playerLeft == -254 and VoltUIDB.playerTop == 176 and VoltUIDB.raidPoint == "BOTTOM" and VoltUIDB.castTop == 119,
      "Healer puts the frames where it says")
    check(VoltUIDB.petPoint == nil, "a frame the layout doesn't place goes back to following its default")
    check(sitsAt(VoltUIPlayerFrame, UIParent:GetWidth() / 2 - 254, 176), "and the frames move there straight away")
    check(w.undo.shown and w.keep.text.text == "Done" and w.note.text:find("Healer", 1, true), "the window says which is in use and offers Undo")
    -- only spots changed
    check(VoltUIDB.font ~= nil and ns.UnitFrames:Cfg("player").width ~= nil, "no other setting is touched")
    w.cards[2].use.scripts.OnClick(w.cards[2].use)
    check(VoltUIDB.playerTop == 340 and VoltUIDB.raidPoint == nil, "picking another swaps to it")
    -- undo goes all the way back: to your own layout, not the last one you tried
    w.undo.scripts.OnClick(w.undo)
    check(same(mine, snapshot()) and not w.undo.shown, "Undo after trying two layouts puts every frame back where it was to begin with")
    -- back to your own layout exactly
    VoltUIDB.playerLeft, VoltUIDB.playerTop, VoltUIDB.playerPoint = -400, 500, "BOTTOM"
    VoltUIDB.raidLeft, VoltUIDB.raidTop, VoltUIDB.raidPoint = 30, 100, "LEFT"
    VoltUIDB.petLeft, VoltUIDB.petTop, VoltUIDB.petPoint = 12, 34, "TOPLEFT"
    VoltUIDB.castLeft, VoltUIDB.castTop, VoltUIDB.castPoint = nil, nil, nil
    mine = snapshot()
    Su:Apply("classic")
    check(VoltUIDB.playerPoint == nil and VoltUIDB.raidPoint == nil, "Classic clears the spots, for VoltUI's defaults")
    Su:Undo()
    check(same(mine, snapshot()), "and Undo brings your own layout back exactly")
    -- not in combat
    InCombatLockdown = function() return true end
    check(Su:Apply("healer") == false and same(mine, snapshot()), "in combat a layout isn't applied")
    w.cards[3].use.scripts.OnClick(w.cards[3].use)
    check(w.note.text:find("combat", 1, true) and same(mine, snapshot()), "and the window says why")
    InCombatLockdown = function() return false end
    check(Su:Apply("no-such-layout") == false, "a layout that doesn't exist does nothing")
    -- the Home page has a way in
    E:Open("home")
    local way
    for _, r in ipairs(E.rows) do
      for _, b in ipairs(r.buttons or {}) do if b.item and b.item.key == "setup" then way = b end end
    end
    check(way and way.text.text == "Layouts", "Home has a Layouts shortcut")
    -- 1.100.0: the three presets, on the Home page, which lay out action bars 2 and 3 as well
    local row
    for _, r in ipairs(E.rows) do if r.cards and r.undo then row = r end end
    check(row and #row.cards == 3 and row.cards[1].name.text == "Centre" and row.cards[2].name.text == "Healer"
      and row.cards[3].name.text == "Top left", "Home has the three presets: Centre, Healer, Top left")
    local AB = ns.ActionBars
    if row and AB.started then
      VoltUIDB.setupUndo = nil
      local b2, b3 = AB:Cfg("bar2"), AB:Cfg("bar3")
      b2.on, b2.perRow, b2.point, b2.left, b2.top = false, 12, nil, nil, nil
      b3.on, b3.perRow, b3.point, b3.left, b3.top = true, 4, "BOTTOM", 10, 300
      mine = snapshot()
      check(not row.undo.shown and row.cards[1].use.text.text == "Use" and #row.cards[1].thumb.boxes >= 6, "nothing is in use until you press Use")
      row.cards[1].use.scripts.OnClick(row.cards[1].use)
      check(VoltUIDB.playerLeft == -254 and VoltUIDB.playerTop == 340 and VoltUIDB.castTop == 258, "Centre puts player, target and cast bar under your character")
      check(b2.on == true and b2.perRow == 6 and b2.point == "BOTTOM" and b2.left == -475 and b2.top == 95
        and b3.on == true and b3.perRow == 6 and b3.left == 245, "and bars 2 and 3 become blocks of six either side of bar 1")
      check(sitsAt(AB.frames.bar2, UIParent:GetWidth() / 2 - 475, 95), "the bars move there straight away")
      check(row.undo.shown and row.cards[1].use.text.text == "In use" and row.note.text:find("Centre", 1, true), "the card says it's in use, and Undo shows")
      row.cards[2].use.scripts.OnClick(row.cards[2].use)
      check(b2.on == true and b2.perRow == 12 and b2.point == nil and b3.on == false and VoltUIDB.raidPoint == "BOTTOM" and VoltUIDB.raidTop == 390,
        "Healer: two full bars, bar 3 off, groups in the middle")
      check(row.cards[1].use.text.text == "Use" and row.cards[2].use.text.text == "In use", "only one preset is in use")
      row.cards[3].use.scripts.OnClick(row.cards[3].use)
      check(VoltUIDB.playerPoint == "TOPLEFT" and VoltUIDB.playerLeft == 24 and VoltUIDB.playerTop == -24 and VoltUIDB.targetLeft == 266
        and VoltUIDB.raidPoint == "TOPLEFT" and b2.on == true and b3.on == true and b3.perRow == 12, "Top left: frames in the corner, three bars stacked")
      Su:Apply("classic")
      check(b2.on == false and b3.on == true and b3.perRow == 4 and b3.left == 10 and b3.top == 300, "a layout with no bars of its own gives your bars back")
      row.cards[1].use.scripts.OnClick(row.cards[1].use)
      InCombatLockdown = function() return true end
      row.undo.scripts.OnClick(row.undo)
      check(b2.perRow == 6 and row.note.text:find("combat", 1, true), "Undo waits for the fight to end, and says so")
      InCombatLockdown = function() return false end
      row.undo.scripts.OnClick(row.undo)
      check(same(mine, snapshot()) and b2.on == false and b2.perRow == 12 and b2.left == nil
        and b3.on == true and b3.perRow == 4 and b3.point == "BOTTOM" and b3.left == 10 and b3.top == 300,
        "Undo puts frames and bars back exactly as they were before the first preset")
      check(not row.undo.shown and row.cards[1].use.text.text == "Use" and VoltUIDB.setupUsed == nil, "and nothing is in use any more")
      -- an Undo kept by 1.50-1.99 has no bars in it: your bars are noted then
      VoltUIDB.setupUndo = { player = {} }
      Su:Apply("healer")
      check(type(VoltUIDB.setupUndo.bars) == "table" and VoltUIDB.setupUndo.bars.bar3.perRow == 4, "an older Undo gains your bars before a preset changes them")
      Su:Undo()
      b2.on, b2.perRow = false, 12
      b3.on, b3.perRow, b3.point, b3.left, b3.top = false, 12, nil, nil, nil
      AB:ApplyAll()
    end
    E:Close()
    w:Hide()
    for _, k in ipairs(SPOTS) do VoltUIDB[k .. "Left"], VoltUIDB[k .. "Top"], VoltUIDB[k .. "Point"] = nil, nil, nil end
    VoltUIDB.setupUndo = nil
    FUI:PlaceAll()
    if ns.Raid.holder then ns.Raid:PlaceHolder() end
    InCombatLockdown = oldLock
  end)()
  -- 1.49.0: the chat windows in VoltUI's look
  ;(function()
    local C = ns.Chat
    check(C and C.enabled and VoltUIDB.chat ~= false, "the chat part is on by default")
    local art = new("Texture", "ChatFrame7Background")
    local tabArt = new("Texture", "ChatFrame7TabLeft")
    local editArt = new("Texture", "ChatFrame7EditBoxLeft")
    local frame = new("ScrollingMessageFrame", "ChatFrame7")
    frame.GetName = function() return "ChatFrame7" end
    local tab = new("Button", "ChatFrame7Tab")
    tab.Text = new("FontString")
    local box = new("EditBox", "ChatFrame7EditBox")
    art:SetAlpha(1); tabArt:SetAlpha(1); editArt:SetAlpha(1)
    C:SkinAll()
    check(C.skinned[frame] and frame.voltBack and frame.voltBack.fuiPanel and frame.voltBack.parent == frame, "a chat window gets a VoltUI panel behind it")
    check(art.alpha == 0 and tabArt.alpha == 0 and editArt.alpha == 0, "the game's chat art is made see-through")
    art:SetAlpha(1)
    check(art.alpha == 0, "and stays that way when the game fades it back in")
    check(box.voltBack and box.voltBack.fuiPanel and tab.Text.font and tab.Text.font[1]:find("Fonts"), "the box you type in gets a panel, the tab VoltUI's font")
    local back = frame.voltBack
    C:SkinAll()
    check(frame.voltBack == back, "only once")
    local a0 = VoltUIDB.chatAlpha
    VoltUIDB.chatAlpha = 0.8
    C:Refresh()
    check(math.abs(back.fuiPanel.fill.ctex[4] - 0.8) < 1e-9, "the panel's opacity follows its setting")
    VoltUIDB.chatAlpha = a0
    C:Refresh()
    ChatFrame7, ChatFrame7Tab, ChatFrame7EditBox, ChatFrame7Background, ChatFrame7TabLeft, ChatFrame7EditBoxLeft = nil, nil, nil, nil, nil, nil
  end)()
  -- 1.54.0: the chat's scroll bar and buttons, and moving and resizing it
  ;(function()
    local C, FUI, M = ns.Chat, ns.FUI, ns.Move
    local function tex(owner) local t = owner:CreateTexture(nil, "ARTWORK"); t:SetAlpha(1); return t end
    local frame = new("ScrollingMessageFrame", "ChatFrame8")
    frame.GetName = function() return "ChatFrame8" end
    local sb = new("Frame", nil, frame)
    sb.Back, sb.Forward, sb.Track = new("Button", nil, sb), new("Button", nil, sb), new("Frame", nil, sb)
    sb.Track.Thumb = new("Button", nil, sb.Track)
    local arrow, thumbArt, trackArt = tex(sb.Back), tex(sb.Track.Thumb), tex(sb.Track)
    frame.ScrollBar = sb
    local down = new("Button", nil, frame)
    local downArt = tex(down)
    down.Flash = tex(down)
    frame.ScrollToBottomButton = down
    C:Skin(frame)
    check(arrow.alpha == 0 and thumbArt.alpha == 0 and trackArt.alpha == 0, "the scroll bar's own art is made see-through")
    check(sb.voltThumb and sb.voltThumb.parent == sb.Track.Thumb and sb.voltThumb.w == 4 and sb.voltThumb.alpha ~= 0 and sb.voltLine.w == 1, "a flat thumb on a thin line takes its place")
    sb.Track.Thumb.scripts.OnEnter(sb.Track.Thumb)
    check(sb.voltThumb.ctex[1] == 1 and sb.voltThumb.ctex[3] < 0.2, "the thumb lights up gold under the mouse (1.86.0)")
    check(downArt.alpha == 0 and down.Flash.alpha == 1 and #down.regions == 4, "back-to-newest: a flat arrow, with the game's flash for new lines kept")
    -- the buttons beside the chat
    local menu = new("Button", "ChatFrameMenuButton")
    local menuArt = tex(menu)
    local friends = new("Button", "QuickJoinToastButton")
    local friendsArt = tex(friends)
    friends.FriendCount = friends:CreateFontString()
    C:SkinButtons()
    check(menuArt.alpha == 0 and menu.voltSkin and menu.voltSkin.fuiPanel and menu.voltSkin.w == 22 and #menu.voltSkin.regions >= 8, "the chat menu button: a flat square with three lines")
    check(friendsArt.alpha == 0 and friends.FriendCount.points[1][2] == friends.voltSkin and friends.FriendCount.color[1] == 1 and friends.FriendCount.color[3] < 0.2, "the friends button: a flat square showing its count, in gold")
    check(frame.voltBack.points[2][4] == 14, "the panel reaches past the scroll bar")
    local channels = new("Button", "ChatFrameChannelButton")
    C:SkinButtons()
    check(friends.points[1][1] == "TOP" and friends.points[1][2] == channels and friends.points[1][3] == "BOTTOM", "the friends button sits under the channels button")
    C.dockQueued = nil
    local oldAfter = C_Timer.After
    local again
    C_Timer.After = function(_, fn) again = fn end
    friends:ClearAllPoints()
    friends:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 5, 400)
    again()
    check(friends.points[1][2] == channels, "and goes back there when the game moves it")
    C_Timer.After = oldAfter
    ChatFrameChannelButton = nil
    local skin = menu.voltSkin
    C:SkinButtons()
    check(menu.voltSkin == skin, "only once")
    menu.scripts.OnEnter(menu)
    check(tint(skin.fuiPanel.edges[1])[1] == 1 and tint(skin.fuiPanel.edges[1])[3] < 0.2, "its border lights up gold under the mouse")
    menu.scripts.OnLeave(menu)
    check(math.abs(tint(skin.fuiPanel.edges[1])[1] - 0.35) < 0.01, "and goes back")
    ChatFrame8, ChatFrameMenuButton, QuickJoinToastButton = nil, nil, nil

    -- moving and resizing the main window
    local main = new("ScrollingMessageFrame", "ChatFrame1")
    main.GetName = function() return "ChatFrame1" end
    main:SetSize(430, 120)
    main:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 32, 95)
    main.StartSizing = function(self, corner) self.sizingFrom = corner end
    main.StopMovingOrSizing = function(self) self.sizingFrom = nil end
    local oldLock = InCombatLockdown
    InCombatLockdown = function() return false end
    VoltUIDB.chatLeft, VoltUIDB.chatTop, VoltUIDB.chatPoint, VoltUIDB.chatW, VoltUIDB.chatH = nil, nil, nil, nil, nil
    C.mover = nil
    C:SetupMover()
    C:PlaceMain()
    check(C.mover and C.mover.name == "Chat" and not C.mover.shown and main.points[1][1] == "BOTTOMLEFT", "the chat has an overlay for Move frames, and stays where the game has it until it's moved")
    FUI:SetUnlocked(true)
    check(C.mover.shown and C.grip and C.grip.parent == C.mover, "moving frames shows it, with a corner to drag for its size")
    -- resize
    C.grip.scripts.OnMouseDown(C.grip)
    check(main.sizingFrom == "BOTTOMRIGHT" and C.sizing, "dragging the corner sizes the window from its bottom-right")
    main.w, main.h = 520, 200
    C.grip.scripts.OnMouseUp(C.grip)
    check(VoltUIDB.chatW == 520 and VoltUIDB.chatH == 200 and VoltUIDB.chatPoint ~= nil and not C.sizing, "letting go keeps the size and the spot")
    -- the game's own layout moving it: back to yours, next frame
    local later = {}
    local oldAfter = C_Timer.After
    C.queued = nil -- the frame after the drag has come and gone
    C_Timer.After = function(_, fn) later[#later + 1] = fn end
    main:SetSize(430, 120)
    main:ClearAllPoints()
    main:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 32, 95)
    check(#later == 1, "the game moving it is noticed, once")
    later[1]()
    check(main.w == 520 and main.h == 200 and main.points[1][1] == "TOPLEFT", "and it's put back at your spot and size")
    -- not while the game's own Edit Mode is open
    EditModeManagerFrame = new("Frame", "EditModeManagerFrame")
    EditModeManagerFrame:Show()
    later = {}
    main:SetSize(300, 150)
    check(#later == 0 and main.w == 300, "while the game's Edit Mode is open the window is the game's to arrange")
    EditModeManagerFrame:Hide()
    C.Again()
    later[1]()
    check(main.w == 520, "and yours again after")
    EditModeManagerFrame = nil
    C_Timer.After = oldAfter
    -- reset
    C:ResetSpot()
    check(VoltUIDB.chatPoint == nil and VoltUIDB.chatW == nil and main.w == 430 and main.h == 120 and main.points[1][1] == "BOTTOMLEFT" and main.points[1][4] == 32,
      "Reset spot: the game's spot and the size it had")
    -- the General page has it
    E:Open("general")
    local reset, note
    for _, r in ipairs(E.rows) do
      if r.def.label == "Spot and size" then reset = r end
      if r.def.key == "chatAlpha" then note = r end
    end
    check(reset and reset.button.text.text == "Reset spot" and note, "General has a Chat section: opacity and Reset spot")
    E:Close()
    FUI:SetUnlocked(false)
    check(not C.mover.shown, "the overlay goes when you finish")
    for i = #ns.Style.movers, 1, -1 do if ns.Style.movers[i] == C.mover then table.remove(ns.Style.movers, i) end end
    C.mover, C.grip, ChatFrame1 = nil, nil, nil
    InCombatLockdown = oldLock
  end)()
  -- 1.55.1: the game's Edit Mode moving the totem frame out of VoltUI's bar
  ;(function()
    local AB = ns.ActionBars
    local f, t = AB.frames.totem, MultiCastActionBarFrame
    if not (f and t) then check(false, "the totem bar is there to test") return end
    local oldLock, oldAfter = InCombatLockdown, C_Timer.After
    local inFight, later = false, nil
    InCombatLockdown = function() return inFight end
    C_Timer.After = function(_, fn) later = fn end
    AB.totemQueued = nil
    check(t.parent == f and t.points[1][2] == f, "the totems sit in VoltUI's bar")
    t:ClearAllPoints()
    t:SetPoint("BOTTOM", UIParent, "BOTTOM", -200, 240)
    check(later ~= nil, "the game moving them is noticed")
    later()
    check(t.points[1][1] == "BOTTOMLEFT" and t.points[1][2] == f and #t.points == 1, "and they're put back in the bar, where its overlay is")
    later = nil
    inFight = true
    AB.applyPending = nil
    t:ClearAllPoints()
    t:SetPoint("BOTTOM", UIParent, "BOTTOM", -200, 240)
    check(later == nil and AB.applyPending == true and t.points[1][2] == UIParent, "in a fight it waits")
    inFight = false
    AB:ApplyAll()
    check(t.points[1][2] == f, "and is put back when the fight ends")
    InCombatLockdown, C_Timer.After = oldLock, oldAfter
  end)()
  Extra("upgrades")
  -- 1.61.0: the settings window, redesigned
  ;(function()
    local P, FUI, U = ns.Pages, ns.FUI, ns.UnitFrames
    local oldLock = InCombatLockdown
    InCombatLockdown = function() return false end
    ns.db.editShape, ns.db.editH = nil, nil
    E:Open("pet")
    -- changed marks, Reset's count, and a right-click to put one row back
    local c = U:Cfg("pet")
    local w0 = U.DEFAULTS.pet.width
    local function prow(key) for _, r in ipairs(E.rows) do if r.def.key == key then return r end end end
    local width = prow("width")
    check(width and not width.changed and E.reset.text.text == "Reset", "nothing changed: no marks, and Reset says just Reset")
    width:Set(w0 + 20)
    check(width.changed and width.chg and width.chg.shown and E.reset.text.text == "Reset · 1 changed", "a changed row gets a mark, and Reset counts it: " .. E.reset.text.text)
    width.scripts.OnMouseUp(width, "RightButton")
    check(c.width == w0 and not width.changed and not width.chg.shown and E.reset.text.text == "Reset", "a right-click puts that one row back to its default")
    check(E.banner.shown and E.banner.text.text:find("back to its default", 1, true), "and says so")
    -- the footer: saved, how many changes, and Undo last
    local n0 = P.logCount
    now = now + 5
    width:Set(w0 + 10)
    width:Set(w0 + 12) -- a slider dragged on is the same change
    check(P.logCount == n0 + 1 and E.hint.text:find("Saved", 1, true) and E.hint.text:find(tostring(P.logCount) .. " change", 1, true) and E.undoBtn.shown,
      "the footer says your changes are saved, how many, and offers Undo last: " .. E.hint.text)
    E.undoBtn.scripts.OnClick(E.undoBtn)
    check(c.width == w0, "Undo last puts the newest change back")
    E:Reset() E:Reset()
    check(P.log[#P.log] == nil or P.log[#P.log].def.key ~= "scale", "Reset isn't logged as a change of yours")
    E.toast = nil
    -- the profile picker at the top
    check(E.profileBtn.shown and E.profileBtn.text.text:find("Profile: Default", 1, true), "the title bar says which profile is in use: " .. E.profileBtn.text.text)
    local menuItems = {}
    MenuUtil = { CreateContextMenu = function(owner, fn)
      local root = { CreateTitle = function(_, t) menuItems[#menuItems + 1] = { t = t } end,
        CreateButton = function(_, t, f) menuItems[#menuItems + 1] = { t = t, fn = f } end }
      fn(owner, root)
    end }
    local Pr = ns.Profiles
    local spare = Pr:New("Spare")
    Pr:Use("Default")
    E.profileBtn.scripts.OnClick(E.profileBtn)
    local pickSpare
    for _, it in ipairs(menuItems) do if it.t == spare then pickSpare = it end end
    check(menuItems[1].t == "Profile for this character" and pickSpare, "its menu lists the profiles")
    pickSpare.fn()
    check(Pr.Wanted(VoltUIDB, Pr.Char()) == spare and E.profileBtn.text.text:find("(reload)", 1, true) and FUI:ReloadPending(), "picking one waits for a reload, and says so")
    Pr:Use("Default")
    Pr:Delete(spare)
    FUI.reloadNeeded = nil
    MenuUtil = nil
    E.toast = nil
    -- Home's status line
    E:Select("home")
    check(E.status.shown and not E.desc.shown, "Home shows a status line in place of its description")
    local texts = {}
    for _, b in ipairs(E.status.items) do texts[b.key] = b.text.text end
    check(texts.profile:find("Default", 1, true) and texts.version:find("VoltUI", 1, true) and texts.reload == "Nothing waiting on a reload", "profile, version, errors and reloads")
    E.status.items[1].scripts.OnClick(E.status.items[1])
    check(E.tab == "profiles" and not E.status.shown and E.desc.shown, "each part links to its page; other pages show their description")
    -- search: where each result lives, and arrow keys
    E:Search("height")
    local first = E.hits and E.hits[1]
    check(first and first.card.title.text:find("  >  ", 1, true), "a result's card says where it lives: " .. (first and first.card.title.text or "?"))
    E.searchBox.scripts.OnArrowPressed(E.searchBox, "DOWN")
    E.searchBox.scripts.OnArrowPressed(E.searchBox, "DOWN")
    check(E.hitIndex == 2 and tint(E.hits[2].card.edges[1])[1] == ns.Style.UI.accent[1] and tint(E.hits[1].card.edges[1])[1] ~= ns.Style.UI.accent[1], "Down picks the next result and edges it in the accent")
    local want = E.hits[2].page
    E.searchBox.scripts.OnEnterPressed(E.searchBox)
    check(E.tab == want and not E.query, "Enter opens the picked result's page")
    E:Select("pet")
    -- resizing: the window's widths, and the rail
    check(E.shape == "2" and E.panel.w == E.ShapeWidth("2") and E.cols == 2, "it starts two columns wide, with the sidebar")
    local grip = E.grip
    local cx, cy = 1000, 500
    local oldCursor = GetCursorPosition
    GetCursorPosition = function() return cx, cy end
    local h0 = E.height
    grip.scripts.OnMouseDown(grip)
    cx = 1000 + (E.ShapeWidth("3") - E.ShapeWidth("2"))
    cy = 500 - 100
    grip.scripts.OnUpdate(grip, 0.01)
    check(E.shape == "3" and E.panel.w == E.ShapeWidth("3") and E.height == math.min(h0 + 100, E:MaxHeight()) and E.height > h0, "dragging the corner out and down: three columns wide, and taller: " .. h0 .. " to " .. E.height)
    grip.scripts.OnMouseUp(grip)
    check(VoltUIDB.editShape == "3" and VoltUIDB.editH == E.height, "and remembers the size")
    -- on the widest window, a frame page's preview takes the third column
    E:Select("pet")
    check(E.docked and E.previewBox.shown and E.pages.pet.cols == 2, "a frame page keeps two columns of cards, and its preview docks beside them")
    E:Select("general")
    check(E.pages.general.cols == 3, "a page with no preview uses all three columns")
    E:Select("home")
    local wideRight = 0
    for _, r in ipairs(E.rows) do if r.tiles then wideRight = r.w end end
    check(wideRight > 900, "Home's cards widen with the window: " .. wideRight)
    E:ApplyShape("2r")
    check(E.sideW == 44 and E.railMode and E.sideFrame.w == 44 and not E.searchBox.shown and E.railSearch.shown and not E.side[1].text.shown,
      "narrower, the sidebar folds to a rail of icons")
    E.side[2].scripts.OnEnter(E.side[2])
    check(E.railOpen and E.sideFrame.w == 204 and E.side[2].text.shown and E.searchBox.shown, "hovering the rail opens the sidebar over the page")
    E.sideFrame.scripts.OnUpdate(E.sideFrame, 0.1)
    check(not E.railOpen and E.sideFrame.w == 44, "and it folds again when the mouse leaves")
    E:ApplyShape("1")
    E:Select("pet")
    check(E.cols == 1 and E.pages.pet.cols == 1 and E.panel.w == E.ShapeWidth("1"), "narrowest: one column")
    E:ApplyShape("2")
    VoltUIDB.editShape, VoltUIDB.editH = nil, nil
    GetCursorPosition = oldCursor
    -- icons and density
    local ic = ns.Style.Icon(UIParent, "bags", 20)
    check(ic.kind == "bags" and #ic.parts >= 4 and ic.parts[1].w == 15, "icons are drawn from rectangles on a 16-unit grid")
    ic:SetColor(1, 0, 0, 1)
    check(ic.parts[1].ctex[1] == 1, "and take a colour")
    check(ns.Style.RowH() == 28 and ns.Style.RowHeight({ kind = "toggle" }) == 28 and ns.Style.CardHead() == 32, "one spacing: rows 28 tall, card titles 32")
    VoltUIDB.uiText = 14
    check(ns.Style.UISize(12) == 14, "the settings text size moves every settings text by the same step")
    VoltUIDB.uiText = 12
    E:Close()
    InCombatLockdown = oldLock
  end)()
  -- 1.62.0: VoltUI's own window colours (1.66.0: the Obsidian look)
  ;(function()
    local T = ns.Style.UI
    check(T and T.accent and T.ok and T.bad and T.warn and T.info and T.cat.Frames and T.cat.Items, "VoltUI's windows have their own colours")
    check(T.Hex(T.ok) == "|cff4ade80" and T.Hex(T.accent) == "|cffffc61a" and T.Hex(T.bg) == "|cff0f0f0f", "and a colour code for text: the accent is WoW's gold since 1.81.0: " .. T.Hex(T.accent))
    local E = ns.EditMode
    E:Open("general")
    check(tint(E.panel.fuiPanel.fill)[1] == T.panel[1] and E.panel.fuiPanel.fill.shape == nil and E.pane.shape == nil and tint(E.pane)[1] == T.bg[1],
      "the settings window is drawn in them: a square window (1.81.0), a darker page")
    -- 1.81.0: the hard-edged look
    local zero = true
    for _, v in pairs(T.r) do if v ~= 0 then zero = false end end
    check(zero, "every corner radius is 0")
    check(E.panel.brandBlock and tint(E.panel.brandBlock)[1] == T.block[1] and T.block[1] < 0.3 and tint(E.panel.brandBlock.kLine)[1] == T.accent[1], "the title strip starts with a dark gold block, a gold line under it (1.87.0)")
    local mk = E.panel.brandMark
    check(mk and tostring(mk.tex):find("Bolt$") and mk.vc[1] == T.primaryText[1] and mk.points[1][2] == E.panel.brandBlock,
      "the block starts with the bolt mark, in the block's text colour (1.105.0)")
    local bt = E.panel.brandText
    check(bt and bt.text == "VoltUI" and bt.points[1][2] == mk and E.panel.brandBlock.w >= 7 + 14 + 3 + ns.Style.TextWidth(bt, 0) + 10,
      "then the whole name after it, and the block is wide enough for both (1.105.0)")
    local anyCard
    for _, c in ipairs(E.pages.general and E.pages.general.cards or {}) do anyCard = anyCard or c end
    check(anyCard and tint(anyCard.headFill)[1] == T.raised[1] and tint(anyCard.mark)[1] == T.accent[1] and tint(anyCard.cap)[1] == T.accent[1]
      and anyCard.hatch.hatch and anyCard.hatch.tex:find("Hatch") and anyCard.no.text == "01" and anyCard.fill.shape == nil,
      "a card's heading is a raised band: a gold marker, its number, a hatched strip and a gold end block")
    check(anyCard and anyCard.title.font[1]:find("SpaceMono%-Bold") and anyCard.title.font[2] == 13, "with its title in Space Mono")
    -- the hover: a flat gold tint, an outline and a solid left edge, all in the highlight layer
    local slide, sw
    for _, r in ipairs(E.rows) do
      if r.slider then slide = slide or r end
      if r.switch then sw = sw or r end
    end
    local function hoverOK(f, layer)
      local hl = f and f.hl
      return hl and hl.layer == (layer or "HIGHLIGHT") and tint(hl)[1] == T.accent[1] and tint(hl)[4] == T.hover
        and f.hlEdges and tint(f.hlEdges[1])[1] == T.accent[1] and f.hlBar and f.hlBar.w == 3 and tint(f.hlBar)[4] == 1
    end
    -- a row with controls lights itself (they'd take the game's own highlight away), one at a time
    local overRow
    local realOver2 = MouseIsOver
    MouseIsOver = function(f) return f == overRow end
    local St2 = ns.Style
    check(hoverOK(slide, "BACKGROUND") and slide.hl.shown == false and slide.hlBar.shown == false, "a row's hover: tint, outline and edge, no gradient, hidden until the mouse is on it")
    overRow = slide
    slide.scripts.OnEnter(slide)
    check(slide.hl.shown and slide.hlBar.shown and slide.hlEdges[1].shown and St2.LitRow() == slide, "the mouse on a row lights it")
    local other
    for _, r in ipairs(E.rows) do if r.slider and r ~= slide then other = other or r end end
    if other then
      overRow = other
      other.slider.scripts.OnEnter(other.slider)
      check(St2.LitRow() == other and other.hl.shown and not slide.hl.shown, "onto another row's slider: that row is lit instead, and stays lit over its own control")
    end
    MouseIsOver = realOver2
    check(sw and hoverOK(sw.switch), "a switch's row too, drawn on the switch that covers it")
    check(E.side[1].hlBar and hoverOK(E.side[1]), "and the sidebar's pages")
    local seg = ns.Style.Card(UIParent, "Choices", 330):Add({ kind = "cycle", label = "Show", key = "show",
      list = { { key = "a", name = "Always" }, { key = "b", name = "In combat" } } }, { get = function() return "a" end, set = function() end })
    check(hoverOK(seg, "BACKGROUND"), "a row of choices has the row's hover")
    seg.segments[1].scripts.OnEnter(seg.segments[1])
    check(seg.hl.shown and ns.Style.LitRow() == seg, "and the mouse on one of its choices lights the row")
    check(seg and seg.segments[1].hl and tint(seg.segments[1].hl)[1] == T.accent[1] and not seg.segments[1].hlEdges and not seg.segments[1].hlBar,
      "a choice in a set gets the tint alone")
    check(tint(E.done.bg)[1] == T.primary[1] and T.primaryText[1] == T.accent[1] and E.done.text.color[1] == T.primaryText[1]
      and E.done.text.font[1]:find("SpaceMono%-Bold"), "Done is gold Space Mono text on a dark gold tint (1.87.0)")
    -- a switch that's off: a grey track and a light knob (1.66.0, Obsidian; a red knob before)
    local off
    for _, r in ipairs(E.rows) do if r.switch and not r.current then off = r break end end
    check(off and tint(off.switch.track)[1] == T.control[1] and tint(off.switch.knob)[1] == T.knobOff[1] and off.switch.knob.tex == nil,
      "a switch that's off: grey, with a square grey knob (white when on)")
    -- the sidebar: headings and icons in their heading's colour
    local frames
    for _, b in ipairs(E.side) do if b.tab == "player" then frames = b end end
    check(frames and frames.cat == T.cat.Frames and frames.icon.color[1] == T.cat.Frames[1], "a page's icon takes its heading's colour")
    local head
    for _, h in ipairs(E.sideHeads) do if h.text == "FRAMES" then head = h end end
    check(head and head.color[1] == T.cat.Frames[1], "and so does the heading")
    -- Reset turns red when it would undo something
    E:Select("pet")
    local w
    for _, r in ipairs(E.rows) do if r.def.key == "width" then w = r end end
    w:Set(w.io.get(w.def) + 4)
    check(E.reset.text.color[1] == T.bad[1], "Reset is red while it would undo a change")
    w:ResetOne()
    E:RefreshPage()
    check(E.reset.text.color[1] == T.text[1], "and plain when there's nothing to undo")
    E:Close()
  end)()
  -- 1.62.2: spacing
  ;(function()
    local S = ns.Style
    local oldW, oldU = Mock.GetStringWidth, Mock.GetUnboundedStringWidth
    Mock.GetUnboundedStringWidth = function(self) return #(self.text or "") * 6 end
    local card = S.Card(UIParent, "Spacing", 330)
    local io = { get = function(def) return def.key == "fmt" and "both" or true end, set = function() end }
    -- a choice: each segment as wide as its name and 10 a side, the set at the row's right
    local seg = card:Add({ kind = "cycle", label = "Numbers show", key = "fmt", segWidth = 120,
      list = { { key = "both", name = "Now / most" }, { key = "cur", name = "Now" }, { key = "missing", name = "Missing" } } }, io)
    local roomy = true
    for _, b in ipairs(seg.segments) do
      if b.w < #b.text.text * 6 + 2 * S.SEG_PAD then roomy = false end
    end
    check(roomy, "every choice has room around its name")
    check(seg.segments[1].w > seg.segments[2].w, "a longer name gets a wider choice")
    check(seg.segTotal >= 120 and seg.segments[3].points[1][4] == -S.INSET, "the set is at least what the page asks, 12 in from the card's edge")
    -- the pieces meet: no gaps and no overlaps
    local x = -S.INSET
    local flush = true
    for i = #seg.segments, 1, -1 do
      local b = seg.segments[i]
      if b.points[1][4] ~= x then flush = false end
      x = x - b.w
    end
    check(flush and -x - S.INSET == seg.segTotal, "side by side, edge to edge")
    -- a note fits its text: one line of text, one line of room
    local oldH = Mock.GetStringHeight
    Mock.GetStringHeight = function() return 14 end
    local note = card:Add({ kind = "note", lines = 3, text = "Switched on. Reload to start it." }, io)
    check(note.h == 14 + 12, "a note's row fits its text, with 6 above and below: " .. note.h)
    local live = card:Add({ kind = "note", lines = 2, text = function() return "Changes" end }, io)
    check(live.h == 2 * 14 + 12, "a note whose text changes keeps the room it asks for")
    Mock.GetStringHeight = oldH
    Mock.GetStringWidth, Mock.GetUnboundedStringWidth = oldW, oldU
    check(card.h == S.CARD_HEAD + 4 + seg.h + note.h + live.h + 4, "the card: its title band, 4 above the rows and 4 under")
    check(card.title.font[2] == 13 and card.title.font[1]:find("SpaceMono%-Bold") and card.mark.points[1][4] == S.INSET and card.no.text == "",
      "card titles are Space Mono 13 after a marker 11 in; a card with no place on a page has no number")
    card:SetNo(3)
    check(card.no.text == "03" and card.title.points[1][2] == card.no, "given its place, the number goes between the marker and the title")
    -- an off part's card: its note is one line, not two
    local E = ns.EditMode
    E:Open("general")
    E:Close()
  end)()
  -- 1.60.0: Alt-click an item or quest for its web page
  ;(function()
    local Li = ns.Links
    check(Li and Li.enabled and VoltUIDB.links ~= false and VoltUIDB.linkSite == "wowhead", "web links are on, on Wowhead")
    check(Li.URL("item", 2589) == "https://www.wowhead.com/forever/item=2589" and Li.URL("quest", 33) == "https://www.wowhead.com/forever/quest=33", "Wowhead's WoW Forever pages")
    check(Li.URL("item", 2589, "foreverdb") == "https://foreverdb.net/item/2589" and Li.URL("quest", 33, "foreverdb") == "https://foreverdb.net/quest/33"
      and Li.URL("npc", 299, "foreverdb") == "https://www.wowhead.com/forever/npc=299", "ForeverDB's item and quest pages; NPCs stay on Wowhead")
    check(Li.URL("item", nil) == nil and Li.URL("mount", 5) == nil, "nothing for something it can't link")
    local kind, id, name = Li.FromLink("|cff1eff00|Hitem:2589::::::::26:::::|h[Linen Cloth]|h|r")
    check(kind == "item" and id == 2589 and name == "Linen Cloth", "an item link from chat")
    kind, id, name = Li.FromLink("|cffffff00|Hquest:33:5|h[Wolves Across the Border]|h|r")
    check(kind == "quest" and id == 33 and name == "Wolves Across the Border", "a quest link")
    check(Li.FromLink("|Hplayer:Someone|h[Someone]|h") == nil, "not a player's name")
    -- the box
    Li:Show("item", 2589, "Linen Cloth")
    local box = VoltUILinkBox
    check(box.shown and box.edit.text == "https://www.wowhead.com/forever/item=2589" and box.title.text == "Item on Wowhead: Linen Cloth"
      and box.edit.focused ~= false, "the box: the address, selected, and what it's for")
    box.edit:SetText("typed over")
    box.edit.scripts.OnTextChanged(box.edit, true)
    check(box.edit.text == "https://www.wowhead.com/forever/item=2589", "typing in it puts the address back")
    box.site.scripts.OnClick(box.site)
    check(VoltUIDB.linkSite == "foreverdb" and box.edit.text == "https://foreverdb.net/item/2589" and box.title.text:find("ForeverDB", 1, true), "its button switches to ForeverDB")
    box.site.scripts.OnClick(box.site)
    check(VoltUIDB.linkSite == "wowhead", "and back")
    box.edit.scripts.OnEscapePressed(box.edit)
    check(not box.shown, "Esc closes it")
    -- Alt-click on whatever shows an item's tooltip
    local keepFoci, keepAlt, keepCtrl, keepShift = GetMouseFoci, IsAltKeyDown, IsControlKeyDown, IsShiftKeyDown
    local alt = true
    IsAltKeyDown = function() return alt end
    IsControlKeyDown, IsShiftKeyDown = function() return false end, function() return false end
    local slot = new("Button", "TestBagSlot")
    local focus = slot
    GetMouseFoci = function() return { focus } end
    Enum = Enum or {}
    Enum.TooltipDataType = Enum.TooltipDataType or { Item = 0, Spell = 1, Unit = 2, Quest = 23 }
    local keepData, keepOwner = GameTooltip.GetTooltipData, GameTooltip.GetOwner
    GameTooltip.GetTooltipData = function() return { type = Enum.TooltipDataType.Item, id = 6948 } end
    GameTooltip.GetOwner = function() return slot end
    GameTooltip:Show()
    local ev
    for _, fr in ipairs(eventFrames.GLOBAL_MOUSE_DOWN or {}) do if fr ~= VoltUIMenu then ev = fr end end
    ev.scripts.OnEvent(ev, "GLOBAL_MOUSE_DOWN", "LeftButton")
    check(box.shown and box.edit.text == "https://www.wowhead.com/forever/item=6948", "Alt-clicking a bag slot opens its item's page")
    box:Hide()
    alt = false
    ev.scripts.OnEvent(ev, "GLOBAL_MOUSE_DOWN", "LeftButton")
    check(not box.shown, "a plain click doesn't")
    alt = true
    slot.action = 5
    slot.GetAttribute = function() return nil end
    ev.scripts.OnEvent(ev, "GLOBAL_MOUSE_DOWN", "LeftButton")
    check(not box.shown, "nor an Alt-click on an action button, where Alt is self-cast")
    slot.action, slot.GetAttribute = nil, nil
    local other = new("Button")
    focus = other
    ev.scripts.OnEvent(ev, "GLOBAL_MOUSE_DOWN", "LeftButton")
    check(not box.shown, "nor a tooltip left over from another frame")
    -- a quest in the game's quest log: the button knows its quest
    other.questID = 33
    ev.scripts.OnEvent(ev, "GLOBAL_MOUSE_DOWN", "LeftButton")
    check(box.shown and box.edit.text == "https://www.wowhead.com/forever/quest=33", "Alt-clicking a quest in the quest log opens its page")
    box:Hide()
    -- a link in chat
    SetItemRef("item:2589::::", "|cffffffff|Hitem:2589::::|h[Linen Cloth]|h|r", "LeftButton")
    check(box.shown and box.edit.text:find("item=2589", 1, true) and box.title.text:find("Linen Cloth", 1, true), "Alt-clicking an item link in chat")
    box:Hide()
    alt = false
    SetItemRef("item:2589::::", "|cffffffff|Hitem:2589::::|h[Linen Cloth]|h|r", "LeftButton")
    check(not box.shown, "a plain click on it is the game's own")
    GameTooltip:Hide()
    GameTooltip.GetTooltipData, GameTooltip.GetOwner = keepData, keepOwner
    GetMouseFoci, IsAltKeyDown, IsControlKeyDown, IsShiftKeyDown = keepFoci, keepAlt, keepCtrl, keepShift
    check(_G.VoltUI.Links == Li, "another add-on can reach it")
  end)()
  -- 1.54.0: currencies beside your money
  ;(function()
    local B = ns.Bags
    local oldCI = C_CurrencyInfo
    C_CurrencyInfo = {
      GetCurrencyInfo = function(id) if id == 3402 then return { name = "Merchant's Favor", quantity = 1250, iconFileID = 4638 } end end,
      GetBackpackCurrencyInfo = function(i)
        if i == 1 then return { name = "Merchant's Favor", quantity = 1250, iconFileID = 4638, currencyTypesID = 3402 } end
        if i == 2 then return { name = "Honor", quantity = 75, iconFileID = 99, currencyTypesID = 1901 } end
      end,
    }
    local text = B.Currencies()
    local _, favors = text:gsub("4638", "")
    check(favors == 1 and text:find("1250", 1, true) and text:find("|T99:", 1, true) and text:find("75", 1, true), "Merchant's Favor and the backpack's currencies, each once: " .. text)
    local f = B:Window("bags").frame
    B:PaintMoney(f)
    check(f.currency.text == text and f.currency.points[1][2] == f.money and f.currency.points[1][3] == "LEFT", "they sit left of your money in the bag's footer")
    C_CurrencyInfo = { GetCurrencyInfo = function() return { name = "", quantity = 0 } end }
    B:PaintMoney(f)
    check(f.currency.text == "", "a client without the currency shows nothing")
    C_CurrencyInfo = oldCI
    B:PaintMoney(f)
  end)()
  -- 1.49.0: profiles, picked per character
  ;(function()
    local Pr = ns.Profiles
    local defaults = { alpha = 0.85, font = "barlow", bagCols = 10 }
    local db = { alpha = 0.5, font = "rajdhani", bagCols = 12, bagLeft = 40, frameCfg = { player = { width = 260 } },
      blockedLog = { [1] = true }, errorLog = { "x" } }
    check(Pr:Load(db, "Kaelra-Forever", defaults) == false and db.activeProfile == "Default" and db.alpha == 0.5, "one profile, Default, until you make another: nothing changes")
    check(table.concat(Pr:List(db), ",") == "Default", "the list has just Default")
    -- a profile of its own for a healer alt
    local name = Pr:New("Thoma", db, "Thoma-Forever")
    check(name == "Thoma" and db.profileOf["Thoma-Forever"] == "Thoma" and db.profiles.Thoma.alpha == 0.5 and db.profiles.Thoma.blockedLog == nil,
      "a new profile starts as a copy of the settings in use, without what VoltUI has learned")
    check(Pr:New("Thoma", db, "Other-Forever") == "Thoma 2", "a name that's taken gets a number")
    Pr:Delete("Thoma 2", db)
    check(db.profiles["Thoma 2"] == nil and db.profileOf["Other-Forever"] == nil, "deleting a profile sends its characters back to Default")
    -- logging in on the alt brings its profile in
    check(Pr:Load(db, "Thoma-Forever", defaults) == true and db.activeProfile == "Thoma" and db.profiles.Default.alpha == 0.5 and db.profiles.Thoma == nil,
      "the alt's login puts Default away and brings its own in")
    db.alpha, db.bagCols, db.frameCfg.player.width = 0.9, 8, 300
    db.blockedLog[2] = true
    -- back on the main: its settings are as they were, and what's been learned is shared
    check(Pr:Load(db, "Kaelra-Forever", defaults) == true and db.activeProfile == "Default", "the main's login swaps back")
    check(db.alpha == 0.5 and db.bagCols == 12 and db.frameCfg.player.width == 260 and db.bagLeft == 40, "with its own settings and spots untouched")
    check(db.blockedLog[2] == true and db.errorLog[1] == "x", "what VoltUI has noted and the error list are shared by every profile")
    check(db.profiles.Thoma.alpha == 0.9 and db.profiles.Thoma.frameCfg.player.width == 300, "the alt's changes were kept in its profile")
    check(db.profiles.Thoma.frameCfg ~= db.frameCfg, "as copies, not the same tables")
    -- a setting a profile lacks comes from the defaults
    db.profiles.Thoma.font = nil
    Pr:Load(db, "Thoma-Forever", defaults)
    check(db.font == "barlow", "a setting a profile doesn't have comes from the defaults")
    Pr:Load(db, "Kaelra-Forever", defaults)
    -- copying, and what can't be deleted
    check(Pr:Delete("Default", db) == false and Pr:Delete(db.activeProfile, db) == false, "Default and the one in use can't be deleted")
    FUI_defaults = nil
    local realDefaults = ns.FUI.defaults
    ns.FUI.defaults = defaults
    check(Pr:CopyFrom("Thoma", db) and db.alpha == 0.9 and db.activeProfile == "Default" and db.profiles.Thoma.alpha == 0.9, "copying another profile's settings onto the ones in use")
    ns.FUI.defaults = realDefaults
    check(table.concat(Pr:UsedBy("Thoma", db), ",") == "Thoma", "who uses a profile")
    -- a character whose profile was deleted falls back to Default
    db.profileOf["Ghost-Forever"] = "Gone"
    check(Pr.Wanted(db, "Ghost-Forever") == "Default", "a character set to a profile that's gone uses Default")
    -- the real thing: untouched by all that, and it has a page
    check(VoltUIDB.activeProfile == "Default" and next(VoltUIDB.profiles) == nil, "this account still has just Default")
    E:Open("profiles")
    local use
    for _, r in ipairs(E.rows) do if r.def.key == "use" then use = r end end
    check(E.tab == "profiles" and use and use.value.text == "Default", "the Profiles page shows which one this character uses")
    E:Close()
    -- a string of text carries the newer settings too
    local world = ns.Share:Collect("world")
    check(world.mapCoords ~= nil and world.stripClock ~= nil and ns.Share:Collect("other").tipAnchor ~= nil and ns.Share:Collect("frames").castLag ~= nil,
      "export strings include the settings added since 1.33")
  end)()
  -- 1.48.0: a drawer for other add-ons' minimap buttons (off until switched on), and roll frames
  ;(function()
    local D, Ro = ns.Drawer, ns.Rolls
    check(D and VoltUIDB.drawer == false and not D.enabled and VoltUIDrawerTab == nil, "the drawer is there but off until it's switched on")
    local function button(name, w, kind)
      local b = new(kind or "Button", name, Minimap)
      b:SetSize(w, w)
      b.GetName = function() return name end
      return b
    end
    local a1, a2 = button("LibDBIcon10_Questie", 31), button("TomTomMinimapButton", 31)
    local ours, big, plain = button("VoltUIMinimapButton2", 22), button("SomeBigPanel", 200), button("PlainFrame", 31, "Frame")
    check(D.IsButton(a1) and D.IsButton(a2), "another add-on's minimap button is recognised")
    check(not D.IsButton(ours) and not D.IsButton(big) and not D.IsButton(plain) and not D.IsButton(GameTimeFrame or {}), "not VoltUI's own, a big frame, or something that isn't a button")
    local oldKids, oldLock = Minimap.GetChildren, InCombatLockdown
    Minimap.GetChildren = function() return a1, ours, a2, big end
    InCombatLockdown = function() return false end
    VoltUIDB.drawerOpen = false
    D:Enable()
    check(VoltUIDrawerTab and VoltUIDrawer and D.count == 2 and VoltUIDrawerTab.text.text:find("2", 1, true), "switched on: a tab under the minimap counts them")
    check(a1.parent == VoltUIDrawer and a2.parent == VoltUIDrawer and ours.parent == Minimap and not VoltUIDrawer.shown, "they leave the map for the drawer, which starts closed")
    VoltUIDrawerTab.scripts.OnClick(VoltUIDrawerTab)
    check(VoltUIDrawer.shown and VoltUIDB.drawerOpen and a2.points[1][4] > a1.points[1][4], "clicking the tab opens it: the buttons side by side")
    check(math.abs(a1.scale - 26 / 31) < 0.001, "shrunk to fit a cell")
    VoltUIDrawerTab.scripts.OnClick(VoltUIDrawerTab)
    check(not VoltUIDrawer.shown, "and closes it")
    InCombatLockdown = function() return true end
    D:Scan()
    check(D.scanPending, "in combat a new look for buttons waits")
    InCombatLockdown = function() return false end
    fire("PLAYER_REGEN_ENABLED")
    check(not D.scanPending, "until the fight ends")
    Minimap.GetChildren, InCombatLockdown = oldKids, oldLock
    VoltUIDrawerTab:Hide(); VoltUIDrawer:Hide()
    D.enabled = nil
    -- roll frames
    check(Ro and Ro.enabled, "roll frames are skinned by a part of their own, on by default")
    local border = { alpha = 1 }
    function border:SetAlpha(a) self.alpha = a end
    local roll = new("Frame", "GroupLootFrame1")
    roll.Border = border
    roll.Timer = new("StatusBar", nil, roll)
    roll.Name = new("FontString")
    Ro:SkinAll()
    check(Ro.skinned[roll] and roll.voltBack and roll.voltBack.fuiPanel and border.alpha == 0, "a roll frame gets a VoltUI panel and loses its border art")
    local back = roll.voltBack
    fire("START_LOOT_ROLL")
    runTimers()
    check(roll.voltBack == back, "only once, however many rolls start")
    GroupLootFrame1 = nil
  end)()
  -- 1.48.0: your buffs and debuffs, as a part that starts switched off.
  -- 1.98.0: it no longer draws its own. In a fight this client refuses every aura read from
  -- an add-on, so the game's own buff and debuff frames are restyled and placed instead.
  ;(function()
    local B, FUI = ns.Buffs, ns.FUI
    check(B and VoltUIDB.buffs == false and not B.enabled and VoltUIBuffs == nil, "the buffs part is there but off until it's switched on")
    check(ns.Pages.PartState(B) == "Off" and ns.Pages.PART_PAGE.buffs == "buffs", "its Home tile says Off and links to its page")
    local old = { BuffFrame = BuffFrame, DebuffFrame = DebuffFrame, colors = DebuffTypeColor, lock = InCombatLockdown }
    DebuffTypeColor = { Magic = { r = 0.2, g = 0.6, b = 1 }, none = { r = 0.8, g = 0, b = 0 } }
    InCombatLockdown = function() return false end
    -- the game's frames, as BuffFrame.lua builds them: buttons with an icon, a time, a count
    -- and two borders, filled in by their own Update
    local function gameButton(parent)
      local btn = new("Button", nil, parent)
      btn.Icon = btn:CreateTexture()
      btn.Duration = btn:CreateFontString()
      btn.Count = btn:CreateFontString()
      btn.DebuffBorder = btn:CreateTexture()
      btn.TempEnchantBorder = btn:CreateTexture()
      btn.Duration.SetFontObject = function(self, o) self.fontObject = o end
      btn.Update = function(self, info)
        self.auraType, self.buttonInfo = info.auraType, info
        self.Icon.tex = info.texture
      end
      btn.shown = false
      return btn
    end
    local function gameFrame(name, n)
      local f = new("Frame", name)
      f.AuraContainer = new("Frame", nil, f)
      f.AuraContainer.iconStride, f.AuraContainer.iconPadding, f.AuraContainer.iconScale = 8, 5, 1
      f.auraFrames = {}
      for i = 1, n do f.auraFrames[i] = gameButton(f.AuraContainer) end
      f.auraInfo = {}
      f.UpdateAuraButtons = function(self)
        for i, btn in ipairs(self.auraFrames) do
          local info = self.auraInfo[i]
          btn.shown = info ~= nil
          if info and btn.Update then btn:Update(info) end
        end
      end
      f.UpdateGridLayout = function() end
      return f
    end
    BuffFrame, DebuffFrame = gameFrame("BuffFrame", 32), gameFrame("DebuffFrame", 16)
    -- a private aura anchor among the debuffs: its Icon is a frame, not a texture
    local anchor = new("Frame", nil, DebuffFrame.AuraContainer)
    anchor.isAuraAnchor, anchor.Icon = true, {}
    table.insert(DebuffFrame.auraFrames, anchor)
    local parent0 = BuffFrame.parent

    B:Enable()
    local h = VoltUIBuffs
    check(B.enabled and h and h.mover and not h.mover.shown, "switched on: a block for them, with a box to drag while moving frames")
    check(BuffFrame.parent == parent0 and BuffFrame.shown ~= false and next(BuffFrame.events or {}) == nil,
      "the game's own buff frame stays: nothing put away, nothing unregistered")
    check(B.Left(7200) == "2h" and B.Left(840) == "14m" and B.Left(7) == "7" and B.Left(3599) == "1h", "times read 2h, 14m, 7")

    -- where they sit
    local function at(f) return f.points[1] end
    check(at(BuffFrame)[1] == "TOPRIGHT" and at(BuffFrame)[2] == h and at(BuffFrame)[3] == "TOPRIGHT" and at(BuffFrame)[5] == 0,
      "the buffs at the top right of VoltUI's block")
    check(BuffFrame.scale == 1 and DebuffFrame.scale == 1, "at VoltUI's sizes: 30 for buffs and for debuffs")
    check(at(DebuffFrame)[4] == -13, "the debuffs set in by the buff frame's arrow, in line with the buffs' icons (1.101.1)")
    do -- the game's own icon size for a frame is taken out: VoltUI's size is the size drawn
      local box, was = DebuffFrame.AuraContainer, nil
      if type(box) ~= "table" then box = {} DebuffFrame.AuraContainer = box was = true end
      local old = box.iconScale
      box.iconScale = 1.5
      VoltUIDB.debuffSize = 36
      B:Arrange()
      check(math.abs(DebuffFrame.scale - 36 / 30 / 1.5) < 0.001, "a bigger Edit Mode icon size doesn't make the debuffs bigger than their setting")
      box.iconScale = old
      VoltUIDB.debuffSize = 30
      if was then DebuffFrame.AuraContainer = nil end
      B:Arrange()
    end
    check(at(DebuffFrame)[2] == h and math.abs(at(DebuffFrame)[5] * DebuffFrame.scale + (45 + 6)) < 0.001,
      "the debuffs under one row of buffs: " .. tostring(at(DebuffFrame)[5]))
    -- the game places its frame again (its Edit Mode): VoltUI puts it back
    BuffFrame:ClearAllPoints()
    BuffFrame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -200, -10)
    check(at(BuffFrame)[2] == h and #BuffFrame.points == 1, "placed by the game again, it goes back to VoltUI's block")

    -- the look of a buff
    BuffFrame.auraInfo = {
      { auraType = "TempEnchant", texture = "e1", count = 0 },
      { auraType = "Buff", texture = "b1", count = 3, auraInstanceID = 1 },
    }
    BuffFrame:UpdateAuraButtons()
    local e1, b1 = BuffFrame.auraFrames[1], BuffFrame.auraFrames[2]
    local s1 = B.skins[b1]
    check(s1 and s1.edges and b1.voltSkin == nil and b1.edges == nil, "a filled button gets VoltUI's border, kept in VoltUI's own table")
    check(b1.Icon.texCoord[1] == 0.08 and b1.Icon.tex == "b1", "the icon cropped square, the game's own picture")
    check(b1.DebuffBorder.alpha == 0 and b1.TempEnchantBorder.alpha == 0, "the game's border art faded, not moved")
    check(b1.Duration.font[2] == 10 and b1.Count.font[2] == 11 and b1.Duration.alpha == 1, "VoltUI's font on the time and the count")
    local function edge(btn) return tint(B.skins[btn].edges[1]) end
    check(math.abs(edge(e1)[1] - 0.62) < 0.01 and math.abs(edge(e1)[3] - 0.95) < 0.01, "a weapon enchant edged in violet")
    check(math.abs(edge(b1)[1] - ns.Style.EDGE[1]) < 0.01, "a buff in the plain edge")
    -- debuffs: the type's colour when it can be read, red when it can't
    DebuffFrame.auraInfo = {
      { auraType = "Debuff", texture = "d1", debuffType = "Magic" },
      { auraType = "Debuff", texture = "d2" },
    }
    DebuffFrame:UpdateAuraButtons()
    local d1, d2 = DebuffFrame.auraFrames[1], DebuffFrame.auraFrames[2]
    check(math.abs(edge(d1)[1] - 0.2) < 0.01 and math.abs(edge(d1)[3] - 1) < 0.01, "a magic debuff in magic's blue")
    check(math.abs(edge(d2)[1] - 0.8) < 0.01 and math.abs(edge(d2)[2] - 0.2) < 0.01, "one with no type in red")
    local oldSecret = issecretvalue
    local hid = {}
    issecretvalue = function(v) return v == hid end
    DebuffFrame.auraInfo[1].debuffType = hid
    DebuffFrame:UpdateAuraButtons()
    check(math.abs(edge(d1)[1] - 0.8) < 0.01, "a type the game keeps secret: red, and no error")
    issecretvalue = oldSecret
    check(B.skins[anchor] == false, "a private aura anchor is left alone")
    -- the game sets the time's font again as it runs down: VoltUI's goes back on
    b1.Duration.font = nil
    b1.Duration:SetFontObject("GameFontNormalSmall")
    check(b1.Duration.font and b1.Duration.font[2] == 10, "the time's font put back after the game changes it")

    -- in a fight nothing here asks about auras, so it keeps up: a second row pushes the debuffs down
    local asked = 0
    local oldUA = C_UnitAuras
    C_UnitAuras = setmetatable({}, { __index = function() asked = asked + 1; return function() error("Auras cannot be accessed when secret while tainted") end end })
    InCombatLockdown = function() return true end
    local y1 = at(DebuffFrame)[5]
    for i = 3, 9 do BuffFrame.auraInfo[i] = { auraType = "Buff", texture = "b" .. i, count = 0 } end
    BuffFrame:UpdateAuraButtons()
    check(asked == 0, "no aura is read by VoltUI")
    check(B.skins[BuffFrame.auraFrames[9]] and BuffFrame.auraFrames[9].Icon.texCoord[1] == 0.08, "a buff that comes in the fight is dressed too")
    check(math.abs(at(DebuffFrame)[5] * DebuffFrame.scale + (90 + 6)) < 0.001 and at(DebuffFrame)[5] < y1, "nine buffs: two rows, the debuffs a row lower")
    for i = 3, 9 do BuffFrame.auraInfo[i] = nil end
    BuffFrame:UpdateAuraButtons()
    check(math.abs(at(DebuffFrame)[5] - y1) < 0.001, "and back up when they go")
    C_UnitAuras = oldUA
    InCombatLockdown = function() return false end

    -- settings
    VoltUIDB.buffSize, VoltUIDB.debuffSize, VoltUIDB.buffScale, VoltUIDB.buffTimers = 45, 30, 2, false
    VoltUIDB.buffTimeSize, VoltUIDB.buffCountSize = 14, 13
    B:Place()
    B:Update()
    check(BuffFrame.scale == 3 and DebuffFrame.scale == 2 and h.scale == 2, "sizes and the scale: 45 at twice is three times the game's 30")
    check(b1.Duration.alpha == 0 and b1.Duration.font[2] == 14 and b1.Count.font[2] == 13, "times off, and the two font sizes")
    check(math.abs(at(DebuffFrame)[5] * DebuffFrame.scale + (45 * 3 + 12)) < 0.001, "the debuffs keep clear of the bigger buffs")
    B:Reset()
    check(VoltUIDB.buffSize == 30 and VoltUIDB.buffTimeSize == 10 and VoltUIDB.buffCountSize == 11 and BuffFrame.scale == 1 and b1.Duration.alpha == 1, "Reset puts it all back")
    check(FUI.defaults.buffTimeSize == 10 and FUI.defaults.buffCountSize == 11, "10 and 11 are the font sizes to begin with")
    -- moving frames
    BuffFrame.auraInfo = {}
    BuffFrame:UpdateAuraButtons()
    FUI:SetUnlocked(true)
    check(h.mover.shown and B.empty.shown, "moving frames: its box shows, and says what goes there when you have none")
    FUI:SetUnlocked(false)
    check(not h.mover.shown and not B.empty.shown, "and back")
    E.pages.buffs = nil -- built earlier, while the part was off
    E:Open("buffs")
    local by = {}
    for _, r in ipairs(E.rows) do if r.def.key then by[r.def.key] = r end end
    check(E.tab == "buffs" and by.buffSize and by.debuffSize and by.buffScale and by.buffTimers and by.buffTimeSize and by.buffCountSize,
      "its own settings page: sizes, scale, times, the two font sizes")
    check(not by.buffPerRow, "how many in a row is the game's to say now")
    by.buffTimeSize:Set(12)
    check(VoltUIDB.buffTimeSize == 12 and b1.Duration.font[2] == 12, "a setting changes the game's buttons straight away")
    by.buffTimeSize:Set(10)
    E:Close()
    E.pages.buffs = nil
    -- put away again: the rest of the tests run without it, as a fresh install does
    B:Reset()
    h:Hide()
    B.enabled, B.holder = nil, nil
    BuffFrame, DebuffFrame, DebuffTypeColor, InCombatLockdown = old.BuffFrame, old.DebuffFrame, old.colors, old.lock
  end)()
  -- 1.47.0: status marks on party and raid tiles
  ;(function()
    local R = ns.Raid
    local f = CreateFrame("Button", nil, UIParent)
    R.BuildTile(f)
    f.kunit = "party1"
    local c = R:TileSet(f)
    local keep = { markers = c.markers, leader = c.leader, ready = c.ready, incoming = c.incoming }
    c.markers, c.leader, c.ready, c.incoming = true, true, true, true
    local old = { GetRaidTargetIndex = GetRaidTargetIndex, SetRaidTargetIconTexture = SetRaidTargetIconTexture, UnitIsGroupLeader = UnitIsGroupLeader,
      GetReadyCheckStatus = GetReadyCheckStatus, UnitHasIncomingResurrection = UnitHasIncomingResurrection, C_IncomingSummon = C_IncomingSummon, After = C_Timer.After }
    local mark, lead, answer, res, summon = nil, false, nil, false, false
    local set
    GetRaidTargetIndex = function() return mark end
    SetRaidTargetIconTexture = function(tex, i) set = i end
    UnitIsGroupLeader = function() return lead end
    GetReadyCheckStatus = function() return answer end
    UnitHasIncomingResurrection = function() return res end
    C_IncomingSummon = { HasIncomingSummon = function() return summon end }
    R:UpdateFlags(f)
    check(not f.kmark.shown and not f.klead.shown and not f.kready.shown and not f.kflag.shown, "a tile with nothing to say shows no marks")
    mark, lead = 8, true
    R:UpdateFlags(f)
    check(f.kmark.shown and set == 8 and f.klead.shown, "a raid marker and the leader's mark")
    answer = "ready"
    R:UpdateFlags(f)
    check(not f.kready.shown, "no ready-check answer outside a ready check")
    local later
    C_Timer.After = function(_, fn) later = fn end
    R:OnEvent("READY_CHECK")
    R:UpdateFlags(f)
    check(f.kready.shown and f.kready.tex:find("ReadyCheck%-Ready$"), "during a ready check, its answer: a tick")
    answer = "notready"
    R:OnEvent("READY_CHECK_CONFIRM", "party1")
    R:UpdateFlags(f)
    check(f.kready.tex:find("NotReady$"), "or a cross")
    R:OnEvent("READY_CHECK_FINISHED")
    R:UpdateFlags(f)
    check(f.kready.shown and later, "the answers stay a few seconds after the check ends")
    later()
    R:UpdateFlags(f)
    check(not f.kready.shown and not R.readyCheck, "then go")
    res = true
    R:UpdateFlags(f)
    check(f.kflag.shown and f.kflag.text == "Res coming", "a resurrection on its way")
    res, summon = false, true
    R:UpdateFlags(f)
    check(f.kflag.text == "Summon", "or a summon waiting")
    c.markers, c.leader, c.incoming = false, false, false
    R:UpdateFlags(f)
    check(not f.kmark.shown and not f.klead.shown and not f.kflag.shown, "each can be switched off")
    for k, v in pairs(keep) do c[k] = v end
    GetRaidTargetIndex, SetRaidTargetIconTexture, UnitIsGroupLeader, GetReadyCheckStatus = old.GetRaidTargetIndex, old.SetRaidTargetIconTexture, old.UnitIsGroupLeader, old.GetReadyCheckStatus
    UnitHasIncomingResurrection, C_IncomingSummon, C_Timer.After = old.UnitHasIncomingResurrection, old.C_IncomingSummon, old.After
    f:Hide()
  end)()
  -- 1.47.0: a focus frame
  ;(function()
    local U, C, FUI = ns.UnitFrames, ns.Castbar, ns.FUI
    local F = VoltUIFocusFrame
    check(F and U.frames.focus == F and U.byUnit.focus == F and F.unit == "focus" and F.attrs and F.attrs.unit == "focus", "a focus frame, for the focus unit")
    check(F.w == 160 and U:Cfg("focus").hpHeight == 14 and U:Cfg("focus").elite == "border", "smaller than the player and target frames")
    check(F.points[1][2] == VoltUIPlayerFrame and F.points[1][1] == "BOTTOMRIGHT", "it starts up and to the left of the player frame")
    check(VoltUIFocusCastbar and C.focus == VoltUIFocusCastbar and VoltUIFocusCastbar.parent == F and VoltUIFocusCastbar.h == VoltUIDB.targetCastH, "with its own cast bar above it")
    local n = 0
    local real = U.Update
    U.Update = function(self, f, light) if f == F then n = n + 1 end return real(self, f, light) end
    fire("PLAYER_FOCUS_CHANGED")
    check(n >= 1, "changing your focus redraws it: " .. n)
    U.Update = real
    -- its cast bar reads the focus's cast, and can be switched off
    castInfo.focus = { name = "Heal", display = "Heal", icon = "i", st = GetTime() * 1000, en = (GetTime() + 2) * 1000, guid = "f1", spellID = 2054 }
    fire("PLAYER_FOCUS_CHANGED")
    check(VoltUIFocusCastbar.shown and VoltUIFocusCastbar.label.text == "Heal" and not VoltUIFocusCastbar.lag.shown, "a focus that's casting shows on its bar, without your latency")
    VoltUIDB.focusCast = false
    C:SetFocusBar(false)
    check(not VoltUIFocusCastbar.shown, "the bar can be switched off")
    VoltUIDB.focusCast = true
    C:SetFocusBar(true)
    check(VoltUIFocusCastbar.shown, "and back on")
    castInfo.focus = nil
    fire("PLAYER_FOCUS_CHANGED")
    check(not VoltUIFocusCastbar.shown, "no cast, no bar")
    -- it has a tab, a preview and joins Move frames
    E:Open("focus")
    check(E.tab == "focus" and E.title.text == "Unit frames" and E.previews.focus and E.previews.focus.shown, "its own tab on Unit frames, with a preview")
    local hasCast
    for _, r in ipairs(E.rows) do if r.def.key == "focusCast" then hasCast = true end end
    check(hasCast, "and a switch for its cast bar")
    E:Close()
    FUI:SetUnlocked(true)
    check(F.mover.shown and F.shown and F.unit == "player", "moving frames: it shows, with you standing in, to be placed")
    FUI:SetUnlocked(false)
    check(F.unit == "focus" and not F.mover.shown, "and goes back to your focus")
    U:ResetFrame("focus")
  end)()
  -- 1.46.0: health and power text formats, a warning on clashing clicks, cast bar extras
  ;(function()
    local U, R, C = ns.UnitFrames, ns.Raid, ns.Castbar
    local P = VoltUIPlayerFrame
    local c = U:Cfg("player")
    local keep = { hpFormat = c.hpFormat, pwFormat = c.pwFormat, short = c.short, hpText = c.hpText, power = c.power, pwText = c.pwText }
    local old = { UnitHealth = UnitHealth, UnitHealthMax = UnitHealthMax, UnitPower = UnitPower, UnitPowerMax = UnitPowerMax,
      UnitHealthMissing = UnitHealthMissing, Abbrev = AbbreviateNumbers, Break = BreakUpLargeNumbers,
      dead = UnitIsDead, ghost = UnitIsGhost, conn = UnitIsConnected }
    UnitHealth, UnitHealthMax = function() return 2480 end, function() return 4000 end
    UnitPower, UnitPowerMax = function() return 3200 end, function() return 4000 end
    UnitIsDead, UnitIsGhost, UnitIsConnected = function() return false end, function() return false end, function() return true end
    UnitHealthMissing = nil
    BreakUpLargeNumbers = function(v) return tostring(v) end
    AbbreviateNumbers = function(v) return ("%.1fK"):format(v / 1000) end
    c.hpText, c.power, c.pwText, c.short = true, true, true, false
    local function hp(format) c.hpFormat = format; U:Update(P); return P.hpText.text end
    local function pw(format) c.pwFormat = format; U:Update(P); return P.pwText.text end
    check(hp("both") == "2480 / 4000", "health numbers: now / most, as before: " .. tostring(P.hpText.text))
    check(hp("cur") == "2480", "just now")
    check(hp("missing") == "-1520", "what's missing: " .. tostring(P.hpText.text))
    UnitHealth = function() return 4000 end
    check(hp("missing") == "", "nothing missing at full health")
    UnitHealth = function() return 2480 end
    check(pw("both") == "3200 / 4000" and pw("cur") == "3200" and pw("pct") == "80%", "power numbers: now / most, now, or percent")
    c.short = true
    check(hp("both") == "2.5K / 4.0K" and pw("cur") == "3.2K", "big numbers shortened: " .. tostring(P.hpText.text))
    c.short = false
    -- numbers the game keeps secret: the game's own count of what's missing is used
    local secret = {}
    local oldSecret = issecretvalue
    issecretvalue = function(v) return v == secret end
    UnitHealth = function() return secret end
    UnitHealthMissing = function() return 777 end
    local oldPct = UnitHealthPercent
    UnitHealthPercent = nil -- the percent beside it isn't what's being tested
    check(hp("missing") == "-777", "missing health with secret numbers comes from the game")
    UnitHealthPercent = oldPct
    issecretvalue = oldSecret
    for k, v in pairs(keep) do c[k] = v end
    UnitHealth, UnitHealthMax, UnitPower, UnitPowerMax, UnitHealthMissing = old.UnitHealth, old.UnitHealthMax, old.UnitPower, old.UnitPowerMax, old.UnitHealthMissing
    AbbreviateNumbers, BreakUpLargeNumbers, UnitIsDead, UnitIsGhost, UnitIsConnected = old.Abbrev, old.Break, old.dead, old.ghost, old.conn
    U:Update(P)

    -- a click the game's own click casting also uses
    local oldCB = C_ClickBindings
    C_ClickBindings = {
      GetProfileInfo = function() return { { type = 1, actionID = 2061, button = "LeftButton", modifiers = 1 }, { type = 1, actionID = 17, button = "Button4", modifiers = 0 } } end,
      GetStringFromModifiers = function(m) return m == 1 and "SHIFT" or "" end,
    }
    local oldSpell = C_Spell
    C_Spell = { GetSpellName = function(id) return id == 2061 and "Flash Heal" or nil end }
    check(R:GameClickFor("shift-1") == "Flash Heal", "the game's click casting on Shift+Left is found, by its spell's name")
    check(R:GameClickFor("1") == nil and R:GameClickFor("ctrl-shift-1") == nil, "plain Left and Ctrl+Shift+Left are free")
    check(R:GameClickFor("4") == "a click binding", "one without a name still counts")
    local slot = ns.Pages.ClickSlot(UIParent, 120, 22, "shift-1")
    local was = R:GetBinding("shift-1")
    R:SetBinding("shift-1", { kind = "target" })
    slot:Paint()
    check(slot.clash == "Flash Heal" and tint(slot.edges[1])[1] == ns.Style.UI.warn[1] and tint(slot.edges[1])[2] == ns.Style.UI.warn[2], "its slot gets an amber edge")
    R:SetBinding("shift-1", nil)
    slot:Paint()
    check(slot.clash == nil, "an empty slot isn't marked: there's nothing of VoltUI's to lose")
    R:SetBinding("shift-1", was)
    C_ClickBindings, C_Spell = oldCB, oldSpell

    -- cast bar: latency zone, and the mark on casts that can't be interrupted
    local Bar = VoltUICastbar
    local oldNet = GetNetStats
    GetNetStats = function() return 0, 0, 40, 200 end
    Bar.bar.w = 200
    local keepDb = { castLag = VoltUIDB.castLag, castLock = VoltUIDB.castLock }
    VoltUIDB.castLag, VoltUIDB.castLock = true, true
    local function cast(locked, seconds)
      castInfo.player = { name = "Fireball", display = "Fireball", icon = "i", st = GetTime() * 1000, en = (GetTime() + seconds) * 1000, guid = "g1", locked = locked, spellID = 133 }
      fire("UNIT_SPELLCAST_START", "player", "g1")
    end
    local function stop()
      castInfo.player = nil
      fire("UNIT_SPELLCAST_STOP", "player", "g1")
      Bar.scripts.OnUpdate(Bar, 2)
    end
    cast(false, 2)
    check(Bar.lag.shown and math.abs(Bar.lag.w - 20) < 0.01, "a 2 second cast at 200 ms: the last tenth of the bar is marked: " .. tostring(Bar.lag.w))
    check(Bar.lock.alpha == 0, "no line on a cast that can be interrupted")
    stop()
    check(not Bar.lag.shown, "the zone goes with the cast")
    VoltUIDB.castLag = false
    cast(false, 2)
    check(not Bar.lag.shown, "and it can be switched off")
    stop()
    local T = ns.Castbar.target
    if T then check(T.lag and not T.lag.shown, "the target's bar never shows your latency") end
    GetNetStats = oldNet
    VoltUIDB.castLag, VoltUIDB.castLock = keepDb.castLag, keepDb.castLock

    -- breath and fatigue timers
    local art, text = { alpha = 1 }, new("FontString")
    function art:SetAlpha(a) self.alpha = a end
    local mirror = new("Frame", "MirrorTimer1")
    mirror.StatusBar = new("StatusBar", nil, mirror)
    mirror.Border, mirror.Text = art, text
    C:SkinMirrors()
    check(mirror.voltSkinned and C.mirrorError == nil and art.alpha == 0 and mirror.voltBack and mirror.voltBack.fuiPanel,
      "the breath timer gets a flat bar on a VoltUI panel, its own art faded")
    local back = mirror.voltBack
    C:SkinMirrors()
    check(mirror.voltBack == back, "only once")
    MirrorTimer1 = nil
  end)()
  -- 1.45.0: a line of readouts under the minimap
  ;(function()
    local MM, Hold, info = ns.Minimap, VoltUIMinimapHolder, VoltUIMinimapInfo
    local KEYS = { "stripClock", "stripMs", "stripFps", "stripDura", "stripGold", "stripMail" }
    local old = { GameTime_GetTime = GameTime_GetTime, GetNetStats = GetNetStats, GetFramerate = GetFramerate,
      GetInventoryItemDurability = GetInventoryItemDurability, GetMoney = GetMoney, HasNewMail = HasNewMail, lock = InCombatLockdown, cal = ToggleCalendar }
    InCombatLockdown = function() return false end
    GameTime_GetTime = function() return "21:47" end
    GetNetStats = function() return 0, 0, 30, 42 end
    GetFramerate = function() return 59.6 end
    local wear = { [1] = { 71, 100 }, [5] = { 90, 100 }, [16] = { 100, 100 } }
    GetInventoryItemDurability = function(slot) local w = wear[slot]; if w then return w[1], w[2] end end
    GetMoney = function() return 381234 end
    local mail = false
    HasNewMail = function() return mail end
    for _, k in ipairs(KEYS) do VoltUIDB[k] = false end
    MM:ApplyInfo()
    local h0 = Hold.h
    check(info and info.parent == Minimap and not info.shown, "with every readout off there's no line")
    for _, k in ipairs(KEYS) do VoltUIDB[k] = true end
    MM:ApplyInfo()
    check(info.shown and Hold.h == h0 + 17, "with any on, a line under the rows, and the holder grows to hold it")
    local mid = VoltUIMinimapMid
    local function plain() return (info.text.text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
    local t = plain()
    check(t:find("42ms", 1, true) and t:find("60fps", 1, true) and t:find("71%", 1, true) and t:find("38g", 1, true),
      "world latency, frame rate, most worn gear and gold: " .. t)
    check(mid.clock.text == "21:47" and not t:find("21:47", 1, true), "the clock beside the coordinates, not on the line (1.83.0)")
    check(mid.clockBtn.shown, "with a button over it")
    VoltUIDB.stripClock = false
    MM:UpdateInfo()
    check(mid.clock.text == "" and not mid.clockBtn.shown, "no clock: none shown")
    for _, k in ipairs(KEYS) do VoltUIDB[k] = k == "stripClock" end
    MM:ApplyInfo()
    check(not info.shown and Hold.h == h0 and mid.clock.text == "21:47", "the clock alone needs no line")
    for _, k in ipairs(KEYS) do VoltUIDB[k] = true end
    MM:ApplyInfo()
    check(not t:find("Mail", 1, true), "no mail, no Mail")
    mail = true
    MM:UpdateInfo()
    check(info.text.text:find("Mail", 1, true), "Mail while there's some waiting")
    wear[1] = { 15, 100 }
    MM:UpdateInfo()
    check(info.text.text:find("f8717115|r", 1, true), "badly worn gear in red")
    GetNetStats = function() return 0, 0, 30, 450 end
    MM:UpdateInfo()
    check(info.text.text:find("f87171450|r", 1, true), "and a bad connection too")
    VoltUIDB.stripFps, VoltUIDB.stripGold = false, false
    MM:UpdateInfo()
    check(not plain():find("fps", 1, true) and not plain():find("38g", 1, true) and mid.clock.text == "21:47", "each readout has its own switch")
    wear = {}
    MM:UpdateInfo()
    check(not info.text.text:find("%%"), "nothing that wears: no durability")
    -- once a second, not every frame
    GameTime_GetTime = function() return "21:47" end
    mid.scripts.OnUpdate(mid, 2) -- starts its second afresh
    GameTime_GetTime = function() return "21:48" end
    mid.scripts.OnUpdate(mid, 0.3)
    check(mid.clock.text == "21:47", "not redrawn every frame")
    mid.scripts.OnUpdate(mid, 0.8)
    check(mid.clock.text == "21:48", "but once a second")
    -- click: calendar
    local opened = 0
    ToggleCalendar = function() opened = opened + 1 end
    info.scripts.OnClick(info)
    check(opened == 1, "clicking the line opens the calendar")
    mid.clockBtn.scripts.OnClick(mid.clockBtn)
    check(opened == 2, "and so does clicking the clock")
    -- in combat the holder's size waits
    for _, k in ipairs(KEYS) do VoltUIDB[k] = false end
    InCombatLockdown = function() return true end
    MM:ApplyInfo()
    check(info.shown and MM.infoPending and Hold.h == h0 + 17, "in combat a change waits")
    InCombatLockdown = function() return false end
    fire("PLAYER_REGEN_ENABLED")
    check(not info.shown and Hold.h == h0 and not MM.infoPending, "and happens when the fight ends")
    GameTime_GetTime, GetNetStats, GetFramerate, GetInventoryItemDurability = old.GameTime_GetTime, old.GetNetStats, old.GetFramerate, old.GetInventoryItemDurability
    GetMoney, HasNewMail, InCombatLockdown, ToggleCalendar = old.GetMoney, old.HasNewMail, old.lock, old.cal
  end)()
  Extra("recent alerts") -- another add-on's tests, since VoltUI 1.104.0
  -- 1.43.0: where tooltips show, their text size, and extras on unit tooltips
  ;(function()
    local T, FUI = ns.Tooltips, ns.FUI
    local keep = { tipAnchor = VoltUIDB.tipAnchor, tipSize = VoltUIDB.tipSize, tipClass = VoltUIDB.tipClass, tipTarget = VoltUIDB.tipTarget, tipCombat = VoltUIDB.tipCombat }
    -- text size
    VoltUIDB.tipSize = 16
    T:Refresh()
    check(GameTooltipText.font[2] == 16 and GameTooltipHeaderText.font[2] == 18 and GameTooltipTextSmall.font[2] == 15, "tooltip text follows its size setting")
    VoltUIDB.tipSize = 13
    T:Refresh()
    check(GameTooltipText.font[2] == 13 and GameTooltipHeaderText.font[2] == 15, "and back to 13, 15 for headings")
    -- where it shows
    local tip = setmetatable({ points = {} }, { __index = GameTooltip })
    local owner = {}
    tip.SetOwner = function(self, p, a) owner = { p, a } end
    tip.SetPoint = function(self, ...) self.points[#self.points + 1] = { ... } end
    tip.ClearAllPoints = function(self) self.points = {} end
    VoltUIDB.tipAnchor = "game"
    T:Anchor(tip, UIParent)
    check(owner[1] == nil, "Game's: the tooltip is left where the game puts it")
    VoltUIDB.tipAnchor = "cursor"
    T:Anchor(tip, UIParent)
    check(owner[2] == "ANCHOR_CURSOR", "Cursor: at the mouse")
    VoltUIDB.tipAnchor = "spot"
    VoltUIDB.tipLeft, VoltUIDB.tipTop, VoltUIDB.tipPoint = nil, nil, nil
    T:Anchor(tip, UIParent)
    check(owner[2] == "ANCHOR_NONE" and tip.points[1][1] == "BOTTOMRIGHT" and tip.points[1][2] == VoltUITooltipSpot and tip.points[1][3] == "BOTTOMRIGHT",
      "Its spot: the tooltip's bottom-right corner on the spot's")
    check(VoltUITooltipSpot.points[1][1] == "BOTTOMRIGHT" and not VoltUITooltipSpot.shown, "the spot starts near the bottom-right, where the game's does, and isn't drawn")
    -- the spot is placed while moving frames
    FUI:SetUnlocked(true)
    local box = VoltUIAnchor_tooltip
    check(box and box.shown and box.mover.shown, "moving frames: a box for the tooltip's spot")
    local sf = VoltUIDB.snapFrames
    VoltUIDB.snapFrames = false
    box.dropLeft, box.dropTop = 900, 400
    box.mover.scripts.OnDragStart(box.mover)
    box.mover.scripts.OnDragStop(box.mover)
    VoltUIDB.snapFrames = sf
    check(VoltUIDB.tipPoint and sitsAt(VoltUITooltipSpot, 900, 400), "dropping it moves the spot")
    FUI:SetUnlocked(false)
    VoltUIDB.tipAnchor = "game"
    FUI:SetUnlocked(true)
    check(not box.shown, "no box unless tooltips use a spot of their own")
    FUI:SetUnlocked(false)
    VoltUIDB.tipLeft, VoltUIDB.tipTop, VoltUIDB.tipPoint = nil, nil, nil
    -- unit extras
    local old = { UnitIsPlayer = UnitIsPlayer, UnitClass = UnitClass, UnitExists = UnitExists, UnitIsUnit = UnitIsUnit, UnitName = UnitName,
      lock = InCombatLockdown, line = GameTooltipTextLeft1, colors = RAID_CLASS_COLORS }
    RAID_CLASS_COLORS = { PALADIN = { r = 0.96, g = 0.55, b = 0.73 } }
    local colour, doubles, hidden
    GameTooltipTextLeft1 = { SetTextColor = function(_, r, g, b) colour = { r, g, b } end }
    local ut = { fuiStyled = true, GetName = function() return "GameTooltip" end, AddDoubleLine = function(_, a, b) doubles[#doubles + 1] = { a, b } end,
      Show = function() end, Hide = function() hidden = true end, GetOwner = function() return UIParent end }
    local function show(unit)
      colour, doubles, hidden = nil, {}, false
      ut.fuiUnitStamp = nil
      T:UnitExtras(ut, unit)
    end
    UnitIsPlayer = function(u) return u == "mouseover" end
    UnitClass = function() return "Paladin", "PALADIN" end
    UnitExists = function(u) return u == "mouseover" or u == "mouseovertarget" end
    UnitIsUnit = function(a, b) return false end
    UnitName = function(u) return u == "mouseovertarget" and "Defias Pillager" or "Thoma" end
    InCombatLockdown = function() return false end
    VoltUIDB.tipClass, VoltUIDB.tipTarget, VoltUIDB.tipCombat = true, true, false
    show("mouseover")
    check(colour and colour[1] == 0.96 and colour[2] == 0.55, "a player's name in their class colour")
    check(#doubles == 1 and doubles[1][1] == "Targeting" and doubles[1][2] == "Defias Pillager", "and who they're targeting")
    T:UnitExtras(ut, "mouseover")
    check(#doubles == 1, "added once for a tooltip, not each time it's filled in")
    UnitIsUnit = function(a, b) return a == "mouseovertarget" and b == "player" end
    show("mouseover")
    check(doubles[1][2] == "You", "Targeting: You when it's you")
    UnitExists = function(u) return u == "mouseover" end
    show("mouseover")
    check(#doubles == 0, "no line when they have no target")
    VoltUIDB.tipClass, VoltUIDB.tipTarget = false, false
    UnitExists = function() return true end
    show("mouseover")
    check(colour == nil and #doubles == 0, "both can be switched off")
    -- a secret name is handed on, never read
    VoltUIDB.tipTarget = true
    local secret = {}
    local oldSecret = issecretvalue
    issecretvalue = function(v) return v == secret end
    UnitIsUnit = function() return secret end
    UnitName = function() return secret end
    show("mouseover")
    check(#doubles == 1 and doubles[1][2] == secret, "a name the game keeps secret is passed straight to the tooltip")
    issecretvalue = oldSecret
    -- hidden in combat
    VoltUIDB.tipCombat = true
    InCombatLockdown = function() return true end
    show("mouseover")
    check(hidden, "in combat, with that on, a unit's tooltip in the world is hidden")
    ut.GetOwner = function() return VoltUIPlayerFrame end
    show("mouseover")
    check(not hidden, "but not one a frame put up")
    InCombatLockdown = function() return false end
    ut.GetOwner = function() return UIParent end
    show("mouseover")
    check(not hidden, "and not out of combat")
    UnitIsPlayer, UnitClass, UnitExists, UnitIsUnit, UnitName = old.UnitIsPlayer, old.UnitClass, old.UnitExists, old.UnitIsUnit, old.UnitName
    InCombatLockdown, GameTooltipTextLeft1, RAID_CLASS_COLORS = old.lock, old.line, old.colors
    for k, v in pairs(keep) do VoltUIDB[k] = v end
  end)()
  Extra("legend") -- another add-on's tests, since VoltUI 1.104.0
  -- 1.104.0: your and the cursor's coordinates on the world map, the map's own (they sat with the pin buttons before)
  ;(function()
    local W = ns.WorldMap
    if not W.enabled then return end
    W:SetupCoords()
    local c = VoltUIMapCoords
    check(c and c == W.coords and c.parent == WorldMapFrame.ScrollContainer and c.points[1][1] == "BOTTOMLEFT", "the map has its coordinates, at the bottom-left")
    local oldPos, oldCursor, oldOver = C_Map.GetPlayerMapPosition, WorldMapFrame.ScrollContainer.GetNormalizedCursorPosition, WorldMapFrame.ScrollContainer.IsMouseOver
    C_Map.GetPlayerMapPosition = function() return { x = 0.461, y = 0.494 } end
    WorldMapFrame.ScrollContainer.GetNormalizedCursorPosition = function() return 0.61, 0.228 end
    WorldMapFrame.ScrollContainer.IsMouseOver = function() return true end
    W:UpdateCoords()
    check(c.text.text:find("46.1, 49.4", 1, true) and c.text.text:find("61.0, 22.8", 1, true) and c.plate.shown, "where you are and where the cursor is: " .. tostring(c.text.text))
    WorldMapFrame.ScrollContainer.IsMouseOver = function() return false end
    W:UpdateCoords()
    check(c.text.text == "46.1, 49.4", "just you when the mouse is off the map")
    C_Map.GetPlayerMapPosition = function() return nil end
    W:UpdateCoords()
    check(c.text.text == "" and not c.plate.shown, "nothing on a map you aren't on")
    c.wait = 0
    C_Map.GetPlayerMapPosition = function() return { x = 0.5, y = 0.5 } end
    c.scripts.OnUpdate(c, 0.05)
    check(c.text.text == "", "not worked out every frame")
    c.scripts.OnUpdate(c, 0.06)
    check(c.text.text == "50.0, 50.0", "but ten times a second")
    VoltUIDB.mapCoords = false
    W:PaintCoords()
    check(not c.shown, "and they can be switched off")
    VoltUIDB.mapCoords = true
    W:PaintCoords()
    check(c.shown, "and on again")
    C_Map.GetPlayerMapPosition, WorldMapFrame.ScrollContainer.GetNormalizedCursorPosition, WorldMapFrame.ScrollContainer.IsMouseOver = oldPos, oldCursor, oldOver
  end)()
  -- 1.40.0: every window joins Move frames; undo, reset, a list of frames; snapping to frames
  ;(function()
    local FUI, M, S = ns.FUI, ns.Move, ns.Style
    local keep = { snap = VoltUIDB.snap, snapFrames = VoltUIDB.snapFrames }
    VoltUIDB.snap, VoltUIDB.snapFrames = false, false
    for _, k in ipairs({ "bag", "bank", "loot", "rare", "treasure", "rareList", "treasureList" }) do
      VoltUIDB[k .. "Left"], VoltUIDB[k .. "Top"], VoltUIDB[k .. "Point"] = nil, nil, nil
    end
    check(VoltUIAnchor_bags == nil or not VoltUIAnchor_bags.shown, "no stand-ins until frames are being moved")
    -- windows another add-on adds (Move.AddAnchor): its own when one is loaded, four made here
    -- when none is
    if not ns.Rares then
      local function spot(key) return function() return VoltUIDB, key .. "Left", key .. "Top", key .. "Point" end end
      local function add(key, sk, w, h, p, x, y)
        M.AddAnchor({ key = key, label = key, on = function() return true end, spot = spot(sk), size = function() return w, h end,
          default = function(f) f:SetPoint(p, UIParent, p, x, y) end })
      end
      add("rareAlert", "rare", 320, 96, "TOP", 0, -140)
      add("treasureAlert", "treasure", 320, 96, "TOP", 0, -270)
      add("rareList", "rareList", 400, 240, "CENTER", -205, 80)
      add("treasureList", "treasureList", 400, 240, "CENTER", 205, 80)
      local n = #M.ANCHOR_DEFS
      add("rareList", "rareList", 400, 240, "CENTER", -205, 80)
      check(#M.ANCHOR_DEFS == n, "Move.AddAnchor adds a window once")
    end
    FUI:SetUnlocked(true)
    local bags, loot, ra, ta, rl, tl = VoltUIAnchor_bags, VoltUIAnchor_loot, VoltUIAnchor_rareAlert, VoltUIAnchor_treasureAlert, VoltUIAnchor_rareList, VoltUIAnchor_treasureList
    check(bags and loot and ra and ta and rl and tl and bags.shown and bags.mover.shown and loot.mover.shown and tl.mover.shown,
      "moving frames: bags, loot, both alerts and both lists each get a box to drag")
    check((VoltUIAnchor_bank ~= nil) == (VoltUIDB.bank and true or false), "the bank too, when VoltUI's bank is on")
    check(bags.w == VoltUIDB.bagCols * VoltUIDB.bagSize + (VoltUIDB.bagCols - 1) * VoltUIDB.gapX + 16 and bags.h == ns.Bags.windows.bags.lastH,
      "the bags' box is the size the bags were last time: " .. tostring(bags.w) .. " x " .. tostring(bags.h))
    check(bags.points[1][1] == "BOTTOMRIGHT" and loot.points[1][1] == "TOPLEFT" and loot.w == 230 and ra.w == 320, "each where its window opens by default")
    check(ra.points[1][5] == -140 and ta.points[1][5] == -270, "the treasure alert's default spot is under the rare alert's now, clear of the line below it")
    -- dropping the bags' box moves the bags
    local bf = ns.Bags.windows.bags.frame
    bags.dropLeft, bags.dropTop = 700, 500
    bags.mover.scripts.OnDragStart(bags.mover)
    bags.mover.scripts.OnDragStop(bags.mover)
    check(VoltUIDB.bagPoint and sitsAt(bags, 700, 500) and sitsAt(bf, 700, 500), "dropping the box saves the spot and the bag window goes there")
    check(M.picked == bags.mover and M.undo and M.undo.m == bags.mover and M.undoBtn.alpha == 1 and M.resetBtn.alpha == 1, "the toolbar picks it, and Undo and Reset spot light up")
    -- undo: it had no spot, so it goes back to its default one
    M.undoBtn.scripts.OnClick(M.undoBtn)
    check(VoltUIDB.bagPoint == nil and bags.points[1][1] == "BOTTOMRIGHT" and bf.points[1][1] == "BOTTOMRIGHT" and M.undo == nil and M.undoBtn.alpha == 0.4,
      "Undo puts it back where it opens by default")
    -- nudges are one move for Undo
    bags.dropLeft, bags.dropTop = 640, 480
    bags.mover.scripts.OnDragStart(bags.mover)
    bags.mover.scripts.OnDragStop(bags.mover)
    M.undo = nil
    M:Nudge(1, 0); M:Nudge(1, 0); M:Nudge(1, 0)
    check(sitsAt(bags, 643, 480) and sitsAt(bf, 643, 480), "arrow keys move the box and the window")
    M:Undo()
    check(sitsAt(bags, 640, 480), "Undo takes a run of nudges back to where it began")
    -- reset spot
    M.resetBtn.scripts.OnClick(M.resetBtn)
    check(VoltUIDB.bagPoint == nil and bags.points[1][1] == "BOTTOMRIGHT" and M.resetBtn.alpha == 0.4, "Reset spot puts it back at its default spot")
    M:Undo()
    check(sitsAt(bags, 640, 480) and sitsAt(bf, 640, 480), "and Undo brings it back")
    M:ResetSpot()
    -- a frame of a part: reset uses that part's own placing
    local pm = VoltUIPlayerFrame.mover
    VoltUIPlayerFrame.dropLeft, VoltUIPlayerFrame.dropTop = 400, 300
    pm.scripts.OnDragStart(pm)
    pm.scripts.OnDragStop(pm)
    check(VoltUIDB.playerPoint ~= nil and sitsAt(VoltUIPlayerFrame, 400, 300), "the player frame, dragged")
    M:ResetSpot()
    check(VoltUIDB.playerPoint == nil and VoltUIPlayerFrame.points[1][1] == "CENTER", "Reset spot sends it back to its default spot")
    M:Undo()
    check(sitsAt(VoltUIPlayerFrame, 400, 300), "and Undo returns it")
    M:ResetSpot()
    M.undo = nil
    -- the list of frames
    M.listBtn.scripts.OnClick(M.listBtn)
    local shown, rows = 0, 0
    for _, m in ipairs(S.movers) do if M.Seen(m) then shown = shown + 1 end end
    local lootRow
    for _, r in ipairs(VoltUIMoveList.rows) do
      if r.shown then rows = rows + 1 end
      if r.shown and r.text.text == "Loot" then lootRow = r end
    end
    check(VoltUIMoveList.shown and rows == shown and lootRow, "Frames lists every frame that can be moved: " .. rows)
    lootRow.scripts.OnClick(lootRow)
    check(M.picked == loot.mover and not VoltUIMoveList.shown and M.name.text == "Loot", "picking one from the list picks it on the toolbar")
    M.listBtn.scripts.OnClick(M.listBtn)
    M.listBtn.scripts.OnClick(M.listBtn)
    check(not VoltUIMoveList.shown, "the button closes the list again")
    -- snapping to another frame
    VoltUIDB.snapFrames = true
    M:Refresh()
    local ll, lt = loot:GetLeft(), loot:GetTop()
    local dropL, dropT = ll + 5, lt - 152 - 60 -- sixty under the loot box, five to the right of its edge
    local dx, dy = M:FrameSnap(ra.mover, dropL, dropT, 320, 96)
    check(dx == -5, "five pixels right of the loot box's edge counts as near it: " .. tostring(dx))
    ra.dropLeft, ra.dropTop = dropL, dropT
    ra.mover.scripts.OnDragStart(ra.mover)
    ra.points = { { "TOPLEFT", UIParent, "BOTTOMLEFT", dropL, dropT } } -- where the drag has it
    M.bar.scripts.OnUpdate(M.bar, 0.1)
    check(VoltUIGuides and VoltUIGuides.shown and VoltUIGuides.v.shown and VoltUIGuides.h.shown == (dy ~= nil), "dragging near another frame's edge shows a line down it")
    ra.mover.scripts.OnDragStop(ra.mover)
    check(sitsAt(ra, ll, dropT + (dy or 0)) and not VoltUIGuides.shown, "dropped, it lines up with that edge, and the line goes")
    -- somewhere nothing is near
    local farL, farT
    for ox = 41, 900, 13 do
      for oy = 0, 500, 17 do
        local fx, fy = M:FrameSnap(ra.mover, ll + ox, lt - 300 - oy, 320, 96)
        if not farL and not fx and not fy then farL, farT = ll + ox, lt - 300 - oy end
      end
    end
    check(farL ~= nil, "there's a spot with no frame near it")
    ra.dropLeft, ra.dropTop = farL, farT
    ra.mover.scripts.OnDragStart(ra.mover)
    ra.mover.scripts.OnDragStop(ra.mover)
    check(sitsAt(ra, farL, farT), "further than a few pixels from any frame it's left where it's dropped")
    M.alignBtn.scripts.OnClick(M.alignBtn)
    check(VoltUIDB.snapFrames == false, "To frames on the toolbar switches it off")
    ra.dropLeft, ra.dropTop = dropL, dropT
    ra.mover.scripts.OnDragStart(ra.mover)
    ra.mover.scripts.OnDragStop(ra.mover)
    check(sitsAt(ra, dropL, dropT), "and then nothing snaps to frames")
    M:ResetSpot()
    -- leaving puts the boxes away
    FUI:SetUnlocked(false)
    check(not bags.shown and not bags.mover.shown and not loot.shown and M.undo == nil, "stopping puts the boxes away")
    Extra("rare list drag") -- another add-on's tests, since VoltUI 1.104.0
    for _, k in ipairs({ "bag", "bank", "loot", "rare", "treasure", "rareList", "treasureList" }) do
      VoltUIDB[k .. "Left"], VoltUIDB[k .. "Top"], VoltUIDB[k .. "Point"] = nil, nil, nil
    end
    ns.Bags:Place(ns.Bags.windows.bags)
    VoltUIDB.snap, VoltUIDB.snapFrames = keep.snap, keep.snapFrames
  end)()
  -- 1.39.0: a copy of the frame at the top of its page
  ;(function()
    local U = ns.UnitFrames
    E:Open("general")
    check(not E.previewBox.shown and E.previewH == 0, "a page without a frame has no preview strip")
    local plain = E.scroll.viewH
    E:Select("player")
    local pf = E.previews.player
    local c = U:Cfg("player")
    check(E.previewBox.shown and pf and pf.shown and pf.preview and pf.parent == E.previewBox, "the player page shows a copy of the player frame")
    check(pf ~= VoltUIPlayerFrame and U.frames.player == VoltUIPlayerFrame and U.byUnit.player == VoltUIPlayerFrame, "it's a copy: the real frame is untouched")
    check(pf.w == c.width and pf.name.text == VoltUIPlayerFrame.name.text and pf.hp.shown ~= false, "laid out and filled in like the real one: " .. tostring(pf.name.text))
    check(E.previewH == 96 and E.previewBox.h == 96, "the strip is one height: " .. E.previewH)
    -- a change shows on it straight away
    local w0, h0 = c.width, E.previewH
    local by = {}
    for _, r in ipairs(E.rows) do if r.def.key then by[r.def.key] = r end end
    by.width:Set(w0 + 40)
    check(pf.w == w0 + 40 and VoltUIPlayerFrame.w == w0 + 40, "changing the width changes both")
    by.width:Set(w0)
    local view0 = E.scroll.viewH
    by.hpHeight:Set(c.hpHeight + 60)
    by.scale:Set(2)
    check(E.previewH == h0 and E.scroll.viewH == view0, "a taller frame doesn't resize the strip, so the cards stay put under the mouse")
    by.scale:Set(1)
    by.hpHeight:Set(20)
    -- other tabs have their own; the target's can try the elite looks
    E:Select("target")
    local tf = E.previews.target
    check(tf and tf.shown and not pf.shown and tf.unit == "player" and tf.key == "target", "the target tab shows its own copy, with you standing in")
    E:Select("bags")
    check(not E.previewBox.shown and not tf.shown and E.scroll.viewH == plain, "leaving for another page puts the strip away")
    E:Select("player")
    E:Search("width")
    check(not E.previewBox.shown and E.previewH == 0, "search results have no strip")
    E:ClearSearch()
    -- its numbers keep up
    E:Select("player")
    local updates = 0
    local real = U.Update
    U.Update = function(self, f, light) if f == pf then updates = updates + 1 end return real(self, f, light) end
    E.previewBox.scripts.OnUpdate(E.previewBox, 0.2)
    check(updates == 0, "the copy isn't redrawn every frame")
    E.previewBox.scripts.OnUpdate(E.previewBox, 0.4)
    check(updates == 1, "but twice a second, so health and power keep up")
    U.Update = real
    -- a part that's off has no preview
    local was = U.enabled
    U.enabled = false
    E.pages.player = nil
    E:Select("player")
    check(not E.previewBox.shown, "no strip while unit frames are off")
    U.enabled = was
    E.pages.player = nil
    E:Select("player")
    check(E.previewBox.shown, "and it's back with them")
    E:Close()
  end)()
  -- 1.38.0: rows with help are marked, and a dimmed row says why
  ;(function()
    local U = ns.UnitFrames
    local function tipOf(owner)
      GameTooltip.lines = {}
      GameTooltip.shownNow = false
      local show = GameTooltip.Show
      GameTooltip.Show = function(self) self.shownNow = true end
      local setText, addLine = GameTooltip.SetText, GameTooltip.AddLine
      local got = {}
      GameTooltip.SetText = function(_, t) got[#got + 1] = t end
      GameTooltip.AddLine = function(_, t) got[#got + 1] = t end
      owner.scripts.OnEnter(owner)
      GameTooltip.Show, GameTooltip.SetText, GameTooltip.AddLine = show, setText, addLine
      return GameTooltip.shownNow, table.concat(got, " | ")
    end
    E:Open("player")
    local by = {}
    for _, r in ipairs(E.rows) do if r.def.key then by[r.def.key] = r end end
    check(by.heals.hasHelp and by.heals.help.text == "?" and by.heals.help.points[1][2] == by.heals.label and not by.heals.label.text:find("?", 1, true)
      and by.heals.label.text:find("Incoming heals", 1, true), "a row with help has a ? of its own right after its name (1.87.0)")
    check(not by.width.hasHelp and by.width.label.text == "Width", "a row without doesn't")
    local was = U:Cfg("player").power
    U:Cfg("player").power = false
    E:RefreshPage()
    local shown, text = tipOf(by.pwHeight.tipZone)
    check(by.pwHeight.alpha == 0.45 and shown and text:find("Needs the power bar on", 1, true), "a dimmed row says what it's waiting for: " .. text)
    U:Cfg("player").power = true
    E:RefreshPage()
    shown = tipOf(by.pwHeight.tipZone)
    check(by.pwHeight.alpha == 1 and not shown, "and nothing once it works again")
    local lock = InCombatLockdown
    InCombatLockdown = function() return true end
    E:RefreshPage()
    shown, text = tipOf(by.width.tipZone)
    check(shown and text:find("out of combat", 1, true), "in combat a held row says it's waiting for the fight to end: " .. text)
    InCombatLockdown = lock
    E:RefreshPage()
    shown, text = tipOf(by.heals.switch)
    check(shown and text:find("Heals on their way", 1, true) and not text:find("Needs", 1, true), "help alone when the row works: " .. text)
    U:Cfg("player").power = was
    E:RefreshPage()
    E:Close()
  end)()
  -- 1.38.0: the Home page
  ;(function()
    local P, FUI = ns.Pages, ns.FUI
    check(P.list[1].key == "home" and E.side[1].tab == "home" and E.side[1].text.text == "Home", "Home is the first page")
    E:Open("home")
    local tiles, shortcuts
    for _, r in ipairs(E.rows) do
      if r.tiles then tiles = r end
      if r.buttons and not shortcuts then shortcuts = r end -- the launcher
    end
    local parts = 0
    for _, m in ipairs(FUI.modules) do if m.key ~= "icon" then parts = parts + 1 end end
    check(tiles and #tiles.tiles == parts and #tiles.subRows == parts, "a tile for each part of VoltUI: " .. parts)
    local function tile(key) for _, t in ipairs(tiles.tiles) do if t.mod.key == key then return t end end end
    local bags, tips = tile("bags"), tile("tooltips")
    check(bags.state.text == "On" and bags.page == "bags" and tile("junk").page == "loot" and bags.icon and bags.icon.kind == "bags", "a tile has its part's icon, says what it's doing, and knows its page")
    -- tiles sit under the sidebar's headings
    local heads = {}
    for _, fs in ipairs(allFontStrings) do if fs.parent == tiles and fs.text ~= "" then heads[#heads + 1] = fs.text end end
    check(table.concat(heads, ","):find("FRAMES", 1, true) and table.concat(heads, ","):find("ITEMS", 1, true), "under the sidebar's headings: " .. table.concat(heads, ","))
    local fr1, fr2 = tile("frames"), tile("castbar")
    local t1, t2 = tiles.tiles[1], tiles.tiles[2]
    check(ns.Pages.PartGroup(t1.mod) == ns.Pages.PartGroup(t2.mod) and t2.points[1][4] > t1.points[1][4] and t2.points[1][5] == t1.points[1][5],
      "side by side within a heading: " .. t1.mod.key .. " " .. t1.points[1][4] .. "," .. t1.points[1][5] .. " / " .. t2.mod.key .. " " .. t2.points[1][4] .. "," .. t2.points[1][5])
    bags.scripts.OnClick(bags)
    check(E.tab == "bags", "clicking a tile opens its page")
    E:Select("home")
    -- switching a part from its tile
    local row
    for _, r in ipairs(E.rows) do if r.def.key == "tooltips" and r.def.store == "part" then row = r end end
    check(row and row.switch and row.page == "home", "the tile's switch is a row like any other")
    local onName = tips.name.color[1]
    row:Step(1)
    check(VoltUIDB.tooltips == false and tips.state.text == "Off after a reload" and FUI:ReloadPending() and E.banner.shown, "switching one off says so, and asks for a reload")
    check(tips.name.color[1] == ns.Style.UI.off[1] and tips.icon.color[1] == ns.Style.UI.off[1] and tips.dot.shown, "an off tile turns grey, icon and all, with a dot for the reload it waits on")
    check(tint(tips.dot)[1] == ns.Style.UI.info[1] and tips.state.color[1] == ns.Style.UI.info[1], "the reload it waits on is blue")
    row:Step(1)
    check(VoltUIDB.tooltips ~= false and tips.state.text == "On" and not E.banner.shown and tips.name.color[1] == onName and not tips.dot.shown, "and back")
    -- standing aside for another add-on, and off
    local N = ns.Nameplates
    local wasY, wasE = N.yielded, N.enabled
    N.yielded, N.enabled = "Plater", true
    check(P.PartState(N) == "Plater draws these", "a part standing aside names the add-on")
    N.yielded, N.enabled = nil, false
    VoltUIDB.nameplates = false
    check(P.PartState(N) == "Off", "and one that's off says Off")
    VoltUIDB.nameplates = nil
    check(P.PartState(N) == "On after a reload", "one switched on but not started yet says so")
    N.yielded, N.enabled = wasY, wasE
    -- General no longer lists the parts
    E:Select("general")
    local dup = false
    for _, r in ipairs(E.rows) do if r.def.store == "part" and r.def.key ~= "chat" and r.def.key ~= "links" then dup = true end end
    check(not dup, "the parts are on Home only (the Chat section has its own switch, as every part's section does)")
    -- search still finds a part's switch, working
    E:Search("sell junk")
    local hit
    for _, r in ipairs(E.rows) do if r.def.key == "junk" and r.def.store == "part" and r.page == "home" then hit = r end end
    check(hit and hit.switch and hit.page == "home", "search finds a part's switch")
    E:ClearSearch()
    -- the launcher
    E:Select("home")
    local function short(key) for _, b in ipairs(shortcuts.buttons) do if b.item.key == key then return b end end end
    check(short("move").text.text == "Move frames" and short("errors").text.text:find("Errors", 1, true) and short("keys") and short("move").icon.kind == "move"
      and not short("move").sub and short("move").item.how == "/volt edit", "the launcher: buttons with an icon and a name; the hover says how else to get there")
    short("share").scripts.OnClick(short("share"))
    check(E.tab == "share", "a launcher button opens its page")
    E:Select("home")
    short("move").scripts.OnClick(short("move"))
    check(FUI.unlocked and short("move").text.text == "Stop moving", "Move frames starts moving frames, and the button says so")
    local right = 0
    for _, b in ipairs(shortcuts.buttons) do right = math.max(right, b.points[1][4] + b.w) end
    check(right <= shortcuts.w, "the launcher fits its card: " .. right .. " of " .. shortcuts.w)
    short("move").scripts.OnClick(short("move"))
    check(not FUI.unlocked and short("move").text.text == "Move frames", "and stops")
    E:Close()
  end)()
  -- 1.37.0: pages that share rows are tabs of one sidebar entry
  local P = ns.Pages
  local function entry(key) for _, b in ipairs(E.side) do if b.tab == key then return b end end end
  local function tab(key) for _, b in ipairs(E.tabButtons) do if b.key == key and b.shown then return b end end end
  E:Open("general")
  check(E.tabGroup == nil and not E.tabLine.shown and tab("player") == nil and E.title.text == "General", "a page on its own has no tabs")
  local top0 = E.scroll.viewH
  check(entry("player") and entry("player").text.text == "Unit frames" and not entry("target") and not entry("pet"), "the four unit frames share one entry")
  check(entry("plates").text.text == "Nameplates" and (not ns.Rares or entry("rares").text.text == "Rares and treasures") and entry("questie").text.text == "Other add-ons"
    and entry("heal").text.text == "Healing" and entry("party").text.text == "Party and raid", "and so do the other sets")
  entry("player").scripts.OnClick(entry("player"))
  check(E.tab == "player" and E.title.text == "Unit frames" and E.tabLine.shown, "its entry opens the first tab, under the set's name")
  check(tab("player") and tab("target") and tab("tot") and tab("pet") and tab("player").bar.shown and not tab("pet").bar.shown, "a tab for each page, the current one marked")
  check(tab("target").points[1][4] > tab("player").points[1][4], "side by side")
  check(E.previewH > 0 and E.scroll.viewH == top0 - 26 - E.previewH - 6, "the cards start below the tabs and the preview")
  tab("pet").scripts.OnClick(tab("pet"))
  check(E.tab == "pet" and tab("pet").bar.shown and entry("player").bar.shown and VoltUIDB.editPage == "pet", "clicking a tab shows that page; the entry stays marked")
  E:Select("bags")
  check(not entry("player").bar.shown and entry("bags").bar.shown and tab("pet") == nil and E.scroll.viewH == top0, "another page: the tabs go")
  entry("player").scripts.OnClick(entry("player"))
  check(E.tab == "pet", "the entry comes back to the tab you were on")
  E:Select("party")
  check(tab("party").text.text == "Party" and tab("raid").text.text == "Raid" and E.title.text == "Party and raid", "tabs can have shorter names than their pages")
  E:Open("plateTarget")
  check(E.tab == "plateTarget" and entry("plates").bar.shown and tab("plateTarget").bar.shown, "opening a page by name lands on its tab")
  E:Search("border")
  check(E.tabGroup == nil and tab("plates") == nil and not E.tabLine.shown, "search results have no tabs")
  local n = (E.counts.plates or 0) + (E.counts.friendly or 0) + (E.counts.plateTarget or 0)
  check(n >= 3 and entry("plates").note.text == tostring(n), "the entry counts the results on all its tabs: " .. n)
  E:ClearSearch()
  E:Select("general")
  local heads = 0
  for _, g in ipairs(P.GROUPS) do heads = heads + 1 end
  check(heads == 6 and P.byKey.plates.group == "World" and P.byKey.errors.group == "More", "six headings in the sidebar")
  E:Close()
  -- the new-item mark sits clear of the item level
  local b
  for _, list in pairs(ns.Bags.windows.bags.buttons) do
    for _, btn in pairs(list) do b = b or btn end
  end
  check(b ~= nil and b.fuiNew.points[1][1] == "BOTTOMLEFT" and b.fuiLevel.points[1][1] == "TOPLEFT",
    "bags: the new-item mark is clear of the item level")
end)()

-- 1.67.0: the game's weapon swing timers and guild bank window in VoltUI's look
;(function()
  local C, G = ns.Castbar, ns.GuildBank
  -- swing timers: the game's bars, repainted, nothing written on them
  check(VoltUIDB.castSwing == true, "swing timers are skinned by default")
  local function swingBar(name)
    local f = new("Frame", name)
    f.Background, f.Border = f:CreateTexture(), f:CreateTexture()
    f.StatusBar = new("StatusBar", nil, f)
    local bar = f.StatusBar
    bar.Pip, bar.TypeLabelShadow = bar:CreateTexture(), bar:CreateTexture()
    bar.TypeLabel, bar.TimeLabel = bar:CreateFontString(), bar:CreateFontString()
    return f
  end
  local main, off = swingBar("SwingTimerMainHandFrame"), swingBar("SwingTimerOffHandFrame")
  local keysBefore = {}
  for k in pairs(main) do keysBefore[k] = true end
  C:SkinSwings()
  local added = {}
  for k in pairs(main) do if not keysBefore[k] then added[#added + 1] = k end end
  check(C.swingSkinned[main] and C.swingSkinned[off] and C.swingError == nil, "both swing bars are skinned: " .. tostring(C.swingError))
  check(#added == 0, "and VoltUI writes no field on the game's Edit Mode frame: " .. table.concat(added, ", "))
  local bar = main.StatusBar
  check(main.Background.ctex and main.Background.ctex[4] == 0 and main.Border.ctex[4] == 0,
    "its frame art is emptied, not faded (the game sets that alpha itself)")
  check(bar.TypeLabelShadow.alpha == 0 and (bar.barTex or bar.sbt) == ns.Style.WHITE, "a flat fill in place of the game's art")
  check(bar.Pip.w == 2 and bar.TypeLabel.font and bar.TimeLabel.font[2] == 11, "a thin spark and VoltUI's font")
  local onBar = 0
  for _, r in ipairs(bar.regions) do if r ~= bar.Pip and r ~= bar.TypeLabelShadow then onBar = onBar + 1 end end
  check(onBar >= 6, "VoltUI's back, track and border hang off the bar, so they dim with it out of range: " .. onBar)
  local n = #bar.regions
  C:SkinSwings()
  check(#bar.regions == n, "only once")
  SwingTimerMainHandFrame, SwingTimerOffHandFrame = nil, nil
  VoltUIDB.castSwing = false
  local later = swingBar("SwingTimerRangedFrame")
  C:SkinSwings()
  check(not C.swingSkinned[later], "switched off, the bars are left as the game drew them")
  VoltUIDB.castSwing = true
  SwingTimerRangedFrame = nil

  -- guild bank: waits for the game's load-on-demand window
  check(G and G.enabled and VoltUIDB.guildbank == true and not G.done, "the guild bank part is on, and waits for the game's window")
  local f = new("Frame", "GuildBankFrame")
  local vault, marble = f:CreateTexture(), f:CreateTexture()
  f.TitleText, f.TabTitle, f.LimitLabel = f:CreateFontString(), f:CreateFontString(), f:CreateFontString()
  f.CloseButton = new("Button", nil, f)
  f.Emblem = new("Frame", nil, f)
  f.Columns, f.BankTabs = {}, {}
  local slot
  for c = 1, 2 do
    local col = new("Frame", nil, f)
    col.Background = col:CreateTexture()
    col.Buttons = {}
    for i = 1, 2 do
      local b = new("Button", nil, col)
      b.icon, b.IconBorder, b.Count = b:CreateTexture(), b:CreateTexture(), b:CreateFontString()
      col.Buttons[i] = b
      slot = slot or b
    end
    f.Columns[c] = col
  end
  local side = new("Frame", nil, f)
  local sideArt = side:CreateTexture()
  side.Button = new("CheckButton", nil, side)
  side.Button.IconTexture = side.Button:CreateTexture()
  f.BankTabs[1] = side
  local tabs = {}
  for i = 1, 4 do
    local t = new("Button", "GuildBankFrameTab" .. i, f)
    t.id = i
    t.Left, t.Middle, t.Right = t:CreateTexture(), t:CreateTexture(), t:CreateTexture()
    t.LeftActive, t.MiddleActive, t.RightActive = t:CreateTexture(), t:CreateTexture(), t:CreateTexture()
    tabs[i] = t
  end
  f.DepositButton = new("Button", nil, f)
  f.DepositButton.Left = f.DepositButton:CreateTexture()
  f.MoneyFrameBG = new("Frame", nil, f)
  local gold = f.MoneyFrameBG:CreateTexture()
  local sb = new("EditBox", "GuildItemSearchBox", f)
  sb.Left, sb.Middle, sb.Right = sb:CreateTexture(), sb:CreateTexture(), sb:CreateTexture()
  local qualityCalls = 0
  function SetItemButtonQuality() qualityCalls = qualityCalls + 1 end
  function PanelTemplates_SelectTab() end
  function PanelTemplates_DeselectTab() end
  fire("ADDON_LOADED", "Blizzard_GuildBanVoltUI")
  check(G.done and G.errors == nil, "the window is skinned once the game loads it: " .. table.concat(G.errors or {}, "; "))
  check(vault.alpha == 0 and marble.alpha == 0 and f.Emblem.alpha == 0 and f.fuiPanel, "the vault art and tabard fade under a VoltUI panel")
  check(f.TitleText.text == GUILD_BANK or f.TitleText.font, "the title in VoltUI's font")
  check(f.Columns[1].Background.alpha == 0 and G.slots[slot] and slot.IconBorder.alpha == 0 and slot.icon.texCoord,
    "slots lose the game's art and border for cropped icons and VoltUI's rarity outline")
  check(sideArt.alpha == 0 and side.Button.IconTexture.texCoord, "the side tabs are flat")
  check(tabs[1].Left.alpha == 0 and tabs[1].LeftActive.alpha == 0 and G.tabs[tabs[1]], "the bottom tabs are flat")
  check(f.DepositButton.Left.alpha == 0 and gold.alpha == 0 and sb.Middle.alpha == 0, "buttons, the money box and search too")
  check(hookedGlobals.SetItemButtonQuality and hookedGlobals.PanelTemplates_SelectTab, "outlines and the chosen tab follow the game's shared helpers")
  SetItemButtonTexture(slot, 135) -- the game redraws the slot, resetting the crop
  local tc = slot.icon.texCoord or {}
  check(hookedGlobals.SetItemButtonTexture and tc[1] == 0.08 and tc[4] == 0.92,
    "the icon keeps its crop after the game redraws the slot, so the border drawn into it stays hidden")
  slot.icon.GetTexture = function() return 135 end
  SetItemButtonQuality(slot, 4)
  local edge = slot.regions[#slot.regions]
  check(qualityCalls == 1, "the game's own helper still runs")
  local purple = false
  for _, r in ipairs(slot.regions) do
    local c = tint(r)
    if c and math.abs((c[1] or 0) - 0.64) < 0.01 and math.abs((c[3] or 0) - 0.93) < 0.01 then purple = true end
  end
  check(purple, "an epic in the guild bank gets a purple outline")
  PanelTemplates_SelectTab(tabs[2])
  check(G.tabs[tabs[2]].shown, "the chosen tab gets its line")
  PanelTemplates_DeselectTab(tabs[2])
  check(not G.tabs[tabs[2]].shown, "and loses it when another is chosen")
  local other = new("Button")
  SetItemButtonQuality(other, 4) -- a bag slot somewhere else: nothing to do
  check(true, "other item buttons are left alone")
  local panel = f.fuiPanel
  G:Skin()
  check(f.fuiPanel == panel, "only once")
  GuildBankFrame, GuildItemSearchBox = nil, nil
  for i = 1, 4 do _G["GuildBankFrameTab" .. i] = nil end
end)()

-- 1.91.0: the group finder's listings laid out by VoltUI (GroupFinder.lua)
print("== Group finder")
;(function()
  local F = ns.GroupFinder
  check(F and F.enabled and VoltUIDB.groupfinder == true and not F.done, "the group finder part is on, and waits for the game's finder")
  check(F.Age(30) == "now" and F.Age(240) == "4m" and F.Age(4800) == "1h 20m" and F.Age(7200) == "2h" and F.Age(12000) == "3h" and F.Age(nil) == "",
    "how long ago a listing was made, in a few letters")
  check(F.Note("  need\n\ntank   and heals ") == "need tank and heals", "a note fits on one line")
  local acts = {
    [1] = { shortName = "Scholomance", fullName = "Scholomance (long)", minLevelSuggestion = 58, maxLevelSuggestion = 60 },
    [2] = { shortName = "", fullName = "Stratholme: Live" }, [3] = { shortName = "Dire Maul: East" },
    [4] = { shortName = "UBRS" }, [5] = { shortName = "LBRS" }, [6] = { shortName = "BRD" }, [7] = { shortName = "" },
  }
  local function infoOf(id) return acts[id] end
  local one, hit = F.Activities({ 1 }, nil, infoOf, true)
  check(one == "Scholomance  58-60" and hit == false, "a lone activity by its short name, with its level range: " .. one)
  local many, hit2 = F.Activities({ 1, 2, 3, 4, 5, 6, 7 }, { [3] = true }, infoOf, true)
  check(many == "Dire Maul: East, Scholomance, Stratholme: Live, UBRS +2" and hit2 == true,
    "several by name, yours first, the rest counted; one with no name is skipped: " .. many)
  local coloured = F.Activities({ 1, 3 }, { [3] = true }, infoOf)
  check(coloured:find("|cff%x+Dire Maul: East|r, Scholomance") ~= nil, "yours in gold: " .. coloured)
  check(F.Activities({}, nil, infoOf) == "" and F.Activities({ 7 }, nil, infoOf) == "", "nothing for no activities")
  local roster = F.Roster({ { name = "Lead", isLeader = true }, { name = "Totem", classFilename = "SHAMAN" }, { name = "Stab" }, false }, RAID_CLASS_COLORS, false)
  check(roster:find("with ") and roster:find("|cff0070deTotem|r, Stab") and not roster:find("Lead"), "who else is in the group, in class colours, without the leader: " .. roster)
  check(F.Roster({ { name = "Lead", isLeader = true } }, RAID_CLASS_COLORS) == "", "nothing for a group of one")

  -- the game's finder loads: its row function is followed, the row re-laid
  local results = {
    [7] = { activityIDs = { 1, 3 }, comment = "need tank\nand heals", numMembers = 3, age = 240, generalPlaystyle = nil },
    [8] = { activityIDs = { 1 }, comment = "", numMembers = 2, age = 30 },
    [9] = { activityIDs = { 2 }, comment = "gone", numMembers = 1, isDelisted = true, age = 900 },
  }
  local oldL = C_LFGList
  C_LFGList = {
    GetSearchResultInfo = function(id) return results[id] end,
    GetSearchResultLeaderInfo = function() return { name = "Lead", level = 60, classFilename = "SHAMAN", className = "Shaman" } end,
    GetSearchResultPlayerInfo = function(_, i) return ({ { name = "Lead", isLeader = true }, { name = "Stab", classFilename = "ROGUE" } })[i] end,
    GetActiveEntryInfo = function() return { activityIDs = { 3 } } end,
    GetActivityInfoTable = infoOf,
  }
  local gameRuns = 0
  function LFGBrowseSearchEntry_Update(row) gameRuns = gameRuns + 1 end
  local browse = new("Frame", "LFGBrowseFrame")
  local head = new("Button", nil, browse)
  head.CategoryLabel, head.ResultBG, head.Highlight = head:CreateFontString(), head:CreateTexture(), head:CreateTexture()
  local function makeRow(tall)
    local row = new("Button", nil, browse)
    for _, k in ipairs({ "ResultBG", "PartyIcon", "ClassIcon", "Selected", "Highlight", "NewPlayerFriendlyIcon" }) do row[k] = row:CreateTexture() end
    for _, k in ipairs({ "Name", "Level", "ActivityName" }) do row[k] = row:CreateFontString() end
    if tall then row.PlaystyleLabel = row:CreateFontString() end
    local dd = new("Frame", nil, row)
    dd.Comment = dd:CreateFontString()
    for _, k in ipairs({ "Solo", "RoleCount", "Enumerate", "PlayerCount", "DelistButton" }) do dd[k] = new("Frame", nil, dd); dd[k].shown = false end
    dd.Solo.RolesText = dd.Solo:CreateFontString()
    dd.RoleCount.shown = true
    row.DataDisplay = dd
    return row
  end
  local row = makeRow(true)
  browse.ScrollBox = { ForEachFrame = function(_, fn) fn(head); fn(row) end }
  fire("ADDON_LOADED", "Blizzard_GroupFinder_VanillaStyle")
  check(F.done and hookedGlobals.LFGBrowseSearchEntry_Update, "VoltUI follows the game's own row function once the finder loads")
  local keysBefore = {}
  for k in pairs(row) do keysBefore[k] = true end
  row.resultID = 7
  LFGBrowseSearchEntry_Update(row)
  local p = F.rows[row]
  check(gameRuns == 1 and p and F.errors == nil, "the game's function still runs, then VoltUI's: " .. tostring(F.errors and F.errors.row))
  local added = {}
  for k in pairs(row) do if not keysBefore[k] and k ~= "resultID" then added[#added + 1] = k end end
  check(#added == 0, "VoltUI writes no field on the game's row: " .. table.concat(added, ", "))
  check(row.ResultBG.alpha == 0 and row.PartyIcon.alpha == 0 and row.Level.alpha == 0 and row.ClassIcon.alpha == 0
    and row.ActivityName.alpha == 0 and row.PlaystyleLabel.alpha == 0 and row.DataDisplay.Comment.alpha == 0,
    "the game's pieces VoltUI's replace are faded")
  check(p.info.text == "60 Shaman", "level and class after the name: " .. tostring(p.info.text))
  check(p.acts.text:find("Dire Maul: East") and p.acts.text:find("Scholomance") and not p.acts.text:find("58%-60"),
    "the activities by name, not a count: " .. p.acts.text)
  check(p.note.text == "need tank and heals" and p.age.text == "4m", "the note on the row, and its age: " .. tostring(p.note.text))
  local bar = tint(p.bar)
  check(bar and math.abs(bar[3] - 0.87) < 0.01, "a bar in the leader's class colour")
  local last = p.acts.points[#p.acts.points]
  check(last[1] == "TOPRIGHT" and last[4] == -F.RIGHT and F.RIGHT <= 12, "the activities have the row's whole width (1.101.4): " .. tostring(last[4]))
  local ddp = row.DataDisplay.points[#row.DataDisplay.points]
  check(ddp and ddp[1] == "TOPRIGHT" and ddp[5] == F.DD_TOP and F.DD_TOP >= -2, "the game's role icons move up beside the first line, clear of the second")
  check(row.Selected.ctex and row.Highlight.ctex, "picked and hovered rows get flat tints")
  check(F.heads[head] and head.ResultBG.alpha == 0, "the Groups and Solo headings are flat too")
  local regions = #row.regions
  LFGBrowseSearchEntry_Update(row)
  check(#row.regions == regions, "parts are made once however often the row is drawn")
  row.resultID = 8
  LFGBrowseSearchEntry_Update(row)
  check(p.acts.text:find("Scholomance") and p.acts.text:find("58%-60") and p.note.text:find("with ") and p.note.text:find("Stab") and p.age.text == "now",
    "no note: who's in the group instead: " .. tostring(p.note.text))
  row.resultID = 9
  LFGBrowseSearchEntry_Update(row)
  check(p.acts.text == "Stratholme: Live" and p.age.text == "" and p.note.text == "gone" and math.abs(tint(p.bar)[1] - 0.87) > 0.01,
    "a listing that's gone: plain grey, no age, no class colour")
  local short = makeRow(false)
  short.resultID = 7
  results[7].hasSelf = true
  LFGBrowseSearchEntry_Update(short)
  local ps = F.rows[short]
  check(ps and not ps.note.shown and ps.acts.text:find("Your listing") and #short.DataDisplay.points == 1
    and short.DataDisplay.points[1][1] == "TOPRIGHT" and ps.acts.points[#ps.acts.points][4] == -F.RIGHT,
    "your own listing (a short row): two lines, the game's display up beside the first, the second full width")
  row.resultID = 404
  LFGBrowseSearchEntry_Update(row)
  check(F.errors == nil, "a result the game no longer has is left alone")
  VoltUIDB.groupfinder = false
  local other = makeRow(true)
  other.resultID = 8
  LFGBrowseSearchEntry_Update(other)
  check(not F.rows[other], "switched off, rows are left as the game drew them")
  VoltUIDB.groupfinder = true
  C_LFGList, LFGBrowseFrame = oldL, nil
end)()

Extra("lifts") -- another add-on's tests, since VoltUI 1.104.0

-- 1.69.0: bar textures (Style.lua) and timers (Timers.lua)
-- what a bar was given (an earlier test has the mock keep it as barTex)
local function barTexOf(b) return b.barTex or b.sbt end
print("== Bar textures")
;(function()
  local S = ns.Style
  local keys = {}
  for _, t in ipairs(S.BAR_TEXTURES) do keys[t.key] = t.path end
  check(keys.flat == S.WHITE and keys.voltsmooth:find("VoltUI\\Media\\BarSmooth", 1, true) and keys.voltobsidian, "flat and VoltUI's own textures, from the add-on's Media folder")
  check(keys.smooth == "Interface\\TargetingFrame\\UI-StatusBar" and keys.raid, "the game's two keep the keys the nameplates saved them under")
  local oldTex = VoltUIDB.barTexture
  VoltUIDB.barTexture = "flat"
  check(S.BarPath() == S.WHITE and S.BarPath("voltgloss") == keys.voltgloss and S.BarPath("gone") == S.WHITE, "a texture's file; flat, or white for one that's gone")
  local bar = S.Bar(new("Frame"))
  check(barTexOf(bar) == S.WHITE and S.texturedBars[bar], "VoltUI's bars start in VoltUI's texture and follow it")
  VoltUIDB.barTexture = "voltstripes"
  S.RefreshBarTextures()
  check(barTexOf(bar) == keys.voltstripes, "a new pick reaches bars already made")
  local raidTile, castMirror = 0, 0
  for b in pairs(S.texturedBars) do
    if barTexOf(b) == keys.voltstripes then raidTile = raidTile + 1 end
  end
  check(raidTile > 5, "unit, raid and cast bars all follow it: " .. raidTile)
  local found
  for _, page in ipairs(ns.Pages.list) do
    if page.key == "general" then
      for _, card in ipairs(page.sections()) do
        for _, row in ipairs(card) do if row.key == "barTexture" and row.store == "db" then found = row end end
      end
    end
  end
  check(found and #found.list() == #S.BAR_TEXTURES, "a Bar texture choice on the General page")
  VoltUIDB.barTexture = oldTex
  S.RefreshBarTextures()
  local share
  for _, p in ipairs(ns.Share.PARTS) do
    if p.key == "look" then for _, k in ipairs(p.keys) do if k == "barTexture" then share = true end end end
  end
  check(share, "and it's shared with the look")
end)()

print("== Timers")
;(function()
  local T = ns.Timers
  T.AUTO_LIST = true -- (1.102.0) as before it: everything found is a timer. The empty list has its own tests further down.
  local saved = {}
  for _, k in ipairs({ "UnitClass", "IsPlayerSpell", "IsSpellKnown", "C_Spell", "C_UnitAuras", "GetTotemInfo", "GetTotemDuration",
    "GetWeaponEnchantInfo", "GetInventoryItemTexture", "UnitCanAttack", "UnitExists", "UnitIsDeadOrGhost", "InCombatLockdown",
    "UnitAffectingCombat", "UnitLevel", "GetTime", "C_SpellBook", "GetSpellBaseCooldown", "issecretvalue", "Enum" }) do
    saved[k] = { _G[k] }
  end
  local clock = 1000
  GetTime = function() return clock end
  issecretvalue = nil
  UnitClass = function() return "Shaman", "SHAMAN" end
  UnitLevel = function() return 40 end
  local known = { [324] = true, [8042] = true, [8050] = true, [421] = true, [8017] = true, [20608] = true }
  IsPlayerSpell = function(id) return known[id] == true end
  IsSpellKnown = nil
  local NAMES = {
    [324] = "Lightning Shield", [8134] = "Lightning Shield", [8042] = "Earth Shock", [8050] = "Flame Shock", [8056] = "Frost Shock", [421] = "Chain Lightning",
    [16246] = "Clearcasting", [16257] = "Flurry", [16166] = "Elemental Mastery", [16188] = "Nature's Swiftness",
    [17364] = "Stormstrike", [20608] = "Reincarnation", [8017] = "Rockbiter Weapon", [20549] = "War Stomp", [2645] = "Ghost Wolf",
  }
  local cds, usable = {}, {}
  C_Spell = {
    GetSpellName = function(id) return NAMES[id] end,
    GetSpellTexture = function(id) return "icon" .. tostring(id) end,
    GetSpellCooldown = function(spell) return cds[spell] or { startTime = 0, duration = 0, isActive = false, isEnabled = true, isOnGCD = false } end,
    GetSpellCooldownDuration = function(spell) return cds[spell] and cds[spell].obj end,
    IsSpellUsable = function(spell) local u = usable[spell] or { true, false } return u[1], u[2] end,
  }
  local auras = { player = {}, target = {} }
  local refuse = false
  C_UnitAuras = {
    GetAuraDataByIndex = function(u, i, filter)
      if refuse then error("Auras cannot be accessed when secret while tainted") end
      return auras[u][i]
    end,
    GetAuraDuration = function(u, id) return { durationFor = id } end,
  }
  local totems = {}
  GetTotemInfo = function(slot)
    local t = totems[slot]
    if not t then return false, "", 0, 0, nil end
    return true, t.name, t.start, t.length, t.icon
  end
  GetTotemDuration = function(slot) return { totem = slot } end
  local mh, mhMs = false, 0
  GetWeaponEnchantInfo = function() return mh, mhMs, 0, 0, false, 0, 0, 0 end
  GetInventoryItemTexture = function(_, slot) return "weapon" .. slot end
  local target, fight = false, false
  UnitExists = function(u) return u == "player" or (u == "target" and target) end
  UnitCanAttack = function(_, u) return u == "target" and target end
  UnitIsDeadOrGhost = function() return false end
  InCombatLockdown = function() return fight end
  UnitAffectingCombat = function() return fight end
  -- the spellbook: War Stomp (a racial, 2 min) and Ghost Wolf (no cooldown), Chain Lightning (listed already)
  C_SpellBook = {
    GetNumSpellBookSkillLines = function() return 1 end,
    GetSpellBookSkillLineInfo = function() return { itemIndexOffset = 0, numSpellBookItems = 3 } end,
    GetSpellBookItemInfo = function(slot)
      local list = { { 20549, "War Stomp" }, { 2645, "Ghost Wolf" }, { 421, "Chain Lightning" } }
      local s = list[slot]
      return { itemType = 1, spellID = s[1], name = s[2], iconID = "book" .. s[1], isPassive = false }
    end,
  }
  GetSpellBaseCooldown = function(id) return ({ [20549] = 120000, [2645] = 0, [421] = 6000 })[id] end
  Enum = Enum or {}

  T.items = {}
  for _, k in ipairs({ "timerBuffsLeft", "timerCdsLeft" }) do VoltUIDB[k] = nil end
  VoltUIDB.timerCfg = nil
  local items = T:Collect()
  local by = {}
  for _, it in ipairs(items) do by[it.key] = it end
  check(by["keep:324"] and by["keep:324"].name == "Lightning Shield" and by["keep:324"].always, "a shaman keeps Lightning Shield up, and hears about it out of a fight")
  check(by["cd:8042"] and by["cd:8042"].name == "Shocks" and by["cd:8042"].spell == "Earth Shock", "one icon for the shared shock cooldown")
  check(by["cd:421"] and by["cd:20608"] and not by["cd:17364"] and not by["cd:16166"], "only the cooldowns you know")
  check(by["proc:16246"] and by["proc:16257"], "procs are watched whether or not you know the talent")
  check(by["dot:8050"] and by["dot:8050"].unit == "target" and not by["dot:17364"], "Flame Shock on the target")
  check(by["imbue:16"] and not by["imbue:17"], "the main-hand imbue (a shaman's off hand can't take one)")
  check(by["totem:1"] and by["totem:4"] and by["totem:1"].group == "totems", "a slot for each totem")
  check(by["cd:20549"] and by["cd:20549"].auto and not by["cd:2645"], "War Stomp from the spellbook; Ghost Wolf has no cooldown")
  local n421 = 0
  for _, it in ipairs(items) do if it.name == "Chain Lightning" then n421 = n421 + 1 end end
  check(n421 == 1, "a listed spell isn't added again from the spellbook")

  -- (1.80.0) spells of your own, by ID or by a spellbook name, and your own order
  do
    NAMES[2825], NAMES[30823] = "Bloodlust", "Shamanistic Rage"
    local function find(key) for i, it in ipairs(T.items) do if it.key == key then return it, i end end end
    local function inGroup(g) local t = {} for _, it in ipairs(T.items) do if it.group == g then t[#t + 1] = it.key end end return t end
    local ok, said = T:AddCustom("proc", "2825")
    if not T.enabled then T:Collect() end
    local mine = find("custom:proc:2825")
    check(ok and said == "Bloodlust" and mine and mine.custom and mine.group == "buffs" and mine.unit == "player" and mine.names[1] == "Bloodlust",
      "a proc added by its spell ID joins the buffs group: " .. tostring(said))
    ok, said = T:AddCustom("proc", "2825")
    check(not ok and said:find("already", 1, true), "not twice: " .. tostring(said))
    ok, said = T:AddCustom("cd", "War Stomp")
    check(not ok and said:find("already in the list", 1, true), "nor one that's a timer already: " .. tostring(said))
    ok, said = T:AddCustom("keep", "ghost wolf")
    if not T.enabled then T:Collect() end
    check(ok and said == "Ghost Wolf" and find("custom:keep:2645"), "a spell in your spellbook can be added by name, whatever the case")
    ok, said = T:AddCustom("dot", "No Such Spell")
    check(not ok and said:find("spell ID", 1, true), "a name the game doesn't know says to use the ID: " .. tostring(said))
    check(not T:AddCustom("bogus", "2825") and not T:AddCustom("cd", ""), "it has to be one of the four kinds, and something has to be typed")
    -- only on the class that added them
    UnitClass = function() return "Mage", "MAGE" end
    T:Collect()
    check(not find("custom:proc:2825"), "another class sharing these settings doesn't get a shaman's spells")
    UnitClass = function() return "Shaman", "SHAMAN" end
    T:Collect()
    check(find("custom:proc:2825") ~= nil, "and they're back on the shaman")
    -- your order
    local was = inGroup("buffs")
    local _, at = find("custom:proc:2825")
    check(T:Move("custom:proc:2825", -1), "one can be moved earlier")
    local now = inGroup("buffs")
    local _, at2 = find("custom:proc:2825")
    check(at2 < at and #VoltUIDB.timerCfg.order == #T.items and now[1] == was[1], "it changes places with the one before it in its group, and the order is kept")
    T:Collect()
    local again = inGroup("buffs")
    check(table.concat(again, ",") == table.concat(now, ","), "the order survives the spells being read again")
    check(not T:Move(again[1], -1) and not T:Move(again[#again], 1), "the ends of a group go no further")
    T:ResetOrder()
    if not T.enabled then T:Collect() end
    check(#VoltUIDB.timerCfg.order == 0 and table.concat(inGroup("buffs"), ",") == table.concat(was, ","), "Back to VoltUI's order puts them as they were")
    -- the settings page (1.102.0): Add a timer has a box and a button for each kind; a spell
    -- added there opens its own settings, which have Earlier, Later and Remove
    local Ed = ns.EditMode
    Ed.timerView = "add"
    Ed:Open("timers")
    local addRow
    for _, r in ipairs(Ed.rows) do
      if r.box and r.add then addRow = r end
    end
    check(addRow ~= nil, "Add a timer has the row to add any spell")
    if addRow then
      addRow.box:SetText("nothing like a spell")
      addRow.add("cd")
      check(addRow.said.text:find("No spell found", 1, true) and Ed.timerView == "add", "it says when it can't, and stays")
      addRow.box:SetText("30823")
      addRow.add("cd")
      check(find("custom:cd:30823") and find("custom:cd:30823").listed, "adding from the page: " .. tostring(addRow.said.text))
      check(Ed.timerView == "edit" and Ed.timerKey == "custom:cd:30823", "and its own settings open")
      local hero, order, gone
      for _, r in ipairs(Ed.rows) do
        if r.sub and r.name and r.icon then hero = r end
        if r.earlier and r.later then order = r end
        if r.def.kind == "button" and r.def.text == "Remove" then gone = r end
      end
      check(hero and hero.name.text == "Shamanistic Rage" and hero.sub.text:find("added by you", 1, true), "which say whose spell it is: " .. tostring(hero and hero.sub.text))
      check(order ~= nil and gone ~= nil, "with Earlier, Later and Remove")
      if order and gone then
        local _, i1 = find("custom:cd:30823")
        order.earlier.scripts.OnClick(order.earlier)
        local _, i2 = find("custom:cd:30823")
        check(i2 < i1, "Earlier moves it")
        gone.button.scripts.OnClick(gone.button)
        check(not find("custom:cd:30823") and Ed.timerView == "list", "Remove takes it off and goes back to the list")
      end
    end
    Ed.timerView, Ed.timerKey = nil, nil
    Ed:Close()
    -- Reset is for the look: the spells you added stay, the order goes
    T:Move("custom:proc:2825", -1)
    T:Reset()
    if not T.enabled then T:Collect() end
    check(find("custom:proc:2825") and #VoltUIDB.timerCfg.order == 0, "Reset keeps your spells and drops your order")
    T:RemoveCustom("custom:proc:2825")
    T:RemoveCustom("custom:keep:2645")
    if not T.enabled then T:Collect() end
    check(#VoltUIDB.timerCfg.custom == 0 and not find("custom:proc:2825") and not find("custom:keep:2645"), "and they can be removed")
    -- as it was, for what follows
    for _, k in ipairs({ "timerBuffsLeft", "timerCdsLeft" }) do VoltUIDB[k] = nil end
    VoltUIDB.timerCfg = nil
    T.items = {}
    items = T:Collect()
    by = {}
    for _, it in ipairs(items) do by[it.key] = it end
  end

  T:Cfg().missIdle = true -- (1.101.2) asked for: a missing buff shows out of a fight
  T:UpdateAll()
  local ls, shocks, cc = by["keep:324"], by["cd:8042"], by["proc:16246"]
  check(ls.w and ls.w.shown and ls.w.icon.desat, "Lightning Shield missing: grey")
  check(not ls.w.flashing and ls.w.body.alpha < 1, "out of a fight it doesn't flash, just sits faded (1.89.0)")
  T:Cfg().warnIdle = true
  T:Refresh()
  check(ls.w.flashing and T.anims[ls.w], "Flash them out of combat too: it flashes, since it's a long buff")
  check(shocks.w.shown and not shocks.w.icon.desat, "Shocks ready: bright")
  check(not cc.w or not cc.w.shown, "Clearcasting only shows while up")
  check(not by["dot:8050"].w or not by["dot:8050"].w.shown, "nothing on the target with no target")
  check(not by["totem:1"].w or not by["totem:1"].w.shown, "no totem down: no bar")
  local holder = T.holders.buffs
  check(holder and holder.shown and holder.w > 0, "the buffs group on screen")

  -- Lightning Shield goes up
  auras.player[1] = { name = "Lightning Shield", icon = "ls", applications = 3, duration = 600, expirationTime = 1500, auraInstanceID = 41 }
  fire("UNIT_AURA", "player")
  check(not ls.w.icon.desat and not ls.w.flashing and ls.w.wash.alpha == 0, "up: bright, no flash")
  check(ls.w.pulse == clock and ls.w.count.text == "3", "a pulse as it comes back, with its charges")
  check(ls.w.cd.cooldown and ls.w.cd.cooldown[1] == 900 and ls.w.cd.cooldown[2] == 600, "and the time it has left")
  clock = clock + 0.2
  T:Animate(clock)
  check(ls.w.body.scale > 1 and ls.w.glow.alpha > 0, "pulsing")
  clock = clock + 1
  T:Animate(clock)
  check(ls.w.body.scale == 1 and ls.w.glow.alpha == 0, "and done")

  -- a proc
  auras.player[2] = { name = "Clearcasting", icon = "cc", applications = 1, duration = 15, expirationTime = clock + 15, auraInstanceID = 42 }
  fire("UNIT_AURA", "player")
  check(cc.w and cc.w.shown and cc.w.pulse == clock and cc.w.icon.tex == "cc", "a proc shows with a pulse and its own icon")

  -- a cooldown: dark with the time, then a pulse when ready
  cds["Earth Shock"] = { startTime = clock, duration = 6, isActive = true, isEnabled = true, isOnGCD = false, obj = { es = true } }
  fire("SPELL_UPDATE_COOLDOWN")
  check(shocks.w.icon.desat and shocks.w.cd.cooldownObj and shocks.w.cd.cooldownObj.es, "on cooldown: grey, the game's own time on it")
  cds["Earth Shock"] = nil
  clock = clock + 6
  fire("SPELL_UPDATE_COOLDOWN")
  check(not shocks.w.icon.desat and shocks.w.pulse == clock and shocks.w.cd.cleared, "ready: bright, with a pulse")
  -- just the global cooldown: nothing
  shocks.w.pulse = nil
  cds["Earth Shock"] = { startTime = clock, duration = 1.5, isActive = true, isOnGCD = true }
  fire("SPELL_UPDATE_COOLDOWN")
  check(not shocks.w.icon.desat, "the global cooldown isn't a cooldown")
  cds["Earth Shock"] = nil
  fire("SPELL_UPDATE_COOLDOWN")
  check(shocks.w.pulse == nil, "and no pulse after it")
  -- short of mana: blue
  usable["Earth Shock"] = { false, true }
  fire("SPELL_UPDATE_USABLE")
  check(shocks.w.icon.vc[3] == 1 and shocks.w.icon.vc[1] < 0.6, "blue when short of mana")
  usable["Earth Shock"] = nil
  fire("SPELL_UPDATE_USABLE")

  -- the target: Flame Shock missing flashes in a fight, comes up with a pulse
  local fs = by["dot:8050"]
  target = true
  fire("PLAYER_TARGET_CHANGED")
  check(fs.w and fs.w.shown and fs.w.icon.desat and not fs.w.flashing, "a target: Flame Shock shows, grey, quiet out of a fight")
  fight = true
  fire("PLAYER_REGEN_DISABLED")
  check(fs.w.flashing, "in a fight it flashes while missing")
  auras.target[1] = { name = "Flame Shock", icon = "fs", duration = 12, expirationTime = clock + 12, auraInstanceID = 51 }
  fire("UNIT_AURA", "target")
  check(not fs.w.flashing and not fs.w.icon.desat and fs.w.pulse == clock, "put on: bright, a pulse")
  -- a fight hiding the auras: what was seen stays until the game says it went
  refuse = true
  fire("UNIT_AURA", "target", { updatedAuraInstanceIDs = { 51 } })
  check(fs.st.on and not fs.w.flashing, "hidden in a fight: still up")
  fire("UNIT_AURA", "target", { removedAuraInstanceIDs = { 51 } })
  check(not fs.st.on and fs.w.flashing, "until the game says it's gone")
  refuse = false
  auras.target[1] = nil
  target = false
  fire("PLAYER_TARGET_CHANGED")
  check(not fs.w.shown, "no target: gone")

  -- Lightning Shield put back on in a fight that hides aura names (seen in game, 1.77.0)
  auras.player[1] = nil
  fire("UNIT_AURA", "player")
  check(not ls.st.on, "Lightning Shield gone")
  fight, refuse = true, true
  fire("PLAYER_REGEN_DISABLED")
  auras.player[1] = { name = "Lightning Shield", icon = "ls", applications = 3, duration = 600, expirationTime = clock + 600, auraInstanceID = 70 }
  fire("UNIT_AURA", "player", { addedAuras = { { auraInstanceID = 70 } } }) -- its name hidden
  check(not ls.st.on and ls.st.unsure, "put back on in a fight it can't be read")
  fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 8134) -- a higher rank of it
  check(ls.st.on and not ls.w.flashing and ls.w.pulse == clock, "your cast says it's on: bright, a pulse")
  fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-2", 8042)
  check(ls.st.on, "another spell changes nothing")
  fight, refuse = false, false
  fire("PLAYER_REGEN_ENABLED")
  runTimers()
  check(ls.st.on and not ls.st.unsure and ls.st.timer and ls.st.timer.length == 600, "out of the fight it's read properly, with its time")
  refuse = true
  auras.player[1] = nil
  fire("UNIT_AURA", "player")
  check(ls.st.on and ls.st.unsure, "gone while it can't be read: kept as it was")
  refuse = false
  T:Tick()
  check(not ls.st.on and not ls.st.unsure, "and read again as soon as it can be")

  -- 1.89.0: a fight hides the names, not the aura ids. Lightning Shield losing its last charge
  -- in a fight flashed only once the fight ended; now its id going says it went.
  local function idList(u)
    local out = {}
    for _, x in ipairs(auras[u]) do out[#out + 1] = x.auraInstanceID end
    return out
  end
  C_UnitAuras.GetUnitAuraInstanceIDs = function(u) return idList(u) end
  wipe(auras.player) -- nothing else on you, so each new aura is the only new one
  C_UnitAuras.GetAuraApplicationDisplayCount = function(u, id, least)
    for _, x in ipairs(auras[u]) do
      if x.auraInstanceID == id then return x.applications >= (least or 2) and tostring(x.applications) or "" end
    end
    return ""
  end
  auras.player[1] = { name = "Lightning Shield", icon = "ls", applications = 3, duration = 600, expirationTime = clock + 600, auraInstanceID = 80 }
  fire("UNIT_AURA", "player")
  check(ls.st.on and ls.st.aid == 80, "Lightning Shield up, its id kept")
  fight, refuse = true, true
  fire("PLAYER_REGEN_DISABLED")
  auras.player[1].applications = 2
  fire("UNIT_AURA", "player")
  check(ls.st.on and not ls.st.unsure and ls.w.count.text == "2", "in a fight its id says it's still there, charges counting down")
  check(ls.st.timer and ls.st.timer.dur and ls.st.timer.dur.durationFor == 80, "with the game's own time for it")
  auras.player[1] = nil
  fire("UNIT_AURA", "player")
  check(not ls.st.on and ls.w.flashing, "its last charge gone in the fight: it flashes straight away")
  fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-3", 324)
  auras.player[1] = { name = "Lightning Shield", icon = "ls", applications = 3, auraInstanceID = 81 }
  fire("UNIT_AURA", "player")
  check(ls.st.on and ls.st.aid == 81 and not ls.st.unsure and not ls.w.flashing, "put back on in the fight: the new aura that came with the cast is it")
  fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-4", 324)
  auras.player[1] = { name = "Lightning Shield", icon = "ls", applications = 3, auraInstanceID = 82 }
  fire("UNIT_AURA", "player")
  check(ls.st.on and ls.st.aid == 82 and not ls.w.flashing, "cast again while up: a new aura in place of the old, no flash")
  auras.player[1] = nil
  fire("UNIT_AURA", "player")
  check(not ls.st.on and ls.w.flashing, "that one going in the fight flashes too")
  auras.player[1] = { name = "Lightning Shield", icon = "ls", applications = 3, auraInstanceID = 83 }
  fire("UNIT_AURA", "player")
  check(not ls.st.on, "a new aura with no cast of yours isn't taken for it")
  fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-5", 324)
  runTimers()
  check(ls.st.on and ls.st.aid == 83 and not ls.st.unsure, "the cast just after it picks it up")
  clock = clock + 5
  auras.player[1] = nil
  fire("UNIT_AURA", "player")
  fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-6", 324)
  auras.player[1] = { name = "Lightning Shield", icon = "ls", applications = 3, auraInstanceID = 84 }
  auras.player[2] = { name = "Flurry", icon = "fl", applications = 3, auraInstanceID = 85 }
  fire("UNIT_AURA", "player")
  check(ls.st.on and ls.st.unsure and ls.st.aid == nil, "two new auras at once: on from the cast, not sure which aura")
  fight, refuse = false, false
  fire("PLAYER_REGEN_ENABLED")
  runTimers()
  check(ls.st.on and ls.st.aid == 84 and not ls.st.unsure, "read properly after the fight")
  table.remove(auras.player, 2)
  -- an id list the game hides is no help: as before
  local hid = setmetatable({}, { __index = function() error("secret") end })
  local oldSecret = issecretvalue
  issecretvalue = function(v) return v == hid end
  C_UnitAuras.GetUnitAuraInstanceIDs = function() return hid end
  check(T.AuraIDs("player", "HELPFUL") == nil, "a secret id list reads as nothing")
  C_UnitAuras.GetUnitAuraInstanceIDs = function() return { 84, hid } end
  check(T.AuraIDs("player", "HELPFUL") == nil, "and so does one with a secret id in it")
  issecretvalue = oldSecret
  -- 1.92.3: the id list refused too, as the game evidently does in a fight: ask about the one
  -- buff, by the id known from before and by its spell id
  C_UnitAuras.GetUnitAuraInstanceIDs = function() error("refused") end
  C_UnitAuras.GetAuraDataByAuraInstanceID = function(u, id)
    for _, x in ipairs(auras[u]) do if x.auraInstanceID == id then return x end end
  end
  auras.player[1] = { name = "Lightning Shield", icon = "ls", applications = 3, duration = 600, expirationTime = clock + 600, auraInstanceID = 90, spellId = 8134 }
  fire("UNIT_AURA", "player")
  check(ls.st.on and ls.st.aid == 90 and ls.st.spellId == 8134, "out of a fight: up, its aura and spell ids kept")
  -- 1.92.4, seen in game: cast out of combat, the cast event a moment after the aura's; that
  -- cast isn't a later recast, so the shield going in the fight still warns
  fire("UNIT_AURA", "player")
  clock = clock + 1
  fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-0", 8134)
  runTimers()
  fight, refuse = true, true
  fire("PLAYER_REGEN_DISABLED")
  clock = clock + 5
  local keepLS = auras.player[1]
  auras.player[1] = nil
  fire("UNIT_AURA", "player")
  check(not ls.st.on and ls.w.flashing and not ls.st.unsure, "put on out of combat, gone in the fight: it flashes")
  fight, refuse = false, false
  fire("PLAYER_REGEN_ENABLED")
  runTimers()
  auras.player[1] = keepLS
  fire("UNIT_AURA", "player")
  VoltUIDB.auraProbe = nil
  fight, refuse = true, true
  fire("PLAYER_REGEN_DISABLED")
  auras.player[1].applications = 2
  fire("UNIT_AURA", "player")
  check(ls.st.on and not ls.st.unsure and ls.w.count.text == "2", "no id list in the fight: its own id says it's still there")
  auras.player[1] = nil
  fire("UNIT_AURA", "player")
  check(not ls.st.on and ls.w.flashing, "its last charge gone in the fight: it flashes straight away, id list or not")
  -- put back on: found by the spell id of the rank you cast, its new id learned
  C_UnitAuras.GetPlayerAuraBySpellID = function(id)
    for _, x in ipairs(auras.player) do if x.spellId == id then return x end end
  end
  auras.player[1] = { name = "Lightning Shield", icon = "ls", applications = 3, auraInstanceID = 91, spellId = 8134 }
  fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-7", 8134)
  runTimers()
  check(ls.st.on and ls.st.aid == 91 and not ls.st.unsure and not ls.w.flashing, "cast again in the fight: found by its spell id")
  auras.player[1] = nil
  fire("UNIT_AURA", "player")
  check(not ls.st.on and ls.w.flashing, "and that one going is seen too")
  -- the spell id refused as well: cast while up, the old aura replaced, so still on (not sure)
  C_UnitAuras.GetPlayerAuraBySpellID = function() error("refused") end
  fight, refuse = false, false
  fire("PLAYER_REGEN_ENABLED")
  auras.player[1] = { name = "Lightning Shield", icon = "ls", applications = 3, auraInstanceID = 92, spellId = 8134 }
  fire("UNIT_AURA", "player")
  fight, refuse = true, true
  fire("PLAYER_REGEN_DISABLED")
  clock = clock + 1
  fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-8", 8134)
  auras.player[1] = { name = "Lightning Shield", icon = "ls", applications = 3, auraInstanceID = 93, spellId = 8134 }
  fire("UNIT_AURA", "player")
  check(ls.st.on and ls.st.unsure and not ls.w.flashing, "recast with the old aura gone: on, not sure of its id")
  -- what the game answered is kept for the next fix
  local pr = VoltUIDB.auraProbe
  check(type(pr) == "table" and #pr >= 2 and #pr <= T.PROBE_KEEP, "the fight's answers are kept in VoltUIDB.auraProbe")
  check(pr[1] and pr[1].idList:find("^error") and pr[1].byIndex:find("^error") and pr[1].byAid:find("^table"),
    "each says what was refused and what wasn't")
  local probesBefore = #pr
  for _ = 1, 5 do fire("UNIT_AURA", "player") end
  check(#VoltUIDB.auraProbe <= probesBefore + T.PROBE_PER_FIGHT, "only the first few changes of a fight")
  VoltUIDB.auraProbe = nil
  fight, refuse = false, false
  fire("PLAYER_REGEN_ENABLED")
  runTimers()
  C_UnitAuras.GetAuraDataByAuraInstanceID, C_UnitAuras.GetPlayerAuraBySpellID = nil, nil
  C_UnitAuras.GetUnitAuraInstanceIDs, C_UnitAuras.GetAuraApplicationDisplayCount = nil, nil
  auras.player[1] = nil
  fire("UNIT_AURA", "player")
  -- 1.98.0, from VoltUIDB.auraProbe in game: in a fight every aura read is refused (the list,
  -- by index, by id, by spell). The game's own buff frame still has your buffs.
  ;(function()
    local oldUA, oldBF, oldIcon = C_UnitAuras, BuffFrame, ls.icon
    local real = C_UnitAuras.GetAuraDataByIndex
    ls.icon = "ls"
    clock = clock + 10 -- well clear of the casts above
    BuffFrame = nil
    check(T.GameBuffs() == nil, "no game buff frame: nothing from it")
    BuffFrame = { auraInfo = {} }
    auras.player[1] = { name = "Lightning Shield", icon = "ls", applications = 3, duration = 600, expirationTime = clock + 600, auraInstanceID = 100, spellId = 8134 }
    fire("UNIT_AURA", "player")
    check(ls.st.on and ls.st.aid == 100, "out of a fight: read as ever")
    fight, refuse = true, true
    fire("PLAYER_REGEN_DISABLED")
    C_UnitAuras = setmetatable({ GetAuraDataByIndex = real }, { __index = function() return function() error("Auras cannot be accessed when secret while tainted by 'VoltUI'") end end })
    BuffFrame.auraInfo = {
      { auraType = "TempEnchant", texture = "rock" },
      { auraType = "Buff", auraInstanceID = 55, texture = "other", count = 0, duration = 0, expirationTime = 0 },
      { auraType = "Buff", auraInstanceID = 100, texture = "ls", count = 2, duration = 600, expirationTime = clock + 500 },
    }
    local g = T.GameBuffs()
    check(g and #g.list == 2 and g.ids[100] and g.ids[55] and g.byId[100].n == 2, "the game's list: its buffs, not the weapon enchant")
    fire("UNIT_AURA", "player")
    check(ls.st.on and not ls.st.unsure and ls.w.count.text == "2", "in the fight the game's buff frame says it's still up, a charge down")
    check(ls.st.timer and ls.st.timer.length == 600 and ls.st.timer.start == clock - 100, "with its time")
    table.remove(BuffFrame.auraInfo, 3)
    fire("UNIT_AURA", "player")
    check(not ls.st.on and ls.w.flashing and not ls.st.unsure, "its last charge gone in the fight: it flashes straight away")
    -- back on with no cast seen (or a proc): found by its icon
    BuffFrame.auraInfo[3] = { auraType = "Buff", auraInstanceID = 101, texture = "ls", count = 3, duration = 600, expirationTime = clock + 600 }
    fire("UNIT_AURA", "player")
    check(ls.st.on and ls.st.aid == 101 and not ls.w.flashing and ls.w.count.text == "3", "put back on in the fight: found by its icon, its new id kept")
    -- values the game keeps secret are no help, and no error: as it was
    local hid = {}
    local oldSecret = issecretvalue
    issecretvalue = function(v) return v == hid end
    BuffFrame.auraInfo = { { auraType = "Buff", auraInstanceID = hid, texture = hid, count = hid, duration = hid, expirationTime = hid } }
    g = T.GameBuffs()
    check(g and g.ids == nil and #g.list == 1 and g.list[1].icon == nil, "secret ids and icons: read as unknown")
    fire("UNIT_AURA", "player")
    check(ls.st.on and ls.st.unsure, "so it stays as it was, to be read again later")
    BuffFrame.auraInfo = hid
    check(T.GameBuffs() == nil, "a secret list is nothing at all")
    issecretvalue = oldSecret
    -- the probe notes what the game's frame held
    BuffFrame.auraInfo = { { auraType = "Buff", auraInstanceID = 101, texture = "ls", count = 3, duration = 600, expirationTime = clock + 600 } }
    VoltUIDB.auraProbe, T.probes = nil, 0
    fire("UNIT_AURA", "player")
    local pr = VoltUIDB.auraProbe and VoltUIDB.auraProbe[1]
    check(pr and pr.gameBuffs and pr.gameBuffs:find("id number", 1, true) and pr.gameBuffs:find("icon string", 1, true),
      "the probe says what the game's buff frame gave: " .. tostring(pr and pr.gameBuffs))
    VoltUIDB.auraProbe = nil
    C_UnitAuras, BuffFrame, ls.icon = oldUA, oldBF, oldIcon
    fight, refuse = false, false
    fire("PLAYER_REGEN_ENABLED")
    runTimers()
    auras.player[1] = nil
    fire("UNIT_AURA", "player")
  end)()
  fight = true -- as the next part expects
  fire("PLAYER_REGEN_DISABLED")

  -- a short buff only flashes in a fight (smart): nothing short for a shaman, so a stand-in
  ls.always = nil
  auras.player[1] = nil
  fire("UNIT_AURA", "player")
  check(ls.w.flashing, "a short buff missing in a fight flashes")
  fight = false
  fire("PLAYER_REGEN_ENABLED")
  check(not ls.w.flashing and ls.w.body.alpha < 1, "out of one it waits, faded")
  ls.always = true
  T:Cfg().warnFight, T:Cfg().warnIdle = false, false
  T:Refresh()
  check(not ls.w.flashing, "warnings off: none")
  fight = true
  T:Refresh()
  check(not ls.w.flashing, "not in a fight either")
  fight = false
  -- 1.88.0's one choice becomes the two switches
  local function from(old)
    VoltUIDB.timerCfg.warn, VoltUIDB.timerCfg.warnFight, VoltUIDB.timerCfg.warnIdle = old, nil, nil
    T.cfgFilled = nil
    local c = T:Cfg()
    return c.warn == nil and c.warnFight, c.warnIdle
  end
  local f1, i1 = from("smart")
  check(f1 == true and i1 == false, "Smart: flashes in a fight, not out of one")
  local f2, i2 = from("always")
  check(f2 == true and i2 == true, "Always: both")
  local f3, i3 = from("combat")
  check(f3 == true and i3 == false, "Fights: in a fight")
  local f4, i4 = from("off")
  check(f4 == false and i4 == false, "Off: neither")
  T:Cfg().warnFight, T:Cfg().warnIdle = true, true
  T:Refresh()

  -- weapon imbue
  local wi = by["imbue:16"]
  mh, mhMs = true, 300000
  T:UpdateImbues()
  check(wi.w.shown and wi.st.on and wi.w.icon.tex == "weapon16" and wi.w.pulse == clock, "an imbue on: the weapon, a pulse")
  check(wi.w.cd.cooldown and wi.w.cd.cooldown[2] == 300, "its five minutes")
  clock = clock + 10
  mhMs = 290000
  T:Tick()
  check(wi.w.cd.cooldown[1] == wi.st.timer.start and wi.st.timer.length == 300, "running down, from the same start")
  mh = false
  T:Tick()
  check(not wi.st.on and wi.w.flashing, "gone: it flashes")

  -- buffs hidden while they're up (1.74.0): shown only when gone or running out
  local cfg = T:Cfg()
  check(cfg.buffHide == false and cfg.buffSoon == 60, "buffs show all the time unless told")
  cfg.buffHide = true
  auras.player[1] = { name = "Lightning Shield", icon = "ls", applications = 3, duration = 600, expirationTime = clock + 600, auraInstanceID = 61 }
  fire("UNIT_AURA", "player")
  check(ls.st.on and not ls.w.shown, "Lightning Shield up: hidden")
  clock = clock + 530
  T:Tick()
  check(not ls.w.shown, "still hidden with 70 seconds left")
  clock = clock + 15
  T:Tick()
  check(ls.w.shown and not ls.w.icon.desat and ls.st.on, "shown in its last minute, still bright")
  auras.player[1] = { name = "Lightning Shield", icon = "ls", applications = 3, duration = 600, expirationTime = clock + 600, auraInstanceID = 62 }
  fire("UNIT_AURA", "player")
  check(not ls.w.shown, "put back on: hidden again")
  table.remove(auras.player, 1)
  fire("UNIT_AURA", "player")
  check(not ls.st.on and ls.w.shown and ls.w.flashing, "gone: shown, and flashing")
  cfg.buffSoon = 0
  auras.player[1] = { name = "Lightning Shield", icon = "ls", applications = 3, duration = 600, expirationTime = clock + 600, auraInstanceID = 63 }
  fire("UNIT_AURA", "player")
  clock = clock + 590
  T:Tick()
  check(not ls.w.shown, "at 0, not even in its last seconds")
  auras.player[1].duration, auras.player[1].expirationTime = nil, nil -- a time the game keeps secret
  ls.st.timer = { dur = {} }
  check(not T:Visible(ls), "a buff whose time can't be read stays hidden while it's up")
  cfg.buffSoon = 60
  mh, mhMs = true, 300000
  T:UpdateImbues()
  check(wi.st.on and not wi.w.shown, "an imbue on: hidden")
  clock = clock + 250
  mhMs = 50000
  T:Tick()
  check(wi.w.shown, "shown in its last minute")
  mh = false
  T:Tick()
  check(not wi.st.on and wi.w.shown and wi.w.flashing, "and when it's gone")
  local ccAt = #auras.player + 1
  auras.player[ccAt] = { name = "Clearcasting", icon = "cc", applications = 1, duration = 15, expirationTime = clock + 15, auraInstanceID = 64 }
  fire("UNIT_AURA", "player")
  check(cc.w.shown, "procs still show while up")
  table.remove(auras.player, ccAt)
  T.preview = true
  check(T:Visible(ls), "moving frames shows them all")
  T.preview = nil
  cfg.buffHide = false
  table.remove(auras.player, 1)
  fire("UNIT_AURA", "player")

  -- totems: a bar each, a flash for a moment when one goes
  local fire1 = by["totem:1"]
  totems[1] = { name = "Searing Totem", start = clock, length = 55, icon = "searing" }
  fire("PLAYER_TOTEM_UPDATE")
  runTimers()
  check(fire1.w and fire1.w.shown and fire1.w.bar and fire1.w.label.text == "Searing Totem", "a totem down: a bar with its name")
  check(fire1.w.style == "bars" and barTexOf(fire1.w.bar) == ns.Style.BarPath(), "in VoltUI's bar texture")
  -- the game's own totem button, see-through over it: its right-click destroys the totem (1.77.0)
  local gb = CreateFrame("Button", nil, TotemFrame)
  gb.slot = 1
  function gb:SetAllPoints(f) self.over = f end
  local other = CreateFrame("Button", nil, TotemFrame)
  other.slot = 3 -- a slot with no timer showing
  local kidsWas = TotemFrame.kids
  TotemFrame.kids = { gb, other }
  TotemFrame.GetChildren = function(self) return unpack(self.kids or {}) end
  TotemFrame:Update()
  check(TotemFrame.alpha == 0, "the game's totem buttons are hidden")
  check(gb.over == fire1.w and gb.mouseOn == true and gb.flevel > (fire1.w.flevel or 0), "its button lies over the totem's timer, to click")
  check(other.over == nil and other.mouseOn == false, "one with no timer to lie over takes no clicks")
  check(gb.slot == 1 and other.slot == 3, "the game's fields are left alone")
  T:G("totems").on = false
  T:Refresh()
  check(TotemFrame.alpha == 1 and other.mouseOn == true, "the Totems group off: the game's buttons are back")
  T:G("totems").on = true
  T:Refresh()
  check(TotemFrame.alpha == 0 and gb.over == fire1.w, "and on again: hidden over the timers")
  TotemFrame.kids, TotemFrame.GetChildren = kidsWas, nil
  clock = clock + 10
  T:Animate(clock)
  check(math.abs(fire1.w.bar.value - 45 / 55) < 1e-6, "the bar runs down")
  totems[1] = nil
  fire("PLAYER_TOTEM_UPDATE")
  runTimers()
  check(fire1.w.shown and fire1.w.flashing, "gone: a flash where it was")
  clock = clock + 3
  T:Tick()
  check(not fire1.w.shown, "then it goes")

  -- seen in game, 1.78.0: what the game hands over as secrets in a fight
  do
    local SECRET = {}
    local secretList = { 70 }
    issecretvalue = function(v) return v == SECRET or v == secretList end
    -- a totem whose time is secret, and no duration object for it either
    local durWas = GetTotemDuration
    GetTotemDuration = function() return nil end
    local water = by["totem:3"]
    totems[3] = { name = "Healing Stream Totem", start = SECRET, length = SECRET, icon = "hs" }
    fire("PLAYER_TOTEM_UPDATE")
    runTimers()
    check(water.w and water.w.shown and water.st.on and water.st.timer == nil, "a totem with no time the game will give: shown, no timer")
    check(not (water.w.cd.cooldown and water.w.cd.cooldown[1] == nil), "and no empty time handed to its cooldown")
    totems[3] = nil
    fire("PLAYER_TOTEM_UPDATE")
    runTimers()
    GetTotemDuration = durWas
    -- seen in game, 1.79.0 (screenshots): in a fight the game hides whether a slot holds a totem
    -- at all. Only the slot it has a timer for is a totem; the empty ones mustn't show as bars.
    do
      local infoWas, durWas2 = GetTotemInfo, GetTotemDuration
      local down = { [2] = true } -- Stoneclaw, in the earth slot
      local hide = true
      GetTotemInfo = function(slot)
        if hide then return SECRET, SECRET, SECRET, SECRET, SECRET end
        if down[slot] then return true, "Stoneclaw Totem", clock, 15, "claw" end
        return false, "", 0, 0, nil
      end
      GetTotemDuration = function(slot) if down[slot] then return { totem = slot } end return nil end
      fight = true
      fire("PLAYER_TOTEM_UPDATE")
      runTimers()
      local earth = by["totem:2"]
      check(earth.w and earth.w.shown and earth.st.on and earth.st.timer and earth.st.timer.dur, "hidden by a fight: the slot the game has a timer for is a totem, on that timer")
      local phantom = {}
      for _, slot in ipairs({ 1, 3, 4 }) do
        local it = by["totem:" .. slot]
        if it.st.on or (it.w and it.w.shown and not it.w.flashing) then phantom[#phantom + 1] = slot end
      end
      check(#phantom == 0, "and the empty slots show nothing (they stood as full bars with no name): " .. table.concat(phantom, ","))
      -- it runs out mid-fight: the game stops handing a timer over, so the bar goes
      down[2] = nil
      fire("PLAYER_TOTEM_UPDATE")
      runTimers()
      clock = clock + 3
      T:Tick()
      check(not earth.st.on and not earth.w.shown, "a totem that runs out in the fight goes (it stayed as an empty black bar)")
      -- one still down when the fight ends is read properly again, name and time
      down[2] = true
      fire("PLAYER_TOTEM_UPDATE")
      runTimers()
      check(earth.st.on and earth.st.secret, "down again, still hidden")
      fight, hide = false, false
      fire("PLAYER_REGEN_ENABLED")
      runTimers()
      check(earth.st.on and not earth.st.secret and earth.w.label.text == "Stoneclaw Totem" and earth.st.timer.start == clock,
        "after the fight the totems are read again, with the name and time the game now gives")
      -- and a slot left marked as hidden is looked at again by the tick, out of a fight
      hide = true
      fire("PLAYER_TOTEM_UPDATE")
      runTimers()
      hide, down[2] = false, nil
      T:Tick()
      runTimers()
      check(not earth.st.on and not earth.st.secret, "a slot last read while hidden is read again once the game will say")
      clock = clock + 3
      T:Tick()
      GetTotemInfo, GetTotemDuration = infoWas, durWas2
      fire("PLAYER_TOTEM_UPDATE")
      runTimers()
    end
    -- UNIT_AURA's lists as secrets: left unread, not walked
    auras.player[1] = { name = "Lightning Shield", icon = "ls", applications = 3, duration = 600, expirationTime = clock + 600, auraInstanceID = 70 }
    fire("UNIT_AURA", "player")
    check(ls.st.on, "Lightning Shield up")
    refuse = true
    local ok = pcall(fire, "UNIT_AURA", "player", { removedAuraInstanceIDs = secretList, addedAuras = secretList })
    check(ok and ls.st.on, "a secret list of what went is left unread, without an error")
    refuse = false
    issecretvalue = nil
    auras.player[1] = nil
    fire("UNIT_AURA", "player")
  end

  -- bars, layout
  local cds = by["cd:8042"]
  T:G("cds").style = "bars"
  T:Refresh()
  check(cds.w.style == "bars" and cds.w.bar and cds.w.w == T:G("cds").width, "cooldowns as bars")
  T:G("cds").style = "icons"
  T:Refresh()
  check(cds.w.style == "icons" and cds.w.w == T:G("cds").size, "and back to icons")
  T:G("cds").perRow = 2
  T:Refresh()
  local shown = {}
  for _, it in ipairs(T.items) do if it.group == "cds" and it.w and it.w.shown then shown[#shown + 1] = it.w end end
  check(#shown >= 3 and shown[3].points[1][5] < 0, "a new row after two")
  T:G("cds").perRow = 10
  -- hiding one
  T:SetOn("cd:421", false)
  check(not by["cd:421"].w.shown and T:Cfg().auras["cd:421"].on == false and by["cd:421"].listed, "a timer switched off from the Timers page stays in the list")
  T:SetOn("cd:421", true)
  T:SetOpt("cd:421", "size", 50)
  check(by["cd:421"].w.shown, "and shown again")
  -- moving frames shows them all
  T:SetUnlocked(true)
  check(cc.w.shown and fs.w.shown and fire1.w.shown and holder.mover.shown, "moving frames: every timer shows, to place")
  T:SetUnlocked(false)
  check(not fire1.w.shown and not holder.mover.shown, "and back after")
  -- 1.99.0: in a fight the game's Cooldown Manager says which tracked buffs are up
  ;(function()
    local old = { cv = C_CooldownViewer, icon = BuffIconCooldownViewer, bar = BuffBarCooldownViewer, getcvar = GetCVar, setcvar = SetCVar,
      secret = issecretvalue, name = C_Spell and C_Spell.GetSpellName, getname = GetSpellInfo, ua = C_UnitAuras, lock = InCombatLockdown, combat = UnitAffectingCombat,
      edit = EditModeManagerFrame }
    local cvar = "0"
    GetCVar = function(k) return k == "cooldownViewerEnabled" and cvar or nil end
    SetCVar = function(k, v) if k == "cooldownViewerEnabled" then cvar = v end end
    C_CooldownViewer = nil
    check(not T.ManagerOn() and T.ViewerBuffs() == nil, "no Cooldown Manager on the client: nothing from it")
    C_CooldownViewer = { GetCooldownViewerCooldownInfo = function(id) return { spellID = id == 11 and 324 or 16256 } end }
    check(not T.ManagerOn() and T.ViewerBuffs() == nil, "there but switched off: nothing")
    local hid = {}
    issecretvalue = function(v) return v == hid end
    -- a keep-up timer to try it on: whichever the test's class has first
    local it = ls
    local nameOf = it.names[1]
    local shield = new("Frame")
    shield.cooldownID, shield.isActive = 11, true
    shield.GetSpellID = function() return 324 end
    local other = new("Frame")
    other.cooldownID, other.isActive = 12, false
    other.GetSpellID = function() return 16256 end
    local empty = new("Frame") -- a pooled icon with no spell
    BuffIconCooldownViewer = new("Frame")
    BuffIconCooldownViewer.GetItemFrames = function() return { shield, other, empty } end
    BuffIconCooldownViewer.hideWhenInactive = true
    BuffBarCooldownViewer = nil
    -- names for the two spells: the timer's own, and another
    local realName = T.SpellNameForTest
    local names = { [324] = nameOf, [16256] = "Some Proc" }
    local oldGet = C_Spell and C_Spell.GetSpellName
    if C_Spell then C_Spell.GetSpellName = function(id) return names[id] or (oldGet and oldGet(id)) end end
    T:TurnManagerOn()
    check(cvar == "1" and T.ManagerOn(), "the button switches the game's manager on")
    local v = T.ViewerBuffs()
    check(v and v[nameOf] == true and v["Some Proc"] == false, "its tracked buffs by name: up, and not")
    shield.isActive = hid
    shield.shown = true
    v = T.ViewerBuffs()
    check(v and v[nameOf] == true, "an 'active' the game keeps secret: an icon that hides while down is up while it shows")
    shield.shown = false
    check(T.ViewerBuffs()[nameOf] == false, "and down while it doesn't")
    BuffIconCooldownViewer.hideWhenInactive = false
    v = T.ViewerBuffs()
    check(v and v[nameOf] == nil, "icons that never hide say nothing when 'active' is secret")
    BuffIconCooldownViewer.hideWhenInactive = true
    BuffIconCooldownViewer.shown = false
    check(T.ViewerBuffs() == nil, "the manager's frame hidden (its own setting): nothing to go on")
    BuffIconCooldownViewer.shown = true

    -- in a fight, with every aura read refused
    local realUA = C_UnitAuras
    C_UnitAuras = setmetatable({}, { __index = function() return function() error("Auras cannot be accessed when secret while tainted by 'VoltUI'") end end })
    UnitAffectingCombat = function() return true end
    InCombatLockdown = function() return true end
    it.st.on, it.st.seen, it.st.aid = true, true, nil
    shield.isActive, shield.shown = true, true
    T:UpdateAuras("player")
    check(it.st.on and not it.st.unsure, "in a fight, auras refused: the manager says it's up")
    shield.isActive = false
    T:UpdateAuras("player")
    check(not it.st.on and not it.st.unsure, "its last charge gone: down straight away, not at the end of the fight")
    shield.isActive = true
    T:Tick()
    check(it.st.on, "put back on: the half-second look catches it")
    shield.isActive, shield.shown = hid, false
    T:Tick()
    check(not it.st.on, "and with 'active' secret, the icon going says so")

    -- 1.101.5: set to Not tracked (no icon for it on the manager): silent in a fight. Seen by the
    -- user: Lightning Shield, not tracked, kept flashing as missing in fights while it was up.
    BuffIconCooldownViewer.GetItemFrames = function() return { other, empty } end
    local _, read = T.ViewerBuffs()
    check(read == true, "the manager on and walked, the buff not among its icons")
    it.st.on, it.st.aid, it.st.castAt = true, 77, nil
    T:UpdateAuras("player")
    check(it.st.on and it.st.untracked and not T:Warns(it), "not tracked, up before the fight: still counted up, no guess that it's gone")
    it.st.on, it.st.aid = false, nil
    T:UpdateAuras("player")
    check(not it.st.on and it.st.untracked and not T:Warns(it) and not T:Visible(it), "not tracked, down before the fight: no warning and not shown in the fight")
    BuffIconCooldownViewer.GetItemFrames = function() return { shield, other, empty } end
    shield.isActive, shield.shown = false, false
    T:UpdateAuras("player")
    check(not it.st.on and not it.st.untracked and T:Warns(it), "tracked again and down: it warns as before")

    -- out of sight while it's read
    check(T:Cfg().hideManager == true and BuffIconCooldownViewer.alpha == 0, "the game's manager is see-through while VoltUI reads it")
    EditModeManagerFrame = new("Frame")
    EditModeManagerFrame.shown = true
    T:HideManager()
    check(BuffIconCooldownViewer.alpha == 1, "back while the game's Edit Mode is open, to place it")
    EditModeManagerFrame.shown = false
    T:HideManager()
    check(BuffIconCooldownViewer.alpha == 0, "and away again")
    T:Cfg().hideManager = false
    T:HideManager()
    check(BuffIconCooldownViewer.alpha == 1, "the setting off: left as the game shows it")
    T:Cfg().hideManager = true

    C_UnitAuras = realUA
    if C_Spell then C_Spell.GetSpellName = oldGet end
    C_CooldownViewer, BuffIconCooldownViewer, BuffBarCooldownViewer, GetCVar, SetCVar = old.cv, old.icon, old.bar, old.getcvar, old.setcvar
    issecretvalue, InCombatLockdown, UnitAffectingCombat, EditModeManagerFrame = old.secret, old.lock, old.combat, old.edit
    T.managerHidden = nil
    it.st.on, it.st.unsure = false, nil
    T:UpdateAuras("player")
  end)()
  -- the page, the slash command
  local page
  for _, p in ipairs(ns.Pages.list) do if p.key == "timers" then page = p end end
  check(page and page.needs == "Timers" and #page.sections() == 3 and page.sections()[1].title == "Your timers", "a Timers page, your timers first")
  local opened
  local oldOpen = ns.FUI.OpenSettings
  ns.FUI.OpenSettings = function(_, key) opened = key end
  SlashCmdList.VOLTUI("timers")
  check(opened == "timers", "/volt timers opens it")
  ns.FUI.OpenSettings = oldOpen
  SlashCmdList.VOLTUI("timers test")
  check(ls.w.pulse == clock, "/volt timers test pulses them")
  VoltUIDB.timerCdsLeft, VoltUIDB.timerCdsTop, VoltUIDB.timerCdsPoint = 10, -20, "TOPLEFT"
  local layout = ns.Share:Collect("layout")
  check(layout.db.timerCdsLeft == 10, "where they sit goes with the layout")
  SlashCmdList.VOLTUI("timers reset")
  check(VoltUIDB.timerCdsLeft == nil and T:Cfg().auras["cd:421"] and T:Cfg().auras["cd:421"].size == nil, "/volt timers reset")

  for k, v in pairs(saved) do _G[k] = v[1] end
  T.items = {}
  T.AUTO_LIST = false
end)()

print("== Fonts")
;(function()
  local S, E, FUI = ns.Style, ns.EditMode, ns.FUI
  local have = {}
  for _, f in ipairs(S.FONTS) do have[f.key] = f.path end
  check(have.inter and have.inter:find("Inter%-SemiBold") and have.ptsansnarrow:find("PTSansNarrow%-Bold")
    and have.lato:find("Lato%-SemiBold") and have.titillium:find("TitilliumWeb%-SemiBold") and have.teko:find("Teko%-SemiBold"),
    "the five new fonts are in the list")
  local files = { bigshoulders = "BigShouldersText%-Bold", baloo = "Baloo2%-SemiBold", orbitron = "Orbitron%-SemiBold",
    russo = "RussoOne%-Regular", oxanium = "Oxanium%-SemiBold", electrolize = "Electrolize%-Regular",
    baijamjuree = "BaiJamjuree%-SemiBold", jetbrainsmono = "JetBrainsMono%-SemiBold", spacemono = "SpaceMono%-Bold",
    bebas = "BebasNeue%-Regular" }
  local all = true
  for key, file in pairs(files) do
    if not (have[key] and have[key]:find(file)) then all = false print("    missing font " .. key) end
  end
  check(all and #S.FONTS >= 23, "and the ten from 1.71.0")
  -- every bundled font's file and licence is in Fonts/
  local okFiles = true
  for _, f in ipairs(S.FONTS) do
    local name = f.path:match("VoltUI\\Fonts\\(.+)$")
    if name then
      local h = io.open(DIR .. "/Fonts/" .. name, "rb")
      if h then h:close() else okFiles = false print("    no file " .. name) end
    end
  end
  check(okFiles, "each bundled font's file is there")

  -- The settings windows' fonts (1.72.0): fixed, Inter for words and JetBrains Mono for data
  check(VoltUIDB.uiFont == nil, "no settings window font is saved")
  E:Open("general")
  local anyFontRow = false
  for _, r in ipairs(E.rows) do if r.def.key == "uiFont" then anyFontRow = true end end
  check(not anyFontRow, "and there's no choice of it")
  local monoAt = function(fs) return fs and fs.font and fs.font[1]:find("JetBrainsMono%-") and true or false end
  -- (1.81.0) words are JetBrains Mono too, a size down; titles are Space Mono Bold; no Inter
  local interAt = function(fs) return fs and fs.font and fs.font[1]:find("JetBrainsMono%-") and true or false end
  local titleAt = function(fs) return fs and fs.font and fs.font[1]:find("SpaceMono%-Bold") and true or false end
  local labels, stepVal, boxVal = true, nil, nil
  for _, r in ipairs(E.rows) do
    if r.label and r.label:GetText() ~= "" and not interAt(r.label) then labels = false end
    if r.def.stepper and not r.def.fontFace then stepVal = stepVal or r.value end
    if r.def.kind == "step" then boxVal = boxVal or r.value end
  end
  check(labels, "row labels are in JetBrains Mono")
  local anyLabel
  for _, r in ipairs(E.rows) do if r.label and r.label:GetText() ~= "" and not r.def.kind ~= "note" then anyLabel = anyLabel or r.label end end
  check(anyLabel and anyLabel.font[2] == 11 and S.UIWordSize(12) == 11 and S.UIWordSize(13) == 12 and S.UIWordSize(11) == 11
    and S.UIWordSize(14) == 14 and S.UIWordSize(12, nil, "mono") == 12, "words asked for at 12 are set at 11 (mono runs wide); data and titles keep their size")
  check(monoAt(stepVal), "a cycle's value is in JetBrains Mono")
  check(monoAt(boxVal), "and a slider's number box")
  local head = E.sideHeads and E.sideHeads[1]
  check(monoAt(head) and head.font[1]:find("Medium") and head.text == head.text:upper(), "the sidebar's headings are mono capitals")
  check(interAt(E.side[1].text) and monoAt(E.side[1].note), "its page names and their counts are JetBrains Mono")
  check(titleAt(E.title) and interAt(E.desc), "the page title is Space Mono, its description JetBrains Mono")
  local made = S.UIText(UIParent, nil, "LEFT", nil, 14)
  check(made.font[1]:find("SpaceMono%-Bold"), "a title (14 and up) is Space Mono Bold unless told")
  local code = S.UIText(UIParent, nil, "LEFT", nil, 14, nil, "mono")
  check(code.font[1]:find("JetBrainsMono%-SemiBold"), "told mono, it's JetBrains Mono")
  S.FixFont(code, 12)
  check(code.font[1]:find("JetBrainsMono%-Regular"), "and stays mono when its size changes")
  S.FixFont(code, 12, nil, nil, "inter")
  check(code.font[1]:find("JetBrainsMono%-Regular") and code.font[2] == 11, "told it's words again, it's set as words are: a size down")
  local anyInter = false
  for _, fs in ipairs(allFontStrings) do
    if fs.font and fs.font[1]:find("Inter%-") and (inside(fs, VoltUISettings) or inside(fs, VoltUIMenu) or inside(fs, VoltUIMinimapButton)) then anyInter = true end
  end
  check(not anyInter, "nothing in the settings window, the minimap icon or its menu is in Inter any more")
  check(#S.fontWarm == 6, "all six settings font files are loaded up front")
  check(not VoltUIPlayerFrame.name.font[1]:find("JetBrains"), "frames keep the frame font")
  local seen = {}
  for _, r in ipairs(S.FONT_ROLES) do
    check(not seen[r.key], "one entry per text: " .. r.key)
    seen[r.key] = true
  end
  local fontWas, rolesWas = VoltUIDB.font, VoltUIDB.fontRoles
  VoltUIDB.font, VoltUIDB.fontRoles = "barlow", nil
  check(S.Font(nil, "frames.health").key == "barlow" and S.RoleFont("frames.health") == nil, "a text with no font of its own uses the overall one")
  S.SetRoleFont("frames.health", "teko")
  S.SetRoleFont("frames.name", "inter")
  S.SetRoleFont("bars.cooldown", "titillium")
  S.SetRoleFont("cast.time", "ptsansnarrow")
  S.SetRoleFont("tooltips", "lato")
  check(VoltUIDB.fontRoles["frames.health"] == "teko", "kept in fontRoles")
  S.ApplyFonts()
  FUI:Refresh()
  local P = VoltUIPlayerFrame
  check(P.name.font[1]:find("Inter%-SemiBold"), "your name in Inter")
  check(P.hpText.font[1]:find("Teko") and P.hpPct.font[1]:find("Teko"), "your health numbers in Teko")
  check(P.pwText.font[1]:find("Barlow"), "the rest keep the overall font")
  check(VoltUICooldownFontbar1.font[1]:find("TitilliumWeb"), "action bar cooldown numbers have their own")
  check(VoltUICastbar.time.font[1]:find("PTSansNarrow") and VoltUICastbar.label.font[1]:find("Barlow"), "the cast time apart from the spell name")
  check(GameTooltipText.font[1]:find("Lato") and GameTooltipHeaderText.font[1]:find("Lato"), "tooltips")
  -- bags: category headings and stack counts (1.73.0)
  S.SetRoleFont("bags.header", "bebas")
  S.SetRoleFont("bags.count", "jetbrainsmono")
  S.ApplyFonts()
  FUI:Refresh()
  local bwin = ns.Bags.windows.bags
  local bhead, bcount = bwin.headers[1], nil
  for _, list in pairs(bwin.buttons) do
    for _, b in pairs(list) do if b.fuiCount then bcount = b.fuiCount end end
  end
  check(bhead and bhead.font[1]:find("BebasNeue"), "bag category headings have their own font")
  check(bcount and bcount.font[1]:find("JetBrainsMono"), "and bag stack counts")
  check(bwin.frame.free.font[1]:find("JetBrainsMono") and bwin.frame.title.font[1]:find("SpaceMono"), "the bag title bar keeps VoltUI's own fonts")
  -- 1.82.0: the bag window in the settings' look, light headings by default
  do
    local Bg, f = ns.Bags, bwin.frame
    local gold = S.UI.accent
    local function isGold(t) local c = tint(t); return c and math.abs(c[1] - gold[1]) < 0.01 and math.abs(c[2] - gold[2]) < 0.01 and math.abs(c[3] - gold[3]) < 0.01 end
    check(tint(f.block)[1] < 0.3 and f.block.kLine and isGold(f.block.kLine) and f.title.color[1] == 1, "the bag title is gold on a dark gold block with a gold line (1.87.0)")
    do -- 1.88.0: how thick the rarity outline is
      local e = {}
      for i = 1, 4 do e[i] = { SetHeight = function(t, h) t.h = h end, SetWidth = function(t, w) t.w = w end } end
      local slot = { fuiGlow = { edges = e } }
      ns.Bags.Stroke(slot, 3)
      check(e[1].h == 3 and e[2].h == 3 and e[3].w == 3 and e[4].w == 3 and slot.fuiStroke == 3, "a slot's rarity outline takes the width asked for")
      ns.Bags.Stroke(slot, 9)
      check(e[1].h == 4 and e[4].w == 4, "no thicker than 4")
      local row
      for _, d in ipairs(ns.Bags.SETTINGS) do if d.key == "bagEdge" then row = d end end
      check(row and row.group == "Look" and row.min == 1 and row.max == 4 and (ns.db.bagEdge or VoltUIDB.bagEdge) == 1, "Rarity outline is a bag setting, 1 to 4, 1 by default")
    end
    check(f.hatch and f.infoMark and f.pane, "with a hatched strip, a free-slot marker and a dark pane")
    check(VoltUIDB.bagHeads == "line" and Bg.HeadStyle() == "line", "headings are the light kind by default")
    check(bhead.kMark and isGold(bhead.kMark) and bhead.kMark.shown ~= false, "a heading has its gold marker")
    check(not bhead.kBand.shown and not bhead.kCap.shown, "and no band")
    S.SetRoleFont("bags.header", nil)
    S.ApplyFonts(); FUI:Refresh()
    check(bhead.font[1]:find("SpaceMono"), "with no font of its own a heading is in Space Mono")
    VoltUIDB.bagHeads = "band"
    FUI:Refresh()
    check(bhead.kBand.shown and bhead.kCap.shown and isGold(bhead.kCap), "the band style gives each heading a band with a gold end")
    VoltUIDB.bagHeads = "nonsense"
    check(Bg.HeadStyle() == "line", "an unknown style reads as light")
    VoltUIDB.bagHeads = "line"
    FUI:Refresh()
    check(not bhead.kBand.shown, "and back")
    local nHead = 0
    for _, h in ipairs(bwin.headers) do if h.shown then nHead = nHead + 1 end end
    VoltUIDB.categories = false
    FUI:Refresh()
    local stray = 0
    for _, h in ipairs(bwin.headers) do
      if not h.shown then for _, p in ipairs(h.kParts) do if p.shown then stray = stray + 1 end end end
    end
    check(nHead > 0 and stray == 0, "a hidden heading takes its graphics with it")
    VoltUIDB.categories = true
    FUI:Refresh()
    local any
    for _, list in pairs(bwin.buttons) do for _, b in pairs(list) do any = any or b end end
    check(any and any.fuiEdge, "each slot has a border")
    local inShare = false
    for _, part in ipairs(ns.Share.PARTS) do for _, k in ipairs(type(part.keys) == "table" and part.keys or {}) do if k == "bagHeads" then inShare = true end end end
    check(inShare, "the heading style travels with shared bag settings")
    S.SetRoleFont("bags.header", "bebas")
    S.ApplyFonts(); FUI:Refresh()
  end
  ns.Bags:Refresh()
  check(bhead.font[1]:find("BebasNeue") and bcount.font[1]:find("JetBrainsMono"), "and keep them when the bags refresh")
  S.SetRoleFont("bags.header", nil)
  S.SetRoleFont("bags.count", nil)
  -- the overall font changes; the texts with their own keep them
  VoltUIDB.font = "rajdhani"
  S.ApplyFonts()
  FUI:Refresh()
  check(P.pwText.font[1]:find("Rajdhani") and P.hpText.font[1]:find("Teko") and P.name.font[1]:find("Inter"), "changing the overall font leaves the picked ones")
  -- a font that's gone (an LSM font from an add-on since removed) falls back to the overall one
  VoltUIDB.fontRoles["frames.health"] = "lsm:Gone"
  S.ApplyFonts()
  check(P.hpText.font[1]:find("Rajdhani"), "a missing font falls back to the overall one")

  -- The Fonts page
  E:Open("fonts")
  check(E.tab == "fonts", "the Fonts page opens")
  local row, overall
  for _, r in ipairs(E.rows) do
    if r.def.key == "frames.name" then row = r end
    if r.def.key == "font" then overall = r end
  end
  check(row and overall, "it has the overall font and a row per text")
  check(row.value.text == "Inter" and row.value.font[1]:find("Inter%-SemiBold") and row.value.fontPreview, "each choice is shown in its own font")
  check(overall.value.text == "Rajdhani" and overall.value.font[1]:find("Rajdhani"), "the overall font too")
  local cards = ns.Pages.byKey.fonts.sections()
  check(#cards == 10 and cards[2].title == "Unit frames" and cards[#cards].title == "Tooltips", "a card per part: " .. #cards)
  local list = row.def.list()
  check(list[1].key == "default" and list[1].name == "Overall: Rajdhani" and #list == #S.FONTS + 1, "the first choice is the overall font, by name")
  row.io.set(row.def, "default")
  row.io.changed(row.def)
  check(VoltUIDB.fontRoles["frames.name"] == nil and P.name.font[1]:find("Rajdhani"), "picking Overall puts it back")
  check(row.value.text == "Overall: Rajdhani", "and says so")
  row.io.set(row.def, "lato")
  row.io.changed(row.def)
  check(P.name.font[1]:find("Lato") and row.io.isChanged(row.def), "a pick shows as changed")
  row:ResetOne()
  check(VoltUIDB.fontRoles["frames.name"] == nil and P.name.font[1]:find("Rajdhani"), "right-click puts one back")
  ns.Pages.byKey.fonts.reset()
  check(VoltUIDB.fontRoles == nil and P.hpText.font[1]:find("Rajdhani") and VoltUIDB.font == "rajdhani", "Reset clears every text's own font, not the overall one")
  -- shared with the look
  S.SetRoleFont("frames.health", "teko")
  check(ns.Share:Collect("look").fontRoles["frames.health"] == "teko", "Share's look carries them")
  S.SetRoleFont("frames.health", nil)
  check(VoltUIDB.fontRoles == nil, "the last one gone leaves nothing saved")

  VoltUIDB.font, VoltUIDB.fontRoles = fontWas, rolesWas
  S.ApplyFonts()
  FUI:Refresh()
end)()

print("\n== 1.79.1's fixes")
;(function()
  local FUI = ns.FUI
  -- slash values stay inside what the settings window allows
  local was ={ VoltUIDB.bagCols, VoltUIDB.bagScale, VoltUIDB.gapX, VoltUIDB.gapY }
  SlashCmdList.VOLTUI("bags cols 0")
  check(VoltUIDB.bagCols == 4, "/volt bags cols 0 is held at the fewest columns: " .. tostring(VoltUIDB.bagCols))
  SlashCmdList.VOLTUI("bags scale -3")
  check(VoltUIDB.bagScale == 0.5, "and a scale below the smallest at the smallest")
  SlashCmdList.VOLTUI("bags gap 999")
  check(VoltUIDB.gapX == 20 and VoltUIDB.gapY == 20, "and both gaps at the widest")
  VoltUIDB.bagCols, VoltUIDB.bagScale, VoltUIDB.gapX, VoltUIDB.gapY = was[1], was[2], was[3], was[4]

  -- the leftover-quest-items switch travels with the bags' settings
  local got = ns.Share:Collect("bags")
  check(got and got.questLeft ~= nil, "Share's bags part carries the leftover quest items switch")

  -- switching the swing timers off asks for the reload its tip says it needs
  local before = FUI.reloadNeeded
  FUI.reloadNeeded = nil
  local pending = FUI:ReloadPending()
  local swing = VoltUIDB.castSwing
  VoltUIDB.castSwing = false
  check(swing ~= false and not pending and FUI:ReloadPending(), "swing timers switched off: a reload is pending")
  VoltUIDB.castSwing = swing
  check(FUI:ReloadPending() == pending, "and not once it's back on")
  FUI.reloadNeeded = before

  -- a fight ends moving frames whichever parts are on
  inCombat = false
  FUI:SetUnlocked(true)
  local n = #chat
  fire("PLAYER_REGEN_DISABLED")
  local said = 0
  for i = n + 1, #chat do if chat[i]:find("moving frames stopped") then said = said + 1 end end
  check(not FUI.unlocked and said == 1, "combat ends moving frames, and says so once: " .. said)
  fire("PLAYER_REGEN_ENABLED")

  -- an imported setting of the wrong kind is treated as missing
  local Sh = ns.Share
  local alphaWas, glowWas = VoltUIDB.alpha, VoltUIDB.glow
  local text = Sh:Make({ look = true })
  local data = text and Sh:Read(text)
  if data and data.parts and data.parts.look then
    data.parts.look.alpha = "not a number"
    data.parts.look.glow = 0.3
    Sh:Apply(data, { look = true })
    check(type(VoltUIDB.alpha) == "number" and VoltUIDB.glow == 0.3, "an import's setting of the wrong kind falls back to the default; the rest come in")
    -- (1.80.0) the preview: how many settings in each part differ from yours, before anything changes
    local mine = Sh:Read(Sh:Make({ look = true, bags = true }))
    check(Sh:Differs(mine, "look") == 0 and Sh:Differs(mine, "bags") == 0 and Sh:Differs(mine, "bars") == nil,
      "your own string differs in nothing; a part it doesn't hold has no count")
    mine.parts.bags.bagCols = (VoltUIDB.bagCols or 10) + 2
    mine.parts.bags.bagSize = (VoltUIDB.bagSize or 36) + 4
    mine.parts.look.fontRoles = { ["frames.health"] = "teko", ["bags.count"] = "lato" }
    check(Sh:Differs(mine, "bags") == 2, "two changed settings count as two: " .. tostring(Sh:Differs(mine, "bags")))
    check(Sh:Differs(mine, "look") == 2, "and each value inside a table of settings counts: " .. tostring(Sh:Differs(mine, "look")))
    local words = Sh:Preview(mine)
    check(words:find("Bags: 2", 1, true) and words:find("differ", 1, true), "the preview names the part and its count: " .. words)
    local colsWas = VoltUIDB.bagCols
    check(VoltUIDB.bagCols == colsWas and VoltUIDB.fontRoles == nil, "and looking changes nothing")
    local same = Sh:Preview(Sh:Read(Sh:Make({ bags = true })))
    check(same:find("The same as yours: Bags", 1, true), "a part that matches says so: " .. same)
  else
    check(false, "couldn't make an export to test importing with")
  end
  VoltUIDB.alpha, VoltUIDB.glow = alphaWas, glowWas
  FUI:Refresh()
end)()

-- 1.95.0: unit frame extras (FrameExtras.lua): mana while shapeshifted, pet experience,
-- the regen tick and the extra texts
;(function()
  local U, X, E = ns.UnitFrames, ns.FrameExtras, ns.EditMode
  local P, Pet = VoltUIPlayerFrame, VoltUIPetFrame
  local c, pc = U:Cfg("player"), U:Cfg("pet")
  local old = {
    UnitPower = UnitPower, UnitPowerMax = UnitPowerMax, UnitPowerType = UnitPowerType, UnitClass = UnitClass,
    UnitLevel = UnitLevel, UnitHealth = UnitHealth, UnitHealthMax = UnitHealthMax, GetTime = GetTime,
    GetPetExperience = GetPetExperience, HasPetUI = HasPetUI, C_Item = C_Item, C_PetInfo = C_PetInfo,
    GetComboPoints = GetComboPoints, GetInventoryItemID = GetInventoryItemID, GetInventoryItemCount = GetInventoryItemCount,
    MenuUtil = MenuUtil, InCombatLockdown = InCombatLockdown,
  }
  local keep = { border = c.border, power = c.power, portrait = c.portrait, unlocked = U.unlocked, rowPips = c.rowPips,
    rowName = c.rowName, rowHp = c.rowHp, rowPw = c.rowPw }
  U.unlocked = nil
  InCombatLockdown = function() return false end
  local secretWas = issecretvalue
  issecretvalue = function(v) return getmetatable(v) == SecretMeta end
  c.border, c.power, c.portrait = "hairline", true, "off"
  c.rowName, c.rowHp, c.rowPw, c.rowPips = 1, 2, 3, 4

  check(X and c.altMana == true and c.tick == false and pc.petXP == true and c.extra1 == "off" and c.extra2 == "off",
    "extras: the mana bar and pet experience start on, the tick and the texts off")

  -- Mana while shapeshifted
  local class, token, mana, manaMost, energy = "DRUID", "MANA", 300, 1000, 40
  UnitClass = function() return class, class end
  UnitPowerType = function() if token == "MANA" then return 0, "MANA" end; return 3, token end
  UnitPower = function(_, k) if k == 0 then return mana end; if k == 14 then return 2 end; return energy end
  UnitPowerMax = function(_, k) if k == 0 then return manaMost end; if k == 14 then return 5 end; return 100 end
  U:Layout(P)
  fire("UNIT_DISPLAYPOWER", "player")
  check(not X.alt or X.alt.shown == false, "in caster form there is no second bar")
  token = "ENERGY"
  fire("UNIT_DISPLAYPOWER", "player")
  local alt = X.alt
  check(alt and alt.shown and alt.value == 300 and alt.maxv == 1000, "in a form: a mana bar, filled by your mana")
  check(alt.points[1][1] == "TOPLEFT" and alt.points[1][2] == P and alt.points[1][3] == "BOTTOMLEFT" and alt.points[1][5] == -1 and alt.h == 5,
    "it hangs under the frame, which keeps its size")
  check(U.below == 6, "what's under the frame knows to make room")
  if U.pips then
    P.kPipsOut = "bottom"
    X:Reflow()
    check(U.pips.points[1][5] == -2 - 6, "combo points outside the frame move down under it")
  end
  mana = 450
  fire("UNIT_POWER_UPDATE", "player")
  check(alt.value == 450, "and follows your mana")
  c.border = "double"; U:Layout(P)
  check(alt.points[1][5] == -1 - 3, "clear of a double border")
  c.border = "hairline"; U:Layout(P)
  manaMost = Secret()
  fire("UNIT_MAXPOWER", "player")
  check(alt.shown and alt.maxv == manaMost, "a secret mana pool still shows for a Druid, handed straight to the bar")
  class = "WARRIOR"
  fire("UNIT_MAXPOWER", "player")
  check(alt.shown == false, "but not for a class that may have none")
  class, manaMost = "DRUID", 1000
  token = "MANA"
  fire("UNIT_DISPLAYPOWER", "player")
  check(alt.shown == false and U.below == 0, "back in caster form it goes")
  if U.pips then check(U.pips.points[1][5] == -2, "and the combo points move back") end
  token, manaMost = "RAGE", 0
  fire("UNIT_DISPLAYPOWER", "player")
  check(alt.shown == false, "rage with no mana at all (a Warrior): no bar")
  manaMost, token = 1000, "ENERGY"
  c.altMana = false; U:Layout(P)
  check(alt.shown == false, "switched off: no bar in a form")
  c.altMana = true; U:Layout(P)
  check(alt.shown, "and on again")
  token = "MANA"; U:Layout(P)

  -- Pet experience
  local xp, xpMost, petLevel, hunterPet = 250, 1000, 5, true
  GetPetExperience = function() return xp, xpMost end
  HasPetUI = function() return true, hunterPet end
  UnitLevel = function(u) return u == "pet" and petLevel or 10 end
  fire("UNIT_PET_EXPERIENCE", "pet")
  local bar = X.xp
  check(bar and bar.shown and bar.value == 250 and bar.maxv == 1000, "a hunter's pet below your level: an experience line")
  check(bar.points[1][2] == Pet and bar.points[1][3] == "BOTTOMLEFT" and bar.points[1][5] == -1 and bar.h == 3, "3 high, under the pet frame")
  local lines = {}
  local addLine = GameTooltip.AddLine
  GameTooltip.AddLine = function(_, text) lines[#lines + 1] = text end
  Pet.scripts.OnEnter(Pet)
  GameTooltip.AddLine = addLine
  check(lines[#lines] == "Experience 250 / 1000 (25%)", "the numbers on hover: " .. tostring(lines[#lines]))
  petLevel = 10
  fire("UNIT_LEVEL", "pet")
  check(bar.shown == false, "caught up with you: gone")
  petLevel, hunterPet = 5, false
  fire("UNIT_PET", "player")
  check(bar.shown == false, "a pet that isn't a hunter's has none")
  hunterPet = true
  fire("UNIT_PET", "player")
  check(bar.shown, "back for a hunter's pet")
  U.unlocked = true; X:UpdateXP()
  check(bar.shown == false, "hidden while the frames are being moved (the pet frame shows you then)")
  U.unlocked = nil
  pc.petXP = false; U:Layout(Pet)
  check(bar.shown == false, "switched off")
  pc.petXP = true; U:Layout(Pet)
  check(bar.shown, "and on")

  -- The regen tick
  local clock = 100
  GetTime = function() return clock end
  token, energy = "ENERGY", 40
  c.tick = true; U:Layout(P)
  local tickNow = X.driver and X.driver.scripts.OnUpdate
  check(X.spark and tickNow and X.ticking, "the tick switched on: a spark on the power bar")
  check(X.pwW == c.width - 2, "the bar's width comes from the settings: " .. tostring(X.pwW))
  energy = 60
  fire("UNIT_POWER_UPDATE", "player")
  clock = 101
  tickNow(X.driver, 0.1)
  check(X.spark.shown and math.abs(X.frac - 0.5) < 0.001 and not X.ruled, "a second after an energy gain: halfway to the next tick")
  check(X.spark.points[1][2] == P.pw and math.abs(X.spark.points[1][4] - 0.5 * (X.pwW - 2)) < 0.001, "the spark halfway along the bar")
  clock = 102.5
  tickNow(X.driver, 0.1)
  check(math.abs(X.frac - 0.25) < 0.001, "it keeps time by itself between gains")
  energy = 100
  fire("UNIT_POWER_UPDATE", "player")
  clock = 103
  tickNow(X.driver, 0.1)
  check(X.spark.shown, "energy: still running at full, to time an opener")
  token, mana = "MANA", 300
  fire("UNIT_DISPLAYPOWER", "player")
  mana = 200
  fire("UNIT_POWER_UPDATE", "player")
  clock = 105
  tickNow(X.driver, 0.1)
  check(X.ruled and math.abs(X.frac - 0.4) < 0.001 and X.rule.shown and math.abs(X.rule.w - 0.4 * X.pwW) < 0.001,
    "2 seconds after spending mana: the 5 second fill, 40 percent along")
  clock = 109.5
  tickNow(X.driver, 0.1)
  check(X.rule.shown == false and X.spark.shown and not X.ruled, "after 5 seconds: the 2 second tick again")
  mana = 1000
  fire("UNIT_POWER_UPDATE", "player")
  tickNow(X.driver, 0.1)
  check(X.spark.shown == false, "full mana: nothing to wait for")
  mana = Secret()
  fire("UNIT_POWER_UPDATE", "player")
  clock = 120
  fire("UNIT_SPELLCAST_SUCCEEDED", "player")
  clock = 121
  tickNow(X.driver, 0.1)
  check(X.ruled and math.abs(X.frac - 0.2) < 0.001, "mana that can't be read: a cast counts as a spend")
  token = "RAGE"
  fire("UNIT_DISPLAYPOWER", "player")
  tickNow(X.driver, 0.1)
  check(X.spark.shown == false and X.rule.shown == false, "rage has no tick")
  c.tick = false; U:Layout(P)
  check(X.driver.scripts.OnUpdate == nil and X.spark.shown == false and not X.ticking, "switched off: no spark, nothing running")
  token, mana = "MANA", 300

  -- The extra texts
  local function has(list, key) for _, it in ipairs(list) do if it.key == key then return true end end end
  class = "WARLOCK"
  local list = X.SourceList()
  check(list[1].key == "off" and has(list, "item:6265") and has(list, "health") and has(list, "name") and has(list, "mana")
    and not has(list, "ammo") and not has(list, "combo"), "a Warlock's list: shards and the plain ones, no ammo or combo points")
  class = "HUNTER"
  list = X.SourceList()
  check(has(list, "ammo") and not has(list, "happiness") and not has(list, "petxp") and not has(list, "item:6265"),
    "a Hunter's: ammo, no shards, and the pet's own are on the pet frame's list")
  local plist = X.SourceList("pet")
  check(plist[1].key == "off" and has(plist, "happiness") and has(plist, "petxp") and has(plist, "health") and has(plist, "name")
    and not has(plist, "ammo") and not has(plist, "mana") and not has(plist, "xp"), "the pet frame's list: its mood, experience and the plain ones")
  class = "WARLOCK"
  check(not has(X.SourceList("pet"), "happiness") and has(X.SourceList("pet"), "health"), "a Warlock's pet: no mood, still the plain ones")
  class = "WARRIOR"
  check(not has(X.SourceList(), "mana") and has(X.SourceList(), "ammo"), "a Warrior's: no mana")
  class = "WARLOCK"
  local shards = 7
  C_Item = { GetItemCount = function(id) return id == 6265 and shards or 0 end }
  c.extra1, c.extra1At = "item:6265", "bl"; U:Layout(P)
  local fs = P.extras and P.extras[1]
  check(fs and fs.shown and fs.text == "|cffa8adb8Soul Shards|r |cffffffff7|r", "shards counted from your bags: " .. tostring(fs and fs.text))
  check(fs.points[1][1] == "TOPLEFT" and fs.points[1][2] == P and fs.points[1][3] == "BOTTOMLEFT" and fs.points[1][4] == 2 and fs.points[1][5] <= -3,
    "below the frame, at the left")
  shards = 0
  fire("BAG_UPDATE_DELAYED")
  check(fs.text == "|cffa8adb8Soul Shards|r |cffe5645f0|r", "none left: red, as the bags change")
  shards = 7
  c.extra1Label = false; U:Layout(P)
  check(fs.text == "|cffffffff7|r", "without its name: just the number")
  c.extra1Label = true
  c.extra1At = "tr"; U:Layout(P)
  check(fs.points[1][1] == "BOTTOMRIGHT" and fs.points[1][3] == "TOPRIGHT" and fs.points[1][4] == -2 and fs.points[1][5] >= 3 and fs.justify ~= "LEFT",
    "above the frame, at the right")
  c.extra1X, c.extra1Y = 10, 4; U:Layout(P)
  local y1 = fs.points[1][5]
  check(fs.points[1][4] == 8, "nudged across")
  c.extra1X, c.extra1Y = 0, 0; U:Layout(P)
  check(fs.points[1][5] == y1 - 4, "and up")
  UnitHealth, UnitHealthMax = function() return 80 end, function() return 100 end
  c.extra2, c.extra2At = "health", "tr"; U:Layout(P)
  local fs2 = P.extras[2]
  check(fs2 and fs2.shown and fs2.text == "|cffa8adb8Health|r 80 / 100", "a second text, with your health: " .. tostring(fs2 and fs2.text))
  check(fs2.points[1][5] == fs.points[1][5] + 11 + 2, "two on one corner stack outward")
  UnitHealth = function() return 55 end
  fire("UNIT_HEALTH", "player")
  check(fs2.text == "|cffa8adb8Health|r 55 / 100", "and it follows")
  fire("UNIT_HEALTH", "target")
  c.extra2 = "healthPct"; U:Layout(P)
  check(fs2.text == "|cffa8adb8Health|r 55%", "health as a percent: " .. tostring(fs2.text))
  c.extra2 = "mana"; U:Layout(P)
  check(fs2.text == "|cffa8adb8Mana|r 300 / 1000", "mana, whatever the bar shows: " .. tostring(fs2.text))
  c.extra2 = "name"; U:Layout(P)
  check(fs2.text == UnitName("player"), "your name, with no label")
  class = "HUNTER"
  C_PetInfo = { GetPetHappiness = function() return 2, 100, -1 end }
  -- (1.95.1) the pet's mood sits on the pet frame, on to begin with
  check(U.DEFAULTS.pet.extra1 == "happiness" and U.DEFAULTS.pet.extra1Label == false and U.DEFAULTS.player.extra1 == "off",
    "the pet frame's text shows its mood from the start; yours stay off")
  U:Layout(Pet)
  local pfs = Pet.extras and Pet.extras[1]
  check(pfs and pfs.shown and pfs.text == "|cfff0b24aContent|r", "the pet's mood, on the pet frame: " .. tostring(pfs and pfs.text))
  check(Pet.extras[2] == nil and pfs.points[1][1] == "TOPLEFT" and pfs.points[1][2] == Pet and pfs.points[1][3] == "BOTTOMLEFT",
    "one text, under the pet frame's left corner")
  local petY = pfs.points[1][5]
  pc.petXP = false; U:Layout(Pet)
  check(pfs.points[1][5] == petY + 4, "it sits clear of the experience line, and moves up when that goes: " .. petY .. " -> " .. pfs.points[1][5])
  pc.petXP = true; U:Layout(Pet)
  check(pfs.points[1][5] == petY, "and back down")
  C_PetInfo = { GetPetHappiness = function() return 1, 75, -1 end }
  fire("UNIT_HAPPINESS", "pet")
  check(pfs.text == "|cffe5645fUnhappy|r", "it follows the pet: " .. tostring(pfs.text))
  pc.extra1Label = true; U:Layout(Pet)
  check(pfs.text == "|cffa8adb8Mood|r |cffe5645fUnhappy|r", "with its name in front when asked")
  pc.extra1Label = false
  hunterPet = false
  fire("UNIT_PET", "player")
  check(pfs.text == "", "no hunter's pet: nothing")
  hunterPet = true
  pc.extra1, pc.extra1At = "healthPct", "tr"; U:Layout(Pet)
  check(pfs.text == "55%" and pfs.points[1][1] == "BOTTOMRIGHT" and pfs.points[1][3] == "TOPRIGHT", "or the pet's health, above right: " .. tostring(pfs.text))
  pc.extra1 = "off"; U:Layout(Pet)
  check(pfs.shown == false, "off hides it")
  pc.extra1, pc.extra1At = "happiness", "bl"; U:Layout(Pet)
  GetInventoryItemID = function() return 2512 end
  GetInventoryItemCount = function() return 148 end
  c.extra2 = "ammo"; U:Layout(P)
  check(fs2.text == "|cffa8adb8Ammo|r |cfff0b24a148|r", "ammo, amber under 200: " .. tostring(fs2.text))
  GetInventoryItemID = function() return nil end
  fire("UNIT_INVENTORY_CHANGED", "player")
  check(fs2.text == "|cffa8adb8Ammo|r |cffe5645fnone|r", "an empty ammo slot says none")
  class = "ROGUE"
  GetComboPoints = function() return 3 end
  c.extra2 = "combo"; U:Layout(P)
  check(fs2.text == "|cffa8adb8Combo|r 3", "combo points as a number: " .. tostring(fs2.text))
  c.extra2 = "gone-in-a-later-version"; U:Layout(P)
  check(fs2.shown and fs2.text == "", "a choice VoltUI no longer knows shows nothing and breaks nothing")
  c.extra2 = "off"; U:Layout(P)
  check(fs2.shown == false and fs.shown, "off: hidden, the other stays")

  -- The settings rows
  class = "WARLOCK"
  E:Select("player")
  local function urow(page, key)
    for _, r in ipairs(E.pages[page].rows) do
      if r.def.key == key then return r end
    end
  end
  check(urow("player", "altMana") and urow("player", "tick") and urow("player", "extra1") and urow("player", "extra1At")
    and urow("player", "extra2Size") and urow("player", "extra2Label"), "rows for the class extras and both texts on the player's page")
  local items = {}
  MenuUtil = { CreateContextMenu = function(owner, fn)
    fn(owner, { CreateButton = function(_, t, f) items[#items + 1] = { t = t, fn = f } end })
  end }
  local row = urow("player", "extra1")
  check(row.pick and row.pick.scripts.OnClick, "the value of a long list can be clicked")
  row.pick.scripts.OnClick(row.pick)
  check(#items == #X.SourceList() and items[1].t == "Off", "and drops the whole list down: " .. #items)
  local marked, pickHealth
  for _, it in ipairs(items) do
    if it.t == "Soul Shards (in bags)  (now)" then marked = true end
    if it.t == "Health" then pickHealth = it end
  end
  check(marked and pickHealth, "with the one in use marked")
  pickHealth.fn()
  check(c.extra1 == "health" and fs.text == "|cffa8adb8Health|r 55 / 100", "picking one sets it and draws it: " .. tostring(fs.text))
  row:Step(1)
  check(c.extra1 ~= "health", "the arrows still step through")
  urow("player", "altMana"):Set(false)
  check(c.altMana == false, "the switch for the mana bar")
  urow("player", "altMana"):Set(true)
  E:Select("pet")
  check(urow("pet", "petXP"), "the pet's page has the experience line's switch")
  E:Select("target")
  check(not urow("target", "extra1") and not urow("target", "altMana"), "other frames have none of it")
  E:Select("player")

  -- and back
  c.extra1, c.extra1At, c.extra2, c.extra2At = "off", "bl", "off", "br"
  for k, v in pairs(old) do _G[k] = v end
  for _, k in ipairs({ "GetPetExperience", "HasPetUI", "C_PetInfo", "GetInventoryItemID", "GetInventoryItemCount", "MenuUtil" }) do
    if old[k] == nil then _G[k] = nil end
  end
  issecretvalue = secretWas
  c.border, c.power, c.portrait = keep.border, keep.power, keep.portrait
  c.rowName, c.rowHp, c.rowPw, c.rowPips = keep.rowName, keep.rowHp, keep.rowPw, keep.rowPips
  U.unlocked = keep.unlocked
  U:Layout(P)
  U:Layout(Pet)
  fire("UNIT_DISPLAYPOWER", "player")
  fire("UNIT_PET", "player")
  check((not X.alt or X.alt.shown == false) and P.extras[1].shown == false, "everything goes back")
end)()

-- 1.96.0: click a part of the frame in the settings preview and its settings come together
-- in one card above the others; the level, tags and percent get font sizes of their own
;(function()
  local U, E = ns.UnitFrames, ns.EditMode
  local c = U:Cfg("player")
  local keep = {}
  for _, k in ipairs({ "nameSize", "levelSize", "tagSize", "hpPctSize", "barSize", "level", "tags", "hpPct", "hpText", "portrait", "power", "border",
    "hpTextX", "hpTextAlign", "extra1" }) do keep[k] = c[k] end
  c.level, c.tags, c.hpPct, c.hpText, c.power, c.portrait, c.border = true, true, true, true, true, "off", "none"

  -- sizes of their own, starting where they were
  local D = U.DEFAULTS.player
  check(D.levelSize == D.nameSize - 1 and D.tagSize == D.nameSize - 2 and D.hpPctSize == D.barSize, "the new sizes default to what they used to follow")
  VoltUIDB.frameCfg.focus = { nameSize = 20, barSize = 17 }
  local fc = U:Cfg("focus")
  check(fc.levelSize == 19 and fc.tagSize == 18 and fc.hpPctSize == 17, "settings saved before keep the look they had: " .. fc.levelSize .. " " .. fc.tagSize .. " " .. fc.hpPctSize)
  VoltUIDB.frameCfg.focus = nil
  U:Layout(VoltUIFocusFrame)

  E:Open("player")
  local pf = E.previews.player
  local function rowsBy()
    local by, mirror = {}, {}
    for _, r in ipairs(E.rows) do
      if r.def.key then
        if r.mirror then mirror[r.def.key] = r else by[r.def.key] = r end
      end
    end
    return by, mirror
  end
  local by = rowsBy()
  check(by.levelSize and by.tagSize and by.hpPctSize, "the page has a font size for the level, the tags and the percent")
  by.levelSize:Set(17); by.tagSize:Set(9); by.hpPctSize:Set(19)
  check(VoltUIPlayerFrame.level.font[2] == 17 and VoltUIPlayerFrame.tag.font[2] == 9 and VoltUIPlayerFrame.hpPct.font[2] == 19
    and VoltUIPlayerFrame.hpText.font[2] == c.barSize and VoltUIPlayerFrame.name.font[2] == c.nameSize, "each changes its own text and no other")

  -- the preview's click zones
  local z = pf.zones
  check(z and z.frame and z.hp and z.pw and z.name and z.level and z.hpText and z.hpPct and z.pwText and z.panel, "the preview has a zone over each part")
  check(not z.portrait or z.portrait.shown == false, "none for a part that isn't showing (no portrait)")
  check(z.hpText.points[1][2] == pf.hpText and z.hpText.points[1][4] == -2 and z.hp.points[1][2] == pf.hp and z.frame.points[1][4] == -6,
    "each covers its part: a text with a little room, the frame with a rim to click")
  check(z.hpText.flevel > z.hp.flevel and z.hp.flevel > z.frame.flevel and z.frame.flevel > pf:GetFrameLevel(), "a text takes the click over its bar, a bar over the frame")
  check(VoltUIPlayerFrame.zones == nil, "the real frame has none: it's for targeting")
  local n0, cards0, h0 = #E.rows, nil, E:Page("player").height
  local changed0 = E:ChangedCount()
  check(U:Picked("player") == nil and not E:Page("player").pinned, "nothing picked to begin with")

  -- picking one
  E.scroll:ScrollTo(200)
  z.hpText.scripts.OnClick(z.hpText)
  local page = E:Page("player")
  local card = page.pins and page.pins.hpText
  check(U:Picked("player") == "hpText" and page.pinned == "hpText" and card and card.shown, "clicking the health numbers picks them")
  check(card.title.text == "Selected: Health numbers", "its card says what's selected: " .. tostring(card.title.text))
  check(card.top <= page.cards[1].top and card.points[1][2] == page.frame, "above the page's other cards")
  check(page.height > h0 and E.scroll.offset == 0, "the page grows by a card and scrolls to it")
  local _, mirror = rowsBy()
  check(mirror.hpText and mirror.hpFormat and mirror.barSize and mirror.hpTextAt and mirror.hpTextAlign and mirror.hpTextX and mirror.hpTextY and mirror.short,
    "the card has everything about them: show, format, font size, where, side, both nudges")
  check(mirror.barSize.label.text == "Font size" and mirror.hpText.label.text == "Show", "with plain labels: " .. tostring(mirror.barSize.label.text))
  check(not mirror.pwSize and not mirror.width, "and nothing about other parts")
  check(#E.rows == n0 + #card.rows and E:ChangedCount() == changed0, "its rows are extra copies: the count of changes doesn't count them twice")
  mirror.hpTextX:Set(-12)
  by = rowsBy()
  check(c.hpTextX == -12 and by.hpTextX.value ~= nil, "a change on the card is a change to the setting")
  check(E:ChangedCount() == changed0 + 1, "counted once: " .. E:ChangedCount() .. " from " .. changed0)
  mirror.hpTextX:Set(0)
  check(z.hpText.edges[1].alpha == 1 and z.hp.edges[1].alpha == 0, "the picked part is outlined on the preview, the others aren't")
  z.hp.scripts.OnEnter(z.hp)
  check(z.hp.edges[1].alpha == 0.7 and GameTooltip.shown, "another lights up under the mouse, with its name")
  z.hp.scripts.OnLeave(z.hp)
  check(z.hp.edges[1].alpha == 0, "and goes dark again")

  -- another part, then none
  z.level.scripts.OnClick(z.level)
  page = E:Page("player")
  local lcard = page.pins.level
  check(U:Picked("player") == "level" and lcard.shown and card.shown == false and lcard.title.text == "Selected: Level", "clicking another part swaps the card")
  _, mirror = rowsBy()
  check(mirror.level and mirror.levelSize and mirror.levelAt and mirror.levelX and not mirror.barSize, "the level's: show, its own font size, where")
  mirror.level:Set(false)
  check(z.level.shown == false and lcard.shown and U:Picked("player") == "level", "switched off there, it leaves the preview but its card stays to bring it back")
  mirror.level:Set(true)
  check(z.level.shown, "and back")
  z.hpText.scripts.OnClick(z.hpText)
  check(E:Page("player").pins.hpText == card and card.shown, "going back to a part shows the card it had: none is built twice")
  z.hpText.scripts.OnClick(z.hpText)
  page = E:Page("player")
  check(U:Picked("player") == nil and card.shown == false and not page.pinned and page.height == h0 and #E.rows == n0,
    "clicking the picked part again lets go: the page is as it was")
  z.frame.scripts.OnClick(z.frame)
  local fcard = E:Page("player").pins.frame
  _, mirror = rowsBy()
  check(fcard and fcard.shown and mirror.width and mirror.scale and mirror.border, "the rim picks the frame: width, scale, border")
  local done
  for _, r in ipairs(fcard.rows) do if r.def.kind == "button" then done = r end end
  check(done and done.def.fn, "the card has a way out")
  done.def.fn()
  check(U:Picked("player") == nil and fcard.shown == false, "Deselect puts it away")

  -- each frame's page keeps its own pick; an extra text is a part too
  z.name.scripts.OnClick(z.name)
  E:Select("target")
  local tz = E.previews.target.zones
  check(tz and tz.hp and U:Picked("target") == nil and not E:Page("target").pinned, "the target's page has its own zones and nothing picked")
  check(not tz.extra1, "and no extra text to pick: it has none")
  E:Select("player")
  check(E:Page("player").pinned == "name" and E:Page("player").pins.name.shown, "back on the player's, its pick is still there")
  U:Pick("player", nil)
  check(not pf.zones.extra1 or pf.zones.extra1.shown == false, "an extra text that's off has no zone")
  c.extra1 = "health"
  E:Select("player")
  local ez = pf.zones.extra1
  check(ez and ez.shown and ez.points[1][2] == pf.extras[1], "switched on, it has one")
  ez.scripts.OnClick(ez)
  _, mirror = rowsBy()
  check(E:Page("player").pins.extra1.title.text == "Selected: Extra text 1" and mirror.extra1 and mirror.extra1At and mirror.extra1Size and mirror.extra1X,
    "and its card: what it shows, where, size, nudges")
  U:Pick("player", nil)
  -- a search doesn't get the card, and leaving search brings back a pick
  z.hp.scripts.OnClick(z.hp)
  E:Search("width")
  U:Pick("player", nil)
  E:ClearSearch()
  E:Select("player")
  check(not E:Page("player").pinned, "let go of during a search: gone when the page comes back")

  for k, v in pairs(keep) do c[k] = v end
  E:Select("player")
  U:Layout(VoltUIPlayerFrame)
  E:Close()
end)()

-- 1.97.0: a sketch of a plate at the top of each nameplate page, with parts to click
;(function()
  local N, E, S = ns.Nameplates, ns.EditMode, ns.Style
  local wasY, wasE = N.yielded, N.enabled
  N.yielded, N.enabled = nil, true
  local c = N:Cfg()
  local keep = {}
  for k, v in pairs(c.enemy) do keep[k] = v end
  local keepT = {}
  for k, v in pairs(c.target) do keepT[k] = v end
  c.enemy.hpColor, c.enemy.hpText, c.enemy.castBar, c.enemy.auras, c.enemy.barHeight = "volt", "pct", true, true, 0
  local function rowsBy()
    local by, mirror = {}, {}
    for _, r in ipairs(E.rows) do
      local keys = { r.def.key }
      for _, k in ipairs(r.def.keys or {}) do keys[#keys + 1] = k.key end
      for _, k in ipairs(keys) do
        if r.mirror then mirror[k] = r else by[k] = r end
      end
    end
    return by, mirror
  end

  E:Open("plates")
  local m = E.previews.plates
  check(E.previewBox.shown and m and m.shown and m.mock and m.parent == E.previewBox, "the enemy plates page shows a sketch of a plate")
  check(E.previewBox.note.text:find("sketch", 1, true), "and says it's a sketch: " .. tostring(E.previewBox.note.text))
  check(m.name.text == "Defias Pillager" and m.text.shown and m.text.text == "62%" and m.castBox.shown and m.auraBox.shown,
    "with a name, health text, a cast bar and aura icons")
  local hostile = N:Color("colHostile")
  check(m.hb.barColor[1] == hostile[1] and m.hb.h == 20, "the bar in VoltUI's hostile colour, at the game's height")
  E.previewBox.scripts.OnUpdate(E.previewBox, 0.6)
  check(true, "the strip's ticker leaves a sketch alone")

  local by = rowsBy()
  by.barHeight:Set(9)
  check(m.hb.h == 9, "a change shows on the sketch: bar height")
  by.barHeight:Set(0)
  by.hpText:Set("off")
  check(m.text.shown == false, "health text off")
  by.hpText:Set("both")
  check(m.text.shown and m.text.text:find("62%%") and m.text.text:find("1"), "number and percent: " .. tostring(m.text.text))
  by.hpTextPos:Set("left")
  check(m.text.points[1][1] == "LEFT" and m.text.points[1][4] == 3, "moved to the left of the bar")
  by.hpTextPos:Set("center")
  by.hpText:Set("pct")
  by.debuffScale:Set(2)
  check(m.auras[1].w == 36 and m.auras[3].w == 18, "debuff size changes the debuffs, not the buff")
  by.debuffScale:Set(1)
  by.auraTimer:Set("off")
  check(m.auras[1].timer.text == "", "timer numbers off")
  by.auraTimer:Set("all")
  check(m.auras[3].timer.text == "2m" and m.auras[1].timer.text == "12", "all: a long one shows too")
  by.auraTimer:Set("short")
  check(m.auras[3].timer.text == "" and m.auras[1].timer.text == "12", "short: only under a minute")

  -- the parts
  local z = m.zones
  check(z and z.border and z.health and z.cast and z.auras and z.name and z.level and z.hpText, "the sketch has a zone over each part")
  check(z.health.points[1][2] == m.hb and z.border.points[1][4] == -5 and z.health.flevel > z.border.flevel and z.hpText.flevel > z.health.flevel,
    "the bar, a rim round it for the border, the text over both")
  local h0, n0 = E:Page("plates").height, #E.rows
  z.cast.scripts.OnClick(z.cast)
  local page = E:Page("plates")
  local card = page.pins and page.pins.cast
  local _, mirror = rowsBy()
  check(S.Picked("plates") == "cast" and card and card.shown and card.title.text == "Selected: Cast bar", "clicking the cast bar picks it")
  check(mirror.castBar and mirror.castHeight and mirror.castTime and mirror.castScale and mirror.colCast and not mirror.auras and not mirror.border,
    "its card: the switch, height, time, text size, colours")
  check(page.height > h0 and z.cast.edges[1].alpha == 1, "above the other cards, outlined on the sketch")
  mirror.castHeight:Set(24)
  check(c.enemy.castHeight == 24 and m.cast.points and m.castBox.h == 24, "a change on the card changes the sketch")
  mirror.castHeight:Set(0)
  z.health.scripts.OnClick(z.health)
  _, mirror = rowsBy()
  check(mirror.hpColor and mirror.texture and mirror.barHeight and mirror.class and mirror.threat and mirror.colHostile, "the health bar's: colour, texture, height, class and threat colours")
  local swatches = 0
  for _, r in ipairs(E:Page("plates").pins.health.rows) do if r.def.kind == "color" then swatches = swatches + 1 end end
  check(swatches == 2, "each row of swatches once: " .. swatches)
  z.health.scripts.OnClick(z.health)
  check(S.Picked("plates") == nil and E:Page("plates").height == h0 and #E.rows == n0, "clicking it again lets go")

  -- the friendly page and the target's have their own
  E:Select("friendly")
  local fm = E.previews.friendly
  check(fm and fm.shown and not m.shown and fm.name.text == "Town Guard" and fm ~= m, "the friendly page has its own sketch")
  E:Select("plateTarget")
  local tm = E.previews.plateTarget
  local tz = tm.zones
  check(tm and tm.shown and tm.castBox.shown == false and tm.auraBox.shown == false, "the target's sketch: just the bar and its texts")
  check(tz.border and tz.health and tz.name and not tz.cast and not tz.auras and not tz.level, "with only the parts that page can change")
  check(tm.edge[1].shown ~= false and tm.ring[1].shown ~= false, "in the target's border, with its faint ring")
  tz.border.scripts.OnClick(tz.border)
  _, mirror = rowsBy()
  check(E:Page("plateTarget").pins.border.title.text == "Selected: Border" and mirror.color and mirror.border and mirror.glow, "its border card: colour, thickness, ring")
  mirror.glow:Set(false)
  check(tm.ring[1].shown == false, "ring off")
  mirror.glow:Set(true)
  S.Pick("plateTarget", nil)
  by = rowsBy()
  by.barHeight:Set(30)
  check(tm.hb.h == 30 and m.hb.h ~= 30, "the target's own bar height shows on its sketch only")
  by.barHeight:Set(0)

  for k in pairs(c.enemy) do c.enemy[k] = keep[k] end
  for k in pairs(c.target) do c.target[k] = keepT[k] end
  E:Select("general")
  E:Close()
  N.yielded, N.enabled = wasY, wasE
end)()

-- 1.98.1: notes on what the game's Cooldown Manager and combat log give in a fight
;(function()
  local T = ns.Timers
  if not (T and T.ProbeViewerStatic) then return end
  local old = { cv = C_CooldownViewer, enum = Enum.CooldownViewerCategory, v = BuffIconCooldownViewer, log = CombatLogGetCurrentEventInfo,
    secret = issecretvalue, probe = VoltUIDB.viewerProbe, getcvar = GetCVar }
  VoltUIDB.viewerProbe = nil
  C_CooldownViewer = nil
  T:ProbeViewerStatic()
  check(VoltUIDB.viewerProbe.static.api == "missing" and VoltUIDB.viewerProbe.static.frames.BuffIconCooldownViewer == "missing", "no Cooldown Manager: it says so")
  local hid = {}
  issecretvalue = function(v) return v == hid end
  GetCVar = function() return "1" end
  Enum.CooldownViewerCategory = { TrackedBuff = 2 }
  C_CooldownViewer = {
    IsCooldownViewerAvailable = function() return true end,
    GetCooldownViewerCategorySet = function(cat) return cat == 2 and { 11, 12 } or {} end,
    GetCooldownViewerCooldownInfo = function(id) return { spellID = id == 11 and 324 or 8042 } end,
  }
  local item = { cooldownID = 11, isActive = hid, GetSpellID = function() return 324 end, IsShown = function() return true end }
  BuffIconCooldownViewer = { IsShown = function() return true end, GetItemFrames = function() return { item } end }
  T:ProbeViewerStatic()
  local st = VoltUIDB.viewerProbe.static
  check(st.api == "there" and st.available:find("true") and st.categories.TrackedBuff:find("324", 1, true) and st.categories.TrackedBuff:find("8042", 1, true),
    "which spells the game tracks: " .. tostring(st.categories.TrackedBuff))
  check(st.frames.BuffIconCooldownViewer:find("shown boolean true", 1, true), "and that its frame is there")
  CombatLogGetCurrentEventInfo = function() return 1, "SPELL_AURA_REMOVED", false, "g", hid end
  T.logSeen, T.logCount = {}, 0
  T:ProbeLog()
  T:ProbeViewerFight("test")
  local f = VoltUIDB.viewerProbe.fights[#VoltUIDB.viewerProbe.fights]
  check(f.items[1] and f.items[1]:find("active secret", 1, true) and f.items[1]:find("shown boolean true", 1, true) and f.items[1]:find("id number 11", 1, true),
    "in a fight: what can be seen of a tracked buff's icon: " .. tostring(f.items[1]))
  check(f.logCount == 1 and f.log:find("2:string SPELL_AURA_REMOVED", 1, true) and f.log:find("5:secret", 1, true), "and of a combat log line: " .. tostring(f.log))
  CombatLogGetCurrentEventInfo = function() error("refused") end
  T.logSeen = {}
  T:ProbeLog()
  check(T.logSeen[1]:find("^error"), "a refused combat log is noted, not thrown")
  for _ = 1, 12 do T:ProbeViewerFight("x") end
  check(#VoltUIDB.viewerProbe.fights == 8, "only the last few fights are kept")
  C_CooldownViewer, Enum.CooldownViewerCategory, BuffIconCooldownViewer, CombatLogGetCurrentEventInfo = old.cv, old.enum, old.v, old.log
  issecretvalue, VoltUIDB.viewerProbe, GetCVar = old.secret, old.probe, old.getcvar
  T.logSeen, T.logCount = nil, nil
end)()

-- 1.99.1, seen in game: asking for the combat log event is a forbidden action on this client
;(function()
  local asked = false
  for _, f in ipairs(eventFrames.COMBAT_LOG_EVENT_UNFILTERED or {}) do
    if f.events.COMBAT_LOG_EVENT_UNFILTERED then asked = true end
  end
  check(not asked, "nothing in VoltUI registers for the combat log")
  local src = io.open(DIR .. "/Timers.lua"):read("*a")
  check(not src:find('RegisterEvent, f, "COMBAT_LOG_EVENT_UNFILTERED"', 1, true), "and the Timers probe no longer tries")
end)()

-- 1.101.0: the game's Tracked Buffs, picked from the Timers page
;(function()
  local T = ns.Timers
  if not (T and T.TrackList) then return end
  local old = { cv = C_CooldownViewer, enum = Enum.CooldownViewerCategory, st = Enum.CooldownLayoutStatus, icon = BuffIconCooldownViewer,
    bar = BuffBarCooldownViewer, set = CooldownViewerSettings, getcvar = GetCVar, probe = VoltUIDB.viewerProbe, combat = T.InCombat,
    name = C_Spell and C_Spell.GetSpellName }
  local names = { [324] = "Lightning Shield", [16256] = "Flurry", [8042] = "Earth Shock" }
  C_Spell = C_Spell or {}
  C_Spell.GetSpellName = function(id) return names[id] end
  C_CooldownViewer = nil
  check(T.TrackList() == nil, "no Cooldown Manager: nothing to pick")
  local on = "1"
  GetCVar = function() return on end
  Enum.CooldownViewerCategory = { Essential = 0, Utility = 1, TrackedBuff = 2, TrackedBar = 3, HiddenActive = -1, HiddenPassive = -2 }
  Enum.CooldownLayoutStatus = { Success = 0, Locked = 1 }
  C_CooldownViewer = {
    GetCooldownViewerCategorySet = function(cat) return cat == 2 and { 11, 12, 13 } or {} end,
    GetCooldownViewerCooldownInfo = function(id) return ({ [11] = { spellID = 324 }, [12] = { spellID = 16256 }, [13] = { spellID = 99999 } })[id] end,
  }
  BuffIconCooldownViewer = { GetItemFrames = function() return { { cooldownID = 12 } } end }
  BuffBarCooldownViewer = nil
  local list = T.TrackList()
  check(#list == 2 and list[1].name == "Flurry" and list[1].on == true and list[2].name == "Lightning Shield" and list[2].on == false,
    "the buffs the game can track, by name, and which it tracks now")
  on = "0"
  check(T.TrackList() == nil, "manager off: no list")
  on = "1"
  local calls, status, fail = {}, 0, false
  CooldownViewerSettings = {
    GetDataProvider = function() return { SetCooldownToCategory = function(_, id, cat) if fail then error("no") end calls[#calls + 1] = id .. ">" .. cat return status end } end,
    SaveCurrentLayout = function() calls[#calls + 1] = "save" end,
  }
  VoltUIDB.viewerProbe = nil
  T.trackPending, T.trackReload = nil, nil
  T.InCombat = function() return true end
  local ok, why = T:SetTracked(11, true)
  check(ok == false and why:find("fight") and #calls == 0, "not changed in a fight")
  T.InCombat = function() return false end
  ok = T:SetTracked(11, true)
  check(ok == true and calls[1] == "11>2" and calls[2] == "save" and T.trackReload == true, "tracking one: set in the game's settings and saved")
  list = T.TrackList()
  check(list[2].on == true and list[2].pending == true, "and shown as tracked, pending a reload")
  ok = T:SetTracked(12, false)
  check(ok == true and calls[3] == "12>-2" and T.TrackList()[1].on == false, "untracking one puts it with the game's hidden buffs")
  check(#VoltUIDB.viewerProbe.trackSet == 2 and VoltUIDB.viewerProbe.trackSet[1].saved:find("true"), "what the game answered is noted")
  status = 1
  local n = #calls
  ok, why = T:SetTracked(11, false)
  check(ok == false and why:find("/cdm", 1, true) and #calls == n + 1 and T.trackPending[11] == true, "a refused change says so and isn't saved")
  status, fail = 0, true
  ok = T:SetTracked(11, false)
  check(ok == false, "an error from the game is a refusal, not thrown")
  CooldownViewerSettings = nil
  ok = T:SetTracked(11, false)
  check(ok == false, "no settings object: refused")
  -- the page
  local E = ns.EditMode
  local def = E and E.defs and E.defs.timers
  local found
  for _, sec in ipairs(def and def.sections or {}) do
    if sec.title == "In a fight" then
      for _, row in ipairs(sec) do
        if row.kind == "custom" and row.keywords and row.keywords:find("tracked buffs", 1, true) then found = row end
      end
    end
  end
  check(def == nil or found ~= nil, "the Timers page lists them under In a fight")
  if found then check(found.heightFor() == 2 * 22 + 6, "as tall as its buffs") end
  T.trackPending, T.trackReload, T.trackSay = nil, nil, nil
  C_CooldownViewer, Enum.CooldownViewerCategory, Enum.CooldownLayoutStatus, BuffIconCooldownViewer = old.cv, old.enum, old.st, old.icon
  BuffBarCooldownViewer, CooldownViewerSettings, GetCVar, VoltUIDB.viewerProbe, T.InCombat = old.bar, old.set, old.getcvar, old.probe, old.combat
  C_Spell.GetSpellName = old.name
end)()

-- 1.101.2: a missing buff doesn't show out of a fight unless asked
;(function()
  local T = ns.Timers
  if not (T and T.Visible) then return end
  local cfg = T:Cfg()
  local old = { combat = T.InCombat, miss = cfg.missIdle, idle = cfg.warnIdle, fight = cfg.warnFight, hide = cfg.buffHide, preview = T.preview, G = T.G }
  T.preview = nil
  T.G = function() return { on = true } end
  local fight = false
  T.InCombat = function() return fight end
  local it = { kind = "keep", group = "buffs", always = true, st = { on = false } }
  cfg.missIdle, cfg.warnIdle, cfg.warnFight = false, false, true
  check(T:Visible(it) == false, "missing and out of a fight: not shown")
  fight = true
  check(T:Visible(it) == true, "missing in a fight: shown")
  fight = false
  cfg.warnIdle = true
  check(T:Visible(it) == true, "out of a fight it shows while it flashes there")
  cfg.warnIdle, cfg.missIdle = false, true
  check(T:Visible(it) == true, "or when you ask to see missing buffs out of combat")
  cfg.missIdle = false
  it.st.on, cfg.buffHide = true, false
  check(T:Visible(it) == true, "a buff that's up is as before")
  check(T.DEFAULTS.missIdle == false, "off to begin with")
  T.InCombat, cfg.missIdle, cfg.warnIdle, cfg.warnFight, cfg.buffHide, T.preview, T.G = old.combat, old.miss, old.idle, old.fight, old.hide, old.preview, old.G
end)()

print("== 1.101.7: fixes from the ElvUI comparison")
;(function()
  local R = ns.Raid
  -- a /reload in a fight: nothing secure is made until the fight ends
  local oldCombat, oldCreate = InCombatLockdown, CreateFrame
  local made = {}
  InCombatLockdown = function() return true end
  CreateFrame = function(...) local f = oldCreate(...); made[#made + 1] = f; return f end
  local started = 0
  local fake = setmetatable({}, { __index = R })
  fake.Start = function() started = started + 1 end
  fake:Enable()
  check(rawget(fake, "enabled") == true and started == 0, "party and raid frames: a reload in a fight makes nothing yet")
  check(#made == 1 and made[1].events and made[1].events.PLAYER_REGEN_ENABLED, "it waits for the fight to end")
  InCombatLockdown, CreateFrame = oldCombat, oldCreate
  local fake2 = setmetatable({}, { __index = R })
  fake2.Start = function() started = started + 1 end
  fake2:Enable()
  check(started == 1, "out of a fight they start at once")
  local bare = setmetatable({ enabled = true }, { __index = function(_, k) if k ~= "holder" then return R[k] end end })
  check(pcall(bare.Apply, bare), "a layout asked for before they start is left alone")
  -- the game's rounded icon mask comes off guild bank slots (and bag slots, same lines)
  local G = ns.GuildBank
  if G and G.SkinSlot then
    local b = CreateFrame("Button", "VoltUITestGBSlot")
    b.icon, b.Mask, b.Count = b:CreateTexture(), b:CreateTexture(), b:CreateFontString()
    G:SkinSlot(b)
    check(b.icon.maskRemoved == b.Mask or (b.icon.unmasked and b.icon.unmasked[b.Mask]), "guild bank slots: the icon's rounded mask is taken off")
  end
end)()

print("== 1.101.8 and 1.101.9: reload buttons in a fight, minimap leftovers")
;(function()
  local FUI, M = ns.FUI, ns.Minimap
  local oldReload, oldCombat, n = ReloadUI, InCombatLockdown, 0
  ReloadUI = function() n = n + 1 end
  InCombatLockdown = function() return true end
  check(FUI:Reload() == false and n == 0, "Reload now does nothing in a fight")
  InCombatLockdown = function() return false end
  check(FUI:Reload() == true and n == 1, "and reloads out of one")
  -- a reload in a fight: the catcher waits
  local saved = M.catch
  M.catch = nil
  InCombatLockdown = function() return true end
  M:Catcher()
  check(M.catch == nil and M.catchPending == true, "the click catcher isn't made in a fight")
  M.catch, M.catchPending = saved, nil
  ReloadUI, InCombatLockdown = oldReload, oldCombat
  -- mail: the indicator frame goes to the map's corner, and back after the game places it
  local ind = CreateFrame("Frame")
  MinimapCluster.IndicatorFrame = ind
  M.mailHooked = nil
  M:PlaceMail()
  check(ind.points and ind.points[1][1] == "TOPRIGHT" and ind.points[1][2] == Minimap, "new mail sits in the map's top-right corner")
  MinimapCluster.IndicatorFrame = nil
end)()

print("== 1.101.11 and 1.101.12: bar 1's art stays off, the leave-vehicle button has a place")
;(function()
  local B = ns.ActionBars
  local b = CreateFrame("Button")
  local normal, pushed = b:CreateTexture(), b:CreateTexture()
  b.GetNormalTexture = function() return normal end
  b.GetPushedTexture = function() return pushed end
  b.icon = b:CreateTexture()
  normal.alpha = 1
  B.Undress(b)
  check(normal.alpha == 0, "a border the game puts back on a button is faded again")
  check(pushed.ctex and pushed.ctex[4] == 0.4, "and the pressed look is VoltUI's again")
  -- the game's leave button, a child of the hidden main bar
  local old = B.leave
  B.leave = nil
  MainMenuBarVehicleLeaveButton = CreateFrame("Button", "MainMenuBarVehicleLeaveButton", CreateFrame("Frame"))
  B:LeaveButton()
  local h = VoltUILeaveVehicle
  check(h and B.leave == h and MainMenuBarVehicleLeaveButton.parent == h, "the leave-vehicle button moves into a holder of its own")
  check(h.mover ~= nil and h.parent == UIParent, "which can be moved like any frame")
  check(h.points and h.points[1][2] == B.frames.bar1, "beside bar 1 until it's moved")
  MainMenuBarVehicleLeaveButton:SetParent(UIParent)
  check(MainMenuBarVehicleLeaveButton.parent == h, "and it goes back when the game re-parents it")
  MainMenuBarVehicleLeaveButton = nil
  B.leave = old
end)()

print("== 1.101.13 and 1.101.14: login probe, group buttons made ahead")
;(function()
  local FUI, R = ns.FUI, ns.Raid
  local p = FUI.loginProbeFrame
  local on = p.scripts.OnEvent
  local oldCombat, oldDB = InCombatLockdown, VoltUIDB.loginProbe
  VoltUIDB.loginProbe = nil
  p.events = p.events or {}
  InCombatLockdown = function() return true end
  on(p, "ADDON_LOADED", "VoltUI")
  InCombatLockdown = function() return false end
  on(p, "PLAYER_LOGIN")
  on(p, "PLAYER_ENTERING_WORLD")
  local row = VoltUIDB.loginProbe and VoltUIDB.loginProbe[1]
  check(row and row.addonLoaded:find("^locked") and row.login:find("^free") and row.enteringWorld:find("^free") and row.inFight == true,
    "the probe notes whether the game is locked at each point VoltUI starts from")
  on(p, "PLAYER_REGEN_ENABLED")
  check(type(row.fightEnded) == "number", "and when the fight ended")
  for i = 1, 10 do on(p, "ADDON_LOADED", "VoltUI") end
  check(#VoltUIDB.loginProbe == 8, "the last eight starts are kept")
  VoltUIDB.loginProbe = oldDB
  -- buttons made ahead
  local h = CreateFrame("Frame")
  local sets = {}
  h.SetAttribute = function(_, k, v) sets[#sets + 1] = k .. "=" .. tostring(v) end
  h.IsVisible = function() return true end
  InCombatLockdown = function() return true end
  check(R.PreMake(h, 5) == false and #sets == 0, "nothing is asked of a header in a fight")
  InCombatLockdown = function() return false end
  check(R.PreMake(h, 5) == true and sets[1] == "startingIndex=-4" and sets[2] == "startingIndex=1", "out of one, the header is asked for five buttons at once, then put back")
  check(R.PreMake(h, 5) == false and #sets == 2, "once is enough")
  check(R.PreMake(h, 40) == true and sets[3] == "startingIndex=-39", "a raid's forty when you join one")
  h.kPremade = nil
  h.IsVisible = function() return false end
  check(R.PreMake(h, 5) == false, "a hidden header is left for later")
  InCombatLockdown = oldCombat
end)()

print("== 1.101.15: auto repair")
;(function()
  local J = ns.Junk
  local old = { CanMerchantRepair, GetRepairAllCost, RepairAllItems, GetMoney, ns.db.autoRepair }
  local repaired, money, cost, can = 0, 5000, 1200, true
  CanMerchantRepair = function() return true end
  GetRepairAllCost = function() return cost, can end
  RepairAllItems = function() repaired = repaired + 1 end
  GetMoney = function() return money end
  ns.db.autoRepair = false
  check(J:Repair() == nil and repaired == 0, "repairs are off unless asked for")
  ns.db.autoRepair = true
  check(J:Repair() == 1200 and repaired == 1, "on: everything is repaired and the cost comes back")
  money = 1000
  check(J:Repair() == nil and repaired == 1, "not when you can't afford it")
  money, cost = 5000, 0
  check(J:Repair() == nil and repaired == 1, "nor when nothing is damaged")
  cost = 1200
  CanMerchantRepair = function() return false end
  check(J:Repair() == nil and repaired == 1, "nor at a vendor that doesn't repair")
  CanMerchantRepair, GetRepairAllCost, RepairAllItems, GetMoney, ns.db.autoRepair = old[1], old[2], old[3], old[4], old[5]
end)()

print("== 1.101.16: cooldown number rules")
;(function()
  local B = ns.ActionBars
  local b = B.frames.bar1.buttons[1]
  local cd, oldCd = CreateFrame("Cooldown"), b.cooldown
  local min, tenths
  cd.SetMinimumCountdownDuration = function(_, ms) min = ms end
  cd.SetCountdownMillisecondsThreshold = function(_, s) tenths = s end
  b.cooldown = cd
  local c = setmetatable({}, { __index = B:Cfg("bar1") })
  B:Fit(b, c)
  check(min == 2000 and tenths == 3, "no number on a cooldown under two seconds long (the global one), tenths under three left")
  c.cdMin, c.cdTenths = 0, 0
  B:Fit(b, c)
  check(min == 0 and tenths == 0, "both can be turned off")
  b.cooldown = oldCd
  B:Fit(b, B:Cfg("bar1"))
end)()

print("== 1.101.17 and 1.101.18: tooltip health text, item counts, ids on Shift")
;(function()
  local T = ns.Tooltips
  local bar = GameTooltipStatusBar
  local old = { ns.db.tipHealth, UnitHealth, UnitHealthMax, UnitExists, GameTooltip.GetUnit, IsShiftKeyDown, C_Item.GetItemCount, UnitIsDeadOrGhost }
  UnitExists = function(u) return u == "mouseover" end
  UnitHealth = function() return 250 end
  UnitHealthMax = function() return 1000 end
  UnitIsDeadOrGhost = function() return false end
  GameTooltip.GetUnit = function() return "Boar", nil end
  ns.db.tipHealth = "percent"
  T:BarLook()
  check(bar.h == 12 and T.barText.shown ~= false, "the bar is tall enough for text when it's on")
  check(tostring(T.barText.text):find("25") and tostring(T.barText.text):find("%%"), "health as a percent: " .. tostring(T.barText.text))
  ns.db.tipHealth = "number"
  T:BarLook()
  check(tostring(T.barText.text):find("250") and tostring(T.barText.text):find("1000"), "or as numbers: " .. tostring(T.barText.text))
  UnitIsDeadOrGhost = function() return true end
  T:BarText()
  check(T.barText.text == (DEAD or "Dead"), "a dead unit says so")
  UnitIsDeadOrGhost = function() return false end
  UnitHealth = function() error("hidden") end
  T:BarText()
  check(T.barText.text == "", "numbers the game refuses leave the bar without text, and no error")
  ns.db.tipHealth = "off"
  T:BarLook()
  check(bar.h == 4 and T.barText.shown == false, "off: the thin line, as before")
  -- item counts and ids
  local tip = GameTooltip
  local function lines() local t = {} for _, l in ipairs(tip.dlines or {}) do t[#t + 1] = l[1] .. "=" .. tostring(l[2]) end return table.concat(t, "|") end
  local oldLeft, oldN = GameTooltipTextLeft1.text, tip.nlines
  GameTooltipTextLeft1.text, tip.nlines = "Linen Cloth", 1
  C_Item.GetItemCount = function(_, bank) return bank and 37 or 12 end
  IsShiftKeyDown = function() return false end
  tip.lines, tip.dlines = {}, {}
  T:OnItem(tip, "item:2589")
  check(lines():find("You have=12", 1, true) and lines():find("25 in the bank", 1, true) and not lines():find("Item id", 1, true), "how many you carry and bank: " .. lines())
  IsShiftKeyDown = function() return true end
  tip.lines, tip.dlines = {}, {}
  T:OnItem(tip, "item:2589")
  check(lines():find("Item id=2589", 1, true), "the item's id while Shift is held")
  C_Item.GetItemCount = function() return 0 end
  IsShiftKeyDown = function() return false end
  tip.lines, tip.dlines = {}, {}
  T:OnItem(tip, "item:2589")
  check(not lines():find("You have", 1, true), "no line for an item you have none of")
  -- spell id
  IsShiftKeyDown = function() return true end
  tip.GetSpell = function() return "Healing Wave", 331 end
  tip.lines, tip.dlines = {}, {}
  T:OnSpell(tip)
  check(lines():find("Spell id=331", 1, true), "a spell's id while Shift is held")
  IsShiftKeyDown = function() return false end
  tip.lines, tip.dlines = {}, {}
  T:OnSpell(tip)
  check(lines() == "", "and nothing without Shift")
  tip.GetSpell = nil
  GameTooltipTextLeft1.text, tip.nlines = oldLeft, oldN
  tip.lines, tip.dlines = {}, {}
  ns.db.tipHealth, UnitHealth, UnitHealthMax, UnitExists, GameTooltip.GetUnit, IsShiftKeyDown, C_Item.GetItemCount, UnitIsDeadOrGhost =
    old[1], old[2], old[3], old[4], old[5], old[6], old[7], old[8]
  T:BarLook()
end)()

print("== 1.101.19: pixel-true borders")
;(function()
  local S = ns.Style
  local oldPU, oldCrisp = PixelUtil, ns.db.pixelEdges
  PixelUtil = { GetPixelToUIUnitFactor = function() return 0.8 end }
  local f = CreateFrame("Frame")
  local scale = 1
  f.GetEffectiveScale = function() return scale end
  ns.db.pixelEdges = true
  local e = S.Edges(f, "OVERLAY")
  check(math.abs(e[1].h - 0.8) < 1e-6 and math.abs(e[3].w - 0.8) < 1e-6, "a border line is one screen pixel thick, not one UI unit")
  S.EdgeWidth(e, 2)
  check(math.abs(e[2].h - 1.6) < 1e-6, "a 2-wide border is two pixels")
  scale = 0.5
  S.RefreshEdges()
  check(math.abs(e[4].w - 3.2) < 1e-6, "on a frame scaled to half, the line is sized for that scale")
  ns.db.pixelEdges = false
  S.RefreshEdges()
  check(e[1].h == 2, "Crisp borders off: plain UI units, as before")
  PixelUtil = nil
  ns.db.pixelEdges = true
  S.RefreshEdges()
  check(e[1].h == 2, "a client that can't say what a pixel is gets UI units")
  PixelUtil, ns.db.pixelEdges = oldPU, oldCrisp
  S.RefreshEdges()
end)()

print("== 1.101.20 and 1.101.21: key ring reachable, bank bag slots")
;(function()
  local B = ns.Bags
  -- bank bag slots
  local old = { C_Bank, Enum.BagIndex, C_Container.GetContainerItemInfo, C_Container.PickupContainerItem, Enum.BankType }
  Enum.BankType = Enum.BankType or { Character = 0, Account = 2 }
  Enum.BagIndex = setmetatable({ Characterbanktab = -4 }, { __index = old[2] or {} })
  local bought, picked = 3, nil
  C_Bank = setmetatable({
    FetchMaxNumBankTabs = function() return 7 end,
    FetchNumPurchasedBankTabs = function() return bought end,
  }, { __index = old[1] or {} })
  C_Container.GetContainerItemInfo = function(bag, slot)
    if bag == -4 then return slot == 2 and { iconFileID = 133633 } or nil end
    return old[3](bag, slot)
  end
  C_Container.PickupContainerItem = function(bag, slot) picked = bag .. ":" .. slot end
  local f = CreateFrame("Frame")
  f.isBank = true
  local wide = B:UpdateBagSlots(f)
  check(#f.bagSlots == 6 and wide == 6 * 20 + 6, "one button for each bank bag slot after the bank itself (2 to 7)")
  local s1, s2, s3 = f.bagSlots[1], f.bagSlots[2], f.bagSlots[3]
  check(s1.slot == 2 and s1.bought and s1.icon.shown ~= false and s1.icon.tex == 133633, "a slot with a bag in it shows the bag")
  check(s2.slot == 3 and s2.bought and s2.icon.shown == false and s2.alpha == 1, "a bought slot with no bag is empty and ready")
  check(s3.slot == 4 and not s3.bought and s3.alpha == 0.35, "one you haven't bought is dimmed")
  s2.scripts.OnClick(s2)
  check(picked == "-4:3", "a click picks up or drops a bag in that slot")
  picked = nil
  s2.scripts.OnReceiveDrag(s2)
  check(picked == "-4:3", "so does dropping one on it")
  picked = nil
  s3.scripts.OnClick(s3)
  check(picked == nil, "a slot that isn't bought does nothing")
  bought = 4
  B:UpdateBagSlots(f)
  check(f.bagSlots[3].bought and f.bagSlots[3].alpha == 1, "buying a slot lights it up")
  C_Bank, Enum.BagIndex, C_Container.GetContainerItemInfo, C_Container.PickupContainerItem, Enum.BankType = old[1], old[2], old[3], old[4], old[5]

  -- key ring
  local oldAB, oldKey, oldCombat = C_ActionBar, KEYRING_CONTAINER, InCombatLockdown
  KEYRING_CONTAINER = -2
  C_ActionBar = setmetatable({ ShouldShowKeyring = function() return true end }, { __index = oldAB or {} })
  InCombatLockdown = function() return false end
  local cf = ContainerFrame3 or CreateFrame("Frame", "ContainerFrame3")
  local wasID, wasParent, wasShown = cf.GetID, cf.parent, cf.shown
  cf.GetID = function() return -2 end
  cf:SetParent(ns.Style.HiddenParent())
  cf.shown = true
  check(B:HasKeyRing() == true, "a client with a key ring says so")
  check(B:ShowKeyRing() == true and cf.parent == UIParent and B.keyFrame == cf, "the game's key ring window is let out when it opens")
  B:PutAwayGameBags()
  check(cf.parent == UIParent, "and stays out while it's open")
  cf.scripts.OnHide(cf)
  check(B.keyFrame == nil and cf.parent == ns.Style.HiddenParent(), "closed, it goes back out of sight")
  C_ActionBar = setmetatable({ ShouldShowKeyring = function() return false end }, { __index = oldAB or {} })
  check(B:HasKeyRing() == false, "a client without one is left alone")
  cf.GetID, cf.shown = wasID, wasShown
  C_ActionBar, KEYRING_CONTAINER, InCombatLockdown = oldAB, oldKey, oldCombat
end)()

print("== 1.101.22: quest marker on nameplates")
;(function()
  local N = ns.Nameplates
  local oldTI, oldName = C_TooltipInfo, UnitName
  local lines
  C_TooltipInfo = { GetUnit = function() return { lines = lines } end }
  UnitName = function(u) if u == "player" then return "Volt" end return "Boar" end
  lines = { { type = 2, leftText = "Kobold Vermin" }, { type = 17, leftText = "Kobold Camp Cleanup" }, { type = 8, leftText = " - Kobold Vermin slain: 3/8" } }
  local wanted, most = N.QuestLeft("nameplate1")
  check(wanted == true and most == 5, "a creature a quest still needs: wanted, five to go")
  lines[3].leftText = " - Kobold Vermin slain: 8/8"
  check(N.QuestLeft("nameplate1") == nil, "an objective that's done doesn't mark it")
  lines = { { type = 17, leftText = "Culling the Herd" }, { type = 8, leftText = " - Threat reduced: 40%" } }
  wanted, most = N.QuestLeft("nameplate1")
  check(wanted == true and most == nil, "a percent objective under 100 marks it, with no count")
  lines = { { type = 17, leftText = "Wolves" }, { type = 18, leftText = "Otherguy" }, { type = 8, leftText = " - Wolf slain: 1/8" },
            { type = 18, leftText = "Volt" }, { type = 8, leftText = " - Wolf slain: 8/8" } }
  check(N.QuestLeft("nameplate1") == nil, "in a group, someone else's unfinished objective isn't yours")
  lines = { { type = 2, leftText = "Rabbit" } }
  check(N.QuestLeft("nameplate1") == nil, "a creature no quest needs has no marker")
  C_TooltipInfo = { GetUnit = function() error("refused") end }
  check(N.QuestLeft("nameplate1") == nil, "a refused read is no marker, and no error")
  C_TooltipInfo = nil
  check(N.QuestLeft("nameplate1") == nil, "a client without tooltip data is left alone")
  -- on a plate
  C_TooltipInfo = { GetUnit = function() return { lines = { { type = 17, leftText = "Q" }, { type = 8, leftText = "Boars: 2/6" } } } end }
  local f
  for frame in pairs(N.plates) do f = frame break end
  if f then
    local p = N.plates[f]
    local oldUnit, oldIsPlayer = f.unit, UnitIsPlayer
    f.unit, f.displayedUnit = "nameplate1", nil
    UnitIsPlayer = function() return false end
    N:Quest(f)
    check(p.quest.shown and p.quest.text == "!4", "the plate shows ! and how many are left: " .. tostring(p.quest.text))
    N:Cfg().quest = false
    N:Quest(f)
    check(p.quest.shown == false, "off in the settings: no marker")
    N:Cfg().quest = true
    UnitIsPlayer = function() return true end
    N:Quest(f)
    check(p.quest.shown == false, "players never get one")
    f.unit, UnitIsPlayer = oldUnit, oldIsPlayer
  end
  C_TooltipInfo, UnitName = oldTI, oldName
end)()

print("== 1.101.23: web addresses in chat, copying chat")
;(function()
  local C, L = ns.Chat, ns.Links
  local out = C.LinkURLs("see https://foreverdb.net/item/2589, it's good")
  check(out == "see |cff7fc8ff|Haddon:VoltUI:url:https://foreverdb.net/item/2589|h[https://foreverdb.net/item/2589]|h|r, it's good", "a web address becomes a link, the comma after it stays outside: " .. tostring(out))
  out = C.LinkURLs("go to www.wowhead.com/classic now")
  check(out and out:find("|Haddon:VoltUI:url:www.wowhead.com/classic|h", 1, true), "www addresses too")
  check(C.LinkURLs("nothing here") == nil and C.LinkURLs("ratio 3:1 or a.b") == nil, "a message without one is left alone")
  local item = "|cff1eff00|Hitem:2589::::|h[Linen http://x.y Cloth]|h|r and http://a.bc/d"
  out = C.LinkURLs(item)
  check(out and out:find("|Hitem:2589::::|h[Linen http://x.y Cloth]|h", 1, true) and out:find("|Haddon:VoltUI:url:http://a.bc/d|h", 1, true), "an address inside another link isn't touched, one outside is")
  check(C.LinkURLs(out) == nil, "a message already done isn't done twice")
  check(C.LinkURLs(nil) == nil and C.LinkURLs(42) == nil, "anything that isn't text is passed on")
  -- the click
  local shown
  local oldShow = L and L.ShowURL
  if L then L.ShowURL = function(_, url) shown = url; return true end end
  check(C:OpenURL("addon:VoltUI:url:https://foreverdb.net/x") == true and (not L or shown == "https://foreverdb.net/x"), "a click opens the copy box with the address")
  check(C:OpenURL("addon:Other:thing") == false and C:OpenURL("item:2589") == false, "other links are not VoltUI's to open")
  if L then L.ShowURL = oldShow end
  -- plain text
  check(C.Plain("|cffff0000[|Hplayer:Bob:1|h[Bob]|h]|r says: |TInterface\\Icons\\x:0|t hi || there") == "[[Bob]] says:  hi | there", "colours, icons and link wrappers come off: " .. tostring(C.Plain("|cffff0000[|Hplayer:Bob:1|h[Bob]|h]|r says: |TInterface\\Icons\\x:0|t hi || there")))
  local frame = { GetNumMessages = function() return 3 end, GetMessageInfo = function(_, i) return ({ "one", "|cff00ff00two|r", "three" })[i] end, name = "General" }
  local text, n = C:Lines(frame, 500)
  check(text == "one\ntwo\nthree" and n == 3, "a window's lines, oldest first")
  text, n = C:Lines(frame, 2)
  check(text == "two\nthree" and n == 2, "only the last ones asked for")
  check(C:Copy(frame) == true and VoltUIChatCopy and VoltUIChatCopy.shown and C.copyText == "one\ntwo\nthree", "the copy window opens with them")
  VoltUIChatCopy:Hide()
end)()

print("== 1.101.24: the target's auras, kept up by the game")
;(function()
  local U = ns.UnitFrames
  local cfg = U:Cfg("target")
  check(U.gameAuras == false and type(U.gameAurasWhy) == "string", "a client without the aura container keeps VoltUI's own row, and notes why")
  check(cfg.auraGame == true, "on to begin with")
  -- a client that has it
  local oldAnchor, oldCombat = AnchorUtil, InCombatLockdown
  AnchorUtil = { FlowDirection = { Left = -1, Right = 1, Up = 1, Down = -1 } }
  auraContainerWorld = true
  U.gameAuras, U.gameAurasWhy, U.gameAuraButtons = nil, nil, nil
  cfg.auras = true
  U:UpdateAuras()
  local c = U.gameAuras
  check(type(c) == "table" and c == VoltUITargetAuras and c.parent == U.auraRow and c.unit == "target", "the game's aura container is made on the target's aura row, for your target")
  check(#c.groups == 2 and c.groups[1].filter == "HARMFUL" and c.groups[2].filter == "HELPFUL", "debuffs first, then buffs")
  check(c.groups[1].options.maxFrameCount == 16 and c.groups[1].options.layout.elementWidth == cfg.auraSize, "sixteen of each at most, at your icon size")
  check(c.flowAnchor == "BOTTOMLEFT" and c.flowDir[1] == 1 and c.flowDir[2] == 1 and c.lineSize == cfg.width, "laid out from the bottom-left, rightwards then up, as wide as the frame")
  local b = c.buttons[1]
  check(#c.buttons == 4 and b.iconSet and b.cdSet and b.countSet and b.w == cfg.auraSize, "each button gets an icon, a sweep and a stack count for the game to fill")
  check(b.iconSet.texCoord and b.iconSet.texCoord[1] == 0.08, "icons cropped like VoltUI's own")
  local anyOld = false
  for _, old in ipairs(U.auras) do if old.shown then anyOld = true end end
  check(not anyOld and c.shown ~= false, "VoltUI's own row steps aside")
  -- size follows the setting, out of a fight
  local was = cfg.auraSize
  cfg.auraSize = 30
  U:SizeGameAuras()
  check(b.w == 30 and c.calls[#c.calls] == "help:30", "a new icon size reaches the game's buttons and layout")
  InCombatLockdown = function() return true end
  cfg.auraSize = 40
  U:SizeGameAuras()
  check(b.w == 30, "but nothing is resized in a fight")
  InCombatLockdown = oldCombat
  cfg.auraSize = was
  U:SizeGameAuras()
  -- the switch
  cfg.auraGame = false
  U:UpdateAuras()
  check(c.shown == false, "Kept up by the game off: the container hides and VoltUI's row is back in charge")
  cfg.auraGame = true
  U:UpdateAuras()
  check(c.shown ~= false, "and on again")
  -- back to the pretend client without one, for anything after this
  pcall(c.Hide, c)
  auraContainerWorld = nil
  U.gameAuras, U.gameAurasWhy = false, "test"
  AnchorUtil = oldAnchor
  U:UpdateAuras()
end)()

-- 1.102.0: the Timers page is a list of your timers. Nothing shows until you add it, and
-- each timer has its own settings: when and where it shows, how it looks.
print("== Timers: your list")
;(function()
  local T, Ed = ns.Timers, ns.EditMode
  if not (T and T.Mine and Ed) then return end
  local saved = {}
  for _, k in ipairs({ "UnitClass", "IsPlayerSpell", "IsSpellKnown", "C_Spell", "C_UnitAuras", "GetTotemInfo", "GetWeaponEnchantInfo", "UnitExists",
    "UnitCanAttack", "UnitIsDeadOrGhost", "InCombatLockdown", "UnitAffectingCombat", "UnitLevel", "C_SpellBook", "GetSpellBaseCooldown",
    "IsInInstance", "C_CooldownViewer", "GetTime" }) do
    saved[k] = { _G[k] }
  end
  local oldOn, oldList = T.ManagerOn, T.TrackList
  local clock = 5000
  GetTime = function() return clock end
  UnitClass = function() return "Shaman", "SHAMAN" end
  UnitLevel = function() return 40 end
  local known = { [324] = true, [8042] = true, [8050] = true, [421] = true, [8017] = true }
  IsPlayerSpell = function(id) return known[id] == true end
  IsSpellKnown = nil
  local NAMES = { [324] = "Lightning Shield", [8042] = "Earth Shock", [8050] = "Flame Shock", [8056] = "Frost Shock", [421] = "Chain Lightning",
    [16246] = "Clearcasting", [8017] = "Rockbiter Weapon", [2825] = "Bloodlust" }
  C_Spell = {
    GetSpellName = function(id) return NAMES[id] end,
    GetSpellTexture = function(id) return "icon" .. tostring(id) end,
    GetSpellCooldown = function() return { startTime = 0, duration = 0, isActive = false, isEnabled = true, isOnGCD = false } end,
    IsSpellUsable = function() return true, false end,
  }
  local auras = { player = {}, target = {} }
  C_UnitAuras = { GetAuraDataByIndex = function(u, i) return auras[u][i] end }
  GetTotemInfo = function() return false, "", 0, 0, nil end
  GetWeaponEnchantInfo = function() return false, 0, 0, 0, false, 0, 0, 0 end
  local fight = false
  UnitExists = function(u) return u == "player" end
  UnitCanAttack = function() return false end
  UnitIsDeadOrGhost = function() return false end
  InCombatLockdown = function() return fight end
  UnitAffectingCombat = function() return fight end
  C_SpellBook, GetSpellBaseCooldown, C_CooldownViewer = nil, nil, nil
  local inside, kind = false, "none"
  IsInInstance = function() return inside, kind end
  local function fresh(cfg)
    VoltUIDB.timerCfg = cfg
    T.cfgFilled, T.zone = nil, nil
    T.items = {}
    T:Collect()
    T:Refresh()
    T:UpdateAll()
  end
  local function shown(it) return it.w ~= nil and it.w.shown == true end

  -- an empty list to begin with
  fresh(nil)
  check(T.AUTO_LIST == false and #T:Mine() == 0 and #T:Available() >= 6, "nothing is a timer until you add it; what VoltUI found waits to be added")
  local ls = T:Find("keep:324")
  check(ls and ls.hidden and not ls.listed and not shown(ls), "so nothing shows")
  check(T.holders.buffs == nil or not T.holders.buffs.shown, "and the blocks are empty")

  -- a set-up from before 1.102.0
  fresh({ buffs = { size = 52 }, hidden = { ["cd:421"] = true }, readyHide = true, buffHide = true, buffSoon = 30,
    warnFight = false, warnIdle = true, missIdle = false, pulse = false })
  local cfg = T:Cfg()
  check(next(cfg.auras) == nil and cfg.buffs.size == 52 and cfg.buffs.gap == 4 and cfg.hidden["cd:421"] and cfg.buffSoon == 30,
    "an older set-up: the list starts empty, and everything that was set is still there")
  check(T:Add("keep:324") and T:Add("cd:421") and not T:Add("no:such"), "adding from what was found")
  ls = T:Find("keep:324")
  local cl = T:Find("cd:421")
  check(ls.listed and not ls.hidden and #T:Mine() == 2, "they're your timers now")
  check(T:Opt(ls, "size") == 52 and T:Opt(ls, "up") == "hide" and T:Opt(ls, "soon") == 30 and T:Opt(ls, "miss") == "faded"
    and T:Opt(ls, "missOut") == "flash" and T:Opt(ls, "pulse") == false,
    "a timer you add starts from what was set before: its block's size, hidden while up, no flash in a fight, a flash out of one")
  check(T:Opt(cl, "ready") == "hide" and T:Opt(cl, "when") == "always" and T:Opt(cl, "raid") == true, "a cooldown: hidden while ready as before, everywhere, all the time")

  -- a new set-up, three timers
  fresh(nil)
  T:Add("keep:324")
  T:Add("cd:8042")
  T:Add("cd:421")
  ls, cl = T:Find("keep:324"), T:Find("cd:421")
  local shocks = T:Find("cd:8042")
  check(shown(cl) and shown(shocks), "an added cooldown shows")
  check(not shown(ls) and T:Missing(ls) == "hide", "a missing buff stays out of sight out of a fight, as before")
  check(T:Summary(cl) == "All the time, everywhere", "its line in the list: " .. T:Summary(cl))

  -- its own size and shape
  T:G("cds").grow = "right"
  check(T:SetOpt("cd:421", "size", 60) and T:Cfg().auras["cd:421"].size == 60 and not T:SetOpt("cd:8050", "size", 60), "a timer in your list takes a size of its own")
  check(cl.w.w == 60 and shocks.w.w == T:G("cds").size, "its own size; the other keeps its block's")
  check(cl.w.points[1][4] == T:G("cds").size + T:G("cds").gap and T.holders.cds.h == 60, "laid out by each one's size: after the smaller one, the block as tall as the bigger")
  T:SetOpt("cd:421", "size", T:G("cds").size)
  check(T:Cfg().auras["cd:421"].size == nil, "put back to its block's size, it follows the block again")
  T:SetOpt("cd:421", "style", "bars")
  check(cl.w.style == "bars" and cl.w.bar and shocks.w.style == "icons" and cl.w.w == T:G("cds").width and T:Summary(cl) == "Bar", "one timer as a bar among icons")
  T:SetOpt("cd:421", "style", nil)
  check(cl.w.style == "icons", "and back")

  -- when: in a fight, out of one
  T:SetOpt("cd:421", "when", "combat")
  check(not shown(cl) and shown(shocks) and T:Summary(cl) == "In a fight", "In a fight: not shown out of one")
  fight = true
  T:OnEvent("PLAYER_REGEN_DISABLED")
  check(shown(cl), "shown in one")
  T:SetOpt("cd:421", "when", "idle")
  check(not shown(cl), "Out of a fight: not shown in one")
  fight = false
  T:OnEvent("PLAYER_REGEN_ENABLED")
  runTimers()
  check(shown(cl), "shown out of one")
  T:SetOpt("cd:421", "when", nil)

  -- where: a switch for each kind of place
  check(T:Zone() == "world", "no instance: the open world")
  T:SetOpt("cd:421", "dungeon", false)
  check(shown(cl), "not in dungeons: still shown outside")
  inside, kind = true, "party"
  T:OnEvent("ZONE_CHANGED_NEW_AREA")
  runTimers()
  check(T:Zone() == "dungeon" and not shown(cl) and shown(shocks), "in a dungeon it's gone; the others stay")
  kind = "raid"
  T:OnEvent("PLAYER_ENTERING_WORLD")
  runTimers()
  check(T:Zone() == "raid" and shown(cl), "in a raid it's back")
  kind = "arena"
  T.zone = nil
  check(T:Zone() == "pvp", "arenas count as battlegrounds")
  kind = "scenario"
  T.zone = nil
  check(T:Zone() == "dungeon", "scenarios as dungeons")
  inside, kind = false, "none"
  T.zone = nil
  ls, cl, shocks = T:Find("keep:324"), T:Find("cd:421"), T:Find("cd:8042") -- a new zone reads the spells again
  check(T:Summary(cl) == "Open world, Raids, Battlegrounds", "its line says where: " .. T:Summary(cl))
  T:SetOpt("cd:421", "dungeon", nil)

  -- a cooldown while it's ready
  T:SetOpt("cd:421", "ready", "hide")
  check(not shown(cl) and shown(shocks), "While it's ready, Hide: this one only")
  T:SetOpt("cd:421", "ready", nil)

  -- a missing buff: flash, faded or hidden, in a fight and out of one
  T:SetOpt("keep:324", "missOut", "faded")
  check(shown(ls) and not ls.w.flashing and ls.w.body.alpha < 1, "Missing, out of a fight, Faded: there and grey")
  T:SetOpt("keep:324", "missOut", "flash")
  check(shown(ls) and ls.w.flashing, "Flash: it flashes")
  T:SetOpt("keep:324", "missOut", nil)
  fight = true
  T:OnEvent("PLAYER_REGEN_DISABLED")
  check(shown(ls) and ls.w.flashing, "in a fight it flashes to begin with")
  T:SetOpt("keep:324", "miss", "hide")
  check(not shown(ls), "Missing, in a fight, Hide")
  T:SetOpt("keep:324", "miss", "faded")
  check(shown(ls) and not ls.w.flashing, "Faded")
  T:SetOpt("keep:324", "miss", nil)
  fight = false
  T:OnEvent("PLAYER_REGEN_ENABLED")
  runTimers()
  -- and while it's up
  auras.player[1] = { name = "Lightning Shield", icon = "ls", applications = 3, duration = 600, expirationTime = clock + 600, auraInstanceID = 41 }
  T:UpdateAuras("player")
  check(ls.st.on and shown(ls), "up: shown")
  T:SetOpt("keep:324", "up", "hide")
  check(not shown(ls) and T:Summary(ls):find("nly when it needs recasting", 1, true), "While it's up, Hide: " .. T:Summary(ls))
  T:SetOpt("keep:324", "soon", 900)
  check(shown(ls), "until its own last seconds")
  T:SetOpt("keep:324", "soon", nil)
  T:SetOpt("keep:324", "up", nil)
  auras.player[1] = nil
  T:UpdateAuras("player")

  -- another block
  T:SetOpt("cd:421", "group", "buffs")
  check(cl.group == "buffs" and cl.w.group == "buffs" and cl.w.parent == T.holders.buffs and T:Opt(cl, "size") == T:G("buffs").size,
    "moved to another block it's drawn there, at that block's size")
  T:SetOpt("cd:421", "group", "nowhere")
  check(cl.group == "cds", "a block that isn't one is ignored")
  T:SetOpt("cd:421", "group", nil)

  -- one timer's look for its whole block
  T:SetOpt("cd:421", "size", 44)
  T:SetOpt("cd:421", "numbers", 20)
  T:SetOpt("cd:8042", "size", 30)
  local n = T:CopyLook("cd:421")
  check(n == 1 and T:G("cds").size == 44 and T:G("cds").numbers == 20 and T:Cfg().auras["cd:421"].size == nil and T:Cfg().auras["cd:8042"].size == nil
    and T:Opt(shocks, "size") == 44 and shocks.w.w == 44, "Copy look: the block takes it, and the others stop having their own")

  -- off, reset, remove
  T:SetOpt("cd:421", "when", "combat")
  T:SetOn("cd:421", false)
  check(cl.hidden and cl.listed and not shown(cl) and T:Opt(cl, "when") == "combat", "switched off: still yours, its settings kept")
  T:SetOn("cd:421", true)
  check(not cl.hidden and T:Cfg().auras["cd:421"].on == nil, "and on again")
  T:Reset()
  cl = T:Find("cd:421")
  check(cl.listed and T:Opt(cl, "when") == "always" and T:G("cds").size == T.DEFAULTS.cds.size and #T:Mine() == 3, "Reset: every setting back, your list stays")
  T:Remove("cd:421")
  check(not T:Find("cd:421").listed and T:Cfg().auras["cd:421"] == nil and #T:Mine() == 2, "Remove takes it out of your list")
  local ok, name, key = T:AddCustom("proc", "2825")
  check(ok and name == "Bloodlust" and key == "custom:proc:2825" and T:Find(key).listed, "a spell of your own is a timer straight away")
  ok, name, key = T:AddCustom("cd", "421")
  check(ok and key == "cd:421" and T:Find("cd:421").listed and #T:Cfg().custom == 1, "one VoltUI knows, typed in: that one joins your list")
  ok, name = T:AddCustom("cd", "421")
  check(not ok and name:find("already in the list", 1, true), "not twice")
  T:Remove("custom:proc:2825")
  check(not T:Find("custom:proc:2825") and #T:Cfg().custom == 0, "removing your own spell forgets it")
  local waiting = #T:Available()
  check(waiting > 0 and T:AddAll() == waiting and #T:Available() == 0, "Add them all")

  -- followed in a fight: the game's Cooldown Manager, by timer
  ls, shocks = T:Find("keep:324"), T:Find("cd:8042")
  check(T:Follow(ls) == "none" and T:Follow(shocks) == nil, "no Cooldown Manager on the client; a cooldown has nothing to follow")
  C_CooldownViewer = {}
  T.ManagerOn = function() return false end
  check(T:Follow(ls) == "off", "the manager off")
  T.ManagerOn = function() return true end
  T.TrackList = function() return { { id = 7, name = "Lightning Shield", on = false } } end
  local f = T:Follow(ls)
  check(type(f) == "table" and not f.on and #f.entries == 1 and f.entries[1].id == 7, "a buff the game can follow, and isn't")
  local followed, total, missing = T:FollowCount()
  check(followed == 0 and total >= 1 and missing[1] == "Lightning Shield", "counted for the page's fight card")
  T.TrackList = function() return { { id = 7, name = "Lightning Shield", on = true } } end
  check(T:Follow(ls).on == true, "followed")
  T.TrackList = function() return {} end
  check(T:Follow(ls) == "cant", "one the game doesn't offer")
  T.ManagerOn, T.TrackList = oldOn, oldList
  C_CooldownViewer = nil

  -- the page: your timers first
  T:Remove("cd:8042")
  Ed.timerView, Ed.timerKey = nil, nil
  Ed:Open("timers")
  local function rowWith(field) for _, r in ipairs(Ed.rows) do if r[field] then return r end end end
  local function count(list) local c = 0 for _, b in ipairs(list) do if b.shown then c = c + 1 end end return c end
  local page = Ed.pages.timers
  local mine = rowWith("entries")
  check(page.shape == "list" and mine ~= nil and count(mine.entries) == #T:Mine() and not mine.none.shown and not mine.add.shown,
    "the page opens on your timers, an entry each")
  local e1 = mine and mine.entries[1]
  if e1 then
    check(e1.name.text == e1.item.name and e1.sum.text:find(T.KIND_LONG[e1.item.kind], 1, true) and e1.on.text.text == "On" and e1.edit ~= nil,
      "an entry: its name, a line on what it is and when it shows, a switch and Edit: " .. tostring(e1.sum.text))
    e1.on.scripts.OnClick(e1.on)
    check(e1.item.hidden and e1.on.text.text == "Off" and e1.item.listed, "its switch turns it off without removing it")
    e1.on.scripts.OnClick(e1.on)
    check(not e1.item.hidden and e1.on.text.text == "On", "and on")
  end
  local card = page.cards[1]
  check(card.action ~= nil and card.action.text.text == "+ Add a timer", "Add a timer on the list's heading")
  local tall = card.h
  T:Remove("totem:4")
  Ed:RefreshPage()
  check(card.h < tall and count(mine.entries) == #T:Mine(), "the list's card is as tall as its list")

  -- add: pick one, land on its settings
  card.action.scripts.OnClick(card.action)
  check(Ed.timerView == "add" and Ed.pages.timers.shape == "add", "Add a timer shows what's left to add")
  local pick = rowWith("tiles")
  check(pick ~= nil and count(pick.tiles) == #T:Available() and count(pick.tiles) == 2, "a tile for each spell found that isn't a timer yet")
  local tile
  for _, b in ipairs(pick and pick.tiles or {}) do if b.shown and b.item.key == "cd:8042" then tile = b end end
  check(tile ~= nil and tile.name.text == "Shocks" and tile.icon.tex == "icon8042", "with its icon and name")
  if tile then tile.scripts.OnClick(tile) end
  check(T:Find("cd:8042").listed and Ed.timerView == "edit" and Ed.timerKey == "cd:8042" and Ed.pages.timers.shape == "edit:cd:icons",
    "a click adds it and opens its own settings")

  -- edit: one timer's settings
  local rows = {}
  for _, r in ipairs(Ed.rows) do if r.def.key then rows[r.def.key] = r end end
  check(rows.on and rows.when and rows.world and rows.dungeon and rows.raid and rows.pvp and rows.ready and rows.style and rows.size and rows.numbers
    and rows.pulse and rows.usable and rows.group and not rows.width and not rows.miss, "a cooldown's settings: when, where, while ready, its look")
  local hero = rowWith("sub")
  check(hero and hero.name.text == "Shocks" and hero.sub.text:find("Cooldown", 1, true) and hero.sub.text:find("Cooldowns", 1, true), "under its name and kind")
  local it = T:Find("cd:8042")
  rows.when:Set("combat")
  check(T:Cfg().auras["cd:8042"].when == "combat" and rows.when.changed and not shown(it), "Show, In a fight: kept on this timer, and marked as changed")
  rows.raid:Set(false)
  check(T:Opt(it, "raid") == false and T:Opt(T:Find("cd:421"), "raid") == true, "In raids off, for this timer only")
  rows.when:Set("always")
  rows.size:Set(48)
  check(T:Cfg().auras["cd:8042"].size == 48 and T:Opt(T:Find("cd:421"), "size") == T:G("cds").size, "its own size")
  rows.style:Set("bars")
  check(Ed.pages.timers.shape == "edit:cd:bars", "as a bar, the page shows a bar's sizes")
  rows = {}
  for _, r in ipairs(Ed.rows) do if r.def.key then rows[r.def.key] = r end end
  check(rows.width and rows.height and not rows.size, "width and height in place of size")
  rows.style:Set("icons")
  rows = {}
  for _, r in ipairs(Ed.rows) do if r.def.key then rows[r.def.key] = r end end
  rows.on:Set(false)
  check(it.hidden and it.listed, "Show this timer off")
  rows.on:Set(true)
  -- a buff's settings are a buff's
  ns.Pages.TimerGo("edit", "keep:324")
  rows = {}
  for _, r in ipairs(Ed.rows) do if r.def.key then rows[r.def.key] = r end end
  check(Ed.pages.timers.shape == "edit:keep:icons" and rows.up and rows.soon and rows.miss and rows.missOut and not rows.ready and not rows.usable,
    "a buff: while it's up, missing in a fight, missing out of one")
  local follow = rowWith("hint")
  check(follow ~= nil and follow.state.text == "No" and not follow.button.shown, "and whether the game follows it in a fight: " .. tostring(follow and follow.hint.text))
  check(rows.soon:Off() and rows.soon.def.whyOff ~= nil, "the last seconds wait for While it's up, Hide")
  rows.up:Set("hide")
  check(not rows.soon:Off() and T:Opt(T:Find("keep:324"), "up") == "hide", "then it can be set")
  rows.up:Set("show")
  -- back, and the blocks
  local back = Ed.pages.timers.cards[1].action
  check(back ~= nil and back.text.text == "Back to list", "Back to list on the first card")
  back.scripts.OnClick(back)
  check(Ed.timerView == "list" and Ed.pages.timers.shape == "list", "back at your timers")
  ns.Pages.TimerGo("layout")
  rows = {}
  for _, r in ipairs(Ed.rows) do if r.def.key then rows[r.def.key] = r end end
  check(Ed.pages.timers.shape == "layout" and rows.perRow and rows.gap and rows.grow and rows.scale and rows.idleAlpha and not rows.size,
    "the blocks: rows, gaps and direction, and what goes for every timer")
  -- a timer that's gone: the page falls back to the list
  ns.Pages.TimerGo("edit", "cd:8042")
  T:Remove("cd:8042")
  check(ns.Pages.TimerView() == "list", "editing a timer that's no longer yours: the list")
  -- the search looks through the settings that aren't one timer's own
  local search = ns.Pages.byKey.timers.searchSections()
  local keys = {}
  for _, sec in ipairs(search) do
    for _, row in ipairs(sec) do if row.key then keys[row.key] = row.store or "group" end end
  end
  check(#search == 3 and keys.perRow == "group" and keys.scale == "timers" and keys.hideManager == "timers" and keys.when == nil and search[1].action == nil,
    "search: the blocks and the fight card, never one timer's rows")
  -- the empty list says what to do
  for _, m in ipairs(T:Mine()) do T:Cfg().auras[m.key] = nil end
  T:Relist()
  ns.Pages.TimerGo("list")
  mine = rowWith("entries")
  check(mine and mine.none.shown and mine.add.shown and count(mine.entries) == 0, "an empty list says what a timer is, with a button to add one")
  mine.add.scripts.OnClick(mine.add)
  check(Ed.timerView == "add", "which opens Add a timer")

  Ed.timerView, Ed.timerKey = nil, nil
  Ed:Close()
  for k, v in pairs(saved) do _G[k] = v[1] end
  VoltUIDB.timerCfg = nil
  T.cfgFilled, T.zone = nil, nil
  T.items = {}
  T:Refresh()
end)()

-- 1.103.0: what another add-on can hook into
;(function()
  local FUI, W, P = ns.FUI, ns.WorldMap, ns.Pages
  check(_G.VoltUI.ns == ns and type(ns.Extra) == "table", "VoltUI's parts and the extra-data slot are there for another add-on")
  -- settings: added to the defaults and to what's saved, without touching a saved one
  VoltUIDB.hookTestB = false
  FUI:AddDefaults({ hookTestA = 7, hookTestB = true })
  check(FUI.defaults.hookTestA == 7 and VoltUIDB.hookTestA == 7 and VoltUIDB.hookTestB == false, "AddDefaults fills in, keeps what's saved")
  FUI.defaults.hookTestA, FUI.defaults.hookTestB, VoltUIDB.hookTestA, VoltUIDB.hookTestB = nil, nil, nil, nil
  -- /volt words
  local got
  FUI.slash.hooktest = function(arg) got = arg end
  SlashCmdList.VOLTUI("hooktest some words")
  check(got == "some words", "an added /volt word gets what follows it")
  FUI.slash.hooktest = nil
  -- a map layer: drawn with the map, its credit shown when it drew something
  local drew = 0
  local layer = { key = "hook", slash = "hook", Draw = function() drew = drew + 1; return true end,
    credit = function() return "Hook credit" end, Toggle = function() got = "toggled" end }
  W:AddLayer(layer)
  W:AddLayer(layer)
  local count = 0
  for _, l in ipairs(W.layers) do if l == layer then count = count + 1 end end
  check(count == 1, "a layer is added once")
  if W.enabled then
    W:Draw()
    check(drew >= 1, "the map draws it")
  end
  SlashCmdList.VOLTUI("worldmap hook")
  check(got == "toggled", "/volt worldmap <its word> goes to it")
  for i, l in ipairs(W.layers) do if l == layer then table.remove(W.layers, i) break end end
  -- a page's extra card
  local before = #P.byKey.maps.sections()
  P.Extend("maps", function() return { { title = "Hook card", { kind = "note", text = "x" } } } end)
  local after = P.byKey.maps.sections()
  check(#after == before + 1 and after[#after].title == "Hook card", "a page shows another add-on's card after its own")
  -- a whole page, as tabs with another
  local nPages = #P.list
  P.AddPage({ key = "hookpage", title = "Hook page", group = "World", sections = function() return { { title = "Hook", { kind = "note", text = "x" } } } end }, "maps")
  P.AddPage({ key = "hookpage", title = "Hook page", group = "World", sections = function() return {} end }, "maps")
  local at
  for i, pg in ipairs(P.list) do if pg.key == "hookpage" then at = i end end
  check(#P.list == nPages + 1 and P.list[at - 1].key == "maps" and P.byKey.hookpage, "a page goes after the one asked, and only once")
  P.AddTab({ key = "hooktabs", title = "Hook tabs", pages = { "hookpage" } })
  check(P.tabOf.hookpage and P.tabOf.hookpage.title == "Hook tabs", "and can share a sidebar entry")
  table.remove(P.list, at)
  P.byKey.hookpage, P.tabOf.hookpage = nil, nil
  table.remove(P.TABS)
  P.reloadKeys = nil
  -- where the map's labels sit: another add-on can swap how they're lifted
  local f, cv = new("Frame"), new("Frame")
  W.LiftLabels(f, cv)
  check(f:GetFrameLevel() == cv:GetFrameLevel() + 40, "the zone labels sit over the map's own layers")
  -- a loot record for "Drops from" on item tooltips
  local had = FUI.dropRecord
  FUI:SetDropRecord(function() return { n1 = { name = "Hook mob", loots = 2, it = { ["77001"] = { seen = 1 } } } } end)
  local list = ns.Tooltips:DropsFor(77001)
  check(list and list[1] and list[1].name == "Hook mob" and list[1].chance == 0.5, "another add-on's loot record fills Drops from")
  FUI:SetDropRecord(nil)
  check(ns.Tooltips:DropsFor(77001) == nil, "and with none there are no drop lines")
  FUI:SetDropRecord(had)
  -- noted data kept out of profiles: remembered for the next load, and brought back out of a profile it went into
  local Pr = ns.Profiles
  local pdb = { profiles = { Alt = { hookNotes = { a = 1 }, alpha = 0.5 } }, profileOf = {}, activeProfile = "Default" }
  Pr.AddData({ "hookNotes" }, pdb)
  check(Pr.DATA.hookNotes and pdb.dataKeys.hookNotes and pdb.hookNotes and pdb.hookNotes.a == 1 and pdb.profiles.Alt.hookNotes == nil,
    "Profiles.AddData keeps another add-on's notes out of profiles, and brings back what went in")
  Pr.DATA.hookNotes = nil
  pdb.profileOf["Hook-Realm"] = "Alt"
  check(Pr:Load(pdb, "Hook-Realm", {}) == true and pdb.hookNotes and pdb.hookNotes.a == 1 and Pr.DATA.hookNotes,
    "and at the next load, before that add-on is back, a profile swap leaves them where they are")
  Pr.DATA.hookNotes = nil
  Extra("hooks") -- another add-on's tests, since VoltUI 1.104.0
end)()

for _, m in ipairs(chat) do print("  chat: " .. m) end
print(string.format("\n%d passed, %d failed", passed, failed))
