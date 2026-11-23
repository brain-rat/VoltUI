-- VoltUI · Tooltips
-- Every tooltip in the flat dark style, with a border in the item's rarity
-- colour, a thin health bar, the VoltUI font, and a few extra lines on items:
--   * item level on gear (when the game doesn't show it)
--   * vendor price (when the game doesn't show it)
--   * which mobs and nodes it drops from, from another add-on's record of your play
--     (FUI:SetDropRecord)
-- Another add-on can add lines under creatures (T:AddUnitLines).

local _, ns = ...
local FUI, S = ns.FUI, ns.Style

local T = { key = "tooltips", name = "Tooltips", styled = {} }
ns.Tooltips = T
-- (1.86.0) A small gold square before the headings VoltUI adds to a tooltip, as in its own windows.
T.MARK = "|TInterface\\Buttons\\WHITE8X8:6:6:0:0:8:8:0:8:0:8:255:198:26|t "

local floor, max, min = math.floor, math.max, math.min

local NAMES = {
  "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2",
  "ItemRefShoppingTooltip1", "ItemRefShoppingTooltip2", "EmbeddedItemTooltip",
  "WorldMapTooltip", "WorldMapCompareTooltip1", "WorldMapCompareTooltip2",
  "FriendsTooltip", "SmallTextTooltip", "NamePlateTooltip", "QuestScrollTooltip",
}

local function Secret(v) return issecretvalue and issecretvalue(v) end

-- Keep something faded even if the game sets its alpha again.
local function KeepFaded(obj)
  if type(obj) ~= "table" or not obj.SetAlpha then return end
  obj:SetAlpha(0)
  if obj.fuiFaded then return end
  obj.fuiFaded = true
  hooksecurefunc(obj, "SetAlpha", function(self, a) if a ~= 0 then self:SetAlpha(0) end end)
end

local function Border(tip, r, g, b, a)
  local p = tip.fuiPanel
  if p then S.ColorEdges(p.edges, r, g, b, a) end
end

local function ResetBorder(tip)
  Border(tip, S.UI.edge[1], S.UI.edge[2], S.UI.edge[3], 1)
end

function T:Style(tip)
  if type(tip) ~= "table" or tip.fuiStyled then return end
  tip.fuiStyled = true
  KeepFaded(tip.NineSlice)
  if tip.SetBackdropColor then
    pcall(tip.SetBackdropColor, tip, 0, 0, 0, 0)
    pcall(tip.SetBackdropBorderColor, tip, 0, 0, 0, 0)
    if tip.SetBackdrop and not tip.NineSlice then
      hooksecurefunc(tip, "SetBackdropColor", function(self, _, _, _, a)
        if a and a > 0 then self:SetBackdropColor(0, 0, 0, 0) end
      end)
    end
  end
  S.ThemePanel(tip, max(ns.db.alpha, 0.9))
  ResetBorder(tip)
  tip:HookScript("OnShow", function(self)
    if self.SetBackdropColor and not self.NineSlice then
      pcall(self.SetBackdropColor, self, 0, 0, 0, 0)
      pcall(self.SetBackdropBorderColor, self, 0, 0, 0, 0)
    end
    if not self.fuiRarity then ResetBorder(self) end
  end)
  tip:HookScript("OnHide", function(self) self.fuiRarity, self.fuiLootStamp, self.fuiUnitStamp = nil, nil, nil end)
  if tip.HasScript and tip:HasScript("OnTooltipCleared") then
    tip:HookScript("OnTooltipCleared", function(self)
      self.fuiRarity, self.fuiLootStamp, self.fuiUnitStamp = nil, nil, nil
      ResetBorder(self)
    end)
  end
  table.insert(self.styled, tip)
end

function T:StyleBar()
  local bar = _G.GameTooltipStatusBar
  if not bar or bar.fuiStyled then return end
  bar.fuiStyled = true
  S.UseBarTexture(bar)
  bar:SetHeight(4)
  bar:ClearAllPoints()
  bar:SetPoint("TOPLEFT", GameTooltip, "BOTTOMLEFT", 1, -2)
  bar:SetPoint("TOPRIGHT", GameTooltip, "BOTTOMRIGHT", -1, -2)
  local bg = S.Tex(bar, "BACKGROUND", -8)
  bg:SetPoint("TOPLEFT", -1, 1)
  bg:SetPoint("BOTTOMRIGHT", 1, -1)
  bg:SetColorTexture(S.UI.bg[1], S.UI.bg[2], S.UI.bg[3], 0.9)
  for _, r in ipairs({ bar:GetRegions() }) do
    if r ~= bg and r.IsObjectType and r:IsObjectType("Texture") and r ~= bar:GetStatusBarTexture() then r:SetAlpha(0) end
  end
  if bar.BorderLeft then KeepFaded(bar.BorderLeft) end
  -- Health as text on the bar (1.101.17). The game redraws the bar through its own
  -- UpdateUnitHealth on this client; older ones only change the bar's value.
  local text = S.Text(bar, nil, "CENTER", "OVERLAY")
  text:SetPoint("CENTER", bar, "CENTER", 0, 0)
  self.barText = text
  local again = function() T:BarText() end
  if type(bar.UpdateUnitHealth) == "function" then hooksecurefunc(bar, "UpdateUnitHealth", again) end
  bar:HookScript("OnValueChanged", again)
  bar:HookScript("OnShow", again)
  self:BarLook()
end

T.HEALTH = { { key = "off", name = "Off" }, { key = "percent", name = "Percent" }, { key = "number", name = "Number" } }

-- The bar is a thin line without text, and tall enough to hold a line of it with.
function T:BarLook()
  local bar = _G.GameTooltipStatusBar
  if not bar or not self.barText then return end
  local on = ns.db.tipHealth == "percent" or ns.db.tipHealth == "number"
  bar:SetHeight(on and 12 or 4)
  S.FixFont(self.barText, 10, nil, nil, "mono")
  self.barText:SetShown(on)
  self:BarText()
end

-- The unit a tooltip is about. The game's answer can be hidden; then it's the one under the mouse.
local function TipUnit(tip)
  local unit
  if tip and tip.GetUnit then
    local ok, _, u = pcall(tip.GetUnit, tip)
    if ok and u and not Secret(u) then unit = u end
  end
  if not unit and UnitExists then
    local ok, there = pcall(UnitExists, "mouseover")
    if ok and not Secret(there) and there then unit = "mouseover" end
  end
  return unit
end
T.TipUnit = TipUnit

-- Health numbers can be hidden from add-ons; the game's own formatters take them as they
-- are, so nothing here does sums or compares them unless they can be read.
function T:BarText()
  local text, mode = self.barText, ns.db and ns.db.tipHealth
  if not text or (mode ~= "percent" and mode ~= "number") then return end
  local unit = TipUnit(GameTooltip)
  if not unit then return text:SetText("") end
  local ok = pcall(function()
    local cur, maxv = UnitHealth(unit), UnitHealthMax(unit)
    local dead = UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit)
    if not Secret(dead) and dead then return text:SetText(_G.DEAD or "Dead") end
    if mode == "percent" then
      text:SetFormattedText("%s%%", S.HealthPercent(unit, cur, maxv))
    else
      text:SetFormattedText("%s / %s", S.ShortNum(cur), S.ShortNum(maxv))
    end
  end)
  if not ok then text:SetText("") end
end

function T:Fonts()
  -- the font objects every tooltip uses
  local size = max(9, min(20, tonumber(ns.db.tipSize) or 13))
  if _G.GameTooltipHeaderText then S.SetFont(_G.GameTooltipHeaderText, size + 2, nil, "tooltips") end
  if _G.GameTooltipText then S.SetFont(_G.GameTooltipText, size, nil, "tooltips") end
  if _G.GameTooltipTextSmall then S.SetFont(_G.GameTooltipTextSmall, size - 1, nil, "tooltips") end
end

------------------------------------------------------------------------
-- Where tooltips show, and extras on unit tooltips (since 1.43.0)
------------------------------------------------------------------------

T.ANCHORS = { { key = "game", name = "Game's" }, { key = "cursor", name = "Cursor" }, { key = "spot", name = "Its spot" } }

-- The box that marks the tooltip's own spot: a tooltip's bottom-right corner sits on the box's.
-- It's dragged while moving frames (Move.lua has its stand-in).
function T:SpotFrame()
  local f = self.spot
  if not f then
    f = CreateFrame("Frame", "VoltUITooltipSpot", UIParent)
    f:SetSize(220, 90)
    f:Hide()
    self.spot = f
    self:PlaceSpot()
  end
  return f
end

-- Puts the box at its saved spot. Once when it's made, and again when Move frames moves it:
-- not on every tooltip.
function T:PlaceSpot()
  local f = self.spot
  if not f then return end
  if not S.PlaceSpot(f, ns.db, "tipLeft", "tipTop", "tipPoint") then
    f:ClearAllPoints()
    f:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -80, 160)
  end
end

-- Runs after the game has put a tooltip in its default place (things in the world, mostly:
-- units and objects under the mouse). Buttons and items that anchor their own tooltips are
-- left alone.
function T:Anchor(tip, parent)
  local mode = ns.db.tipAnchor
  if mode ~= "cursor" and mode ~= "spot" then return end
  if not tip or not tip.SetOwner or (tip.IsForbidden and tip:IsForbidden()) then return end
  if mode == "cursor" then
    tip:SetOwner(parent or UIParent, "ANCHOR_CURSOR")
  else
    tip:SetOwner(parent or UIParent, "ANCHOR_NONE")
    tip:ClearAllPoints()
    tip:SetPoint("BOTTOMRIGHT", self:SpotFrame(), "BOTTOMRIGHT", 0, 0)
  end
end

-- A player's name in their class colour, who a unit is targeting, and no tooltips for units in
-- the world while you fight. Names can be secret here, so they're only ever handed on.
function T:UnitExtras(tip, unit)
  local db = ns.db
  if not tip or not tip.fuiStyled or tip.fuiUnitStamp then return end
  if not unit and tip.GetUnit then unit = select(2, tip:GetUnit()) end
  if Secret(unit) or not unit then return end
  tip.fuiUnitStamp = true
  if db.tipCombat and InCombatLockdown() and unit == "mouseover" then
    local owner = tip.GetOwner and tip:GetOwner()
    if owner == nil or owner == UIParent or owner == WorldFrame then
      tip:Hide()
      return true -- hidden: nothing more is added to it
    end
  end
  if db.tipClass and S.Safe(UnitIsPlayer(unit)) == true then
    local _, class = UnitClass(unit)
    local c = not Secret(class) and class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    local line = _G[(tip.GetName and tip:GetName() or "GameTooltip") .. "TextLeft1"]
    if c and line and line.SetTextColor then line:SetTextColor(c.r, c.g, c.b) end
  end
  if db.tipTarget then
    local target = unit .. "target"
    if S.Safe(UnitExists(target)) == true then
      if S.Safe(UnitIsUnit(target, "player")) == true then
        tip:AddDoubleLine("Targeting", "You", 0.55, 0.55, 0.55, S.UI.accent[1], S.UI.accent[2], S.UI.accent[3])
      else
        local name = UnitName(target)
        if S.Present(name) then tip:AddDoubleLine("Targeting", name, 0.55, 0.55, 0.55, 1, 1, 1) end
      end
      tip:Show() -- the tooltip grows to fit the new line
    end
  end
end

------------------------------------------------------------------------
-- Extra item lines
------------------------------------------------------------------------

local function HasLine(tip, pattern, plain)
  local name = tip.GetName and tip:GetName()
  if not name then return false end
  for i = 1, (tip.NumLines and tip:NumLines() or 0) do
    local fs = _G[name .. "TextLeft" .. i]
    local t = fs and fs:GetText()
    if t and not Secret(t) and t:find(pattern, 1, plain) then return true end
  end
  return false
end

local function Money(c)
  c = floor((c or 0) + 0.5)
  if GetCoinTextureString then return GetCoinTextureString(c) end
  return ("%dg %ds %dc"):format(floor(c / 10000), floor(c / 100) % 100, c % 100)
end

-- itemID -> { {name, chance, loots}, ... } from another add-on's drop record, rebuilt now and then.
local dropIndex, dropBuilt, dropLoots, dropFrom = nil, 0, -1, nil
function T:DropsFor(itemID)
  local drops = FUI.dropRecord and FUI.dropRecord()
  if not drops then return nil end
  local now = GetTime()
  if not dropIndex or now - dropBuilt > 30 or drops ~= dropFrom then
    local total = 0
    for _, d in pairs(drops) do total = total + (d.loots or 0) end
    if total ~= dropLoots or not dropIndex or drops ~= dropFrom then
      dropIndex = {}
      for key, d in pairs(drops) do
        local loots = d.loots or 0
        if loots > 0 then
          for ikey, it in pairs(d.it or {}) do
            local id = tonumber(tostring(ikey):match("^(%d+)"))
            if id then
              dropIndex[id] = dropIndex[id] or {}
              local name = (d.name or "?"):gsub("^Node: ", "")
              -- chests and other objects by their own name, not their first item (ns.TreasureData, when
              -- another add-on gives it)
              local oid = key:sub(1, 1) == "o" and tonumber(key:sub(2))
              if oid and ns.TreasureData and ns.TreasureData[oid] then name = ns.TreasureData[oid][1] end
              table.insert(dropIndex[id], { name = name, chance = (it.seen or 0) / loots, loots = loots, node = key:sub(1, 1) == "o" })
            end
          end
        end
      end
      for _, list in pairs(dropIndex) do
        table.sort(list, function(a, b)
          if a.chance ~= b.chance then return a.chance > b.chance end
          return a.loots > b.loots
        end)
      end
      dropLoots = total
    end
    dropBuilt, dropFrom = now, drops
  end
  return dropIndex[itemID]
end

local function Instant(link)
  local fn = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
  if fn then return fn(link) end
end

function T:OnItem(tip, link)
  if not tip or not tip.fuiStyled or not link or Secret(link) then return end
  local info = C_Item and C_Item.GetItemInfo or GetItemInfo
  local name, _, quality, ilvl, _, _, _, _, _, _, sell = info(link)
  local id, _, _, _, _, classID = Instant(link)
  if quality then
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if c and quality ~= 1 then
      tip.fuiRarity = quality
      Border(tip, c.r, c.g, c.b, 1)
    end
  end
  local db = ns.db
  local added = false
  if db.tipIlvl and ilvl and ilvl > 1 and (classID == 2 or classID == 4) and not HasLine(tip, "Item Level") then
    tip:AddLine("Item level " .. ilvl, 0.85, 0.85, 0.85)
    added = true
  end
  -- The game's own price: a money frame on older clients, a plain "Sell Price: ..." line on
  -- this one (GameTooltip_OnTooltipAddMoney), so both are looked for.
  local gamePrice = (tip.shownMoneyFrames and tip.shownMoneyFrames > 0)
    or (type(SELL_PRICE) == "string" and SELL_PRICE ~= "" and HasLine(tip, SELL_PRICE .. ":", true))
  if db.tipVendor and sell and sell > 0 and not gamePrice then
    tip:AddDoubleLine("Vendor", Money(sell), 0.75, 0.75, 0.75, 1, 1, 1)
    added = true
  end
  if db.tipDrops and id then
    local list = self:DropsFor(id)
    if list and #list > 0 then
      tip:AddLine(T.MARK .. "Drops from (your loot record)", S.UI.accent[1], S.UI.accent[2], S.UI.accent[3])
      for i = 1, math.min(3, #list) do
        local d = list[i]
        local pct = d.chance >= 0.995 and "100%" or (d.chance >= 0.1 and ("%d%%"):format(floor(d.chance * 100 + 0.5)) or ("%.1f%%"):format(d.chance * 100))
        tip:AddDoubleLine("  " .. d.name, ("%s  |cff808080of %d|r"):format(pct, d.loots), 0.9, 0.9, 0.9, 1, 1, 1)
      end
      if #list > 3 then tip:AddLine(("  and %d more"):format(#list - 3), 0.6, 0.6, 0.6) end
      added = true
    end
  end
  -- How many you have (1.101.18): what you carry, and the bank's share if there is one.
  if db.tipCount and id and not HasLine(tip, "You have", true) then
    local count = C_Item and C_Item.GetItemCount or GetItemCount
    local ok, carried, all = pcall(function() return count(id, false), count(id, true) end)
    if ok and type(carried) == "number" and type(all) == "number" and not Secret(carried) and not Secret(all) and all > 0 then
      local bank = all - carried
      tip:AddDoubleLine("You have", bank > 0 and ("%d  |cff808080+ %d in the bank|r"):format(carried, bank) or tostring(carried), 0.75, 0.75, 0.75, 1, 1, 1)
      added = true
    end
  end
  if db.tipIds and id and IsShiftKeyDown and IsShiftKeyDown() and not HasLine(tip, "Item id", true) then
    tip:AddDoubleLine("Item id", tostring(id), 0.55, 0.55, 0.55, 0.8, 0.8, 0.8)
    added = true
  end
  if added and tip.Show then tip:Show() end
end

-- A spell's id, while Shift is held (1.101.18).
function T:OnSpell(tip)
  if not tip or not tip.fuiStyled or not ns.db.tipIds or not (IsShiftKeyDown and IsShiftKeyDown()) then return end
  if not tip.GetSpell or HasLine(tip, "Spell id", true) then return end
  local _, id = tip:GetSpell()
  if type(id) ~= "number" or Secret(id) then return end
  tip:AddDoubleLine("Spell id", tostring(id), 0.55, 0.55, 0.55, 0.8, 0.8, 0.8)
  if tip.Show then tip:Show() end
end

------------------------------------------------------------------------
-- Creatures: their id while Shift is held, and other add-ons' lines
------------------------------------------------------------------------

local function NpcID(guid)
  if not guid or Secret(guid) then return nil end
  local kind, _, _, _, _, id = strsplit("-", guid)
  if kind == "Creature" or kind == "Vehicle" then return tonumber(id) end
end
T.NpcID = NpcID

-- Lines another add-on adds under a creature's or player's tooltip: fn(tip, unit), after VoltUI's
-- own, each in a pcall. tip.fuiLootStamp is cleared as the tooltip clears or hides, for an
-- add-on to note it has already added its lines this showing.
T.unitLines = {}
function T:AddUnitLines(fn)
  self.unitLines[#self.unitLines + 1] = fn
end

-- A creature's id, while Shift is held (1.101.18). Not when the game hides who the unit is.
function T:UnitId(tip, unit)
  if not tip or not tip.fuiStyled or not ns.db.tipIds or not (IsShiftKeyDown and IsShiftKeyDown()) then return end
  unit = unit or TipUnit(tip)
  if not unit or Secret(unit) or HasLine(tip, "NPC id", true) then return end
  local id = NpcID(UnitGUID(unit))
  if not id then return end
  tip:AddDoubleLine("NPC id", tostring(id), 0.55, 0.55, 0.55, 0.8, 0.8, 0.8)
  if tip.Show then tip:Show() end
end

function T:OnUnit(tip, unit)
  local ok, hidden = pcall(self.UnitExtras, self, tip, unit)
  if ok and hidden then return end
  pcall(self.UnitId, self, tip, unit)
  if #self.unitLines == 0 or not tip or not tip.fuiStyled then return end
  if not unit and tip.GetUnit then unit = select(2, tip:GetUnit()) end
  if not unit or Secret(unit) then return end
  for _, fn in ipairs(self.unitLines) do pcall(fn, tip, unit) end
end

------------------------------------------------------------------------
-- Start-up
------------------------------------------------------------------------

function T:Refresh()
  self:Fonts()
  self:BarLook()
  for _, tip in ipairs(self.styled) do
    S.ThemePanel(tip, max(ns.db.alpha, 0.9))
    if not tip.fuiRarity then ResetBorder(tip) end
  end
end

function T:Enable()
  self.enabled = true
  for _, n in ipairs(NAMES) do self:Style(_G[n]) end
  self:StyleBar()
  self:Fonts()
  if type(_G.GameTooltip_SetDefaultAnchor) == "function" then
    hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tip, parent)
      local ok, err = pcall(T.Anchor, T, tip, parent)
      if not ok and T.debug then FUI:Print("tooltip: %s", tostring(err)) end
    end)
  end
  -- Tooltips made later (some windows load on demand)
  local ev = CreateFrame("Frame")
  ev:RegisterEvent("ADDON_LOADED")
  ev:SetScript("OnEvent", function()
    for _, n in ipairs(NAMES) do if _G[n] and not _G[n].fuiStyled then T:Style(_G[n]) end end
  end)
  if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    if Enum.TooltipDataType.Unit then
      TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tip)
        local ok, err = pcall(T.OnUnit, T, tip)
        if not ok and T.debug then FUI:Print("tooltip: %s", tostring(err)) end
      end)
    end
    if Enum.TooltipDataType.Spell then
      TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, function(tip) pcall(T.OnSpell, T, tip) end)
    end
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tip)
      if not (tip and tip.GetItem) then return end
      local _, link = tip:GetItem()
      local ok, err = pcall(T.OnItem, T, tip, link)
      if not ok and T.debug then FUI:Print("tooltip: %s", tostring(err)) end
    end)
  else
    for _, tip in ipairs(self.styled) do
      if tip.HasScript and tip:HasScript("OnTooltipSetItem") then
        tip:HookScript("OnTooltipSetItem", function(self)
          local _, link = self:GetItem()
          pcall(T.OnItem, T, self, link)
        end)
      end
      if tip.HasScript and tip:HasScript("OnTooltipSetUnit") then
        tip:HookScript("OnTooltipSetUnit", function(self) pcall(T.OnUnit, T, self) end)
      end
    end
  end
end

FUI:Register(T)
