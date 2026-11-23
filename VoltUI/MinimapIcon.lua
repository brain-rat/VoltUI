-- VoltUI · Minimap icon
-- A small "k" on the minimap's edge. Click it for a short menu: the settings, moving
-- frames, heal mode, quick keybinds and VoltUI's lists. Right-click goes straight to the
-- settings. Drag it to move it around the edge.
--
-- Until 1.54.0 the menu also held samples, a switch for every part of VoltUI and "Hide this
-- icon": twenty-odd rows. Those are on the settings window's Home and General pages.

local _, ns = ...
local FUI, S = ns.FUI, ns.Style

local I = { key = "icon", name = "Minimap icon", rows = {} }
ns.MinimapIcon = I

local SIZE, WIDTH, ROW_H, HEAD_H, HEAD = 24, 220, 22, 22, 28
local A = S.UI.accent
local rad, deg, atan2, cos, sin, abs, max = math.rad, math.deg, math.atan2 or math.atan, math.cos, math.sin, math.abs, math.max

------------------------------------------------------------------------
-- Where it sits
------------------------------------------------------------------------

-- Inside the corners on the square map, centred on the edge of a round one.
function I:Place()
  local b, angle = self.button, rad(ns.db.iconAngle)
  local dx, dy = cos(angle), sin(angle)
  local w, h = Minimap:GetWidth() / 2, Minimap:GetHeight() / 2
  local x, y
  if ns.db.map ~= false then
    local m = max(abs(dx), abs(dy))
    x, y = dx / m * (w - SIZE / 2 - 3), dy / m * (h - SIZE / 2 - 3)
  else
    x, y = dx * w, dy * h
  end
  b:ClearAllPoints()
  b:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function Dragging(b)
  local cx, cy = Minimap:GetCenter()
  if not cx then return end
  local x, y = GetCursorPosition()
  local s = Minimap:GetEffectiveScale()
  ns.db.iconAngle = deg(atan2(y / s - cy, x / s - cx)) % 360
  I:Place()
end

------------------------------------------------------------------------
-- The menu
------------------------------------------------------------------------

local function ReloadPending() return FUI:ReloadPending() end

-- Lines another add-on adds to the menu: { section = "Windows", text, fn, when }.
I.extra = {}
function I:AddAction(item)
  for _, it in ipairs(self.extra) do
    if it.text == item.text then return end
  end
  self.extra[#self.extra + 1] = item
end

local function Items()
  local list = {}
  local function section(t) list[#list + 1] = { kind = "section", text = t } end
  local function action(t, fn, opts)
    local it = { kind = "action", text = t, fn = fn }
    for k, v in pairs(opts or {}) do it[k] = v end
    list[#list + 1] = it
  end

  section("Customise")
  action("Settings", function() ns.EditMode:Open() end, { note = ns.Errors and ns.Errors.unseen and "error" or nil })
  if #S.movers > 0 then
    action("Move frames", function()
      if FUI.unlocked then
        FUI:SetUnlocked(false)
      else
        FUI:SetUnlocked(true)
      end
    end, {
      on = FUI.unlocked, off = InCombatLockdown(), note = FUI.unlocked and "on" or nil,
    })
  end
  if ns.Raid and ns.Raid.enabled then
    local on = ns.Raid:HealOn()
    action("Heal mode", function() ns.Raid:ToggleHeal() end, { on = on, note = on and "on" or nil })
  end
  if ns.ActionBars.enabled then
    action("Quick keybinds", function() ns.ActionBars:QuickKeys() end, { off = InCombatLockdown() })
  end

  section("Windows")
  for _, it in ipairs(I.extra) do
    if (it.section or "Windows") == "Windows" and (not it.when or it.when()) then action(it.text, it.fn) end
  end

  -- A part switched on or off in the settings and not yet applied.
  if ReloadPending() then
    action("Reload to apply", function() FUI:Reload() end, { primary = true })
  end
  return list
end

function I:Row(i)
  local r = self.rows[i]
  if r then return r end
  r = CreateFrame("Button", nil, self.menu)
  r:SetPoint("TOPLEFT", self.menu, "TOPLEFT", 1, 0)
  -- (1.66.0) rounded hover and main-button fill, and Obsidian's switch
  r.hl = S.Highlight(r, 0.06, S.UI.r.seg)
  r.bg = S.Tex(r, "BACKGROUND")
  r.bg:SetAllPoints()
  S.Round(r.bg, S.UI.r.seg)
  r.text = S.UIText(r, nil, "LEFT", "OVERLAY", 13)
  r.note = S.UIText(r, nil, "RIGHT", "OVERLAY", 11)
  r.note:SetPoint("RIGHT", -9, 0)
  r.note:SetTextColor(S.UI.hint[1], S.UI.hint[2], S.UI.hint[3])
  r.track = S.Tex(r, "ARTWORK")
  r.track:SetSize(26, 14)
  r.track:SetPoint("RIGHT", -9, 0)
  S.Round(r.track, S.UI.r.switch)
  r.knob = S.Disc(S.Tex(r, "OVERLAY"), 10)
  r.knob:SetSize(10, 10)
  r:SetScript("OnClick", function(self)
    local it = self.item
    if not it or it.kind == "section" or it.off then return end
    if it.kind == "switch" then
      ns.db[it.key] = not (ns.db[it.key] ~= false)
      I:Fill() -- stays open, so several can be switched
    else
      I:CloseMenu()
      it.fn()
    end
  end)
  self.rows[i] = r
  return r
end

function I:Paint(r, it)
  r.item = it
  r.track:Hide()
  r.knob:Hide()
  r.note:SetText("")
  S.Paint(r.bg, 0, 0, 0, 0)
  S.PlainLook(r)
  r.text:ClearAllPoints()
  r.text:SetPoint("LEFT", 9, 0)
  r.text:SetText(it.text)
  if not r.mark then
    r.mark = S.Tex(r, "ARTWORK")
    r.mark:SetSize(6, 6)
    r.mark:SetPoint("LEFT", 9, 0)
    r.mark:SetColorTexture(A[1], A[2], A[3], 1)
  end
  r.mark:SetShown(it.kind == "section")
  if it.kind == "section" then
    -- (1.81.0) a heading: a gold square, then the name in small mono capitals
    S.Mono(r.text, 10, nil, "medium")
    r.text:ClearAllPoints()
    r.text:SetPoint("LEFT", r.mark, "RIGHT", 7, 0)
    r.text:SetText((it.text or ""):upper())
    r.text:SetTextColor(S.UI.hint[1], S.UI.hint[2], S.UI.hint[3])
    r.hl:Hide()
    r:EnableMouse(false)
    return
  end
  S.FixFont(r.text, 13, nil, "regular", "inter")
  r.hl:Show()
  r:EnableMouse(true)
  if it.kind == "switch" then
    local on = ns.db[it.key] ~= false
    r.text:SetTextColor(S.UI.label[1], S.UI.label[2], S.UI.label[3])
    r.track:Show()
    r.knob:Show()
    local T = S.UI
    if on then
      S.Paint(r.track, A[1], A[2], A[3], 1)
    else
      S.Paint(r.track, T.control[1], T.control[2], T.control[3], 1)
    end
    S.Paint(r.knob, T.knob[1], T.knob[2], T.knob[3], 1)
    r.knob:ClearAllPoints()
    r.knob:SetPoint(on and "RIGHT" or "LEFT", r.track, on and "RIGHT" or "LEFT", on and -2 or 2, 0)
  elseif it.primary then
    S.PrimaryLook(r, r.bg)
  elseif it.off then
    r.text:SetTextColor(S.UI.off[1], S.UI.off[2], S.UI.off[3])
    r.note:SetText("not in combat")
  else
    r.text:SetTextColor(S.UI.text[1], S.UI.text[2], S.UI.text[3])
    if it.note then r.note:SetText(it.note) end
  end
end

function I:Fill()
  local items = Items()
  local y = HEAD + 3
  for i, it in ipairs(items) do
    local r = self:Row(i)
    local h = it.kind == "section" and HEAD_H or ROW_H
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", self.menu, "TOPLEFT", 1, -y)
    r:SetPoint("TOPRIGHT", self.menu, "TOPRIGHT", -1, -y)
    r:SetHeight(h)
    self:Paint(r, it)
    r:Show()
    y = y + h
  end
  for i = #items + 1, #self.rows do
    self.rows[i].item = nil
    self.rows[i]:Hide()
  end
  self.menu:SetHeight(y + 5)
end

function I:BuildMenu()
  if self.menu then return end
  local m = CreateFrame("Frame", "VoltUIMenu", UIParent)
  m:SetFrameStrata("DIALOG")
  m:SetToplevel(true)
  m:SetClampedToScreen(true)
  m:EnableMouse(true)
  m:SetWidth(WIDTH)
  m:Hide()
  S.ThemePanel(m, math.max(ns.db.alpha, 0.94))
  S.TitleBar(m, "Options", HEAD)
  self.menu = m
  table.insert(UISpecialFrames, "VoltUIMenu") -- Esc closes it
  -- A click anywhere else closes it. Only listening while it's open.
  m:SetScript("OnShow", function(self) pcall(self.RegisterEvent, self, "GLOBAL_MOUSE_DOWN") end)
  m:SetScript("OnHide", function(self) pcall(self.UnregisterEvent, self, "GLOBAL_MOUSE_DOWN") end)
  m:SetScript("OnEvent", function(self)
    if MouseIsOver and not MouseIsOver(self) and not MouseIsOver(I.button) then self:Hide() end
  end)
end

function I:OpenMenu()
  self:BuildMenu()
  local m = self.menu
  S.ThemePanel(m, math.max(ns.db.alpha, 0.94))
  self:Fill()
  m:ClearAllPoints()
  m:SetPoint("TOPRIGHT", self.button, "BOTTOMLEFT", -2, -2)
  m:Show()
  GameTooltip:Hide()
end

function I:CloseMenu()
  if self.menu then self.menu:Hide() end
end

function I:ToggleMenu()
  if self.menu and self.menu:IsShown() then self:CloseMenu() else self:OpenMenu() end
end

------------------------------------------------------------------------
-- The icon
------------------------------------------------------------------------

-- (1.81.0) The icon is the title bar's block in small: solid gold, square, with VoltUI's mark
-- in dark (the bolt since 1.105.0). Under the mouse it lightens a step.
function I:PaintButton()
  local b = self.button
  if not b then return end
  local p = S.ThemePanel(b, 1, S.UI.r.button)
  S.Paint(p.fill, A[1], A[2], A[3], 1)
  S.ColorEdges(p.edges, S.UI.primaryText[1], S.UI.primaryText[2], S.UI.primaryText[3], 1)
  local dark = S.UI.primaryText
  b.glyph:SetVertexColor(dark[1], dark[2], dark[3], 1)
end

function I:Refresh()
  self:PaintButton()
end

-- A red dot on the icon while there's an error of VoltUI's you haven't looked at.
function I:Badge(on)
  if self.button then self.button.badge:SetShown(on and true or false) end
end

-- The settings window's switch: hides it now; showing it again needs a reload if it was off
-- when the game started.
function I:SetShown(on)
  if self.button then
    self.button:SetShown(on)
  elseif on then
    FUI:NeedReload()
  end
end

function I:Enable()
  if not Minimap then return end
  self.enabled = true
  local b = CreateFrame("Button", "VoltUIMinimapButton", Minimap)
  b:SetSize(SIZE, SIZE)
  b:SetFrameStrata("MEDIUM")
  b:SetFrameLevel(Minimap:GetFrameLevel() + 8)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:RegisterForDrag("LeftButton")
  -- (1.66.0) In VoltUI's window look: a rounded square, a rounded hover, VoltUI's mark, and a
  -- round red dot for an unseen error. (1.105.0) The mark is the bolt (Media\Bolt.tga).
  b.hover = S.Tex(b, "HIGHLIGHT")
  b.hover:SetAllPoints()
  b.hover:SetColorTexture(1, 1, 1, 0.3)
  b.glyph = S.Tex(b, "OVERLAY")
  b.glyph:SetTexture(S.MEDIA .. "Bolt")
  b.glyph:SetSize(16, 16)
  b.glyph:SetPoint("CENTER", 0, 0)
  self.button = b
  self:PaintButton()
  b.badge = S.Disc(S.Tex(b, "OVERLAY", 7), 6)
  b.badge:SetPoint("TOPRIGHT", -3, -3)
  S.Paint(b.badge, S.UI.bad[1], S.UI.bad[2], S.UI.bad[3], 1)
  b.badge:Hide()
  b:SetScript("OnClick", function(_, button)
    if button == "RightButton" then
      I:CloseMenu()
      if ns.EditMode:IsOpen() then ns.EditMode:Close() else ns.EditMode:Open() end
    else
      I:ToggleMenu()
    end
  end)
  b:SetScript("OnDragStart", function(self)
    I:CloseMenu()
    self:SetScript("OnUpdate", Dragging)
  end)
  b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  b:SetScript("OnEnter", function(self)
    if I.menu and I.menu:IsShown() then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("VoltUI", A[1], A[2], A[3])
    GameTooltip:AddLine("Click: menu", 1, 1, 1)
    GameTooltip:AddLine("Right-click: settings", 1, 1, 1)
    if ns.Errors and ns.Errors.unseen then GameTooltip:AddLine("VoltUI caught an error: Settings > Errors", 1, 0.5, 0.45) end
    GameTooltip:AddLine("Drag: move around the map", 0.7, 0.72, 0.76)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  self.button = b
  self:Place()
end

FUI:Register(I)
