-- VoltUI · Web links
-- Alt-click an item or a quest to get its Wowhead (or ForeverDB) page, ready to copy (since
-- 1.60.0). The game doesn't let add-ons open a browser, so the address comes up in a small box,
-- already selected: Ctrl+C, then paste it into your browser.
--
-- Where it works:
--   * anything that shows an item's tooltip: bags, bank, the character window, loot, vendors,
--     the Upgrades window, an item link you clicked open from chat
--   * an item or quest link in chat (Alt-click the link itself)
--   * quests in the game's quest log, and another add-on's tracker that calls VoltUI.Links
-- Action buttons are left out: Alt is the self-cast key there.

local _, ns = ...
local FUI, S = ns.FUI, ns.Style

local L = { key = "links", name = "Web links" }
ns.Links = L
FUI.Links = L -- another add-on can ask for links through this

local A = S.UI.accent

L.SITES = {
  { key = "wowhead", name = "Wowhead" },
  { key = "foreverdb", name = "ForeverDB" },
}
local KIND_NAME = { item = "Item", quest = "Quest", npc = "NPC", spell = "Spell" }

-- The page for a thing: Wowhead's WoW Forever database (wowhead.com/forever, which has
-- Forever's own new items and quests too; Classic's pages until 1.60.1), or ForeverDB, which
-- has item, quest and spell pages; anything else goes to Wowhead.
function L.URL(kind, id, site)
  id = tonumber(id)
  if not (KIND_NAME[kind] and id and id > 0) then return nil end
  site = site or ns.db.linkSite or "wowhead"
  if site == "foreverdb" and (kind == "item" or kind == "quest" or kind == "spell") then
    return ("https://foreverdb.net/%s/%d"):format(kind, id)
  end
  return ("https://www.wowhead.com/forever/%s=%d"):format(kind, id)
end

------------------------------------------------------------------------
-- The box
------------------------------------------------------------------------

function L:Build()
  if self.box then return end
  local f = CreateFrame("Frame", "VoltUILinkBox", UIParent)
  f:SetSize(460, 78)
  f:SetFrameStrata("DIALOG")
  f:SetToplevel(true)
  f:SetClampedToScreen(true)
  f:EnableMouse(true)
  f:SetPoint("TOP", UIParent, "TOP", 0, -180)
  f:Hide()
  -- (1.85.0) in VoltUI's own windows' look: "Link" on a gold block, then what it's a link to
  local U = S.UI
  S.ThemePanel(f, math.max(ns.db.alpha or 0.85, 0.94))
  S.BlockHead(f, "Link", 13)
  f.close = S.PillButton(f, "x", 20, function() f:Hide() end, false, "Close")
  f.close:SetSize(20, 18)
  f.close:SetPoint("RIGHT", f, "TOPRIGHT", -3, -S.HEADER_H / 2)
  f.title = S.UIText(f, nil, "LEFT", nil, 11, nil, "mono")
  f.title:SetPoint("LEFT", f.block, "RIGHT", 9, 0)
  f.title:SetPoint("RIGHT", f.close, "LEFT", -8, 0)
  if f.title.SetWordWrap then f.title:SetWordWrap(false) end
  f.title:SetTextColor(U.text[1], U.text[2], U.text[3])

  local e = CreateFrame("EditBox", "VoltUILinkBoxText", f)
  e:SetPoint("TOPLEFT", 9, -(S.HEADER_H + 8))
  e:SetPoint("RIGHT", f, "RIGHT", -9, 0)
  e:SetHeight(22)
  e:SetAutoFocus(false)
  e:SetTextInsets(6, 6, 0, 0)
  S.FixFont(e, 11, nil, nil, "mono")
  local bg = S.Tex(e, "BACKGROUND", -8)
  bg:SetAllPoints()
  bg:SetColorTexture(U.bg[1], U.bg[2], U.bg[3], 1)
  S.ColorEdges(S.Edges(e, "BACKGROUND", -7), A[1], A[2], A[3], 1)
  -- It's for copying: typing puts the address back, and anything but Ctrl+C is ignored.
  e:SetScript("OnTextChanged", function(self, user)
    if user and self:GetText() ~= L.url then
      self:SetText(L.url or "")
      self:HighlightText()
    end
  end)
  e:SetScript("OnEscapePressed", function() f:Hide() end)
  e:SetScript("OnEnterPressed", function() f:Hide() end)
  e:SetScript("OnEditFocusLost", function(self) self:HighlightText(0, 0) end)
  e:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
  -- Ctrl+C copies and closes the box a moment later, so the copy lands first.
  e:SetScript("OnKeyDown", function(_, key)
    if key == "C" and IsControlKeyDown and IsControlKeyDown() then
      L.copied = true
      if C_Timer and C_Timer.After then C_Timer.After(0.15, function() if L.copied then f:Hide() end end) end
    end
  end)
  f.edit = e

  f.hint = S.UIText(f, nil, "LEFT", nil, 11)
  f.hint:SetPoint("BOTTOMLEFT", 9, 7)
  f.hint:SetTextColor(U.hint[1], U.hint[2], U.hint[3])
  f.site = S.UIButton(f, "", 150, function()
    ns.db.linkSite = ns.db.linkSite == "foreverdb" and "wowhead" or "foreverdb"
    if L.kind then L:Show(L.kind, L.id, L.name) end
  end, "Wowhead's WoW Forever database, or ForeverDB's.")
  f.site:SetPoint("BOTTOMRIGHT", -6, 4)
  f.site.text:SetJustifyH("RIGHT")
  f.site.text:SetTextColor(U.accentText[1], U.accentText[2], U.accentText[3])
  f:SetScript("OnHide", function() L.copied = nil; e:ClearFocus() end)
  table.insert(UISpecialFrames, "VoltUILinkBox")
  self.box = f
end

-- Shows the page's address, selected, for kind ("item", "quest") and id. name is optional.
function L:Show(kind, id, name)
  local url = L.URL(kind, id)
  if not url then return false end
  self:Build()
  local f = self.box
  self.kind, self.id, self.name, self.url, self.copied = kind, tonumber(id), name, url, nil
  local site = ns.db.linkSite == "foreverdb" and (kind == "item" or kind == "quest" or kind == "spell") and "ForeverDB" or "Wowhead"
  f.title:SetText(("%s on %s: %s"):format(KIND_NAME[kind], site, name and name ~= "" and name or ("#" .. id)))
  f.edit:SetText(url)
  f.hint:SetText("Ctrl+C to copy, then paste it into your browser")
  f.site.text:SetText(ns.db.linkSite == "foreverdb" and "Use Wowhead instead" or "Use ForeverDB instead")
  f.site:Show()
  f:Show()
  f.edit:SetFocus()
  f.edit:HighlightText()
  return true
end

-- Any web address, in the same box (1.101.23: addresses people post in chat). No site to
-- pick, so that button is put away until the box next shows an item or a quest.
function L:ShowURL(url)
  if type(url) ~= "string" or url == "" then return false end
  self:Build()
  local f = self.box
  self.kind, self.id, self.name, self.url, self.copied = nil, nil, nil, url, nil
  f.title:SetText("Web address")
  f.edit:SetText(url)
  f.hint:SetText("Ctrl+C to copy, then paste it into your browser")
  f.site:Hide()
  f:Show()
  f.edit:SetFocus()
  f.edit:HighlightText()
  return true
end

------------------------------------------------------------------------
-- What was Alt-clicked
------------------------------------------------------------------------

local function ItemName(id)
  local get = (C_Item and C_Item.GetItemNameByID) or (C_Item and C_Item.GetItemInfo) or GetItemInfo
  if not get then return nil end
  local ok, name = pcall(get, id)
  name = ok and S.Safe(name) or nil
  return type(name) == "string" and name or nil
end

local function QuestName(id)
  local get = C_QuestLog and C_QuestLog.GetTitleForQuestID
  if not get then return nil end
  local ok, name = pcall(get, id)
  name = ok and S.Safe(name) or nil
  return type(name) == "string" and name or nil
end

-- An item or quest link: "item:123:..." or "quest:456:..." (a whole chat link works too).
function L.FromLink(link)
  if type(link) ~= "string" or S.IsSecret(link) then return nil end
  local kind, id = link:match("|H(%a+):(%d+)")
  if not kind then kind, id = link:match("^(%a+):(%d+)") end
  if kind == "item" or kind == "quest" then
    local name = link:match("|h%[(.-)%]|h")
    return kind, tonumber(id), name
  end
end

-- An action button's Alt is self-cast, so those are left alone.
local function IsActionButton(f)
  if type(f) ~= "table" then return false end
  if f.action ~= nil and type(f.GetAttribute) == "function" then return true end
  local ok, t = pcall(function() return f.GetAttribute and f:GetAttribute("type") end)
  return ok and t ~= nil
end

-- A frame the game forbids add-ons to touch (a nameplate, some of its secure windows) raises an
-- error when it's read at all, so those count as nothing under the mouse.
local function Allowed(f)
  if type(f) ~= "table" then return nil end
  local ok, forbidden = pcall(function() return f.IsForbidden and f:IsForbidden() end)
  if not ok or forbidden then return nil end
  return f
end

local function Focus()
  if GetMouseFoci then
    local ok, list = pcall(GetMouseFoci)
    if ok and type(list) == "table" then return Allowed(list[1]) end
  end
  if GetMouseFocus then
    local ok, f = pcall(GetMouseFocus)
    if ok then return Allowed(f) end
  end
end

-- The item or quest a tooltip is showing, from the game's own record of it.
function L.FromTooltip(tip)
  if not (tip and tip.IsShown and tip:IsShown() and tip.GetTooltipData) then return nil end
  local ok, d = pcall(tip.GetTooltipData, tip)
  if not ok or type(d) ~= "table" then return nil end
  local T = Enum and Enum.TooltipDataType or {}
  local id = S.Safe(d.id)
  if type(id) ~= "number" then return nil end
  if d.type == T.Item then return "item", id, ItemName(id) end
  if T.Quest and d.type == T.Quest then return "quest", id, QuestName(id) end
end

-- An Alt-click anywhere: the frame under the mouse if it's a quest, else whatever item the
-- tooltip shows, if the tooltip belongs to that frame.
function L:OnAltClick()
  local f = Focus()
  if IsActionButton(f) then return false end
  local qid = type(f) == "table" and (f.questID or (type(f.info) == "table" and f.info.questID))
  qid = S.Safe(qid)
  if type(qid) == "number" and qid > 0 then return self:Show("quest", qid, QuestName(qid)) end
  for _, tip in ipairs({ GameTooltip, _G.ItemRefTooltip }) do
    if tip and tip.IsShown and tip:IsShown() then
      local owner = tip.GetOwner and tip:GetOwner()
      local over = tip == _G.ItemRefTooltip and tip.IsMouseOver and tip:IsMouseOver()
      if over or (owner and owner == f) or (owner and f and f.GetParent and f:GetParent() == owner) then
        if not IsActionButton(owner) then
          local kind, id, name = L.FromTooltip(tip)
          if kind then return self:Show(kind, id, name) end
        end
      end
    end
  end
  return false
end

function L:Enable()
  self.enabled = true
  -- Item and quest links in chat. The game still opens the link's own window as usual.
  if type(_G.SetItemRef) == "function" then
    hooksecurefunc("SetItemRef", function(link, text, button)
      if not (L.enabled and IsAltKeyDown and IsAltKeyDown()) then return end
      local kind, id, name = L.FromLink(text or link)
      if not kind then kind, id = L.FromLink(link) end
      if kind then L:Show(kind, id, name) end
    end)
  end
  local ev = CreateFrame("Frame")
  pcall(ev.RegisterEvent, ev, "GLOBAL_MOUSE_DOWN")
  ev:SetScript("OnEvent", function(_, _, button)
    if button ~= "LeftButton" or not (IsAltKeyDown and IsAltKeyDown()) then return end
    if IsControlKeyDown and (IsControlKeyDown() or IsShiftKeyDown()) then return end
    L:OnAltClick()
  end)
end

FUI:Register(L)
