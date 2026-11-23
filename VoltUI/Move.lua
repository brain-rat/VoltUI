-- VoltUI · Moving frames
-- While frames can be moved (the edit mode's Move frames), a toolbar sits at the top of the
-- screen with the grid, snapping, and where the picked frame is:
--  * a grid over the screen, its lines a set number of screen pixels apart, starting from the
--    middle of the screen (the middle lines in the accent colour)
--  * snap to grid: a dropped frame's nearest edge or middle lines up with the nearest grid line
--    or screen edge
--  * the picked frame's spot in screen pixels from the top-left, which you can type into, and
--    the arrow keys to move it one screen pixel at a time (ten with Shift)
-- Positions are only ever worked out from the frame's saved spot and the screen's size, never
-- read back from a frame just moved, since the game can still report its old place then.

local _, ns = ...
local FUI, S = ns.FUI, ns.Style

local M = { lines = {} }
ns.Move = M

local floor, abs, max = math.floor, math.abs, math.max
local A = S.ACCENT
local ARROWS = { LEFT = { -1, 0 }, RIGHT = { 1, 0 }, UP = { 0, 1 }, DOWN = { 0, -1 } }
local HOLD_DELAY, HOLD_EVERY = 0.35, 0.05 -- seconds: before a held arrow repeats, and between repeats

-- Is this overlay on screen? One can be flagged as shown while the frame it sits on is hidden
-- (a pet bar with no pet), and that frame is nothing to pick from a list or line up with.
local function Seen(m)
  if m.IsVisible then return m:IsVisible() and true or false end
  return m:IsShown() and true or false
end
M.Seen = Seen

-- One screen pixel, in the units of `frame` (or of the screen).
local function Px(frame)
  local pu = _G.PixelUtil
  local factor = pu and pu.GetPixelToUIUnitFactor and S.Safe(pu.GetPixelToUIUnitFactor())
  if type(factor) ~= "number" or factor <= 0 then factor = 1 end
  local scale = (frame or UIParent):GetEffectiveScale()
  if type(scale) ~= "number" or scale <= 0 then scale = 1 end
  return factor / scale
end
M.Px = Px

local function GridPx() return max(4, tonumber(ns.db.gridSize) or 16) end

-- The screen's size in f's units.
local function Screen(f)
  local s = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
  return UIParent:GetWidth() / s, UIParent:GetHeight() / s
end

------------------------------------------------------------------------
-- Where a frame is, and putting it somewhere
------------------------------------------------------------------------

-- The picked frame's top-left in its own units: from its saved spot, or, before it's ever been
-- moved, from where the game has it.
function M:Corner(m)
  local f = m.frame
  if m.opts.spot then
    local left, top = S.SpotCorner(f, m.opts.spot())
    if left then return left, top end
  end
  return f:GetLeft(), f:GetTop()
end

-- Saves and shows f with its top-left at left, top (its own units), to a hundredth.
function M:MoveTo(m, left, top, quiet)
  if not m.opts.spot or InCombatLockdown() then return end
  local f = m.frame
  local t, xk, yk, pk = m.opts.spot()
  -- Kept on the screen: the game holds a frame at the edge anyway, and a typed 99999 would
  -- leave the saved spot and the readout somewhere the frame isn't.
  local W, H = Screen(f)
  if type(left) == "number" and type(top) == "number" and W > 0 and H > 0 then
    left, top = max(0, math.min(W, left)), max(0, math.min(H, top))
  end
  local p, x, y = S.SpotFrom(f, left, top, true)
  if not p then return end
  if not quiet then self:Remember(m, "nudge") end
  t[xk], t[yk], t[pk] = x, y, p
  S.PlaceSpot(f, t, xk, yk, pk)
  if m.opts.apply then m.opts.apply() end -- a stand-in's own window follows
  self:Readout()
end

------------------------------------------------------------------------
-- Undo, and back to the default spot
------------------------------------------------------------------------

-- Notes where m is before it moves, so Undo can put it back. A run of nudges of one frame is
-- one move: Undo takes it back to where the run began. The last ten moves are kept (since
-- 1.80.0; it was one), newest first: each holds the one before it in `prev`.
local UNDO_MAX = 10
function M:Remember(m, kind)
  if not m.opts.spot then return end
  local u = self.undo
  if kind == "nudge" and u and u.m == m and u.kind == "nudge" then return end
  local t, xk, yk, pk = m.opts.spot()
  local left, top = self:Corner(m)
  self.undo = { m = m, kind = kind, x = t[xk], y = t[yk], p = t[pk], left = left, top = top, prev = u }
  local last, n = self.undo, 1
  while last.prev do
    n = n + 1
    if n >= UNDO_MAX then last.prev.prev = nil end
    last = last.prev
  end
  self:PaintTools()
end

-- How many moves Undo can take back.
function M:Undos()
  local n, u = 0, self.undo
  while u do n, u = n + 1, u.prev end
  return n
end

function M:Undo()
  local u = self.undo
  if not u or InCombatLockdown() then return end
  self.undo = u.prev
  local m = u.m
  local t, xk, yk, pk = m.opts.spot()
  if u.p ~= nil or u.x ~= nil then
    t[xk], t[yk], t[pk] = u.x, u.y, u.p
    S.PlaceSpot(m.frame, t, xk, yk, pk)
    if m.opts.apply then m.opts.apply() end
  elseif not self:Replace(m) and u.left then
    -- It had never been moved and VoltUI can't work out its default spot: where it was, then.
    self:MoveTo(m, u.left, u.top, true)
  end
  self:Pick(m)
  self:ReadoutSoon()
  self:PaintTools()
end

-- Puts m's frame where it sits when it has no saved spot. False if VoltUI doesn't know how.
function M:Replace(m)
  local f = m.frame
  local t, xk, yk, pk = m.opts.spot()
  S.ClearSpot(t, xk, yk, pk)
  local U, AB, C, R, D, MM = ns.UnitFrames, ns.ActionBars, ns.Castbar, ns.Raid, ns.Dispel, ns.Minimap
  if m.opts.default then
    f:ClearAllPoints()
    m.opts.default(f)
    if m.opts.apply then m.opts.apply() end
  elseif U and f.key and U.frames and U.frames[f.key] == f then
    U:Place()
  elseif AB and f.key and AB.frames and AB.frames[f.key] == f then
    AB:Place(f)
  elseif C and f == C.player then
    C:Place()
  elseif R and f == R.holder then
    R:PlaceHolder()
  elseif MM and f == MM.holder then
    MM:Place()
  elseif D and f == D.holder then
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
  elseif D and f == D.warn then
    f:ClearAllPoints()
    f:SetPoint("TOP", UIParent, "TOP", 0, -180)
  else
    return false
  end
  return true
end

-- The picked frame back to its default spot. Undo brings it back.
function M:ResetSpot()
  local m = self.picked
  if not m or not m.opts.spot or InCombatLockdown() then return end
  local t, xk, yk, pk = m.opts.spot()
  if t[pk] == nil and t[xk] == nil then return end -- it's there already
  self:Remember(m, "reset")
  local x, y, p = t[xk], t[yk], t[pk]
  if not self:Replace(m) then
    t[xk], t[yk], t[pk] = x, y, p
    self.undo = self.undo and self.undo.prev -- nothing moved: just this one forgotten
    self:PaintTools()
    return
  end
  self:Readout()
  self:ReadoutSoon()
  self:PaintTools()
end

-- Where the picked frame is, read again next frame: one just re-anchored to its default spot can
-- still report its old place.
function M:ReadoutSoon()
  if C_Timer and C_Timer.After then C_Timer.After(0, function() if M.active then M:Readout() end end) end
end

function M:PaintTools()
  if not self.bar then return end
  local m = self.picked
  local t, xk, _, pk
  if m and m.opts.spot then t, xk, _, pk = m.opts.spot() end
  local placed = t ~= nil and (t[pk] ~= nil or t[xk] ~= nil)
  self.undoBtn:SetAlpha(self.undo and 1 or 0.4)
  local n = self:Undos()
  self.undoBtn.tip = n > 1 and ("Take back the last move (%d can be taken back)"):format(n) or "Take back the last move"
  self.resetBtn:SetAlpha(placed and 1 or 0.4)
  if self.winBtn then self.winBtn.text:SetText(ns.EditMode:IsOpen() and "Hide settings" or "Show settings") end
end

------------------------------------------------------------------------
-- Stand-ins for windows that aren't open while frames are being moved
------------------------------------------------------------------------

-- Bags, bank, loot, the alerts and the lists only exist while they're open, so each gets a box
-- of its own size at its own spot to drag. Dropping it saves the window's spot.
--   key, label, page (its settings page), on() -> is its part running,
--   spot() -> t, xk, yk, pk, size() -> w, h, scale() -> number,
--   default(f): anchors f where the window opens when it has no saved spot,
--   apply(): puts the real window there, if it exists
M.anchors = {}

local function BagSize(kind)
  local db, B = ns.db, ns.Bags
  local w = db.bagCols * db.bagSize + (db.bagCols - 1) * db.gapX + 16
  local win = B.windows and B.windows[kind]
  return w, win and win.lastH or 320
end
local function BagApply()
  for _, win in pairs(ns.Bags.windows or {}) do ns.Bags:Place(win) end
end
local function DbSpot(key)
  return function() return ns.db, key .. "Left", key .. "Top", key .. "Point" end
end

M.ANCHOR_DEFS = {
  { key = "bags", label = "Bags", page = "bags", on = function() return ns.Bags.enabled end, spot = DbSpot("bag"),
    size = function() return BagSize("bags") end, scale = function() return ns.db.bagScale end, apply = BagApply,
    default = function(f) f:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -60, 110) end },
  { key = "bank", label = "Bank", page = "bags", on = function() return ns.Bags.enabled and ns.db.bank end, spot = DbSpot("bank"),
    size = function() return BagSize("bank") end, scale = function() return ns.db.bagScale end, apply = BagApply,
    default = function(f) f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 40, -120) end },
  { key = "loot", label = "Loot", page = "loot", on = function() return ns.Loot.enabled end, spot = DbSpot("loot"),
    size = function() return tonumber(ns.db.lootWidth) or 230, 152 end, scale = function() return tonumber(ns.db.lootScale) or 1 end,
    default = function(f) f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 260, -220) end },
  { key = "tooltip", label = "Tooltips", page = "loot",
    on = function() return ns.Tooltips.enabled and ns.db.tipAnchor == "spot" end, spot = DbSpot("tip"),
    size = function() return 220, 90 end,
    apply = function() ns.Tooltips:SpotFrame(); ns.Tooltips:PlaceSpot() end,
    default = function(f) f:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -80, 160) end },
}

-- A window of another add-on's, in the same shape as the ones
-- above, put after the one keyed `after` (at the end without one). Before frames are moved.
function M.AddAnchor(def, after)
  for _, d in ipairs(M.ANCHOR_DEFS) do
    if d.key == def.key then return end
  end
  local at = #M.ANCHOR_DEFS + 1
  for i, d in ipairs(M.ANCHOR_DEFS) do
    if d.key == after then at = i + 1 end
  end
  table.insert(M.ANCHOR_DEFS, at, def)
end

function M:ShowAnchors(on)
  for _, def in ipairs(self.ANCHOR_DEFS) do
    local a = self.anchors[def.key]
    local want = on and def.on() and true or false
    if want and not a then
      a = CreateFrame("Frame", "VoltUIAnchor_" .. def.key, UIParent)
      a:SetFrameStrata("MEDIUM")
      a:SetClampedToScreen(true)
      a:SetMovable(true)
      S.Panel(a, 0.45)
      a.def = def
      a.mover = S.Mover(a, def.label, function(f)
        local t, xk, yk, pk = def.spot()
        S.KeepSpot(f, t, xk, yk, pk)
        if def.apply then def.apply() end
      end, { spot = def.spot, apply = def.apply, default = def.default })
      a.mover:SetScript("OnMouseUp", function()
        if S.MoverDragged(a.mover) then return end -- that was the end of a drag, not a click
        ns.EditMode:Open(def.page)
        M:Pick(a.mover)
      end)
      self.anchors[def.key] = a
    end
    if a then
      if want then
        local w, h = def.size()
        a:SetScale(def.scale and def.scale() or 1)
        a:SetSize(w, h)
        local t, xk, yk, pk = def.spot()
        if not S.PlaceSpot(a, t, xk, yk, pk) then
          a:ClearAllPoints()
          def.default(a)
        end
        a:Show()
        a.mover:Show()
      else
        a.mover:Hide()
        a:Hide()
      end
    end
  end
end

------------------------------------------------------------------------
-- The list of frames: pick one that's hidden, tiny or under another
------------------------------------------------------------------------

function M:ToggleList()
  local l = self.list
  if l and l:IsShown() then return l:Hide() end
  if not l then
    l = CreateFrame("Frame", "VoltUIMoveList", self.bar)
    l:SetFrameStrata("DIALOG")
    l:SetToplevel(true)
    l:EnableMouse(true)
    l:SetWidth(180)
    l:SetClampedToScreen(true)
    S.ThemePanel(l, 0.97)
    l.rows = {}
    self.list = l
  end
  local shown = {}
  for _, m in ipairs(S.movers) do
    if Seen(m) then shown[#shown + 1] = m end
  end
  table.sort(shown, function(a, b) return (a.name or "") < (b.name or "") end)
  for i, m in ipairs(shown) do
    local r = l.rows[i]
    if not r then
      r = S.UIButton(l, "", 172, function(btn)
        l:Hide()
        M:Pick(btn.mover)
      end)
      r:SetHeight(20)
      if r.hl then
        S.Hover(r)
      end
      r.text:ClearAllPoints()
      r.text:SetPoint("LEFT", 8, 0)
      r.text:SetJustifyH("LEFT")
      r:SetPoint("TOPLEFT", l, "TOPLEFT", 4, -(4 + (i - 1) * 20))
      l.rows[i] = r
    end
    r.mover = m
    r.text:SetText(m.name or "?")
    if m == self.picked then
      r.text:SetTextColor(S.UI.accent[1], S.UI.accent[2], S.UI.accent[3])
    else
      r.text:SetTextColor(S.UI.text[1], S.UI.text[2], S.UI.text[3])
    end
    r:Show()
  end
  for i = #shown + 1, #l.rows do l.rows[i]:Hide() end
  l:SetHeight(#shown * 20 + 8)
  l:ClearAllPoints()
  l:SetPoint("TOPLEFT", self.listBtn, "BOTTOMLEFT", 0, -4)
  l:Show()
end

function M:Nudge(dx, dy)
  local m = self.picked
  if not m or not m.opts.spot then return end
  local left, top = self:Corner(m)
  if not left then return end
  local px = Px(m.frame)
  self:MoveTo(m, left + dx * px, top + dy * px)
end

-- In screen pixels from the screen's top-left: x, y.
function M:Pixels(m, left, top)
  if not left then left, top = self:Corner(m) end
  if not left then return end
  local px = Px(m.frame)
  local _, H = Screen(m.frame)
  return floor(left / px + 0.5), floor((H - top) / px + 0.5)
end

-- A typed spot, in screen pixels from the top-left.
function M:Typed(which, value)
  local m = self.picked
  local n = tonumber(value)
  if not m or not n then return self:Readout() end
  local left, top = self:Corner(m)
  if not left then return end
  local px = Px(m.frame)
  local _, H = Screen(m.frame)
  if which == "x" then left = n * px else top = H - n * px end
  self:MoveTo(m, left, top)
end

-- Just before a dropped frame's spot is saved: where it lands on the grid.
-- How far a frame at left, top (w by h, in its own units) is from lining up with a frame near
-- it, on each axis: dx, dy (nil when nothing lines up), and where the line they'd share runs.
-- Edges line up with edges and middles with middles, and only with frames within NEAR_PX of it
-- the other way: with every frame on screen counting, there'd nearly always be something to
-- snap to. Only frames at rest are measured, so their rects are right.
local SNAP_PX, NEAR_PX = 6, 120
function M:FrameSnap(m, left, top, w, h)
  local f = m.frame
  local es = f:GetEffectiveScale()
  if type(es) ~= "number" or es <= 0 then es = 1 end
  local px = Px(f)
  local tol, near = SNAP_PX * px, NEAR_PX * px
  local right, bottom = left + w, top - h
  local dx, dy, lineX, lineY
  local function tryX(target, v)
    local d = target - v
    if abs(d) <= tol and (not dx or abs(d) < abs(dx)) then dx, lineX = d, target end
  end
  local function tryY(target, v)
    local d = target - v
    if abs(d) <= tol and (not dy or abs(d) < abs(dy)) then dy, lineY = d, target end
  end
  for _, o in ipairs(S.movers) do
    if o ~= m and Seen(o) then
      local of = o.frame
      local l, r, t, b = of:GetLeft(), of:GetRight(), of:GetTop(), of:GetBottom()
      local os = of:GetEffectiveScale()
      if type(l) == "number" and type(r) == "number" and type(t) == "number" and type(b) == "number"
        and type(os) == "number" and os > 0 then
        local k = os / es
        l, r, t, b = l * k, r * k, t * k, b * k
        -- how far apart they are up and down, and side to side (0 when they overlap that way)
        local gapY = max(0, b - top, bottom - t)
        local gapX = max(0, l - right, left - r)
        if gapY <= near then
          tryX(l, left); tryX(r, left); tryX(l, right); tryX(r, right)
          tryX((l + r) / 2, left + w / 2)
        end
        if gapX <= near then
          tryY(t, top); tryY(b, top); tryY(t, bottom); tryY(b, bottom)
          tryY((t + b) / 2, top - h / 2)
        end
      end
    end
  end
  return dx, dy, lineX, lineY
end

-- The yellow lines a dragged frame shares with another frame: x and y in the dragged frame's
-- units, or nil for none.
function M:Guides(f, lineX, lineY)
  if not self.guide then
    local g = CreateFrame("Frame", "VoltUIGuides", UIParent)
    g:SetAllPoints(UIParent)
    g:SetFrameStrata("HIGH")
    g:EnableMouse(false)
    g.v, g.h = S.Tex(g, "OVERLAY"), S.Tex(g, "OVERLAY")
    g.v:SetColorTexture(1, 0.82, 0.4, 0.9)
    g.h:SetColorTexture(1, 0.82, 0.4, 0.9)
    g.v:SetWidth(1)
    g.h:SetHeight(1)
    self.guide = g
  end
  local g = self.guide
  local k = f and (f:GetEffectiveScale() / UIParent:GetEffectiveScale()) or 1
  g.v:SetShown(lineX ~= nil)
  g.h:SetShown(lineY ~= nil)
  if lineX then
    g.v:ClearAllPoints()
    g.v:SetPoint("TOP", UIParent, "TOPLEFT", lineX * k, 0)
    g.v:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", lineX * k, 0)
  end
  if lineY then
    g.h:ClearAllPoints()
    g.h:SetPoint("LEFT", UIParent, "BOTTOMLEFT", 0, lineY * k)
    g.h:SetPoint("RIGHT", UIParent, "BOTTOMRIGHT", 0, lineY * k)
  end
  g:SetShown(lineX ~= nil or lineY ~= nil)
end

function M:Snap(m)
  local toGrid, toFrames = ns.db.snap, ns.db.snapFrames ~= false
  if not (self.active and (toGrid or toFrames) and m.opts.spot) then return end
  local f = m.frame
  local left, top = f:GetLeft(), f:GetTop() -- straight after a drag, these are right
  if type(left) ~= "number" or type(top) ~= "number" then return end
  local w, h = f:GetWidth() or 0, f:GetHeight() or 0
  -- Another frame nearby wins over the grid, on each axis of its own.
  local fx, fy
  if toFrames then fx, fy = self:FrameSnap(m, left, top, w, h) end
  if not toGrid then
    if fx or fy then S.dropAt = { frame = f, left = left + (fx or 0), top = top + (fy or 0) } end
    return
  end
  local W, H = Screen(f)
  local g = GridPx() * Px(f)
  -- The shift that puts the nearest of start, middle or end on a grid line or screen edge.
  local function shift(start, size, total)
    local mid, best = total / 2, nil
    for _, v in ipairs({ start, start + size / 2, start + size }) do
      local line = mid + floor((v - mid) / g + 0.5) * g
      for _, l in ipairs({ line, 0, total }) do
        local d = l - v
        if not best or abs(d) < abs(best) then best = d end
      end
    end
    return best or 0
  end
  left = left + (fx or shift(left, w, W))
  local bottom = top - h
  top = top + (fy or shift(bottom, h, H))
  S.dropAt = { frame = f, left = left, top = top }
end

------------------------------------------------------------------------
-- The grid
------------------------------------------------------------------------

function M:Line(i)
  local t = self.lines[i]
  if not t then
    t = S.Tex(self.grid, "BACKGROUND")
    self.lines[i] = t
  end
  return t
end

function M:DrawGrid()
  if not self.grid then
    local g = CreateFrame("Frame", "VoltUIGrid", UIParent)
    g:SetAllPoints(UIParent)
    g:SetFrameStrata("BACKGROUND")
    g:EnableMouse(false)
    self.grid = g
  end
  local on = self.active and ns.db.grid
  self.grid:SetShown(on and true or false)
  if not on then return end
  local W, H = UIParent:GetWidth(), UIParent:GetHeight()
  local px = Px(UIParent)
  local step = GridPx() * px
  local n = 0
  local function line(vertical, at, k)
    n = n + 1
    local t = self:Line(n)
    t:ClearAllPoints()
    if vertical then
      t:SetPoint("TOPLEFT", self.grid, "TOPLEFT", at, 0)
      t:SetPoint("BOTTOMLEFT", self.grid, "BOTTOMLEFT", at, 0)
      t:SetWidth(px)
    else
      t:SetPoint("BOTTOMLEFT", self.grid, "BOTTOMLEFT", 0, at)
      t:SetPoint("BOTTOMRIGHT", self.grid, "BOTTOMRIGHT", 0, at)
      t:SetHeight(px)
    end
    if k == 0 then
      t:SetColorTexture(A[1], A[2], A[3], 0.55)
    else
      t:SetColorTexture(1, 1, 1, k % 4 == 0 and 0.13 or 0.06)
    end
    t:Show()
  end
  for _, dir in ipairs({ { true, W }, { false, H } }) do
    local vertical, total = dir[1], dir[2]
    local mid = total / 2
    local k = 0
    while mid + k * step <= total and k < 400 do
      line(vertical, mid + k * step, k)
      if k > 0 and mid - k * step >= 0 then line(vertical, mid - k * step, k) end
      k = k + 1
    end
  end
  for i = n + 1, #self.lines do self.lines[i]:Hide() end
end

------------------------------------------------------------------------
-- The toolbar
------------------------------------------------------------------------

local function Pill(parent, label, width, fn, tip)
  local b = S.PillButton(parent, label, width, fn, false, tip)
  b:SetHeight(20)
  S.FixFont(b.text, 11)
  return b
end

local function NumberBox(parent, which)
  local box = CreateFrame("EditBox", nil, parent)
  box:SetSize(48, 18)
  box:SetAutoFocus(false)
  box:SetMaxLetters(6)
  box:SetTextInsets(2, 4, 0, 0)
  box:SetJustifyH("RIGHT")
  S.Mono(box, 11)
  local bg, edges = S.RoundBox(box, S.UI.r.field, "BACKGROUND", -8, -7)
  S.Paint(bg, S.UI.card[1], S.UI.card[2], S.UI.card[3], 1)
  S.ColorEdges(edges, S.UI.soft[1], S.UI.soft[2], S.UI.soft[3], 1)
  box:SetScript("OnEditFocusGained", function(self)
    S.ColorEdges(edges, S.UI.accent[1], S.UI.accent[2], S.UI.accent[3], 1)
    self:HighlightText()
  end)
  box:SetScript("OnEditFocusLost", function(self)
    S.ColorEdges(edges, S.UI.soft[1], S.UI.soft[2], S.UI.soft[3], 1)
    self:HighlightText(0, 0)
    M:Readout() -- a number typed and abandoned doesn't stay on show
  end)
  box:SetScript("OnEnterPressed", function(self)
    M:Typed(which, self:GetText())
    self:ClearFocus()
  end)
  box:SetScript("OnTabPressed", function(self)
    M:Typed(which, self:GetText())
    if which == "x" then M.yBox:SetFocus() else self:ClearFocus() end
  end)
  box:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
    M:Readout()
  end)
  return box
end

function M:Build()
  if self.bar then return end
  local b = CreateFrame("Frame", "VoltUIMoveBar", UIParent)
  b:SetFrameStrata("DIALOG")
  b:SetToplevel(true)
  b:SetClampedToScreen(true)
  b:SetMovable(true)
  b:EnableMouse(true)
  b:RegisterForDrag("LeftButton")
  b:SetScript("OnDragStart", function(self) self:StartMoving() end)
  b:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    S.KeepSpot(self, ns.db, "moveBarLeft", "moveBarTop", "moveBarPoint")
  end)
  b:SetSize(1100, 32)
  b:Hide()
  S.ThemePanel(b, 0.96)
  self.bar = b

  local brand = S.UIText(b, nil, "LEFT", "OVERLAY", 14, nil, "mono")
  brand:SetPoint("LEFT", 10, 0)
  brand:SetText("VoltUI")
  brand:SetTextColor(S.UI.text[1], S.UI.text[2], S.UI.text[3])
  local title = S.UIText(b, nil, "LEFT", "OVERLAY", 12)
  title:SetPoint("LEFT", brand, "RIGHT", 6, 0)
  title:SetText("Moving frames")
  title:SetTextColor(S.UI.hint[1], S.UI.hint[2], S.UI.hint[3])

  self.gridBtn = Pill(b, "Grid", 46, function()
    ns.db.grid = not ns.db.grid
    M:Refresh()
  end, "Show a grid over the screen")
  self.gridBtn:SetPoint("LEFT", title, "RIGHT", 14, 0)
  self.snapBtn = Pill(b, "Snap: grid", 74, function()
    ns.db.snap = not ns.db.snap
    M:Refresh()
  end, "Line dropped frames up with the grid")
  self.snapBtn:SetPoint("LEFT", self.gridBtn, "RIGHT", 4, 0)
  self.alignBtn = Pill(b, "Snap: frames", 86, function()
    ns.db.snapFrames = not (ns.db.snapFrames ~= false)
    M:Refresh()
  end, "Line dropped frames up with other frames' edges and middles")
  self.alignBtn:SetPoint("LEFT", self.snapBtn, "RIGHT", 4, 0)
  local less = S.UIButton(b, "<", 18, function() M:GridSize(-4) end, "Grid lines closer together")
  less:SetPoint("LEFT", self.alignBtn, "RIGHT", 8, 0)
  self.sizeText = S.UIText(b, nil, "CENTER", "OVERLAY", 11, nil, "mono")
  self.sizeText:SetPoint("LEFT", less, "RIGHT", 0, 0)
  self.sizeText:SetWidth(40)
  local more = S.UIButton(b, ">", 18, function() M:GridSize(4) end, "Grid lines further apart")
  more:SetPoint("LEFT", self.sizeText, "RIGHT", 0, 0)

  local split = S.Tex(b, "ARTWORK")
  split:SetSize(1, 18)
  split:SetPoint("LEFT", more, "RIGHT", 10, 0)
  split:SetColorTexture(S.UI.line[1], S.UI.line[2], S.UI.line[3], 1)

  self.name = S.UIText(b, nil, "LEFT", "OVERLAY", 12)
  self.name:SetPoint("LEFT", split, "RIGHT", 10, 0)
  self.name:SetWidth(118)
  local xl = S.UIText(b, nil, "RIGHT", "OVERLAY", 11, nil, "mono")
  xl:SetText("X")
  xl:SetTextColor(S.UI.hint[1], S.UI.hint[2], S.UI.hint[3])
  xl:SetPoint("LEFT", self.name, "RIGHT", 4, 0)
  self.xBox = NumberBox(b, "x")
  self.xBox:SetPoint("LEFT", xl, "RIGHT", 4, 0)
  local yl = S.UIText(b, nil, "RIGHT", "OVERLAY", 11, nil, "mono")
  yl:SetText("Y")
  yl:SetTextColor(S.UI.hint[1], S.UI.hint[2], S.UI.hint[3])
  yl:SetPoint("LEFT", self.xBox, "RIGHT", 8, 0)
  self.yBox = NumberBox(b, "y")
  self.yBox:SetPoint("LEFT", yl, "RIGHT", 4, 0)
  self.hint = S.UIText(b, nil, "LEFT", "OVERLAY", 11)
  self.hint:SetPoint("LEFT", self.yBox, "RIGHT", 8, 0)
  self.hint:SetWordWrap(false)
  self.hint:SetTextColor(S.UI.hint[1], S.UI.hint[2], S.UI.hint[3])

  local done = S.PillButton(b, "Done", 62, function() FUI:SetUnlocked(false) end, true, "Stop moving frames")
  done:SetHeight(20)
  done:SetPoint("RIGHT", -6, 0)
  -- Since 1.40.0: every frame by name, the last move undone, and a frame back to its default spot.
  self.resetBtn = Pill(b, "Reset spot", 74, function() M:ResetSpot() end, "The picked frame back to its default spot")
  self.resetBtn:SetPoint("RIGHT", done, "LEFT", -8, 0)
  self.undoBtn = Pill(b, "Undo", 46, function() M:Undo() end, "Take back the last move")
  self.undoBtn:SetPoint("RIGHT", self.resetBtn, "LEFT", -4, 0)
  self.listBtn = Pill(b, "Frames", 58, function() M:ToggleList() end, "Pick a frame by name")
  self.listBtn:SetPoint("RIGHT", self.undoBtn, "LEFT", -4, 0)
  -- The settings window covers much of the screen; this puts it away and brings it back
  -- without ending Move frames.
  self.winBtn = Pill(b, "Hide settings", 96, function()
    local E = ns.EditMode
    E:Stash(E:IsOpen())
  end, "Put the settings window away while you move frames, or bring it back")
  self.winBtn:SetPoint("RIGHT", self.listBtn, "LEFT", -4, 0)
  self.hint:SetPoint("RIGHT", self.winBtn, "LEFT", -8, 0) -- cut short rather than run under the buttons
  table.insert(UISpecialFrames, "VoltUIMoveBar") -- Esc stops moving frames (its own key handler goes first: see OnKeyDown)

  -- The arrow keys nudge the picked frame; every other key goes on to the game.
  -- Esc (since 1.80.0) puts the settings window away if it's up, and only ends Move frames
  -- when it isn't: one press used to do both. A held arrow keeps nudging after a moment.
  b:SetScript("OnKeyDown", function(self, key)
    M.held = nil
    if InCombatLockdown() then return end
    local d = ARROWS[key]
    local typing = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
    if key == "ESCAPE" and not typing then
      self:SetPropagateKeyboardInput(false)
      local E = ns.EditMode
      if E:IsOpen() then E:Stash(true) else FUI:SetUnlocked(false) end
    elseif d and M.picked and M.picked.opts.spot and not typing then
      self:SetPropagateKeyboardInput(false)
      local n = IsShiftKeyDown and IsShiftKeyDown() and 10 or 1
      M:Nudge(d[1] * n, d[2] * n)
      M.held = { key = key, dx = d[1] * n, dy = d[2] * n, wait = HOLD_DELAY }
    else
      self:SetPropagateKeyboardInput(true)
    end
  end)
  b:SetScript("OnKeyUp", function(_, key)
    if M.held and M.held.key == key then M.held = nil end
  end)
  b:SetScript("OnUpdate", function(_, dt)
    local h = M.held
    if h then
      -- Let go without the game saying so (the window lost focus)? Then it's over.
      if InCombatLockdown() or not M.picked or (IsKeyDown and not IsKeyDown(h.key)) then
        M.held = nil
      else
        h.wait = h.wait - (dt or 0)
        if h.wait <= 0 then
          h.wait = HOLD_EVERY
          M:Nudge(h.dx, h.dy)
        end
      end
    end
    local m = M.dragging
    if m then
      local l, t = m.frame:GetLeft(), m.frame:GetTop() -- while dragging, the game's spot is current
      M:Readout(l, t)
      if ns.db.snapFrames ~= false and type(l) == "number" and type(t) == "number" then
        local _, _, lx, ly = M:FrameSnap(m, l, t, m.frame:GetWidth() or 0, m.frame:GetHeight() or 0)
        M:Guides(m.frame, lx, ly)
      end
    end
  end)
  b:SetScript("OnHide", function(self)
    if self.EnableKeyboard and not InCombatLockdown() then self:EnableKeyboard(false) end
    if FUI.unlocked then FUI:SetUnlocked(false) end
  end)
end

function M:GridSize(delta)
  local v = GridPx() + delta
  ns.db.gridSize = math.min(64, max(4, v))
  self:Refresh()
end

-- The toolbar's buttons and the grid, after a setting changes.
function M:Refresh()
  if not self.bar then return end
  S.PillOn(self.gridBtn, ns.db.grid)
  S.PillOn(self.snapBtn, ns.db.snap)
  S.PillOn(self.alignBtn, ns.db.snapFrames ~= false)
  if self.active then self:ShowAnchors(true) end -- a setting may have added a box, or resized one
  self.sizeText:SetText(GridPx() .. " px")
  self:DrawGrid()
  self:Readout()
  local E = ns.EditMode
  if E and E.panel and E.panel:IsShown() then E:RefreshPage() end
end

-- The picked frame (a mover), shown on the toolbar and on its own overlay.
function M:Pick(m)
  self.picked = m
  for _, mv in ipairs(S.movers) do
    if mv.fill then mv.fill:SetColorTexture(A[1], A[2], A[3], mv == m and 0.45 or 0.2) end
  end
  self:Readout()
  self:PaintTools()
end

-- Where the picked frame is. left, top: while it's being dragged, where the game has it now.
function M:Readout(left, top)
  for _, mv in ipairs(S.movers) do
    if mv ~= self.picked and mv.pos then mv.pos:Hide() end
  end
  if not self.bar then return end
  local m = self.picked
  if not m or not m:IsShown() then
    self.name:SetText("Click a frame")
    self.name:SetTextColor(S.UI.hint[1], S.UI.hint[2], S.UI.hint[3])
    self.xBox:SetText("")
    self.yBox:SetText("")
    self.hint:SetText("")
    return
  end
  self.name:SetText(m.name or "")
  self.name:SetTextColor(0.92, 0.93, 0.95)
  local x, y = self:Pixels(m, left, top)
  local canMove = m.opts.spot ~= nil
  if x and not self.xBox:HasFocus() then self.xBox:SetText(x) end
  if y and not self.yBox:HasFocus() then self.yBox:SetText(y) end
  self.hint:SetText(canMove and "Arrows: 1 px, Shift: 10" or "Drag it to move it")
  if m.pos and x then
    m.pos:SetText(x .. ", " .. y)
    m.pos:Show()
  end
end

function M:Dragging(m, on)
  self.dragging = on and m or nil
  if on then
    self:Remember(m, "drag")
    self:Pick(m)
  else
    if self.guide then self.guide:Hide() end
    self:Readout()
    self:PaintTools()
  end
end

function M:SetActive(on)
  on = on and true or false
  if on == (self.active or false) then return end
  self.active = on
  if on then
    self:Build()
    local b = self.bar
    if not S.PlaceSpot(b, ns.db, "moveBarLeft", "moveBarTop", "moveBarPoint") then
      b:ClearAllPoints()
      b:SetPoint("TOP", UIParent, "TOP", 0, -6)
    end
    -- On a screen narrower than the toolbar it shrinks to fit, so Done never falls off the edge.
    local screen = UIParent:GetWidth()
    if type(screen) == "number" and screen > 0 then b:SetScale(math.min(1, (screen - 20) / 1100)) end
    b:Show()
    self:ShowAnchors(true)
    self:PaintTools()
    if b.EnableKeyboard then
      b:EnableKeyboard(true)
      if b.SetPropagateKeyboardInput then b:SetPropagateKeyboardInput(true) end
    end
    self:Refresh()
  else
    self.dragging, self.undo, self.held = nil, nil, nil
    self:ShowAnchors(false)
    if self.list then self.list:Hide() end
    if self.bar then self.bar:Hide() end
    self:DrawGrid()
    for _, mv in ipairs(S.movers) do
      if mv.pos then mv.pos:Hide() end
    end
  end
end

S.SnapDrop = function(m) M:Snap(m) end
S.OnMoverDrag = function(m, on) M:Dragging(m, on) end
