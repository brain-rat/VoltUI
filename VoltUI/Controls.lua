-- VoltUI · Controls
-- The settings controls every VoltUI panel builds from: flat sliders, switches,
-- segmented choices and steppers, grouped into cards. Same dark panels, thin
-- borders and sky-blue accent as the rest of the UI.
--
-- A row is made from a definition and an `io` table:
--   def = { kind = "step" | "cycle" | "toggle" | "color" | "button" | "note" | "link" | "custom", label, key, ... }
--     step:   min, max, step, fmt            a slider (the mouse wheel steps it) and a box to type in
--     cycle:  list = { { key, name } }       segmented buttons
--             stepper = true                 < value > for long lists; list may be a function
--     toggle:                                a switch
--     color:  keys = { { key, name } }       colour swatches (or one, from `key`); a click opens
--                                            the game's colour picker, a right-click puts the
--                                            default back (io.set with nil). Values are { r, g, b }.
--     button: text, fn(row), width           a button at the right of the row
--     note:   text (or a function), lines    grey text across the row, `lines` tall
--     link:   fn(row), note                  the whole row is a button, with a note at the right
--     custom: height, build(row, width),     anything else; refresh(row) runs with every refresh
--             refresh(row)
--     when:   function() -> bool             dims the row when it has no effect
--     tip:    text                           shown when hovering the row's label
--     height:                                rows are 28 tall unless they say (a note fits its text)
--   io = { get(def), set(def, v), changed(def), blocked() }
--   A row also dims while io.blocked() says it can't change (secure frames, in combat).

local _, ns = ...
local S = ns.Style

S.SOFT = { 0.24, 0.28, 0.36 } -- quieter borders inside a panel
-- Spacing, on one scale (since 1.62.2): text and controls sit 12 in from a card's edges, a
-- card's title band is 32 tall, rows 28, and the space above a card's first line of text
-- matches the space under its last. One spacing for everyone: the Comfortable/Compact choice
-- is gone.
local ROW_H, CARD_HEAD = 28, 32
local INSET = 11 -- in from a row's edges; rows sit 1 in from their card's, so 12 from the card's
local CARD_PAD_TOP, CARD_PAD_BOTTOM = 4, 4 -- with a row's own 8 above and below its text: 12
local floor, max, min, ceil = math.floor, math.max, math.min, math.ceil
local A = S.UI.accent

S.ROW_H, S.CARD_HEAD, S.INSET = ROW_H, CARD_HEAD, INSET
function S.RowH() return ROW_H end
function S.CardHead() return CARD_HEAD end

-- How wide a text is, unwrapped and uncut. Falls back to a guess where the client can't say.
function S.TextWidth(fs, fallback)
  local w
  if fs.GetUnboundedStringWidth then w = fs:GetUnboundedStringWidth() end
  if (type(w) ~= "number" or w <= 0) and fs.GetStringWidth then w = fs:GetStringWidth() end
  if type(w) ~= "number" or w <= 0 then return fallback or 0 end
  return w
end

local function List(def)
  return type(def.list) == "function" and def.list() or def.list
end

local function NameOf(def, v)
  for _, it in ipairs(List(def)) do
    if it.key == v then return it.name end
  end
  return tostring(v)
end

local function Text(def)
  if type(def.text) == "function" then return def.text() end
  return def.text or ""
end

-- Kinds that hold no value of their own.
local PLAIN = { button = true, note = true, link = true, custom = true }
S.PLAIN_ROWS = PLAIN

------------------------------------------------------------------------
-- Hover text for a row
------------------------------------------------------------------------

-- Why a row is dimmed, if it is: what it's waiting for (def.whyOff, where the page says), or
-- the fight to end.
local function WhyOff(r)
  if not r then return nil end
  local def, io = r.def, r.io
  if def.when and not def.when() then return def.whyOff or "This has no effect right now." end
  if io and io.blocked and io.blocked(def) then return "Waits until you're out of combat." end
  return nil
end
S.WhyOff = WhyOff

-- The row's help, and under it why it's dimmed. A row with neither shows nothing.
local function Tip(owner, def, r)
  owner:HookScript("OnEnter", function(self)
    local why = WhyOff(r)
    if not def.tip and not why then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(def.label or "", 1, 1, 1)
    if def.tip then GameTooltip:AddLine(def.tip, 0.75, 0.77, 0.8, true) end
    if why then GameTooltip:AddLine(why, 1, 0.82, 0.3, true) end
    GameTooltip:Show()
  end)
  owner:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

------------------------------------------------------------------------
-- Painting each kind
------------------------------------------------------------------------

local function RefreshSlider(r, v)
  r.slider:SetValue(v)
  if not r.typing then -- never over what you're typing
    r.value:SetText(r.def.fmt and r.def.fmt:format(v) or tostring(v))
  end
end

local function RefreshSwitch(r, v)
  local sw = r.switch
  -- Obsidian's switch (since 1.66.0): a violet pill when on, a grey one when off, and a light
  -- round knob that sits at the side it's switched to.
  local T = S.UI
  if v then
    S.Paint(sw.track, A[1], A[2], A[3], 1)
  else
    S.Paint(sw.track, T.control[1], T.control[2], T.control[3], 1)
  end
  local k = v and T.knob or T.knobOff -- (1.81.0) a square knob, white when on and grey when off
  S.Paint(sw.knob, k[1], k[2], k[3], 1)
  sw.knob:ClearAllPoints()
  sw.knob:SetPoint(v and "RIGHT" or "LEFT", sw.track, v and "RIGHT" or "LEFT", v and -2 or 2, 0)
  r.current = v
end

local function RefreshSegments(r, v)
  for _, b in ipairs(r.segments) do
    local on = b.choice == v
    -- the chosen one a raised grey pill in the well, the rest plain text (Obsidian)
    if on then
      S.Paint(b.bg, S.UI.control[1], S.UI.control[2], S.UI.control[3], 1)
      b.text:SetTextColor(S.UI.text[1], S.UI.text[2], S.UI.text[3])
    else
      S.Paint(b.bg, 1, 1, 1, 0)
      b.text:SetTextColor(S.UI.sub[1], S.UI.sub[2], S.UI.sub[3])
    end
  end
  r.current = NameOf(r.def, v)
end

-- A stepper with fontFace(v) shows each choice's name in that font (the Fonts page). A font the
-- game hasn't drawn yet can come out blank the first time, so its text is set again a moment later.
local function RefreshStepper(r, v)
  r.current = NameOf(r.def, v)
  local path = r.def.fontFace and r.def.fontFace(v)
  if type(path) == "string" and pcall(r.value.SetFont, r.value, path, S.UISize(13), "") and r.value:GetFont() then
    r.faced = path
    r.value.fontPreview = true -- shown in its own font on purpose
    local text = r.current
    if C_Timer and C_Timer.After then
      C_Timer.After(0, function()
        if r.faced == path and r.current == text then
          r.value:SetText(" ")
          r.value:SetText(text)
        end
      end)
    end
  elseif r.faced then
    r.faced = nil
    r.value.fontPreview = nil
    S.Mono(r.value, 11)
  end
  r.value:SetText(r.current)
end

local function RefreshSwatches(r)
  for _, sw in ipairs(r.swatches) do
    local c = r.io.get(sw.sub)
    if type(c) == "table" then sw.fill:SetColorTexture(c[1] or 1, c[2] or 1, c[3] or 1, 1) end
  end
end

------------------------------------------------------------------------
-- Building each kind
------------------------------------------------------------------------

-- A typed value goes in as written, between the row's limits, rather than snapping to
-- the slider's steps: whole numbers stay whole, decimals keep what the row can show.
local function Typed(r, box)
  local def = r.def
  local v = tonumber((box:GetText():gsub(",", ".")))
  if not v then return r:Refresh() end
  v = max(def.min, min(def.max, v))
  if def.fmt then
    v = tonumber(def.fmt:format(v)) or v
  elseif def.step == floor(def.step) then
    v = floor(v + 0.5)
  end
  r:Set(v)
end

local function BuildValueBox(r)
  local box = CreateFrame("EditBox", nil, r)
  box:SetSize(46, 20)
  box:SetPoint("RIGHT", -INSET, 0)
  box:SetAutoFocus(false)
  box:SetMaxLetters(8)
  box:SetTextInsets(4, 6, 0, 0)
  box:SetJustifyH("RIGHT")
  S.Mono(box, 11)
  local bg, edges = S.RoundBox(box, S.UI.r.field, "BACKGROUND", -8, -7)
  S.Paint(bg, S.UI.field[1], S.UI.field[2], S.UI.field[3], 1)
  S.ColorEdges(edges, S.UI.soft[1], S.UI.soft[2], S.UI.soft[3], 1)
  box:SetScript("OnEditFocusGained", function(self)
    r.typing = true
    S.ColorEdges(edges, A[1], A[2], A[3], 1)
    self:HighlightText()
  end)
  box:SetScript("OnEditFocusLost", function(self)
    S.ColorEdges(edges, S.UI.soft[1], S.UI.soft[2], S.UI.soft[3], 1)
    self:HighlightText(0, 0)
    if r.typing then -- clicked away: keep it
      r.typing = false
      Typed(r, self)
    end
  end)
  local function commit(self)
    r.typing = false
    Typed(r, self)
    self:ClearFocus()
  end
  box:SetScript("OnEnterPressed", commit)
  box:SetScript("OnTabPressed", commit)
  box:SetScript("OnEscapePressed", function(self)
    r.typing = false
    r:Refresh()
    self:ClearFocus()
  end)
  box:SetScript("OnHide", function(self) self:ClearFocus() end)
  r.value = box
end

local function BuildSlider(r, def, width)
  BuildValueBox(r)
  local sl = CreateFrame("Slider", nil, r)
  sl:SetOrientation("HORIZONTAL")
  r.sliderW = max(92, width - 262) -- what a wider panel gives goes to the slider; the label keeps 190 or so
  sl:SetSize(r.sliderW, 16)
  sl:SetPoint("RIGHT", r.value, "LEFT", -10, 0)
  sl:SetMinMaxValues(def.min, def.max)
  sl:SetValueStep(def.step)
  if sl.SetObeyStepOnDrag then sl:SetObeyStepOnDrag(true) end
  sl:EnableMouseWheel(true)
  -- Obsidian's slider (since 1.66.0): a thin rounded grey track, violet up to a light round thumb
  local track = S.Tex(sl, "BACKGROUND")
  track:SetPoint("LEFT")
  track:SetPoint("RIGHT")
  track:SetHeight(4)
  S.Round(track, S.UI.r.track)
  S.Paint(track, S.UI.control[1], S.UI.control[2], S.UI.control[3], 1)
  -- (1.81.0) hard-edged: the thumb is an upright white bar, 6 by 12
  sl:SetThumbTexture(S.UI.round and (S.MEDIA .. "Disc12") or S.WHITE)
  local thumb = sl:GetThumbTexture()
  if S.UI.round then thumb:SetSize(12, 12) else thumb:SetSize(6, 12) end
  thumb:SetVertexColor(S.UI.knob[1], S.UI.knob[2], S.UI.knob[3], 1)
  local fill = S.Tex(sl, "ARTWORK")
  fill:SetPoint("LEFT", track, "LEFT")
  fill:SetPoint("RIGHT", thumb, "CENTER")
  fill:SetHeight(4)
  S.Round(fill, S.UI.r.track)
  S.Paint(fill, A[1], A[2], A[3], 1)
  sl:SetScript("OnValueChanged", function(_, v)
    if r.filling then return end
    r:Set(r:Snap(v))
  end)
  sl:SetScript("OnMouseWheel", function(_, delta)
    -- On a page that scrolls, the wheel scrolls the page: a slider under the mouse would
    -- otherwise change, and save, as you scrolled past it. Hold Shift or Ctrl to step it.
    if S.PageWheel and S.PageWheel(delta) then return end
    r:Step(delta > 0 and 1 or -1)
  end)
  r.slider = sl
end

local function BuildSwitch(r)
  local sw = CreateFrame("Button", nil, r)
  sw:SetAllPoints(r)
  S.Hover(sw) -- the switch is the whole row, so the row's hover is drawn on it
  sw.track = S.Tex(sw, "ARTWORK")
  sw.track:SetSize(26, 14)
  sw.track:SetPoint("RIGHT", -INSET, 0)
  S.Round(sw.track, S.UI.r.switch)
  sw.knob = S.Disc(S.Tex(sw, "OVERLAY"), 10)
  sw.knob:SetSize(10, 10)
  -- The switch covers its whole row, so the row never sees a click: right-click to put the
  -- setting back to its default is handled here, as the row does for the other kinds.
  sw:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  sw:SetScript("OnClick", function(_, button)
    if button == "RightButton" then
      if r:ResetOne() and S.OnRowReset then S.OnRowReset(r) end
    else
      r:Step(1)
    end
  end)
  r.switch = sw
end

-- Segmented choices (since 1.62.2): each as wide as its name plus 10 a side, so no name runs
-- into its edges. A page's segWidth is the least the set takes (the extra is shared out evenly,
-- so sets line up down a card); a set too wide for its row shrinks to leave the label room.
local SEG_H, SEG_PAD, SEG_MIN = 20, 10, 44
S.SEG_PAD = SEG_PAD
local function BuildSegments(r, def, width)
  local list = List(def)
  r.segments = {}
  local widths, total = {}, 0
  for i, it in ipairs(list) do
    local b = S.UIButton(r, it.name, 300, function() r:Set(it.key) end, nil, true) -- wide while it's measured
    b:SetHeight(SEG_H)
    S.SetFont(b.text, 11)
    widths[i] = max(SEG_MIN, ceil(S.TextWidth(b.text, #(it.name or "") * 6)) + 2 * SEG_PAD)
    total = total + widths[i]
    b.choice = it.key
    -- the chosen segment's pill and the hover, rounded and 2 in from the well's edge
    b.bg = S.Tex(b, "BACKGROUND")
    b.bg:SetPoint("TOPLEFT", 2, -2)
    b.bg:SetPoint("BOTTOMRIGHT", -2, 2)
    S.Round(b.bg, S.UI.r.seg)
    if b.hl then
      b.hl:ClearAllPoints()
      b.hl:SetPoint("TOPLEFT", 2, -2)
      b.hl:SetPoint("BOTTOMRIGHT", -2, 2)
    end
    r.segments[i] = b
  end
  local label = (def.label or "") ~= "" and S.TextWidth(r.label, #def.label * 6) + 22 or 0 -- its "?" too
  local room = width - 2 * INSET - label
  local want = max(total, def.segWidth or 0)
  if want > room then want = max(room, #list * SEG_MIN) end
  -- from the right: each segment's right edge, rounded so neighbours meet without a gap
  local extra = want - total
  local x = 0
  for i = #list, 1, -1 do
    local w = extra >= 0 and widths[i] + extra / #list or widths[i] * want / total
    local right, left = floor(x + 0.5), floor(x + w + 0.5)
    local b = r.segments[i]
    b:SetWidth(left - right)
    b:SetPoint("RIGHT", r, "RIGHT", -INSET - right, 0)
    x = x + w
  end
  r.segTotal = floor(x + 0.5)
  -- the well behind them: drawn on the row, so it sits under the segments' own pills
  local box = CreateFrame("Frame", nil, r)
  box:SetPoint("RIGHT", r, "RIGHT", -INSET, 0)
  box:SetSize(r.segTotal, SEG_H)
  local well = S.Tex(r, "BACKGROUND", -6)
  well:SetAllPoints(box)
  S.Round(well, S.UI.r.field)
  S.Paint(well, S.UI.field[1], S.UI.field[2], S.UI.field[3], 1)
  S.ColorEdges(S.RoundEdges(r, "BACKGROUND", -5, box, S.UI.r.field), S.UI.soft[1], S.UI.soft[2], S.UI.soft[3], 1)
  r.segWell = well
end

local function BuildStepper(r)
  r.plus = S.UIButton(r, ">", 20, function() r:Step(1) end)
  r.plus:SetPoint("RIGHT", -(INSET - 4), 0) -- the ">" sits mid-button: its glyph lines up with the rest
  r.value = S.UIText(r, nil, "CENTER", nil, 11, nil, "mono") -- a value: JetBrains Mono
  r.value:SetPoint("RIGHT", r.plus, "LEFT", 0, 0)
  r.value:SetWidth(112)
  r.minus = S.UIButton(r, "<", 20, function() r:Step(-1) end)
  r.minus:SetPoint("RIGHT", r.value, "LEFT", 0, 0)
  -- (1.95.0) menu = true: a click on the value drops the whole list down, for long ones.
  if r.def.menu then
    r.value:SetWidth(150)
    r.pick = CreateFrame("Button", nil, r)
    r.pick:SetAllPoints(r.value)
    r.pick:SetScript("OnClick", function() S.StepperMenu(r) end)
  end
end

-- A stepper's choices as the game's drop-down menu, the one in use marked. Without the
-- game's menu (or while the row is dimmed) the click does nothing: < and > still work.
function S.StepperMenu(r)
  if not (MenuUtil and MenuUtil.CreateContextMenu) or r:Off() then return end
  local now = r.io.get(r.def)
  MenuUtil.CreateContextMenu(r.pick, function(_, root)
    for _, it in ipairs(List(r.def)) do
      root:CreateButton(it.key == now and (it.name .. "  (now)") or it.name, function() r:Set(it.key) end)
    end
  end)
end

-- The game's colour picker, on one swatch. Every change shows straight away; Cancel (or a
-- click outside it) puts the colour it had back.
local function PickColor(r, sub)
  local cp = _G.ColorPickerFrame
  if not cp and C_AddOns and C_AddOns.LoadAddOn then
    pcall(C_AddOns.LoadAddOn, "Blizzard_ColorPickerFrame")
    cp = _G.ColorPickerFrame
  end
  if not cp then return end
  local io = r.io
  local cur = io.get(sub)
  if type(cur) ~= "table" then cur = { 1, 1, 1 } end
  local function apply(rr, gg, bb)
    if type(rr) ~= "number" or (io.blocked and io.blocked(sub)) then return end
    io.set(sub, { rr, gg, bb })
    if io.changed then io.changed(sub) end
    r:Refresh()
  end
  local info = {
    r = cur[1], g = cur[2], b = cur[3], hasOpacity = false,
    swatchFunc = function() apply(cp:GetColorRGB()) end,
    cancelFunc = function(prev) if type(prev) == "table" then apply(prev.r, prev.g, prev.b) end end,
  }
  if cp.SetupColorPickerAndShow then
    cp:SetupColorPickerAndShow(info)
  else -- an older picker, set up by its fields
    cp.func, cp.swatchFunc, cp.cancelFunc, cp.hasOpacity = info.swatchFunc, info.swatchFunc, info.cancelFunc, false
    cp.previousValues = { r = cur[1], g = cur[2], b = cur[3] }
    if cp.SetColorRGB then cp:SetColorRGB(cur[1], cur[2], cur[3]) end
    cp:Show()
  end
  if cp.Raise then cp:Raise() end -- over the settings window, which is a dialog too
end

local SWATCH_W, SWATCH_GAP = 22, 5

local function BuildSwatches(r, def)
  local keys = def.keys or { { key = def.key, name = def.label } }
  r.swatches = {}
  for i, it in ipairs(keys) do
    local sw = CreateFrame("Button", nil, r)
    sw:SetSize(SWATCH_W, 14)
    sw:SetPoint("RIGHT", r, "RIGHT", -INSET - (#keys - i) * (SWATCH_W + SWATCH_GAP), 0)
    sw.sub = { key = it.key, store = def.store, name = it.name }
    sw.fill = S.Tex(sw, "ARTWORK")
    sw.fill:SetPoint("TOPLEFT", 1, -1)
    sw.fill:SetPoint("BOTTOMRIGHT", -1, 1)
    S.ColorEdges(S.Edges(sw, "OVERLAY"), S.UI.soft[1], S.UI.soft[2], S.UI.soft[3], 1)
    S.Highlight(sw, 0.15)
    sw:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    sw:SetScript("OnClick", function(_, button)
      if button == "RightButton" then
        local io = r.io
        if io.blocked and io.blocked(sw.sub) then return end
        io.set(sw.sub, nil)
        if io.changed then io.changed(sw.sub) end
        r:Refresh()
      else
        PickColor(r, sw.sub)
      end
    end)
    sw:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:SetText(it.name or def.label)
      GameTooltip:AddLine("Click to pick a colour. Right-click for the default.", 0.75, 0.77, 0.8, true)
      GameTooltip:Show()
    end)
    sw:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r.swatches[i] = sw
  end
end

local function BuildButton(r, def)
  r.button = S.PillButton(r, Text(def), def.width or 116, function()
    local io = r.io
    if io and io.blocked and io.blocked(def) then return end
    if def.when and not def.when() then return end
    def.fn(r)
    r:Refresh()
  end, def.primary, def.buttonTip)
  r.button:SetPoint("RIGHT", -INSET, 0)
end

-- A note's row fits its text (since 1.62.2): 6 above it and 6 under, measured once it's set.
-- A note whose text is a function keeps the `lines` it asks for, since its text can grow.
local NOTE_PAD, NOTE_LINE = 6, 14
local function BuildNote(r, def, width)
  r.label:ClearAllPoints()
  r.label:SetPoint("TOPLEFT", INSET, -NOTE_PAD)
  r.label:SetWidth(width - 2 * INSET)
  r.label:SetWordWrap(true)
  if r.label.SetJustifyV then r.label:SetJustifyV("TOP") end
  r.label:SetTextColor(S.UI.hint[1], S.UI.hint[2], S.UI.hint[3])
  r.label:SetText(Text(def))
end

local function BuildLink(r, def)
  local b = CreateFrame("Button", nil, r)
  b:SetAllPoints(r)
  S.Hover(b)
  b:SetScript("OnClick", function() def.fn(r) end)
  r.link = b
  r.note = S.UIText(r, nil, "RIGHT", "OVERLAY", 11)
  r.note:SetPoint("RIGHT", -INSET, 0)
  r.note:SetTextColor(A[1], A[2], A[3])
  r.note:SetText(def.note or "Open")
end

------------------------------------------------------------------------
-- A row
------------------------------------------------------------------------

local Row = {}

function Row:Snap(v)
  local def = self.def
  return max(def.min, min(def.max, floor(v / def.step + 0.5) * def.step))
end

-- Set a value from the controls. Nothing changes while the panel says it's blocked.
function Row:Set(v)
  local io = self.io
  if io.blocked and io.blocked(self.def) then return self:Refresh() end
  if v == io.get(self.def) then return self:Refresh() end
  io.set(self.def, v)
  if io.changed then io.changed(self.def) end
  self:Refresh()
end

-- One notch: up or down a step, next or previous choice, or flip a switch.
function Row:Step(dir)
  local def = self.def
  if def.kind == "color" or PLAIN[def.kind] then return end
  local v = self.io.get(def)
  if def.kind == "step" then
    self:Set(self:Snap(v + dir * def.step))
  elseif def.kind == "toggle" then
    self:Set(not v)
  else
    local list, idx = List(def), 1
    for i, it in ipairs(list) do if it.key == v then idx = i end end
    self:Set(list[(idx - 1 + dir) % #list + 1].key)
  end
end

-- Dimmed: no effect right now, or can't change right now.
function Row:Off()
  local def, io = self.def, self.io
  if def.when and not def.when() then return true end
  if io and io.blocked and io.blocked(def) then return true end
  return false
end

-- Back to its default, if the page knows it (a right-click on the row, since 1.61.0).
function Row:ResetOne()
  local io = self.io
  if not (io and io.default and io.isChanged and io.isChanged(self.def)) then return false end
  if io.blocked and io.blocked(self.def) then return false end
  local v = io.default(self.def)
  if type(v) == "table" then
    local t = {}
    for k, x in pairs(v) do t[k] = x end
    v = t
  end
  io.set(self.def, v)
  if io.changed then io.changed(self.def) end
  self:Refresh()
  return true
end

-- A small square before the label while the value isn't the default.
function Row:PaintChanged()
  local io = self.io
  local on = io and io.isChanged and not PLAIN[self.def.kind] and io.isChanged(self.def) or false
  if on and not self.chg then
    self.chg = S.Disc(S.Tex(self, "OVERLAY"), 5)
    self.chg:SetSize(5, 5)
    self.chg:SetPoint("LEFT", 3, 0)
    S.Paint(self.chg, A[1], A[2], A[3], 1)
  end
  if self.chg then self.chg:SetShown(on and true or false) end
  self.changed = on and true or nil
end

function Row:Refresh()
  local def = self.def
  local kind = def.kind
  if PLAIN[kind] then
    if kind == "button" then self.button.text:SetText(Text(def)) end
    if kind == "note" then self.label:SetText(Text(def)) end
    if kind == "link" and def.noteFn then self.note:SetText(def.noteFn()) end
    if kind == "custom" and def.refresh then def.refresh(self) end
    self:SetAlpha(self:Off() and 0.45 or 1)
    return
  end
  if self.swatches then
    RefreshSwatches(self)
    self:PaintChanged()
    self:SetAlpha(self:Off() and 0.45 or 1)
    return
  end
  local v = self.io.get(def)
  self.filling = true
  if self.slider then
    RefreshSlider(self, v)
  elseif self.switch then
    RefreshSwitch(self, v)
  elseif self.segments then
    RefreshSegments(self, v)
  else
    RefreshStepper(self, v)
  end
  self.filling = false
  self:PaintChanged()
  self:SetAlpha(self:Off() and 0.45 or 1)
end

-- How tall a row is.
function S.RowHeight(def)
  if def.height then return def.height end
  if def.kind == "note" then return (def.lines or 2) * NOTE_LINE + 2 * NOTE_PAD end
  return S.RowH()
end

-- One settings row is lit at a time: the one the mouse is on, for as long as it's anywhere on
-- the row, its label and its controls included (they take the mouse from the row, so the
-- game's own highlight layer would go out over them). A watcher that only runs while a row is
-- lit puts it out when the mouse leaves or the row goes.
local lit
local watch = CreateFrame("Frame")
watch:Hide()
local function Unlight()
  if lit and lit.hl then lit.hl:Hide() end
  lit = nil
  watch:Hide()
end
watch:SetScript("OnUpdate", function()
  if not lit or (lit.IsVisible and not lit:IsVisible()) or not (MouseIsOver and MouseIsOver(lit)) then Unlight() end
end)
local function Light(r)
  if lit == r then return end
  Unlight()
  if r.GetAlpha and (r:GetAlpha() or 1) < 1 then return end -- a dimmed row does nothing: it doesn't light
  lit = r
  r.hl:Show()
  watch:Show()
end
S.LitRow = function() return lit end

-- Lights `r` when the mouse comes onto it or onto anything of its own that takes the mouse.
function S.RowLights(r)
  local function on() Light(r) end
  local function hook(f) if f and f.HookScript then f:HookScript("OnEnter", on) end end
  hook(r)
  hook(r.tipZone)
  hook(r.slider)
  hook(r.value)
  hook(r.plus)
  hook(r.minus)
  for _, b in ipairs(r.segments or {}) do hook(b) end
  for _, b in ipairs(r.swatches or {}) do hook(b) end
end

function S.Row(parent, def, width, io)
  local r = CreateFrame("Frame", nil, parent)
  r.h = def.heightFor and def.heightFor(width) or S.RowHeight(def) -- a custom row can fit its width
  r:SetSize(width, r.h)
  r.def, r.io = def, io
  for k, fn in pairs(Row) do r[k] = fn end
  r.label = S.UIText(r, nil, "LEFT", nil, 12)
  r.label:SetPoint("LEFT", INSET, 0)
  r.label:SetText(def.label)
  r.label:SetTextColor(S.UI.label[1], S.UI.label[2], S.UI.label[3])
  if def.kind == "button" then
    BuildButton(r, def)
  elseif def.kind == "note" then
    BuildNote(r, def, width)
    if not def.height and not def.heightFor and type(def.text) ~= "function" then
      local h = r.label.GetStringHeight and r.label:GetStringHeight()
      if type(h) == "number" and h >= 8 and h <= (def.lines or 2) * NOTE_LINE * 2 then
        r.h = ceil(h) + 2 * NOTE_PAD
        r:SetHeight(r.h)
      end
    end
  elseif def.kind == "link" then
    BuildLink(r, def)
  elseif def.kind == "custom" then
    def.build(r, width)
  elseif def.kind == "step" then
    BuildSlider(r, def, width)
  elseif def.kind == "color" then
    BuildSwatches(r, def)
  elseif def.kind == "toggle" then
    BuildSwitch(r)
  elseif def.stepper then
    BuildStepper(r)
  else
    BuildSegments(r, def, width)
  end
  -- Rows with help say so with a "?" after their name. Rows that can dim get the hover too,
  -- to say why (since 1.38.0).
  if def.tip and not PLAIN[def.kind] and (def.label or "") ~= "" then
    -- (1.87.0) a text of its own, bigger and right after the name (it was part of the label:
    -- the label's size, two spaces off)
    r.help = S.UIText(r, nil, "LEFT", nil, 14, nil, "mono")
    S.FixFont(r.help, 14, nil, "semibold", "mono")
    r.help:SetText("?")
    r.help:SetTextColor(S.UI.info[1], S.UI.info[2], S.UI.info[3])
    r.help:SetPoint("LEFT", r.label, "RIGHT", 3, 0)
    r.hasHelp = true
  end
  -- A slider's label stops short of the slider, cut off rather than drawn over it. With a "?",
  -- it's as wide as its words or its room, so the "?" sits at its end either way.
  if r.slider and r.help then
    local room = width - 2 * INSET - 46 - 10 - (r.sliderW or 92) - 6 - 14
    r.label:SetWidth(max(20, min(ceil(S.TextWidth(r.label, #def.label * 6.6)) + 1, room)))
  elseif r.slider then
    r.label:SetPoint("RIGHT", r.slider, "LEFT", -6, 0)
  end
  if def.tip or (not PLAIN[def.kind] and (def.when or (io and io.blocked))) then
    if r.switch then
      Tip(r.switch, def, r)
    else
      -- The hover covers the label and no more: any wider and it sat over the left end of the
      -- row's slider or first choice, taking their clicks.
      local zone = CreateFrame("Frame", nil, r)
      zone:SetPoint("TOPLEFT")
      zone:SetPoint("BOTTOMLEFT")
      local text = r.label.GetStringWidth and r.label:GetStringWidth() or 0
      if type(text) ~= "number" or text <= 0 then text = 60 end
      zone:SetWidth(min(floor(width * 0.5) - 30, max(40, text + (r.help and 26 or 14))))
      zone:EnableMouse(true)
      Tip(zone, def, r)
      r.tipZone = zone
    end
  end
  -- Right-click a row to put it back to its default. The label's hover zone takes the click
  -- where there is one; the row itself elsewhere.
  if not PLAIN[def.kind] and io and io.default then
    local function click(_, button)
      if button == "RightButton" and r:ResetOne() and S.OnRowReset then S.OnRowReset(r) end
    end
    if r.tipZone then r.tipZone:SetScript("OnMouseUp", click) end
    r:EnableMouse(true)
    r:SetScript("OnMouseUp", click)
  end
  -- (1.81.0) A row with a value is lit while the mouse is anywhere on it (a switch's hover is
  -- drawn on the switch, which covers its row). Set up last, once its label's hover zone and
  -- its controls exist: each of them lights the row too.
  if not PLAIN[def.kind] and not r.switch then
    r:EnableMouse(true)
    S.Hover(r, { layer = "BACKGROUND", sub = 2 })
    S.RowLights(r)
  end
  r:Refresh()
  return r
end

------------------------------------------------------------------------
-- Cards and buttons
------------------------------------------------------------------------

-- A titled group of rows. card:Add(def, io) adds one and grows the card.
function S.Card(parent, title, width)
  local BAND = S.CardHead()
  local CARD_HEAD = BAND + CARD_PAD_TOP -- where the rows start
  local c = CreateFrame("Frame", nil, parent)
  c:SetWidth(width)
  c:SetHeight(CARD_HEAD + CARD_PAD_BOTTOM)
  c.head, c.padBottom = CARD_HEAD, CARD_PAD_BOTTOM
  local T = S.UI
  -- (1.81.0) A square #1E1E1E panel with a #404040 border. Its heading is a raised band: a
  -- gold square marker, the card's number on its page, the title in Space Mono, a hatched
  -- strip running to a gold end block, and a line under it all.
  local fill = S.Tex(c, "BACKGROUND", -6)
  fill:SetAllPoints()
  S.Round(fill, T.r.card)
  S.Paint(fill, T.card[1], T.card[2], T.card[3], 1)
  c.fill = fill
  c.headFill = S.Tex(c, "BACKGROUND", -5)
  c.headFill:SetPoint("TOPLEFT", 1, -1)
  c.headFill:SetPoint("TOPRIGHT", -1, -1)
  c.headFill:SetHeight(BAND - 2)
  c.headFill:SetColorTexture(T.raised[1], T.raised[2], T.raised[3], 1)
  c.band = S.Tex(c, "BACKGROUND", -4)
  c.band:SetPoint("TOPLEFT", 1, -(BAND - 1))
  c.band:SetPoint("TOPRIGHT", -1, -(BAND - 1))
  c.band:SetHeight(1)
  c.band:SetColorTexture(T.line[1], T.line[2], T.line[3], 1)
  c.edges = S.RoundEdges(c, "BACKGROUND", -3, c, T.r.card)
  S.ColorEdges(c.edges, T.line[1], T.line[2], T.line[3], 1)
  c.mark = S.Tex(c, "ARTWORK")
  c.mark:SetSize(8, 8)
  c.mark:SetPoint("LEFT", c, "TOPLEFT", INSET, -floor(BAND / 2))
  c.mark:SetColorTexture(A[1], A[2], A[3], 1)
  c.no = S.UIText(c, nil, "LEFT", nil, 10, nil, "mono")
  c.no:SetPoint("LEFT", c.mark, "RIGHT", 7, 0)
  c.no:SetTextColor(T.hint[1], T.hint[2], T.hint[3])
  c.no:SetText("")
  c.title = S.UIText(c, nil, "LEFT", nil, 13)
  S.FixFont(c.title, 13, nil, "semibold")
  c.title:SetPoint("LEFT", c.mark, "RIGHT", 8, 0)
  c.title:SetText(title)
  c.title:SetTextColor(T.text[1], T.text[2], T.text[3])
  c.cap = S.Tex(c, "ARTWORK")
  c.cap:SetPoint("TOPRIGHT", -1, -1)
  c.cap:SetSize(10, BAND - 2)
  c.cap:SetColorTexture(A[1], A[2], A[3], 1)
  c.hatch = S.Hatch(S.Tex(c, "ARTWORK"))
  c.hatch:SetHeight(BAND - 20)
  c.hatch:SetPoint("LEFT", c.title, "RIGHT", 10, 0)
  c.hatch:SetPoint("RIGHT", c.cap, "LEFT", 0, 0)
  S.Paint(c.hatch, T.hatch[1], T.hatch[2], T.hatch[3], 1)
  -- The card's place on its page ("01"), between the marker and the title.
  function c:SetNo(n)
    n = tonumber(n)
    self.no:SetText(n and ("%02d"):format(n) or "")
    self.title:ClearAllPoints()
    if n then
      self.title:SetPoint("LEFT", self.no, "RIGHT", 7, 0)
    else
      self.title:SetPoint("LEFT", self.mark, "RIGHT", 8, 0)
    end
  end
  c.rows, c.used = {}, 0
  function c:Add(def, io)
    local r = S.Row(self, def, width - 2, io)
    r:SetPoint("TOPLEFT", self, "TOPLEFT", 1, -(CARD_HEAD + self.used))
    self.rows[#self.rows + 1] = r
    self.used = self.used + r.h
    self:SetHeight(CARD_HEAD + self.used + CARD_PAD_BOTTOM)
    return r
  end
  -- Shows only `rows` (some of this card's, in this order), one under another.
  function c:Arrange(rows)
    for _, r in ipairs(self.rows) do r:Hide() end
    local y = 0
    for _, r in ipairs(rows) do
      r:ClearAllPoints()
      r:SetPoint("TOPLEFT", self, "TOPLEFT", 1, -(CARD_HEAD + y))
      r:Show()
      y = y + r.h
    end
    self.used = y
    self:SetHeight(CARD_HEAD + y + CARD_PAD_BOTTOM)
  end
  -- A small text button at the right of the title.
  function c:Action(text, fn, tip)
    local b = S.UIButton(self, text, 110, fn, tip)
    b:SetHeight(BAND - 10)
    b:SetPoint("RIGHT", self, "TOPRIGHT", -(INSET + 1), -floor(BAND / 2))
    b.text:SetJustifyH("RIGHT")
    S.FixFont(b.text, 11)
    b.text:SetTextColor(A[1], A[2], A[3])
    -- on the heading's band, left of its end block: the hatching stops short of it
    b:ClearAllPoints()
    b:SetPoint("RIGHT", self.cap, "LEFT", -6, 0)
    self.hatch:ClearAllPoints()
    self.hatch:SetPoint("LEFT", self.title, "RIGHT", 10, 0)
    self.hatch:SetPoint("RIGHT", b, "LEFT", -6, 0)
    self.action = b
    return b
  end
  return c
end

-- A bordered button. primary: the window's main button (S.PrimaryLook).
function S.PillButton(parent, label, width, onClick, primary, tip)
  local b = S.UIButton(parent, label, width, onClick, tip)
  b:SetHeight(22)
  -- (1.81.0) square: a raised grey fill and border, and the settings' hover (S.UIButton's)
  local rad = S.UI.r.button
  b.bg = S.Tex(b, "BACKGROUND")
  b.bg:SetAllPoints()
  S.Round(b.bg, rad)
  if primary then
    S.FixFont(b.text, S.PRIMARY_TEXT, nil, "semibold") -- Space Mono, like every title
    if b.hl then b.hl:Hide() end -- solid gold already: its border lightens under the mouse instead
    S.PrimaryLook(b, b.bg)
  else
    S.Paint(b.bg, S.UI.raised[1], S.UI.raised[2], S.UI.raised[3], 1)
    b.edges = S.RoundEdges(b, "BORDER", nil, b, rad)
    S.ColorEdges(b.edges, S.UI.soft[1], S.UI.soft[2], S.UI.soft[3], 1)
  end
  S.FitPill(b, width) -- Inter runs wider than Barlow: never let a label touch its edges
  return b
end

-- (1.85.0) A small window's title in dark Space Mono on a solid gold block at its top-left
-- (f.block, f.word), and the line under its title bar (f.headLine). S.BlockWord changes the
-- word later and fits the block to it.
function S.BlockWord(f, word)
  f.word:SetText(word)
  f.block:SetWidth(math.ceil(S.TextWidth(f.word, #word * 8)) + 20)
end
function S.BlockHead(f, word, size)
  local T, H = S.UI, S.HEADER_H
  f.block = S.Tex(f, "ARTWORK")
  f.block:SetPoint("TOPLEFT", 1, -1)
  f.block:SetHeight(H - 1)
  S.BlockLook(f, f.block)
  f.word = S.UIText(f, nil, "CENTER", "OVERLAY", size or 13)
  S.FixFont(f.word, size or 13, nil, "semibold")
  f.word:SetTextColor(T.primaryText[1], T.primaryText[2], T.primaryText[3])
  f.word:SetPoint("CENTER", f.block, "CENTER", 0, 0)
  S.BlockWord(f, word)
  f.headLine = S.Tex(f, "BORDER")
  f.headLine:SetPoint("TOPLEFT", 1, -H)
  f.headLine:SetPoint("TOPRIGHT", -1, -H)
  f.headLine:SetHeight(1)
  f.headLine:SetColorTexture(T.line[1], T.line[2], T.line[3], 1)
  return f.block
end
-- The hatched strip of a title bar, from `left` to `right` (regions).
function S.HeadHatch(f, left, right)
  local h = S.Hatch(S.Tex(f, "ARTWORK"))
  h:SetHeight(math.max(4, S.HEADER_H - 16))
  h:SetPoint("LEFT", left, "RIGHT", 8, 0)
  h:SetPoint("RIGHT", right, "LEFT", -8, 0)
  S.Paint(h, 0.23, 0.23, 0.23, 1)
  return h
end

-- Lights a plain pill button up as "on" (the accent), or back to plain.
function S.PillOn(b, on)
  local T = S.UI
  if on then
    S.Paint(b.bg, A[1], A[2], A[3], 0.2)
    b.text:SetTextColor(T.accentText[1], T.accentText[2], T.accentText[3])
    if b.edges then S.ColorEdges(b.edges, A[1], A[2], A[3], 0.9) end
  else
    S.Paint(b.bg, T.raised[1], T.raised[2], T.raised[3], 1)
    b.text:SetTextColor(T.text[1], T.text[2], T.text[3])
    if b.edges then S.ColorEdges(b.edges, T.soft[1], T.soft[2], T.soft[3], 1) end
  end
end

-- Window title strip: the accent "VoltUI", then what this window is.
-- (1.66.0) The strip is the window's own grey, so the rounded window's top corners show; a
-- quiet line under it, and "VoltUI" in plain bright text: violet is kept for what you pick.
function S.TitleBar(parent, subtitle, height)
  local bar = S.Header(parent, height)
  bar:SetColorTexture(S.UI.head[1], S.UI.head[2], S.UI.head[3], 0)
  local line = S.Tex(parent, "BORDER")
  line:SetPoint("TOPLEFT", parent, "TOPLEFT", 1, -height)
  line:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -1, -height)
  line:SetHeight(1)
  line:SetColorTexture(S.UI.line[1], S.UI.line[2], S.UI.line[3], 1)
  -- (1.81.0) VoltUI's name on a block the height of the strip, then what the window is, in
  -- white. (1.105.0) The bolt mark, then "VoltUI", on a block as wide as both need. The word is
  -- measured as drawn; if the game can't say, 54 (its width in Space Mono Bold 14, the widest
  -- bundled font for it; Inter SemiBold is 42, JetBrains Mono 48, measured from the font files).
  local T = S.UI.primaryText
  local block = S.Tex(parent, "ARTWORK")
  block:SetPoint("TOPLEFT", parent, "TOPLEFT", 1, -1)
  block:SetSize(88, height - 1) -- the width is fitted to the word below
  S.BlockLook(parent, block)
  parent.brandBlock = block
  local mark = S.Tex(parent, "OVERLAY")
  mark:SetTexture(S.MEDIA .. "Bolt")
  mark:SetSize(14, 14)
  mark:SetPoint("LEFT", block, "LEFT", 7, 0)
  mark:SetVertexColor(T[1], T[2], T[3], 1)
  parent.brandMark = mark
  local brand = S.UIText(parent, nil, "LEFT", "OVERLAY", 14)
  S.FixFont(brand, 14, nil, "semibold", "inter")
  brand:SetPoint("LEFT", mark, "RIGHT", 3, 0)
  brand:SetText("VoltUI")
  brand:SetTextColor(T[1], T[2], T[3])
  block:SetWidth(7 + 14 + 3 + math.ceil(S.TextWidth(brand, 54)) + 10)
  parent.brandText = brand
  local sub = S.UIText(parent, nil, "LEFT", "OVERLAY", 13)
  S.FixFont(sub, 13, nil, "semibold")
  sub:SetPoint("LEFT", block, "RIGHT", 10, 0)
  sub:SetText(subtitle)
  sub:SetTextColor(S.UI.text[1], S.UI.text[2], S.UI.text[3])
  return bar, brand, sub
end

------------------------------------------------------------------------
-- A scrolling area, and a box of text to copy from or paste into
------------------------------------------------------------------------

-- A scroll frame with a thin bar. scroll.child holds what scrolls. The owner says how tall the
-- view is (scroll.viewH) and how tall its content is (SetContentHeight), since sizes read back
-- from the game can lag behind.
function S.Scroll(parent)
  local sf = CreateFrame("ScrollFrame", nil, parent)
  local child = CreateFrame("Frame", nil, sf)
  child:SetSize(1, 1)
  sf:SetScrollChild(child)
  sf:EnableMouseWheel(true)
  sf.child, sf.offset, sf.contentH, sf.viewH = child, 0, 0, 0
  local bar = CreateFrame("Frame", nil, sf)
  bar:SetPoint("TOPRIGHT", sf, "TOPRIGHT", -3, -2)
  bar:SetPoint("BOTTOMRIGHT", sf, "BOTTOMRIGHT", -3, 2)
  bar:SetWidth(4)
  local track = S.Tex(bar, "BACKGROUND")
  track:SetAllPoints()
  track:SetColorTexture(1, 1, 1, 0)
  local thumb = S.Tex(bar, "ARTWORK")
  thumb:SetWidth(4)
  S.Round(thumb, S.UI.r.track)
  S.Paint(thumb, S.UI.control[1], S.UI.control[2], S.UI.control[3], 1)
  sf.bar, sf.thumb = bar, thumb
  function sf:MaxScroll() return max(0, (self.contentH or 0) - (self.viewH or 0)) end
  function sf:Paint()
    local most = self:MaxScroll()
    self.bar:SetShown(most > 0)
    if most <= 0 then return end
    local view = max(1, self.viewH or 1)
    local h = max(16, view * view / max(view, self.contentH))
    self.thumb:SetHeight(h)
    self.thumb:ClearAllPoints()
    self.thumb:SetPoint("TOP", self.bar, "TOP", 0, -((view - 4 - h) * self.offset / most))
  end
  function sf:ScrollTo(y)
    y = max(0, min(self:MaxScroll(), y or 0))
    self.offset = y
    self:SetVerticalScroll(y)
    self:Paint()
  end
  function sf:ScrollBy(delta) self:ScrollTo(self.offset - delta * 44) end
  function sf:SetContentHeight(h)
    self.contentH = h
    self.child:SetHeight(max(1, h))
    self:ScrollTo(self.offset)
  end
  -- Brings a band of the content into view (a row after a jump, say).
  function sf:Reveal(top, height)
    if top < self.offset then
      self:ScrollTo(top)
    elseif top + height > self.offset + self.viewH then
      self:ScrollTo(top + height - self.viewH)
    end
  end
  sf:SetScript("OnMouseWheel", function(self, delta)
    self.lastWheel = GetTime and GetTime() or 0
    self:ScrollBy(delta)
  end)
  return sf
end

-- A bordered box of text that scrolls. opts.readOnly keeps what was set (anything typed or
-- pasted is put back) and selects it all on a click, ready for Ctrl+C. opts.onChange(text)
-- runs when you type or paste. opts.hint shows while it's empty.
function S.TextBox(parent, width, height, opts)
  opts = opts or {}
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(width, height)
  local bg, edges = S.RoundBox(f, S.UI.r.field, "BACKGROUND", -8, -7)
  S.Paint(bg, S.UI.field[1], S.UI.field[2], S.UI.field[3], 1)
  S.ColorEdges(edges, S.UI.soft[1], S.UI.soft[2], S.UI.soft[3], 1)
  local sf = CreateFrame("ScrollFrame", nil, f)
  sf:SetPoint("TOPLEFT", 6, -5)
  sf:SetPoint("BOTTOMRIGHT", -8, 5)
  local eb = CreateFrame("EditBox", nil, sf)
  eb:SetMultiLine(true)
  eb:SetAutoFocus(false)
  eb:SetMaxLetters(0)
  if eb.SetMaxBytes then eb:SetMaxBytes(0) end
  eb:SetWidth(width - 16)
  eb:SetPoint("TOPLEFT")
  S.Mono(eb, 11) -- export strings and pasted text read as code
  eb:SetTextColor(S.UI.text[1], S.UI.text[2], S.UI.text[3])
  sf:SetScrollChild(eb)
  sf:EnableMouseWheel(true)
  local view = height - 10
  sf:SetScript("OnMouseWheel", function(self, delta)
    local most = self.GetVerticalScrollRange and self:GetVerticalScrollRange() or 0
    self:SetVerticalScroll(max(0, min(most or 0, (self:GetVerticalScroll() or 0) - delta * 28)))
  end)
  eb:SetScript("OnCursorChanged", function(_, _, y, _, h)
    local top, off = -(y or 0), sf:GetVerticalScroll() or 0
    h = h or 12
    if top < off then
      sf:SetVerticalScroll(top)
    elseif top + h > off + view then
      sf:SetVerticalScroll(top + h - view)
    end
  end)
  local hint = S.UIText(f, nil, "LEFT", "ARTWORK", 11)
  hint:SetPoint("TOPLEFT", 8, -6)
  hint:SetPoint("RIGHT", -8, 0)
  hint:SetTextColor(S.UI.off[1], S.UI.off[2], S.UI.off[3])
  hint:SetText(opts.hint or "")
  eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  eb:SetScript("OnEditFocusGained", function(self)
    S.ColorEdges(edges, A[1], A[2], A[3], 1)
    if opts.readOnly then self:HighlightText() end
  end)
  eb:SetScript("OnEditFocusLost", function(self)
    S.ColorEdges(edges, S.UI.soft[1], S.UI.soft[2], S.UI.soft[3], 1)
    self:HighlightText(0, 0)
  end)
  eb:SetScript("OnTextChanged", function(self, user)
    hint:SetShown((self:GetText() or "") == "")
    if not user then return end
    if opts.readOnly then
      self:SetText(f.fixed or "")
      self:HighlightText()
    elseif opts.onChange then
      opts.onChange(self:GetText() or "")
    end
  end)
  -- A click anywhere in the box, not just on the text, puts the cursor in it.
  f:EnableMouse(true)
  f:SetScript("OnMouseDown", function() eb:SetFocus() end)
  f.edit, f.scroll, f.hint = eb, sf, hint
  function f:SetText(t)
    self.fixed = t or ""
    self.edit:SetText(self.fixed)
    self.hint:SetShown(self.fixed == "")
    sf:SetVerticalScroll(0)
  end
  function f:GetText() return self.edit:GetText() or "" end
  -- Everything selected and the cursor in the box, ready for Ctrl+C.
  function f:Select()
    self.edit:SetFocus()
    self.edit:HighlightText()
  end
  return f
end

------------------------------------------------------------------------
-- Icons (since 1.61.0): small flat glyphs drawn from rectangles on a 16-unit grid, in one
-- colour, so every part and page has a mark in VoltUI's look rather than a game icon.
------------------------------------------------------------------------

-- Each glyph: { x, y, w, h, alpha, turn } from the top-left; alpha defaults to 1.
local GLYPHS = {
  frames = { { 0, 3, 5, 10, 0.55 }, { 6, 3, 10, 5 }, { 6, 9, 10, 3, 0.6 }, { 6, 13, 6, 1, 0.4 } },
  castbar = { { 0, 5, 16, 6, 0.25 }, { 0, 5, 10, 6 }, { 11, 4, 1, 8, 0.9 } },
  buffs = { { 0, 3, 4, 4 }, { 6, 3, 4, 4 }, { 12, 3, 4, 4, 0.6 }, { 0, 9, 4, 4, 0.6 }, { 6, 9, 4, 4, 0.35 } },
  groups = { { 1, 1, 14, 3 }, { 1, 5, 14, 3, 0.8 }, { 1, 9, 14, 3, 0.6 }, { 1, 13, 14, 2, 0.4 } },
  bars = { { 0, 4, 4, 4 }, { 6, 4, 4, 4 }, { 12, 4, 4, 4 }, { 0, 10, 4, 4, 0.55 }, { 6, 10, 4, 4, 0.55 }, { 12, 10, 4, 4, 0.55 } },
  nameplates = { { 3, 3, 10, 2, 0.6 }, { 0, 7, 16, 5 }, { 0, 13, 9, 1, 0.5 } },
  map = { { 1, 1, 14, 2 }, { 1, 13, 14, 2 }, { 1, 1, 2, 14 }, { 13, 1, 2, 14 }, { 6.5, 6.5, 3, 3 } },
  worldmap = { { 0, 2, 5, 12 }, { 5.5, 1, 5, 12, 0.55 }, { 11, 2, 5, 12 } },
  bags = { { 2, 5, 12, 10 }, { 5, 2, 1, 4, 0.7 }, { 10, 2, 1, 4, 0.7 }, { 5, 2, 6, 1, 0.7 }, { 6, 8, 4, 1, 0.35 } },
  loot = { { 4, 4, 8, 8, 1, 45 }, { 11, 0, 4, 4, 0.55, 45 }, { 1, 11, 3, 3, 0.4, 45 } },
  -- a tooltip: a faint box with a bright title line and two lines of text under it
  tooltips = { { 0, 2, 16, 12, 0.35 }, { 2, 4, 9, 2 }, { 2, 8, 12, 1, 0.65 }, { 2, 11, 8, 1, 0.65 } },
  junk = { { 2, 2, 12, 12, 0.45, 45 }, { 0, 7, 16, 2, 1, -45 } },
  -- rares: a crown, three points over a band
  rares = { { 1, 4, 3, 3, 1, 45 }, { 6, 2, 4, 4, 1, 45 }, { 12, 4, 3, 3, 1, 45 }, { 2, 7, 12, 4, 0.75 }, { 1, 11, 14, 3 } },
  treasures = { { 1, 6, 14, 9 }, { 1, 3, 14, 4, 0.6 }, { 7, 8, 2, 3, 0.25 } },
  questie = { { 6.5, 1, 3, 10 }, { 6.5, 12.5, 3, 3 } },
  -- chat: two speech bubbles, each with its tail, the reply fainter
  chat = { { 0, 0, 11, 8 }, { 2, 6, 3, 3, 1, 45 }, { 5, 7, 11, 7, 0.55 }, { 11, 12, 3, 3, 0.55, 45 } },
  links = { { 0, 5, 10, 11, 0.4 }, { 6, 0, 10, 2 }, { 14, 0, 2, 10 }, { 4, 6.5, 12, 2, 1, -45 } },
  drawer = { { 1, 1, 6, 6 }, { 9, 1, 6, 6, 0.7 }, { 1, 9, 6, 6, 0.7 }, { 9, 9, 6, 6, 0.45 } },
  rolls = { { 1, 1, 14, 14, 0.3 }, { 3, 3, 3, 3 }, { 10, 10, 3, 3 }, { 6.5, 6.5, 3, 3 } },
  -- guild bank: a vault, its door with a diamond lock, on two feet
  guildbank = { { 1, 1, 14, 12, 0.4 }, { 1, 1, 14, 2 }, { 5.5, 4.5, 5, 5, 1, 45 }, { 2, 13, 3, 2, 0.7 }, { 11, 13, 3, 2, 0.7 } },
  -- group finder: three heads over a listing's line
  groupfinder = { { 1, 2, 4, 4, 0.7 }, { 6, 1, 4, 4 }, { 11, 2, 4, 4, 0.7 }, { 1, 8, 14, 3 }, { 1, 12, 9, 2, 0.5 } },
  -- pages and launcher buttons
  home = { { 3, 3, 10, 10, 1, 45 }, { 3, 8, 10, 8 }, { 7, 11, 2, 5, 0.3 } },
  general = { { 0, 3, 16, 1, 0.45 }, { 3, 1, 3, 5 }, { 0, 8, 16, 1, 0.45 }, { 10, 6, 3, 5 }, { 0, 13, 16, 1, 0.45 }, { 5, 11, 3, 5 } },
  -- profiles: an empty avatar, a round head over rounded shoulders on a faint square
  profiles = { { 0, 0, 16, 16, 0.25 }, { 5, 2.5, 6, 6 }, { 5, 2.5, 6, 6, 1, 45 }, { 3, 12, 10, 4 }, { 4, 10.5, 8, 2 } },
  share = { { 1, 1, 14, 14, 0.35 }, { 4, 1, 8, 5 }, { 3, 9, 10, 6 } },
  errors = { { 0, 0, 16, 16, 0.25 }, { 6.5, 3, 3, 7 }, { 6.5, 11.5, 3, 2.5 } },
  discard = { { 5.5, 0, 5, 2 }, { 1, 2, 14, 2.5 }, { 3, 5.5, 10, 10.5, 0.85 }, { 5.5, 7, 1.5, 7.5, 0.35 }, { 9, 7, 1.5, 7.5, 0.35 } },
  heal = { { 6, 1, 4, 14 }, { 1, 6, 14, 4 } },
  clicks = { { 3, 0, 10, 16, 0.35 }, { 3, 0, 4.5, 7 }, { 7.5, 2, 1, 4, 0.6 } },
  -- dispel: a shield with a sparkle at its top right (cleansed)
  dispel = { { 1, 4, 10, 6 }, { 2.5, 6.5, 7, 7, 1, 45 }, { 12.5, 0, 1.5, 6, 0.8 }, { 10.25, 2.25, 6, 1.5, 0.8 } },
  extras = { { 0, 3, 16, 3 }, { 0, 8, 16, 3, 0.6 }, { 0, 13, 16, 2, 0.35 } },
  -- move: a thin four-way cross with a diamond point at each end (thin, so it isn't heal's plus)
  move = { { 7.25, 2, 1.5, 12, 0.7 }, { 2, 7.25, 12, 1.5, 0.7 }, { 6.25, 0.75, 3.5, 3.5, 1, 45 }, { 6.25, 11.75, 3.5, 3.5, 1, 45 },
    { 0.75, 6.25, 3.5, 3.5, 1, 45 }, { 11.75, 6.25, 3.5, 3.5, 1, 45 } },
  keys = { { 0, 4, 16, 9, 0.3 }, { 2, 6, 2, 2 }, { 5, 6, 2, 2 }, { 8, 6, 2, 2 }, { 11, 6, 3, 2 }, { 4, 10, 8, 1.5 } },
  layouts = { { 0, 0, 7, 7 }, { 9, 0, 7, 7, 0.55 }, { 0, 9, 16, 7, 0.8 } },
  -- upgrades: three bars rising left to right, the tallest brightest
  upgrades = { { 1, 10, 4, 5, 0.4 }, { 6, 6, 4, 9, 0.7 }, { 11, 1, 4, 14 }, { 0, 15, 16, 1, 0.3 } },
  alerts = { { 4, 2, 8, 9 }, { 2, 10, 12, 2 }, { 6.5, 13, 3, 2.5, 0.7 }, { 7, 0, 2, 2 } },
  look = { { 2, 2, 12, 12, 0.3, 45 }, { 2, 0, 3, 16 }, { 2, 0, 11, 3 }, { 2, 6.5, 8, 3, 0.8 } },
  search = { { 1, 1, 10, 10, 0.35 }, { 3, 3, 6, 6, 0 }, { 9, 11, 7, 3, 1, 45 } },
  foreverdb = { { 1, 1, 6, 14 }, { 9, 1, 6, 14, 0.6 }, { 7, 2, 2, 12, 0.3 } },
}
S.GLYPHS = GLYPHS
-- Which glyph each settings page shows (its own key where there's one by that name).
S.PAGE_GLYPH = {
  player = "frames", target = "frames", tot = "frames", pet = "frames", focus = "frames",
  cast = "castbar", party = "groups", raid = "groups", plates = "nameplates", friendly = "nameplates",
  plateTarget = "nameplates", maps = "map", questie = "questie",
}

-- icon = S.Icon(parent, kind, size); icon:SetKind(kind); icon:SetColor(r, g, b, a)
function S.Icon(parent, kind, size)
  local ic = CreateFrame("Frame", nil, parent)
  size = size or 16
  ic:SetSize(size, size)
  ic.parts, ic.size, ic.color = {}, size, { A[1], A[2], A[3], 1 }
  function ic:SetKind(k)
    local spec = GLYPHS[k] or GLYPHS[S.PAGE_GLYPH[k] or ""] or { { 2, 2, 12, 12, 0.6 } }
    self.kind = k
    local u = self.size / 16
    for i, r in ipairs(spec) do
      local t = self.parts[i]
      if not t then
        t = S.Tex(self, "ARTWORK")
        self.parts[i] = t
      end
      t:ClearAllPoints()
      t:SetSize(math.max(1, r[3] * u), math.max(1, r[4] * u))
      t:SetPoint("TOPLEFT", self, "TOPLEFT", r[1] * u, -r[2] * u)
      t.alpha = r[5] or 1
      if t.SetRotation then pcall(t.SetRotation, t, math.rad(r[6] or 0)) end
      t:Show()
    end
    for i = #spec + 1, #self.parts do self.parts[i]:Hide() end
    self:SetColor(self.color[1], self.color[2], self.color[3], self.color[4])
  end
  function ic:SetColor(r, g, b, a)
    local c = self.color
    if c then c[1], c[2], c[3], c[4] = r, g, b, a or 1 else self.color = { r, g, b, a or 1 } end
    for _, t in ipairs(self.parts) do t:SetColorTexture(r, g, b, (a or 1) * (t.alpha or 1)) end
  end
  ic:SetKind(kind)
  return ic
end
