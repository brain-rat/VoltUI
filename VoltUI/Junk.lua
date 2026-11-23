-- VoltUI · Junk
-- Sells your grey (poor-quality) items when you open a vendor, then says what it
-- made. Hold Shift while opening the vendor to skip it. Repairs only if you've turned
-- that on (off to begin with). Greys you've
-- Alt-right-clicked in VoltUI's bags are kept.
-- Each slot is checked again right before selling, so nothing else gets sold or used.

local _, ns = ...
local FUI, S = ns.FUI, ns.Style

local J = { key = "junk", name = "Sell junk" }
ns.Junk = J

local CC = C_Container
local STEP = 0.2 -- seconds between sales, so the server keeps up

local function NumSlots(bag)
  local fn = CC and CC.GetContainerNumSlots or GetContainerNumSlots
  return fn and fn(bag) or 0
end

local function Info(bag, slot)
  if CC and CC.GetContainerItemInfo then return CC.GetContainerItemInfo(bag, slot) end
  local tex, count, locked, quality, _, _, link, _, noValue, itemID = GetContainerItemInfo(bag, slot)
  if not tex then return nil end
  return { stackCount = count, isLocked = locked, quality = quality, hyperlink = link, hasNoValue = noValue, itemID = itemID }
end

local function Sell(bag, slot)
  local fn = CC and CC.UseContainerItem or UseContainerItem
  if fn then fn(bag, slot) end
end

local function SellPrice(id)
  local fn = C_Item and C_Item.GetItemInfo or GetItemInfo
  local sell = select(11, fn(id))
  return sell or 0
end

local function Money(c)
  if GetCoinTextureString then return GetCoinTextureString(c) end
  return ("%dg %ds %dc"):format(math.floor(c / 10000), math.floor(c / 100) % 100, c % 100)
end

local function IsJunk(info)
  return info and info.quality == 0 and not info.hasNoValue and not info.isLocked and info.itemID
end

-- Grey items you've said to keep (since 1.80.0): Alt-right-click one in VoltUI's bags. By item, so
-- every stack of it is kept, on every character that uses these settings.
function J:Keeps(id)
  local keep = ns.db and ns.db.junkKeep
  return type(keep) == "table" and id ~= nil and keep[id] ~= nil
end

function J:KeepCount()
  local n = 0
  for _ in pairs(ns.db and type(ns.db.junkKeep) == "table" and ns.db.junkKeep or {}) do n = n + 1 end
  return n
end

function J:ToggleKeep(id, name)
  if type(id) ~= "number" then return end
  local db = ns.db
  if type(db.junkKeep) ~= "table" then db.junkKeep = {} end
  name = type(name) == "string" and name or ("item " .. id)
  if db.junkKeep[id] ~= nil then
    db.junkKeep[id] = nil
    FUI:Print("%s is sold with your junk again.", name)
  else
    db.junkKeep[id] = name
    FUI:Print("%s is kept: it isn't sold with your junk. Alt-right-click it again to change that.", name)
  end
  if next(db.junkKeep) == nil then db.junkKeep = nil end
end

function J:ForgetKept()
  ns.db.junkKeep = nil
end

-- Every grey item you can sell: { bag, slot, id, count, value }
function J:Find()
  local list = {}
  for bag = 0, (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4) do
    for slot = 1, NumSlots(bag) do
      local info = Info(bag, slot)
      if IsJunk(info) and not self:Keeps(info.itemID) then
        local price = SellPrice(info.itemID)
        if price > 0 then
          list[#list + 1] = { bag = bag, slot = slot, id = info.itemID, count = info.stackCount or 1, value = price * (info.stackCount or 1) }
        end
      end
    end
  end
  return list
end

function J:Run()
  if self.running then return end
  local list = self:Find()
  if #list == 0 then return end
  self.running = true
  local i, sold, total = 0, 0, 0
  local function step()
    if not self.atMerchant then
      self.running = false
      if sold > 0 then FUI:Print("Sold %d junk item%s for %s (the vendor closed before the rest).", sold, sold == 1 and "" or "s", Money(total)) end
      return
    end
    i = i + 1
    local it = list[i]
    if not it then
      self.running = false
      if sold > 0 then FUI:Print("Sold %d junk item%s for %s.", sold, sold == 1 and "" or "s", Money(total)) end
      return
    end
    local info = Info(it.bag, it.slot)
    -- still the same grey item in that slot?
    if IsJunk(info) and info.itemID == it.id and not self:Keeps(it.id) then
      Sell(it.bag, it.slot)
      sold = sold + 1
      total = total + SellPrice(it.id) * (info.stackCount or 1)
    end
    C_Timer.After(STEP, step)
  end
  step()
end

-- Repairs everything at a vendor that can, from your own money, and says what it cost. Off
-- unless "Repair your gear too" is on. The same three calls the game's own Repair All
-- button makes (MerchantFrame.lua). Returns the cost, or nil when nothing was repaired.
function J:Repair()
  if not (ns.db and ns.db.autoRepair) then return nil end
  if not (CanMerchantRepair and GetRepairAllCost and RepairAllItems) or not CanMerchantRepair() then return nil end
  local cost, can = GetRepairAllCost()
  if type(cost) ~= "number" or cost <= 0 or not can then return nil end
  local have = GetMoney and GetMoney() or 0
  if have < cost then
    FUI:Print("Repairs would cost %s, and you have %s: nothing repaired.", Money(cost), Money(have))
    return nil
  end
  RepairAllItems()
  FUI:Print("Repaired your gear for %s.", Money(cost))
  return cost
end

function J:Enable()
  self.enabled = true
  local ev = CreateFrame("Frame")
  ev:RegisterEvent("MERCHANT_SHOW")
  ev:RegisterEvent("MERCHANT_CLOSED")
  ev:SetScript("OnEvent", function(_, event)
    if event == "MERCHANT_SHOW" then
      J.atMerchant = true
      if IsShiftKeyDown and IsShiftKeyDown() then return end
      pcall(J.Repair, J)
      C_Timer.After(0.3, function() if J.atMerchant then J:Run() end end)
    else
      J.atMerchant = false
    end
  end)
end

FUI:Register(J)
