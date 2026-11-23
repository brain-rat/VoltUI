-- VoltUI · Extras
-- Two small parts (since 1.48.0):
--
--  * Add-on buttons: other add-ons' minimap buttons, taken off the square minimap and put in a
--    drawer under it. A tab says how many there are; click it to open or close the drawer.
--    Off until you switch it on, since it moves other add-ons' buttons.
--
--  * Roll frames: the game's need / greed windows on a flat VoltUI panel. The game still runs them;
--    VoltUI only fades their art. Every step is guarded, since their make-up differs between clients.

local _, ns = ...
local FUI, S = ns.FUI, ns.Style

------------------------------------------------------------------------
-- Add-on buttons
------------------------------------------------------------------------

local D = { key = "drawer", name = "Add-on buttons drawer", found = {}, list = {} }
ns.Drawer = D

local CELL, GAP, PER_ROW, TAB_H = 26, 2, 7, 16
local floor, max = math.floor, math.max

-- The game's own buttons round the map, and VoltUI's: these stay where they are.
local KEEP = {
  VoltUIMinimapButton = true, MiniMapTracking = true, MiniMapTrackingButton = true, MiniMapMailFrame = true,
  MinimapZoomIn = true, MinimapZoomOut = true, GameTimeFrame = true, TimeManagerClockButton = true,
  MiniMapWorldMapButton = true, MinimapBackdrop = true, MiniMapBattlefieldFrame = true, MiniMapLFGFrame = true,
  QueueStatusButton = true, QueueStatusMinimapButton = true, VoltUIMinimapStrip = true, VoltUIMinimapInfo = true,
  VoltUIDrawerTab = true, VoltUIDrawer = true, MinimapCompassTexture = true, ExpansionLandingPageMinimapButton = true,
  AddonCompartmentFrame = true, -- the game's own add-on menu button
}
-- Named buttons on the minimap that aren't add-on launchers: map pins and the like.
local NOT_BUTTONS = { "Questie", "GatherMate", "HandyNotes", "Pin", "POI", "Node", "TomTomMapOverlay", "Spy_" }

-- Is this one of another add-on's minimap buttons? A named button, about the size of one.
function D.IsButton(f)
  if type(f) ~= "table" or not f.GetName or not f.IsObjectType then return false end
  local name = f:GetName()
  if type(name) ~= "string" or KEEP[name] or name:find("^VoltUI") then return false end
  if not name:find("^LibDBIcon") then
    for _, word in ipairs(NOT_BUTTONS) do
      if name:find(word, 1, true) then return false end
    end
  end
  if not (f:IsObjectType("Button") or f:IsObjectType("CheckButton")) then return false end
  local w, h = f:GetWidth() or 0, f:GetHeight() or 0
  if w < 16 or w > 48 or h < 16 or h > 48 then return false end
  return true
end

function D:Scan()
  if InCombatLockdown() then
    self.scanPending = true
    return
  end
  self.scanPending = nil
  local seen = {}
  local function take(f)
    if D.IsButton(f) and not seen[f] then
      seen[f] = true
      if not self.found[f] then
        self.found[f] = true
        self.list[#self.list + 1] = f
      end
    end
  end
  -- Only what's on the map itself: the frame round it holds the game's own buttons.
  for _, parent in ipairs({ Minimap, _G.MinimapBackdrop }) do
    if type(parent) == "table" and parent.GetChildren then
      for _, f in ipairs({ parent:GetChildren() }) do take(f) end
    end
  end
  local lib = LibStub and LibStub("LibDBIcon-1.0", true)
  if lib and lib.GetButtonList and lib.GetMinimapButton then
    for _, name in ipairs(lib:GetButtonList() or {}) do take(lib:GetMinimapButton(name)) end
  end
  self:Layout()
end

function D:Layout()
  local box, tab = self.box, self.tab
  if not box then return end
  if InCombatLockdown() then -- one of the buttons may be a protected one
    self.scanPending = true
    return
  end
  -- Under the readout line when that's showing, else under the zone strip.
  local info, strip = _G.VoltUIMinimapInfo, _G.VoltUIMinimapStrip
  local anchor = (info and info:IsShown() and info) or strip or Minimap
  tab:ClearAllPoints()
  tab:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -1)
  tab:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -1)
  -- As many across as the map is wide.
  local width = Minimap:GetWidth()
  if type(width) ~= "number" or width <= 0 then width = 198 end
  local perRow = max(1, floor((width + 2 - 6 + GAP) / (CELL + GAP)))
  local shown = {}
  for _, f in ipairs(self.list) do
    if f.IsShown and f:IsShown() then shown[#shown + 1] = f end -- one its add-on has hidden gives up its place
  end
  table.sort(shown, function(a, b) return (a:GetName() or "") < (b:GetName() or "") end)
  self.placing = true
  for i, f in ipairs(shown) do
    local col, row = (i - 1) % perRow, floor((i - 1) / perRow)
    pcall(function()
      f:SetParent(box)
      -- Offsets are in the button's own scale, so the scale comes first.
      local w = f:GetWidth() or 0
      local s = (w > 0) and (CELL / w) or 1
      f:SetScale(s)
      f:ClearAllPoints()
      f:SetPoint("TOPLEFT", box, "TOPLEFT", (3 + col * (CELL + GAP)) / s, -(3 + row * (CELL + GAP)) / s)
      f:SetAlpha(1) -- one set to show only under the mouse would be invisible here
      if f.SetFrameLevel then f:SetFrameLevel((box:GetFrameLevel() or 1) + 2) end
      -- Its own add-on may put it back on the map's edge (a drag, a refresh): then it's placed again.
      if not f.voltDrawer then
        f.voltDrawer = true
        hooksecurefunc(f, "SetPoint", function()
          if D.placing or not D.enabled then return end
          D:Later()
        end)
      end
    end)
  end
  self.placing = nil
  local rows = max(1, math.ceil(#shown / perRow))
  box:SetHeight(rows * (CELL + GAP) + 4)
  tab.text:SetText(#shown == 0 and "No add-on buttons" or ((ns.db.drawerOpen and "Hide" or "Add-ons") .. "  ·  " .. #shown))
  box:SetShown(ns.db.drawerOpen and #shown > 0)
  self.count = #shown
end

function D:Toggle()
  if InCombatLockdown() then
    FUI:Print("The add-on buttons drawer opens and closes out of combat.")
    return
  end
  ns.db.drawerOpen = not ns.db.drawerOpen
  self:Layout()
end

-- One look for buttons a moment from now, however many things ask for it.
function D:Later()
  if self.later then return end
  self.later = true
  local function go()
    D.later = nil
    D:Scan()
  end
  if C_Timer and C_Timer.After then C_Timer.After(2, go) else go() end
end

function D:Refresh()
  if self.tab then
    S.Panel(self.tab)
    S.Panel(self.box)
  end
end

function D:Enable()
  if not Minimap then return end
  self.enabled = true
  local anchor = _G.VoltUIMinimapInfo and _G.VoltUIMinimapInfo:IsShown() and _G.VoltUIMinimapInfo or _G.VoltUIMinimapStrip or Minimap
  local tab = CreateFrame("Button", "VoltUIDrawerTab", Minimap)
  tab:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -1)
  tab:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -1)
  tab:SetHeight(TAB_H)
  S.Panel(tab)
  S.Highlight(tab, 0.06)
  tab.text = S.Text(tab, nil, "CENTER", nil, 11)
  tab.text:SetPoint("CENTER")
  tab.text:SetTextColor(S.SUB[1], S.SUB[2], S.SUB[3])
  tab:SetScript("OnClick", function() D:Toggle() end)
  tab:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:SetText("Add-on buttons", 1, 1, 1)
    GameTooltip:AddLine("Other add-ons' minimap buttons, kept off the map. Click to open or close.", 0.75, 0.77, 0.8, true)
    GameTooltip:Show()
  end)
  tab:SetScript("OnLeave", function() GameTooltip:Hide() end)
  self.tab = tab
  local box = CreateFrame("Frame", "VoltUIDrawer", Minimap)
  box:SetPoint("TOPLEFT", tab, "BOTTOMLEFT", 0, -1)
  box:SetPoint("TOPRIGHT", tab, "BOTTOMRIGHT", 0, -1)
  box:SetHeight(CELL + 4)
  S.Panel(box)
  box:Hide()
  self.box = box
  -- Add-ons make their buttons as they load, some a moment after you log in.
  local ev = CreateFrame("Frame")
  ev:RegisterEvent("PLAYER_ENTERING_WORLD")
  ev:RegisterEvent("ADDON_LOADED")
  ev:RegisterEvent("PLAYER_REGEN_ENABLED")
  ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
      if D.scanPending then D:Scan() end
      return
    end
    D:Later()
  end)
  self:Scan()
end

FUI:Register(D)

------------------------------------------------------------------------
-- Roll frames
------------------------------------------------------------------------

local R = { key = "rolls", name = "Loot roll frames", skinned = {} }
ns.Rolls = R

function R:Skin(f)
  if type(f) ~= "table" or self.skinned[f] or not f.CreateTexture then return end
  self.skinned[f] = true
  local ok, err = pcall(function()
    local name = f.GetName and f:GetName()
    local function part(key) return f[key] or (name and _G[name .. key]) end
    for _, key in ipairs({ "Border", "Background", "SlotTexture", "NameFrame", "Corner", "Decoration" }) do
      local art = part(key)
      if type(art) == "table" and art.SetAlpha then art:SetAlpha(0) end
    end
    local back = CreateFrame("Frame", nil, f)
    back:SetAllPoints(f)
    -- Two levels down: the game puts the roll's timer bar one level under the frame each time
    -- it shows, and the panel must stay behind that.
    back:SetFrameLevel(max(0, (f:GetFrameLevel() or 2) - 2))
    S.Panel(back, max(ns.db.alpha, 0.9))
    f.voltBack = back
    local timer = part("Timer")
    if type(timer) == "table" and timer.SetStatusBarTexture then
      S.UseBarTexture(timer)
      if timer.SetStatusBarColor then timer:SetStatusBarColor(S.ACCENT[1], S.ACCENT[2], S.ACCENT[3]) end
      local art = timer.Background or timer.Border
      if type(art) == "table" and art.SetAlpha then art:SetAlpha(0) end
    end
    local text = part("Name")
    if type(text) == "table" and text.SetFont then S.SetFont(text, 13) end
  end)
  if not ok and ns.Errors and ns.Errors.Add then pcall(ns.Errors.Add, ns.Errors, "Roll frame: " .. tostring(err), nil, nil, "volt") end
end

function R:SkinAll()
  for i = 1, (_G.NUM_GROUP_LOOT_FRAMES or 4) do self:Skin(_G["GroupLootFrame" .. i]) end
  local box = _G.GroupLootContainer
  if type(box) == "table" and box.GetChildren then
    for _, f in ipairs({ box:GetChildren() }) do self:Skin(f) end
  end
end

function R:Refresh()
  for f in pairs(self.skinned) do
    if f.voltBack then S.Panel(f.voltBack, max(ns.db.alpha, 0.9)) end
  end
end

function R:Enable()
  self.enabled = true
  local ev = CreateFrame("Frame")
  pcall(ev.RegisterEvent, ev, "START_LOOT_ROLL")
  ev:SetScript("OnEvent", function()
    -- The frame for a roll is set up just after the event.
    if C_Timer and C_Timer.After then C_Timer.After(0, function() R:SkinAll() end) else R:SkinAll() end
  end)
  self:SkinAll()
end

FUI:Register(R)
