-- VoltUI · Bags
-- One bag window (and one bank window) in VoltUI's style:
--   * items sorted into categories that sit side by side when they fit
--   * every empty slot shown at the bottom
--   * rarity outline and inner glow on every item
--   * adjustable columns, slot size, horizontal and vertical gaps, fonts
--   * search, sort, money, item level, quest and new-item markers
--
-- Item slots are the game's own container item buttons, so clicking, dragging,
-- using, splitting, tooltips and selling all behave exactly like the default bags.

local _, ns = ...
local FUI, S = ns.FUI, ns.Style

local B = { key = "bags", name = "Bags", windows = {} }
ns.Bags = B

local floor, ceil, max, min, lower = math.floor, math.ceil, math.max, math.min, string.lower
local CC = C_Container
local PAD, HEADER_H, FOOTER_H = 8, S.HEADER_H, 24 -- the header is as tall as every VoltUI window's (it was 26)
local HEAD_PAD = 6 -- under a category heading, before its slots
local FILTER_H = 0 -- the row of filter buttons under the title went in 1.55.0; the search box knows their words
local MIN_COLS, MAX_COLS = 4, 30
-- (1.82.0) The bag and bank windows are drawn in VoltUI's own windows' look: square, gold, the
-- title on a solid block, hatched strips. T is its colours.
local T, A = S.UI, S.UI.accent
local HEAD_MARK = 12 -- a heading's gold marker and the space after it

------------------------------------------------------------------------
-- Container API (modern C_Container, or the old globals)
------------------------------------------------------------------------

local function NumSlots(bag)
  local fn = CC and CC.GetContainerNumSlots or GetContainerNumSlots
  return fn and fn(bag) or 0
end

local function ItemInfo(bag, slot)
  if CC and CC.GetContainerItemInfo then return CC.GetContainerItemInfo(bag, slot) end
  local tex, count, locked, quality, _, _, link, _, noValue, itemID = GetContainerItemInfo(bag, slot)
  if not tex then return nil end
  return { iconFileID = tex, stackCount = count, isLocked = locked, quality = quality, hyperlink = link,
           hasNoValue = noValue, itemID = itemID }
end

local function QuestInfo(bag, slot)
  if CC and CC.GetContainerItemQuestInfo then
    local q = CC.GetContainerItemQuestInfo(bag, slot)
    if q then return q.isQuestItem, q.questID, q.isActive end
  elseif GetContainerItemQuestInfo then
    return GetContainerItemQuestInfo(bag, slot)
  end
end

------------------------------------------------------------------------
-- Quest items you no longer need (since 1.63.0)
------------------------------------------------------------------------
-- A quest item is left over once no quest in your log needs it: you've handed the quest in,
-- or dropped it. What the log needs: the items its objectives name, each quest's usable item,
-- and, with QuestieDB, each quest's own items (the one its giver hands you, like a letter to
-- deliver, the ones it takes to start, and its item objectives) and the quests QuestieDB ties
-- the item to. An item that starts a quest is left over once that quest is done. Only the
-- game's Quest kind of item is judged, so the cloth or ore a quest asks for is never marked.
-- A quest with no objectives (a delivery) that QuestieDB doesn't know could need any quest
-- item, so while you have one nothing is marked but finished quests' starters (1.63.1: a
-- letter to deliver was marked, since its name is in no objective).

local function Call(fn, ...)
  if type(fn) ~= "function" then return nil end
  local r = { pcall(fn, ...) }
  if r[1] then return unpack(r, 2, table.maxn(r)) end
end

local QDB_CONTRACT = 4
local function Questie()
  local L = LibQuestieDB
  if type(L) ~= "table" or type(L.Item) ~= "table" or type(L.Item.Get) ~= "function" then return nil end
  if type(L.Quest) ~= "table" or type(L.Quest.Get) ~= "function" then return nil end
  if L.RequireContract and not Call(L.RequireContract, QDB_CONTRACT) then return nil end
  return L
end
local function QuestieItems()
  local L = Questie()
  return L and L.Item
end

-- The items QuestieDB says a quest hands you or asks for. Nil if it doesn't know the quest.
local function QuestItems(L, id)
  if not (L and Call(L.Quest.Exists, id)) then return nil end
  local out = {}
  local src = Call(L.Quest.Get, id, "sourceItemId")
  if type(src) == "number" and src > 0 then out[#out + 1] = src end
  local req = Call(L.Quest.Get, id, "requiredSourceItems")
  if type(req) == "table" then
    for _, i in ipairs(req) do if type(i) == "number" then out[#out + 1] = i end end
  end
  local obj = Call(L.Quest.Get, id, "objectives")
  if type(obj) == "table" and type(obj[3]) == "table" then
    for _, o in ipairs(obj[3]) do
      local i = type(o) == "table" and o[1] or o
      if type(i) == "number" then out[#out + 1] = i end
    end
  end
  return out
end

local function QuestDone(q)
  return Call(C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted, q) == true
end

local function Plain(v) return type(v) == "string" and not S.IsSecret(v) and v ~= "" and v or nil end

-- Your quest log, as what it needs: its quests, the text of their objectives (lower case)
-- and their usable items. Read once per layout of the bags.
function B:QuestLog()
  if self.log then return self.log end
  local log = { quests = {}, text = {}, items = {} }
  local CQ = C_QuestLog
  local L = Questie()
  local n = CQ and Call(CQ.GetNumQuestLogEntries) or Call(GetNumQuestLogEntries)
  for i = 1, type(n) == "number" and n or 0 do
    local id, header
    if CQ and CQ.GetInfo then
      local info = Call(CQ.GetInfo, i)
      if type(info) == "table" then id, header = info.questID, info.isHeader end
    else
      local _, _, _, isHeader, _, _, _, qid = Call(GetQuestLogTitle, i)
      id, header = qid, isHeader
    end
    if not header and type(id) == "number" and id > 0 then
      log.quests[id] = true
      local before = #log.text
      local objectives = CQ and Call(CQ.GetQuestObjectives, id)
      if type(objectives) == "table" then
        for _, o in ipairs(objectives) do
          local t = type(o) == "table" and Plain(o.text)
          if t then log.text[#log.text + 1] = t:lower() end
        end
      else
        for j = 1, Call(GetNumQuestLeaderBoards, i) or 0 do
          local t = Plain((Call(GetQuestLogLeaderBoard, j, i)))
          if t then log.text[#log.text + 1] = t:lower() end
        end
      end
      local own = QuestItems(L, id)
      for _, item in ipairs(own or {}) do log.items[item] = true end
      -- no objectives, and QuestieDB can't say what it hands you: it could need any quest item
      if #log.text == before and not own then log.unsure = true end
      local link = Plain((Call(GetQuestLogSpecialItemInfo, i)))
      local item = link and tonumber(link:match("item:(%d+)"))
      if item then log.items[item] = true end
    end
  end
  self.log = log
  return log
end

local related = {} -- QuestieDB's quests for an item, by item id (false: none)
local function Related(id)
  if related[id] == nil then
    local items = QuestieItems()
    if not items then return nil end -- not cached: QuestieDB may load later
    local q = Call(items.Get, id, "relatedQuests")
    local start = Call(items.Get, id, "startQuest")
    related[id] = { quests = type(q) == "table" and q or {}, start = type(start) == "number" and start > 0 and start or nil }
  end
  return related[id]
end
B.Related = Related

-- Nil, or why it's left over (for its tooltip).
function B:Leftover(it)
  if ns.db.questLeft == false or not it.id then return nil end
  local log = self:QuestLog()
  local qdb = Related(it.id)
  local start = it.questID or (qdb and qdb.start)
  if start then -- it starts a quest: left over once that's done
    if log.quests[start] or not QuestDone(start) then return nil end
    return "You've done the quest it starts."
  end
  if it.classID ~= 12 then return nil end
  if log.items[it.id] or log.unsure then return nil end
  for _, q in ipairs(qdb and qdb.quests or {}) do
    if log.quests[q] then return nil end
  end
  local name = Plain(it.name)
  if not name then return nil end -- can't tell yet: the game hasn't sent its name
  name = name:lower()
  for _, t in ipairs(log.text) do
    if t:find(name, 1, true) then return nil end
  end
  return "No quest in your log needs it."
end

local function Cooldown(bag, slot)
  local fn = CC and CC.GetContainerItemCooldown or GetContainerItemCooldown
  if fn then return fn(bag, slot) end
end

local function Instant(id)
  local fn = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
  if fn then return fn(id) end
end

local function ItemName(id)
  local fn = C_Item and C_Item.GetItemInfo or GetItemInfo
  local name = fn and fn(id)
  return name
end

local function ItemLevel(link)
  local fn = C_Item and C_Item.GetDetailedItemLevelInfo or GetDetailedItemLevelInfo
  return fn and link and fn(link)
end

local function IsNew(bag, slot)
  return C_NewItems and C_NewItems.IsNewItem and C_NewItems.IsNewItem(bag, slot) or false
end

local EQUIPPED = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4

-- The reagent bag only takes crafting reagents, so its slots aren't general bag space.
local REAGENT_BAG = Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag
if REAGENT_BAG and REAGENT_BAG > EQUIPPED then REAGENT_BAG = nil end

local function BagIDs()
  local t = {}
  for bag = 0, EQUIPPED do t[#t + 1] = bag end
  return t
end

-- What a bag is limited to: 0 means it takes anything. Quivers, ammo pouches, soul bags
-- and profession bags each report their own value.
local function BagFamily(bag)
  local fn = CC and CC.GetContainerNumFreeSlots or GetContainerNumFreeSlots
  if not fn then return 0 end
  local _, family = fn(bag)
  return family or 0
end

local function BagName(bag)
  local fn = CC and CC.GetBagName or GetBagName
  return fn and fn(bag)
end

-- The bags that take anything, and those that only take some things. Worn bags can change
-- at any time, so this is worked out fresh for each layout.
local function SplitBagIDs()
  local general, limited = {}, {}
  for _, bag in ipairs(BagIDs()) do
    if bag == REAGENT_BAG or BagFamily(bag) ~= 0 then
      limited[#limited + 1] = bag
    else
      general[#general + 1] = bag
    end
  end
  return general, limited
end

-- A bank made of tabs you buy: the ones you have, then any warband tabs you can see.
local function BankTabIDs()
  local bank, types = _G.C_Bank, Enum and Enum.BankType
  if not (bank and types and bank.FetchPurchasedBankTabData) then return nil end
  local t = {}
  local function add(kind)
    if kind and bank.CanViewBank(kind) then
      for _, tab in ipairs(bank.FetchPurchasedBankTabData(kind) or {}) do t[#t + 1] = tab.ID end
    end
  end
  add(types.Character)
  add(types.Account)
  return t
end

local function BankIDs()
  local tabs = BankTabIDs()
  if tabs then return tabs end
  local t = { BANK_CONTAINER or -1 }
  for i = 1, (NUM_BANKBAGSLOTS or 6) do t[#t + 1] = EQUIPPED + i end
  local E = Enum and Enum.BagIndex
  if E and E.CharacterBankTab_1 then
    for i = 1, 6 do
      local id = E["CharacterBankTab_" .. i]
      if id then t[#t + 1] = id end
    end
  end
  if REAGENTBANK_CONTAINER and IsReagentBankUnlocked and IsReagentBankUnlocked() then
    t[#t + 1] = REAGENTBANK_CONTAINER
  end
  return t
end

------------------------------------------------------------------------
-- Categories
------------------------------------------------------------------------

local CATS = {
  { key = "new", label = "New" },
  { key = "quest", label = "Quest" },
  { key = "equipment", label = "Equipment", classes = { 2, 4 } },
  { key = "consumable", label = "Consumables", classes = { 0 } },
  { key = "trade", label = "Trade Goods", classes = { 7 } },
  { key = "reagent", label = "Reagents", classes = { 5 } },
  { key = "recipe", label = "Recipes", classes = { 9 } },
  { key = "container", label = "Bags", classes = { 1 } },
  { key = "ammo", label = "Ammo", classes = { 6, 11 } },
  { key = "key", label = "Keys", classes = { 13 } },
  { key = "misc", label = "Miscellaneous", classes = { 15, 8, 10, 16, 17, 18, 19 } },
  { key = "junk", label = "Junk" },
  { key = "other", label = "Other" },
}
B.CATS = CATS
local CLASS_CAT = {}
for i, c in ipairs(CATS) do
  c.order = i
  for _, id in ipairs(c.classes or {}) do CLASS_CAT[id] = c end
end
local CAT = {}
for _, c in ipairs(CATS) do CAT[c.key] = c end

local function Categorise(it)
  if it.new then return CAT.new end
  if it.isQuest then return CAT.quest end
  if it.quality == 0 then return CAT.junk end
  return CLASS_CAT[it.classID] or CAT.other
end

------------------------------------------------------------------------
-- Item buttons (the game's own container buttons, restyled)
------------------------------------------------------------------------

local buttonType
local function ButtonType()
  if buttonType then return buttonType end
  local ok, probe = pcall(CreateFrame, "ItemButton", nil, UIParent, "ContainerFrameItemButtonTemplate")
  if ok and probe then probe:Hide() end
  buttonType = ok and "ItemButton" or "Button"
  return buttonType
end

local function Fade(obj)
  if type(obj) == "table" and obj.SetAlpha then obj:SetAlpha(0) end
end

function B:Holder(win, bag)
  local h = win.holders[bag]
  if h then return h end
  h = CreateFrame("Frame", nil, win.content)
  h:SetID(bag)
  h:SetAllPoints(win.content)
  win.holders[bag] = h
  return h
end

function B:NewButton(win, bag, slot)
  local name = ("VoltUI%sItem%s_%d"):format(win.kind == "bank" and "Bank" or "Bag", bag < 0 and ("m" .. -bag) or bag, slot)
  local b = _G[name] or CreateFrame(ButtonType(), name, self:Holder(win, bag), "ContainerFrameItemButtonTemplate")
  b:SetID(slot)
  -- The bag number comes from the holder's ID, never b:SetBagID or b.bagID. The game
  -- reads that field right before it uses the item, and a value VoltUI wrote there makes its
  -- click count as add-on code, which it blocks for anything that casts, like a Hearthstone.
  b.fuiBag, b.fuiSlot = bag, slot

  -- Our look instead of the slot art.
  if b.ClearNormalTexture then b:ClearNormalTexture() else b:SetNormalTexture("") end
  for _, k in ipairs({ "IconBorder", "IconQuestTexture", "JunkIcon", "UpgradeIcon", "flash", "NewItemTexture",
                       "BattlepayItemTexture", "ItemContextOverlay", "IconOverlay", "IconOverlay2", "ExtendedSlot",
                       "EmptyBagIcon" }) do
    Fade(b[k])
  end
  local hl = b:GetHighlightTexture()
  if hl then hl:SetColorTexture(A[1], A[2], A[3], 0.22) end
  S.ColorEdges(S.Edges(b, "HIGHLIGHT"), A[1], A[2], A[3], 1) -- with the tint: VoltUI's hover, without the left edge a slot has no room for
  local pushed = b.GetPushedTexture and b:GetPushedTexture()
  if pushed then pushed:SetColorTexture(1, 1, 1, 0.1) end

  b.fuiIcon = b.icon or b.Icon or _G[name .. "IconTexture"]
  b.fuiIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- Paint puts this back each time the icon changes
  -- The game's item buttons round the icon's corners with a mask (ItemButtonMixin:PostOnLoad).
  -- Off, so the icon fills VoltUI's square outline. A widget call: nothing is written on the button.
  if b.Mask then
    if b.fuiIcon.RemoveMaskTexture then pcall(b.fuiIcon.RemoveMaskTexture, b.fuiIcon, b.Mask) end
    if pushed and pushed.RemoveMaskTexture then pcall(pushed.RemoveMaskTexture, pushed, b.Mask) end
  end
  b.fuiCount = b.Count or _G[name .. "Count"]
  if b.fuiCount then
    b.fuiCount:SetDrawLayer("OVERLAY", 7)
    b.fuiCount:ClearAllPoints()
    b.fuiCount:SetPoint("BOTTOMRIGHT", -2, 2)
  end
  b.fuiCooldown = b.Cooldown or _G[name .. "Cooldown"]
  b.fuiSlotBg = S.Tex(b, "BACKGROUND", -6)
  b.fuiSlotBg:SetAllPoints()
  b.fuiSlotBg:SetColorTexture(T.card[1], T.card[2], T.card[3], 1)
  b.fuiEdge = S.Edges(b, "BACKGROUND", -5) -- under the rarity outline, which is drawn over it
  S.ColorEdges(b.fuiEdge, T.line[1], T.line[2], T.line[3], 1)
  b.fuiGlow = S.Glow(b, b, ns.db.bagSize)
  b.fuiLevel = S.Text(b, nil, "LEFT", "OVERLAY", ns.db.countSize - 1, ns.db.outline)
  b.fuiLevel:SetDrawLayer("OVERLAY", 7)
  b.fuiLevel:SetPoint("TOPLEFT", 2, -2)
  b.fuiMark = S.Text(b, nil, "RIGHT", "OVERLAY", ns.db.countSize + 2, "OUTLINE")
  b.fuiMark:SetDrawLayer("OVERLAY", 7)
  b.fuiMark:SetPoint("TOPRIGHT", -2, -1)
  -- a quest item no quest needs any more: a small red bin, top right (1.63.0)
  b.fuiLeft = CreateFrame("Frame", nil, b)
  b.fuiLeft:SetSize(14, 14)
  b.fuiLeft:SetPoint("TOPRIGHT", -1, -1)
  b.fuiLeft:SetFrameLevel((b:GetFrameLevel() or 1) + 4)
  local back = S.Tex(b.fuiLeft, "BACKGROUND")
  back:SetAllPoints()
  back:SetColorTexture(0, 0, 0, 0.65)
  b.fuiLeft.icon = S.Icon(b.fuiLeft, "discard", 10)
  b.fuiLeft.icon:SetPoint("CENTER")
  b.fuiLeft.icon:SetColor(S.UI.bad[1], S.UI.bad[2], S.UI.bad[3], 1)
  b.fuiLeft:Hide()
  b:HookScript("OnEnter", function(self)
    local it = self.fuiItem
    if not it then return end
    local junk = it.quality == 0 and it.id and ns.Junk and ns.Junk.enabled
    if not (it.leftover or junk) then return end
    if GameTooltip.IsOwned and not GameTooltip:IsOwned(self) then return end
    if it.leftover then
      GameTooltip:AddLine("Quest item you no longer need. " .. it.leftover, S.UI.bad[1], S.UI.bad[2], S.UI.bad[3], true)
    end
    if junk then
      if ns.Junk:Keeps(it.id) then
        GameTooltip:AddLine("Kept: not sold with your junk. Alt-right-click to sell it again.", A[1], A[2], A[3], true)
      else
        GameTooltip:AddLine("Alt-right-click: keep it (don't sell it with your junk)", 0.6, 0.6, 0.6, true)
      end
    end
    GameTooltip:Show()
  end)
  -- Alt-right-click a grey item: keep it, or stop keeping it (Junk.lua). After the game's own
  -- click, which does nothing with Alt held; only a post-hook, so the button stays the game's.
  b:HookScript("OnClick", function(self, button)
    local it = self.fuiItem
    if button ~= "RightButton" or not (it and it.quality == 0 and it.id) then return end
    if not (IsAltKeyDown and IsAltKeyDown()) or (IsShiftKeyDown and IsShiftKeyDown()) or (IsControlKeyDown and IsControlKeyDown()) then return end
    if not (ns.Junk and ns.Junk.enabled) then return end
    ns.Junk:ToggleKeep(it.id, it.name)
    if GameTooltip.IsOwned and GameTooltip:IsOwned(self) and self:GetScript("OnEnter") then self:GetScript("OnEnter")(self) end
  end)
  b.fuiNew = S.Tex(b, "OVERLAY", 7)
  b.fuiNew:SetSize(6, 6)
  b.fuiNew:SetPoint("BOTTOMLEFT", 3, 3) -- top-left is the item level's, top-right the quest mark's
  b.fuiNew:SetColorTexture(A[1], A[2], A[3], 1)
  if b.fuiCount then S.SetFont(b.fuiCount, ns.db.countSize, ns.db.outline, "bags.count") end
  return b
end

-- Closing the bags: every new item stops being new, so next time each is sorted into its own
-- category (1.92.2; from 1.80.0 only the ones you'd hovered did). While the bags stay open
-- they stay in New, so nothing moves from under the mouse.
function B:ForgetSeen()
  local N = C_NewItems
  if not N then return end
  if N.ClearAll then
    pcall(N.ClearAll)
  elseif N.RemoveNewItem then
    for _, w in pairs(self.windows) do
      for _, b in ipairs(w.shown or {}) do
        if b.fuiItem and b.fuiItem.new then pcall(N.RemoveNewItem, b.fuiBag, b.fuiSlot) end
      end
    end
  end
end

function B:AllSeen()
  if C_NewItems and C_NewItems.ClearAll then C_NewItems.ClearAll() end
  for _, w in pairs(self.windows) do
    if w.frame:IsShown() then self:Layout(w) else w.dirty = true end
  end
end

function B:Button(win, bag, slot)
  win.buttons[bag] = win.buttons[bag] or {}
  local b = win.buttons[bag][slot]
  if not b then
    if InCombatLockdown() then
      self.pendingButtons = true
      return nil
    end
    b = self:NewButton(win, bag, slot)
    win.buttons[bag][slot] = b
  end
  return b
end

-- Draw one slot.
-- The game's SetItemButtonTexture resets the icon's crop to the whole texture, which brings
-- back the border drawn into every item icon inside VoltUI's outline, so the crop goes back on
-- after it. For an empty slot it paints the game's slot picture ("bags-item-slot64") as the
-- icon; VoltUI hides that and leaves just its own faint square.
local CROP = { 0.08, 0.92, 0.08, 0.92 }
function B:Paint(b, it)
  local db = ns.db
  local icon = b.fuiIcon
  if it then
    SetItemButtonTexture(b, it.icon)
    icon:SetTexCoord(CROP[1], CROP[2], CROP[3], CROP[4])
    icon:Show()
    SetItemButtonCount(b, it.count)
    SetItemButtonDesaturated(b, it.locked)
    S.PaintGlow(b.fuiGlow, it.quality)
    B.Stroke(b, S.QualityRGB(it.quality) and db.bagEdge or 1)
    b.fuiLevel:SetText(db.ilvl and it.level and it.level > 1 and it.level or "")
    if it.level and it.quality then
      local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[it.quality]
      if c then b.fuiLevel:SetTextColor(c.r, c.g, c.b) end
    end
    b.fuiMark:SetText(it.starts and not it.leftover and "|cffffd100!|r" or "")
    b.fuiLeft:SetShown(it.leftover and true or false)
    b.fuiNew:SetShown(it.new and true or false)
    b.fuiSlotBg:SetColorTexture(T.card[1], T.card[2], T.card[3], 1)
    if b.fuiEdge then S.ColorEdges(b.fuiEdge, T.line[1], T.line[2], T.line[3], 1) end
  else
    SetItemButtonTexture(b, nil)
    icon:SetTexture(nil)
    icon:Hide()
    SetItemButtonCount(b, 0)
    SetItemButtonDesaturated(b, false)
    S.PaintGlow(b.fuiGlow, nil)
    B.Stroke(b, 1)
    b.fuiLevel:SetText("")
    b.fuiMark:SetText("")
    b.fuiLeft:Hide()
    b.fuiNew:Hide()
    -- an empty slot: the window's own grey with a quieter border
    b.fuiSlotBg:SetColorTexture(T.panel[1], T.panel[2], T.panel[3], 1)
    if b.fuiEdge then S.ColorEdges(b.fuiEdge, 0.2, 0.2, 0.2, 1) end
  end
  b.fuiItem = it
  self:PaintCooldown(b)
end

function B:PaintCooldown(b)
  local cd = b.fuiCooldown
  if not cd then return end
  if not b.fuiItem then cd:Hide() return end
  local start, duration, enable = Cooldown(b.fuiBag, b.fuiSlot)
  if CooldownFrame_Set and start then
    CooldownFrame_Set(cd, start, duration, enable)
  elseif cd.SetCooldown and start and duration and duration > 0 then
    cd:SetCooldown(start, duration)
    cd:Show()
  else
    cd:Hide()
  end
end

------------------------------------------------------------------------
-- Filters and search
------------------------------------------------------------------------

local function IsGear(it) return it.classID == 2 or it.classID == 4 end

-- Kinds of item the search box knows by name (they were buttons under the title until 1.55.0).
-- BoE is a guess the game doesn't spell out: gear of green quality or better that isn't bound
-- to you yet.
local FILTERS = {
  { key = "gear", label = "Gear", width = 42, tip = "Weapons and armour", fn = IsGear },
  { key = "boe", label = "BoE", width = 38, tip = "Green or better gear that isn't bound to you yet",
    fn = function(it) return IsGear(it) and it.bound == false and (it.quality or 0) >= 2 end },
  { key = "quest", label = "Quest", width = 46, tip = "Quest items", fn = function(it) return it.isQuest and true or false end },
  { key = "consumable", label = "Consumables", width = 88, tip = "Food, drink, potions and the like", fn = function(it) return it.classID == 0 end },
  { key = "trade", label = "Trade goods", width = 82, tip = "Cloth, ore, herbs and other materials", fn = function(it) return it.classID == 7 end },
  { key = "junk", label = "Junk", width = 40, tip = "Grey items, which sell themselves at a vendor", fn = function(it) return it.quality == 0 end },
}
B.FILTERS = FILTERS
local FILTER = {}
for _, f in ipairs(FILTERS) do FILTER[f.key] = f end

-- Words the search box knows besides names and types: a filter's name, "new", or a rarity.
local function Quality(q) return function(it) return it.quality == q end end
local WORDS = {
  gear = IsGear, boe = FILTER.boe.fn, quest = FILTER.quest.fn, junk = FILTER.junk.fn,
  new = function(it) return it.new and true or false end,
  leftover = function(it) return it.leftover and true or false end,
  poor = Quality(0), grey = Quality(0), gray = Quality(0), common = Quality(1), white = Quality(1),
  uncommon = Quality(2), green = Quality(2), rare = Quality(3), blue = Quality(3), epic = Quality(4), purple = Quality(4),
}

-- Does this item match what's typed in the search box?
local function Matches(it, text)
  if text == "" then return true end
  local word = WORDS[text]
  if word and word(it) then return true end
  if lower(it.name or ""):find(text, 1, true) then return true end
  local _, itemType, subType = Instant(it.id or 0)
  if itemType and lower(itemType):find(text, 1, true) then return true end
  if subType and lower(subType):find(text, 1, true) then return true end
  return false
end

------------------------------------------------------------------------
-- Windows
------------------------------------------------------------------------

-- Gold, silver and copper each in their own colour, with the game's coin beside the number.
local COIN = "|TInterface\\MoneyFrame\\UI-%sIcon:12:12:2:0|t"
local function Money()
  local m = GetMoney and GetMoney() or 0
  return ("|cffffd100%d|r%s  |cffc7c7cf%d|r%s  |cffeda55f%d|r%s"):format(
    floor(m / 10000), COIN:format("Gold"), floor(m / 100) % 100, COIN:format("Silver"), m % 100, COIN:format("Copper"))
end
B.Money = Money

-- Merchant's Favor, Forever's trade currency, and whatever you've ticked "Show on backpack"
-- for in the game's currency window: an icon and how much, left of your money.
B.FAVOR = 3402
local function Currencies()
  local CI = _G.C_CurrencyInfo
  local out, seen = {}, {}
  if type(CI) ~= "table" then return "" end
  local function add(info, id)
    if type(info) ~= "table" or not id or seen[id] then return end
    local name, amount = S.Safe(info.name), S.Safe(info.quantity)
    if type(name) ~= "string" or name == "" or type(amount) ~= "number" then return end
    seen[id] = true
    local icon = info.iconFileID
    local mark = icon and ("|T%s:13:13:0:0:64:64:5:59:5:59|t "):format(tostring(icon)) or (name .. " ")
    out[#out + 1] = mark .. (BreakUpLargeNumbers and BreakUpLargeNumbers(amount) or tostring(amount))
  end
  if CI.GetCurrencyInfo then
    local ok, info = pcall(CI.GetCurrencyInfo, B.FAVOR)
    if ok then add(info, B.FAVOR) end
  end
  if CI.GetBackpackCurrencyInfo then
    for i = 1, 5 do
      local ok, info = pcall(CI.GetBackpackCurrencyInfo, i)
      if ok and type(info) == "table" then add(info, info.currencyTypesID or info.name) end
    end
  end
  return table.concat(out, "    ")
end
B.Currencies = Currencies

function B:PaintMoney(f)
  f.money:SetText(Money())
  if f.currency then f.currency:SetText(Currencies()) end
end

function B:Window(kind)
  if self.windows[kind] then return self.windows[kind] end
  local db = ns.db
  local win = { kind = kind, holders = {}, buttons = {}, headers = {} }
  local name = kind == "bank" and "VoltUIBank" or "VoltUIBags"
  local f = CreateFrame("Frame", name, UIParent)
  f:SetFrameStrata("MEDIUM")
  f:SetToplevel(true)
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:Hide()
  S.ThemePanel(f, db.alpha)
  -- the slots sit on the darkest grey, between a line under the title and one over the footer
  f.pane = S.Tex(f, "BACKGROUND", -6)
  f.pane:SetPoint("TOPLEFT", 1, -HEADER_H)
  f.pane:SetPoint("BOTTOMRIGHT", -1, FOOTER_H)
  f.pane:SetColorTexture(T.bg[1], T.bg[2], T.bg[3], 1)
  for _, at in ipairs({ { "TOPLEFT", "TOPRIGHT", -HEADER_H }, { "BOTTOMLEFT", "BOTTOMRIGHT", FOOTER_H } }) do
    local line = S.Tex(f, "BORDER")
    line:SetPoint(at[1], f, at[1], 1, at[3])
    line:SetPoint(at[2], f, at[2], -1, at[3])
    line:SetHeight(1)
    line:SetColorTexture(T.line[1], T.line[2], T.line[3], 1)
  end
  table.insert(UISpecialFrames, name)

  local header = CreateFrame("Frame", nil, f)
  header:SetPoint("TOPLEFT", 1, -1)
  header:SetPoint("TOPRIGHT", -1, -1)
  header:SetHeight(HEADER_H - 1)
  header:EnableMouse(true)
  header:RegisterForDrag("LeftButton")
  header:SetScript("OnDragStart", function() f:StartMoving() end)
  header:SetScript("OnDragStop", function()
    f:StopMovingOrSizing()
    local k = kind == "bank" and "bank" or "bag"
    S.KeepSpot(f, db, k .. "Left", k .. "Top", k .. "Point")
  end)
  -- the window's name in dark Space Mono on a solid gold block, as wide as the name needs
  f.block = S.Tex(header, "ARTWORK")
  f.block:SetPoint("TOPLEFT", 0, 0)
  f.block:SetPoint("BOTTOMLEFT", 0, 0)
  S.BlockLook(header, f.block)
  f.title = S.UIText(header, nil, "CENTER", "OVERLAY", 13)
  S.FixFont(f.title, 13, nil, "semibold")
  f.title:SetText(kind == "bank" and "Bank" or "Bags")
  f.title:SetTextColor(T.primaryText[1], T.primaryText[2], T.primaryText[3])
  f.block:SetWidth(ceil(S.TextWidth(f.title, #(f.title:GetText() or "") * 8)) + 22)
  f.title:SetPoint("CENTER", f.block, "CENTER", 0, 0)
  f.free = S.UIText(header, nil, "LEFT", nil, 11, nil, "mono")
  f.free:SetPoint("LEFT", f.block, "RIGHT", 9, 0)
  f.free:SetTextColor(T.text[1], T.text[2], T.text[3])

  local function button(label, width, fn, tip)
    local b = S.PillButton(header, label, width, fn, false, tip)
    b:SetHeight(18)
    return b
  end
  f.close = button("x", 20, function() f:Hide() end)
  f.close:SetWidth(20)
  f.close:SetPoint("RIGHT", -3, 0)
  local right = f.close
  if kind == "bags" then
    f.cog = button("Settings", 58, function() B:ToggleSettings() end, "Columns, slot size, gaps, fonts and more")
    f.cog:SetPoint("RIGHT", right, "LEFT", -3, 0)
    right = f.cog
  end
  local sortFn
  if kind ~= "bank" then
    sortFn = CC and CC.SortBags or SortBags
  elseif CC and CC.SortBank and Enum and Enum.BankType then
    sortFn = function() CC.SortBank(Enum.BankType.Character) end
  else
    sortFn = CC and CC.SortBankBags or SortBankBags
  end
  if sortFn then
    -- It says what it sorts: on the bank that's your character's bank, never the warband tabs.
    local what = kind ~= "bank" and "Tidy the items in your bags"
      or (CC and CC.SortBank and "Tidy your character's bank. Warband tabs are left as they are." or "Tidy the items in your bank")
    f.sort = button("Sort", 36, function() pcall(sortFn) end, what)
    f.sort:SetPoint("RIGHT", right, "LEFT", -3, 0)
    right = f.sort
  end

  -- Search box
  local sb = CreateFrame("EditBox", name .. "Search", header)
  sb:SetSize(110, 18)
  sb:SetPoint("RIGHT", right, "LEFT", -6, 0)
  sb:SetAutoFocus(false)
  sb:SetTextInsets(6, 6, 0, 0)
  S.FixFont(sb, 11, nil, nil, "mono")
  local sbg = S.Tex(sb, "BACKGROUND", -8)
  sbg:SetAllPoints()
  sbg:SetColorTexture(T.bg[1], T.bg[2], T.bg[3], 1)
  local sbe = S.Edges(sb, "BACKGROUND", -7)
  S.ColorEdges(sbe, T.soft[1], T.soft[2], T.soft[3], 1)
  sb:HookScript("OnEditFocusGained", function() S.ColorEdges(sbe, A[1], A[2], A[3], 1) end)
  sb:HookScript("OnEditFocusLost", function() S.ColorEdges(sbe, T.soft[1], T.soft[2], T.soft[3], 1) end)
  sb.hint = S.UIText(sb, nil, "LEFT", nil, 11)
  sb.hint:SetPoint("LEFT", 6, 0)
  sb.hint:SetText("Search")
  sb.hint:SetTextColor(T.hint[1], T.hint[2], T.hint[3])
  -- a hatched strip fills what's left of the title bar, between the count and the search box
  f.hatch = S.Hatch(S.Tex(header, "ARTWORK"))
  f.hatch:SetHeight(max(4, HEADER_H - 16))
  f.hatch:SetPoint("LEFT", f.free, "RIGHT", 9, 0)
  f.hatch:SetPoint("RIGHT", sb, "LEFT", -8, 0)
  S.Paint(f.hatch, 0.23, 0.23, 0.23, 1)
  sb:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
  sb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  sb:SetScript("OnTextChanged", function(self)
    local t = self:GetText() or ""
    self.hint:SetShown(t == "")
    B:Search(win, t)
  end)
  f.search = sb

  sb:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:SetText("Search", 1, 1, 1)
    GameTooltip:AddLine("A name or a kind of item. It also knows gear, boe, quest, leftover (quest items no quest needs), junk, new, and rarities like rare or epic.", 0.75, 0.77, 0.8, true)
    GameTooltip:Show()
  end)
  sb:SetScript("OnLeave", function() GameTooltip:Hide() end)

  local content = CreateFrame("Frame", nil, f)
  content:SetPoint("TOPLEFT", PAD, -(HEADER_H + FILTER_H + PAD - 2))
  content:SetSize(10, 10)
  win.content = content

  f.money = S.UIText(f, nil, "RIGHT", nil, 12, nil, "mono")
  f.money:SetPoint("BOTTOMRIGHT", -(PAD + 6), 7) -- clear of the corner you drag
  f.currency = S.UIText(f, nil, "RIGHT", nil, 12, nil, "mono")
  f.currency:SetPoint("RIGHT", f.money, "LEFT", -16, 0)
  f.currency:SetTextColor(T.sub[1], T.sub[2], T.sub[3])
  -- what the first of those is, under the mouse
  local tipOver = CreateFrame("Frame", nil, f)
  tipOver:SetAllPoints(f.currency)
  tipOver:EnableMouse(true)
  tipOver:SetScript("OnEnter", function(self)
    if (f.currency:GetText() or "") == "" or not GameTooltip.SetCurrencyByID then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    if pcall(GameTooltip.SetCurrencyByID, GameTooltip, B.FAVOR) then GameTooltip:Show() else GameTooltip:Hide() end
  end)
  tipOver:SetScript("OnLeave", function() GameTooltip:Hide() end)
  f.currencyTip = tipOver
  f.info = S.UIText(f, nil, "LEFT", nil, 11, nil, "mono")
  f.info:SetPoint("BOTTOMLEFT", PAD + 12, 7)
  f.info:SetTextColor(T.label[1], T.label[2], T.label[3])
  -- a small green square before the free slots, red when there are none
  f.infoMark = S.Tex(f, "ARTWORK")
  f.infoMark:SetSize(6, 6)
  f.infoMark:SetPoint("RIGHT", f.info, "LEFT", -6, 0)
  f.infoMark:SetColorTexture(T.ok[1], T.ok[2], T.ok[3], 1)

  if kind == "bank" then
    f.isBank = true -- its footer gets the bank's bag slots (UpdateBagSlots)
    self:MakeBuyButton(f)
  end
  self:MakeGrip(win, f)

  f:SetScript("OnShow", function()
    B:Layout(win)
    if kind == "bags" and PlaySound and SOUNDKIT and SOUNDKIT.IG_BACKPACK_OPEN then PlaySound(SOUNDKIT.IG_BACKPACK_OPEN) end
  end)
  f:SetScript("OnHide", function()
    sb:SetText("")
    sb:ClearFocus()
    if kind == "bags" then
      if PlaySound and SOUNDKIT and SOUNDKIT.IG_BACKPACK_CLOSE then PlaySound(SOUNDKIT.IG_BACKPACK_CLOSE) end
      B:ForgetSeen()
    elseif B.bankOpen then
      B:CloseBanker()
    end
  end)

  win.frame = f
  self.windows[kind] = win
  self:Place(win)
  return win
end

-- The corner to drag: the window gets wider or narrower a column at a time, and the rows
-- follow. It's the Columns setting, set by hand; bags and bank share it.
function B:ColsFor(width)
  local db = ns.db
  local cols = floor((width - 2 * PAD + db.gapX) / (db.bagSize + db.gapX) + 0.5)
  return max(MIN_COLS, min(MAX_COLS, cols))
end

function B:MakeGrip(win, f)
  local g = CreateFrame("Button", nil, f)
  g:SetSize(12, 12)
  g:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
  g:SetFrameLevel((f:GetFrameLevel() or 1) + 10)
  g.dots = {}
  for _, at in ipairs({ { 0, 0 }, { 3, 0 }, { 6, 0 }, { 0, 3 }, { 3, 3 }, { 0, 6 } }) do
    local d = S.Tex(g, "OVERLAY")
    d:SetSize(2, 2)
    d:SetPoint("BOTTOMRIGHT", g, "BOTTOMRIGHT", -1 - at[1], 1 + at[2])
    g.dots[#g.dots + 1] = d
  end
  local function paint(on)
    for _, d in ipairs(g.dots) do
      if on then d:SetColorTexture(A[1], A[2], A[3], 1) else d:SetColorTexture(T.edge[1], T.edge[2], T.edge[3], 1) end
    end
  end
  paint(false)
  local function drag()
    if not win.gripLeft then return end
    local x = GetCursorPosition()
    local cols = B:ColsFor(x / f:GetEffectiveScale() - win.gripLeft)
    if cols == ns.db.bagCols then return end
    ns.db.bagCols = cols
    for _, w in pairs(B.windows) do
      if w.frame:IsShown() then B:Layout(w) else w.dirty = true end
    end
  end
  local function stop()
    if not win.gripLeft then return end
    win.gripLeft = nil
    g:SetScript("OnUpdate", nil)
    paint(g.over)
    if ns.EditMode and ns.EditMode.IsOpen and ns.EditMode:IsOpen() then ns.EditMode:RefreshPage() end
  end
  g:SetScript("OnMouseDown", function()
    if InCombatLockdown() and B.protected then
      FUI:Print("The bags can't be resized in combat.")
      return
    end
    -- Pin the top-left corner, so the window grows towards the mouse and not away from it.
    local k = win.kind == "bank" and "bank" or "bag"
    local left = f:GetLeft()
    if type(left) ~= "number" then return end
    S.KeepSpot(f, ns.db, k .. "Left", k .. "Top", k .. "Point")
    win.gripLeft = left
    paint(true)
    g:SetScript("OnUpdate", drag)
  end)
  g:SetScript("OnMouseUp", stop)
  g:SetScript("OnHide", stop)
  g:SetScript("OnEnter", function(self)
    self.over = true
    paint(true)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Drag to resize", 1, 1, 1)
    GameTooltip:AddLine("Wider or narrower by a column; the rows follow.", 0.75, 0.77, 0.8, true)
    GameTooltip:Show()
  end)
  g:SetScript("OnLeave", function(self)
    self.over = nil
    if not win.gripLeft then paint(false) end
    GameTooltip:Hide()
  end)
  f.grip = g
  return g
end

-- The game's own script for buying a tab, on our button. It runs the game's own
-- confirmation, which add-on code couldn't do itself. Its OnClick has to stay as it is.
function B:MakeBuyButton(f)
  local types = Enum and Enum.BankType
  local ok, b = false, nil
  if types and _G.C_Bank then
    ok, b = pcall(CreateFrame, "Button", nil, f, "BankPanelPurchaseButtonScriptTemplate")
  end
  if ok and b then
    b:SetAttribute("overrideBankType", types.Character)
    b:SetHeight(18)
    b:SetPoint("BOTTOMLEFT", PAD - 2, 4)
    local bg = S.Tex(b, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(T.raised[1], T.raised[2], T.raised[3], 1)
    S.ColorEdges(S.Edges(b, "BORDER"), T.soft[1], T.soft[2], T.soft[3], 1)
    S.Hover(b)
    b.text = S.UIText(b, nil, "CENTER", nil, 12)
    b.text:SetPoint("CENTER")
    b.tabs = true
    f.buy = b
  elseif PurchaseSlot and GetNumBankSlots then -- the older bank, on other clients
    f.buy = S.PillButton(f, "Buy bag slot", 90, function()
      if StaticPopup_Show then StaticPopup_Show("CONFIRM_BUY_BANK_SLOT") end
    end, false, "Buy another bank bag slot")
    f.buy:SetHeight(18)
    f.buy:SetPoint("BOTTOMLEFT", PAD - 2, 4)
  end
end

-- What the next tab costs, if there is one to buy.
function B:NextTab()
  local bank, types = _G.C_Bank, Enum and Enum.BankType
  if not (bank and types and bank.FetchNextPurchasableBankTabData) then return nil end
  local kind = types.Character
  if bank.FetchNumPurchasedBankTabs(kind) >= bank.FetchMaxNumBankTabs(kind) then return nil end
  return bank.FetchNextPurchasableBankTabData(kind)
end

-- The bank's bag slots (1.101.21). On this client a bank "tab" you buy is an empty bag slot:
-- nothing can go in it until a bag does, and the slots only existed on the game's own bank
-- window, which VoltUI replaces. One small button per slot in the footer: click or drag a bag
-- onto it to put it in, click or drag it off to take it out. Slot 1 is the bank itself, so
-- the row starts at 2, as the game's does (Camelot/BankFrame.lua). Plain buttons of VoltUI's
-- own; picking up from a container isn't a protected call.
local SLOT, SLOT_GAP = 18, 2

local function BankSlotBag()
  local E = Enum and Enum.BagIndex
  return E and E.Characterbanktab
end

local function SlotIcon(bag, n)
  local get = CC and CC.GetContainerItemInfo
  local ok, info = pcall(function() return get and get(bag, n) end)
  return ok and type(info) == "table" and info.iconFileID or nil
end

function B:BagSlotButton(f, i)
  f.bagSlots = f.bagSlots or {}
  local b = f.bagSlots[i]
  if b then return b end
  b = CreateFrame("Button", nil, f)
  b:SetSize(SLOT, SLOT)
  b:SetPoint("BOTTOMLEFT", PAD - 2 + (i - 1) * (SLOT + SLOT_GAP), 3)
  local bg = S.Tex(b, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(T.raised[1], T.raised[2], T.raised[3], 1)
  b.edges = S.Edges(b, "BORDER")
  S.ColorEdges(b.edges, T.soft[1], T.soft[2], T.soft[3], 1)
  b.icon = S.Tex(b, "ARTWORK")
  b.icon:SetPoint("TOPLEFT", 1, -1)
  b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
  b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  S.Hover(b)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:RegisterForDrag("LeftButton")
  local function pick(self)
    local bag = BankSlotBag()
    if not (self.bought and bag and CC and CC.PickupContainerItem) then return end
    CC.PickupContainerItem(bag, self.slot)
  end
  b:SetScript("OnClick", pick)
  b:SetScript("OnDragStart", pick)
  b:SetScript("OnReceiveDrag", pick)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    local bag = BankSlotBag()
    local shown = false
    if self.bought and bag and GameTooltip.SetBagItem then
      local ok, has = pcall(GameTooltip.SetBagItem, GameTooltip, bag, self.slot)
      shown = ok and has and true or false
    end
    if not shown then
      if self.bought then
        GameTooltip:SetText(_G.BANK_BAG or "Bank bag slot", 1, 1, 1)
        GameTooltip:AddLine("Drop a bag here to add its slots to your bank.", 0.75, 0.75, 0.75, true)
      else
        GameTooltip:SetText(_G.BANK_BAG_PURCHASE or "Bank bag slot (not bought)", 1, 1, 1)
        GameTooltip:AddLine("Buy it with the button beside these.", 0.75, 0.75, 0.75, true)
      end
    end
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  f.bagSlots[i] = b
  return b
end

-- Draws the row; returns how wide it is (0 with no slots to show).
function B:UpdateBagSlots(f)
  local bank, types, bag = _G.C_Bank, Enum and Enum.BankType, BankSlotBag()
  if not (bank and types and bag and bank.FetchMaxNumBankTabs and bank.FetchNumPurchasedBankTabs) then return 0 end
  local ok, most, have = pcall(function()
    return bank.FetchMaxNumBankTabs(types.Character), bank.FetchNumPurchasedBankTabs(types.Character)
  end)
  if not ok or type(most) ~= "number" or type(have) ~= "number" then return 0 end
  local count = 0
  for n = 2, most do
    count = count + 1
    local b = self:BagSlotButton(f, count)
    b.slot, b.bought = n, n <= have
    local icon = b.bought and SlotIcon(bag, n) or nil
    b.icon:SetTexture(icon)
    b.icon:SetShown(icon ~= nil)
    b:SetAlpha(b.bought and 1 or 0.35)
    local c = icon and T.accent or T.soft
    S.ColorEdges(b.edges, c[1], c[2], c[3], 1)
    b:Show()
  end
  for i = count + 1, #(f.bagSlots or {}) do f.bagSlots[i]:Hide() end
  return count > 0 and (count * (SLOT + SLOT_GAP) + 6) or 0
end

function B:UpdateBuy(f)
  local b = f.buy
  if f.isBank then
    f.slotsWide = self:UpdateBagSlots(f)
    if b then
      b:ClearAllPoints()
      b:SetPoint("BOTTOMLEFT", PAD - 2 + (f.slotsWide or 0), 4)
    end
  end
  if not b then return end
  if not b.tabs then
    local have, cost = GetNumBankSlots()
    b:SetShown(not cost and have < (NUM_BANKBAGSLOTS or 6))
    return
  end
  local tab = self:NextTab()
  b:SetShown(tab ~= nil)
  if not tab then return end
  local cost = tab.tabCost or 0
  if cost > 0 then
    b.text:SetText("Buy bank tab: " .. (GetCoinTextureString and GetCoinTextureString(cost) or tostring(cost)))
  else
    b.text:SetText("Claim your free bank tab")
  end
  if tab.canAfford == false then
    b.text:SetTextColor(0.9, 0.35, 0.3)
  else
    b.text:SetTextColor(1, 1, 1)
  end
  b:SetWidth(b.text:GetStringWidth() + 20)
end

function B:UsesOwnBank()
  return ns.db.bank and BankFrame ~= nil
end

function B:CloseBanker()
  local close = _G.C_Bank and _G.C_Bank.CloseBankFrame or _G.CloseBankFrame
  if close then close() end
end

-- The game opens its own window however you reach a banker, so both signals lead here.
function B:BankerOpened()
  if self.bankOpen then return end
  self.bankOpen = true
  local bags = self:Window("bags")
  self.bankOpenedBags = not bags.frame:IsShown()
  self:Window("bank").frame:Show()
  self:Open()
end

function B:BankerClosed()
  if not self.bankOpen then return end
  self.bankOpen = false
  local bank = self.windows.bank
  if bank and bank.frame:IsShown() then bank.frame:Hide() end
  if self.bankOpenedBags then self:Close() end
  self.bankOpenedBags = nil
end

function B:Place(win)
  local f, db = win.frame, ns.db
  f:SetScale(db.bagScale)
  local k = win.kind == "bank" and "bank" or "bag"
  if S.PlaceSpot(f, db, k .. "Left", k .. "Top", k .. "Point") then return end
  f:ClearAllPoints()
  if k == "bank" then
    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 40, -120)
  else
    f:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -60, 110)
  end
end

-- Everything in a set of bags: items (with what's needed to sort them) and empty slots.
function B:Read(bags)
  local items, empty, total = {}, {}, 0
  for _, bag in ipairs(bags) do
    local n = NumSlots(bag)
    for slot = 1, n do
      total = total + 1
      local it = self:ReadSlot(bag, slot)
      if it then
        items[#items + 1] = it
      else
        empty[#empty + 1] = { bag = bag, slot = slot }
      end
    end
  end
  return items, empty, total
end

-- What's in one slot, with what's needed to sort and paint it. Nil for an empty one.
function B:ReadSlot(bag, slot)
  local info = ItemInfo(bag, slot)
  if not (info and info.iconFileID) then return nil end
  local id = info.itemID
  local _, _, _, equipLoc, _, classID, subClassID = Instant(id or info.hyperlink or 0)
  local isQuest, questID, active = QuestInfo(bag, slot)
  local it = {
    bag = bag, slot = slot, id = id, icon = info.iconFileID, count = info.stackCount,
    locked = info.isLocked, quality = info.quality, link = info.hyperlink,
    classID = classID, subClassID = subClassID, equipLoc = equipLoc,
    isQuest = isQuest or classID == 12, starts = questID and questID > 0 and not active,
    questID = questID and questID > 0 and questID or nil,
    new = IsNew(bag, slot), bound = info.isBound,
  }
  it.name = id and ItemName(id)
  if not it.name then self.missingNames = true end
  it.leftover = self:Leftover(it)
  if (classID == 2 or classID == 4) and it.link then it.level = ItemLevel(it.link) end
  return it
end

-- In a fight the slots can't be moved or shown, but what's in them can still be painted: each
-- slot shows what it holds now, where it already is. They're put in order when the fight ends.
function B:Repaint(win)
  for _, b in ipairs(win.shown or {}) do
    self:Paint(b, self:ReadSlot(b.fuiBag, b.fuiSlot))
  end
  self:Search(win, win.frame.search:GetText() or "")
end

local function SortItems(a, b)
  if (a.quality or 0) ~= (b.quality or 0) then return (a.quality or 0) > (b.quality or 0) end
  if (a.classID or 99) ~= (b.classID or 99) then return (a.classID or 99) < (b.classID or 99) end
  if (a.subClassID or 99) ~= (b.subClassID or 99) then return (a.subClassID or 99) < (b.subClassID or 99) end
  if (a.name or "") ~= (b.name or "") then return (a.name or "") < (b.name or "") end
  if (a.count or 0) ~= (b.count or 0) then return (a.count or 0) > (b.count or 0) end
  if a.bag ~= b.bag then return a.bag < b.bag end
  return a.slot < b.slot
end

-- A heading's font: the one picked for bag headings on the Fonts page, if any; otherwise Space
-- Mono Bold, the titles' font in this look (not the overall font, as it was before 1.82.0).
function B:HeadFont(h)
  local size = ns.db.headerSize
  S.SetFont(h, size)
  if not S.RoleFont("bags.header") then pcall(h.SetFont, h, S.UI_FONTS.semibold, size, "") end
end

function B.HeadStyle() return ns.db.bagHeads == "band" and "band" or "line" end

function B:Header(win, i)
  local h = win.headers[i]
  if not h then
    h = S.Text(win.content, nil, "LEFT", "OVERLAY", ns.db.headerSize, nil, "bags.header")
    self:HeadFont(h)
    h:SetTextColor(T.text[1], T.text[2], T.text[3])
    -- its graphics: a gold marker before the name and a hatched strip after it; for the band
    -- style, a raised band behind and a gold block at its end
    local c = win.content
    h.kBand = S.Tex(c, "BACKGROUND", 1)
    h.kBand:SetColorTexture(T.raised[1], T.raised[2], T.raised[3], 1)
    h.kCap = S.Tex(c, "ARTWORK")
    h.kCap:SetColorTexture(A[1], A[2], A[3], 1)
    h.kMark = S.Tex(c, "ARTWORK")
    h.kMark:SetSize(6, 6)
    h.kMark:SetColorTexture(A[1], A[2], A[3], 1)
    h.kHatch = S.Hatch(S.Tex(c, "ARTWORK"))
    S.Paint(h.kHatch, 0.23, 0.23, 0.23, 1)
    h.kParts = { h.kBand, h.kCap, h.kMark, h.kHatch }
    win.headers[i] = h
  end
  h:Show()
  return h
end

function B:HideHead(h)
  h:Hide()
  for _, p in ipairs(h.kParts or {}) do p:Hide() end
end

-- Puts a heading and its graphics at x, y (from the content's top-left), `width` across.
function B:PlaceHead(win, h, x, y, width)
  local c, size = win.content, ns.db.headerSize
  local band = B.HeadStyle() == "band"
  local inset = band and 5 or 0 -- the band has a little room before its marker
  local cap = band and 6 or 0
  local mid = -(y + floor(size / 2) + 1)
  h:ClearAllPoints()
  h:SetPoint("TOPLEFT", c, "TOPLEFT", x + inset + HEAD_MARK, -y)
  h:SetWidth(max(1, width - inset - HEAD_MARK - cap))
  h.kMark:ClearAllPoints()
  h.kMark:SetPoint("LEFT", c, "TOPLEFT", x + inset, mid)
  h.kMark:Show()
  h.kBand:SetShown(band)
  h.kCap:SetShown(band)
  if band then
    h.kBand:ClearAllPoints()
    h.kBand:SetPoint("TOPLEFT", c, "TOPLEFT", x, -(y - 2))
    h.kBand:SetSize(width, size + 5)
    h.kCap:ClearAllPoints()
    h.kCap:SetPoint("TOPRIGHT", h.kBand, "TOPRIGHT", 0, 0)
    h.kCap:SetSize(cap, size + 5)
  end
  -- the hatch takes what the name leaves, if that's worth drawing
  local text = ceil(S.TextWidth(h, #(h:GetText() or "") * size * 0.6))
  local left = x + inset + HEAD_MARK + text + 7
  local room = x + width - cap - (band and 4 or 0) - left
  h.kHatch:SetShown(room >= 8)
  if room >= 8 then
    h.kHatch:ClearAllPoints()
    h.kHatch:SetPoint("LEFT", c, "TOPLEFT", left, mid)
    h.kHatch:SetSize(room, 5)
  end
end

-- One section for a bag that only takes some things. Its name comes from the bag itself,
-- which may not have reached the game yet.
function B:ReadLimitedBag(bag)
  local items, empty, total = self:Read({ bag })
  if total == 0 then return nil end
  local label = bag == REAGENT_BAG and "Reagent Bag" or BagName(bag)
  if not label or label == "" then
    label = "Special Bag"
    self.missingNames = true
  end
  return { label = label, items = items, empty = empty, total = total }
end

-- Sections flow left to right and wrap, like words on a line; empties next, full width;
-- then each bag that only takes some things on its own, in the order they're worn.
function B:Layout(win, hidden)
  local f = win.frame
  if not hidden and not f:IsShown() then win.dirty = true return end
  self.log = nil
  if InCombatLockdown() and self.protected then
    win.dirty = true
    if f:IsShown() then self:Repaint(win) end
    return
  end
  win.dirty = false
  local db = ns.db
  local bags, limited
  if win.kind == "bank" then
    bags, limited = BankIDs(), {}
  else
    bags, limited = SplitBagIDs()
  end
  self.missingNames = false
  local items, empty, total = self:Read(bags)
  local apart = {}
  for _, bag in ipairs(limited) do
    apart[#apart + 1] = self:ReadLimitedBag(bag)
  end

  local sections = {}
  if db.categories then
    local byCat = {}
    for _, it in ipairs(items) do
      local c = Categorise(it)
      if not byCat[c] then
        byCat[c] = { cat = c, items = {} }
        sections[#sections + 1] = byCat[c]
      end
      table.insert(byCat[c].items, it)
    end
    table.sort(sections, function(a, b) return a.cat.order < b.cat.order end)
  elseif #items > 0 then
    sections[1] = { cat = { label = "Items" }, items = items }
  end
  for _, s in ipairs(sections) do table.sort(s.items, SortItems) end

  local size, gx, gy = db.bagSize, db.gapX, db.gapY
  local cols = max(MIN_COLS, min(MAX_COLS, tonumber(db.bagCols) or MIN_COLS)) -- never 0: slots are placed modulo it
  local headH = db.headerSize + HEAD_PAD
  local width = cols * size + (cols - 1) * gx
  local x, y, rowH, colUsed = 0, 0, 0, 0
  local used, hi, shown = {}, 0, {}
  local newHead -- the New category's heading, if there is one this time
  local function place(b, px, py)
    if b.fuiX ~= px or b.fuiY ~= py or b.fuiSize ~= size then
      b.fuiX, b.fuiY, b.fuiSize = px, py, size
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", win.content, "TOPLEFT", px, -py)
      b:SetSize(size, size)
      S.GlowSize(b.fuiGlow, size)
    end
    b:Show()
    used[b] = true
  end
  local function HeadText(label, n) return label .. "  |cff8c8c8c" .. n .. "|r" end
  local headExtra = HEAD_MARK + (B.HeadStyle() == "band" and 15 or 0) -- what a heading takes besides its words
  -- How many columns a heading needs to be read whole (1.76.0: a one-item category's was cut
  -- to its one slot, "R..."). Measured on the heading it will be.
  local function headCols(label, n)
    local h = self:Header(win, hi + 1)
    h:SetWidth(0)
    h:SetText(HeadText(label, n))
    local w = S.TextWidth(h, #label * db.headerSize * 0.6) + 4 + headExtra
    return min(cols, max(1, ceil((w + gx) / (size + gx))))
  end
  local function grid(list, label, startCol, top, span, count, room)
    hi = hi + 1
    local h = self:Header(win, hi)
    h:ClearAllPoints()
    -- Centred between the category above and its own slots (1.75.0): the category gap and the
    -- heading's own 6 below are shared out evenly. Nothing above it: at the top.
    local hy = top
    if top > 0 then hy = top + floor((HEAD_PAD - db.sectionGap) / 2) end
    h:SetText(HeadText(label, count or #list))
    h.kX, h.kY = startCol * (size + gx), hy
    self:PlaceHead(win, h, h.kX, hy, max(span, room or span) * (size + gx) - gx)
    local rows = 0
    for i, it in ipairs(list) do
      local b = self:Button(win, it.bag, it.slot)
      if b then
        local c, r = (i - 1) % span, floor((i - 1) / span)
        place(b, (startCol + c) * (size + gx), top + headH + r * (size + gy))
        self:Paint(b, it.bag and it.icon and it or nil)
        shown[#shown + 1] = b
        rows = r + 1
      end
    end
    return headH + rows * (size + gy) - gy
  end

  -- (1.90.1) The last heading on each line runs on to the window's right edge, so its hatched
  -- strip doesn't stop short over the empty space beside a small category.
  local lastHead
  local function stretch()
    local h = lastHead
    lastHead = nil
    if h and h.kX and width - h.kX > 0 then self:PlaceHead(win, h, h.kX, h.kY, width - h.kX) end
  end
  for _, s in ipairs(sections) do
    local span = min(#s.items, cols)
    local room = max(span, headCols(s.cat.label, #s.items)) -- its slots, or its heading if wider
    if colUsed > 0 and colUsed + 1 + room > cols then
      stretch()
      y = y + rowH + db.sectionGap
      colUsed, rowH = 0, 0
    end
    local start = colUsed > 0 and colUsed + 1 or 0
    local h = grid(s.items, s.cat.label, start, y, span, nil, room)
    lastHead = win.headers[hi]
    if s.cat.key == "new" then newHead = win.headers[hi] end
    rowH = max(rowH, h)
    colUsed = start + room
  end
  stretch()
  if colUsed > 0 then y = y + rowH + db.sectionGap end
  if #empty > 0 then
    y = y + grid(empty, "Empty", 0, y, cols)
  elseif y > 0 then
    y = y - db.sectionGap
  end
  for _, a in ipairs(apart) do
    table.sort(a.items, SortItems)
    local filled = #a.items
    for _, slot in ipairs(a.empty) do a.items[#a.items + 1] = slot end
    if y > 0 then y = y + db.sectionGap end
    y = y + grid(a.items, a.label, 0, y, cols, ("%d/%d"):format(filled, a.total))
  end

  -- Slots not shown this time (bag swapped out) are hidden.
  for _, list in pairs(win.buttons) do
    for _, b in pairs(list) do
      if not used[b] then b:Hide() end
    end
  end
  for i = hi + 1, #win.headers do self:HideHead(win.headers[i]) end
  -- A click on the New heading says you've seen them all.
  if newHead and not win.newBtn then
    local nb = CreateFrame("Button", nil, win.content)
    S.Hover(nb, { bar = false })
    nb:SetScript("OnClick", function() B:AllSeen() end)
    nb:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
      GameTooltip:AddLine("New items", 1, 1, 1)
      GameTooltip:AddLine("Click: you've seen them all, so they go to their own categories. Otherwise they all stop being new when you close your bags.", 0.75, 0.75, 0.75, true)
      GameTooltip:Show()
    end)
    nb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    win.newBtn = nb
  end
  if win.newBtn then
    win.newBtn:SetShown(newHead ~= nil)
    if newHead then
      win.newBtn:ClearAllPoints()
      win.newBtn:SetAllPoints(newHead)
    end
  end
  win.shown = shown
  win.lastH = HEADER_H + FILTER_H + PAD - 2 + max(size, y) + PAD + FOOTER_H -- for its stand-in while moving frames

  win.content:SetSize(width, max(size, y))
  f:SetWidth(width + 2 * PAD)
  f:SetHeight(HEADER_H + FILTER_H + PAD - 2 + max(size, y) + PAD + FOOTER_H)
  f.free:SetText(("%d/%d"):format(total - #empty, total))
  self:PaintMoney(f)
  self:UpdateBuy(f)
  -- The bank's footer too: free slots after its buy button when that's showing, and your money.
  f.info:ClearAllPoints()
  if f.buy and f.buy:IsShown() then
    f.info:SetPoint("LEFT", f.buy, "RIGHT", 8 + 12, 0)
  else
    f.info:SetPoint("BOTTOMLEFT", PAD + 12 + (f.slotsWide or 0), 7)
  end
  f.info:SetText(#empty .. " free")
  local mark = #empty > 0 and T.ok or T.bad
  f.infoMark:SetColorTexture(mark[1], mark[2], mark[3], 1)
  self:Search(win, f.search:GetText() or "")
end

function B:Search(win, text)
  text = lower(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
  for _, b in ipairs(win.shown or {}) do
    local it = b.fuiItem
    local match = true
    if text ~= "" then match = it ~= nil and Matches(it, text) end
    b:SetAlpha(match and 1 or 0.18)
  end
end

function B:Refresh()
  for _, win in pairs(self.windows) do
    S.ThemePanel(win.frame, ns.db.alpha)
    for _, h in ipairs(win.headers) do self:HeadFont(h) end
    for _, list in pairs(win.buttons) do
      for _, b in pairs(list) do
        if b.fuiCount then S.SetFont(b.fuiCount, ns.db.countSize, ns.db.outline) end
        S.SetFont(b.fuiLevel, ns.db.countSize - 1, ns.db.outline)
      end
    end
    self:Place(win)
    if win.frame:IsShown() then self:Layout(win) else win.dirty = true end
  end
end

------------------------------------------------------------------------
-- Opening and closing (the game's bag functions now open these windows)
------------------------------------------------------------------------

function B:Open()
  local win = self:Window("bags")
  if not win.frame:IsShown() then win.frame:Show() end
end
function B:Close()
  local win = self.windows.bags
  if win and win.frame:IsShown() then win.frame:Hide() end
end
function B:Toggle()
  local win = self:Window("bags")
  if win.frame:IsShown() then self:Close() else self:Open() end
end

-- VoltUI follows the game's bag functions rather than replacing them. Everything the game
-- does after calling a replaced function counts as add-on code, and the game blocks some
-- of that: its bank opens the bags, then claims your free first bag slot.
--
-- These functions also call each other, and a hook only runs once its function is done,
-- so the outermost one reports last. Toggling your bags closes them piece by piece
-- first. So each report replaces the one before, and the last is acted on just after.
local FOLLOW = {
  OpenAllBags = "open", OpenBackpack = "open", OpenBag = "open",
  CloseAllBags = "close", CloseBackpack = "close",
  ToggleAllBags = "toggle", ToggleBackpack = "toggle",
}

function B:Follow(what)
  self.following = what
  if self.followQueued then return end
  self.followQueued = true
  C_Timer.After(0, function()
    B.followQueued = nil
    local act = B.following
    B.following = nil
    if act == "open" then
      B:Open()
    elseif act == "close" then
      B:Close()
    elseif act == "toggle" then
      B:Toggle()
    end
  end)
end

-- The game's bag windows still open and close as far as it knows, out of sight. Under a
-- hidden parent none of their show and hide code runs, and that's what VoltUI would be
-- running as add-on code if it hid them itself.
function B:PutAwayGameBags()
  if InCombatLockdown() then
    self.putAwayPending = true
    return
  end
  self.putAwayPending = nil
  local hidden = S.HiddenParent()
  for i = 1, (NUM_CONTAINER_FRAMES or 13) do
    local cf = _G["ContainerFrame" .. i]
    if cf and cf ~= self.keyFrame then cf:SetParent(hidden) end -- the key ring's window stays out while it's open
  end
  if ContainerFrameCombinedBags then ContainerFrameCombinedBags:SetParent(hidden) end
  -- The game still opens its bank window as far as it knows, which its own item clicks
  -- check, but none of its code for showing it runs.
  if self.ownBank and BankFrame then BankFrame:SetParent(hidden) end
end

-- The key ring (1.101.20). Where the client has one, its button opens it in one of the game's
-- own bag windows, and VoltUI keeps all of those out of sight: so keys couldn't be reached at
-- all. VoltUI's bags don't have a key ring section yet, so that one window is let back out, in
-- the game's own look, for as long as it holds the key ring.
local function KeyRingID()
  local E = Enum and Enum.BagIndex
  return _G.KEYRING_CONTAINER or (E and E.Keyring)
end

function B:HasKeyRing()
  local ab = _G.C_ActionBar
  if not (ab and ab.ShouldShowKeyring and KeyRingID()) then return false end
  local ok, yes = pcall(ab.ShouldShowKeyring)
  return ok and yes and true or false
end

function B:ShowKeyRing()
  local id = KeyRingID()
  if not id or InCombatLockdown() then return end
  for i = 1, (NUM_CONTAINER_FRAMES or 13) do
    local cf = _G["ContainerFrame" .. i]
    if cf and cf.GetID and cf:GetID() == id and cf:IsShown() then
      self.keyFrame = cf
      cf:SetParent(UIParent)
      self.keyHooked = self.keyHooked or {}
      if not self.keyHooked[cf] then
        self.keyHooked[cf] = true
        cf:HookScript("OnHide", function(frame)
          if B.keyFrame ~= frame then return end
          B.keyFrame = nil
          B:PutAwayGameBags() -- back out of sight, now or when the fight ends
        end)
      end
      return true
    end
  end
  return false
end

function B:TakeOver()
  for name, what in pairs(FOLLOW) do
    if type(_G[name]) == "function" then
      hooksecurefunc(name, function() B:Follow(what) end)
    end
  end
  if type(_G.ToggleBag) == "function" then
    hooksecurefunc("ToggleBag", function(id)
      if id ~= nil and id == KeyRingID() and B:HasKeyRing() then
        B.following = nil
        B:ShowKeyRing()
      elseif B.bankOpen and id and id > EQUIPPED then
        B.following = nil
      else
        B:Follow("toggle")
      end
    end)
  end
  self:PutAwayGameBags()
end

------------------------------------------------------------------------
-- Settings panel
------------------------------------------------------------------------

-- (1.88.0) How thick an item's rarity outline is (db.bagEdge, 1 to 4 pixels). A slot with no
-- rarity colour (empty, or a plain item with no glow on common items) keeps a 1-pixel line.
function B.Stroke(b, w)
  w = max(1, min(4, floor((tonumber(w) or 1) + 0.5)))
  if b.fuiStroke ~= w then
    b.fuiStroke = w
    S.EdgeWidth(b.fuiGlow.edges, w)
  end
end

local SETTINGS = {
  { group = "Layout", kind = "step", label = "Columns", key = "bagCols", min = 4, max = 30, step = 1 },
  { group = "Layout", kind = "step", label = "Slot size", key = "bagSize", min = 24, max = 64, step = 2 },
  { group = "Layout", kind = "step", label = "Horizontal gap", key = "gapX", min = 0, max = 20, step = 1 },
  { group = "Layout", kind = "step", label = "Vertical gap", key = "gapY", min = 0, max = 20, step = 1 },
  { group = "Layout", kind = "step", label = "Category gap", key = "sectionGap", min = 0, max = 40, step = 2 },
  { group = "Layout", kind = "step", label = "Scale", key = "bagScale", min = 0.5, max = 2, step = 0.05, fmt = "%.2f" },
  { group = "Text", kind = "cycle", stepper = true, label = "Font", key = "font", list = function() return S.FONTS end },
  { group = "Text", kind = "step", label = "Count size", key = "countSize", min = 8, max = 24, step = 1 },
  { group = "Text", kind = "step", label = "Heading size", key = "headerSize", min = 8, max = 24, step = 1 },
  { group = "Text", kind = "cycle", label = "Text outline", key = "outline", list = S.OUTLINES },
  { group = "Look", kind = "step", label = "Glow strength", key = "glow", min = 0, max = 1, step = 0.1, fmt = "%.1f" },
  { group = "Look", kind = "step", label = "Opacity", key = "alpha", min = 0, max = 1, step = 0.05, fmt = "%.2f" },
  { group = "Look", kind = "step", label = "Rarity outline", key = "bagEdge", min = 1, max = 4, step = 1,
    tip = "How thick the outline in an item's rarity colour is, in pixels. It grows inward, over the edge of the icon." },
  { group = "Look", kind = "toggle", label = "Categories", key = "categories" },
  { group = "Look", kind = "cycle", label = "Category headings", key = "bagHeads",
    list = { { key = "line", name = "Light" }, { key = "band", name = "Band" } },
    tip = "Light: a gold marker, the name and a short hatched strip. Band: each heading on a raised band with a gold end, like the settings' cards." },
  { group = "Look", kind = "toggle", label = "Item level on gear", key = "ilvl" },
  { group = "Look", kind = "toggle", label = "Mark quest items you don't need", key = "questLeft",
    tip = "A small red bin on a quest item once no quest in your log needs it (handed in or dropped), or that starts a quest you've done. Hover it to see why." },
  { group = "Look", kind = "toggle", label = "Glow on common items", key = "common" },
}
B.SETTINGS = SETTINGS
-- The bag window's Settings button, /volt bags and the minimap menu all open the settings
-- window on its Bags page (since 1.36.0; there used to be a small panel of its own here, with
-- the same rows). A second press closes it again.
function B:ToggleSettings()
  local E = ns.EditMode
  if not E then return end
  if E:IsOpen() and E.tab == "bags" and not E.query then
    E:Close()
  else
    E:Open("bags")
  end
end

------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------

local function LayoutShown()
  for _, win in pairs(B.windows) do
    if win.frame:IsShown() then B:Layout(win) else win.dirty = true end
  end
end

local pendingLayout
local function LayoutSoon(delay)
  if pendingLayout then return end
  pendingLayout = true
  C_Timer.After(delay or 0.05, function()
    pendingLayout = false
    LayoutShown()
  end)
end

function B:Enable()
  local loaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
  if loaded and loaded("Baganator") then
    FUI:Print("Bags: Baganator is on, so VoltUI bags are staying out of the way. Untick Baganator (and Baganator Sleek) to use them.")
    return
  end
  self.enabled = true
  local win = self:Window("bags")
  -- Make every slot now, out of combat.
  for _, bag in ipairs(BagIDs()) do
    for slot = 1, NumSlots(bag) do self:Button(win, bag, slot) end
  end
  local any = next(win.buttons[0] or {}) and win.buttons[0][1]
  self.protected = any and any.IsProtected and any:IsProtected() or false
  self.ownBank = self:UsesOwnBank()
  self:TakeOver()

  local ev = CreateFrame("Frame")
  for _, e in ipairs({ "BAG_UPDATE", "BAG_UPDATE_DELAYED", "ITEM_LOCK_CHANGED", "BAG_UPDATE_COOLDOWN",
                       "PLAYER_MONEY", "CURRENCY_DISPLAY_UPDATE", "GET_ITEM_INFO_RECEIVED", "QUEST_ACCEPTED", "QUEST_REMOVED",
                       "BAG_NEW_ITEMS_UPDATED", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "PLAYERBANKSLOTS_CHANGED",
                       "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "INVENTORY_SEARCH_UPDATE",
                       "BANK_TABS_CHANGED", "PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED", "BAG_CONTAINER_UPDATE",
                       "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" }) do
    pcall(ev.RegisterEvent, ev, e)
  end
  local function IsBanker(kind)
    local types = Enum and Enum.PlayerInteractionType
    return types and kind and (kind == types.Banker or kind == types.AccountBanker)
  end
  ev:SetScript("OnEvent", function(_, event, a1, a2)
    if event == "BAG_UPDATE_DELAYED" or event == "BAG_NEW_ITEMS_UPDATED" or event == "QUEST_ACCEPTED"
       or event == "QUEST_REMOVED" or event == "PLAYERBANKSLOTS_CHANGED" or event == "BANK_TABS_CHANGED"
       or event == "PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED" or event == "BAG_CONTAINER_UPDATE" then
      B.nameTries = 0
      LayoutSoon()
    elseif event == "BAG_UPDATE" then
      for _, w in pairs(B.windows) do w.dirty = true end
    elseif event == "ITEM_LOCK_CHANGED" then
      if a1 and a2 then
        for _, w in pairs(B.windows) do
          local b = w.buttons[a1] and w.buttons[a1][a2]
          if b and b.fuiItem then
            local info = ItemInfo(a1, a2)
            SetItemButtonDesaturated(b, info and info.isLocked)
          end
        end
      end
    elseif event == "BAG_UPDATE_COOLDOWN" then
      for _, w in pairs(B.windows) do
        for _, b in ipairs(w.shown or {}) do B:PaintCooldown(b) end
      end
    elseif event == "PLAYER_MONEY" or event == "CURRENCY_DISPLAY_UPDATE" then
      local w = B.windows.bags
      if w then B:PaintMoney(w.frame) end
      local bank = B.windows.bank
      if bank then B:PaintMoney(bank.frame) end
      if bank and bank.frame:IsShown() then B:UpdateBuy(bank.frame) end
    elseif event == "GET_ITEM_INFO_RECEIVED" then
      -- A few tries: this arrives for every item in the game, and a bag or item that never
      -- gives a name would otherwise lay the bags out again after each one.
      if B.missingNames and (B.nameTries or 0) < 8 then
        B.nameTries = (B.nameTries or 0) + 1
        LayoutSoon(0.3)
      end
    elseif event == "PLAYER_REGEN_DISABLED" then
      -- Just before the game locks the slots for the fight: closed bags that have changed are
      -- laid out now, so opening them in the fight shows them as they are, not empty or stale.
      local w = B.windows.bags
      if w and B.protected and w.dirty ~= false and not w.frame:IsShown() then B:Layout(w, true) end
    elseif event == "PLAYER_REGEN_ENABLED" then
      if B.putAwayPending then B:PutAwayGameBags() end
      if B.pendingButtons then
        B.pendingButtons = false
        LayoutShown()
      else
        for _, w in pairs(B.windows) do if w.dirty and w.frame:IsShown() then B:Layout(w) end end
      end
    elseif event == "BANKFRAME_OPENED" or (event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" and IsBanker(a1)) then
      if B.ownBank then B:BankerOpened() end
    elseif event == "BANKFRAME_CLOSED" or (event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" and IsBanker(a1)) then
      if B.ownBank then B:BankerClosed() end
    end
  end)
end

FUI:Register(B)

-- /volt bags ...
function B:Slash(arg)
  local db = ns.db
  local k, v = (arg or ""):match("^(%S*)%s*(.-)$")
  local n = tonumber(v)
  local map = { cols = "bagCols", columns = "bagCols", size = "bagSize", gapx = "gapX", gapy = "gapY",
                gap = "gap", sections = "sectionGap", count = "countSize", heading = "headerSize", scale = "bagScale" }
  if k == "" then
    if self.enabled then self:Open(); self:ToggleSettings() else FUI:Print("Bags are off. /volt bags on, then /reload.") end
    return
  end
  -- Inside what the settings window allows: 0 columns or a scale of 0 would be saved and
  -- break the bags at every login.
  local function clamp(key, value)
    for _, s in ipairs(SETTINGS) do
      if s.key == key and s.kind == "step" then return max(s.min, min(s.max, value)) end
    end
    return value
  end
  if k == "gap" and n then
    db.gapX, db.gapY = clamp("gapX", n), clamp("gapY", n)
  elseif map[k] and n then
    db[map[k]] = clamp(map[k], n)
  elseif k == "categories" or k == "ilvl" then
    db[k] = not db[k]
  elseif k == "reset" then
    for key, val in pairs(FUI.defaults) do
      if key:find("^bag") or key:find("^gap") or key:find("^bank") or key == "sectionGap" or key == "categories"
         or key == "ilvl" or key == "countSize" or key == "headerSize" or key == "outline" then
        db[key] = val
      end
    end
  else
    FUI:Print("/volt bags (settings) · cols 10 · size 36 · gapx 4 · gapy 4 · gap 4 · sections 10 · count 12 · heading 12 · scale 1 · categories · ilvl · reset")
    return
  end
  FUI:Refresh()
  FUI:Print("bags: %d columns, %d px slots, gaps %d x %d.", db.bagCols, db.bagSize, db.gapX, db.gapY)
end
