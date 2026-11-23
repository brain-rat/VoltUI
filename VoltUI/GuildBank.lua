-- VoltUI · Guild bank (since 1.67.0)
-- The game's guild bank window in VoltUI's look: a flat panel in place of the vault art, slots
-- like VoltUI's bags (cropped icons, a rarity outline and glow), flat tabs, buttons and search.
-- (1.86.0) In VoltUI's own windows' look: square greys, the title on a gold block, gold for the
-- hover and for the tab and page that are shown.
--
-- The game still runs the window: its slots, tabs, deposits, withdrawals, logs and tab info
-- are all its own. VoltUI only fades art and adds its own textures. It never hooks the window's
-- methods or writes fields the game reads; the rarity outlines and the chosen tab follow the
-- game's shared helpers (SetItemButtonQuality, PanelTemplates_SelectTab), hooked after they
-- run. Art the game shows and hides again is faded with SetAlpha, which showing doesn't undo.
-- Every step is guarded, since the window is the game's and may change.
--
-- The window comes from a load-on-demand add-on (Blizzard_GuildBanVoltUI), so it's skinned when
-- that loads: the first time you talk to a guild banker.

local _, ns = ...
local FUI, S = ns.FUI, ns.Style

local G = { key = "guildbank", name = "Guild bank" }
ns.GuildBank = G

local max = math.max
local Fade, FadeTextures, FlatHighlight, FlatButton = S.Fade, S.FadeTextures, S.FlatHighlight, S.FlatButton
local UI, A = S.UI, S.UI.accent

G.ADDON = "Blizzard_GuildBanVoltUI"
G.slots = {}   -- the game's item button -> its glow
G.tabs = {}    -- the game's bottom tabs -> their chosen line
G.done = false

local function Report(what, err)
  G.errors = G.errors or {}
  G.errors[#G.errors + 1] = what .. ": " .. tostring(err)
  if ns.Errors and ns.Errors.Add then pcall(ns.Errors.Add, ns.Errors, "Guild bank " .. what .. ": " .. tostring(err), nil, nil, "volt") end
end

-- One step of the skin; a failure is noted and the rest still runs.
local function Step(what, fn, ...)
  local ok, err = pcall(fn, ...)
  if not ok then Report(what, err) end
  return ok
end

-- A flat fill and 1px border behind `anchor`, drawn on `owner`'s back layers.
local function Back(owner, anchor, alpha, outset, col)
  local o = outset or 0
  col = col or UI.raised
  local fill = S.Tex(owner, "BACKGROUND", -8)
  fill:SetPoint("TOPLEFT", anchor, "TOPLEFT", -o, o)
  fill:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", o, -o)
  fill:SetColorTexture(col[1], col[2], col[3], alpha or 1)
  local edges = S.Edges(owner, "BACKGROUND", -7, anchor, o)
  S.ColorEdges(edges, UI.soft[1], UI.soft[2], UI.soft[3], 1)
  return fill, edges
end

------------------------------------------------------------------------
-- Parts
------------------------------------------------------------------------

-- A game button (Deposit, Withdraw, Purchase, Save): its three-piece art faded, a flat box.
-- The game swaps that art on press and disable, but never its alpha, so the fade holds.
function G:SkinButton(b)
  if type(b) ~= "table" or not b.GetRegions then return end
  Fade(b.Left, b.Middle, b.Right)
  if b.GetNormalTexture then Fade(b:GetNormalTexture(), b:GetPushedTexture(), b:GetDisabledTexture()) end
  S.GoldHighlight(b)
  Back(b, b, 1)
  local text = b.GetFontString and b:GetFontString()
  if text then S.FixFont(text, 11, nil, nil, "mono") end
end

-- One slot: cropped icon, a faint square behind it, VoltUI's rarity outline and glow. The
-- game's own slot art and quality border are faded; the glow is painted from its quality.
function G:SkinSlot(b)
  if type(b) ~= "table" or self.slots[b] then return end
  local name = b.GetName and b:GetName()
  if b.GetNormalTexture then Fade(b:GetNormalTexture()) end
  Fade(b.IconBorder, b.IconOverlay, b.IconOverlay2)
  local hl = b.GetHighlightTexture and b:GetHighlightTexture()
  if hl then hl:SetColorTexture(A[1], A[2], A[3], 0.22) end -- the bags' hover: a gold tint and outline
  S.ColorEdges(S.Edges(b, "HIGHLIGHT"), A[1], A[2], A[3], 1)
  local pushed = b.GetPushedTexture and b:GetPushedTexture()
  if pushed then pushed:SetColorTexture(1, 1, 1, 0.1) end
  local icon = b.icon or b.Icon or (name and _G[name .. "IconTexture"])
  if icon and icon.SetTexCoord then icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
  -- no rounded corners from the game's icon mask, as in the bags
  if b.Mask then
    if icon and icon.RemoveMaskTexture then pcall(icon.RemoveMaskTexture, icon, b.Mask) end
    if pushed and pushed.RemoveMaskTexture then pcall(pushed.RemoveMaskTexture, pushed, b.Mask) end
  end
  local bg = S.Tex(b, "BACKGROUND", -6)
  bg:SetAllPoints()
  bg:SetColorTexture(UI.card[1], UI.card[2], UI.card[3], 1)
  S.ColorEdges(S.Edges(b, "BACKGROUND", -5), UI.line[1], UI.line[2], UI.line[3], 1)
  local count = b.Count or (name and _G[name .. "Count"])
  if count and count.SetFont then
    S.SetFont(count, ns.db.countSize or 12, ns.db.outline)
    count:SetDrawLayer("OVERLAY", 7)
  end
  local glow = S.Glow(b, icon or b, b.GetWidth and b:GetWidth() or 37)
  S.PaintGlow(glow, nil)
  self.slots[b] = glow
end

-- The side tabs (one per bank tab): the game's tab art faded, the icon cropped and boxed.
function G:SkinBankTab(tab)
  if type(tab) ~= "table" then return end
  FadeTextures(tab)
  local b = tab.Button
  if type(b) ~= "table" then return end
  if b.GetNormalTexture then Fade(b:GetNormalTexture()) end
  local pushed = b.GetPushedTexture and b:GetPushedTexture()
  if pushed then pushed:SetColorTexture(1, 1, 1, 0.1) end
  S.GoldHighlight(b)
  local checked = b.GetCheckedTexture and b:GetCheckedTexture()
  if checked then
    checked:SetColorTexture(A[1], A[2], A[3], 0.35) -- the tab that's shown: gold
    if checked.SetBlendMode then checked:SetBlendMode("BLEND") end
  end
  if b.IconTexture and b.IconTexture.SetTexCoord then
    b.IconTexture:ClearAllPoints()
    b.IconTexture:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
    b.IconTexture:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
    b.IconTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  end
  Back(tab, b, 0.9)
end

-- The bottom tabs (Guild Bank, Log, Money Log, Info): flat, with an accent line under the
-- chosen one. The game shows and hides their art pieces, never their alpha.
function G:SkinTab(tab)
  if type(tab) ~= "table" or self.tabs[tab] then return end
  for _, t in ipairs(type(tab.TabTextures) == "table" and tab.TabTextures or {}) do Fade(t) end
  Fade(tab.Left, tab.Middle, tab.Right, tab.LeftActive, tab.MiddleActive, tab.RightActive,
    tab.LeftHighlight, tab.MiddleHighlight, tab.RightHighlight)
  if tab.GetHighlightTexture then Fade(tab:GetHighlightTexture()) end
  local hover = S.Tex(tab, "HIGHLIGHT")
  hover:SetPoint("TOPLEFT", tab, "TOPLEFT", 4, -7)
  hover:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -4, 5)
  hover:SetColorTexture(A[1], A[2], A[3], UI.hover)
  local box = CreateFrame("Frame", nil, tab)
  box:SetPoint("TOPLEFT", tab, "TOPLEFT", 3, -6)
  box:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -3, 4)
  box:SetFrameLevel(max(0, (tab:GetFrameLevel() or 1) - 1))
  Back(box, box, 1, 0, UI.card)
  -- the page that's shown: a gold tint and a solid gold line under it
  local line = S.Tex(tab, "OVERLAY", 2)
  line:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", 1, 1)
  line:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -1, 1)
  line:SetHeight(3)
  line:SetColorTexture(A[1], A[2], A[3], 1)
  line:Hide()
  local tint = S.Tex(box, "BACKGROUND", -6)
  tint:SetPoint("TOPLEFT", 1, -1)
  tint:SetPoint("BOTTOMRIGHT", -1, 1)
  tint:SetColorTexture(A[1], A[2], A[3], 0.2)
  tint:Hide()
  line.tint = tint
  self.tabs[tab] = line
  local f = _G.GuildBankFrame
  if f and tab.GetID and PanelTemplates_GetSelectedTab then
    local ok, sel = pcall(PanelTemplates_GetSelectedTab, f)
    if ok then line:SetShown(sel == tab:GetID()); tint:SetShown(sel == tab:GetID()) end
  end
end

-- The search box: its three-piece art faded, the dark box of VoltUI's bag search.
function G:SkinSearch(sb)
  if type(sb) ~= "table" then return end
  Fade(sb.Left, sb.Middle, sb.Right)
  local fill = S.Tex(sb, "BACKGROUND", -8)
  fill:SetPoint("TOPLEFT", sb, "TOPLEFT", -4, 0)
  fill:SetPoint("BOTTOMRIGHT", sb, "BOTTOMRIGHT", 0, 0)
  fill:SetColorTexture(UI.bg[1], UI.bg[2], UI.bg[3], 1)
  S.ColorEdges(S.Edges(sb, "BACKGROUND", -7, fill), UI.soft[1], UI.soft[2], UI.soft[3], 1)
  S.FixFont(sb, 11, nil, nil, "mono")
end

------------------------------------------------------------------------
-- The window
------------------------------------------------------------------------

function G:PaintPanel()
  local f = _G.GuildBankFrame
  if f and f.fuiPanel then S.ThemePanel(f, max(ns.db.alpha, 0.92)) end
end

function G:Skin()
  local f = _G.GuildBankFrame
  if self.done or type(f) ~= "table" then return end
  self.done = true

  -- The vault: every texture straight on the window (frame, corners, marble, title bands,
  -- portrait) is faded before VoltUI adds its own, and the guild's tabard with it.
  Step("frame", function()
    FadeTextures(f)
    Fade(f.Emblem)
    S.ThemePanel(f, max(ns.db.alpha, 0.92))
    local line = S.Tex(f, "BACKGROUND", -6)
    line:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -S.HEADER_H)
    line:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -S.HEADER_H)
    line:SetHeight(1)
    line:SetColorTexture(UI.line[1], UI.line[2], UI.line[3], 1)
  end)

  Step("title", function()
    local text = f.TitleText
    if type(text) == "table" and text.SetFont then
      -- the title in dark Space Mono on a gold block that follows the text's width
      local H = S.HEADER_H
      text:ClearAllPoints()
      text:SetPoint("LEFT", f, "TOPLEFT", 12, -H / 2)
      text:SetJustifyH("LEFT")
      S.FixFont(text, 13, nil, "semibold")
      text:SetTextColor(UI.primaryText[1], UI.primaryText[2], UI.primaryText[3])
      if text.SetDrawLayer then text:SetDrawLayer("OVERLAY", 2) end
      local now = text:GetText()
      if (now == nil or now == "") and _G.GUILD_BANK then text:SetText(_G.GUILD_BANK) end
      local block = S.Tex(f, "ARTWORK")
      block:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
      block:SetPoint("BOTTOMRIGHT", text, "RIGHT", 11, -(H / 2 - 1))
      S.BlockLook(f, block)
      G.block = block
    end
    for _, key in ipairs({ "TabTitle", "LimitLabel" }) do
      local fs = f[key]
      if type(fs) == "table" and fs.SetFont then S.FixFont(fs, key == "TabTitle" and 12 or 10, nil, nil, "mono") end
    end
  end)

  Step("close", function()
    local close = f.CloseButton
    if close then
      close:SetSize(20, 20)
      close:ClearAllPoints()
      close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)
      FlatButton(close, "x")
    end
  end)

  Step("slots", function()
    for _, col in ipairs(type(f.Columns) == "table" and f.Columns or {}) do
      Fade(col.Background)
      for _, b in ipairs(type(col.Buttons) == "table" and col.Buttons or {}) do
        Step("slot", G.SkinSlot, G, b)
      end
    end
  end)

  Step("bank tabs", function()
    for i, tab in ipairs(type(f.BankTabs) == "table" and f.BankTabs or {}) do
      Step("bank tab " .. i, G.SkinBankTab, G, tab)
    end
  end)

  Step("tabs", function()
    for i = 1, 4 do
      local tab = _G["GuildBankFrameTab" .. i]
      if tab then Step("tab " .. i, G.SkinTab, G, tab) end
    end
  end)

  Step("buttons", function()
    G:SkinButton(f.DepositButton)
    G:SkinButton(f.WithdrawButton)
    if type(f.BuyInfo) == "table" then G:SkinButton(f.BuyInfo.PurchaseButton) end
    if type(f.Info) == "table" then G:SkinButton(f.Info.SaveButton) end
  end)

  Step("money", function()
    if f.MoneyFrameBG then FadeTextures(f.MoneyFrameBG) end
    if f.MoneyFrameBG and f.MoneyFrameBG.NineSlice then Fade(f.MoneyFrameBG.NineSlice) end
    local line = S.Tex(f, "BACKGROUND", -6)
    line:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1, 24)
    line:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 24)
    line:SetHeight(1)
    line:SetColorTexture(UI.line[1], UI.line[2], UI.line[3], 1)
  end)

  Step("search", function() G:SkinSearch(_G.GuildItemSearchBox) end)

  Step("log", function()
    local log = f.Log
    if type(log) == "table" and type(log.MessageFrame) == "table" then Back(log, log.MessageFrame, 1, 4, UI.bg) end
    local info = f.Info
    if type(info) == "table" and type(info.ScrollFrame) == "table" then Back(info, info.ScrollFrame, 1, 4, UI.bg) end
  end)

  -- Rarity outlines: painted after the game's own helper draws each slot. A slot that
  -- isn't one of the guild bank's is skipped straight away.
  Step("quality hook", function()
    if type(SetItemButtonQuality) ~= "function" then return end
    hooksecurefunc("SetItemButtonQuality", function(button, quality)
      local glow = G.slots[button]
      if not glow then return end
      local tex = button.icon or button.Icon
      local has = tex and tex.GetTexture and tex:GetTexture()
      S.PaintGlow(glow, has and quality or nil)
    end)
  end)

  -- The game sets each slot's icon with SetItemButtonTexture every time the bank redraws, and
  -- that resets the icon's crop to the whole texture, bringing back the border drawn into
  -- every item icon inside VoltUI's outline. The crop goes back on straight after (1.68.1).
  Step("icon hook", function()
    if type(SetItemButtonTexture) ~= "function" then return end
    hooksecurefunc("SetItemButtonTexture", function(button)
      if not G.slots[button] then return end
      local icon = button.icon or button.Icon
      if icon and icon.SetTexCoord then icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    end)
  end)

  -- The chosen bottom tab's line.
  Step("tab hook", function()
    local function chosen(tab, on)
      local line = G.tabs[tab]
      if line then line:SetShown(on); if line.tint then line.tint:SetShown(on) end end
    end
    if type(PanelTemplates_SelectTab) == "function" then
      hooksecurefunc("PanelTemplates_SelectTab", function(tab) chosen(tab, true) end)
    end
    for _, fn in ipairs({ "PanelTemplates_DeselectTab", "PanelTemplates_SetDisabledTabState" }) do
      if type(_G[fn]) == "function" then hooksecurefunc(fn, function(tab) chosen(tab, false) end) end
    end
  end)
end

function G:Refresh()
  self:PaintPanel()
end

function G:Enable()
  self.enabled = true
  local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or _G.IsAddOnLoaded
  if loaded and loaded(self.ADDON) then
    self:Skin()
    return
  end
  local ev = CreateFrame("Frame")
  ev:RegisterEvent("ADDON_LOADED")
  ev:SetScript("OnEvent", function(frame, _, name)
    if name ~= G.ADDON then return end
    frame:UnregisterEvent("ADDON_LOADED")
    G:Skin()
  end)
end

FUI:Register(G)
