-- VoltUI · Questie skin
-- Gives the Questie add-on VoltUI's flat look: its tracker, its settings window and the
-- My Journey window.
--
-- Questie stays its own add-on, installed and updated on its own, and nothing of it is
-- copied here. This only restyles its frames while the game runs, and does nothing when
-- Questie isn't installed. Its name and logo belong to its authors, so its icons stay.
--
-- Three rules, because each one breaks something quietly:
--  * Only hook functions that never yield. Questie builds much of its UI in coroutines
--    (TrackerLinePool.Initialize, QuestieJourney:Initialize) and a yield can't pass through
--    a hooksecurefunc wrapper. Hooks here sit on leaf functions and on what a click calls.
--  * Leave the tracker's quest item buttons alone. They're secure buttons used in combat.
--  * AceGUI's widgets are pooled and shared with other add-ons such as WeakAuras, so a
--    released widget can come back in someone else's window. Inside My Journey only colours
--    change, and they're put back as soon as a widget leaves the window.

local _, ns = ...
local FUI, S = ns.FUI, ns.Style

local Q = { key = "questie", name = "Questie skin", missing = {}, reported = {} }
ns.QuestieSkin = Q

local max = math.max

local OPTIONS_WINDOW = "QuestieStandaloneSettings"
local FLAT_BACKDROP = { bgFile = S.WHITE, edgeFile = S.WHITE, edgeSize = 1 }
local FONT_KEYS = { "trackerFontHeader", "trackerFontZone", "trackerFontQuest", "trackerFontObjective" }

-- Questie's defaults are small for VoltUI's fonts. { setting, Questie's default, VoltUI's size }
local FONT_SIZES = {
  { "trackerFontSizeHeader", 12, 13 },
  { "trackerFontSizeZone", 12, 12 },
  { "trackerFontSizeQuest", 10, 12 },
  { "trackerFontSizeObjective", 10, 12 },
}

-- A Questie update can rename anything here, and that shouldn't cost it or VoltUI anything
-- more than the look of one part. Says so once per part.
local function Guard(what, fn, ...)
  local ok, err = pcall(fn, ...)
  if not ok and not Q.reported[what] then
    Q.reported[what] = tostring(err)
    FUI:Print("Questie skin: couldn't style the %s. Questie itself still works. %s", what, tostring(err))
  end
end

local function After(module, name, what, fn)
  if type(module[name]) ~= "function" then
    Q.missing[#Q.missing + 1] = name
    return
  end
  hooksecurefunc(module, name, function(...) Guard(what, fn, ...) end)
end

local function Profile()
  local db = Questie and Questie.db
  return db and db.profile
end

local function IsTexture(r)
  return r.IsObjectType and r:IsObjectType("Texture")
end

local function IsFontString(r)
  return r.IsObjectType and r:IsObjectType("FontString")
end

-- Same font as VoltUI's other settings windows, at the size the text already has.
local function KeepSize(fs, fallback)
  if type(fs) ~= "table" then return end
  local _, size, flags = fs:GetFont()
  S.FixFont(fs, size or fallback or 12, flags)
end

------------------------------------------------------------------------
-- Tracker
------------------------------------------------------------------------

function Q:ApplyFonts()
  if not ns.db.questieFonts then return end
  local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
  local p = Profile()
  if not (LSM and p) then return end
  local f = S.Font()
  if not LSM:IsValid("font", f.name) then LSM:Register("font", f.name, f.path) end
  for _, key in ipairs(FONT_KEYS) do p[key] = f.name end
end

-- The first time only, then these are Questie's own settings to change. Its background
-- and border options, its fader and its colour picker all keep working.
function Q:Seed()
  local p = Profile()
  if not p or p.voltSkinned then return end
  p.voltSkinned = true
  p.trackerBackdropEnabled, p.currentBackdropEnabled = true, true
  p.trackerBorderEnabled, p.currentBorderEnabled = true, true
  p.trackerBackdropColor = { r = S.BG[1], g = S.BG[2], b = S.BG[3], a = ns.db.alpha }
  for _, v in ipairs(FONT_SIZES) do
    if p[v[1]] == v[2] then p[v[1]] = v[3] end
  end
end

-- Questie keeps setting these colours as the tracker fades, so the art changes once and
-- the colours are followed from then on.
function Q:SkinTracker()
  local base = self.TrackerBaseFrame.baseFrame
  if not base or self.trackerDone then return end
  self.trackerDone = true
  base:SetBackdrop(FLAT_BACKDROP)

  local strip = S.Tex(base, "BACKGROUND", -6)
  strip:SetColorTexture(1, 1, 1, 0.06)
  strip:Hide()
  self.strip = strip

  local painting = false
  hooksecurefunc(base, "SetBackdropBorderColor", function(frame, _, _, _, a)
    if painting then return end
    painting = true
    frame:SetBackdropBorderColor(S.EDGE[1], S.EDGE[2], S.EDGE[3], a or 1)
    painting = false
  end)
  hooksecurefunc(base, "SetBackdropColor", function(_, _, _, _, a) strip:SetAlpha(a or 1) end)
  base:SetBackdropColor(0, 0, 0, 0)
  base:SetBackdropBorderColor(0, 0, 0, 0)

  if type(base.sizer) == "table" then
    for _, r in ipairs({ base.sizer:GetRegions() }) do
      if IsTexture(r) then r:SetVertexColor(S.EDGE[1], S.EDGE[2], S.EDGE[3]) end
    end
  end
end

function Q:SkinHeader()
  local header = self.TrackerHeaderFrame.headerFrame
  local p = Profile()
  if not (header and p) then return end
  local quests = header.trackedQuests
  if quests and quests.label then
    quests.label:SetTextColor(S.ACCENT[1], S.ACCENT[2], S.ACCENT[3])
  end
  local strip = self.strip
  local base = self.TrackerBaseFrame.baseFrame
  if not (strip and base) then return end
  strip:ClearAllPoints()
  if p.moveHeaderToBottom then
    strip:SetPoint("BOTTOMLEFT", base, "BOTTOMLEFT", 1, 1)
    strip:SetPoint("BOTTOMRIGHT", base, "BOTTOMRIGHT", -1, 1)
  else
    strip:SetPoint("TOPLEFT", base, "TOPLEFT", 1, -1)
    strip:SetPoint("TOPRIGHT", base, "TOPRIGHT", -1, -1)
  end
  strip:SetHeight((p.trackerFontSizeHeader or 12) + 16)
  local char = Questie.db.char
  strip:SetShown(p.trackerHeaderEnabled and char and char.isTrackerExpanded)
end

-- /volt edit moves the tracker like every other frame. Questie's own drag code does the work,
-- because it saves the spot against whichever corner the tracker's set to grow from. It only
-- runs unlocked, so the tracker counts as unlocked for the length of the drag.
function Q:StartDrag()
  local p, base = Profile(), self.TrackerBaseFrame.baseFrame
  if InCombatLockdown() or self.lockedBeforeDrag ~= nil then return end
  self.lockedBeforeDrag = p.trackerLocked and true or false
  p.trackerLocked = false
  base:SetMovable(true)
  if not self.TrackerBaseFrame.OnDragStart(base, "LeftButton") then
    p.trackerLocked = self.lockedBeforeDrag
    self.lockedBeforeDrag = nil
  end
end

function Q:StopDrag()
  if self.lockedBeforeDrag == nil then return end
  local locked = self.lockedBeforeDrag
  self.lockedBeforeDrag = nil
  local ok, err = pcall(self.TrackerBaseFrame.OnDragStop, self.TrackerBaseFrame.baseFrame, "LeftButton")
  Profile().trackerLocked = locked
  if not ok then error(err, 0) end
end

function Q:Mover()
  if self.mover then return self.mover end
  local base = self.TrackerBaseFrame.baseFrame
  if not base then return end
  local m = S.Mover(base, "Questie tracker", function() end)
  m:SetFrameLevel(200) -- over the tracker's own lines and buttons
  m:SetScript("OnDragStart", function() Guard("tracker", Q.StartDrag, Q) end)
  m:SetScript("OnDragStop", function() Guard("tracker", Q.StopDrag, Q) end)
  m:SetScript("OnHide", function() Guard("tracker", Q.StopDrag, Q) end) -- combat closed the edit mode mid-drag
  self.mover = m
  return m
end

function Q:SetUnlocked(on)
  if not self.ready then return end
  local m = self:Mover()
  if m then m:SetShown(on) end
end

------------------------------------------------------------------------
-- Shared pieces for the windows
------------------------------------------------------------------------

-- The game's UIPanelButtonTemplate. Its fonts stay: the button sets them again on every
-- change of state.
local function FlatPanelButton(b)
  if type(b) ~= "table" then return end
  S.Fade(b.Left, b.Middle, b.Right)
  S.FlatHighlight(b)
  S.Panel(b, 0.5)
end

------------------------------------------------------------------------
-- Settings window
------------------------------------------------------------------------

local function SkinSideTab(tab)
  tab:SetSize(38, 38)
  local function fill(t, r, g, b, a)
    t:ClearAllPoints()
    t:SetAllPoints(tab)
    t:SetColorTexture(r, g, b, a)
    t:SetTexCoord(0, 1, 0, 1)
  end
  fill(tab.Background, S.BG[1], S.BG[2], S.BG[3], 0.92)
  fill(tab.Selected, S.ACCENT[1], S.ACCENT[2], S.ACCENT[3], 0.25)
  tab.Selected:SetBlendMode("BLEND")
  fill(tab.Highlight, 1, 1, 1, 0.12)
  tab.Highlight:SetBlendMode("BLEND")
  S.ColorEdges(S.Edges(tab, "BORDER", 1), S.EDGE[1], S.EDGE[2], S.EDGE[3], 1)
  -- Square icons in place of the game's rounded tab.
  if tab.Mask then tab.Icon:RemoveMaskTexture(tab.Mask) end
  tab.Icon:SetSize(26, 26)
  tab.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  tab.button:ClearAllPoints()
  tab.button:SetAllPoints(tab)
end

function Q:PaintOptionsWindow()
  local win = self.QuestieOptionsEngine.popup
  if win and win.fuiPanel then S.Panel(win, max(ns.db.alpha, 0.92)) end
end

function Q:SkinOptionsWindow()
  local win = self.QuestieOptionsEngine.popup
  if not win or self.optionsDone then return end
  self.optionsDone = true
  S.Fade(win.NineSlice, win.Bg, win.TopTileStreaks, win.PortraitContainer)
  S.Panel(win, max(ns.db.alpha, 0.92))
  S.Header(win, S.HEADER_H)

  local title = win.TitleContainer
  local text = title and title.TitleText
  if text then
    title:ClearAllPoints()
    title:SetPoint("TOPLEFT", win, "TOPLEFT", 8, -1)
    title:SetPoint("TOPRIGHT", win, "TOPRIGHT", -24, -1)
    title:SetHeight(S.HEADER_H - 2)
    text:ClearAllPoints()
    text:SetPoint("LEFT", title, "LEFT", 0, 0)
    text:SetPoint("RIGHT", title, "RIGHT", 0, 0)
    text:SetJustifyH("LEFT")
    S.FixFont(text, 14)
    text:SetTextColor(S.ACCENT[1], S.ACCENT[2], S.ACCENT[3])
  end

  local close = win.CloseButton
  if type(close) == "table" then
    close:SetSize(20, 20)
    close:ClearAllPoints()
    close:SetPoint("TOPRIGHT", win, "TOPRIGHT", -2, -2)
    S.FlatButton(close, "x")
  end

  for _, child in ipairs({ win:GetChildren() }) do
    if child.Selected and child.Icon and child.button and child.Background then
      SkinSideTab(child)
    end
  end
end

local function Enabled(item)
  local on = item.enabled
  if type(on) == "function" then on = on() end
  return on == nil or (on and true or false)
end

local function Box(t, size, r, g, b, a)
  if not t then return end
  t:ClearAllPoints()
  t:SetPoint("CENTER")
  t:SetSize(size, size)
  t:SetColorTexture(r, g, b, a)
  t:SetTexCoord(0, 1, 0, 1)
end

local function SkinCheck(control)
  local w = control.widget
  local normal = w:GetNormalTexture()
  Box(normal, 16, 1, 1, 1, 0.07)
  Box(w:GetPushedTexture(), 16, 1, 1, 1, 0.12)
  Box(w:GetDisabledTexture(), 16, 1, 1, 1, 0.03)
  Box(w:GetCheckedTexture(), 10, S.ACCENT[1], S.ACCENT[2], S.ACCENT[3], 1)
  Box(w:GetDisabledCheckedTexture(), 10, 0.5, 0.5, 0.5, 1)
  if type(w.HoverTex) == "table" then -- radio buttons have none
    w.HoverTex:SetBlendMode("BLEND")
    Box(w.HoverTex, 16, 1, 1, 1, 0.12)
    w.HoverTex:SetAlpha(1)
  end
  if normal then
    S.ColorEdges(S.Edges(w, "ARTWORK", 2, normal), S.EDGE[1], S.EDGE[2], S.EDGE[3], 0.9)
  end
end

local function SkinSlider(control)
  local w = control.widget
  S.Fade(w.TrackLeft, w.TrackRight)
  local track = w.TrackMiddle
  if type(track) == "table" then
    track:SetColorTexture(1, 1, 1, 0.15)
    track:SetTexCoord(0, 1, 0, 1)
    track:SetHeight(2)
  end
  if control.thumb then
    control.thumb:SetColorTexture(S.ACCENT[1], S.ACCENT[2], S.ACCENT[3], 1)
    control.thumb:SetSize(8, 14)
  end
  KeepSize(w.Text, 12)
  KeepSize(w.Low, 10)
  KeepSize(w.High, 10)
  KeepSize(control.valueDisplay, 12)
end

-- The game keeps changing this art on hover and press, so it's only ever faded.
local function SkinDropdown(control)
  local w = control.widget
  S.Fade(w.Background)
  S.Panel(w, 0.35)
  KeepSize(w.Text, 12)
end

local function SkinDivider(control)
  if control.itemData.title == "" then return end
  for _, child in ipairs({ control:GetChildren() }) do
    for _, r in ipairs({ child:GetRegions() }) do
      if IsTexture(r) then
        r:SetColorTexture(S.EDGE[1], S.EDGE[2], S.EDGE[3], 0.5)
        r:SetHeight(1)
      end
    end
  end
end

local function SkinContainer(control)
  local c = control.containerFrame
  if type(c) ~= "table" then return end
  S.FadeTextures(c)
  c:SetAlpha(1)
  S.Panel(c, 0.2)
end

-- Questie's own button: its art, with its label sized to fit, and no state fonts.
local function SkinButton(control)
  local w = control.widget
  S.FadeTextures(w)
  S.FlatHighlight(w)
  S.Panel(w, 0.5)
  KeepSize(w:GetFontString(), 12)
end

local function SkinTextbox(control)
  local w = control.widget
  S.FadeTextures(w)
  S.Panel(w, 0.35)
  FlatPanelButton(control.okBtn)
end

local CONTROL_SKINS = {
  checkbox = SkinCheck,
  radioButton = SkinCheck,
  slider = SkinSlider,
  dropdown = SkinDropdown,
  fontDropdown = SkinDropdown,
  divider = SkinDivider,
  container = SkinContainer,
  button = SkinButton,
  textbox = SkinTextbox,
}

-- Questie's own window only. The same controls also fill its pages in the game's settings.
local inWindow = {}
local function InOptionsWindow(control)
  local known = inWindow[control]
  if known ~= nil then return known end
  local window = _G[OPTIONS_WINDOW]
  local f = control
  local found = false
  for _ = 1, 40 do
    f = f:GetParent()
    if not f then break end
    if f == window then
      found = true
      break
    end
  end
  inWindow[control] = found
  return found
end

-- The page's own heading and rule. They appear while the page builds, so each new control
-- has another look. The portrait they made room for is gone.
local canvasSeen = {}
local function SkinCanvas(control)
  local f = control
  for _ = 1, 40 do
    f = f:GetParent()
    if not f then return end
    if f.tab and f.controls then break end
  end
  for _, r in ipairs({ f:GetRegions() }) do
    if not canvasSeen[r] then
      canvasSeen[r] = true
      if IsFontString(r) then
        KeepSize(r, 13)
        if r:GetText() == "Questie" then
          r:ClearAllPoints()
          r:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -4)
          r:SetTextColor(S.ACCENT[1], S.ACCENT[2], S.ACCENT[3])
        end
      elseif IsTexture(r) then
        r:SetColorTexture(S.EDGE[1], S.EDGE[2], S.EDGE[3], 0.5)
      end
    end
  end
end

-- Runs when each control is made and whenever Questie refreshes it, which also sets its
-- label colours back.
local skinned = {}
function Q:SkinControl(control)
  if not InOptionsWindow(control) then return end
  local item = control.itemData
  if not skinned[control] then
    skinned[control] = true
    SkinCanvas(control)
    KeepSize(control.titleFrame, 12)
    KeepSize(control.descriptionFrame, 11)
    local skin = CONTROL_SKINS[item.type]
    if skin then skin(control) end
  end
  if Enabled(item) then
    local title = control.titleFrame
    if title then
      if item.type == "divider" or item.type == "container" then
        title:SetTextColor(S.ACCENT[1], S.ACCENT[2], S.ACCENT[3])
      else
        title:SetTextColor(0.92, 0.92, 0.92)
      end
    end
    local slider = item.type == "slider" and control.widget
    if slider and type(slider.Text) == "table" then
      slider.Text:SetTextColor(0.92, 0.92, 0.92)
    end
    if control.descriptionFrame then
      control.descriptionFrame:SetTextColor(S.LABEL[1], S.LABEL[2], S.LABEL[3])
    end
  end
end

------------------------------------------------------------------------
-- My Journey
------------------------------------------------------------------------

-- Which of each pooled widget's frames have a backdrop. An inline group doesn't keep its
-- border on the widget, but its content sits inside it.
local PANES = {
  InlineGroup = function(w) return w.content:GetParent() end,
  TreeGroup = function(w) return w.treeframe, w.border end,
  TabGroup = function(w) return w.border end,
}

local tinted = {}

-- The off colours are AceGUI's own for all three.
local function TintPane(widget, on)
  for _, f in ipairs({ PANES[widget.type](widget) }) do
    if on then
      f:SetBackdropColor(S.BG[1], S.BG[2], S.BG[3], 0.35)
      f:SetBackdropBorderColor(S.EDGE[1], S.EDGE[2], S.EDGE[3], 0.7)
    else
      f:SetBackdropColor(0.1, 0.1, 0.1, 0.5)
      f:SetBackdropBorderColor(0.4, 0.4, 0.4)
    end
  end
end

local function WalkPanes(widget, seen)
  if PANES[widget.type] and widget ~= Q.journeyTabs then
    seen[widget] = true
    if not tinted[widget] then
      tinted[widget] = true
      TintPane(widget, true)
    end
  end
  for _, child in ipairs(widget.children or {}) do WalkPanes(child, seen) end
end

-- Widgets come and go as you click around. A widget that's left this window goes back in
-- the shared pool, so it gets its own colours back in case another add-on picks it up.
function Q:UpdatePanes()
  local seen = {}
  WalkPanes(QuestieJourneyFrame, seen)
  for widget in pairs(tinted) do
    if not seen[widget] then
      tinted[widget] = nil
      TintPane(widget, false)
    end
  end
end

local function SkinTab(tab)
  if tab.voltLine then return end
  S.Fade(tab.Left, tab.Middle, tab.Right, tab.LeftDisabled, tab.MiddleDisabled, tab.RightDisabled)
  local hl = tab.HighlightTexture
  if type(hl) == "table" then
    hl:ClearAllPoints()
    hl:SetPoint("TOPLEFT", tab, "TOPLEFT", 2, -2)
    hl:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -2, 0)
    hl:SetColorTexture(1, 1, 1, 0.12)
    hl:SetBlendMode("BLEND")
  end
  local line = S.Tex(tab, "OVERLAY", 2)
  line:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 4, 0)
  line:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -4, 0)
  line:SetHeight(2)
  line:SetColorTexture(S.ACCENT[1], S.ACCENT[2], S.ACCENT[3], 1)
  line:SetShown(tab.selected and true or false)
  tab.voltLine = line
  hooksecurefunc(tab, "SetSelected", function(_, selected) line:SetShown(selected and true or false) end)
end

local function SkinTabs(group)
  for _, tab in pairs(group.tabs or {}) do SkinTab(tab) end
end

-- This window's own frame, tabs and top button are never handed back to the pool, unlike
-- what's inside them, so they can have the full look.
function Q:SkinJourney()
  local w = QuestieJourneyFrame
  if not w or self.journeyDone then return end
  self.journeyDone = true
  local f = w.frame
  local status
  for _, child in ipairs({ f:GetChildren() }) do
    if child.obj == w then
      if type(child.Left) == "table" then
        FlatPanelButton(child)
      -- AceGUI marks its plain content frame with .obj too, and that has no backdrop.
      elseif child ~= w.content and child.SetBackdrop then
        status = child
      end
    end
  end
  f:SetBackdrop(nil)
  S.FadeTextures(f)
  S.Panel(f, max(ns.db.alpha, 0.92))
  S.Header(f, S.HEADER_H + 4)
  if status then
    status:SetBackdrop(nil)
    S.Panel(status, 0.35)
  end
  if w.titletext then
    w.titletext:ClearAllPoints()
    w.titletext:SetPoint("TOP", f, "TOP", 0, -7)
    S.FixFont(w.titletext, 14)
    w.titletext:SetTextColor(S.ACCENT[1], S.ACCENT[2], S.ACCENT[3])
  end
  if w.sizer_se then
    for _, r in ipairs({ w.sizer_se:GetRegions() }) do
      if IsTexture(r) then r:SetVertexColor(S.EDGE[1], S.EDGE[2], S.EDGE[3]) end
    end
  end

  for _, child in ipairs(w.children or {}) do
    if child.type == "Button" then
      FlatPanelButton(child.frame)
    elseif child.type == "TabGroup" and not self.journeyTabs then
      self.journeyTabs = child
      child.border:SetBackdrop(nil)
      S.Panel(child.border, 0.35)
      SkinTabs(child)
      -- Tabs are made as they're first needed.
      After(child, "BuildTabs", "My Journey tabs", SkinTabs)
    end
  end

  -- Only runs while the window's open, because a hidden frame gets no OnUpdate.
  local elapsed = 0
  local watcher = CreateFrame("Frame", nil, f)
  watcher:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    if elapsed < 0.25 then return end
    elapsed = 0
    Guard("My Journey window", Q.UpdatePanes, Q)
  end)
  self:UpdatePanes()
end

function Q:PaintJourney()
  local w = QuestieJourneyFrame
  if self.journeyDone and w then S.Panel(w.frame, max(ns.db.alpha, 0.92)) end
end

------------------------------------------------------------------------
-- Start-up, settings
------------------------------------------------------------------------

function Q:Enable()
  self.enabled = true
  if not (Questie and QuestieLoader and Profile()) then return end
  self.ready = true

  local function Import(name) return QuestieLoader:ImportModule(name) end
  self.TrackerBaseFrame = Import("TrackerBaseFrame")
  self.TrackerHeaderFrame = Import("TrackerHeaderFrame")
  self.QuestieTracker = Import("QuestieTracker")
  self.QuestieOptionsEngine = Import("QuestieOptionsEngine")
  self.QuestieOptionsControls = Import("QuestieOptionsControls")
  self.QuestieJourney = Import("QuestieJourney")

  self:Seed()
  self:ApplyFonts()
  self.lastFont, self.lastAlpha = ns.db.font, ns.db.alpha

  After(self.TrackerBaseFrame, "Initialize", "tracker", function() Q:SkinTracker() end)
  After(self.TrackerHeaderFrame, "Update", "tracker's header", function() Q:SkinHeader() end)
  After(self.QuestieOptionsEngine, "ShowFrame", "settings window", function() Q:SkinOptionsWindow() end)
  After(self.QuestieOptionsControls, "Refresh", "settings window", function(control) Q:SkinControl(control) end)
  After(self.QuestieJourney, "ToggleJourneyWindow", "My Journey window", function() Q:SkinJourney() end)

  if self.TrackerBaseFrame.IsInitialized then Guard("tracker", self.SkinTracker, self) end
end

-- Questie's own font settings do the same: set the setting, then update the tracker.
function Q:Refresh()
  if not self.ready then return end
  local db = ns.db
  self:PaintOptionsWindow()
  self:PaintJourney()
  if db.font == self.lastFont and db.alpha == self.lastAlpha then return end
  self.lastFont, self.lastAlpha = db.font, db.alpha
  self:ApplyFonts()
  -- Only follow the panel opacity while the colour is still VoltUI's, not one you've picked.
  local c = Profile().trackerBackdropColor
  if c and c.r == S.BG[1] and c.g == S.BG[2] and c.b == S.BG[3] then c.a = db.alpha end
  Guard("tracker", self.QuestieTracker.Update, self.QuestieTracker)
end

local function OnOff(v) return v and "|cff7fff7fon|r" or "|cffff7f7foff|r" end

function Q:Slash(arg)
  local db = ns.db
  if arg == "fonts" then
    db.questieFonts = not db.questieFonts
    FUI:Print("VoltUI's font on Questie's tracker: %s", OnOff(db.questieFonts))
    if db.questieFonts and self.ready then
      self:ApplyFonts()
      Guard("tracker", self.QuestieTracker.Update, self.QuestieTracker)
    elseif not db.questieFonts then
      FUI:Print("Questie's tracker keeps its current font until you pick another in Questie's settings.")
    end
    return
  end
  if not self.enabled then
    FUI:Print("The Questie skin is off. /volt questie on, then /reload.")
  elseif not self.ready then
    FUI:Print("Questie isn't installed or isn't running, so there's nothing to style.")
  else
    FUI:Print("Questie skin %s. VoltUI's font on its tracker %s.", OnOff(true), OnOff(db.questieFonts))
    if #self.missing > 0 then
      FUI:Print("This Questie version has changed, so these aren't styled: %s", table.concat(self.missing, ", "))
    end
    for what, err in pairs(self.reported) do FUI:Print("%s: %s", what, err) end
  end
  FUI:Print("/volt questie fonts · on|off")
end

FUI:Register(Q)
